/**
 * Library Includes
 * ----------------------------------------------------------------------------------------------------
 */

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>		// Used to set player and weapon attributes
#tryinclude <Source-Chat-Relay>	// Discord relay

#undef REQUIRE_EXTENSIONS
#tryinclude <steamtools>		// Used to set the game description
#tryinclude <tf2items>			// Used to replace or issue weapons
#tryinclude <tf2_stocks>		// OF




/**
 * Compile Preprocessor Directives
 * ----------------------------------------------------------------------------------------------------
 */

#pragma semicolon 1
#pragma newdecls required




/**
 * Definitions
 * ----------------------------------------------------------------------------------------------------
 */

#define DEBUG

#define SQLITE_DATABASE		"sourcemod-local"
#define SQLITE_TABLE		"dtk_players"

#define TF2MAXPLAYERS		34		// 32 clients and 1 Source TV client, offset by 1 for matching array indexes
#define MINIMUM_ACTIVATORS 	3		// This or below number of willing activators and we use the turn-based system
#define HEALTH_SCALE_BASE	300.0	// The base value used in the activator health scaling system




/**
 * Enumerations
 * ----------------------------------------------------------------------------------------------------
 */

enum {
	Points_Starting = 10,		// Queue points a player receives when connecting for the first time
	Points_FullAward = 10,		// Queue ponts awarded on round end
	Points_PartialAward = 5,	// Smaller amount of round end queue points awarded
	Points_Consumed = 0,		// The points a selected activator is left with
}

/**
 * Default Class Run Speeds
 *
 * Used when calculating what float value to set the run speed attribute to, if used.
 * Included here in case Valve changes a class's run speed.
 */
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
}

/**
 * Life States
 *
 * Values of player property m_lifeState. Descriptions from SDK 2013
 */
enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
	LifeState_Any = 255		// A custom value used for our purposes
}

/**
 * Team Numbers
 *
 * The first four match TF2 and OF team numbers. The others are custom for use by our plugin.
 * Team 255 is also used by TF2 when broadcasting audio events to all players.
 */
enum {
	Team_None,
	Team_Spec,
	Team_Red,
	Team_Blue,
	Team_Both,
	Team_All = 255
}

// Health Bar Array
enum {
	HealthBar_Health,
	HealthBar_MaxHealth,
	HealthBar_Health2,
	HealthBar_MaxHealth2,
	HealthBar_PlayerResource,
	HealthBar_ArraySize,
}

// Player Data Array
enum {
	Player_Index,
	Player_ID,
	Player_Points,
	Player_Flags,
	Player_ArrayMax
}

/**
 * Games
 *
 * Used by some functions to do different things depending on the game the plugin is running on.
 */
enum {
	Game_TF,
	Game_OF
}

/**
 * Open Fortress Round States
 *
 * Not currently used because I don't know how to get the round state from OF.
 */
/*enum OFRoundState {
	GR_STATE_INIT = 0,				// initialize the game, create teams
	GR_STATE_PREGAME = 1,			// Before players have joined the game. Periodically checks to see if enough players are ready
									// to start a game. Also reverts to this when there are no active players
	GR_STATE_STARTGAME = 2,			// The game is about to start, wait a bit and spawn everyone
	GR_STATE_PREROUND = 3,			// All players are respawned, frozen in place
	GR_STATE_RND_RUNNING = 4,		// Round is on, playing normally
	GR_STATE_TEAM_WIN = 5,			// Someone has won the round
	GR_STATE_RESTART = 6,			// Noone has won, manually restart the game, reset scores
	GR_STATE_STALEMATE = 7,			// Noone has won, restart the game
	GR_STATE_GAME_OVER = 8,			// Game is over, showing the scoreboard etc
	GR_STATE_BONUS = 9,				// Game is in a bonus state, transitioned to after a round ends
	GR_STATE_BETWEEN_RNDS = 10,		// Game is awaiting the next wave/round of a multi round experience
	GR_NUM_ROUND_STATES = 11
}*/




/**
 * Bit Masks
 * ----------------------------------------------------------------------------------------------------
 */

