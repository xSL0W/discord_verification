public void OnPluginEnd()
{
	KillBot();
}

public void OnLibraryAdded(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "shavit")) g_bShavit = true;
}

public void OnLibraryRemoved(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "shavit")) g_bShavit = false;
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("discord-api"))
	{
		SetFailState("[Discord-Utilities] This plugin is fully dependant on \"Discord-API\" by Deathknife. (https://github.com/Deathknife/sourcemod-discord)");
	}
	
	g_bShavit = LibraryExists("shavit");
}

public void OnConfigsExecuted()
{
	LoadCvars();
	
	if(Bot == view_as<DiscordBot>(INVALID_HANDLE))
	{
		if(!CommandExists(g_sViewIDCommand))
		{
			RegConsoleCmd(g_sViewIDCommand, Command_ViewId);
			RegConsoleCmd(g_sUnLinkCommand, Cmd_Unlink);
			RegConsoleCmd("sm_verify", Command_ViewId);
		}
		CreateBot();
	}
	
	LoadCommands();
	
	char sDTB[32];
	g_cDatabaseName.GetString(sDTB, sizeof(sDTB));
	g_cTableName.GetString(g_sTableName, sizeof(g_sTableName));
	SQL_TConnect(SQLQuery_Connect, sDTB);
}

public void OnMapEnd()
{
	KillBot();
}

