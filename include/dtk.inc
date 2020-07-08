#if defined _dtk_included
 #endinput
#endif
#define _dtk_included


/**
 * These aren't really native, they are functions that I am considering making into natives.
 * It's partly as a technical exercise so I can learn how to do it.
 * Some of these aren't used and/or are incomplete.
 */


/**
 * DTK Native Functions
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * DTK Count Players
 * Count the number of players on a team, or on both teams, or on all teams.
 * Choose to count only live players, or dead, or either.
 *
 * @param int Team_Red, Team_Blue, Team_Both, Team_Spec, Team_None or Team_All.
 * @param int LifeState_Alive, LifeState_Dead or LifeState_Any.
 *
 * @return			   Number of players counted.
 */
stock int DTK_CountPlayers(int team=Team_Both, int lifestate=LifeState_Any)
{
	int iCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		
		if (!player.InGame)
			continue;
		
		int iLifeState = (player.IsAlive) ? LifeState_Alive : LifeState_Dead;
		
		if (player.Team == team || (team == Team_Both && (player.Team == Team_Blue || player.Team == Team_Red)) || team == Team_All)
			if (iLifeState == lifestate || lifestate == LifeState_Any)
				iCount++;
	}
	
	//DebugMessage("Counted %d clients on team %d %swith specified life state: %d%s", iCount, team,
	//	(team == Team_Both) ? "(red and blue) " : "", lifestate,
	//	(lifestate == LifeState_Any) ? " (any)" : "");
	return iCount;
}


/**
 * DTK Set Attributes
 * Apply an attribute to a player.
 *
 * @param int Client index to apply attribute to.
 * @param char Attribute name.
 * @param float Value to assign. Default 1.0.
 * @param float Optional duration, default infinite (until death).
 * @param bool Remove this attribute (you can also use DTK_RemovePlayerAttribute).
 *
 * @return			   True if successful, false if there was a problem.
 */
stock bool DTK_AddPlayerAttribute(int client, const char[] attribute, float value=1.0, float duration=-1.0, bool remove=false)
{
	if (g_iGame != Game_TF)
		return false;
	
	// Create trigger
	int trigger;
	if ((trigger = CreateEntityByName("trigger_add_or_remove_tf_player_attributes")) == -1)
	{
		LogError("Couldn't create attribute trigger to apply attribute \"%s\" to %N", attribute, client);
		return false;
	}
	
	// Provide keyvalues
	bool bKVAccepted = true;
	bKVAccepted = DispatchKeyValue(trigger, "add_or_remove", (remove) ? "1" : "0");
	bKVAccepted = DispatchKeyValue(trigger, "spawnflags", "1");	// 1 = clients, 64 = everything except physics debris
	bKVAccepted = DispatchKeyValueFloat(trigger, "duration", duration);
	bKVAccepted = DispatchKeyValueFloat(trigger, "value", value);
	bKVAccepted = DispatchKeyValue(trigger, "attribute_name", attribute);
	if (!bKVAccepted) LogError("Couldn't dispatch a key value to attribute trigger (applying \"%s\" to %N)", attribute, client);
	
	// Spawn it
	if (!DispatchSpawn(trigger))
	{
		LogError("Couldn't spawn attribute trigger to apply attribute \"%s\" to %N", attribute, client);
		RemoveEdict(trigger);
		return false;
	}
	
	// Trigger the input from the entity
	if (!AcceptEntityInput(trigger, "StartTouch", client, client))	// not supplying a caller seemed to cause a crash
	{
		LogError("Couldn't send input to attribute trigger to apply attribute \"%s\" to %N", attribute, client);
		RemoveEdict(trigger);
		return false;
	}
	
	DebugMessage("Applied attribute \"%s\" with value '%f' to %N", attribute, value, client);
	RemoveEdict(trigger);
	return true;
}


/**
 * DTK Remove Attribute
 * Remove an attribute from a player.
 *
 * @param int Entity index to remove attribute from.
 * @param char Attribute name.
 *
 * @return			   True if successful, false if there was a problem.
 */
stock bool DTK_RemovePlayerAttribute(int client, const char[] attribute)
{
	return DTK_AddPlayerAttribute(client, attribute, _, _, true);
}



/**
 * DTK Game Sound
 * Send a teamplay_broadcast_audio event to a client.
 *
 * @param client Client to broadcast to.
 * @param sound1 Game sound name.
 * @param sound2 Second game sound name to use if first doesn't exist.
 * @param sound3 Third game sound name to use if second doesn't exist.
 * @return True if game sound exists and was broadcast. False if the mapper doesn't use it.
 */
stock bool DTK_GameSound(int client, const char[] sound1, const char[] sound2="", const char[] sound3="")
{
	if (sound1[0] == '\0')
		ThrowError("No game sound specified when using DTK_GameSound on client %d", client);
	
	Event hSound = CreateEvent("teamplay_broadcast_audio", true);
	int channel, soundLevel, pitch, maxlength;
	float volume;
	char sample[256];
	
	if (GetGameSoundParams(sound1, channel, soundLevel, volume, pitch, sample, maxlength))
		hSound.SetString("sound", sound1);
	else if (GetGameSoundParams(sound2, channel, soundLevel, volume, pitch, sample, maxlength))
		hSound.SetString("sound", sound2);
	else if (GetGameSoundParams(sound3, channel, soundLevel, volume, pitch, sample, maxlength))
		hSound.SetString("sound", sound3);
	else
	{
		hSound.Cancel();
		return false;
	}
	
	hSound.SetInt("team", 255);
	hSound.FireToClient(client);
	hSound.Cancel();
	
	return true;
}



/**
 * DTK Set Weapon Attributes
 * Apply an attribute to a weapon.
 *
 * @param int Weapon entity index to apply attribute to.
 * @param char Attribute name.
 * @param float Value to assign. Default 1.0.
 * @param float Optional duration, default infinite (until death).
 * @param bool Remove this attribute (you can also use DTK_RemoveWeaponAttribute).
 *
 * @return			   True if successful, false if there was a problem.
 */
stock bool DTK_AddWeaponAttribute(int weapon, const char[] attribute, float value=1.0, float duration=-1.0, bool remove=false)
{
	if (g_iGame != Game_TF)
		return false;
	
	if (!IsValidEdict(weapon))
	{
		LogError("Tried to adjust attributes on a weapon but it's not a valid edict");
		return false;
	}
	
	int offset; 
	if ((offset = GetEntSendPropOffs(weapon, "m_AttributeList", true)) <= 0)
	{
		LogError("Tried to set \"%s\" on weapon %d but the offset returned <= 0", attribute, weapon);
		return false;
	}
	
	// Incomplete. Probably not possible to do but I will persevere. 
	
}

