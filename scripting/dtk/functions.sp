
/**
 * Entity Work
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Find and hook entities. 
 * 
 * @noreturn
 */
stock void SetUpEnts()
{
	// Clear NPC array
	g_NPCs.Clear();
	g_NPCs.Resize(1);
	
	// monster_resource
	if ((g_iEnts[Ent_MonsterRes] = FindEntityByClassname(-1, "monster_resource")) == -1)
	{
		if ((g_iEnts[Ent_MonsterRes] = CreateEntityByName("monster_resource")) != -1)
		{
			if (!DispatchSpawn(g_iEnts[Ent_MonsterRes]))
			{
				LogError("Unable to spawn a monster_resource entity. SDKTools game data not working?");
				RemoveEdict(g_iEnts[Ent_MonsterRes]);
				g_iEnts[Ent_MonsterRes] = -1;
			}
		}
		else
		{
			LogError("Unable to create a monster_resource entity. Not supported by mod?");
		}
	}
	
	// Player resource manager
	if ((g_iEnts[Ent_PlayerRes] = GetPlayerResourceEntity()) == -1)
		LogError("Player resource entity not found!");


	int i = -1;
	char targetname[256];
	
	// math_counter
	while ((i = FindEntityByClassname(i, "math_counter")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		if (StrContains(targetname, DRENT_MATH_BOSS, false) == 0)
		{
			HookSingleEntityOutput(i, "OutValue", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser1", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser2", Hook_HealthEnts);
			
			// The first boss math_counter will be at index 0
			g_NPCs.Set(0, i);
			
			Debug("Hooked boss math_counter %d named %s", i, targetname);
		}
		
		else if (StrContains(targetname, DRENT_MATH_MINIBOSS, false) == 0)
		{
			HookSingleEntityOutput(i, "OutValue", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser1", Hook_HealthEnts);
			HookSingleEntityOutput(i, "OnUser2", Hook_HealthEnts);
			
			// Add math_counter to NPC array
			g_NPCs.Push(i);
			
			Debug("Hooked mini-boss math_counter %d named %s", i, targetname);
		}
	}

	// logic_relay
	while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DTKENT_HEALTHSCALE_MAX, false) == 0 || StrContains(targetname, DTKENT_HEALTHSCALE_OVERHEAL, false) == 0)
		{
			HookSingleEntityOutput(i, "OnTrigger", Hook_HealthEnts);
			Debug("Hooked OnTrigger output of logic_relay %d named %s", i, targetname);
		}
	}

	if (!g_ConVars[P_MapInstructions].BoolValue)
		return;

	// logic_branch
	while ((i = FindEntityByClassname(i, "logic_branch")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DRENT_BRANCH, false) == 0 || StrContains(targetname, DTKENT_BRANCH, false) == 0)
		{
			SetEntProp(i, Prop_Data, "m_bInValue", 1, 1);
			Debug("Set logic_branch '%s' to true", targetname);
		}
	}

	// logic_case
	while ((i = FindEntityByClassname(i, "logic_case")) != -1)
	{
		GetEntPropString(i, Prop_Data, "m_iName", targetname, sizeof(targetname));
		if (StrContains(targetname, DRENT_PROPERTIES, false) == 0)
		{
			HookSingleEntityOutput(i, "OnUser1", ProcessLogicCase);
			Debug("Hooked OnUser1 output of logic_case named '%s'", targetname);
		}
	}
}




void LoadKVFiles()
{
	g_Restrictions = new KeyValues("restrictions");
	if (!g_Restrictions.ImportFromFile(WEAPON_RESTRICTIONS_CFG))
	{
		LogError("Failed to load weapon restriction config \"%s\"", WEAPON_RESTRICTIONS_CFG);
	}
	
	g_Replacements = new KeyValues("replacements");
	if (!g_Replacements.ImportFromFile(WEAPON_REPLACEMENTS_CFG))
	{
		LogError("Failed to load weapon replacement config \"%s\"", WEAPON_REPLACEMENTS_CFG);
	}
}




StringMap BuildSoundList()
{
	StringMap hSounds = new StringMap();
	hSounds.SetString("chat_warning",	"common/warning.wav");
	hSounds.SetString("chat_reply", (FileExists("sound/ui/chat_display_text.wav", true)) ? "ui/chat_display_text.wav" : "misc/talk.wav");
		// TF2: sound/ui/chat_display_text.wav  HL2: ui/buttonclickrelease.wav
	
	return hSounds;
}




/**
 * Player Preferences
 * ----------------------------------------------------------------------------------------------------
 */
 
// Toggle English language
void ToggleEnglish(int client)
{	
	if (Player(client).HasFlag(PF_PrefEnglish))
	{
		Player(client).RemoveFlag(PF_PrefEnglish);
		char language[32];
		
		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
				ChatMessage(client, "When you next connect, your client language will be used");
			else
			{
				SetClientLanguage(client, iLanguage);
				ChatMessage(client, "Your client language of '%s' will now be used", language);
			}
		}
	}
	else
	{
		Player(client).AddFlag(PF_PrefEnglish);
		ChatMessage(client, "Your language has been set to English");
		SetClientLanguage(client, 0);
	}
}




/**
 * Player Allocation
 * ----------------------------------------------------------------------------------------------------
 */


/**
 * Check teams to see if we have the required number of players on each team
 * 
 * @noreturn
 */
void CheckTeams()
{
	/*
		While the plugin makes changes to teams, it disables Watch Mode.
		This prevents it from reacting to changes as if they were caused by players,
		or from going into an infinite loop of activator selection.
		
		Disable Watch Mode before performing team distrubution, and enable it when you're done.
	*/
	
	// Monitor Activators During Freeze Time
	if (game.InWatchMode)
	{
		int activators = GetNumActivatorsRequired();
		
		if (game.Activators < activators && game.Participants > activators)
		{
			Debug("We have enough participants so we'll select some Activators");
			
			game.InWatchMode = false;
			RequestFrame(SelectActivators);
		}
	}
	/*
	// Fixed by enabling the Unbalance cvar at < 2 participants
	else if (!game.InWatchMode && game.Participants < 2)	// Go into Watch Mode when insufficient participants
	{
		Debug("Insufficient participants for a round, so Watch Mode will be enabled");
		game.InWatchMode = true;
	}
	*/
	
	// The Unbalancing ConVar helps manage Round Restart when the server is empty
	if (game.Participants > 1)
	{
		g_ConVars[S_Unbalance].IntValue = 0;
	}
	else
	{
		g_ConVars[S_Unbalance].RestoreDefault();
	}
}




