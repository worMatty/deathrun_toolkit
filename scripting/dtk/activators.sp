
#include "dtk/steamid.sp"	// for banning

/**
 * Player Allocation
 * ----------------------------------------------------------------------------------------------------
 */

/**
 * Check teams to see if we have the required number of players on each team
 */
void CheckTeams()
{
	/*
		While the plugin makes changes to teams, it disables Watch Mode.
		This prevents it from reacting to changes as if they were caused by players,
		or from going into an infinite loop of activator selection.

		Disable Watch Mode before performing team distrubution, and enable it when you're done.
	*/

	// Monitor Activators During Freeze Time
	if (DRGame.InWatchMode) {
		int activatorsNeeded = GetNumActivatorsRequired();

		if (g_Activators.Length < activatorsNeeded && GetActiveClientCount() > activatorsNeeded) {
			DRGame.InWatchMode = false;
			RequestFrame(SelectActivators);
		}
	}
	/*
	// Fixed by enabling the Unbalance cvar at < 2 participants, forcing the next player onto the opposing team
	else if (!DRGame.InWatchMode && DRGame.Participants < 2)	// Go into Watch Mode when insufficient participants
	{
		Debug("Insufficient participants for a round, so Watch Mode will be enabled");
		DRGame.InWatchMode = true;
	}
	*/

	// The Unbalancing ConVar helps manage Round Restart when the server is empty
	if (GetActiveClientCount() > 1) {
		g_ConVars[S_Unbalance].IntValue = 0;
	}
	else {
		g_ConVars[S_Unbalance].RestoreDefault();
	}
}

/**
 * Select and move eligible activators
 *
 * @noreturn
 */
void SelectActivators()
{
	ArrayList pool		   = CreateActivatorPool();

	// If we need activators and have enough on red to supply and not empty the team, move someone
	int		  i			   = 0;
	int		  num_required = GetNumActivatorsRequired();

	while (TFTeam_Blue.Count() < num_required && TFTeam_Red.Count() > 1 && i < pool.Length) {
		DRPlayer player = DRPlayer(pool.Get(i));

		if (player.InGame && player.Team == Team_Red) {
			player.MakeActivator();
			player.SetTeam(Team_Blue, true);

			if (GameRules_GetRoundState() != RoundState_Pregame) {
				player.Points		 = 0;
				player.ActivatorLast = GetTime();

				TF2_PrintToChat(player.Index, _, "%t", "you_are_an_activator");
				EmitMessageSoundToClient(player.Index);

				if (g_bSCR && g_ConVars[P_SCR].BoolValue) {
					SCR_SendEvent("Deathrun Activator Selected", "%N", player.Index);
				}

				if (num_required == 1) {
					CreateTimer(0.1, Timer_AnnounceActivatorToAll, player.Index);
				}
			}
		}

		i++;
	}

	// Go into watch mode to replace activator if needed
	DRGame.InWatchMode = true;
}

Action Timer_AnnounceActivatorToAll(Handle timer, int client)
{
	char name[32];
	GetClientName(client, name, sizeof(name));

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i) && i != client) {
			TF2_PrintToChat(i, client, "%t", "name_has_been_made_activator", name);
		}
	}

	return Plugin_Stop;
}

/**
 * Get the number of activators needed
 * @return		int		Number of activators
 */
int GetNumActivatorsRequired()
{
	// Get the ratio of activators to participants
	int activators = RoundFloat(GetActiveClientCount() * g_ConVars[P_ActivatorRatio].FloatValue);

	// If we have specified an activator cap, clamp to it
	if (g_ConVars[P_ActivatorsMax].IntValue > -1) {
		ClampInt(activators, 1, g_ConVars[P_ActivatorsMax].IntValue);
	}

	// else, clamp between 1 and participants -1
	ClampInt(activators, 1, GetActiveClientCount() - 1);

	return activators;
}

/**
 * Create an ArrayList of valid activators for selection
 * sorted by order of queue points, then time last activator.
 * Filters players who prefer not to be activator, or who are activator-banned.
 * These conditions are ignored on low participant numbers.
 *
 * @return	ArrayList		List of client indexes
 */
