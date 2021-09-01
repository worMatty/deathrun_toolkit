
/**
 * Game Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_RoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s --- The round has restarted ---", PREFIX_SERVER);

	// Set Round State
	game.RoundState = Round_Freeze;

	// Find and Hook Entities
	SetUpEnts();
	
	/*
	// Move players to Red and add Runner flag
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame)
		{
			if (player.Team == Team_Red)
			{
				player.AddFlag(PF_Runner);
			}
			if (player.Team == Team_Blue)
			{
				player.SetTeam(Team_Red);
				player.AddFlag(PF_Runner);
			}
		}	
	}
	*/
	
	/*
		Reset Player Flags
		Move players to Red and add Runner flag
		Choose a class for players with none
		Apply Initial Player Attributes
	*/
	
	Debug("Moving all players to Red");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame)
		{
			player.RemoveFlag(PF_Activator);	// TODO Necessary?
			player.RemoveFlag(PF_Runner);		// TODO Necessary?
			
			if (player.Team == Team_Red)
			{
				player.AddFlag(PF_Runner);
			}
			
			if (player.Team == Team_Blue)
			{
				player.SetTeam(Team_Red);
				player.AddFlag(PF_Runner);
			}
			
			//if (!player.IsBot && player.Class == Class_Unknown)
			//{
			//	player.SetClass(GetRandomInt(1, 9), _, true);
			//}
			// Note: This doesn't work on puppet bots. They are on the leaderboard but don't spawn.
			// !player.IsBot added to prevent this.
	
			ApplyPlayerAttributes(i);
		}
	}
	
	// Hide Health Bar
	RefreshBossHealthHUD();
	
	// Begin Redistribution
	SelectActivators();
}




void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	game.InWatchMode = false;	// No need to watch for team changes now
	
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
		
		ChatMessageAll("%t", phrase);
		phrase_number++;
	}
	
	// Set round state to Active
	game.RoundState = Round_Active;
	
	PrintToServer("%s --- The round is now active ---", PREFIX_SERVER);
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
		SCR_SendEvent(PREFIX_SERVER, "The round is now active");
	
	// Move players with no class to Spectator
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame && player.IsParticipating && player.Class == Class_Unknown)
		{
			player.SetTeam(Team_Spec);
			char sname[MAX_NAME_LENGTH];
			GetClientName(i, sname, sizeof(sname));
			ChatMessageAll("%t", "name_no_class_moved_spec", sname);
		}
	}
}



void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	game.RoundState = Round_Win;
	
	char buffer[MAX_CHAT_MESSAGE];
	int activators = GetNumActivatorsRequired();
	
	FormatNextActivators(buffer, activators);	// TODO: Don't display this if the map is about to change
	
	if (buffer[0] != '\0')
		ChatMessageAll(buffer);
	
	PrintToServer("%s --- The round has ended ---", PREFIX_SERVER);
	
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
	{
		SCR_SendEvent(PREFIX_SERVER, "The round has ended");
	}
}




