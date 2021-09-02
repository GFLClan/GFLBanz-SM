#include <sourcemod>
#include <basecomm>
#include <sdktools>

#include <gflbans>

#pragma semicolon 1
#pragma newdecls required

#include "gflbans-core/variables.sp"
#include "gflbans-core/forwards.sp"
#include "gflbans-core/logging.sp"
#include "gflbans-core/natives.sp"
#include "gflbans-core/misc.sp"
#include "gflbans-core/api.sp"
#include "gflbans-core/events.sp"
#include "gflbans-core/bans.sp"
#include "gflbans-core/comms.sp"

/* ===== Plugin Info ===== */
public Plugin myinfo =
{
    name        =   PLUGIN_NAME,
    author      =   PLUGIN_AUTHOR,
    description =   PLUGIN_DESCRIPTION,
    version     =   PLUGIN_VERSION,
    url         =   PLUGIN_URL
};

/* ===== Main Code ===== */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    RegPluginLibrary("gflbans");
    
    CreateNatives(); // From natives.sp
    CreateForwards(); // From forwards.sp

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("gflbans-core.phrases");
    LoadTranslations("common.phrases");
    
    Handle gameData = LoadGameConfigFile("gflbans.games");
    if (gameData == INVALID_HANDLE)
        SetFailState("Can't find gflbans.games.txt gamedata.");
		
    if (GameConfGetOffset(gameData, "CheckOS") == 1) // CheckOS = 1 for Windows, CheckOS = 2 for Linux.
        Format(g_sServerOS, sizeof(g_sServerOS), "windows");
    else
        Format(g_sServerOS, sizeof(g_sServerOS), "linux"); // We are falling back to Linux.
        
    delete gameData;

    g_cvAPIUrl = CreateConVar("gb_api_url", "", "GFLBans API URL");
    g_cvAPIKey = CreateConVar("gb_api_key", "", "GFLBans API Key", FCVAR_PROTECTED);
    g_cvAPIServerID = CreateConVar("gb_api_svid", "", "GFLBans API Server ID.", FCVAR_PROTECTED);
    
    g_cvAcceptGlobalBans = CreateConVar("gb_accept_global_infractions", "1", "Accept global GFL bans. 1 = Enabled, 0 = Disabled.", _, true, 0.0, true, 1.0);
    g_cvInfractionScope = CreateConVar("gb_infractions_scope", "1", "Infraction Scope. 1 = Server, 0 = Global.", _, true, 0.0, true, 1.0);
    g_cvShowJoinMessage = CreateConVar("gb_join_message", "1", "Displays infraction count of player to admins on join. 1 = Enabled, 0 = Disabled", _, true, 0.0, true, 1.0);
    
    g_cvDebug = CreateConVar("gb_enable_debug_mode", "1", "Enable detailed logging of actions. 1 = Enabled, 0 = Disabled.", _, true, 0.0, true, 1.0);
    
    RegAdminCmd("sm_checkplayer", Command_GFLBansCheckPlayer, ADMFLAG_GENERIC, "sm_checkplayer <#userid|name>");
    RegAdminCmd("sm_gflbans_debug", Command_GFLBansDebug, ADMFLAG_ROOT, "sm_gflbans_debug <#userid|name>");
    
    RegisterBanCommands();
    RegisterCommCommands();

    AutoExecConfig(true, "GFLBans-Core");
}

public void OnConfigsExecuted()
{
    char APIKey[256];
    char APIServerID[32];
    char APIAuthHeader[512];

    GetConVarString(g_cvAPIUrl, g_sAPIUrl, sizeof(g_sAPIUrl));
    GetConVarString(g_cvAPIKey, APIKey, sizeof(APIKey));
    GetConVarString(g_cvAPIServerID, APIServerID, sizeof(APIServerID));
    Format(APIAuthHeader, sizeof(APIAuthHeader), "SERVER %s %s", APIServerID, APIKey);
    
    if(httpClient != null)
    	delete httpClient;

    // Start the HTTP Connection:
    httpClient = new HTTPClient(g_sAPIUrl);
    httpClient.SetHeader("Authorization", APIAuthHeader);
}

public void OnMapStart()
{
    hbTimer = CreateTimer(30.0, PulseTimer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); // Start the Heartbeat pulse timer
}

public Action PulseTimer(Handle timer)
{
    API_Heartbeat();

    return Plugin_Continue;
}

public void OnMapEnd()
{
    CloseHandle(hbTimer); // Close the Heartbeat timer handle (started in OnMapStart)
    if (g_cvDebug.BoolValue)
        DebugLog("[GFLBans-Core] DEBUG >> Map is ending, cleaning heartbeat pulse timer handle.");
}

public void OnClientPostAdminCheck(int iClient)
{
    API_CheckInfractions(iClient);
    
    if (g_cvShowJoinMessage.BoolValue)
        API_GetPlayerStats(iClient);
}

public void OnClientConnected(int iClient)
{
    // Clear all the details for a newly connected client:
    g_esPlayerInfo[iClient].ClearAll();
}

public void OnClientDisconnect(int iClient)
{
    // Clear all the details for a disconnected client:
    g_esPlayerInfo[iClient].ClearAll();
}

