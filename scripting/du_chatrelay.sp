#include <sourcemod>
#include <autoexecconfig>
#include <SteamWorks>
#include <discord>
#include <discord_utilities>

#include <multicolors>
#include <basecomm>

#pragma dynamic 500000
#pragma newdecls required
#pragma semicolon 1

#define MAX_BLOCKLIST_LIMIT 20
#define USE_AutoExecConfig

ConVar g_cChatRelay_Webhook, g_cChatRelay_BlockList, g_cAdminChatRelay_Mode, g_cAdminChatRelay_Webhook, g_cAdminChatRelay_BlockList, g_cAdminLog_Webhook, g_cAdminLog_BlockList;
ConVar g_cChatRelayChannelID, g_cAdminChatRelayChannelID;
ConVar g_cBotToken, g_cTimeStamps, g_cDiscordPrefix, g_cAPIKey;

char g_sAvatarURL[MAXPLAYERS+1][128];

char g_sChatRelay_Webhook[128], g_sChatRelay_BlockList[MAX_BLOCKLIST_LIMIT][64], g_sAdminChatRelay_Mode[16], g_sAdminChatRelay_Webhook[128], g_sAdminChatRelay_BlockList[MAX_BLOCKLIST_LIMIT][64], g_sAdminLog_Webhook[128], g_sAdminLog_BlockList[MAX_BLOCKLIST_LIMIT][64];
char g_sVerificationChannelID[20], g_sChatRelayChannelID[20], g_sAdminChatRelayChannelID[20];
char g_sBotToken[60], g_sAPIKey[64];

char g_sDiscordPrefix[128];

char g_sServerName[128];

bool g_bBaseComm, g_bShavit;

DiscordBot Bot;

char gS_GlobalColorNames[][] =
{
	"{default}",
	"{team}",
	"{green}"
};

char gS_GlobalColors[][] =
{
	"\x01",
	"\x03",
	"\x04"
};

char gS_CSGOColorNames[][] =
{
	"{blue}",
	"{bluegrey}",
	"{darkblue}",
	"{darkred}",
	"{gold}",
	"{grey}",
	"{grey2}",
	"{lightgreen}",
	"{lightred}",
	"{lime}",
	"{orchid}",
	"{yellow}",
	"{palered}"
};

char gS_CSGOColors[][] =
{
	"\x0B",
	"\x0A",
	"\x0C",
	"\x02",
	"\x10",
	"\x08",
	"\x0D",
	"\x05",
	"\x0F",
	"\x06",
	"\x0E",
	"\x09",
	"\x07"
};

public Plugin myinfo = 
{
	name = "Discord Utilities - Chatrelay module",
	author = "AiDN™ & Cruze03",
	description = "Chatrelay module for the Discord Utilities, code from Cruze03",
	version = "1.1",
	url = "https://steamcommunity.com/id/originalaidn & https://github.com/Cruze03/discord-utilities"
};

