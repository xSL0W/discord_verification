#include <sourcemod>
#include <autoexecconfig>
#include <SteamWorks>
#include <discord>
#include <discord_utilities>

#include <bugreport>

#pragma dynamic 500000
#pragma newdecls required
#pragma semicolon 1

ConVar g_cBugReport_Webhook, g_cBugReport_BotName, g_cBugReport_BotAvatar, g_cBugReport_Color, g_cBugReport_Content, g_cBugReport_FooterIcon, g_cDNSServerIP;

char g_sBugReport_Webhook[128], g_sBugReport_BotName[32], g_sBugReport_BotAvatar[128], g_sBugReport_Color[8], g_sBugReport_Content[256], g_sBugReport_FooterIcon[128], g_sServerIP[128];

char g_sServerName[128];

bool g_bBugReport;

#define REPORTER_CONSOLE 1679124
#define DEFAULT_COLOR "#00FF00"
#define USE_AutoExecConfig

public Plugin myinfo = 
{
	name = "Discord Utilities - Bugreport module",
	author = "AiDN™ & Cruze03",
	description = "Bugreport module for the Discord Utilities, code from Cruze03",
	version = "1.0",
	url = "https://steamcommunity.com/id/originalaidn & https://github.com/Cruze03/discord-utilities"
};

public void OnPluginStart()
{
	#if defined USE_AutoExecConfig
	AutoExecConfig_SetFile("Discord-Utilities");
	AutoExecConfig_SetCreateFile(true);

	g_cBugReport_Webhook = AutoExecConfig_CreateConVar("sm_du_bugreport_webhook", "", "Webhook for bugreport reports. Blank to disable.", FCVAR_PROTECTED);
	g_cBugReport_BotName = AutoExecConfig_CreateConVar("sm_du_bugreport_botname", "Discord Utilities", "BotName for bugreport. Blank to use webhook name.");
	g_cBugReport_BotAvatar = AutoExecConfig_CreateConVar("sm_du_bugreport_avatar", "", "Avatar link for bugreport bot. Blank to use webhook avatar.");
	g_cBugReport_Color = AutoExecConfig_CreateConVar("sm_du_bugreport_color", "#ff9911", "Color for embed message of bugreport.");
	g_cBugReport_Content = AutoExecConfig_CreateConVar("sm_du_bugreport_content", "", "Content for embed message of bugreport. Blank to disable.");
	g_cBugReport_FooterIcon = AutoExecConfig_CreateConVar("sm_du_bugreport_footericon", "", "Link to footer icon for bugreport. Blank for no footer icon.");
	
	g_cDNSServerIP = AutoExecConfig_CreateConVar("sm_du_dns_ip", "", "DNS IP address of your game server. Blank to use real IP.");
	
	#else
	g_cBugReport_Webhook = CreateConVar("sm_du_bugreport_webhook", "", "Webhook for bugreport reports. Blank to disable.", FCVAR_PROTECTED);
	g_cBugReport_BotName = CreateConVar("sm_du_bugreport_botname", "Discord Utilities", "BotName for bugreport. Blank to use webhook name.");
	g_cBugReport_BotAvatar = CreateConVar("sm_du_bugreport_avatar", "", "Avatar link for bugreport bot. Blank to use webhook avatar.");
	g_cBugReport_Color = CreateConVar("sm_du_bugreport_color", "#ff9911", "Color for embed message of bugreport.");
	g_cBugReport_Content = CreateConVar("sm_du_bugreport_content", "", "Content for embed message of bugreport. Blank to disable.");
	g_cBugReport_FooterIcon = CreateConVar("sm_du_bugreport_footericon", "", "Link to footer icon for bugreport. Blank for no footer icon.");
	
	g_cDNSServerIP = CreateConVar("sm_du_dns_ip", "", "DNS IP address of your game server. Blank to use real IP.");
	
	AutoExecConfig(true, "Discord-Utilities");
	#endif
	
	HookConVarChange(g_cBugReport_Webhook, OnSettingsChanged);
	HookConVarChange(g_cBugReport_BotName, OnSettingsChanged);
	HookConVarChange(g_cBugReport_BotAvatar, OnSettingsChanged);
	HookConVarChange(g_cBugReport_Color, OnSettingsChanged);
	HookConVarChange(g_cBugReport_Content, OnSettingsChanged);
	HookConVarChange(g_cBugReport_FooterIcon, OnSettingsChanged);
	
	LoadTranslations("Discord-Utilities.phrases");	
}

