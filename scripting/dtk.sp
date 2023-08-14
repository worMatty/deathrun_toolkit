
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#tryinclude <tf2attributes>		// Used to set player and weapon attributes
#tryinclude <Source-Chat-Relay>	// Discord relay

#undef REQUIRE_EXTENSIONS
#tryinclude <SteamWorks>		// Used to set the game description
#tryinclude <tf2_stocks>		// TF2 Tools extension natives

// ----------------------------------------------------------------------------------------------------

#define PLUGIN_VERSION 				"0.4.7"
#define PLUGIN_NAME					"[DTK] Deathrun Toolkit"
#define PLUGIN_SHORTNAME 			"Deathrun Toolkit"

#define SQLITE_DATABASE				"sourcemod-local"
#define SQLITE_TABLE				"dtk_players"
#define SQLITE_RECORDS_EXPIRE		14515200				// Number of seconds until records expire. Default is six months
#define MINIMUM_WILLING 			3						// With this many players, activator preference and ban status is ignored
#define DEFAULT_GAME_DESC			"Source Game Server"	// Default game description when using with unsupported games/mods
#define TIMER_GRANTPOINTS			10.0					// Frequency of queue point grants in seconds
#define QUEUE_POINT					1						// Points to grant when the timer gets called
#define TIMER_NA_MESSAGE			120.0					// Frequency of next activator message in seconds

#define HELP_URL					"https://steamcommunity.com/groups/death_experiments/discussions/3/3111395113752151418/"
#define WEAPON_REPLACEMENTS_CFG		"addons/sourcemod/configs/dtk/replacements.cfg"
#define WEAPON_RESTRICTIONS_CFG		"addons/sourcemod/configs/dtk/restrictions.cfg"

StringMap BuildSoundList()
{
	StringMap sounds = new StringMap();
	sounds.SetString("chat_warning",	"common/warning.wav");
	sounds.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "misc/talk.wav");
	// TF2: sound/ui/chat_display_text.wav  HL2: ui/buttonclickrelease.wav

	return sounds;
}

// ----------------------------------------------------------------------------------------------------

// #define MAP_INSTRUCTIONS
// #define BOOST_HUD

#define MAX_CHAT_MESSAGE		255		// used by activators.sp, commands.sp, events.sp

bool g_bSCR;							// used by activators.sp, events.sp

int g_GameState;

ConVar g_ConVars[ConVars_Max];

DRGameType DRGame;

PlayerList g_Activators;				// used by activators.sp, funstuff.sp, methodmaps.sp

#include "dtk/activators.sp"
#include "dtk/commands.sp"
#include "dtk/convars.sp"
#include "dtk/database.sp"
#include "dtk/events.sp"
#include "dtk/funstuff.sp"
#include "dtk/items.sp"
#include "dtk/menus.sp"
#include "dtk/methodmaps.sp"
#include "dtk/stocks.sp"

StringMap g_Sounds;

bool g_bSteamWorks;					// SteamWorks found
bool g_bTF2Attributes;				// TF2 Attributes found

// ----------------------------------------------------------------------------------------------------

public Plugin myinfo =
{
	name 		= PLUGIN_NAME,
	author 		= "worMatty",
	description = "Deathrun",
	version 	= PLUGIN_VERSION,
	url 		= ""
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	MarkNativeAsOptional("SCR_SendEvent");

	if (late)
	{
		DRGame.LateLoaded = true;
	}

	return APLRes_Success;
}


public void OnAllPluginsLoaded()
{
	// Check for the existence of libraries that DTK can use
	if (!(g_bSteamWorks = LibraryExists("SteamWorks")))
	{
		LogMessage("Library not found: SteamWorks. Unable to change server game description");
	}

	// if (!(g_bTF2Attributes = LibraryExists("tf2attributes")))
	// {
	// 	LogMessage("Library not found: TF2 Attributes. Unable to modify weapon or player attributes");
	// }

	if (!(g_bSCR = LibraryExists("Source-Chat-Relay")))
	{
		LogMessage("Library not found: Source Chat Relay. Unable to send event messages to Discord");
	}
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
	if (StrEqual(name, "SteamWorks"))			g_bSteamWorks 		= loaded;
	// if (StrEqual(name, "tf2attributes"))		g_bTF2Attributes 	= loaded;
	if (StrEqual(name, "Source-Chat-Relay"))	g_bSCR 				= loaded;
}


