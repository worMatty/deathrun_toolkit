
/**
 * Commands
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Show my queue points in chat.
 */
Action Command_ShowPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	Player player = new Player(client);
	
	if (g_cUsePointsSystem.BoolValue == true)
		ReplyToCommand(client, "%t %t", "prefix_notice", "you have i points", player.Points);
	else
		ReplyToCommand(client, "%t %t", "prefix_notice", "not using the points system");
		
	return Plugin_Handled;
}



// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
	
	Player player = new Player(client);
	
	if (g_cUsePointsSystem.BoolValue == true)
	{
		if (player.Points >= 0)
		{
			player.SetPoints(Points_Consumed);
			ReplyToCommand(player.Index, "%t %t", "prefix_notice", "points have been reset to i", player.Points);
			DebugMessage("%N has reset their points using /reset", player.Index);
		}
		else
		{
			ReplyToCommand(player.Index, "%t %t", "prefix_notice", "points cannot be reset");
			LogMessage("%L tried to reset their points total but was disallowed because it is a negative value", player.Index);
		}
	}
	else
		ReplyToCommand(player.Index, "%t %t", "prefix", "not using the points system");
		
	return Plugin_Handled;
}



// Set my queue points multiplier and activator preference
Action Command_Preferences(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	if (args < 1)
	{
		Player player = new Player(client);
		if (!(player.Flags & FLAGS_PREFERENCE))
			// If player.Flags does not have the FLAGS_PREFERENCE bit set return false
		{
			ReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to never be the activator");
		}
		else
		{
			ReplyToCommand(client, "%t %t", "prefix_notice", "current preference is to receive i points per round", (player.Flags & FLAGS_FULLPOINTS) ? Points_FullAward : Points_PartialAward);
			// If player.Flags has the FLAGS_FULLPOINTS bit set return true, otherwise return false
		}
		
		PrintToConsole(client, " %s Your preference bit flags: Session: %06b Stored: %06b", SERVERMSG_PREFIX, (player.Flags & FLAGS_SESSION), (player.Flags & FLAGS_STORED));
		return Plugin_Handled;
	}
	
	char sArg1[2];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (StrEqual("?", sArg1))
		ReplyToCommand(client, "%t %t", "prefix", "usage of pref command");
	else
	{
		int iArg1 = StringToInt(sArg1);
		AdjustPreference(client, iArg1);
	}
	
	return Plugin_Handled;
}



void AdjustPreference(int client, int selection)
{
	Player player = new Player(client);
	
	switch (selection)
	{
		case 0:
		{
			player.Flags &= ~FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 0
			ReplyToCommand(client, "%t %t", "prefix_notice", "no longer receive queue points");
			LogMessage(" [DR] %N Has opted out of being the activator", player.Index);
		}
		case 1:
		{
			player.Flags |= FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 1
			player.Flags &= ~FLAGS_FULLPOINTS;
			// Set the FLAGS_FULLPOINTS bit to 0
			ReplyToCommand(client, "%t %t", "prefix_notice", "you will now receive fewer queue points");
			LogMessage(" [DR] %N Has opted to receive fewer queue points", player.Index);
		}
		case 2:
		{
			player.Flags |= FLAGS_PREFERENCE;
			// Set the FLAGS_PREFERENCE bit to 1
			player.Flags |= FLAGS_FULLPOINTS;
			// Set the FLAGS_FULLPOINTS bit to 1
			ReplyToCommand(client, "%t %t", "prefix_notice", "you will receive the maximum amount of queue points");
			LogMessage(" [DR] %N Has opted to receive full queue points", player.Index);
		}
	}	
}



// Toggle English language
void Command_English(int client)
{	
	Player player = new Player(client);
	
	if ((player.Flags & FLAGS_ENGLISH))
	// If the player has the FLAGS_ENGLISH bit set return true
	{
		player.Flags &= ~FLAGS_ENGLISH;
		// Set the FLAGS_ENGLISH bit to 0
		char language[32];
		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
				ReplyToCommand(client, "%t When you next connect, your client language will be used", "prefix_notice");
			else
			{
				SetClientLanguage(client, iLanguage);
				ReplyToCommand(client, "%t Your client language of '%s' will now be used", "prefix_notice", language);
			}
		}
	}
	else
	{
		player.Flags |= FLAGS_ENGLISH;
		// Set the FLAGS_ENGLISH bit to 1
		ReplyToCommand(client, "%t Your language has been been set to English", "prefix_notice");
		SetClientLanguage(client, 0);
	}
}



// Show the contents of the player prefs and points arrays in client console
// Set my queue points multiplier and activator preference
Action AdminCommand_PlayerData(int client, int args)
{
	PrintToConsole(client, "\n %s Player points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.\n", SERVERMSG_PREFIX);
	PrintToConsole(client, " Index | User ID | Steam ID   | Name                             | Points | Flags");
	PrintToConsole(client, " ----------------------------------------------------------------------------------------");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		char sName[MAX_NAME_LENGTH] = "<no player>";
		//if (IsValidEdict(i))
		//if (IsClientConnected(i))
		if (player.InGame)
			Format(sName, MAX_NAME_LENGTH, "%N", player.Index);
		PrintToConsole(client, " %5d | %7d | %10d | %32s | %6d | %06b %06b", player.Index, player.ArrayUserID, player.SteamID, sName, player.Points, ((player.Flags & FLAGS_SESSION) >> 16), (player.Flags & FLAGS_STORED));
			// This bit shift operation should take the resulting bits and shift them all down to the 'stored' range for display purposes
	}
	
	PrintToConsole(client, " ----------------------------------------------------------------------------------------");
	ReplyToCommand(client, "%t Check console for output", "prefix_notice");
	
	return Plugin_Handled;
}



