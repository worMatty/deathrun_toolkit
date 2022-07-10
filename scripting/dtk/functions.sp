
/**
 * Entity Work
 * ----------------------------------------------------------------------------------------------------
 */

void LoadConfigs()
{
	g_kvRestrictions = new KeyValues("restrictions");
	g_kvReplacements = new KeyValues("replacements");
	
	if (!g_kvRestrictions.ImportFromFile(WEAPON_RESTRICTIONS_CFG))
	{
		LogError("Failed to load weapon restriction config \"%s\"", WEAPON_RESTRICTIONS_CFG);
	}
		
	if (!g_kvReplacements.ImportFromFile(WEAPON_REPLACEMENTS_CFG))
	{
		LogError("Failed to load weapon replacement config \"%s\"", WEAPON_REPLACEMENTS_CFG);
	}
}




StringMap BuildSoundList()
{
	StringMap hSounds = new StringMap();
	hSounds.SetString("chat_warning",	"common/warning.wav");
	hSounds.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "misc/talk.wav");
		// TF2: sound/ui/chat_display_text.wav  HL2: ui/buttonclickrelease.wav
	
	return hSounds;
}




/**
 * Player Preferences
 * ----------------------------------------------------------------------------------------------------
 */
 
// Toggle English language
void ToggleEnglish(int client)
{	
	if (Player(client).HasFlag(PF_PrefEnglish))
	{
		Player(client).RemoveFlag(PF_PrefEnglish);
		char language[32];
		
		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
			{
				TF2_PrintToChat(client, _, "When you next connect, your client language will be used");
				EmitMessageSoundToClient(client);
			}
			else
			{
				SetClientLanguage(client, iLanguage);
				TF2_PrintToChat(client, _, "\x01Your client language of \x05%s\x01 will now be used", language);
				EmitMessageSoundToClient(client);
			}
		}
	}
	else
	{
		Player(client).AddFlag(PF_PrefEnglish);
		TF2_PrintToChat(client, _, "\x01Your language has been set to \x05English");
		EmitMessageSoundToClient(client);
		SetClientLanguage(client, 0);
	}
}








/**
 * Player Properties
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Apply the necessary attributes to a player after they spawn.
 * 
 * @noreturn
 */
void ApplyPlayerAttributes(int client)
{
	if (!DRGame.IsGame(Mod_TF))
		return;

	Player player = Player(client);

	// Reset player attributes TODO Probably best practice to do this separately
	RemoveAllAttributes(client);
	
	// Blue Speed
	if (player.Team == Team_Blue)
		if (g_ConVars[P_BlueSpeed].FloatValue != 0.0)
			player.SetSpeed(g_ConVars[P_BlueSpeed].IntValue);

	// Red
	if (player.Team == Team_Red)
	{
		// Red Speed
		if (g_ConVars[P_RedSpeed].FloatValue != 0.0)
			player.SetSpeed(g_ConVars[P_RedSpeed].IntValue);
		
		// Red Scout Speed
		else if (g_ConVars[P_RedScoutSpeed].FloatValue != 0.0 && player.Class == Class_Scout)
			player.SetSpeed(g_ConVars[P_RedScoutSpeed].IntValue);
		
		// Double Jump
		if (!g_ConVars[P_RedAirDash].BoolValue && player.Class == Class_Scout)
			AddAttribute(client, "no double jump", 1.0);
		
		// Spy Cloak
		if (player.Class == Class_Spy)
		{
			AddAttribute(client, "mult cloak meter consume rate", 8.0);
			AddAttribute(client, "mult cloak meter regen rate", 0.25);
		}

		// Demo Charging
		if (player.Class == Class_DemoMan)
		{
			switch (g_ConVars[P_EnhancedMobility].IntValue)
			{
				case 0:
				{
					AddAttribute(client, "charge time decreased", -1000.0);
					AddAttribute(client, "charge recharge rate increased", 0.0);
				}
				case 1:
				{
					AddAttribute(client, "charge time decreased", -0.95);
					AddAttribute(client, "charge recharge rate increased", 0.2);
				}
			}
		}
	}
}