/**
* Main functions
*
* Debug Print Variables
**/
public Action Command_GFLBansDebug(int iClient, int iArgs)
{
    if (iArgs < 1)
    {
        ReplyToCommand(iClient, "%sUsage: sm_gflbans_debug <#userid|name>", PREFIX);
        return Plugin_Handled;
    }
    
    char sBuffer[64];
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    
    int iTarget = FindTarget(iClient, sBuffer, true, true);
    if (iTarget == -1 || !IsValidClient(iTarget))
        return Plugin_Handled;
        
    PrintToChat(iClient, "%sDebugging values printed to console.", PREFIX);
    PrintToConsole(iClient, "[GFLBans Debug] INT: Current Time = %d", GetTime());
    
    PrintToConsole(iClient, "[GFLBans Debug] BOOL: PlayerInfo::gagIsGagged = %b", g_esPlayerInfo[iTarget].gagIsGagged);
    PrintToConsole(iClient, "[GFLBans Debug] INT: PlayerInfo::gagExpiration = %d", g_esPlayerInfo[iTarget].gagExpiration);
    PrintToConsole(iClient, "[GFLBans Debug] STR: PlayerInfo::gagReason = %s", g_esPlayerInfo[iTarget].gagReason);
    PrintToConsole(iClient, "[GFLBans Debug] STR: PlayerInfo::gagAdminName = %s", g_esPlayerInfo[iTarget].gagAdminName);
    PrintToConsole(iClient, "[GFLBans Debug] INT: PlayerInfo::gagType = %d", view_as<int>(g_esPlayerInfo[iTarget].gagType));

    PrintToConsole(iClient, "[GFLBans Debug] BOOL: PlayerInfo::muteIsMuted = %b", g_esPlayerInfo[iTarget].muteIsMuted);
    PrintToConsole(iClient, "[GFLBans Debug] INT: PlayerInfo::muteExpiration = %d", g_esPlayerInfo[iTarget].muteExpiration);
    PrintToConsole(iClient, "[GFLBans Debug] STR: PlayerInfo::muteReason = %s", g_esPlayerInfo[iTarget].muteReason);
    PrintToConsole(iClient, "[GFLBans Debug] STR: PlayerInfo::muteAdminName = %s", g_esPlayerInfo[iTarget].muteAdminName);
    PrintToConsole(iClient, "[GFLBans Debug] INT: PlayerInfo::muteType = %d", view_as<int>(g_esPlayerInfo[iTarget].muteType));
    
    return Plugin_Handled;
}

/**
* Main functions
*
* Create punishment
**/
void SetupInfraction(int iClient = 0, int iTarget, int iLength, const char[] sReason, PunishmentsTemplate iPunishmentFlags)
{
    CreateInfraction infraction = new CreateInfraction();
    
    if (iLength)
        infraction.Duration = iLength;
        
    // Set player:
    PlayerObjSimple targetObjSimple = new PlayerObjSimple();
    targetObjSimple.SetService("steam");
    targetObjSimple.SetID64(iTarget);
    targetObjSimple.SetIP(iTarget);
    
    infraction.SetPlayer(targetObjSimple);
    
    // Set admin field if it's not console:
    if (iClient)
    {
        PlayerObjNoIp adminObjNoIp = new PlayerObjNoIp();
        adminObjNoIp.SetService("steam");
        adminObjNoIp.SetID64(iClient);
        
        infraction.SetAdmin(adminObjNoIp);
        
        delete adminObjNoIp;
    }
    
    // Set other fields:
    infraction.SetReason(sReason);
    infraction.SetPunishment(iPunishmentFlags);
    infraction.SetScope(view_as<InfractionScope>(g_cvInfractionScope.IntValue));
    infraction.SessionOnly = false;
    infraction.OnlineOnly = false;
    
    API_CreateInfraction(iClient, iTarget, iLength, sReason, iPunishmentFlags, infraction);
    
    // Cleanup:
    delete targetObjSimple;
    delete infraction;
}

/**
* Main functions
*
* Remove Infraction
**/
void SetupRemoval(int iClient, int iTarget, PunishmentsTemplate iPunishmentFlags, const char[] sReason)
{
    RemoveInfractionsOfPlayer removeInfraction = new RemoveInfractionsOfPlayer();
    
    // Set player:
    PlayerObjNoIp targetObjNoIp = new PlayerObjNoIp();
    targetObjNoIp.SetService("steam");
    targetObjNoIp.SetID64(iTarget);
    
    removeInfraction.SetPlayer(targetObjNoIp);
    
    // Set admin field if it's not console:
    if (iClient)
    {
        PlayerObjNoIp adminObjNoIp = new PlayerObjNoIp();
        adminObjNoIp.SetService("steam");
        adminObjNoIp.SetID64(iClient);
        
        removeInfraction.SetAdmin(adminObjNoIp);
        
        delete adminObjNoIp;
    }
    
    // Set other fields:
    removeInfraction.SetReason(sReason);
    removeInfraction.SetIncludeOtherServers = true;
    removeInfraction.SetRestrictTypes(iPunishmentFlags);
    
    API_RemoveInfraction(iClient, iTarget, sReason, iPunishmentFlags, removeInfraction);
    
    // Cleanup:
    delete targetObjNoIp;
    delete removeInfraction;
}

/**
* Main Commands
*
* Check player infraction count
**/
public Action Command_GFLBansCheckPlayer(int iClient, int iArgs)
{
    
}