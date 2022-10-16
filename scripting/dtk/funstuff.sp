
/**
 * Commands
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Test the activator health scaling.
 * 
 * @noreturn
 */
void FunStuff_ScaleHealth(int commander)
{
	int health = ScaleActivatorHealth();
	
	if (health)
	{
		TF2_PrintToChatAll(_, "Scaled total activator health to %d", health);
		EmitMessageSoundToAll();
	}
	else
	{
		TF2_PrintToChat(commander, _, "Unable to scale any activator's health");
		EmitMessageSoundToClient(commander);
	}
}



/**
 * Make red players a pyro and give them a jetpack with unlimited uses.
 * Give them a slow run speed.
 * 
 * @noreturn
 */
void FunStuff_JetpackGame()
{
	float time;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(Team_Red))
		{
			CreateTimer(time, Timer_Jetpacks, i);
			time += 0.5;
		}
	}
}

Action Timer_Jetpacks(Handle timer, int client)
{
	Player player = Player(client);
	
	if (player.InGame && player.Team == Team_Red && player.IsAlive)
	{
		int weapon = CreateWeapon(1179, "tf_weapon_rocketpack");
		
		if (weapon != -1)
		{
			player.SetClass(Class_Pyro);
			
			int oldweapon = player.GetWeapon(Weapon_Secondary);
			
			if (oldweapon != -1)
			{
				RemoveEntity(oldweapon);
				GiveWeapon(client, weapon);
				AddAttribute(weapon, "item_meter_charge_rate", 0.01);
				CreateTimer(0.1, Timer_Jetpacks2, client);
				
				TF2_PrintToChat(client, _, "You are now a pyro with unlimited jet pack uses");
				EmitMessageSoundToClient(client);
			}
			else
			{
				RemoveEntity(weapon);
				TF2_PrintToChat(client, _, "We tried to make you a pyro with a jetpack but it went missing");
				EmitMessageSoundToClient(client);
			}
			
			
		}
	}
}

Action Timer_Jetpacks2(Handle timer, int client)
{
	Player player = Player(client);
	player.SetSlot(Weapon_Secondary);
}




/**
 * Slap runners every ten seconds
 * 
 * @noreturn
 */
void FunStuff_PeriodicSlap()
{
	CreateTimer(10.0, Timer_PeriodicSlap, _, TIMER_REPEAT);
	TF2_PrintToChatAll(_, "Runners will now be slapped every ten seconds");
	EmitMessageSoundToAll();
}

Action Timer_PeriodicSlap(Handle timer)
{
	if (DRGame.RoundState == Round_Active)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			Player player = Player(i);
			
			if (player.InGame && player.Team == Team_Red && player.IsAlive)
			{
				SlapPlayer(i, 0);
			}
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}