/**
 * Remove a player's weapon and replace it with a new one.
 * 
 * @param		int		Client index
 * @param		int		Current weapon
 * @param		int		New weapon item definition index
 * @param		char	New weapon classname
 * @return		int		Entity index of new weapon. -1 if failed to create
 */
int ReplaceWeapon(int client, int oldweapon, int itemDefIndex, char[] classname)
{
	int weapon = CreateWeapon(itemDefIndex, classname);
	
	if (weapon != -1)
	{
		RemoveEntity(oldweapon);
		GiveWeapon(client, weapon);
	}
	else
	{
		LogError("Failed to create a new weapon for %N", client);
	}
	
	return weapon;
}




/**
 * Create a new weapon
 * 
 * @param		int		New weapon item definition index
 * @param		char	New weapon classname
 * @return		int		New weapon entity index
 */
int CreateWeapon(int itemDefIndex, char[] classname)
{
	int weapon = CreateEntityByName(classname);
	
	if (weapon != -1)
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		
		if (!DispatchSpawn(weapon))
		{
			RemoveEntity(weapon);
			weapon = -1;
		}
	}
	
	return weapon;
}




/**
 * Equip a player with a weapon and assign them as owner
 * 
 * @param		int		Client index
 * @param		int		Weapon entity index
 * @noreturn
 */
void GiveWeapon(int client, int weapon)
{
	SetEntProp(weapon, Prop_Send, "m_hOwnerEntity", client);
	EquipPlayerWeapon(client, weapon);
}




/*
void ModulateSpeed(int client)
{
	if (GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != g_flSpeeds[client][Speed_Last] && g_flSpeeds[client][Speed_Desired])
	{
		// Calculate how much to multiply player's max speed by
		float modifier = g_flSpeeds[client][Speed_Desired] / Player(client).ClassRunSpeed;
		
		// Calculate new max speed property
		float newmaxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") * modifier;
		
		// Set new max speed property
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", newmaxspeed);
		
		// Save new max speed for comparison
		g_flSpeeds[client][Speed_Last] = newmaxspeed;
		
		// Resetting player speed to class speed
		if (g_flSpeeds[client][Speed_Desired] == Player(client).ClassRunSpeed)
			g_flSpeeds[client][Speed_Desired] = 0.0;
		
		//PrintCenterText(client, "g_flSpeeds[client][Speed_Last] == %f\ng_flSpeeds[client][Speed_Desired] == %f\nm_flMaxspeed == %f\nm_flSpeed == %f", g_flSpeeds[client][Speed_Last], g_flSpeeds[client][Speed_Desired], GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"), GetEntPropFloat(client, Prop_Data, "m_flSpeed"));
	}
}
*/













/**
 * Communication
 * ----------------------------------------------------------------------------------------------------
 */




/**
 * Messages
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Emit the message sound to a client
 *
 * @param	client	Recipient client index
 * @error	Invalid client index
 */
stock void EmitMessageSoundToClient (int client)
{
	char effect[256];
	g_hSounds.GetString("chat_reply", effect, sizeof(effect));
	
	if (effect[0] && client)
	{
		EmitSoundToClient(client, effect);
	}
}


/**
 * Emit the message sound to all clients
 */
stock void EmitMessageSoundToAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitMessageSoundToClient(i);
		}
	}
}




/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 *
 * @param 		char	Formatting rules
 * @param 		...		Variable number of formatting arguments
 * @noreturn
 */
stock void Debug(const char[] format, any...)
{
	if (!g_ConVars[P_Debug].BoolValue)
		return;
	
	char logfile[128], map[48], buffer[1024];
	GetCurrentMap(map, sizeof(map));
	
	if (!DirExists("addons/sourcemod/logs/dtk", true))
	{
		CreateDirectory("addons/sourcemod/logs/dtk", 0775, true);
	}
	
	Format(logfile, sizeof(logfile), "addons/sourcemod/logs/dtk/%s.log", map);
	
	VFormat(buffer, sizeof(buffer), format, 2);
	LogToFile(logfile, "%s", buffer);
}





