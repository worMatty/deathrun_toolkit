
/**
 * Commands
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Show my queue points in chat.
 */
Action Command_ShowPoints(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	TF2_PrintToChat(client, _, "%t", "you_have_i_queue_points", Player(client).Points);
	EmitMessageSoundToClient(client);
	
	return Plugin_Handled;
}



// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Continue;
	
	if (Player(client).Points >= 0)
	{
		Player(client).SetPoints(QP_Consumed);
		TF2_PrintToChat(client, _, "%t", "points_have_been_reset_to_i", Player(client).Points);
		EmitMessageSoundToClient(client);
	}
	else
	{
		TF2_PrintToChat(client, _, "%t", "points_cannot_be_reset");
		EmitMessageSoundToClient(client);
	}
	
	return Plugin_Handled;
}




// drtoggle
Action Command_ToggleActivator(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	Player player = Player(client);
	
	if (player.HasFlag(PF_PrefActivator))
	{
		player.RemoveFlag(PF_PrefActivator);
		TF2_PrintToChat(client, _, "%t", "opted_out_activator");
		EmitMessageSoundToClient(client);
	}
	else
	{
		player.AddFlag(PF_PrefActivator);
		TF2_PrintToChat(client, _, "%t", "opted_in_activator");
		EmitMessageSoundToClient(client);
	}
	
	return Plugin_Handled;
}




// na
Action Command_NextActivators(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	char buffer[MAX_CHAT_MESSAGE], arg[3];
	int number = GetNumActivatorsRequired();
	
	if (GetCmdArg(1, arg, sizeof(arg)))
	{
		number = StringToInt(arg);
	}
	
	if (FormatNextActivators(buffer, number))
	{
		TF2_PrintToChat(client, _, buffer);
		EmitMessageSoundToClient(client);
	}
	
	return Plugin_Handled;
}




// Help
Action Command_Help(int client, int args)
{
	TF2_PrintToChat(client, _, "Opening the help page. You need HTML MOTD enabled");
	TF2_PrintToChat(client, _, "%s", HELP_URL);
	
	KeyValues kv = CreateKeyValues("data");
	kv.SetString("msg", HELP_URL);
	kv.SetNum("customsvr", 1);
	kv.SetNum("type", MOTDPANEL_TYPE_URL);	// MOTDPANEL_TYPE_URL displays a web page. MOTDPANEL_TYPE_TEXT displays text. MOTDPANEL_TYPE_FILE shows a blank MOTD panel. MOTDPANEL_TYPE_INDEX shows a blank panel with title.
	ShowVGUIPanel(client, "info", kv, true);
	kv.Close();
	
	return Plugin_Handled;
}



/*
// Show player flags in console
Action AdminCommand_PlayerData(int client, int args)
{
	PrintToConsole(client, "\n %s Player points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.\n", PLUGIN_PREFIX);
	PrintToConsole(client, " Index | Name                             | Points | Flags         | Activator Last");
	PrintToConsole(client, " ----------------------------------------------------------------------------------");
	
	char name[MAX_NAME_LENGTH];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame)
		{
			GetClientName(i, name, sizeof(name));
		}
		else
		{
			name = "<no player>";
		}
		
		PrintToConsole(client, " %5d | %32s | %6d | %06b %06b | %d", i, name, player.Points, ((player.Flags & MASK_SESSION_FLAGS) >> 16), (player.Flags & MASK_STORED_FLAGS), player.ActivatorLast);
	}
	
	PrintToConsole(client, " ----------------------------------------------------------------------------------");
	PrintToConsole(client, " Game State Flags: %06b  Round State: %d  Game: %03b\n\n", g_iGameState, DRGame.RoundState, g_iGame);
	if (client) TF2_PrintToChat(client, "Check console for output");
	
	return Plugin_Handled;
}
*/