/**
 * Player Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (game.RoundState == Round_Freeze || game.RoundState == Round_Active)
		RequestFrame(ApplyPlayerAttributes, client);
}




void Event_InventoryApplied(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	RequestFrame(RF_InventoryApplied, client);
}

void RF_InventoryApplied(int client)
{
	Player player = Player(client);
	
	// Restrict Items
	if (g_ConVars[P_RestrictItems].BoolValue)
		CheckItemRestrictions(player);

	// Melee only
	if (g_ConVars[P_RedMelee].BoolValue)
		if (player.Team == Team_Red)
			player.MeleeOnly();
	
	// Boss Health Bar
	if (game.IsBossBarActive && player.IsActivator)
		UpdateHealthBar(player.Index);
				
}

void CheckItemRestrictions(Player player)
{
	for (int i = 0; i < Weapon_ArrayMax; i++)
	{
		int weapon = player.GetWeapon(i);
			
		if (weapon == -1)
			continue;
		
		int item = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		
		// Check Restrictions KV
		char key[16];
		IntToString(item, key, sizeof(key));
		
		// Check if the item is in the restrictions config
		if (g_Restrictions != null && g_Restrictions.JumpToKey(key))
		{
			
			// Check if the item is to be given attributes
			if (g_bTF2Attributes && g_Restrictions.JumpToKey("attributes"))
			{
				if (g_Restrictions.GotoFirstSubKey())
				{
					do
					{
						char attrib[128];
						g_Restrictions.GetString("name", attrib, sizeof(attrib));
						float value = g_Restrictions.GetFloat("value");
						
						if (attrib[0] == '\0')
						{
							char section[16];
							g_Restrictions.GetSectionName(section, sizeof(section));
							LogError("Weapon restrictions > %d > attributes > %s > Attribute name key not found", item, section);
						}
						else
						{
							AddAttribute(weapon, attrib, value);
							PrintToConsole(player.Index, "%s Gave your weapon in slot %d the attribute \"%s\" with value %.2f", PREFIX_SERVER, i, attrib, value);
						}
					}
					while (g_Restrictions.GotoNextKey());
				}
				else
					LogError("Weapon restrictions > %d > attributes > No attribute sections found", item);
			}
			
			// Check if the item should be replaced
			else if (g_Replacements != null && g_Restrictions.JumpToKey("replace"))
			{
				IntToString(player.Class, key, sizeof(key));
				
				if (g_Replacements.JumpToKey(key)) // Player Class
				{
					IntToString(i, key, sizeof(key));
					
					if (g_Replacements.JumpToKey(key)) // Weapon Slot
					{
						int id = g_Replacements.GetNum("id");
						char classname[128];
						g_Replacements.GetString("classname", classname, sizeof(classname));
						
						if (!id)
						{
							LogError("Weapon replacements > %d > %d > id key or value not found", player.Class, i);
						}
						else if (classname[0] == '\0')
						{
							LogError("Weapon replacements > %d > %d > classname key or value not found", player.Class, i);
						}
						else if (ReplaceWeapon(player.Index, weapon, id, classname))
						{
							PrintToConsole(player.Index, "%s Replaced your weapon in slot %d with a %s (type %d)", PREFIX_SERVER, i, classname, id);
						}
					}
					else
						LogError("Weapon replacements > %d > Weapon slot %d not found", player.Class, i);
				}
				else
					LogError("Weapon replacements > Class %d not found", player.Class);
				
				g_Replacements.Rewind();
			}
			
			// Check if the item should be removed
			else if (g_Restrictions.JumpToKey("remove"))	// Remove Weapon
			{
				if (AcceptEntityInput(weapon, "Kill"))
				{
					PrintToConsole(player.Index, "%s Removed your weapon in slot %d", PREFIX_SERVER, i);
				}
			}
			
			// The item exists in the config but there are no valid actions
			else
			{
				LogError("Weapon restrictions > %d > No valid actions found", item);
			}
			
			g_Restrictions.Rewind();
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
	//int attacker 	= GetClientOfUserId(event.GetInt("attacker"));
	
	//if (attacker != victim && victim == g_iBoss)
	if (Player(victim).IsActivator)
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
	
	//if (patient == g_iBoss)
	if (Player(patient).IsActivator)
		RequestFrame(UpdateHealthBar, patient);
}



void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Welcome the player
	if (!Player(client).HasFlag(PF_Welcomed))
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		ChatMessage(client, "%t", "welcome_player_to_deathrun_toolkit", sName);
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
			
			ChatMessage(victim, "%t", "killed_by_entity_classname", classname, targetname);
		}
	}
	
	// Boss Health Bar
	//if (g_ConVars[P_BossBar].BoolValue && victim == g_iBoss)
	if (Player(victim).IsActivator)
		RefreshBossHealthHUD();
}



Action Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	Player player = Player(GetClientOfUserId(event.GetInt("userid")));
	
	// Player switches away from Blue
	if (event.GetInt("oldteam") == Team_Blue)
	{
		//player.RemoveFlag(PF_Activator);
		player.UnmakeActivator();
	}
	
	// Player switches away from Red
	if (event.GetInt("oldteam") == Team_Red)
	{
		player.RemoveFlag(PF_Runner);
	}
	
	// Player switches to Red
	if (event.GetInt("team") == Team_Red)
	{
		player.AddFlag(PF_Runner);
	}
	
	// Non-Activator switches to Blue
	if (event.GetInt("team") == Team_Blue && !player.HasFlag(PF_Activator) && game.Participants > 2)
	{
		RequestFrame(RF_MoveToRed, player.Index);
	}
	
	// Check teams on any change
	RequestFrame(CheckTeams);
}


void RF_MoveToRed(int client)
{
	Player(client).SetTeam(Team_Red, false);
	Debug("Moved non-Activator %N to Blue to Red", client);
}