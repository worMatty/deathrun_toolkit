#pragma semicolon 1

#define DEBUG // what does this do?
#define PLUGIN_VERSION "0.25"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
//#include <sdkhooks>
#include <tf2attributes>	// Needed to set attributes
#include <steamtools>		// Needed to set the game description
//#include <colorlib>		// ColorLib https://github.com/c0rp3n/colorlib-sm
#include <multicolors>		// https://github.com/Bara/Multi-Colors

public Plugin myinfo = 
{
	name = "Deathrun Toolkit Base",
	author = "worMatty",
	description = "Basic functions for the deathrun game mode.",
	version = PLUGIN_VERSION,
	url = ""
};

/*

	Todo:
	-----
	
	3. Limit certain abilities.
		Dead Ringer. (maybe make the spy go slow for a bit after using it)
		Rocket and sticky jumping.
		Cleaver?
	
	4. Glow
		Give mapper control.
	
	5. Cancel fall damage ONLY on certain maps.
	
	9. Points deposit system accessible by other plugins.
	
	10. Points system could be 'Insanity'
	
	11. Suppress 'joined team <team>' messages
	
	12. Handle waiting for players time.
	
	16. Display attribute messages once during freeze time after a delay as long as the attributes are still there.
		(team mover)
	
	17. Give the user the option to toggle the language to English rather than their own. Find out how SM chooses a language. cl_language
	
	18. Make some logic where if no one wants to be the activator, a puppet bot is spawned instead.

	23. See about making my own events.
	
	24. Force someone to not be an activator.
	
	25. Make the plugin's functionality depend on an 'enabled' cvar which when changed triggers the setup or close down logic.
	
	28. Strip ammo from players.
	
	29. Show a message to players when they connect to remind them of the menu.
	
	30. Add in some protection for situations where no player has any points. Revert to a turn-based system.
	
	31. Optionally offload points to a database using a universal points system that can be used by other modes.
	
	32. Implement some basic events like forced class switching.

	33. Implement some basic map entity settings.
	
	34. Research whether convars are best used when checking values during functions and if using one convar handle for multiple
		convars is better than creating one handle per convar.
	
	35. Optionally limit or block engi builds.
	
	36. Optionally limit or block extra movement abilities (rocket jumping, jetpack)
	
	38. Translations.
	
	39. Admin menu.

	40. Help info for commands.
	
	41. Make a list of all 50/50 entities in a map and let people vote on whether to enable them.
	
	42. Repurpose next activator function so it can be used as a command. /next /nextdeath /nd
	
	43. Consider not granting points to players when they join.
	
	44. Consider asking players if they would like to reset their queue points if they choose not to be activator.
	
	45. Respawning stuff for no tf_logic_arena.

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
	
	Not showing all player points in console.
	
	If the plugin is loaded during a game, when players are already on the server, their preferences are apparently not recorded properly.
	
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
	
*/


// Default class run speeds
enum {
	RunSpeed_Scout = 400,
	RunSpeed_Sniper = 300,
	RunSpeed_Soldier = 240,
	RunSpeed_DemoMan = 280,
	RunSpeed_Medic = 320,
	RunSpeed_Heavy = 230,
	RunSpeed_Pyro = 300,
	RunSpeed_Spy = 320,
	RunSpeed_Engineer = 300
}

// Global variables
static bool g_bIsDeathrunMap;
static bool g_bIsRoundActive;
static bool g_bSettingsRead;
static bool g_bBlueWarnedSuicide;
//static bool g_bHasTFLogicArena;		// Will be used in future to handle respawning for new map types
static bool g_bWatchForPlayerChanges;
static bool g_bIsRedGlowActive;
//static bool g_bRedMeleeOnly;

// Player points and bit flag arrays
static int g_iPoints[33];
static int g_iFlags[33];

#define POINTS_STARTING 10		// Starting points for players when they connect.
#define POINTS_AWARD_FULL 10	// Points awarded to red players at the end of a round.
#define POINTS_AWARD_FEWER 5	// Same as above but for players who opt to get fewer points.
#define POINTS_CONSUMED 0		// When a player is made the activator their points are reset to this value.
#define MINIMUM_ACTIVATORS 2	// This or below number of willing activators and we use the turn-based system

#define PLAYERFLAG_CONNECTED			(1 << 0)
#define PLAYERFLAG_PREFERENCE			(1 << 1)
#define PLAYERFLAG_FULLPOINTS			(1 << 2)
#define PLAYERFLAG_TURN					(1 << 3)
#define PLAYERFLAG_WARNEDBLUESUICIDE	(1 << 4)
#define PLAYERFLAG_WARNEDBUILD			(1 << 5)
#define PLAYERFLAG_FORCEDNOTACTIVATOR	(1 << 6)
#define PLAYERFLAG_ENGLISHLANGUAGE		(1 << 7)
#define PLAYERFLAG_WELCOMED				(1 << 8)