public void OnPluginStart()
{
	LoadTranslations("dtk.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("basebans.phrases");

	ConVars_Init();
	Commands_Init();
	Items_Init();
	g_Sounds = BuildSoundList();
}

public void OnPluginEnd()
{
	// Save Player Data
	if (g_db != null)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			DRPlayer player = DRPlayer(i);

			if (player.InGame && !player.IsBot)
			{
				player.SaveData();
			}
		}
	}

	g_ConVars[P_Enabled].SetBool(false);
}


public void OnConfigsExecuted()
{
	if (g_ConVars[P_AutoEnable].BoolValue)
	{
		char mapname[32];
		GetCurrentMap(mapname, sizeof(mapname));

		if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
			g_ConVars[P_Enabled].SetBool(true);
	}

	if (g_ConVars[P_Enabled].BoolValue)
	{
		PrecacheAssets(g_Sounds);
		ServerCommand("exec config_deathrun.cfg");		// TODO Does this happen when reloading the plugin?
	}
}


public void OnMapStart()
{
	DBCreateTable();
	DBPrune();

	DRGame.RoundState = Round_Waiting;

	if (DRGame.LateLoaded)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame)
			{
				OnClientAuthorized(i, "");
				OnClientPutInServer(i);
			}
		}

		DRGame.LateLoaded = false;
	}
}

public void OnMapEnd()
{
	delete g_db;

	if (g_ConVars[P_Enabled].BoolValue)
	{
		g_ConVars[P_Enabled].SetBool(false);
	}
}


public void OnClientAuthorized(int client, const char[] auth)
{
	DRPlayer(client).CheckNewPlayer();
}

public void OnClientPutInServer(int client)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;

	if (GetFeatureStatus(FeatureType_Native, "SDKHook") == FeatureStatus_Available)
	{
		SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_OnTakeDamage);
	}
}

public void OnClientDisconnect(int client)
{
	DRPlayer player = DRPlayer(client);

	// Save Player Data
	if (g_db != null && !player.IsBot)
	{
		player.SaveData();
	}
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return;

	#if defined BOOST_HUD
	// Monitor and apply activator boosts
	ActivatorBoost(client, buttons, tickcount);
	#endif
}


public int SteamWorks_SteamServersConnected()
{
	if (g_ConVars[P_Enabled].BoolValue)
		GameDescription(true);
}

// ----------------------------------------------------------------------------------------------------

Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool changed;

	// Blast Pushing / Self Damage
	if (attacker == victim && !g_ConVars[P_ExtraMobility].BoolValue)
	{
		damage = 0.0;		// Negate all self damage
		changed = true;
	}

	return (changed) ? Plugin_Changed : Plugin_Continue;
}


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

	// Red melee-only
	else if (convar == g_ConVars[P_RedMelee])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).MeleeOnly(convar.BoolValue);
		}
	}

	// Blue melee-only
	else if (convar == g_ConVars[P_BlueMelee])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Blue)
			{
				Player(i).MeleeOnly(convar.BoolValue);
			}
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


Handle g_TimerQP;
Handle g_Timer_OFTeamCheck;

void EnableGameMode(bool enabled)
{
	GameDescription(enabled);

	if (enabled)
	{
		g_TimerQP = CreateTimer(TIMER_GRANTPOINTS, Timer_GrantPoints, _, TIMER_REPEAT);

		// OF stalled round check
		if (IsGameOpenFortress())
		{
			g_Timer_OFTeamCheck = CreateTimer(10.0, Timer_OFTeamCheck, _, TIMER_REPEAT);
		}

		g_Activators = new PlayerList();
	}
	else
	{
		if (g_TimerQP != null)
			delete g_TimerQP;

		// OF stalled round check
		if (IsGameOpenFortress() && g_Timer_OFTeamCheck != null)
			delete g_Timer_OFTeamCheck;

		delete g_Activators;
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
		HookEvent("teamplay_round_win", Event_RoundEnd);									// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn);										// Player spawns
		HookEvent("player_team", Event_TeamsChanged);										// Player chooses a team
		HookEvent("player_changeclass", Event_ChangeClass);									// Player changes class
		HookEvent("player_death", Event_PlayerDeath);										// Player dies

		if (IsGameTF2())
			HookEvent("post_inventory_application", Event_InventoryApplied);				// Player receives weapons
	}
	else
	{
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_team", Event_TeamsChanged);
		UnhookEvent("player_changeclass", Event_ChangeClass);
		UnhookEvent("player_death", Event_PlayerDeath);

		if (IsGameTF2())
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
		DRPlayer player = DRPlayer(i);

		if (player.InGame && player.Team == Team_Red && player.PrefersActivator && !player.ActivatorBanned)
		{
			player.Points += (player.ReceivesMoreQP ? QUEUE_POINT * 2 : QUEUE_POINT);
		}
	}

	return Plugin_Continue;
}

