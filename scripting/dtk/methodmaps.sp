#pragma semicolon 1

// Teams
enum {
	Team_None,
	Team_Spec,
	Team_Red,	// 2 - red
	Team_Blue	// 3 - blue
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



// Game Flags
enum {
	GF_LateLoad = 0x1,				// Plugin was loaded late/reloaded
	GF_WatchMode = 0x2,				// We're in team watch mode during pre-round freeze time
	GF_Restarting = 0x4				// Counting down to round restart (OF)
}

// Player Flags
enum {
	// Stored in database
	PF_PrefActivator = 0x1,			// Wants to be activator
	PF_ReceivesMoreQP = 0x2,		// Receives more queue points
	PF_PrefEnglish = 0x4,			// Wants English SourceMod
	PF_ActivatorBanned = 0x8,		// Banned from being activator

	// Stored for session
	PF_Welcomed = 0x10000,			// Has been welcomed to the server
	PF_Activator = 0x20000,			// Is an activator
	PF_Runner = 0x40000,			// Is a runner
}

// Player Flag Masks
#define MASK_NEW_PLAYER			( PF_PrefActivator )		// Used to assign default flags to a new player
#define MASK_STORED_FLAGS		( 0x0000FFFF )				// Used to store only specific flags in the database
#define MASK_SESSION_FLAGS		( 0xFFFF0000 )				// The session flag block of the player's bit field

enum struct PlayerData {
	int Index;
	int UserID;
	int Points;
	int Flags;
	int ActivatorLast;
}

int g_RoundState;

PlayerData g_Players[MAXPLAYERS];

// ----------------------------------------------------------------------------------------------------

methodmap Player
{
	public Player(int client)
	{
		return view_as<Player>(client);
	}

	property int Index {
		public get() {
			return view_as<int>(this);
		}
	}

	property int UserID {
		public get() {
			return GetClientUserId(view_as<int>(this));
		}
	}

	property int SteamAccountId {
		public get() {
			return GetSteamAccountID(view_as<int>(this));
		}
	}

	property bool IsValid {
		public get() {
			return (view_as<int>(this) > 0 && view_as<int>(this) <= MaxClients);
		}
	}

	property bool IsConnected {
		public get() {
			return IsClientConnected(view_as<int>(this));
		}
	}

	property bool InGame {
		public get() {
			return IsClientInGame(view_as<int>(this));
		}
	}

	property bool IsObserver {
		public get() {
			return IsClientObserver(view_as<int>(this));
		}
	}

	property bool IsBot {
		public get() {
			return IsFakeClient(view_as<int>(this));
		}
	}

	property bool IsAlive {
		public get() {
			return (GetEntProp(view_as<int>(this), Prop_Send, "m_lifeState") == LifeState_Alive);
		}
		public set(bool alive) {
			SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", (alive) ? LifeState_Alive : LifeState_Dead);
		}
	}

	property bool IsAdmin {
		public get() {
			return (view_as<int>(this) == 0) || (GetUserAdmin(view_as<int>(this)) != INVALID_ADMIN_ID);
		}
	}

	property int Team {
		public get() {
			return GetClientTeam(view_as<int>(this));
		}
	}

	property int Class {
		public get() {
			return GetEntProp(view_as<int>(this), Prop_Send, "m_iClass");
		}
	}

	property bool IsParticipating {
		public get() {
			return (GetClientTeam(view_as<int>(this)) > Team_Spec);
		}
	}

	property int Health {
		public get() {
			return GetClientHealth(view_as<int>(this));
		}
		public set(int health) {
			SetEntProp(view_as<int>(this), Prop_Send, "m_iHealth", health, 4);
		}
	}

	property int MaxHealth {
		public get() {
			return (GetPlayerResourceEntity() != -1) ? GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, view_as<int>(this)) : 0;
		}
	}

	property bool Glow {
		public get() {
			return !!(GetEntProp(view_as<int>(this), Prop_Send, "m_bGlowEnabled"));
		}
		public set(bool glow) {
			SetEntProp(view_as<int>(this), Prop_Send, "m_bGlowEnabled", glow, 1);
		}
	}


