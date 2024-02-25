#pragma semicolon 1
#pragma newdecls required

#define DEBUG
#define PLUGIN_NAME		"[DTK] QoL Damage Filter"
#define PLUGIN_VERSION	"0.1"
#define PREFIX			"[DTK Damage Filter]"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>



/*	
	Todo
	----

	* Filter damage from red to blue using damage bits
	* Filter damage from blue to red using damage bits
	* Debugging convar
	* Filter damage on buttons
	* Allow damage from red to blue when blue first hits red (first blood)
	
*/



// ConVar enum
enum {
	C_Enabled,
	C_RedBits,
	C_BlueBits,
	C_Debug,
	C_Max
}

ConVar g_ConVar[C_Max];




public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "A QoL plugin that filters damage between red and blue. Useful on old ported maps",
	version = PLUGIN_VERSION,
	url = ""
};



public void OnPluginStart()
{
	// Fail if SDKHooks is not supported
	if (GetFeatureStatus(FeatureType_Native, "SDKHook") != FeatureStatus_Available)
		SetFailState("%s requires SDKHooks. Check your game data", PLUGIN_NAME);

	// Create convars
	g_ConVar[C_Enabled] 	= CreateConVar("dtk_qol_df", "0", "Filter damage between teams");
	g_ConVar[C_RedBits] 	= CreateConVar("dtk_qol_df_red_bits", "0", "If a red damage event on a blue player contains any of these bits it is filtered out");
	g_ConVar[C_BlueBits] 	= CreateConVar("dtk_qol_df_blue_bits", "0", "If a blue damage event on a red player contains any of these bits it is filtered out");
	g_ConVar[C_Debug] 		= CreateConVar("dtk_qol_df_debug", "0", "Debug mode that prints damage bit values to client console");
	
	// Hook convars
	for (int i = 0; i < C_Max; i++)
		g_ConVar[i].AddChangeHook(Hook_ConVar);
}



public void OnMapEnd()
{
	// Disable plugin on map end
	g_ConVar[C_Enabled].BoolValue = false;
}




public void OnClientPutInServer(int client)
{
	if (!g_ConVar[C_Enabled].BoolValue)
		return;
	
	// Hook damage on user
	SDKHook(client, SDKHook_OnTakeDamageAlive, Hook_Damage);
}



Action Hook_Damage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype)
{
	if (g_ConVar[C_Debug].BoolValue)
		PrintToConsole(attacker, "Your damage bits on %N were %b (%d)", victim, damagetype, damagetype);
	
	if (!g_ConVar[C_Enabled].BoolValue)
		return Plugin_Continue;

	bool changed;

	// If combatants are on different teams
	if (GetClientTeam(attacker) != GetClientTeam(victim))
	{
		switch (GetClientTeam(attacker))
		{
			case 2: // attacker is on red team
			{
				if (damagetype & g_ConVar[C_RedBits].IntValue)
				{
					damage = 0.0;
					changed = true;
					if (g_ConVar[C_Debug].BoolValue)
						PrintToConsole(attacker, "Your damage matched a convar bit and was nullified");
				}
			}
			
			case 3: // attacker is on blue team
			{
				if (damagetype & g_ConVar[C_BlueBits].IntValue)
				{
					damage = 0.0;
					changed = true;
					if (g_ConVar[C_Debug].BoolValue)
						PrintToConsole(attacker, "Your damage matched a convar bit and was nullified");
				}
			}
		}
	}
	
	if (changed)
		return Plugin_Changed;
	
	return Plugin_Continue;
}




void Hook_ConVar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));
	
	PrintToServer("%s %s set to %s", PREFIX, name, newValue);
}

