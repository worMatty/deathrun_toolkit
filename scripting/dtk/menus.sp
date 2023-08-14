#pragma semicolon 1


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
	 * Main Menu
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
	 * Preferences Menu
	 */
	if (StrEqual(selection, "menu_prefs"))
	{
		Format(title, sizeof(title), "%T\n \n", "menu_item_preferences", client);
		
		menu.ExitBackButton = true;
		
		menu.AddItem("prefs_activator", (DRPlayer(client).PrefersActivator) ? "menu_item_dont_be_activator" : "menu_item_be_activator");
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
	 * Activator Queue Menu
	 */
	if (StrEqual(selection, "menu_queue"))
	{
		menu.ExitBackButton = true;
		PlayerList activators = CreateActivatorPool();
		char sItem[40];
		
		for (int i = 0; i < activators.Length; i++)
		{
			DRPlayer player = DRPlayer(activators.Get(i));
			Format(sItem, sizeof(sItem), "%16N", player.Index);
			menu.AddItem("raw_points", sItem, ITEMDRAW_DISABLED);
		}
	}
	
	
	/**
	 * Admin Menu
	 */
	if (StrEqual(selection, "menu_admin"))
	{
		menu.ExitBackButton = true;
	
		menu.AddItem("menu_admin_more_qp", "menu_item_admin_bonus_points");
		menu.AddItem("menu_admin_activator_ban", "menu_item_admin_activator_ban");
		menu.AddItem("admin_scalehealth", "menu_item_admin_scale_activator_health");
		menu.AddItem("admin_jetpackgame", "menu_item_admin_jetpack_game");
		menu.AddItem("admin_periodicslap", "menu_item_admin_periodic_slap");
	}
	
	
	/**
	 * More Queue Points Menu
	 */
	if (StrEqual(selection, "menu_admin_more_qp"))
	{
		menu.ExitBackButton = true;
		char sItem[64], display[64];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			DRPlayer player = DRPlayer(i);
			
			if (player.InGame)
			{
				bool bonus_points = player.ReceivesMoreQP;
				Format(sItem, sizeof(sItem), "raw_more_qp %d %s", player.UserID, bonus_points ? "off" : "on");
				Format(display, sizeof(display), "%N - %t", player.Index, bonus_points ? "Yes" : "No");
				menu.AddItem(sItem, display);
			}
		}
	}
	
	
	/**
	 * Activator Ban Menu
	 */
	if (StrEqual(selection, "menu_admin_activator_ban"))
	{
		menu.ExitBackButton = true;
		char sItem[64], display[64];
		
		for (int i = 1; i <= MaxClients; i++)
		{
			DRPlayer player = DRPlayer(i);
			
			if (player.InGame)
			{
				bool activator_banned = player.ActivatorBanned;
				Format(sItem, sizeof(sItem), "raw_activator_ban %d %s", player.UserID, activator_banned ? "off" : "on");
				Format(display, sizeof(display), "%N - %t", player.Index, activator_banned ? "Yes" : "No");
				menu.AddItem(sItem, display);
			}
		}
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
		char selection[64];
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
		
		// Receives bonus queue points
		else if (StrContains(selection, "raw_more_qp") == 0)
		{
			char item[32], arg1[32], arg2[4];
			
			int len = BreakString(selection, item, sizeof(item));
			len += BreakString(selection[len], arg1, sizeof(arg1));
			BreakString(selection[len], arg2, sizeof(arg2));
			
			int userid = StringToInt(arg1);
			int client = GetClientOfUserId(userid);
			
			if (client == 0)
			{
				ReplyToCommand(param1, "%t", "Player no longer available");
			}
			else
			{
				DRPlayer player = DRPlayer(client);
				
				if (StrEqual(arg2, "on"))
				{
					player.ReceivesMoreQP = true;
					player.SaveData();
					ReplyToCommand(param1, "%N will now receive more queue points", player.Index);
				}
				else
				{
					player.ReceivesMoreQP = false;
					player.SaveData();
					ReplyToCommand(param1, "%N will no longer receive more queue points", player.Index);
				}
			}
			
			MenuFunction(param1, "menu_admin_more_qp");
		}
		
		// Activator ban
		else if (StrContains(selection, "raw_activator_ban") == 0)
		{
			char item[32], arg1[32], arg2[4];
			
			int len = BreakString(selection, item, sizeof(item));
			len += BreakString(selection[len], arg1, sizeof(arg1));
			BreakString(selection[len], arg2, sizeof(arg2));
			
			int userid = StringToInt(arg1);
			int client = GetClientOfUserId(userid);
			
			if (client == 0)
			{
				ReplyToCommand(param1, "%t", "Player no longer available");
			}
			else
			{
				DRPlayer player = DRPlayer(client);
				
				if (StrEqual(arg2, "on"))
				{
					player.ActivatorBanned = true;
					player.SaveData();
					ReplyToCommand(param1, "%N is now activator banned", player.Index);
				}
				else
				{
					player.ActivatorBanned = false;
					player.SaveData();
					ReplyToCommand(param1, "%N is no longer activator banned", player.Index);
				}
			}
			
			MenuFunction(param1, "menu_admin_activator_ban");
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

		if (display[0] != '\0' && StrContains(selection, "raw_") != 0)
		{
			char buffer[256];
			Format(buffer, sizeof(buffer), "%T", display, param1);
			
			return RedrawMenuItem(buffer);
		}
    }
	
	return 0;
}
