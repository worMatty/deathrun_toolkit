#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdkhooks>

//#define DEBUG
#define PLUGIN_NAME 		"[DTK] QoL Train Control"
#define PLUGIN_VERSION 		"0.2"



ConVar g_cEnabled;



public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "Patch func_track/tanktrains to prevent them being +used",
	version = PLUGIN_VERSION,
	url = ""
};




public void OnPluginStart()
{
	g_cEnabled = CreateConVar("dtk_qol_patch_trains", "0", "Patch trains on spawn to disable user control", _, true, 0.0, true, 1.0);
	g_cEnabled.AddChangeHook(ChangeHook);
}




// Disable plugin on map change
public void OnMapEnd()
{
	g_cEnabled.RestoreDefault();
}




public void OnEntityCreated(int train, const char[] classname)
{
	if (g_cEnabled.BoolValue)
	{
		if (StrEqual(classname, "func_tracktrain", false) || StrEqual(classname, "func_tanktrain", false))
		{
			SDKHook(train, SDKHook_SpawnPost, SpawnPost);
		}
	}
}




// Give trains the No User Control flag
void SpawnPost(int train)
{	
	if (!(GetEntProp(train, Prop_Data, "m_spawnflags") & 2))
	{
		SetEntProp(train, Prop_Data, "m_spawnflags", GetEntProp(train, Prop_Data, "m_spawnflags") | 2);
		LogMessage("Turned off user control for train entity %d", train);
	}
	
	SDKUnhook(train, SDKHook_SpawnPost, SpawnPost);
}




void ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char sName[64];
	convar.GetName(sName, sizeof(sName));
	LogMessage("%s changed from %s to %s", sName, oldValue, newValue);
}