Action Timer_OFTeamCheck(Handle timer)
{
	// OF starts the round regardless if there aren't enough players
	// A round in progress will only end when one team is dead and the other has live players

	if (DRGame.RoundState == Round_Active && (!TFTeam_Red.AliveCount() && !TFTeam_Blue.AliveCount()) && GetActiveClientCount() >= 1)
	{
		TF2_PrintToChatAll(_, "%t", "restarting_round_seconds", 5);
		EmitMessageSoundToAll();
		ServerCommand("mp_restartgame 5");
	}

	return Plugin_Continue;
}


/**
 * Set the server's game description to the plugin name and version
 *
 * @param	enabled		True to set to the plugin's name, false to return to standard
 * @noreturn
 */
void GameDescription(bool enabled)
{
	if (!g_bSteamWorks)
		return;

	char description[256];
	g_ConVars[P_Description].GetString(description, sizeof(description));

	if (description[0] == '\0')
		return;

	if (!enabled) // Plugin not enabled
	{
		// TODO Replace this with an OnMapStart string storage, as no mod should be changing the description at this point
		// and if it is then it must be a global thing so is desired
		if 			(IsGameTF2())		Format(description, sizeof(description), "Team Fortress");
		else if 	(IsGameOpenFortress())		Format(description, sizeof(description), "Open Fortress");
		else if 	(IsGameTF2Classic())	Format(description, sizeof(description), "Team Fortress 2 Classic");
		else 									Format(description, sizeof(description), DEFAULT_GAME_DESC);
	}
	else
	{
		ReplaceString(description, sizeof(description), "{plugin_name}", PLUGIN_SHORTNAME, false);
		ReplaceString(description, sizeof(description), "{plugin_version}", PLUGIN_VERSION, false);
	}

	SteamWorks_SetGameDescription(description);
	ShowActivity(0, "Set game description to \"%s\"", description);
}


/**
 * Emit the message sound to a client
 *
 * @param	client	Recipient client index
 * @error	Invalid client index
 */
void EmitMessageSoundToClient(int client)
{
	char effect[256];
	g_Sounds.GetString("chat_reply", effect, sizeof(effect));

	if (effect[0] && client)
	{
		EmitSoundToClient(client, effect);
	}
}

/**
 * Emit the message sound to all clients
 */
void EmitMessageSoundToAll()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitMessageSoundToClient(i);
		}
	}
}


/**
 * Add Attribute
 * Apply an attribute to an entity.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute name
 * @param 	float 	Value. Default 1.0
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool AddAttribute(int entity, char[] attribute, float value = 1.0)
{
	// Return false if game is not TF2 as only TF2 supports attributes
	char folder[8];
	GetGameFolderName(folder, sizeof(folder));

	if (!StrEqual(folder, "tf"))
	{
		return false;
	}

	if (g_bTF2Attributes)
	{
		return TF2Attrib_SetByName(entity, attribute, value);
	}
	else	// use VScript
	{
		if (IsClient(entity))
		{
			return RunScriptCode(entity, "self.AddCustomAttribute(\"%s\", %f, 0.0)", attribute, value);
		}
		else
		{
			return RunScriptCode(entity, "self.AddAttribute(\"%s\", %f, 0.0)", attribute, value);
		}
	}
}

/**
 * Remove Attribute
 * Remove an attribute from an entity.
 *
 * @param 	int 	Entity index
 * @param 	char 	Attribute
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool RemoveAttribute(int entity, char[] attribute)
{
	if (g_bTF2Attributes)
	{
		return TF2Attrib_RemoveByName(entity, attribute);
	}
	else	// use VScript
	{
		if (IsClient(entity))
		{
			return RunScriptCode(entity, "self.RemoveCustomAttribute(\"%s\")", attribute);
		}
		else
		{
			return RunScriptCode(entity, "self.RemoveAttribute(\"%s\")", attribute);
		}
	}
}

/**
 * Remove All Attributes
 * Remove all attributes from an entity.
 *
 * @param 	int 	Entity index
 *
 * @return	bool	True if successful, false if there was a problem
 */
stock bool RemoveAllAttributes(int entity)
{
	if (g_bTF2Attributes)
		return TF2Attrib_RemoveAll(entity);
	else
		return false;
}
