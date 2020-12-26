/**
 * Methodmaps
 * ----------------------------------------------------------------------------------------------------
 */

#include	"dtk/baseplayer"


/**
 * Game
 * ----------------------------------------------------------------------------------------------------
 */
methodmap Game < Handle
{
	public Game()
	{
	}
	
	/**
	 * Returns either true or false if the round is active or not.
	 * True if the round is currently active and not in pre-round freeze time or has ended.
	 * In TF2 Arena, an active round state is actually Sudden Death.
	 * 
	 * @return	bool	Is the round active?
	 */
	property bool RoundActive
	{
		public get()
		{
			if (g_iGame & FLAG_TF)
				return (GameRules_GetRoundState() == RoundState_Stalemate);
			else
			{
				//PrintToServer("%s Round is %s", PREFIX_SERVER, (g_bRoundActive) ? "active" : "not active");
				return g_bRoundActive;	// TODO Replace all this with JBB's round state system
			}
			//else return false;
		}
	}
	
	
	/**
	 * Functions
	 * --------------------------------------------------
	 */
	
	/**
	 * Connect to the database and create the table if it doesn't exist
	 *
	 * @noreturn
	 */
	public void CreateDBTable()
	{
		char error[255];
		
		if (g_cUseSQL.BoolValue)
		{
			if ((g_db = SQLite_UseDatabase(SQLITE_DATABASE, error, sizeof(error))) == null)
			{
				LogError("Unable to connect to SQLite database %s: %s", SQLITE_DATABASE, error);
			}
			else
			{
				PrintToServer("%s Database connection established. Handle is %x", PREFIX_SERVER, g_db);
				
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
	}
	
	/**
	 * Get rid of database records older than one month.
	 *
	 * @noreturn
	 */
	public void PruneDB()
	{
		// Remove entries older than a month, or 2629743 seconds
		if (g_db != null)
		{
			char query[255];
			Format(query, sizeof(query), "DELETE FROM %s WHERE last_seen <= %d", SQLITE_TABLE, GetTime() - 2629743);
			//SQL_FastQuery(g_db, query);
			
			DBResultSet resultset = SQL_Query(g_db, query);
			DebugMessage("Found %d expired records in the database to delete", resultset.AffectedRows);
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
	public void ResetDB(int client)
	{
		char query[255];
		Format(query, sizeof(query), "DROP TABLE %s", SQLITE_TABLE);
		if (SQL_FastQuery(g_db, query))
		{
			ShowActivity2(client, "", "%t Reset player database. Changing the map will reinitialise it", "prefix_notice");
			LogMessage("%L reset the database using the admin command", client);
		}
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(query));
			ShowActivity2(client, "", "%t Failed: %s", "prefix_notice", error);
			LogError("%L failed to reset the database. Error: %s", client, error);
		}
	}
}

Game game;							// Game logic




/**
 * HealthBar
 * ----------------------------------------------------------------------------------------------------
 */
methodmap HealthBar < Handle
{
	/**
	 * Initialise the handle by storing the indexes of entities used by the health bar system.
	 */
	public HealthBar()
	{
		// Find or create monster_resource entity used to display boss health bar
		int index = FindEntityByClassname(-1, "monster_resource");
	 	if (index == -1)
	 	{
 			index = CreateEntityByName("monster_resource");
 			if (index != -1)
 			{
 				if (!DispatchSpawn(index))
 				{
 					LogError("Unable to spawn a monster_resource entity");
 				}
 			}
 			else
 			{
 				LogError("Unable to create a monster_resource entity");
 			}
	 	}
	 	
	 	if ((g_iHealthBar[HealthBar_PlayerResource] = GetPlayerResourceEntity()) == -1)
	 		LogError("Player resource entity not found");

	 	// Set health bar timer to null - may not need to do this here now
	 	//hBarTimer = null;
	 	
	 	// Hook logic entities for map interaction
	 	int i = -1;
	 	char sTargetname[MAX_NAME_LENGTH];
/*		while ((i = FindEntityByClassname(i, "math_counter")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			if (StrEqual("dtk_health", sTargetname))
			{
				DebugMessage("Found math_counter named %s with entity index %d", sTargetname, i);
				HookSingleEntityOutput(i, "OutValue", EntityHealthBar);
				HookSingleEntityOutput(i, "OnUser1", EntityHealthBar);
				HookSingleEntityOutput(i, "OnUser2", EntityHealthBar);
				break;
			}
		}
*/
		// Hook health math_counters
		if (g_bHookSingleEntityOutput) while ((i = FindEntityByClassname(i, "math_counter")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			if (StrContains(sTargetname, "dtk_health", false) != -1)
			{
				DebugMessage("Found math_counter named %s with entity index %d", sTargetname, i);
				HookSingleEntityOutput(i, "OutValue", EntityHealthBar);
				HookSingleEntityOutput(i, "OnUser1", EntityHealthBar);
				HookSingleEntityOutput(i, "OnUser2", EntityHealthBar);
			}
		}
		
		// Hook health logic_relays
		if (g_bHookSingleEntityOutput) while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
		{
			GetEntPropString(i, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			if (StrContains(sTargetname, "dtk_health", false) != -1)
			{
				DebugMessage("Found logic_relay named %s with entity index %d", sTargetname, i);
				HookSingleEntityOutput(i, "OnTrigger", EntityHealthBar);
			}
		}
	 	
		return view_as<HealthBar>(index);
	}
	
	/**
	 * Get the index of the monster_resource entity.
	 *
	 * @return	int	Entity index.
	 */
	property int Index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	/*
		Health bar
			.Set the monster resource entity
			Set the value and max value, optionally omitting max value and using the value as a number between 0-255
			Set the values of the 'secondary' health bar
			Show
				Copies the values stored in global variables to the entity
			Hide
				Doesn't touch the values stored in the global variables but sends the entity a 0 value to hide it
	*/
	
	
	
	/**
	 * Get the index of the player resource entity. This entity tracks player aspects such as health and kills.
	 *
	 * @return	int	Entity index.
	 */
	property int PlayerResource
	{
		public get()
		{
			return g_iHealthBar[HealthBar_PlayerResource];
		}
	}
	
	/**
	 * Get or set the value stored in the array for 'Health'
	 * 
	 * @param	int Store health.
	 * @return	int	Retrieve stored health.
	 */
	property int Health
	{
		public get()
		{
			return g_iHealthBar[HealthBar_Health];
		}
		public set(int health)
		{
			g_iHealthBar[HealthBar_Health] = health;
		}
	}
	
	/**
	 * Get or set the value stored in the array for 'Max Health'
	 * 
	 * @param	int Store max health.
	 * @return	int	Retrieve stored max health.
	 */
	property int MaxHealth
	{
		public get()
		{
			return g_iHealthBar[HealthBar_MaxHealth];
		}
		public set(int maxhealth)
		{
			g_iHealthBar[HealthBar_MaxHealth] = maxhealth;
		}
	}
	
	/**
	 * Get or set the value stored in the array for 'Health 2'
	 * Health 2 is used to track the health of an entity. It is displayed using a HUDSync.
	 * 
	 * @param	int Store health 2.
	 * @return	int	Retrieve stored health 2.
	 */
	property int Health2
	{
		public get()
		{
			return g_iHealthBar[HealthBar_Health2];
		}
		public set(int health2)
		{
			g_iHealthBar[HealthBar_Health2] = health2;
		}
	}
	
	/**
	 * Get or set the value stored in the array for 'Max Health 2'
	 * Health 2 is used to track the health of an entity. It is displayed using a HUDSync.
	 * 
	 * @param	int Store max health 2.
	 * @return	int	Retrieve stored max health 2.
	 */
	property int MaxHealth2
	{
		public get()
		{
			return g_iHealthBar[HealthBar_Health2];
		}
		public set(int maxhealth2)
		{
			g_iHealthBar[HealthBar_Health2] = maxhealth2;
		}
	}
	
	
	/**
	 * Functions
	 * --------------------------------------------------
	 */
	
	/**
	 * Set the color of the boss health bar.
	 *
	 * @param	int	0 for blue, 1 for green.
	 * @noreturn
	 */
	public void SetColor(int color=0)
	{
		if (this.Index == -1)
			return;
		
		SetEntProp(this.Index, Prop_Send, "m_iBossState", color);
		DebugMessage("Set the colour of the boss health bar to %s", color ? "blue" : "green");
	}
	
	/**
	 * Display some text below the health bar.
	 *
	 * @param	char	The text.
	 * @noreturn
	 */
	public void DisplayText(const char[] string, any ...)
	{
		int len = strlen(string) + 255;
		char[] buffer = new char[len];
		VFormat(buffer, len, string, 3);
		
		SetHudTextParams(-1.0, 0.16, 20.0, 123, 190, 242, 255, _, 0.0, 0.0, 0.0);
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				ShowSyncHudText(i, g_hHealthText, buffer);
		}
	}
	 
	/**
	 * Clear the health bar text object.
	 *
	 * @noreturn
	 */
	public void ClearText()
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
				ClearSyncHud(i, g_hHealthText);
		}
	}
	
	/**
	 * Hide the health bar text object.
	 *
	 * @noreturn
	 */
	public Action Hide()
	{
		if (this.Index == -1)
			return;
		
		SetEntProp(this.Index, Prop_Send, "m_iBossHealthPercentageByte", 0);
		this.ClearText();
	 	
		DebugMessage("Health bar hidden");
	}

	
	/**
	 * Set the percentage of the boss health bar.
	 *
	 * @param	int	Health
	 * @param	int	Max health
	 * @noreturn
	 */
	public void SetHealth(int health=0, int maxhealth=255)
	{
		if (this.Index == -1)
			return;
		
		if (hBarTimer != null)
			delete hBarTimer;
		
		this.Health = health;
		this.MaxHealth = maxhealth;
		
		int iPercent = RoundToNearest((float(health) / float(maxhealth)) * 255);

		SetEntProp(this.Index, Prop_Send, "m_iBossHealthPercentageByte", (iPercent > 255) ? 255 : iPercent);
	
		//PrintToChatAll("health: %d, maxhealth: %d, overheal: %d", health, maxhealth, (health - maxhealth));
 	
		if (health > maxhealth)
		{
			this.DisplayText("+ Overheal: %d  ", (health - maxhealth));
		}
	 	
		DebugMessage("Health bar value set to %d / %d%% (health: %d, maxhealth: %d)", iPercent, RoundToNearest(float(iPercent) / 255.0 * 100.0), health, maxhealth);
		
		hBarTimer = CreateTimer(30.0, DTK_HideBar);
	}
}

HealthBar healthbar;

stock Action DTK_HideBar(Handle timer)
{
	SetEntProp(healthbar.Index, Prop_Send, "m_iBossHealthPercentageByte", 0);
	healthbar.ClearText();
	hBarTimer = null;
 	
	DebugMessage("Health bar hidden");
}






methodmap Player < BasePlayer
{
	public Player(int client)
	{
		return view_as<Player>(client);
	}

	// Hook Damage Received TODO Move this out? Doesn't need a method
	public void HookDamage()
	{
		if (g_iGame & FLAG_TF)	// TODO Replace this with a check to see if we can hook things
		{
			SDKHook(this.Index, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
		}
	}
	
	/**
	 * Plugin Properties
	 * --------------------------------------------------
	 * --------------------------------------------------
	 */
	
	// Queue Points
	property int Points
	{
		public get()
		{
			return g_iPlayers[this.Index][Player_Points];
		}
		public set(int points)
		{
			g_iPlayers[this.Index][Player_Points] = points;
		}
	}
	
	// Plugin Flags
	property int Flags
	{
		public get()
		{
			return g_iPlayers[this.Index][Player_Flags];
		}
		public set(int flags)
		{
			g_iPlayers[this.Index][Player_Flags] = flags;
		}
	}
	
	// Is Runer
	property bool IsRunner
	{
		public get()
		{
			if (g_iPlayers[this.Index][Player_Flags] & SESSION_RUNNER)
				return true;
			else
				return false;
		}
	}
	
	// Is Activator
	property bool IsActivator
	{
		public get()
		{
			if (g_iPlayers[this.Index][Player_Flags] & SESSION_ACTIVATOR)
				return true;
			else
				return false;
		}
	}
	
	// User ID from Player Array
	property int ArrayUserID
	{
		public get()
		{
			return g_iPlayers[this.Index][Player_ID];
		}
		public set(int userid)
		{
			g_iPlayers[this.Index][Player_ID] = userid;
		}
	}
	
	// Initialise a New Player's Data in the Array
	public void NewPlayer()
	{
		g_iPlayers[this.Index][Player_ID] = this.UserID;
		g_iPlayers[this.Index][Player_Points] = QP_Start;
		g_iPlayers[this.Index][Player_Flags] = PREF_DEFAULT;
	}
	
	
	/**
	 * Plugin Functions
	 * --------------------------------------------------
	 * --------------------------------------------------
	 */
	
	// Add Queue Points
	public void AddPoints(int points)
	{
		g_iPlayers[this.Index][Player_Points] += points;
	}
	
	// Set Queue Points
	public void SetPoints(int points)
	{
		g_iPlayers[this.Index][Player_Points] = points;
	}
	
	// Check Player On Connection
	public void CheckArray()
	{
		// If the player's User ID is not in our array
		if (GetClientUserId(this.Index) != g_iPlayers[this.Index][Player_ID])
		{
			this.NewPlayer();
		}
		
		// If the player wants SourceMod translations in English, set their language
		if (g_iPlayers[this.Index][Player_Flags] & PREF_ENGLISH)
		{
			SetClientLanguage(this.Index, 0);
		}
	}
	
	// Player Has Flag
	public bool HasFlag(int flag)
	{
		return !!(g_iPlayers[this.Index][Player_Flags] & flag);
		// I don't understand it but it worked. https://forums.alliedmods.net/showthread.php?t=319928
	}
	
	// Player Set Flag
	public void AddFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] |= flag;
	}
	
	// Player Remove Flag
	public void RemoveFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] &= ~flag;
	}
	
	// Retrieve Player Data from the Database
	public bool RetrieveData()
	{
		if (g_db != null)
		{
			// Attempt to get the player's database values
			char query[255];
			Format(query, sizeof(query), "SELECT points, flags from %s WHERE steamid=%d", SQLITE_TABLE, this.SteamID);
			DBResultSet result = SQL_Query(g_db, query);
			
			if (result == null)
			{
				LogError("Database query failed for user %L", this.Index);
				CloseHandle(result);
				return false;
			}
			else
			{
				if (SQL_FetchRow(result))	// If record found
				{
					// Store stuff in the array
					g_iPlayers[this.Index][Player_ID] = this.UserID;
					int field;
					result.FieldNameToNum("points", field);
					this.SetPoints(result.FetchInt(field));
					result.FieldNameToNum("flags", field);
					this.Flags = (this.Flags & MASK_SESSION) | (result.FetchInt(field) & MASK_STORED);
						// Keep only the session flags and OR in the stored flags
					DebugMessage("Retrieved stored data for %N: Points %d, flags: %06b", this.Index, this.Points, (this.Flags & MASK_STORED));
					CloseHandle(result);
					return true;
				}
				else
				{
					DebugMessage("%N doesn't have a database record", this.Index);
					return false;
				}
			}
		}
		else
		{
			LogMessage("Database connection not established. Unable to fetch record for %N", this.Index);
			return false;
		}
	}
	

	// Store Player Data in the Database
	public void SaveData()
	{
		char query[255];
		int iLastSeen = GetTime();
		Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, this.Points, (this.Flags & MASK_STORED), iLastSeen, this.SteamID);
		//Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, g_iPoints[client], g_iFlags[client] & FLAGS_DATABASE, GetTime(), GetSteamAccountID(client));
		if (SQL_FastQuery(g_db, query, strlen(query)))
			DebugMessage("Updated %N's data in the database. Points %d, flags %06b, last_seen %d, steamid %d", this.Index, this.Points, (this.Flags & MASK_STORED), iLastSeen, this.SteamID);
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(error));
			LogError("Failed to update database record for %L. Error: %s", this.Index, error);
		}
	}
	
	// Create New Database Record
	public void CreateRecord()
	{
		char query[255];
		Format(query, sizeof(query), "INSERT INTO %s (steamid, points, flags, last_seen) \
		VALUES (%d, %d, %d, %d)", SQLITE_TABLE, this.SteamID, this.Points, (this.Flags & MASK_STORED), GetTime());
		if (SQL_FastQuery(g_db, query))
		{
			DebugMessage("Created a new record for %N", this.Index);
		}
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(error));
			LogError("Unable to create record for %L. Error: %s", this.Index, error);
		}
	}
	
	// Delete Player Database Record
	public void DeleteRecord(int client)
	{
		char query[255];
		Format(query, sizeof(query), "DELETE from %s WHERE steamid=%d", SQLITE_TABLE, this.SteamID);
		if (SQL_FastQuery(g_db, query))
		{
			ShowActivity2(client, "", "%t Deleted %N from the database", "prefix_notice", this.Index);
			LogMessage("%L deleted %L from the database", client, this.Index);
		}
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(error));
			ShowActivity2(client, "", "%t Failed to delete %N from the database", "prefix_notice", this.Index);
			LogError("%L failed to delete %L from the database. Error: %s", client, this.Index, error);
		}
	}
	
	// Check Player TODO Replace with CheckPlayer
	public void Initialize()
	{
		if (this.UserID != this.ArrayUserID)	// If this is a new player
		{
			this.NewPlayer();					// Give them default array values
			
			if (this.SteamID != 0)				// If they are not a bot
			{
				if (!this.RetrieveData())		// If database record exists retrieve it
				{
					this.CreateRecord();		// else create a new one
				}
			}
		}
		
		// If the player wants SourceMod translations in English, set their language TODO Move to OnClientAuth forward
		if (this.Flags & PREF_ENGLISH)
		{
			// If the PREF_ENGLISH bit is found in player.Flags return true
			SetClientLanguage(this.Index, 0);
		}
	}
	
	// Stuff On Player Disconnect TODO Move to forward
	public void OnDisconnect()
	{
		if (!this.InGame)
			return;
	
		if (g_cUseSQL.BoolValue && g_db != null && this.SteamID != 0)	// Database handle exists and the user is not a bot
		{
			this.SaveData();
		}
	}
	
	// Welcome Player TODO Move to OnCLientAuth forward
	public void Welcome()
	{
		if (this.Flags & SESSION_WELCOMED)
			// If AND finds the bit in that position it will return true
		{
			return;
		}
		
		char sName[64];
		GetClientName(this.Index, sName, sizeof(sName));
		PrintToChat(this.Index, "%t %t", "prefix_notice", "welcome player to deathrun toolkit", sName);
		this.Flags |= SESSION_WELCOMED;
			// |= adds the bit value to the variable
	}
	
	// Scale Health Based on Red Players Remaining
	public void ScaleHealth(int mode = 6, int value = -1)
	{
		float base = (value == -1) ? HEALTH_SCALE_BASE : float(value);
		float percentage = 1.0;
		float health = float(this.MaxHealth);
		float largehealthkit = float(this.MaxHealth);
		int count = DTK_CountPlayers(Team_Red, LifeState_Alive);
	
		for (int i = 2; i <= count; i++)
		{
			health += (base * percentage);
			percentage *= 1.15;
		}

		// TODO Don't do any of this if the health has not been scaled
		if (mode > 2)
		{
			this.SetMaxHealth(health);
			//if (g_bTF2Attributes) TF2Attrib_SetByName(this.Index, "health from packs decreased", largehealthkit / health);
			AddPlayerAttribute(this.Index, "health from packs decreased", largehealthkit / health);
		}
		this.SetHealth(RoundToNearest(health));
		//TF2Attrib_SetByName(this.Index, "cannot be backstabbed", 1.0); // This is a weapon attr
		
		/*
			Modes
			-----
			
			1. Overheal and multiply internal value
			2. Overheal and multiply set value
			3. Overheal and multiply based on max health
			4. Expand pool to a multiple of internal value
			5. Expand pool to a multiple of set value
			6. Expand pool to a multiple of max health
			
			Back stab
			Fall damage
		*/
		
		PrintToChatAll("%t %N's health has been scaled up to %0.f", "prefix_notice", this.Index, health);
	}
}