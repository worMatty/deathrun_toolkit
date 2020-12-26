#pragma semicolon 1
#pragma newdecls required

#define DEBUG
#define PLUGIN_NAME "[DTK] Deathrun Toolkit Base"
#define PLUGIN_VERSION "0.28"

#include <dtk>

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "Basic functions for the deathrun game mode.",
	version = PLUGIN_VERSION,
	url = ""
};

/*
	VERSION 0.3 PLANS
	=================
	
	External points plugin.
		Has natives for setting and retrieving points.
		Natives return correc values on success or -1 on failure.
		Natives print SQL errors to log.
	
	Uses points system exclusively.
		Fall back to a token system built into player flags.
	
	Remove multiple activator support.
	
	Don't rely on the 'choose team' cvar to prevent people joining blue.
		Monitor for team changes.
		If not activator, move to red.
	
	
*/

/*

	TO DO
	=====
	
	
	Backend
	-------
	
	'Enabled' convar & change hook
	Late load
	Dependencies
		Check for SteamTools or SteamWorks, TF2 Attributes and TF2 Items. Log each missing component. Spew to admins in chat.
	Help system
	Admin menu
	Next Activator(s) command
	Revised activator selection
		Points only
		Token-based system for fall back
	Health bar control using if statement and conditions.
	Better way of applying and removing attributes.
	Better session flag storage and resetting which works while on non-DR maps.
	Find out what happens when a net cafe joins a server. What ID.
	What is the significance of a LAN ID?
	
	
	Attributes
	----------
	
	Dead Ringer?
		Consider penalising the player for its use.
	
	
	Abilities
	---------
	
	Blast jumping.
	Rocket pack.
	Sticky counting and jumping.
	Investigate force application.
	Perhaps an existing plugin for sticky jumping.
	Self heal
	Speed boost bind for activator.
	
	
	Weapons
	-------
	
	Eureka Moment
	Health items
	Mediguns
	Force-a-Nature
	Winger
	
	
	Anti Exploit
	------------
	
	Cleaver(s)
	
	
	Map Control
	-----------
	
	Entities
		logic_case, boss health
	Class
	Weapons allowed
	Weapons restricted
	Weapon slot switch
	Melee-only
	Glow (not anymore)
	Blue puppet bot
	Ammo game
	Health game
	Engi builds
	Health scale
	
	
	Mapper Enhancements
	-------------------
	
	Checkpoints
		Reward bonus points
		Stat tracking
	Event Sound Broadcasts
		Last one alive
		One player alive
		Three players left
		Two players left
		One player left
		You died
		Someone died (with time delay)
		Someone died (without time delay)
	Stat tracking
		Mini games chosen
		Mini game team wins
		Number of players who spawned
		Number of players who got to the second half
		Number of players who got to the end
		Red wins (ignoring false rounds)
		Blue wins (ignoring false rounds)
		Average round length (ignoring false rounds)
		Entity targetname deaths
	
	
	Personal Preferences
	--------------------
	
	
	
	
	
	Player group preferences
	------------------------
	
	Blue puppet bot
	
	
	Player experience
	-----------------
	
	Shorter round start messages.
	
	
	Admin
	-----
	
	Forced no activator
		Use target or Steam ID
	Set player flags
		Use target or Steam ID (check if player is on server and change array values)
	
	
	Logging
	-------
	
	Discord relay events
		Activator chosen
		Activator killed themselves
	Always in server console
		Activator chosen
		Round reset
		Round start
		Round end
		Player joined (Steam ID)
		Player left (Steam ID)
	Debugging
		All current team swapping and checking
		Database activity
		Player changing preferences
	

	12. Handle waiting for players time.
	
	16. Display attribute messages once during freeze time after a delay as long as the attributes are still there.
		(team mover)

	23. See about making my own events.
	
	34. Research whether convars are best used when checking values during functions and if using one convar handle for multiple
		convars is better than creating one handle per convar.
		
	41. Make a list of all 50/50 entities in a map and let people vote on whether to enable them.
	
	45. Respawning stuff for no tf_logic_arena.
	
	49. Show current preference in menu.
	
	50. Plugin information menu option that leads to a group post.
	
	52. Alternative phrases for points consumption.
	
	The plugin may not set up new player default preferences properly when it's running and the map changes to a non-DR map.
	
	Disguising as a friendly player makes that player receive kill feed notices in chat.

*/


/*

	Bugs:
	-----
	
	Need to prevent people joining blue team. Cvar alone may not be enough. Not robust enough and confusing.
	
		Server event "player_team", Tick 125905:
		- "userid" = "52"
		- "team" = "2"
		- "oldteam" = "0"
		- "disconnect" = "0"
		- "autoteam" = "1"
		- "silent" = "0"
		- "name" = "ÔøÉ worMatty"
	
	I somehow broke Arena mode when joining blue when there was already an activator. When the red bot died it didn't end the round.
	
	Found a bug with DTK. If you join a team but don't choose a class, you will still be team swapped.
	I was put on blue as the activator and had yet to choose a team, but was only able to spec from the Buzz train on PlayStation
	and when I tried to choose a class and spawn after the round had started, the game told me I couldn't change class after the round had started.
	
	If the plugin is loaded during a game, when players are already on the server, their preferences are apparently not recorded properly.
	
	Blast pushing cvar setting doesn't match with actual function.
	
	When arriving on the server, if waiting for players time has finished, everyone is forced onto red and a round start event is never called.
		Fixed?
	
		
	Observations:
	-------------
	
	player_initial_spawn fires when the players first joins and lands on the MOTD. Seems to happen once per map/connection.
	player_spawn and player_activate happen at the same time as this.
	
	Setting activators to 2 and then slaying myself while on blue crashed the server.
	
	If on a server alone and you spawn into a team then go to spec, the 'waiting' message is shown three times.
	
	Activator can kill themselves with stickies.
	
	If for some reason SteamTools isn't running, the plugin will not load.
	
	'Next activators' shows people in spec.
	
	'Next activators' should show correct order if turn-based system is being used.
	
	A bug that seems to have been introduced while scripting the database stuff is you can be selected as activator even if your preference is not to.
	
	A 5144 byte trie is created by morecolors.
	
	The game name will not be set when the server first starts. Perhaps SteamTools isn't loaded by that point or some networking functionality might not be ready?
	
*/

// Global variables
//static bool g_bIsRoundActive;
static bool g_bSettingsRead;
static bool g_bBlueWarnedSuicide;
//static bool g_bHasTFLogicArena;		// Will be used in future to handle respawning for new map types
static bool g_bWatchForPlayerChanges;
//static bool g_bIsRedGlowActive;
//static bool g_bRedMeleeOnly;
static bool g_bHealthBarActive;

// Player points and bit flag arrays
//static int g_iPoints[33];		// Deprecated
//static int g_iFlags[33];		// Deprecated

static int g_iHealthBarTarget;

// Points Values
#define MINIMUM_ACTIVATORS 	2	// This or below number of willing activators and we use the turn-based system
	// Could make this a cvar

// Plugin cvars
ConVar g_cAutoEnable;			// Automatically enable the plugin's features
ConVar g_cEnabled;				// The plugin's features are active
ConVar g_cPreventBlueEscape;		// Blue can't suicide or switch teams when the round is active
ConVar g_cRedSpeed;				// Optionally set all red players' run speed
ConVar g_cRedScoutSpeed;			// Optionally cap red scout speed
ConVar g_cBlueSpeed;				// Run speed of blue players
ConVar g_cRedScoutDoubleJump;	// Optionally disable red scout double jump
ConVar g_cActivators;			// Number of activators (blue players. Recommended: 1)
ConVar g_cTeamMatePush;			// Players will push their team mates when touching them
ConVar g_cRedDemoChargeLimits;	// Reduce demoman charge duration or remove it
ConVar g_cRedSpyCloakLimits;		// Reduce cloak duration and increase regeneration time, or 'disable' both
ConVar g_cUsePointsSystem;		// Grant queue points to red players on round end, and make the player with the most points activator
ConVar g_cTeamPushOnRemaining;	// Enable team mate pushing when we reach a certain number of red players remaining
//ConVar g_cRedGlowRemaining;		// Enable a glow on red players when we reach a certain number remaining
//ConVar g_cRedGlow;				// Permanently enable a red glow on red players
ConVar g_cRedMeleeOnly;			// Remove weapons other than melee from red players, and kill their entities
ConVar g_cChatKillFeed;			// Tell a player the classname (and targetname if it exists) of the entity that caused their death
ConVar g_cBlastPushing;			// Control blast force pushing, e.g. rocket jumping
ConVar g_cBuildings;				// Restrict engineer building types for both teams
ConVar g_cAllowEurekaEffect;		// Allow the Eureka Effect. If not, it will be replaced with a wrench.
ConVar g_cShowRoundStartMessage;	// Shows the round start messages
ConVar g_cUseActivatorHealthBar;	// Use the boss health bar for the blue player when they are damaged by other players.
ConVar g_cThermalThruster;			// Thermal thruster charge rate

