#include <sourcemod>
#include <autoexecconfig>
#include <SteamWorks>
#include <discord>
#include <discord_utilities>

#include <calladmin>

#include <multicolors>

#define DEFAULT_COLOR "#00FF00"

#pragma dynamic 500000
#pragma newdecls required
#pragma semicolon 1

ConVar g_cCallAdmin_Webhook, g_cCallAdmin_BotName, g_cCallAdmin_BotAvatar, g_cCallAdmin_Color, g_cCallAdmin_Content, g_cCallAdmin_FooterIcon, g_cDNSServerIP;

char g_sCallAdmin_Webhook[128], g_sCallAdmin_BotName[32], g_sCallAdmin_BotAvatar[128], g_sCallAdmin_Color[8], g_sCallAdmin_Content[256], g_sCallAdmin_FooterIcon[128], g_sServerIP[128];

int g_iLastReportID;

char g_sServerName[128];

ArrayList g_aCallAdmin_ReportedList;

bool g_bCallAdmin;

public Plugin myinfo = 
{
	name = "Discord Utilities - Calladmin module",
	author = "AiDN™ & Cruze03",
	description = "Calladmin module for the Discord Utilities, code from Cruze03",
	version = "1.0",
	url = "https://steamcommunity.com/id/originalaidn & https://github.com/Cruze03/discord-utilities"
};

public void OnLibraryAdded(const char[] szLibrary)	
{	
	if(StrEqual(szLibrary, "calladmin")) g_bCallAdmin = true;	
}

public void OnLibraryRemoved(const char[] szLibrary)	
{	
	if(StrEqual(szLibrary, "calladmin")) g_bCallAdmin = false;	
}	
public void OnAllPluginsLoaded()	
{	
	if(!LibraryExists("discord-api"))	
	{	
		SetFailState("[Discord-Utilities] This plugin is fully dependant on \"Discord-API\" by Deathknife. (https://github.com/Deathknife/sourcemod-discord)");	
	}	
		
	g_bCallAdmin = LibraryExists("calladmin");	
}

public void OnConfigsExecuted()
{
	LoadCvars();
	if(g_bCallAdmin)	
	{	
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));	
		g_aCallAdmin_ReportedList = new ArrayList(64);	
	}	
	else	
	{	
		FindConVar("hostname").GetString(g_sServerName, sizeof(g_sServerName));	
	}
}

public int OnSettingsChanged(ConVar convar, const char[] oldVal, const char[] newVal)
{
	if(StrEqual(oldVal, newVal, true))
	{
        return;
	}
	if(convar == g_cCallAdmin_Webhook)
	{
		strcopy(g_sCallAdmin_Webhook, sizeof(g_sCallAdmin_Webhook), newVal);
	}
	else if(convar == g_cCallAdmin_BotName)
	{
		strcopy(g_sCallAdmin_BotName, sizeof(g_sCallAdmin_BotName), newVal);
	}
	else if(convar == g_cCallAdmin_BotAvatar)
	{
		strcopy(g_sCallAdmin_BotAvatar, sizeof(g_sCallAdmin_BotAvatar), newVal);
	}
	else if(convar == g_cCallAdmin_Color)
	{
		strcopy(g_sCallAdmin_Color, sizeof(g_sCallAdmin_Color), newVal);
	}
	else if(convar == g_cCallAdmin_Content)
	{
		strcopy(g_sCallAdmin_Content, sizeof(g_sCallAdmin_Content), newVal);
	}
	else if(convar == g_cCallAdmin_FooterIcon)
	{
		strcopy(g_sCallAdmin_FooterIcon, sizeof(g_sCallAdmin_FooterIcon), newVal);
	}
	else if(convar == g_cDNSServerIP)
	{
		strcopy(g_sServerIP, sizeof(g_sServerIP), newVal);
		ServerIP(g_sServerIP, sizeof(g_sServerIP));
	}
}

