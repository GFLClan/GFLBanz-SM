methodmap PlayerObjSimple < JSONObject
{
    public PlayerObjSimple() { return view_as<PlayerObjSimple>(new JSONObject()); }
    
    public void SetService(const char[] buffer)
    {
        this.SetString("gs_service", buffer);
    }
    
    public void SetID64(int client)
    {
        char sPlayerID64[64];
        GetClientAuthId(client, AuthId_SteamID64, sPlayerID64, sizeof(sPlayerID64), true);
        this.SetString("gs_id", sPlayerID64);
    }
    
    public void SetIP(int client)
    {
        char sPlayerIP[32];
        GetClientIP(client, sPlayerIP, sizeof(sPlayerIP), true);
        this.SetString("ip", sPlayerIP);
    }
}

methodmap PlayerObjNoIp < JSONObject
{
    public PlayerObjNoIp() { return view_as<PlayerObjNoIp>(new JSONObject()); }
    
    public void GetService(char[] buffer, int maxlength)
    {
    	this.GetString("gs_service", buffer, maxlength);
    }
    
    public void SetService(const char[] buffer)
    {
    	this.SetString("gs_service", buffer);
    }
    
    public void GetID64(char[] buffer, int maxlength)
    {
    	this.GetString("gs_id", buffer, maxlength);
    }
    
    public void SetID64(int client)
    {
    	char sPlayerID64[64];
    	GetClientAuthId(client, AuthId_SteamID64, sPlayerID64, sizeof(sPlayerID64), true);
    	this.SetString("gs_id", sPlayerID64);
    }
}

methodmap PlayerObjIPOptional < PlayerObjNoIp
{
    public PlayerObjIPOptional() { return view_as<PlayerObjIPOptional>(new JSONObject()); }
    
    public void GetIP(char[] buffer, int maxlength)
    {
        this.GetString("ip", buffer, maxlength);
    }
    
    public void SetIP(int client)
    {
        char sPlayerIP[32];
        GetClientIP(client, sPlayerIP, sizeof(sPlayerIP), true);
        this.SetString("ip", sPlayerIP);
    }
}

methodmap CInfractionSummary < JSONObject
{
    property int Expiration
    {
        public get()
        {
            // In the current API, if the key is not present, it means the length is permanent
            if (!this.HasKey("expiration"))
                return 0;
                
            if (this.IsNull("expiration"))
                return 0; // 0 means permanent length.
            	
            return this.GetInt("expiration");
        }
    }
	
    public void GetReason(char[] buffer, int maxlength)
    {
        if (!this.HasKey("reason"))
            return;
            
        this.GetString("reason", buffer, maxlength);
    }
	
    public void GetAdminName(char[] buffer, int maxlength)
    {
        if (!this.HasKey("admin_name"))
            return;
            
        this.GetString("admin_name", buffer, maxlength);
    }
}