	// public int GetPlayerWeaponSlot(int slot) {
	// 	return GetPlayerWeaponSlot(this.Index, slot);
	// }

	/**
	 * Move a player to another team
	 * @param	team		Team number
	 * @param	respawn		Respawn the player after moving them
	 */
	public void SetTeam(int team, bool respawn = false)
	{
		if (GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available)
		{
			respawn = false;
		}

		// SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", LifeState_Dead);
		this.IsAlive = false;
		ChangeClientTeam(view_as<int>(this), team);

		// BUG Testing if we really need to respawn players or if the game will do that for us
		respawn = false;
		// TODO find out where I'm doing this in code and correct that instead of changing the function

		if (respawn && this.Class != Class_Unknown)
		{
			// SetEntProp(view_as<int>(this), Prop_Send, "m_lifeState", LifeState_Alive);
			this.IsAlive = true;
			RequestFrame(RespawnPlayer, view_as<int>(this));
		}
	}

	public bool SetClass(int class, bool regenerate = true, bool persistent = false)
	{
		TF2_SetPlayerClass(view_as<int>(this), view_as<TFClassType>(class), _, persistent);

		// Don't regenerate a dead player because they'll go to Limbo
		if (regenerate && this.IsAlive
			&& (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available))
		{
			TF2_RegeneratePlayer(view_as<int>(this));
		}
	}

	/**
	 * Switch the player's active slot
	 * Removes taunting condition to ensure the change happens
	 *
	 * @param	slot		Weapon slot
	 */
	public void SetSlot(int slot)
	{
		int weapon = GetPlayerWeaponSlot(view_as<int>(this), slot);

		if (slot == -1)
		{
			LogError("Tried to get %N's weapon in slot %d but got -1. Can't switch to that slot", this, slot);
			return;
		}

		if (GetFeatureStatus(FeatureType_Native, "TF2_RemoveCondition") == FeatureStatus_Available)
		{
			TF2_RemoveCondition(view_as<int>(this), TFCond_Taunting);
		}

		char classname[64];
		GetEntityClassname(weapon, classname, sizeof(classname));
		FakeClientCommandEx(view_as<int>(this), "use %s", classname);
		//FakeClientCommand(view_as<int>(this), "use %s", classname); // TODO Try this?
		SetEntProp(view_as<int>(this), Prop_Send, "m_hActiveWeapon", weapon);	// TODO Do I need to use SetEntPropEnt?
	}

	/**
	 * Switches the player to their melee slot and deletes all their other weapons.
	 * Upon disabling, regenerates the player to respawn their weapons,
	 * then switches them to their primary weapon.
	 *
	 * @param	melee_only		True to set, false to restore
	 */
	public void MeleeOnly(bool melee_only = true)
	{
		if (melee_only)
		{
			this.SetSlot(TFWeaponSlot_Melee);

			for (int i; i <= 7; i++)
			{
				if (i == TFWeaponSlot_Melee)
				{
					continue;
				}
				else
				{
					TF2_RemoveWeaponSlot(view_as<int>(this), i);
				}
			}
		}
		else
		{
			if (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available)
			{
				int health = this.Health;
				TF2_RegeneratePlayer(view_as<int>(this));
				this.Health = health;
			}

			this.SetSlot(TFWeaponSlot_Primary);
		}
	}

	public int SetMaxHealth(int max)
	{
		float new_max = float( max - TF2_GetTFClassHealth( view_as<TFClassType>( this.Class ) ) );

		// if (GetPlayerResourceEntity() != -1)	// TODO why was I doing this?
		if (AddAttribute(view_as<int>(this), "max health additive bonus", new_max))
		{
			return max;
		}

		return 0;
	}

