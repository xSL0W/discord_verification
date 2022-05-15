void AccountsCheck()
{
	Action action = Plugin_Continue;
	Call_StartForward(g_hOnCheckedAccounts);
	Call_PushString(g_sBotToken);
	Call_PushString(g_sGuildID);
	Call_PushString(g_sTableName);
	Call_Finish(action);

	if(action >= Plugin_Handled)
	{
		return;
	}
	/*
	if(g_hDB == null)
	{
		CreateTimer(5.0, Timer_Query_AccountCheck, _, TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		char Query[256];
		g_hDB.Format(Query, sizeof(Query), "SELECT userid FROM %s", g_sTableName);
		SQL_TQuery(g_hDB, SQLQuery_AccountCheck, Query);
	}
	*/
	delete hFinalMemberList;
	Handle hData = json_object();
	hFinalMemberList = json_array();
	json_object_set_new(hData, "limit", json_integer(1000));
	json_object_set_new(hData, "after", json_string(""));
	GetMembers(hData);
	//PrintToChatAll("AccountsCheck();");
}

void GetMembers(Handle hData = INVALID_HANDLE)
{
	if(StrEqual(g_sGuildID, "") && !StrEqual(g_sVerificationChannelID, ""))
	{
		LogError("[Discord-Utilities] GuildID is not provided. GetMember won't work!");
		delete hData;
		delete hFinalMemberList;
		return;
	}
	if(Bot == null)
	{
		delete hData;
		delete hFinalMemberList;
		return;
	}
	int limit = JsonObjectGetInt(hData, "limit");
	char after[32];
	JsonObjectGetString(hData, "after", after, sizeof(after));

	char url[256];
	if(StrEqual(after, ""))
	{
		FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/members?limit=%i", g_sGuildID, limit);
	}
	else
	{
		FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/members?limit=%i&after=%s", g_sGuildID, limit, after);
	}

	char route[128];
	FormatEx(route, sizeof(route), "guild/%s/members", g_sGuildID);

	DiscordRequest request = new DiscordRequest(url, k_EHTTPMethodGET);
	if(request == null)
	{
		CreateTimer(2.0, SendGetMembers, hData);
		return;
	}
	request.SetCallbacks(HTTPCompleted, MembersDataReceive);
	request.SetBot(Bot);
	request.SetData(hData, route);
	request.Send(route);
}

public int HTTPCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statuscode, any data, any data2)
{
}

public void MembersDataReceive(Handle request, bool failure, int offset, int statuscode, any dp)
{
	if(failure || (statuscode != 200))
	{
		if(statuscode == 429 || statuscode == 500)
		{
			GetMembers(dp);
			//delete view_as<Handle>(dp);
			delete request;
			return;
		}
		delete hFinalMemberList;
		delete request;
		delete view_as<Handle>(dp);
		return;
	}
	SteamWorks_GetHTTPResponseBodyCallback(request, GetMembersData, dp);
	delete request;
}

public int GetMembersData(const char[] data, any dp)
{
	//PrintToChatAll("GetMembersData();");
	Handle hJson = json_load(data);
	//bool returned = json_array_extend(hFinalMemberList, hJson);
	json_array_extend(hFinalMemberList, hJson);
	//PrintToChatAll("returned %d", returned);
	Handle hData = view_as<Handle>(dp);

	int size = json_array_size(hJson);
	int limit = JsonObjectGetInt(hData, "limit");
	//PrintToChatAll("size %d | limit %d", size, limit);

	if(limit == size)
	{
		char userid[32];
		DiscordGuildUser GuildUser;
		DiscordUser user;

		GuildUser = view_as<DiscordGuildUser>(json_array_get(hJson, limit - 1));
		user = GuildUser.GetUser();
		user.GetID(userid, sizeof(userid));
		delete GuildUser;
		delete user;
		//PrintToChatAll("userID %s", userid);

		delete hJson;

		json_object_set_new(hData, "after", json_string(userid));
		GetMembers(hData);
		return;
	}
		
	OnGetMembersAll(hFinalMemberList);
	
	delete hJson;
	delete hData;
	delete hFinalMemberList;
}

