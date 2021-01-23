
/**
 * Entity Work
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Find and hook entities. 
 * 
 * @noreturn
 */
stock void SetUpEnts()
{
	// monster_resource
	if ((g_iEnts[Ent_MonsterRes] = FindEntityByClassname(-1, "monster_resource")) == -1)
	{
		if ((g_iEnts[Ent_MonsterRes] = CreateEntityByName("monster_resource")) != -1)
		{
			if (!DispatchSpawn(g_iEnts[Ent_MonsterRes]))
			{
				LogError("Unable to spawn a monster_resource entity. SDKTools game data not working?");
				RemoveEdict(g_iEnts[Ent_MonsterRes]);
				g_iEnts[Ent_MonsterRes] = -1;
			}
		}
		else
		{
			LogError("Unable to create a monster_resource entity. Not supported by mod?");
		}
	}
	
	// Player resource manager
	if ((g_iEnts[Ent_PlayerRes] = GetPlayerResourceEntity()) == -1)
		LogError("Player resource entity not found!");


	int i = -1;
	char targetname[256];
	
	// math_counter
	while ((i = FindEntityByClassname(i, "math_counter")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DRENT_HEALTH_MATH, false) == 0)
		{
			HookSingleEntityOutput(i, "OutValue", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser1", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser2", Hook_HealthEnts);
			Debug("Hooked OutValue, OnUser1, OnUser2 outputs of math_counter %d named %s", i, targetname);
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
 * Player Preferences
 * ----------------------------------------------------------------------------------------------------
 */

void AdjustPreference(int client, int selection)
{
	switch (selection)
	{
		case 0:
		{
			Player(client).RemoveFlag(FLAG_PREF_ACTIVATOR);
			Player(client).RemoveFlag(FLAG_PREF_FULLQP);
			ChatMessage(client, Msg_Reply, "%t", "no longer receive queue points");
		}
		case 1:
		{
			Player(client).AddFlag(FLAG_PREF_ACTIVATOR);
			Player(client).RemoveFlag(FLAG_PREF_FULLQP);
			ChatMessage(client, Msg_Reply, "%t", "you will now receive fewer queue points");
		}
		case 2:
		{
			Player(client).AddFlag(FLAG_PREF_ACTIVATOR);
			Player(client).AddFlag(FLAG_PREF_FULLQP);
			ChatMessage(client, Msg_Reply, "%t", "you will receive the maximum amount of queue points");
		}
	}	
}




/**
 * Player Allocation
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Check for players when an activator is needed or a team changed detected
 * during pre-round freeze time.
 * 
 * @noreturn
 */
void CheckForPlayers()
{
	// The number of activators we want
	int desired_activators = g_ConVars[P_Activators].IntValue;

	Debug("Checking for players...");


	/*
		Select an Activator
		Move them to Blue and the rest to Red		

		Team Change Detected
		Are there enough players on Blue?
		If yes, then do nothing.
		If not, Select an Activator.
	*/

	// Watching for Player Changes, Too Few Blue Players, Enough Participants <-- Post Team Change
	if (game.HasFlag(FLAG_WATCHMODE) && game.Blues < desired_activators && game.Participants > desired_activators)
	{
		game.RemoveFlag(FLAG_WATCHMODE);
		Debug("Team change detected. Too few blue players");
		RequestFrame(RedistributePlayers);
		return;
	}
	
	// Watching for Player Changes, Enough Blues <-- Team Change Amongst Reds
	if (game.HasFlag(FLAG_WATCHMODE) && game.Blues == desired_activators)
	{
		Debug("Team change detected but no action required as we have enough Blue players");
		return;
	}

	// Not Watching for Player Changes, Enough Participants <-- New Round
	if (!game.HasFlag(FLAG_WATCHMODE))
	{
		if (game.Participants > 1)
		{
			Debug("We have enough participants to start a round!");
			RedistributePlayers();
		}
		else
		{
			Debug("Not enough participants to start a round. Gone into waiting mode");
			game.AddFlag(FLAG_WATCHMODE);
		}
	}
}



/**
 * Select an activator and redistribute players to the right teams.
 * 
 * @noreturn
 */
void RedistributePlayers()
{
	Debug("Redistributing the players");
	
	// Move all blue players to the red team
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).Team == Team_Blue)
			Player(i).SetTeam(Team_Red);
	}

	int prefers;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).HasFlag(FLAG_PREF_ACTIVATOR))
			prefers += 1;
	}
	
	if (prefers <= MINIMUM_ACTIVATORS)
	{
		SelectActivatorTurn();
		ChatMessageAll(Msg_Normal, "%t", "not enough activators");
	}
	else
		SelectActivatorPoints();
	
	game.AddFlag(FLAG_WATCHMODE);		// Go into watch mode to replace activator if needed
}