	public void SetSpeed(int speed = 0)
	{
		if (speed)
		{
			float new_speed = speed / float( TF2_GetTFClassRunSpeed( TF2_GetPlayerClass( this.Index ) ) );
			AddAttribute(view_as<int>(this), "CARD: move speed bonus", new_speed);
		}
		else
		{
			RemoveAttribute(view_as<int>(this), "CARD: move speed bonus");
		}
	}
}


methodmap DRPlayer < Player
{
	public DRPlayer(int client)
	{
		return view_as<DRPlayer>(client);
	}

	property int Points {
		public get() {
			return g_Players[this.Index].Points;
		}
		public set(int points) {
			g_Players[this.Index].Points = points;
		}
	}

	property int Flags {
		public get() {
			return g_Players[this.Index].Flags;
		}
		public set(int flags) {
			g_Players[this.Index].Flags = flags;
		}
	}

	property bool IsRunner {
		public get() {
			return !!(g_Players[this.Index].Flags & PF_Runner);
		}
	}

	property bool IsActivator {
		public get() {
			return !!(g_Players[this.Index].Flags & PF_Activator);
		}
	}

	// User ID from Player Array
	property int ArrayUserID {
		public get() {
			return g_Players[this.Index].UserID;
		}
		public set(int userid) {
			g_Players[this.Index].UserID = userid;
		}
	}

	// Last time player was activator
	property int ActivatorLast {
		public get() {
			return g_Players[this.Index].ActivatorLast;
		}
		public set(int time) {
			g_Players[this.Index].ActivatorLast = time;
		}
	}

	property bool PrefersActivator {
		public get() {
			return !!(this.Flags & PF_PrefActivator);
		}
		public set(bool prefers)
		{
			if (prefers) this.Flags |= PF_PrefActivator;
			else this.Flags &= ~PF_PrefActivator;
		}
	}

	property bool ReceivesMoreQP {
		public get() {
			return !!(this.Flags & PF_ReceivesMoreQP);
		}
		public set(bool receive_more)
		{
			if (receive_more) this.Flags |= PF_ReceivesMoreQP;
			else this.Flags &= ~PF_ReceivesMoreQP;
		}
	}

	property bool PrefersEnglish {
		public get() {
			return !!(this.Flags & PF_PrefEnglish);
		}
		public set(bool set)
		{
			if (set) this.Flags |= PF_PrefEnglish;
			else this.Flags &= ~PF_PrefEnglish;
		}
	}

	property bool ActivatorBanned {
		public get() {
			return !!(this.Flags & PF_ActivatorBanned);
		}
		public set(bool banned)
		{
			if (banned) this.Flags |= PF_ActivatorBanned;
			else this.Flags &= ~PF_ActivatorBanned;
		}
	}

	property bool Welcomed {
		public get() {
			return !!(this.Flags & PF_Welcomed);
		}
		public set(bool set)
		{
			if (set) this.Flags |= PF_Welcomed;
			else this.Flags &= ~PF_Welcomed;
		}
	}

	property bool Activator {
		public get() {
			return !!(this.Flags & PF_Activator);
		}
		public set(bool set)
		{
			if (set) this.Flags |= PF_Activator;
			else this.Flags &= ~PF_Activator;
		}
	}

	property bool Runner {
		public get() {
			return !!(this.Flags & PF_Runner);
		}
		public set(bool set)
		{
			if (set) this.Flags |= PF_Runner;
			else this.Flags &= ~PF_Runner;
		}
	}


	/**
	 * Plugin Functions
	 * --------------------------------------------------
	 */

	// Initialise a New Player's Data in the Array
	public void NewPlayer()
	{
		g_Players[this.Index].UserID = this.UserID;
		g_Players[this.Index].Flags = MASK_NEW_PLAYER;
		this.ActivatorLast = GetTime();
	}

	public bool HasFlag(int flag) {
		return !!(g_Players[this.Index].Flags & flag);
		// https://forums.alliedmods.net/showthread.php?t=319928
	}

	public void AddFlag(int flag) {
		g_Players[this.Index].Flags |= flag;
	}

	public void RemoveFlag(int flag) {
		g_Players[this.Index].Flags &= ~flag;
	}

	public void MakeActivator()
	{
		this.AddFlag(PF_Activator);
		g_Activators.Push(this);
	}

	public void UnmakeActivator()
	{
		this.RemoveFlag(PF_Activator);
		int index = g_Activators.FindValue(this);
		if (index != -1) g_Activators.Erase(index);
	}

	public void MakeNextActivator()
	{
		PlayerList pool = CreateActivatorPool();
		int next_activator = pool.Get(0);
		this.Points = DRPlayer(next_activator).Points + 1000;
	}

	// Retrieve Player Data from the Database
	public bool RetrieveData()
	{
		if (this.SteamAccountId == 0)
		{
			return false;
		}

		bool record_exists;
		int points, flags, last_seen;
		DBResultSet result_set = DBQueryForRecord(this.SteamAccountId);

		if (result_set != null)
		{
			record_exists = DBGetRecordFromResult(result_set, points, flags, last_seen);

			if (record_exists)
			{
				this.Points = points;
				this.Flags = (this.Flags & MASK_SESSION_FLAGS) | (flags & MASK_STORED_FLAGS);
			}

			delete result_set;
		}
		else
		{
			LogError("Database query failed for user %L", this.Index);
		}

		return record_exists;
	}

	// Store Player Data in the Database
	public bool SaveData()
	{
		if (this.SteamAccountId == 0)
		{
			return false;
		}

		bool succeeded = DBSaveData(this.SteamAccountId, this.Points, (this.Flags & MASK_STORED_FLAGS), GetTime());

		if (!succeeded)
		{
			LogError("Failed to update database record for %L", this.Index);
		}

		return succeeded;
	}

	// Create New Database Record
	public bool CreateRecord()
	{
		if (this.SteamAccountId == 0)
		{
			return false;
		}

		bool succeeded = DBCreateRecord(this.SteamAccountId, this.Points, this.Flags & MASK_STORED_FLAGS, GetTime());

		if (!succeeded)
		{
			LogError("Unable to create record for %L", this.Index);
		}

		return succeeded;
	}

	// Delete Player Database Record
	public bool DeleteRecord(int client)
	{
		if (this.SteamAccountId == 0)
		{
			return false;
		}

		return DBDeleteRecord(this.SteamAccountId);
	}

	// Check Player
	public void CheckNewPlayer()
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
		if (this.PrefersEnglish)
		{
			SetClientLanguage(this.Index, 0);
		}
	}
}