public void OnPluginStart()
{
	AddCommandListener(Command_AdminChat, "sm_chat");

	#if defined USE_AutoExecConfig
	AutoExecConfig_SetFile("Discord-Utilities");
	AutoExecConfig_SetCreateFile(true);

	g_cChatRelay_Webhook = AutoExecConfig_CreateConVar("sm_du_chat_webhook", "", "Webhook for game server => discord server chat messages. Blank to disable.", FCVAR_PROTECTED);
	g_cChatRelay_BlockList = AutoExecConfig_CreateConVar("sm_du_chat_blocklist", "rtv, nominate", "Text that shouldn't appear in gameserver => discord server chat messages. Separate it with \", \"");
	g_cAdminChatRelay_Mode = AutoExecConfig_CreateConVar("sm_du_adminchat_mode", "0b", "0 - Only \"say_team with @ / sm_chat\"\n0b - \"say_team with @ / sm_chat\" with discord to game server chat to admin.\nAny admin flag - Show messages of specific flag in channel.");
	g_cAdminChatRelay_Webhook = AutoExecConfig_CreateConVar("sm_du_adminchat_webhook", "", "Webhook for game server => discord server chat messages where chat messages are to (say_team with @ / sm_chat) / are of admins. Blank to disable.", FCVAR_PROTECTED);
	g_cAdminChatRelay_BlockList = AutoExecConfig_CreateConVar("sm_du_adminchat_blocklist", "rtv, nominate", "Text that shouldn't appear in gameserver => discord server where chat messages are to admin. Separate it with \", \"");
	g_cAdminLog_Webhook = AutoExecConfig_CreateConVar("sm_du_adminlog_webhook", "", "Webhook for channel where all admin commands are logged. Blank to disable.", FCVAR_PROTECTED);
	g_cAdminLog_BlockList = AutoExecConfig_CreateConVar("sm_du_adminlog_blocklist", "slapped, firebombed", "Log with this string will be ignored. Separate it with \", \"");
	
	g_cChatRelayChannelID = AutoExecConfig_CreateConVar("sm_du_chat_channelid", "", "Channel ID for discord server => game server messages. Blank to disable.");
	g_cAdminChatRelayChannelID = AutoExecConfig_CreateConVar("sm_du_adminchat_channelid", "", "Channel ID for discord server => game server messages only of admins. Blank to disable.");
	
	g_cBotToken = AutoExecConfig_CreateConVar("sm_du_bottoken", "", "Bot Token. Needed for discord server => gameserver and/or verification module.", FCVAR_PROTECTED);
	
	g_cDiscordPrefix = AutoExecConfig_CreateConVar("sm_du_discord_prefix", "[{lightgreen}Discord{default}]", "Prefix for discord messages.");
	
	g_cTimeStamps = AutoExecConfig_CreateConVar("sm_du_display_timestamps", "0", "Display timestamps? Used in gameserver => discord server relay AND AdminLog");
	
	g_cAPIKey = AutoExecConfig_CreateConVar("sm_du_apikey", "", "Steam API Key (https://steamcommunity.com/dev/apikey). Needed for gameserver => discord server relay and/or admin chat relay and/or Admin logs. Blank will show default author icon of discord.", FCVAR_PROTECTED);
	
	#else
	g_cChatRelay_Webhook = CreateConVar("sm_du_chat_webhook", "", "Webhook for game server => discord server chat messages. Blank to disable.", FCVAR_PROTECTED);
	g_cChatRelay_BlockList = CreateConVar("sm_du_chat_blocklist", "rtv, nominate", "Text that shouldn't appear in gameserver => discord server chat messages. Separate it with \", \"");
	g_cAdminChatRelay_Mode = CreateConVar("sm_du_adminchat_mode", "0b", "0 - Only \"say_team with @ / sm_chat\"\n0b - \"say_team with @ / sm_chat\" with discord to game server chat to admin.\nAny admin flag - Show messages of specific flag in channel.");
	g_cAdminChatRelay_Webhook = CreateConVar("sm_du_adminchat_webhook", "", "Webhook for game server => discord server chat messages where chat messages are to (say_team with @ / sm_chat) / are of admins. Blank to disable.", FCVAR_PROTECTED);
	g_cAdminChatRelay_BlockList = CreateConVar("sm_du_adminchat_blocklist", "rtv, nominate", "Text that shouldn't appear in gameserver => discord server where chat messages are to admin. Separate it with \", \"");
	g_cAdminLog_Webhook = CreateConVar("sm_du_adminlog_webhook", "", "Webhook for channel where all admin commands are logged. Blank to disable.", FCVAR_PROTECTED);
	g_cAdminLog_BlockList = CreateConVar("sm_du_adminlog_blocklist", "slapped, firebombed", "Log with this string will be ignored. Separate it with \", \"");
	
	g_cChatRelayChannelID = CreateConVar("sm_du_chat_channelid", "", "Channel ID for discord server => game server messages. Blank to disable.");
	g_cAdminChatRelayChannelID = CreateConVar("sm_du_adminchat_channelid", "", "Channel ID for discord server => game server messages only of admins. Blank to disable.");
	
	g_cBotToken = CreateConVar("sm_du_bottoken", "", "Bot Token. Needed for discord server => gameserver and/or verification module.", FCVAR_PROTECTED);
	
	g_cDiscordPrefix = CreateConVar("sm_du_discord_prefix", "[{lightgreen}Discord{default}]", "Prefix for discord messages.");
	
	g_cTimeStamps = CreateConVar("sm_du_display_timestamps", "0", "Display timestamps? Used in gameserver => discord server relay AND AdminLog");
	
	g_cAPIKey = CreateConVar("sm_du_apikey", "", "Steam API Key (https://steamcommunity.com/dev/apikey). Needed for gameserver => discord server relay and/or admin chat relay and/or Admin logs. Blank will show default author icon of discord.", FCVAR_PROTECTED);
	
	AutoExecConfig(true, "Discord-Utilities");
	#endif
	
	HookConVarChange(g_cChatRelay_Webhook, OnSettingsChanged);
	HookConVarChange(g_cChatRelay_BlockList, OnSettingsChanged);
	HookConVarChange(g_cAdminChatRelay_Mode, OnSettingsChanged);
	HookConVarChange(g_cAdminChatRelay_Webhook, OnSettingsChanged);
	HookConVarChange(g_cAdminChatRelay_BlockList, OnSettingsChanged);
	HookConVarChange(g_cAdminLog_Webhook, OnSettingsChanged);
	HookConVarChange(g_cAdminLog_BlockList, OnSettingsChanged);
	HookConVarChange(g_cChatRelayChannelID, OnSettingsChanged);
	HookConVarChange(g_cAdminChatRelayChannelID, OnSettingsChanged);
	
	HookConVarChange(g_cBotToken, OnSettingsChanged);
	
	HookConVarChange(g_cDiscordPrefix, OnSettingsChanged);
	
	HookConVarChange(g_cAPIKey, OnSettingsChanged);
	
	LoadTranslations("Discord-Utilities.phrases");	
}