// Plugin cvars
ConVar g_cvarPreventBlueEscape;		// Blue can't suicide or switch teams when the round is active
ConVar g_cvarRedSpeed;				// Optionally set all red players' run speed
ConVar g_cvarRedScoutSpeed;			// Optionally cap red scout speed
ConVar g_cvarBlueSpeed;				// Run speed of blue players
ConVar g_cvarRedScoutDoubleJump;	// Optionally disable red scout double jump
ConVar g_cvarActivators;			// Number of activators (blue players. Recommended: 1)
ConVar g_cvarTeamMatePush;			// Players will push their team mates when touching them
ConVar g_cvarRedDemoChargeLimits;	// Reduce demoman charge duration or remove it
ConVar g_cvarRedSpyCloakLimits;		// Reduce cloak duration and increase regeneration time, or 'disable' both
ConVar g_cvarUsePointsSystem;		// Grant queue points to red players on round end, and make the player with the most points activator
ConVar g_cvarTeamPushOnRemaining;	// Enable team mate pushing when we reach a certain number of red players remaining
ConVar g_cvarRedGlowRemaining;		// Enable a glow on red players when we reach a certain number remaining
ConVar g_cvarRedGlow;				// Permanently enable a red glow on red players
ConVar g_cvarRedMeleeOnly;			// Remove weapons other than melee from red players, and kill their entities
ConVar g_cvarChatKillFeed;			// Tell a player the classname (and targetname if it exists) of the entity that caused their death

// Server cvars
ConVar g_cvarTeamsUnbalanceLimit;
ConVar g_cvarAutoBalance;
ConVar g_cvarScramble;
ConVar g_cvarArenaQueue;
ConVar g_cvarArenaFirstBlood;
ConVar g_cvarAirDashCount;
ConVar g_cvarServerTeamMatePush;
ConVar g_cvarRoundWaitTime;
ConVar g_cvarHumansMustJoinTeam;


/*	PLUGIN AND MAP FORWARDS
---------------------------------------------------------------------------------------------------*/

