/**
 * Methodmaps
 * ----------------------------------------------------------------------------------------------------
 */



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
			if (g_iGame == Game_TF)
				return (GameRules_GetRoundState() == RoundState_Stalemate);
			if (g_iGame == Game_OF)
			{
				//PrintToServer("%s Round is %s", SERVERMSG_PREFIX, (g_bRoundActive) ? "active" : "not active");
				return g_bRoundActive;
			}
			else return false;
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
				PrintToServer("%s Database connection established. Handle is %x", SERVERMSG_PREFIX, g_db);
				
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
		while ((i = FindEntityByClassname(i, "math_counter")) != -1)
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
		while ((i = FindEntityByClassname(i, "logic_relay")) != -1)
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



/**
 * Player
 * ----------------------------------------------------------------------------------------------------
 */
methodmap Player < Handle
{
	public Player(int player)
	{
		return view_as<Player>(player);
	}
	
	/**
	 * Get the player's client entity index,
	 * 
	 * @return	int	Entity index of the player.
	 */
	property int Index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	/**
	 * Get the players User ID number. This is the one the server gives to the player when they connect.
	 * The ID is unique to the player's server session They lose it when they disconnect.
	 * 
	 * @return	int	
	 */
	property int UserID
	{
		public get()
		{
			if (IsClientConnected(this.Index))
				return GetClientUserId(this.Index);
			else
				return 0;
		}
	}
	
	/**
	 * Get the player's Steam account ID. This is the short form unique number with no special characters.
	 * 
	 * @return	int	Steam account ID
	 */
	property int SteamID
	{
		public get()
		{
			if (IsClientConnected(this.Index))
				return GetSteamAccountID(this.Index);
			else
				return 0;
		}
	}
	
	

	/**
	 * Get the player's queue points.
	 * 
	 * @return	int	Queue points.
	 */
	property int Points
	{
		public get()
		{
			return g_iPlayerData[this.Index][Player_Points];
		}
	}
	
	/**
	 * Get or set the player's DTK bit flags. This is a single cell of up to 32 bits.
	 * 
	 * @param	int	Bit flags.
	 * @return	int	Bit flags.
	 */
	property int Flags
	{
		public get()
		{
			return g_iPlayerData[this.Index][Player_Flags];
		}
		public set(int flags)
		{
			g_iPlayerData[this.Index][Player_Flags] = flags;
		}
	}
	
	/**
	 * Get the player's User ID from the player data array.
	 * 
	 * @return	int	User ID
	 */
	property int ArrayUserID
	{
		public get()
		{
			return g_iPlayerData[this.Index][Player_ID];
		}
	}
	
	/**
	 * Get the client's team number.
	 * 
	 * @return	int	
	 */
	property int Team
	{
		public get()
		{
			return GetClientTeam(this.Index);
		}
	}
	
	/**
	 * Get the player's TFClassType class.
	 * 
	 * @return	TFClassType	Player's TF class.
	 */
	property TFClassType Class 
	{
		public get()
		{
			return TF2_GetPlayerClass(this.Index);
		}
	}
	
	/**
	 * See if the player is connected to the server.
	 * 
	 * @return	bool	Is client connected?	
	 */
	property bool IsConnected
	{
		public get()
		{
			return IsClientConnected(this.Index);
		}
	}
	
	/**
	 * See if the player is in game.
	 * 
	 * @return	bool	is the client in game?	
	 */
	property bool InGame
	{
		public get()
		{
			return IsClientInGame(this.Index);
		}
	}
	
	/**
	 * See if the player is an observer (spectating a target).
	 * 
	 * @return	bool	Is the client an observer?	
	 */
	property bool IsObserver
	{
		public get()
		{
			return IsClientObserver(this.Index);
		}
	}
	
	/**
	 * See if the player is in the game and alive.
	 * This function works by checking if the player is an observer.
	 * This function may need to be changed if a map doesn't use Arena mode and allows natural respawning.
	 * 
	 * @return	bool	Is the client alive (not an observer)?	
	 */
	property bool IsAlive
	{
		public get()
		{
			if (this.InGame)
				return (!this.IsObserver);
				//return (IsPlayerAlive(this.Index));
			else
				return false;
		}
	}
	
	/**
	 * Is the client in the game and on a playing team? Spectators don't count.
	 * 
	 * @return	bool	is the player participating?	
	 */
	property bool IsParticipating
	{
		public get()
		{
			if (this.InGame)
				return (this.Team == Team_Red || this.Team == Team_Blue);
			else
				return false;
		}
	}
	
	/**
	 * If the client is in game, get their health value.
	 * If not, return 0.
	 * 
	 * @return	int	Player's health. 0 if not in game.
	 */
	property int Health
	{
		public get()
		{
			if (this.InGame)
				return GetClientHealth(this.Index);
			else
				return 0;
		}
	}
	
	/**
	 * If the player is in-game and we have found our player resource manager entity,
	 * get the player's max health from that entity. If not in game, returns 0.
	 * If calling this from an event hook you should use RequestFrame to give it chance to update.
	 * TODO Will it be up to date if we get this from the player's data map instead?
	 * 
	 * @return	int	Max health. 0 if not in game.
	 */
	property int MaxHealth
	{
		public get()
		{
			if (this.InGame && g_iHealthBar[HealthBar_PlayerResource] != -1)
				return GetEntProp(g_iHealthBar[HealthBar_PlayerResource], Prop_Send, "m_iMaxHealth", _, this.Index);
			else
				return 0;
		}
	}
	

	
	/**
	 * Player Array
	 * --------------------------------------------------
	 */
	
	/**
	 * Set the value of the User ID cell for the player in the data array.
	 * 
	 * @param	int	User ID.
	 * @noreturn
	 */
	public void SetUserID(int userid)
	{
		g_iPlayerData[this.Index][Player_ID] = userid;
	}
	
	/**
	 * Give a player the default array values. This is used when a new player joins the server.
	 * 
	 * @noreturn	
	 */
	public void ResetData()
	{
		g_iPlayerData[this.Index][Player_ID] = this.UserID;
		g_iPlayerData[this.Index][Player_Points] = Points_Starting;
		g_iPlayerData[this.Index][Player_Flags] = FLAGS_DEFAULT;
			// Assigning FLAGS_DEFAULT to the variable replaces the value
	}
	
	/**
	 * Set a player's queue points value in the data array.
	 * 
	 * @noreturn
	 */
	public void SetPoints(int points)
	{
		g_iPlayerData[this.Index][Player_Points] = points;
	}
	
	/**
	 * Add a value to the player's queue points array value. 
	 * 
	 * @noreturn
	 */
	public void AddPoints(int points)
	{
		g_iPlayerData[this.Index][Player_Points] += points;
	}
	
	/**
	 * Retrieve a player's data from the database.
	 * Returns true if the player has a record, and stores the values in the array.
	 * Returns false if they do not have a record, or if the database connection is not established,
	 * or if the query failed.
	 * 
	 * @return	bool	Successful retrieval of player data.
	 */
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
					this.SetUserID(this.UserID);
					int field;
					result.FieldNameToNum("points", field);
					this.SetPoints(result.FetchInt(field));
					result.FieldNameToNum("flags", field);
					this.Flags = (this.Flags & FLAGS_SESSION) | (result.FetchInt(field) & FLAGS_STORED);
						// Keep only the session flags and OR in the stored flags
					DebugMessage("Retrieved stored data for %N: Points %d, flags: %06b", this.Index, this.Points, (this.Flags & FLAGS_STORED));
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
	
	/**
	 * Save the player's array data in the database.
	 * 
	 * @noreturn
	 */
	public void SaveData()
	{
		char query[255];
		int iLastSeen = GetTime();
		Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, this.Points, (this.Flags & FLAGS_STORED), iLastSeen, this.SteamID);
		//Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, g_iPoints[client], g_iFlags[client] & FLAGS_DATABASE, GetTime(), GetSteamAccountID(client));
		if (SQL_FastQuery(g_db, query, strlen(query)))
			DebugMessage("Updated %N's data in the database. Points %d, flags %06b, last_seen %d, steamid %d", this.Index, this.Points, (this.Flags & FLAGS_STORED), iLastSeen, this.SteamID);
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(error));
			LogError("Failed to update database record for %L. Error: %s", this.Index, error);
		}
	}
	
	/**
	 * Create a new database record for a player.
	 * 
	 * @noreturn
	 */
	public void CreateRecord()
	{
		char query[255];
		Format(query, sizeof(query), "INSERT INTO %s (steamid, points, flags, last_seen) \
		VALUES (%d, %d, %d, %d)", SQLITE_TABLE, this.SteamID, this.Points, (this.Flags & FLAGS_STORED), GetTime());
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
	
	/**
	 * Remove a player's record from the database. We won't be able to store their array data at map
	 * end if the record doesn't exist. When a new map begins, a new record will be created.
	 * TODO Split this off to a separate function and allow the use of a Steam ID as an argument
	 * 
	 * @noreturn
	 */
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
	
	/**
	 * Check if a player was on the last map. If they weren't, give them default array values
	 * and attempt to retrieve their database values. If they don't have a record, create one for them.
	 * Only players with a valid Steam ID (not a bot) will be saved in the database.
	 * TODO Change the name of this function to something more suitable
	 * 
	 * @noreturn
	 */
	public void Initialize()
	{
		if (this.UserID != this.ArrayUserID)	// If this is a new player
		{
			this.ResetData();					// Give them default array values
			
			if (this.SteamID != 0)				// If they are not a bot
			{
				if (!this.RetrieveData())		// If database record exists retrieve it
				{
					this.CreateRecord();		// else create a new one
				}
			}
		}
		
		// If the player wants SourceMod translations in English, set their language
		if (this.Flags & FLAGS_ENGLISH)
		{
			// If the FLAGS_ENGLISH bit is found in player.Flags return true
			SetClientLanguage(this.Index, 0);
		}
	}
	
	/**
	 * When the player disconnects, attempt to save their data in the database.
	 * 
	 * @noreturn
	 */
	public void OnDisconnect()
	{
		if (!this.InGame)
			return;
	
		if (g_cUseSQL.BoolValue && g_db != null && this.SteamID != 0)	// Database handle exists and the user is not a bot
		{
			this.SaveData();
		}
	}
	
	/**
	 * If the player has just joined the server, welcome them. Set their session
	 * welcomed flag so they don't get welcomed again until the next time they join.
	 * 
	 * @noreturn
	 */
	public void Welcome()
	{
		if (this.Flags & FLAGS_WELCOMED)
			// If AND finds the bit in that position it will return true
		{
			return;
		}
		
		char sName[64];
		GetClientName(this.Index, sName, sizeof(sName));
		PrintToChat(this.Index, "%t %t", "prefix_notice", "welcome player to deathrun toolkit", sName);
		this.Flags |= FLAGS_WELCOMED;
			// |= adds the bit value to the variable
	}
	
	
	/**
	 * Do Stuff to Players
	 * --------------------------------------------------
	 */
	
	/**
	 * Set the player's team number and respawn them. Optionally do not respawn them.
	 * In Open Fortress, we can't yet respawn individual players so we must instead create a 
	 * game_forcerespawn entity and respawn all players. It's not ideal.
	 * 
	 * @param	int	Team number.
	 * @param	bool	Respawn the player (default is true).
	 * @noreturn
	 */
	public void SetTeam(int team, bool respawn=true)
	{
		if (g_iGame == Game_OF)
			respawn = false;
		
		if (respawn) SetEntProp(this.Index, Prop_Send, "m_lifeState", LifeState_Dead);
		ChangeClientTeam(this.Index, team);
		if (respawn) SetEntProp(this.Index, Prop_Send, "m_lifeState", LifeState_Alive);
		if (respawn) TF2_RespawnPlayer(this.Index);
		
		DebugMessage("Moved %N to team %d %s", this.Index, team, (respawn) ? "and respawned them" : "");
		
		// If running in Open Fortress, respawn all players
		if (g_iGame == Game_OF)
		{
			int respawn_ent = CreateEntityByName("game_forcerespawn");
			if (respawn_ent == -1)
			{
				LogError("Unable to create game_forcerespawn");
			}
			else
			{
				if (!DispatchSpawn(respawn_ent))
				{
					LogError("Unable to spawn game_forcerespawn");
				}
				else
				{
					if (!AcceptEntityInput(respawn_ent, "ForceRespawn"))
					{
						LogError("game_forcerespawn wouldn't accept our ForceRespawn input");
					}
					else
					{
						DebugMessage("Respawned all players by creating a game_forcerespawn");
					}
				}
				
				RemoveEdict(respawn_ent);
			}
		}
	}
	
	/**
	 * Set a player's glow
	 * I don't use this anymore because outlines are a crutch for bad map design.
	 * They ruin mini games where the red team has to hide.
	 * 
	 * @noreturn
	 */
/*	public void SetGlow(bool glow=true)
	{
		SetEntProp(this.Index, Prop_Send, "m_bGlowEnabled", (glow) ? 1 : 0, 1);
		
		DebugMessage("Made %N %s", this.Index, glow ? "glow" : "stop glowing");
	}
*/
	
	/**
	 * Temporarily change a player's class.
	 * 
	 * @param	TFClassType	Class.
	 * @noreturn
	 */
	public bool SetClass(TFClassType class, bool regenerate=true)
	{
		TF2_SetPlayerClass(this.Index, class, _, false);
		if (this.IsAlive)	// Don't regen a dead player or they'll go to limbo
		{
			if (regenerate) TF2_RegeneratePlayer(this.Index);
			if (g_cEnabled.BoolValue) ApplyPlayerAttributes(this);
		}
	}
	
	/**
	 * Set the player's health directly.
	 * 
	 * @param	int	Health.
	 * @noreturn
	 */
	public void SetHealth(int health)
	{
		SetEntProp(this.Index, Prop_Send, "m_iHealth", health, 4);
	}
	
	/**
	 * Set the player's maximum health. This is not as simple as changing a property.
	 * If the client is not in game or the player resource entity was not found, nothing happens.
	 * If the value we're setting it to is lower than their existing max health, nothing happens.
	 * Otherwise, we achieve this by giving the player a TF2 attribute which bumps their health pool. 
	 * 
	 * @param	float	Max health.
	 * @noreturn
	 */
	public void SetMaxHealth(float health)
	{
		if (this.InGame && g_iHealthBar[HealthBar_PlayerResource] != -1)
		{
			//if (health < this.MaxHealth)
			//	return;
			
			/*if (!g_bTF2Attributes)
			{
				LogError("Couldn't scale %N's max health because TF2 Attributes doesn't seem to be loaded", this.Index);
				ShowActivity(0, "Couldn't scale %N's max health because TF2 Attributes doesn't seem to be loaded", this.Index);
				return;
			}*/

			//TF2Attrib_SetByName(this.Index, "max health additive bonus", health - this.MaxHealth);
			DTK_AddPlayerAttribute(this.Index, "max health additive bonus", health - this.MaxHealth);
			//SetEntProp(g_iHealthBar[HealthBar_PlayerResource], Prop_Send, "m_iMaxHealth", health, _, this.Index);
			DebugMessage("Set %N's max health to %0.f", this.Index, health);
			if (g_bSCR && g_cSCR.BoolValue)
				SCR_SendEvent(SERVERMSG_PREFIX, "Set %N's max health to %0.f", this.Index, health);
		}
	}
	
	/**
	 * Scale the player's health and max health based on the number of red players alive.
	 * 
	 * @param	int
	 * @param	int
	 * @noreturn
	 */
	public void ScaleHealth(int mode=6, int value=-1)
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
			DTK_AddPlayerAttribute(this.Index, "health from packs decreased", largehealthkit / health);
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
	
	/**
	 * Hook a player's damage for use by the health bar and blast pushing reduction.
	 * 
	 * @noreturn
	 */
	public void HookDamage()
	{
		if (g_iGame != Game_OF)
		{
			SDKHook(this.Index, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
		}
	}
	
	/**
	 * Set a player's speed in u/s. Not supplying a value resets it
	 * TODO Add this if necessary.
	 * 
	 * @noreturn
	 */
	public void SetSpeed(int speed=0)
	{
		//if (speed > 0)
		// set to a speed in u/s
		//else
		// set to class default speed according to cvars
		
		int iRunSpeeds[] =
		{
			RunSpeed_NoClass,
			RunSpeed_Scout,
			RunSpeed_Sniper,
			RunSpeed_Soldier,
			RunSpeed_DemoMan,
			RunSpeed_Medic,
			RunSpeed_Heavy,
			RunSpeed_Pyro,
			RunSpeed_Spy,
			RunSpeed_Engineer
		};
		
		if (speed == 0)
		{
			DTK_RemovePlayerAttribute(this.Index, "CARD: move speed bonus");
		}
		else
		{
			DTK_AddPlayerAttribute(this.Index, "CARD: move speed bonus", speed / (iRunSpeeds[this.Class] + 0.0));
		}
	}

	/**
	 * Get the entity index of the player's weapon. 
	 * BUG This may return -1 if called too soon after spawning. Not sure.
	 * 
	 * @param	int	Weapon slot number.
	 * @return	int	Weapon entity index. -1 if no player or weapon.
	 */
	public int GetWeapon(int slot=TFWeaponSlot_Primary)
	{
		if (this.InGame)
			return GetPlayerWeaponSlot(this.Index, slot);
		else
			return -1;
	}
	
	/**
	 * Make a player switch weapon to a specified slot.
	 * 
	 * @param	int	Weapon slot.
	 * @noreturn
	 * @error	Can't find the weapon in the specified slot.
	 */
	public void SetSlot(int slot=TFWeaponSlot_Primary)
	{
		if (this.GetWeapon(slot) == -1)
		{
			ThrowError("Can't find %N's weapon in slot %d when trying to call SetSlot", this.Index, slot);
			//LogError("Can't find %N's weapon in slot %d when trying to call SetSlot", this.Index, slot);
			//return;
		}
		
		char sClassname[64];
		GetEntityClassname(this.GetWeapon(slot), sClassname, sizeof(sClassname));
		FakeClientCommandEx(this.Index, "use %s", sClassname);
		SetEntProp(this.Index, Prop_Send, "m_hActiveWeapon", this.GetWeapon(slot));
	}
	
	/**
	 * Force the player to switch to their melee weapon and prevent them switching away.
	 * If the first parameter is false, return the other weapons if they do not exist,
	 * remove the switching restriction and switch them to their primary weapon.
	 * TODO: Find out which slot Open Fortress melee weapon lives in.
	 * 
	 * @param	bool	Switch to melee and prevent switching away or return to normal.
	 * @param	bool	Remove the player's primary and secondary weapons.
	 * @noreturn
	 */
	public void MeleeOnly(bool meleeonly=true, bool remove=false)
	{
		if (!this.InGame || g_iGame != Game_TF)
			return;
		
		if (meleeonly)
		{
			TF2_AddCondition(this.Index, TFCond_RestrictToMelee, TFCondDuration_Infinite);
			this.SetSlot(TFWeaponSlot_Melee);
			
			if (remove)
			{
				TF2_RemoveWeaponSlot(this.Index, TFWeaponSlot_Primary);
				TF2_RemoveWeaponSlot(this.Index, TFWeaponSlot_Secondary);
			}
			
			DebugMessage("Restricted %N to melee %s", this.Index, (remove) ? "and removed their other weapons" : "");
		}
		else
		{
			if (this.GetWeapon(TFWeaponSlot_Primary) == -1 || this.GetWeapon(TFWeaponSlot_Secondary) == -1)
			{
				int health = this.Health;			// Temporarily store the player's health
				TF2_RegeneratePlayer(this.Index);
				this.SetHealth(health);				// Gve the player back their previous health
			}
			
			TF2_RemoveCondition(this.Index, TFCond_RestrictToMelee);
			this.SetSlot();
			
			DebugMessage("Removed %N's melee-only restriction %s", this.Index, (remove) ? "and respawned their other weapons" : "");
		}
	}
}