public void OnGetMembersAll(Handle hMemberList)
{
	//DeleteFile("addons/sourcemod/logs/dsmembers.json")
	//json_dump_file(hMemberList, "addons/sourcemod/logs/dsmembers.json");
	//LogToFile("addons/sourcemod/logs/dsmembers.json", "OnGetMembersAll size %d", json_array_size(hMemberList));

	Call_StartForward(g_hOnMemberDataDumped);
	Call_Finish();

	char userid[20];
	DiscordGuildUser GuildUser;
	DiscordUser user;
	bool found;
	char Query[256];
	bool[] bUpdate = new bool[MaxClients+1];

	for(int x = 1; x <= MaxClients; x++)
	{
		if(!IsClientInGame(x))
		{
			continue;
		}
		if(!g_bMember[x])
		{
			continue;
		}
		found = false;
		for(int i = 0; i < json_array_size(hMemberList); i++)
		{
			GuildUser = view_as<DiscordGuildUser>(json_array_get(hMemberList, i));
			user = GuildUser.GetUser();
			user.GetID(userid, sizeof(userid));
			if(strcmp(userid, g_sUserID[x]) == 0)
			{
				found = true;
				delete user;
				delete GuildUser;
				break;
			}
			delete user;
			delete GuildUser;
		}
		delete user;
		delete GuildUser;
		if(!found)
		{
			char steamid[32];
			GetClientAuthId(x, AuthId_Steam2, steamid, sizeof(steamid));
			if(g_bIsMySQl)
			{
				g_hDB.Format(Query, sizeof(Query), "UPDATE `%s` SET `userid` = '%s', member = '0' WHERE `steamid` = '%s';", g_sTableName, NULL_STRING, steamid);
			}
			else
			{
				g_hDB.Format(Query, sizeof(Query), "UPDATE %s SET userid = '%s', member = '0' WHERE steamid = '%s';", g_sTableName, NULL_STRING, steamid);
			}
			SQL_TQuery(g_hDB, SQLQuery_UpdatePlayer, Query);
			bUpdate[x] = true;
			CPrintToChat(x, "%s %T", g_sServerPrefix, "DiscordRevoked", x);

			LogToFile("addons/sourcemod/logs/dsmembers_revoke.log", "Player %L got revoked. Memberlist json size: %d", x, json_array_size(hMemberList));

			Call_StartForward(g_hOnAccountRevoked);
			Call_PushCell(x);
			Call_PushString(g_sUserID[x]);
			Call_Finish();
		}
		else
		{
			if(strlen(g_sRoleID) > 5 && !g_bRoleGiven[x])
			{
				ManagingRole(g_sUserID[x], g_sRoleID, k_EHTTPMethodPUT);
				g_bRoleGiven[x] = true;
			}
		}
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
		{
			continue;
		}
		if(!bUpdate[i])
		{
			continue;
		}
		OnClientPutInServer(i);
		OnClientPreAdminCheck(i);
	}
}

/*
void GetGuildMember(char[] userid)
{
	Handle hData = json_object();
	json_object_set_new(hData, "userID", json_string(userid[0]));
	GetMembers(hData);
}
*/

void UpdatePlayer(int client)
{
	char steamid[32], szQuery[512];
	
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	if(g_bIsMySQl)
	{
		g_hDB.Format(szQuery, sizeof(szQuery), "UPDATE `%s` SET last_accountuse = '%d' WHERE `steamid` = '%s';", g_sTableName, GetTime(), steamid);
	}
	else
	{
		g_hDB.Format(szQuery, sizeof(szQuery), "UPDATE %s SET last_accountuse = '%d' WHERE steamid = '%s'", g_sTableName, GetTime(), steamid);
	}
	SQL_TQuery(g_hDB, SQLQuery_UpdatePlayer, szQuery, GetClientUserId(client));
}

