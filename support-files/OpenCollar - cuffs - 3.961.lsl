////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenCollar - cuffs - 3.961                          //
//                            version 3.961                                       //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.                                      //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
// Not now supported by OpenCollar at all                                         //
////////////////////////////////////////////////////////////////////////////////////

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
key g_kDialogID;
list localbuttons = ["Cuff Menu", "ReSync"];
//list buttons;
integer g_nLastRLVChange=-1;
list g_lstResetOnOwnerChange=["OpenCollar - auth - 3.","OpenCollar - httpdb - 3.","OpenCollar - settings - 3."]; // scripts to be reseted on ownerchanges to keep system in sync
// chat command for opening the mnu of the cuffs directly
string g_szOpenCuffMenuCommand="cuffmenu";
integer g_nUpdateActive= TRUE;
key wearer;
string g_szScriptIdentifier="OpenCollar - cuffs -"; // for checking if already an older version of theis scrip is in the collar
string TURNON = "Sync  ON";
string TURNOFF = "Sync OFF";
string HIDEON = "Hide Cuffs";
string HIDEOFF = "Show Cuffs";
integer sync;
integer hide = FALSE;
integer wait = FALSE;
//MESSAGE MAP
integer COMMAND_NOAUTH = 0;
integer COMMAND_OWNER = 500;
integer COMMAND_WEARER = 503;
integer COMMAND_OBJECT = 506;
integer COMMAND_SAFEWORD = 510;  // new for safeword
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer MENUNAME_REQUEST = 3000;
integer MENUNAME_RESPONSE = 3001;
integer SUBMENU = 3002;
integer ATTACHMENT_FORWARD = 610;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
string UPMENU = "BACK";
string CTYPE = "collar";

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page)
{
    key id = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`"), id);
    return id;
}

DoMenu(key id)
{
    string prompt = "\n\nCollar to Cuff interface\n";
    list mybuttons = localbuttons;
    if (sync == TRUE)
    {
        mybuttons += TURNOFF;
        prompt += "The Collar will try and update the cuffs.\n";
    }
    else
    {
        mybuttons += TURNON;
        prompt += "The Collar will NOT update the cuffs.\n";
    }
    if (hide == FALSE)
    {
        mybuttons += HIDEON;
        prompt += "The Cuffs are not hidden from this menu.\n";
    }
    else
    {
        mybuttons += HIDEOFF;
        prompt += "The Cuffs ARE hidden from this menu.\n";
    }
    prompt += "Sync must be turned ON to ReSync.\n";
    prompt += "Pick an option.";
    g_kDialogID=Dialog(id, prompt, mybuttons, [UPMENU], 0);
}

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

integer nStartsWith(string szHaystack, string szNeedle) // http://wiki.secondlife.com/wiki/llSubStringIndex
{
    return (llDeleteSubString(szHaystack, llStringLength(szNeedle), -1) == szNeedle);
}

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
        if (wearer != llGetOwner())
        {
            sync = TRUE;   //on new owener set sync to ON
        }
        // wait for all script to be ready
        llSleep(0.6);
        wearer=llGetOwner();//who owns us
        llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "C_Sync", wearer);
        DoubleScriptCheck();//only one copy of me running
        CUFF_CHANNEL = nGetOwnerChannel(wearer,1111);//lets get our channel (same as collar
        CUFF_CHANNEL = ++ CUFF_CHANNEL;//and add 1 to it to seperate it from collar channel
        llMessageLinked(LINK_THIS, MENUNAME_REQUEST, submenu, NULL_KEY);
        llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
    }

    on_rez(integer iParam)
    {
        if (wearer!=llGetOwner())
        {
            llResetScript();//on new owner reset script
        }
    }
    //
    //NG Main block of listen to link messages, and then forward to cuffs is required
    //
    link_message(integer sender, integer num, string str, key id)
    {
        list lParams = llParseString2List(str, ["|"], []);
        str1= llList2String(lParams, 1);
        
        if (num == MENUNAME_REQUEST && str == parentmenu)
        {
            llMessageLinked(LINK_THIS, MENUNAME_RESPONSE, parentmenu + "|" + submenu, NULL_KEY);
        }
        
        if ((num == COMMAND_OWNER) && (str == "runaway"))
        {
            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":runaway");
        }
        else if (str == "menu " + submenu)
        {
            DoMenu(id);
        }
        else if ((str1 ==" LOCK") && (num == DIALOG_RESPONSE))
        {
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_lock=1", NULL_KEY);
        }
        else if ((str1 ==" UNLOCK") && (num == DIALOG_RESPONSE))
        {
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_lock=0", NULL_KEY);
        }
        else if (str == "C_Sync=0")//Sync off
        {
            sync = FALSE;
        }
        else if (str == "C_Sync=1")//Sync on
        {
            sync = TRUE;
        }
        else if ((num >= COMMAND_OWNER)&&(num <= COMMAND_WEARER)) //code to bring up collar menu from cuff
        {//see if this is a command from the cuffs
            list lParam = llParseString2List(str, ["|"], []);
            integer h = llGetListLength(lParam);
            str1= llList2String(lParam, 0);
            key kAv = (key)llList2String(lParam, 1);
            llMessageLinked (LINK_SET, COMMAND_NOAUTH, str1, kAv);
        }
        if (sync == TRUE)//only do this bit if sync is turned on
        {
            if (str == "rlvmain_on=1")//RLV on
            {
                llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":rlvon");  
            }
            else if (str == "rlvmain_on=0")//RLV off
            {
                llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":rlvoff"); //this was commented out????
            }
            else if (str == "C_lock=1")//Lock on
            {
                llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":lock");
            }
            else if (str == "C_lock=0")//Lock off
            {
                llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":unlock");
            }
            else
            {
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
                else if (((str1=="auth_owner") || (str1=="auth_secowners") || (str1=="auth_blacklist")) && (str2 !=""))
                {
                    llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":"+ str);
                }
                else 
                {
                    list lParam2 = llParseString2List(str1, ["_"], []);
                    integer g = llGetListLength(lParam2);
                    str3= llList2String(lParam2, 0);
        
                    //Lets see if it's color or texture information
                    if(str3 == "color")
                    {
                        llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":"+ str); 
                    }
                    else if(str3 == "texture")
                    {
                        if(llGetInventoryType(str2) == INVENTORY_TEXTURE)
                        {    //Texture exist in Prim?  Error evasion.  It may be surplus.
                            key k = llGetInventoryKey(str2);
                            if(k != NULL_KEY) str = str1 + "=" + (string)k;    //Full permission is not NULL_KEY.  If it is not Full permission, then put texture in each Slave-cuffs.
                        }
                        llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":"+ str); 
                    }
                    else
                    {
                        list lParams = llParseString2List(str, ["|"], []);
                        integer i = llGetListLength(lParams);
                        str0= llList2String(lParams, 0);
                        str1= llList2String(lParams, 1);
                        integer iAuth = (integer)llList2String(lParams, 3); // auth level of avatar
                        //Do we see a show, or hide?
                        if ((str1 =="Show Collar") || (str1 =="Show All") || (str =="show"))
                        {
                            llRegionSayTo(wearer,CUFF_CHANNEL,(string)id + ":cshow");
                            hide = FALSE;
                        }
                        else if ((str1 =="Hide Collar") || (str1 =="Hide All") || (str =="hide"))
                        {
                            llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":chide");
                            hide = TRUE;
                        }
                        else if ((str1 ==" OFF") && (num == DIALOG_RESPONSE))//RLV off (bad way of doing RLV off as maybe other " OFF" in the commands
                        {
                            llRegionSayTo(wearer,CUFF_CHANNEL,str0 + ":rlvoff");
                        }
                        else if ((str1 ==" LOCK") && (num == DIALOG_RESPONSE) && (wait = FALSE))
                        {
                              llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_lock=1", NULL_KEY);
                                wait = TRUE;
                                llSetTimerEvent(0.5);
                        }
                        else if ((str1 ==" UNLOCK") && (num == DIALOG_RESPONSE) && (wait = FALSE))
                        {
                                llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_lock=0", NULL_KEY);
                                wait = TRUE;
                                llSetTimerEvent(0.5);
                        }
                    }
                }
            }
        }
        if ( num == DIALOG_RESPONSE)
        {
        if (id==g_kDialogID)
            {
                list menuparams = llParseString2List(str, ["|"], []);
                key AV = (key)llList2String(menuparams, 0);
                string message = llList2String(menuparams, 1);
                integer page = (integer)llList2String(menuparams, 2);
                integer iAuth = (integer)llList2String(menuparams, 3); // auth level of avatar
                if (message == UPMENU)
                {
                    llMessageLinked(LINK_THIS, iAuth, "menu "+ parentmenu, AV);//NEW command structer
                }
                else if (message == "Cuff Menu")//ask for the cuff menu
                {
                    llRegionSayTo(wearer,CUFF_CHANNEL,(string)AV + ":cmenu|"+(string)AV);
                }
                else if (message == TURNON)
                {
                    sync = TRUE;
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_Sync=1", NULL_KEY);
                    DoMenu(AV);
                }
                else if (message == TURNOFF)
                {
                    sync = FALSE;
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, "C_Sync=0", NULL_KEY);
                    DoMenu(AV);
                }
                else if (message == HIDEON)
                {
                    llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":chide");
                    hide = TRUE;
                    DoMenu(AV);
                }
                else if (message == HIDEOFF)
                {
                    llRegionSayTo(wearer,CUFF_CHANNEL,(string)wearer + ":cshow");
                    hide = FALSE;
                    DoMenu(AV);
                }
                else if (message == "ReSync")
                {//lets grab the saved settings so we can forward them on
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "auth_owner", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "auth_secowners", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "auth_blacklist", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "C_lock", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "rlvmain_on", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "Global_trace", AV);
                    llMessageLinked(LINK_THIS, LM_SETTING_REQUEST, "collarversion", AV);
                    DoMenu(AV);
                }
            }
        }
    }
    timer()
    {
        wait = FALSE;
        llSetTimerEvent(0);
    }
}