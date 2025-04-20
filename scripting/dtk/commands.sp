

// Engineer Buildings
enum {
	Build_Sentry	= 0x1,
	Build_Dispenser = 0x2,
	Build_TeleEnt	= 0x4,
	Build_TeleEx	= 0x8,
}

void
	Commands_Init() {
	// Console Commands
	RegConsoleCmd("sm_dr", Command_Menu, "Open the deathrun menu");
	RegConsoleCmd("sm_drmenu", Command_Menu, "Open the deathrun menu");
	RegConsoleCmd("sm_drtoggle", Command_ToggleActivator, "Toggle activator preference");
	RegConsoleCmd("sm_na", Command_NextActivators, "Show the next activator(s) in chat");
	RegConsoleCmd("sm_drnext", Command_NextActivators, "Show the next activator(s) in chat");
	RegConsoleCmd("next", Command_NextActivators, "Show the next activator(s) in chat");
	RegConsoleCmd("sm_drhelp", Command_Help, "Open the help page");

	// Server Commands
	RegServerCmd("dtk_remove_database_table", ServerCommand_RemoveDBTable, "Drop (delete) the DTK table from your SQLite database");

	// Admin Commands
	RegAdminCmd("sm_setclass", AdminCommand_SetClass, ADMFLAG_SLAY, "Immediately change a player's class");
	RegAdminCmd("sm_regenall", AdminCommand_RegenAll, ADMFLAG_SLAY, "Regenerate all live players");
	RegAdminCmd("sm_printitems", AdminCommand_PrintItems, ADMFLAG_SLAY, "Print all your weapons/items to console for the purpose of identifying classnames and item definition indexes for working with the restriction system");
	RegAdminCmd("dtk_remove_database_record", AdminCommand_RemoveDBRecord, ADMFLAG_CONVARS | ADMFLAG_CONFIG | ADMFLAG_RCON, "Deletes a Steam ID from the DTK database table. Next time they join, a new record will be created for them");
	RegAdminCmd("dtk_reload_configs", AdminCommand_ReloadConfigs, ADMFLAG_CONVARS | ADMFLAG_CONFIG | ADMFLAG_RCON, "Reload DTK config files");
	RegAdminCmd("dtk_addban", AdminCommand_AddActivatorBan, ADMFLAG_SLAY, "Ban a Steam ID from becoming an activator. Ban is ignored on low players");
	RegAdminCmd("dtk_removeban", AdminCommand_RemActivatorBan, ADMFLAG_SLAY, "Remove an activator ban from a Steam ID");
	RegAdminCmd("dtk_isbanned", AdminCommand_IsActivatorBanned, ADMFLAG_SLAY, "Check if a Steam ID is banned from being an activator");

	// Debug Commands
	RegAdminCmd("dtk_data", AdminCommand_PlayerData, ADMFLAG_SLAY, "Print internal data about client flags to your console, for debugging");
}

/**
 * Console commands
 * --------------------------------------------------------------------------------
 */

/**
 * sm_drtoggle
 *
 * Toggle activator preference
 */
Action Command_ToggleActivator(int client, int args) {
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;

	DRPlayer player = DRPlayer(client);

	if (player.PrefersActivator) {
		player.PrefersActivator = false;
		TF2_PrintToChat(client, _, "%t", "opted_out_activator");
		EmitMessageSoundToClient(client);
	} else {
		player.PrefersActivator = true;
		TF2_PrintToChat(client, _, "%t", "opted_in_activator");
		EmitMessageSoundToClient(client);
	}

	return Plugin_Handled;
}

/**
 * sm_na, sm_drnext, next
 *
 * Show the next activator(s).
 * Set the next activator.
 */
