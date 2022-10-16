
/**
 * Game Events
 * ----------------------------------------------------------------------------------------------------
 */

static bool restarting;

void Event_RoundRestart (Event event, const char[] name, bool dontBroadcast)
{
	PrintToServer("%s --- The round has restarted ---", PLUGIN_PREFIX);
	DRGame.RoundState = Round_Freeze;
	Instructions_FindEnts();

	// If the activator leaves the blue team during a round or victory time, the round will restart at the end
	// of the victory state, and go into a waiting state. When a player joins the empty team, a round restart
	// is triggered again. In our case, the act of transferring an activator to blue on the next round
	// causes a second round restart which immediately replaces them.
	if (restarting)
	{
		Debug("Double round restart detected");
		ShowActivity(0, "Double round restart detected");
		return;
	}
	
	// Activator Selection
	restarting = true;
	Debug("Moving all players to Red");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame)
		{
			if (player.Team == Team_Blue)
			{
				Debug("Moving %N to RED", player.Index);
				player.SetTeam(Team_Red);
			}
			ApplyPlayerAttributes(i);
		}
	}

	SelectActivators();
	CreateTimer(1.0, Timer_RoundRestarted);
}

Action Timer_RoundRestarted(Handle timer)
{
	restarting = false;
}




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
	
	PrintToServer("%s --- The round is now active ---", PLUGIN_PREFIX);
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
		SCR_SendEvent(PLUGIN_PREFIX, "The round is now active");
	
	// Move players with no class to Spectator
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame && player.IsParticipating && player.Class == Class_Unknown)
		{
			player.SetTeam(Team_Spec);
			char sname[MAX_NAME_LENGTH];
			GetClientName(i, sname, sizeof(sname));
			TF2_PrintToChatAll(i, "%t", "name_no_class_moved_spec", sname);
		}
	}
	
	// Start next activator message timer
	static Handle timer;
	if (timer != null)
	{
		delete timer;
	}
	timer = CreateTimer(TIMER_NA_MESSAGE, Timer_NextActivator_Message, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}


Action Timer_NextActivator_Message(Handle timer, any data)
{
	char buffer[MAX_CHAT_MESSAGE];
	int numact = GetNumActivatorsRequired();
	
	if (FormatNextActivators(buffer, numact))
	{
		PrintToChatAll(buffer);
	}
	
	timer = null;
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
	
	PrintToServer("%s --- The round has ended ---", PLUGIN_PREFIX);
	
	if (g_bSCR && g_ConVars[P_SCR].BoolValue)
	{
		SCR_SendEvent(PLUGIN_PREFIX, "The round has ended");
	}
}




/**
 * Player Events
 * ----------------------------------------------------------------------------------------------------
 */

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (DRGame.RoundState == Round_Freeze || DRGame.RoundState == Round_Active)
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
		if (g_kvRestrictions != null && g_kvRestrictions.JumpToKey(key))
		{
			
			// Check if the item is to be given attributes
			if (g_bTF2Attributes && g_kvRestrictions.JumpToKey("attributes"))
			{
				if (g_kvRestrictions.GotoFirstSubKey())
				{
					do
					{
						char attrib[128];
						g_kvRestrictions.GetString("name", attrib, sizeof(attrib));
						float value = g_kvRestrictions.GetFloat("value");
						
						if (attrib[0] == '\0')
						{
							char section[16];
							g_kvRestrictions.GetSectionName(section, sizeof(section));
							LogError("Weapon restrictions > %d > attributes > %s > Attribute name key not found", item, section);
						}
						else
						{
							AddAttribute(weapon, attrib, value);
							PrintToConsole(player.Index, "%s Gave your weapon in slot %d the attribute \"%s\" with value %.2f", PLUGIN_PREFIX, i, attrib, value);
						}
					}
					while (g_kvRestrictions.GotoNextKey());
				}
				else
					LogError("Weapon restrictions > %d > attributes > No attribute sections found", item);
			}
			
			// Check if the item should be replaced
			else if (g_kvReplacements != null && g_kvRestrictions.JumpToKey("replace"))
			{
				IntToString(player.Class, key, sizeof(key));
				
				if (g_kvReplacements.JumpToKey(key)) // Player Class
				{
					IntToString(i, key, sizeof(key));
					
					if (g_kvReplacements.JumpToKey(key)) // Weapon Slot
					{
						char id[16], classname[128];
						g_kvReplacements.GetString("id", id, sizeof(id));
						g_kvReplacements.GetString("classname", classname, sizeof(classname));
						
						if (id[0] == '\0')
						{
							LogError("Weapon replacements > %d > %d > id key or value not found", player.Class, i);
						}
						else if (classname[0] == '\0')
						{
							LogError("Weapon replacements > %d > %d > classname key or value not found", player.Class, i);
						}
						else if (ReplaceWeapon(player.Index, weapon, g_kvReplacements.GetNum("id"), classname))
						{
							PrintToConsole(player.Index, "%s Replaced your weapon in slot %d with a %s (type %d)", PLUGIN_PREFIX, i, classname, g_kvReplacements.GetNum("id"));
						}
					}
					else
						LogError("Weapon replacements > %d > Weapon slot %d not found", player.Class, i);
				}
				else
					LogError("Weapon replacements > Class %d not found", player.Class);
				
				g_kvReplacements.Rewind();
			}
			
			// Check if the item should be removed
			else if (g_kvRestrictions.JumpToKey("remove"))	// Remove Weapon
			{
				if (AcceptEntityInput(weapon, "Kill"))
				{
					PrintToConsole(player.Index, "%s Removed your weapon in slot %d", PLUGIN_PREFIX, i);
				}
			}
			
			// The item exists in the config but there are no valid actions
			else
			{
				LogError("Weapon restrictions > %d > No valid actions found", item);
			}
			
			g_kvRestrictions.Rewind();
		}
	}
}