methodmap CheckInfractionsReply < JSONObject
{
    public CheckInfractionsReply() { return view_as<CheckInfractionsReply>(new JSONObject()); }
	
    property CInfractionSummary VoiceBlock
    {
        public get()
        {
            if (!this.HasKey("voice_block"))
                return null;
            
            if (this.IsNull("voice_block"))
            	return null;
            	
            return view_as<CInfractionSummary>(this.Get("voice_block"));
        }
    }
	
    property CInfractionSummary ChatBlock
    {
        public get()
        {
            if (!this.HasKey("chat_block"))
                return null;
                
            if (this.IsNull("chat_block"))
                return null;
            	
            return view_as<CInfractionSummary>(this.Get("chat_block"));
        }
    }
	
    property CInfractionSummary Ban
    {
        public get()
        {
            if (!this.HasKey("ban"))
                return null;
                
            if (this.IsNull("ban"))
                return null;
            	
            return view_as<CInfractionSummary>(this.Get("ban"));
        }
    }
	
    property CInfractionSummary AdminChatBlock
    {
        public get()
        {
            if (!this.HasKey("admin_chat_block"))
                return null;
                
            if (this.IsNull("admin_chat_block"))
                return null;
            	
            return view_as<CInfractionSummary>(this.Get("admin_chat_block"));
        }
    }
	
	property CInfractionSummary CallAdminBlock
	{
		public get()
		{
            if (!this.HasKey("call_admin_block"))
                return null;
		        
            if (this.IsNull("call_admin_block"))
				return null;
				
            return view_as<CInfractionSummary>(this.Get("call_admin_block"));
		}
	}
	
	public bool IsPunishmentNull(CInfractionSummary punishment)
	{
	    if (punishment == null)
	        return true;
	    else
	    {
	        delete punishment;
	        return false;
	    }
	}
	
	public int GetExpiration(CInfractionSummary punishment)
	{
	    if (punishment == null) 
	        return -1; // -1 means no punishment found.
	        
	    int iExpiration = punishment.Expiration;
	    delete punishment;
	    
	    return iExpiration;
	}
	
	public void GetReason(CInfractionSummary punishment, char[] reason, int maxlength)
	{
	    if (punishment == null)
	        return; // Means no punishment found.
	        
	    punishment.GetReason(reason, maxlength);
	    delete punishment;
	}
	
	public void GetAdminName(CInfractionSummary punishment, char[] reason, int maxlength)
	{
	    if (punishment == null)
	        return; // Means no punishment found.
	        
	    punishment.GetAdminName(reason, maxlength);
	    delete punishment;
	}
}

methodmap CreateInfraction < JSONObject
{
    public CreateInfraction() { return view_as<CreateInfraction>(new JSONObject()); }
    
    property int Duration 
    {
        public set(int duration)
        {
            this.SetInt("duration", duration * 60);
        }
    }
    
    public void SetPlayer(PlayerObjSimple playerObjSimple)
    {
        this.Set("player", playerObjSimple);
    }
    
    // We are going to use Initiator -> gs_admin in our admin field:
    public void SetAdmin(PlayerObjNoIp playerObjNoIp)
    {
        JSONObject gsAdmin = new JSONObject();
        gsAdmin.Set("gs_admin", playerObjNoIp);
        
        this.Set("admin", gsAdmin);
        
        delete gsAdmin;
    }
    
    public void SetReason(const char[] buffer)
    {
        this.SetString("reason", buffer);
    }
    
    public void SetPunishment(PunishmentsTemplate iPunishmentFlags)
    {
//        char sBuffer[32];
//        switch(punishment)
//        {
//            case PUNISHMENT_VOICE_BLOCK:
//            {
//                Format(sBuffer, sizeof(sBuffer), "voice_block");
//            }
//            case PUNISHMENT_CHAT_BLOCK:
//            {
//                Format(sBuffer, sizeof(sBuffer), "chat_block");
//            }
//            case PUNISHMENT_BAN:
//            {
//                Format(sBuffer, sizeof(sBuffer), "ban");
//            }
//            case PUNISHMENT_ADMIN_CHAT_BLOCK:
//            {
//                Format(sBuffer, sizeof(sBuffer), "admin_chat_block");
//            }
//            case PUNISHMENT_CALL_ADMIN_BLOCK:
//            {
//                Format(sBuffer, sizeof(sBuffer), "call_admin_block");
//            }
//        }
//        
//        JSONArray punishmentArray = new JSONArray();
//        punishmentArray.PushString(sBuffer);

        JSONArray punishmentArray = new JSONArray();
        
        if (view_as<int>(iPunishmentFlags) & BITS_VOICE_BLOCK)
            punishmentArray.PushString("voice_block");
            
        if (view_as<int>(iPunishmentFlags) & BITS_CHAT_BLOCK)
            punishmentArray.PushString("chat_block");
        
        if (view_as<int>(iPunishmentFlags) & BITS_BAN)
            punishmentArray.PushString("ban");
            
        if (view_as<int>(iPunishmentFlags) & BITS_ADMIN_CHAT_BLOCK)
            punishmentArray.PushString("admin_chat_block");
            
        if (view_as<int>(iPunishmentFlags) & BITS_CALL_ADMIN_BLOCK)
            punishmentArray.PushString("call_admin_block");

        this.Set("punishments", punishmentArray);
        
        delete punishmentArray;
    }
    
    public void SetScope(InfractionScope scope)
    {
        char sBuffer[32];
        switch(scope)
        {
            case SCOPE_GLOBAL:
            {
                Format(sBuffer, sizeof(sBuffer), "global");
            }
            case SCOPE_SERVER:
            {
                Format(sBuffer, sizeof(sBuffer), "server");
            }
            default:
            {
                Format(sBuffer, sizeof(sBuffer), "server");
            }
        }
        
        this.SetString("scope", sBuffer);
    }
    
    property bool SessionOnly
    {
        public set(bool sessionOnly)
        {
            this.SetBool("session", sessionOnly);
        }
    }
    
    property bool OnlineOnly
    {
        public set(bool onlineOnly)
        {
            this.SetBool("dec_online_only", onlineOnly);
        }
    }
}