// OnPluginStart
public void OnPluginStart()
{
	LoadTranslations("dtk-base.phrases");
	LoadTranslations("common.phrases");
	
	// Handle server cvars
	g_cvarTeamsUnbalanceLimit = FindConVar("mp_teams_unbalance_limit"); 	// 1 (0-30) - Teams are unbalanced when one team has this many more players than the other team. (0 disables check)
	g_cvarAutoBalance = FindConVar("mp_autoteambalance"); 					// 1 (0-2) - Automatically balance the teams based on mp_teams_unbalance_limit. 0 = off, 1 = forcibly switch, 2 = ask volunteers
	g_cvarScramble = FindConVar("mp_scrambleteams_auto"); 					// 1 - Server will automatically scramble the teams if criteria met.  Only works on dedicated servers.
	g_cvarArenaQueue = FindConVar("tf_arena_use_queue"); 					// 1 - Enables the spectator queue system for Arena.
	g_cvarArenaFirstBlood = FindConVar("tf_arena_first_blood"); 			// 1 - Rewards the first player to get a kill each round.
	g_cvarAirDashCount = FindConVar("tf_scout_air_dash_count"); 			// A hidden cvar which toggles scout double jump. Used for advice only.
	g_cvarServerTeamMatePush = FindConVar("tf_avoidteammates_pushaway"); 	// 1 - Whether or not teammates push each other away when occupying the same space
	g_cvarRoundWaitTime = FindConVar("mp_enableroundwaittime"); 			// 1 - The time at the beginning of the round, while players are frozen.
	g_cvarHumansMustJoinTeam = FindConVar("mp_humans_must_join_team");		// Forces players to join the specified team. Default is 'any'.
	
	// Register console variables
	CreateConVar("sm_dt_version", PLUGIN_VERSION);
	g_cvarPreventBlueEscape = CreateConVar("sm_dt_preventblueescape", "1", "Prevent the blue player from escaping their role during a round by suicide or switching team.", _, true, 0.0, true, 1.0);
	g_cvarRedSpeed = CreateConVar("sm_dt_redspeed", "0", "Set the speed red players should run in units per second. 0 is off.", _, true, 0.0, true, 750.0);
	g_cvarRedScoutSpeed = CreateConVar("sm_dt_redscoutspeed", "320", "Cap red Scout speed to this value. Ignored if sm_dt_redspeed is set. 0 is off.", _, true, 0.0, true, 750.0);
	g_cvarBlueSpeed = CreateConVar("sm_dt_bluespeed", "420", "Set blue run speed in units per second. 0 is off.", _, true, 0.0, true, 750.0);
	g_cvarRedScoutDoubleJump = CreateConVar("sm_dt_redscoutdoublejump", "0", "Allow red scouts to double jump. 0 = NO. 1 = YES.", _, true, 0.0, true, 1.0);
	g_cvarActivators = CreateConVar("sm_dt_activators", "1", "Number of activators (players on blue team). Setting to 0 will cause continual round resets on maps with a tf_logic_arena.", _, true, 0.0, true, 15.0);
	g_cvarTeamMatePush = CreateConVar("sm_dt_teampush", "0", "Team mate pushing", _, true, 0.0, true, 1.0);
	g_cvarRedDemoChargeLimits = CreateConVar("sm_dt_reddemocharge", "2", "Place limits on red demo charges. 0 = No charging. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cvarRedSpyCloakLimits = CreateConVar("sm_dt_redspycloak", "2", "Place limits on red spy cloaking. 1 = Regular behaviour. 2 = Limit duration and regeneration.", _, true, 0.0, true, 2.0);
	g_cvarUsePointsSystem = CreateConVar("sm_dt_usepoints", "1", "Use the new points system for activator selection.", _, true, 0.0, true, 1.0);
	g_cvarTeamPushOnRemaining = CreateConVar("sm_dt_teampush_remaining", "5", "Number of players remaining on Red to activate team pushing. 0 = off.", _, true, 0.0, true, 30.0);
	g_cvarRedGlowRemaining = CreateConVar("sm_dt_redglow_remaining", "3", "Number of players remaining on Red to activate glow outline. 0 = off.", _, true, 0.0, true, 30.0);
	g_cvarRedGlow = CreateConVar("sm_dt_redglow", "0", "Make red players have a glowing outline for better visibility in maps with poorly designed activator corridors. 1 = on, 0 = off.", _, true, 0.0, true, 1.0);
	g_cvarRedMeleeOnly = CreateConVar("sm_dt_redmeleeonly", "0", "Restrict red players to melee weapons.", _, true, 0.0, true, 1.0);
	g_cvarChatKillFeed = CreateConVar("sm_dt_chatkillfeed", "1", "Show clients the classname and targetname of the entity that killed them.", _, true, 0.0, true, 1.0);
	
	// Hook some convars
	g_cvarTeamMatePush.AddChangeHook(ConVarChangeHook);
	
	// Add some console commands
	RegConsoleCmd("sm_drmenu", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_dr", Command_Menu, "Opens the deathrun menu.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_pts", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegConsoleCmd("sm_pref", Command_ActivatorModifier, "Select your activator queue points gain preference. 0/1/2.");
	RegAdminCmd("sm_giveqp", Command_GivePointsAdmin, ADMFLAG_SLAY, "Give a peon some pity points.");
}

// OnMapStart
public void OnMapStart()
{
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
		strncmp(mapname, "workshop/vsh_deathrun_", 22, false) == 0)
		{
			// This is a deathrun map
			g_bIsDeathrunMap = true;
			LogMessage("Detected a deathrun map.");
			Steam_SetGameDescription("Deathrun Toolkit");
		}
		else
		{
			// This is not a deathrun map
			g_bIsDeathrunMap = false;
			LogMessage("Not a deathrun map. Deathrun functions will not be available.");
			Steam_SetGameDescription("Team Fortress");
		}
	
	if (g_bIsDeathrunMap)
	{
		// Does the map have a tf_logic_arena?
		if (FindEntityByClassname(-1, "tf_logic_arena") == -1)
		{
			LogMessage("Map doesn't have a tf_logic_arena. Handling some things a bit differently.");
			//g_bHasTFLogicArena = false;
			g_cvarRoundWaitTime.SetInt(2);
		}
		//else
			//g_bHasTFLogicArena = true;
		
		EventsAndListeners(true);
		SetServerCvars(1);
	}
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
}

// TF2 WaitingForPlayersTime finishes
public void TF2_OnWaitingForPlayersEnd()
{
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("  [DR] Waiting for players time has ended");
}

// OnClientPutInServer
public void OnClientPutInServer(int client)
{
	if (g_bIsDeathrunMap && (g_iFlags[client] & PLAYERFLAG_WELCOMED) != PLAYERFLAG_WELCOMED)
	{
		int userid = GetClientUserId(client);
		CreateTimer(30.0, WelcomeMessage, userid);
	}
}

// OnMapEnd
public void OnMapEnd()
{
	if (!g_bIsDeathrunMap)
		return;
	
	// Close handles and restore cvars when the map switches
	EventsAndListeners(false);
	SetServerCvars(0);
	LogMessage("OnMapEnd has been called on a deathrun map. Restoring cvars.");
}

// OnPluginEnd
public void OnPluginEnd()
{
	if (g_bIsDeathrunMap)
		SetServerCvars(0);
	
	LogMessage("Plugin has been unloaded.");
}



/*	GAME EVENTS
---------------------------------------------------------------------------------------------------*/

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("  [DR] Round has restarted.");
	
	g_bIsRoundActive = false;			// Essentially this is pre-round prep/freeze time
	g_bIsRedGlowActive = false;
	//g_bRedMeleeOnly = g_cvarRedMeleeOnly.BoolValue;
	
	// Read settings and apply attributes
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			ApplyAttributes(i);
	}
	g_bSettingsRead = true;				// Players won't receive attributes until settings have been read
	
	SetServerCvars(1);					// Make sure required cvars for the game mode are set on every round
	CheckForPlayers();					// Perform player number checking and begin team distribuiton
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = true;			// The round is now active
	g_bBlueWarnedSuicide = false;		// Reset the warning given to blue when trying to quit
	g_bWatchForPlayerChanges = false;	// No need to watch for team changes now
	
	RoundActiveMessage();				// Fire the function that cycles through round start messages
	CheckGameState();					// Count players and apply some settings like pushing and glow
	
	if (g_cvarRedGlow.BoolValue)		// Turn on red glow if the cvar is set to true
	{
		g_bIsRedGlowActive = true;
		
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red)
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
	}
	
	PrintToServer("  [DR] Round is now active.");
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// Give players points
	if (g_cvarUsePointsSystem.BoolValue == true)
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red && (g_iFlags[i] & PLAYERFLAG_PREFERENCE) == PLAYERFLAG_PREFERENCE)
			{
				int awarded = (g_iFlags[i] & PLAYERFLAG_FULLPOINTS) ? POINTS_AWARD_FULL : POINTS_AWARD_FEWER;
				g_iPoints[i] += awarded;
				CPrintToChat(i, "%t %t", "prefix", "round end queue points received", awarded, g_iPoints[i]);
			}
	
	DisplayNextActivators();
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("  [DR] Round has ended");
}


