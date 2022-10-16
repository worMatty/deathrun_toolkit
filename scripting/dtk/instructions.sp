
#define DRENT_BRANCH				"deathrun_enabled"			// logic_branch
#define DRENT_MATH_BOSS				"deathrun_boss"				// math_counter for boss bar
#define DRENT_MATH_MINIBOSS			"deathrun_miniboss"			// math_counter for mini bosses
#define DRENT_PROPERTIES			"deathrun_properties"		// logic_case
#define DRENT_SETTINGS				"deathrun_settings"			// logic_case
#define DTKENT_BRANCH				"dtk_enabled"				// logic_branch for DTK-specific functions
#define DTKENT_HEALTHSCALE_MAX		"dtk_health_scalemax"		// logic_relay - DEPRECATED
#define DTKENT_HEALTHSCALE_OVERHEAL	"dtk_health_scaleoverheal"	// logic_relay - DEPRECATED


/**
 * Map Interaction
 * ----------------------------------------------------------------------------------------------------
 */


stock void Instructions_FindEnts()
{
	g_NPCs.Clear();
	g_NPCs.Resize(1);
	
	int i = -1;
	char targetname[256];
	
	// math_counter
	while ((i = FindEntityByClassname(i, "math_counter")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		if (StrContains(targetname, DRENT_MATH_BOSS, false) == 0)
		{
			HookSingleEntityOutput(i, "OutValue", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser1", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser2", Hook_HealthEnts);
			
			// The first boss math_counter will be at index 0
			g_NPCs.Set(0, i);
			
			Debug("Hooked boss math_counter %d named %s", i, targetname);
		}
		
		else if (StrContains(targetname, DRENT_MATH_MINIBOSS, false) == 0)
		{
			HookSingleEntityOutput(i, "OutValue", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser1", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser2", Hook_HealthEnts);
			
			// Add math_counter to NPC array
			g_NPCs.Push(i);
			
			Debug("Hooked mini-boss math_counter %d named %s", i, targetname);
		}
	}

	// logic_relay
	while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DTKENT_HEALTHSCALE_MAX, false) == 0 || StrContains(targetname, DTKENT_HEALTHSCALE_OVERHEAL, false) == 0)
		{
			HookSingleEntityOutput(i, "OnTrigger", Hook_HealthEnts);
			Debug("Hooked OnTrigger output of logic_relay %d named %s", i, targetname);
		}
	}

	if (!g_ConVars[P_MapInstructions].BoolValue)
		return;

	// logic_branch
	while ((i = FindEntityByClassname(i, "logic_branch")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DRENT_BRANCH, false) == 0 || StrContains(targetname, DTKENT_BRANCH, false) == 0)
		{
			SetEntProp(i, Prop_Data, "m_bInValue", 1, 1);
			Debug("Set logic_branch '%s' to true", targetname);
		}
	}

	// logic_case
	while ((i = FindEntityByClassname(i, "logic_case")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DRENT_PROPERTIES, false) == 0)
		{
			HookSingleEntityOutput(i, "OnUser1", ProcessLogicCase);
			Debug("Hooked OnUser1 output of logic_case named '%s'", targetname);
		}
	}
}


/**
 * Process data from a logic_case using string splitting and delimiters
 * 
 * @noreturn
 */
