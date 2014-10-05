////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - _slave cuffs                               //
//                            version 3.980                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////
integer g_nCmdChannel = -190890; // command channel
integer g_nCmdHandle = 0; // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC; // offset to be used to make sure we do not interfere with other items using the same technique for
key g_keyWearer = NULL_KEY; // key of the owner/wearer
integer LM_CUFF_CMD = -551001;
integer g_nShowScript = FALSE;

list lstCuffNames=["Not","chest","skull","lshoulder","rshoulder","lhand","rhand","lfoot","rfoot","spine","ocbelt","mouth","chin","lear","rear","leye","reye","nose","ruac","rlac","luac","llac","rhip","rulc","rllc","lhip","lulc","lllc","ocbelt","rpec","lpec","HUD Center 2","HUD Top Right","HUD Top","HUD Top Left","HUD Center","HUD Bottom Left","HUD Bottom","HUD Bottom Right"]; // list of attachment point to resolcve the names for the cuffs system, addition cuff chain point will be transamitted via LMs
// attention, belt is twice in the list, once for stomach. , once for pelvis as there are version for both points
string  g_szAllowedCommadToken = "rlac"; // only accept commands from this token adress
list g_lstModTokens = []; // valid token for this module
integer CMD_UNKNOWN = -1; // unknown command - don't handle
integer CMD_CHAT = 0; // chat cmd - check what should happen with it
integer CMD_EXTERNAL = 1; // external cmd - check what should happen with it
integer CMD_MODULE = 2; // cmd for this module
integer g_nCmdType  = CMD_UNKNOWN;

string  g_szReceiver = "";
string  g_szSender = "";
integer g_nLockGuardChannel = -9119;

integer nGetOwnerChannel(integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)llGetOwner(),3,8)) + g_nCmdChannelOffset;
    if (chan>0)
        chan=chan*(-1);
    if (chan > -10000)
        chan -= 30000;
    return chan;
}

integer IsAllowed( key keyID )
{
    integer nAllow    = FALSE;
    if ( llGetOwnerKey(keyID) == g_keyWearer )
        nAllow = TRUE;
    return nAllow;
}

SendCmd( string szSendTo, string szCmd, key keyID )
{
    llRegionSay(g_nCmdChannel, llList2String(g_lstModTokens,0) + "|" + szSendTo + "|" + szCmd + "|" + (string)keyID);
}

Init()
{
    g_keyWearer = llGetOwner();
    // get unique channel numbers for the command and cuff channel, cuff channel wil be used for LG chains of cuffs as well
    g_nCmdChannel = nGetOwnerChannel(g_nCmdChannelOffset);
    llListenRemove(g_nCmdHandle);
    g_nCmdHandle = llListen(g_nCmdChannel + 1, "", NULL_KEY, "");
    g_lstModTokens = (list)llList2String(lstCuffNames,llGetAttached()); // get name of the cuff from the attachment point, this is absolutly needed for the system to work, other chain point wil be received via LMs
}

string CheckCmd( key keyID, string szMsg )
{
    list    lstParsed    = llParseString2List( szMsg, [ "|" ], [] );
    string    szCmd        = szMsg;
    // first part should be sender token
    // second part the receiver token
    // third part = command
    if ( llGetListLength(lstParsed) > 2 )
    { // check the sender of the command occ,rwc,...
        g_szSender            = llList2String(lstParsed,0);
        g_nCmdType        = CMD_UNKNOWN;
        if ( g_szSender==g_szAllowedCommadToken ) // only accept command from the master cuff
        {
            g_nCmdType    = CMD_EXTERNAL;
            // cap and store the receiver
            g_szReceiver = llList2String(lstParsed,1);
            // we are the receiver
            if ( (llListFindList(g_lstModTokens,[g_szReceiver]) != -1) || g_szReceiver == "*" )
            {// set cmd return to the rest of the command string
                szCmd = llList2String(lstParsed,2);
                g_nCmdType = CMD_MODULE;
            }
        }
    }
    lstParsed = [];
    return szCmd;
}

ParseCmdString( key keyID, string szMsg )
{
    list lstParsed = llParseString2List( szMsg, [ "~" ], [] );
    integer nCnt = llGetListLength(lstParsed);
    integer i = 0;
    for (i = 0; i < nCnt; i++ )
        ParseSingleCmd(keyID, llList2String(lstParsed, i));
    lstParsed = [];
}

ParseSingleCmd( key keyID, string szMsg )
{
    list lstParsed = llParseString2List( szMsg, [ "=" ], [] );
    string szCmd = llList2String(lstParsed,0);
    string szValue = llList2String(lstParsed,1);
    if ( szCmd == "chain" )
    {
        if ( llGetListLength(lstParsed) == 4 )
        {
            if ( llGetKey() != keyID )
                llMessageLinked( LINK_SET, LM_CUFF_CMD, szMsg, llGetKey() );
        }
    }
    else
        llMessageLinked(LINK_SET, LM_CUFF_CMD, szMsg, keyID);
    lstParsed = [];
}

default
{
    state_entry()
    {
        Init();
        llListen(g_nLockGuardChannel,"","","");// listen to LockGuard requests
    }

    listen(integer nChannel, string szName, key keyID, string szMsg)
    {
        szMsg = llStringTrim(szMsg, STRING_TRIM);
        // commands sent on cmd channel
        if ( nChannel == g_nCmdChannel+ 1 )
        {
            if ( IsAllowed(keyID) )
            {
                if (llGetSubString(szMsg,0,8)=="lockguard")
                    llMessageLinked(LINK_SET, -9119, szMsg, keyID);
                else
                {
                    // check if external or maybe for this module
                    string szCmd = CheckCmd( keyID, szMsg );
                    if ( g_nCmdType == CMD_MODULE )
                        ParseCmdString(keyID, szCmd);
                }
            }
        } 
        else if ( nChannel == g_nLockGuardChannel)
            llMessageLinked(LINK_SET,g_nLockGuardChannel,szMsg,NULL_KEY);// LG message received, forward it to the other prims
    }

    on_rez(integer nParam)
    {
        llResetScript();
    }
}