Action AdminCommand_SetClass(int client, int args)
{
	if (args < 1 || args > 2)
	{
		ReplyToCommand(client, "%t Usage: sm_setclass <target(s)> [class] (blank for random)", "prefix_notice");
		return Plugin_Handled;
	}
	
	char arg1[MAX_NAME_LENGTH], arg2[10];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	char tfclassnames[10][20] = { "random class", "Scout", "Sniper", "Soldier", "Demoman", "Medic", "Heavy", "Pyro", "Spy", "Engineer" };

	// Get class
	int class;
	/*
	TFClassType class;
	if (strncmp(arg2, "scout", 3, false) == 0)
	{
		class = TFClass_Scout;
	}
	else if (strncmp(arg2, "soldier", 3, false) == 0)
	{
		class = TFClass_Soldier;
	}
	else if (strncmp(arg2, "pyro", 3, false) == 0)
	{
		class = TFClass_Pyro;
	}
	else if (strncmp(arg2, "demo", 3, false) == 0)
	{
		class = TFClass_DemoMan;
	}
	else if (strncmp(arg2, "heavy", 3, false) == 0)
	{
		class = TFClass_Heavy;
	}
	else if (strncmp(arg2, "engineer", 3, false) == 0)
	{
		class = TFClass_Engineer;
	}
	else if (strncmp(arg2, "medic", 3, false) == 0)
	{
		class = TFClass_Medic;
	}
	else if (strncmp(arg2, "spy", 3, false) == 0)
	{
		class = TFClass_Spy;
	}
	else if (strncmp(arg2, "sniper", 3, false) == 0)
	{
		class = TFClass_Sniper;
	}
	else
	{
		class = view_as<TFClassType>(GetRandomInt(1, 9));
	}*/
	
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
			Player player = new Player(iTarget[i]);
			player.SetClass(view_as<TFClassType>(class));
			if (client == iTarget[i])
				PrintToChat(iTarget[i], "%t You are now a %s", "prefix_notice", sClass);
			else
				PrintToChat(iTarget[i], "%t %N has made you a %s", "prefix_notice", client, sClass);
			LogAction(client, iTarget[i], "%L respawned %L", client, iTarget[i]);
		}
	}
	
	return Plugin_Handled;
}



// Admin can award a player some queue points TODO Increase integer length 'because' and add setpoints command
Action AdminCommand_AwardPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	if (args != 2)
	{
		ReplyToCommand(client, "%t %t", "prefix", "wrong usage of award command");
		return Plugin_Handled;
	}
	
	char sArg1[MAX_NAME_LENGTH], sArg2[6];
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
		Player player = new Player(iTarget);
		player.AddPoints(iPoints);
		char sTargetName[MAX_NAME_LENGTH];
		GetClientName(client, sTargetName, sizeof(sTargetName));
		
		PrintToChat(iTarget, "%t %t", "prefix_notice", "received queue points from an admin", sTargetName, iPoints, player.Points);
		
		ShowActivity(client, "Awarded %N %d queue points. New total: %d", iTarget, iPoints, player.Points);
		LogMessage("%L awarded %L %d queue points", client, iTarget, iPoints);
		
		return Plugin_Handled;
	}
}

// Reset the player database
Action AdminCommand_ResetDatabase(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(1, confirm, sizeof(confirm));
	
	if (!StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "%t To reset the database, supply the argument 'confirm'", "prefix_notice");
		return Plugin_Handled;
	}
	else if (StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "%t Resetting the player database...", "prefix_notice");
		game.ResetDB(client);
	}
	
	return Plugin_Handled;
}

// Reset a user (delete them from the database)
Action AdminCommand_ResetUser(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(2, confirm, sizeof(confirm));
	
	if (args != 2 || !StrEqual(confirm, "confirm"))
	{
		ReplyToCommand(client, "%t Usage: sm_resetuser <user> confirm", "prefix_notice");
		return Plugin_Handled;
	}
	else if (args == 2 && StrEqual(confirm, "confirm"))
	{
		char sPlayer[65];
		GetCmdArg(1, sPlayer, sizeof(sPlayer));
		
		int iTarget = FindTarget(client, sPlayer, true, false);
		if (iTarget == -1)
		{
			ReplyToTargetError(client, COMMAND_TARGET_AMBIGUOUS);
			return Plugin_Handled;
		}
		else
		{
			ReplyToCommand(client, "%t Deleting %N from the database...", "prefix_notice", iTarget);
			Player player = new Player(iTarget);
			player.DeleteRecord(client);
		}
	}
	
	return Plugin_Handled;
}

/*/ Show the available commands
Action Command_Menu(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;

	ReplyToCommand(client, "%t No menu yet. Deathrun Toolkit is in development. Head to Discord to suggest things. https://discordapp.com/invite/3F7QADc", "prefix");
	ReplyToCommand(client, "%t Available commands: /points\x02, /reset\x02, /pref 0/1/2\x02.", "prefix");

	return Plugin_Handled;
}*/
