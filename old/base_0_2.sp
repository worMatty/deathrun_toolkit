#pragma semicolon 1

#define DEBUG // what does this do?
#define PLUGIN_VERSION "0.2"

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

THINGS TO DO

1. Check if the map has a deathrun prefix.

2. Select activator(s) and distribute players.

3. Limit certain abilities.
	Dead Ringer. (maybe make the spy go slow for a bit after using it)
	Cloaking.
	Double jump.
	Rocket and sticky jumping.
	Scout drink.
	Demo charge.

4. Glow
	Give mapper control.

5. Cancel fall damage ONLY on certain maps.

6. Detect if there is no tf_logic_arena and set 'mp_enableroundwaittime 2'

7. Detect and set cvars.

8. Find out when teamplay_restart_round fires.

9. Points deposit system accessible by other plugins.

10. Points system could be 'Insanity'

11. Suppress 'joined team <team>' messages

12. Handle waiting for players time.

*/

/*
	Things I've Done
	
	Blue suicide prevention
	Red/red scout/blue speed mod
	Red scout double jump
*/

/*
	Bugs
	
	When there are no players on one team when the round ends in an Arena map, the round does not restart.
	Instead it waits for more players to connect. Killing yourself doesn't fix it because you stay dead.
	Can I detect this state?
	
		Reason:
		When the round is won, a teamplay_round_start is fired and the game's entities are reset. Players can move around
		but the arena game mode does not start. It just sits and waits for a new player. The plugin detects the event and 
		presumably fires its logic but if there is no need for it to put anyone on the opposite team it won't bother.
		Need to add a check to make sure there is at least one player on either team in tf_logic_arena maps.
		
		Global: Has tf_logic_arena (added)
		Always have one team's count one under the total player count.
		
	It seems that when a player leaves the server and the round resets, the plugin cycles through the redistribution logic
	until SM times it out after eight seconds. This could be fixed by implementing a 'game ready' state which checks for
	the minimum number of players depending on the mode, or at least one player playing.
	
		"This map requires at least %s players to start.", two
	
	
	Observations:
	
	mp_teams_unbalance_limit and mp_autoteambalance seem to do nothing.
	Perhaps the former is purely cosmetic for the team selection screen. Must check.
	
	player_initial_spawn fires when the players first joins and lands on the MOTD. Seems to happen once per map/connection.
	player_spawn and player_activate also do.
		
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
enum
{
    LifeState_Alive = 0,
    LifeState_Dead = 2
}

// Set some variables
static bool g_bIsDeathrunMap;
static bool g_bIsRoundActive;
static bool g_bBlueWarnedSuicide;
static bool g_bHasTFLogicArena;
//static bool g_bWaitingState;

static g_bActivatorTurn[33];

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

// Server cvars
ConVar g_cvarTeamsUnbalanceLimit;
//ConVar g_cvarAutoBalance;
//ConVar g_cvarScramble;
ConVar g_cvarArenaQueue;
ConVar g_cvarArenaFirstBlood;
ConVar g_cvarAirDashCount;
ConVar g_cvarServerTeamMatePush;
ConVar g_cvarRoundWaitTime;
//ConVar g_cvarHumansMustJoinTeam;


public void OnPluginStart()
{
	LoadTranslations("dtk-base.phrases");
	
	// Handle server cvars
	g_cvarTeamsUnbalanceLimit = FindConVar("mp_teams_unbalance_limit"); 	// 1 (0-30) - Teams are unbalanced when one team has this many more players than the other team. (0 disables check)
	//g_cvarAutoBalance = FindConVar("mp_autoteambalance"); 					// 1 (0-2) - Automatically balance the teams based on mp_teams_unbalance_limit. 0 = off, 1 = forcibly switch, 2 = ask volunteers
	//g_cvarScramble = FindConVar("mp_scrambleteams_auto"); 					// 1 - Server will automatically scramble the teams if criteria met.  Only works on dedicated servers.
	g_cvarArenaQueue = FindConVar("tf_arena_use_queue"); 					// 1 - Enables the spectator queue system for Arena.
	g_cvarArenaFirstBlood = FindConVar("tf_arena_first_blood"); 			// 1 - Rewards the first player to get a kill each round.
	g_cvarAirDashCount = FindConVar("tf_scout_air_dash_count"); 			// A hidden cvar which toggles scout double jump. Used for advice only.
	g_cvarServerTeamMatePush = FindConVar("tf_avoidteammates_pushaway"); 	// 1 - Whether or not teammates push each other away when occupying the same space
	g_cvarRoundWaitTime = FindConVar("mp_enableroundwaittime"); 			// 1 - The time at the beginning of the round, while players are frozen.
	//g_cvarHumansMustJoinTeam = FindConVar("mp_humans_must_join_team");		// Forces players to join the specified team. Default is 'any'.
	
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
	
	// Hook the teampush convar so it synchronises with the server convar
	g_cvarTeamMatePush.AddChangeHook(ConVarChangeHook_TeamMatePush);
	
	LogMessage("%t", "plugin has loaded");
}


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
			g_bIsDeathrunMap = true;
			LogMessage("%t", "current map is deathrun");
			Steam_SetGameDescription("Deathrun Toolkit");
		}
		else
		{
			g_bIsDeathrunMap = false;
			LogMessage("%t", "current map not deathrun");
			Steam_SetGameDescription("Team Fortress");	
		}
	
	if (g_bIsDeathrunMap)
	{
		if (FindEntityByClassname(-1, "tf_logic_arena") == -1)
		{
			LogMessage("%t", "no tf_logic_arena");
			g_bHasTFLogicArena = false;
			g_cvarRoundWaitTime.SetInt(2);
		}
		else
			g_bHasTFLogicArena = true;
		
		EventsAndListeners(true);
		SetServerCvars(true);
	}
}

// Set and remove event hooks and command listeners
void EventsAndListeners(bool set_mode)
{
	switch (set_mode)
	{
		case true:
		{
			// Hook some events
			HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
			HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
			HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
			HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
			HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
			// HookEvent("player_team", Event_PlayerChangeTeam, EventHookMode_PostNoCopy);
			HookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);
			// HookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
			HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
			HookEvent("teams_changed", Event_TeamsChanged, EventHookMode_Post);
			
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
			UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_PostNoCopy);
			UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
			// UnhookEvent("player_team", Event_PlayerChangeTeam, EventHookMode_PostNoCopy);
			UnhookEvent("player_connect_client", Event_PlayerConnect, EventHookMode_Post);
			// UnhookEvent("player_activate", Event_PlayerActivate, EventHookMode_Post);
			UnhookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
			UnhookEvent("teams_changed", Event_TeamsChanged, EventHookMode_Post);
			
			// Remove the command listeners
			RemoveCommandListener(CommandListener_Suicide, "kill");
			RemoveCommandListener(CommandListener_Suicide, "explode");
			RemoveCommandListener(CommandListener_Suicide, "spectate");
			RemoveCommandListener(CommandListener_Suicide, "jointeam");
			RemoveCommandListener(CommandListener_Suicide, "autoteam");
		}
	}
}


public void TF2_OnWaitingForPlayersEnd()
{
	
}


// Event is only hooked if the map is a deathrun map 
void Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast)
{	
	// Menu after a delay
	// CreateTimer(15.0, WelcomePlayer, event.GetInt("userid"));
	
	// Reset points
	//int client = event.GetInt("index") + 1;
	//g_iPlayerPoints[client][0] = 0;
	//g_iPlayerPoints[client][1] = 1;
	
	// Reset points - 1 is 'has played'.
	g_bActivatorTurn[event.GetInt("index") + 1] = 1;
}


// On player disconnect
// Event is only hooked if the map is a deathrun map 
void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	PrintToServer("  %N has triggered player_disconnect.", client);
	
	// Reset points
	g_bActivatorTurn[client] = 0;
}


// On round restart
// Event is only hooked if the map is a deathrun map 
void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = false; // Essentially this is pre-round prep time
	g_bBlueWarnedSuicide = false;
	
	SetServerCvars(true); // Make sure required cvars for the game mode are set on every round
	
	PrintToServer("[DR] Round has restarted.");
	ShowActivity(0, "[DR] Number of activators is currently set to %d.", g_cvarActivators.IntValue);
	
	/* Queue point system
	for (int i = 1; i <= 32 && IsClientInGame(i); i++)
	{
		PrintToChat(i, "%t You have %d points.", "prefix", g_iPlayerPoints[i][0]);
	}
	*/
	
	CreateTimer(1.0, RedistributePlayers);
}


