#pragma semicolon 1

#define DEBUG // what does this do?
#define PLUGIN_VERSION "0.22"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
//#include <sdkhooks>
#include <tf2attributes> // Needed to set attributes
#include <steamtools> // Needed to set the game description

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
	
	13. Points and queue system. Learn to sort stuff.
	
	14. Add the force team cvar.
	
	15. Attribute kills to entity classnames.
	
	16. Display attribute messages once during freeze time after a delay as long as the attributes are still there.
		(team mover)
		
	17. Give the user the option to toggle the language to English rather than their own. Find out how SM chooses a language.
	
	18. Make some logic where if no one wants to be the activator, a puppet bot is spawned instead.
	
	19. Display points to users shortly after a round starts. Kill the timer if the round ends.

*/


/*

	Bugs:
	-----

	Dead spectators on Blue get the anti-suicide treatment. Need to check if they're alive.
	
	Need to prevent people joining blue team.
	
	I somehow broke Arena mode when joining blue when there was already an activator. When the red bot died it didn't end the round.
	
	Found a bug with DTK. If you join a team but don't choose a class, you will still be team swapped.
	I was put on blue as the activator and had yet to choose a team, but was only able to spec from the Buzz train on PlayStation
	and when I tried to choose a class and spawn after the round had started, the game told me I couldn't change class after the round had started.
	
	Game thinks there are more red players than in reality. Possibly caused by team swapping too fast. Can we 'update' the player numbers?
	
	/points repeats its message three times on the server.
	Blue player gets notified of points reset three times.
	
	
	Observations:
	-------------
	
	player_initial_spawn fires when the players first joins and lands on the MOTD. Seems to happen once per map/connection.
	player_spawn and player_activate happen at the same time as this.
	
	Setting activators to 2 and then slaying myself while on blue crashed the server.
	
	If on a server alone and you spawn into a team then go to spec, the 'waiting' message is shown three times.
	
	Activator can kill themselves with stickies.
	
	Could these entities be responsible for holding the number of players shown on the HUD?
	{
		tf_player_manager
		tf_team
		tf_logic_arena
		tf_gamerules
		tf_objective_resource 
	}
	
*/

/*
	Console dump from a server crash:
	---------------------------------
	
	Attempted to create unknown entity type tf_weapon_shotgun!
	Failed to generate base item: tf_weapon_shotgun_primary
	L 02/17/2020 - 13:34:12: [SM] Exception reported: Entity 208 (208) is not a CBaseEntity
	L 02/17/2020 - 13:34:12: [SM] Blaming: dv/matty_ammobombs.smx
	L 02/17/2020 - 13:34:12: [SM] Call stack trace:
	L 02/17/2020 - 13:34:12: [SM]   [0] AcceptEntityInput
	L 02/17/2020 - 13:34:12: [SM]   [1] Line 119, D:\TF2 mapping\SourceMod Scripting\- matty\matty_ammobombs.sp::TriggerBomb
	  [DR] The round has ended.
	  [DR] Round has restarted.
	  [DR] Checking for players...
	  [DR] We have enough players to start.
	  [DR] Redistributing players.
	  [DR] Moved 'fejmking'  TRADEIT.GG to team 2
	  [DR] Moved siulaisiulek to team 3
	  [DR] Round is now active.
	L 02/17/2020 - 13:36:15: [SM] Exception reported: Entity 489 (489) is not a CBaseEntity
	L 02/17/2020 - 13:36:15: [SM] Blaming: dv/matty_ammobombs.smx
	L  02/17/2020 - 13:36:15: [SM] Call stack trace:
	L 02/17/2020 - 13:36:15: [SM]   [0] AcceptEntityInput
	L 02/17/2020 - 13:36:15: [SM]   [1] Line 119, D:\TF2 mapping\SourceMod Scripting\- matty\matty_ammobombs.sp::TriggerBomb
	siulaisiulek: ee
	  [DR] 'fejmking'  TRADEIT.GG has triggered player_disconnect. Resetting their points.
	Dropped 'fejmking'  TRADEIT.GG from server (Disconnect by user.)
	  [DR] Boomek has triggered player_disconnect. Resetting their points.
	Dropped Boomek from server (Disconnect by user.)
	  [DR] 0w0 TRADEIT.GG has triggered player_disconnect. Resetting their points.
	Dropped 0w0 TRADEIT.GG from server (Disconnect by user.)
	*DEAD* ⛐ worMatty: gg
	  [DR] siulaisiulek has triggered player_disconnect. Resetting their points.
	Dropped siulaisiulek from server (Disconnect by user.)
	Wrote minidump to: /home/main/tfserver/tf2/tf/addons/sourcemod/data/dumps/308b9842-7a9d-4bd7-923f1aa3-6b0ff4b9.dmp
	Segmentation fault (core dumped)
	Add "-debug" to the tf2/srcds_run command line to generate a debug.log to help with solving this problem
	Mon Feb 17 13:37:42 CET 2020: Server restart in 10 seconds
	Updating server using Steam.

*/

