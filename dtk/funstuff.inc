
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
	Player activator = new Player(g_iBoss);
	activator.ScaleHealth();
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
		Player player = new Player(i);
		
		if (player.InGame && player.Team == Team_Red)
		{
			//int weapon = player.GetWeapon(Weapon_Secondary);
			//if (weapon != -1) RemoveEdict(weapon);
			player.SetClass(Class_Pyro);
			player.SetSpeed(150);
			
			RequestFrame(RequestFrame_Jetpacks, player);
		}
	}
}

void RequestFrame_Jetpacks(Player player)
{
	int weapon = player.GetWeapon(Weapon_Secondary);
	
	weapon = ReplaceWeapon(player.Index, weapon, 1179, "tf_weapon_rocketpack");
	
	if (weapon != -1)
	{
		TF2Attrib_SetByName(weapon, "item_meter_charge_rate", 0.01);
		player.SetSlot(Weapon_Secondary);
	}
}