/**
 * Select an activator by using the queue point system. 
 * 
 * @noreturn
 */
void SelectActivatorPoints()
{
	// First sort our player points array by points in descending order
	int points_order[MAXPLAYERS][2];
		// 0 will be client index. 1 will be points.
	
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = Player(i + 1).Index;
		points_order[i][1] = Player(i + 1).Points;
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	int activators = GetNumberActivators();
	
	while (game.Blues < activators && game.Reds > 1)
	{
		int player = points_order[i][0];
		
		if (Player(player).InGame && Player(player).Team == Team_Red && Player(player).HasFlag(FLAG_PREF_ACTIVATOR))
		{
			PrintToServer("%s The points-based activator selection system has selected %N", PREFIX_SERVER, player);
			if (g_bSCR && g_ConVars[P_SCR].BoolValue)
				SCR_SendEvent(PREFIX_SERVER, "%N is now the activator", player);
			Player(player).AddFlag(FLAG_ACTIVATOR);
			if (Player(player).HasFlag(FLAG_ACTIVATOR))
				Debug("%N has been given FLAG_ACTIVATOR", player);
			Player(player).SetTeam(Team_Blue);
			Player(player).SetPoints(QP_Consumed);
			ChatMessage(player, Msg_Reply, "%t", "queue points consumed");
			g_iBoss = player;
			
			if (g_ConVars[P_BlueBoost].BoolValue)
				ChatMessage(player, Msg_Reply, "Bind +speed to use the Activator speed boost");
		}
		
		if (i == MaxClients - 1)
			i = 0;
		else
			i++;
	}
	
	// If running in Open Fortress or TF2C, respawn all players
	if (game.IsGame(FLAG_OF|FLAG_TF2C)) // TODO Change to a check if the native is available
	{
		int iRespawn = CreateEntityByName("game_forcerespawn");
		if (iRespawn == -1)
		{
			LogError("Unable to create game_forcerespawn");
		}
		else
		{
			if (!DispatchSpawn(iRespawn))
			{
				LogError("Unable to spawn game_forcerespawn");
			}
			else
			{
				if (!AcceptEntityInput(iRespawn, "ForceRespawn"))
				{
					LogError("game_forcerespawn wouldn't accept our ForceRespawn input");
				}
				else
				{
					Debug("Respawned all players by creating a game_forcerespawn");
				}
			}
			
			AcceptEntityInput(iRespawn, "Kill");
			//RemoveEdict(iRespawn);
		}
	}
}



/**
 * Select an activator by using the fall-back turn-based system.
 * 
 * @noreturn
 */