// enums
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

// Set some variables
static bool g_bIsDeathrunMap;
static bool g_bIsRoundActive;
static bool g_bBlueWarnedSuicide;
static bool g_bHasTFLogicArena;
static bool g_bWatchForPlayerChanges;

static g_iPlayerData[33];		// Our new multi dimensional array for points

#define STARTING_POINTS 10

// Plugin cvars
ConVar g_cvarPreventBlueEscape;
ConVar g_cvarRedSpeed;
ConVar g_cvarRedScoutSpeed;
ConVar g_cvarBlueSpeed;
ConVar g_cvarRedScoutDoubleJump;
ConVar g_cvarActivators;
ConVar g_cvarTeamMatePush;
ConVar g_cvarRedDemoChargeLimits;
ConVar g_cvarRedSpyCloakLimits;
ConVar g_cvarUsePointsSystem;

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
	
	// Hook the teampush convar so it synchronises with the server convar
	g_cvarTeamMatePush.AddChangeHook(ConVarChangeHook);
	
	// Add some console commands
	RegConsoleCmd("sm_drmenu", Command_Menu, "Doesn't open a menu.");
	RegConsoleCmd("sm_dr", Command_Menu, "Shows available commands.");
	RegConsoleCmd("sm_points", Command_ShowPoints, "Show how many deathrun queue points you have.");
	RegConsoleCmd("sm_reset", Command_ResetPoints, "Reset your deathrun queue points.");
	RegAdminCmd("sm_giveqp", Command_GivePointsAdmin, ADMFLAG_SLAY, "Give a peon some pity points.");
	
	LogMessage("Deathrun Toolkit Base has loaded");
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
			LogMessage("Not a deathrun map. No need to hook some stuff.");
			Steam_SetGameDescription("Team Fortress");	
		}
	
	if (g_bIsDeathrunMap)
	{
		// Does the map has a tf_logic_arena?
		if (FindEntityByClassname(-1, "tf_logic_arena") == -1)
		{
			LogMessage("Map doesn't have a tf_logic_arena. Handling some things a bit differently.");
			g_bHasTFLogicArena = false;
			g_cvarRoundWaitTime.SetInt(2);
		}
		else
			g_bHasTFLogicArena = true;
		
		EventsAndListeners(true);
		SetServerCvars(1);
	}
}

// OnMapEnd
public void OnMapEnd()
{
	// Paired with OnMapStart so must be included.
	
	if (g_bIsDeathrunMap)
	{
		// Close handles and restore cvars when the map switches
		EventsAndListeners(false);
		SetServerCvars(0);
		LogMessage("OnMapEnd has been called on a deathrun map. Restoring cvars.");
	}
}

// OnPluginEnd
public void OnPluginEnd()
{
	// Paired with OnPluginStart to must be included
	// Handles are closed when the plugin is unloaded so event hooks and command listeners don't need to be closed.
	
	SetServerCvars(0);
	LogMessage("Plugin has been unloaded.");
}



/*	GAME EVENTS
---------------------------------------------------------------------------------------------------*/

// On round restart (hooked on deathrun map)
void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = false; // Essentially this is pre-round prep time
	g_bBlueWarnedSuicide = false;
	
	SetServerCvars(1); // Make sure required cvars for the game mode are set on every round
	
	PrintToServer("  [DR] Round has restarted.");
	// ShowActivity(0, "[DR] Number of activators is currently set to %d.", g_cvarActivators.IntValue);
	
	/* Queue point system
	for (int i = 1; i <= 32 && IsClientInGame(i); i++)
	{
		PrintToChat(i, "%t You have %d points.", "prefix", g_iPlayerPoints[i][0]);
	}
	*/
	
	CheckForPlayers();
}