Action Command_NextActivators(int client, int args) {
	if (!g_ConVars[P_Enabled].BoolValue)
		return Plugin_Handled;

	if (args == 0) {
		char buffer[MAX_CHAT_MESSAGE];
		int	 numact = GetNumActivatorsRequired();

		if (FormatNextActivators(buffer, (numact > 1) ? numact : 3)) {
			TF2_PrintToChat(client, _, buffer);
			EmitMessageSoundToClient(client);
		}
	} else if (args == 1 && DRPlayer(client).IsAdmin) {
		bool tn_is_ml;
		char pattern[64], target_name[64];
		int	 result, max_targets, tn_maxlength;
		int[] targets = new int[MaxClients];

		GetCmdArg(1, pattern, sizeof(pattern));

		result = ProcessTargetString(pattern, client, targets, max_targets, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_MULTI, target_name, tn_maxlength, tn_is_ml);

		if (result == 1) {
			int target = targets[0];
			DRPlayer(target).MakeNextActivator();
			TF2_ReplyToCommand(client, target, "\x02%N will be the next activator", target);
		} else if (tn_is_ml) {
			ReplyToCommand(client, "Can't use this command with a multi-target specifier");
		} else if (result < 1) {
			ReplyToTargetError(client, result);
		}
	} else {
		ReplyToCommand(client, "\x01Usage: \x04/na\x01 or \x04/na *name*\x01 (admin)");
		return Plugin_Handled;
	}

	return Plugin_Handled;
}

/**
 * sm_drhelp
 */
Action Command_Help(int client, int args) {
	TF2_PrintToChat(client, _, "Opening the help page. You need HTML MOTD enabled");
	TF2_PrintToChat(client, _, "%s", HELP_URL);

	KeyValues kv = CreateKeyValues("data");
	kv.SetString("msg", HELP_URL);
	kv.SetNum("customsvr", 1);
	kv.SetNum("type", MOTDPANEL_TYPE_URL);	  // MOTDPANEL_TYPE_URL displays a web page. MOTDPANEL_TYPE_TEXT displays text. MOTDPANEL_TYPE_FILE shows a blank MOTD panel. MOTDPANEL_TYPE_INDEX shows a blank panel with title.
	ShowVGUIPanel(client, "info", kv, true);
	kv.Close();

	return Plugin_Handled;
}

/**
 * Server commands
 * --------------------------------------------------------------------------------
 */

/**
 * dtk_remove_database_table
 *
 * Remove the DTK table from the SQL database
 */
Action ServerCommand_RemoveDBTable(int args) {
	char confirm[8];
	GetCmdArg(1, confirm, sizeof(confirm));

	if (StrEqual(confirm, "confirm", false)) {
		PrintToServer("Deleting the table from your database");

		if (DBDeleteTable()) {
			PrintToServer("Reset player database. Changing the map will reinitialise it");
			LogMessage("Server console deleted table %s from the database %s", SQLITE_TABLE, SQLITE_DATABASE);
		} else {
			PrintToServer("Failed to reset database. See the SourceMod logs for the SQL error");
		}
	} else {
		PrintToServer("To reset the database, supply the argument 'confirm'");
	}

	return Plugin_Handled;
}

/**
 * Admin commands
 * --------------------------------------------------------------------------------
 */

/**
 * sm_setclass
 *
 * Set the class of a player or players
 */
