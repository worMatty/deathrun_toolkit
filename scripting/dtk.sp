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

#define DEBUG
#define PLUGIN_AUTHOR		"worMatty"
#define PLUGIN_VERSION 		"0.3"
#define PLUGIN_NAME			"[DTK] Deathrun Toolkit"
#define PLUGIN_SHORTNAME 	"Deathrun Toolkit"
#define PLUGIN_DESCRIPTION	"Deathrun"
#define PREFIX_SERVER		"[DTK]"
#define PREFIX_DEBUG		"[DTK] [Debug]"

#define SQLITE_DATABASE		"sourcemod-local"
#define SQLITE_TABLE		"dtk_players"
#define MINIMUM_ACTIVATORS 	3						// This or below number of willing activators and we use the turn-based system
#define HEALTH_SCALE_BASE	300.0					// The base value used in the activator health scaling system
#define DEFAULT_GAME_DESC	"Source Game Server"	// Default game description when using with unsupported games/mods

#define DRENT_BRANCH				"deathrun_enabled"			// logic_branch
#define DRENT_HEALTH_MATH			"deathrun_health"			// math_counter
#define DRENT_PROPERTIES			"deathrun_properties"		// logic_case
#define DRENT_SETTINGS				"deathrun_settings"			// logic_case
#define DTKENT_BRANCH				"dtk_enabled"				// logic_branch for DTK-specific functions
#define DTKENT_HEALTHSCALE_MAX		"dtk_health_scalemax"		// logic_relay - DEPRECATED
#define DTKENT_HEALTHSCALE_OVERHEAL	"dtk_health_scaleoverheal"	// logic_relay - DEPRECATED




/**
 * Enumerations
 * ----------------------------------------------------------------------------------------------------
 */

// Queue Points
enum {
	QP_Start = 10,			// New players receive this amount on beginning a server session
	QP_Full = 10,			// End of round award
	QP_Partial = 5,			// Reduced end of round award
	QP_Consumed = 0,		// Selected activators have their QP reset to this
}

// Life States
enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
}

// Classes
enum {
	Class_Unknown,
	Class_Scout,
	Class_Sniper,
	Class_Soldier,
	Class_DemoMan,
	Class_Medic,
	Class_Heavy,
	Class_Pyro,
	Class_Spy,
	Class_Engineer
}

// Teams
enum {
	Team_None,
	Team_Spec,
	Team_Red,
	Team_Blue
}

// Player Data Array
enum {
	Player_Index,
	Player_UserID,
	Player_Points,
	Player_Flags,
	Player_Max
}

// Player Speed Array
enum {
	Speed_Last,
	Speed_Desired,
	Speed_Max
}

// ConVars
enum {
	// Plugin Server Settings
	P_Version,
	P_Enabled,
	P_AutoEnable,
	P_Debug,
	P_Database,
	P_SCR,
	P_MapInstructions,
	P_Description,
	
	// Player Interface
	P_ChatKillFeed,
	P_RoundStartMessage,
	P_BossBar,
	P_Activators,
	P_LockActivator,
	//P_Ghosts,
	
	// Player Attributes
	P_RedSpeed,
	P_RedScoutSpeed,
	P_RedAirDash,
	P_RedMelee,
	P_BlueSpeed,
	P_Buildings,
	
	// Server ConVars
	S_Unbalance,
	S_AutoBalance,
	S_Scramble,
	S_Queue,
	S_FirstBlood,		// Not supported by OF
	S_Pushaway,
	S_WFPTime,
	
	// Work-in-Progress Features
	P_BlueBoost,
	P_ActivatorRatio,
	
	ConVars_Max
}

// Timers
enum {
	Timer_HealthBar,
	Timers_Max
}

// Round State
enum {
	Round_Waiting,
	Round_Freeze,
	Round_Active,
	Round_Win
}

// Ammo Types
enum {
	Ammo_Dummy,
	Ammo_Primary,
	Ammo_Secondary,
	Ammo_Metal,
	Ammo_Grenades1,		// Thermal Thruster fuel
	Ammo_Grenades2
}

// Message Types
enum {
	Msg_Normal,
	Msg_Reply,
	Msg_Plugin
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
	PF_PrefActivator = 0x1,
	PF_PrefFullQP = 0x2,
	PF_PrefEnglish = 0x4,
	
	PF_Welcomed = 0x10000,
	PF_Activator = 0x20000,
	PF_Runner = 0x40000,
	PF_PointsEligible = 0x80000,
	PF_CanBoost = 0x140000,
}

// Player Flag Masks
#define MASK_NEW_PLAYER			( PF_PrefActivator | PF_PrefFullQP )
#define MASK_STORED_FLAGS		( PF_PrefActivator | PF_PrefFullQP | PF_PrefEnglish )
#define MASK_SESSION_FLAGS		( 0xFFFF0000 )

// Game Flags
enum {
	GF_LateLoad = 0x1,
	GF_HPBarActive = 0x2,
	GF_WatchMode = 0x4,
}

// TF Mod
enum {
	Mod_TF = 0x1,
	Mod_OF = 0x2,
	Mod_TF2C = 0x4,
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

bool g_bSteamTools;
bool g_bSCR;
bool g_bTF2Attributes;

float g_flSpeeds[MAXPLAYERS + 1][Speed_Max];

int g_iGame;
int g_iGameState;
int g_iRoundState;
int g_iPlayers[MAXPLAYERS + 1][Player_Max];
int g_iBoss;
int g_iEnts[Ent_Max];

ConVar g_ConVars[ConVars_Max];

Database g_db;

Handle g_hTimers[Timers_Max];
Handle hBoostHUD;

StringMap g_hSounds;
StringMap SoundList()
{
	StringMap hSounds = new StringMap();
	hSounds.SetString("chat_plugin",	"common/warning.wav");
	hSounds.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "misc/talk.wav");
		// TF2: sound/ui/chat_display_text.wav  HL2: ui/buttonclickrelease.wav
	
	return hSounds;
}




/**
 * Plugin Info
 * ----------------------------------------------------------------------------------------------------
 */

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
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
