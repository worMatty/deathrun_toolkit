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
		if ((player.Flags & PREF_ACTIVATOR))
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
			menu.AddItem("menu_adminfunstuff", "menu item admin fun stuff");
		}
		
	}
	
	
	/**
	 * Show the preferences menu
	 */
	if (StrEqual(sMenu, "menu_prefs"))
	{
		if ((player.Flags & PREF_ACTIVATOR) && (player.Flags & PREF_FULL_QP))
			// if player.Flags has PREF_ACTIVATOR set, PREF_FULL_QP
	 	{
	 		Format(title, sizeof(title), "%s%T\n \n", title, "menu full queue points", player.Index, player.Points);
	 	}
 		else if ((player.Flags & PREF_ACTIVATOR) && !(player.Flags & PREF_FULL_QP))
 			// if player.Flags has PREF_ACTIVATOR set, and *not* PREF_FULL_QP set
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
		
		int points_order[MAXPLAYERS_TF2-1][2];
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
			if (iPlayer.InGame && (iPlayer.Flags & PREF_ACTIVATOR))
			// If the player has PREF_ACTIVATOR set to 1
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
		//menu.AddItem("admincommands_scalehealth", "menu item admin command drscalehealth");		
		menu.AddItem("menu_main", "menu item back");
	}
	
	
	/**
	 * Show the admin fun stuff
	 */
	if (StrEqual(sMenu, "menu_adminfunstuff"))
	{
		menu.AddItem("adminfunstuff_scalehealth", "menu item admin fun stuff scale activator health");
		menu.AddItem("adminfunstuff_jetpackgame", "menu item admin fun stuff jetpack game");
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
		}
		
		else if (StrContains(selection, "adminfunstuff_") == 0)
		{
			if (StrEqual(selection, "adminfunstuff_scalehealth"))
			{
				FunStuff_ScaleHealth();
			}
			if (StrEqual(selection, "adminfunstuff_jetpackgame"))
			{
				FunStuff_JetpackGame();
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
