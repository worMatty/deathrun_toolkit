
/**
 * SourceMod Forwards
 * ----------------------------------------------------------------------------------------------------
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game_folder[32];
	
	GetGameFolderName(game_folder, sizeof(game_folder));
	
	if 		(StrEqual(game_folder, "tf"))				game.SetGame(Mod_TF);
	else if (StrEqual(game_folder, "open_fortress"))	game.SetGame(Mod_OF);
	else if (StrEqual(game_folder, "tf2classic"))		game.SetGame(Mod_TF2C);
	else	LogError("DTK is designed for TF2. Some things may not work!");
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	MarkNativeAsOptional("SCR_SendEvent");
	
	if (late) game.AddFlag(GF_LateLoad);
	
	return APLRes_Success;
}




/**
 * OnAllPluginsLoaded
 */
public void OnAllPluginsLoaded()
{
	// Check for the existence of libraries that DTK can use
	if (!(g_bSteamTools = LibraryExists("SteamTools")))
		LogMessage("Library not found: SteamTools. Unable to change server game description");
	
	if (!(g_bTF2Attributes = LibraryExists("tf2attributes")))
		LogMessage("Library not found: TF2 Attributes. Unable to modify weapon or player attributes");
		
	if (!(g_bSCR = LibraryExists("Source-Chat-Relay")))
		LogMessage("Library not found: Source Chat Relay. Unable to send event messages to Discord");
}

public void OnLibraryAdded(const char[] name)
{
	LibraryChanged(name, true);
}

public void OnLibraryRemoved(const char[] name)
{
	LibraryChanged(name, false);
}

void LibraryChanged(const char[] name, bool loaded)
{
	if (StrEqual(name, "Steam Tools"))			g_bSteamTools 		= loaded;
	if (StrEqual(name, "tf2attributes"))		g_bTF2Attributes 	= loaded;
	if (StrEqual(name, "Source-Chat-Relay"))	g_bSCR 				= loaded;
}





/**
 * OnPluginStart
 */