void SelectActivatorTurn()
{
	static int client = 1;
	
	//if (client > MaxClients)
		//client = 1;
	
	/*
	int activators = g_ConVars[P_Activators].IntValue;
	if (g_ConVars[P_Activators].IntValue == -1)
	{
		activators = RoundFloat(game.Participants * g_ConVars[P_ActivatorRatio].FloatValue);
		ClampInt(activators, 1, game.Participants - 1);
		Debug("There are %d participants and the ratio is %f so we need %d activators", game.Participants, g_ConVars[P_ActivatorRatio].FloatValue, activators);
	}
	*/
	
	int activators = GetNumberActivators();
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	while (game.Blues < activators && game.Reds > 1)
	{
		if (Player(client).InGame && Player(client).Team == Team_Red)
		{
			PrintToServer("%s The turn-based activator selection system has selected %N", PREFIX_SERVER, client);
			if (g_bSCR && g_ConVars[P_SCR].BoolValue)
				SCR_SendEvent(PREFIX_SERVER, "%N is now the activator", client);
			Player(client).AddFlag(FLAG_ACTIVATOR);
			if (Player(client).HasFlag(FLAG_ACTIVATOR))
				Debug("Selected activator %N has been given FLAG_ACTIVATOR", client);
			Player(client).SetTeam(Team_Blue);
			g_iBoss = client;
			Debug("Set g_iBoss to %d (%N)", client, client);
			
			if (g_ConVars[P_BlueBoost].BoolValue)
				ChatMessage(client, Msg_Reply, "Bind +speed to use the Activator speed boost");
		}
		
		if (client == MaxClients)
			client = 1;
		else
			client++;
	}
	
	// If running in Open Fortress or TF2C, respawn all players
	//if (game.IsGame(FLAG_OF|FLAG_TF2C)) // TODO Change to a check if the native is available
	
	// If TF2_RespawnPlayer is not available, use a game_forcerespawn entity to respawn everyone
	if (GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available) // TODO Does this work?
	{
		int iRespawn = CreateEntityByName("game_forcerespawn");
		if (iRespawn == -1)
		{
			LogError("Unable to create game_forcerespawn");
		}
		else
		{
			if (!DispatchSpawn(iRespawn))
			{
				LogError("Unable to spawn game_forcerespawn");
			}
			else
			{
				if (!AcceptEntityInput(iRespawn, "ForceRespawn"))
				{
					LogError("game_forcerespawn wouldn't accept our ForceRespawn input");
				}
				else
				{
					Debug("Respawned all players by creating a game_forcerespawn");
				}
			}
			
			AcceptEntityInput(iRespawn, "Kill");
			//RemoveEdict(iRespawn);
		}
	}
}




/**
 * Get number of activators needed
 * 
 * @return		int		Number of activators
 */
int GetNumberActivators()
{
	int activators = RoundFloat(game.Participants * g_ConVars[P_ActivatorRatio].FloatValue);
	if (g_ConVars[P_Activators].IntValue > -1)
		ClampInt(activators, 1, g_ConVars[P_Activators].IntValue);
	ClampInt(activators, 1, game.Participants - 1);
	
	return activators;
}




/**
 * Player Properties
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Apply the necessary attributes to a player after they spawn.
 * 
 * @noreturn
 */
void ApplyPlayerAttributes(int client)
{
	if (!game.IsGame(FLAG_TF))
		return;

	// Reset player attributes
	if (RemoveAllAttributes(client))
		Debug("Removed all attributes from %N", client);

	// Blue Speed
	if (Player(client).Team == Team_Blue)
		if (g_ConVars[P_BlueSpeed].FloatValue != 0.0)
			Player(client).SetSpeed(g_ConVars[P_BlueSpeed].IntValue);

	// Red
	if (Player(client).Team == Team_Red)
	{
		// Red Speed
		if (g_ConVars[P_RedSpeed].FloatValue != 0.0)
			Player(client).SetSpeed(g_ConVars[P_RedSpeed].IntValue);
		
		// Red Scout Speed
		else if (g_ConVars[P_RedScoutSpeed].FloatValue != 0.0 && Player(client).Class == Class_Scout)
			Player(client).SetSpeed(g_ConVars[P_RedScoutSpeed].IntValue);
		
		// Double Jump
		if (g_ConVars[P_RedAirDash].BoolValue == false && Player(client).Class == Class_Scout)
			AddAttribute(client, "no double jump", 1.0);
		
		// Spy Cloak
		if (Player(client).Class == Class_Spy)
		{
			AddAttribute(client, "mult cloak meter consume rate", 8.0);
			AddAttribute(client, "mult cloak meter regen rate", 0.25);
		}

		// Demo Charging
		if (Player(client).Class == Class_DemoMan)
		{
			switch (2)
			{
				case 0:
				{
					AddAttribute(client, "charge time decreased", -1000.0);
					AddAttribute(client, "charge recharge rate increased", 0.0);
				}
				case 2:
				{
					AddAttribute(client, "charge time decreased", -0.95);
					AddAttribute(client, "charge recharge rate increased", 0.2);
				}
			}
		}
	}
}