// On round start (hooked on deathrun map)
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = true;			// The round is now active
	g_bBlueWarnedSuicide = false;		// Reset the warning given to blue when trying to quit
	g_bWatchForPlayerChanges = false;	// No need to watch for team changes now
	
	PrintToServer("  [DR] Round is now active.");
	
	RoundActiveMessage();				// Fire the function that cycles through round start messages
	CheckGameState();					// How many players and should we enable team pushing?
	//CreateTimer(12.0, Timer_TellPoints);
}

// On round end (only hooked on deathrun map)
void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// Give players points
	if (g_cvarUsePointsSystem.BoolValue == true)
	{
		int award = 10;
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red)
			{
				g_iPlayerData[i] += award;
				PrintToChat(i, "%t You have received %d queue points for a total of %d.", "prefix", award, g_iPlayerData[i]);
				PrintToServer("  [DR] g_iPlayerData[%d] %N has %d points.", i, i, g_iPlayerData[i]);
			}
		}
	}
	
	PrintToServer("  %t %t", "prefix", "round ended");
}



/*	PLAYER EVENTS
---------------------------------------------------------------------------------------------------*/

// Event is only hooked if the map is a deathrun map 
void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{
	// Menu after a delay
	// CreateTimer(15.0, WelcomePlayer, event.GetInt("userid"));
	
	// Reset points
	if (g_cvarUsePointsSystem.BoolValue == true)
	{
		int client = event.GetInt("index") + 1;
		g_iPlayerData[client] = STARTING_POINTS;
		//PrintToServer("  [DR] Reset new player %N's queue points to %d.", client, starting_points); // Client index doesn't resolve this early
	}
}

// On player spawn (only hooked on deathrun map)
void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
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
				PrintToChat(client, "[DR] Your run speed has been set to %.0f u/s", g_cvarRedScoutSpeed.FloatValue);
			}
			else
				PrintToConsole(client, "%t %t", "prefix", "class default run speed");
			
			// Red scout double jump
			// ***************************************************************************************************************************************
			if (g_cvarRedScoutDoubleJump.BoolValue == false && TF2_GetPlayerClass(client) == TFClass_Scout)
			{
				TF2Attrib_SetByName(client, "no double jump", 1.0);
				PrintToChat(client, "%t %t", "prefix", "red scout double jump disabled");
			}
			
			// Red team class ability modding
			// ***************************************************************************************************************************************
			switch (TF2_GetPlayerClass(client))
			{
				case TFClass_Spy:		if (g_cvarRedSpyCloakLimits.IntValue == 2)
										{
											TF2Attrib_SetByName(client, "mult cloak meter consume rate", 10.0);
											TF2Attrib_SetByName(client, "mult cloak meter regen rate", 0.25);
											PrintToChat(client, "%t %t", "prefix", "red spy cloak limited");
										}

				case TFClass_DemoMan:	switch (g_cvarRedDemoChargeLimits.IntValue)
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
												TF2Attrib_SetByName(client, "charge time decreased", -1.0);
												TF2Attrib_SetByName(client, "charge recharge rate increased", 0.2);
												PrintToChat(client, "%t %t", "prefix", "red demo charge limited");
											}
										}
			} // switch end
		}
	}
}

// On player death (only hooked on deathrun map)
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	CheckGameState();	// Check for live players remaining and enable team pushing at some amount
}

// Team players have changed (hooked on deathrun map) 
void Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	// If we're watching for player changes and teams change...
	if (g_bWatchForPlayerChanges)
	{
		CheckForPlayers();
	}
}

// On player disconnect (hooked on deathrun map)
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	// Reset queue points
	if (g_cvarUsePointsSystem.BoolValue == true)
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		int starting_points = 0;
		g_iPlayerData[client] = starting_points;
		PrintToServer("  [DR] Reset disconnecting player %N's queue points to %d.", client, starting_points);
	}
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