public void OnPluginStart()
{
	LoadTranslations("dtk.phrases");
	LoadTranslations("common.phrases");
	
	// Plugin ConVars
	g_ConVars[P_Version]			= CreateConVar("dtk_version", PLUGIN_VERSION);
	g_ConVars[P_Enabled]			= CreateConVar("dtk_enabled", "0", "Enable Deathrun Toolkit");
	g_ConVars[P_AutoEnable]			= CreateConVar("dtk_auto_enable", "1", "Allow the plugin to enable and disable itself based on a map's prefix");
	g_ConVars[P_Debug]				= CreateConVar("dtk_debug", "0", "Enable verbose plugin action log events in server console to aid debugging");
	g_ConVars[P_SCR]				= CreateConVar("dtk_source_chat_relay", "1", "Use 'Source Chat Relay' to communicate game mode events to a Discord channel");
	g_ConVars[P_MapInstructions]	= CreateConVar("dtk_map_instructions", "1", "Allow maps to alter player properties and weapons on demand for game play purposes");
	g_ConVars[P_Description]		= CreateConVar("dtk_game_description", "{plugin_name} | {plugin_version}", "Game description that appears in the server browser when the game mode is enabled. Leave blank to not change it at all. {plugin_name} and {plugin_version} will be filled in by the plugin");
	
	g_ConVars[P_ChatKillFeed]		= CreateConVar("dtk_kill_feed", "1", "Tell clients which entity killed them in chat");
	g_ConVars[P_RoundStartMessage]	= CreateConVar("dtk_round_start_message", "1", "Show round start messages in chat");
	g_ConVars[P_BossBar]			= CreateConVar("dtk_boss_bar", "1", "Allow activator and entity health to be displayed as a boss health bar");
	g_ConVars[P_ActivatorsMax]		= CreateConVar("dtk_activators_max", "1", "Maximum number of activators. -1 = no maximum. There will always be one player on each team");
	g_ConVars[P_ActivatorRatio]		= CreateConVar("dtk_activator_ratio", "0.2", "Activator ratio. Decimal fraction of the number of participants who will be chosen as activators. e.g. 0.2 means one fifth of participants will become an activator");
	g_ConVars[P_LockActivator]		= CreateConVar("dtk_lock_activator", "1", "Prevent activators from suiciding or switching teams. 1 = during round, 2 = also during pre-round");
		
	// Player Attributes
	g_ConVars[P_RedSpeed]			= CreateConVar("dtk_red_speed", "0", "Apply a flat run speed in u/s to all red players");
	g_ConVars[P_RedScoutSpeed]		= CreateConVar("dtk_red_speed_scout", "0", "Adjust the run speed in u/s of red scouts");
	g_ConVars[P_RedAirDash]			= CreateConVar("dtk_red_air_dash", "0", "Allow red scout air dash");
	g_ConVars[P_RedMelee]			= CreateConVar("dtk_red_melee", "0", "Restrict red players to melee weapons");
	g_ConVars[P_BlueSpeed]			= CreateConVar("dtk_blue_speed", "0", "Apply a flat run speed in u/s to all blue players");
	g_ConVars[P_Buildings]			= CreateConVar("dtk_buildings", "12", "Restrict engineer buildings. Add up these values to make the ConVar value: Sentry = 1, Dispenser = 2, Tele Entrance = 4, Tele Exit = 8");
	g_ConVars[P_Pushaway]			= CreateConVar("dtk_push_away", "0", "Players push away their team mates");
	
	// Server ConVars
	g_ConVars[S_Unbalance]			= FindConVar("mp_teams_unbalance_limit");
	g_ConVars[S_AutoBalance]		= FindConVar("mp_autoteambalance");
	g_ConVars[S_Scramble]			= FindConVar("mp_scrambleteams_auto");
	g_ConVars[S_Queue]				= FindConVar("tf_arena_use_queue");
	g_ConVars[S_WFPTime]			= FindConVar("mp_waitingforplayers_time");
	
	// Mod-specific ConVars
	if (game.IsGame(Mod_OF))
		g_ConVars[S_Pushaway]	 	= FindConVar("of_teamplay_collision");
	else
	{
		g_ConVars[S_FirstBlood]		= FindConVar("tf_arena_first_blood");	// Does not exist in OF
		g_ConVars[S_Pushaway] 		= FindConVar("tf_avoidteammates_pushaway");
	}
	
	// Work-in-Progress Features
	if (game.IsGame(Mod_TF))
		g_ConVars[P_BlueBoost]		= CreateConVar("dtk_wip_blue_boost", "0", "Allow activators to sprint using the +speed key bind");
	
	// Cycle through and hook each ConVar
	for (int i = 0; i < ConVars_Max; i++)
		if (g_ConVars[i] != null)
			g_ConVars[i].AddChangeHook(ConVar_ChangeHook);
	
	// Commands
	RegConsoleCmd("sm_drmenu", Command_Menu, "Open the deathrun menu");
	RegConsoleCmd("sm_dr", Command_Menu, "Open the deathrun menu");
	RegConsoleCmd("sm_drtoggle", Command_ToggleActivator, "Toggle activator preference");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Print your deathrun queue points to chat");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Print your deathrun queue points to chat");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points");
	RegConsoleCmd("sm_na", Command_NextActivators, "Show the next activator(s) in chat");
	RegConsoleCmd("sm_drhelp", Command_Help, "Open the help page");
	
	// Admin Commands
	RegAdminCmd("sm_setclass", AdminCommand_SetClass, ADMFLAG_SLAY, "Immediately change a player's class");
	RegAdminCmd("sm_setspeed", AdminCommand_SetSpeed, ADMFLAG_SLAY, "Immediately change a player's run speed. Work-in-progress, may not function");
	RegAdminCmd("sm_draward", AdminCommand_AwardPoints, ADMFLAG_SLAY, "Grant a player a quantity of queue points");
	RegAdminCmd("sm_drresetdatabase", AdminCommand_ResetDatabase, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Drop the DTK database table");
	RegAdminCmd("sm_drresetuser", AdminCommand_ResetUser, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Deletes a player's data from the DTK database table. They will be treated as a new player");
	
	// Debug Commands
	RegAdminCmd("sm_drdata", AdminCommand_PlayerData, ADMFLAG_SLAY, "Print internal data about client flags to your console, for debugging");
	
	// Build Sound List
	g_hSounds = BuildSoundList();
	
	// Load Restriction System Configs
	LoadKVFiles();
	
	// Construct Activator ArrayList
	g_Activators 	= new ArrayList(AL_Max);
	g_NPCs 			= new ArrayList(AL_Max);
	
	// Announce Plugin Load
	PrintToServer("%s %s has loaded", PLUGIN_NAME, PLUGIN_VERSION);
}




/**
 * OnMapStart
 *
 * Also Called on Late Load
 */
public void OnMapStart()
{
	// Database Maintenance
	DBCreateTable();	// Create table and connection
	DBPrune();			// Prune old records
	
	// Round State Reset
	game.RoundState = Round_Waiting;
	
	// Late Loading
	if (game.HasFlag(GF_LateLoad))
	{
		// Initialise Player Data Array
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame)
			{
				OnClientAuthorized(i, "");
				OnClientPutInServer(i);
				
				/*
				Player(i).CheckArray();
				
				// Hook Player Damage Received
				if (GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available)
					SDKHook(i, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
				*/
			}
		}
		
		game.RemoveFlag(GF_LateLoad);
	}
}




