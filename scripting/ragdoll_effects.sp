#pragma semicolon 1

#define DEBUG
#define PLUGIN_AUTHOR "worMatty"
#define PLUGIN_VERSION "0.1"

/*
	DMG_SPECIAL is used to signify to the plugin that a ragdoll effect is desired.
	If this bit is not found, the plugin will do nothing.
	
	DMG_ALT1 and DMG_ALT2 are used to distinguish between multiple similar effects.
*/

#define DMG_SPECIAL		(1 << 30)		// DMG_LASTGENERICFLAG
#define DMG_ALT1		DMG_DIRECT		// Bit 28
#define DMG_ALT2		DMG_BUCKSHOT	// Bit 29

/*
	Damage Bits
	-----------
	
	Use these values in Hammer to achieve the effect you want. The numbers are pre-calculated,
	and can be copy and pasted into the trigger_hurt's damage field with Smart Edit turned off.
	
	DMG_LASTGENERICFLAG		No effect on its own		1073741824
		DMG_SLASH			Decapitation				1073741828
		DMG_PHYSGUN			Electrocution				1082130432
		DMG_SLOWBURN		Burn						1075838976
		DMG_ENERGYBEAM		Ash							1073742848
		DMG_PLASMA			Cow Mangler					1090519040
			DMG_ALWAYSGIB	Cow Mangler Gib				1090527232
		DMG_PARALYZE		Paralyze					1073774592
			DMG_DIRECT		Paralyze Freeze				1342210048
			DMG_BUCKSHOT	Paralyze Gold				1610645504
		DMG_DISSOLVE		Burn, float and dissolve	1140850688
			DMG_DIRECT		Burn and dissolve			1409286144
			DMG_BUCKSHOT	Dissolve immediately		1677721600

*/

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>




/*
	Bugs
	----
	
	The effect doesn't always happen. I think this is because the window where you can change a ragdoll's
	properties is very narrow, and 'race conditions' mean the functions might not line up sometimes.
	
	Todo
	----
	
	Investigate a way to change a ragdoll's properties during its formation prior to spawning.
	This will probably take the form of some kind of TF2 function hook, but I'm not sure.
	
	Notes
	-----
	
	RequestFrame works but not all the time. Seems to be dependent on the prop being set at the right point.
	But when is the right point?
	CreateTimer won't do it.
	
	SDKHooks can't be used to hook a tf_ragdoll. 
*/




public Plugin myinfo = 
{
	name = "Ragdoll Effects",
	author = PLUGIN_AUTHOR,
	description = "Allows mappers to use special ragdoll effects by setting trigger_hurt damage bits",
	version = PLUGIN_VERSION,
	url = ""
};




ConVar g_cEnabled;

int g_iPlayers[MAXPLAYERS + 1];




public void OnPluginStart()
{
	g_cEnabled = CreateConVar("sm_ragdoll_effects", "1");
	
	HookEvent("player_death", Event_PlayerDeath);
}




void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	// Check if a player was killed by a trigger_hurt
	char weapon[32];
	event.GetString("weapon", weapon, sizeof(weapon));
	
	if (StrEqual(weapon, "trigger_hurt"))
	{
		// Get damage type from trigger_hurt
		int damagebits = event.GetInt("damagebits");
		
		// If damage bit field contains our special flag, store it in our global array
		if (damagebits & DMG_SPECIAL)
		{
			int victim = GetClientOfUserId(event.GetInt("userid"));
			g_iPlayers[victim] = damagebits;
		}
	}
}




public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_cEnabled.BoolValue)
		return;
	
	if (StrEqual(classname, "tf_ragdoll"))
		RequestFrame(CheckRagdoll, entity);
}

void CheckRagdoll(int ragdoll)
{
	int client = GetEntProp(ragdoll, Prop_Send, "m_iPlayerIndex");
	if (g_iPlayers[client])
		RagdollEffect(client, ragdoll);
}




void RagdollEffect(int client, int ragdoll)
{
	int damagebits = g_iPlayers[client];

	// Decapitation
	if (damagebits & DMG_SLASH)
	{
		SetEntProp(ragdoll, Prop_Send, "m_iDamageCustom", TF_CUSTOM_DECAPITATION);
	}
	
	// Electrocution
	if (damagebits & DMG_ENERGYBEAM)
	{
		SetEntProp(ragdoll, Prop_Send, "m_bElectrocuted", 1);
	}
	
	// Burn
	if (damagebits & DMG_SLOWBURN)
	{
		SetEntProp(ragdoll, Prop_Send, "m_bBurning", 1);
	}
	
	// Become Ash (CAPPER)
	if (damagebits & DMG_PHYSGUN)
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
			
			// Dissolve gun
			int item = -1;
			while ((item = FindEntityByClassname(item, "tf_dropped_weapon")) != -1)
			{
				if (GetEntProp(item, Prop_Send, "m_iAccountID") == GetSteamAccountID(client))
				{
					AcceptEntityInput(dissolver, "Dissolve", item, item);
					item = -1;
					break;
				}
			}
			
			// Dissolve ammo pack
			while ((item = FindEntityByClassname(item, "tf_ammo_pack")) != -1)
			{
				if (GetEntPropEnt(item, Prop_Send, "m_hOwnerEntity") == client)
				{
					AcceptEntityInput(dissolver, "Dissolve", item, item);
					break;
				}
			}
			
			AcceptEntityInput(dissolver, "kill");
		}
	}
	
	g_iPlayers[client] = 0;
}




public void OnMapEnd()
{
	// Reset player damage bits array on map end
	for (int i = 0; i <= MAXPLAYERS; i++)
		g_iPlayers[i] = 0;
}