public void OnLibraryAdded(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "basecomm")) g_bBaseComm = true;
	else if(StrEqual(szLibrary, "shavit")) g_bShavit = true;
}

public void OnLibraryRemoved(const char[] szLibrary)
{
	if(StrEqual(szLibrary, "basecomm")) g_bBaseComm = false;
	else if(StrEqual(szLibrary, "shavit")) g_bShavit = false;
}

public void OnAllPluginsLoaded()
{
	if(!LibraryExists("discord-api"))
	{
		SetFailState("[Discord-Utilities] This plugin is fully dependant on \"Discord-API\" by Deathknife. (https://github.com/Deathknife/sourcemod-discord)");
	}

	g_bShavit = LibraryExists("shavit");
	g_bBaseComm = LibraryExists("basecomm");
}

public void OnConfigsExecuted()
{
	LoadCvars();
	
	if(!StrEqual(g_sBotToken, ""))
	{
		if(Bot == view_as<DiscordBot>(INVALID_HANDLE))
		{
			CreateBot();
		}
	}
	
	FindConVar("hostname").GetString(g_sServerName, sizeof(g_sServerName));
}

void LoadCvars()
{
	char sBlockList[PLATFORM_MAX_PATH];
	g_cChatRelay_Webhook.GetString(g_sChatRelay_Webhook, sizeof(g_sChatRelay_Webhook));
	g_cChatRelay_BlockList.GetString(sBlockList, sizeof(sBlockList));
	ExplodeString(sBlockList, ", ", g_sChatRelay_BlockList, MAX_BLOCKLIST_LIMIT, 64);
	g_cAdminChatRelay_Mode.GetString(g_sAdminChatRelay_Mode, sizeof(g_sAdminChatRelay_Mode));
	g_cAdminChatRelay_Webhook.GetString(g_sAdminChatRelay_Webhook, sizeof(g_sAdminChatRelay_Webhook));
	g_cAdminChatRelay_BlockList.GetString(sBlockList, sizeof(sBlockList));
	ExplodeString(sBlockList, ", ", g_sAdminChatRelay_BlockList, MAX_BLOCKLIST_LIMIT, 64);
	g_cAdminLog_Webhook.GetString(g_sAdminLog_Webhook, sizeof(g_sAdminLog_Webhook));
	g_cAdminLog_BlockList.GetString(sBlockList, sizeof(sBlockList));
	ExplodeString(sBlockList, ", ", g_sAdminLog_BlockList, MAX_BLOCKLIST_LIMIT, 64);
	
	g_cChatRelayChannelID.GetString(g_sChatRelayChannelID, sizeof(g_sChatRelayChannelID));
	g_cAdminChatRelayChannelID.GetString(g_sAdminChatRelayChannelID, sizeof(g_sAdminChatRelayChannelID));
	
	g_cBotToken.GetString(g_sBotToken, sizeof(g_sBotToken));
	
	g_cDiscordPrefix.GetString(g_sDiscordPrefix, sizeof(g_sDiscordPrefix));
	
	g_cAPIKey.GetString(g_sAPIKey, sizeof(g_sAPIKey));
}