/**
 * Remove a player's weapon and replace it with a new one.
 * 
 * @param	int	Client index.
 * @param	int	Current weapon entity index.
 * @param	int	Chosen item definition index.
 * @param	char	Classname of chosen weapons.
 * @return	int	Entity index of the new weapon
 */
int ReplaceWeapon(int client, int weapon, int itemDefIndex, char[] classname)
{
	RemoveEdict(weapon);
	
	weapon = CreateEntityByName(classname);
	if (weapon == -1)
	{
		LogError("Couldn't create %s for %N", classname, client);
	}
	else
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		SetEntProp(weapon, Prop_Send, "m_hOwnerEntity", client);
		
		if (!DispatchSpawn(weapon))
		{
			LogError("Couldn't spawn %s for %N", classname, client);
		}
		else
		{
			EquipPlayerWeapon(client, weapon);
			Debug("Replaced a weapon belonging to %N with %s %d", client, classname, itemDefIndex);
			return weapon;
		}
	}
	
	return -1;
}



/**
 * Map Interaction
 * ----------------------------------------------------------------------------------------------------
 */

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
	char buffers[16][256];
	ExplodeString(properties, ",", buffers, 16, 256, true);

	// Give weapon
	if (StrEqual(instruction, "weapon", false))
	{
		int weapon = Player(client).GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			ReplaceWeapon(Player(client).Index, weapon, StringToInt(buffers[1]), buffers[2]);
		}
	}
	
	// Remove weapon
	if (StrEqual(instruction, "remove_weapon", false))
	{
		int weapon = Player(client).GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			RemoveEdict(weapon);
			Debug("Removed %N's weapon in slot %s", client, buffers[0]);
		}
	}
	
	// Give weapon attribute
	if (StrEqual(instruction, "weapon_attribute", false))
	{
		int weapon = Player(client).GetWeapon(StringToInt(buffers[0]));
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
		Player(client).SetSlot(StringToInt(buffers[0]));
	}
	
	// Change class
	if (StrEqual(instruction, "class", false))
	{
		int class = ProcessClassString(buffers[0]);
		Player(client).SetClass(class);
	}
	
	// Set speed
	if (StrEqual(instruction, "speed", false))
	{
		Player(client).SetSpeed(StringToInt(buffers[0]));
	}
	
	// Set health
	if (StrEqual(instruction, "health", false))
	{
		Player(client).SetHealth(StringToInt(buffers[0]));
	}
	
	// Set max health
	if (StrEqual(instruction, "maxhealth", false))
	{
		Player(client).SetMaxHealth(StringToFloat(buffers[0]));
	}
	
	// Scale max health (Activator)
	if (StrEqual(instruction, "scalehealth", false))
	{
		// Scale max health - plugin default
		if (buffers[0][0] == '\0' || StrEqual(buffers[0], "pool", false))
			Player(client).ScaleHealth(3);
		
		if (StrEqual(buffers[0], "overheal", false))
			Player(client).ScaleHealth(1);
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
		ChatMessage(client, Msg_Normal, "%s", buffers[0]);
	}
	
	// Melee only
	if (StrEqual(instruction, "meleeonly", false))
	{
		if (StrEqual(buffers[0], "yes", false))
		{
			Player(client).MeleeOnly();
		}
		if (StrEqual(buffers[0], "no", false))
		{
			Player(client).MeleeOnly(false);
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




/**
 * Communication
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Display up to the next three activators at the end of a round.
 * 
 * @noreturn
 */
void DisplayNextActivators()
{
	// Count the number of willing activators
	int willing;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).HasFlag(FLAG_PREF_ACTIVATOR))
			willing += 1;
	}
	
	// If we don't have enough willing activators, don't display the message
	if (willing <= MINIMUM_ACTIVATORS)
		return;
	
	// Create a temporary array to store client index[0] and points[1]
	int points_order[MAXPLAYERS][2];
	
	// Populate with player data
	for (int i = 0; i < MaxClients; i++)
	{
		points_order[i][0] = i + 1;
		points_order[i][1] = Player(i + 1).Points;
	}
	
	// Sort by points descending
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	// Get the top three players with points
	//int players[3], count, client;
	int players[3], count;
	
	for (int i = 0; i < MaxClients && count < 3; i++)
	{
		int player = points_order[i][0];
		//client = points_order[i][0];
	
		if (Player(player).InGame && Player(player).IsParticipating && points_order[i][1] > 0 && Player(player).HasFlag(FLAG_PREF_ACTIVATOR))
		//if (IsClientInGame(client) && points_order[i][1] > 0 && (g_iFlags[client] & PREF_ACTIVATOR) == PREF_ACTIVATOR)
		{
			players[count] = player;
			//players[count] = client;
			count++;
		}
	}
	
	// Display the message
	if (players[0] != 0)
	{
		char string1[MAX_NAME_LENGTH];
		char string2[MAX_NAME_LENGTH];
		char string3[MAX_NAME_LENGTH];
		
		Format(string1, sizeof(string1), "%N", players[0]);
		
		if (players[1] > 0)
			Format(string2, sizeof(string2), ", %N", players[1]);
		
		if (players[2] > 0)
			Format(string3, sizeof(string3), ", %N", players[2]);
		
		ChatMessageAll(Msg_Normal, "%t", "next activators", string1, string2, string3);
	}
}


