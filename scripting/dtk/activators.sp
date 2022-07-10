
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
	
	Debug("Checking teams");
	
	// Monitor Activators During Freeze Time
	if (DRGame.InWatchMode)
	{
		int activatorsNeeded = GetNumActivatorsRequired();
		
		if (DRGame.Activators < activatorsNeeded && DRGame.Participants > activatorsNeeded)
		{
			Debug("We have enough participants. Select activator(s)");
			
			DRGame.InWatchMode = false;
			RequestFrame(SelectActivators);
		}
		else if (DRGame.Activators == activatorsNeeded)
		{
			Debug("We have enough activators");
		}
		else if (DRGame.Participants <= activatorsNeeded)
		{
			Debug("We have too few participants");
		}
	}
	/*
	// Fixed by enabling the Unbalance cvar at < 2 participants
	else if (!DRGame.InWatchMode && DRGame.Participants < 2)	// Go into Watch Mode when insufficient participants
	{
		Debug("Insufficient participants for a round, so Watch Mode will be enabled");
		DRGame.InWatchMode = true;
	}
	*/
	
	// The Unbalancing ConVar helps manage Round Restart when the server is empty
	if (DRGame.Participants > 1)
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
	
	int len = DRGame.ActivatorPool;
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
			
			if (DRGame.RoundState != Round_Waiting)
			{
				player.SetPoints(QP_Consumed);
				player.ActivatorLast = GetTime();
				
				TF2_PrintToChat(player.Index, _, "%t", "you_are_an_activator");
				EmitMessageSoundToClient(player.Index);
				
				if (g_ConVars[P_BlueBoost] != null && g_ConVars[P_BlueBoost].BoolValue)
				{
					TF2_PrintToChat(player.Index, _, "Bind +speed to use the Activator speed boost");
				}
				
				if (g_bSCR && g_ConVars[P_SCR].BoolValue)
				{
					SCR_SendEvent(PLUGIN_PREFIX, "%N has been made activator", player.Index);
				}
				
				if (activators == 1)
				{
					CreateTimer(0.1, Timer_AnnounceActivatorToAll, player.Index);
					//RequestFrame(RF_AnnounceActivatorToAll, player.Index);
				}
			}
		}

		i++;
	}
	
	// Respawn teams if OF or TF2C
	if (DRGame.IsGame(Mod_TF2C|Mod_OF) && GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available) // TODO Does this work?
	{
		RespawnTeamsUsingEntity();
	}
	
	// Go into watch mode to replace activator if needed
	DRGame.InWatchMode = true;
}

Action Timer_AnnounceActivatorToAll (Handle timer, int client)
{
	char name[32];
	GetClientName(client, name, sizeof(name));
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i) && i != client)
		{
			TF2_PrintToChat(i, client, "%t", "name_has_been_made_activator", name);
		}
	}
}




/**
 * Get the number of activators needed
 * 
 * @return		int		Number of activators
 */
int GetNumActivatorsRequired()
{
	// Get the ratio of activators to participants
	int activators = RoundFloat(DRGame.Participants * g_ConVars[P_ActivatorRatio].FloatValue);
	
	// If we have specified an activator cap, clamp to it
	if (g_ConVars[P_ActivatorsMax].IntValue > -1)
	{
		ClampInt(activators, 1, g_ConVars[P_ActivatorsMax].IntValue);
	}

	// else, clamp between 1 and participants -1
	ClampInt(activators, 1, DRGame.Participants - 1);
	
	Debug("Number of activators required: %d", activators);
	return activators;
}




/**
 * Populate a 1D array of client indexes in order of activator queue position
 * 
 * @noreturn
 */
stock void CreateActivatorList(int[] list)
{
	int len = DRGame.ActivatorPool;
	bool optout = (DRGame.WillingActivators >= MINIMUM_WILLING);

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
				if (DRGame.IsGame(Mod_TF))
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
			if (DRGame.IsGame(Mod_TF))
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
				if (DRGame.IsGame(Mod_TF))
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
	
	
	
	int activators = DRGame.AliveActivators;
	int reds = TFTeam_Red.Alive();
	int ihealth;
	
	if (activators >= reds || !activators)	// Don't scale if teams are even or there are no activators
		return 0;
	
	if (client != 0)
	{
		Player player = Player(client);
		
		if (!player.IsAlive || !player.InGame || !player.IsActivator)
			return 0;
		
		float health = float(GetTFClassHealth(TF2_GetPlayerClass(player.Index)));
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
		
		AddAttribute(client, "health from packs decreased", GetTFClassHealth(TF2_GetPlayerClass(player.Index)) / float(ihealth));
		
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
				health += GetTFClassHealth(TF2_GetPlayerClass(player.Index));
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
				AddAttribute(client, "health from packs decreased", GetTFClassHealth(TF2_GetPlayerClass(player.Index)) / float(ihealth));
				
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
	int count = DRGame.AliveReds;

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
 * Display up to the next three activators at the end of a round.
 * 
 * @noreturn
 */
int FormatNextActivators(char[] buffer, int max = 3)
{
	// Get number of activators
	int len = DRGame.ActivatorPool;
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
				cells += Format(buffer, MAX_CHAT_MESSAGE, "%s\x03%N", buffer, list[i]);
			}
			else
			{
				cells += Format(buffer, MAX_CHAT_MESSAGE, "%s\x01, \x03%N", buffer, list[i]);
			}
		}
	}
	
	return cells;
}