public void CallAdmin_OnServerDataChanged(ConVar convar, ServerData type, const char[] oldVal, const char[] newVal)	
{	
	if (type == ServerData_HostName)	
		CallAdmin_GetHostName(g_sServerName, sizeof(g_sServerName));	
}

public void OnPluginStart()
{
	#if defined USE_AutoExecConfig
	AutoExecConfig_SetFile("Discord-Utilities");
	AutoExecConfig_SetCreateFile(true);

	g_cCallAdmin_Webhook = AutoExecConfig_CreateConVar("sm_du_calladmin_webhook", "", "Webhook for calladmin reports and report handled print. Blank to disable.", FCVAR_PROTECTED);	
	g_cCallAdmin_BotName = AutoExecConfig_CreateConVar("sm_du_calladmin_botname", "Discord Utilities", "BotName for calladmin. Blank to use webhook name.");	
	g_cCallAdmin_BotAvatar = AutoExecConfig_CreateConVar("sm_du_calladmin_avatar", "", "Avatar link for calladmin bot. Blank to use webhook avatar.");	
	g_cCallAdmin_Color = AutoExecConfig_CreateConVar("sm_du_calladmin_color", "#ff9911", "Color for embed message of calladmin.");	
	g_cCallAdmin_Content = AutoExecConfig_CreateConVar("sm_du_calladmin_content", "When in-game type !calladmin_handle <ReportID> in chat to handle this report.", "Content for embed message of calladmin. Blank to disable.");	
	g_cCallAdmin_FooterIcon = AutoExecConfig_CreateConVar("sm_du_calladmin_footericon", "", "Link to footer icon for calladmin. Blank for no footer icon.");	
	
	g_cDNSServerIP = AutoExecConfig_CreateConVar("sm_du_dns_ip", "", "DNS IP address of your game server. Blank to use real IP.");
	
	#else
	g_cCallAdmin_Webhook = CreateConVar("sm_du_calladmin_webhook", "", "Webhook for calladmin reports and report handled print. Blank to disable.", FCVAR_PROTECTED);	
	g_cCallAdmin_BotName = CreateConVar("sm_du_calladmin_botname", "Discord Utilities", "BotName for calladmin. Blank to use webhook name.");	
	g_cCallAdmin_BotAvatar = CreateConVar("sm_du_calladmin_avatar", "", "Avatar link for calladmin bot. Blank to use webhook avatar.");	
	g_cCallAdmin_Color = CreateConVar("sm_du_calladmin_color", "#ff9911", "Color for embed message of calladmin.");	
	g_cCallAdmin_Content = CreateConVar("sm_du_calladmin_content", "When in-game type !calladmin_handle <ReportID> in chat to handle this report.", "Content for embed message of calladmin. Blank to disable.");	
	g_cCallAdmin_FooterIcon = CreateConVar("sm_du_calladmin_footericon", "", "Link to footer icon for calladmin. Blank for no footer icon.");	
	
	g_cDNSServerIP = CreateConVar("sm_du_dns_ip", "", "DNS IP address of your game server. Blank to use real IP.");
	
	AutoExecConfig(true, "Discord-Utilities");
	#endif
	
	HookConVarChange(g_cCallAdmin_Webhook, OnSettingsChanged);
	HookConVarChange(g_cCallAdmin_BotName, OnSettingsChanged);
	HookConVarChange(g_cCallAdmin_BotAvatar, OnSettingsChanged);
	HookConVarChange(g_cCallAdmin_Color, OnSettingsChanged);
	HookConVarChange(g_cCallAdmin_Content, OnSettingsChanged);
	HookConVarChange(g_cCallAdmin_FooterIcon, OnSettingsChanged);
	
	LoadTranslations("Discord-Utilities.phrases");	
}