stock void RemoveColors(char[] text, int size)
{
	if(g_bShavit)
	{
		for(int i = 0; i < sizeof(gS_GlobalColorNames); i++)
		{
			ReplaceString(text, size, gS_GlobalColorNames[i], "");
		}
		for(int i = 0; i < sizeof(gS_GlobalColors); i++)
		{
			ReplaceString(text, size, gS_GlobalColors[i], "");
		}
		for(int i = 0; i < sizeof(gS_CSGOColorNames); i++)
		{
			ReplaceString(text, size, gS_CSGOColorNames[i], "");
		}
		for(int i = 0; i < sizeof(gS_CSGOColors); i++)
		{
			ReplaceString(text, size, gS_CSGOColors[i], "");
		}
	}
	else
	{
		for(int i = 0; i < sizeof(C_Tag); i++)
		{
			ReplaceString(text, size, C_Tag[i], "");
		}
		for(int i = 0; i < sizeof(C_TagCode); i++)
		{
			ReplaceString(text, size, C_TagCode[i], "");
		}
	}
}

void CreateCvars()
{
	#if defined USE_AutoExecConfig
	AutoExecConfig_SetFile("Discord-Utilities");
	AutoExecConfig_SetCreateFile(true);

	g_cVerificationChannelID = AutoExecConfig_CreateConVar("sm_du_verfication_channelid", "", "Channel ID for verfication. Blank to disable.");
	g_cGuildID = AutoExecConfig_CreateConVar("sm_du_verification_guildid", "", "Guild ID of your discord server. Blank to disable. Needed for verification module.");
	g_cRoleID = AutoExecConfig_CreateConVar("sm_du_verification_roleid", "", "Role ID to give to user when user is verified. Blank to give no role. Verification module needs to be running.");

	g_cBotToken = AutoExecConfig_CreateConVar("sm_du_bottoken", "", "Bot Token. Needed for discord server => gameserver and/or verification module.", FCVAR_PROTECTED);
	g_cCheckInterval = AutoExecConfig_CreateConVar("sm_du_accounts_check_interval", "300", "Time in seconds between verifying accounts.");
	g_cUseSWGM = AutoExecConfig_CreateConVar("sm_du_use_swgm_file", "0", "Use SWGM config file for restricting commands.");
	g_cServerID = AutoExecConfig_CreateConVar("sm_du_server_id", "1", "Increase this with every server you put this plugin in. Prevents multiple replies from the bot in verfication channel.");
	g_cPrimaryServer = AutoExecConfig_CreateConVar("sm_du_server_primary", "0", "Is this the primary server in the verification channel? Only this server will respond to generic queries so atleast 1 server should have this 1.");

	g_cLinkCommand = AutoExecConfig_CreateConVar("sm_du_link_command", "!link", "Command to use in text channel.");
	g_cViewIDCommand = AutoExecConfig_CreateConVar("sm_du_viewid_command", "sm_viewid", "Command to view id.");
	g_cInviteLink = AutoExecConfig_CreateConVar("sm_du_link", "https://discord.gg/83g5xcE", "Invite link of your discord server.");

	g_cDiscordPrefix = AutoExecConfig_CreateConVar("sm_du_discord_prefix", "[{lightgreen}Discord{default}]", "Prefix for discord messages.");
	g_cServerPrefix = AutoExecConfig_CreateConVar("sm_du_server_prefix", "[{lightgreen}Discord-Utilities{default}]", "Prefix for chat messages.");

	g_cDatabaseName = AutoExecConfig_CreateConVar("sm_du_database_name", "du", "Section name in databases.cfg.");
	g_cTableName = AutoExecConfig_CreateConVar("sm_du_table_name", "du_users", "Table Name.");
	g_cPruneDays = AutoExecConfig_CreateConVar("sm_du_prune_days", "60", "Prune database with players whose last connect is X DAYS and he is not member of discord server. 0 to disable.");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	#else
	g_cVerificationChannelID = CreateConVar("sm_du_verfication_channelid", "", "Channel ID for verfication. Blank to disable.");
	g_cGuildID = CreateConVar("sm_du_verification_guildid", "", "Guild ID of your discord server. Blank to disable. Needed for verification module.");
	g_cRoleID = CreateConVar("sm_du_verification_roleid", "", "Role ID to give to user when user is verified. Blank to give no role. Verification module needs to be running.");

	g_cBotToken = CreateConVar("sm_du_bottoken", "", "Bot Token. Needed for discord server => gameserver and/or verification module.", FCVAR_PROTECTED);
	g_cCheckInterval = CreateConVar("sm_du_accounts_check_interval", "300", "Time in seconds between verifying accounts.");
	g_cUseSWGM = CreateConVar("sm_du_use_swgm_file", "0", "Use SWGM config file for restricting commands.");
	g_cServerID = CreateConVar("sm_du_server_id", "1", "Increase this with every server you put this plugin in. Prevents multiple replies from the bot in verfication channel.");
	g_cPrimaryServer = CreateConVar("sm_du_server_primary", "0", "Is this the primary server in the verification channel? Only this server will respond to generic queries so atleast 1 server should have this 1.");

	g_cLinkCommand = CreateConVar("sm_du_link_command", "!link", "Command to use in text channel.");
	g_cViewIDCommand = CreateConVar("sm_du_viewid_command", "sm_viewid", "Command to view id.");
	g_cInviteLink = CreateConVar("sm_du_link", "https://discord.gg/83g5xcE", "Invite link of your discord server.");

	g_cDiscordPrefix = CreateConVar("sm_du_discord_prefix", "[{lightgreen}Discord{default}]", "Prefix for discord messages.");
	g_cServerPrefix = CreateConVar("sm_du_server_prefix", "[{lightgreen}Discord-Utilities{default}]", "Prefix for chat messages.");

	g_cDatabaseName = CreateConVar("sm_du_database_name", "du", "Section name in databases.cfg.");
	g_cTableName = CreateConVar("sm_du_table_name", "du_users", "Table Name.");
	g_cPruneDays = CreateConVar("sm_du_prune_days", "60", "Prune database with players whose last connect is X DAYS and he is not member of discord server. 0 to disable.");
	
	AutoExecConfig(true, "Discord-Utilities");
	#endif

	HookConVarChange(g_cVerificationChannelID, OnSettingsChanged);
	HookConVarChange(g_cGuildID, OnSettingsChanged);
	HookConVarChange(g_cRoleID, OnSettingsChanged);

	HookConVarChange(g_cBotToken, OnSettingsChanged);

	HookConVarChange(g_cLinkCommand, OnSettingsChanged);
	HookConVarChange(g_cViewIDCommand, OnSettingsChanged);
	HookConVarChange(g_cInviteLink, OnSettingsChanged);

	HookConVarChange(g_cDiscordPrefix, OnSettingsChanged);
	HookConVarChange(g_cServerPrefix, OnSettingsChanged);
}