// Check if we have enough players
Action CheckForPlayers()
{
	static bool need_more_players_message = false;
	int desired_activators = g_cvarActivators.IntValue;

	PrintToServer("  [DR] Checking for players...");

	// Blue player leaves the server during freeze time and we have enough players to replace them
	if (g_bWatchForPlayerChanges && CountPlayers(_:TFTeam_Blue, false) < desired_activators && CountPlayers(0, false) > desired_activators)
	{
		g_bWatchForPlayerChanges = false;	// Stop watching for new players
		PrintToServer("  [DR] A blue player has left the team during freeze time.");
		RequestFrame(RedistributePlayers2);		// Needed to do request frame to keep the red player count right
		//RedistributePlayers2();				// Make some changes. We'll go back to watching when the changes are done.
		return Plugin_Handled;
	}
	
	// In freeze time with the required number of activators
	if (g_bWatchForPlayerChanges && CountPlayers(_:TFTeam_Blue, false) == desired_activators)
	{
		PrintToServer("  [DR] Team change detected but no action required.");
		return Plugin_Handled;
	}

	// At round restart
	if (!g_bWatchForPlayerChanges && CountPlayers(0, false) > 1)
	{
		PrintToServer("  [DR] We have enough players to start.");
		RedistributePlayers2();
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
			PrintToChatAll("%t %t", "prefix", "need more players");
			need_more_players_message = true;
		}
	}
	
	return Plugin_Continue;
}

// Redistribute players
void RedistributePlayers2() // was public
{
	PrintToServer("  [DR] Redistributing players.");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
		{
			MovePlayerToTeam(i, _:TFTeam_Red);
		}
	}
	
	if (g_cvarUsePointsSystem.BoolValue == true)
		SelectActivatorPoints();					// Use the new system for moving blue based on points
	else
		SelectActivatorOld();						// Use the old system for moving blue by taking it in turns
	
	g_bWatchForPlayerChanges = true;
	
	//return Plugin_Handled;
}

// Select activator (old system)
SelectActivatorOld()
{
	// Move the next player to the blue team
	static int client = 1;
	
	if (client > MaxClients)
		client = 1;
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	while (GetTeamClientCount(_:TFTeam_Blue) < g_cvarActivators.IntValue && GetTeamClientCount(_:TFTeam_Red) > 1)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Red)
		{
			MovePlayerToTeam(client, _:TFTeam_Blue);
		}
		
		if (client == MaxClients)
		{
			client = 1;
		}
		else
		{
			client++;
		}
	}	
}

// Select activator and deduct points (new system)
SelectActivatorPoints()
{
	// First sort our player points array by points in descending order
	int points_order[32][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = i + 1;
		points_order[i][1] = g_iPlayerData[i + 1];
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	for (int i = 0; i < MaxClients; i++)	// The sort function returns an array starting with the index 0! Not 1.
	{
		if (IsClientInGame(points_order[i][0]))
			PrintToServer("  [DR] points_order[%d] Client %d %N has %d points.", i, points_order[i][0], points_order[i][0], points_order[i][1]);
	}
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	
	while (GetTeamClientCount(_:TFTeam_Blue) < g_cvarActivators.IntValue && GetTeamClientCount(_:TFTeam_Red) > 1)
	{
		int client = points_order[i][0];
		
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Red)
		{
			MovePlayerToTeam(client, _:TFTeam_Blue);
			int reset_points = 0;
			g_iPlayerData[client] = reset_points;
			PrintToChat(client, "%t Your queue points have been consumed.", "prefix");
		}
		
		if (i == MaxClients - 1)
		{
			i = 0;
		}
		else
		{
			i++;
		}
	}
}

// Sort the players by points
SortByPoints(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])
	{
		return 0;
	}
	else if (b[1] > a[1])
	{
		return 1;
	}
	else
	{
		return -1;
	} 
}

// Tell the red players how many points they have after a time 
/*Action Timer_TellPoints(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red)
			PrintToChat(i, "%t You are currently sitting on %d queue points. Rejoice.", "prefix", g_iPlayerData[i]);
	}
}*/

