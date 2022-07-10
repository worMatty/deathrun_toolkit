
/**
 * Player Methodmap
 * ----------------------------------------------------------------------------------------------------
 */
 
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

// Default Class Run Speeds
enum {
	RunSpeed_NoClass = 0,
	RunSpeed_Scout = 400,
	RunSpeed_Sniper = 300,
	RunSpeed_Soldier = 240,
	RunSpeed_DemoMan = 280,
	RunSpeed_Medic = 320,
	RunSpeed_Heavy = 230,
	RunSpeed_Pyro = 300,
	RunSpeed_Spy = 320,
	RunSpeed_Engineer = 300,
	RunSpeed_Merc = 320,
	RunSpeed_Civ = 280
}

// Default Class Health
enum {
	Health_NoClass = 50,
	Health_Scout = 125,
	Health_Sniper = 125,
	Health_Soldier = 200,
	Health_DemoMan = 175,
	Health_Medic = 150,
	Health_Heavy = 300,
	Health_Pyro = 175,
	Health_Spy = 125,
	Health_Engineer = 125,
	Health_Merc = 150,
	Health_Civ = 200
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




methodmap BasePlayer
{
	public BasePlayer(int client)
	{
		return view_as<BasePlayer>(client);
	}
	
	
	/**
	 * Properties
	 * --------------------------------------------------
	 * --------------------------------------------------
	 */
	
	// Client Index
	property int Index
	{
		public get()
		{
			return view_as<int>(this);
		}
	}
	
	
	// User ID
	property int UserID
	{
		public get()
		{
			return GetClientUserId(view_as<int>(this));
		}
	}
	
	
	// Serial
	property int Serial
	{
		public get()
		{
			return GetClientSerial(view_as<int>(this));
		}
	}
	
	
	// Steam Account ID
	property int SteamID
	{
		public get()
		{
			return GetSteamAccountID(view_as<int>(this));
		}
	}
	
	
	// Team Number
	property int Team
	{
		public get()
		{
			return GetClientTeam(view_as<int>(this));
		}
	}
	
	
	// Class Number
	property int Class
	{
		public get()
		{
			return GetEntProp(view_as<int>(this), Prop_Send, "m_iClass");
		}
	}
	
	
	// Class Run Speed
	property int ClassRunSpeed
	{
		public get()
		{
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
				RunSpeed_Engineer,
				RunSpeed_Merc
			};
			
			char folder[32];
			GetGameFolderName(folder, sizeof(folder));
			if (StrEqual(folder, "tf2classic")) iRunSpeeds[10] = RunSpeed_Civ;
			
			return iRunSpeeds[this.Class];
		}
	}

	
	// Class Health
	property int ClassHealth
	{
		public get()
		{
			int health[] =
			{
				Health_NoClass,
				Health_Scout,
				Health_Sniper,
				Health_Soldier,
				Health_DemoMan,
				Health_Medic,
				Health_Heavy,
				Health_Pyro,
				Health_Spy,
				Health_Engineer,
				Health_Merc
			};
			
			char folder[32];
			GetGameFolderName(folder, sizeof(folder));
			if (StrEqual(folder, "tf2classic")) health[10] = Health_Civ;
			
			return health[this.Class];
		}
	}
	
	
	// Is Connected
	property bool IsConnected
	{
		public get()
		{
			return IsClientConnected(view_as<int>(this));
		}
	}
	
	
	// In Game
	property bool InGame
	{
		public get()
		{
			return IsClientInGame(view_as<int>(this));
		}
	}
	
	
	// Is Valid
	property bool IsValid
	{
		public get()
		{
			return (view_as<int>(this) > 0 && view_as<int>(this) <= MaxClients);
		}
	}
	
	
	// Is Observer
	property bool IsObserver
	{
		public get()
		{
			return IsClientObserver(view_as<int>(this));
		}
	}
	
	
	// Alive
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
	
	
	// Is Participating
	property bool IsParticipating
	{
		public get()
		{
			return (GetClientTeam(view_as<int>(this)) == Team_Red || GetClientTeam(view_as<int>(this)) == Team_Blue);
		}
	}
	
	
	// Is Admin
	property bool IsAdmin
	{
		public get()
		{
			return (GetUserAdmin(view_as<int>(this)) != INVALID_ADMIN_ID);
		}
	}
	
	
	// Is Bot
	property bool IsBot
	{
		public get()
		{
			return IsFakeClient(view_as<int>(this));
		}
	}
	
	
	// Health
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
	
	
	// Max Health
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
	
	
	// Glow
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
	 * --------------------------------------------------
	 */
	
	// Set Team & Optionally Respawn
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
	
	
	// Set Class
	public bool SetClass(int class, bool regenerate = true, bool persistent = false)
	{
		// This native is a wrapper for a player property change
		TF2_SetPlayerClass(view_as<int>(this), view_as<TFClassType>(class), _, persistent);
		
		// Don't regenerate a dead player because they'll go to Limbo
		if (regenerate && this.IsAlive && (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available))
			TF2_RegeneratePlayer(view_as<int>(this));
	}
	
	
	// Get Weapon Index
	// BUG Use with RequestFrame after spawning or it might return -1
	public int GetWeapon(int slot = Weapon_Primary)
	{
		return GetPlayerWeaponSlot(view_as<int>(this), slot);
	}
	
	
	// Switch to Slot
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
	
	
	// Restrict to Melee
	// TODO Find out OF melee slot
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
	
	
	// Strip Ammo
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
	
	
	// Set Player Max Health TODO Do TF2C and OF support setting max health directly?
	public int SetMaxHealth(int max)
	{
		int resent = GetPlayerResourceEntity();
		
		if (resent != -1)
		{
			AddAttribute(view_as<int>(this), "max health additive bonus", float(max - this.ClassHealth));
			//SetEntProp(g_iPlayerRes, Prop_Send, "m_iMaxHealth", health, _, this);
			
			return max;
		}
		else
		{
			return 0;
		}
	}
	
	
	// Set Player Speed
	public void SetSpeed(int speed = 0)
	{
		if (speed)
		{
			AddAttribute(view_as<int>(this), "CARD: move speed bonus", speed / (this.ClassRunSpeed + 0.0));
			//SetEntPropFloat(this, Prop_Send, "m_flMaxspeed", speed + 0.0);
		}
		else
		{
			RemoveAttribute(view_as<int>(this), "CARD: move speed bonus");
			//SetEntPropFloat(this, Prop_Send, "m_flMaxspeed", (this.ClassRunSpeed + 0.0));
		}
	}
}