// Engineer buildings restriction ConVar
#define BUILDINGS_SENTRY			( 1 << 0 )
#define BUILDINGS_DISPENSER			( 1 << 1 )
#define BUILDINGS_TELE_ENTRANCE		( 1 << 2 )
#define BUILDINGS_TELE_EXIT			( 1 << 3 )

// Player preferences
#define FLAGS_PREFERENCE			( 1 << 0 )
#define FLAGS_FULLPOINTS			( 1 << 1 )
#define FLAGS_ENGLISH				( 1 << 4 )
#define FLAGS_DEFAULT				( FLAGS_PREFERENCE | FLAGS_FULLPOINTS )
//#define FLAGS_WELCOMED_OLD		( 1 << 3 )		// Not used anymore, shown for reference

// Session
#define FLAGS_WELCOMED		( 1 << 17 )
#define FLAGS_ARMED			( 1 << 18 )				// When a player has been given a weapon by a map instruction

/**
 * Bit Masks
 *
 * FLAGS_STORED are saved in the database. It's the first sixteen bits.
 * We only mask for specific bits so that old deprecated flags are not saved to the DB.
 * FLAGS_SESSION are only used while the player is on the server. Second sixteen bits.
 */
#define FLAGS_STORED				( FLAGS_PREFERENCE | FLAGS_FULLPOINTS | FLAGS_ENGLISH )
#define FLAGS_SESSION				( 0xFFFF0000 )




/**
 * Variables
 * ----------------------------------------------------------------------------------------------------
 */

bool g_bSteamTools;
bool g_bTF2Attributes;
bool g_bTF2Items;
bool g_bSCR;

bool g_bSettingsRead;
bool g_bBlueWarnedSuicide;
bool g_bWatchForPlayerChanges;
bool g_bHealthBarActive;
bool g_bRoundActive; 				// For OF until I find out how to check round state


int g_iGame;
int g_iHealthBar[HealthBar_ArraySize];
int g_iPlayerData[TF2MAXPLAYERS][Player_ArrayMax];
int g_iHealthBarTarget;				// TODO Replace with a global Player handle for the activator


ConVar g_cDebugMessages;
ConVar g_cUseSQL;					// Use SQLite store store points and prefs
ConVar g_cSCR;						// Use Discord relay for some events
ConVar g_cEnabled;					// The plugin's features are active
ConVar g_cAutoEnable;				// Automatically enable the plugin's features
ConVar g_cPreventBlueEscape;		// Blue can't suicide or switch teams when the round is active
ConVar g_cRedSpeed;					// Optionally set all red players' run speed
ConVar g_cRedScoutSpeed;			// Optionally cap red scout speed
ConVar g_cBlueSpeed;				// Run speed of blue players
ConVar g_cRedScoutDoubleJump;		// Optionally disable red scout double jump
ConVar g_cActivators;				// Number of activators (blue players. Recommended: 1)
ConVar g_cTeamMatePush;				// Players will push their team mates when touching them
ConVar g_cRedDemoChargeLimits;		// Reduce demoman charge duration or remove it
ConVar g_cRedSpyCloakLimits;		// Reduce cloak duration and increase regeneration time, or 'disable' both
ConVar g_cUsePointsSystem;			// Grant queue points to red players on round end, and make the player with the most points activator
ConVar g_cTeamPushOnRemaining;		// Enable team mate pushing when we reach a certain number of red players remaining
ConVar g_cRedMeleeOnly;				// Remove weapons other than melee from red players, and kill their entities
ConVar g_cChatKillFeed;				// Tell a player the classname (and targetname if it exists) of the entity that caused their death
ConVar g_cBlastPushing;				// Control blast force pushing, e.g. rocket jumping
ConVar g_cBuildings;				// Restrict engineer building types for both teams
ConVar g_cAllowEurekaEffect;		// Allow the Eureka Effect. If not, it will be replaced with a wrench.
ConVar g_cShowRoundStartMessage;	// Shows the round start messages
ConVar g_cUseActivatorHealthBar;	// Use the boss health bar for the blue player when they are damaged by other players.
ConVar g_cThermalThruster;			// Thermal thruster charge rate