ArrayList CreateActivatorPool()
{
	ArrayList activator_pool = new ArrayList();
	int		  len, pool;
	bool	  use_all;

	// get array of willing players
	for (int i = 1; i <= MaxClients; i++) {
		DRPlayer player = DRPlayer(i);

		if (player.InGame && (player.Team == Team_Red || player.Team == Team_Blue) && player.PrefersActivator && !player.ActivatorBanned) {
			pool += 1;
		}
	}

	// if too few willing, set use_all to true and len to count of all active players
	if (pool < MINIMUM_WILLING) {
		len		= GetActiveClientCount();
		use_all = true;
	}
	else {
		len = pool;
	}

	// return early if no active players
	if (len == 0) {
		return activator_pool;
	}

	// create sorted list of activators
	int[][] list = new int[len][3];
	int count;

	for (int i = 1; i <= MaxClients; i++) {
		DRPlayer player = DRPlayer(i);

		if (player.InGame && player.IsParticipating) {
			// skip over players who are unwilling or banned, if we are not using all players
			if (!use_all && (!player.PrefersActivator | player.ActivatorBanned)) {
				continue;
			}

			list[count][0] = player.Index;
			list[count][1] = player.Points;
			list[count][2] = player.ActivatorLast;
			count++;
		}
	}

	// sort players by queue points & last time activator
	SortCustom2D(list, len, SortPlayers, (len <= MINIMUM_WILLING) ? g_ConVars[P_BotActivatorOnLow] : null);

	// push sorted list into arraylist
	for (int i = 0; i < len; i++) {
		activator_pool.Push(list[i][0]);
	}

	return activator_pool;
}

/**
 * Sorting function used by SortCustom2D. Sorts players by queue points
 * and last activator time.
 * @return	int
 */
int SortPlayers(int[] player1, int[] player2, const int[][] array, Handle hndl)
{
	// [0] client index
	// [1] queue points
	// [2] last time activator timestamp
	int index = 0, points = 1, lasttime = 2;

	// compare player1 and player2's values
	// returning 1 moves player2 up by one position

	// move bots up by 1 if that convar is enabled
	if (hndl != null && g_ConVars[P_BotActivatorOnLow].BoolValue) {
		Debug("Got to move bots to the top");

		// lower the human
		if (IsFakeClient(player1[index]) && !IsFakeClient(player2[index])) {
			Debug("Lowering %N", player2[index]);
			return -1;
		}

		// bump the bot
		if (!IsFakeClient(player1[index]) && IsFakeClient(player2[index])) {
			Debug("Raising %N", player2[index]);
			return 1;
		}
	}

	// same points
	if (player1[points] == player2[points]) {
		// check last time
		if (player1[lasttime] > player2[lasttime]) {
			return 1;
		}
		else if (player1[lasttime] < player2[lasttime]) {
			return -1;
		}
		else {
			return 0;
		}
	}

	// player1 has fewer points
	else if (player1[points] < player2[points]) {
		return 1;
	}

	// player1 has more points
	else {
		return -1;
	}

	// if (b[1] == a[1])	 // B and A have the same points
	// {
	// 	if (b[2] < a[2])	// B has an earlier Activator time than A
	// 	{
	// 		return 1;
	// 	}
	// 	else if (b[2] > a[2])	 // B has a later Activator time than A
	// 	{
	// 		return -1;
	// 	}
	// 	else	// B and A have the same Activator time
	// 	{
	// 		return 0;
	// 	}
	// }
	// else if (b[1] > a[1])	 // B has more points than A
	// {
	// 	return 1;
	// }
	// else	// B has fewer points than A
	// {
	// 	return -1;
	// }
}

/**
 * Format a string containing the names of the next specified number of activators.
 *
 * @return		int		Number of cells written
 */
int FormatNextActivators(char[] buffer, int max = 3, int maxlength = MAX_CHAT_MESSAGE)
{
	int		  cells;
	ArrayList pool = CreateActivatorPool();

	// Format the message
	if (pool.Length > 0) {
		cells += Format(buffer, maxlength, "%t", (pool.Length == 1 || max == 1) ? "next_activator" : "next_activators");

		for (int i; max > i < pool.Length; i++) {
			if (i == 0)	   // is first name
			{
				int client = pool.Get(i);
				cells += Format(buffer, maxlength, "%s\x03%N", buffer, client);
			}
			else {
				int client = pool.Get(i);
				cells += Format(buffer, maxlength, "%s\x01, \x03%N", buffer, client);
			}
		}
	}

	return cells;
}
