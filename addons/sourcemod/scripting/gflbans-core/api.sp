/***************************************
 * Heartbeat API
***************************************/
void API_Heartbeat()
{
	// Update whatever is needed for the Heartbeat pulse:
    GetServerInfo();
    CheckMod(); //Check what game we are on.
	
    char requestURL[512];
    Format(requestURL, sizeof(requestURL), "gs/heartbeat");
    
    // Populate array list of PlayerObjs.
    JSONArray playerList = new JSONArray();
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && !IsFakeClient(client))
        {
            PlayerObjIPOptional PlayerObjIP = new PlayerObjIPOptional();
            PlayerObjIP.SetService("steam");
            PlayerObjIP.SetID64(client);
            PlayerObjIP.SetIP(client);

            // Push current PlayerObj
            playerList.Push(PlayerObjIP);
            delete PlayerObjIP;
        }
    }

    // Create heartbeat pulse object.
    JSONObject jsonHeartbeat = new JSONObject();
    jsonHeartbeat.SetString("hostname", g_sServerHostname);
    jsonHeartbeat.SetInt("max_slots", g_iMaxPlayers);
    jsonHeartbeat.Set("players", playerList); // ngl, no idea if this will work LOL
    jsonHeartbeat.SetString("operating_system", g_sServerOS);
    jsonHeartbeat.SetString("mod", g_sMod);
    jsonHeartbeat.SetString("map", g_sMap);
    jsonHeartbeat.SetBool("locked", g_bServerLocked);
    jsonHeartbeat.SetBool("include_other_servers", g_cvAcceptGlobalBans.BoolValue);

    // POST
    httpClient.Post(requestURL, jsonHeartbeat, OnHeartbeatPulse);
    if (g_cvDebug.BoolValue)
    {
    	char sData[2048];
    	jsonHeartbeat.ToString(sData, sizeof(sData), JSON_INDENT(4));
    	DebugLog("Sending API_Heartbeat with the body: %s", sData);
    }

    // Clean up.
    delete jsonHeartbeat;
    delete playerList;
}

void OnHeartbeatPulse(HTTPResponse response, any value) // Callback for heartbeat pulse.
{
    if (response.Status != HTTPStatus_OK)
    {
        char HTTPLocation[128];
        response.GetHeader("Location", HTTPLocation, sizeof(HTTPLocation));
        ErrorLog("FATAL ERROR >> Failed to POST Heartbeat Pulse:");
        ErrorLog("---> ENDPOINT = /gs/heartbeat");
        ErrorLog("---> HTTP Status = %d", response.Status);
        return;
    }

    // TO-DO: Whatever needs to be done after heartbeat pulse has been sent.
    if (g_cvDebug.BoolValue)
    {
    	DebugLog("DEBUG >> 200 - Successfully sent heartbeat pulse.");
    	char sData[2048];
    	response.Data.ToString(sData, sizeof(sData), JSON_INDENT(4));
    	DebugLog("Response from API_Heartbeat: %s", sData);
    }
    
//    JSONArray arr = view_as<JSONArray>(response.Data);
//    JSONObject obj = view_as<JSONObject>(arr.Get(0));
//    CheckInfractionsReply cir = view_as<CheckInfractionsReply>(obj.Get("check"));
//    CInfractionSummary cis = view_as<CInfractionSummary>(cir.VoiceBlock);
//    
//    if (cis == null)
//    	PrintToChatAll("CIS = null");
//    else
//    {
//    	PrintToChatAll("CIS != null");
//    	char sReason[64];
//    	cis.GetReason(sReason, sizeof(sReason));
//    	PrintToChatAll(sReason);
//    }
    
    // Do something with the info:
}

