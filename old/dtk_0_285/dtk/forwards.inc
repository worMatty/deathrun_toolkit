/**
 * SourceMod Forwards
 * ----------------------------------------------------------------------------------------------------
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game_folder[32];
	
	GetGameFolderName(game_folder, sizeof(game_folder));
	
	if (StrEqual(game_folder, "tf"))
	{
		g_iGame |= FLAG_TF;
	}
	else if (StrEqual(game_folder, "open_fortress"))
	{
		g_iGame |= FLAG_OF;
	}
	else if (StrEqual(game_folder, "tf2classic"))
	{
		g_iGame |= FLAG_TF2C;
	}
	else
	{
		LogError("DTK is designed for TF2. Some things may not work!");
	}
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	MarkNativeAsOptional("SCR_SendEvent");
	
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
		LogMessage("Library not found: TF2 Attributes. Unable to modify weapon attributes");
		
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
	if (StrEqual(name, "Steam Tools"))
	{	
		g_bSteamTools = loaded;
	}
	if (StrEqual(name, "tf2attributes"))
	{
		g_bTF2Attributes = loaded;
	}
	if (StrEqual(name, "Source-Chat-Relay"))
	{
		g_bSCR = loaded;
	}
}





/**
 * OnPluginStart
 */
public void OnPluginStart()
{
	LoadTranslations("dtk-base.phrases");
	LoadTranslations("common.phrases");		// Used by targeting systems
	
	// Server ConVars
	g_cTeamsUnbalanceLimit 	= FindConVar("mp_teams_unbalance_limit"); 	// 1 (0-30) - Teams are unbalanced when one team has this many more players than the other team. (0 disables check)
	g_cAutoBalance 			= FindConVar("mp_autoteambalance"); 		// 1 (0-2) - Automatically balance the teams based on mp_teams_unbalance_limit. 0 = off, 1 = forcibly switch, 2 = ask volunteers
	g_cScramble 			= FindConVar("mp_scrambleteams_auto"); 		// 1 - Server will automatically scramble the teams if criteria met.  Only works on dedicated servers.
	g_cArenaQueue 			= FindConVar("tf_arena_use_queue"); 		// 1 - Enables the spectator queue system for Arena.
	g_cArenaFirstBlood 		= FindConVar("tf_arena_first_blood"); 		// 1 - Rewards the first player to get a kill each round.
	g_cRoundWaitTime 		= FindConVar("mp_enableroundwaittime"); 	// 1 - The time at the beginning of the round, while players are frozen.
	//g_cHumansMustJoinTeam 	= FindConVar("mp_humans_must_join_team");	// Forces players to join the specified team. Default is 'any'.
	
	if (g_iGame & FLAG_OF) g_cServerTeamMatePush = FindConVar("of_teamplay_collision");		// Optionally enabled when there are a specific number of runners remaining
	else g_cServerTeamMatePush = FindConVar("tf_avoidteammates_pushaway");	// Team mate collision ConVars...
	
	// Register console variables
	CreateConVar("dtk_version", PLUGIN_VERSION);
	g_cDebugMessages 		= CreateConVar("dtk_debug", "0", _, FCVAR_HIDDEN);
	g_cAutoEnable			= CreateConVar("dtk_autoenable", "1", "Automatically enable the plugin when a deathrun map is detected.", _, true, 0.0, true, 1.0);
	g_cEnabled				= CreateConVar("dtk_enabled", "0", "Enable the plugin's features.", _, true, 0.0, true, 1.0);
	g_cPreventBlueEscape 	= CreateConVar("dtk_preventblueescape", "1", "Prevent the blue player from escaping their role during a round by suicide or switching team.", _, true, 0.0, true, 1.0);
	g_cRedSpeed 			= CreateConVar("dtk_redspeed", "0", "Set the speed red players should run in units per second. 0 is off.", _, true, 0.0, true, 750.0);
	g_cRedScoutSpeed 		= CreateConVar("dtk_redscoutspeed", "320", "Cap red Scout speed to this value. Ignored if dtk_redspeed is set. 0 is off.", _, true, 0.0, true, 750.0);
	g_cBlueSpeed 			= CreateConVar("dtk_bluespeed", "420", "Set blue run speed in units per second. 0 is off.", _, true, 0.0, true, 750.0);
	g_cRedScoutDoubleJump 	= CreateConVar("dtk_redscoutdoublejump", "0", "Allow red scouts to double jump. 0 = NO. 1 = YES.", _, true, 0.0, true, 1.0);
	g_cActivators 			= CreateConVar("dtk_activators", "1", "Number of activators (players on blue team). Setting to 0 will cause continual round resets on maps with a tf_logic_arena.", FCVAR_HIDDEN, true, 0.0, true, 15.0);
	g_cTeamMatePush 		= CreateConVar("dtk_teampush", "0", "Team mate pushing", _, true, 0.0, true, 1.0);
	g_cRedDemoChargeLimits 	= CreateConVar("dtk_reddemocharge", "2", "Place limits on red demo charges. 0 = No charging. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cRedSpyCloakLimits 	= CreateConVar("dtk_redspycloak", "2", "Place limits on red spy cloaking. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cUsePointsSystem 		= CreateConVar("dtk_usepoints", "1", "Use the new points system for activator selection.", FCVAR_HIDDEN, true, 0.0, true, 1.0);
	g_cTeamPushOnRemaining 	= CreateConVar("dtk_teampush_remaining", "3", "Number of players remaining on Red to activate team pushing. 0 = off.", _, true, 0.0, true, 30.0);
	g_cRedMeleeOnly 		= CreateConVar("dtk_redmeleeonly", "0", "Restrict red players to melee weapons.", _, true, 0.0, true, 1.0);
	g_cChatKillFeed 		= CreateConVar("dtk_chatkillfeed", "1", "Show clients the classname and targetname of the entity that killed them.", _, true, 0.0, true, 1.0);
	g_cUseSQL 				= CreateConVar("dtk_usesql", "1", "Use SQLite for player points and prefs.", _, true, 0.0, true, 1.0);
	g_cBlastPushing 		= CreateConVar("dtk_blastpushing", "2", "Control blast force pushing. 0 = off, 1 = unregulated, 2 = reduced", _, true, 0.0, true, 2.0);
	g_cBuildings 			= CreateConVar("dtk_buildings", "12", "Restrict engineer buildings. Add up these values to make the convar value: Sentry = 1, Dispenser = 2, Tele Entrance = 4, Tele Exit = 8", _, true, 0.0, false, 15.0);
	g_cAllowEurekaEffect 	= CreateConVar("dtk_allow_eurekaeffect", "0", "Allow the Eureka effect. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cShowRoundStartMessage = CreateConVar("dtk_roundstartmessages", "1", "Show the round start messages. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cUseActivatorHealthBar = CreateConVar("dtk_activatorhealthbar", "1", "Use a boss health bar for the activator's health when they are damaged by an enemy. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cThermalThruster		= CreateConVar("dtk_thermalthruster", "2", "Thermal thruster charge rate. 0 = No charges, 1 = Normal charge behaviour, 2 = Charges take one minute to recharge, 3 = Two charges with no recharging", _, true, 0.0, true, 3.0);
	g_cSCR 					= CreateConVar("dtk_scr", "0", "Use Source Chat Relay to send event messages to your Discord server", _, true, 0.0, true, 1.0);
	g_cMapInstructions		= CreateConVar("dtk_map_instructions", "1", "Allow the map to change player properties such as class, speed and weapons", _, true, 0.0, true, 1.0);
	
	// Hook our convar changes
	g_cAutoEnable.AddChangeHook(ConVarChangeHook);
	g_cEnabled.AddChangeHook(ConVarChangeHook);
	g_cPreventBlueEscape.AddChangeHook(ConVarChangeHook);
	g_cRedSpeed.AddChangeHook(ConVarChangeHook);
	g_cRedScoutSpeed.AddChangeHook(ConVarChangeHook);
	g_cBlueSpeed.AddChangeHook(ConVarChangeHook);
	g_cRedScoutDoubleJump.AddChangeHook(ConVarChangeHook);
	g_cActivators.AddChangeHook(ConVarChangeHook);
	g_cTeamMatePush.AddChangeHook(ConVarChangeHook);
	g_cRedDemoChargeLimits.AddChangeHook(ConVarChangeHook);
	g_cRedSpyCloakLimits.AddChangeHook(ConVarChangeHook);
	g_cUsePointsSystem.AddChangeHook(ConVarChangeHook);
	g_cTeamPushOnRemaining.AddChangeHook(ConVarChangeHook);
	g_cRedMeleeOnly.AddChangeHook(ConVarChangeHook);
	g_cChatKillFeed.AddChangeHook(ConVarChangeHook);
	g_cUseSQL.AddChangeHook(ConVarChangeHook);
	g_cBlastPushing.AddChangeHook(ConVarChangeHook);
	g_cBuildings.AddChangeHook(ConVarChangeHook);
	g_cAllowEurekaEffect.AddChangeHook(ConVarChangeHook);
	g_cShowRoundStartMessage.AddChangeHook(ConVarChangeHook);
	g_cUseActivatorHealthBar.AddChangeHook(ConVarChangeHook);
	g_cThermalThruster.AddChangeHook(ConVarChangeHook);
	g_cSCR.AddChangeHook(ConVarChangeHook);
	g_cMapInstructions.AddChangeHook(ConVarChangeHook);
	
	// Add some console commands
	RegConsoleCmd("sm_drmenu", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_dr", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_drtoggle", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegConsoleCmd("sm_prefs", Command_Preferences, "A shortcut command for setting your deathrun activator and points preference.");
	RegAdminCmd("sm_setclass", AdminCommand_SetClass, ADMFLAG_SLAY, "Change a player's class using DTK's built in functions, which also apply the correct attributes");
	RegAdminCmd("sm_drdata", AdminCommand_PlayerData, ADMFLAG_SLAY, "Print to console the values in the prefs and points arrays.");
	RegAdminCmd("sm_draward", AdminCommand_AwardPoints, ADMFLAG_SLAY, "Award a poor person some deathrun queue points.");
	RegAdminCmd("sm_drresetdatabase", AdminCommand_ResetDatabase, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Reset the deathrun player database.");
	RegAdminCmd("sm_drresetuser", AdminCommand_ResetUser, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Deletes a player's data from the deathrun database table. They will be treated as a new player.");
	
	g_hHealthText = CreateHudSynchronizer();	// TODO Move to function
	
	// Build Sound List
	g_hSound = SoundList();
	
	LogMessage("%s %s has loaded", PLUGIN_NAME, PLUGIN_VERSION);
	PrintToChatAll("%t %s has loaded", "prefix_strong", PLUGIN_SHORTNAME);
}




/**
 * OnPluginEnd
 */
public void OnPluginEnd()
{
	// Upload user data if plugin is unloaded
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		player.OnDisconnect();
	}
	
	PrintToChatAll("%t %s has been unloaded", "prefix_strong", PLUGIN_SHORTNAME);

	if (g_cEnabled.BoolValue) g_cEnabled.BoolValue = false;
	
	LogMessage("Plugin has been unloaded");
}





/**
 * OnMapStart
 *
 * Also Called on Late Load
 */
public void OnMapStart()
{
	// Always run
	game.CreateDBTable();	// Create database table and open a connection
	game.PruneDB();			// Prune old table entries
	g_bHookSingleEntityOutput = (GetFeatureStatus(FeatureType_Capability, "HookSingleEntityOutput") == FeatureStatus_Available);
	
	// Populate player array if plugin is loaded late and hook their damage
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		if (player.IsConnected)
		{
			player.Initialize();
			player.HookDamage();
		}
	}
	
	if (g_cAutoEnable.BoolValue)
	{
		char mapname[32];
		GetCurrentMap(mapname, sizeof(mapname));
		
		if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
		{
			LogMessage("Detected a deathrun map");
			g_cEnabled.SetBool(true);
			//if (g_bSteamTools) SetServerGameDescription();
		}
		else
		{
			LogMessage("Not a deathrun map. Deathrun functions will not be available");
			//if (g_bSteamTools) SetServerGameDescription();
		}
	}
}




/**
 * OnMapEnd
 */
public void OnMapEnd()
{
	// Always run
	delete g_db;
	
	if (g_cEnabled.BoolValue)
	{
		g_cEnabled.SetBool(false);
		LogMessage("The map has come to an end. Restoring some cvars to their default values");
	}
}




/**
 * OnConfigsExecuted
 *
 * Execute config_deathrun.cfg when all other configs have loaded.
 */
public void OnConfigsExecuted()
{
	if (g_cEnabled.BoolValue)
	{
		ServerCommand("exec config_deathrun.cfg");
	}
}




/**
 * OnClientAuthorized
 */
public void OnClientAuthorized(int client, const char[] auth)
{
	Player player = new Player(client);
	player.Initialize();
		// Retrive stored data or set up a new record. Give player default session flags
}




/**
 * OnClientPutInServer
 */
public void OnClientPutInServer(int client)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	Player player = new Player(client);
	player.HookDamage();
}




/**
 * OnClientDisconnect
 */
public void OnClientDisconnect(int client)
{
	// Always run
	Player player = new Player(client);
	player.OnDisconnect();

	if (!g_cEnabled.BoolValue)
		return;
	
	// Boss health bar
	if (g_bHealthBarActive == true && client == g_iHealthBarTarget)
	{
		g_iHealthBarTarget = -1;
		SetHealthBar();
	}
}




/**
 * TF2_OnWaitingForPlayersEnd
 *
 * NOT called in Arena, probably because it doesn't seem to use WFP time.
 * OF does use this however.
 */
public void TF2_OnWaitingForPlayersEnd()
{
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("%s Waiting for players time has ended", PREFIX_SERVER);
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
	if (g_cEnabled.BoolValue) SetServerGameDescription();
}