void LoadCvars()
{
	g_cVerificationChannelID.GetString(g_sVerificationChannelID, sizeof(g_sVerificationChannelID));
	g_cGuildID.GetString(g_sGuildID, sizeof(g_sGuildID));
	g_cRoleID.GetString(g_sRoleID, sizeof(g_sRoleID));
	
	g_cBotToken.GetString(g_sBotToken, sizeof(g_sBotToken));
	
	g_cLinkCommand.GetString(g_sLinkCommand, sizeof(g_sLinkCommand));
	g_cViewIDCommand.GetString(g_sViewIDCommand, sizeof(g_sViewIDCommand));
	g_cInviteLink.GetString(g_sInviteLink, sizeof(g_sInviteLink));

	g_cDiscordPrefix.GetString(g_sDiscordPrefix, sizeof(g_sDiscordPrefix));
	g_cServerPrefix.GetString(g_sServerPrefix, sizeof(g_sServerPrefix));
}

void ManagingRole(char[] userid, char[] roleid, EHTTPMethod method)
{
	Handle hData = json_object();
	json_object_set_new(hData, "userid", json_string(userid));
	json_object_set_new(hData, "roleid", json_string(roleid));
	json_object_set_new(hData, "method", json_integer(view_as<int>(method)));
	ManageRole(hData);
}