/**
 * Select and move eligible activators
 * 
 * @noreturn
 */
void SelectActivators()
{	
	Debug("Selecting activators");
	
	int len = game.ActivatorPool;
	int[] list = new int[len];
	CreateActivatorList(list);
	
	// If we need activators and have enough on red to supply and not empty the team, move someone
	int i = 0;
	int activators = GetNumActivatorsRequired();
	
	while (TFTeam_Blue.Count() < activators && TFTeam_Red.Count() > 1 && i < len)
	{
		Player player = Player(list[i]);
		
		if (player.InGame && player.Team == Team_Red)
		{
			Debug("Selected %N as an activator and moving them to Blue", player.Index);
			
			player.MakeActivator();
			player.SetTeam(Team_Blue);
			
			if (game.RoundState != Round_Waiting)
			{
				player.SetPoints(QP_Consumed);
				player.ActivatorLast = GetTime();
				
				ChatMessage(player.Index, "%t", "you_are_an_activator");
				
				if (g_ConVars[P_BlueBoost] != null && g_ConVars[P_BlueBoost].BoolValue)
				{
					ChatMessage(player.Index, "Bind +speed to use the Activator speed boost");
				}
				
				if (g_bSCR && g_ConVars[P_SCR].BoolValue)
				{
					SCR_SendEvent(PREFIX_SERVER, "%N has been made activator", player.Index);
				}
				
				if (activators == 1)
				{
					char name[32];
					GetClientName(player.Index, name, sizeof(name));
					ChatMessageAllEx(player.Index, "%t", "name_has_been_made_activator", name);
				}
			}
		}

		i++;
	}
	
	// Respawn teams if OF or TF2C
	if (game.IsGame(Mod_TF2C|Mod_OF) && GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available) // TODO Does this work?
	{
		RespawnTeamsUsingEntity();
	}
	
	// Go into watch mode to replace activator if needed
	game.InWatchMode = true;
}




/**
 * Get the number of activators needed
 * 
 * @return		int		Number of activators
 */
int GetNumActivatorsRequired()
{
	// Get the ratio of activators to participants
	int activators = RoundFloat(game.Participants * g_ConVars[P_ActivatorRatio].FloatValue);
	
	// If we have specified an activator cap, clamp to it
	if (g_ConVars[P_ActivatorsMax].IntValue > -1)
	{
		ClampInt(activators, 1, g_ConVars[P_ActivatorsMax].IntValue);
	}

	// else, clamp between 1 and participants -1
	ClampInt(activators, 1, game.Participants - 1);
	
	Debug("We need %d activators", activators);
	
	return activators;
}




/**
 * Populate a 1D array of client indexes in order of activator queue position
 * 
 * @noreturn
 */
stock void CreateActivatorList(int[] list)
{
	int len = game.ActivatorPool;
	bool optout = (game.WillingActivators >= MINIMUM_WILLING);

	if (!len) return;

	int[][] sort = new int[len][3];
	int count;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		Player player = Player(i);
		
		if (player.InGame && player.IsParticipating)
		{
			if (!player.HasFlag(PF_PrefActivator) && optout)
				continue;

			sort[count][0] = player.Index;
			sort[count][1] = player.Points;
			sort[count][2] = player.ActivatorLast;
			count++;
		}
	}
	
	SortCustom2D(sort, len, SortPlayers);
	
	for (int i = 0; i < len; i++)
	{
		list[i] = sort[i][0];
	}
}




/**
 * Sorting function used by SortCustom2D. Sorts players by queue points
 * and last activator time.
 * 
 * @return	int	
 */
stock int SortPlayers(int[] a, int[] b, const int[][] array, Handle hndl)
{
	if (b[1] == a[1])			// B and A have the same points
	{
		if (b[2] < a[2])			// B has an earlier Activator time than A
		{
			return 1;
		}
		else if (b[2] > a[2])		// B has a later Activator time than A
		{
			return -1;
		}
		else						// B and A have the same Activator time
		{
			return 0;
		}	
	}
	else if (b[1] > a[1])		// B has more points than A
	{
		return 1;
	}
	else						// B has fewer points than A
	{
		return -1;
	}
}





/**
 * Player Properties
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Apply the necessary attributes to a player after they spawn.
 * 
 * @noreturn
 */
void ApplyPlayerAttributes(int client)
{
	if (!game.IsGame(Mod_TF))
		return;

	Player player = Player(client);

	// Reset player attributes
	RemoveAllAttributes(client);
	
	// Blue Speed
	if (player.Team == Team_Blue)
		if (g_ConVars[P_BlueSpeed].FloatValue != 0.0)
			player.SetSpeed(g_ConVars[P_BlueSpeed].IntValue);

	// Red
	if (player.Team == Team_Red)
	{
		// Red Speed
		if (g_ConVars[P_RedSpeed].FloatValue != 0.0)
			player.SetSpeed(g_ConVars[P_RedSpeed].IntValue);
		
		// Red Scout Speed
		else if (g_ConVars[P_RedScoutSpeed].FloatValue != 0.0 && player.Class == Class_Scout)
			player.SetSpeed(g_ConVars[P_RedScoutSpeed].IntValue);
		
		// Double Jump
		if (!g_ConVars[P_RedAirDash].BoolValue && player.Class == Class_Scout)
			AddAttribute(client, "no double jump", 1.0);
		
		// Spy Cloak
		if (player.Class == Class_Spy)
		{
			AddAttribute(client, "mult cloak meter consume rate", 8.0);
			AddAttribute(client, "mult cloak meter regen rate", 0.25);
		}

		// Demo Charging
		if (player.Class == Class_DemoMan)
		{
			switch (2)
			{
				case 0:
				{
					AddAttribute(client, "charge time decreased", -1000.0);
					AddAttribute(client, "charge recharge rate increased", 0.0);
				}
				case 2:
				{
					AddAttribute(client, "charge time decreased", -0.95);
					AddAttribute(client, "charge recharge rate increased", 0.2);
				}
			}
		}
	}
}



