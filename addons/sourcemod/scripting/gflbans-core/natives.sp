void CreateNatives()
{
    // ALL NATIVE CREATION GOES HERE.
    
    // To support old plugins using sourcecomms native
    CreateNative("GFLBans_SetClientGag", Native_SetClientGag);
    CreateNative("GFLBans_SetClientMute", Native_SetClientMute);
    CreateNative("GFLBans_GetClientGagType", Native_GetClientGagType);
    CreateNative("GFLBans_GetClientMuteType", Native_GetClientMuteType);
}

public int Native_SetClientGag(Handle hPlugin, int iNumParams)
{
    int iTarget = GetNativeCell(1);
    if (iTarget < 1 || iTarget > MaxClients)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid target index %d", iTarget);
        return false;
    }
    
    if (!IsValidClient(iTarget))
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Target %d is not a valid client", iTarget);
        return false;
    }
    
    bool bGagState = GetNativeCell(2);
    int iLength = GetNativeCell(3);
    bool bSavePunishment = GetNativeCell(4);
    if (!bGagState && bSavePunishment)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Removing punishments from native is not allowed");
        return false;
    }
    
    char sReason[256];
    GetNativeString(5, sReason, sizeof(sReason));
    
    if (bGagState)
    {
        if (g_esPlayerInfo[iTarget].gagType > P_NOT)
            return false;
        
        PerformGag(iTarget, iLength, _, sReason, _);
        if (bSavePunishment && iLength >= 0)
            SetupInfraction(_, iTarget, iLength, sReason, P_CHAT);
    }
    else
    {
        if (g_esPlayerInfo[iTarget].gagType == P_NOT)
            return false;
            
        PerformUngag(iTarget);
    }
    
    return true;
}

public int Native_SetClientMute(Handle hPlugin, int iNumParams)
{
    int iTarget = GetNativeCell(1);
    if (iTarget < 1 || iTarget > MaxClients)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid target index %d", iTarget);
        return false;
    }
    
    if (!IsValidClient(iTarget))
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Target %d is not a valid client", iTarget);
        return false;
    }
    
    bool bMuteState = GetNativeCell(2);
    int iLength = GetNativeCell(3);
    bool bSavePunishment = GetNativeCell(4);
    if (!bMuteState && bSavePunishment)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Removing punishments from native is not allowed");
        return false;
    }
    
    char sReason[256];
    GetNativeString(5, sReason, sizeof(sReason));
    
    if (bMuteState)
    {
        if (g_esPlayerInfo[iTarget].gagType > P_NOT)
            return false;
        
        PerformMute(iTarget, iLength, _, sReason, _);
        if (bSavePunishment && iLength >= 0)
            SetupInfraction(_, iTarget, iLength, sReason, P_VOICE);
    }
    else
    {
        if (g_esPlayerInfo[iTarget].muteType == P_NOT)
            return false;
            
        PerformUnmute(iTarget);
    }
    
    return true;
}

public any Native_GetClientGagType(Handle hPlugin, int iNumParams)
{
    int iTarget = GetNativeCell(1);
    if (iTarget < 1 || iTarget > MaxClients)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid target index %d", iTarget);
        return P_NOT;
    }
    
    if (!IsValidClient(iTarget))
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Target %d is not a valid client", iTarget);
        return P_NOT;
    }
    
    return g_esPlayerInfo[iTarget].gagType;
}

public any Native_GetClientMuteType(Handle hPlugin, int iNumParams)
{
    int iTarget = GetNativeCell(1);
    if (iTarget < 1 || iTarget > MaxClients)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Invalid target index %d", iTarget);
        return P_NOT;
    }
    
    if (!IsValidClient(iTarget))
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Target %d is not a valid client", iTarget);
        return P_NOT;
    }
    
    return g_esPlayerInfo[iTarget].muteType;
}

