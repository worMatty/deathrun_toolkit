#pragma semicolon 1
#pragma newdecls required

//#define DEBUG
#define PLUGIN_VERSION "0.2"
#define PLUGIN_NAME "[DTK] QoL +use"

#include <sourcemod>
#include <sdktools>		// FindEntityByClassname
#include <sdkhooks>		// SDK Hooks :facepalm:



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
	name = PLUGIN_NAME,
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

	CreateConVar("dtk_qol_use_version", PLUGIN_VERSION, "Version of DTK QoL +use", FCVAR_SPONLY | FCVAR_DONTRECORD | FCVAR_NOTIFY);
	
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
#if defined DEBUG
	PrintToServer("Button %d has had +use spawnflag enabled", entity);
#endif
}



// Print to server console when the plugin is en/dis-abled
void Hook_ConVar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_cEnabled.BoolValue)
		PrintToServer("%s enabled. Hooking and modifying existing buttons", PLUGIN_NAME);
	else
		PrintToServer("%s disabled. Existing buttons still affected", PLUGIN_NAME);
	
	if (convar.BoolValue)
	{
		PrintToServer("Hooking all existing func_buttons");
		
		// Cycle through and hook all buttons
		int i = -1;
		while ((i = FindEntityByClassname(i, "func_button")) != -1)
		{
			#if defined DEBUG
			PrintToServer("func_button found with entity index %d. Hooking use output", i);
			#endif
			
			SDKHook(i, SDKHook_UsePost, Hook_ButtonPressed);
			Hook_ButtonSpawn(i);
				// Go ahead and change the spawnflags immediately as it's already spawned
		}
	}
}



// Button press hook
Action Hook_ButtonPressed(int entity, int activator, int caller, UseType type, float value)
{
#if defined DEBUG
	PrintToServer("Applying damage to func_button %d", entity);
#endif
	
	// Make the button take damage of 0 value
	SDKHooks_TakeDamage(entity, activator, activator, 0.0, 0, -1, NULL_VECTOR, NULL_VECTOR);
}