// Show player flags in console
Action AdminCommand_PlayerData(int client, int args)
{
	PrintToConsole(client, "\n %s Player points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.\n", PLUGIN_PREFIX);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		char name[25] = "----", flags[128];
		Player player = Player(i);
		
		if (player.InGame)
		{
			Format(name, sizeof(name), "%N", player.Index);
		}
		
/*		enum {
			PF_PrefActivator = 0x1,			// Wants to be activator
			//PF_PrefFullQP = 0x2,			// Wants full queue points (no longer used)
			PF_PrefEnglish = 0x4,			// Wants English SourceMod
			
			PF_Welcomed = 0x10000,			// Has been welcomed to the server
			PF_Activator = 0x20000,			// Is an activator
			PF_Runner = 0x40000,			// Is a runner
			PF_TurnToken = 0x80000,			// Turn token
			PF_CanBoost = 0x140000,			// Is allowed to use the +speed boost
		}
*/		
		
		if (player.Flags & PF_Activator)
		{
			Format(flags, sizeof(flags), " ACTIVATOR");
		}
		if (player.Flags & PF_Runner)
		{
			Format(flags, sizeof(flags), "%s | RUNNER", flags);
		}
		if (player.Flags & PF_PrefActivator)
		{
			Format(flags, sizeof(flags), "%s | OPTED-IN", flags);
		}
		if (player.Flags & PF_Welcomed)
		{
			Format(flags, sizeof(flags), "%s | WELCOMED", flags);
		}
		if (player.Flags & PF_PrefEnglish)
		{
			Format(flags, sizeof(flags), "%s | ENGLISH", flags);
		}
		
		PrintToConsole(client, " %2d. %24s (#%d - %d) Points: %d ActLast: %d \
			Flags:%s", i, name, player.ArrayUserID, (player.InGame) ? player.SteamID : 0, player.Points, player.ActivatorLast, flags);
	}
	
	PrintToConsole(client, "\n Game State Flags: %06b  Round State: %s\n\n", g_iGameState, g_sRoundStates[DRGame.RoundState]);
	if (client)
	{
		TF2_PrintToChat(client, _, "Check console for output");
		EmitMessageSoundToClient(client);
	}
	
	return Plugin_Handled;
}