/***************************************
 * Checking Infractions API
***************************************/
 void API_CheckInfractions(int client)
 {
    if (!IsValidClient(client))
        return;
        
    char requestURL[512];
    Format(requestURL, sizeof(requestURL), "infractions/check?gs_service=steam&gs_id={SteamID64}&ip={PlayerIP}");
    
    char sSteamID64[64], sPlayerIP[20];
    GetClientAuthId(client, AuthId_SteamID64, sSteamID64, sizeof(sSteamID64), true);
    GetClientIP(client, sPlayerIP, sizeof(sPlayerIP), true);
    
    ReplaceString(requestURL, sizeof(requestURL), "{SteamID64}", sSteamID64);
    ReplaceString(requestURL, sizeof(requestURL), "{PlayerIP}", sPlayerIP);
    
    httpClient.Get(requestURL, OnCheckInfractionsCallback, GetClientUserId(client));
 }
 
 void OnCheckInfractionsCallback(HTTPResponse response, any data)
 {
    int client = GetClientOfUserId(data);
    
    if (!client)
        return;
        
    if (response.Status != HTTPStatus_OK)
    {
        ErrorLog("FATAL ERROR >> Failed to GET Infractions Check data:");
        ErrorLog("---> ENDPOINT = /infractions/check");
        ErrorLog("---> HTTP Status = %d", response.Status);
        return;
    }
    
    if (response.Data == null)
    {
        ErrorLog("FATAL ERROR >> Empty response recieved:");
        ErrorLog("---> ENDPOINT = /infractions/check");
        ErrorLog("---> HTTP Status = %d", response.Status);
        return;
    }
    
    CheckInfractionsReply infractionsReply = view_as<CheckInfractionsReply>(response.Data);
    
    /****************************
    * Get all the relevant data:
    ****************************/
    
    // Bans - Check bans first and kick them if they have an active ban.
    if (!infractionsReply.IsPunishmentNull(view_as<CInfractionSummary>(infractionsReply.Ban)))
    {
        int iClientExpiration = infractionsReply.GetExpiration(view_as<CInfractionSummary>(infractionsReply.Ban));
        
        // Additional check to determine if the client has a ban on record, 0 equals a permanent ban:
        if (iClientExpiration > GetTime() || iClientExpiration == 0)
        {
            char sReason[256], sAdminName[256], sExpirationTime[64], sDisconnectReason[256];
            
            infractionsReply.GetReason(view_as<CInfractionSummary>(infractionsReply.Ban), sReason, sizeof(sReason));
            infractionsReply.GetAdminName(view_as<CInfractionSummary>(infractionsReply.Ban), sAdminName, sizeof(sAdminName));
            
            FormatSeconds(iClientExpiration - GetTime(), sExpirationTime, sizeof(sExpirationTime));
            Format(sDisconnectReason, sizeof(sDisconnectReason), "%T\n\nADMIN: %s\nREASON: %s\nTIME LEFT: %s", "Banned Player Text", LANG_SERVER, sAdminName, sReason, iClientExpiration != 0 ? sExpirationTime : "PERMANENT");
            
            if (g_cvDebug.BoolValue)
                DebugLog("[GFLBans] Rejected client %N due to a ban: %s", client, sDisconnectReason);
            
            KickClient(client, sDisconnectReason);
        }
    }
    
    // Voice Blocks
    if (!infractionsReply.IsPunishmentNull(view_as<CInfractionSummary>(infractionsReply.VoiceBlock)))
    {
        int iClientExpiration = infractionsReply.GetExpiration(view_as<CInfractionSummary>(infractionsReply.VoiceBlock));
        
        if (iClientExpiration > GetTime() || iClientExpiration == 0)
        {
            char sReason[256], sAdminName[256];
            
            infractionsReply.GetReason(view_as<CInfractionSummary>(infractionsReply.VoiceBlock), sReason, sizeof(sReason));
            infractionsReply.GetAdminName(view_as<CInfractionSummary>(infractionsReply.VoiceBlock), sAdminName, sizeof(sAdminName));
            PerformMute(client, iClientExpiration != 0 ? iClientExpiration - GetTime() : 0, true, sReason, sAdminName);
            
            PrintToChat(client, "%s%t", PREFIX, "Muted On Connect");
        }
    }
    
    // Chat Blocks
    if (!infractionsReply.IsPunishmentNull(view_as<CInfractionSummary>(infractionsReply.ChatBlock)))
    {
        int iClientExpiration = infractionsReply.GetExpiration(view_as<CInfractionSummary>(infractionsReply.ChatBlock));
        
        if (iClientExpiration > GetTime() || iClientExpiration == 0)
        {
            char sReason[256], sAdminName[256];
            
            infractionsReply.GetReason(view_as<CInfractionSummary>(infractionsReply.VoiceBlock), sReason, sizeof(sReason));
            infractionsReply.GetAdminName(view_as<CInfractionSummary>(infractionsReply.VoiceBlock), sAdminName, sizeof(sAdminName));
            PerformGag(client, iClientExpiration != 0 ? iClientExpiration - GetTime() : 0, true, sReason, sAdminName);
            
            PrintToChat(client, "%s%t", PREFIX, "Gagged On Connect");
        }
    } 
    
    // Cleanup.
    delete infractionsReply;
 }


