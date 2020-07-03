/**
 * New menu command handler
 */
stock Action Command_NewMenu(int client, int args)
{
	NewMenuFunction(client, "menu_main");
 	return Plugin_Handled;
}




/**
* New menu function
*/
stock void NewMenuFunction(int client, const char[] sMenu)
{
	Player player = new Player(client);
	Menu menu = new Menu(NewMenuHandler, MenuAction_DisplayItem);
	char title[256];
	
	Format(title, sizeof(title), "%s %s\n \n", PLUGIN_SHORTNAME, PLUGIN_VERSION);
	
	/**
	 * Show the main menu
	 */
	if (StrEqual(sMenu, "menu_main"))
	{
		if ((player.Flags & FLAGS_PREFERENCE))
	 	{
	 		Format(title, sizeof(title), "%s%T\n \n", title, "menu queue points", player.Index, player.Points);
	 	}
		
		menu.AddItem("menu_prefs", "menu item preferences");
		menu.AddItem("menu_reset", "menu item reset");
		menu.AddItem("menu_points", "menu item points");
		menu.AddItem("menu_commands", "menu item commands");
		
		if (GetAdminFlags(GetUserAdmin(client), Access_Effective))
		//if (CheckAccess(GetUserAdmin(client), "", ADMFLAG_KICK, true))
		{
			menu.AddItem("menu_admincommands", "menu item admin commands");
		}
		
	}
	
	/**
	 * Show the preferences menu
	 */
	if (StrEqual(sMenu, "menu_prefs"))
	{
		if ((player.Flags & FLAGS_PREFERENCE) && (player.Flags & FLAGS_FULLPOINTS))
			// if player.Flags has FLAGS_PREFERENCE set, FLAGS_FULLPOINTS
	 	{
	 		Format(title, sizeof(title), "%s%T\n \n", title, "menu full queue points", player.Index, player.Points);
	 	}
 		else if ((player.Flags & FLAGS_PREFERENCE) && !(player.Flags & FLAGS_FULLPOINTS))
 			// if player.Flags has FLAGS_PREFERENCE set, and *not* FLAGS_FULLPOINTS set
	 	{
	 		Format(title, sizeof(title), "%s%T\n \n", title, "menu fewer queue points", player.Index, player.Points);
	 	}
		else
	 	{
	 		Format(title, sizeof(title), "%s%T\n \n", title, "menu not the activator", player.Index);
	 	}
		
		menu.AddItem("prefs_full", "menu item full queue points");
		menu.AddItem("prefs_fewer", "menu item fewer queue points");
		menu.AddItem("prefs_none", "menu item do not be activator");
		menu.AddItem("", "", ITEMDRAW_SPACER);
		menu.AddItem("prefs_english", "menu item toggle english language");
		menu.AddItem("", "", ITEMDRAW_SPACER);
		menu.AddItem("menu_main", "menu item back");
	
		/**
		 * AddItem Styles
		 * 
		 * ITEMDRAW_CONTROL and ITEMDRAW_DEFAULT presented a normal numbered menu option.
		 * ITEMDRAW_DISABLED presented a numbered option that cannot be selected.
		 * ITEMDRAW_IGNORE did not add the item.
		 * ITEMDRAW_NOTEXT did not add an item, but consumed the number.
		 * ITEMDRAW_RAWLINE did not add an item. I believe this cannot be done using the Menu helper, only panels.
		 * ITEMDRAW_SPACER created a completely blank line. It consumed the position number.
		 */
	}
	
	/**
	 * Show the reset points menu
	 */
	if (StrEqual(sMenu, "menu_reset"))
	{
		Format(title, sizeof(title), "%s%T\n \n", title, "menu reset question", player.Index);
		menu.AddItem("reset_yes", "menu item yes");
		menu.AddItem("reset_no", "menu item no");
	}
	
	/**
	 * Show the list points menu
	 */
	if (StrEqual(sMenu, "menu_points"))
	{
		menu.ExitBackButton = true;
		
		int points_order[TF2MAXPLAYERS-1][2];
		// 0 will be client index. 1 will be points.
		
		for (int i = 0; i < MaxClients; i++)
		{
			Player iPlayer = new Player(i + 1);
			points_order[i][0] = iPlayer.Index;
			points_order[i][1] = iPlayer.Points;
		}
		
		SortCustom2D(points_order, MaxClients, SortByPoints);
		
		char sItem[40];
		
		for (int i = 0; i < MaxClients; i++)
		{
			Player iPlayer = new Player(points_order[i][0]);
			if (iPlayer.InGame && (iPlayer.Flags & FLAGS_PREFERENCE))
			// If the player has FLAGS_PREFERENCE set to 1
			{
				Format(sItem, sizeof(sItem), "%N: %d", iPlayer.Index, iPlayer.Points);
				menu.AddItem("points_item", sItem, ITEMDRAW_DISABLED);
			}
		}
	}
	
	/**
	 * Show the commands menu
	 */
	if (StrEqual(sMenu, "menu_commands"))
	{
		menu.AddItem("commands_points", "menu item command points");
		menu.AddItem("commands_reset", "menu item command reset");
		menu.AddItem("commands_prefs", "menu item command prefs");
		menu.AddItem("menu_main", "menu item back");
	
		/**
		 * AddItem Styles
		 * 
		 * ITEMDRAW_CONTROL and ITEMDRAW_DEFAULT presented a normal numbered menu option.
		 * ITEMDRAW_DISABLED presented a numbered option that cannot be selected.
		 * ITEMDRAW_IGNORE did not add the item.
		 * ITEMDRAW_NOTEXT did not add an item, but consumed the number.
		 * ITEMDRAW_RAWLINE did not add an item. I believe this cannot be done using the Menu helper, only panels.
		 * ITEMDRAW_SPACER created a completely blank line. It consumed the position number.
		 */
	}
	
	/**
	 * Show the admin commands menu
	 */
	if (StrEqual(sMenu, "menu_admincommands"))
	{
		menu.AddItem("admincommands_award", "menu item admin command award");
		menu.AddItem("admincommands_setclass", "menu item admin command setclass");
		menu.AddItem("admincommands_data", "menu item admin command drdata");
		menu.AddItem("admincommands_scalehealth", "menu item admin command drscalehealth");		
		menu.AddItem("menu_main", "menu item back");
	}
	
	menu.SetTitle(title);
	menu.Display(client, MENU_TIME_FOREVER);
}