public void OnLibraryAdded(const char[] szLibrary)	
{	
	if(StrEqual(szLibrary, "bugreport")) g_bBugReport = true;
}

public void OnLibraryRemoved(const char[] szLibrary)	
{	
	if(StrEqual(szLibrary, "bugreport")) g_bBugReport = false;
}	
public void OnAllPluginsLoaded()	
{	
	if(!LibraryExists("discord-api"))	
	{	
		SetFailState("[Discord-Utilities] This plugin is fully dependant on \"Discord-API\" by Deathknife. (https://github.com/Deathknife/sourcemod-discord)");	
	}	
		
	g_bBugReport = LibraryExists("bugreport");
}

public void OnConfigsExecuted()
{
	LoadCvars();	
	FindConVar("hostname").GetString(g_sServerName, sizeof(g_sServerName));	
}

void LoadCvars()
{
	g_cBugReport_Webhook.GetString(g_sBugReport_Webhook, sizeof(g_sBugReport_Webhook));
	g_cBugReport_BotName.GetString(g_sBugReport_BotName, sizeof(g_sBugReport_BotName));
	g_cBugReport_BotAvatar.GetString(g_sBugReport_BotAvatar, sizeof(g_sBugReport_BotAvatar));
	g_cBugReport_Color.GetString(g_sBugReport_Color, sizeof(g_sBugReport_Color));
	g_cBugReport_Content.GetString(g_sBugReport_Content, sizeof(g_sBugReport_Content));
	g_cBugReport_FooterIcon.GetString(g_sBugReport_FooterIcon, sizeof(g_sBugReport_FooterIcon));	
		
	g_cDNSServerIP.GetString(g_sServerIP, sizeof(g_sServerIP));
	ServerIP(g_sServerIP, sizeof(g_sServerIP));
}

public int OnSettingsChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if(StrEqual(oldVal, newVal, true))
	{
        return;
	}
	if(convar == g_cBugReport_Webhook)
	{
		strcopy(g_sBugReport_Webhook, sizeof(g_sBugReport_Webhook), newVal);
	}
	else if(convar == g_cBugReport_BotName)
	{
		strcopy(g_sBugReport_BotName, sizeof(g_sBugReport_BotName), newVal);
	}
	else if(convar == g_cBugReport_BotAvatar)
	{
		strcopy(g_sBugReport_BotAvatar, sizeof(g_sBugReport_BotAvatar), newVal);
	}
	else if(convar == g_cBugReport_Color)
	{
		strcopy(g_sBugReport_Color, sizeof(g_sBugReport_Color), newVal);
	}
	else if(convar == g_cBugReport_Content)
	{
		strcopy(g_sBugReport_Content, sizeof(g_sBugReport_Content), newVal);
	}
	else if(convar == g_cBugReport_FooterIcon)
	{
		strcopy(g_sBugReport_FooterIcon, sizeof(g_sBugReport_FooterIcon), newVal);
	}
	else if(convar == g_cDNSServerIP)
	{
		strcopy(g_sServerIP, sizeof(g_sServerIP), newVal);
		ServerIP(g_sServerIP, sizeof(g_sServerIP));
	}
}

