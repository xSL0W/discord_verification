public void ChatRelayReceived(DiscordBot bawt, DiscordChannel channel, DiscordMessage discordmessage)
{
	DiscordUser author = discordmessage.GetAuthor();
	if(author.IsBot()) 
	{
		delete author;
		return;
	}

	char message[512];
	char userName[32], discriminator[6];
	discordmessage.GetContent(message, sizeof(message));
	author.GetUsername(userName, sizeof(userName));
	author.GetDiscriminator(discriminator, sizeof(discriminator));
	delete author;

	CPrintToChatAll("%s %T", g_sDiscordPrefix, "ChatRelayFormat", LANG_SERVER, userName, discriminator, message);
}

public void OnMessageReceived(DiscordBot bawt, DiscordChannel channel, DiscordMessage discordmessage)
{
	DiscordUser author = discordmessage.GetAuthor();
	if(author.IsBot()) 
	{
		delete author;
		return;
	}

	char szValues[2][99];
	char szReply[512];
	char message[512];
	char userID[20], userName[32], discriminator[6];

	discordmessage.GetContent(message, sizeof(message));
	author.GetUsername(userName, sizeof(userName));
	author.GetDiscriminator(discriminator, sizeof(discriminator));
	author.GetID(userID, sizeof(userID));
	delete author;

	int retrieved1 = ExplodeString(message, " ", szValues, sizeof(szValues), sizeof(szValues[]));	
	TrimString(szValues[1]);
	
	char _szValues[3][75];
	int retrieved2 = ExplodeString(szValues[1], "-", _szValues, sizeof(_szValues), sizeof(_szValues[]));

	bool bIsPrimary = g_cPrimaryServer.BoolValue;

	if(StrEqual(szValues[0], g_sLinkCommand))
	{
		if (retrieved1 < 2)
		{
			//Prevent multiple replies, only allow the primary server to respond
			if (bIsPrimary)
			{
				Format(szReply, sizeof(szReply), "%T", "DiscordMissingParameters", LANG_SERVER, userID);
				Bot.SendMessage(channel, szReply);
				DU_DeleteMessageID(discordmessage);
			}
			return;
		}
		else if (retrieved2 != 3)
		{
			if (bIsPrimary)
			{
				Format(szReply, sizeof(szReply), "%T", "DiscordInvalidID", LANG_SERVER, userID, g_sViewIDCommand);
				Bot.SendMessage(channel, szReply);
				DU_DeleteMessageID(discordmessage);
			}
			return;
		}
		
		if(StringToInt(_szValues[0]) != g_cServerID.IntValue)
		{
			return; //Prevent multiple replies from the bot (for e.g. the plugin is installed on more than 1 server and they're using the same bot & channel)
		}

		int client = GetClientFromUniqueCode(szValues[1]);
		if(client <= 0)
		{
			Format(szReply, sizeof(szReply), "%T", "DiscordInvalid", LANG_SERVER, userID);
			Bot.SendMessage(channel, szReply);
		}
		else if (!g_bMember[client])
		{
			DataPack datapack = new DataPack();
			datapack.WriteCell(client);
			datapack.WriteString(userID);
			datapack.WriteString(userName);
			datapack.WriteString(discriminator);
			//datapack.WriteString(messageID);

			char szSteamId[32];
			GetClientAuthId(client, AuthId_Steam2, szSteamId, sizeof(szSteamId));

			char Query[512];
			g_hDB.Format(Query, sizeof(Query), "SELECT userid FROM %s WHERE steamid = '%s'", g_sTableName, szSteamId);
			SQL_TQuery(g_hDB, SQLQuery_CheckUserData, Query, datapack);
			
			//Security addition - renew unique code in case another user copies it before query returns (?)
			GetClientAuthId(client, AuthId_SteamID64, szSteamId, sizeof(szSteamId));
			int uniqueNum = GetRandomInt(100000, 999999);
			Format(g_sUniqueCode[client], sizeof(g_sUniqueCode), "%i-%i-%s", g_cServerID.IntValue, uniqueNum, szSteamId);

			return; //Dont delete this message so user has positive confirmation
		}
		else
		{
			//Don't bother querying the DB if user is already a member
			Format(szReply, sizeof(szReply), "%T", "DiscordAlreadyLinked", LANG_SERVER, userID);
			Bot.SendMessage(channel, szReply);
		}
	}
	else
	{
		if (bIsPrimary)
		{
			Format(szReply, sizeof(szReply), "%T", "DiscordInfo", LANG_SERVER, userID, g_sLinkCommand);
			Bot.SendMessage(channel, szReply);
		}
	}
	DU_DeleteMessageID(discordmessage);
}