/**
 * New Menu Handler
 * ----------------------------------------------------------------------------------------------------
 */


public int NewMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char selection[32];
		menu.GetItem(param2, selection, sizeof(selection));
		
		if (StrContains(selection, "menu_") == 0)
		{
			NewMenuFunction(param1, selection);
		}
		
		else if (StrContains(selection, "prefs_") == 0)
		{
			if (StrEqual(selection, "prefs_full"))
			{
				AdjustPreference(param1, 2);
			}
			if (StrEqual(selection, "prefs_fewer"))
			{
				AdjustPreference(param1, 1);
			}
			if (StrEqual(selection, "prefs_none"))
			{
				AdjustPreference(param1, 0);
			}
			if (StrEqual(selection, "prefs_english"))
			{
				Command_English(param1);
			}
		}
		
		else if (StrContains(selection, "commands_") == 0)
		{
			if (StrEqual(selection, "commands_points"))
			{
				Command_ShowPoints(param1, 0);
			}
			if (StrEqual(selection, "commands_reset"))
			{
				Command_ResetPoints(param1, 0);
			}
			if (StrEqual(selection, "commands_prefs"))
			{
				Command_Preferences(param1, 0);
			}
		}
		
		else if (StrContains(selection, "admincommands_") == 0)
		{
			if (StrEqual(selection, "admincommands_award"))
			{
				AdminCommand_AwardPoints(param1, 0);
			}
			if (StrEqual(selection, "admincommands_setclass"))
			{
				AdminCommand_SetClass(param1, 0);
			}
			if (StrEqual(selection, "admincommands_data"))
			{
				AdminCommand_PlayerData(param1, 0);
			}
			if (StrEqual(selection, "admincommands_scalehealth"))
			{
				AdminCommand_ScaleHealth(param1, 0);
			}
		}
		
		else if (StrEqual(selection, "reset_yes"))
		{
			Command_ResetPoints(param1, 0);			
		}
		
		else NewMenuFunction(param1, "menu_main");
	}
	
	else if (param2 == MenuCancel_ExitBack)
	{
		NewMenuFunction(param1, "menu_main");
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	else if (action == MenuAction_DisplayItem)
    {
		char display[64];
		char selection[32];
		menu.GetItem(param2, selection, sizeof(selection), _, display, sizeof(display));

		if (display[0] != '\0' && !StrEqual(selection, "points_item"))
		{
			char buffer[256];
			Format(buffer, sizeof(buffer), "%T", display, param1);
			
			return RedrawMenuItem(buffer);
		}
    }
	
	return 0;
}










