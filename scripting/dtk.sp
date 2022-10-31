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
#tryinclude <tf2_stocks>		// TF2 Tools extension natives




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

#define PLUGIN_VERSION 		"0.4.6.2"
#define PLUGIN_NAME			"[DTK] Deathrun Toolkit"
#define PLUGIN_SHORTNAME 	"Deathrun Toolkit"
#define PLUGIN_PREFIX		"[DTK]"

#define SQLITE_DATABASE		"sourcemod-local"
#define SQLITE_TABLE		"dtk_players"
#define MINIMUM_WILLING 	3						// This or below number of willing activators and everyone takes it in turns
#define HEALTH_SCALE_BASE	300.0					// The base value used in the activator health scaling system
#define DEFAULT_GAME_DESC	"Source Game Server"	// Default game description when using with unsupported games/mods
#define TIMER_GRANTPOINTS	10.0
#define TIMER_NA_MESSAGE	120.0

#define HELP_URL					"https://steamcommunity.com/groups/death_experiments/discussions/3/3111395113752151418/"
#define WEAPON_REPLACEMENTS_CFG		"addons/sourcemod/configs/dtk/replacements.cfg"
#define WEAPON_RESTRICTIONS_CFG		"addons/sourcemod/configs/dtk/restrictions.cfg"




/**
 * Enumerations
 * ----------------------------------------------------------------------------------------------------
 */

// Queue Points
enum {
	QP_Start = 0,			// New players receive this amount on beginning a server session
	QP_Award = 1,			// Queue points received every minute
	QP_Consumed = 0,		// Selected activators have their QP reset to this
}

// Player Data Array
enum {
	Player_Index,
	Player_UserID,
	Player_Points,
	Player_Flags,
	Player_ActivatorLast,
	Player_Max
}

// Activators ArrayList Cells
enum {
	AL_Client,
	AL_Health,
	AL_MaxHealth,
	AL_Max,
}

// ConVars
enum {
	// Plugin Server Settings
	P_Enabled,
	P_AutoEnable,
	P_Debug,
	P_SCR,
	P_MapInstructions,
	P_Description,
	
	// Player Interface
	P_ChatKillFeed,
	P_RoundStartMessage,
	P_BossBar,
	P_ActivatorsMax,
	P_ActivatorRatio,
	P_LockActivator,
	
	// Player Attributes
	P_RedSpeed,
	P_RedScoutSpeed,
	P_RedAirDash,
	P_RedMelee,
	P_BlueSpeed,
	P_Buildings,
	P_Pushaway,			// Server's preference
	
	// Server ConVars
	S_Unbalance,
	S_AutoBalance,
	S_Scramble,
	S_Queue,
	S_FirstBlood,		// Not supported by OF
	S_Pushaway,			// Server ConVar. Respects server's preference
	S_WFPTime,
	
	// Work-in-Progress Features
	P_BlueBoost,
	P_RestrictItems,
	P_EnhancedMobility,
	P_ExtraMobility,
	P_HealthScaleMethod,
	
	ConVars_Max
}




/**
 * Bit Flags
 * ----------------------------------------------------------------------------------------------------
 */

// Player Flags
enum {
	PF_PrefActivator = 0x1,			// Wants to be activator
	//PF_PrefFullQP = 0x2,			// Wants full queue points (no longer used)
	PF_PrefEnglish = 0x4,			// Wants English SourceMod
	
	PF_Welcomed = 0x10000,			// Has been welcomed to the server
	PF_Activator = 0x20000,			// Is an activator
	PF_Runner = 0x40000,			// Is a runner
	PF_TurnToken = 0x80000,			// Turn token
	PF_CanBoost = 0x140000,			// Is allowed to use the +speed boost
}

// Player Flag Masks
#define MASK_NEW_PLAYER			( PF_PrefActivator )						// Used to assign default flags to a new player
#define MASK_STORED_FLAGS		( PF_PrefActivator | PF_PrefEnglish )		// Used to store only specific flags in the database
#define MASK_SESSION_FLAGS		( 0xFFFF0000 )								// The session flag block of the player's bit field

// TF Mod
enum {
	Mod_TF = 0x1,					// Mod is TF2
	Mod_OF = 0x2,					// Mod is Open Fortress
	Mod_TF2C = 0x4,					// Mod is TF2 Classic
}

// Engineer Buildings
enum {
	Build_Sentry = 0x1,
	Build_Dispenser = 0x2,
	Build_TeleEnt = 0x4,
	Build_TeleEx = 0x8,
}




/**
 * Variables
 * ----------------------------------------------------------------------------------------------------
 */

ArrayList g_Activators;
ArrayList g_NPCs;

bool g_bSteamTools;					// SteamTools found
bool g_bSCR;						// Steam Chat Relay found
bool g_bTF2Attributes;				// TF2 Attributes found

int g_iGame;
int g_iGameState;
int g_iRoundState;
int g_iTickTimer;
int g_iPlayers[MAXPLAYERS + 1][Player_Max];

ConVar g_ConVars[ConVars_Max];

Database g_db;

Handle g_TimerHPBar;
Handle g_TimerQP;
Handle g_Timer_OFTeamCheck;
Handle g_Text_Boost;

KeyValues g_kvReplacements;
KeyValues g_kvRestrictions;

StringMap g_hSounds;





/**
 * Plugin Info
 * ----------------------------------------------------------------------------------------------------
 */

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= "worMatty",
	description = "Deathrun",
	version 	= PLUGIN_VERSION,
	url 		= ""
};




/**
 * DTK Includes
 * ----------------------------------------------------------------------------------------------------
 */