public int OnSettingsChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if(StrEqual(oldVal, newVal, true))
	{
        return;
	}
	if(convar == g_cChatRelay_Webhook)
	{
		strcopy(g_sChatRelay_Webhook, sizeof(g_sChatRelay_Webhook), newVal);
	}
	else if(convar == g_cChatRelay_BlockList)
	{
		ExplodeString(newVal, ", ", g_sChatRelay_BlockList, MAX_BLOCKLIST_LIMIT, 64);
	}
	else if(convar == g_cAdminChatRelay_Webhook)
	{
		strcopy(g_sAdminChatRelay_Webhook, sizeof(g_sAdminChatRelay_Webhook), newVal);
	}
	else if(convar == g_cAdminChatRelay_BlockList)
	{
		ExplodeString(newVal, ", ", g_sAdminChatRelay_BlockList, MAX_BLOCKLIST_LIMIT, 64);
	}
	else if(convar == g_cChatRelayChannelID)
	{
		strcopy(g_sChatRelayChannelID, sizeof(g_sChatRelayChannelID), newVal);
	}
	else if(convar == g_cBotToken)
	{
		strcopy(g_sBotToken, sizeof(g_sBotToken), newVal);
	}
	else if(convar == g_cDiscordPrefix)
	{
		strcopy(g_sDiscordPrefix, sizeof(g_sDiscordPrefix), newVal);
	}
}

public void OnPluginEnd()
{
	KillBot();
}

public void OnMapEnd()
{
	KillBot();
}

public void OnClientPutInServer(int client)
{
	g_sAvatarURL[client][0] = '\0';
}

public Action Command_AdminChat(int client, const char[] command, int argc)
{
	if(g_sAdminChatRelay_Webhook[0] == '\0' || g_sAdminChatRelay_Mode[0] != '0')
	{
		return Plugin_Continue;
	}
	if(IsValidClient(client) && g_bBaseComm && BaseComm_IsClientGagged(client))
	{
		return Plugin_Continue;
	}
	if(1 <= client <= MaxClients)
	{
		char sMessage[256];
		GetCmdArgString(sMessage, sizeof(sMessage));
		SendChatRelay(client, sMessage, g_sAdminChatRelay_Webhook);
	}
	return Plugin_Continue;
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if(StrEqual(g_sChatRelay_Webhook, "") && StrEqual(g_sAdminChatRelay_Webhook, ""))
	{
		return Plugin_Continue;
	}
	if(IsValidClient(client) && g_bBaseComm && BaseComm_IsClientGagged(client))
	{
		return Plugin_Continue;
	}
	if(1 <= client <= MaxClients)
	{
		if(strcmp(command, "say") != 0 && strcmp(command, "say_team") != 0)
		{
			return Plugin_Continue;
		}
		if(IsChatTrigger())
		{
			return Plugin_Continue;
		}
		if(strcmp(command, "say_team") == 0 && sArgs[0] == '@')
		{
			bool bAdmin = CheckCommandAccess(client, "", ADMFLAG_GENERIC);
			if(g_sAdminChatRelay_Mode[0] == '0')
			{
				SendChatRelay(client, sArgs[1], g_sAdminChatRelay_Webhook, bAdmin);
			}
			return Plugin_Continue;
		}
		if(strcmp(command, "say") == 0 && sArgs[0] == '@')
		{
			if(g_sChatRelay_Webhook[0])
			{
				SendChatRelay(client, sArgs[1], g_sChatRelay_Webhook, true, true);
			}
			return Plugin_Continue;
		}
		if(!StrEqual(g_sAdminChatRelay_Mode, "0", false) && !StrEqual(g_sAdminChatRelay_Mode, "", false) && g_sAdminChatRelay_Mode[1] == '\0')
		{
			if(g_sAdminChatRelay_Webhook[0] && CheckAdminFlags(client, ReadFlagString(g_sAdminChatRelay_Mode)))
				SendChatRelay(client, sArgs, g_sAdminChatRelay_Webhook);
		}
		else if(g_sChatRelay_Webhook[0])
		{
			SendChatRelay(client, sArgs, g_sChatRelay_Webhook);
		}
	}
	return Plugin_Continue;
}