ConVar g_cTeamsUnbalanceLimit;
ConVar g_cAutoBalance;
ConVar g_cScramble;
ConVar g_cArenaQueue;
ConVar g_cArenaFirstBlood;
ConVar g_cServerTeamMatePush;
ConVar g_cRoundWaitTime;
ConVar g_cHumansMustJoinTeam;


Handle hBarTimer = null;
Handle g_hHealthText;

Database g_db;




/**
 * Plugin Info
 * ----------------------------------------------------------------------------------------------------
 */

#define PLUGIN_VERSION 		"0.284"
#define PLUGIN_SHORTNAME 	"Deathrun Toolkit"				// Used in the server game description
#define PLUGIN_NAME 		"[DTK] Deathrun Toolkit Base"	// Used for the plugin info
#define SERVERMSG_PREFIX	"[DTK]"							// The prefix for server console messages
#define DEBUG_PREFIX		" [DTK debug]"					// The prefix for server console debugging messages

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "Basic functions for the deathrun game mode",
	version = PLUGIN_VERSION,
	url = ""
};




/**
 * DTK Includes
 * ----------------------------------------------------------------------------------------------------
 */

#include <dtk/methodmaps.sp>
#include <dtk/functions.sp>
#include <dtk/commands.sp>
#include <dtk/menus.sp>
#include <dtk>




/**
 * Plugin and Map Forwards
 * ----------------------------------------------------------------------------------------------------
 */

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char game_folder[32];
	
	GetGameFolderName(game_folder, sizeof(game_folder));
	
	if (StrEqual(game_folder, "tf", false))
	{
		g_iGame = Game_TF;
		PrintToServer("%s Team Fortress 2 detected", SERVERMSG_PREFIX);
	}
	else if (StrEqual(game_folder, "open_fortress", false))
	{
		g_iGame = Game_OF;
		PrintToServer("%s Open Fortress detected", SERVERMSG_PREFIX);
	}
	else
	{
		g_iGame = Game_OF;
		LogError("DTK is only designed for TF2 and Open Fortress so some things may not work!");
	}
	
	MarkNativeAsOptional("Steam_SetGameDescription");
	MarkNativeAsOptional("TF2Items_CreateItem");
	MarkNativeAsOptional("TF2Items_SetItemIndex");
	MarkNativeAsOptional("TF2Items_SetClassname");
	MarkNativeAsOptional("TF2Items_SetNumAttributes");
	MarkNativeAsOptional("TF2Items_SetQuality");
	MarkNativeAsOptional("TF2Items_SetLevel");
	MarkNativeAsOptional("TF2Items_GiveNamedItem");
	MarkNativeAsOptional("SCR_SendEvent");
	
	return APLRes_Success;
}



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
	g_cHumansMustJoinTeam 	= FindConVar("mp_humans_must_join_team");	// Forces players to join the specified team. Default is 'any'.
	
	if (g_iGame == Game_TF) g_cServerTeamMatePush = FindConVar("tf_avoidteammates_pushaway");	// Team mate collision ConVars...
	if (g_iGame == Game_OF) g_cServerTeamMatePush = FindConVar("of_teamplay_collision");		// Optionally enabled when there are a specific number of runners remaining
	
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
	
	// Add some console commands
	RegConsoleCmd("sm_drmenu", Command_NewMenu, "Opens the deathrun menu.");
	//RegConsoleCmd("sm_dr", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_dr", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_drtoggle", Command_NewMenu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegConsoleCmd("sm_prefs", Command_Preferences, "A shortcut command for setting your deathrun activator and points preference.");
	//RegConsoleCmd("sm_english", Command_English, "Toggle forcing English language plugin phrases.");
	//RegConsoleCmd("sm_drhelp", Command_Help, "Display a list of DTK commands.");
	RegAdminCmd("sm_setclass", AdminCommand_SetClass, ADMFLAG_SLAY, "Change a player's class using DTK's built in functions, which also apply the correct attributes");
	RegAdminCmd("sm_drdata", AdminCommand_PlayerData, ADMFLAG_SLAY, "Print to console the values in the prefs and points arrays.");
	RegAdminCmd("sm_draward", AdminCommand_AwardPoints, ADMFLAG_SLAY, "Award a poor person some deathrun queue points.");
	RegAdminCmd("sm_drresetdatabase", AdminCommand_ResetDatabase, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Reset the deathrun player database.");
	RegAdminCmd("sm_drresetuser", AdminCommand_ResetUser, ADMFLAG_CONVARS|ADMFLAG_CONFIG|ADMFLAG_RCON, "Deletes a player's data from the deathrun database table. They will be treated as a new player.");
	
	// Testing commands
	RegAdminCmd("sm_drscalehealth", AdminCommand_ScaleHealth, ADMFLAG_SLAY, "Scale the activator's health");
	
	g_hHealthText = CreateHudSynchronizer();
	
	LogMessage("%s %s has loaded", PLUGIN_NAME, PLUGIN_VERSION);
	PrintToChatAll("%t %s has loaded", "prefix_strong", PLUGIN_SHORTNAME);
}