/*	PLAYER EVENTS
---------------------------------------------------------------------------------------------------*/

void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	// Reset points and preferences for new clients on connecting for the first time
	int client = event.GetInt("index") + 1;
	g_iPoints[client] = POINTS_STARTING;
	g_iFlags[client] |= PLAYERFLAG_CONNECTED | PLAYERFLAG_PREFERENCE | PLAYERFLAG_FULLPOINTS & ~(PLAYERFLAG_TURN | PLAYERFLAG_WARNEDBLUESUICIDE | PLAYERFLAG_WARNEDBUILD | PLAYERFLAG_FORCEDNOTACTIVATOR | PLAYERFLAG_ENGLISHLANGUAGE | PLAYERFLAG_WELCOMED);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_bSettingsRead)
		ApplyAttributes(client);
	
	// Remove a glow from the previous round
	SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1); // Not working!
	
	// Check if it's necessary to make the player glow
	RequestFrame(CheckForGlow, client);
}

Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	if (g_cvarRedMeleeOnly.BoolValue)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		if (TF2_GetClientTeam(client) == TFTeam_Red)
			MeleeOnly(client);
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	// Chat kill feed
	if (g_cvarChatKillFeed)
		if (event.GetInt("attacker") == 0)	// Killed by world
		{
			char classname[MAX_NAME_LENGTH];
			event.GetString("weapon_logclassname", classname, sizeof(classname));	// Get the killer entity's classname
			
			char targetname[MAX_NAME_LENGTH];										// Get the targetname if it exists
			GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
	
			if (strlen(targetname) > 0)	// If there is a targetname, reformat a string to include it
				Format(targetname, sizeof(targetname), " (%s)", targetname);
			
			CPrintToChat(event.GetInt("victim_entindex"), "%t %t", "prefix", "killed by entity classname", classname, targetname);
		}
	
	CheckGameState();	// Check for live players remaining and enable team pushing at some amount
}

void Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	// If we're watching for player changes during freeze time:
	if (g_bWatchForPlayerChanges)
		CheckForPlayers();
}

void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	// Reset queue points
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iPoints[client] = 0;
	g_iFlags[client] = 0;
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
	if (g_bIsDeathrunMap)
		if (condition == TFCond_Cloaked && g_bIsRedGlowActive && TF2_GetClientTeam(client) == TFTeam_Red)
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0, 1);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (g_bIsDeathrunMap)
		if (condition == TFCond_Cloaked && g_bIsRedGlowActive && TF2_GetClientTeam(client) == TFTeam_Red)
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
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
Action WelcomeMessage(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (client == 0 || (g_iFlags[client] & PLAYERFLAG_WELCOMED) == PLAYERFLAG_WELCOMED)	// Just in case connecting caused multiple timer fires
		return;
	
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	CPrintToChat(client, "%t %t", "prefix_notice", "welcome player to deathrun toolkit", name);
	g_iFlags[client] |= PLAYERFLAG_WELCOMED;
}

// Check to see if it's necessary to make the player glow
void CheckForGlow(int client)
{
	if (g_bIsRedGlowActive || g_cvarRedGlow.BoolValue)
		if (TF2_GetClientTeam(client) == TFTeam_Red)
		{
			SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1, 1);
			PrintToServer("  [DR] %N just spawned and was made to glow.", client);
		}
}

