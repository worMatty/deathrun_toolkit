
#define MAX_CHAT_MESSAGE		255

// Life States
//enum {
	//LifeState_Alive,		// alive
	//LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	//LifeState_Dead,			// dead. lying still.
	//LifeState_Respawnable,
	//LifeState_DiscardBody,
//}

// Default Class Run Speeds
enum {
	RunSpeed_NoClass = 0,
	RunSpeed_Scout = 400,
	RunSpeed_Sniper = 300,
	RunSpeed_Soldier = 240,
	RunSpeed_DemoMan = 280,
	RunSpeed_Medic = 320,
	RunSpeed_Heavy = 230,
	RunSpeed_Pyro = 300,
	RunSpeed_Spy = 320,
	RunSpeed_Engineer = 300,
	RunSpeed_Merc = 320,
	RunSpeed_Civ = 280
}

// Default Class Health
enum {
	Health_NoClass = 50,
	Health_Scout = 125,
	Health_Sniper = 125,
	Health_Soldier = 200,
	Health_DemoMan = 175,
	Health_Medic = 150,
	Health_Heavy = 300,
	Health_Pyro = 175,
	Health_Spy = 125,
	Health_Engineer = 125,
	Health_Merc = 150,
	Health_Civ = 200
}


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



stock int GetTFClassRunSpeed(TFClassType class)
{
	int runspeeds[] =
	{
		RunSpeed_NoClass,
		RunSpeed_Scout,
		RunSpeed_Sniper,
		RunSpeed_Soldier,
		RunSpeed_DemoMan,
		RunSpeed_Medic,
		RunSpeed_Heavy,
		RunSpeed_Pyro,
		RunSpeed_Spy,
		RunSpeed_Engineer,
		RunSpeed_Merc
	};
	
	char folder[32];
	GetGameFolderName(folder, sizeof(folder));
	if (StrEqual(folder, "tf2classic")) runspeeds[10] = RunSpeed_Civ;
	
	return runspeeds[view_as<int>(class)];
	
}