/**
 * Sorting function used by SortCustom2D. Sorts players by queue points.
 * 
 * @return	int	
 */
int SortByPoints(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])
		return 0;
	else if (b[1] > a[1])
		return 1;
	else
		return -1;
}




/**
 * Server Environment
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Set server ConVars and hook events
 * 
 * @param		bool	Enable or disable
 * @noreturn
 */
void HookStuff(bool enabled)
{
	// ConVars
	if (enabled)
	{
		g_ConVars[S_Unbalance].IntValue 		= 0;
		g_ConVars[S_AutoBalance].IntValue 		= 0;
		g_ConVars[S_Scramble].IntValue 			= 0;
		g_ConVars[S_Queue].IntValue 			= 0;
		g_ConVars[S_WFPTime].IntValue 			= 0;	// Needed in OF and TF2C
		g_ConVars[S_Pushaway].SetBool(false);
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].IntValue = 0;
	}
	else
	{
		g_ConVars[S_Unbalance].RestoreDefault();
		g_ConVars[S_AutoBalance].RestoreDefault();
		g_ConVars[S_Scramble].RestoreDefault();
		g_ConVars[S_Queue].RestoreDefault();
		g_ConVars[S_Pushaway].RestoreDefault();
		g_ConVars[S_WFPTime].RestoreDefault();
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].RestoreDefault();
	}
	
	// Events
	if (enabled)
	{
		HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
		HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
		HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
		HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn);										// Player spawns
		HookEvent("player_team", Event_TeamsChanged);										// Player chooses a team
		HookEvent("player_changeclass", Event_ChangeClass);									// Player changes class
		HookEvent("player_healed", Event_PlayerHealed);										// Player healed
		HookEvent("player_healonhit", Event_PlayerHealed);									// Player healed by health kit
		HookEvent("player_death", Event_PlayerDeath);										// Player dies
		HookEvent("player_hurt", Event_PlayerDamaged);										// Player is damaged
		
		if (game.IsGame(FLAG_TF))
			HookEvent("post_inventory_application", Event_InventoryApplied);
	}
	else
	{
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_team", Event_TeamsChanged);
		UnhookEvent("player_changeclass", Event_ChangeClass);
		UnhookEvent("player_healed", Event_PlayerHealed);
		UnhookEvent("player_healonhit", Event_PlayerHealed);
		UnhookEvent("player_death", Event_PlayerDeath);
		UnhookEvent("player_hurt", Event_PlayerDamaged);
		
		if (game.IsGame(FLAG_TF))
			UnhookEvent("post_inventory_application", Event_InventoryApplied);
	}
	
	// Command Listeners
	if (enabled)
	{
		AddCommandListener(CmdListener_LockBlue,	"kill");
		AddCommandListener(CmdListener_LockBlue, 	"explode");
		AddCommandListener(CmdListener_LockBlue, 	"spectate");
		AddCommandListener(CmdListener_Teams, 		"jointeam");
		AddCommandListener(CmdListener_Teams, 		"autoteam");
		AddCommandListener(CmdListener_Builds, 		"build");
	}
	else
	{
		RemoveCommandListener(CmdListener_LockBlue,	"kill");
		RemoveCommandListener(CmdListener_LockBlue,	"explode");
		RemoveCommandListener(CmdListener_LockBlue,	"spectate");
		RemoveCommandListener(CmdListener_Teams, 	"jointeam");
		RemoveCommandListener(CmdListener_Teams, 	"autoteam");
		RemoveCommandListener(CmdListener_Builds, 	"build");
	}
}