// Check if we have enough players
CheckForPlayers()
{
	static bool need_more_players_message = false;
	int desired_activators = g_cvarActivators.IntValue;

	PrintToServer("  [DR] Checking for players...");

	// Blue player switches/leaves during freeze time and we have enough players to replace them
	if (g_bWatchForPlayerChanges && CountPlayers(_:TFTeam_Blue, false) < desired_activators && CountPlayers(0, false) > desired_activators)
	{
		g_bWatchForPlayerChanges = false;		// Stop watching for new players
		PrintToServer("  [DR] A blue player has left the team during freeze time.");
		RequestFrame(RedistributePlayers);		// Make some changes. We'll go back to watching when the changes are done.
			// Request frame prevents red team count from going up falsely due to switching too fast
		return;
	}
	
	// In freeze time with the required number of activators
	if (g_bWatchForPlayerChanges && CountPlayers(_:TFTeam_Blue, false) == desired_activators)
	{
		PrintToServer("  [DR] Team change detected but no action required.");
		return;
	}

	// At round restart
	if (!g_bWatchForPlayerChanges && CountPlayers(0, false) > 1)
	{
		PrintToServer("  [DR] We have enough players to start.");
		RedistributePlayers();
		need_more_players_message = false;
	}
	/*else if (!g_bWatchForPlayerChanges && CountPlayers(0, false) > 2 && desired_activators > 1)
	{
		CheckForPlayers();
	}*/
	else
	{
		PrintToServer("  [DR] Not enough players to start a round. Gone into waiting mode.");
		if (!need_more_players_message)
		{
			CPrintToChatAll("%t %t", "prefix_strong", "need more players");
			need_more_players_message = true;
		}
	}
}

// Redistribute players
void RedistributePlayers() // was public
{
	PrintToServer("  [DR] Redistributing players.");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
			MovePlayerToTeam(i, _:TFTeam_Red);
	
	if (g_cvarUsePointsSystem.BoolValue)	// Use queue points system if enabled
	{
		int prefers;
		
		for (int i = 1; i <= MaxClients && prefers <= MINIMUM_ACTIVATORS; i++)
		{
			if ((g_iFlags[i] & PLAYERFLAG_PREFERENCE) == PLAYERFLAG_PREFERENCE)
				prefers += 1;
		}
		
		if (prefers <= MINIMUM_ACTIVATORS)
		{
			SelectActivatorTurn();
			CPrintToChatAll("%t %t", "prefix", "not enough activators");
		}
		else
			SelectActivatorPoints();
	}					
	else
		SelectActivatorTurn();				// Use turn-based system if queue points are disabled
	
	g_bWatchForPlayerChanges = true;		// Go into watch mode to replace activator if needed
}

// Select activator (turn-based system)
SelectActivatorTurn()
{
	static int client = 1;
	
	//if (client > MaxClients)
		//client = 1;
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	while (GetTeamClientCount(_:TFTeam_Blue) < g_cvarActivators.IntValue && GetTeamClientCount(_:TFTeam_Red) > 1)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Red)
			MovePlayerToTeam(client, _:TFTeam_Blue);
		
		if (client == MaxClients)
			client = 1;
		else
			client++;
	}	
}

// Select activator (queue points system)
SelectActivatorPoints()
{
	// First sort our player points array by points in descending order
	int points_order[32][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = i + 1;
		points_order[i][1] = g_iPoints[i + 1];
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	
	while (GetTeamClientCount(_:TFTeam_Blue) < g_cvarActivators.IntValue && GetTeamClientCount(_:TFTeam_Red) > 1)
	{
		int client = points_order[i][0];
		
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Red && (g_iFlags[client] & PLAYERFLAG_PREFERENCE) == PLAYERFLAG_PREFERENCE)
		{
			MovePlayerToTeam(client, _:TFTeam_Blue);
			g_iPoints[client] = POINTS_CONSUMED;
			CPrintToChat(client, "%t %t", "prefix_notice", "queue points consumed");
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
	int iClassRunSpeeds[] = { 0, RunSpeed_Scout, RunSpeed_Sniper, RunSpeed_Soldier, RunSpeed_DemoMan, RunSpeed_Medic, RunSpeed_Heavy, RunSpeed_Pyro, RunSpeed_Spy, RunSpeed_Engineer };
	
	// Remove all player attributes
	if (!TF2Attrib_RemoveAll(client))
		LogMessage("Unable to remove attributes from %L", client);
	
	
	// Add attributes
	switch (TF2_GetClientTeam(client))
	{
		// Blue flat speed setting
		case TFTeam_Blue:
			if (g_cvarBlueSpeed.FloatValue != 0.0)
			{
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cvarBlueSpeed.FloatValue / iClassRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, "  [DR] Your run speed has been set to %.0f u/s", g_cvarBlueSpeed.FloatValue);
			}

		// Red team modding for speed and abilities
		case TFTeam_Red:
		{
			// Red speed
			// ***************************************************************************************************************************************
			if (g_cvarRedSpeed.FloatValue != 0.0)
			{
				// If red speed cvar is set
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cvarRedSpeed.FloatValue / iClassRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, "  [DR] Your run speed has been set to %.0f u/s", g_cvarRedSpeed.FloatValue);
			}
			else if (g_cvarRedScoutSpeed.FloatValue != 0.0 && TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				// If red scout run speed cvar is set
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cvarRedScoutSpeed.FloatValue / iClassRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, "[DR] Your run speed has been set to %.0f u/s", g_cvarRedScoutSpeed.FloatValue);
			}
			else
				PrintToConsole(client, "%t %t", "prefix", "class default run speed");
			
			// Red scout double jump
			// ***************************************************************************************************************************************
			if (g_cvarRedScoutDoubleJump.BoolValue == false && TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				TF2Attrib_SetByName(client, "no double jump", 1.0);
				PrintToConsole(client, "%t %t", "prefix", "red scout double jump disabled");
			}
			
			// Red team class ability modding
			// ***************************************************************************************************************************************
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Spy:		if (g_cvarRedSpyCloakLimits.IntValue == 2)
										{
											TF2Attrib_SetByName(client, "mult cloak meter consume rate", 8.0);
											TF2Attrib_SetByName(client, "mult cloak meter regen rate", 0.25);
											CPrintToChat(client, "%t %t", "prefix", "red spy cloak limited");
										}

				case TFClass_DemoMan:	switch (g_cvarRedDemoChargeLimits.IntValue)
										{
											case 0:
											{
												// Turn off red demo charging
												TF2Attrib_SetByName(client, "charge time decreased", -1000.0);
												TF2Attrib_SetByName(client, "charge recharge rate increased", 0.0);
												CPrintToChat(client, "%t %t", "prefix", "red demo charge disabled");
											}
											case 2:
											{
												// Limit demo charging
												TF2Attrib_SetByName(client, "charge time decreased", -0.95);
												TF2Attrib_SetByName(client, "charge recharge rate increased", 0.2);
												CPrintToChat(client, "%t %t", "prefix", "red demo charge limited");
											}
										}
			} // switch end
		}
	}
}

