#pragma semicolon 1

static bool restarting;

void Event_RoundRestart (Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("--- The deathrun round has restarted ---");
	DRGame.RoundState = Round_Freeze;

	#if defined MAP_INSTRUCTIONS
	Instructions_FindEnts();
	#endif

	/**
	 * Double round restart protection
	 *
	 * In TF2 Arena there is a bit of a problem.
	 * If a team is empty when the round restarts, the game will go into a waiting state.
	 * Once a player joins the empty team, the round will immediately restart again.
	 * This can cause the activator we selected to be replaced by another.
	 */

	if (restarting)
	{
		ShowActivity(0, "Double round restart detected");
		return;
	}

	// Activator Selection
	restarting = true;

	for (int i = 1; i <= MaxClients; i++)
	{
		DRPlayer player = DRPlayer(i);

		if (player.InGame)
		{
			if (player.Team == Team_Blue)
			{
				player.SetTeam(Team_Red, true);
			}
			else
			{
				ApplyPlayerAttributes(i);
			}
		}
	}

	SelectActivators();
	CreateTimer(1.0, Timer_RoundRestarted);
}

Action Timer_RoundRestarted(Handle timer)
{
	restarting = false;

	return Plugin_Stop;
}


static Handle g_hNextActivator;

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	DRGame.InWatchMode = false;	// No need to watch for team changes now

	// Round Start Message
	if (g_ConVars[P_RoundStartMessage].BoolValue)
	{
		static int phrase_number = 1;
		char phrase[20];
		Format(phrase, sizeof(phrase), "round_has_begun_%d", phrase_number);

		if (!TranslationPhraseExists(phrase))
		{
			phrase_number = 1;
			Format(phrase, sizeof(phrase), "round_has_begun_%d", phrase_number);
		}

		TF2_PrintToChatAll(_, "%t", phrase);
		phrase_number++;
	}

	// Set round state to Active
	DRGame.RoundState = Round_Active;

	PrintToServer("--- The deathrun round is now active ---");
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
	{
		SCR_SendEvent("Deathrun Round Active", "Activators: %d Runners: %d", TFTeam_Blue.AliveCount(), TFTeam_Red.AliveCount());
	}

	// Start next activator message timer
	delete g_hNextActivator;
	g_hNextActivator = CreateTimer(TIMER_NA_MESSAGE, Timer_NextActivator_Message, _, TIMER_REPEAT);
}

Action Timer_NextActivator_Message(Handle timer, any data)
{
	if (DRGame.RoundState != Round_Active)
	{
		g_hNextActivator = null;
		return Plugin_Stop;
	}

	char buffer[MAX_CHAT_MESSAGE];
	int numact = GetNumActivatorsRequired();

	if (FormatNextActivators(buffer, numact))
	{
		PrintToChatAll(buffer);
	}

	return Plugin_Continue;
}


void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	DRGame.RoundState = Round_Win;

	char buffer[MAX_CHAT_MESSAGE];
	int activators = GetNumActivatorsRequired();

	FormatNextActivators(buffer, activators);	// TODO: Don't display this if the map is about to change

	if (buffer[0] != '\0')
	{
		TF2_PrintToChatAll(_, buffer);
	}

	PrintToServer("--- The deathrun round has ended ---");

	int winning_team = event.GetInt("team", 0);
	char scr_message[64];

	switch (winning_team)
	{
		case Team_Blue:
		{
			Format(scr_message, sizeof(scr_message), "The runners lost!");
		}
		case Team_Red:
		{
			Format(scr_message, sizeof(scr_message), "The runners won!");
		}
		default:
		{
			Format(scr_message, sizeof(scr_message), "The round ended with no winning team");
		}
	}

	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
	{
		SCR_SendEvent("Deathrun Round Ended", scr_message);
	}
}


void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (DRGame.RoundState == Round_Freeze || DRGame.RoundState == Round_Active)
	{
		RequestFrame(ApplyPlayerAttributes, client);
	}
}


void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RequestFrame(RF_InventoryApplied, client);
}

void RF_InventoryApplied(int client)
{
	// Restrict Items
	if (g_ConVars[P_RestrictItems].BoolValue)
	{
		CheckItems(client);
	}

	RequestFrame(RF_InventoryApplied2, client);
}

void RF_InventoryApplied2(int client)
{
	DRPlayer player = DRPlayer(client);

	// Red melee-only
	if (g_ConVars[P_RedMelee].BoolValue)
	{
		if (player.Team == Team_Red)
		{
			player.MeleeOnly();
		}
	}

	// Blue melee-only
	if (g_ConVars[P_BlueMelee].BoolValue)
	{
		if (player.Team == Team_Blue)
		{
			player.MeleeOnly();
		}
	}
}


void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	// Welcome the player
	if (!DRPlayer(client).Welcomed)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		TF2_PrintToChat(client, client, "%t", "welcome_player_to_deathrun_toolkit", sName);
		EmitMessageSoundToClient(client);
		DRPlayer(client).Welcomed = true;
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

		if (IsGameTF2())
		{
			event.GetString("weapon_logclassname", classname, sizeof(classname));
		}
		else
		{
			event.GetString("weapon", classname, sizeof(classname));
		}

		if (classname[0] != 'w')	// Filter out 'world' as the killer entity because dying from fall damage is obvious
		{
			char targetname[256];

			if (IsGameTF2())
			{
				GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));

				if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
				{
					Format(targetname, sizeof(targetname), "(%s)", targetname);
				}
			}

			TF2_PrintToChat(victim, _, "%t", "killed_by_entity_classname", classname, targetname);
			EmitMessageSoundToClient(victim);
			PrintToConsoleAll("%N was killed by a %s %s", victim, classname, targetname);
		}
	}

	return Plugin_Handled;
}


Action Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	DRPlayer player = DRPlayer(GetClientOfUserId(event.GetInt("userid")));

	// Player switches away from Blue
	if (event.GetInt("oldteam") == Team_Blue)
	{
		if (player.IsActivator)
		{
			player.UnmakeActivator();
		}
	}

	// Player switches away from Red
	if (event.GetInt("oldteam") == Team_Red)
	{
		player.Runner = false;
	}

	// Player switches to Red
	if (event.GetInt("team") == Team_Red)
	{
		player.Runner = true;

		// Kill players joining red during the round to prevent them being in limbo
		// because they can't choose a class so won't spawn. Game bug!
		//if (DRGame.RoundState == Round_Active && player.IsAlive)
		//{
			//player.IsAlive = false;
			//Debug("%L joined red during an active round but had no class, so their life state has been set to Dead", player.Index);
			//ShowActivity(player.Index, "Joined red team without a chosen class. Their life state has been set to Dead");
		//}
	}

	// Non-Activator switches to Blue during a running game
	if (event.GetInt("team") == Team_Blue && !player.Activator && GetActiveClientCount() > 2)
	{
		RequestFrame(RF_MoveToRed, player.Index);
	}
	// Non-Activator switches to Blue while the game is not running
	else if (event.GetInt("team") == Team_Blue && !player.Activator && TFTeam_Blue.Count())
	{
		// If a player somehow switches to Blue while there is already a player there
		// they will be moved to Red
		RequestFrame(RF_MoveToRed, player.Index);
	}

	// Check teams on any change
	RequestFrame(CheckTeams);

	return Plugin_Handled;
}

void RF_MoveToRed(int client)
{
	DRPlayer(client).SetTeam(Team_Red);
}