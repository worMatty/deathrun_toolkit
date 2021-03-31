#define MAX_CHAT_MESSAGE		255


/**
 * TF2 Stuff
 * ----------------------------------------------------------------------------------------------------
 */

methodmap TFTeam
{
	public int Count()
	{
		return GetTeamClientCount(view_as<int>(this));
	}
	
	public int Alive()
	{
		int count;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == this && GetEntProp(i, Prop_Send, "m_lifeState") == LifeState_Alive)
				count++;
		}
		
		return count;
	}
}
// TFTeam(TFTeam_Red).Alive()
// TFTeam_Red.Alive()
// TF2_GetClientTeam(client).Alive()
// player.Team.Alive()?




/**
 * Take a TF class name and return its number.
 * 
 * @param		char	Class name string
 * @return		int		Class number
 */
stock int ProcessClassString(const char[] string)
{
	if 		(strncmp(string, "scout", 		3, false) == 0)		return 1;
	else if (strncmp(string, "sniper", 		3, false) == 0)		return 2;
	else if (strncmp(string, "soldier", 	3, false) == 0)		return 3;
	else if (strncmp(string, "demo", 		3, false) == 0)		return 4;
	else if (strncmp(string, "medic", 		3, false) == 0)		return 5;
	else if (strncmp(string, "heavy", 		3, false) == 0)		return 6;
	else if (strncmp(string, "pyro", 		3, false) == 0)		return 7;
	else if (strncmp(string, "spy", 		3, false) == 0)		return 8;
	else if (strncmp(string, "engineer", 	3, false) == 0)		return 9;
	else if (strncmp(string, "mercenary",	4, false) == 0)		return 10;
	else if (strncmp(string, "civilian",	3, false) == 0)		return 10;
	return 0; // Class not recognised
}




/**
 * Players & Teams
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Pick a random player from a team.
 * 
 * @param	int		Team number
 * @return	int		Client index
 */
stock int PickRandomTeamMember(int team)
{
	int table[MaxClients];
	int index;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			table[index] = i;
			index += 1;
		}
	}
	
	int result = table[GetRandomInt(0, index - 1)];
	return result;
}




/**
 * Respawn all players using a game_forcerespawn
 * 
 * @noreturn
 */
stock void RespawnTeamsUsingEntity(int team = 0)
{
	int ent = CreateEntityByName("game_forcerespawn");
	
	if (ent != -1 && DispatchSpawn(ent))
	{
		if (!team)
		{
			AcceptEntityInput(ent, "ForceRespawn");
		}
		else
		{
			SetVariantInt(team);
			AcceptEntityInput(ent, "ForceTeamRespawn");
		}

		AcceptEntityInput(ent, "Kill");
	}
}



/**
 * Utilities
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Remove special characters from a parsed string.
 * 
 * @param		char	String
 * @noreturn
 */
stock void CleanString(char[] buffer)
{
	// Get the length of the string
	int len = strlen(buffer);
	
	// For every character, if it's a special character replace it with whitespace
	for (int i = 0; i < len; i++)
	{
		switch (buffer[i])
		{
			case '\r': buffer[i] = ' ';
			case '\n': buffer[i] = ' ';
			case '\t': buffer[i] = ' ';
		}
	}

	// Remove whitespace from the beginning and end
	TrimString(buffer);
}




/**
 * Entity Work
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Check if an entity is a client
 *
 * @param		int		Entity
 * @return		bool	True if ent is a client
 */
stock bool IsClient(int entity)
{
	if (entity > 0 && entity <= MaxClients)
		return true;
	else
		return false;
}



/**
 * Get the distance between two entities
 *
 * @param		int		Entity 1
 * @param		int		Entity 2
 * @return		float	Distance
 */
stock float GetDistance(int ent1, int ent2)
{
	float pos1[3], pos2[3];
	
	if (IsClient(ent1))
		GetClientAbsOrigin(ent1, pos1);
	else
		GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos1);
	
	if (IsClient(ent2))
		GetClientAbsOrigin(ent2, pos2);
	else
		GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", pos2);
	
	return GetVectorDistance(pos1, pos2);
}




/**
 * Check if two entities are in LOS
 *
 * @param		int		Entity 1
 * @param		int		Entity 2
 * @param		int		Contents flags used for solidity and visibility
 * @return		bool	Entities are within LOS
 * @error		Invalid entity, client not in game, property not found or valid, etc.
 */