// Display up to the next three activators at the end of a round.
DisplayNextActivators()
{
	// Create a temporary array to store client index[0] and points[1]
	int points_order[32][2];
	
	// Populate with player data
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = i + 1;
		points_order[i][1] = g_iPoints[i + 1];
	}
	
	// Sort by points descending
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// Get the top three players with points
	int players[3], count, client;
	
	for (int i = 0; i < MaxClients && count < 3; i++)
	{
		client = points_order[i][0];
	
		if (IsClientInGame(client) && points_order[i][1] > 0 && (g_iFlags[client] & PLAYERFLAG_PREFERENCE) == PLAYERFLAG_PREFERENCE)
		{
			players[count] = client;
			count++;
		}
	}
	
	// Display the message
	if (players[0] != 0)
	{
		char string1[64];
		char string2[64];
		char string3[64];
		
		Format(string1, sizeof(string1), "%N", players[0]);
		
		if (players[1] > 0)
			Format(string2, sizeof(string2), ", %N", players[1]);
		
		if (players[2] > 0)
			Format(string3, sizeof(string3), " %t %N", "and", players[2]);
		
		CPrintToChatAll("%t %t", "prefix_strong", "next activators", string1, string2, string3);
	}
}

// Sort the players by points
SortByPoints(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])
		return 0;
	else if (b[1] > a[1])
		return 1;
	else
		return -1;
}

// Check the state of the game during a round, fired on round active and when a player dies
void CheckGameState()
{
	// If there are five or fewer players on the red team, enable player pushing
	if (CountPlayers(_:TFTeam_Red, true) <= g_cvarTeamPushOnRemaining.IntValue && g_cvarTeamPushOnRemaining.BoolValue != false && g_cvarServerTeamMatePush.BoolValue == false && g_bIsRoundActive)
	{
		g_cvarServerTeamMatePush.SetBool(true);
		CPrintToChatAll("%t %t", "prefix", "team mate pushing enabled");
	}
	
	// Red glow at a certain number of players
	if (CountPlayers(_:TFTeam_Red, true) <= g_cvarRedGlowRemaining.IntValue && g_cvarRedGlowRemaining.BoolValue != false && g_cvarRedGlow.BoolValue == false && g_bIsRoundActive)
	{
		g_bIsRedGlowActive = true;
		
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red)
			{
				SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
				PrintToServer("  [DR] CheckGameState has determined that %N should glow.", i);
			}
		
	}
}