/***************************************
 * Create Infractions API
***************************************/
void API_CreateInfraction(int iClient, int iTarget, int iLength, const char[] sReason, PunishmentsTemplate iPunishmentFlags, CreateInfraction infraction)
{
    char requestURL[512];
    Format(requestURL, sizeof(requestURL), "infractions/");
    
    if (g_cvDebug.BoolValue)
    {
        char sData[2048];
        infraction.ToString(sData, sizeof(sData), JSON_INDENT(4));
        DebugLog("API_CreateInfraction %s", sData);
    }
    
    DataPack dp = new DataPack();
    dp.WriteCell(iClient);
    dp.WriteCell(iTarget);
    dp.WriteCell(iLength);
    dp.WriteString(sReason);
    dp.WriteCell(iPunishmentFlags);
    dp.Reset();
    
    httpClient.Post(requestURL, infraction, OnCreateInfractionsCallback, dp);
}

void OnCreateInfractionsCallback(HTTPResponse response, any data, const char[] sError)
{
    DataPack dp = view_as<DataPack>(data);
    int iClient = dp.ReadCell();
    int iTarget = dp.ReadCell();
    int iLength = dp.ReadCell();
    
    char sReason[256];
    dp.ReadString(sReason, sizeof(sReason));
    
    int iPunishmentFlags = dp.ReadCell();
    
    char sAdminName[64];
    if (iClient)
        GetClientName(iClient, sAdminName, sizeof(sAdminName));
    else
        FormatEx(sAdminName, sizeof(sAdminName), "CONSOLE");
    
    char sTargetName[64];
    GetClientName(iTarget, sTargetName, sizeof(sTargetName));
    
    delete dp;
    
    if (response.Status == HTTPStatus_Forbidden)
    {
        JSONObject APIreply = view_as<JSONObject>(response.Data);
        char sBuffer[128];
        APIreply.GetString("detail", sBuffer, sizeof(sBuffer));
        
        ErrorLog("FATAL ERROR >> Failed to POST CreateInfractions:");
        ErrorLog("---> ENDPOINT = /infractions/");
        ErrorLog("---> HTTP Status = %d", response.Status);
        ErrorLog("---> Detail = %s", sBuffer);
        
        PrintToClientOrServer(iClient, _, "%sUnable to create infraction. Detail: %s", PREFIX, sBuffer);
        //PrintToChat(iClient, "%s Unable to create infraction. Detail: %s", PREFIX, sBuffer);
        return;
    }
    
    if (response.Status != HTTPStatus_OK)
    {
        ErrorLog("FATAL ERROR >> Failed to POST CreateInfractions:");
        ErrorLog("---> ENDPOINT = /infractions/");
        ErrorLog("---> HTTP Status = %d", response.Status);
        
        PrintToClientOrServer(iClient, _, "%s%t", PREFIX, "API Create Infraction Failure", response.Status);
        //ReplyToCommand(iClient, "%s %t", PREFIX, "API Create Infraction Failure", response.Status);
        return;
    }
    
    if (response.Data == null)
    {
        ErrorLog("FATAL ERROR >> Empty response recieved:");
        ErrorLog("---> ENDPOINT = /infractions/");
        ErrorLog("---> HTTP Status = %d", response.Status);
        
        PrintToClientOrServer(iClient, _, "%sSomething went wrong with the API, please contact a higher up...", PREFIX);
        //ReplyToCommand(iClient, "%s Something went wrong with the API, please contact a higher up...", PREFIX);
        return;
    }
    
//    switch (ePunishment)
//    {
//        case PUNISHMENT_VOICE_BLOCK:
//        {
//            
//        }
//        case PUNISHMENT_CHAT_BLOCK:
//        {
//            
//        }
//        case PUNISHMENT_BAN:
//        {
//            if (!iLength)
//                ShowActivityEx(iClient, PREFIX, "%t", "PermBanned Player", sTargetName, sReason);
//            else
//                ShowActivityEx(iClient, PREFIX, "%t", "Banned Player", iTarget, iLength, sReason);
//                
//            LogAction(iClient, iTarget, "%t", "Ban Log", iClient, iTarget, iLength, sReason);
//            
//            if (IsValidClient(iTarget))
//            {
//                char sDisconnectReason[256], sExpirationTime[64];
//                FormatSeconds(iLength * 60, sExpirationTime, sizeof(sExpirationTime));
//                
//                Format(sDisconnectReason, sizeof(sDisconnectReason), "%T\n\nADMIN: %s\nREASON: %s\nTIME LEFT: %s", "Banned Player Text", LANG_SERVER, sAdminName, sReason, iLength != 0 ? sExpirationTime : "PERMANENT");
//                KickClient(iTarget, sDisconnectReason);
//            }
//        }
//        case PUNISHMENT_ADMIN_CHAT_BLOCK:
//        {
//            
//        }
//        case PUNISHMENT_CALL_ADMIN_BLOCK:
//        {
//            
//        }
//    }

    int iPunishmentFlagsTemp = iPunishmentFlags;
    // The first check is to determine whether it is a silence:
    if ((iPunishmentFlagsTemp & BITS_CHAT_BLOCK) && (iPunishmentFlagsTemp & BITS_VOICE_BLOCK))
    {
        PerformMute(iTarget, iLength, _, sReason, sAdminName);
        PerformGag(iTarget, iLength, _, sReason, sAdminName);
        
        // Remove bits to prevent below ifs from firing:
        iPunishmentFlagsTemp &= ~(BITS_CHAT_BLOCK|BITS_VOICE_BLOCK);
    }
    
    if (iPunishmentFlagsTemp & BITS_CHAT_BLOCK)
    {
        PerformGag(iTarget, iLength, _, sReason, sAdminName);
    }
    
    if (iPunishmentFlagsTemp & BITS_VOICE_BLOCK)
    {
        PerformMute(iTarget, iLength, _, sReason, sAdminName);
    }
    
    if (iPunishmentFlagsTemp & BITS_BAN)
    {
        if (!iLength)
            ShowActivity2(iClient, PREFIX, "%t", "PermBanned Player", iTarget, sReason);
        else
            ShowActivity2(iClient, PREFIX, "%t", "Banned Player", iTarget, iLength, sReason);
            
        LogAction(iClient, iTarget, "%t", "Ban Log", iClient, iTarget, iLength, sReason);
        
        if (IsValidClient(iTarget))
        {
            char sDisconnectReason[256], sExpirationTime[64];
            FormatSeconds(iLength * 60, sExpirationTime, sizeof(sExpirationTime));
            
            Format(sDisconnectReason, sizeof(sDisconnectReason), "%T\n\nADMIN: %s\nREASON: %s\nTIME LEFT: %s", "Banned Player Text", LANG_SERVER, sAdminName, sReason, iLength != 0 ? sExpirationTime : "PERMANENT");
            KickClient(iTarget, sDisconnectReason);
        }
    }
    
    if (iPunishmentFlagsTemp & BITS_ADMIN_CHAT_BLOCK)
    {
        
    }
    
    if (iPunishmentFlagsTemp & BITS_CALL_ADMIN_BLOCK)
    {
        
    }
    
    char sInfractionID[64];
    JSONObject infractionObj = view_as<JSONObject>(response.Data);
    infractionObj.GetString("id", sInfractionID, sizeof(sInfractionID));
    
    Call_StartForward(g_gfOnPunishAdded);
    Call_PushCell(iClient);
    Call_PushCell(iTarget);
    Call_PushCell(iLength);
    Call_PushCell(iPunishmentFlags);
    Call_PushString(sReason);
    Call_PushString(sInfractionID);
    Call_Finish();
}

