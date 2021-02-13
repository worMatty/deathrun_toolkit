
/**
 * Game Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s The round has restarted", PREFIX_SERVER);
	
	// Apply Initial Player Attributes
	// Reset Player Flags
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame)
		{
			Player(i).RemoveFlag(PF_Activator);
			Player(i).RemoveFlag(PF_Runner);
			Player(i).RemoveFlag(PF_PointsEligible);
			ApplyPlayerAttributes(i);
		}
	}
	
	// Find and Hook Entities
	SetUpEnts();
	
	// Hide Health Bar
	SetHealthBar();
	
	// Set Round State
	game.RoundState = Round_Freeze;
	
	// Begin Redistribution
	CheckForPlayers();
}



void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	game.RemoveFlag(GF_WatchMode);	// No need to watch for team changes now
	
	// Round Start Message
	if (g_ConVars[P_RoundStartMessage].BoolValue)
	{
		static int phrase_number = 1;
		char phrase[20];
		Format(phrase, sizeof(phrase), "round has begun %d", phrase_number);
		
		if (!TranslationPhraseExists(phrase))
		{
			phrase_number = 1;
			Format(phrase, sizeof(phrase), "round has begun %d", phrase_number);
		}
		
		ChatMessageAll(Msg_Normal, "%t", phrase);
		phrase_number++;
	}
	
	// Set round state to Active
	game.RoundState = Round_Active;
	
	PrintToServer("%s The round is now active", PREFIX_SERVER);
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
		SCR_SendEvent(PREFIX_SERVER, "The round is now active");
	
	// OF starts the round regardless if there aren't enough players
	if (game.IsGame(Mod_OF))
	{
		Debug("Open Fortress: Server has %d alive reds and %d alive blues", game.AliveReds, game.AliveBlues);
		
		// If one team doesn't have any live players, start the timer
		//if (!game.AliveReds || !game.AliveBlues)
		//{
		//	Debug("Open Fortress: Starting the OF team check timer");
		//	CreateTimer(5.0, TimerCB_OFTeamCheck, _, TIMER_REPEAT);
		//}
		
		Debug("Open Fortress: Starting the OF team check timer");
		CreateTimer(5.0, TimerCB_OFTeamCheck, _, TIMER_REPEAT);
	}
	
		// Make red players eligible for queue points
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).Team == Team_Red)
		{
			Player(i).AddFlag(PF_PointsEligible);
			Debug("Granted %N the PF_PointsEligible flag", i);
		}
	}
}



void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	game.RoundState = Round_Win;
	
	// Grant Queue Points
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).HasFlag(PF_PointsEligible) && Player(i).HasFlag(PF_PrefActivator))
		{
			int awarded = (Player(i).HasFlag(PF_PrefFullQP)) ? QP_Full : QP_Partial;
			Player(i).AddPoints(awarded);
			ChatMessage(i, Msg_Reply, "%t", "round end queue points received", awarded, Player(i).Points);
		}
	}
	
	DisplayNextActivators();	// TODO: Don't display this if the map is about to change
	
	PrintToServer("%s The round has ended", PREFIX_SERVER);
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
		SCR_SendEvent(PREFIX_SERVER, "The round has ended");
}




/**
 * Player Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	//return; // BUG 
	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	//if (g_iGhost[player.Index] && !IsFakeClient(player.Index))
	//{
	//	MakeGhost(player.Index, false);
	//	return;
	//}
	
	if (game.RoundState == Round_Freeze || game.RoundState == Round_Active)
		RequestFrame(ApplyPlayerAttributes, client);
}




void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RequestFrame(NextFrame_InventoryApplied, client);
}

void NextFrame_InventoryApplied(int client)
{
	// Melee only
	if (g_ConVars[P_RedMelee].BoolValue)
		if (Player(client).Team == Team_Red)
			Player(client).MeleeOnly();
	
	// Boss Health Bar
	if (game.IsHealthBarActive && client == g_iBoss)
		Player(client).UpdateHealthBar();
	

	/**
	 * Weapon Checks
	 *
	 * In future I'd like to do different things depending on the weapon and have the things in a KV file.
	 */
	
	int weapon;
	int itemDefIndex;
	
	// Secondary Weapons
	if ((weapon = Player(client).GetWeapon(Weapon_Secondary)) != -1)
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	
	switch (itemDefIndex)
	{
		case 1179:		// Thermal thruster
		{
			if (g_bTF2Attributes)
				switch (3)
				{
					case 0: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", -1.0);	// Charges are drained rendering the weapon unuseable
					case 1: TF2Attrib_RemoveByName(weapon, "item_meter_charge_rate");		// Use normal charging behaviour
					case 2: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 120.0);	// Charges take one minute to charge
					case 3: TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.0);		// The player only has two charges
				}
		}
		case 812, 833:	// Cleaver
		{
			ReplaceWeapon(client, weapon, 23, "tf_weapon_pistol");
		}
	}
	
	
	// Melee Weapons
	if ((weapon = Player(client).GetWeapon(Weapon_Melee)) != -1)
	{
		itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
	}
	
	switch (itemDefIndex)
	{
		case 589:	// Eureka Effect
		{
			ReplaceWeapon(client, weapon, 7, "tf_weapon_wrench");
		}
	}
}