Action AdminCommand_SetClass(int client, int args) {
	if (args < 1 || args > 2) {
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
	if (class == 0) {
		class = GetRandomInt(1, 9);
	}

	char sClass[20];
	Format(sClass, sizeof(sClass), "%s", tfclassnames[class]);

	int	 iTarget[MAXPLAYERS];
	int	 iTargetCount;
	bool bIsMultiple;	 // Not used
	char sTargetName[MAX_NAME_LENGTH];

	iTargetCount = ProcessTargetString(arg1, client, iTarget, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsMultiple);

	if (iTargetCount <= 0) {
		ReplyToTargetError(client, iTargetCount);
	} else {
		for (int i = 0; i < iTargetCount; i++) {
			int target = iTarget[i];
			// float pos[3];
			// float angles[3];

			// GetClientAbsOrigin(target, pos);
			// GetClientAbsAngles(target, angles);

			DRPlayer(target).SetClass(class);
			// TF2_RespawnPlayer(target);
			// TeleportEntity(target, client_pos, client_angles, NULL_VECTOR);

			ApplyPlayerAttributes(target);

			if (client == target) {
				TF2_PrintToChat(target, _, "You are now a %s", sClass);
				EmitMessageSoundToClient(target);
			} else {
				TF2_PrintToChat(target, client, "\x02%N has made you a %s", client, sClass);
				EmitMessageSoundToClient(target);
			}

			LogAction(client, target, "%L changed class of %L to %s", client, target, sClass);
		}

		ShowActivity(client, "Changed %d %s to %s", iTargetCount, (iTargetCount > 1) ? "players" : "player", sClass);
	}

	return Plugin_Handled;
}

/**
 * Regenerate all live players
 * Useful for testing changes to the restriction config after reloading it
 */
Action AdminCommand_RegenAll(int client, int args) {
	int maxplayers = MaxClients;
	int count;

	for (int player = 1; player <= maxplayers; player++) {
		if (IsClientInGame(player) && IsPlayerAlive(player)) {
			TF2_RegeneratePlayer(player);
			count++;
		}
	}

	ShowActivity(client, "Regenerated %d players", count);
	LogAction(client, -1, "%L regenerated %d players", client, count);
	return Plugin_Handled;
}

/**
 * Print your weapons/items to console to identify classnames and item definition
 * indexes for working with the restriction system
 */
Action AdminCommand_PrintItems(int client, int args) {
	if (client == 0) {
		ReplyToCommand(client, "You can't use this command from the console because you aren't a player so you have no items");
		return Plugin_Handled;
	}

	char classname[64];
	char netclass[64];
	int	 weaponcount, idef;

	// check weapon slots
	for (int slot; slot < 7; slot++) {	  // highest weapon slot used
		int item = GetPlayerWeaponSlot(client, slot);
		if (item != -1) {
			weaponcount++;
			GetEntityClassname(item, classname, sizeof(classname));
			GetEntityNetClass(item, netclass, sizeof(netclass));
			idef = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
			PrintToConsole(client, "Weapon in slot %d: Classname & netclass: %s, %s; IDI: %d; Entindex: %d", slot, classname, netclass, idef, item);
		} else {
			PrintToConsole(client, "No weapon found in slot %d", slot);
		}
	}
	ReplyToCommand(client, "Printed %d weapons in weapon slots to console", weaponcount);

	// check wearables
	ArrayList wearables = GetWearables(client);
	for (int i; i < wearables.Length; i++) {
		int item = wearables.Get(i);
		GetEntityClassname(item, classname, sizeof(classname));
		GetEntityNetClass(item, netclass, sizeof(netclass));
		idef = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
		PrintToConsole(client, "Wearable #%d: Classname & netclass: %s, %s; IDI: %d; Entindex: %d", i, classname, netclass, idef, item);
	}
	ReplyToCommand(client, "Printed %d wearables to console", wearables.Length);

	return Plugin_Handled;
}

/**
 * dtk_remove_database_record
 *
 * Remove a player record from the database
 */
Action AdminCommand_RemoveDBRecord(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "Usage: dtk_remove_database_record <steamid>");
		return Plugin_Handled;
	}

	char arg_string[32], authid[32];
	GetCmdArgString(arg_string, sizeof(arg_string));
	BreakString(arg_string, authid, sizeof(authid));

	int steam_account = GetSteamAccountIdFromSteamId(authid);

	if (steam_account == 0) {
		ReplyToCommand(client, "%t: %s", "Invalid SteamID specified", authid);
		return Plugin_Handled;
	}

	bool deleted = DBDeleteRecord(steam_account);

	if (deleted) {
		ShowActivity(client, "Deleted Steam account Id %d from the database. A new one will not be created until they rejoin", steam_account);
		LogMessage("%L deleted Steam account Id %d from the database", client, steam_account);
	} else {
		ReplyToCommand(client, "Failed to delete Steam account Id %d from the database", steam_account);
	}

	return Plugin_Handled;
}

/**
 * dtk_reload_configs
 *
 * Reload the item restriction config files
 */
Action AdminCommand_ReloadConfigs(int client, int args) {
	ReplyToCommand(client, "Reloading the config files");

	LoadConfigs();

	return Plugin_Handled;
}

/**
 * dtk_addban
 *
 * Add an activator ban to the database
 */