// Command blocking (only hooked on deathrun map)
Action CommandListener_Suicide(int client, const char[] command, int args)
{
	// If the round is active, prevent blue players from suiciding or switching if the server has that enabled.
	if (g_bIsRoundActive && TF2_GetClientTeam(client) == TFTeam_Blue && IsPlayerAlive(client) && g_cvarPreventBlueEscape.BoolValue)
	{
		if (!g_bBlueWarnedSuicide)
		{
			SlapPlayer(client, 0);
			CPrintToChat(client, "%t %t", "prefix", "blue no escape");
			g_bBlueWarnedSuicide = true;
		}
		
		CReplyToCommand(client, "%t Command '%s' has been disallowed by the server.", "prefix", command);
		return Plugin_Handled;
	}
	
	// Block the 'autoteam' command at all times because it bypasses team balancing
	else if (strcmp(command, "autoteam", false) == 0)
	{
		return Plugin_Handled;
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
			if (g_cvarAirDashCount.IntValue == 0)
				PrintToServer("  [DR] It seems you have tf_scout_air_dash_count set to 0. DTK doesn't need that because it sets double jump using attributes.");
			
			g_cvarTeamsUnbalanceLimit.IntValue = 0;
			g_cvarAutoBalance.IntValue = 0;
			g_cvarScramble.IntValue = 0;
			g_cvarArenaQueue.IntValue = 0;
			g_cvarArenaFirstBlood.IntValue = 0;
			g_cvarHumansMustJoinTeam.SetString("red");
			g_cvarServerTeamMatePush.SetBool(g_cvarTeamMatePush.BoolValue);
		}
		case 0:
		{
			g_cvarTeamsUnbalanceLimit.RestoreDefault();
			g_cvarAutoBalance.RestoreDefault();
			g_cvarScramble.RestoreDefault();
			g_cvarArenaQueue.RestoreDefault();
			g_cvarArenaFirstBlood.RestoreDefault();
			g_cvarServerTeamMatePush.RestoreDefault();
			g_cvarRoundWaitTime.RestoreDefault();
			g_cvarHumansMustJoinTeam.RestoreDefault();
		}
	}
}

// Set a player to switch to their melee weapon and delete their other weapons
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
		}
		
		case false:
		{
			// Unhook some events
			UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
			UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
			UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
			UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
			UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
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
		}
	}
}

// Move a player to the other team silently
void MovePlayerToTeam(int client, int team)
{
	SetEntProp(client, Prop_Send, "m_lifeState", 2); // Dead, or...
	ChangeClientTeam(client, team);
	SetEntProp(client, Prop_Send, "m_lifeState", 0); // .. Alive
	TF2_RespawnPlayer(client);
	PrintToServer("  [DR] Moved %N to team %d", client, team);
}

// Replicate plugin cvar values to server cvars
void ConVarChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.SetString(newValue);
	char convar_name[64]; convar.GetName(convar_name, sizeof(convar_name));
	LogMessage("%s has been set to %s", convar_name, newValue);
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
		CPrintToChatAll("%t %t", "prefix_strong", phrase);
		phrase_number++;
	}
}

// Count players allocated to a given team or teams, alive or all
int CountPlayers(int team, bool alive)
{
	int players;
	
	switch (alive)
	{
		case true: // Only live players
		{
			switch (team)
			{
				case TFTeam_Red:	for (int i = 1; i <= MaxClients; i++)
									{
										if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Red)
											players++;
									}

				case TFTeam_Blue:	for (int i = 1; i <= MaxClients; i++)
									{
										if (IsClientInGame(i) && IsPlayerAlive(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
											players++;
									}
									
				default:			for (int i = 1; i <= MaxClients; i++) // Both teams
									{
										if (IsClientInGame(i) && IsPlayerAlive(i))
											players++;
									}
			}
		}
		
		case false: 	switch (team) // Alive and dead
						{
							case TFTeam_Red:	players = GetTeamClientCount(_:TFTeam_Red);
							case TFTeam_Blue:	players = GetTeamClientCount(_:TFTeam_Blue);
							default: 			players = GetTeamClientCount(_:TFTeam_Red) + GetTeamClientCount(_:TFTeam_Blue); // Both teams
						}
	}
	
	return players;
}


/*	COMMANDS
---------------------------------------------------------------------------------------------------*/

// Show my points
Action Command_ShowPoints(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;
	
	if (g_cvarUsePointsSystem.BoolValue == true)
		CReplyToCommand(client, "%t %t", "prefix_notice", "you have i points", g_iPoints[client]);
	else
		CReplyToCommand(client, "%t %t", "prefix_notice", "not using the points system");
		
	return Plugin_Handled;
}

// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Continue;
	
	if (g_cvarUsePointsSystem.BoolValue == true)
	{
		g_iPoints[client] = POINTS_CONSUMED;
		CReplyToCommand(client, "%t %t", "prefix_notice", "points have been reset to i", g_iPoints[client]);
		PrintToServer("  [DR] %N has reset their points using /reset.", client);
	}
	else
		CReplyToCommand(client, "%t %t", "prefix", "not using the points system");
		
	return Plugin_Handled;
}

// Set my queue points multiplier and activator preference
Action Command_ActivatorModifier(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;
	
	/*
		1. Check number of args
		2. Match case
		3. Set preference.
	*/

	if (args < 1)
	{
		if ((g_iFlags[client] & PLAYERFLAG_PREFERENCE) != PLAYERFLAG_PREFERENCE)
		{
			CReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to never be the activator");
		}
		else
		{
			CReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to receive i points per round", ((g_iFlags[client] & PLAYERFLAG_FULLPOINTS) == PLAYERFLAG_FULLPOINTS) ? POINTS_AWARD_FULL : POINTS_AWARD_FEWER);
		}
		
		CReplyToCommand(client, "%t %t", "prefix", "usage of pref command");
		PrintToConsole(client, "  [DR] Your preference bit flags are %b.", g_iFlags[client]);
		return Plugin_Handled;
	}
	
	char arg1[2];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int selection = StringToInt(arg1);
	
	AdjustMultiplier(client, selection);
	
	return Plugin_Handled;
}

