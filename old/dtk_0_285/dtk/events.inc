
/**
 * Game Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s The round has restarted", PREFIX_SERVER);
	
	//g_bIsRoundActive = false;			// Essentially this is pre-round prep/freeze time
	
	//if (g_iGame == Game_TF)
	healthbar = new HealthBar();
	
	g_iHealthBarTarget = -1;
	SetHealthBar();
	
	// Read settings and apply attributes
	// This prevents players from receiving attributes twice because they spawn twice at round reset
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			Player player = new Player(i);
			ApplyPlayerAttributes(player);
			if (player.Flags & SESSION_ACTIVATOR)
			{
				player.Flags &= ~SESSION_ACTIVATOR;
				DebugMessage("Removed SESSION_ACTIVATOR from %N", player.Index);
			}
				// Invert SESSION_ACTIVATOR bits and do an AND comparison with player.Flags
		}
	}
	g_bSettingsRead = true;				// Players won't receive attributes until settings have been read
	
	SetServerCvars(true);				// Make sure required cvars for the game mode are set on every round
	CheckForPlayers();					// Perform player number checking and begin team distribuiton
	
	
	/**
	 * Hook the map instruction logic entities
	 *
	 * TODO Move this to the Game method?
	 */
	if (g_cMapInstructions.BoolValue && g_bHookSingleEntityOutput)
	{
		int i = -1;
		char sTargetname[MAX_NAME_LENGTH];
		
		while ((i = FindEntityByClassname(i, "logic_branch")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			if (StrContains(sTargetname, "deathrun_enabled", false) != -1 || StrContains(sTargetname, "dtk_enabled", false) != -1)
			{
				SetEntProp(i, Prop_Data, "m_bInValue", 1, 1);
				DebugMessage("Set logic_branch '%s' to true", sTargetname);
			}
		}
		
		while ((i = FindEntityByClassname(i, "logic_case")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			if (StrContains(sTargetname, "deathrun_properties", false) != -1 || StrContains(sTargetname, "dtk_properties", false) != -1)
			{
				DebugMessage("Hooked logic_case named '%s'", sTargetname);
				HookSingleEntityOutput(i, "OnUser1", ProcessLogicCase);
			}
		}
	}
}



void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bBlueWarnedSuicide = false;		// Reset the warning given to blue when trying to quit
	g_bWatchForPlayerChanges = false;	// No need to watch for team changes now
	
	if (g_cShowRoundStartMessage.BoolValue)
		RoundActiveMessage();			// Fire the function that cycles through round start messages
		
	RequestFrame(CheckGameState);		// Count players for the player pushing cvar
	
	PrintToServer("%s The round is now active", PREFIX_SERVER);
	if (g_bSCR && g_cSCR.BoolValue)
		SCR_SendEvent(PREFIX_SERVER, "The round is now active");
	
	g_bRoundActive = true;				// Open Fortress Gamerules property doesn't work yet
}



void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// Give players points
	if (g_cUsePointsSystem.BoolValue == true)
		for (int i = 1; i <= MaxClients; i++)
		{
			Player player = new Player(i);
			if (player.InGame && player.Team == Team_Red && (player.Flags & PREF_ACTIVATOR))
				// If PREF_ACTIVATOR bit is found in player.Flags
			{
				int awarded = (player.Flags & PREF_FULL_QP) ? QP_Full : QP_Partial;
					// If player.Flags has PREF_FULL_QP set, give full points else give partial points
				player.AddPoints(awarded);
				PrintToChat(i, "%t %t", "prefix", "round end queue points received", awarded, player.Points);
			}
		}
	
	DisplayNextActivators();	// TODO: Don't display this if the map is about to change
	
	g_bSettingsRead = false;	// Turned off now so players don't receive attributes next round until after settings have been read
	
	PrintToServer("%s The round has ended", PREFIX_SERVER);
	if (g_bSCR && g_cSCR.BoolValue)
		SCR_SendEvent(PREFIX_SERVER, "The round has ended");
		
	g_bRoundActive = false;		// Open Fortress Gamerules property doesn't work yet
}




/**
 * Player Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	
	if (g_bSettingsRead)
	{
		RequestFrame(ApplyPlayerAttributes, player);
	}
	
	//RequestFrame(NextFrame_InventoryApplied, player);
	RequestFrame(CheckGameState);
}



void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	Player player = new Player(client);
	
	RequestFrame(NextFrame_InventoryApplied, player);
}

void NextFrame_InventoryApplied(Player player)
{
	// Melee only
	if (g_cRedMeleeOnly.BoolValue)
	{
		if (player.Team == Team_Red)
		{
			player.MeleeOnly();
		}
		else
		{
			player.SetSlot(TFWeaponSlot_Primary);
		}
	}
	/*else
	{
		player.SetSlot(TFWeaponSlot_Primary);
	}*/
	
	// Boss health bar
	if (g_bHealthBarActive == true && player.Index == g_iHealthBarTarget)
		SetHealthBar();
	
	// Don't do weapon checks if a weapon has been given by the map
	if (player.Flags & SESSION_ARMED)
		// If the player has SESSION_ARMED
	{
		player.Flags &= ~SESSION_ARMED;
			// Remove the SESSION_ARMED bit by doing an AND NOT comparison
		DebugMessage("post_inventory_application function was stopped before it could do weapon checks");
		return;
	}
	
	/**
	 * Weapon Checks
	 *
	 * In future I'd like to do different things depending on the weapon and have the things in a KV file.
	 */
	
	/*
		Attributes
		Replace
		Hook Damage?
	*/
	
	int weapon;
	int itemDefIndex;
	
	// Secondary weapon checks
	if ((weapon = player.GetWeapon(TFWeaponSlot_Secondary)) != -1)
	{
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	switch (itemDefIndex)
	{
		case 1179:		// Thermal thruster
		{
			if (g_bTF2Attributes)
				switch (g_cThermalThruster.IntValue)
				{
					case 0: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", -1.0);	// Charges are drained rendering the weapon unuseable
					case 1: TF2Attrib_RemoveByName(weapon, "item_meter_charge_rate");		// Use normal charging behaviour
					case 2: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 120.0);	// Charges take one minute to charge
					case 3: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.0);		// The player only has two charges
				}
		}
		case 812, 833:	// Cleaver
		{
			ReplaceWeapon(player.Index, weapon, 23, "tf_weapon_pistol");
		}
	}
	
	
	// Melee weapon checks
	if ((weapon = player.GetWeapon(TFWeaponSlot_Melee)) != -1)
	{
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	switch (itemDefIndex)
	{
		case 589:	// Eureka Effect
		{
			if (!g_cAllowEurekaEffect.BoolValue)
			{
				ReplaceWeapon(player.Index, weapon, 7, "tf_weapon_wrench");
			}
		}
	}
}