/**
 * OnConfigsExecuted
 *
 * Execute config_deathrun.cfg when all other configs have loaded.
 */
public void OnConfigsExecuted()
{
	// Detect deathrun maps
	if (g_ConVars[P_AutoEnable].BoolValue)
	{
		char mapname[32];
		GetCurrentMap(mapname, sizeof(mapname));
		
		if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
			g_ConVars[P_Enabled].SetBool(true);
	}
	
	if (g_ConVars[P_Enabled].BoolValue)
	{
		PrecacheAssets(g_hSounds);
		ServerCommand("exec config_deathrun.cfg");		// TODO Does this happen when reloading the plugin?
	}
}




/**
 * OnMapEnd
 */
public void OnMapEnd()
{
	delete g_db;
	
	if (g_ConVars[P_Enabled].BoolValue)
		g_ConVars[P_Enabled].SetBool(false);
}




/**
 * OnPluginEnd
 */
public void OnPluginEnd()
{
	// Save Player Data
	if (g_db != null)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && !Player(i).IsBot)
				Player(i).SaveData();
		}
	}
	
	g_ConVars[P_Enabled].SetBool(false);
}




/**
 * OnClientAuthorized
 */
public void OnClientAuthorized(int client, const char[] auth)
{
	Player(client).CheckPlayer();
}




/**
 * OnClientPutInServer
 */
public void OnClientPutInServer(int client)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Hook Player Damage Received
	if (GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available)
		SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
}




/**
 * OnClientDisconnect
 */
public void OnClientDisconnect(int client)
{
	// Save Player Data
	if (g_db != null && !Player(client).IsBot)
		Player(client).SaveData();

	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Hide Health Bar if Client Was Boss
	/*
	if (game.IsBossBarActive && client == g_iBoss)
	{
		g_iBoss = -1;
		SetHealthBar();
	}
	*/
}




/**
 * OnPlayerRunCmdPost
 */
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;
	
	// Modulate player speeds
	//ModulateSpeed(client);
	
	// Monitor and apply activator boosts
	ActivatorBoost(client, buttons, tickcount);
}





/**
 * Library Forwards
 * ----------------------------------------------------------------------------------------------------
 */

 /**
 * SteamTools Steam_FullyLoaded
 *
 * Called when SteamTools connects to Steam.
 * This forward is used to set the game description after a server restart.
 */
public int Steam_FullyLoaded()
{
	if (g_ConVars[P_Enabled].BoolValue)
		GameDescription(true);
}