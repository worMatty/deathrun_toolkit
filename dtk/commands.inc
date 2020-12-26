
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
	
	Player player = new Player(client);
	
	ChatMessage(client, Msg_Reply, "%t", "you have i points", player.Points);
	
	return Plugin_Handled;
}



// Reset my points
Action Command_ResetPoints(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Continue;
	
	Player player = new Player(client);
	
	if (player.Points >= 0)
	{
		player.SetPoints(QP_Consumed);
		ChatMessage(player.Index, Msg_Reply, "%t", "points have been reset to i", player.Points);
		Debug("%N has reset their points using /reset", player.Index);
	}
	else
	{
		ChatMessage(player.Index, Msg_Reply, "%t", "points cannot be reset");
	}
	
	return Plugin_Handled;
}



// Set my queue points multiplier and activator preference
Action Command_Preferences(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	if (args < 1)
	{
		Player player = new Player(client);
		if (!player.HasFlag(FLAG_PREF_ACTIVATOR))
			ChatMessage(client, Msg_Reply, "%t", "current preference is to never be the activator");
		else
			ChatMessage(client, Msg_Reply, "%t", "current preference is to receive i points per round", (player.HasFlag(FLAG_PREF_FULLQP)) ? QP_Full : QP_Partial);
		
		PrintToConsole(client, " %s Your preference bit flags: Session: %06b Stored: %06b", PREFIX_SERVER, (player.Flags & MASK_SESSION_FLAGS), (player.Flags & MASK_STORED_FLAGS));
		return Plugin_Handled;
	}
	
	char sArg1[2];
	GetCmdArg(1, sArg1, sizeof(sArg1));
	
	if (StrEqual("?", sArg1))
		ChatMessage(client, Msg_Reply, "%t", "usage of pref command");
	else
	{
		int iArg1 = StringToInt(sArg1);
		AdjustPreference(client, iArg1);
	}
	
	return Plugin_Handled;
}



// Toggle English language
void Command_English(int client)
{	
	Player player = new Player(client);
	
	if (player.HasFlag(FLAG_PREF_ENGLISH))
	{
		player.RemoveFlag(FLAG_PREF_ENGLISH);
		char language[32];
		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
				ChatMessage(client, Msg_Reply, "When you next connect, your client language will be used");
			else
			{
				SetClientLanguage(client, iLanguage);
				ChatMessage(client, Msg_Reply, "Your client language of '%s' will now be used", language);
			}
		}
	}
	else
	{
		player.AddFlag(FLAG_PREF_ENGLISH);
		ChatMessage(client, Msg_Reply, "Your language has been been set to English");
		SetClientLanguage(client, 0);
	}
}



// Show the contents of the player prefs and points arrays in client console
// Set my queue points multiplier and activator preference
Action AdminCommand_PlayerData(int client, int args)
{
	PrintToConsole(client, "\n %s Player points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.\n", PREFIX_SERVER);
	PrintToConsole(client, " Index | User ID | Steam ID   | Name                             | Points | Flags");
	PrintToConsole(client, " ----------------------------------------------------------------------------------------");
	
	char name[MAX_NAME_LENGTH];
	int steamid;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = new Player(i);
		
		if (player.InGame)
		{
			GetClientName(player.Index, name, sizeof(name));
			steamid = player.SteamID;
		}
		else
		{
			name = "<no player>";
			steamid = 0;
		}
		
		PrintToConsole(client, " %5d | %7d | %10d | %32s | %6d | %06b %06b", player.Index, player.ArrayUserID, steamid, name, player.Points, ((player.Flags & MASK_SESSION_FLAGS) >> 16), (player.Flags & MASK_STORED_FLAGS));
			// This bit shift operation should take the resulting bits and shift them all down to the 'stored' range for display purposes
	}
	
	PrintToConsole(client, " ----------------------------------------------------------------------------------------");
	PrintToConsole(client, " Game State Flags: %06b  Round State: %d  Game: %03b\n\n", g_iGameState, game.RoundState, g_iGame);
	ChatMessage(client, Msg_Reply, "Check console for output");
	
	return Plugin_Handled;
}



Action AdminCommand_SetClass(int client, int args)
{
	if (args < 1 || args > 2)
	{
		ChatMessage(client, Msg_Reply, "Usage: sm_setclass <target(s)> [class] (blank for random)");
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
			Player player = new Player(iTarget[i]);
			player.SetClass(class);
			if (client == iTarget[i])
				ChatMessage(iTarget[i], Msg_Reply, "You are now a %s", sClass);
			else
				ChatMessage(iTarget[i], Msg_Reply, "%N has made you a %s", client, sClass);
			LogAction(client, iTarget[i], "%L changed class of %L to %s", client, iTarget[i], sClass);
		}
	}
	
	return Plugin_Handled;
}




