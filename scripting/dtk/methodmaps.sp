
// Life States
enum {
	LifeState_Alive,		// alive
	LifeState_Dying,		// playing death animation or still falling off of a ledge waiting to hit ground
	LifeState_Dead,			// dead. lying still.
	LifeState_Respawnable,
	LifeState_DiscardBody,
}

// Classes
enum {
	Class_Unknown,
	Class_Scout,
	Class_Sniper,
	Class_Soldier,
	Class_DemoMan,
	Class_Medic,
	Class_Heavy,
	Class_Pyro,
	Class_Spy,
	Class_Engineer,
	Class_Merc = 10,
	Class_Civ = 10
}

// Teams
enum {
	Team_None,
	Team_Spec,
	Team_Red,
	Team_Blue
}

// Weapon Slots
enum {
	Weapon_Primary,
	Weapon_Secondary,
	Weapon_Melee,
	Weapon_Grenades,
	Weapon_Building,
	Weapon_PDA,
	Weapon_ArrayMax
}

// Ammo Types
enum {
	Ammo_Dummy,
	Ammo_Primary,
	Ammo_Secondary,
	Ammo_Metal,
	Ammo_Grenades1,		// Thermal Thruster fuel
	Ammo_Grenades2
}

// Round State
enum {
	Round_Waiting,
	Round_Freeze,
	Round_Active,
	Round_Win
}

char g_sRoundStates[][] = {
	"ROUND WAITING",
	"ROUND FREEZE",
	"ROUND ACTIVE",
	"ROUND WIN"
};

// Game Flags
enum {
	GF_LateLoad = 0x1,				// Plugin was loaded late/reloaded
	GF_HPBarActive = 0x2,			// The boss bar is on-screen
	GF_WatchMode = 0x4,				// We're in team watch mode during pre-round freeze time
	GF_Restarting = 0x8				// Counting down to round restart (OF)
}