/**
 * HUD Elements
 * ----------------------------------------------------------------------------------------------------
 */

#define USE_BOSS_BAR



/*

	Each frame query
	1. Check health values by iterating across the activators array and combining them
	2. Check it with a static value. If it changes, update the bar and restart the timer.
	3. Don't display outside of round active
	4. Update max values outside of round active

*/



Handle g_hBossTextBarTimer;

void BossBar_Check()
{
	// If boss bar cvar is disabled, use a text bar
	if (!g_ConVars[P_BossBar].BoolValue)
	{
		if (g_hBossTextBarTimer == null)
		{
			g_hBossTextBarTimer = CreateTimer(1.0, BossBar_Text, _, TIMER_REPEAT);
		}
		return;
	}
	delete g_hBossTextBarTimer;
	
	// If monster_resource not found, disable the boss bar cvar
	int bar = FindEntityByClassname(-1, "monster_resource");
	if (bar == -1)
	{
		g_ConVars[P_BossBar].BoolValue = false;
		LogError("monster_resource entity not found. Lack of mod support? Disabled boss bar");
		return;
	}
	
	// Stop if there are no activators and hide the bar
	int len = g_Activators.Length;
	if (!len)
	{
		SetEntProp(bar, Prop_Send, "m_iBossHealthPercentageByte", 0);
		return;
	}
	
	// Iterate across the Activators list and collect health & max health
	static int health, maxhealth;
	int newhealth, newmaxhealth;
	for (int i = 0; i < len; i++)
	{
		Player player = Player(g_Activators.Get(i));
		if (player.IsConnected && player.InGame)
		{
			newhealth += player.Health;
			newmaxhealth += player.MaxHealth;
		}
	}

	// Hide if round not active
	if (DRGame.RoundState != Round_Active)
	{
		health = newhealth;
		maxhealth = newmaxhealth;
		SetEntProp(bar, Prop_Send, "m_iBossHealthPercentageByte", 0);
		return;
	}
	
	// Update stored max health
	if (health > maxhealth)
	{
		maxhealth = health;
	}
	if (newmaxhealth > maxhealth)
	{
		maxhealth = newmaxhealth;
	}

	// If health has changed, display bar and reset timer
	if (health != newhealth)
	{
		health = newhealth;
		int barval = RoundToNearest( float(health) / float(maxhealth) * 255.0 );
		SetEntProp(bar, Prop_Send, "m_iBossHealthPercentageByte", barval);
		Debug("Boss bar -- health %d, maxhealth %d, barval %d", health, maxhealth, barval);
		DRGame.IsBossBarActive = true;
		delete g_TimerHPBar;
		g_TimerHPBar = CreateTimer(10.0, Timer_HideHealthBar);
	}
	// If the timer has elapsed hide the bar
	else if (!DRGame.IsBossBarActive)
	{
		SetEntProp(bar, Prop_Send, "m_iBossHealthPercentageByte", 0);
	}
}


Action BossBar_Text(Handle timer)
{
	// Stop if there are no activators and hide the bar
	int len = g_Activators.Length;
	if (!len || DRGame.RoundState != Round_Active)
	{
		return;
	}
	
	char buffer[256];
	
	// If two activators, display their bars separately
	if (TFTeam_Blue.Alive() <= 2)
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
	// If three or more activators, combine their health
	else
	{
		int health;
		for (int i = 0; i < len; i++)
		{
			Player player = Player(g_Activators.Get(i));
			if (player.InGame && player.IsAlive)
				health += player.Health;
		}
		Format(buffer, 256, "%t: %dHP", "hud_activators", health);
	}
	
	HealthText(buffer);
}


Action Timer_HideHealthBar(Handle timer)
{
	HealthText();
	DRGame.IsBossBarActive = false;
	g_TimerHPBar = null;
}



/**
 * Refresh boss health HUD display elements
 *
 * @noreturn
 */

// Removed this in favout of the simpler OnGameFrame boss bar update.
// Entity data will need to come later

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
 
/*
void RefreshBossHealthHUD()
{
	if (!g_ConVars[P_BossBar].BoolValue)
		return;
	
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
	
	DRGame.IsBossBarActive = true;
	
	delete g_TimerHPBar;
	g_TimerHPBar = CreateTimer(10.0, Timer_HideHealthBar);
}
*/



/**
 * Display some text below the health bar.
 *
 * @param	char	The text.
 * @noreturn
 */
void HealthText(const char[] string = "", any ...)
{
	static Handle hHealthText;
	if (!hHealthText)
		hHealthText = CreateHudSynchronizer();
	
	int len = strlen(string) + 255;
	char[] buffer = new char[len];
	
	SetHudTextParams(-1.0, 0.16, 1.0, 123, 190, 242, 200);
	
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
