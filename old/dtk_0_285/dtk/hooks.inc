
Action Hook_OnTakeDamage(int victim, int& attacker, int& inflictor, float& damage, int& damagetype, int& weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	bool bChanged;

	// Adjust boss health bar
	if (g_cUseActivatorHealthBar.BoolValue)
	{
		if (attacker != victim && victim == g_iHealthBarTarget)
		{
			g_bHealthBarActive = true;
			RequestFrame(SetHealthBar);
		}
	}
	
	// Cap backstab damage on the activator at 300
	if (damagecustom == TF_CUSTOM_BACKSTAB && victim == g_iHealthBarTarget)
	{
		damage = 100.0;
		bChanged = true;
	}
	
	// Blast pushing prevention
	if (GetClientTeam(victim) == Team_Red && attacker == victim)
	{
		switch (g_cBlastPushing.IntValue)
		{
			case 0:						// Negate blast pushing
			{
				damage = 0.0;
			}
			case 1:						// Allow blast pushing
			{
				return Plugin_Continue;
			}
			case 2:						// Reduce blast pushing
			{
				switch (TF2_GetPlayerClass(victim))
				{
					case TFClass_Soldier:
					{
						if (damage > 35)
							damage = 35.0;
					}
					case Class_DemoMan:	// TODO Find a better way of controlling sticky jump distance
					{
						damage = 2.2;
					}
				}
			}
		}
		bChanged = true;
	}
	
	if (bChanged)
		return Plugin_Changed;
	else
		return Plugin_Continue;
}



