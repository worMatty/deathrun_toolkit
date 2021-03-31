/**
 * Methodmaps
 * ----------------------------------------------------------------------------------------------------
 */

#include	"dtk/player.sp"

// Round State
enum {
	Round_Waiting,
	Round_Freeze,
	Round_Active,
	Round_Win
}

// Game Flags
enum {
	GF_LateLoad = 0x1,				// Plugin was loaded late/reloaded
	GF_HPBarActive = 0x2,			// The boss bar is on-screen
	GF_WatchMode = 0x4,				// We're in team watch mode during pre-round freeze time
	GF_Restarting = 0x8				// Counting down to round restart (OF)
}


/**
 * Game
 * ----------------------------------------------------------------------------------------------------
 */
methodmap Game
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
		//PrintToServer("%s Game flag added: %d", PREFIX_DEBUG, flag);
	}
	
	// Game Remove Flag
	public void RemoveFlag(int flag)
	{
		g_iGameState &= ~flag;
		//PrintToServer("%s Game flag removed: %d", PREFIX_DEBUG, flag);
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
	property bool IsBossBarActive
	{
		public get()
		{
			return this.HasFlag(GF_HPBarActive);
		}
		public set(bool set)
		{
			if (set)
			{
				this.AddFlag(GF_HPBarActive);
			}
			else
			{
				this.RemoveFlag(GF_HPBarActive);
			}
		}
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
			Debug("Round state set to %d", state);
		}
	}
	
	// In Watch Mode
	property bool InWatchMode
	{
		public get()
		{
			return this.HasFlag(GF_WatchMode);
		}
		public set(bool set)
		{
			if (set)
			{
				this.AddFlag(GF_WatchMode);
				Debug("Watch Mode ENABLED");
			}
			else
			{
				this.RemoveFlag(GF_WatchMode);
				Debug("Watch Mode DISABLED");
			}
		}
	}
	
	// Count Reds
	/*
	property int Reds
	{
		public get()
		{
			return GetTeamClientCount(Team_Red);
		}
	}
	*/
	
	// Count Alive Reds
	/*
	property int AliveReds
	{
		public get()
		{
			int count;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == Team_Red && GetEntProp(i, Prop_Send, "m_lifeState") == LifeState_Alive)
					count++;
			}
			
			return count;
		}
	}
	*/
	
	// Count Blues
	/*
	property int Blues
	{
		public get()
		{
			return GetTeamClientCount(Team_Blue);
		}
	}
	*/
	
	// Count Alive Blues
	/*
	property int AliveBlues
	{
		public get()
		{
			int count;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == Team_Blue && GetEntProp(i, Prop_Send, "m_lifeState") == LifeState_Alive)
					count++;
			}
			
			return count;
		}
	}
	*/
	
	// Count Participants
	property int Participants
	{
		public get()
		{
			return (GetTeamClientCount(Team_Blue) + GetTeamClientCount(Team_Red));
		}
	}
	
	// Willing Activators
	property int WillingActivators
	{
		public get()
		{
			int willing;
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && (GetClientTeam(i) == Team_Red || GetClientTeam(i) == Team_Blue) && g_iPlayers[i][Player_Flags] & (PF_PrefActivator))
				{
					willing += 1;
				}
			}
			
			return willing;
		}
	}
	
	// Activator Pool
	property int ActivatorPool
	{
		public get()
		{
			return (this.WillingActivators < MINIMUM_WILLING) ? this.Participants : this.WillingActivators;
		}
	}
	
	// Activators
	property int Activators
	{
		public get()
		{
			return g_Activators.Length;
		}
	}
	
	// Live Activators
	property int AliveActivators
	{
		public get()
		{
			int len = g_Activators.Length;
			int count;
			
			for (int i = 0; i < len; i++)
			{
				BasePlayer player = BasePlayer(g_Activators.Get(i));
				
				if (player.IsAlive)
					count++;
			}
			
			return count;
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
			if (g_iPlayers[this.Index][Player_Flags] & PF_Runner)
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
			return !!(g_iPlayers[this.Index][Player_Flags] & PF_Activator);
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
	
	// Last time player was activator
	property int ActivatorLast
	{
		public get()
		{
			return g_iPlayers[this.Index][Player_ActivatorLast];
		}
		public set(int time)
		{
			g_iPlayers[this.Index][Player_ActivatorLast] = time;
		}
	}
	
	// Initialise a New Player's Data in the Array
	public void NewPlayer()
	{
		g_iPlayers[this.Index][Player_UserID] = this.UserID;
		g_iPlayers[this.Index][Player_Points] = QP_Start;
		g_iPlayers[this.Index][Player_Flags] = MASK_NEW_PLAYER;
		this.ActivatorLast = GetTime();
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
	
	/*
	// Check Player On Connection
	public void CheckArray()
	{
		// If the player's User ID is not in our array
		if (GetClientUserId(this.Index) != g_iPlayers[this.Index][Player_UserID])
		{
			this.NewPlayer();
		}
		
		// If the player wants SourceMod translations in English, set their language
		if (g_iPlayers[this.Index][Player_Flags] & PF_PrefEnglish)
		{
			SetClientLanguage(this.Index, 0);
		}
	}
	*/
	
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
	
	// Make Activator
	public void MakeActivator()
	{
		this.AddFlag(PF_Activator);
		int index = g_Activators.Push(this);
		g_Activators.Set(index, this.Health, AL_Health);
		g_Activators.Set(index, this.MaxHealth, AL_MaxHealth);
	}
	
	// Unmake Activator
	public void UnmakeActivator()
	{
		this.RemoveFlag(PF_Activator);
		int index = g_Activators.FindValue(this);
		if (index != -1) g_Activators.Erase(index);
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
					//Debug("Retrieved stored data for %N: Points %d, flags: %06b", this.Index, this.Points, (this.Flags & MASK_STORED_FLAGS));
					CloseHandle(result);
					return true;
				}
				else
				{
					//Debug("%N doesn't have a database record", this.Index);
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
		if (!SQL_FastQuery(g_db, query, strlen(query)))
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
		if (!SQL_FastQuery(g_db, query))
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
			ShowActivity(client, "Deleted %N from the database", this.Index);
			LogMessage("%L deleted %L from the database", client, this.Index);
		}
		else
		{
			char error[255];
			SQL_GetError(g_db, error, sizeof(error));
			ShowActivity(client, "Failed to delete %N from the database", this.Index);
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
		
		if (this.HasFlag(PF_PrefEnglish))
			SetClientLanguage(this.Index, 0);
	}
}