#include "dtk/methodmaps.sp"
#include "dtk/stocks.sp"
#include "dtk/forwards.sp"
#include "dtk/functions.sp"
#include "dtk/activators.sp"
#include "dtk/events.sp"
#include "dtk/hooks.sp"
#include "dtk/instructions.sp"
#include "dtk/commands.sp"
#include "dtk/menus.sp"
#include "dtk/funstuff.sp"





void ConVar_ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));
	
	if (StrContains(name, "dtk_", false) == 0)
	{
		ShowActivity(0, "%s has been changed from %s to %s", name, oldValue, newValue);
	}
	
	// Enable or disable game mode
	if (convar == g_ConVars[P_Enabled])
	{
		EnableGameMode(g_ConVars[P_Enabled].BoolValue);
	}
	
	// TODO Do the following cause problems when the game mode is not enabled?
	
	// Player Push Away
	else if (convar == g_ConVars[P_Pushaway])
	{
		g_ConVars[S_Pushaway].BoolValue = convar.BoolValue;
	}

	// Red Melee Only
	else if (convar == g_ConVars[P_RedMelee])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).MeleeOnly(convar.BoolValue);
		}
	}
	
	// Red Speed TODO redundant
	else if (convar == g_ConVars[P_RedSpeed])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).SetSpeed(convar.IntValue);
		}
	}
}




void EnableGameMode(bool enabled)
{
	GameDescription(enabled);
	
	if (enabled)
	{
		g_TimerQP = CreateTimer(TIMER_GRANTPOINTS, Timer_GrantPoints, _, TIMER_REPEAT);
		
		// OF stalled round check
		if (DRGame.IsGame(Mod_OF))
			g_Timer_OFTeamCheck = CreateTimer(10.0, Timer_OFTeamCheck, _, TIMER_REPEAT);
		
		g_Activators 	= new ArrayList(AL_Max);
		g_NPCs 			= new ArrayList(AL_Max);
	}
	else
	{
		if (g_TimerQP != null)
			delete g_TimerQP;
		
		// OF stalled round check
		if (DRGame.IsGame(Mod_OF) && g_Timer_OFTeamCheck != null)
			delete g_Timer_OFTeamCheck;
			
		delete g_Activators;
		delete g_NPCs;
	}
	
	// ConVars
	if (enabled)
	{
		//g_ConVars[S_Unbalance].IntValue 		= 0;
		g_ConVars[S_AutoBalance].IntValue 		= 0;
		g_ConVars[S_Scramble].IntValue 			= 0;
		g_ConVars[S_Queue].IntValue 			= 0;
		g_ConVars[S_WFPTime].IntValue 			= 0;	// Needed in OF and TF2C
		g_ConVars[S_Pushaway].BoolValue			= (g_ConVars[P_Pushaway].BoolValue);
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].IntValue = 0;
	}
	else
	{
		g_ConVars[S_Unbalance].RestoreDefault();
		g_ConVars[S_AutoBalance].RestoreDefault();
		g_ConVars[S_Scramble].RestoreDefault();
		g_ConVars[S_Queue].RestoreDefault();
		g_ConVars[S_Pushaway].RestoreDefault();
		g_ConVars[S_WFPTime].RestoreDefault();
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].RestoreDefault();
	}
	
	// Events
	if (enabled)
	{
		HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
		HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
		HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
		HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn);										// Player spawns
		HookEvent("player_team", Event_TeamsChanged);										// Player chooses a team
		HookEvent("player_changeclass", Event_ChangeClass);									// Player changes class
		HookEvent("player_death", Event_PlayerDeath);										// Player dies
		
		if (DRGame.IsGame(Mod_TF))
			HookEvent("post_inventory_application", Event_InventoryApplied);				// Player receives weapons
	}
	else
	{
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_team", Event_TeamsChanged);
		UnhookEvent("player_changeclass", Event_ChangeClass);
		UnhookEvent("player_death", Event_PlayerDeath);
		
		if (DRGame.IsGame(Mod_TF))
			UnhookEvent("post_inventory_application", Event_InventoryApplied);
	}
	
	// Command Listeners
	if (enabled)
	{
		AddCommandListener(CmdListener_LockBlue,	"kill");
		AddCommandListener(CmdListener_LockBlue, 	"explode");
		AddCommandListener(CmdListener_LockBlue, 	"spectate");
		AddCommandListener(CmdListener_Teams, 		"jointeam");
		AddCommandListener(CmdListener_Teams, 		"autoteam");
		AddCommandListener(CmdListener_Builds, 		"build");
	}
	else
	{
		RemoveCommandListener(CmdListener_LockBlue,	"kill");
		RemoveCommandListener(CmdListener_LockBlue,	"explode");
		RemoveCommandListener(CmdListener_LockBlue,	"spectate");
		RemoveCommandListener(CmdListener_Teams, 	"jointeam");
		RemoveCommandListener(CmdListener_Teams, 	"autoteam");
		RemoveCommandListener(CmdListener_Builds, 	"build");
	}
}

Action Timer_GrantPoints(Handle timer)
{
	// Give each red player QP
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).Team == Team_Red)
		{
			Player(i).AddPoints(QP_Award);
		}
	}
}

Action Timer_OFTeamCheck(Handle timer)
{
	// OF starts the round regardless if there aren't enough players
	// A round in progress will only end when one team is dead and the other has live players
	
	if (DRGame.RoundState == Round_Active && (!TFTeam_Red.Alive() && !TFTeam_Blue.Alive()) && DRGame.Participants >= 1)
	{
		Debug("Stalled round detected. Restarting in five seconds");
		TF2_PrintToChatAll(_, "%t", "restarting_round_seconds", 5);
		EmitMessageSoundToAll();
		ServerCommand("mp_restartgame 5");
	}
}