Action AdminCommand_AddActivatorBan(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "Usage: dtk_addban <steamid>");
		return Plugin_Handled;
	}

	char arg_string[32], authid[32];
	GetCmdArgString(arg_string, sizeof(arg_string));
	BreakString(arg_string, authid, sizeof(authid));

	int steam_account = GetSteamAccountIdFromSteamId(authid);

	if (steam_account == 0) {
		ReplyToCommand(client, "%t: %s", "Invalid SteamID specified", authid);
		return Plugin_Handled;
	}

	bool banned = ActivatorBan(steam_account);

	if (banned) {
		LogAction(client, -1, "%L activator banned Steam ID %s", client, authid);
		ReplyToCommand(client, "%t: %s", "Ban added", authid);
	} else {
		ReplyToCommand(client, "%t", "Failed to query database");
	}

	return Plugin_Handled;
}

/**
 * dtk_removeban
 *
 * Remove an activator ban from the database
 */
Action AdminCommand_RemActivatorBan(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "Usage: dtk_removeban <steamid>");
		return Plugin_Handled;
	}

	char arg_string[32], authid[32];

	GetCmdArgString(arg_string, sizeof(arg_string));
	BreakString(arg_string, authid, sizeof(authid));

	int steam_account = GetSteamAccountIdFromSteamId(authid);

	if (steam_account == 0) {
		ReplyToCommand(client, "%t: %s", "Invalid SteamID specified", authid);
		return Plugin_Handled;
	}

	bool unbanned = RemoveActivatorBan(steam_account);

	if (unbanned) {
		LogAction(client, -1, "%L removed activator ban for Steam ID %s", client, authid);
		ReplyToCommand(client, "%t", "Removed bans matching", authid);
	} else {
		ReplyToCommand(client, "%t", "Failed to query database");
	}

	return Plugin_Handled;
}

/**
 * dtk_isbanned
 *
 * Check if a player is activator banned
 */
Action AdminCommand_IsActivatorBanned(int client, int args) {
	if (args < 1) {
		ReplyToCommand(client, "Usage: dtk_isbanned <steamid>");
		return Plugin_Handled;
	}

	char arg_string[32], authid[32];
	GetCmdArgString(arg_string, sizeof(arg_string));
	BreakString(arg_string, authid, sizeof(authid));

	int steam_account = GetSteamAccountIdFromSteamId(authid);

	if (steam_account == 0) {
		ReplyToCommand(client, "%t: %s", "Invalid SteamID specified", authid);
		return Plugin_Handled;
	}

	bool banned = IsActivatorBanned(steam_account);

	if (banned) {
		ReplyToCommand(client, "Player with Steam ID %s is currently activator-banned", authid);
	} else {
		ReplyToCommand(client, "Player with Steam ID %s is not activator-banned", authid);
	}

	return Plugin_Handled;
}

/**
 * Debug commands
 * --------------------------------------------------------------------------------
 */

/**
 * dtk_data
 */
Action AdminCommand_PlayerData(int client, int args) {
	PrintToConsole(client, "\nPlayer points and preference flags\n  Please note: The table will show values for unoccupied slots. These are from\n  previous players and are reset when someone new takes the slot.\n");

	for (int i = 1; i <= MaxClients; i++) {
		char	 name[25] = "----", flags[128];
		DRPlayer player	  = DRPlayer(i);

		if (player.InGame) {
			Format(name, sizeof(name), "%N", player.Index);
		}

		if (player.Activator) {
			Format(flags, sizeof(flags), " ACTIVATOR");
		}
		if (player.Runner) {
			Format(flags, sizeof(flags), "%s | RUNNER", flags);
		}
		if (player.PrefersActivator) {
			Format(flags, sizeof(flags), "%s | OPTED-IN", flags);
		}
		if (player.ReceivesMoreQP) {
			Format(flags, sizeof(flags), "%s | POINTS+", flags);
		}
		if (player.Welcomed) {
			Format(flags, sizeof(flags), "%s | WELCOMED", flags);
		}
		if (player.PrefersEnglish) {
			Format(flags, sizeof(flags), "%s | ENGLISH", flags);
		}
		if (player.ActivatorBanned) {
			Format(flags, sizeof(flags), "%s | BANNED", flags);
		}

		PrintToConsole(client, " %2d. %24s (#%d - %d) Points: %d ActLast: %d \
			Flags:%s",
					   i, name, player.ArrayUserID, (player.InGame) ? player.SteamAccountId : 0, player.Points, player.ActivatorLast, flags);
	}

	PrintToConsole(client, "\n Game State Flags: %06b", g_GameState);
	if (client) {
		TF2_PrintToChat(client, _, "Check console for output");
		EmitMessageSoundToClient(client);
	}

	return Plugin_Handled;
}

