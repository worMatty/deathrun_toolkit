
/**
 * BasePlayer
 * ----------------------------------------------------------------------------------------------------
 */

bool g_bTF2Attributes;

int g_iGlow[MAXPLAYERS + 1];

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
	
	// Is Bot
	property bool IsBot
	{
		public get()
		{
			return IsFakeClient(this.Index);
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
	
	// Max Health
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
	
	// Set Team & Optionally Respawn
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
		// This native is a wrapper for a player property change
		TF2_SetPlayerClass(this.Index, view_as<TFClassType>(class), _, persistent);
		
		// Don't regenerate a dead player because they'll go to Limbo
		if (regenerate && IsPlayerAlive(this.Index) && (GetFeatureStatus(FeatureType_Native, "TF2_RegeneratePlayer") == FeatureStatus_Available))
			TF2_RegeneratePlayer(this.Index);
	}
	
	// Glow
	public void Glow(bool glow = true)
	{
		SetEntProp(this.Index, Prop_Send, "m_bGlowEnabled", glow, 1);
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

			AddAttribute(this.Index, "max health additive bonus", fMax - this.MaxHealth);
			//SetEntProp(g_iPlayerRes, Prop_Send, "m_iMaxHealth", health, _, this.Index);
			Debug("Set %N's max health to %0.f", this.Index, fMax);
			return fMax;
		}
		else
		{
			return 0.0;
		}
	}
	
	// Set Player Speed
	public void SetSpeed(int speed = 0)
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
			RunSpeed_Engineer
		};
		
		char gamefolder[32];
		GetGameFolderName(gamefolder, sizeof(gamefolder));
		
		if (speed)
		{
			//TF2_AddCondition(this.Index, TFCond_SpeedBuffAlly);
			AddAttribute(this.Index, "CARD: move speed bonus", speed / (iRunSpeeds[this.Class] + 0.0));
			SetEntPropFloat(this.Index, Prop_Send, "m_flMaxspeed", speed + 0.0);
			// Speed attributes don't take effect until the character's m_flMaxspeed property is modified by something
			Debug("Set speed of %N to %d", this.Index, speed);
		}
		else
		{
			//TF2_RemoveCondition(this.Index, TFCond_SpeedBuffAlly);
			RemoveAttribute(this.Index, "CARD: move speed bonus");
			SetEntPropFloat(this.Index, Prop_Send, "m_flMaxspeed", (iRunSpeeds[this.Class] + 0.0));
			Debug("Removed %N's speed attribute", this.Index);
		}
	}
	
	// TFGlow
	public void TFGlow(bool active = true)
	{
		// Create a tf_glow
		if (active)
		{
			if (g_iGlow[this.Index])
			{
				// If the player already has a valid tf_glow entity index stored, remove that entity 
				if (IsValidEntity(g_iGlow[this.Index]))
				{
					DebugEx(this.Index, "Destrying %N's existing tf_glow (%d)", this.Index, g_iGlow[this.Index]);
					char classname[32];
					GetEntityClassname(g_iGlow[this.Index], classname, sizeof(classname));
					if (StrEqual(classname, "tf_glow"))
					{
						RemoveEntity(g_iGlow[this.Index]);
					}
				}
			}
			
			g_iGlow[this.Index] = CreateEntityByName("tf_glow");
			if (g_iGlow[this.Index] != -1)
			{
				// Get the player's current targetname
				char oldtname[64];
				GetEntPropString(this.Index, Prop_Data, "m_iName", oldtname, sizeof(oldtname));
				
				// Format a new, temporary targetname for the player
				char tname[32];
				Format(tname, sizeof(tname), "player_%d", this.Index);
				
				// Give the player the new targetname
				SetEntPropString(this.Index, Prop_Data, "m_iName", tname);
				
				// Tell the tf_glow to use the player's new targetname as its target
				DispatchKeyValue(g_iGlow[this.Index], "target", tname);
				
				// Set the tf_glow's default colour and alpha and spawn it
				DispatchKeyValue(g_iGlow[this.Index], "GlowColor", "0 0 0 0");
				if (!DispatchSpawn(g_iGlow[this.Index]))
					RemoveEntity(g_iGlow[this.Index]);
				
				// Restore the player's previous targetname
				SetEntPropString(this.Index, Prop_Data, "m_iName", oldtname);
				
				DebugEx(this.Index, "Created a tf_glow (%d) for %N", g_iGlow[this.Index], this.Index);
			}
			else
			{
				// Unable to create a tf_glow
				g_iGlow[this.Index] = 0;
			}
		}
		
		// Destroy a tf_glow
		else
		{
			if (g_iGlow[this.Index])
			{
				// If the player already has a valid tf_glow entity index stored, remove that entity 
				if (IsValidEntity(g_iGlow[this.Index]))
				{
					char classname[32];
					GetEntityClassname(g_iGlow[this.Index], classname, sizeof(classname));
					if (StrEqual(classname, "tf_glow"))
					{
						RemoveEntity(g_iGlow[this.Index]);
					}
				}
				
				g_iGlow[this.Index] = 0;
			}
		}
	}
	
	// Set TF Glow Colour
	public void SetTFGlowColor(int color[4])
	{
		if (!g_iGlow[this.Index])
			return;
		
		if (IsValidEntity(g_iGlow[this.Index]))
		{
			SetVariantColor(color);
			AcceptEntityInput(g_iGlow[this.Index], "SetGlowColor");
		}
	}	
}