/**
 * Remove a player's weapon and replace it with a new one.
 * 
 * @param		int		Client index
 * @param		int		Current weapon
 * @param		int		New weapon item definition index
 * @param		char	New weapon classname
 * @return		int		Entity index of new weapon. -1 if failed to create
 */
int ReplaceWeapon(int client, int oldweapon, int itemDefIndex, char[] classname)
{
	int weapon = CreateWeapon(itemDefIndex, classname);
	
	if (weapon != -1)
	{
		RemoveEntity(oldweapon);
		GiveWeapon(client, weapon);
	}
	else
	{
		LogError("Failed to create a new weapon for %N");
	}
	
	return weapon;
}




/**
 * Create a new weapon
 * 
 * @param		int		New weapon item definition index
 * @param		char	New weapon classname
 * @return		int		New weapon entity index
 */
int CreateWeapon(int itemDefIndex, char[] classname)
{
	int weapon = CreateEntityByName(classname);
	
	if (weapon != -1)
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
		
		if (!DispatchSpawn(weapon))
		{
			RemoveEntity(weapon);
			weapon = -1;
		}
	}
	
	return weapon;
}




/**
 * Equip a player with a weapon and assign them as owner
 * 
 * @param		int		Client index
 * @param		int		Weapon entity index
 * @noreturn
 */
void GiveWeapon(int client, int weapon)
{
	SetEntProp(weapon, Prop_Send, "m_hOwnerEntity", client);
	EquipPlayerWeapon(client, weapon);
}




/*
void ModulateSpeed(int client)
{
	if (GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") != g_flSpeeds[client][Speed_Last] && g_flSpeeds[client][Speed_Desired])
	{
		// Calculate how much to multiply player's max speed by
		float modifier = g_flSpeeds[client][Speed_Desired] / Player(client).ClassRunSpeed;
		
		// Calculate new max speed property
		float newmaxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed") * modifier;
		
		// Set new max speed property
		SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", newmaxspeed);
		
		// Save new max speed for comparison
		g_flSpeeds[client][Speed_Last] = newmaxspeed;
		
		// Resetting player speed to class speed
		if (g_flSpeeds[client][Speed_Desired] == Player(client).ClassRunSpeed)
			g_flSpeeds[client][Speed_Desired] = 0.0;
		
		//PrintCenterText(client, "g_flSpeeds[client][Speed_Last] == %f\ng_flSpeeds[client][Speed_Desired] == %f\nm_flMaxspeed == %f\nm_flSpeed == %f", g_flSpeeds[client][Speed_Last], g_flSpeeds[client][Speed_Desired], GetEntPropFloat(client, Prop_Send, "m_flMaxspeed"), GetEntPropFloat(client, Prop_Data, "m_flSpeed"));
	}
}
*/




void ActivatorBoost(int client, int buttons, int tickcount)
{
	if (g_ConVars[P_BlueBoost] == null)
		return;
	
	Player player = Player(client);
	
	if (!g_ConVars[P_BlueBoost].BoolValue || !player.IsActivator || !player.IsAlive)
		return;
	
	// Activator Speed Boosting
	static float boost[MAXPLAYERS] =  { 396.0, ... };
	static int boosting[MAXPLAYERS];
	
	if (buttons & IN_SPEED)	// TODO Find an alternative way to boost speed in OF. Sprinting?
	{
		if (boost[client] > 0.0)
		{
			if (!boosting[client] && boost[client] > 132.0)
			{
				if (game.IsGame(Mod_TF))
				{
					TF2_AddCondition(client, TFCond_SpeedBuffAlly, TFCondDuration_Infinite);
				}
				
				boosting[client] = true;
			}
			
			if (boosting[client])
			{
				boost[client] -= 1.0;
			}
			else
			{
				boost[client] += 0.5;
			}
		}
		else if (boost[client] <= 0.0)
		{
			if (game.IsGame(Mod_TF))
			{
				TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
			}
			
			boosting[client] = false;
			boost[client] += 0.5;
		}
	}
	else if (!(buttons & IN_SPEED))
	{
		if (boost[client] < 396.0)
		{
			if (boosting[client])
			{
				if (game.IsGame(Mod_TF))
					TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
				
				boosting[client] = false;
			}
			
			boost[client] += 0.5;
		}
	}
	
	// Tick timer for boost HUD
	if (!g_iTickTimer)
		g_iTickTimer = tickcount;
	
	// Show Boost HUD every half second
	if ((tickcount) > (g_iTickTimer + 33))
	{
		g_iTickTimer = tickcount;
		BoostHUD(client, boost[client]);
	}
}




/*
	Health Scaling
	--------------
	
	Modes
	-----
	BUG These don't seem to be right. 1 is overheal and 3 is max
	
	1. Overheal and multiply internal value
	2. Overheal and multiply set value
	3. Overheal and multiply based on max health
	4. Expand pool to a multiple of internal value
	5. Expand pool to a multiple of set value
	6. Expand pool to a multiple of max health
	
	Revised: 
	
	Pool
		Plugin default scaling
		Multiply by given health value
	
	Overheal
		Plugin default scaling
		Multiply by given health value
	
	
	Back stab
	Fall damage
*/



/**
 * Scale activator health
 * If a value is not specified, health will be scaled up using DTK's internal
 * health scaling calculation, which is tested for balancing
 * 
 * @param		bool	Overheal or increase health pool
 * @param		int		Multiply health by this number * live reds
 * @param		int		Apply scaling to a specific client
 * @noreturn
 */