Action AdminCommand_SetSpeed(int client, int args)
{
	if (args < 1 || args > 2)
	{
		ChatMessage(client, Msg_Reply, "Usage: sm_setspeed <target(s)> [speed]");
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
			Player player = new Player(iTarget[i]);
			player.SetSpeed(speed);
			if (client == iTarget[i])
				ChatMessage(iTarget[i], Msg_Reply, "Your speed has been set to %du/s", speed);
			else
				ChatMessage(iTarget[i], Msg_Reply, "%N has set your speed to %du/s", client, speed);
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
		ChatMessage(client, Msg_Reply, "%t", "wrong usage of award command");
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
		
		ChatMessage(iTarget, Msg_Reply, "%t", "received queue points from an admin", sTargetName, iPoints, player.Points);
		
		ChatAdmins(Msg_Reply, "%N awarded %N %d queue points. New total: %d", client, iTarget, iPoints, player.Points);
		LogMessage("%L awarded %L %d queue points", client, iTarget, iPoints);
		
		return Plugin_Handled;
	}
}



// Reset the player database
Action AdminCommand_ResetDatabase(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(1, confirm, sizeof(confirm));
	
	if (!StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "%t To reset the database, supply the argument 'confirm'", "prefix_reply");
		return Plugin_Handled;
	}
	else if (StrEqual(confirm, "confirm", false))
	{
		ReplyToCommand(client, "%t Resetting the player database...", "prefix_reply");
		DBReset(client);
	}
	
	return Plugin_Handled;
}



// Reset a user (delete them from the database)
Action AdminCommand_ResetUser(int client, int args)
{
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;
	
	char confirm[8];
	GetCmdArg(2, confirm, sizeof(confirm));
	
	if (args != 2 || !StrEqual(confirm, "confirm"))
	{
		ReplyToCommand(client, "%t Usage: sm_resetuser <user> confirm", "prefix_reply");
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
			ReplyToCommand(client, "%t Deleting %N from the database...", "prefix_reply", iTarget);
			Player player = new Player(iTarget);
			player.DeleteRecord(client);
		}
	}
	
	return Plugin_Handled;
}




/**
 * Command Listeners
 * ----------------------------------------------------------------------------------------------------
 */

Action CmdListener_LockBlue(int client, const char[] command, int args)
{
	// Prevent Activators Escaping
	if (game.RoundState == Round_Active && GetClientTeam(client) == Team_Blue && IsPlayerAlive(client) && g_ConVars[P_LockActivator].BoolValue)
	{
		ChatMessage(client, Msg_Reply, "%t", "blue no escape");
		PrintToConsole(client, "%s Command '%s' has been disallowed by the server.", PREFIX_SERVER, command);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}



Action CmdListener_Teams(int client, const char[] command, int args)
{
	char arg1[32], arg2[32];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	if (StrEqual(command, "jointeam", false))
	{
		// Prevent Activators Escaping
		if (game.RoundState == Round_Active && GetClientTeam(client) == Team_Blue && IsPlayerAlive(client) && g_ConVars[P_LockActivator].BoolValue)
		{
			ChatMessage(client, Msg_Reply, "%t", "blue no escape");
			PrintToConsole(client, "%s Command '%s' has been disallowed by the server.", PREFIX_SERVER, command);
			return Plugin_Handled;
		}
		
		// Prevent Players Joining Blue
		if (StrEqual(arg1, "blue", false))
		{
			ChangeClientTeam(client, Team_Red);
			return Plugin_Handled;
		}
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
		Player player = new Player(client);
		char arg1[2], arg2[2];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		int iArg1 = StringToInt(arg1);
		int iArg2 = StringToInt(arg2);
		
		if (iArg1 == 0 && (g_ConVars[P_Buildings].IntValue & BUILDING_DISPENSER) == BUILDING_DISPENSER)
		{
			ChatMessage(client, Msg_Reply, "Sorry, you aren't allowed to build dispensers");
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 0 && (g_ConVars[P_Buildings].IntValue & BUILDING_TELE_ENTRANCE) == BUILDING_TELE_ENTRANCE)
		{
			ChatMessage(client, Msg_Reply, "Sorry, you aren't allowed to build teleporter entrances");
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 1 && (g_ConVars[P_Buildings].IntValue & BUILDING_TELE_EXIT) == BUILDING_TELE_EXIT)
		{
			ChatMessage(client, Msg_Reply, "Sorry, you aren't allowed to build teleporter exits");
			return Plugin_Handled;
		}
		if (iArg1 == 2 && (g_ConVars[P_Buildings].IntValue & BUILDING_SENTRY) == BUILDING_SENTRY)
		{
			ChatMessage(client, Msg_Reply, "Sorry, you aren't allowed to build sentries");
			return Plugin_Handled;
		}
		
		// build 3 is for backwards compatability of the deprecated build argument to build a tele exit
		if (iArg1 == 3 && (g_ConVars[P_Buildings].IntValue & BUILDING_TELE_EXIT) == BUILDING_TELE_EXIT && player.Class == Class_Engineer)
		{
			ChatMessage(client, Msg_Reply, "Sorry, you aren't allowed to build teleporter exits");
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}