// Server cvars
ConVar g_cTeamsUnbalanceLimit;
ConVar g_cAutoBalance;
ConVar g_cScramble;
ConVar g_cArenaQueue;
ConVar g_cArenaFirstBlood;
ConVar g_cAirDashCount;
ConVar g_cServerTeamMatePush;
ConVar g_cRoundWaitTime;
ConVar g_cHumansMustJoinTeam;


HealthBar healthbar; // For some reason this wouldn't work when put in the include
Game game;


/*	PLUGIN AND MAP FORWARDS
---------------------------------------------------------------------------------------------------*/

// OnPluginStart
public void OnPluginStart()
{
	LoadTranslations("dtk-base.phrases");
	LoadTranslations("common.phrases");
	
	// Handle server cvars
	g_cTeamsUnbalanceLimit 	= FindConVar("mp_teams_unbalance_limit"); 	// 1 (0-30) - Teams are unbalanced when one team has this many more players than the other team. (0 disables check)
	g_cAutoBalance 			= FindConVar("mp_autoteambalance"); 		// 1 (0-2) - Automatically balance the teams based on mp_teams_unbalance_limit. 0 = off, 1 = forcibly switch, 2 = ask volunteers
	g_cScramble 			= FindConVar("mp_scrambleteams_auto"); 		// 1 - Server will automatically scramble the teams if criteria met.  Only works on dedicated servers.
	g_cArenaQueue 			= FindConVar("tf_arena_use_queue"); 		// 1 - Enables the spectator queue system for Arena.
	g_cArenaFirstBlood 		= FindConVar("tf_arena_first_blood"); 		// 1 - Rewards the first player to get a kill each round.
	g_cAirDashCount 		= FindConVar("tf_scout_air_dash_count"); 	// A hidden cvar which toggles scout double jump. Used for advice only.
	g_cServerTeamMatePush 	= FindConVar("tf_avoidteammates_pushaway"); // 1 - Whether or not teammates push each other away when occupying the same space
	g_cRoundWaitTime 		= FindConVar("mp_enableroundwaittime"); 	// 1 - The time at the beginning of the round, while players are frozen.
	g_cHumansMustJoinTeam 	= FindConVar("mp_humans_must_join_team");	// Forces players to join the specified team. Default is 'any'.
	
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
	g_cActivators 			= CreateConVar("dtk_activators", "1", "Number of activators (players on blue team). Setting to 0 will cause continual round resets on maps with a tf_logic_arena.", _, true, 0.0, true, 15.0);
	g_cTeamMatePush 		= CreateConVar("dtk_teampush", "0", "Team mate pushing", _, true, 0.0, true, 1.0);
	g_cRedDemoChargeLimits 	= CreateConVar("dtk_reddemocharge", "2", "Place limits on red demo charges. 0 = No charging. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cRedSpyCloakLimits 	= CreateConVar("dtk_redspycloak", "2", "Place limits on red spy cloaking. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cUsePointsSystem 		= CreateConVar("dtk_usepoints", "1", "Use the new points system for activator selection.", _, true, 0.0, true, 1.0);
	g_cTeamPushOnRemaining 	= CreateConVar("dtk_teampush_remaining", "3", "Number of players remaining on Red to activate team pushing. 0 = off.", _, true, 0.0, true, 30.0);
	//g_cRedGlowRemaining 	= CreateConVar("dtk_redglow_remaining", "3", "Number of players remaining on Red to activate glow outline. 0 = off.", _, true, 0.0, true, 30.0);
	//g_cRedGlow 				= CreateConVar("dtk_redglow", "0", "Make red players have a glowing outline for better visibility in maps with poorly designed activator corridors. 1 = on, 0 = off.", _, true, 0.0, true, 1.0);
	g_cRedMeleeOnly 		= CreateConVar("dtk_redmeleeonly", "0", "Restrict red players to melee weapons.", _, true, 0.0, true, 1.0);
	g_cChatKillFeed 		= CreateConVar("dtk_chatkillfeed", "1", "Show clients the classname and targetname of the entity that killed them.", _, true, 0.0, true, 1.0);
	g_cUseSQL 				= CreateConVar("dtk_usesql", "1", "Use SQLite for player points and prefs.", _, true, 0.0, true, 1.0);
	g_cBlastPushing 		= CreateConVar("dtk_blastpushing", "2", "Control blast force pushing. 0 = off, 1 = unregulated, 2 = reduced", _, true, 0.0, true, 2.0);
	g_cBuildings 			= CreateConVar("dtk_buildings", "12", "Restrict engineer buildings. Add up these values to make the convar value: Sentry = 1, Dispenser = 2, Tele Entrance = 4, Tele Exit = 8", _, true, 0.0, false, 15.0);
	g_cAllowEurekaEffect 	= CreateConVar("dtk_allow_eurekaeffect", "0", "Allow the Eureka effect. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cShowRoundStartMessage = CreateConVar("dtk_roundstartmessages", "1", "Show the round start messages. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cUseActivatorHealthBar = CreateConVar("dtk_activatorhealthbar", "1", "Use a boss health bar for the activator's health when they are damaged by an enemy. 1 = yes, 0 = no.", _, true, 0.0, true, 1.0);
	g_cThermalThruster		= CreateConVar("dtk_thermalthruster", "2", "Thermal thruster charge rate. 0 = No charges, 1 = Normal charge behaviour, 2 = Charges take one minute to recharge, 3 = Two charges with no recharging", _, true, 0.0, true, 3.0);
	
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
	//g_cRedGlowRemaining.AddChangeHook(ConVarChangeHook);
	//g_cRedGlow.AddChangeHook(ConVarChangeHook);
	g_cRedMeleeOnly.AddChangeHook(ConVarChangeHook);
	g_cChatKillFeed.AddChangeHook(ConVarChangeHook);
	g_cUseSQL.AddChangeHook(ConVarChangeHook);
	g_cBlastPushing.AddChangeHook(ConVarChangeHook);
	g_cBuildings.AddChangeHook(ConVarChangeHook);
	g_cAllowEurekaEffect.AddChangeHook(ConVarChangeHook);
	g_cShowRoundStartMessage.AddChangeHook(ConVarChangeHook);
	g_cUseActivatorHealthBar.AddChangeHook(ConVarChangeHook);
	g_cThermalThruster.AddChangeHook(ConVarChangeHook);
	
	// Add some console commands
	RegConsoleCmd("sm_drmenu", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_dr", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_drtoggle", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegConsoleCmd("sm_prefs", Command_Preferences, "A shortcut command for setting your deathrun activator and points preference.");
	RegConsoleCmd("sm_english", Command_English, "Toggle forcing English language plugin phrases.");
	RegConsoleCmd("sm_drdata", Command_PlayerData, "Print to console the values in the prefs and points arrays.");
	RegAdminCmd("sm_award", AdminCommand_AwardPoints, ADMFLAG_SLAY, "Award a poor person some deathrun queue points.");
	RegAdminCmd("sm_resetdatabase", AdminCommand_ResetDatabase, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Reset the deathrun player database.");
	RegAdminCmd("sm_resetuser", AdminCommand_ResetUser, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Deletes a player's data from the deathrun database table. They will be treated as a new player.");
	
	g_hHealthText = CreateHudSynchronizer();
	
	LogMessage("%s %s has loaded", PLUGIN_NAME, PLUGIN_VERSION);
}

// OnMapStart
public void OnMapStart()
{
	if (!g_cAutoEnable.BoolValue)
		return;
	
	// Detect if the map is using a deathrun prefix.
	char mapname[32];
	GetCurrentMap(mapname, sizeof(mapname));
	
	if (strncmp(mapname, "dr_", 3, false) == 0 ||
		strncmp(mapname, "deathrun_", 9, false) == 0 ||
		strncmp(mapname, "vsh_dr_", 7, false) == 0 ||
		strncmp(mapname, "vsh_deathrun_", 13, false) == 0 ||
		strncmp(mapname, "workshop/dr_", 12, false) == 0 ||
		strncmp(mapname, "workshop/deathrun_", 18, false) == 0 ||
		strncmp(mapname, "workshop/vsh_dr_", 16, false) == 0 ||
		strncmp(mapname, "workshop/vsh_deathrun_", 22, false) == 0 ||
		strncmp(mapname, "sandbox", 7, false) == 0)
		{
			// This is a deathrun map
			g_cEnabled.SetBool(true);
			LogMessage("Detected a deathrun map.");
			SetDescription();
		}
		else
		{
			// This is not a deathrun map
			LogMessage("Not a deathrun map. Deathrun functions will not be available.");
			Steam_SetGameDescription("Team Fortress");
		}
	
	if (g_cEnabled.BoolValue)
	{
		// Does the map have a tf_logic_arena?
		if (FindEntityByClassname(-1, "tf_logic_arena") == -1)
		{
			PrintToServer("%s This map does not have a tf_logic_arena", SERVERMSG_PREFIX);
			//g_bHasTFLogicArena = false;
			//g_cRoundWaitTime.SetInt(2);
		}
		//else
			//g_bHasTFLogicArena = true;
		
		EventsAndListeners(true);
		SetServerCvars(1);
		g_bWatchForPlayerChanges = true;	// Watch for players connecting after the map change
			// This is necessary because the server doesn't fire a round reset or start event
		
		game.CreateDBTable();
		game.PruneDB();
	}
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
}

// OnMapEnd
public void OnMapEnd()
{
	if (!g_cEnabled.BoolValue)
		return;
	
	// Close handles and restore cvars when the map switches
	EventsAndListeners(false);
	SetServerCvars(0);
	delete g_db;
	g_cEnabled.SetBool(false);
	LogMessage("The deathrun map has come to an end. Restoring some cvars to their default values");
}

// OnPluginEnd
public void OnPluginEnd()
{
	if (g_cEnabled.BoolValue)
		SetServerCvars(0);
	
	LogMessage("Plugin has been unloaded.");
}

public int Steam_FullyLoaded() // when void is supplied it says it wants int
{
	SetDescription();
}

void SetDescription()
{
	char sGameDesc[32];
	Format(sGameDesc, sizeof(sGameDesc), "Deathrun Toolkit | %s", PLUGIN_VERSION);
	Steam_SetGameDescription(sGameDesc);
	PrintToServer("%s Set game description to '%s'", SERVERMSG_PREFIX, sGameDesc);
}

// TF2 WaitingForPlayersTime finishes
public void TF2_OnWaitingForPlayersEnd()
{
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("%s Waiting for players time has ended", SERVERMSG_PREFIX);
}

// OnClientAuthorized
public void OnClientAuthorized(int client, const char[] auth)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	Player player = new Player(client);
/*
	Check User ID.
	
	Returning?
		Yes
			Leave them alone
		No
			Are they a bot or LAN user?
				Yes
					Give them default values
				No
					Retrieve their data
						Exists?
							Yes
								Retrieve it and store
							No
								Give them default values
*/
	if (player.UserID != player.ArrayUserID)	// New user session
	{
		DTK_DebugMsg("%N is a new player", player.Index);
		player.ResetData();
		
		if (player.SteamID == 0)	// Bot or LAN user?
		{
			DTK_DebugMsg("Steam ID of %N is %d. Bot or LAN user", player.Index, player.SteamID);
		}
		else
		{
			DTK_DebugMsg("%N has a valid Steam ID (%d). Retrieving stored data", player.Index, player.SteamID);
			if (!player.RetrieveData())	// If database record exists retrieve it and set
			{
				player.CreateRecord();
			}
		}
	}
	else
		DTK_DebugMsg("%N was playing on the last map", player.Index);
	
	if (player.Flags & FLAGS_ENGLISH)
		// If the FLAGS_ENGLISH bit is found in player.Flags return true
		SetClientLanguage(player.Index, 0);
	
	// Reset points and preferences for new clients on connecting for the first time
/*	int client = event.GetInt("index") + 1;
	g_iPoints[client] = Points_Starting;
	g_iFlags[client] |= FLAGS_NEW;
	
	if (g_cUseSQL.BoolValue && player.SteamID == 0)
		DTK_DebugMsg("%N doesn't have a valid Steam ID. They are likely a bot", player.Index);
	else
*/		
}

// OnClientPutInServer
public void OnClientPutInServer(int client)
{
	if (!g_cEnabled.BoolValue)
		return;

/*
	if ((g_iFlags[client] & FLAGS_WELCOMED_OLD) != FLAGS_WELCOMED_OLD)
	{
		int userid = GetClientUserId(client);
		CreateTimer(30.0, WelcomeMessage, userid);
	}
*/
	
	//if ((g_iFlags[client] & FLAGS_ENGLISH) == FLAGS_ENGLISH)
	//	SetClientLanguage(client, 0);
	
	// Hook damage on the player so we can modify it if it's from themselves
	SDKHook(client, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
}

// OnClientDisconnect
public void OnClientDisconnect(int client)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	Player player = new Player(client);
	
	// Store their data in the database
	if (g_cUseSQL.BoolValue && g_db != null)
	{
		//char auth[64];
		//GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
		
		//if (!StrEqual(auth, "BOT", true) && !StrEqual(auth, "STEAM_ID_LAN", true))
		if (player.SteamID == 0)
			DTK_DebugMsg("%N is a bot, or is on a LAN, so we won't store their data in the database", client);
		else
			player.SaveData();
	}
	
	// Boss health bar
	if (g_bHealthBarActive == true && client == g_iHealthBarTarget)
	{
		g_iHealthBarTarget = -1;
		SetHealthBar();
	}
}


/*	GAME EVENTS
---------------------------------------------------------------------------------------------------*/

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s The round has restarted", SERVERMSG_PREFIX);
	
	//g_bIsRoundActive = false;			// Essentially this is pre-round prep/freeze time
	//g_bIsRedGlowActive = false;
	//g_bRedMeleeOnly = g_cRedMeleeOnly.BoolValue;
	
	healthbar = new HealthBar();
	
	g_iHealthBarTarget = -1;
	SetHealthBar();
	
	// Read settings and apply attributes
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			ApplyAttributes(i);
	}
	g_bSettingsRead = true;				// Players won't receive attributes until settings have been read
	
	SetServerCvars(1);					// Make sure required cvars for the game mode are set on every round
	CheckForPlayers();					// Perform player number checking and begin team distribuiton
	
	// Set the value of the 'dtk_enabled' logic_branch to 1/true
	int i = -1;
	char sBranchName[MAX_NAME_LENGTH];
	while ((i = FindEntityByClassname(i, "logic_branch")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", sBranchName, sizeof(sBranchName));
		if (StrEqual("dtk_enabled", sBranchName))
		{
			SetEntProp(i, Prop_Data, "m_bInValue", 1, 1);
			i = -1;
			break;
		}
	}
	
	char sHealthName[MAX_NAME_LENGTH];
	while ((i = FindEntityByClassname(i, "math_counter")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", sHealthName, sizeof(sHealthName));
		if (StrEqual("dtk_health", sHealthName))
		{
			DTK_DebugMsg("Found math_counter named %s with entity index %d", sHealthName, i);
			HookSingleEntityOutput(i, "OutValue", EntityHealthBar);
			HookSingleEntityOutput(i, "OnUser1", EntityHealthBar);
			HookSingleEntityOutput(i, "OnUser2", EntityHealthBar);
			break;
		}
	}
		
}

// Entity health bar stuff
// Just putting it here for now while we make sure it works
void EntityHealthBar(const char[] output, int caller, int activator, float delay)
{
	if (StrEqual(output, "OnUser1", false))
	{
		healthbar.SetColor(0);
		//SetEntProp(g_iHealthBar[HealthBar_Resource], Prop_Send, "m_iBossState", 0);
	}
	if (StrEqual(output, "OnUser2", false))
	{
		healthbar.SetColor(1);
		//SetEntProp(g_iHealthBar[HealthBar_Resource], Prop_Send, "m_iBossState", 1);
	}
	if (StrEqual(output, "OutValue", false))
	{
		float fMin = GetEntPropFloat(caller, Prop_Data, "m_flMin");
		float fMax = GetEntPropFloat(caller, Prop_Data, "m_flMax");
		int offset = FindDataMapInfo(caller, "m_OutValue");
		float fValue = GetEntDataFloat(caller, offset);

		fMax -= fMin;
		fValue -= fMin;
		int iPercent = RoundToNearest((fValue / fMax) * 255);
		
		SetEntProp(healthbar.Index, Prop_Send, "m_iBossHealthPercentageByte", iPercent);
	}
	
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//g_bIsRoundActive = true;			// The round is now active
	g_bBlueWarnedSuicide = false;		// Reset the warning given to blue when trying to quit
	g_bWatchForPlayerChanges = false;	// No need to watch for team changes now
	
	if (g_cShowRoundStartMessage.BoolValue)
		RoundActiveMessage();			// Fire the function that cycles through round start messages
		
	RequestFrame(CheckGameState);		// Count players and apply some settings like pushing and glow
	
/*	if (g_cRedGlow.BoolValue)		// Turn on red glow if the cvar is set to true
	{
		g_bIsRedGlowActive = true;
		
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == Team_Red)
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
	}
*/
	
	PrintToServer("%s The round is now active", SERVERMSG_PREFIX);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// Give players points
	if (g_cUsePointsSystem.BoolValue == true)
		for (int i = 1; i <= MaxClients; i++)
		{
			Player player = new Player(i);
			if (player.InGame && player.Team == Team_Red && (player.Flags & FLAGS_PREFERENCE))
				// If FLAGS_PREFERENCE bit is found in player.Flags
			{
				int awarded = (player.Flags & FLAGS_FULLPOINTS) ? Points_FullAward : Points_PartialAward;
					// If player.Flags has FLAGS_FULLPOINTS set, give full points else give partial points
				player.AddPoints(awarded);
				PrintToChat(i, "%t %t", "prefix", "round end queue points received", awarded, player.Points);
			}
		}
	
	DisplayNextActivators();
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("%s The round has ended", SERVERMSG_PREFIX);
}


/*	PLAYER EVENTS
---------------------------------------------------------------------------------------------------*/

void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	// Server console information that a player has newly-connected
	char sName[64], sSteamID[128];
	event.GetString("name", sName, sizeof(sName));
	event.GetString("networkid", sSteamID, sizeof(sSteamID));
	PrintToServer("%s %s has connected (Steam ID: %s)", SERVERMSG_PREFIX, sName, sSteamID);
	
	// Reset points and preferences for new clients on connecting for the first time
/*	int client = event.GetInt("index") + 1;
	g_iPoints[client] = Points_Starting;
	g_iFlags[client] |= FLAGS_NEW;
*/
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	
	if (g_bSettingsRead)
		ApplyAttributes(player.Index);
	
	// Remove a glow from the previous round
	//SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1); // Not working!
	
	// Check if it's necessary to make the player glow
	//RequestFrame(CheckForGlow, client);
	
	RequestFrame(CheckGameState);
}

void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	/*

	Weapon Restriction Plan
	-----------------------
	
	On post inventory check
	
		If it's not a melee weapon, check if we are ent stripping non-melee weapons and if so, skip non-melee weapon replacement.
	
			Is engineer?
	
				Check wrench slot item def. index.
	
					Remove if 589.
	
						Create a new weapon (standard wrench).
	
						Give the player the weapon.
	
		Strip to melee as usual after this is done.

	*/
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	Player player = new Player(client);
	
	/*if (TF2_GetPlayerClass(client) == TFClass_Engineer)
	{
		int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
		if (GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex") == 589)
		{
			TF2_RemoveWeaponSlot(client, TFWeaponSlot_Melee);
			
			Handle item = TF2Items_CreateItem();
			// FORCE_GENERATION | OVERRIDE_CLASSNAME | OVERRIDE_ITEM_DEF | OVERRIDE_ITEM_LEVEL | OVERRIDE_ITEM_QUALITY | OVERRIDE_ATTRIBUTES
			TF2Items_SetItemIndex(item, 7);
			
		}
	}*/
	
	
	
	
	
	/*
	MeleeOnly(int client)
{
	TF2_AddCondition(client, TFCond_RestrictToMelee, TFCondDuration_Infinite, 0);
	
	int weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
	char classname[MAX_NAME_LENGTH];
	GetEdictClassname(weapon, classname, sizeof(classname));
	
	//EquipPlayerWeapon(client, weapon); // doesn't seem to work
	FakeClientCommandEx(client, "use %s", classname);
	SetEntProp(client, Prop_Send, "m_hActiveWeapon", weapon);
	
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
}*/
	
	
	
	if (g_cRedMeleeOnly.BoolValue)
	{
		if (player.Team == Team_Red)
			//MeleeOnly(client);
		player.MeleeOnly();
	}
	else
	{
		player.SetSlot(TFWeaponSlot_Primary);
		//SwitchToSlot(client, TFWeaponSlot_Primary);
	}
		
	// Boss health bar
	if (g_bHealthBarActive == true && client == g_iHealthBarTarget)
		SetHealthBar();
	
	// Thermal Thruster modding
	int weapon;
	if ((weapon = GetPlayerWeaponSlot(client, TFWeaponSlot_Secondary)) != -1)
	{
		char classname[64];
		GetEntityClassname(weapon, classname, sizeof(classname));
		if (StrEqual(classname, "tf_weapon_rocketpack"))
		{
			switch (g_cThermalThruster.IntValue)
			{
				case 0:
				{
					TF2Attrib_SetByName(weapon, "item_meter_charge_rate", -1.0);	// Charges are drained rendering the weapon unuseable
				}
				case 1:
				{
					TF2Attrib_RemoveByName(weapon, "item_meter_charge_rate");		// Use normal charging behaviour
				}
				case 2:
				{
					TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 120.0);	// Charges take one minute to charge
				}
				case 3:
				{
					TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.0);		// The player only has two charges
				}
			}
			
		}
	}
}