int ScaleActivatorHealth(bool overheal = false, int value = 0, int client = 0)
{
	/*
		How it Works
		------------
		
		Take a 'base' of 300
		Set percentage float to 1.0
		Get the client's max health (substitute with an average of all activators when scaling all?
			Or give each client a different amount based on their existing max health?)
		Store the player's max health in a float so we can use it to reduce health pack contribution
			by a corresponding amount
		
		Get number of live reds
		For each live red, add 'base' times 'percentage' to a variable containing the player's max health value.
		Multiply percentage by 1.15. This is equivalent to increasing the percentage multiplier by 15%.
		
		Set player's health to new max.
		Scale HP contribution.
		Set player's health to new figure.
		
		
		Thoughts
		--------
		
		Why am I using a base? Why did I choose 300?
		
		
		Method
		------
		
		If client == 0
			get average max health of activators
			if value != 0
				Get new max health from scaling maths
			else
				Get new max health from multiply maths
			Give each activator the health pack attribute using their stored max health
			Give each player the new health divided by number of live acts
		else if client is specified
			get class health of activator
			if value != 0
				Get new max health from scaling maths
			else
				Get new max health from multiply maths
			Give the client the health pack attribute using their stored max health divided by number of live acts
			Give the client the new health divided by number of live acts
	*/
	
	
	
	int activators = game.AliveActivators;
	int reds = TFTeam_Red.Alive();
	int ihealth;
	
	if (activators >= reds || !activators)	// Don't scale if teams are even or there are no activators
		return 0;
	
	if (client != 0)
	{
		Player player = Player(client);
		
		if (!player.IsAlive || !player.InGame || !player.IsActivator)
			return 0;
		
		float health = float(player.ClassHealth);
		float p = 1.0;
		
		if (value == 0)	// Scale
		{
			for (int i = 1; i < reds; i++)
			{
				health += (HEALTH_SCALE_BASE * p);
				p *= 1.15;
			}
		}
		else	// Multiply
		{
			health = float(value * reds);
		}
		
		ihealth = RoundToNearest(health / activators);
		
		AddAttribute(client, "health from packs decreased", float(player.ClassHealth / ihealth));
		
		if (!overheal) player.SetMaxHealth(ihealth);
		player.Health = ihealth;
		
		int index = g_Activators.FindValue(client);
		g_Activators.Set(index, ihealth, AL_MaxHealth);
		g_Activators.Set(index, ihealth, AL_Health);
	}
	else
	{
		float health;
		int len = g_Activators.Length;
		
		for (int i = 0; i < len; i++)
		{
			Player player = Player(g_Activators.Get(i));
			
			if (player.InGame && player.IsAlive)
				health += player.ClassHealth;
		}
		
		health /= activators;
		
		float p = 1.0;
		
		if (value == 0)	// Scale
		{
			for (int i = 1; i < reds; i++)
			{
				health += (HEALTH_SCALE_BASE * p);
				p *= 1.15;
			}
		}
		else	// Multiply
		{
			health = float(value * reds);
		}
		
		ihealth = RoundToNearest(health / activators);
		
		for (int i = 0; i < len; i++)
		{
			Player player = Player(g_Activators.Get(i));
			
			if (player.InGame && player.IsAlive)
			{
				AddAttribute(client, "health from packs decreased", float(player.ClassHealth / ihealth));
				
				if (!overheal) player.SetMaxHealth(ihealth);
				player.Health = ihealth;
				
				g_Activators.Set(i, ihealth, AL_MaxHealth);
				g_Activators.Set(i, ihealth, AL_Health);
			}
		}
	}
	
	return ihealth;
}


	/*
	float base = (value == -1) ? HEALTH_SCALE_BASE : float(value);
	float percentage = 1.0;
	float health = float(this.MaxHealth);
	float largehealthkit = float(this.MaxHealth);
	int count = game.AliveReds;

	for (int i = 2; i <= count; i++)
	{
		health += (base * percentage);
		percentage *= 1.15;
	}

	// TODO Don't do any of this if the health has not been scaled
	if (mode > 2)
	{
		this.SetMaxHealth(health);
		AddAttribute(this.Index, "health from packs decreased", largehealthkit / health);
	}
	this.Health = RoundToNearest(health);
	*/





/**
 * Map Interaction
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Process data from a logic_case using string splitting and delimiters
 * 
 * @noreturn
 */
stock void ProcessLogicCase(const char[] output, int caller, int activator, float delay)
{
	// Caller is the entity reference of the logic_case
	
	if (activator > MaxClients || activator < 0)
	{
		char classname[64];
		char targetname[64];
		
		GetEntityClassname(activator, classname, sizeof(classname));
		GetEntPropString(activator, Prop_Data, "m_iName", targetname, sizeof(targetname));
		
		LogError("Deathrun logic_case was triggered by an invalid client index (%d, a %s named '%s')", activator, classname, targetname);
		return;
	}
	
	char caseValue[256];
	char caseNumber[12];
	char targetname[64];
	
	GetEntPropString(caller, Prop_Data, "m_iName", targetname, sizeof(targetname));
	Debug("Deathrun logic_case '%s' received %s from %N", targetname, output, activator);
	
	for (int i = 0; i < 16; i++)
	{
		Format(caseNumber, sizeof(caseNumber), "m_nCase[%d]", i);
		GetEntPropString(caller, Prop_Data, caseNumber, caseValue, sizeof(caseValue));
		
		if (caseValue[0] != '\0')
		{
			char buffers[2][256];
			ExplodeString(caseValue, ":", buffers, 2, 256, true);
			ProcessMapInstruction(activator, buffers[0], buffers[1]);
		}
	}
}


/**
 * Process a map instruction
 * 
 * @noreturn
 */