void LoadCvars()
	{
		g_cCallAdmin_Webhook.GetString(g_sCallAdmin_Webhook, sizeof(g_sCallAdmin_Webhook));		
		g_cCallAdmin_BotName.GetString(g_sCallAdmin_BotName, sizeof(g_sCallAdmin_BotName));		
		g_cCallAdmin_BotAvatar.GetString(g_sCallAdmin_BotAvatar, sizeof(g_sCallAdmin_BotAvatar));		
		g_cCallAdmin_Color.GetString(g_sCallAdmin_Color, sizeof(g_sCallAdmin_Color));		
		g_cCallAdmin_Content.GetString(g_sCallAdmin_Content, sizeof(g_sCallAdmin_Content));		
		g_cCallAdmin_FooterIcon.GetString(g_sCallAdmin_FooterIcon, sizeof(g_sCallAdmin_FooterIcon));	
		
		g_cDNSServerIP.GetString(g_sServerIP, sizeof(g_sServerIP));
		ServerIP(g_sServerIP, sizeof(g_sServerIP));
	}

public void CallAdmin_OnReportHandled(int client, int id)
{
	if(StrEqual(g_sCallAdmin_Webhook, ""))
	{
		return;
	}
	if(!g_bCallAdmin)
	{
		return;
	}
	if (id != g_iLastReportID)
	{
		return;
	}
	
	char clientName[MAX_NAME_LENGTH], clientAuth[32], clientAuth2[32];
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_SteamID64, clientAuth, sizeof(clientAuth));
	GetClientAuthId(client, AuthId_Steam2, clientAuth2, sizeof(clientAuth2));
	Discord_EscapeString(clientName, sizeof(clientName));
	
	DiscordWebHook hook = new DiscordWebHook( g_sCallAdmin_Webhook );
	hook.SlackMode = true;
	if(g_sCallAdmin_BotName[0])
	{
		hook.SetUsername( g_sCallAdmin_BotName );
	}
	if(g_sCallAdmin_BotAvatar[0])
	{
		hook.SetAvatar( g_sCallAdmin_BotAvatar );
	}
	
	MessageEmbed embed = new MessageEmbed();
	
	if(StrContains(g_sCallAdmin_Color, "#") != -1)
	{
		embed.SetColor(g_sCallAdmin_Color);
	}
	else
	{
		LogError("[Discord-Utilities] CallAdmin ReportHandled is using default color as you've set invalid CallAdmin ReportHandled color.");
		embed.SetColor(DEFAULT_COLOR);
	}
	
	char buffer[512], trans[64];
	Format( trans, sizeof( trans ), "%T", "CallAdminReportHandledTitle", LANG_SERVER);
	embed.SetTitle( trans );
	
	Format( trans, sizeof( trans ), "%T", "CallAdminReportHandlerName", LANG_SERVER);
	Format( buffer, sizeof( buffer ), "[%s](http://www.steamcommunity.com/profiles/%s)(%s)", clientName, clientAuth, clientAuth2 );
	embed.AddField( trans, buffer, true );
	
	Format( trans, sizeof( trans ), "%T", "CallAdminReportIDField", LANG_SERVER);
	Format(buffer, sizeof(buffer), "%d", g_iLastReportID);
	embed.AddField( trans, buffer, true );
	
	Format( trans, sizeof( trans ), "%T", "DirectConnectField", LANG_SERVER);
	Format( buffer, sizeof( buffer ), "steam://connect/%s", g_sServerIP );
	embed.AddField( trans, buffer, false );
	
	if(g_sCallAdmin_FooterIcon[0])
	{
		embed.SetFooterIcon( g_sCallAdmin_FooterIcon );
	}
	Format( buffer, sizeof( buffer ), "%T", "ServerField", LANG_SERVER, g_sServerName );
	embed.SetFooter( buffer );
	
	hook.Embed( embed );
	hook.Send();
	delete hook;
}