/**
 * Command Listeners
 * ----------------------------------------------------------------------------------------------------
 */

// kill, explode, spectate
/**
 * Prevent the deathrun activator from committing suicide or trying to spectate
 * @param	client		Client index
 * @param	command		Command used
 * @param	args		Command args
 */
Action CmdListener_LockBlue(int client, const char[] command, int args) {
	DRPlayer player = DRPlayer(client);

	if (IsDeathrunRoundActive() && player.Team == Team_Blue && player.IsAlive && player.Activator && g_ConVars[P_LockActivator].BoolValue) {
		TF2_PrintToChat(client, _, "%t", "activator_no_escape");
		EmitMessageSoundToClient(client);
		PrintToConsole(client, "Command '%s' has been disallowed by the server", command);
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// jointeam, autoteam
/**
 * Prevent deathrun activators from switching teams during an active round, and during pre-round time if set
 * Prevent any player from using the `autoteam` command manually
 * @param	client		Client index
 * @param	command		Command used
 * @param	args		Command args
 */
Action CmdListener_Teams(int client, const char[] command, int args) {
	char arg1[32], arg2[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));

	if (StrEqual(command, "jointeam", false)) {
		DRPlayer player = DRPlayer(client);

		// prevent activators from switching away from blue
		if (player.Team == Team_Blue && player.Activator) {
			if ((IsDeathrunRoundActive() && g_ConVars[P_LockActivator].BoolValue)
				|| (GameRules_GetRoundState() == RoundState_Preround && g_ConVars[P_LockActivator].IntValue == 2)) {
				TF2_PrintToChat(client, _, "%t", "activator_no_escape");
				EmitMessageSoundToClient(client);
				return Plugin_Handled;
			}
		}

		// prevent anyone joining blue directly or randomly
		if (StrEqual(arg1, "blue", false) || StrEqual(arg1, "auto", false)) {
			if (player.Team == Team_Red) {
				return Plugin_Handled;
			} else {
				// player.SetTeam(Team_Red);	 // doesn't seem to work. probably too quick
				RequestFrame(RF_MoveToRed, player.Index);	 // this works but if player was randomly put on blue, they see blue character models in class selection menu
				return Plugin_Continue;
			}
		}
	}

	// block "autoteam" because it bypasses team balancing
	// this command must be entered directly in console
	else if (StrEqual(command, "autoteam", false)) {
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

Action CmdListener_Builds(int client, const char[] command, int args) {
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

	if (g_ConVars[P_Buildings].IntValue != 0) {
		char arg1[2], arg2[2];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		int iArg1 = StringToInt(arg1);
		int iArg2 = StringToInt(arg2);

		if (iArg1 == 0 && (g_ConVars[P_Buildings].IntValue & Build_Dispenser) == Build_Dispenser) {
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build dispensers");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 0 && (g_ConVars[P_Buildings].IntValue & Build_TeleEnt) == Build_TeleEnt) {
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter entrances");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 1 && iArg2 == 1 && (g_ConVars[P_Buildings].IntValue & Build_TeleEx) == Build_TeleEx) {
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter exits");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
		if (iArg1 == 2 && (g_ConVars[P_Buildings].IntValue & Build_Sentry) == Build_Sentry) {
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build sentries");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}

		// build 3 is for backwards compatability of the deprecated build argument to build a tele exit
		if (iArg1 == 3 && (g_ConVars[P_Buildings].IntValue & Build_TeleEx) == Build_TeleEx && DRPlayer(client).Class == Class_Engineer) {
			TF2_PrintToChat(client, _, "Sorry, you aren't allowed to build teleporter exits");
			EmitMessageSoundToClient(client);
			return Plugin_Handled;
		}
	}

	return Plugin_Continue;
}