public Action OnLogAction(Handle hSource, Identity ident, int client, int target, const char[] sMsg)
{
	if(StrEqual(g_sAdminLog_Webhook, ""))
	{
		delete hSource;
		return Plugin_Continue;
	}

	if(client <= 0)
	{
		delete hSource;
		return Plugin_Continue;
	}

	if(StrContains(sMsg, "sm_chat", false) != -1)
	{
		delete hSource;
		return Plugin_Continue;// dont log sm_chat because it's already being showed in admin chat relay channel.
	}
	
	SendAdminLog(client, sMsg);
	delete hSource;
	
	return Plugin_Continue;
}

public void GuildList(DiscordBot bawt, char[] id, char[] name, char[] icon, bool owner, int permissions, const bool listen)
{
	Bot.GetGuildChannels(id, ChannelList, INVALID_FUNCTION, listen);
}

public void ChannelList(DiscordBot bawt, const char[] guild, DiscordChannel Channel, const bool listen)
{
	if(StrEqual(g_sBotToken, "") || (StrEqual(g_sChatRelayChannelID, "") && StrEqual(g_sVerificationChannelID, "") && StrEqual(g_sAdminChatRelayChannelID, "")))
	{
		return;
	}
	if(Bot == null || Channel == null)
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
	if(strlen(g_sChatRelayChannelID) > 10) //ChannelID size is around 18-20 char
	{
		if(StrEqual(id, g_sChatRelayChannelID))
		{
			Bot.StartListeningToChannel(Channel, ChatRelayReceived);
		}
	}
	if(strlen(g_sAdminChatRelayChannelID) > 10)
	{
		if(StrEqual(id, g_sAdminChatRelayChannelID) && !StrEqual(g_sAdminChatRelay_Mode, "", false) && (g_sAdminChatRelay_Mode[0] == '0' && g_sAdminChatRelay_Mode[1] != '\0') || (g_sAdminChatRelay_Mode[0] != '0' && g_sAdminChatRelay_Mode[0] != '\0'))
		{
			Bot.StartListeningToChannel(Channel, AdminChatRelayReceived);
		}
	}
}

public void AdminChatRelayReceived(DiscordBot bawt, DiscordChannel channel, DiscordMessage discordmessage)
{
	if((g_sAdminChatRelay_Mode[0] == '0' && g_sAdminChatRelay_Mode[1] == '\0') || (g_sAdminChatRelay_Mode[0] != '\0' && g_sAdminChatRelay_Mode[0] != '0' && g_sAdminChatRelay_Mode[1] != '\0'))
	{
		return;
	}
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

	char sFlag[5];
	if(g_sAdminChatRelay_Mode[0] == '0' && g_sAdminChatRelay_Mode[1] != '\0')
	{
		sFlag[0] = g_sAdminChatRelay_Mode[1];
	}
	else
	{
		sFlag[0] = g_sAdminChatRelay_Mode[0];
	}
	for(int i = 1; i <= MaxClients; i++) if(IsClientInGame(i) && !IsFakeClient(i) && CheckAdminFlags(i, ReadFlagString(sFlag)))
	{
		CPrintToChat(i, "%s %T", g_sDiscordPrefix, "AdminChatRelayFormat", i, userName, discriminator, message);
	}
}

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