// TF2 Items' OnGiveNamedItem forward
public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &hItem)
{
	static Handle previousItem = INVALID_HANDLE;
	
	// I think we are closing a clone of the previous hItem handle to stop leaks
	if (previousItem != INVALID_HANDLE)
	{
		CloseHandle(previousItem);
		previousItem = INVALID_HANDLE;
	}
	
	if (hItem != INVALID_HANDLE)
	{
		return Plugin_Continue;
	}
	
	if (itemDefIndex == 589 && !g_cAllowEurekaEffect.BoolValue)	// Eureka Effect
	{
		hItem = TF2Items_CreateItem(OVERRIDE_ITEM_DEF);
		TF2Items_SetItemIndex(hItem, 7);	// Wrench
		previousItem = hItem;
		return Plugin_Changed;
	}
	else if (itemDefIndex == 1179)	// Thermal Thruster 1179
	{
	/*	hItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);
		PrintToChat(client, "Number of weapon attributes: %d", TF2Items_GetNumAttributes(hItem));
		PrintToChat(client, "Weapon attribute index of [0]: %d", TF2Items_GetAttributeId(hItem, 0));
		PrintToChat(client, "Weapon attribute value of [0]: %d", TF2Items_GetAttributeValue(hItem, 0));
		PrintToChat(client, "Applying attribute to the weapon...");
		TF2Items_SetNumAttributes(hItem, 1);
		TF2Items_SetAttribute(hItem, 0, 801, 1.0); // 801
		//if (TF2Attrib_SetByName(hItem, "item_meter_charge_rate", 0.1))
			//PrintToChat(client, "Set charge rate on your jetpack!");
		PrintToChat(client, "Number of weapon attributes: %d", TF2Items_GetNumAttributes(hItem));
		PrintToChat(client, "Weapon attribute index of [0]: %d", TF2Items_GetAttributeId(hItem, 0));
		PrintToChat(client, "Weapon attribute value of [0]: %f", TF2Items_GetAttributeValue(hItem, 0));
		TF2Items_GetAttributeI
		previousItem = hItem;
		return Plugin_Changed;*/
		return Plugin_Continue;
	}
	else
		return Plugin_Continue;
}


