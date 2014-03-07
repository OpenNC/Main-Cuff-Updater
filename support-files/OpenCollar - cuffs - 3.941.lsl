//Licensed under the GPLv2, with the additional requirement that these scripts remain "full perms" in Second Life. Not supported by OpenCollar at all.
//Collar Cuff Menu

//=============================================================================
//== OpenNC - Command forwarder to listen for commands in OpenCollar
//== receives messages from linkmessages send within the collar
//== sends the needed commands out to the cuffs
//==
//==
//== 2009-01-16 Cleo Collins - 1. draft
//== 2013-12-24 North Glenwalker - rebuild for 3.940 code
//   NOT SUPPORTED BY OpenCollar AT ALL
//==
//=============================================================================

integer    g_nCmdHandle    = 0;            // command listen handler
integer g_nCmdChannelOffset = 0xCC0CC;       // offset to be used to make sure we do not interfere with other items using the same technique for
integer CUFF_CHANNEL; //custom channel to send to cuffs (our channel +1)
//set of strings to hold values when chopping up lines
string str0="";
string str1="";
string str2="";
string str3="";
string str4="";
string name="";
key kID;
integer g_nRecolor=FALSE; // only send color values on demand
integer g_nRetexture=FALSE; // only send texture values on demand
float g_fMinVersion=3.930; //whats the minimum version of collar code this will work with
string submenu = "Cuffs";
string parentmenu = "AddOns";
key g_keyDialogID;
list localbuttons = ["Cuff Menu", "Show/Hide"];
list buttons;
integer g_nLastRLVChange=-1;
list g_lstResetOnOwnerChange=["OpenCollar - auth - 3.","OpenCollar - httpdb - 3.","OpenCollar - settings - 3."]; // scripts to be reseted on ownerchanges to keep system in sync
// chat command for opening the mnu of the cuffs directly
string g_szOpenNCMenuCommand="cmenu";
integer g_nUpdateActive= TRUE;
key wearer;
string g_szScriptIdentifier="OpenCollar - cuffs -"; // for checking if already an older version of theis scrip is in the collar

//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_OBJECT = 506;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer ATTACHMENT_FORWARD = 610;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;


key ShortKey()
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string chars = "0123456789abcdef";
    integer length = 16;
    string out;
    integer n;
    for (n = 0; n < 8; n++)
    {
        integer index = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        out += llGetSubString(chars, index, index);
    }
     
    return (key)(out + "-0000-0000-0000-000000000000");
}

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

integer VersionOK()
{
    // checks if the version of the collar fits the needed version for the plugin
    list params = llParseString2List(llGetObjectDesc(), ["~"], []);
    string name = llList2String(params, 0);
    string version = llList2String(params, 1);
    return TRUE;
}

//===============================================================================
//= parameters   :  integer nOffset        Offset to make sure we use really a unique channel
//=
//= description  : Function which calculates a unique channel number based on the owner key, to reduce lag
//=
//= returns      : Channel number to be used
//===============================================================================
integer nGetOwnerChannel(key wearer,integer nOffset)
{
    integer chan = (integer)("0x"+llGetSubString((string)wearer,2,7)) + nOffset;
    if (chan>0)
    {
        chan=chan*(-1);
    }
    if (chan > -10000)
    {
        chan -= 30000;
    }
    return chan;
}
//===============================================================================
//= parameters   :    string    szMsg   message string received
//=
//= return        :    integer TRUE/FALSE
//=
//= description  :    checks if a string begin with another string
//=
//===============================================================================

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

//===============================================================================
//= parameters   :   none
//=
//= return        :    none
//=
//= description  :    display an error message if more than one plugin of the same version is found
//=
//===============================================================================

DoubleScriptCheck()
{
    integer l=llStringLength(g_szScriptIdentifier)-1;
    string s;
    integer i;
    integer c=0;
    integer m=llGetInventoryNumber(INVENTORY_SCRIPT);
    for(i=0;i<m;i++)
    {
        s=llGetSubString(llGetInventoryName(INVENTORY_SCRIPT,i),0,l);
        if (g_szScriptIdentifier==s)
        {
            c++;
        }
    }
    if (c>1)
    {
        llOwnerSay ("There is more than one version of the Cuffs plugin in your collar. Please make sure you only keep the latest version of this plugin in your collar and delete all other versions.");
    }
}

default
{
    state_entry()
    {
        if (!VersionOK()) state WrongVersion;
        wearer=llGetOwner();//who owns us
        DoubleScriptCheck();//only one copy of me running
        CUFF_CHANNEL = nGetOwnerChannel(wearer,1111);//lets get our channel
        CUFF_CHANNEL = CUFF_CHANNEL++;//and add 1 to it to seperate it from collar channel
        // wait for all scripst to be ready
        llSleep(1.0);
        // any submenu want to register?
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        // include ourselft into parent menu
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }

    on_rez(integer param)
    {
        llResetScript();
    }
    //
    //NG Main block of listen to link messages, and then forward to cuffs is required
    //
    link_message(integer sender, integer num, string str, key id)
    {
        if ((num == COMMAND_OWNER) && (str == "runaway"))
            {
                llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":runaway");
            }

        if (str == "rlvmain_on=1")//RLV on
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":rlvon");  
        }
        else if (str == "rlvmain_on=0")//RLV off
        {
        }

        else if (str=="menu Cuffs")//ask for the cuff menu
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)id + ":cmenu");
        }
        //Lets chop up at "=" to see if we want it
        list lParam = llParseString2List(str, ["="], []);
        integer h = llGetListLength(lParam);
        str1= llList2String(lParam, 0);
        str2= llList2String(lParam, 1);
        if ((str1=="auth_group") && (str2 !=""))
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":setgroup");
        }
        else if (str1=="auth_group")
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":unsetgroup");
        }
        else if ((str1=="auth_openaccess") && (str2 !=""))
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":setopenaccess");
        }
        else if (str1=="auth_openaccess")
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":unsetopenaccess");
        }
        else if (((str1=="auth_owner") | (str1=="auth_secowners") | (str1=="auth_blacklist")) && (str2 !=""))
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":"+ str);
        }
        list lParam2 = llParseString2List(str1, ["_"], []);
        integer g = llGetListLength(lParam2);
        str3= llList2String(lParam2, 0);
        //Lets see if it's color or texture information
        if((str3 == "color") || (str3 == "texture"))
        {
          llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":"+ str); 
        }
        list lParams = llParseString2List(str, ["|"], []);
        integer i = llGetListLength(lParams);
        str0= llList2String(lParams, 0);
        str1= llList2String(lParams, 1);
        //Do we see a show, or hide?
        if (str1 =="Show All")
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":show");
        }
        else if (str1 =="Hide All")
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":hide");
        }
        else if ((str1 ==" OFF") && (num == DIALOG_RESPONSE))//RLV off (bad way of doing RLV off as maybe other " OFF" in the commands
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,str0 + ":rlvoff");
        } 
    }
}

state WrongVersion
{
    state_entry()
    {  
    }
    
    on_rez(integer param)
    {
        llResetScript();
    }
}