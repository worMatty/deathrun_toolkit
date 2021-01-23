#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>

#undef REQUIRE_PLUGIN
#include <Source-Chat-Relay>

#pragma newdecls required

#define DEBUG
#define PLUGIN_SHORTNAME 	"Sacrifice"
#define PLUGIN_NAME 		"[DTK] Sacrifice"
#define PLUGIN_VERSION 		"0.2.1"
#define SERVERMSG_PREFIX	"[DTK] [Sac]"
#define PREFIX				"\x08B071FF80[DR]\x01" // D258B4
#define DEBUG_PREFIX		" [DTK] [Sac] debugging >"
#define TF2MAXPLAYERS		34	// 32 clients and 1 Source TV client, offset by 1 for matching array indexes

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "Sacrifice yourself to bring a dead team mate back to life in your place",
	version = PLUGIN_VERSION,
	url = ""
};

int g_iCanSacrifice[TF2MAXPLAYERS];

bool g_bSCR;

ConVar g_cEnabled;
ConVar g_cDebug;
ConVar g_cSCR;

enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
	LifeState_Any = 255		// For our purposes
}

/*  Things to do
	1. Apply player's velocity and movement direction
	2. Make sure health transfer is capped so no overheal occurs
	
	3. Consider a cooldown timer. Maybe ten seconds. - No longer needed
	4. What happens when you do it while dead? - You can't
	5. Kill a player without triggering a bomb - Not relevant
	6. "You must be alive to sacrifice!" - Done
	7. No sacrificing when there are no dead players. - Players can only sac when the target is dead, so Done
	8. No sacrificing outside of a round. - Done
	9. Announce that someone has sacrificed themselves. - DONE
	10. Look at Blue sacrificing and maybe disable it. - essentially done
	11. Add alternative command 'sacrifice' - DONE
	
	Suggestions
	-----------
	
	IzotopeToday at 20:36
	@worMatty Suggestion for your sacrifice feature:
	- Respawned player can't sacrifice this round.
	- 30 second cooldown before a sacrificed player can be respawned
	
	Bugs:
	-----
	
	Two players spamming the command on each other will cause both of them to be alive. - Sorted.
*/


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("SCR_SendEvent");
	return APLRes_Success;
}

// Library checking
public void OnAllPluginsLoaded()
{
	if (!(g_bSCR = LibraryExists("Source-Chat-Relay")))
		LogError("Source Chat Relay isn't loaded. Won't be able to send sacrifice events to Discord");
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
	if (StrEqual(name, "Source-Chat-Relay"))
	{	
		g_bSCR = loaded;
		LogMessage("SCR has been %s", (loaded) ? "loaded" : "unloaded");
		ShowActivity(0, "SCR has been %s", (loaded) ? "loaded" : "unloaded");
	}
}


public void OnPluginStart()
{
	RegConsoleCmd("sm_sac", Command_Sacrifice, "Sacrifice your life to bring a dead team mate back in your place.");
	RegConsoleCmd("sm_sacrifice", Command_Sacrifice, "Sacrifice your life to bring a dead team mate back in your place.");
	
	g_cEnabled = CreateConVar("dtk_sacrifice", "1", "Allow live players to sacrifice themselves for a dead teammate", _, true, 0.0, true, 1.0);
	g_cEnabled.AddChangeHook(ChangeHook);
	g_cDebug = CreateConVar("dtk_sacrifice_debug", "0", "Log actions performed by Sacrifice", _, true, 0.0, true, 1.0);
	g_cDebug.AddChangeHook(ChangeHook);
	g_cSCR = CreateConVar("dtk_sacrifice_scr", "1", "Send Source Chat Relay events to your Discord server", _, true, 0.0, true, 1.0);
	g_cSCR.AddChangeHook(ChangeHook);
	
	HookEvent("teamplay_round_active", RoundStart, EventHookMode_PostNoCopy);
	HookEvent("arena_round_start", RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath);
	//HookEvent("teamplay_round_win", EventRoundWin);
}


void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsPlayerAlive(i))
			g_iCanSacrifice[i] = true;
		else
			g_iCanSacrifice[i] = false;
	
	if (g_cDebug.BoolValue) PrintToServer("%s Res tokens reset", DEBUG_PREFIX);
}


void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iCanSacrifice[client] = false;
	if (g_cDebug.BoolValue) PrintToServer("%s %N lost their res token through dying", DEBUG_PREFIX, client);
}


Action Command_Sacrifice(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
		
	if (args != 1)
	{
		ReplyToCommand(client, "%s Usage: sm_sac <dead player|#userid>", PREFIX);
		return Plugin_Handled;
	}

	if (!(GameRules_GetRoundState() == RoundState_RoundRunning || GameRules_GetRoundState() == RoundState_Stalemate))
	{
		ReplyToCommand(client, "%s Round is not active", PREFIX);
		if (g_cDebug.BoolValue) PrintToServer("%s %N tried to use sm_sac but the round isn't active", DEBUG_PREFIX, client);
		return Plugin_Handled;
	}
	
	if (!g_iCanSacrifice[client] || !IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s You no longer have a soul to give...", PREFIX);
		if (g_cDebug.BoolValue)
			PrintToServer("%s %N tried to sacrifice themselves but they don't have a res token", DEBUG_PREFIX, client);
		return Plugin_Handled;
	}

	char arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int target = FindTarget(client, arg1, false, false);

	if (target <= 0)
	{
		ReplyToTargetError(client, target);
		return Plugin_Handled;
	}
	else if (GetClientTeam(target) != GetClientTeam(client))
	{
		ReplyToCommand(client, "%s Target needs to be on the same team", PREFIX);
		return Plugin_Handled;
	}
	else if (IsPlayerAlive(target))
	{
		ReplyToCommand(client, "%s Target needs to be dead...", PREFIX);
		return Plugin_Handled;
	}
	
	float client_pos[3]; GetClientAbsOrigin(client, client_pos);
	float client_angles[3]; GetClientAbsAngles(client, client_angles);
	int client_health = GetClientHealth(client);

	// Teleport target to us and respawn them
	TF2_RespawnPlayer(target);
	TeleportEntity(target, client_pos, client_angles, NULL_VECTOR);
	SetEntityHealth(target, client_health);
	SetVariantString("TLK_RESURRECTED");
	AcceptEntityInput(target, "SpeakResponseConcept");
	EmitGameSoundToAll("MVM.PlayerRevived", target);
	
	// Sacrifice ourselves
	//SetEntProp(client, Prop_Send, "m_lifeState", LifeState_Dead);
	ForcePlayerSuicide(client);
	g_iCanSacrifice[client] = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (i == client)
			{
				PrintToChat(client, "%s You have sacrificed yourself for %N. You may not sacrifice again this round", PREFIX, target);
			}
			else if (i == target)
			{
				PrintToChat(i, "%s %N has sacrificed themselves to give you a second chance. Use it wisely", PREFIX, client);
			}
			else
			{
				PrintToChat(i, "%s %N sacrificed themselves to bring %N back from the dead", PREFIX, client, target);
			}
		}
	}
	
	if (g_cDebug.BoolValue)
		PrintToServer("%s %N sacrificed themselves for %N", DEBUG_PREFIX, client, target);
	
	if (g_cSCR.BoolValue && g_bSCR)
		SCR_SendEvent(PLUGIN_NAME, "%N sacrificed themselves for %N", client, target);

	return Plugin_Handled;
}


void ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[64];
	convar.GetName(sName, sizeof(sName));
	PrintToServer("%s %s changed from %s to %s", SERVERMSG_PREFIX, sName, oldValue, newValue);
}