void ManageRole(Handle hData)
{
	if(StrEqual(g_sGuildID, ""))
	{
		LogError("[Discord-Utilities] GuildID is not provided. Role cannot be provided!");
		delete hData;
		return;
	}
	char userid[128];
	if (!JsonObjectGetString(hData, "userid", userid, sizeof(userid)))
	{
		LogError("JsonObjectGetString \"userid\" failed");
		delete hData;
		return;
	}
	char roleid[128];
	if (!JsonObjectGetString(hData, "roleid", roleid, sizeof(roleid)))
	{
		LogError("JsonObjectGetString \"roleid\" failed");
		delete hData;
		return;
	}
	EHTTPMethod method = view_as<EHTTPMethod>(JsonObjectGetInt(hData, "method"));
	char url[1024];
	FormatEx(url, sizeof(url), "https://discord.com/api/guilds/%s/members/%s/roles/%s", g_sGuildID, userid, roleid);
	char route[512];
	FormatEx(route, sizeof(route), "guild/%s/members", g_sGuildID);
	DiscordRequest request = new DiscordRequest(url, method);
	if (request == null)
	{
		CreateTimer(2.0, SendManageRole, hData, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	request.SetCallbacks(HTTPCompleted, OnManageRoleSent);
	request.SetContentSize();
	request.SetBot(Bot);
	request.SetData(hData, route);
	request.Send(route);
}


public void OnManageRoleSent(Handle request, bool failure, int offset, int statuscode, any dp)
{
	if(failure || (statuscode != 200))
	{
		if(statuscode == 429 || statuscode == 500)
		{
			ManageRole(dp);
			//delete view_as<Handle>(dp);
			delete request;
			//LogError("OnManageRoleSent: Error code %d | Retrying to Managerole(dp)", statuscode);
			return;
		}
		delete request;
		delete view_as<Handle>(dp);
		//LogError("OnManageRoleSent: Error code %d | Deleting everything and returning", statuscode);
		return;
	}
	delete request
	delete view_as<Handle>(dp);
}


stock void RefreshClients()
{
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i))
	{
		OnClientPreAdminCheck(i);
	}
}

void LoadCommands()
{
	char sBuffer[256];
	if(g_cUseSWGM.IntValue == 1)
	{
		KeyValues kv = new KeyValues("Command_Listener");
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/swgm/command_listener.ini");
		if(!FileToKeyValues(kv, sBuffer))
		{
			SetFailState("[Discord-Utilities] Missing config file %s. If you don't use SWGM, then change 'sm_du_use_swgm_file' value to 0.", sBuffer);
		}
		if(kv.GotoFirstSubKey())
		{
			do
			{
				if(kv.GetSectionName(sBuffer, sizeof(sBuffer)))
				{
					AddCommandListener(Check, sBuffer);
				}
			}
			while (kv.GotoNextKey());
		}
		delete kv;
		return;
	}
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/du/command_listener.ini");
	
	File fFile = OpenFile(sBuffer, "r");
	
	if(!FileExists(sBuffer))
	{
		fFile.Close();
		fFile = OpenFile(sBuffer, "w+");
		fFile.WriteLine("// Separate each commands with separate lines. DON'T USE SPACE INFRONT OF COMMANDS. Example:");
		fFile.WriteLine("//sm_shop");
		fFile.WriteLine("//sm_store");
		fFile.WriteLine("//Use it without \"//\"");
		fFile.Close();
		LogError("[Discord-Utilities] %s file is empty. Add commands to restrict them!", sBuffer);
		return;
	}
	char sReadBuffer[PLATFORM_MAX_PATH];

	int len;
	while(!fFile.EndOfFile() && fFile.ReadLine(sReadBuffer, sizeof(sReadBuffer)))
	{
		if (sReadBuffer[0] == '/' && sReadBuffer[1] == '/' || IsCharSpace(sReadBuffer[0]))
		{
			continue;
		}

		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\n", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\r", "");
		ReplaceString(sReadBuffer, sizeof(sReadBuffer), "\t", "");

		len = strlen(sReadBuffer);

		if (len < 3)
		{
			continue;
		}

		AddCommandListener(Check, sReadBuffer);
	}

	fFile.Close();
}