AdjustMultiplier(int client, int selection)
{
	switch (selection)
	{
		case 0:
		{
			g_iFlags[client] &= ~PLAYERFLAG_PREFERENCE;
			CReplyToCommand(client, "%t %t", "prefix_notice", "no longer receive queue points");
		}
		case 1:
		{
			g_iFlags[client] |= PLAYERFLAG_PREFERENCE;
			g_iFlags[client] &= ~PLAYERFLAG_FULLPOINTS;
			CReplyToCommand(client, "%t %t", "prefix_notice", "you will now receive fewer queue points");
		}
		case 2:
		{
			g_iFlags[client] |= PLAYERFLAG_PREFERENCE;
			g_iFlags[client] |= PLAYERFLAG_FULLPOINTS;
			CReplyToCommand(client, "%t %t", "prefix_notice", "you will receive the maximum amount of queue points");
		}
	}	
}

// Admin can give a player some queue points
Action Command_GivePointsAdmin(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;
	
	if (args != 2)
	{
		CReplyToCommand(client, "%t %t", "prefix", "wrong usage of giveqp command");
		return Plugin_Handled;
	}
	
	char player[MAX_NAME_LENGTH]; char arg2[6];
	GetCmdArg(1, player, sizeof(player)); GetCmdArg(2, arg2, sizeof(arg2));
	int points = StringToInt(arg2);
	
	int target = FindTarget(client, player, false, false);
	if (target == -1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
		return Plugin_Handled;
	}
	else
	{
		g_iPoints[target] += points;
		char clientname[MAX_NAME_LENGTH];
		GetClientName(client, clientname, sizeof(clientname));
		CPrintToChat(target, "%t %t", "prefix_notice", "received queue points from an admin", clientname, points, g_iPoints[target]);
		ShowActivity(client, "awarded %N %d queue points. New total: %d", target, points, g_iPoints[target]);
		LogMessage("%L awarded %L %d queue points.", client, target, points);
		return Plugin_Handled;
	}
}

/*/ Show the available commands
Action Command_Menu(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Continue;

	CReplyToCommand(client, "%t No menu yet. Deathrun Toolkit is in development. Head to Discord to suggest things. https://discordapp.com/invite/3F7QADc", "prefix");
	CReplyToCommand(client, "%t Available commands: /points\x02, /reset\x02, /pref 0/1/2\x02.", "prefix");

	return Plugin_Handled;
}*/


/*	MENUS
---------------------------------------------------------------------------------------------------*/

// Open the menu
public Action Command_Menu(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;

	int points = g_iPoints[client];
	char title[64];
	Format(title, sizeof(title), "Deathrun Toolkit\n \nYou have %d points\n ", points);

	Menu menu = new Menu(MenuHandlerMain);
	menu.SetTitle(title);
	menu.AddItem("item1", "Activator Preferences");
	menu.AddItem("item2", "List Points");
	menu.AddItem("item3", "Reset My Points");
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

// Open the activator preference menu
public Action Command_MenuPreference(int client, int args)
{
	if (!g_bIsDeathrunMap)
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
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;

	Menu menu = new Menu(MenuHandlerPoints);
	menu.SetTitle("List Points\n ");
	menu.ExitBackButton = true;

	int points_order[32][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = i + 1;
		points_order[i][1] = g_iPoints[i + 1];
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	char item[40];
	
	for (int i = 0; i < MaxClients; i++)
		if (IsClientInGame(points_order[i][0]))
		{
			Format(item, sizeof(item), "%N: %d", points_order[i][0], points_order[i][1]);
			menu.AddItem("item", item, ITEMDRAW_DISABLED);
		}
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Open the points reset menu
public Action Command_MenuPointsReset(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Handled;

	int points = g_iPoints[client];
	char title[100];
	Format(title, sizeof(title), "Reset My Points\n \nYou have %d points\n \nAre you sure you want\nto reset your points?\n ", points);

	Menu menu = new Menu(MenuHandlerPointsReset);
	menu.SetTitle(title);
	menu.AddItem("item1", "Yes");
	menu.AddItem("item2", "No");
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

/*	MENU HANDLERS
---------------------------------------------------------------------------------------------------*/

/*
	Log of events:
	
	1. Typed /dr and up came the menu like this:
	
		Panel title
		1. Set my activator preference
		2. View the points board
		3. The legendary third item (disabled)
		
		0. Exit
		
	In console was:
		[DR] Console has opened the menu!
		[DR] worMatty was sent menu with panel 24800f2
	
	2. Selected choice 1 and the menu disappeared. In console was:
		[DR] worMatty selected #choice1
	
	
*/

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
				AdjustMultiplier(param1, 2);
			if (StrEqual(info, "item2"))
				AdjustMultiplier(param1, 1);
			if (StrEqual(info, "item3"))
				AdjustMultiplier(param1, 0);
				
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