/**
 * ConVar change hook
 * 
 * @param		ConVar	ConVar handle.
 * @param		char	Old ConVar value.
 * @param		char	New ConVar value.
 * @noreturn
 */
void ConVar_ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// TODO Replace string comparisons with handle comparisons
	
	char name[64];
	convar.GetName(name, sizeof(name));
	
	if (StrContains(name, "dtk_", false) == 0)
		PrintToServer("%s %s has been changed from %s to %s", PREFIX_SERVER, name, oldValue, newValue);
	
	// Enabled
	if (StrEqual(name, "dtk_enabled", false))
	{
		// Enable
		if (g_ConVars[P_Enabled].BoolValue)
		{
			HookStuff(true);
			game.AddFlag(FLAG_WATCHMODE);	// Watch for players connecting after the map change
											// Server doesn't fire a round reset or start event unless there are players
			if (g_bSteamTools)
				GameDescription(true);
		}
		// Disable
		else
		{
			HookStuff(false);
			
			if (g_bSteamTools)
				GameDescription(false);
		}
	}

	// Red Melee Only
	else if (StrEqual(name, "dtk_red_melee", false))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).MeleeOnly(convar.BoolValue);
		}
	}
	
	// Red Speed
	else if (StrEqual(name, "dtk_red_speed", false))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).SetSpeed(convar.IntValue);
		}
	}
}




/**
 * Set the server's game description.
 *
 * @noreturn
 */
stock void GameDescription(bool enabled)
{
	if (!g_bSteamTools)
		return;
	
	char description[32];
	
	if (!enabled) // Plugin not enabled
	{
		if 			(game.IsGame(FLAG_TF))		Format(description, sizeof(description), "Team Fortress");
		else if 	(game.IsGame(FLAG_OF))		Format(description, sizeof(description), "Open Fortress");
		else if 	(game.IsGame(FLAG_TF2C))	Format(description, sizeof(description), "Team Fortress 2 Classic");
		else 									Format(description, sizeof(description), DEFAULT_GAME_DESC);
	}
	else
		Format(description, sizeof(description), "%s | %s", PLUGIN_SHORTNAME, PLUGIN_VERSION);
	
	Steam_SetGameDescription(description);
	PrintToServer("%s Set game description to \"%s\"", PREFIX_SERVER, description);
}





