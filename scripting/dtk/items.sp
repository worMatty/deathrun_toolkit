
KeyValues g_Replacements;
KeyValues g_Restrictions;

void	  Items_Init()
{
	LoadConfigs();
}

/**
 * Load the restriction system config files
 * @noreturn
 */
void LoadConfigs()
{
	g_Restrictions = new KeyValues("restrictions");
	g_Replacements = new KeyValues("replacements");

	if (!g_Restrictions.ImportFromFile(WEAPON_RESTRICTIONS_CFG)) {
		LogError("Failed to load weapon restriction config \"%s\"", WEAPON_RESTRICTIONS_CFG);
	}

	if (!g_Replacements.ImportFromFile(WEAPON_REPLACEMENTS_CFG)) {
		LogError("Failed to load weapon replacement config \"%s\"", WEAPON_REPLACEMENTS_CFG);
	}
}

/*
get the player's weapons and cosmetics
check each of them
pull up any entries and combine attributes
if this, then that
*/

/**
 * Check all of the player's equipped items by iterating across their weapon slots
 * @param	client		Client index
 */
void CheckItems(int client)
{
	if (g_Restrictions == null) {
		return;
	}

	// check weapon slots
	for (int slot; slot < 7; slot++) {	  // highest weapon slot used
		int item = GetPlayerWeaponSlot(client, slot);
		if (item != -1) {
			CheckItem(client, item, slot);
		}
	}

	// check wearables
	ArrayList wearables = GetWearables(client);
	for (int i = wearables.Length - 1; i >= 0; i--) {
		CheckItem(client, wearables.Get(i));
	}
}

/**
 * Check an item to see if it's restricted and modify, replace or remove it
 *
 * @param	client		Client index
 * @param	item		Entity index of the item
 * @param	slot		Weapon slot the item occupies on the client
 */
void CheckItem(int client, int item, int slot = -1)
{
	KeyValues kv = GetItemRestrictions(item);

	// no restrictions found
	if (!kv.GotoFirstSubKey(false)) {
		delete kv;
		return;
	}

	kv.GoBack();

	/*
		Wearables have m_hWeaponAssociatedWith
		Can't find a way to tell what slot wearable weapons replace
	*/

	// remove
	if (kv.JumpToKey("remove")) {
		if (slot != -1) {
			TF2_RemoveWeaponSlot(client, slot);
		}
		else {
			TF2_RemoveWearable(client, item);
			// AcceptEntityInput(item, "Kill");
		}
	}

	// replace
	else if (kv.JumpToKey("replace")) {
		int	 idi;
		char classname[64];
		GetEdictClassname(item, classname, sizeof(classname));

		if (!StrEqual(classname, "dtk_weapon") && GetReplacementItem(TF2_GetPlayerClass(client), slot, idi, classname, sizeof(classname))) {
			int replacement = ReplaceWeapon(client, idi, classname, slot);

			if (replacement != -1) {
				CheckItem(client, replacement, slot);
			}
		}
	}

	// attributes
	else if (kv.JumpToKey("attributes")) {
		char  name[128];
		float value;

		kv.GotoFirstSubKey(false);
		do {
			kv.GetSectionName(name, sizeof(name));
			value = kv.GetFloat(NULL_STRING);
			AddAttribute(item, name, value);
		}
		while (kv.GotoNextKey(false))
	}

	delete kv;
}

/**
 * Get a client's wearables
 * @param	client		Client index
 * @return				ArrayList containing wearable edict indexes
 */
stock ArrayList GetWearables(int client)
{
	ArrayList wearables = new ArrayList();
	char	  classname[64];
	int		  ent = GetEntPropEnt(client, Prop_Data, "m_hMoveChild");

	while (IsValidEntity(ent)) {
		GetEdictClassname(ent, classname, sizeof(classname));
		if (StrContains(classname, "tf_wearable") == 0 && GetEntProp(ent, Prop_Send, "m_iItemDefinitionIndex") != 65535) {
			wearables.Push(ent);
		}
		ent = GetEntPropEnt(ent, Prop_Data, "m_hMovePeer");
	}

	return wearables;
}

/**
 * Given the edict index of an item, scan the restrictions keyvalue structure for entries
 * for its item definition index or classname and return the found entry as a KV structure.
 * It will continue to follow goto instructions until they stop, or a maximum of five times.
 * @param	item		Edict index of item
 * @return				KeyValues structure containing the restriction keyvalues for the item
 */
