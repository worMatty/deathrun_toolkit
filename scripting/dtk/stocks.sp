// Matty's stocks v1.1

/**
 * Changelog
 * 1.1 - GetEntityParent; GetEntityAbsOrigin;
 */

#include <tf2_stocks>

// Life states
enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
}

// TF2 / Open Fortress / TF2 Classic classes
enum {
	Class_Unknown,
	Class_Scout,
	Class_Sniper,
	Class_Soldier,
	Class_DemoMan,
	Class_Medic,
	Class_Heavy,
	Class_Pyro,
	Class_Spy,
	Class_Engineer,
	Class_Merc = 10,
	Class_Civ = 10
}

// Default TF2 class max run speeds
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

// Default TF2 class health
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

static bool g_bIsGameTF2;
static bool g_bIsGameOpenFortress;
static bool g_bIsGameTF2Classic;
static bool g_bIsGameUnknown;
static bool g_bIsGameDetermined;

/**
 * Determine the game.
 * Called whenever a game check is made.
 * First time this runs it determines the game.
 *
 * @noreturn
 */
stock void DetermineGame()
{
	if (!g_bIsGameDetermined)
	{
		char game_folder[32];
		GetGameFolderName(game_folder, sizeof(game_folder));

		if (StrEqual(game_folder, "tf"))
		{
			g_bIsGameTF2 = true;
		}

		else if (StrEqual(game_folder, "open_fortress"))
		{
			g_bIsGameOpenFortress = true;
		}

		else if (StrEqual(game_folder, "tf2classic"))
		{
			g_bIsGameTF2Classic = true;
		}

		else
		{
			g_bIsGameUnknown = true;
		}

		g_bIsGameDetermined = true;
	}
}

stock bool IsGameTF2()
{
	DetermineGame();
	return g_bIsGameTF2;
}

stock bool IsGameOpenFortress()
{
	DetermineGame();
	return g_bIsGameOpenFortress;
}

stock bool IsGameTF2Classic()
{
	DetermineGame();
	return g_bIsGameTF2Classic;
}

stock bool IsGameKnown()
{
	DetermineGame();
	return !g_bIsGameUnknown;
}


/**
 * TF2 Stuff
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Attach methods to the TFTeam type
 */
methodmap TFTeam
{
	public int Count()
	{
		return GetTeamClientCount(view_as<int>(this));
	}

	public int AliveCount()
	{
		int count;

		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == this && GetEntProp(i, Prop_Send, "m_lifeState") == LifeState_Alive)
			{
				count++;
			}
		}

		return count;
	}
}
// TFTeam(TFTeam_Red).Alive()
// TFTeam_Red.AliveCount()
// TF2_GetClientTeam(client).Alive()
// player.Team.Alive()?

/**
 * Take a TF class name and return its number.
 *
 * @param	string		Class name string
 * @return	Class number
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
 * Get a TF2 classs max run speed
 *
 * @param	class		TF2 class
 * @return	Max run speed
 */
stock int TF2_GetTFClassRunSpeed(TFClassType class)
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

	if (IsGameTF2Classic())
	{
		runspeeds[10] = RunSpeed_Civ;
	}

	return runspeeds[view_as<int>(class)];

}

/**
 * Get a TF2 class's default max health
 *
 * @param	class		TF2 class
 * @return	Class health
 */
stock int TF2_GetTFClassHealth(TFClassType class)
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

	if (IsGameTF2Classic())
	{
		health[10] = Health_Civ;
	}

	return health[view_as<int>(class)];
}

/**
 * Gets the team number from a text string.
 *
 * @param	string			Text string
 * @return	int				Team number, or -1 if no match found;
  */
stock int StringToTeam(const char[] string)
{
	int team = -1;

	if (StrContains(string, "u", false) == 0)
	{
		team = 0;
	}
	else if (StrContains(string, "sp", false) == 0)
	{
		team = 1;
	}
	else if (StrContains(string, "r", false) == 0)
	{
		team = 2;
	}
	else if (StrContains(string, "b", false) == 0)
	{
		team = 3;
	}

	return team;
}