/***************************************
 * Remove Infractions API
***************************************/
void API_RemoveInfraction(int iClient, int iTarget, const char[] sReason, PunishmentsTemplate iPunishmentFlags, RemoveInfractionsOfPlayer removeInfraction)
{
    char requestURL[512];
    Format(requestURL, sizeof(requestURL), "infractions/remove");
    
    if (g_cvDebug.BoolValue)
    {
        char sData[2048];
        removeInfraction.ToString(sData, sizeof(sData), JSON_INDENT(4));
        DebugLog("API_RemoveInfraction %s", sData);
    }
    
    DataPack dp = new DataPack();
    dp.WriteCell(iClient);
    dp.WriteCell(iTarget);
    dp.WriteString(sReason);
    dp.WriteCell(iPunishmentFlags);
    dp.Reset();
    
    httpClient.Post(requestURL, removeInfraction, OnRemoveInfractionsCallback, dp);
}

void OnRemoveInfractionsCallback(HTTPResponse response, any data, const char[] sError)
{
    DataPack dp = view_as<DataPack>(data);
    int iClient = dp.ReadCell();
    int iTarget = dp.ReadCell();
    
    char sReason[256];
    dp.ReadString(sReason, sizeof(sReason));
    
    int iPunishmentFlags = dp.ReadCell();
    
    char sAdminName[64];
    if (iClient)
        GetClientName(iClient, sAdminName, sizeof(sAdminName));
    else
        FormatEx(sAdminName, sizeof(sAdminName), "CONSOLE");
    
    char sTargetName[64];
    GetClientName(iTarget, sTargetName, sizeof(sTargetName));
    
    delete dp;
    
    if (response.Status != HTTPStatus_OK)
    {
        ErrorLog("FATAL ERROR >> Failed to POST RemoveInfractions:");
        ErrorLog("---> ENDPOINT = /infractions/remove");
        ErrorLog("---> HTTP Status = %d", response.Status);
        
        PrintToClientOrServer(iClient, _, "%s%t", PREFIX, "API Remove Infraction Failure", response.Status);
        //ReplyToCommand(iClient, "%s %d", PREFIX, response.Status);
        return;
    }
    
    if (response.Data == null)
    {
        ErrorLog("FATAL ERROR >> Empty response recieved:");
        ErrorLog("---> ENDPOINT = /infractions/remove");
        ErrorLog("---> HTTP Status = %d", response.Status);
        
        PrintToClientOrServer(iClient, _, "%sSomething went wrong with the API, please contact a higher up...", PREFIX);
        //ReplyToCommand(iClient, "%s Something went wrong with the API, please contact a higher up...", PREFIX);
        return;
    }
    
    int iPunishmentFlagsTemp = iPunishmentFlags;
    if ((iPunishmentFlagsTemp & BITS_CHAT_BLOCK) && (iPunishmentFlagsTemp & BITS_VOICE_BLOCK))
    {
        PerformUnmute(iTarget);
        PerformUngag(iTarget);
        
        // Remove bits to prevent below ifs from firing:
        iPunishmentFlagsTemp &= ~(BITS_CHAT_BLOCK|BITS_VOICE_BLOCK);
    }
    
    if (iPunishmentFlagsTemp & BITS_CHAT_BLOCK)
        PerformUngag(iTarget);
    
    if (iPunishmentFlagsTemp & BITS_VOICE_BLOCK)
        PerformUnmute(iTarget);
    
    Call_StartForward(g_gfOnPunishRemoved);
    Call_PushCell(iClient);
    Call_PushCell(iTarget);
    Call_PushCell(iPunishmentFlags);
    Call_PushString(sReason);
    Call_Finish();
}

/***************************************
 * Get Infractions Count API
***************************************/
void API_GetPlayerStats(int iClient, int iReplyTarget = -1)
{
    
}