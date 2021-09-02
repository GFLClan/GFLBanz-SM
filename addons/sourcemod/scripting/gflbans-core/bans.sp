// Register ban commands:
void RegisterBanCommands()
{
    RegAdminCmd("sm_ban", Command_Ban, ADMFLAG_BAN, "sm_ban <#userid|name> <minutes|0> [reason]");
}

// Ban Commands go here:
public Action Command_Ban(int iClient, int iArgs)
{
    if (iArgs < 3)
    {
        ReplyToCommand(iClient, "%sUsage: sm_ban <#userid|name> <time|0> [reason]", PREFIX);
        return Plugin_Handled;
    }
    
    char sBuffer[64];
    
    // Get the target:
    GetCmdArg(1, sBuffer, sizeof(sBuffer));
    int iTarget = FindTarget(iClient, sBuffer, true, true);
    
    if (iTarget == -1 || !IsValidClient(iTarget))
        return Plugin_Handled;
    
    // Get the time:
    GetCmdArg(2, sBuffer, sizeof(sBuffer));
    int iBanTime = StringToInt(sBuffer);
    
    if (!iBanTime && iClient && !(CheckCommandAccess(iClient, "sm_ban", ADMFLAG_UNBAN | ADMFLAG_ROOT)))
    {
        ReplyToCommand(iClient, "%s%t", PREFIX, "InsufficientPermBanPerms");
        return Plugin_Handled;
    }
    
    // Get the reason:
    char sReason[128];
    GetCmdArg(3, sReason, sizeof(sReason));
    for (int i = 4; i <= iArgs; i++)
    {
        GetCmdArg(i, sBuffer, sizeof(sBuffer));
        Format(sReason, sizeof(sReason), "%s %s", sReason, sBuffer);
    }
    
    SetupInfraction(iClient, iTarget, iBanTime, sReason, P_BAN);
    return Plugin_Handled;
}