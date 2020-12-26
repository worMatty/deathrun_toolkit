
/**
 * BasePlayer
 * ----------------------------------------------------------------------------------------------------
 */
methodmap BasePlayer < Handle
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
			return GetClientUserId(this.Index);
		}
	}
	
	// Steam Account ID
	property int SteamID
	{
		public get()
		{
			return GetSteamAccountID(this.Index);
		}
	}
	
	// Team Number
	property int Team
	{
		public get()
		{
			return GetClientTeam(this.Index);
		}
	}
	
	// Class Number
	property int Class
	{
		public get()
		{
			return GetEntProp(this.Index, Prop_Send, "m_iClass");
		}
	}
	
	// Is Connected
	property bool IsConnected
	{
		public get()
		{
			return IsClientConnected(this.Index);
		}
	}
	
	// In Game
	property bool InGame
	{
		public get()
		{
			return IsClientInGame(this.Index);
		}
	}
	
	// Is Valid
	property bool IsValid
	{
		public get()
		{
			return (this.Index > 0 && this.Index <= MaxClients);
		}
	}
	
	// Is Observer
	property bool IsObserver
	{
		public get()
		{
			return IsClientObserver(this.Index);
		}
	}
	
	// Alive
	property bool IsAlive
	{
		public get()
		{
			IsPlayerAlive(this.Index);
		}
	}
	
	// Is Participating
	property bool IsParticipating
	{
		public get()
		{
			return (GetClientTeam(this.Index) == Team_Red || GetClientTeam(this.Index) == Team_Blue);
		}
	}
	
	// Is Admin
	property bool IsAdmin
	{
		public get()
		{
			return (GetUserAdmin(this.Index) != INVALID_ADMIN_ID);
		}
	}
	
	// Health
	property int Health
	{
		public get()
		{
			return GetClientHealth(this.Index);
		}
	}
	
	property int MaxHealth
	{
		public get()
		{
			int iPlayerResource = GetPlayerResourceEntity();
			
			if (iPlayerResource != -1)
				return GetEntProp(iPlayerResource, Prop_Send, "m_iMaxHealth", _, this.Index);
			else
				return 0;
		}
		// Can't set max health this way in TF2
	}
	
	
	/**
	 * Functions
	 * --------------------------------------------------
	 * --------------------------------------------------
	 */
	
	// Set Health
	public void SetHealth(int health)
	{
		SetEntProp(this.Index, Prop_Send, "m_iHealth", health, 4);
	}
	
	// Set Team & Optionally Respawn TODO Put game_forcerespawn in plugin code
	public void SetTeam(int team, bool respawn = true)
	{
		if (GetFeatureStatus(FeatureType_Native, "TF2_RespawnPlayer") != FeatureStatus_Available)
			respawn = false;
		
		if (respawn)
		{
			SetEntProp(this.Index, Prop_Send, "m_lifeState", LifeState_Dead);
			ChangeClientTeam(this.Index, team);
			SetEntProp(this.Index, Prop_Send, "m_lifeState", LifeState_Alive);
			TF2_RespawnPlayer(this.Index);
		}
		else
		{
			ChangeClientTeam(this.Index, team);
		}
	}
	
	// Set Class
	public bool SetClass(int class, bool regenerate = true, bool persistent = false)
	{
		TF2_SetPlayerClass(this.Index, view_as<TFClassType>(class), _, persistent);
		
		// Don't regenerate a dead player because they'll go to Limbo
		if (regenerate && IsPlayerAlive(this.Index) && (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available))
			TF2_RegeneratePlayer(this.Index);
	}
	
	// Get Weapon Index
	// BUG Use with RequestFrame after spawning or it might return -1
	public int GetWeapon(int slot = Weapon_Primary)
	{
		return GetPlayerWeaponSlot(this.Index, slot);
	}
	
	// Switch to Slot
	public void SetSlot(int slot = Weapon_Primary)
	{
		int iWeapon;
		
		if ((iWeapon = GetPlayerWeaponSlot(this.Index, slot)) == -1)
		{
			LogError("Tried to get %N's weapon in slot %d but got -1. Can't switch to that slot", this.Index, slot);
			return;
		}
		
		if (GetFeatureStatus(FeatureType_Native, "TF2_RemoveCondition") == FeatureStatus_Available)
			TF2_RemoveCondition(this.Index, TFCond_Taunting);
		
		char sClassname[64];
		GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
		FakeClientCommandEx(this.Index, "use %s", sClassname);
		SetEntProp(this.Index, Prop_Send, "m_hActiveWeapon", iWeapon);
	}
	
	// Switch to Melee & Optionally Restrict
	// TODO Find out OF melee slot
	public void MeleeOnly(bool apply = true, bool remove_others = false)
	{
		bool bConds = (GetFeatureStatus(FeatureType_Native, "TF2_AddCondition") == FeatureStatus_Available);
		
		if (apply)
		{
			if (bConds)
			{
				TF2_AddCondition(this.Index, TFCond_RestrictToMelee, TFCondDuration_Infinite);
				remove_others = true;
			}
			
			this.SetSlot(TFWeaponSlot_Melee);
			
			if (remove_others)
			{
				TF2_RemoveWeaponSlot(this.Index, TFWeaponSlot_Primary);
				TF2_RemoveWeaponSlot(this.Index, TFWeaponSlot_Secondary);
			}
		}
		else
		{
			if (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available &&
				(GetPlayerWeaponSlot(this.Index, TFWeaponSlot_Primary) == -1 ||
				GetPlayerWeaponSlot(this.Index, TFWeaponSlot_Secondary) == -1))
			{
				int iHealth = this.Health;
				TF2_RegeneratePlayer(this.Index);
				this.SetHealth(iHealth);
			}
			
			if (GetFeatureStatus(FeatureType_Native, "TF2_RemoveCondition") == FeatureStatus_Available)
				TF2_RemoveCondition(this.Index, TFCond_RestrictToMelee);
			
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
				DebugEx(this.Index, "Slot %d weapon had %d ammo", slot, GetEntProp(iWeapon, Prop_Data, "m_iClip1"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip1", 0);
			}
			
			if (GetEntProp(iWeapon, Prop_Data, "m_iClip2") != -1)
			{
				DebugEx(this.Index, "Slot %d weapon had %d ammo", slot, GetEntProp(iWeapon, Prop_Data, "m_iClip2"));
				SetEntProp(iWeapon, Prop_Send, "m_iClip2", 0);
			}
			
			// Weapon's ammo type
			int iAmmoType = GetEntProp(iWeapon, Prop_Send, "m_iPrimaryAmmoType", 1);
			
			// Player ammo table offset
			int iAmmoTable = FindSendPropInfo("CTFPlayer", "m_iAmmo");
			
			// Set quantity of that ammo type in table to 0
			SetEntData(this.Index, iAmmoTable + (iAmmoType * 4), 0, 4, true);
		}

		/*
			Get the weapon index
			Get its ammo type
			Set its clip values
			Set the client's ammo?
		*/
	}
	
	// Set Player Max Health TODO Do TF2C and OF support setting max health directly?
	public float SetMaxHealth(float fMax)
	{
		int iPRes = GetPlayerResourceEntity();
		
		if (iPRes != -1)
		{
			//if (health < this.MaxHealth)
			//	return;

			AddPlayerAttribute(this.Index, "max health additive bonus", fMax - this.MaxHealth);
			//SetEntProp(g_iHealthBar[HealthBar_PlayerResource], Prop_Send, "m_iMaxHealth", health, _, this.Index);
			DebugMessage("Set %N's max health to %0.f", this.Index, fMax);
			if (g_bSCR && g_cSCR.BoolValue)
				SCR_SendEvent(PREFIX_SERVER, "Set %N's max health to %0.f", this.Index, fMax);
			return fMax;
		}
		else
		{
			return 0.0;
		}
	}
	
	// Set Player Speed
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
			RemovePlayerAttribute(this.Index, "CARD: move speed bonus");
		}
		else
		{
			AddPlayerAttribute(this.Index, "CARD: move speed bonus", speed / (iRunSpeeds[this.Class] + 0.0));
		}
	}
}