enum InfractionScope {
    SCOPE_GLOBAL = 1,
    SCOPE_SERVER
}

#define TYPE_MUTE		1
#define TYPE_UNMUTE		2
#define TYPE_GAG		3
#define TYPE_UNGAG		4
#define TYPE_SILENCE	5
#define TYPE_UNSILENCE	6

#define BITS_VOICE_BLOCK        (1 << 0)    // 1
#define BITS_CHAT_BLOCK         (1 << 1)    // 2
#define BITS_BAN                (1 << 2)    // 4
#define BITS_ADMIN_CHAT_BLOCK   (1 << 3)    // 8
#define BITS_CALL_ADMIN_BLOCK   (1 << 4)    // 16

enum PunishmentsTemplate
{
    P_VOICE               = 1,
    P_CHAT                = 2,
    P_SILENCE             = 3,
    P_BAN                 = 4,
    P_ADMIN_CHAT_BLOCK    = 8,
    P_CALL_ADMIN_BLOCK    = 16
}

enum PunishmentType
{
    P_NOT = 0,          // Not muted/gagged
    P_SESS,             // Session mute/gag
    P_TIMED,            // Timed mute/gag
    P_PERM              // Permanent mute/gag
}