stock void ProcessMapInstruction(int client, const char[] instruction, const char[] properties)
{
	Player player = Player(client);
	char buffers[16][256];
	ExplodeString(properties, ",", buffers, 16, 256, true);

	// Give weapon
	if (StrEqual(instruction, "weapon", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			ReplaceWeapon(player.Index, weapon, StringToInt(buffers[1]), buffers[2]);
		}
	}
	
	// Remove weapon
	if (StrEqual(instruction, "remove_weapon", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			RemoveEdict(weapon);
			Debug("Removed %N's weapon in slot %s", client, buffers[0]);
		}
	}
	
	// Give weapon attribute
	if (StrEqual(instruction, "weapon_attribute", false))
	{
		int weapon = player.GetWeapon(StringToInt(buffers[0]));
		if (weapon != -1)
		{
			int itemDefIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (itemDefIndex == StringToInt(buffers[1]))
			{
				bool success = TF2Attrib_SetByName(weapon, buffers[2], StringToFloat(buffers[3]));
				if (success) Debug("Set an attribute on a weapon belonging to %N (%s with value %f)", client, buffers[2], StringToFloat(buffers[3]));
			}
		}
	}
	
	// Switch to slot
	if (StrEqual(instruction, "switch_to_slot", false))
	{
		player.SetSlot(StringToInt(buffers[0]));
	}
	
	// Change class
	if (StrEqual(instruction, "class", false))
	{
		int class = ProcessClassString(buffers[0]);
		player.SetClass(class);
	}
	
	// Set speed
	if (StrEqual(instruction, "speed", false))
	{
		player.SetSpeed(StringToInt(buffers[0]));
	}
	
	// Set health
	if (StrEqual(instruction, "health", false))
	{
		player.Health = StringToInt(buffers[0]);
	}
	
	// Set max health
	if (StrEqual(instruction, "maxhealth", false))
	{
		player.SetMaxHealth(StringToInt(buffers[0]));
	}
	
	/*
	// Scale max health (Activator)
	if (StrEqual(instruction, "scalehealth", false))
	{
		// Scale max health - plugin default
		if (buffers[0][0] == '\0' || StrEqual(buffers[0], "pool", false))
			player.ScaleHealth(3);
		
		if (StrEqual(buffers[0], "overheal", false))
			player.ScaleHealth(1);
	}
	*/
	
	// Scale max health (Activator) TODO Add hard multiply value
	if (StrEqual(instruction, "scalehealth", false))
	{
		// Pool
		if (buffers[0][0] == '\0' || StrEqual(buffers[0], "pool", false))
			ScaleActivatorHealth(false, _, client);
		
		// Overheal
		if (StrEqual(buffers[0], "overheal", false))
			ScaleActivatorHealth(true, _, client);
	}
	
	// Set move type
	if (StrEqual(instruction, "movetype", false))
	{
		if (StrEqual(buffers[0], "fly", false))
		{
			SetEntityMoveType(client, MOVETYPE_FLY);
		}
		if (StrEqual(buffers[0], "walk", false))
		{
			SetEntityMoveType(client, MOVETYPE_WALK);
		}
	}
	
	// Chat message
	if (StrEqual(instruction, "message", false))
	{
		ChatMessage(client, "%s", buffers[0]);
	}
	
	// Melee only
	if (StrEqual(instruction, "meleeonly", false))
	{
		if (StrEqual(buffers[0], "yes", false))
		{
			player.MeleeOnly();
		}
		if (StrEqual(buffers[0], "no", false))
		{
			player.MeleeOnly(false);
		}
	}
	
	// Use class animations for custom model
	if (StrEqual(instruction, "use_class_animations", false))
	{
		if (StrEqual(buffers[0], "true", false) || buffers[0][0] == '\0')
		{
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 1);
			Debug("Enabled m_bUseClassAnimations for %N", client);
		}
		if (StrEqual(buffers[0], "false", false))
		{
			SetEntProp(client, Prop_Send, "m_bUseClassAnimations", 0);
			Debug("Disabled m_bUseClassAnimations for %N", client);
		}
	}
	
	// Set custom model
	if (StrEqual(instruction, "setmodel", false))
	{
		// TODO Check if model is precached
		
		if (StrEqual(buffers[0], "none", false) || buffers[0][0] == '\0')
		{
			SetVariantString("");
		}
		else
		{
			SetVariantString(buffers[0]);
		}
		
		AcceptEntityInput(client, "SetCustomModel", client, client);
		Debug("Set %N's custom model to %s", client, buffers[0]);
	}
	
	// TODO: Add something to hide cosmetics. Consider resetting custom model on round restart or death
	// Is it possible to parent a model to the player, bone merge it (effect flag 129) and make it visible (EF_NODRAW)?
	
	/*
	// Custom model rotates
	if (StrEqual(instruction, "model_rotates", false))
	{
		if (StrEqual(buffers[0], "true", false) || buffers[0][0] == '\0')
		{
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 1);
			Debug("Enabled m_bCustomModelRotates for %N", client);
		}
		if (StrEqual(buffers[0], "false", false))
		{
			SetEntProp(client, Prop_Send, "m_bCustomModelRotates", 0);
			Debug("Disabled m_bCustomModelRotates for %N", client);
		}
	}
	*/
}




/**
 * Communication
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Display up to the next three activators at the end of a round.
 * 
 * @noreturn
 */
int FormatNextActivators(char[] buffer, int max = 3)
{
	// Get number of activators
	int len = game.ActivatorPool;
	int[] list = new int[len];
	int cells;
	
	// Create activator list
	CreateActivatorList(list);

	// Format the message
	if (list[0])
	{
		cells += Format(buffer, MAX_CHAT_MESSAGE, "%t", (len == 1 || max == 1) ? "next_activator" : "next_activators");
		
		for (int i = 0; max > i < len; i++)
		{
			if (i == 0)
			{
				cells += Format(buffer, MAX_CHAT_MESSAGE, "%s%N", buffer, list[i]);
			}
			else
			{
				cells += Format(buffer, MAX_CHAT_MESSAGE, "%s, %N", buffer, list[i]);
			}
		}
	}
	
	return cells;
}