void Event_ChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	// Welcome the player
	if (!Player(client).HasFlag(PF_Welcomed))
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));
		TF2_PrintToChat(client, client, "%t", "welcome_player_to_deathrun_toolkit", sName);
		EmitMessageSoundToClient(client);
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
		
		if (DRGame.IsGame(Mod_TF))
			event.GetString("weapon_logclassname", classname, sizeof(classname));
		else
			event.GetString("weapon", classname, sizeof(classname));
		
		if (classname[0] != 'w')	// Filter out 'world' as the killer entity because dying from fall damage is obvious
		{
			char targetname[256];
			
			if (DRGame.IsGame(Mod_TF))
			{
				GetEntPropString(event.GetInt("inflictor_entindex"), Prop_Data, "m_iName", targetname, sizeof(targetname));
		
				if (targetname[0] != '\0')	// If there is a targetname, reformat a string to include it
					Format(targetname, sizeof(targetname), "(%s)", targetname);
			}
			
			TF2_PrintToChat(victim, _, "%t", "killed_by_entity_classname", classname, targetname);
			EmitMessageSoundToClient(victim);
			PrintToConsoleAll("%N was killed by a %s %s", victim, classname, targetname);
		}
	}
}



Action Event_TeamsChanged(Event event, const char[] name, bool dontBroadcast)
{
	Player player = Player(GetClientOfUserId(event.GetInt("userid")));
	
	// Player switches away from Blue
	if (event.GetInt("oldteam") == Team_Blue)
	{
		Debug("%L switched away from BLUE", player.Index);
		
		if (player.IsActivator)
		{
			player.UnmakeActivator();
		}
	}
	
	// Player switches away from Red
	if (event.GetInt("oldteam") == Team_Red)
	{
		Debug("%L switched away from RED", player.Index);
		player.RemoveFlag(PF_Runner);
		Debug("%L removed the RUNNER flag", player.Index);
	}
	
	// Player switches to Red
	if (event.GetInt("team") == Team_Red)
	{
		Debug("%L joined RED", player.Index);
		player.AddFlag(PF_Runner);
		Debug("%L given the RUNNER flag", player.Index);
	}
	
	// Non-Activator switches to Blue during a running game
	if (event.GetInt("team") == Team_Blue && !player.HasFlag(PF_Activator) && DRGame.Participants > 2)
	{
		Debug("%L joined BLUE without ACTIVATOR flag. There are > 2 participants", player.Index);
		RequestFrame(RF_MoveToRed, player.Index);
	}
	// Non-Activator switches to Blue while the game is not running
	else if (event.GetInt("team") == Team_Blue && !player.HasFlag(PF_Activator) && TFTeam_Blue.Count())
	{
		// If a player somehow switches to Blue while there is already a player there
		// they will be moved to Red
		Debug("%L joined BLUE without ACTIVATOR flag. There is at least one player on BLUE", player.Index);
		RequestFrame(RF_MoveToRed, player.Index);
	}
	else if (event.GetInt("team") == Team_Blue && player.HasFlag(PF_Activator))
	{
		Debug("%L joined BLUE with the ACTIVATOR flag", player.Index);
	}
	
	// Check teams on any change
	RequestFrame(CheckTeams);
}


void RF_MoveToRed(int client)
{
	Debug("Moving %L to RED from BLUE", client);
	Player(client).SetTeam(Team_Red, false);
}