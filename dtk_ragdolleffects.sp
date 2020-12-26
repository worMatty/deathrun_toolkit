#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "worMatty"
#define PLUGIN_VERSION "0.1"

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "[DTK] Ragdoll Effects",
	author = PLUGIN_AUTHOR,
	description = "Allows mappers to use special ragdoll effects by setting trigger_hurt damage bits",
	version = PLUGIN_VERSION,
	url = ""
};



#define DMG_SPECIAL		(1 << 30)		// DMG_LASTGENERICFLAG
#define DMG_ALT1		DMG_DIRECT		// Bit 28
#define DMG_ALT2		DMG_BUCKSHOT	// Bit 29



ConVar g_cEnabled;


public void OnPluginStart()
{
	g_cEnabled = CreateConVar("dtk_ragdoll_effects", "0");
	
	HookEvent("player_death", Event_PlayerDeath);
}




stock void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	if (StrEqual(weapon, "trigger_hurt"))
	{
		int damagebits = event.GetInt("damagebits");
		
		if (damagebits & DMG_SPECIAL)
		{
			int victim = GetClientOfUserId(event.GetInt("userid"));
			
			DataPack data = CreateDataPack();
			data.WriteCell(victim);
			data.WriteCell(damagebits);
			RequestFrame(RagdollEffect, data);
		}
	}
}


/*
	RequestFrame works but not all the time. Seems to be dependent on the prop being set at the right point.
	But when is the right point?
	CreateTimer won't do it.
	
	SDKHooks can't be used to hook a tf_ragdoll. 

*/


void RagdollEffect(DataPack data)
{
	data.Reset();
	int client = data.ReadCell();
	int damagebits = data.ReadCell();
	delete data;
	
	// Get Player Ragdoll
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	
	PrintToServer("[DTK Ragdolls] Client %d  Ragdoll %d  damagebits %d", client, ragdoll, damagebits);

	
	// Decapitation
	if (damagebits & DMG_SLASH)
	{
		SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_DECAPITATION);
	}
	
	// Electrocution
	if (damagebits & DMG_PHYSGUN)
	{
		SetEntProp(ragdoll, Prop_Send, "m_bElectrocuted", 1);
	}
	
	// Burn
	if (damagebits & DMG_SLOWBURN)
	{
		SetEntProp(ragdoll, Prop_Send, "m_bBurning", 1);
	}
	
	// Become Ash (CAPPER)
	if (damagebits & DMG_ENERGYBEAM)
	{
		SetEntProp(ragdoll, Prop_Send, "m_bBecomeAsh", 1);
	}
	
	// Plasma Effects
	if (damagebits & DMG_PLASMA)
	{
		// Plasma Gibs
		if (damagebits & DMG_ALWAYSGIB)
		{
			SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_PLASMA_CHARGED);
		}
		// Plasma Standard (Cow Mangler)
		else
		{
			SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_PLASMA);
		}
	}
	
	// Paralysis
	if (damagebits & DMG_PARALYZE)
	{
		// Paralyze Ice
		if (damagebits & DMG_ALT1)
		{
			SetEntProp(ragdoll, Prop_Send, "m_bIceRagdoll", 1);
		}
		// Paralyze Gold
		else if (damagebits & DMG_ALT2)
		{
			SetEntProp(ragdoll, Prop_Send, "m_bGoldRagdoll", 1);
		}
		// Paralyze
		else
		{
			SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_GOLD_WRENCH);
		}
	}
	
	// Dissolve
	if (damagebits & DMG_DISSOLVE && !(damagebits & DMG_PLASMA))
	{
		int dissolver = CreateEntityByName("env_entity_dissolver");
		
		if (dissolver != -1 && ragdoll != -1)
		{
			DispatchKeyValue(dissolver, "target", "!activator");
			
			// Burn corpse, disintegrate
			if (damagebits & DMG_ALT1)
			{
				DispatchKeyValue(dissolver, "dissolvetype", "1");
			}
			// Disintegrate Rapidly
			else if (damagebits & DMG_ALT2)
			{
				DispatchKeyValue(dissolver, "dissolvetype", "3");
			}
			// Burn and float corpse, disintegrate
			else
			{
				DispatchKeyValue(dissolver, "dissolvetype", "0");
			}
			
			AcceptEntityInput(dissolver, "Dissolve", ragdoll, ragdoll);
			AcceptEntityInput(dissolver, "kill");
		}
	}
}
