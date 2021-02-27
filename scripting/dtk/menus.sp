/**
 * New menu command handler
 */
stock Action Command_Menu(int client, int args)
{
	MenuFunction(client, "menu_main");
 	return Plugin_Handled;
}




/**
* New menu function
*/
stock void MenuFunction(int client, const char[] selection)
{
	Menu menu = new Menu(MenuHandler, MenuAction_DisplayItem);
	char title[256];
	
	Format(title, sizeof(title), "%s %s\n \n", PLUGIN_SHORTNAME, PLUGIN_VERSION);
	
	
	/**
	 * Main
	 */
	if (StrEqual(selection, "menu_main"))
	{
		menu.AddItem("menu_prefs", "menu_item_preferences");
		menu.AddItem("menu_queue", "menu_item_queue");
		menu.AddItem("item_help", "menu_item_help");
		
		if (GetAdminFlags(GetUserAdmin(client), Access_Effective))
		{
			menu.AddItem("menu_admin", "menu_item_admin");
		}
	}
	
	
	/**
	 * Preferences
	 */
	if (StrEqual(selection, "menu_prefs"))
	{
		Format(title, sizeof(title), "%T\n \n", "menu_item_preferences", client);
		
		menu.ExitBackButton = true;
		
		menu.AddItem("prefs_activator", (Player(client).HasFlag(PF_PrefActivator)) ? "menu_item_dont_be_activator" : "menu_item_be_activator");
		menu.AddItem("menu_reset", "menu_item_reset");
		menu.AddItem("prefs_english", "menu item toggle english language");
		
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
	 * Reset Points
	 */
	if (StrEqual(selection, "menu_reset"))
	{
		Format(title, sizeof(title), "%s%T\n \n", title, "menu_reset_question", client);
		menu.AddItem("reset_yes", "menu_item_yes");
		menu.AddItem("reset_no", "menu_item_no");
	}
	
	
	/**
	 * Activator Queue
	 */
	if (StrEqual(selection, "menu_queue"))
	{
		menu.ExitBackButton = true;
		
		int len = game.ActivatorPool;
		int[] list = new int[len];
		CreateActivatorList(list);

		char sItem[40];
		
		for (int i = 0; i < len; i++)
		{
			Player player = Player(list[i]);
			Format(sItem, sizeof(sItem), "%16N", player.Index);
			menu.AddItem("points_item", sItem, ITEMDRAW_DISABLED);
		}
	}
	
	
	/**
	 * Admin
	 */
	if (StrEqual(selection, "menu_admin"))
	{
		menu.ExitBackButton = true;
	
		menu.AddItem("admin_scalehealth", "menu_item_admin_scale_activator_health");
		menu.AddItem("admin_jetpackgame", "menu_item_admin_jetpack_game");
		menu.AddItem("admin_periodicslap", "menu_item_admin_periodic_slap");
	}
	
	menu.SetTitle(title);
	menu.Display(client, MENU_TIME_FOREVER);
}




/**
 * New Menu Handler
 * ----------------------------------------------------------------------------------------------------
 */


public int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char selection[32];
		menu.GetItem(param2, selection, sizeof(selection));
		
		// Menus
		if (StrContains(selection, "menu_") == 0)
		{
			MenuFunction(param1, selection);
		}
		
		// Preferences
		else if (StrContains(selection, "prefs_") == 0)
		{
			if (StrEqual(selection, "prefs_activator"))
			{
				Command_ToggleActivator(param1, 0);
			}
			else if (StrEqual(selection, "prefs_english"))
			{
				ToggleEnglish(param1);
			}
			
			MenuFunction(param1, "menu_prefs");
		}
		
		// Reset
		else if (StrContains(selection, "reset_") == 0)
		{
			if (StrEqual(selection, "reset_yes"))
			{
				Command_ResetPoints(param1, 0);
			}
			
			MenuFunction(param1, "menu_prefs");
		}
		
		// Help
		else if (StrEqual(selection, "item_help"))
		{
			Command_Help(param1, 0);
		}
		
		// Admin
		else if (StrContains(selection, "admin_") == 0)
		{
			if (StrEqual(selection, "admin_scalehealth"))
			{
				FunStuff_ScaleHealth(param1);
			}
			else if (StrEqual(selection, "admin_jetpackgame"))
			{
				FunStuff_JetpackGame();
			}
			else if (StrEqual(selection, "admin_periodicslap"))
			{
				FunStuff_PeriodicSlap();
			}
			
			MenuFunction(param1, "menu_admin");
		}
		
		else MenuFunction(param1, "menu_main");
	}
	
	else if (param2 == MenuCancel_ExitBack)
	{
		MenuFunction(param1, "menu_main");
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