// On round start!
// Event is only hooked if the map is a deathrun map
void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundActive = true;
	g_bBlueWarnedSuicide = false;
	
	RoundStartMessage();
	CheckGameState();
}

void RoundStartMessage()
{
	static int phrase_number = 1; char phrase[20];
	FormatEx(phrase, sizeof(phrase), "round has begun %d", phrase_number);
	
	if (!TranslationPhraseExists(phrase))
	{
		phrase_number = 1;
		RoundStartMessage();
	}
	else
	{
		PrintToChatAll("\x04%t %t", "prefix", phrase);
		phrase_number++;
	}
}


public Action RedistributePlayers(Handle timer)
{
	RedistributePlayers2();
}

public Action RedistributePlayers2()
{
	if (g_bHasTFLogicArena)
	{
		if (CountPlayers(0, false) < 2)
		{
			PrintToChatAll("\x04[DR] This map needs a minimum of two players.");
			//g_bWaitingState = true;
			return Plugin_Handled;
		}
	}
	else
	{
		if (CountPlayers(0, false) < 1)
		{
			PrintToChatAll("\x04[DR] This map needs a minimum of one player.");
			//g_bWaitingState = true;
			return Plugin_Handled;
		}

	}

	PrintToServer("[DR] Redistributing players.");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Blue)
		{
		//TF2_ChangeClientTeam(i, TFTeam_Red);
		SetEntProp(i, Prop_Send, "m_lifeState", LifeState_Dead);
		TF2_ChangeClientTeam(i, TFTeam_Red);
		SetEntProp(i, Prop_Send, "m_lifeState", LifeState_Alive);
		TF2_RespawnPlayer(i);
		}
	}
	
	// Move the next player to the blue team
	static int client = 1;
	
	if (client > MaxClients)
		client = 1;
	
	while (GetTeamClientCount(_:TFTeam_Blue) < g_cvarActivators.IntValue)
	{
		if (IsClientInGame(client) && TF2_GetClientTeam(client) == TFTeam_Red) // Client index 25 is invalid
		{
			{
			//TF2_ChangeClientTeam(client, TFTeam_Blue);
			SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Dead);
			TF2_ChangeClientTeam(client, TFTeam_Blue);
			SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Alive);
			TF2_RespawnPlayer(client);
			PrintToServer("[DR] %N (%d) has been made an activator.", client, client);
			}
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
	
	return Plugin_Handled;
}