stock void CreateBot(bool guilds = true, bool listen = true)
{
	if(StrEqual(g_sBotToken, "") || StrEqual(g_sVerificationChannelID, ""))
	{
		delete Bot;
		return;
	}

	delete Bot;

	//if(!g_bIsBotLoaded)
	//{
		Bot = new DiscordBot(g_sBotToken);
	//}
	
	if(guilds)
	{
		//if(g_bIsBotLoaded)
		//{
			Bot.GetGuilds(GuildList, _, listen);
		//}
		//else
		//{
		//	CreateBot();
		//}
	}
}

stock void KillBot()
{
	if(Bot)
	{
		Bot.StopListeningToChannels();
		Bot.StopListening();
	}
	delete Bot;
}

stock int GetClientFromUniqueCode(const char[] unique)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i)) continue;
		if (StrEqual(g_sUniqueCode[i], unique)) return i;
	}
	return -1;
}

stock char ChangePartsInString(char[] input, const char[] from, const char[] to)
{
	char output[64];
	ReplaceString(input, sizeof(output), from, to);
	strcopy(output, sizeof(output), input);
	return output;
}

/*
stock void GetGuilds(bool listen = true)
{	
	Bot.GetGuilds(GuildList, _, listen);
}
*/

stock void Discord_EscapeString(char[] string, int maxlen, bool name = false)
{
	if(name)
	{
		ReplaceString(string, maxlen, "everyone", "everyonｅ");
		ReplaceString(string, maxlen, "here", "herｅ");
		ReplaceString(string, maxlen, "discordtag", "dｉscordtag");
	}
	ReplaceString(string, maxlen, "#", "＃");
	ReplaceString(string, maxlen, "@", "＠");
	//ReplaceString(string, maxlen, ":", "");
	ReplaceString(string, maxlen, "_", "ˍ");
	ReplaceString(string, maxlen, "'", "＇");
	ReplaceString(string, maxlen, "`", "＇");
	ReplaceString(string, maxlen, "~", "∽");
	ReplaceString(string, maxlen, "\"", "＂");
}

/* TIMERS */

public Action VerifyAccounts(Handle timer)
{
	AccountsCheck();
}

public Action Cmd_Unlink(int client, int args)
{
	if(g_bMember[client])
	{
		char Query[256];

		char szSteamId[32];
		GetClientAuthId(client, AuthId_Steam2, szSteamId, sizeof(szSteamId));

		g_hDB.Format(Query, sizeof(Query), "SELECT userid FROM %s WHERE steamid = '%s'", g_sTableName, szSteamId);
		SQL_TQuery(g_hDB, SQLQuery_UnlinkAccount, Query, GetClientUserId(client));
	}
}
/*
public Action Timer_Query_AccountCheck(Handle timer)
{
	if(g_hDB == null)
	{
		CreateTimer(5.0, Timer_Query_AccountCheck, _, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}
	char Query[256];
	g_hDB.Format(Query, sizeof(Query), "SELECT userid FROM %s", g_sTableName);
	SQL_TQuery(g_hDB, SQLQuery_AccountCheck, Query);
}
*/

public Action SendGetMembers(Handle timer, any data)
{
	GetMembers(view_as<Handle>(data));
}

public Action SendManageRole(Handle timer, any data)
{
	ManageRole(view_as<Handle>(data));
}

public Action SendRequestAgain(Handle timer, DataPack dp)
{
	ResetPack(dp, false);
	Handle request = ReadPackCell(dp);
	char route[512];
	ReadPackString(dp, route, sizeof(route));
	delete dp;
	DiscordSendRequest(request, route);
}

public Action Timer_RefreshClients(Handle timer)
{
	RefreshClients();
}

stock void DU_DeleteMessageID(DiscordMessage discordmessage)
{
	char channelid[64], msgid[64];
	
	discordmessage.GetChannelID(channelid, sizeof(channelid));
	discordmessage.GetID(msgid, sizeof(msgid));
	
	Bot.DeleteMessageID(channelid, msgid);
}

stock bool IsClientValid(int client)
{
    return (0 < client <= MaxClients) && IsClientInGame(client) && !IsFakeClient(client);
}