Action AdminCommand_SetClass(int client, int args)
{
	if (args < 1 || args > 2)
	{
		ReplyToCommand(client, "Usage: sm_setclass <target(s)> [class] (blank for random)");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH], arg2[10];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	char tfclassnames[10][20] = { "random class", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" };

	// Get class
	int class;
	class = ProcessClassString(arg2);
	if (class == 0)
	{
		class = GetRandomInt(1, 9);
	}
	
	char sClass[20];
	Format(sClass, sizeof(sClass), "%s", tfclassnames[class]);

	int iTarget[MAXPLAYERS];
	int iTargetCount;
	bool bIsMultiple; // Not used
	char sTargetName[MAX_NAME_LENGTH];
	
	iTargetCount = ProcessTargetString(arg1, client, iTarget, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsMultiple);
	
	if (iTargetCount <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
	}
	else
	{
		for (int i = 0; i < iTargetCount; i++)
		{
			Player(iTarget[i]).SetClass(class);
			RequestFrame(ApplyPlayerAttributes, client);
			
			if (client == iTarget[i])
			{
				TF2_PrintToChat(iTarget[i], _, "You are now a %s", sClass);
				EmitMessageSoundToClient(client);
			}
			else
			{
				TF2_PrintToChat(iTarget[i], client, "\x02%N has made you a %s", client, sClass);
				EmitMessageSoundToClient(client);
			}
			LogAction(client, iTarget[i], "%L changed class of %L to %s", client, iTarget[i], sClass);
		}
	}
	
	return Plugin_Handled;
}




Action AdminCommand_SetSpeed(int client, int args)
{
	if (args < 1 || args > 2)
	{
		TF2_PrintToChat(client, _, "Usage: sm_setspeed <target(s)> [speed]");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH], arg2[10];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	int speed = StringToInt(arg2);

	int iTarget[MAXPLAYERS];
	int iTargetCount;
	bool bIsMultiple; // Not used
	char sTargetName[MAX_NAME_LENGTH];
	
	iTargetCount = ProcessTargetString(arg1, client, iTarget, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsMultiple);
	
	if (iTargetCount <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
	}
	else
	{
		for (int i = 0; i < iTargetCount; i++)
		{
			int player = iTarget[i];
			Player(player).SetSpeed(speed);
			if (client == iTarget[i])
			{
				TF2_PrintToChat(iTarget[i], _, "Your speed has been set to %du/s", speed);
				EmitMessageSoundToClient(client);
			}
			else
			{
				TF2_PrintToChat(iTarget[i], client, "\x02%N has set your speed to %du/s", client, speed);
				EmitMessageSoundToClient(client);
			}
			LogAction(client, iTarget[i], "%L changed speed of %L to %d", client, iTarget[i], speed);
		}
	}
	
	return Plugin_Handled;
}



// Admin can award a player some queue points TODO Increase integer length 'because' and add setpoints command
Action AdminCommand_AwardPoints(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	if (args != 2)
	{
		TF2_PrintToChat(client, _, "%t", "wrong_usage_of_award_command");
		EmitMessageSoundToClient(client);
		return Plugin_Handled;
	}
	
	char sArg1[MAX_NAME_LENGTH], sArg2[16];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int iPoints = StringToInt(sArg2);
	
	int iTarget = FindTarget(client, sArg1, false, false);
	if (iTarget == -1)
	{
		ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
		return Plugin_Handled;
	}
	else
	{
		Player(iTarget).AddPoints(iPoints);
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(client, sTargetName, sizeof(sTargetName));
		
		TF2_PrintToChat(iTarget, client, "%t", "received_queue_points_from_an_admin", sTargetName, iPoints, Player(iTarget).Points);
		EmitMessageSoundToClient(iTarget);
		
		ShowActivity(client, "Awarded %d queue points to %N. New total: %d", iPoints, iTarget, Player(iTarget).Points);
		LogMessage("%L awarded %L %d queue points", client, iTarget, iPoints);
		
		return Plugin_Handled;
	}
}



// Delete the table from the database
Action AdminCommand_RemoveDBTable(int client, int args)
{
	char confirm[8];
	GetCmdArg(1, confirm, sizeof(confirm));
	
	if (StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "Deleting the table from your database");
		DBReset(client);
	}
	else
	{
		ReplyToCommand(client, "To reset the database, supply the argument 'confirm'");
	}
	
	return Plugin_Handled;
}



// Delete a user from the database
Action AdminCommand_RemoveDBUser(int client, int args)
{
	char command[64], confirm[8];
	
	GetCmdArg(0, command, sizeof(command));
	GetCmdArg(2, confirm, sizeof(confirm));
	
	if (args == 2 && StrEqual(confirm, "confirm"))
	{
		char player[64];
		int target;
		
		GetCmdArg(1, player, sizeof(player));
		target = FindTarget(client, player, true, false);
		
		if (target == -1)
		{
			ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
		}
		else
		{
			ReplyToCommand(client, "Deleting %N from the database table", target);
			Player(target).DeleteRecord(client);
		}
	}
	else
	{
		ReplyToCommand(client, "Usage: %s <username/#userid> confirm\nUser must be present on the server", command);
	}
	
	return Plugin_Handled;
}



// Reload configuration files
Action AdminCommand_ReloadConfigs(int client, int args)
{
	ReplyToCommand(client, "Reloading the config files");
	
	LoadConfigs();
	
	return Plugin_Handled;
}




/**
 * Command Listeners
 * ----------------------------------------------------------------------------------------------------
 */

