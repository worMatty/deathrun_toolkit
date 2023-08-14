
KeyValues g_Replacements;
KeyValues g_Restrictions;


void Items_Init()
{
    LoadConfigs();
}


/**
 * Load the restriction system config files
 *
 * @noreturn
 */
void LoadConfigs()
{
	g_Restrictions = new KeyValues("restrictions");
	g_Replacements = new KeyValues("replacements");

	if (!g_Restrictions.ImportFromFile(WEAPON_RESTRICTIONS_CFG))
	{
		LogError("Failed to load weapon restriction config \"%s\"", WEAPON_RESTRICTIONS_CFG);
	}

	if (!g_Replacements.ImportFromFile(WEAPON_REPLACEMENTS_CFG))
	{
		LogError("Failed to load weapon replacement config \"%s\"", WEAPON_REPLACEMENTS_CFG);
	}
}


/**
 * Check all of the player's equipped items by iterating across their weapon slots
 *
 * @param	client		Client index
 * @noreturn
 */
void CheckItems(int client)
{
	if (g_Restrictions == null)
	{
		return;
	}

	for (int slot; slot < 7; slot++)		// highest weapon slot used
	{
		int item = GetPlayerWeaponSlot(client, slot);

		if (item != -1)
		{
			CheckItem(client, item, slot);
		}
	}
}


/**
 * Check and item to see if it's restricted and modify, replace or remove it
 *
 * @param	client		Client index
 * @param	item		Entity index of the item
 * @param	slot		Weapon slot the item occupies on the client
 * @noreturn
 */
void CheckItem(int client, int item, int slot)
{
	char key[16];

	int definition_index = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
	IntToString(definition_index, key, sizeof(key));


	/**
	 * Check if the restrictions config is loaded
	 */
	if (!g_Restrictions.JumpToKey(key))
	{
		return;	// item not found in config
	}


	/**
	 * Check if the plugin can apply attributes, and if the item has an attributes field
	 * in the restrictions config. If either are false, the code will naturally fall through to
	 * replacement or removal, if they are specified.
	 */
	if (DRGame.AttributesSupported && g_Restrictions.JumpToKey("attributes"))
	{
		if (g_Restrictions.GotoFirstSubKey())
		{
			do
			{
				char attribute[128];
				float value = g_Restrictions.GetFloat("value");

				g_Restrictions.GetString("name", attribute, sizeof(attribute));

				if (attribute[0] != '\0')
				{
					AddAttribute(item, attribute, value);
					PrintToConsole(client, "Gave your weapon in slot %d the attribute \"%s\" with value %.2f", slot, attribute, value);
				}
				else	// attribute key not found
				{
					char section[16];
					g_Restrictions.GetSectionName(section, sizeof(section));
					LogError("Weapon restrictions > %d > attributes > %s > Attribute name key not found", definition_index, section);
				}
			}
			while (g_Restrictions.GotoNextKey());
		}
		else	// no attributes specified
		{
			LogError("Weapon restrictions > %d > attributes > No attribute sections found", definition_index);
		}
	}


	/**
	 * Replace the item
	 */
	else if (g_Restrictions.JumpToKey("replace"))	// should the item be replaced
	{
		Player player = Player(client);
		IntToString(player.Class, key, sizeof(key));

		if (g_Replacements.JumpToKey(key))	// jump to class
		{
			IntToString(slot, key, sizeof(key));

			if (g_Replacements.JumpToKey(key)) // jump to slot
			{
				char id[16], classname[128];
				g_Replacements.GetString("id", id, sizeof(id));
				g_Replacements.GetString("classname", classname, sizeof(classname));

				if (id[0] == '\0')
				{
					LogError("Weapon replacements > %d > %d > id key or value not found", player.Class, slot);
				}
				else if (classname[0] == '\0')
				{
					LogError("Weapon replacements > %d > %d > classname key or value not found", player.Class, slot);
				}
				else if (ReplaceWeapon(client, item, g_Replacements.GetNum("id"), classname))
				{
					PrintToConsole(client, "Replaced your weapon in slot %d with a %s (type %d)", slot, classname, g_Replacements.GetNum("id"));
				}
			}
			else	// slot not found
			{
				LogError("Weapon replacements > %d > Weapon slot %d not found", player.Class, slot);
			}
		}
		else	// class not found
		{
			LogError("Weapon replacements > Class %d not found", player.Class);
		}

		g_Replacements.Rewind();
	}


	/**
	 * Remove the item
	 */
	else if (g_Restrictions.JumpToKey("remove"))	// Remove Weapon
	{
		if (AcceptEntityInput(item, "Kill"))
		{
			PrintToConsole(client, "Removed your weapon in slot %d", slot);
		}
	}


	/**
	 * The item is found in the restriction config but has no valid action
	 */
	else
	{
		LogError("Weapon restrictions > %d > No valid actions found", definition_index);
	}

	g_Restrictions.Rewind();
}


/**
 * Remove a player's weapon and replace it with a new one.
 *
 * @param	client			Client index
 * @param	oldweapon		Current weapon
 * @param	itemDefIndex	New weapon item definition index
 * @param	classname		New weapon classname
 * @return	Entity index of new weapon. -1 if failed to create
 */
int ReplaceWeapon(int client, int oldweapon, int itemDefIndex, char[] classname)
{
	int weapon = CreateWeapon(itemDefIndex, classname);

	if (weapon != -1)
	{
		int team = GetClientTeam(client);
		SetEntProp(weapon, Prop_Send, "m_iTeamNum", team);
		SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
		// EquipPlayerWeapon(client, weapon);

		int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
		int offset = FindSendPropInfo("CTFPlayer", "m_hMyWeapons");

		for (int i; i < size; i++)
		{
			int entity = GetEntDataEnt2(client, offset + (i * 4));

			if (entity == oldweapon)
			{
				SetEntDataEnt2(client, offset + (i * 4), weapon, true);
			}
		}

		RemoveEntity(oldweapon);
	}
	else
	{
		LogError("Failed to create a new weapon for %N", client);
	}

	return weapon;
}


/**
 * Create a new weapon
 *
 * @param	itemDefIndex	New weapon item definition index
 * @param	classname		New weapon classname
 * @return	New weapon entity index
 */
int CreateWeapon(int itemDefIndex, char[] classname)
{
	int weapon = CreateEntityByName(classname);

	if (weapon != -1)
	{
		SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
		SetEntProp(weapon, Prop_Send, "m_bInitialized", true);
		SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", true);
		SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
		SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);

		if (!DispatchSpawn(weapon))
		{
			RemoveEntity(weapon);
			weapon = -1;
		}
	}

	return weapon;
}