/**
 * Old Menus
 * ----------------------------------------------------------------------------------------------------
 */
/*
// Open the menu
public Action Command_Menu(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Player player = new Player(client);
	char sTitle[64];
	Format(sTitle, sizeof(sTitle), "%s %s\n \nYou have %d points\n ", PLUGIN_SHORTNAME, PLUGIN_VERSION, player.Points);

	Menu menu = new Menu(MenuHandlerMain);
	menu.SetTitle(sTitle);
	menu.AddItem("item1", "Activator Preferences");
	menu.AddItem("item2", "List Points");
	menu.AddItem("item3", "Reset My Points");
	menu.Display(player.Index, MENU_TIME_FOREVER);

	return Plugin_Handled;
}


// Open the activator preference menu
public Action Command_MenuPreference(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Menu menu = new Menu(MenuHandlerPreference);
	menu.SetTitle("Activator Preference\n ");
	menu.AddItem("item1", "Full queue points");
	menu.AddItem("item2", "Fewer queue points");
	menu.AddItem("item3", "Don't be the activator");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

// Open the player points menu
public Action Command_MenuPoints(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Menu menu = new Menu(MenuHandlerPoints);
	menu.SetTitle("List Points\n ");
	menu.ExitBackButton = true;

	int points_order[TF2MAXPLAYERS-1][2];
		// 0 will be client index. 1 will be points.
		
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(i + 1);
		points_order[i][0] = player.Index;
		points_order[i][1] = player.Points;
	}
	
	SortCustom2D(points_order, MaxClients, SortByPoints);
	
	char sItem[40];
	
	for (int i = 0; i < MaxClients; i++)
	{
		Player player = new Player(points_order[i][0]);
		if (player.InGame && (player.Flags & FLAGS_PREFERENCE))
		// If the player has FLAGS_PREFERENCE set to 1
		{
			Format(sItem, sizeof(sItem), "%N: %d", player.Index, player.Points);
			menu.AddItem("item", sItem, ITEMDRAW_DISABLED);
		}
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

// Open the points reset menu
public Action Command_MenuPointsReset(int client, int args)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Handled;

	Player player = new Player(client);
	char sTitle[100];
	Format(sTitle, sizeof(sTitle), "Reset My Points\n \nYou have %d points\n \nAre you sure you want\nto reset your points?\n ", player.Points);

	Menu menu = new Menu(MenuHandlerPointsReset);
	menu.SetTitle(sTitle);
	menu.AddItem("item1", "Yes");
	menu.AddItem("item2", "No");
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}
*/



/**
 * Menu Handlers
 * ----------------------------------------------------------------------------------------------------
 */

/*
// The menu handler
public int MenuHandlerMain(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		// param1 = client, param2 = item position
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				Command_MenuPreference(param1, param2);
			if (StrEqual(info, "item2"))
				Command_MenuPoints(param1, param2);
			if (StrEqual(info, "item3"))
				Command_MenuPointsReset(param1, param2);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

// Activator preference menu handler
public int MenuHandlerPreference(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				AdjustPreference(param1, 2);
			if (StrEqual(info, "item2"))
				AdjustPreference(param1, 1);
			if (StrEqual(info, "item3"))
				AdjustPreference(param1, 0);
				
			Command_Menu(param1, param2);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}

// Queue points menu handler
public int MenuHandlerPoints(Menu menu, MenuAction action, int param1, int param2) // Must always be public
{
	switch (action)
	{
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}

// Points reset menu handler
public int MenuHandlerPointsReset(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "item1"))
				Command_ResetPoints(param1, 0);
				
			Command_Menu(param1, param2);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				Command_Menu(param1, param2);
		}
		case MenuAction_End:
			delete menu;
	}
}*/