/**
 * player_hurt
 *
 * Added for the health bar to function in Open Fortress.
 * This is NOT hooked if the game is TF2.
 */
void Event_PlayerDamaged(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (g_cUseActivatorHealthBar.BoolValue)
	{
		if (attacker != victim && victim == g_iHealthBarTarget)
		{
			g_bHealthBarActive = true;
			RequestFrame(SetHealthBar);
		}
	}
}



void Event_PlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("patient")));
	
	if (player.Index == g_iHealthBarTarget)
		RequestFrame(SetHealthBar);
}



void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	// The class change event fires when the player enters the game properly for the first time
	// This is the best time to display welcome information to them
	
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	player.Welcome();
}



void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	/*
		Open Fortress death event
		
		Server event "player_death", Tick 2942:
		- "userid" = "2"
		- "attacker" = "0"
		- "weapon" = "trigger_hurt"
		- "damagebits" = "0"
		- "customkill" = "0"
		- "assister" = "-1"
		- "dominated" = "0"
		- "assister_dominated" = "0"
		- "revenge" = "0"
		- "assister_revenge" = "0"
		- "killer_pupkills" = "0"
		- "killer_kspree" = "0"
		- "victim_pupkills" = "-1"
		- "victim_kspree" = "0"
		- "ex_streak" = "0"
		- "firstblood" = "1"
		- "midair" = "0"
		- "humiliation" = "0"
		- "kamikaze" = "0"
	*/
	
	
	//int victim = event.GetInt("victim_entindex");
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	// Chat kill feed
	if (g_cChatKillFeed.BoolValue)
	{
		if (event.GetInt("attacker") == 0)	// If killed by the world, not a player
		{
			char classname[MAX_NAME_LENGTH];
			
			if (g_iGame & FLAG_TF) event.GetString("weapon_logclassname", classname, sizeof(classname));
			else event.GetString("weapon", classname, sizeof(classname));
			
			if (classname[0] != 'w')	// Filter out 'world' as the killer entity because dying from fall damage is obvious
			{
				char targetname[MAX_NAME_LENGTH];
				
				if (g_iGame & FLAG_TF)
				{
					GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
			
					if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
						Format(targetname, sizeof(targetname), " (%s)", targetname);
				}
				
				PrintToChat(victim, "%t %t", "prefix", "killed by entity classname", classname, targetname);
			}
		}
	}
	
	// Check for live players remaining and enable team pushing at some amount
	RequestFrame(CheckGameState);
	
	// Boss health bar
	if (g_bHealthBarActive == true && victim == g_iHealthBarTarget)
	{
		g_iHealthBarTarget = -1;
		SetHealthBar();
	}
}



Action Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	Player player = new Player(GetClientOfUserId(event.GetInt("userid")));
	
	/* TTrying to prevent people going on blue team but switching them back to red appears to trigger the redistribution logic
		and go int an inf loop */
	
	if (DTK_CountPlayers(Team_Both, LifeState_Any) < 3)
		return Plugin_Continue;
	
	bool changed;
	
	if (event.GetInt("team") == Team_Blue && !(player.Flags & SESSION_ACTIVATOR))
	{
		DebugMessage("A player who is not an activator tried to join Blue (%N)", player.Index);
		//event.SetInt("team", Team_Red);
		//changed = true;
		RequestFrame(RequestFrame_TeamsChanged, player);
		// I think the problem was forcing them back to Red without first disabling the 'watch for player changes' gBool? 
	}
	
	if (event.GetInt("oldteam") == Team_Blue && (player.Flags & SESSION_ACTIVATOR))
	{
		DebugMessage("Activator %N switched away from Blue so we're removing SESSION_ACTIVATOR from them", player.Index);
		player.Flags &= ~SESSION_ACTIVATOR;
		// TODO Tell them to opt out if they don't want to be activator
	}
	
	// If we're watching for player changes during freeze time:
	if (g_bWatchForPlayerChanges)	// TODO Can this be replaced by a roundstate check?
		RequestFrame(CheckForPlayers);
	
	if (changed)
		return Plugin_Changed;
	else
		return Plugin_Continue;
}

void RequestFrame_TeamsChanged(Player player)
{
	player.SetTeam(Team_Red, false);
	DebugMessage("%N joined team Blue so I put them on Red", player.Index);
}