/**
 * Database
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Connect to the database and create the table if it doesn't exist
 *
 * @noreturn
 */
stock void DBCreateTable()
{
	char error[255];
	
	if (g_ConVars[P_Database].BoolValue)
	{
		if ((g_db = SQLite_UseDatabase(SQLITE_DATABASE, error, sizeof(error))) == null)
		{
			LogError("Unable to connect to SQLite database %s: %s", SQLITE_DATABASE, error);
		}
		else
		{
			PrintToServer("%s Database connection established. Handle is %x", PREFIX_SERVER, g_db);
			
			char query[255];
			
			Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (steamid INTEGER PRIMARY KEY, \
			points INTEGER, flags INTEGER, last_seen INTEGER DEFAULT 0)", SQLITE_TABLE);
			
			if (!SQL_FastQuery(g_db, query))
			{
				SQL_GetError(g_db, error, sizeof(error));
				LogError("Unable to create database table %s: %s", SQLITE_TABLE, error);
			}
		}
	}
}



/**
 * Get rid of database records older than one month.
 *
 * @noreturn
 */
stock void DBPrune()
{
	// Remove entries older than a month, or 2629743 seconds
	if (g_db != null)
	{
		char query[255];
		Format(query, sizeof(query), "DELETE FROM %s WHERE last_seen <= %d", SQLITE_TABLE, GetTime() - 2629743);
		//SQL_FastQuery(g_db, query);
		
		DBResultSet resultset = SQL_Query(g_db, query);
		Debug("Found %d expired records in the database to delete", resultset.AffectedRows);
		if (resultset.AffectedRows > 0)
			LogMessage("Deleted %d expired records from the database", resultset.AffectedRows);
		CloseHandle(resultset);
	}
}



/**
 * Delete the DTK table from the database.
 *
 * @noreturn
 */
stock void DBReset(int client)
{
	char query[255];
	Format(query, sizeof(query), "DROP TABLE %s", SQLITE_TABLE);
	if (SQL_FastQuery(g_db, query))
	{
		ShowActivity2(client, "", "%t Reset player database. Changing the map will reinitialise it", "prefix_notice");
		LogMessage("%L reset the database using the admin command", client);
	}
	else
	{
		char error[255];
		SQL_GetError(g_db, error, sizeof(query));
		ShowActivity2(client, "", "%t Failed: %s", "prefix_notice", error);
		LogError("%L failed to reset the database. Error: %s", client, error);
	}
}




/**
 * HUD Elements
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Set the percentage of the boss health bar.
 *
 * @param	int	Health
 * @param	int	Max health
 * @noreturn
 */
stock void SetHealthBar(int health = 0, int maxhealth = 0, int entity = 0)
{
	/*
		Does the monster res exist?
			Display boss bar.
				Is overheal?
					Display overheal text.
		else
			Use text exclusively including overheal.
	
	*/
	
	if (!health && !maxhealth && !entity)
	{
		Debug("SetHealthBar called with no arguments. Did the activator die?");
	}
	else
	{
		Debug("Set boss bar. health: %d  maxhealth: %d  entity: %d", health, maxhealth, entity);
	}
	
	if (g_iEnts[Ent_MonsterRes] != -1)	// monster_resource exists
	{
		int percent = RoundToNearest((float(health) / float(maxhealth)) * 255);
		SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossHealthPercentageByte", (percent > 255) ? 255 : percent);
		if (health > maxhealth)
			HealthText("+ %t: %d  ", "dtk_overheal", (health - maxhealth));
	}
	else
	{
		if (!health)
			HealthText();
		else if (Player(entity).IsValid)
			HealthText("%N: %d", entity, health);
		else
			HealthText("%t: %d", "dtk_health", health);
	}
	game.AddFlag(FLAG_HEALTH_BAR_ACTIVE);
	
	delete g_hTimers[Timer_HealthBar];
	g_hTimers[Timer_HealthBar] = CreateTimer(10.0, TimerCB_HealthBar);
}