void Event_PlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("patient")));
	
	if (player.Index == g_iHealthBarTarget)
		RequestFrame(SetHealthBar);
}


void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	player.Welcome();
}


void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//int victim = event.GetInt("victim_entindex");
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	// Chat kill feed
	if (g_cChatKillFeed)
		if (event.GetInt("attacker") == 0)	// Killed by world
		{
			char classname[MAX_NAME_LENGTH];
			event.GetString("weapon_logclassname", classname, sizeof(classname));	// Get the killer entity's classname
			
			if (classname[0] != 'w')
			{
				char targetname[MAX_NAME_LENGTH];										// Get the targetname if it exists
				GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
		
				if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
					Format(targetname, sizeof(targetname), " (%s)", targetname);
				
				PrintToChat(victim, "%t %t", "prefix", "killed by entity classname", classname, targetname);
			}
		}
	
	RequestFrame(CheckGameState);	// Check for live players remaining and enable team pushing at some amount
	
	// Boss health bar
	if (g_bHealthBarActive == true && victim == g_iHealthBarTarget)
	{
		g_iHealthBarTarget = -1;
		SetHealthBar();
	}
}

void Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	// If we're watching for player changes during freeze time:
	if (g_bWatchForPlayerChanges)
		RequestFrame(CheckForPlayers);
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	char sName[32], sSteamID[64], sReason[64];
	event.GetString("name", sName, sizeof(sName));
	event.GetString("networkid", sSteamID, sizeof(sSteamID));
	event.GetString("reason", sReason, sizeof(sReason));
	
	PrintToServer("%s %s has disconnected (Steam ID: %s - Reason: %s)", SERVERMSG_PREFIX, sName, sSteamID, sReason);
	
	/*/ Reset queue points
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iPoints[client] = 0;
	g_iFlags[client] = FLAGS_DISCONNECTED;*/
}

