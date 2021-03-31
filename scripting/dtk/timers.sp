
/**
 * Timers
 * ----------------------------------------------------------------------------------------------------
 */

Action Timer_HealthBar(Handle timer)
{
	if (g_iEnts[Ent_MonsterRes] != -1)
		SetEntProp(g_iEnts[Ent_MonsterRes], Prop_Send, "m_iBossHealthPercentageByte", 0);
	HealthText();
	game.IsBossBarActive = false;
	g_TimerHPBar = null;
}




Action Timer_OFTeamCheck(Handle timer)
{
	// OF starts the round regardless if there aren't enough players
	// A round in progress will only end when one team is dead and the other has live players
	if (game.RoundState == Round_Active && (!TFTeam_Red.Alive() && !TFTeam_Blue.Alive()) && game.Participants >= 1)
	{
		Debug("Stalled round detected. Restarting in five seconds");
		ChatMessageAll("%t", "restarting_round_seconds", 5);
		ServerCommand("mp_restartgame 5");
	}
}




Action Timer_GrantPoints(Handle timer)
{
	// Give each red player QP
	for (int i = 1; i <= MaxClients; i++)
	{
		if (Player(i).InGame && Player(i).Team == Team_Red)
		{
			Player(i).AddPoints(QP_Award);
		}
	}
}