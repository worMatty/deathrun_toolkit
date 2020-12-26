/**
 * TF2 Stuff
 * ----------------------------------------------------------------------------------------------------
 */

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
	else if (strncmp(string, "spy", 		3, false) == 0)			return 8;
	else if (strncmp(string, "engineer", 	3, false) == 0)	return 9;
	return 0; // Class not recognised
}



/**
 * Pick a random player from a team.
 * 
 * @param	int		Team number
 * @return	int		Client index
 */
stock int PickRandomParticipant(int team)
{
	int iTable[MaxClients + 1];
	int iIndex;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == team)
		{
			iTable[iIndex] = i;
			iIndex += 1;
		}
	}
	
	int iResult = iTable[GetRandomInt(0, iIndex - 1)];
	return iResult;
}



/**
 * Set Player Attribute TODO Include TF2 Attributes in here if it is loaded 
 * Apply an attribute to a player.
 *
 * @param int Client index to apply attribute to.
 * @param char Attribute name.
 * @param float Value to assign. Default 1.0.
 * @param float Optional duration, default infinite (until death).
 * @param bool Remove this attribute (you can also use RemovePlayerAttribute).
 *
 * @return			   True if successful, false if there was a problem.
 */
stock bool AddPlayerAttribute(int client, const char[] attribute, float value=1.0, float duration=-1.0, bool remove=false)
{
	if (!(g_iGame & FLAG_TF))
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
 * Remove Player Attribute
 * Remove an attribute from a player.
 *
 * @param int Entity index to remove attribute from.
 * @param char Attribute name.
 *
 * @return			   True if successful, false if there was a problem.
 */
stock bool RemovePlayerAttribute(int client, const char[] attribute)
{
	return AddPlayerAttribute(client, attribute, _, _, true);
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
	int iLength = strlen(buffer);
	
	// For every character, if it's a special character replace it with whitespace
	for (int i = 0; i < iLength; i++)
	{
		switch (buffer[i])
		{
			case '\r': buffer[i] = ' ';
			case '\n': buffer[i] = ' ';		// New line
			case '\t': buffer[i] = ' ';
		}
	}

	// Remove whitespace from the beginning and end
	TrimString(buffer);
}




/**
 * Messages
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Reply to a client's command and play a sound effect.
 * Uses a sound from StringMap 'g_hSound' with key 'chat_reply'.
 * Uses the translation phrase 'prefix_reply' for the chat prefix.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void ReplyToChat(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 3);
	
	PrintToChat(client, "%t %s", "prefix_reply", sBuffer);
	
	char sSound[128];
	g_hSound.GetString("chat_reply", sSound, sizeof(sSound));
	EmitSoundToClient(client, sSound);
}



/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 *
 * @param 		char	Formatting rules
 * @param 		...		Variable number of formatting arguments
 * @noreturn
 */
stock void Debug(const char[] string, any...)
{
	if (!g_ConVar[P_Debug].BoolValue)
		return;
	
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 2);
	
	PrintToServer("%s %s", PREFIX_DEBUG, sBuffer);
}



/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 * Ex: Also displays to client in chat.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void DebugEx(int client, const char[] string, any...)
{
	if (!g_ConVar[P_Debug].BoolValue)
		return;
	
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 3);
	
	PrintToChat(client, "%t %s", "prefix_error", sBuffer);
	PrintToServer("%s %s", PREFIX_DEBUG, sBuffer);
}



/**
 * Send a message to all clients except the one specified.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void PrintToChatAllEx(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 3);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client)
			continue;
		
		PrintToChat(i, sBuffer);
	}
}



/**
 * Send a message to all admins.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void PrintToChatAdmins(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 3);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetUserAdmin(i) != INVALID_ADMIN_ID)
			PrintToChat(i, sBuffer);
	}
}



/**
 * Send a message to all admins except the one specified.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void PrintToChatAdminsEx(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] sBuffer = new char[len];
	VFormat(sBuffer, len, string, 3);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetUserAdmin(i) != INVALID_ADMIN_ID && i != client)
			PrintToChat(i, sBuffer);
	}
}




/**
 * Server Stuff
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Precache sounds in g_hSounds StringMap.
 *
 * @noreturn
 */
stock void PrecacheSounds()
{
	StringMapSnapshot hSnapshot = g_hSound.Snapshot();
	int iLength = hSnapshot.Length;
	char sKeyString[32];
	char sSound[64];

	for (int i = 0; i < iLength; i++)
	{
		hSnapshot.GetKey(i, sKeyString, sizeof(sKeyString));
		g_hSound.GetString(sKeyString, sSound, sizeof(sSound));
		
		if (!PrecacheSound(sSound, true))
			LogError("Failed to precache %s", sSound);
	}

	delete hSnapshot;
}