methodmap InfractionStatisticReply < JSONObject
{
    public InfractionStatisticReply() { return view_as<InfractionStatisticReply>(new JSONObject()); }
    
    property int VoiceBlockCount
    {
        public get()
        {
            return this.GetInt("voice_block_count");
        }
    }
    
    property int TextBlockCount
    {
        public get()
        {
            return this.GetInt("text_block_count");
        }
    }
    
    property int BanCount
    {
        public get()
        {
            return this.GetInt("ban_count");
        }
    }
    
    property int AdminChatBlockCount
    {
        public get()
        {
            return this.GetInt("admin_chat_block_count");
        }
    }
    
    property int CallAdminBlockCount
    {
        public get()
        {
            return this.GetInt("call_admin_block_count");
        }
    }
    
    property int WarningsCount
    {
        public get()
        {
            return this.GetInt("warnings_count");
        }
    }
}

methodmap RemoveInfractionsOfPlayer < JSONObject
{
    public RemoveInfractionsOfPlayer() { return view_as<RemoveInfractionsOfPlayer>(new JSONObject()); }
    
    public void SetPlayer(PlayerObjNoIp playerObjNoIp)
    {
        this.Set("player", playerObjNoIp);
    }
    
    public void SetReason(const char[] buffer)
    {
        this.SetString("remove_reason", buffer);
    }
    
    // We are going to use Initiator -> gs_admin in our admin field:
    public void SetAdmin(PlayerObjNoIp playerObjNoIp)
    {
        JSONObject gsAdmin = new JSONObject();
        gsAdmin.Set("gs_admin", playerObjNoIp);
        
        this.Set("admin", gsAdmin);
        
        delete gsAdmin;
    }
    
    property bool SetIncludeOtherServers
    {
        public set(bool includeOtherServers)
        {
            this.SetBool("include_other_servers", includeOtherServers);
        }
    }
    
    public void SetRestrictTypes(PunishmentsTemplate iPunishmentFlags)
    {
        JSONArray restrictArray = new JSONArray();
        
        if (view_as<int>(iPunishmentFlags) & BITS_VOICE_BLOCK)
            restrictArray.PushString("voice_block");
            
        if (view_as<int>(iPunishmentFlags) & BITS_CHAT_BLOCK)
            restrictArray.PushString("chat_block");
        
        if (view_as<int>(iPunishmentFlags) & BITS_BAN)
            restrictArray.PushString("ban");
            
        if (view_as<int>(iPunishmentFlags) & BITS_ADMIN_CHAT_BLOCK)
            restrictArray.PushString("admin_chat_block");
            
        if (view_as<int>(iPunishmentFlags) & BITS_CALL_ADMIN_BLOCK)
            restrictArray.PushString("call_admin_block");

        this.Set("restrict_types", restrictArray);
        
        delete restrictArray;
    }
}