/*
public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (g_cEnabled.BoolValue)
		if (condition == TFCond_Cloaked && g_bIsRedGlowActive && GetClientTeam(client) == Team_Red)
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (g_cEnabled.BoolValue)
		if (condition == TFCond_Cloaked && g_bIsRedGlowActive && GetClientTeam(client) == Team_Red)
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
}
*/

// SDKHook OnTakeDamage
Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3])
{
	if (g_cUseActivatorHealthBar.BoolValue)
	{
		if (attacker != victim && victim == g_iHealthBarTarget)
		{
			g_bHealthBarActive = true;
			RequestFrame(SetHealthBar);
		}
	}
	
	if (GetClientTeam(victim) == Team_Red && attacker == victim)
	{
		switch (g_cBlastPushing.IntValue)
		{
			case 0:
				return Plugin_Continue;
			case 1:
				damage = 0.0;
			case 2:
			{
				switch (TF2_GetPlayerClass(victim))
				{
					case TFClass_Soldier:
						if (damage > 35)
							damage = 35.0;
					case TFClass_DemoMan:
						damage = 2.2;
				}
			}
		}
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}


/*	SINGLE TASK FUNCTIONS
---------------------------------------------------------------------------------------------------*/

/*
	1. Check the number of players. If not enough goto 2. if enough goto 5.
	2. Print a message if there are not enough and go into a waiting state.
	3. Watch for changes to teams
	4. Recycle this function again if teams change.
	5. Redistribute.

	On round reset > Check players

	What is the desired number of activators?
	Are there at least 1+desired_activators players?
	
	Yes > Swap people around using whichever system is active.
	
	No > Print "Not enough players" and go on watch for team changes (global var in team_change event)

	Need to replace activator if they leave.
	When players have been moved, watch for changes. 
	If a change occurs, check if we have desired_activators on blue team. If we do, do nothing. If we don't, run Check Players.

	Bug:
	
	When using more than one activator and the number of players in game is equal to that and someone leaves blue, teams
	will not rebalance because there isn't an branch to deal with the situation. I think I need to come up with a better checking
	system set of branches which has fallback for fewer activators than the required. But for now it's best to keep the
	number of activators on 1.

*/

// Welcome message
/*
Action WelcomeMessage(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0 || (g_iFlags[client] & FLAGS_WELCOMED_OLD) == FLAGS_WELCOMED_OLD)	// Just in case connecting caused multiple timer fires
		return;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	PrintToChat(client, "%t %t", "prefix_notice", "welcome player to deathrun toolkit", name);
	g_iFlags[client] |= FLAGS_WELCOMED_OLD;
}
*/

// Check to see if it's necessary to make the player glow
/*
void CheckForGlow(int client)
{
	if (g_bIsRedGlowActive || g_cRedGlow.BoolValue)
		if (GetClientTeam(client) == Team_Red)
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
			DTK_DebugMsg("%N just spawned and was made to glow", client);
		}
}
*/

// Check if we have enough players
void CheckForPlayers()
{
	static bool need_more_players_message = false;
	int desired_activators = g_cActivators.IntValue;

	DTK_DebugMsg("Checking for players...");

	// Blue player switches/leaves during freeze time and we have enough players to replace them
	if (g_bWatchForPlayerChanges && DTK_CountPlayers(Team_Blue) < desired_activators && DTK_CountPlayers() > desired_activators)
	{
		g_bWatchForPlayerChanges = false;		// Stop watching for new players
		DTK_DebugMsg("A blue player has left the team during freeze time.");
		RequestFrame(RedistributePlayers);		// Make some changes. We'll go back to watching when the changes are done.
			// Request frame prevents red team count from going up falsely due to switching too fast
		return;
	}
	
	// In freeze time with the required number of activators
	if (g_bWatchForPlayerChanges && DTK_CountPlayers(Team_Blue) == desired_activators)
	{
		DTK_DebugMsg("Team change detected but no action required");
		return;
	}

	// At round restart
	if (!g_bWatchForPlayerChanges && DTK_CountPlayers() > 1)
	{
		DTK_DebugMsg("We have enough players to start.");
		RedistributePlayers();
		need_more_players_message = false;
	}
	/*else if (!g_bWatchForPlayerChanges && DTK_CountPlayers(0, false) > 2 && desired_activators > 1)
	{
		CheckForPlayers();
	}*/
	else
	{
		DTK_DebugMsg("Not enough players to start a round. Gone into waiting mode");
		g_bWatchForPlayerChanges = true;
		if (!need_more_players_message)
		{
			PrintToChatAll("%t %t", "prefix_strong", "need more players");
			need_more_players_message = true;
		}
	}
}

// Redistribute players
void RedistributePlayers()
{
	DTK_DebugMsg("Redistributing the players");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		if (player.InGame && player.Team == Team_Blue)
			player.SetTeam(Team_Red);
	}
	
	if (g_cUsePointsSystem.BoolValue)	// Use queue points system if enabled
	{
		int prefers;
		
		for (int i = 1; i <= MaxClients; i++)
		//for (int i = 1; i <= MaxClients && prefers <= MINIMUM_ACTIVATORS; i++)
		{
			Player player = new Player(i);
			if (player.Flags & FLAGS_PREFERENCE)
				// If player.Flags has the FLAGS_PREFERENCE bit set, return true
				prefers += 1;
		}
		
		if (prefers <= MINIMUM_ACTIVATORS)
		{
			SelectActivatorTurn();
			PrintToChatAll("%t %t", "prefix", "not enough activators");
		}
		else
			SelectActivatorPoints();
	}					
	else
		SelectActivatorTurn();				// Use turn-based system if queue points are disabled
	
	g_bWatchForPlayerChanges = true;		// Go into watch mode to replace activator if needed
}

// Select activator (turn-based system)
void SelectActivatorTurn()
{
	static int iClientTurn = 1;
	
	//if (client > MaxClients)
		//client = 1;
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	while (GetTeamClientCount(Team_Blue) < g_cActivators.IntValue && GetTeamClientCount(Team_Red) > 1)
	{
		Player player = new Player(iClientTurn);
		
		if (player.InGame && player.Team == Team_Red)
		{
			PrintToServer("%s The turn-based activator selection system has selected %N", SERVERMSG_PREFIX, player.Index);
			player.SetTeam(Team_Blue);
			g_iHealthBarTarget = player.Index;
		}
		
		if (iClientTurn == MaxClients)
			iClientTurn = 1;
		else
			iClientTurn++;
	}	
}

// Select activator (queue points system)
void SelectActivatorPoints()
{
	// First sort our player points array by points in descending order
	int points_order[32][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	
	while (GetTeamClientCount(Team_Blue) < g_cActivators.IntValue && GetTeamClientCount(Team_Red) > 1)
	{
		Player player = new Player(points_order[i][0]);
		
		if (player.InGame && player.Team == Team_Red && (player.Flags & FLAGS_PREFERENCE))
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
		{
			PrintToServer("%s The points-based activator selection system has selected %N", SERVERMSG_PREFIX, player.Index);
			player.SetTeam(Team_Blue);
			player.SetPoints(Points_Consumed);
			PrintToChat(player.Index, "%t %t", "prefix_notice", "queue points consumed");
			g_iHealthBarTarget = player.Index;
		}
		
		if (i == MaxClients - 1)
			i = 0;
		else
			i++;
	}
}

// Apply Attributes
void ApplyAttributes(int client)
{
	// Remove all player attributes
	if (!TF2Attrib_RemoveAll(client))
		LogMessage("Unable to remove attributes from %L", client);
	
	
	// Add attributes
	switch (GetClientTeam(client))
	{
		// Blue flat speed setting
		case Team_Blue:
			if (g_cBlueSpeed.FloatValue != 0.0)
			{
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cBlueSpeed.FloatValue / g_iRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, " [DR] Your run speed has been set to %.0f u/s", g_cBlueSpeed.FloatValue);
			}

		// Red team modding for speed and abilities
		case Team_Red:
		{
			// Red speed
			// ***************************************************************************************************************************************
			if (g_cRedSpeed.FloatValue != 0.0)
			{
				// If red speed cvar is set
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cRedSpeed.FloatValue / g_iRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, " [DR] Your run speed has been set to %.0f u/s", g_cRedSpeed.FloatValue);
			}
			else if (g_cRedScoutSpeed.FloatValue != 0.0 && TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				// If red scout run speed cvar is set
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cRedScoutSpeed.FloatValue / g_iRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, "[DR] Your run speed has been set to %.0f u/s", g_cRedScoutSpeed.FloatValue);
			}
			else
				PrintToConsole(client, "%t %t", "prefix", "class default run speed");
			
			// Red scout double jump
			// ***************************************************************************************************************************************
			if (g_cRedScoutDoubleJump.BoolValue == false && TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				TF2Attrib_SetByName(client, "no double jump", 1.0);
				PrintToConsole(client, "%t %t", "prefix", "red scout double jump disabled");
			}
			
			// Red team class ability modding
			// ***************************************************************************************************************************************
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Spy:		if (g_cRedSpyCloakLimits.IntValue == 2)
										{
											TF2Attrib_SetByName(client, "mult cloak meter consume rate", 8.0);
											TF2Attrib_SetByName(client, "mult cloak meter regen rate", 0.25);
											PrintToChat(client, "%t %t", "prefix", "red spy cloak limited");
										}

				case TFClass_DemoMan:	switch (g_cRedDemoChargeLimits.IntValue)
										{
											case 0:
											{
												// Turn off red demo charging
												TF2Attrib_SetByName(client, "charge time decreased", -1000.0);
												TF2Attrib_SetByName(client, "charge recharge rate increased", 0.0);
												PrintToChat(client, "%t %t", "prefix", "red demo charge disabled");
											}
											case 2:
											{
												// Limit demo charging
												TF2Attrib_SetByName(client, "charge time decreased", -0.95);
												TF2Attrib_SetByName(client, "charge recharge rate increased", 0.2);
												PrintToChat(client, "%t %t", "prefix", "red demo charge limited");
											}
										}
			} // switch end
		}
	}
}