/**
 * Respawn a player
 *
 * @param	client		Client index
 * @error	Invalid client index; client not in game; no mod support
 * @noreturn
 */
void RespawnPlayer(int client)
{
	TF2_RespawnPlayer(client);
}


/**
 * Apply the necessary attributes to a player after they spawn.
 *
 * @noreturn
 */
void ApplyPlayerAttributes(int client)
{
	if (!IsGameTF2())
	{
		return;
	}

	DRPlayer player = DRPlayer(client);

	// Reset player attributes TODO Probably best practice to do this separately
	RemoveAllAttributes(client);

	// Blue Speed
	if (player.Team == Team_Blue)
	{
		if (g_ConVars[P_BlueSpeed].FloatValue != 0.0)
		{
			player.SetSpeed(g_ConVars[P_BlueSpeed].IntValue);
		}
	}

	// Red
	if (player.Team == Team_Red)
	{
		// Red Speed
		if (g_ConVars[P_RedSpeed].FloatValue != 0.0)
		{
			player.SetSpeed(g_ConVars[P_RedSpeed].IntValue);
		}

		// Red Scout Speed
		else if (g_ConVars[P_RedScoutSpeed].FloatValue != 0.0 && player.Class == Class_Scout)
		{
			player.SetSpeed(g_ConVars[P_RedScoutSpeed].IntValue);
		}

		// Double Jump
		if (!g_ConVars[P_RedAirDash].BoolValue && player.Class == Class_Scout)
		{
			AddAttribute(client, "no double jump", 1.0);
		}

		// Spy Cloak
		// if (player.Class == Class_Spy)
		// {
		// 	AddAttribute(client, "mult cloak meter consume rate", 8.0);
		// 	AddAttribute(client, "mult cloak meter regen rate", 0.25);
		// }

		// Demo Charging
		if (player.Class == Class_DemoMan)
		{
			switch (g_ConVars[P_EnhancedMobility].IntValue)
			{
				case 0:
				{
					AddAttribute(client, "charge time decreased", -1000.0);
					AddAttribute(client, "charge recharge rate increased", 0.0);
				}
				case 1:
				{
					AddAttribute(client, "charge time decreased", -0.95);
					AddAttribute(client, "charge recharge rate increased", 0.2);
				}
			}
		}
	}
}