// On player spawn
// Event is only hooked if the map is a deathrun map
void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int iClassRunSpeeds[] = { 0, RunSpeed_Scout, RunSpeed_Sniper, RunSpeed_Soldier, RunSpeed_DemoMan, RunSpeed_Medic, RunSpeed_Heavy, RunSpeed_Pyro, RunSpeed_Spy, RunSpeed_Engineer };
	
	// Remove all player attributes
	if (!TF2Attrib_RemoveAll(client))
		LogMessage("Unable to remove attributes from %L", client);
	
	
	switch (TF2_GetClientTeam(client))
	{
		// Blue flat speed setting
		case TFTeam_Blue:
			if (g_cvarBlueSpeed.FloatValue != 0.0)
			{
				TF2Attrib_SetByName(client, "CARD: move speed bonus", g_cvarBlueSpeed.FloatValue / iClassRunSpeeds[TF2_GetPlayerClass(client)]);
				PrintToConsole(client, "[DR] Your run speed has been set to %.0f u/s", g_cvarBlueSpeed.FloatValue);
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
				PrintToConsole(client, "[DR] Your run speed has been set to %.0f u/s", g_cvarRedSpeed.FloatValue);
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


void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	CheckGameState();
}



// On round end!
// Event is only hooked if the map is a deathrun map
void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	/* Points queue system
	for (int i = 1; i <= 32 && IsClientInGame(i) && TF2_GetClientTeam(i) == TFTeam_Red; i++)
	{
		g_iPlayerPoints[i][0] += 10;
		PrintToChat(i, "%t You have received 10 points.", "prefix");
	}
	*/
	
	PrintToServer("%t %t", "prefix", "round ended");
}