KeyValues GetItemRestrictions(int item)
{
	KeyValues kv  = new KeyValues("restrictions");

	int		  idi = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
	int		  goto_count;
	char	  sidi[8], classname[64];

	IntToString(idi, sidi, sizeof(sidi));
	GetEdictClassname(item, classname, sizeof(classname));

	if (g_Restrictions.JumpToKey(sidi) || g_Restrictions.JumpToKey(classname)) {
		char next_section[64];
		g_Restrictions.GetString("goto", next_section, sizeof(next_section));

		// loop through gotos
		while (next_section[0] != '\0' && goto_count <= 5) {
			goto_count++;
			g_Restrictions.Rewind();
			g_Restrictions.JumpToKey(next_section);
			g_Restrictions.GetString("goto", next_section, sizeof(next_section));
		}

		if (KvNodesInStack(g_Restrictions) > 0) {
			KvCopySubkeys(g_Restrictions, kv);
		}

		g_Restrictions.Rewind();
	}

	return kv;
}

/**
 * Given a TF2 class number and weapon slot number, find a replacement weapon to suit the class's
 * slot from the replacements KeyValues structure.
 * @param	class		TF2 class
 * @param	slot		Weapon slot
 * @param	idi			Variable to store the item definition index of the replacement weapon
 * @param	classname	String to store the classname of the replacement weapon
 * @param	maxlen		The max length of the classname string
 * @return				True if a replacement was found, false if not
 */
bool GetReplacementItem(TFClassType class, int slot, int &idi, char[] classname, int maxlen)
{
	bool success;
	char sclass[2], sslot[2];

	IntToString(view_as<int>(class), sclass, sizeof(sclass));
	IntToString(slot, sslot, sizeof(sslot));

	if (g_Replacements.JumpToKey(sclass)) {
		if (g_Replacements.JumpToKey(sslot)) {
			idi = g_Replacements.GetNum("id", -1);
			g_Replacements.GetString("classname", classname, maxlen);

			if (idi != -1 && classname[0] != '\0') {
				success = true;
			}
		}
	}

	g_Replacements.Rewind();
	return success;
}

/**
 * Remove a player's weapon and replace it with a new one.
 *
 * @param	client			Client index
 * @param	oldweapon		Current weapon
 * @param	itemDefIndex	New weapon item definition index
 * @param	classname		New weapon classname
 * @param	slot			Weapon slot
 * @return					Entity index of new weapon. -1 if failed to create
 */
int ReplaceWeapon(int client, int itemDefIndex, char[] classname, int slot)
{
	int entindex = CreateWeapon(client, itemDefIndex, classname);

	if (entindex != -1) {
		TF2_RemoveWeaponSlot(client, slot);
		EquipPlayerWeapon(client, entindex);
	}

	return entindex;
}

/**
 * Create a new weapon entity
 * @param	client			Client index the weapon is meant for
 * @param	itemDefIndex	New weapon item definition index
 * @param	classname		New weapon classname
 * @return					New weapon entity index or -1 if failed to create
 */
int CreateWeapon(int client, int itemDefIndex, char[] classname)
{
	int entindex;

	if (g_bTF2Items) {
		Handle weapon = TF2Items_CreateItem(OVERRIDE_ALL | FORCE_GENERATION);
		TF2Items_SetClassname(weapon, classname);
		TF2Items_SetItemIndex(weapon, itemDefIndex);
		TF2Items_SetLevel(weapon, 0);
		TF2Items_SetQuality(weapon, 0);
		TF2Items_SetNumAttributes(weapon, 0);
		entindex = TF2Items_GiveNamedItem(client, weapon);
		delete weapon;
	}
	else {
		int weapon = CreateEntityByName(classname);

		if (weapon != -1) {
			int team = GetClientTeam(client);
			entindex = weapon;

			SetEntProp(weapon, Prop_Send, "m_iTeamNum", team);
			SetEntProp(weapon, Prop_Send, "m_bInitialized", 1);
			SetEntProp(weapon, Prop_Send, "m_bValidatedAttachedEntity", 1);
			SetEntProp(weapon, Prop_Send, "m_iEntityLevel", 0);
			SetEntProp(weapon, Prop_Send, "m_iEntityQuality", 0);
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", itemDefIndex);
			SetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity", client);
			SetEntityTargetname(weapon, "dtk_weapon");

			if (!DispatchSpawn(weapon)) {
				RemoveEntity(weapon);
				entindex = -1;
			}
		}
	}

	return entindex;
}