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
	else if (strncmp(string, "spy", 		3, false) == 0)		return 8;
	else if (strncmp(string, "engineer", 	3, false) == 0)		return 9;
	return 0; // Class not recognised
}



/**
 * Create an item for a player
 * 
 * @param	int		Item definition index
 * @param	char	Classname of item
 * @return	int		Item entity index. -1 if unable to create
 */
stock int CreateItem(int itemDefIndex, char[] classname)
{
	int item = CreateEntityByName(classname);
	if (item == -1)
	{
		LogError("Couldn't create %s", classname);
	}
	else
	{
		SetEntProp(item, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(item, Prop_Send, "m_iEntityLevel", 0);
		SetEntProp(item, Prop_Send, "m_iEntityQuality", 0);
		SetEntProp(item, Prop_Send, "m_bValidatedAttachedEntity", true);
		SetEntProp(item, Prop_Send, "m_bInitialized", 1);
		//SetEntProp(item, Prop_Send, "m_hOwnerEntity");
		
		if (!DispatchSpawn(item))
		{
			LogError("Couldn't spawn %s", classname);
			RemoveEntity(item);
			item = -1;
		}
	}
	
	return item;
}



// TODO Remove this

int g_iGhost[MAXPLAYERS + 1];

/**
 * Make a player a 'ghost'.
 * They will have the same attributes as before, but they will be invisible and unable to interact with the world.
 * The player's model transmission is hooked using SDKHooks' SetTransmit to a function named Hook_GhostsTransmit.
 * 
 * @param		int		Client
 * @param		bool	Turn them into a ghost or make them 'real'
 * @param		bool	Make them a dead ghost or keep them alive
 * @noreturn
 */
stock void MakeGhost(int client, bool ghost = true, bool dead = true)
{
	if (ghost)
	{
		float pos[3], angles[3];
		GetClientAbsOrigin(client, pos);
		GetClientAbsAngles(client, angles);
		
		TF2_RespawnPlayer(client);
		TeleportEntity(client, pos, angles, NULL_VECTOR);
		
		if (dead)
			SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Dead);
		SetEntProp(client, Prop_Send, "m_CollisionGroup", 1); // Debris
		SetEntProp(client, Prop_Send, "m_usSolidFlags", GetEntProp(client, Prop_Send, "m_usSolidFlags") | 0x0006);
		
		SetEntityRenderMode(client, RENDER_TRANSALPHA);
		SetEntityRenderColor(client, _, _, _, 0);
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
		SetEntPropEnt(client, Prop_Send, "m_hLastWeapon", -1);
		SDKHook(client, SDKHook_SetTransmit, Hook_GhostsTransmit);
		
		if (!GetEntProp(client, Prop_Send, "m_bGlowEnabled"))
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
		g_iGhost[client] = true;
	}
	else
	{
		if (GetEntProp(client, Prop_Send, "m_bGlowEnabled"))
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1);
		g_iGhost[client] = false;
		
		if (IsValidEntity(client))
		{
			float pos[3], angles[3];
			GetClientAbsOrigin(client, pos);
			GetClientAbsAngles(client, angles);
		
			SDKUnhook(client, SDKHook_SetTransmit, Hook_GhostsTransmit);
			
			SetEntProp(client, Prop_Send, "m_CollisionGroup", 5);	// Player
			SetEntProp(client, Prop_Send, "m_usSolidFlags", GetEntProp(client, Prop_Send, "m_usSolidFlags") & ~0x0006);
			
			SetEntityRenderMode(client, RENDER_NORMAL);
			SetEntityRenderColor(client);
			
			TF2_RespawnPlayer(client);
			TeleportEntity(client, pos, angles, NULL_VECTOR);
		}
	}
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
stock int PickRandomParticipant(int team)
{
	int table[MaxClients + 1];
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
bool Trace_AreEntsInLOS(int entity, int contentsMask, int ent1)
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
 * Messages
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * ChatMessage
 * Send a message to a player with sound effect and prefix based on the 'message type' parameter.
 *
 * @param		int		Client index
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessage(int client, int type, const char[] string, any...)
{
	SetGlobalTransTarget(client);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 4);
	
	char prefix[13], sound[128];
	switch (type)
	{
		case Msg_Normal:
		{
			prefix = "prefix";
		}
		case Msg_Reply:
		{
			prefix = "prefix_reply";
			g_hSounds.GetString("chat_reply", sound, sizeof(sound));
		}
		case Msg_Plugin:
		{
			prefix = "prefix_plugin";
			g_hSounds.GetString("chat_plugin", sound, sizeof(sound));
		}
	}
	
	PrintToChat(client, "%t %s", prefix, buffer);
	if (sound[0]) EmitSoundToClient(client, sound);
}



/**
 * ChatMessage wrapper that sends a message to all clients
 *
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessageAll(int type, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	//VFormat(buffer, len, string, 3);	// BUG Caused incorrect translations
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 3);
		ChatMessage(i, type, buffer);
	}
}



/**
 * ChatMessage wrapper that sends a message to all clients except one
 *
 * @param		int		Client index
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessageAllEx(int client, int type, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	//VFormat(buffer, len, string, 4);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client)
			continue;
			
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 4);
		ChatMessage(i, type, buffer);
	}
}



/**
 * ChatMessage wrapper that sends a message to all admins
 *
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatAdmins(int type, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	//VFormat(buffer, len, string, 4);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetUserAdmin(i) == INVALID_ADMIN_ID)
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 3);
		ChatMessage(i, type, buffer);
	}
}



/**
 * ChatMessage wrapper that sends a message to all admins except one
 *
 * @param		int		Client index
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatAdminsEx(int client, int type, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	//VFormat(buffer, len, string, 4);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetUserAdmin(i) == INVALID_ADMIN_ID || i == client)
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 4);
		ChatMessage(i, type, buffer);
	}
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
	if (!g_ConVars[P_Debug].BoolValue)
		return;
	
	SetGlobalTransTarget(LANG_SERVER);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 2);
	
	PrintToServer("%s %s", PREFIX_DEBUG, buffer);
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
	if (!g_ConVars[P_Debug].BoolValue)
		return;
	
	SetGlobalTransTarget(client);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 3);
	
	PrintToChat(client, "%t %s", "prefix_plugin", buffer);
	PrintToServer("%s %s", PREFIX_DEBUG, buffer);
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
 * Clamp an integer
 *
 * @param		int		By-reference variable to clamp
 * @param		int		Minimum clamp boundary
 * @param		int		Maximum clamp boundary
 * @noreturn
 */
stock void ClampInt(int &value, int min, int max)
{
	if (value < min)
		value = min;
	else if (value > max)
		value = max;
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
