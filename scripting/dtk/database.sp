
Database g_db;


bool DBCreateTable()
{
	bool succeeded;
	char error[256];

	g_db = SQLite_UseDatabase(SQLITE_DATABASE, error, sizeof(error));

	if (g_db == null)
	{
		LogError("%s", error);
	}
	else
	{
		char query[256];

		Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS %s (steamid INTEGER PRIMARY KEY, points INTEGER, flags INTEGER, last_seen INTEGER DEFAULT 0)", SQLITE_TABLE);

		succeeded = SQL_FastQuery(g_db, query);

		if (!succeeded)
		{
			SQL_GetError(g_db, error, sizeof(error));
			LogError("%s", error);
		}
	}

	return succeeded;
}



bool DBPrune()
{
	if (g_db != null)
	{
		char query[256];
		Format(query, sizeof(query), "DELETE FROM %s WHERE last_seen <= %d", SQLITE_TABLE, GetTime() - SQLITE_RECORDS_EXPIRE);
		return (SQL_Query(g_db, query) != null);
	}

	return false;
}



bool DBDeleteTable()
{
	bool succeeded;
	char query[255];

	Format(query, sizeof(query), "DROP TABLE %s", SQLITE_TABLE);

	succeeded = SQL_FastQuery(g_db, query);

	if (!succeeded)
	{
		char error[256];
		SQL_GetError(g_db, error, sizeof(error));
		LogError("%s", error);
	}

	return succeeded;
}



bool DBCreateRecord(int steam_account, int queue_points, int flags, int last_seen)
{
	if (g_db == null)
	{
		return false;
	}

	char query[256];

	Format(query, sizeof(query), "INSERT INTO %s (steamid, points, flags, last_seen) VALUES (%d, %d, %d, %d)", SQLITE_TABLE, steam_account, queue_points, flags, last_seen);

	bool succeeded = SQL_FastQuery(g_db, query);

	if (!succeeded)
	{
		char error[256];
		SQL_GetError(g_db, error, sizeof(error));
		LogError("%s", error);
	}

	return succeeded;
}



DBResultSet DBQueryForRecord(int steam_account)
{
	DBResultSet result_set;

	if (g_db != null)
	{
		char query[256];

		Format(query, sizeof(query), "SELECT points, flags from %s WHERE steamid=%d", SQLITE_TABLE, steam_account);

		result_set = SQL_Query(g_db, query);
	}
	else
	{
		LogMessage("Database connection not established. Unable to fetch record for Steam account %d", steam_account);
	}

	return result_set;
}



bool DBGetRecordFromResult(DBResultSet result_set, int &points, int &flags, int &last_seen)
{
	bool record_exists = SQL_FetchRow(result_set);

	if (record_exists)
	{
		int field;

		result_set.FieldNameToNum("points", field);
		points = result_set.FetchInt(field);

		result_set.FieldNameToNum("flags", field);
		flags = result_set.FetchInt(field);

		result_set.FieldNameToNum("last_seen", field);
		last_seen = result_set.FetchInt(field);
	}

	return record_exists;
}



bool DBSaveData(int steam_account, int points, int flags, int last_seen)
{
	bool succeeded;
	char query[256];

	Format(query, sizeof(query), "UPDATE %s SET points=%d, flags=%d, last_seen=%d WHERE steamid=%d", SQLITE_TABLE, points, flags, last_seen, steam_account);

	succeeded = SQL_FastQuery(g_db, query, strlen(query));

	if (!succeeded)
	{
		char error[256];
		SQL_GetError(g_db, error, sizeof(error));
		LogError("%s", error);
	}

	return succeeded;
}



bool DBDeleteRecord(int steam_account)
{
	char query[256];

	Format(query, sizeof(query), "DELETE from %s WHERE steamid=%d", SQLITE_TABLE, steam_account);

	bool succeeded = SQL_FastQuery(g_db, query);

	if (!succeeded)
	{
		char error[256];
		SQL_GetError(g_db, error, sizeof(error));
		LogError("%s",  error);
	}

	return succeeded;
}