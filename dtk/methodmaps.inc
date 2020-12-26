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
	
	// Game Has Flag
	public bool HasFlag(int flag)
	{
		return !!(g_iGameState & flag);
	}
	
	// Game Add Flag
	public void AddFlag(int flag)
	{
		g_iGameState |= flag;
	}
	
	// Game Remove Flag
	public void RemoveFlag(int flag)
	{
		g_iGameState &= ~flag;
	}
	
	// Game Set Flags
	public void SetFlags(int flags)
	{
		g_iGameState = flags;
	}
	
	// Game Set Hame
	public void SetGame(int flag)
	{
		g_iGame = flag;
	}
	
	// Game Is Game
	public bool IsGame(int flag)
	{
		return !!(g_iGame & flag);
	}
	
	// Health Bar Active
	property bool IsHealthBarActive
	{
		public get()
		{
			return this.HasFlag(FLAG_HEALTH_BAR_ACTIVE);
		}
	}
	
	// Set Health Bar Active
	public void SetHealthBarActive(bool active)
	{
		if (active)
			this.AddFlag(FLAG_HEALTH_BAR_ACTIVE);
		else
			this.RemoveFlag(FLAG_HEALTH_BAR_ACTIVE);
	}
	
	// Round State
	property int RoundState
	{
		public get()
		{
			return g_iRoundState;
		}
		public set(int state)
		{
			g_iRoundState = state;
			Debug("Round state has been set to %d", state);
		}
	}
	
	// Count Reds
	property int Reds
	{
		public get()
		{
			return GetTeamClientCount(Team_Red);
		}
	}
	
	// Count Alive Reds
	property int AliveReds
	{
		public get()
		{
			int count;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == Team_Red && IsPlayerAlive(i))
					count++;
			}
			
			return count;
		}
	}
	
	// Count Blues
	property int Blues
	{
		public get()
		{
			return GetTeamClientCount(Team_Blue);
		}
	}
	
	// Count Alive Blues
	property int AliveBlues
	{
		public get()
		{
			int count;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == Team_Blue && IsPlayerAlive(i))
					count++;
			}
			
			return count;
		}
	}
	
	// Count Participants
	property int Participants
	{
		public get()
		{
			return (GetTeamClientCount(Team_Blue) + GetTeamClientCount(Team_Red));
		}
	}
}

Game game;							// Game logic




methodmap Player < BasePlayer
{
	public Player(int client)
	{
		return view_as<Player>(client);
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
	
	// Is Runner
	property bool IsRunner
	{
		public get()
		{
			if (g_iPlayers[this.Index][Player_Flags] & FLAG_RUNNER)
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
			if (g_iPlayers[this.Index][Player_Flags] & FLAG_ACTIVATOR)
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
			return g_iPlayers[this.Index][Player_UserID];
		}
		public set(int userid)
		{
			g_iPlayers[this.Index][Player_UserID] = userid;
		}
	}
	
	// Initialise a New Player's Data in the Array
	public void NewPlayer()
	{
		g_iPlayers[this.Index][Player_UserID] = this.UserID;
		g_iPlayers[this.Index][Player_Points] = QP_Start;
		g_iPlayers[this.Index][Player_Flags] = MASK_NEW_PLAYER;
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
		if (GetClientUserId(this.Index) != g_iPlayers[this.Index][Player_UserID])
		{
			this.NewPlayer();
		}
		
		// If the player wants SourceMod translations in English, set their language
		if (g_iPlayers[this.Index][Player_Flags] & FLAG_PREF_ENGLISH)
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
	
	// Player Add Flag
	public void AddFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] |= flag;
	}
	
	// Player Remove Flag
	public void RemoveFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] &= ~flag;
	}
	
	// Player Set Flags
	public void SetFlags(int flags)
	{
		g_iPlayers[this.Index][Player_Flags] = flags;
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
					g_iPlayers[this.Index][Player_UserID] = this.UserID;
					int field;
					result.FieldNameToNum("points", field);
					this.SetPoints(result.FetchInt(field));
					result.FieldNameToNum("flags", field);
					this.Flags = (this.Flags & MASK_SESSION_FLAGS) | (result.FetchInt(field) & MASK_STORED_FLAGS);
						// Keep only the session flags and OR in the stored flags
					Debug("Retrieved stored data for %N: Points %d, flags: %06b", this.Index, this.Points, (this.Flags & MASK_STORED_FLAGS));
					CloseHandle(result);
					return true;
				}
				else
				{
					Debug("%N doesn't have a database record", this.Index);
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
		Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, this.Points, (this.Flags & MASK_STORED_FLAGS), iLastSeen, this.SteamID);
		//Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, g_iPoints[client], g_iFlags[client] & FLAGS_DATABASE, GetTime(), GetSteamAccountID(client));
		if (SQL_FastQuery(g_db, query, strlen(query)))
			Debug("Updated %N's data in the database. Points %d, flags %06b, last_seen %d, steamid %d", this.Index, this.Points, (this.Flags & MASK_STORED_FLAGS), iLastSeen, this.SteamID);
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
		VALUES (%d, %d, %d, %d)", SQLITE_TABLE, this.SteamID, this.Points, (this.Flags & MASK_STORED_FLAGS), GetTime());
		if (SQL_FastQuery(g_db, query))
		{
			Debug("Created a new record for %N", this.Index);
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
	
	// Check Player
	public void CheckPlayer()
	{
		if (this.UserID != this.ArrayUserID)	// If this is a new player
		{
			this.NewPlayer();					// Give them default array values
			
			if (!this.IsBot)					// If they are not a bot
			{
				if (!this.RetrieveData())		// If database record exists retrieve it
				{
					this.CreateRecord();		// else create a new one
				}
			}
		}
		
		if (this.HasFlag(FLAG_PREF_ENGLISH))
			SetClientLanguage(this.Index, 0);
	}
	
	// Scale Health Based on Red Players Remaining
	public void ScaleHealth(int mode = 6, int value = -1)
	{
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
			//if (g_bTF2Attributes) TF2Attrib_SetByName(this.Index, "health from packs decreased", largehealthkit / health);
			AddAttribute(this.Index, "health from packs decreased", largehealthkit / health);
		}
		this.SetHealth(RoundToNearest(health));
		//TF2Attrib_SetByName(this.Index, "cannot be backstabbed", 1.0); // This is a weapon attr
		
		/*
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
		
		ChatMessageAll(Msg_Normal, "%N's health has been scaled up to %0.f", this.Index, health);
	}
	
	// Update Health Bar
	public void UpdateHealthBar()
	{
		SetHealthBar(this.Health, this.MaxHealth, this.Index);
	}
}