/**
 * Messages
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * ChatMessage
 * Send a message to a player with sound effect and prefix based on the 'message type' parameter.
 *
 * @param		int		Client index
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessage(int client, const char[] string, any...)
{
	SetGlobalTransTarget(client);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 3);
	Format(buffer, len, "%t%s", "chat_prefix_client", buffer);
	
	FormatChatColours(buffer, len);
	
	char effect[256];
	g_hSounds.GetString("chat_reply", effect, sizeof(effect));
	
	if (!client)
	{
		PrintToServer(buffer);
	}
	else
	{
		BfWrite say = UserMessageToBfWrite(StartMessageOne("SayText2", client, USERMSG_BLOCKHOOKS));
		
		if (say != null)
		{
			say.WriteByte(client); 
			say.WriteByte(true);
			say.WriteString(buffer);
			EndMessage();
		}
		else
		{
			PrintToChat(client, buffer);
		}
	}
	
	if (effect[0] && client) EmitSoundToClient(client, effect);
}




/**
 * ChatMessage wrapper that sends a message to all clients
 *
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessageAll(const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 2);
		Format(buffer, len, "%t%s", "chat_prefix_all", buffer);
		
		FormatChatColours(buffer, len);
		
		BfWrite say = UserMessageToBfWrite(StartMessageOne("SayText2", i, USERMSG_BLOCKHOOKS));
		if (say != null)
		{
			say.WriteByte(i); 
			say.WriteByte(true);
			say.WriteString(buffer);
			EndMessage();
		}
		else
		{
			PrintToChat(i, buffer);
		}
	}
}



/**
 * ChatMessage wrapper that sends a message to all clients except one
 *
 * @param		int		Client index
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatMessageAllEx(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || i == client)
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 3);
		Format(buffer, len, "%t%s", "chat_prefix_all", buffer);
		
		FormatChatColours(buffer, len);
		
		BfWrite say = UserMessageToBfWrite(StartMessageOne("SayText2", i, USERMSG_BLOCKHOOKS));
		if (say != null)
		{
			say.WriteByte(i); 
			say.WriteByte(true);
			say.WriteString(buffer);
			EndMessage();
		}
		else
		{
			PrintToChat(i, buffer);
		}
	}
}



/**
 * ChatMessage wrapper that sends a message to all admins
 *
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatAdmins(const char[] string, any ...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetUserAdmin(i) == INVALID_ADMIN_ID)
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 2);
		ChatMessage(i, buffer);
	}
}



/**
 * ChatMessage wrapper that sends a message to all admins except one
 *
 * @param		int		Client index
 * @param		int		Msg_Type
 * @param		char	Message string
 * @param		any		...
 */
stock void ChatAdminsEx(int client, const char[] string, any...)
{
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetUserAdmin(i) == INVALID_ADMIN_ID || i == client)
			continue;
		
		SetGlobalTransTarget(i);
		VFormat(buffer, len, string, 3);
		ChatMessage(i, string);
	}
}



/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 *
 * @param 		char	Formatting rules
 * @param 		...		Variable number of formatting arguments
 * @noreturn
 */
stock void Debug(const char[] string, any...)
{
	if (!g_ConVars[P_Debug].BoolValue)
		return;
	
	SetGlobalTransTarget(LANG_SERVER);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 2);
	
	PrintToServer("%s %s", PREFIX_DEBUG, buffer);
}



/**
 * Displays a debug message in server console when the plugin's debug ConVar is enabled.
 * Ex: Also displays to client in chat.
 *
 * @param		int		Client index
 * @param		char	Formatting rules
 * @param		...		Variable number of formatting arguments
 * @noreturn
 */
stock void DebugEx(int client, const char[] string, any...)
{
	if (!g_ConVars[P_Debug].BoolValue)
		return;
	
	SetGlobalTransTarget(client);
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	VFormat(buffer, len, string, 3);
	
	char effect[256];
	g_hSounds.GetString("chat_warning", effect, sizeof(effect));
	
	PrintToChat(client, "%t%s", "chat_prefix_client", buffer);
	if (effect[0]) EmitSoundToClient(client, effect);
	
	PrintToServer("%s %s", PREFIX_DEBUG, buffer);
}




stock void FormatChatColours(char[] string, int len)
{
	char replacement[32];
	
	Format(replacement, 32, "%t", "{default}");
	ReplaceString(string, len, "{default}", replacement);
	
	Format(replacement, 32, "%t", "{highlight}");
	ReplaceString(string, len, "{highlight}", replacement);
	
	Format(replacement, 32, "%t", "{killing_entity}");
	ReplaceString(string, len, "{killing_entity}", replacement);
}




/**
 * Server Environment
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Set server ConVars and hook events
 * 
 * @param		bool	Enable or disable
 * @noreturn
 */
void HookStuff(bool enabled)
{
	// ConVars
	if (enabled)
	{
		//g_ConVars[S_Unbalance].IntValue 		= 0;
		g_ConVars[S_AutoBalance].IntValue 		= 0;
		g_ConVars[S_Scramble].IntValue 			= 0;
		g_ConVars[S_Queue].IntValue 			= 0;
		g_ConVars[S_WFPTime].IntValue 			= 0;	// Needed in OF and TF2C
		g_ConVars[S_Pushaway].BoolValue			= (g_ConVars[P_Pushaway].BoolValue);
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].IntValue = 0;
	}
	else
	{
		g_ConVars[S_Unbalance].RestoreDefault();
		g_ConVars[S_AutoBalance].RestoreDefault();
		g_ConVars[S_Scramble].RestoreDefault();
		g_ConVars[S_Queue].RestoreDefault();
		g_ConVars[S_Pushaway].RestoreDefault();
		g_ConVars[S_WFPTime].RestoreDefault();
		
		if (g_ConVars[S_FirstBlood] != null)
			g_ConVars[S_FirstBlood].RestoreDefault();
	}
	
	// Events
	if (enabled)
	{
		HookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);	// Round restart
		HookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);		// Round has begun
		HookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);			// Round has begun (Arena)
		HookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);			// Round has ended
		HookEvent("player_spawn", Event_PlayerSpawn);										// Player spawns
		HookEvent("player_team", Event_TeamsChanged);										// Player chooses a team
		HookEvent("player_changeclass", Event_ChangeClass);									// Player changes class
		HookEvent("player_healed", Event_PlayerHealed);										// Player healed
		HookEvent("player_death", Event_PlayerDeath);										// Player dies
		HookEvent("player_hurt", Event_PlayerDamaged);										// Player is damaged
		
		if (game.IsGame(Mod_TF))
			HookEvent("post_inventory_application", Event_InventoryApplied);				// Player receives weapons
			
		if (game.IsGame(Mod_TF2C))
			HookEvent("player_healonhit", Event_PlayerHealed);								// Player healed by health kit
	}
	else
	{
		UnhookEvent("teamplay_round_start", Event_RoundRestart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_active", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("arena_round_start", Event_RoundStart, EventHookMode_PostNoCopy);
		UnhookEvent("teamplay_round_win", Event_RoundEnd, EventHookMode_PostNoCopy);
		UnhookEvent("player_spawn", Event_PlayerSpawn);
		UnhookEvent("player_team", Event_TeamsChanged);
		UnhookEvent("player_changeclass", Event_ChangeClass);
		UnhookEvent("player_healed", Event_PlayerHealed);
		UnhookEvent("player_death", Event_PlayerDeath);
		UnhookEvent("player_hurt", Event_PlayerDamaged);
		
		if (game.IsGame(Mod_TF))
			UnhookEvent("post_inventory_application", Event_InventoryApplied);
		
		if (game.IsGame(Mod_TF2C))
			UnhookEvent("player_healonhit", Event_PlayerHealed);
	}
	
	// Command Listeners
	if (enabled)
	{
		AddCommandListener(CmdListener_LockBlue,	"kill");
		AddCommandListener(CmdListener_LockBlue, 	"explode");
		AddCommandListener(CmdListener_LockBlue, 	"spectate");
		AddCommandListener(CmdListener_Teams, 		"jointeam");
		AddCommandListener(CmdListener_Teams, 		"autoteam");
		AddCommandListener(CmdListener_Builds, 		"build");
	}
	else
	{
		RemoveCommandListener(CmdListener_LockBlue,	"kill");
		RemoveCommandListener(CmdListener_LockBlue,	"explode");
		RemoveCommandListener(CmdListener_LockBlue,	"spectate");
		RemoveCommandListener(CmdListener_Teams, 	"jointeam");
		RemoveCommandListener(CmdListener_Teams, 	"autoteam");
		RemoveCommandListener(CmdListener_Builds, 	"build");
	}
}