// Display up to the next three activators at the end of a round.
void DisplayNextActivators()
{
	// Count the number of willing activators
	int willing;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		if (player.Flags & FLAGS_PREFERENCE)
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
			willing += 1;
	}
	
	// If we don't have enough willing activators, don't display the message
	if (willing <= MINIMUM_ACTIVATORS)
	{
		return;
	}
	
	// Create a temporary array to store client index[0] and points[1]
	int points_order[32][2];
	
	// Populate with player data
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	// Sort by points descending
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// Get the top three players with points
	//int players[3], count, client;
	int players[3], count;
	
	for (int i = 0; i < MaxClients && count < 3; i++)
	{
		Player player = new Player(points_order[i][0]);
		//client = points_order[i][0];
	
		if (player.InGame && player.IsParticipating && points_order[i][1] > 0 && (player.Flags & FLAGS_PREFERENCE))
			// If player.Flags has the FLAGS_PREFERENCE bit set return true
		//if (IsClientInGame(client) && points_order[i][1] > 0 && (g_iFlags[client] & FLAGS_PREFERENCE) == FLAGS_PREFERENCE)
		{
			players[count] = player.Index;
			//players[count] = client;
			count++;
		}
	}
	
	// Display the message
	if (players[0] != 0)
	{
		char string1[MAX_NAME_LENGTH];
		char string2[MAX_NAME_LENGTH];
		char string3[MAX_NAME_LENGTH];
		
		Format(string1, sizeof(string1), "%N", players[0]);
		
		if (players[1] > 0)
			Format(string2, sizeof(string2), ", %N", players[1]);
		
		if (players[2] > 0)
			Format(string3, sizeof(string3), ", %N", players[2]);
		
		PrintToChatAll("%t %t", "prefix", "next activators", string1, string2, string3);
	}
}

// Sort the players by points
int SortByPoints(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])
		return 0;
	else if (b[1] > a[1])
		return 1;
	else
		return -1;
}

// Perform actions based on the number of reds alive
void CheckGameState()
{
	//if (!g_bIsRoundActive)
	//	return;
	
	if (!game.RoundActive)
		return;
	
	int iRedAlive = DTK_CountPlayers(Team_Red, LifeState_Alive);
	
	// Team pushing	
	int iPushRemaining = g_cTeamPushOnRemaining.IntValue;
	bool bAlwaysPush = g_cTeamMatePush.BoolValue;
	bool bPushingEnabled = g_cServerTeamMatePush.BoolValue;
	
	if (!bAlwaysPush && iPushRemaining != 0)
	{
		if (!bPushingEnabled && iRedAlive <= iPushRemaining)
		{
			g_cServerTeamMatePush.SetBool(true);
			PrintToChatAll("%t %t", "prefix", "team mate pushing enabled");
		}
		if (bPushingEnabled && iRedAlive > iPushRemaining)
		{
			g_cServerTeamMatePush.SetBool(false);
			PrintToChatAll("%t %s", "prefix", "Team mate pushing has been disabled");
		}
	}
	
	/*
		Is the round active?
		
		Count red players alive
		
		Pushing
			Is global pushing disabled?
				If push remain enabled?
					If less than or equal to cvar setting, apply pushing
					Else disable.
	*/

/*
	// Red glow
	int iGlowRemain = g_cRedGlowRemaining.IntValue;
	
	if (iRedAlive <= iGlowRemain && iGlowRemain != 0 && g_cRedGlow.BoolValue == false)
	{
		g_bIsRedGlowActive = true;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == Team_Red)
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
			}
		}
	}
*/
}