stock int GetTFClassHealth(TFClassType class)
{
	int health[] =
	{
		Health_NoClass,
		Health_Scout,
		Health_Sniper,
		Health_Soldier,
		Health_DemoMan,
		Health_Medic,
		Health_Heavy,
		Health_Pyro,
		Health_Spy,
		Health_Engineer,
		Health_Merc
	};
	
	char folder[32];
	GetGameFolderName(folder, sizeof(folder));
	if (StrEqual(folder, "tf2classic")) health[10] = Health_Civ;
	
	return health[view_as<int>(class)];
	
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
	int[] table = new int[MaxClients];
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
stock bool RespawnTeamsUsingEntity(int team = 0)
{
	int ent = CreateEntityByName("game_forcerespawn");
	bool result;

	if (ent != -1 && DispatchSpawn(ent))
	{
		if (!team)
		{
			result = AcceptEntityInput(ent, "ForceRespawn");
		}
		else
		{
			SetVariantInt(team);
			result = AcceptEntityInput(ent, "ForceTeamRespawn");
		}

		AcceptEntityInput(ent, "Kill");
	}
	
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
 * @param	entity	Entity index
 * @return	True if entity is a client, false otherwise
 */
stock bool IsClient(int entity)
{
	return (0 < entity <= MaxClients);
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
	char folder[8];
	GetGameFolderName(folder, sizeof(folder));
	if (!StrEqual(folder, "tf"))
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
	if (!DRGame.IsGame(Mod_TF))
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
 * Show a training annotation to a player
 *
 * @param	client	Client who will see the annotation
 * @param	entity	Entity the message appears above
 * @param	sound	Sound file that will be played to the client when the event is fired
 * @param	format	Formatting rules
 * @param	...		Variable number of formatting parameters
 * @error	Client not in game
 * @return	Event created
 */
stock bool ShowAnnotation(int client, int entity, const char[] sound = "", const char[] format, any...)
{
	Event annotation = CreateEvent("show_annotation");
	
	if (!annotation)
		return false;
	
	char buffer[256];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 4);
	
	annotation.SetBool("show_effect", false);
	annotation.SetInt("follow_entindex", entity);
	annotation.SetFloat("lifetime", 5.0);
	annotation.SetString("play_sound", sound[0] ? sound : "common/null.wav");
	annotation.SetString("text", buffer);
	annotation.FireToClient(client);
	annotation.Cancel();
	
	return true;
}




/**
 * Sends a SayText2 User Message to a client which team-colours text when \x02 or \x03 are used in the string.
 *
 * @param	client			Recipient client index
 * @param	colorClient		Team-coloured text will use this client's team, or light green if left blank
 * @param	format			Formatting rules
 * @param	any				Variable number of formatting parameters
 *
 * Guidelines: colorClient should not be used to colour the recipient's name, and they should not be referred to in the third person.
 * This parameter should be used to colour the name of another client who has done something the recipient needs to be aware of.
 * For example, they are the recipient's killer, or they granted them a bonus or performed some action.
  */
stock void TF2_PrintToChat(int client, int colorClient = 0, const char[] format, any ...)
{
	char buffer[254];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 4);
	
	BfWrite message = UserMessageToBfWrite(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	
	if (message != null)
	{
		message.WriteByte(colorClient);
		message.WriteByte(true);		// bChat?
		message.WriteString(buffer);
		
		EndMessage();
	}
	else
	{
		PrintToChat(client, buffer);
	}
}



/**
 * Sends a SayText2 User Message to a client which team-colours text when \x02 or \x03 are used in the string.
 * Additionally specify up to two Source translation keys, and the game will translate them into the user's local language.
 *
 * @param	client			Recipient client index
 * @param	colorClient		Team-coloured text will use this client's team, or light green if left blank
 * @param	translate1		Source translation key
 * @param	translate2		Source translation key
 * @param	format			Formatting rules
 * @param	any				Variable number of formatting parameters
 *
 * Guidelines: colorClient should not be used to colour the recipient's name, and they should not be referred to in the third person.
 * This parameter should be used to colour the name of another client who has done something the recipient needs to be aware of.
 * For example, they are the recipient's killer, or they granted them a bonus or performed some action.
 */
stock void TF2_PrintToChatEx(int client, int colorClient = 0, const char[] translation1 = "", const char[] translation2 = "", const char[] format, any ...)
{
	BfWrite message = UserMessageToBfWrite(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	
	if (message != null)
	{
		SetGlobalTransTarget(client);
		char buffer[254];
		VFormat(buffer, sizeof(buffer), format, 6);
		
		message.WriteByte(colorClient);
		message.WriteByte(true);
		message.WriteString(buffer)

		message.WriteString("");
		message.WriteString("");
		message.WriteString(translation1);
		message.WriteString(translation2);
		
		/*
			This works like a format function.
			We supply a format string first, and any formatting parameters afterwards.
			String parameters three and four are translated.
		*/
		
		EndMessage();
	}
}




/**
 * Sends a SayText2 User Message to a client which team-colours text when \x02 or \x03 are used in the string.
 * If the command was issued from the console, the reply is sent there.
 * 
 * @param	client			Recipient client index
 * @param	colorClient		Team-coloured text will use this client's team, or light green if left blank
 * @param	format			Formatting rules
 * @param	any				Variable number of formatting parameters
 *
 * Guidelines: colorClient should not be used to colour the recipient's name, and they should not be referred to in the third person.
 * This parameter should be used to colour the name of another client who has done something the recipient needs to be aware of.
 * For example, they are the recipient's killer, or they granted them a bonus or performed some action.
 */
stock void TF2_ReplyToCommand(int client, int colorClient = 0, const char[] format, any ...)
{
	char buffer[254];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 4);

	if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		PrintToConsole(client, buffer);
		return;
	}

	BfWrite message = UserMessageToBfWrite(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
	
	if (message != null)
	{
		message.WriteByte(colorClient);
		message.WriteByte(true);		// bChat?
		message.WriteString(buffer);
		
		EndMessage();
	}
	else
	{
		PrintToChat(client, buffer);
	}
}




/**
 * Sends a SayText2 User Message to all client which team-colours text when \x02 or \x03 are used in the string.
 * 
 * @param	colorClient		Team-coloured text will use this client's team, or light green if left blank
 * @param	format			Formatting rules
 * @param	any				Variable number of formatting parameters
  */
stock void TF2_PrintToChatAll(int colorClient = 0, const char[] format, any ...)
{
	char buffer[254];
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			SetGlobalTransTarget(client);
			VFormat(buffer, sizeof(buffer), format, 3);
			
			BfWrite message = UserMessageToBfWrite(StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS));
			
			if (message != null)
			{
				message.WriteByte(colorClient);
				message.WriteByte(true);
				message.WriteString(buffer);
				
				EndMessage();
			}
			else
			{
				PrintToChat(client, buffer);
			}
		}
	}
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
