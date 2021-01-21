#pragma semicolon 1
#pragma newdecls required

#define DEBUG
#define PLUGIN_VERSION "0.1"
#define PREFIX "[DTK +use]"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>



/*	
	Bugs
	----

	I you set the Useable spawnflag on a button that didn't have it previously, it will take one damage event to make it 'update'
	before it will respond to the next damage event. (is this still a problem? 2021.01.20)
	
	Todo
	----
	
	See if buttons with melee filters will work with this plugin.
	Don't give a button the useable spawnflag if it already has it.
*/



ConVar g_cEnabled;



public Plugin myinfo = 
{
	name = "DTK +use",
	author = "worMatty",
	description = "A QoL plugin that simulates +use functionality on maps with buttons that only have OnDamaged outputs",
	version = PLUGIN_VERSION,
	url = ""
};



public void OnPluginStart()
{
	// Check if SDKHooks is supported
	if (GetFeatureStatus(FeatureType_Native, "SDKHook") != FeatureStatus_Available)
		SetFailState("DTK QOL +use requires SDKHooks");

	CreateConVar("sm_useinator_version", PLUGIN_VERSION, "+useinatr version.", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
	g_cEnabled = CreateConVar("dtk_qol_button_use", "0", "Let players +use buttons that normally require damage to press. A problem in some old maps. Resets to 0 on map end");
	g_cEnabled.AddChangeHook(Hook_ConVar);
}



public void OnMapEnd()
{
	// Disable plugin on map end
	g_cEnabled.BoolValue = false;
}



public void OnEntityCreated(int entity, const char[] classname)
{
	// Hook buttons that spawn
	if (g_cEnabled.BoolValue)
	{
		if (StrEqual(classname, "func_button"))
		{
			SDKHook(entity, SDKHook_UsePost, Hook_ButtonPressed);
			SDKHook(entity, SDKHook_Spawn, Hook_ButtonSpawn);
		}
	}
}



// When a button spawns, give it the 'useable' spawnflag
Action Hook_ButtonSpawn(int entity)
{
	int spawnflags = GetEntProp(entity, Prop_Data, "m_spawnflags");
	SetEntProp(entity, Prop_Data, "m_spawnflags", spawnflags | (1024));
	PrintToServer("%s Button %d has had +use spawnflag enabled", PREFIX, entity);
}



// Print to server console when the plugin is en/dis-abled
void Hook_ConVar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrintToServer("%s Plugin %s. Changes will take effect next round", PREFIX, g_cEnabled.BoolValue ? "enabled" : "disabled");
}



// Button press hook
Action Hook_ButtonPressed(int entity, int activator, int caller, UseType type, float value)
{
	// Make the button take damage of 0 value
	SDKHooks_TakeDamage(entity, activator, activator, 0.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
}