/**
 * Toggle a player's SourceMod translations to English
 *
 * @param	client		Client index
 * @noreturn
 */
void ToggleEnglish(int client)
{
	if (DRPlayer(client).PrefersEnglish)
	{
		DRPlayer(client).PrefersEnglish = false;
		char language[32];

		if (GetClientInfo(client, "cl_language", language, sizeof(language)))
		{
			int iLanguage = GetLanguageByName(language);
			if (iLanguage == -1)
			{
				TF2_PrintToChat(client, _, "When you next connect, your client language will be used");
				EmitMessageSoundToClient(client);
			}
			else
			{
				SetClientLanguage(client, iLanguage);
				TF2_PrintToChat(client, _, "\x01Your client language of \x05%s\x01 will now be used", language);
				EmitMessageSoundToClient(client);
			}
		}
	}
	else
	{
		DRPlayer(client).PrefersEnglish = true;
		TF2_PrintToChat(client, _, "\x01Your language has been set to \x05English");
		EmitMessageSoundToClient(client);
		SetClientLanguage(client, 0);
	}
}

/**
 * Ban a player from becoming activator
 *
 * @param	steam_account		The Steam account ID of the player
 * @return	Ban succeeded
 */
bool ActivatorBan(int steam_account)
{
	int client = GetClientFromSteamAccount(steam_account);

	if (client != 0)
	{
		DRPlayer(client).ActivatorBanned = true;
		return DRPlayer(client).SaveData();
	}
	else
	{
		DBResultSet results = DBQueryForRecord(steam_account);

		if (results == null)
		{
			return false;
		}
		else
		{
			int points, flags, last_seen;
			bool found = DBGetRecordFromResult(results, points, flags, last_seen);
			delete results;

			if (found)
			{
				flags |= PF_ActivatorBanned;
				bool saved = DBSaveData(steam_account, points, flags, last_seen);

				return saved;
			}
			else
			{
				flags |= (MASK_NEW_PLAYER | PF_ActivatorBanned);
				bool created = DBCreateRecord(steam_account, points, flags, last_seen);

				return created;
			}
		}
	}
}


/**
 * Remove an activator ban from a player
 *
 * @param	steam_account		Steam account ID of the player
 * @return	Unban succeeded
 */
bool RemoveActivatorBan(int steam_account)
{
	int client = GetClientFromSteamAccount(steam_account);

	if (client != 0)
	{
		DRPlayer(client).ActivatorBanned = false;
		return DRPlayer(client).SaveData();
	}
	else
	{
		DBResultSet results = DBQueryForRecord(steam_account);

		if (results == null)
		{
			return false;
		}
		else
		{
			int points, flags, last_seen;
			bool found = DBGetRecordFromResult(results, points, flags, last_seen);
			delete results;

			if (found)
			{
				flags &= ~PF_ActivatorBanned;
				bool saved = DBSaveData(steam_account, points, flags, last_seen);

				return saved;
			}
			else
			{
				return true;	// player doesn't have a record so there's no point in making one
			}
		}
	}
}


/**
 * Is a player banned from being activator?
 *
 * @param	steam_account		Steam account ID of the player
 * @return	Player is banned
 */
