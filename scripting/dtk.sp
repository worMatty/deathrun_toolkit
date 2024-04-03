
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#undef REQUIRE_PLUGIN
#tryinclude <Source-Chat-Relay>	// Discord relay

#undef REQUIRE_EXTENSIONS
#tryinclude <SteamWorks>		// Used to set the game description
#tryinclude <tf2_stocks>		// TF2 Tools extension natives
#tryinclude <tf2items>			// Replacement weapons

// ----------------------------------------------------------------------------------------------------

#define PLUGIN_VERSION			"0.5.3"
#define PLUGIN_NAME				"[DTK] Deathrun Toolkit"
#define PLUGIN_SHORTNAME		"Deathrun Toolkit"

#define SQLITE_DATABASE			"sourcemod-local"
#define SQLITE_TABLE			"dtk_players"
#define SQLITE_RECORDS_EXPIRE	14515200				// Number of seconds until records expire. Default is six months
#define MINIMUM_WILLING			3						// With this many players, activator preference and ban status is ignored
#define TIMER_GRANTPOINTS		10.0					// Frequency of queue point grants in seconds
#define QUEUE_POINT				1						// Points to grant when the timer gets called
#define TIMER_NA_MESSAGE		120.0					// Frequency of next activator message in seconds

#define HELP_URL				"https://steamcommunity.com/groups/death_experiments/discussions/3/3111395113752151418/"
#define WEAPON_REPLACEMENTS_CFG "addons/sourcemod/configs/dtk/replacements.cfg"
#define WEAPON_RESTRICTIONS_CFG "addons/sourcemod/configs/dtk/restrictions.cfg"

StringMap BuildSoundList()
{
	StringMap sounds = new StringMap();
	sounds.SetString("chat_warning", "common/warning.wav");
	sounds.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "misc/talk.wav");
	// TF2: sound/ui/chat_display_text.wav  HL2: ui/buttonclickrelease.wav

	return sounds;
}

// ----------------------------------------------------------------------------------------------------

#define MAX_CHAT_MESSAGE 255	// used by activators.sp, commands.sp, events.sp

bool	   g_bSCR;			 // used by activators.sp, events.sp
bool	   g_bSteamWorks;	 // SteamWorks found
bool		g_bTF2Items;		// TF2Items found
int		   g_GameState;

ConVar	   g_ConVars[ConVars_Max];
DRGameType DRGame;
ArrayList  g_Activators;
StringMap  g_Sounds;

#include "dtk/activators.sp"
#include "dtk/commands.sp"
#include "dtk/convars.sp"
#include "dtk/database.sp"
#include "dtk/events.sp"
#include "dtk/items.sp"
#include "dtk/menus.sp"
#include "dtk/methodmaps.sp"
#include "dtk/stocks.sp"

// ----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name		= PLUGIN_NAME,
	author		= "worMatty",
	description = "Deathrun",
	version		= PLUGIN_VERSION,
	url			= ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("SteamWorks_SetGameDescription");
	MarkNativeAsOptional("SCR_SendEvent");
	MarkNativeAsOptional("TF2Items_CreateItem");
	MarkNativeAsOptional("TF2Items_SetClassname");
	MarkNativeAsOptional("TF2Items_SetItemIndex");
	MarkNativeAsOptional("TF2Items_SetLevel");
	MarkNativeAsOptional("TF2Items_SetQuality");
	MarkNativeAsOptional("TF2Items_SetNumAttributes");
	MarkNativeAsOptional("TF2Items_GiveNamedItem");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	g_bSteamWorks = LibraryExists("SteamWorks");
	g_bSCR		  = LibraryExists("Source-Chat-Relay");
	g_bTF2Items		  = LibraryExists("TF2Items");
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
	if (StrEqual(name, "SteamWorks")) g_bSteamWorks = loaded;
	if (StrEqual(name, "Source-Chat-Relay")) g_bSCR = loaded;
	if (StrEqual(name, "TF2Items")) g_bTF2Items = loaded;
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
	if (g_db != null) {
		for (int i = 1; i <= MaxClients; i++) {
			DRPlayer player = DRPlayer(i);

			if (player.InGame && !player.IsBot) {
				player.SaveData();
			}
		}
	}

	// disable
	g_ConVars[P_Enabled].SetBool(false);
}

