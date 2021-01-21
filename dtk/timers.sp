
/**
 * Timers
 * ----------------------------------------------------------------------------------------------------
 */

stock Action TimerCB_HealthBar(Handle timer)
{
	Debug("Hiding the health bar");
	if (g_iEnts[Ent_MonsterRes] != -1)
		SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossHealthPercentageByte", 0);
	HealthText();
	game.RemoveFlag(FLAG_HEALTH_BAR_ACTIVE);
	g_hTimers[Timer_HealthBar] = null;	// Matty you must remember to null handles when the timer is done
}



stock Action TimerCB_OFTeamCheck(Handle timer)
{
	if (game.RoundState == Round_Active)
	{
		// Enough participants but fewer than one alive player per team.
		if (game.Participants >= 2 && (!game.AliveReds || !game.AliveBlues))
		{
			Debug("Open Fortress: We have enough participants to start a round");
			ServerCommand("mp_restartgame 5");
			//CheckForPlayers();
			return Plugin_Stop;
		}
		else
		{
			Debug("Open Fortress: Not enough participants or things are fine!");
			return Plugin_Continue;
		}
	}
	else
	{
		Debug("Open Fortress: Ronund is not active. Stopping the team check timer");
		return Plugin_Stop;	
	}
}