public void OnMapStart()
{
	if(g_cCheckInterval.FloatValue)
	{
		CreateTimer(g_cCheckInterval.FloatValue, VerifyAccounts, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void OnClientDisconnect(int client)
{
	if(g_hDB == null)
	{
		return;
	}
	UpdatePlayer(client);
}

public void OnClientPutInServer(int client)
{
	g_bChecked[client] = false;
	g_bMember[client] = false;
	g_sUniqueCode[client][0] = '\0';
	g_sUserID[client][0] = '\0';
	g_bRoleGiven[client] = false;
}

public Action OnClientPreAdminCheck(int client)
{
	if(IsFakeClient(client) || g_hDB == null)
	{
		return;
	}
	
	char szQuery[512], szSteamId[32];
	GetClientAuthId(client, AuthId_Steam2, szSteamId, sizeof(szSteamId));
	if(g_bIsMySQl)
	{
		g_hDB.Format(szQuery, sizeof(szQuery), "SELECT userid, member FROM %s WHERE steamid = '%s';", g_sTableName, szSteamId);
	}
	else
	{
		g_hDB.Format(szQuery, sizeof(szQuery), "SELECT userid, member FROM %s WHERE steamid = '%s'", g_sTableName, szSteamId);
	}
	SQL_TQuery(g_hDB, SQLQuery_GetUserData, szQuery, GetClientUserId(client));
}

public int OnSettingsChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if(StrEqual(oldVal, newVal, true))
	{
        return;
	}
	if(convar == g_cVerificationChannelID)
	{
		strcopy(g_sVerificationChannelID, sizeof(g_sVerificationChannelID), newVal);
	}
	else if(convar == g_cGuildID)
	{
		strcopy(g_sGuildID, sizeof(g_sGuildID), newVal);
	}
	else if(convar == g_cRoleID)
	{
		strcopy(g_sRoleID, sizeof(g_sRoleID), newVal);
	}
	else if(convar == g_cBotToken)
	{
		strcopy(g_sBotToken, sizeof(g_sBotToken), newVal);
	}
	else if(convar == g_cLinkCommand)
	{
		strcopy(g_sLinkCommand, sizeof(g_sLinkCommand), newVal);
	}
	else if(convar == g_cViewIDCommand)
	{
		strcopy(g_sViewIDCommand, sizeof(g_sViewIDCommand), newVal);
	}
	else if(convar == g_cUnLinkCommand)
	{
		strcopy(g_sUnLinkCommand, sizeof(g_sUnLinkCommand), newVal);
	}
	else if(convar == g_cInviteLink)
	{
		strcopy(g_sInviteLink, sizeof(g_sInviteLink), newVal);
	}
	else if(convar == g_cServerPrefix)
	{
		strcopy(g_sServerPrefix, sizeof(g_sServerPrefix), newVal);
	}
	else if(convar == g_cTableName)
	{
		strcopy(g_sTableName, sizeof(g_sTableName), newVal);
		char dtbname[32];
		g_cDatabaseName.GetString(dtbname, sizeof(dtbname));
		SQL_TConnect(SQLQuery_Connect, dtbname);
		RefreshClients();
	}
}

public void GuildList(DiscordBot bawt, char[] id, char[] name, char[] icon, bool owner, int permissions, const bool listen)
{
	Bot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION, listen);
}

public void ChannelList(DiscordBot bawt, const char[] guild, DiscordChannel Channel, const bool listen)
{
	if(StrEqual(g_sBotToken, "") || StrEqual(g_sVerificationChannelID, ""))
	{
		return;
	}
	if(Channel == null || Bot == null)
	{
		return;
	}
	if(Bot.IsListeningToChannel(Channel))
	{
		//Bot.StopListeningToChannel(Channel);
		return;
	}


	char id[20], name[32];
	Channel.GetID(id, sizeof(id));
	Channel.GetName(name, sizeof(name));
	
	if(strlen(g_sVerificationChannelID) > 10)
	{
		if(StrEqual(id, g_sVerificationChannelID))
		{
			g_sVerificationChannelName = name;
			if(listen)
			{
				PrintToServer("******** STARTING TO LISTEN ***********");
				Bot.StartListeningToChannel(Channel, OnMessageReceived);
				//Bot.PrintChannels();
				//Bot.PrintChannels();
			}
		}
	}
}

/*
public Action smpc(int client, int args)
{
	Bot.PrintChannels();
}
*/

public Action Command_ViewId(int client, int args)
{
	if(!client || StrEqual(g_sVerificationChannelID, ""))
	{
		return Plugin_Handled;
	}
	if(!g_bChecked[client])
	{
		CReplyToCommand(client, "%s %T", g_sServerPrefix, "TryAgainLater", client);
		return Plugin_Handled;
	}
	
	//CPrintToChat(client, "%s %T", g_sServerPrefix, "LinkYourID", client, g_sUniqueCode[client]);
	if(!g_bMember[client])
	{
		CPrintToChat(client, "%s %T", g_sServerPrefix, "LinkConnect", client);
		CPrintToChat(client, "%s {blue}%s", g_sServerPrefix, g_sInviteLink);
		
		CPrintToChat(client, "%s %T", g_sServerPrefix, "LinkUsage", client, g_sLinkCommand, g_sUniqueCode[client], g_sVerificationChannelName);
		CPrintToChat(client, "%s %T", g_sServerPrefix, "CopyPasteFromConsole", client);

		char buf[128], g_sServerPrefix2[128];
		Format(g_sServerPrefix2, sizeof(g_sServerPrefix2), g_sServerPrefix);
		for(int i = 0; i < sizeof(C_Tag); i++)
		{
			ReplaceString(g_sServerPrefix2, sizeof(g_sServerPrefix2), C_Tag[i], "");
		}
		
		PrintToConsole(client, "*****************************************************");
		PrintToConsole(client, "%s %T", g_sServerPrefix2, "LinkConnect", client, g_sInviteLink);
		PrintToConsole(client, "%s %s", g_sServerPrefix2, g_sInviteLink);
		Format(buf, sizeof(buf), "%T", "LinkUsage", client, g_sLinkCommand, g_sUniqueCode[client], g_sVerificationChannelName);
		for(int i = 0; i < sizeof(C_Tag); i++)
		{
			ReplaceString(buf, sizeof(buf), C_Tag[i], "");
		}
		PrintToConsole(client, "%s %s", g_sServerPrefix2,  buf);
		PrintToConsole(client, "*****************************************************");
	}
	else
	{
		CPrintToChat(client, "%s - %T", g_sServerPrefix, "AlreadyVerified", client);
		CPrintToChat(client, "%s - %T", g_sServerPrefix, "CanChange", client, ChangePartsInString(g_sUnLinkCommand, "sm_", "!"), ChangePartsInString(g_sViewIDCommand, "sm_", "!"));
	}


	
	return Plugin_Handled;
}

public Action Check(int client, const char[] command, int args)
{
	if(IsValidClient(client) && !g_bMember[client])
	{
		CPrintToChat(client, "%s %T", g_sServerPrefix, "MustVerify", client, ChangePartsInString(g_sViewIDCommand, "sm_", "!"));
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

stock bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
} 