/**
 * ConVar change hook
 * 
 * @param		ConVar	ConVar handle.
 * @param		char	Old ConVar value.
 * @param		char	New ConVar value.
 * @noreturn
 */
void ConVar_ChangeHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char name[64];
	convar.GetName(name, sizeof(name));
	
	if (StrContains(name, "dtk_", false) == 0)
	{
		PrintToServer("%s %s has been changed from %s to %s", PREFIX_SERVER, name, oldValue, newValue);
		ChatAdmins("%s has been changed from %s to %s", name, oldValue, newValue);
	}
	
	// Enabled
	if (convar == g_ConVars[P_Enabled])
	{
		// Enable game mode
		if (convar.BoolValue)
		{
			HookStuff(true);
			//game.InWatchMode = true;
			/*
				Here we enable Watch Mode. This will... why do we need to do this again?
				
				When a map changes, the server does not fire a round restart or round start event until there
				are enough players to begin a round. When that happens, the players are spawned and the events
				fired.
			*/
			GameDescription(true);
			g_TimerQP = CreateTimer(TIMER_GRANTPOINTS, Timer_GrantPoints, _, TIMER_REPEAT);
			
			// OF stalled round check
			if (game.IsGame(Mod_OF))
				g_Timer_OFTeamCheck = CreateTimer(10.0, Timer_OFTeamCheck, _, TIMER_REPEAT);
		}
		// Disable game mode
		else
		{
			HookStuff(false);
			GameDescription(false);
			
			if (g_TimerQP != null)
				delete g_TimerQP;
			
			// OF stalled round check
			if (game.IsGame(Mod_OF) && g_Timer_OFTeamCheck != null)
				delete g_Timer_OFTeamCheck;
		}
	}
	
	// Player Push Away
	else if (convar == g_ConVars[P_Pushaway])
	{
		g_ConVars[S_Pushaway].BoolValue = convar.BoolValue;
	}

	// Red Melee Only
	else if (convar == g_ConVars[P_RedMelee])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).MeleeOnly(convar.BoolValue);
		}
	}
	
	// Red Speed
	else if (convar == g_ConVars[P_RedSpeed])
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (Player(i).InGame && Player(i).Team == Team_Red)
				Player(i).SetSpeed(convar.IntValue);
		}
	}
}




/**
 * Set the server's game description.
 *
 * @noreturn
 */
stock void GameDescription(bool enabled)
{
	// Stop if SteamTools is not found
	if (!g_bSteamTools)
		return;

	// Stop if ConVar is empty
	char description[256];
	g_ConVars[P_Description].GetString(description, sizeof(description));
	
	if (description[0] == '\0')
		return;
	
	if (!enabled) // Plugin not enabled
	{
		if 			(game.IsGame(Mod_TF))		Format(description, sizeof(description), "Team Fortress");
		else if 	(game.IsGame(Mod_OF))		Format(description, sizeof(description), "Open Fortress");
		else if 	(game.IsGame(Mod_TF2C))	Format(description, sizeof(description), "Team Fortress 2 Classic");
		else 									Format(description, sizeof(description), DEFAULT_GAME_DESC);
	}
	else
	{
		ReplaceString(description, sizeof(description), "{plugin_name}", PLUGIN_SHORTNAME, false);
		ReplaceString(description, sizeof(description), "{plugin_version}", PLUGIN_VERSION, false);
	}
	
	Steam_SetGameDescription(description);
	PrintToServer("%s Set game description to \"%s\"", PREFIX_SERVER, description);
}




/**
 * Database
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Connect to the database and create the table if it doesn't exist
 *
 * @noreturn
 */
stock void DBCreateTable()
{
	char error[255];
	
	if ((g_db = SQLite_UseDatabase(SQLITE_DATABASE, error, sizeof(error))) == null)
	{
		LogError("Unable to connect to SQLite database %s: %s", SQLITE_DATABASE, error);
	}
	else
	{
		char query[255];
		
		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (steamid INTEGER PRIMARY KEY, \
		points INTEGER, flags INTEGER, last_seen INTEGER DEFAULT 0)", SQLITE_TABLE);
		
		if (!SQL_FastQuery(g_db, query))
		{
			SQL_GetError(g_db, error, sizeof(error));
			LogError("Unable to create database table %s: %s", SQLITE_TABLE, error);
		}
	}
}




/**
 * Get rid of database records older than one month.
 *
 * @noreturn
 */
stock void DBPrune()
{
	// Remove entries older than a month, or 2629743 seconds
	if (g_db != null)
	{
		char query[255];
		Format(query, sizeof(query), "DELETE FROM %s WHERE last_seen <= %d", SQLITE_TABLE, GetTime() - 2629743);
		
		DBResultSet resultset = SQL_Query(g_db, query);
		if (resultset.AffectedRows > 0)
			LogMessage("Deleted %d expired records from the database", resultset.AffectedRows);
		CloseHandle(resultset);
	}
}




/**
 * Delete the DTK table from the database.
 *
 * @noreturn
 */