public void OnAllPluginsLoaded()
{
	// Check for the existence of libraries that DTK can use
	if (!(g_bSteamTools = LibraryExists("SteamTools")))
		LogMessage("Library not found: SteamTools. Unable to change server game description");
	
	//if (!(g_bTF2Items = LibraryExists("TF2Items")))
	//	LogMessage("Library not found: TF2 Items. Unable to replace weapons");
	
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
	//if (StrEqual(name, "TF2Items"))
	//{
	//	g_bTF2Items = loaded;
	//}
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
 * OnMapStart
 *
 * Also called when the plugin loads late.
 */
public void OnMapStart()
{
	// Always run
	game.CreateDBTable();	// Create database table and open a connection
	game.PruneDB();			// Prune old table entries
	
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
	
	// If automatic enabling of the plugin based on the map prefix is disabled, exit OnMapStart now
	if (!g_cAutoEnable.BoolValue)
		return;
	
	// Detect if the map is using a deathrun prefix
	char mapname[32];
	GetCurrentMap(mapname, sizeof(mapname));
	
	if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
		{
			// This is a deathrun map
			g_cEnabled.SetBool(true);
			LogMessage("Detected a deathrun map");
			//if (g_bSteamTools) SetServerGameDescription();
		}
		else
		{
			// This is not a deathrun map
			LogMessage("Not a deathrun map. Deathrun functions will not be available");
			//if (g_bSteamTools) SetServerGameDescription();
		}
	
	// Only runs if deathrun is enabled
	if (g_cEnabled.BoolValue)
	{
		// Does the map have a tf_logic_arena?
		if (FindEntityByClassname(-1, "tf_logic_arena") == -1)
		{
			PrintToServer("%s This map does not have a tf_logic_arena", SERVERMSG_PREFIX);
			//g_cRoundWaitTime.SetInt(2);
		}
		
		EventsAndListeners(true);			// Hook events and command listeners
		SetServerCvars(true);				// Adjust server cvars for our player distribution functions to work smoothly
		g_bWatchForPlayerChanges = true;	// Watch for players connecting after the map change
			// This is necessary because the server doesn't fire a round reset or start event unless there are players
	}
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
}



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



/**
 * OnConfigsExecuted
 *
 * Execute config_dr.cfg when all other configs have loaded.
 */
public void OnConfigsExecuted()
{
	if (g_cEnabled.BoolValue)
	{
		ServerCommand("exec config_deathrun.cfg");
	}
}



/**
 * OnMapEnd
 *
 * NOT called when the plugn is unloaded.
 */
public void OnMapEnd()
{
	// Always run
	delete g_db;

	// If DTK was never enabled, no need to unhook events or change cvars
	if (!g_cEnabled.BoolValue)
		return;
	
	// Unhook events and restore cvars when the map switches
	EventsAndListeners(false);
	SetServerCvars(false);
	g_cEnabled.SetBool(false);	// DTK is now disabled
		// Can we put the event hooking and cvar changing into the enable/disable cvar change?
	
	LogMessage("The deathrun map has come to an end. Restoring some cvars to their default values");
}



public void OnPluginEnd()
{
	// Upload user data if plugin is unloaded
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		player.OnDisconnect();
	}
	
	PrintToChatAll("%t %s has been unloaded", "prefix_strong", PLUGIN_SHORTNAME);

	if (g_cEnabled.BoolValue)
		SetServerCvars(false);
		// No need to unhook events as this is done on plugin unload
	
	LogMessage("Plugin has been unloaded");
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
	
	PrintToServer("%s Waiting for players time has ended", SERVERMSG_PREFIX);
}