// Suicide command blocking (only hooked on deathrun map)
Action CommandListener_Suicide(int client, const char[] command, int args)
{
	// If the round is active, prevent blue players from suiciding or switching if the server has that enabled.
	//if (g_bIsRoundActive && GetClientTeam(client) == Team_Blue && IsPlayerAlive(client) && g_cPreventBlueEscape.BoolValue)
	if (game.RoundActive && GetClientTeam(client) == Team_Blue && IsPlayerAlive(client) && g_cPreventBlueEscape.BoolValue)
	{
		if (!g_bBlueWarnedSuicide)
		{
			SlapPlayer(client, 0);
			PrintToChat(client, "%t %t", "prefix", "blue no escape");
			g_bBlueWarnedSuicide = true;
		}
		
		ReplyToCommand(client, "%t Command '%s' has been disallowed by the server.", "prefix", command);
		return Plugin_Handled;
	}
	
	// Block the 'autoteam' command at all times because it bypasses team balancing
	else if (strcmp(command, "autoteam", false) == 0)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


// Engineer build command blocking (only hooked on deathrun map)
Action CommandListener_Build(int client, const char[] command, int args)
{
	/*
	
	build 0 0 will build a Dispenser (Engineer only)
    build 1 0 will build a teleporter entrance (Engineer only)
    build 1 1 will build a teleporter exit (Engineer only)
    build 2 0 will build a Sentry Gun (Engineer only)
    build 3 0 will build a Sapper (Spy only)
    
    build 0 will build a Dispenser (Engineer only)
    build 1 will build a teleporter entrance (Engineer only)
    build 2 will build a Sentry Gun (Engineer only)
    build 3 will build a teleporter exit (Engineer only)
    build 3 will build a Sapper (Spy only) [deprecated]
    
    1 = sentry
	2 = dispenser
	4 = tele entrance
	8 = tele exit
	
	*/
	
	if (g_cBuildings.IntValue != 0)
	{
		char arg1[2], arg2[2];
		GetCmdArg(1, arg1, sizeof(arg1)), GetCmdArg(2, arg2, sizeof(arg2));
		int iArg1 = StringToInt(arg1), iArg2 = StringToInt(arg2);
		
		if (iArg1 == 0 && (g_cBuildings.IntValue & BUILDINGS_DISPENSER) == BUILDINGS_DISPENSER)
		{
			PrintToChat(client, "%t Sorry, you aren't allowed to build dispensers", "prefix");
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 0 && (g_cBuildings.IntValue & BUILDINGS_TELE_ENTRANCE) == BUILDINGS_TELE_ENTRANCE)
		{
			PrintToChat(client, "%t Sorry, you aren't allowed to build teleporter entrances", "prefix");
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 1 && (g_cBuildings.IntValue & BUILDINGS_TELE_EXIT) == BUILDINGS_TELE_EXIT)
		{
			PrintToChat(client, "%t Sorry, you aren't allowed to build teleporter exits", "prefix");
			return Plugin_Handled;
		}
		if (iArg1 == 2 && (g_cBuildings.IntValue & BUILDINGS_SENTRY) == BUILDINGS_SENTRY)
		{
			PrintToChat(client, "%t Sorry, you aren't allowed to build sentries", "prefix");
			return Plugin_Handled;
		}
		// build 3 is for backwards compatability of the deprecated build argument to build a tele exit
		if (iArg1 == 3 && (g_cBuildings.IntValue & BUILDINGS_TELE_EXIT) == BUILDINGS_TELE_EXIT && TF2_GetPlayerClass(client) == TFClass_Engineer)
		{
			PrintToChat(client, "%t Sorry, you aren't allowed to build teleporter exits", "prefix");
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}

// Set cvars on the server to allow player team distribution, or reset them
void SetServerCvars(int set_mode)
{
	switch (set_mode)
	{
		case 1:
		{
			if (g_cAirDashCount.IntValue == 0)
				PrintToServer("%s INFORMATION: DTK doesn't need 'tf_scout_air_dash_count' set to 0 because we only limit red scout air dash using attributes", SERVERMSG_PREFIX);
			
			g_cTeamsUnbalanceLimit.IntValue = 0;
			g_cAutoBalance.IntValue = 0;
			g_cScramble.IntValue = 0;
			g_cArenaQueue.IntValue = 0;
			g_cArenaFirstBlood.IntValue = 0;
			g_cHumansMustJoinTeam.SetString("red");
			g_cServerTeamMatePush.SetBool(g_cTeamMatePush.BoolValue);
		}
		case 0:
		{
			g_cTeamsUnbalanceLimit.RestoreDefault();
			g_cAutoBalance.RestoreDefault();
			g_cScramble.RestoreDefault();
			g_cArenaQueue.RestoreDefault();
			g_cArenaFirstBlood.RestoreDefault();
			g_cServerTeamMatePush.RestoreDefault();
			g_cRoundWaitTime.RestoreDefault();
			g_cHumansMustJoinTeam.RestoreDefault();
		}
	}
}

// Set a player to switch to their melee weapon and delete their other weapons
// Replaced by Player methodmap
/*MeleeOnly(int client)
{
	TF2_AddCondition(client, TFCond_RestrictToMelee, TFCondDuration_Infinite);
	
	//SwitchToSlot(client, TFWeaponSlot_Melee);
	Player player = new Player(client);
	player.SetSlot(TFWeaponSlot_Melee);
	
	//TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);
	//TF2_RemoveWeaponSlot(client, TFWeaponSlot_Grenade);
	//TF2_RemoveWeaponSlot(client, TFWeaponSlot_PDA);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Secondary);
}*/

void SetHealthBar()
{
	if (healthbar.Index == -1 || healthbar.PlayerResource == -1)
		return;
	
	if (g_iHealthBarTarget == -1)
	{
		healthbar.SetHealth();
		g_bHealthBarActive = false;
		return;
	}
	
	Player player = new Player(g_iHealthBarTarget);
	
	int health = player.Health;						// Get the player's health
	int maxHealth = player.MaxHealth;				// Get the player's max health from the player resource entity
	
	/*
	if (health > maxHealth)
		maxHealth = health;
	
	float value = (float(health) / float(maxHealth)) * 255.0;									// Calculate the percentage of health to max health and convert it to a 0-255 scale
	
	if (value > 255.0)																			// Limit the values so they don't cause the bar to display at incorrect times
		value = 255.0;
	if (value < 0.0)
		value = 0.0;
	
	SetEntProp(healthbar.Index, Prop_Send, "m_iBossHealthPercentageByte", RoundToNearest(value));
	SetEntProp(healthbar.Index, Prop_Send, "m_iBossState", 0);											// Makes it default blue
	*/
	
	healthbar.SetHealth(health, maxHealth);
}


/*	MULTI-USE FUNCTIONS
---------------------------------------------------------------------------------------------------*/

// Set and remove event hooks and command listeners
void EventsAndListeners(bool set_mode)
{
	switch (set_mode)
	{
		case true:
		{
			// Hook some events
			HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
			HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
			HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
			HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
			HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);					// Player spawns
			HookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Post);				// Player changes class
			HookEvent("player_healed", Event_PlayerHealed, EventHookMode_Post);					// Player healed
			HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);					// Player dies
			HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);		// Player connects to the server for the first time
			HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);			// Player disconnects from the server
			HookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);			// A player changes team
			HookEvent("post_inventory_application", Event_InventoryApplied, EventHookMode_Post);// A player receives their weapons
			
			// Add some command listeners to restrict certain actions
			AddCommandListener(CommandListener_Suicide, "kill");
			AddCommandListener(CommandListener_Suicide, "explode");
			AddCommandListener(CommandListener_Suicide, "spectate");
			AddCommandListener(CommandListener_Suicide, "jointeam");
			AddCommandListener(CommandListener_Suicide, "autoteam");
			AddCommandListener(CommandListener_Build, "build");
		}
		
		case false:
		{
			// Unhook some events
			UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
			UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
			UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
			UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
			UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
			UnhookEvent("player_changeclass", Event_ChangeClass, EventHookMode_Post);
			UnhookEvent("player_healed", Event_PlayerHealed, EventHookMode_Post);
			UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
			UnhookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);
			UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
			UnhookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);
			UnhookEvent("post_inventory_application", Event_InventoryApplied, EventHookMode_Post);
			
			// Remove the command listeners
			RemoveCommandListener(CommandListener_Suicide, "kill");
			RemoveCommandListener(CommandListener_Suicide, "explode");
			RemoveCommandListener(CommandListener_Suicide, "spectate");
			RemoveCommandListener(CommandListener_Suicide, "jointeam");
			RemoveCommandListener(CommandListener_Suicide, "autoteam");
			RemoveCommandListener(CommandListener_Build, "build");
		}
	}
}

void ConVarChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[64];
	convar.GetName(sName, sizeof(sName));
	
	PrintToServer("%s %s has been changed from %s to %s", SERVERMSG_PREFIX, sName, oldValue, newValue);
	
	/*
		Convars which need a change to take effect when changed
		
		Evaluate attributes:
			redspeed
			redscoutspeed
			bluespeed
			redscoutdoublejump
			reddemochargelimits
			redspycloaklimits
		
		Respawn weapons:
			alloweurekaeffect
			redmeleeonly
	
		Check game state:
			teampushonremaining
			redglowremaining (not anymore)
			redglow (not anymore)
		
		Special:
			useactivatorhealthbar
			teammatepush
	*/
	
	if (StrContains(sName, "teampush", false) != -1)
	{
		CheckGameState();
	}
	if (StrContains(sName, "meleeonly", false))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			Player player = new Player(i);
			if (player.InGame && player.Team == Team_Red)
				player.MeleeOnly(convar.BoolValue);
		}
	}
}

// Message in chat when the round is active
void RoundActiveMessage()
{
	static int phrase_number = 1; char phrase[20];
	FormatEx(phrase, sizeof(phrase), "round has begun %d", phrase_number);
	
	if (!TranslationPhraseExists(phrase))
	{
		phrase_number = 1;
		RoundActiveMessage();
	}
	else
	{
		PrintToChatAll("%t %t", "prefix_strong", phrase);
		phrase_number++;
	}
}


/*	COMMANDS
---------------------------------------------------------------------------------------------------*/

// Show my points
Action Command_ShowPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	Player player = new Player(client);
	
	if (g_cUsePointsSystem.BoolValue == true)
		ReplyToCommand(client, "%t %t", "prefix_notice", "you have i points", player.Points);
	else
		ReplyToCommand(client, "%t %t", "prefix_notice", "not using the points system");
		
	return Plugin_Handled;
}

// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
	
	Player player = new Player(client);
	
	if (g_cUsePointsSystem.BoolValue == true)
	{
		if (player.Points >= 0)
		{
			player.SetPoints(Points_Consumed);
			ReplyToCommand(player.Index, "%t %t", "prefix_notice", "points have been reset to i", player.Points);
			DTK_DebugMsg("%N has reset their points using /reset", player.Index);
		}
		else
		{
			ReplyToCommand(player.Index, "%t %t", "prefix_notice", "points cannot be reset");
			LogMessage("%L tried to reset their points total but was disallowed because it is a negative value", player.Index);
		}
	}
	else
		ReplyToCommand(player.Index, "%t %t", "prefix", "not using the points system");
		
	return Plugin_Handled;
}

// Set my queue points multiplier and activator preference
Action Command_Preferences(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	if (args < 1)
	{
		Player player = new Player(client);
		if (!(player.Flags & FLAGS_PREFERENCE))
			// If player.Flags does not have the FLAGS_PREFERENCE bit set return false
		{
			ReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to never be the activator");
		}
		else
		{
			ReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to receive i points per round", (player.Flags & FLAGS_FULLPOINTS) ? Points_FullAward : Points_PartialAward);
			// If player.Flags has the FLAGS_FULLPOINTS bit set return true, otherwise return false
		}
		
		PrintToConsole(client, " %s Your preference bit flags: Session: %b Stored: %b", SERVERMSG_PREFIX, (player.Flags & FLAGS_SESSION), (player.Flags & FLAGS_STORED));
		return Plugin_Handled;
	}
	
	char sArg1[2];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (StrEqual("?", sArg1))
		ReplyToCommand(client, "%t %t", "prefix", "usage of pref command");
	else
	{
		int iArg1 = StringToInt(sArg1);
		AdjustPreference(client, iArg1);
	}
	
	return Plugin_Handled;
}