// Block commands!
// The command listeners are only active if the map is a deathrun map
Action CommandListener_Suicide(int client, const char[] command, int args)
{
	// If the round is active, prevent blue players from suiciding or switching if the server has that enabled.
	if (g_bIsRoundActive && TF2_GetClientTeam(client) == TFTeam_Blue && g_cvarPreventBlueEscape.BoolValue)
	{
		if (!g_bBlueWarnedSuicide)
		{
			SlapPlayer(client, 0);
			PrintToChat(client, "%t %t", "prefix", "blue no escape");
			g_bBlueWarnedSuicide = true;
		}
		
		ReplyToCommand(client, "[DR] Command '%s' has been disallowed by the server.", command);
		return Plugin_Handled;
	}
	// Block the 'autoteam' command at all times because it bypasses team balancing
	// red are prevented from going to blue by a server cvar
	else if (strcmp(command, "autoteam", false) == 0)
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


// Set cvars on the server to allow player team distribution
// True = set. False = return to game defaults.
void SetServerCvars(bool set_mode)
{
	switch (set_mode)
	{
		case true:
		{
			if (g_cvarAirDashCount.IntValue == 0)
				PrintToServer("%t %t", "prefix", "airdash cvar disabled");
			
			g_cvarTeamsUnbalanceLimit.IntValue = 0;
			//g_cvarAutoBalance.IntValue = 0;
			//g_cvarScramble.IntValue = 0;
			g_cvarArenaQueue.IntValue = 0;
			g_cvarArenaFirstBlood.IntValue = 0;
			//g_cvarHumansMustJoinTeam.SetString("red");
			g_cvarServerTeamMatePush.SetBool(g_cvarTeamMatePush.BoolValue);
		}
		case false:
		{
			g_cvarTeamsUnbalanceLimit.RestoreDefault();
			//g_cvarAutoBalance.RestoreDefault();
			//g_cvarScramble.RestoreDefault();
			g_cvarArenaQueue.RestoreDefault();
			g_cvarArenaFirstBlood.RestoreDefault();
			g_cvarServerTeamMatePush.RestoreDefault();
			g_cvarRoundWaitTime.RestoreDefault();
			//g_cvarHumansMustJoinTeam.RestoreDefault();
		}
	}
}


// Hook changes to the team mate pushing cvar
void ConVarChangeHook_TeamMatePush(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_cvarServerTeamMatePush.SetString(newValue);
	char convar_name[64]; convar.GetName(convar_name, sizeof(convar_name));
	LogMessage("%s has been set to %s", convar_name, newValue);
}


// Count players allocated to teams
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
									
				default:			for (int i = 1; i <= MaxClients; i++)
									{
										if (IsClientInGame(i) && IsPlayerAlive(i))
											players++;
									}
			}
		}
		
		case false: 	switch (team)
						{
							case TFTeam_Red:	players = GetTeamClientCount(_:TFTeam_Red);
							case TFTeam_Blue:	players = GetTeamClientCount(_:TFTeam_Blue);
							default: 			players = GetTeamClientCount(_:TFTeam_Red) + GetTeamClientCount(_:TFTeam_Blue);
						}
	}
	
	return players;
}


void CheckGameState()
{
	// If there are five or fewer players on the red team, enable player pushing
	if (CountPlayers(_:TFTeam_Red, true) <= 5 && g_cvarServerTeamMatePush.BoolValue == false && g_bIsRoundActive)
	{
		g_cvarServerTeamMatePush.SetBool(true);
		PrintToChatAll("\x04[DR] Team mate pushing has been enabled.");
	}
}


public void OnMapEnd()
{
	// Paired with OnMapStart so must be included.
	
	if (g_bIsDeathrunMap)
	{
		// Close handles and restore cvars when the map switches
		EventsAndListeners(false);
		SetServerCvars(false);
		LogMessage("OnMapEnd has been called on a deathrun map. Restoring cvars.");
	}
}


public void OnPluginEnd()
{
	// Paired with OnPluginStart to must be included
	// Handles are closed when the plugin is unloaded so event hooks and command listeners don't need to be closed.
	
	SetServerCvars(false);
	LogMessage("Plugin has been unloaded.");
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