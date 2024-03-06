
// ConVars
enum
{
	// Plugin Server Settings
	P_Enabled,
	P_AutoEnable,
	P_Debug,
	P_SCR,
	P_Description,

	// Player Interface
	P_ChatKillFeed,
	P_RoundStartMessage,
	P_ActivatorsMax,
	P_ActivatorRatio,
	P_LockActivator,
	P_BotActivatorOnLow,

	// Player Attributes
	P_RedSpeed,
	P_RedScoutSpeed,
	P_RedAirDash,
	P_RedMelee,
	P_BlueSpeed,
	P_BlueMelee,
	P_Buildings,
	P_RestrictItems,

	// Server ConVars
	S_Unbalance,
	S_AutoBalance,
	S_Scramble,
	S_Pushaway,
	S_Queue,
	S_FirstBlood,

	ConVars_Max
}

void
	ConVars_Init()
{
	// Plugin ConVars
	CreateConVar("dtk_version", PLUGIN_VERSION, _, FCVAR_NOTIFY);
	g_ConVars[P_Enabled]		   = CreateConVar("dtk_enabled", "0", "Enable Deathrun Toolkit", FCVAR_NOTIFY);
	g_ConVars[P_AutoEnable]		   = CreateConVar("dtk_auto_enable", "1", "Allow the plugin to enable and disable itself based on a map's prefix");
	g_ConVars[P_Debug]			   = CreateConVar("dtk_debug", "0", "Enable verbose plugin action log events in server console to aid debugging");
	g_ConVars[P_SCR]			   = CreateConVar("dtk_source_chat_relay", "1", "Use 'Source Chat Relay' to communicate game mode events to a Discord channel");
	g_ConVars[P_Description]	   = CreateConVar("dtk_game_description", "TF2 Deathrun", "Game description that appears in the server browser when the game mode is enabled. Leave blank to not change it at all. {plugin_name} and {plugin_version} will be filled in by the plugin");

	g_ConVars[P_ChatKillFeed]	   = CreateConVar("dtk_kill_feed", "1", "Tell clients which entity killed them in chat");
	g_ConVars[P_RoundStartMessage] = CreateConVar("dtk_round_start_message", "1", "Show round start messages in chat");
	g_ConVars[P_ActivatorsMax]	   = CreateConVar("dtk_activators_max", "1", "Maximum number of activators. -1 = no maximum. There will always be one player on each team");
	g_ConVars[P_ActivatorRatio]	   = CreateConVar("dtk_activator_ratio", "0.2", "Activator ratio. Decimal fraction of the number of participants who will be chosen as activators. e.g. 0.2 means one fifth of participants will become an activator");
	g_ConVars[P_LockActivator]	   = CreateConVar("dtk_lock_activator", "1", "Prevent activators from suiciding or switching teams. 1 = during round, 2 = also during pre-round");
	g_ConVars[P_BotActivatorOnLow] = CreateConVar("dtk_bot_activator_on_low", "1", "Make a bot the Activator on low players");

	// Player Attributes
	g_ConVars[P_RedSpeed]		   = CreateConVar("dtk_red_speed", "0", "Apply a flat run speed in u/s to all red players");
	g_ConVars[P_RedScoutSpeed]	   = CreateConVar("dtk_red_speed_scout", "0", "Adjust the run speed in u/s of red scouts");
	g_ConVars[P_BlueSpeed]		   = CreateConVar("dtk_blue_speed", "0", "Apply a flat run speed in u/s to all blue players");
	g_ConVars[P_RedAirDash]		   = CreateConVar("dtk_red_air_dash", "0", "Allow red scout air dash");
	g_ConVars[P_RedMelee]		   = CreateConVar("dtk_red_melee", "0", "Restrict red players to melee weapons");
	g_ConVars[P_BlueMelee]		   = CreateConVar("dtk_blue_melee", "0", "Restrict blue players to melee weapons");
	g_ConVars[P_Buildings]		   = CreateConVar("dtk_buildings", "12", "Restrict engineer buildings. Add up these values to make the ConVar value: Sentry = 1, Dispenser = 2, Tele Entrance = 4, Tele Exit = 8");
	g_ConVars[P_RestrictItems]	   = CreateConVar("dtk_restrictions", "1", "Item restrictions");

	// Server ConVars
	g_ConVars[S_Unbalance]		   = FindConVar("mp_teams_unbalance_limit");
	g_ConVars[S_AutoBalance]	   = FindConVar("mp_autoteambalance");
	g_ConVars[S_Scramble]		   = FindConVar("mp_scrambleteams_auto");
	g_ConVars[S_Pushaway]		   = FindConVar("tf_avoidteammates_pushaway");
	g_ConVars[S_Queue]			   = FindConVar("tf_arena_use_queue");
	g_ConVars[S_FirstBlood]		   = FindConVar("tf_arena_first_blood");

	// Cycle through and hook each ConVar
	for (int i = 0; i < ConVars_Max; i++) {
		if (g_ConVars[i] != null) {
			g_ConVars[i].AddChangeHook(ConVar_ChangeHook);
		}
	}
}

/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 * @param 		char	Formatting rules
 * @param 		...		Variable number of formatting arguments
 * @noreturn
 */
stock Debug(const char[] format, any...)
{
	if (!g_ConVars[P_Debug].BoolValue) {
		return;
	}

	char logfile[128], map[48], buffer[1024];
	GetCurrentMap(map, sizeof(map));

	if (!DirExists("addons/sourcemod/logs/dtk", true)) {
		CreateDirectory("addons/sourcemod/logs/dtk", 0775, true);
	}

	Format(logfile, sizeof(logfile), "addons/sourcemod/logs/dtk/%s.log", map);
	VFormat(buffer, sizeof(buffer), format, 2);
	LogToFile(logfile, "%s", buffer);
}