/**
 * Run some VScript on an entity
 *
 * @param		entity		Entity index to send the input to
 * @param		format		String of text including format specifiers
 * @param		...			Formatting arguments
 * @return		True if entity input was accepted and game is TF2
 */
stock bool RunScriptCode(int entity, const char[] format, any ...)
{
	if (IsGameTF2())
	{
		int len = strlen(format) + 256;
		char[] parameter = new char[len];
		VFormat(parameter, len, format, 3);

		SetVariantString(parameter);
		return AcceptEntityInput(entity, "RunScriptCode");
	}

	return false;
}

/**
 * Respawn all players using a game_forcerespawn
 *
 * @param	team		Team number
 * @return	True if the entity was created and input accepted
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
 * Players & Teams
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Get the number of clients in-game and on a playable team
 * i.e. Not unassigned and not on the spectator team
 *
 * @return		Number of clients playing
 */
stock int GetActiveClientCount()
{
	int count;

	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) > 1)
		count++;
	}

	return count;
}

/**
 * Pick a random player from the specified team
 *
 * @param	team		Team number
 * @return	Client index
 */
stock int PickRandomTeamMember(int team)
{
	int[] table = new int[MaxClients];
	int len = MaxClients;
	int index;

	for (int i = 1; i <= len; i++)
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
 * Strings
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Remove special characters from a parsed string
 *
 * @param	buffer		String
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
 * Checks if a string is numeric.
 * # is not classed as a number!
 *
 * @param	string		String to check
 * @return	True if string is numeric, false if at least one character is alphabetical
 */
stock bool IsStringNumeric(const char[] string)
{
	bool alpha;
	int i;
	int len = strlen(string);

	while (!alpha && i <= len)
	{
		if (string[i] == '#' || IsCharAlpha(string[i]))
		{
			alpha = true;
			break;
		}
		i++;
	}

	return !alpha;
}


/**
 * Entities
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Check if an entity's index falls within the client range
 *
 * @param	entity		Entity index
 * @return	True if entity index is in the client range, false otherwise
 */
stock bool IsClient(int entity)
{
	return (0 < entity <= MaxClients);
}

/**
 * Get an entity's targetname
 *
 * @param	entity			Entity index
 * @param	targetname		Destination string buffer
 * @param	maxlength		Maximum length of output string buffer
 * @return					Number of non-null bytes written
 * @error					Invalid entity, offset out of reasonable bounds, or property is not a valid string
 */
stock int GetEntityTargetname(int entity, char[] targetname, int maxlength)
{
	int num_written = GetEntPropString(entity, Prop_Data, "m_iName", targetname, maxlength);
	return num_written;
}

/**
 * Get an entity's origin
 * @param	entity			Entity index or reference
 * @prarm	origin			Three floats to store the X Y Z position
 */
stock void GetEntityAbsOrigin(int entity, float origin[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsOrigin", origin);
}


/**
 * Set an entity's targetname
 *
 * @param	entity			Entity index
 * @param	targetname		String to set
 * @return					Number of non-null bytes written
 * @error					Invalid entity, offset out of reasonable bounds, or property is not a valid string
 */
stock int SetEntityTargetname(int entity, char[] targetname)
{
	int num_written = SetEntPropString(entity, Prop_Data, "m_iName", targetname);
	return num_written;
}

/**
 * Kill an entity by giving it an output to kill itself with an optional delay
 *
 * @param	entity			Entity index
 * @param	delay			Time delay to add to the output
 * @noreturn
 */
stock void KillViaIO(int entity, float delay)
{
	char global_variant[32];
	Format(global_variant, sizeof(global_variant), "OnUser1 !self,Kill,,%.2f,1", delay);
	SetVariantString(global_variant);
	AcceptEntityInput(entity, "AddOutput");
	AcceptEntityInput(entity, "FireUser1");
}

/**
 * Get the distance between two entities
 *
 * @param	ent1		Entity 1
 * @param	ent2		Entity 2
 * @return	Distance in units
 */
stock float GetDistance(int ent1, int ent2)
{
	float pos1[3], pos2[3];

	(IsClient(ent1)) ? GetClientAbsOrigin(ent1, pos1) : GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos1);
	(IsClient(ent2)) ? GetClientAbsOrigin(ent2, pos2) : GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", pos2);

	return GetVectorDistance(pos1, pos2);
}

/**
 * Check if two entities are in line of sight of one another
 *
 * @param	ent1		Entity 1
 * @param	ent2		Entity 2
 * @param	flags		Contents flags used for solidity and visibility
 * @return	True if entities are within line of sight
 * @error	Invalid entity, client not in game, property not found or valid, etc.
 */
stock bool AreEntsInLOS(int ent1, int ent2, int flags = CONTENTS_SOLID)
{
	float pos1[3], pos2[3];

	(IsClient(ent1)) ? GetClientEyePosition(ent1, pos1) : GetEntPropVector(ent1, Prop_Data, "m_vecOrigin", pos1);
	(IsClient(ent2)) ? GetClientEyePosition(ent2, pos2) : GetEntPropVector(ent2, Prop_Data, "m_vecOrigin", pos2);

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
 * Get an entity's children
 * @param	entity		Entity index
 * @param	arr			ArrayList to put child entity indexes in
 * @return				Number of children found
 */
stock int GetEntityChildren(int entity, ArrayList arr)
{
    int count = 0;
    int child = GetEntPropEnt(entity, Prop_Data, "m_hMoveChild");
    while (IsValidEntity(child))
    {
        arr.Push(child);
        count++;
        child = GetEntPropEnt(child, Prop_Data, "m_hMovePeer");
    }
    return count;
}

/**
 * Get the parent of an entity
 * @return	Entity index of parent, or -1 if none found or entity not valid
 */
stock int GetEntityParent(int entity)
{
    return GetEntPropEnt(entity, Prop_Data, "m_pParent");
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
	{
		return false;
	}

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
		message.WriteString(buffer);

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
 * Sends a SayText2 User Message to all clients, which team-colours text when \x02 or \x03 are used in the string.
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
 * Maths
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Clamp an integer between two ranges
 * Min must be lower than max and vice versa
 *
 * @param	value		By-reference variable to clamp
 * @param	min			Minimum clamp boundary
 * @param	max			Maximum clamp boundary
 * @noreturn
 */
stock void ClampInt(int &value, int min, int max)
{
	if (value <= min)
	{
		value = min;
	}
	else if (value >= max)
	{
		value = max;
	}
}

/**
 * Clamp an integer to a minimum value
 *
 * @param	value		By-reference variable to clamp
 * @param	min			Minimum clamp boundary
 * @noreturn
 */
stock void ClampIntMin(int &value, int min)
{
	value = ((value < min) ? min : value);
}

/**
 * Clamp an integer to a maximum value
 *
 * @param	value		By-reference variable to clamp
 * @param	max			Maximum clamp boundary
 * @noreturn
 */
stock void ClampIntMax(int &value, int max)
{
	value = ((value > max) ? max : value);
}

/**
 * Clamp a float
 *
 * @param	value		By-reference variable to clamp
 * @param	min			Minimum clamp boundary
 * @param	max			Maximum clamp boundary
 * @noreturn
 */
stock void ClampFloat(float &value, float min, float max)
{
	if (value < min)
	{
		value = min;
	}
	else if (value > max)
	{
		value = max;
	}
}


/**
 * Coordinates
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Get the coordinates of the point in the world your crosshair is resting
 *
 * @param	client		Client index
 * @param	pos			Vector to store the coordinates in
 * @noreturn
 */
stock void GetClientAimPos(int client, float pos[3])
{
	float vEyePos[3], vEyeAngles[3];

	GetClientEyePosition(client, vEyePos);
	GetClientEyeAngles(client, vEyeAngles);

	Handle hTrace = TR_TraceRayFilterEx(vEyePos, vEyeAngles, MASK_PLAYERSOLID, RayType_Infinite, Trace_GetClientAimPos);

	if (TR_DidHit(hTrace))
	{
		TR_GetEndPosition(pos, hTrace);
	}

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
		{
			LogError("Failed to precache sound %s", asset);
		}

		if (StrContains(asset, ".mdl", false) != -1 && !PrecacheModel(asset, true))
		{
			LogError("Failed to precache model %s", asset);
		}
	}

	delete snapshot;
}
