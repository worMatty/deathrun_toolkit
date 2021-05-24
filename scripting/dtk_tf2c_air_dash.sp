#pragma semicolon 1
#pragma newdecls required

//#define DEBUG
#define PLUGIN_NAME		"[DTK] QoL TF2C Air Dash"
#define PLUGIN_VERSION	"0.1"

#include <sourcemod>
//#include <sdktools>
//#include <sdkhooks>



// ConVar enum
enum {
	C_Enabled,
	C_Max
}

ConVar g_ConVar[C_Max];




public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = "worMatty",
	description = "A QoL plugin that prevents scouts in TF2 Classic from air dashing (double jump)",
	version = PLUGIN_VERSION,
	url = ""
};



public void OnPluginStart()
{
	// Fail if SDKHooks is not supported
	//if (GetFeatureStatus(FeatureType_Native, "SDKHook") != FeatureStatus_Available)
	//	SetFailState("%s requires SDKHooks. Check your game data", PLUGIN_NAME);

	// Create convars
	g_ConVar[C_Enabled] 	= CreateConVar("dtk_qol_tf2c_air_dash", "0", "Prevent scouts from air dashing in TF2 Classic");
	
	// Hook convars
	for (int i = 0; i < C_Max; i++)
		g_ConVar[i].AddChangeHook(Hook_ConVar);
}




/**
 * OnPlayerRunCmdPost
 */
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
	if (!g_ConVar[C_Enabled].BoolValue)
		return;
	
	if (GetEntProp(client, Prop_Send, "m_iClass") == 1)	// Is scout
	{
		if ((buttons & 2) && !GetEntProp(client, Prop_Send, "m_bAirDash"))	// Is pressing jump and air dash variable is false
		{
			SetEntProp(client, Prop_Send, "m_bAirDash", 1);
#if defined DEBUG
			PrintToChat(client, "Set airdash member variable to TRUE");
#endif
		}
	}
}




void Hook_ConVar(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));
	
	PrintToServer("%s set to %s", name, newValue);
}