stock bool AreEntsInLOS(int ent1, int ent2, int flags = CONTENTS_SOLID)
{
	float pos1[3], pos2[3];
	
	// Get coords
	if (IsClient(ent1))
		GetClientEyePosition(ent1, pos1);
	else
		GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos1);
	
	if (IsClient(ent2))
		GetClientEyePosition(ent2, pos2);
	else
		GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", pos2);
	
	// Check if ents are in LOS
	Handle hTrace = TR_TraceRayFilterEx(pos1, pos2, flags, RayType_EndPoint, Trace_AreEntsInLOS, ent1);
	
	bool los = (TR_GetEntityIndex(hTrace) == ent2);
	
	delete(hTrace);
	return los;
}

// Trace filter for the above function
stock bool Trace_AreEntsInLOS(int entity, int contentsMask, int ent1)
{
	/*
		TraceFilter is called for each entity the ray hits.
		If the entity should be ignored, return true.
		The ray collides with the player it originates from so you need to filter them out.
	*/
	
	// True to allow the current entity to be hit, otherwise false.
	return (entity != ent1);
	// This filters out the originating entity
}




/**
 * Add Attribute
 * Apply an attribute to an entity.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute name
 * @param 	float 	Value. Default 1.0
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool AddAttribute(int entity, char[] attribute, float value = 1.0)
{
	// Return false if game is not TF2 as only TF2 supports attributes
	if (!game.IsGame(Mod_TF))
		return false;
	
	// TF2 Attributes plugin is now required
	if (g_bTF2Attributes)
		return TF2Attrib_SetByName(entity, attribute, value);
	else
		return false;
}



/**
 * Remove Attribute
 * Remove an attribute from an entity.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool RemoveAttribute(int entity, char[] attribute)
{
	if (g_bTF2Attributes)
		return TF2Attrib_RemoveByName(entity, attribute);
	else
		return false;
}


/**
 * Remove All Attributes
 * Remove all attributes from an entity.
 *
 * @param 	int 	Entity index
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool RemoveAllAttributes(int entity)
{
	if (g_bTF2Attributes)
		return TF2Attrib_RemoveAll(entity);
	else
		return false;
}



/**
 * Add Attribute Trigger
 * Apply an attribute to an entity using the tf attribute trigger.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute name
 * @param 	float 	Value. Default 1.0
 * @param 	float 	Optional duration, default infinite (until player death)
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool AddAttributeTrigger(int entity, char[] attribute, float value = 1.0, float duration = -1.0, bool remove = false)
{
	if (!game.IsGame(Mod_TF))
		return false;
	
	else if (entity > 0 && entity <= MaxClients)	// Attribute trigger only works on players
	{
		// Create Trigger
		int trigger;
		if ((trigger = CreateEntityByName("trigger_add_or_remove_tf_player_attributes")) == -1)
		{
			LogError("Couldn't create attribute trigger");
			return false;
		}
		
		// Provide keyvalues
		DispatchKeyValue(trigger, "add_or_remove", (remove) ? "1" : "0");
		DispatchKeyValue(trigger, "spawnflags", "1");	// 1 = clients, 64 = everything except physics debris
		DispatchKeyValue(trigger, "attribute_name", attribute);
		if (!remove) DispatchKeyValueFloat(trigger, "duration", duration);
		if (!remove) DispatchKeyValueFloat(trigger, "value", value);
		
		// Spawn
		if (!DispatchSpawn(trigger))
		{
			LogError("Couldn't spawn attribute trigger");
			RemoveEntity(trigger);
			return false;
		}
		
		// Fire Input
		if (!AcceptEntityInput(trigger, "StartTouch", entity, entity))	// not supplying a caller seemed to cause a crash
		{
			LogError("Couldn't send input to attribute trigger");
			RemoveEntity(trigger);
			return false;
		}
		
		RemoveEntity(trigger);
		return true;
	}
	else
	{
		LogError("Unable to apply attributes using TF2 trigger to non-player entities (ent: %d)", entity);
		return false;
	}
}



/**
 * Remove Attribute Trigger
 * Remove an attribute from an entity using the tf attribute trigger.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool RemoveAttributeTrigger(int client, char[] attribute)
{
	return AddAttributeTrigger(client, attribute, _, _, true);
}




/**
 * Show a training annotation to a player
 *
 * @param		int		Client index
 * @param		int		Entity the message appears above
 * @param		char	Sound file to give the event
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @error				Client not in game
 * @noreturn
 */
