#include <regex>

/**
 * Get a Steam account number from a Steam2 or 3 auth Id
 *
 * @param		char	Auth Id string
 * @return		int		Steam account number, or 0 if input not recognised
 */
stock int GetSteamAccountIdFromSteamId(const char[] authid)
{
	int auth_type = GetSteamIdType(authid);
	
	if (auth_type == 0)
	{
		return 0;
	}
	
	int steam_account;
	
	if (auth_type == 2)
	{
		steam_account = GetSteamAccountFromId2(authid);
	}
	else if (auth_type == 3)
	{
		steam_account = GetSteamAccountFromId3(authid);
	}
	
	return steam_account;
}



/**
 * Get the Steam auth Id type
 * Currently only recognises types 2 and 3
 *
 * @param		char		Input auth Id
 * @return		int			2, 3, or 0 if not recognised.
 */
stock int GetSteamIdType(const char[] steam_id)
{
	// Steam2: STEAM_0:0:523696
	if (strncmp(steam_id, "STEAM_", 6) == 0 && steam_id[7] == ':')
	{
		return 2;
	}
	
	int len = strlen(steam_id);
	
	// Steam3: [U:1:1047392]
	if ((strncmp(steam_id, "[U:", 3) == 0) && (steam_id[len - 1] == ']'))
	{
		return 3;
	}
	
	// Steam Id 64: 76561197961313120
	// 0000000100010000000000000000000100000000000011111111101101100000
	
	// STEAM_X:Y:Z
	// Universe Type Instance             Account number ----------------->
	// 00000001 0001 00000000000000000001 0000000000001111111110110110000 0
	// X                                  Z                               Y
	
	// No information on instances
	
	// Type 1 equates to U in Steam3 format
	
	/*	else
	{
		bool numeric = IsStringNumeric(steam_id);
		// and other stuff
		return 64;
	}
*/
	return 0;
}



/**
 * Get a Steam account number from a Steam3 Id string
 * Steam3: [U:1:1047392]
 * Result: 1047392
 *
 * @param		char	Input Steam3 Id
 * @return		int		Steam account number, or 0 on failure
 */
stock int GetSteamAccountFromId3(const char[] steam_id3)
{
	Regex exp = new Regex("^\\[U:1:\\d+]$");
	int matches = exp.Match(steam_id3);
	delete exp;
	
	if (matches != 1)
	{
		return 0;
	}

	int i = 5;
	char account_number[64];
	
	while (steam_id3[i] != ']' && steam_id3[i] != '\0')
	{
		Format(account_number, sizeof(account_number), "%s%c", account_number, steam_id3[i]);
		i++;
	}
	
	return StringToInt(account_number);
}



/**
 * Get a Steam account number from a Steam2 Id string
 * Steam2: STEAM_0:0:523696
 * Result: 1047392
 *
 * @param		char	Input Steam2 Id
 * @return		int		Steam account number, or 0 on failure
 */
stock int GetSteamAccountFromId2(const char[] steam_id)
{
	Regex exp = new Regex("^STEAM_[0-5]:[0-1]:[0-9]+$");
	int matches = exp.Match(steam_id);
	delete exp;
	
	if (matches != 1)
	{
		return 0;
	}
	
	return StringToInt(steam_id[10]) * 2 + (steam_id[8] - 48);
}


/**
 * Convert a Steam3 Id to a Steam2 Id
 * Steam3: [U:1:1047392]
 * Steam2: STEAM_0:0:523696
 *
 * @param		char	Steam3 Id
 * @param		char	Output Steam2 Id
 * @return		int		Number of characters written
 */
stock int GetSteam2FromSteam3(const char[] steamid3, char[] steamid2)
{
	int len;
	char buffer[64];
	int account_id = GetSteamAccountFromId3(steamid3);
	int remainder = account_id % 2;
	
	if (account_id == 0)
	{
		return 0;
	}
	
	len = 1 + Format(buffer, sizeof(buffer), "STEAM_0:%d:%d", remainder, (account_id - remainder) / 2);
	strcopy(steamid2, len, buffer);
	
	return len;
}


// Thank you Illusion9
// https://forums.alliedmods.net/showthread.php?t=324112


// Sussy bakas
/*
stock int GetSteam2FromAccountId(char[] result, int maxlen, int account_id)
{
    return Format(result, maxlen, "STEAM_1:%d:%d", view_as<bool>(account_id % 2), account_id / 2);
}

stock int GetSteam64FromAccountId(int account_id)
{
    return account_id + 76561197960265728;
}

stock int GetAccountIdFromSteam64(int steam64)
{
    return steam64 - 76561197960265728;
} 
*/


/**
 * Get a client index from a Steam account number
 *
 * @param		int		Steam account number
 * @return		int		Client index if a player with a matching account number is found, 0 otherwise
 */
stock int GetClientFromSteamAccount(int steam_account)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			int account_id = GetSteamAccountID(i);
			
			if (account_id == steam_account)
			{
				return i;
			}
		}
	}
	
	return 0;
} 