/**
 * Display some text below the health bar.
 *
 * @param	char	The text.
 * @noreturn
 */
stock void HealthText(const char[] string = "", any ...)
{
	static Handle hHealthText;
	if (!hHealthText)
		hHealthText = CreateHudSynchronizer();
	
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	SetHudTextParams(-1.0, 0.16, 20.0, 123, 190, 242, 255, _, 0.0, 0.0, 0.0);
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
		{
			if (string[0])
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, len, string, 2);
				ShowSyncHudText(i, hHealthText, buffer);
			}
			else
				ClearSyncHud(i, hHealthText);
		}
}



/**
 * Update the boss health bar with a player's health
 *
 * @param		int		Client index
 * @noreturn
 */
stock void UpdateHealthBar(int client)
{
	SetHealthBar(Player(client).Health, Player(client).MaxHealth, client);
}



/**
 * Boost HUD
 *
 * @param		int		Client index
 * @noreturn
 */
stock void BoostHUD(int client, float value)
{
	if (hBoostHUD == null) hBoostHUD = CreateHudSynchronizer();
	
	char buffer[256] = "Boost: ";
	int characters = RoundToFloor(value / 33);
	
	for (int i = 0; i < characters; i++)
	{
		Format(buffer, sizeof(buffer), "%s▋", buffer);
	}
	
	SetHudTextParamsEx(0.20, 0.85, 0.5, { 255, 255, 255, 255 }, { 255, 255, 255, 255 }, 0, 0.1, 0.1);
	ShowSyncHudText(client, hBoostHUD, buffer);
}

/*
https://en.wikipedia.org/wiki/List_of_Unicode_characters
Block Elements
Main article: Block Elements (Unicode block)
See also: Box-drawing characters
Code 	Glyph 	Description
U+2580 	▀ 	Upper half block
U+2581 	▁ 	Lower one eighth block
U+2582 	▂ 	Lower one quarter block
U+2583 	▃ 	Lower three eighths block
U+2584 	▄ 	Lower half block
U+2585 	▅ 	Lower five eighths block
U+2586 	▆ 	Lower three quarters block
U+2587 	▇ 	Lower seven eighths block
U+2588 	█ 	Full block
U+2589 	▉ 	Left seven eighths block
U+258A 	▊ 	Left three quarters block
U+258B 	▋ 	Left five eighths block
U+258C 	▌ 	Left half block
U+258D 	▍ 	Left three eighths block
U+258E 	▎ 	Left one quarter block
U+258F 	▏ 	Left one eighth block
U+2590 	▐ 	Right half block
U+2591 	░ 	Light shade
U+2592 	▒ 	Medium shade
U+2593 	▓ 	Dark shade
U+2594 	▔ 	Upper one eighth block
U+2595 	▕ 	Right one eighth block
U+2596 	▖ 	Quadrant lower left
U+2597 	▗ 	Quadrant lower right
U+2598 	▘ 	Quadrant upper left
U+2599 	▙ 	Quadrant upper left and lower left and lower right
U+259A 	▚ 	Quadrant upper left and lower right
U+259B 	▛ 	Quadrant upper left and upper right and lower left
U+259C 	▜ 	Quadrant upper left and upper right and lower right
U+259D 	▝ 	Quadrant upper right
U+259E 	▞ 	Quadrant upper right and lower left
U+259F 	▟ 	Quadrant upper right and lower left and lower right 

█
*/