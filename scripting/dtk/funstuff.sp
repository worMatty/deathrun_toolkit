
/**
 * Commands
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Test the activator health scaling.
 * 
 * @noreturn
 */
void FunStuff_ScaleHealth()
{
	Player(g_iBoss).ScaleHealth();
}



/**
 * Make red players a pyro and give them a jetpack with unlimited uses.
 * Give them a slow run speed.
 * 
 * @noreturn
 */
void FunStuff_JetpackGame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).Team == Team_Red)
		{
			//int weapon = player.GetWeapon(Weapon_Secondary);
			//if (weapon != -1) RemoveEdict(weapon);
			Player(i).SetClass(Class_Pyro);
			Player(i).SetSpeed(150);
			
			RequestFrame(RequestFrame_Jetpacks, i);
		}
	}
}

void RequestFrame_Jetpacks(int client)
{
	int weapon = Player(client).GetWeapon(Weapon_Secondary);
	
	weapon = ReplaceWeapon(client, weapon, 1179, "tf_weapon_rocketpack");
	
	if (weapon != -1)
	{
		TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.01);
		Player(client).SetSlot(Weapon_Secondary);
	}
}