void SendChatRelay(int client, const char[] sArgs, char[] url, bool bAdmin = true, bool bAllChat = false)
{
	if(strcmp(url, g_sChatRelay_Webhook) == 0)
	{
		for(int i = 0; i < sizeof(g_sChatRelay_BlockList); i++)
		{
			if(strcmp(sArgs, g_sChatRelay_BlockList[i], false) == 0)
			{
				return;
			}
		}
	}
	else if(strcmp(url, g_sAdminChatRelay_Webhook) == 0)
	{
		for(int i = 0; i < sizeof(g_sAdminChatRelay_BlockList); i++)
		{
			if(strcmp(sArgs, g_sAdminChatRelay_BlockList[i], false) == 0)
			{
				return;
			}
		}
	}
	char name[MAX_NAME_LENGTH+1], timestamp[32], sMessage[256];
	GetClientName(client, name, sizeof(name));
	TrimString(name);
	Discord_EscapeString(name, sizeof(name), true);
	
	char auth[32];
	if(!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		return;
	}
	Format(name, sizeof(name), "%s [%s]", name, auth);
	
	FormatEx(sMessage, sizeof(sMessage), sArgs);
	Discord_EscapeString(sMessage, sizeof(sMessage));

	RemoveColors(sMessage, sizeof(sMessage));
	
	if(g_cTimeStamps.BoolValue)
	{
		FormatTime(timestamp, sizeof(timestamp), "[%I:%M:%S %p] ", GetTime());
	}
	
	DiscordWebHook hook = new DiscordWebHook( url );
	hook.SlackMode = true;
	hook.SetUsername( name );
	if(g_sAvatarURL[client][0])
	{
		hook.SetAvatar(g_sAvatarURL[client]);
	}
	char sPrivateToAdmins[32], sAllChat[32];
	Format(sPrivateToAdmins, sizeof(sPrivateToAdmins), "%T", "ChatRelayPrivateToAdmins", LANG_SERVER);
	Format(sAllChat, sizeof(sAllChat), "%T", "ChatRelayAllChat", LANG_SERVER);
	if(strcmp(url, g_sAdminChatRelay_Webhook) == 0)
	{
		Format(sMessage, sizeof(sMessage), "%T", "AdminChatFormat", LANG_SERVER, timestamp, g_sServerName, bAdmin ? "" : sPrivateToAdmins, sMessage);
	}
	else
	{
		Format(sMessage, sizeof(sMessage), "%s%s%s", timestamp, bAllChat ? sAllChat : "", sMessage);
	}
	hook.SetContent(sMessage);
	hook.Send();
	
	delete hook;
}

void SendAdminLog(int client, const char[] sArgs)
{
	char name[MAX_NAME_LENGTH+1], timestamp[32], sMessage[256], map[PLATFORM_MAX_PATH], mapdisplay[64];
	GetClientName(client, name, sizeof(name));
	TrimString(name);
	Discord_EscapeString(name, sizeof(name), true);
	
	char auth[32];
	if(!GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth)))
	{
		return;
	}
	Format(name, sizeof(name), "%s [%s]", name, auth);
	
	GetCurrentMap(map, sizeof(map));
	GetMapDisplayName(map, mapdisplay, sizeof(mapdisplay));

	FormatEx(sMessage, sizeof(sMessage), sArgs);
	Discord_EscapeString(sMessage, sizeof(sMessage));

	
	RemoveColors(name, sizeof(name));
	RemoveColors(sMessage, sizeof(sMessage));
	
	if(g_cTimeStamps.BoolValue)
	{
		FormatTime(timestamp, sizeof(timestamp), "[%I:%M:%S %p] ", GetTime());
	}
	
	DiscordWebHook hook = new DiscordWebHook( g_sAdminLog_Webhook );
	hook.SlackMode = true;
	hook.SetUsername( name );
	if(g_sAvatarURL[client][0])
	{
		hook.SetAvatar(g_sAvatarURL[client]);
	}
	Format(sMessage, sizeof(sMessage), "%T", "AdminLogFormat", LANG_SERVER, timestamp, g_sServerName, mapdisplay, sMessage);
	hook.SetContent(sMessage);
	
	hook.Send();
	
	delete hook;
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