void AdjustPreference(int client, int selection)
{
	Player player = new Player(client);
	
	switch (selection)
	{
		case 0:
		{
			player.Flags &= ~FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 0
			ReplyToCommand(client, "%t %t", "prefix_notice", "no longer receive queue points");
			LogMessage(" [DR] %N Has opted out of being the activator", player.Index);
		}
		case 1:
		{
			player.Flags |= FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 1
			player.Flags &= ~FLAGS_FULLPOINTS;
			// Set the FLAGS_FULLPOINTS bit to 0
			ReplyToCommand(client, "%t %t", "prefix_notice", "you will now receive fewer queue points");
			LogMessage(" [DR] %N Has opted to receive fewer queue points", player.Index);
		}
		case 2:
		{
			player.Flags |= FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 1
			player.Flags |= FLAGS_FULLPOINTS;
			// Set the FLAGS_FULLPOINTS bit to 1
			ReplyToCommand(client, "%t %t", "prefix_notice", "you will receive the maximum amount of queue points");
			LogMessage(" [DR] %N Has opted to receive full queue points", player.Index);
		}
	}	
}

// Toggle English language
Action Command_English(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	Player player = new Player(client);
	
	if ((player.Flags & FLAGS_ENGLISH))
	// If the player has the FLAGS_ENGLISH bit set return true
	{
		player.Flags &= ~FLAGS_ENGLISH;
		// Set the FLAGS_ENGLISH bit to 0
		char language[32];
		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
				ReplyToCommand(client, "%t When you next connect, your client language will be used", "prefix_notice");
			else
			{
				SetClientLanguage(client, iLanguage);
				ReplyToCommand(client, "%t Your client language of '%s' will now be used", "prefix_notice", language);
			}
		}
		return Plugin_Handled;
	}
	else
	{
		player.Flags |= FLAGS_ENGLISH;
		// Set the FLAGS_ENGLISH bit to 1
		ReplyToCommand(client, "%t Your language has been been set to English", "prefix_notice");
		SetClientLanguage(client, 0);
	}
	return Plugin_Handled;
}

// Show the contents of the player prefs and points arrays in client console
// Set my queue points multiplier and activator preference
Action Command_PlayerData(int client, int args)
{
	PrintToConsole(client, "\n %s Player points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.", SERVERMSG_PREFIX);
	PrintToConsole(client, " Index User ID   Name                              Points Flags (session, stored)");
	PrintToConsole(client, " -----------------------------------------------------------------------------------");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		char sName[MAX_NAME_LENGTH] = "<no player>";
		//if (IsValidEdict(i))
		//if (IsClientConnected(i))
		if (player.InGame)
			Format(sName, MAX_NAME_LENGTH, "%N", player.Index);
		PrintToConsole(client, " %4d | %6d | %32s | %4d | %b, %b", player.Index, player.ArrayUserID, sName, player.Points, (player.Flags & FLAGS_SESSION), (player.Flags & FLAGS_STORED));
	}
	
	PrintToConsole(client, " --------------------------------------------------------------------------------");
	ReplyToCommand(client, "%t Check console for output", "prefix_notice");
	
	return Plugin_Handled;
}

// Admin can award a player some queue points
Action AdminCommand_AwardPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	if (args != 2)
	{
		ReplyToCommand(client, "%t %t", "prefix", "wrong usage of award command");
		return Plugin_Handled;
	}
	
	char sArg1[MAX_NAME_LENGTH], sArg2[6];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iPoints = StringToInt(sArg2);
	
	int iTarget = FindTarget(client, sArg1, false, false);
	if (iTarget == -1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
		return Plugin_Handled;
	}
	else
	{
		Player player = new Player(iTarget);
		player.AddPoints(iPoints);
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(client, sTargetName, sizeof(sTargetName));
		
		PrintToChat(iTarget, "%t %t", "prefix_notice", "received queue points from an admin", sTargetName, iPoints, player.Points);
		
		ShowActivity(client, "Awarded %N %d queue points. New total: %d", iTarget, iPoints, player.Points);
		LogMessage("%L awarded %L %d queue points", client, iTarget, iPoints);
		
		return Plugin_Handled;
	}
}

// Reset the player database
Action AdminCommand_ResetDatabase(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(1, confirm, sizeof(confirm));
	
	if (!StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "%t To reset the database, supply the argument 'confirm'", "prefix_notice");
		return Plugin_Handled;
	}
	else if (StrEqual(confirm, "confirm", false))
	{	
		ReplyToCommand(client, "%t Resetting the player database...", "prefix_notice");
		game.ResetDB(client);
	}
	
	return Plugin_Handled;
}

// Reset a user (delete them from the database)
Action AdminCommand_ResetUser(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(2, confirm, sizeof(confirm));
	
	if (args != 2 || !StrEqual(confirm, "confirm"))
	{
		ReplyToCommand(client, "%t Usage: sm_resetuser <user> confirm", "prefix_notice");
		return Plugin_Handled;
	}
	else if (args == 2 && StrEqual(confirm, "confirm"))
	{
		char sPlayer[65];
		GetCmdArg(1, sPlayer, sizeof(sPlayer));
		
		int iTarget = FindTarget(client, sPlayer, true, false);
		if (iTarget == -1)
		{
			ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "%t Deleting %N from the database...", "prefix_notice", iTarget);
			Player player = new Player(iTarget);
			player.DeleteRecord(client);
		}
	}
	
	return Plugin_Handled;
}

/*/ Show the available commands
Action Command_Menu(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;

	ReplyToCommand(client, "%t No menu yet. Deathrun Toolkit is in development. Head to Discord to suggest things. https://discordapp.com/invite/3F7QADc", "prefix");
	ReplyToCommand(client, "%t Available commands: /points\x02, /reset\x02, /pref 0/1/2\x02.", "prefix");

	return Plugin_Handled;
}*/


/*	MENUS
---------------------------------------------------------------------------------------------------*/

// Open the menu
public Action Command_Menu(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Player player = new Player(client);
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "Deathrun Toolkit %s\n \nYou have %d points\n ", PLUGIN_VERSION, player.Points);

	Menu menu = new Menu(MenuHandlerMain);
	menu.SetTitle(sTitle);
	menu.AddItem("item1", "Activator Preferences");
	menu.AddItem("item2", "List Points");
	menu.AddItem("item3", "Reset My Points");
	menu.Display(player.Index, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

// Open the activator preference menu
public Action Command_MenuPreference(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Menu menu = new Menu(MenuHandlerPreference);
	menu.SetTitle("Activator Preference\n ");
	menu.AddItem("item1", "Full queue points");
	menu.AddItem("item2", "Fewer queue points");
	menu.AddItem("item3", "Don't be the activator");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

// Open the player points menu
public Action Command_MenuPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Menu menu = new Menu(MenuHandlerPoints);
	menu.SetTitle("List Points\n ");
	menu.ExitBackButton = true;

	int points_order[32][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	char sItem[40];
	
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(points_order[i][0]);
		if (player.InGame && (player.Flags & FLAGS_PREFERENCE))
		// If the player has FLAGS_PREFERENCE set to 1
		{
			Format(sItem, sizeof(sItem), "%N: %d", player.Index, player.Points);
			menu.AddItem("item", sItem, ITEMDRAW_DISABLED);
		}
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Open the points reset menu
public Action Command_MenuPointsReset(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Player player = new Player(client);
	char sTitle[100];
	Format(sTitle, sizeof(sTitle), "Reset My Points\n \nYou have %d points\n \nAre you sure you want\nto reset your points?\n ", player.Points);

	Menu menu = new Menu(MenuHandlerPointsReset);
	menu.SetTitle(sTitle);
	menu.AddItem("item1", "Yes");
	menu.AddItem("item2", "No");
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

/*	MENU HANDLERS
---------------------------------------------------------------------------------------------------*/

// The menu handler
public int MenuHandlerMain(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				Command_MenuPreference(param1, param2);
			if (StrEqual(info, "item2"))
				Command_MenuPoints(param1, param2);
			if (StrEqual(info, "item3"))
				Command_MenuPointsReset(param1, param2);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

// Activator preference menu handler
public int MenuHandlerPreference(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				AdjustPreference(param1, 2);
			if (StrEqual(info, "item2"))
				AdjustPreference(param1, 1);
			if (StrEqual(info, "item3"))
				AdjustPreference(param1, 0);
				
			Command_Menu(param1, param2);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}

// Queue points menu handler
public int MenuHandlerPoints(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}

// Points reset menu handler
public int MenuHandlerPointsReset(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				Command_ResetPoints(param1, 0);
				
			Command_Menu(param1, param2);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}