public void OnClientAuthorized(int client, const char[] auth)
{
	Player player = new Player(client);
	player.Initialize();
		// Retrive stored data or set up a new record. Give player default session flags
}



public void OnClientPutInServer(int client)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	Player player = new Player(client);
	player.HookDamage();
}



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
 * Hooked Game Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s The round has restarted", SERVERMSG_PREFIX);
	
	//g_bIsRoundActive = false;			// Essentially this is pre-round prep/freeze time
	
	healthbar = new HealthBar();
	HookLogicCases();
	
	g_iHealthBarTarget = -1;
	SetHealthBar();
	
	// Read settings and apply attributes
	// This prevents players from receiving attributes twice because they spawn twice at round reset
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			Player player = new Player(i);
			ApplyPlayerAttributes(player);
		}
	}
	g_bSettingsRead = true;				// Players won't receive attributes until settings have been read
	
	SetServerCvars(true);				// Make sure required cvars for the game mode are set on every round
	CheckForPlayers();					// Perform player number checking and begin team distribuiton
	
	// Set the value of the 'dtk_enabled' logic_branch to 1/true
	// TODO Move this to the Game method
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
}

// Entity health bar stuff
// Just putting it here for now while we make sure it works
void EntityHealthBar(const char[] output, int caller, int activator, float delay)
{
	if (StrEqual(output, "OnUser1", false))
	{
		healthbar.SetColor(0);
	}
	if (StrEqual(output, "OnUser2", false))
	{
		healthbar.SetColor(1);
	}
	if (StrEqual(output, "OutValue", false))	// TODO: Put this into a methodmap function
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
	
	if (StrEqual(output, "OnTrigger", false))
	{
		char targetname[MAX_NAME_LENGTH];
		GetEntPropString(caller, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrEqual(targetname, "dtk_health_scalemax", false))
		{
			Player Activator = new Player(g_iHealthBarTarget);
			Activator.ScaleHealth(3);
		}
		else if (StrEqual(targetname, "dtk_health_scaleoverheal", false))
		{
			// TODO Grab the mode from somewhere
			Player Activator = new Player(g_iHealthBarTarget);
			Activator.ScaleHealth(1);
		}
	}
}



void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bBlueWarnedSuicide = false;		// Reset the warning given to blue when trying to quit
	g_bWatchForPlayerChanges = false;	// No need to watch for team changes now
	
	if (g_cShowRoundStartMessage.BoolValue)
		RoundActiveMessage();			// Fire the function that cycles through round start messages
		
	RequestFrame(CheckGameState);		// Count players for the player pushing cvar
	
	PrintToServer("%s The round is now active", SERVERMSG_PREFIX);
	if (g_bSCR && g_cSCR.BoolValue)
		SCR_SendEvent(SERVERMSG_PREFIX, "The round is now active");
	
	g_bRoundActive = true;				// Open Fortress Gamerules property doesn't work yet
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
	
	DisplayNextActivators();	// TODO: Don't display this if the map is about to change
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("%s The round has ended", SERVERMSG_PREFIX);
	if (g_bSCR && g_cSCR.BoolValue)
		SCR_SendEvent(SERVERMSG_PREFIX, "The round has ended");
		
	g_bRoundActive = false;		// Open Fortress Gamerules property doesn't work yet
}