bool IsActivatorBanned(int steam_account)
{
	int client = GetClientFromSteamAccount(steam_account);

	if (client != 0)
	{
		return !!(DRPlayer(client).ActivatorBanned);
	}
	else
	{
		DBResultSet results = DBQueryForRecord(steam_account);

		if (results == null)
		{
			return false;
		}
		else
		{
			int points, flags, last_seen;
			bool found = DBGetRecordFromResult(results, points, flags, last_seen);
			delete results;

			if (found)
			{
				return !!(flags & PF_ActivatorBanned);
			}
			else
			{
				return false;
			}
		}
	}
}


methodmap EntityList < ArrayList
{
	public EntityList(int blocksize = 1) {
		return view_as<EntityList>(new ArrayList(blocksize));
	}

	property bool IsEmpty {
		public get()
		{
			this.Validate();
			return !this.Length;
		}
	}

	public void Validate() {
		for (int i; i < this.Length;)
		{
			if (IsValidEntity(this.Get(i))) i++;
			else this.Erase(i);
		}
	}
}



methodmap PlayerList < EntityList
{
	public PlayerList(int blocksize = 1) {
		return view_as<PlayerList>(new EntityList(blocksize));
	}

	property int CountAlive {
		public get()
		{
			this.Validate();
			int count;
			for (int i; i < this.Length; i++)
			{
				DRPlayer player = DRPlayer(this.Get(i));
				if (player.IsAlive) count++;
			}
			return count;
		}
	}

	public void GetHealthFigures(int &health, int &maxhealth)
	{
		this.Validate();

		for (int i; i < this.Length; i++)
		{
			DRPlayer player = DRPlayer(this.Get(i));
			health += player.Health;
			maxhealth += player.MaxHealth;
		}
	}

	public int ScaleHealth(int enemies)
	{
		this.Validate();

		int alive_activators = this.CountAlive;

		if (alive_activators >= enemies || !alive_activators)
		{
			return 0;
		}

		int health_total;

		for (int i; i < this.Length; i++)
		{
			DRPlayer player = DRPlayer(this.Get(i));

			if (player.InGame && player.IsAlive)
			{
				float health = float(TF2_GetTFClassHealth(TF2_GetPlayerClass(player.Index)));

				health = (((enemies * 2) * health) - health);
				health /= enemies;

				AddAttribute(player.Index, "health from packs decreased", TF2_GetTFClassHealth(TF2_GetPlayerClass(player.Index)) / health);
				player.SetMaxHealth(RoundToNearest(health));
				player.Health = RoundToNearest(health);

				health_total += RoundToNearest(health);
			}
		}

		return health_total;
	}
}



/**
 * Game
 * ----------------------------------------------------------------------------------------------------
 */

// enum struct Game {
// 	int flags;
// 	int roundstate;
// 	bool lateload;
// 	bool watchmode;
// 	bool of_restarting;
// }

// Game game;

methodmap DRGameType
{
	property int flags {
		public get() {
			return this.flags;
		}
		public set(int flags) {
			this.flags;
		}
	}

	public bool HasFlag(int flag) {
		return !!(g_GameState & flag);
	}

	public void AddFlag(int flag) {
		g_GameState |= flag;
	}

	public void RemoveFlag(int flag) {
		g_GameState &= ~flag;
	}

	property bool LateLoaded {
		public get() {
			return this.HasFlag(GF_LateLoad);
		}
		public set(bool late_loaded) {
			late_loaded ? this.AddFlag(GF_LateLoad) : this.RemoveFlag(GF_LateLoad);
		}
	}

	property int RoundState {
		public get() {
			return g_RoundState;
		}
		public set(int state) {
			g_RoundState = state;
		}
	}

	property bool InWatchMode {
		public get() {
			return this.HasFlag(GF_WatchMode);
		}
		public set(bool watch_mode) {
			watch_mode ? this.AddFlag(GF_WatchMode) : this.RemoveFlag(GF_WatchMode);
		}
	}

	property bool AttributesSupported {
		public get() {
			return IsGameTF2();
		}
	}
}