public void OnConfigsExecuted()
{
	// auto enable
	if (g_ConVars[P_AutoEnable].BoolValue) {
		char mapname[32];
		GetCurrentMap(mapname, sizeof(mapname));

		if (StrContains(mapname, "dr_", false) != -1 || StrContains(mapname, "deathrun_", false) != -1)
			g_ConVars[P_Enabled].SetBool(true);
	}
}

public void OnMapStart()
{
	DBCreateTable();
	DBPrune();
	g_Activators = new ArrayList();
}

public void OnMapEnd()
{
	delete g_db;
	g_ConVars[P_Enabled].SetBool(false);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	DRPlayer(client).CheckNewPlayer();
}

public void OnClientDisconnect(int client)
{
	DRPlayer player = DRPlayer(client);

	// Save Player Data
	if (g_db != null && !player.IsBot) {
		player.SaveData();
	}
}

public int SteamWorks_SteamServersConnected()
{
	if (g_ConVars[P_Enabled].BoolValue)
		GameDescription(true);
}

// ----------------------------------------------------------------------------------------------------

Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// prevent activators killing themselves
	DRPlayer player = DRPlayer(attacker);
	if (attacker == victim && weapon > MaxClients && IsDeathrunRoundActive() && player.Activator && g_ConVars[P_LockActivator].BoolValue) {
		damage = 0.0;	 // Negate all self damage
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

void ConVar_ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));

	if (StrContains(name, "dtk_", false) == 0) {
		ShowActivity(0, "%s has been changed from %s to %s", name, oldValue, newValue);
	}

	// Enable or disable game mode
	if (convar == g_ConVars[P_Enabled]) {
		EnableGameMode(g_ConVars[P_Enabled].BoolValue);
	}

	// TODO Do the following cause problems when the game mode is not enabled?

	// Red melee-only
	else if (convar == g_ConVars[P_RedMelee]) {
		for (int i = 1; i <= MaxClients; i++) {
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).MeleeOnly(convar.BoolValue);
		}
	}

	// Blue melee-only
	else if (convar == g_ConVars[P_BlueMelee]) {
		for (int i = 1; i <= MaxClients; i++) {
			if (Player(i).InGame && Player(i).Team == Team_Blue) {
				Player(i).MeleeOnly(convar.BoolValue);
			}
		}
	}

	// Red Speed TODO redundant
	else if (convar == g_ConVars[P_RedSpeed]) {
		for (int i = 1; i <= MaxClients; i++) {
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).SetSpeed(convar.IntValue);
		}
	}
}

Handle g_TimerQP;

void   EnableGameMode(bool enabled)
{
	PrecacheAssets(g_Sounds);
	GameDescription(enabled);

	if (enabled) {
		g_TimerQP	 = CreateTimer(TIMER_GRANTPOINTS, Timer_GrantPoints, _, TIMER_REPEAT);
	}
	else {
		if (g_TimerQP != null) {
			delete g_TimerQP;
		}
	}

	// ConVars
	if (enabled) {
		// g_ConVars[S_Unbalance].IntValue 		= 0;
		g_ConVars[S_AutoBalance].IntValue = 0;
		g_ConVars[S_Scramble].IntValue	  = 0;
		g_ConVars[S_Queue].IntValue		  = 0;
		g_ConVars[S_Pushaway].IntValue	  = 0;
		g_ConVars[S_FirstBlood].IntValue  = 0;
	}
	else {
		g_ConVars[S_Unbalance].RestoreDefault();
		g_ConVars[S_AutoBalance].RestoreDefault();
		g_ConVars[S_Scramble].RestoreDefault();
		g_ConVars[S_Pushaway].RestoreDefault();
		g_ConVars[S_Queue].RestoreDefault();
		g_ConVars[S_FirstBlood].RestoreDefault();
	}

	// Events
	if (enabled) {
		HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
		HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
		HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
		HookEvent("teamplay_round_win", Event_RoundEnd);									// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn);										// Player spawns
		HookEvent("player_team", Event_TeamsChanged);										// Player chooses a team
		HookEvent("player_changeclass", Event_ChangeClass);									// Player changes class
		HookEvent("player_death", Event_PlayerDeath);										// Player dies
		HookEvent("post_inventory_application", Event_InventoryApplied);					// Player receives weapons
	}
	else {
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_team", Event_TeamsChanged);
		UnhookEvent("player_changeclass", Event_ChangeClass);
		UnhookEvent("player_death", Event_PlayerDeath);
		UnhookEvent("post_inventory_application", Event_InventoryApplied);
	}

	// Command Listeners
	if (enabled) {
		AddCommandListener(CmdListener_LockBlue, "kill");
		AddCommandListener(CmdListener_LockBlue, "explode");
		AddCommandListener(CmdListener_LockBlue, "spectate");
		AddCommandListener(CmdListener_Teams, "jointeam");
		AddCommandListener(CmdListener_Teams, "autoteam");
		AddCommandListener(CmdListener_Builds, "build");
	}
	else {
		RemoveCommandListener(CmdListener_LockBlue, "kill");
		RemoveCommandListener(CmdListener_LockBlue, "explode");
		RemoveCommandListener(CmdListener_LockBlue, "spectate");
		RemoveCommandListener(CmdListener_Teams, "jointeam");
		RemoveCommandListener(CmdListener_Teams, "autoteam");
		RemoveCommandListener(CmdListener_Builds, "build");
	}

	ServerCommand("exec config_deathrun.cfg");
}