/**
 * Hooked Player Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	// Server console information that a player has newly-connected
	char sName[MAX_NAME_LENGTH], sSteamID[128];
	event.GetString("name", sName, sizeof(sName));
	event.GetString("networkid", sSteamID, sizeof(sSteamID));
	PrintToServer("%s %s has connected (Steam ID: %s)", SERVERMSG_PREFIX, sName, sSteamID);
}



void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	
	if (g_bSettingsRead)
	{
		RequestFrame(ApplyPlayerAttributes, player);
	}
	
	RequestFrame(CheckGameState);
}



void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	Player player = new Player(client);
	
	RequestFrame(NextFrame_InventoryApplied, player);
}

void NextFrame_InventoryApplied(Player player)
{
	// Melee only
	if (g_cRedMeleeOnly.BoolValue)
	{
		if (player.Team == Team_Red)
		{
			player.MeleeOnly();
		}
		else
		{
			player.SetSlot(TFWeaponSlot_Primary);
		}
	}
	else
	{
		player.SetSlot(TFWeaponSlot_Primary);
	}
	
	// Boss health bar
	if (g_bHealthBarActive == true && player.Index == g_iHealthBarTarget)
		SetHealthBar();
	
	// Don't do weapon checks if a weapon has been given by the map
	if (player.Flags & FLAGS_ARMED)
		// If the player has FLAGS_ARMED
	{
		player.Flags &= ~FLAGS_ARMED;
			// Remove the FLAGS_ARMED bit by doing an AND NOT comparison
		DebugMessage("post_inventory_application function was stopped before it could do weapon checks");
		return;
	}
	
	/**
	 * Weapon Checks
	 *
	 * In future I'd like to do different things depending on the weapon and have the things in a KV file.
	 */
	
	/*
		Attributes
		Replace
		Hook Damage?
	*/
	
	int weapon;
	int itemDefIndex;
	
	// Secondary weapon checks
	if ((weapon = player.GetWeapon(TFWeaponSlot_Secondary)) != -1)
	{
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	switch (itemDefIndex)
	{
		case 1179:		// Thermal thruster
		{
			if (g_bTF2Attributes)
				switch (g_cThermalThruster.IntValue)
				{
					case 0: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", -1.0);	// Charges are drained rendering the weapon unuseable
					case 1: TF2Attrib_RemoveByName(weapon, "item_meter_charge_rate");		// Use normal charging behaviour
					case 2: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 120.0);	// Charges take one minute to charge
					case 3: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.0);		// The player only has two charges
				}
		}
		case 812, 833:	// Cleaver
		{
			ReplaceWeapon(player.Index, weapon, 23, "tf_weapon_pistol");
		}
	}
	
	
	// Melee weapon checks
	if ((weapon = player.GetWeapon(TFWeaponSlot_Melee)) != -1)
	{
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	switch (itemDefIndex)
	{
		case 589:	// Eureka Effect
		{
			if (!g_cAllowEurekaEffect.BoolValue)
			{
				ReplaceWeapon(player.Index, weapon, 7, "tf_weapon_wrench");
			}
		}
	}
}



/**
 * TF2Items_OnGiveNamedItem
 *
 * TF2 Items calls this when a player recieves a weapon.
 */
/*public Action TF2Items_OnGiveNamedItem(int client, char[] classname, int itemDefIndex, Handle &hItem)
{
	static Handle previousItem = null;
	
	// I think we are closing a clone of the previous hItem handle to stop leaks
	if (previousItem != null)
	{
		CloseHandle(previousItem);
		previousItem = null;
	}
	
	// If hItem is already being used to replace a weapon, continue using its values
	if (hItem != null)
	{
		return Plugin_Continue;
	}
	
	// Weapon replacements
	switch (itemDefIndex)
	{
		case 589:	// Eureka Effect
		{
			if (!g_cAllowEurekaEffect.BoolValue)
			{
				hItem = TF2Items_CreateItem(OVERRIDE_ITEM_DEF);
				TF2Items_SetItemIndex(hItem, 7);	// Wrench
				previousItem = hItem;
				return Plugin_Changed;
			}
		}
	}
	
	return Plugin_Continue;
}*/



/**
 * player_hurt
 *
 * Added for the health bar to function in Open Fortress.
 * This is NOT hooked if the game is TF2.
 */
void Event_PlayerDamaged(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_cUseActivatorHealthBar.BoolValue)
	{
		if (attacker != victim && victim == g_iHealthBarTarget)
		{
			g_bHealthBarActive = true;
			RequestFrame(SetHealthBar);
		}
	}
}