stock void FormatChatColours(char[] string, int len)
{
	char replacement[32];
	
	Format(replacement, 32, "%t", "{default}");
	ReplaceString(string, len, "{default}", replacement);
	
	Format(replacement, 32, "%t", "{highlight}");
	ReplaceString(string, len, "{highlight}", replacement);
	
	Format(replacement, 32, "%t", "{killing_entity}");
	ReplaceString(string, len, "{killing_entity}", replacement);
}




/**
 * Server Environment
 * ----------------------------------------------------------------------------------------------------
 */

void GameDescription(bool enabled)
{
	if (!g_bSteamTools)
		return;

	char description[256];
	g_ConVars[P_Description].GetString(description, sizeof(description));
	
	if (description[0] == '\0')
		return;
	
	if (!enabled) // Plugin not enabled
	{
		// TODO Replace this with an OnMapStart string storage, as no mod should be changing the description at this point
		// and if it is then it must be a global thing so is desired
		if 			(DRGame.IsGame(Mod_TF))		Format(description, sizeof(description), "Team Fortress");
		else if 	(DRGame.IsGame(Mod_OF))		Format(description, sizeof(description), "Open Fortress");
		else if 	(DRGame.IsGame(Mod_TF2C))	Format(description, sizeof(description), "Team Fortress 2 Classic");
		else 									Format(description, sizeof(description), DEFAULT_GAME_DESC);
	}
	else
	{
		ReplaceString(description, sizeof(description), "{plugin_name}", PLUGIN_SHORTNAME, false);
		ReplaceString(description, sizeof(description), "{plugin_version}", PLUGIN_VERSION, false);
	}
	
	Steam_SetGameDescription(description);
	ShowActivity(0, "Set game description to \"%s\"", description);
}




/**
 * Database
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Connect to the database and create the table if it doesn't exist
 *
 * @noreturn
 */
stock void DBCreateTable()
{
	char error[255];
	
	if ((g_db = SQLite_UseDatabase(SQLITE_DATABASE, error, sizeof(error))) == null)
	{
		LogError("Unable to connect to SQLite database %s: %s", SQLITE_DATABASE, error);
	}
	else
	{
		char query[255];
		
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (steamid INTEGER PRIMARY KEY, \
		points INTEGER, flags INTEGER, last_seen INTEGER DEFAULT 0)", SQLITE_TABLE);
		
		if (!SQL_FastQuery(g_db, query))
		{
			SQL_GetError(g_db, error, sizeof(error));
			LogError("Unable to create database table %s: %s", SQLITE_TABLE, error);
		}
	}
}




/**
 * Get rid of database records older than one month.
 *
 * @noreturn
 */
stock void DBPrune()
{
	// Remove entries older than a month, or 2629743 seconds
	if (g_db != null)
	{
		char query[255];
		Format(query, sizeof(query), "DELETE FROM %s WHERE last_seen <= %d", SQLITE_TABLE, GetTime() - 2629743);
		
		DBResultSet resultset = SQL_Query(g_db, query);
		if (resultset.AffectedRows > 0)
			LogMessage("Deleted %d expired records from the database", resultset.AffectedRows);
		CloseHandle(resultset);
	}
}




/**
 * Delete the DTK table from the database.
 *
 * @noreturn
 */
stock void DBReset(int client)
{
	char query[255];
	Format(query, sizeof(query), "DROP TABLE %s", SQLITE_TABLE);
	if (SQL_FastQuery(g_db, query))
	{
		ShowActivity(client, "Reset player database. Changing the map will reinitialise it");
		LogMessage("%L reset the database using the admin command", client);
	}
	else
	{
		char error[255];
		SQL_GetError(g_db, error, sizeof(query));
		ShowActivity(client, "Failed to reset database: %s", error);
		LogError("%L failed to reset the database. Error: %s", client, error);
	}
}