public void CallAdmin_OnReportPost(int client, int target, const char[] reason)
{
	if(StrEqual(g_sCallAdmin_Webhook, ""))
	{
		return;
	}
	if(!g_bCallAdmin)
	{
		return;
	}
	char sReason[(REASON_MAX_LENGTH + 1) * 2];
	strcopy(sReason, sizeof(sReason), reason);
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
	
	char targetAuth[21];
	char targetAuth2[21];
	char targetName[(MAX_NAME_LENGTH + 1) * 2];
	
	GetClientAuthId(target, AuthId_SteamID64, targetAuth, sizeof(targetAuth));
	GetClientAuthId(target, AuthId_Steam2, targetAuth2, sizeof(targetAuth2));
	GetClientName(target, targetName, sizeof(targetName));
	Discord_EscapeString(targetName, sizeof(targetName));
	
	int index = g_aCallAdmin_ReportedList.FindString(targetAuth);
	
	if(index != -1)
	{
		return;
	}
	
	g_aCallAdmin_ReportedList.PushString(targetAuth);
	
	DiscordWebHook hook = new DiscordWebHook( g_sCallAdmin_Webhook );
	hook.SlackMode = true;
	if(g_sCallAdmin_BotName[0])
	{
		hook.SetUsername( g_sCallAdmin_BotName );
	}
	if(g_sCallAdmin_BotAvatar[0])
	{
		hook.SetAvatar( g_sCallAdmin_BotAvatar );
	}
	
	MessageEmbed embed = new MessageEmbed();
	
	if(StrContains(g_sCallAdmin_Color, "#") != -1)
	{
		embed.SetColor(g_sCallAdmin_Color);
	}
	else
	{
		LogError("[Discord-Utilities] CallAdmin ReportPost is using default color as you've set invalid CallAdmin ReportPost color.");
		embed.SetColor(DEFAULT_COLOR);
	}
	
	g_iLastReportID = CallAdmin_GetReportID();
	
	char buffer[512], trans[64];
	Format( trans, sizeof( trans ), "%T", "CallAdminReportTitle", LANG_SERVER);
	embed.SetTitle( buffer );
	
	if (client != REPORTER_CONSOLE)
	{
		Format( buffer, sizeof( buffer ), "[%s](http://www.steamcommunity.com/profiles/%s) (%s)", clientName, clientAuth, clientAuth2 );
	}
	else
	{
		Format( buffer, sizeof( buffer ), "%s", clientName );
	}
	Format(trans, sizeof(trans), "%T", "ReporterField", LANG_SERVER);
	embed.AddField( trans, buffer, true );
	
	Format(trans, sizeof(trans), "%T", "TargetField", LANG_SERVER);
	Format( buffer, sizeof( buffer ), "[%s](http://www.steamcommunity.com/profiles/%s) (%s)", targetName, targetAuth, targetAuth2 );
	embed.AddField( trans, buffer, true	);
	
	Format(trans, sizeof(trans), "%T", "ReasonField", LANG_SERVER);
	embed.AddField( trans, sReason, true );

	Format(trans, sizeof(trans), "%T", "CallAdminReportIDField", LANG_SERVER);
	Format(buffer, sizeof(buffer), "%d",  g_iLastReportID);
	
	embed.AddField( trans, buffer, false );
	
	Format(trans, sizeof(trans), "%T", "DirectConnectField", LANG_SERVER);
	Format( buffer, sizeof( buffer ), "steam://connect/%s", g_sServerIP );
	embed.AddField( trans, buffer, true );
	
	if(g_sCallAdmin_FooterIcon[0])
	{
		embed.SetFooterIcon( g_sCallAdmin_FooterIcon );
	}
	Format( buffer, sizeof( buffer ), "%T", "ServerField", LANG_SERVER, g_sServerName );
	embed.SetFooter( buffer );
	
	if(g_sCallAdmin_Content[0])
	{
		hook.SetContent( g_sCallAdmin_Content );
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