stock void CreateBot()
{
	if(StrEqual(g_sBotToken, "") || StrEqual(g_sChatRelayChannelID, "") && StrEqual(g_sVerificationChannelID, ""))
	{
		return;
	}
	KillBot();
	Bot = new DiscordBot(g_sBotToken);
	CreateTimer(5.0, Timer_GuildList, _, TIMER_FLAG_NO_MAPCHANGE);
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

bool CheckAdminFlags(int client, int iFlag)
{
	int iUserFlags = GetUserFlagBits(client);
	return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}

public Action Timer_GuildList(Handle timer)
{
	GetGuilds();
}

public Action OnClientPreAdminCheck(int client)
{
	if(IsFakeClient(client))
	{
		return;
	}

	
	if(StrEqual(g_sAPIKey, ""))
	{
		return;
	}
	
	char szSteamID64[32];
	if(!GetClientAuthId(client, AuthId_SteamID64, szSteamID64, sizeof(szSteamID64)))
	{
		return;
	}

	static char sRequest[256];
	FormatEx(sRequest, sizeof(sRequest), "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s&format=vdf", g_sAPIKey, szSteamID64);
	Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, sRequest);
	if(!hRequest || !SteamWorks_SetHTTPRequestContextValue(hRequest, client) || !SteamWorks_SetHTTPCallbacks(hRequest, OnTransferCompleted) || !SteamWorks_SendHTTPRequest(hRequest))
	{
		delete hRequest;
	}
}

public int OnTransferCompleted(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, int client)
{
	if (bFailure || !bRequestSuccessful || eStatusCode != k_EHTTPStatusCode200OK)
	{
		LogError("SteamAPI HTTP Response failed: %d", eStatusCode);
		delete hRequest;
		return;
	}

	int iBodyLength;
	SteamWorks_GetHTTPResponseBodySize(hRequest, iBodyLength);

	char[] sData = new char[iBodyLength];
	SteamWorks_GetHTTPResponseBodyData(hRequest, sData, iBodyLength);

	delete hRequest;
	
	APIWebResponse(sData, client);
}

public void APIWebResponse(const char[] sData, int client)
{
	KeyValues kvResponse = new KeyValues("SteamAPIResponse");

	if (!kvResponse.ImportFromString(sData, "SteamAPIResponse"))
	{
		LogError("kvResponse.ImportFromString(\"SteamAPIResponse\") in APIWebResponse failed. Try updating your steamworks extension.");

		delete kvResponse;
		return;
	}

	if (!kvResponse.JumpToKey("players"))
	{
		LogError("kvResponse.JumpToKey(\"players\") in APIWebResponse failed. Try updating your steamworks extension.");

		delete kvResponse;
		return;
	}

	if (!kvResponse.GotoFirstSubKey())
	{
		LogError("kvResponse.GotoFirstSubKey() in APIWebResponse failed. Try updating your steamworks extension.");

		delete kvResponse;
		return;
	}

	kvResponse.GetString("avatarfull", g_sAvatarURL[client], sizeof(g_sAvatarURL[]));
	delete kvResponse;
}

stock void GetGuilds()
{	
	Bot.GetGuilds(GuildList, _, true);
}

stock bool IsValidClient(int client)
{
    return (1 <= client <= MaxClients && IsClientInGame(client));
} 