// Check the state of the game during a round, fired on round active and when a player dies
void CheckGameState()
{
	// If there are five or fewer players on the red team, enable player pushing
	if (CountPlayers(_:TFTeam_Red, true) <= 5 && g_cvarServerTeamMatePush.BoolValue == false && g_bIsRoundActive)
	{
		g_cvarServerTeamMatePush.SetBool(true);
		PrintToChatAll("[DR] Team mate pushing has been enabled.");
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
			PrintToChat(client, "%t %t", "prefix", "blue no escape");
			g_bBlueWarnedSuicide = true;
		}
		
		ReplyToCommand(client, "  [DR] Command '%s' has been disallowed by the server.", command);
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
			HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begn (Arena)
			HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
			HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);					// Player spawns
			HookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);				// Player dies
			HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);		// Player connects to the server for the first time
			HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);			// Player disconnects from the server
			HookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);			// A player changes team
			
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
			UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_PostNoCopy);
			UnhookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);
			UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
			UnhookEvent("teams_changed", Event_TeamsChanged, EventHookMode_PostNoCopy);
			
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
		PrintToChatAll("\x03%t %t", "prefix", phrase);
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
		return Plugin_Continue;
	
	if (g_cvarUsePointsSystem.BoolValue == true)
		ReplyToCommand(client, "%t You have %d points.", "prefix", g_iPlayerData[client]);
	else
		ReplyToCommand(client, "%t We're not using the points system at the moment.", "prefix");
		
	return Plugin_Handled;
}

// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Continue;
	
	if (g_cvarUsePointsSystem.BoolValue == true)
	{
		g_iPlayerData[client] = 0;
		ReplyToCommand(client, "%t Your points have been reset to %d.", "prefix", g_iPlayerData[client]);
		PrintToServer("  [DR] %N has reset their points by command.", client);
	}
	else
		ReplyToCommand(client, "%t We're not using the points system at the moment.", "prefix");
		
	return Plugin_Handled;
}

// Admin give a player some queue points
Action Command_GivePointsAdmin(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Continue;
	
	if (args != 2)
	{
		ReplyToCommand(client, "%t You're doing it wrong. /giveqp <name> <points>", "prefix");
		return Plugin_Handled;
	}
	
	char player[MAX_NAME_LENGTH]; char arg2[4];
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
		g_iPlayerData[target] += points;
		ReplyToCommand(client, "%t You have awarded %N %d queue points, making their total %d.", "prefix", target, points, g_iPlayerData[target]);
		PrintToChat(target, "%t %N has awarded you %d points, making your total %d.", "prefix", client, points, g_iPlayerData[target]);
		return Plugin_Handled;
	}
}

// Show the available commands
Action Command_Menu(int client, int args)
{
	if (!g_bIsDeathrunMap)
		return Plugin_Continue;

	ReplyToCommand(client, "%t No menu yet. Deathrun Toolkit is in development. Head to Discord to suggest things.", "prefix");
	ReplyToCommand(client, "%t Available commands: \x03/points\x02, \x03/reset\x02.", "prefix");

	return Plugin_Handled;
}


/*	Old team switching logic

// Our own function for redistributing players one second after a round restart
public Action RedistributePlayers(Handle timer)
{
	int desired_activators = g_cvarActivators.IntValue;
	
	// If blue has fewer than the desired amount and red has greater, move some from red
	if (GetTeamClientCount(_:TFTeam_Blue) < desired_activators && (GetTeamClientCount(_:TFTeam_Red) + GetTeamClientCount(_:TFTeam_Blue)) > desired_activators)
	{
		int i = 1;
		while (GetTeamClientCount(_:TFTeam_Blue) < desired_activators)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red && i <= MaxClients)
				TF2_ChangeClientTeam(i, TFTeam_Blue);
			i++;
		}
	}
	// Otherwise, if blue has too many players, move them to red.
	else
	{	
		int i = 1;
		while (GetTeamClientCount(_:TFTeam_Blue) > desired_activators)
		{
			if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue && i <= MaxClients)
				TF2_ChangeClientTeam(i, TFTeam_Red);
			i++;
		}
	}
}

*/



/*	Unneeded debug stuff

// Event is only hooked if the map is a deathrun map 
void Event_PlayerActivate(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	PrintToServer("  %N has triggered player_activate.", client);
}

// Event is only hooked if the map is a deathrun map
void Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	
}

*/