stock bool ShowAnnotation(int client, int entity, const char[] sound = "", const char[] string, any...)
{
	Event hAnnot = CreateEvent("show_annotation");
	
	if (!hAnnot)
		return false;
	
	hAnnot.SetBool("show_effect", false);
	hAnnot.SetInt("follow_entindex", entity);
	hAnnot.SetFloat("lifetime", 5.0);
	
	// Set sound
/*	if (sound[0])
		hAnnot.SetString("play_sound", sound);
	else
		hAnnot.SetString("play_sound", "common/null.wav");
*/	hAnnot.SetString("play_sound", sound[0] ? sound : "common/null.wav");

	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	SetGlobalTransTarget(client);
	VFormat(buffer, len, string, 4);
	
	hAnnot.SetString("text", buffer);
	hAnnot.FireToClient(client);
	hAnnot.Cancel();
	return true;
}




/**
 * Sounds
 * ----------------------------------------------------------------------------------------------------
 */




/**
 * Maths
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Clamp an integer between two ranges
 * Min must be lower than max and vice versa
 *
 * @param		int		By-reference variable to clamp
 * @param		int		Minimum clamp boundary
 * @param		int		Maximum clamp boundary
 * @noreturn
 */
stock void ClampInt(int &value, int min, int max)
{
	if (value <= min)
		value = min;
	else if (value >= max)
		value = max;
}



/**
 * Clamp an integer to a minimum value
 *
 * @param		int		By-reference variable to clamp
 * @param		int		Minimum clamp boundary
 * @noreturn
 */
stock void ClampIntMin(int &value, int min)
{
	value = ((value < min) ? min : value);
}



/**
 * Clamp an integer to a maximum value
 *
 * @param		int		By-reference variable to clamp
 * @param		int		Maximum clamp boundary
 * @noreturn
 */
stock void ClampIntMax(int &value, int max)
{
	value = ((value > max) ? max : value);
}



/**
 * Clamp a float
 *
 * @param		float		By-reference variable to clamp
 * @param		float		Minimum clamp boundary
 * @param		float		Maximum clamp boundary
 * @noreturn
 */
stock void ClampFloat(float &value, float min, float max)
{
	if (value < min)
		value = min;
	else if (value > max)
		value = max;
}




/**
 * Coordinates
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Get the coordinates of the point in the world your crosshair is resting
 *
 * @param		int		Client index
 * @param		vec		Coordinates vector (by reference)
 * @noreturn
 */
stock void GetClientAimPos(int client, float pos[3])
{
	float vEyePos[3], vEyeAngles[3];
	
	GetClientEyePosition(client, vEyePos);
	GetClientEyeAngles(client, vEyeAngles);
	
	Handle hTrace = TR_TraceRayFilterEx(vEyePos, vEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, Trace_GetClientAimPos);
	
	if (TR_DidHit(hTrace))
		TR_GetEndPosition(pos, hTrace);
	
	CloseHandle(hTrace);
}

// Trace filter for the above function
bool Trace_GetClientAimPos(int entity, int contentsMask)
{
	// Filter out players hit by the ray
	return (entity > MaxClients);
}




/**
 * Server Stuff
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Precache assets in a StringMap
 *
 * @noreturn
 */
stock void PrecacheAssets(StringMap stringmap)
{
	StringMapSnapshot snapshot = stringmap.Snapshot();
	int len = snapshot.Length;
	char key[32];
	char asset[128];

	for (int i = 0; i < len; i++)
	{
		snapshot.GetKey(i, key, sizeof(key));
		stringmap.GetString(key, asset, sizeof(asset));
		
		if ((StrContains(asset, ".wav", false) != -1 || StrContains(asset, ".mp3", false) != -1) && !PrecacheSound(asset, true))
			LogError("Failed to precache sound %s", asset);
		
		if (StrContains(asset, ".mdl", false) != -1 && !PrecacheModel(asset, true))
			LogError("Failed to precache model %s", asset);
	}

	delete snapshot;
}