Action Timer_GrantPoints(Handle timer)
{
	// Give each red player QP
	for (int i = 1; i <= MaxClients; i++) {
		DRPlayer player = DRPlayer(i);

		if (player.InGame && player.Team == Team_Red && player.PrefersActivator && !player.ActivatorBanned) {
			player.Points += (player.ReceivesMoreQP ? QUEUE_POINT * 2 : QUEUE_POINT);
		}
	}

	return Plugin_Continue;
}

/**
 * Set the server's game description to the plugin name and version
 * @param	enabled		True to set to the plugin's name, false to return to standard
 * @noreturn
 */
void GameDescription(bool enabled)
{
	if (!g_bSteamWorks) {
		return;
	}

	char description[256];
	g_ConVars[P_Description].GetString(description, sizeof(description));

	if (description[0] == '\0') {
		return;
	}

	if (!enabled)	 // Plugin not enabled
	{
		GetGameDescription(description, sizeof(description), true);
	}
	else {
		ReplaceString(description, sizeof(description), "{plugin_name}", PLUGIN_SHORTNAME, false);
		ReplaceString(description, sizeof(description), "{plugin_version}", PLUGIN_VERSION, false);
	}

	SteamWorks_SetGameDescription(description);
	ShowActivity(0, "Set game description to \"%s\"", description);
}

/**
 * Emit the message sound to a client
 * @param	client	Recipient client index
 * @error	Invalid client index
 */
void EmitMessageSoundToClient(int client)
{
	char effect[256];
	g_Sounds.GetString("chat_reply", effect, sizeof(effect));

	if (effect[0] && client) {
		EmitSoundToClient(client, effect);
	}
}

/**
 * Emit the message sound to all clients
 */
stock void EmitMessageSoundToAll()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			EmitMessageSoundToClient(i);
		}
	}
}

/**
 * Add an attribute to a player or weapon, using VScript.
 * Attributes given in this way are reset on round restart for the player
 * @param 	int 	Entity index
 * @param 	char 	Attribute name
 * @param 	float 	Value. Default 1.0
 * @return	bool	True if successful, false if there was a problem
 */
bool AddAttribute(int entity, char[] attribute, float value = 1.0)
{
	if (IsClient(entity)) {
		return RunScriptCode(entity, "self.AddCustomAttribute(\"%s\", %f, -1)", attribute, value);
	}
	else {
		return RunScriptCode(entity, "self.AddAttribute(\"%s\", %f, -1)", attribute, value);
	}
}

/**
 * Remove an attribute from a player or weapon, using VScript.
 * @param 	int 	Entity index
 * @param 	char 	Attribute
 * @return	bool	True if successful, false if there was a problem
 */
bool RemoveAttribute(int entity, char[] attribute)
{
	if (IsClient(entity)) {
		return RunScriptCode(entity, "self.RemoveCustomAttribute(\"%s\")", attribute);
	}
	else {
		return RunScriptCode(entity, "self.RemoveAttribute(\"%s\")", attribute);
	}
}

/**
 * Check if the deathrun round is running.
 * @return bool		True if deathrun round is active
 */
bool IsDeathrunRoundActive()
{
	// is arena mode
	if (GameRules_GetProp("m_nGameType") == 4) {
		return GameRules_GetRoundState() == RoundState_Stalemate;
	}
	else {
		return GameRules_GetRoundState() == RoundState_RoundRunning;
	}
}