stock void DBReset(int client)
{
	char query[255];
	Format(query, sizeof(query), "DROP TABLE %s", SQLITE_TABLE);
	if (SQL_FastQuery(g_db, query))
	{
		ShowActivity(client, "Reset player database. Changing the map will reinitialise it");
		LogMessage("%L reset the database using the admin command", client);
	}
	else
	{
		char error[255];
		SQL_GetError(g_db, error, sizeof(query));
		ShowActivity(client, "Failed to reset database: %s", error);
		LogError("%L failed to reset the database. Error: %s", client, error);
	}
}




/**
 * HUD Elements
 * ----------------------------------------------------------------------------------------------------
 */

#define USE_BOSS_BAR

/**
 * Refresh boss health HUD display elements
 *
 * @noreturn
 */
void RefreshBossHealthHUD()
{
	if (!g_ConVars[P_BossBar].BoolValue)
		return;
		
	/*
		Priority
		--------
		
		Boss bar: Boss
		Text: Boss
		Text: Activators
		Boss bar: Activators
		Text: Mini bosses
		
		Rules
		-----
		
		Don't hide the boss bar if there is a math boss
		Don't hide the text if there are mini bosses
		Make sure bosses disappearing (dying) doesn't trigger activator health display as a side effect
		
		Should activator health be suppressed if there are NPCs?
	*/
	
	int len = g_Activators.Length;
	int health, maxhealth;
	
	// Prevent the bar being shown if we have no activators
	if (!len)return;

#if defined USE_BOSS_BAR
	if (g_iEnts[Ent_MonsterRes] != -1)	// monster_resource exists
	{
		// We have a boss math_counter with a health value
		Debug("TF2 CLASSIC - g_NPCs.Length is %d and g_iEnts[Ent_MonsterRes] is %d", g_NPCs.Length, g_iEnts[Ent_MonsterRes]);
		int ent = g_NPCs.Get(0);
		health = RoundToNearest(g_NPCs.Get(0, AL_Health));
		if (ent && health)
		{
			Debug("We have a boss math_counter %d with health %d", ent, health);
			maxhealth = RoundToNearest(g_NPCs.Get(0, AL_MaxHealth));
			SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossState", 1);
		}
		// We will use the activators for the boss bar
		else
		{
			for (int i = 0; i < len; i++)
			{
				health += g_Activators.Get(i, AL_Health);
				maxhealth += g_Activators.Get(i, AL_MaxHealth);
				SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossState", 0);
			}
			Debug("Activator total health: %d total max: %d", health, maxhealth);
		}
		
		int percent = RoundToNearest( float(health) / float(maxhealth) * 255.0 );
		SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossHealthPercentageByte", (percent > 255) ? 255 : percent);
		Debug("Setting health bar to %d / 255", percent);
	}
	else	// Text alternative
#endif
	{
		char buffer[256];
		
		if (TFTeam_Blue.Alive() <= 2)	// Two Activators
		{
			for (int i = 0; i < len; i++)
			{
				Player player = Player(g_Activators.Get(i));
	
				if (player.InGame && player.IsAlive)
				{
					Format(buffer, 256, "%s%N: %dHP\n", buffer, player.Index, player.Health);
				}
			}
		}
		else						// Three or more Activators
		{
			for (int i = 0; i < len; i++)
			{
				health += g_Activators.Get(i, AL_Health);
			}
			
			Format(buffer, 256, "%t: %dHP", "hud_activators", health);
		}
		
		HealthText(buffer);
	}
	
	game.IsBossBarActive = true;
	
	delete g_TimerHPBar;
	g_TimerHPBar = CreateTimer(10.0, Timer_HealthBar);
}




/**
 * Display some text below the health bar.
 *
 * @param	char	The text.
 * @noreturn
 */
stock void HealthText(const char[] string = "", any ...)
{
	static Handle hHealthText;
	if (!hHealthText)
		hHealthText = CreateHudSynchronizer();
	
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	SetHudTextParams(-1.0, 0.16, 20.0, 123, 190, 242, 255, _, 0.0, 0.0, 0.0);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (string[0])
			{
				SetGlobalTransTarget(i);
				VFormat(buffer, len, string, 2);
				ShowSyncHudText(i, hHealthText, buffer);
			}
			else
			{
				ClearSyncHud(i, hHealthText);
			}
		}
	}
}



// TODO Use this to update activator health values in the array without updating the bars

/**
 * Update stored health and max health values of client Activator in dynamic array,
 * then cause boss health HUD to update to reflect changes.
 *
 * @param		int		Client index
 * @noreturn
 */
void UpdateHealthBar(int client)
{
	int index = g_Activators.FindValue(client);
	Player player = Player(client);
	
	if (index != -1)
	{
		g_Activators.Set(index, player.Health, AL_Health);		// Store health
		
		int maxhealth = g_Activators.Get(index, AL_MaxHealth);	// Get Array max health
		
		Debug("%N's stored Array max health is %d", client, maxhealth);
		
		if (player.MaxHealth > maxhealth)
		{
			g_Activators.Set(index, player.MaxHealth, AL_MaxHealth);
			
			Debug("%N's max health is greater than their array stored health (%d > %d)", client, player.MaxHealth, maxhealth);
		}
		else if (player.Health > maxhealth)
		{
			g_Activators.Set(index, player.Health, AL_MaxHealth);
			
			Debug("%N's health is greater than their array stored health (%d > %d)", client, player.Health, maxhealth);
		}
	}
	
	RefreshBossHealthHUD();
}




/**
 * Boost HUD
 *
 * @param		int		Client index
 * @noreturn
 */
stock void BoostHUD(int client, float value)
{
	if (g_Text_Boost == null) g_Text_Boost = CreateHudSynchronizer();
	
	char buffer[256] = "Boost: ";
	int characters = RoundToFloor(value / 33);
	
	for (int i = 0; i < characters; i++)
	{
		Format(buffer, sizeof(buffer), "%s▋", buffer);
	}
	
	SetHudTextParamsEx(0.20, 0.85, 0.54, { 255, 255, 255, 255 }, { 255, 255, 255, 255 }, 0, 0.0, 0.0);
	ShowSyncHudText(client, g_Text_Boost, buffer);
}
