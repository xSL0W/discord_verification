#define PLUGIN_VERSION "2.6"

#define PLUGIN_NAME "Discord Utilities"
#define PLUGIN_AUTHOR "Cruze & xSlow & AiDN™"
#define PLUGIN_DESC "Utilities that can be used to integrate gameserver to discord server I guess?"
#define PLUGIN_URL "https://github.com/Cruze03/discord-utilities | http://www.steamcommunity.com/profiles/76561198132924835 & http://steamcommunity.com/profiles/76561198192410833 & http://steamcommunity.com/profiles/76561198069218105"

//#define USE_AutoExecConfig


ConVar g_cVerificationChannelID, g_cGuildID, g_cRoleID;
ConVar g_cBotToken, g_cCheckInterval, g_cUseSWGM, g_cServerID;
ConVar g_cLinkCommand, g_cViewIDCommand, g_cUnLinkCommand, g_cInviteLink;
ConVar g_cDiscordPrefix, g_cServerPrefix;
ConVar g_cDatabaseName, g_cTableName, g_cPruneDays;
ConVar g_cPrimaryServer;
ConVar g_cLogRevokeEnabled, g_cDsMembersEnabled;

char g_sVerificationChannelID[20], g_sGuildID[20], g_sRoleID[20];
char g_sBotToken[60];
char g_sLinkCommand[20], g_sViewIDCommand[20], g_sUnLinkCommand[20], g_sInviteLink[30];
char g_sDiscordPrefix[128], g_sServerPrefix[128];
char g_sTableName[32];

char g_sVerificationChannelName[32];

bool g_bShavit;

bool g_bChecked[MAXPLAYERS+1];
bool g_bMember[MAXPLAYERS+1];
bool g_bRoleGiven[MAXPLAYERS+1];
char g_sUserID[MAXPLAYERS+1][20];
char g_sUniqueCode[MAXPLAYERS+1][36];

Handle g_hOnCheckedAccounts, g_hOnLinkedAccount, g_hOnAccountRevoked, g_hOnMemberDataDumped;

DiscordBot Bot;

Database g_hDB;

bool g_bIsMySQl;

bool g_bLateLoad = false;
//bool g_bIsBotLoaded = false;

Handle hRateLimit = null;
Handle hRateReset = null;
Handle hRateLeft = null;

Handle hFinalMemberList;