// kill, explode, spectate
Action CmdListener_LockBlue(int client, const char[] command, int args)
{
	Player player = Player(client);
	
	// Prevent Activators Escaping
	if (DRGame.RoundState == Round_Active && player.Team == Team_Blue && player.IsAlive && player.HasFlag(PF_Activator) && g_ConVars[P_LockActivator].BoolValue)
	{
		TF2_PrintToChat(client, _, "%t", "activator_no_escape");
		EmitMessageSoundToClient(client);
		PrintToConsole(client, "%s Command '%s' has been disallowed by the server.", PLUGIN_PREFIX, command);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


// jointeam, autoteam
Action CmdListener_Teams(int client, const char[] command, int args)
{
	char arg1[32], arg2[32];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if (StrEqual(command, "jointeam", false))
	{
		Player player = Player(client);
		
		// Assign a class if a player has none
		// We're now moving players with no class to Spec on round start
		/*
		if (DRGame.RoundState == Round_Freeze && player.Class == Class_Unknown)
		{
			player.SetClass(GetRandomInt(1, 9), _, true);
			Debug("%N had no class so we chose a random one for them", client);
		}
		*/
		
		// Prevent Activators Escaping
		if (player.Team == Team_Blue && player.HasFlag(PF_Activator))
		{
			if ((DRGame.RoundState == Round_Active && g_ConVars[P_LockActivator].BoolValue) ||
				(DRGame.RoundState == Round_Freeze && g_ConVars[P_LockActivator].IntValue == 2))
			{
				TF2_PrintToChat(client, _, "%t", "activator_no_escape");
				EmitMessageSoundToClient(client);
				return Plugin_Handled;
			}
		}
		
		// Prevent Players Joining Blue - Commented out as the Event-based system works
		/*
		if (StrEqual(arg1, "blue", false) && (DRGame.RoundState == Round_Active || DRGame.RoundState == Round_Freeze))
		{
			ChangeClientTeam(client, Team_Red);	// Best for TF2C as blocking the command prevents them choosing a team
			Debug("%N tried to join Blue but was moved instead to Red", client);
			return Plugin_Handled;
		}
		*/
	}
	
	// Block the 'autoteam' command at all times because it bypasses team balancing
	if (StrEqual(command, "autoteam", false))
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}



Action CmdListener_Builds(int client, const char[] command, int args)
{
	/* TODO Translation phrases
	
	build 0 0 will build a Dispenser (Engineer only)
    build 1 0 will build a teleporter entrance (Engineer only)
    build 1 1 will build a teleporter exit (Engineer only)
    build 2 0 will build a Sentry Gun (Engineer only)
    build 3 0 will build a Sapper (Spy only)
    
    build 0 will build a Dispenser (Engineer only)
    build 1 will build a teleporter entrance (Engineer only)
    build 2 will build a Sentry Gun (Engineer only)
    build 3 will build a teleporter exit (Engineer only)
    build 3 will build a Sapper (Spy only) [deprecated]
    
    1 = sentry
	2 = dispenser
	4 = tele entrance
	8 = tele exit
	
	*/

	if (g_ConVars[P_Buildings].IntValue != 0)
	{
		char arg1[2], arg2[2];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		int iArg1 = StringToInt(arg1);
		int iArg2 = StringToInt(arg2);
		
		if (iArg1 == 0 && (g_ConVars[P_Buildings].IntValue & Build_Dispenser) == Build_Dispenser)
		{
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build dispensers");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 0 && (g_ConVars[P_Buildings].IntValue & Build_TeleEnt) == Build_TeleEnt)
		{
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter entrances");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 1 && (g_ConVars[P_Buildings].IntValue & Build_TeleEx) == Build_TeleEx)
		{
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter exits");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 2 && (g_ConVars[P_Buildings].IntValue & Build_Sentry) == Build_Sentry)
		{
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build sentries");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		
		// build 3 is for backwards compatability of the deprecated build argument to build a tele exit
		if (iArg1 == 3 && (g_ConVars[P_Buildings].IntValue & Build_TeleEx) == Build_TeleEx && Player(client).Class == Class_Engineer)
		{
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter exits");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}