methodmap Player
{
	public Player(int client)
	{
		return view_as<Player>(client);
	}
	
	property int Index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	property int UserID
	{
		public get()
		{
			return GetClientUserId(view_as<int>(this));
		}
	}
	
	property int Serial
	{
		public get()
		{
			return GetClientSerial(view_as<int>(this));
		}
	}
	
	property int SteamID
	{
		public get()
		{
			return GetSteamAccountID(view_as<int>(this));
		}
	}
	
	property bool IsValid
	{
		public get()
		{
			return (view_as<int>(this) > 0 && view_as<int>(this) <= MaxClients);
		}
	}
	
	property bool IsConnected
	{
		public get()
		{
			return IsClientConnected(view_as<int>(this));
		}
	}
	
	property bool InGame
	{
		public get()
		{
			return IsClientInGame(view_as<int>(this));
		}
	}

	property bool IsObserver
	{
		public get()
		{
			return IsClientObserver(view_as<int>(this));
		}
	}
	
	property bool IsBot
	{
		public get()
		{
			return IsFakeClient(view_as<int>(this));
		}
	}
	
	property bool IsAlive
	{
		public get()
		{
			return (GetEntProp(view_as<int>(this), Prop_Send, "m_lifeState") == LifeState_Alive);
		}
		public set(bool alive)
		{
			SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", (alive) ? LifeState_Alive : LifeState_Dead);
		}
	}
	
	property bool IsParticipating
	{
		public get()
		{
			return (GetClientTeam(view_as<int>(this)) == Team_Red || GetClientTeam(view_as<int>(this)) == Team_Blue);
		}
	}
	
	property bool IsAdmin
	{
		public get()
		{
			return (view_as<int>(this) == 0) || (GetUserAdmin(view_as<int>(this)) != INVALID_ADMIN_ID);
		}
	}
	
	property int Team
	{
		public get()
		{
			return GetClientTeam(view_as<int>(this));
		}
	}
	
	property int Class
	{
		public get()
		{
			return GetEntProp(view_as<int>(this), Prop_Send, "m_iClass");
		}
	}
	
	property int Health
	{
		public get()
		{
			return GetClientHealth(view_as<int>(this));
		}
		public set(int health)
		{
			SetEntProp(view_as<int>(this), Prop_Send, "m_iHealth", health, 4);
		}
	}
	
	property int MaxHealth
	{
		public get()
		{
			int iPlayerResource = GetPlayerResourceEntity();
			
			if (iPlayerResource != -1)
				return GetEntProp(iPlayerResource, Prop_Send, "m_iMaxHealth", _, view_as<int>(this));
			else
				return 0;
		}
		// Can't set max health this way in TF2
	}
	
	property bool Glow
	{
		public get()
		{
			return !!(GetEntProp(view_as<int>(this), Prop_Send, "m_bGlowEnabled"));
		}
		public set(bool glow)
		{
			SetEntProp(view_as<int>(this), Prop_Send, "m_bGlowEnabled", glow, 1);
		}
	}
	
	
	/**
	 * Functions
	 * --------------------------------------------------
	 */
	
	public void SetTeam(int team, bool respawn = true)
	{
		if (GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available)
			respawn = false;
		
		if (respawn)
		{
			SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", LifeState_Dead);
			ChangeClientTeam(view_as<int>(this), team);
			SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", LifeState_Alive);
			TF2_RespawnPlayer(view_as<int>(this));
		}
		else
		{
			ChangeClientTeam(view_as<int>(this), team);
		}
	}
	
	public bool SetClass(int class, bool regenerate = true, bool persistent = false)
	{
		// This native is a wrapper for a player property change
		TF2_SetPlayerClass(view_as<int>(this), view_as<TFClassType>(class), _, persistent);
		
		// Don't regenerate a dead player because they'll go to Limbo
		if (regenerate && this.IsAlive && (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available))
			TF2_RegeneratePlayer(view_as<int>(this));
	}
	
	
	// BUG Use with RequestFrame after spawning or it might return -1
	public int GetWeapon(int slot = Weapon_Primary)
	{
		return GetPlayerWeaponSlot(view_as<int>(this), slot);
	}
	
	public void SetSlot(int slot = Weapon_Primary)
	{
		int iWeapon;
		
		if ((iWeapon = GetPlayerWeaponSlot(view_as<int>(this), slot)) == -1)
		{
			LogError("Tried to get %N's weapon in slot %d but got -1. Can't switch to that slot", this, slot);
			return;
		}
		
		if (GetFeatureStatus(FeatureType_Native, "TF2_RemoveCondition") == FeatureStatus_Available)
			TF2_RemoveCondition(view_as<int>(this), TFCond_Taunting);
		
		char sClassname[64];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		FakeClientCommandEx(view_as<int>(this), "use %s", sClassname);
		//FakeClientCommand(view_as<int>(this), "use %s", sClassname); // TODO Try this?
		SetEntProp(view_as<int>(this), Prop_Send, "m_hActiveWeapon", iWeapon);
	}
	
	public void MeleeOnly(bool apply = true, bool remove_others = false)
	{
		bool bConds = (GetFeatureStatus(FeatureType_Native, "TF2_AddCondition") == FeatureStatus_Available);
		
		if (apply)
		{
			if (bConds)
			{
				TF2_AddCondition(view_as<int>(this), TFCond_RestrictToMelee, TFCondDuration_Infinite);
				remove_others = true;
			}
			
			this.SetSlot(TFWeaponSlot_Melee);
			
			if (remove_others)
			{
				TF2_RemoveWeaponSlot(view_as<int>(this), TFWeaponSlot_Primary);
				TF2_RemoveWeaponSlot(view_as<int>(this), TFWeaponSlot_Secondary);
			}
		}
		else
		{
			if (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available &&
				(GetPlayerWeaponSlot(view_as<int>(this), TFWeaponSlot_Primary) == -1 ||
				GetPlayerWeaponSlot(view_as<int>(this), TFWeaponSlot_Secondary) == -1))
			{
				int iHealth = this.Health;
				TF2_RegeneratePlayer(view_as<int>(this));
				this.Health = iHealth;
			}
			
			if (GetFeatureStatus(FeatureType_Native, "TF2_RemoveCondition") == FeatureStatus_Available)
				TF2_RemoveCondition(view_as<int>(this), TFCond_RestrictToMelee);
			
			this.SetSlot();
		}
	}
	
	public void StripAmmo(int slot)
	{
		int iWeapon = this.GetWeapon(slot);
		if (iWeapon != -1)
		{
			if (GetEntProp(iWeapon, Prop_Data, "m_iClip1") != -1)
			{
				Debug("StrimpAmmo -- %L weapon in slot %d had %d ammo", view_as<int>(this), slot, GetEntProp(iWeapon, Prop_Data, "m_iClip1"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 0);
			}
			
			if (GetEntProp(iWeapon, Prop_Data, "m_iClip2") != -1)
			{
				Debug("StrimpAmmo -- %L weapon in slot %d had %d ammo", view_as<int>(this), slot, GetEntProp(iWeapon, Prop_Data, "m_iClip2"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip2", 0);
			}
			
			// Weapon's ammo type
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType", 1);
			
			// Player ammo table offset
			int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
			
			// Set quantity of that ammo type in table to 0
			SetEntData(view_as<int>(this), iAmmoTable + (iAmmoType * 4), 0, 4, true);
		}

		/*
			Get the weapon index
			Get its ammo type
			Set its clip values
			Set the client's ammo?
		*/
	}
	
	public int SetMaxHealth(int max)
	{
		int resent = GetPlayerResourceEntity();
		
		if (resent != -1)
		{
			AddAttribute(view_as<int>(this), "max health additive bonus", float(max - GetTFClassHealth(view_as<TFClassType>(this.Class))));
			return max;
		}
		else
		{
			return 0;
		}
	}
	
	public void SetSpeed(int speed = 0)
	{
		if (speed)
		{
			AddAttribute(view_as<int>(this), "CARD: move speed bonus", speed / float(GetTFClassRunSpeed(TF2_GetPlayerClass(this.Index))));
		}
		else
		{
			RemoveAttribute(view_as<int>(this), "CARD: move speed bonus");
		}
	}

	
	/**
	 * Plugin Properties
	 * --------------------------------------------------
	 */
	
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
	
	
	/**
	 * Plugin Functions
	 * --------------------------------------------------
	 */
	
	// Initialise a New Player's Data in the Array
	public void NewPlayer()
	{
		g_iPlayers[this.Index][Player_UserID] = this.UserID;
		g_iPlayers[this.Index][Player_Points] = QP_Start;
		g_iPlayers[this.Index][Player_Flags] = MASK_NEW_PLAYER;
		this.ActivatorLast = GetTime();
	}
	
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
	
	public bool HasFlag(int flag)
	{
		return !!(g_iPlayers[this.Index][Player_Flags] & flag);
		// I don't understand it but it worked. https://forums.alliedmods.net/showthread.php?t=319928
	}
	
	public void AddFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] |= flag;
	}
	
	public void RemoveFlag(int flag)
	{
		g_iPlayers[this.Index][Player_Flags] &= ~flag;
	}
	
	public void SetFlags(int flags)
	{
		g_iPlayers[this.Index][Player_Flags] = flags;
	}
	
	public void MakeActivator()
	{
		// Give the player the Activator flag
		this.AddFlag(PF_Activator);
		Debug("%N given the ACTIVATOR flag", this.Index);
		
		// Add them to the Activators dynamic array (for health bar)
		int index = g_Activators.Push(this);
		
		// Store the player's health and max health in that array
		g_Activators.Set(index, this.Health, AL_Health);
		g_Activators.Set(index, this.MaxHealth, AL_MaxHealth);
	}
	
	public void UnmakeActivator()
	{
		// Remove the Activator flag from the player
		this.RemoveFlag(PF_Activator);
		Debug("%N removed the ACTIVATOR flag", this.Index);
		
		// Remove the player from the Activators dynamic array (health bar)
		int index = g_Activators.FindValue(this);
		if (index != -1) g_Activators.Erase(index);
	}
	
	public void MakeNextActivator()
	{
		int[] activators = new int[MaxClients];
		CreateActivatorList(activators);
		
		int nextact = activators[0];
		
		if (this.Index != nextact)
		{
			this.Points = Player(nextact).Points + 1000;
			Debug("Player.MakeNextActivator --> %N.Points == %d  %N.Points == %d", this.Index, this.Points, Player(nextact).Index, Player(nextact).Points);
		}
		else
		{
			Debug("Player.MakeNextActivator --> %N is already next activator", this.Index);
		}
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
		
		// Set client's language to English
		if (this.HasFlag(PF_PrefEnglish))
			SetClientLanguage(this.Index, 0);
	}
}



/**
 * Game
 * ----------------------------------------------------------------------------------------------------
 */
methodmap DRGameType
{
	public DRGameType()
	{
	}
	
	public bool HasFlag(int flag)
	{
		return !!(g_iGameState & flag);
	}
	
	public void AddFlag(int flag)
	{
		g_iGameState |= flag;
	}
	
	public void RemoveFlag(int flag)
	{
		g_iGameState &= ~flag;
	}
	
	public void SetFlags(int flags)
	{
		g_iGameState = flags;
	}
	
	public void SetGame(int flag)
	{
		g_iGame = flag;
	}
	
	public bool IsGame(int flag)
	{
		return !!(g_iGame & flag);
	}
	
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
	
	property int RoundState
	{
		public get()
		{
			return g_iRoundState;
		}
		public set(int state)
		{
			g_iRoundState = state;
			Debug("Round state set to %s", g_sRoundStates[state]);
		}
	}
	
	property bool InWatchMode
	{
		public get()
		{
			Debug("DRGame.InWatchMode = %s", this.HasFlag(GF_WatchMode) ? "true" : "false");
			return this.HasFlag(GF_WatchMode);
		}
		public set(bool set)
		{
			if (set)
			{
				this.AddFlag(GF_WatchMode);
				Debug("Entered watch mode");
			}
			else
			{
				this.RemoveFlag(GF_WatchMode);
				Debug("Exited watch mode");
			}
		}
	}

	// Players on an active team
	property int Participants
	{
		public get()
		{
			return (GetTeamClientCount(Team_Blue) + GetTeamClientCount(Team_Red));
		}
	}
	
	// Players who prefer to be activator
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
	
	// Activator pool size
	property int ActivatorPool
	{
		public get()
		{
			return (this.WillingActivators < MINIMUM_WILLING) ? this.Participants : this.WillingActivators;
		}
	}
	
	// Number of activators in ADT array
	property int Activators
	{
		public get()
		{
			Debug("DRGame.Activators -- g_Activators length = %d", g_Activators.Length);
			if (g_ConVars[P_Debug].BoolValue)
			{
				int len = g_Activators.Length;
				for (int i = 0; i < len; i++)
				{
					Debug("DRGame.Activators -- g_Activators index %d: %L", i, g_Activators.Get(0));
				}
			}
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
				Player player = Player(g_Activators.Get(i));
				
				if (player.IsAlive)
					count++;
			}
			
			return count;
		}
	}
}

DRGameType DRGame;							// Game logic



