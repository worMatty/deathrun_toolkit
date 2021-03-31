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

#define DEBUG

#pragma semicolon 1
#pragma newdecls required




/**
 * Definitions
 * ----------------------------------------------------------------------------------------------------
 */

#define PLUGIN_VERSION 		"0.4.1"
#define PLUGIN_NAME			"[DTK] Deathrun Toolkit"
#define PLUGIN_SHORTNAME 	"Deathrun Toolkit"
#define PREFIX_SERVER		"[DTK]"
#define PREFIX_DEBUG		"[DTK] [Debug]"

#define SQLITE_DATABASE		"sourcemod-local"
#define SQLITE_TABLE		"dtk_players"
#define MINIMUM_WILLING 	3						// This or below number of willing activators and everyone takes it in turns
#define HEALTH_SCALE_BASE	300.0					// The base value used in the activator health scaling system
#define DEFAULT_GAME_DESC	"Source Game Server"	// Default game description when using with unsupported games/mods
#define TIMER_GRANTPOINTS	10.0

#define DRENT_BRANCH				"deathrun_enabled"			// logic_branch
#define DRENT_MATH_BOSS				"deathrun_boss"				// math_counter for boss bar
#define DRENT_MATH_MINIBOSS			"deathrun_miniboss"			// math_counter for mini bosses
#define DRENT_PROPERTIES			"deathrun_properties"		// logic_case
#define DRENT_SETTINGS				"deathrun_settings"			// logic_case
#define DTKENT_BRANCH				"dtk_enabled"				// logic_branch for DTK-specific functions
#define DTKENT_HEALTHSCALE_MAX		"dtk_health_scalemax"		// logic_relay - DEPRECATED
#define DTKENT_HEALTHSCALE_OVERHEAL	"dtk_health_scaleoverheal"	// logic_relay - DEPRECATED

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
	P_Version,
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
	
	ConVars_Max
}

// Entities
enum {
	Ent_PlayerRes,
	Ent_MonsterRes,
	Ent_Max
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
int g_iEnts[Ent_Max] = { -1, ... };

ConVar g_ConVars[ConVars_Max];

Database g_db;

Handle g_TimerHPBar;
Handle g_TimerQP;
Handle g_Timer_OFTeamCheck;
Handle g_Text_Boost;

KeyValues g_Replacements;
KeyValues g_Restrictions;

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
#include "dtk/events.sp"
#include "dtk/hooks.sp"
#include "dtk/commands.sp"
#include "dtk/menus.sp"
#include "dtk/timers.sp"
#include "dtk/funstuff.sp"
