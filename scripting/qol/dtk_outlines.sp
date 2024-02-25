public Plugin myinfo = 
{
	name = "[DTK] QoL Outlines",
	author = "worMatty",
	description = "A QoL plugin which enables glowing outlines on either team",
	version = "1.0",
	url = ""
}

#include <sourcemod>
#include <tf2_stocks>

ConVar cv_red;
ConVar cv_blue;

public OnPluginStart()
{
	cv_red	= CreateConVar("dtk_qol_outlines_red", "0", "Apply outlines to red players. 1 = Condition type, only see teammates. 2 = Property type, visible by all", _, true, 0.0, true, 2.0);
	cv_blue = CreateConVar("dtk_qol_outlines_blue", "0", "Apply outlines to blue players. 1 = Condition type, only see teammates. 2 = Property type, visible by all", _, true, 0.0, true, 2.0);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (TF2_GetClientTeam(client) == TFTeam_Red && cv_red.IntValue == 2) {
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
	}
	else if (TF2_GetClientTeam(client) == TFTeam_Blue && cv_blue.IntValue == 2) {
		SetEntProp(client, Prop_Send, "m_bGlowEnabled", 1);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond cond)
{
	if (cond == TFCond_SpawnOutline) {
		if (TF2_GetClientTeam(client) == TFTeam_Red && cv_red.IntValue == 1) {
			TF2_AddCondition(client, TFCond_SpawnOutline, TFCondDuration_Infinite);
		}
		else if (TF2_GetClientTeam(client) == TFTeam_Blue && cv_blue.IntValue == 1) {
			TF2_AddCondition(client, TFCond_SpawnOutline, TFCondDuration_Infinite);
		}
	}
}