void Event_PlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("patient")));
	
	if (player.Index == g_iHealthBarTarget)
		RequestFrame(SetHealthBar);
}



void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	// The class change event fires when the player enters the game properly for the first time
	// This is the best time to display welcome information to them
	
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	player.Welcome();
}



void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	/*
		Open Fortress death event
		
		Server event "player_death", Tick 2942:
		- "userid" = "2"
		- "attacker" = "0"
		- "weapon" = "trigger_hurt"
		- "damagebits" = "0"
		- "customkill" = "0"
		- "assister" = "-1"
		- "dominated" = "0"
		- "assister_dominated" = "0"
		- "revenge" = "0"
		- "assister_revenge" = "0"
		- "killer_pupkills" = "0"
		- "killer_kspree" = "0"
		- "victim_pupkills" = "-1"
		- "victim_kspree" = "0"
		- "ex_streak" = "0"
		- "firstblood" = "1"
		- "midair" = "0"
		- "humiliation" = "0"
		- "kamikaze" = "0"
	*/
	
	
	//int victim = event.GetInt("victim_entindex");
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	// Chat kill feed
	if (g_cChatKillFeed.BoolValue)
	{
		if (event.GetInt("attacker") == 0)	// If killed by the world, not a player
		{
			char classname[MAX_NAME_LENGTH];
			
			if (g_iGame == Game_TF) event.GetString("weapon_logclassname", classname, sizeof(classname));
			if (g_iGame == Game_OF) event.GetString("weapon", classname, sizeof(classname));
			
			if (classname[0] != 'w')	// Filter out 'world' as the killer entity because dying from fall damage is obvious
			{
				char targetname[MAX_NAME_LENGTH];
				
				if (g_iGame == Game_TF)
				{
					GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
			
					if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
						Format(targetname, sizeof(targetname), " (%s)", targetname);
				}
				
				PrintToChat(victim, "%t %t", "prefix", "killed by entity classname", classname, targetname);
			}
		}
	}
	
	// Check for live players remaining and enable team pushing at some amount
	RequestFrame(CheckGameState);
	
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
	if (g_bWatchForPlayerChanges)	// TODO Can this be replaced by a roundstate check?
		RequestFrame(CheckForPlayers);
}



void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	// Display Steam ID of disconnecting player in server console
	char sName[32], sSteamID[64], sReason[64];
	event.GetString("name", sName, sizeof(sName));
	event.GetString("networkid", sSteamID, sizeof(sSteamID));
	event.GetString("reason", sReason, sizeof(sReason));
	
	PrintToServer("%s %s has disconnected (Steam ID: %s - Reason: %s)", SERVERMSG_PREFIX, sName, sSteamID, sReason);
}



Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bChanged;

	// Adjust boss health bar
	if (g_cUseActivatorHealthBar.BoolValue)
	{
		if (attacker != victim && victim == g_iHealthBarTarget)
		{
			g_bHealthBarActive = true;
			RequestFrame(SetHealthBar);
		}
	}
	
	// Cap backstab damage on the activator at 300
	if (damagecustom == TF_CUSTOM_BACKSTAB && victim == g_iHealthBarTarget)
	{
		damage = 100.0;
		bChanged = true;
	}
	
	// Blast pushing prevention
	if (GetClientTeam(victim) == Team_Red && attacker == victim)
	{
		switch (g_cBlastPushing.IntValue)
		{
			case 0:						// Negate blast pushing
			{
				damage = 0.0;
			}
			case 1:						// Allow blast pushing
			{
				return Plugin_Continue;
			}
			case 2:						// Reduce blast pushing
			{
				switch (TF2_GetPlayerClass(victim))
				{
					case TFClass_Soldier:
					{
						if (damage > 35)
							damage = 35.0;
					}
					case TFClass_DemoMan:	// TODO Find a better way of controlling sticky jump distance
					{
						damage = 2.2;
					}
				}
			}
		}
		bChanged = true;
	}
	
	if (bChanged)
		return Plugin_Changed;
	else
		return Plugin_Continue;
}




/**
 * Command Listeners
 * ----------------------------------------------------------------------------------------------------
 */

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