public void BugReport_OnReportPost(int client, const char[] map, const char[] reason, ArrayList array)
{
	if(StrEqual(g_sBugReport_Webhook, ""))
	{
		return;
	}
	
	if(!g_bBugReport)
	{
		return;
	}
	
	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
	int index = array.FindString(sReason);

	if(index != -1)
	{
		LogError("Duplicate Reason. Skipping.");
		return;
	}

	Discord_EscapeString(sReason, sizeof(sReason));
	
	char clientAuth[21];
	char clientAuth2[21];
	char clientName[(MAX_NAME_LENGTH + 1) * 2];
	
	if (client == REPORTER_CONSOLE)
	{
		Format(clientName, sizeof(clientName), "%T", "SERVER", LANG_SERVER);
		Format(clientAuth, sizeof(clientAuth), "%T", "CONSOLE", LANG_SERVER);
	}
	else
	{
		GetClientAuthId(client, AuthId_SteamID64, clientAuth, sizeof(clientAuth));
		GetClientAuthId(client, AuthId_Steam2, clientAuth2, sizeof(clientAuth2));
		GetClientName(client, clientName, sizeof(clientName));
		Discord_EscapeString(clientName, sizeof(clientName));
	}
	
	DiscordWebHook hook = new DiscordWebHook( g_sBugReport_Webhook );
	hook.SlackMode = true;
	if(g_sBugReport_BotName[0])
	{
		hook.SetUsername( g_sBugReport_BotName );
	}
	
	if(g_sBugReport_BotAvatar[0])
	{
		hook.SetAvatar( g_sBugReport_BotAvatar );
	}
	
	MessageEmbed embed = new MessageEmbed();
	
	if(StrContains(g_sBugReport_Color, "#") != -1)
	{
		embed.SetColor(g_sBugReport_Color);
	}
	else
	{
		LogError("[Discord-Utilities] BugReport is using default color as you've set invalid BugReport color.");
		embed.SetColor(DEFAULT_COLOR);
	}
	
	char buffer[512], trans[64];
	Format( trans, sizeof( trans ), "%T", "BugReportTitle", LANG_SERVER);
	embed.SetTitle( buffer );
	
	if (client != REPORTER_CONSOLE)
	{
		Format( buffer, sizeof( buffer ), "[%s](http://www.steamcommunity.com/profiles/%s) (%s)", clientName, clientAuth, clientAuth2 );
	}
	else
	{
		Format( buffer, sizeof( buffer ), "%s", clientName );
	}
	Format( trans, sizeof( trans ), "%T", "ReporterField", LANG_SERVER);
	embed.AddField( trans, buffer, true );
	
	Format( trans, sizeof( trans ), "%T", "MapField", LANG_SERVER);
	embed.AddField( trans, map, true );
	
	Format( trans, sizeof( trans ), "%T", "ReasonField", LANG_SERVER);
	embed.AddField( trans, sReason, false );
	
	Format( trans, sizeof( trans ), "%T", "DirectConnectField", LANG_SERVER);
	Format( buffer, sizeof( buffer ), "steam://connect/%s", g_sServerIP );
	embed.AddField( trans, buffer, false );
	
	if(g_sBugReport_FooterIcon[0])
	{
		embed.SetFooterIcon( g_sBugReport_FooterIcon );
	}
	Format( buffer, sizeof( buffer ), "%T", "ServerField", LANG_SERVER, g_sServerName);
	embed.SetFooter( buffer );
	
	if(g_sBugReport_Content[0])
	{
		hook.SetContent(g_sBugReport_Content);
	}
	
	hook.Embed( embed );
	hook.Send();
	delete hook;
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

void ServerIP(char[] sIP, int size)
{
	if(sIP[0])
	{
		return;
	}
	int ip[4];
	int iServerPort = FindConVar("hostport").IntValue;
	SteamWorks_GetPublicIP(ip);
	if(SteamWorks_GetPublicIP(ip))
	{
		Format(sIP, size, "%d.%d.%d.%d:%d", ip[0], ip[1], ip[2], ip[3], iServerPort);
	}
	else
	{
		int iServerIP = FindConVar("hostip").IntValue;
		Format(sIP, size, "%d.%d.%d.%d:%d", iServerIP >> 24 & 0x000000FF, iServerIP >> 16 & 0x000000FF, iServerIP >> 8 & 0x000000FF, iServerIP & 0x000000FF, iServerPort);
	}
}