/**
 * player_hurt
 */
void Event_PlayerDamaged(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_ConVars[P_BossBar].BoolValue)
		return;
	
	int victim 		= GetClientOfUserId(event.GetInt("userid"));
	int attacker 	= GetClientOfUserId(event.GetInt("attacker"));
	
	if (attacker != victim && victim == g_iBoss)
		RequestFrame(UpdateHealthBar, victim);
}



void Event_PlayerHealed(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_ConVars[P_BossBar].BoolValue)
		return;
	
	int patient;
	
	// Grab player index from player_healed event
	if (StrEqual("player_healed", name))
		patient = GetClientOfUserId(event.GetInt("patient"));
	
	// Grab player index from player_healonhit event (TF2C uses this exclusively for health kits)
	if (StrEqual("player_healonhit", name))
		patient = event.GetInt("entindex");
	
	if (patient == g_iBoss)
		RequestFrame(UpdateHealthBar, patient);
}



void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!Player(client).HasFlag(PF_Welcomed))
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		ChatMessage(client, Msg_Reply, "%t", "welcome player to deathrun toolkit", sName);
		Player(client).AddFlag(PF_Welcomed);
	}
}



Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
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
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	// Chat Kill Feed TODO Change to player_hurt with 0 health for OF - why? 10/11/20
	if (g_ConVars[P_ChatKillFeed].BoolValue && event.GetInt("attacker") == 0)
	{
		char classname[64];
		
		if (game.IsGame(Mod_TF))
			event.GetString("weapon_logclassname", classname, sizeof(classname));
		else
			event.GetString("weapon", classname, sizeof(classname));
		
		if (classname[0] != 'w')	// Filter out 'world' as the killer entity because dying from fall damage is obvious
		{
			char targetname[256];
			
			if (game.IsGame(Mod_TF))
			{
				GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
		
				if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
					Format(targetname, sizeof(targetname), " (%s)", targetname);
			}
			
			ChatMessage(victim, Msg_Reply, "%t", "killed by entity classname", classname, targetname);
		}
	}
	
	// Boss Health Bar
	if (g_ConVars[P_BossBar].BoolValue && victim == g_iBoss)
		SetHealthBar();
	
	// Ghost Mode
	//if (g_ConVars[P_Ghosts].BoolValue && !IsFakeClient(victim))
	//	RequestFrame(RF_MakeGhost, victim);
}

//void RF_MakeGhost(int client)
//{
//	MakeGhost(client);
//}



Action Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Assign a random class
	if (!Player(client).IsBot && Player(client).Class == Class_Unknown)
	{
		Player(client).SetClass(GetRandomInt(1, 9));
	}
	// Note: This doesn't work on puppet bots. They are on the leaderboard but don't spawn. !player.IsBot added to prevent this.
	
	// Trying to prevent people going on blue team but switching them back to red appears to trigger the redistribution logic
	// and go int an inf loop
	
	//if ((GetTeamClientCount(Team_Red) + GetTeamClientCount(Team_Blue)) < 3)
	//	return;
	
	//if (event.GetInt("team") == Team_Blue && !player.IsActivator)
	//{
	//	Debug("A player who is not an activator tried to join Blue (%N)", player.Index);
	//	RequestFrame(RequestFrame_TeamsChanged, player);
	//	// I think the problem was forcing them back to Red without first disabling the 'watch for player changes' gBool? 
	//}
	
	if (event.GetInt("oldteam") == Team_Blue && Player(client).IsActivator)
	{
		Debug("Activator %N switched away from Blue so we're removing PF_Activator from them", client);
		Player(client).RemoveFlag(PF_Activator);
		// TODO Tell them to opt out if they don't want to be activator
	}
	
	// If we're watching for player changes during freeze time:
	if (game.HasFlag(GF_WatchMode))	// TODO Can this be replaced by a roundstate check?
		RequestFrame(CheckForPlayers);
}

//void RequestFrame_TeamsChanged(Player player)
//{
//	player.SetTeam(Team_Red, false);
//	Debug("%N joined team Blue so I put them on Red", player.Index);
//}