stock void ProcessLogicCase(const char[] output, int caller, int activator, float delay)
{
	// Caller is the entity reference of the logic_case
	
	if (activator > MaxClients || activator < 0)
	{
		char classname[64];
		char targetname[64];
		
		GetEntityClassname(activator, classname, sizeof(classname));
		GetEntPropString(activator, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		LogError("Deathrun logic_case was triggered by an invalid client index (%d, a %s named '%s')", activator, classname, targetname);
		return;
	}
	
	char caseValue[256];
	char caseNumber[12];
	char targetname[64];
	
	GetEntPropString(caller, Prop_Data, "m_iName", targetname, sizeof(targetname));
	Debug("Deathrun logic_case '%s' received %s from %N", targetname, output, activator);
	
	for (int i = 0; i < 16; i++)
	{
		Format(caseNumber, sizeof(caseNumber), "m_nCase[%d]", i);
		GetEntPropString(caller, Prop_Data, caseNumber, caseValue, sizeof(caseValue));
		
		if (caseValue[0] != '\0')
		{
			char buffers[2][256];
			ExplodeString(caseValue, ":", buffers, 2, 256, true);
			ProcessMapInstruction(activator, buffers[0], buffers[1]);
		}
	}
}


/**
 * Process a map instruction
 * 
 * @noreturn
 */
stock void ProcessMapInstruction(int client, const char[] instruction, const char[] properties)
{
	Player player = Player(client);
	char buffers[16][256];
	ExplodeString(properties, ",", buffers, 16, 256, true);

	// Give weapon
	if (StrEqual(instruction, "weapon", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			ReplaceWeapon(player.Index, weapon, StringToInt(buffers[1]), buffers[2]);
		}
	}
	
	// Remove weapon
	if (StrEqual(instruction, "remove_weapon", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			RemoveEdict(weapon);
			Debug("Removed %N's weapon in slot %s", client, buffers[0]);
		}
	}
	
	// Give weapon attribute
	if (StrEqual(instruction, "weapon_attribute", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			int itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (itemDefIndex == StringToInt(buffers[1]))
			{
				bool success = TF2Attrib_SetByName(weapon, buffers[2], StringToFloat(buffers[3]));
				if (success) Debug("Set an attribute on a weapon belonging to %N (%s with value %f)", client, buffers[2], StringToFloat(buffers[3]));
			}
		}
	}
	
	// Switch to slot
	if (StrEqual(instruction, "switch_to_slot", false))
	{
		player.SetSlot(StringToInt(buffers[0]));
	}
	
	// Change class
	if (StrEqual(instruction, "class", false))
	{
		int class = ProcessClassString(buffers[0]);
		player.SetClass(class);
	}
	
	// Set speed
	if (StrEqual(instruction, "speed", false))
	{
		player.SetSpeed(StringToInt(buffers[0]));
	}
	
	// Set health
	if (StrEqual(instruction, "health", false))
	{
		player.Health = StringToInt(buffers[0]);
	}
	
	// Set max health
	if (StrEqual(instruction, "maxhealth", false))
	{
		player.SetMaxHealth(StringToInt(buffers[0]));
	}
	
	/*
	// Scale max health (Activator)
	if (StrEqual(instruction, "scalehealth", false))
	{
		// Scale max health - plugin default
		if (buffers[0][0] == '\0' || StrEqual(buffers[0], "pool", false))
			player.ScaleHealth(3);
		
		if (StrEqual(buffers[0], "overheal", false))
			player.ScaleHealth(1);
	}
	*/
	
	// Scale max health (Activator) TODO Add hard multiply value
	if (StrEqual(instruction, "scalehealth", false))
	{
		// Pool
		if (buffers[0][0] == '\0' || StrEqual(buffers[0], "pool", false))
		{
			int health = ScaleActivatorHealth(false, _);

			if (health)
			{
				TF2_PrintToChatAll(_, "Scaled total activator health to %d", health);
				EmitMessageSoundToAll();
			}
		}
			
		// Overheal
		if (StrEqual(buffers[0], "overheal", false))
		{
			int health = ScaleActivatorHealth(true, _);
			
			if (health)
			{
				TF2_PrintToChatAll(_, "Overhealed total activator health to %d", health);
				EmitMessageSoundToAll();
			}
		}
	}
	
	// Set move type
	if (StrEqual(instruction, "movetype", false))
	{
		if (StrEqual(buffers[0], "fly", false))
		{
			SetEntityMoveType(client, MOVETYPE_FLY);
		}
		if (StrEqual(buffers[0], "walk", false))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
	
	// Chat message
	if (StrEqual(instruction, "message", false))
	{
		TF2_PrintToChat(client, _, "%s", buffers[0]);
		EmitMessageSoundToClient(client);
	}
	
	// Melee only
	if (StrEqual(instruction, "meleeonly", false))
	{
		if (StrEqual(buffers[0], "yes", false))
		{
			player.MeleeOnly();
		}
		if (StrEqual(buffers[0], "no", false))
		{
			player.MeleeOnly(false);
		}
	}
	
	// Use class animations for custom model
	if (StrEqual(instruction, "use_class_animations", false))
	{
		if (StrEqual(buffers[0], "true", false) || buffers[0][0] == '\0')
		{
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
			Debug("Enabled m_bUseClassAnimations for %N", client);
		}
		if (StrEqual(buffers[0], "false", false))
		{
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
			Debug("Disabled m_bUseClassAnimations for %N", client);
		}
	}
	
	// Set custom model
	if (StrEqual(instruction, "setmodel", false))
	{
		// TODO Check if model is precached
		
		if (StrEqual(buffers[0], "none", false) || buffers[0][0] == '\0')
		{
			SetVariantString("");
		}
		else
		{
			SetVariantString(buffers[0]);
		}
		
		AcceptEntityInput(client, "SetCustomModel", client, client);
		Debug("Set %N's custom model to %s", client, buffers[0]);
	}
	
	// TODO: Add something to hide cosmetics. Consider resetting custom model on round restart or death
	// Is it possible to parent a model to the player, bone merge it (effect flag 129) and make it visible (EF_NODRAW)?
	
	/*
	// Custom model rotates
	if (StrEqual(instruction, "model_rotates", false))
	{
		if (StrEqual(buffers[0], "true", false) || buffers[0][0] == '\0')
		{
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 1);
			Debug("Enabled m_bCustomModelRotates for %N", client);
		}
		if (StrEqual(buffers[0], "false", false))
		{
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
			Debug("Disabled m_bCustomModelRotates for %N", client);
		}
	}
	*/
}
