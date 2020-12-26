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
#define PLUGIN_VERSION 		"0.285"
#define PLUGIN_NAME			"[DTK] Deathrun Toolkit Base"
#define PLUGIN_SHORTNAME 	"Deathrun Toolkit"
#define PLUGIN_DESCRIPTION	"Basic functions for the deathrun game mode"
#define MAXPLAYERS_TF2		34						// Source TV + 1 for client index offset
#define PREFIX_SERVER		"[DTK]"
#define PREFIX_DEBUG		"[DTK] [Debug]"

#define SQLITE_DATABASE		"sourcemod-local"
#define SQLITE_TABLE		"dtk_players"
#define MINIMUM_ACTIVATORS 	3						// This or below number of willing activators and we use the turn-based system
#define HEALTH_SCALE_BASE	300.0					// The base value used in the activator health scaling system
#define STRING_YOUR_MOD		"Source Game Server"	// Default game description when using with unsupported games/mods




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

// Default Class Run Speeds
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

// Life States
enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
	LifeState_Any = 255		// A custom value used for our purposes
}

// Classes
enum {
	Class_Unknown = 0,
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
	Team_None = 0,
	Team_Spec,
	Team_Red,
	Team_Blue,
	Team_Both = 254,
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

// Games / TF Mods
enum {
	Game_Unknown,
	Game_TF,
	Game_OF,
	Game_TF2C
}

// ConVars
enum {
	// Plugin Server Settings
	P_Version = 0,
	P_Enabled,
	P_AutoEnable,
	P_Debug,
	P_SQLite,
	P_SCR,
	P_UsePoints,
	P_MapInstructions,
	
	// Player Interface
	P_ChatKillFeed,
	P_RoundStartMessage,
	P_BossBar,
	P_Activators,
	P_TeamPush,
	P_TeamPushRemaining,
	P_NoBlueSuicide,
	
	// Player Attributes
	P_RedSpeed,
	P_RedScoutSpeed,
	
	// Player Weapons & Abilities
	P_RedDemoCharge,
	P_RedSpyCloak,
	P_BlastPushing,
	P_Buildings,
	P_EurekaEffect,
	P_ThermalThruster,
	
	// Server ConVars
	S_Unbalance,
	S_AutoBalance,
	S_Scramble,
	S_Queue,
	S_FirstBlood,		// Not supported by OF
	S_Pushaway,
	
	ConVars_Max
}

// Round State
enum {
	Round_Waiting = 0,
	Round_Freeze,
	Round_Active,
	Round_Win
}

// Weapon Slots
enum {
	Weapon_Primary = 0,
	Weapon_Secondary,
	Weapon_Melee,
	Weapon_Grenades,
	Weapon_Building,
	Weapon_PDA,
	Weapon_ArrayMax
}

// Ammo Types
enum {
	Ammo_Dummy = 0,
	Ammo_Primary,
	Ammo_Secondary,
	Ammo_Metal,
	Ammo_Grenades1,		// Thermal Thruster fuel
	Ammo_Grenades2
}




/**
 * Bit Flags
 * ----------------------------------------------------------------------------------------------------
 */

// Engineer Building Restriction
#define BUILD_SENTRY			( 1 << 0 )
#define BUILD_DISPENSER			( 1 << 1 )
#define BUILD_TELE_ENTR			( 1 << 2 )
#define BUILD_TELE_EXIT			( 1 << 3 )

// Player Preferences
#define PREF_ACTIVATOR			( 1 << 0 )
#define PREF_FULL_QP			( 1 << 1 )
#define PREF_ENGLISH			( 1 << 4 )

// Session
#define SESSION_WELCOMED		( 1 << 17 )
#define SESSION_ARMED			( 1 << 18 )		// When a player has been given a weapon by a map instruction
#define SESSION_ACTIVATOR		( 1 << 19 )
#define SESSION_RUNNER			( 1 << 20 )

// Games or Source Mods
#define FLAG_TF					( 1 << 0 )
#define FLAG_OF					( 1 << 1 ) 
#define FLAG_TF2C				( 1 << 2 )

// Masks
#define PREF_DEFAULT			( PREF_ACTIVATOR | PREF_FULL_QP )
#define MASK_STORED				( PREF_ACTIVATOR | PREF_FULL_QP | PREF_ENGLISH )
#define MASK_SESSION			( 0xFFFF0000 )




/**
 * Variables
 * ----------------------------------------------------------------------------------------------------
 */

bool g_bSteamTools;
bool g_bTF2Attributes;
bool g_bSCR;
bool g_bHookSingleEntityOutput;

bool g_bSettingsRead;
bool g_bBlueWarnedSuicide;
bool g_bWatchForPlayerChanges;
bool g_bHealthBarActive;
bool g_bRoundActive; 				// For OF until I find out how to check round state


int g_iGame;
int g_iHealthBar[HealthBar_ArraySize];
int g_iPlayers[MAXPLAYERS_TF2][Player_ArrayMax];
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
ConVar g_cMapInstructions;			// Allow the use of map instructions to set player properties.

ConVar g_cTeamsUnbalanceLimit;
ConVar g_cAutoBalance;
ConVar g_cScramble;
ConVar g_cArenaQueue;
ConVar g_cArenaFirstBlood;
ConVar g_cServerTeamMatePush;
ConVar g_cRoundWaitTime;
//ConVar g_cHumansMustJoinTeam;

Handle hBarTimer = null;
Handle g_hHealthText;

Database g_db;

StringMap g_hSound;

StringMap SoundList()
{
	StringMap hSound = new StringMap();
	hSound.SetString("warden_instruction",	"buttons/button17.wav");
	hSound.SetString("chat_debug", 			"common/warning.wav");
	hSound.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "ui/buttonclickrelease.wav");	
	
	return hSound;
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
	url = ""
};




/**
 * DTK Includes
 * ----------------------------------------------------------------------------------------------------
 */

#include "dtk/methodmaps"
#include "dtk/forwards"
#include "dtk/events"
#include "dtk/hooks"
#include "dtk/stocks"
#include "dtk/tools"
#include "dtk/commands"
#include "dtk/menus"
#include "dtk/funstuff" 
