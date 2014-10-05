////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                           OpenNCUpdater - Master                               //
//                                 version 3.980                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ©   2013 - 2014  OpenNC                                                        //
// ------------------------------------------------------------------------------ //
////////////////////////////////////////////////////////////////////////////////////

// This is the master updater script.  It complies with the update handshake
// protocol that OC has been using for quite some time, and should therefore be
// compatible with current OC collars.  the internals of this script, and the
// the other parts of the new updater, have been completely re-written.  Don't
// expect this to work like the old updater.  Because we load an update shim
// script right after handshaking, we're free to rewrite everything that comes
// after the handshake.
// In addition to the handshake and shim installation, this script decides
// which bundles should be installed into (or removed from) the collar.  It
// loops over each bundle in inventory, telling the BundleGiver script to
// install or remove each.
// This script also does a little bit of magic to ensure that the updater's
// version number always matches the contents of the "~version" card.

key version_line_id;
integer initChannelC = -7483214; // Collar updater channel
integer initChannel = -7483215;//changed to be unique Master cuff
integer initChannelS = -7483216;//changed to be unique Slave cuff
integer slave = FALSE;//are we updating a slave cuff?
integer collar = FALSE;//are we updating the collar??
integer iSecureChannel;
// store the script pin here when we get it from the collar.
integer iPin;
// the collar's key
key kCollarKey;
// strided list of bundles in the prim and whether they are supposed to be 
// installed.
list lBundles;
// here we remember the index of the bundle that's currently being installed/removed
// by the bundlegiver.
integer iBundleIdx;
// handle for our dialogs
key kDialogID;
integer DO_BUNDLE = 98749;
integer BUNDLE_DONE = 98750;
integer DIALOG = -9000;
integer DIALOG_RESPONSE = -9001;
integer DIALOG_TIMEOUT = -9002;
string BTN_REQUIRED = " ★ ";
string BTN_INSTALL = " ☒ ";
string BTN_UNINSTALL = " ☐ ";
string BTN_DEPRECATED = " ♻ ";
string INSTALL_METHOD = "Standard";

// A wrapper around llSetScriptState to avoid the problem where it says it can't
// find scripts that are already not running.
DisableScript(string name) 
{
    if (llGetInventoryType(name) == INVENTORY_SCRIPT) 
    {
        if (llGetScriptState(name) != FALSE) 
            llSetScriptState(name, FALSE);
    }
}

DoBundle() 
{ // tell bundle slave to load the bundle.
    string card = llList2String(lBundles, iBundleIdx);
    string mode = llList2String(lBundles, iBundleIdx + 1);
    string bundlemsg = llDumpList2String([iSecureChannel, kCollarKey, card, iPin, mode], "|");
    llMessageLinked(LINK_SET, DO_BUNDLE, bundlemsg, "");    
}

key ShortKey() 
{//just pick 8 random hex digits and pad the rest with 0.  Good enough for dialog uniqueness.
    string sChars = "0123456789abcdef";
    integer iLength = 16;
    string sOut;
    integer n;
    for (n = 0; n < 8; n++) 
    {
        integer iIndex = (integer)llFrand(16);//yes this is correct; an integer cast rounds towards 0.  See the llFrand wiki entry.
        sOut += llGetSubString(sChars, iIndex, iIndex);
    }
    return (key)(sOut + "-0000-0000-0000-000000000000");
}

key Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage) 
{
    key kID = ShortKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`"), kID);
    return kID;
}

SetBundleStatus(string bundlename, string status) 
{// find the bundle in the list
    integer n;
    integer stop = llGetListLength(lBundles);
    for (n = 0; n < stop; n += 2) 
    {
        string card = llList2String(lBundles, n);
        list parts = llParseString2List(card, ["_"], []);
        string name = llList2String(parts, 2);
        if (name == bundlename) 
        {
            lBundles = llListReplaceList(lBundles, [status], n + 1, n + 1);
            return;
        }
    }
}

SetInstallmode(string type) 
{//user clicked default.. restore Bundle Status
    if((slave == FALSE) && (collar == FALSE))
    {
        if(type == "Standard") 
        {
            lBundles = [];
            integer n;
            integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
            for (n = 0; n < stop; n++) 
            {
                string name = llGetInventoryName(INVENTORY_NOTECARD, n);
                if (llSubStringIndex(name, "BUNDLE_") == 0) 
                {
                    list parts = llParseString2List(name, ["_"], []);
                    lBundles += [name, llList2String(parts, -1)];
                }
            }
            return;
        }
        string newstatus;
        integer n;
        integer stop = llGetListLength(lBundles);
        //user clicked Basic.. set Bundle Status
        if(type == "Tail")
            newstatus = "REMOVE";
        else if (type == "Wings")
            newstatus = "INSTALL";
        for (n = 0; n < stop; n += 2)
        {
            string card = llList2String(lBundles, n);
            string status = llList2String(lBundles, n + 1);
            if (status != "REQUIRED" && status != "DEPRECATED")
                lBundles = llListReplaceList(lBundles, [newstatus], n + 1, n + 1);
        }
    }
    else if((slave == TRUE) && (collar == FALSE))
    {
        if(type == "Standard") 
        {
            lBundles = [];
            integer n;
            integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
            for (n = 0; n < stop; n++) 
            {
                string name = llGetInventoryName(INVENTORY_NOTECARD, n);
                if (llSubStringIndex(name, "BUNDLESLAVE_") == 0) 
                {
                    list parts = llParseString2List(name, ["_"], []);
                    lBundles += [name, llList2String(parts, -1)];
                }
            }
            return;
        }
        string newstatus;
        integer n;
        integer stop = llGetListLength(lBundles);
        //user clicked Basic.. set Bundle Status
        for (n = 0; n < stop; n += 2)
        {
            string card = llList2String(lBundles, n);
            string status = llList2String(lBundles, n + 1);
            if (status != "REQUIRED" && status != "DEPRECATED")
                lBundles = llListReplaceList(lBundles, [newstatus], n + 1, n + 1);
        }
    }
     else if((slave == FALSE) && (collar == TRUE))
    {
        if(type == "Standard") 
        {
            lBundles = [];
            integer n;
            integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
            for (n = 0; n < stop; n++) 
            {
                string name = llGetInventoryName(INVENTORY_NOTECARD, n);
                if (llSubStringIndex(name, "BUNDLECOLLAR_") == 0) 
                {
                    list parts = llParseString2List(name, ["_"], []);
                    lBundles += [name, llList2String(parts, -1)];
                }
            }
            return;
        }
        string newstatus;
        integer n;
        integer stop = llGetListLength(lBundles);
        //user clicked Basic.. set Bundle Status
        for (n = 0; n < stop; n += 2)
        {
            string card = llList2String(lBundles, n);
            string status = llList2String(lBundles, n + 1);
            if (status != "REQUIRED" && status != "DEPRECATED")
                lBundles = llListReplaceList(lBundles, [newstatus], n + 1, n + 1);
        }
    }
    else llOwnerSay("Opps I'm not sure what to do!");
}

BundleMenu(integer page) 
{
    // Give the plugin selection/start menu.
    string prompt = "Add/remove plugins by checking the boxes below.";
    prompt += "\n\nClick START when you're ready to update.\n";  
    // build list of buttons from list of bundles
    integer n;
    integer stop = llGetListLength(lBundles);
    list choices;
    for (n = 0; n < stop; n += 2) 
    {
        string card = llList2String(lBundles, n);
        string status = llList2String(lBundles, n + 1);
        list parts = llParseString2List(card, ["_"], []);
        string name = llList2String(parts, 2);
        if (status == "INSTALL") 
            choices += [BTN_INSTALL + " " + name];
        else if (status == "REQUIRED") 
            choices += [BTN_REQUIRED + " " + name];
        else if (status == "REMOVE") 
            choices += [BTN_UNINSTALL + " " + name];
    }
    kDialogID = Dialog(llGetOwner(), prompt + "\n", choices, ["START"], page);
}

GiveMethodMenu() 
{
    if((slave == FALSE) && (collar == FALSE))
    {
        string prompt = "\nStandard: \"Normal cuff update and clean up.\"";
        prompt += "\nCustom: \"Use this if you want wing and/or tail support.\"";
        prompt += "Or if updateing an old original Gaslight cuff, untick pose, and tick Gaslight\"";
        prompt += "\nThe currently selected method is ["+INSTALL_METHOD+"]";
        list choices = ["Standard","Custom"];
        kDialogID = Dialog(llGetOwner(), prompt + "\n", choices, ["START"],0);
    }
    else if((slave == TRUE) && (collar == FALSE))
    {
        string prompt = "\n\n Normal slave cuff update and clean up.";
        prompt += "\n";
        list choices = [""];
        kDialogID = Dialog(llGetOwner(), prompt + "\n", choices, ["Help","START"],0);
    }
    else if((slave == FALSE) && (collar == TRUE))
    {
        string prompt = "\n\n Normal collar slave script update and clean up.";
        prompt += "\n";
        list choices = [""];
        kDialogID = Dialog(llGetOwner(), prompt + "\n", choices, ["Help","START"],0);
    }
    else
    {
        string prompt = "Houston we have a problem!";
        list choices = [" "];
        kDialogID = Dialog(llGetOwner(), prompt + "\n", choices, [" "," "],0);
    }
}

ReadVersionLine() 
{// try to keep object's version in sync with "~version" notecard.
    if (llGetInventoryType("~version") == INVENTORY_NOTECARD) 
        version_line_id = llGetNotecardLine("~version", 0);
}

SetInstructionsText() 
{
    llSetText("1 - Create a backup copy of your collar or cuff\n" +
              "2 - Rez a Collar / Cuff next to me\n" +
              "    In your Collar, select Help/About, Update, & skip 3,4 below\n" +
              ".\n" +
              "3 - Drop the OpenNC update script into the cuff\n" + 
              "4 - Touch the cuff (maybe twice) to get the update menu.\n"
               , <1,1,1>, 1.0);
}

Particles(key target) 
{
    llParticleSystem([ 
        PSYS_PART_FLAGS, 
        PSYS_PART_INTERP_COLOR_MASK |
        PSYS_PART_INTERP_SCALE_MASK |
        PSYS_PART_TARGET_POS_MASK |
        PSYS_PART_EMISSIVE_MASK,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
        PSYS_SRC_TEXTURE, "aa383f73-8be2-c693-acf0-9b8be8b4a155",
        PSYS_SRC_TARGET_KEY, target,
        PSYS_PART_START_SCALE, <0.68, 0.64, 0>,
        PSYS_PART_END_SCALE, <0.04, 0.04, 0>,
        PSYS_PART_START_ALPHA, 0.1,
        PSYS_PART_END_ALPHA, 1,
        PSYS_SRC_BURST_PART_COUNT, 4,
        PSYS_PART_MAX_AGE, 2,
        PSYS_SRC_BURST_SPEED_MIN, 0.2,
        PSYS_SRC_BURST_SPEED_MAX, 1
    ]);
}

default 
{
    state_entry() 
    {
        lBundles = [];
        ReadVersionLine();
        llListen(initChannelC, "", "", "");//Collar update
        llListen(initChannel, "", "", "");
        llListen(initChannelS, "", "", "");//Slave cuffs
        // set all scripts except self to not running
        // also build list of all bundles
        integer n;
        integer stop = llGetInventoryNumber(INVENTORY_ALL);
        for (n = 0; n < stop; n++) 
        {
            string name = llGetInventoryName(INVENTORY_ALL, n);
            integer type = llGetInventoryType(name);
            if (type == INVENTORY_SCRIPT) 
            {// ignore updater scripts.  set others to not running.
                if (llSubStringIndex(name, "OpenNCUpdater") != 0) 
                    DisableScript(name);
            }
        }
        SetInstructionsText();
        llParticleSystem([]);
    }

    listen(integer channel, string name, key id, string msg) 
    {
        if (llGetOwnerKey(id) == llGetOwner()) 
        {
            if (channel == initChannel)//Main cuff Update
            {// everything heard on the init channel is stuff that has to
                // comply with the existing update kickoff protocol.  New stuff
                // will be heard on the random secure channel instead.
                slave = FALSE;
                collar = FALSE;
                SetInstallmode("Standard");
                list parts = llParseString2List(msg, ["|"], []);
                string cmd = llList2String(parts, 0);
                string param = llList2String(parts, 1);
                if (cmd == "UPDATE") // someone just clicked the upgrade button on their collar.
                    llRegionSay(channel, "get ready");
                else if (cmd == "ready") 
                {// person clicked "Yes I want to update" on the collar menu.
                    // the script pin will be in the param
                    iPin = (integer)param;
                    kCollarKey = id;
                    GiveMethodMenu();
                }
            }
            else if (channel == initChannelS)
            {// everything heard on the init channel is stuff that has to
                // comply with the existing update kickoff protocol.  New stuff
                // will be heard on the random secure channel instead.
                slave = TRUE;
                collar = FALSE;
                SetInstallmode("Standard");
                list parts = llParseString2List(msg, ["|"], []);
                string cmd = llList2String(parts, 0);
                string param = llList2String(parts, 1);
                if (cmd == "UPDATE") // someone just clicked the upgrade button on their collar.
                    llRegionSay(initChannelS, "get ready");
                else if (cmd == "ready") 
                {// person clicked "Yes I want to update" on the collar menu.
                    // the script pin will be in the param
                    iPin = (integer)param;
                    kCollarKey = id;
                    GiveMethodMenu();
                }
            }
            else if (channel == initChannelC)//Collar update channel
            {// everything heard on the init channel is stuff that has to
                // comply with the existing update kickoff protocol.  New stuff
                // will be heard on the random secure channel instead.
                slave = FALSE;
                collar = TRUE;
                SetInstallmode("Standard");
                list parts = llParseString2List(msg, ["|"], []);
                string cmd = llList2String(parts, 0);
                string param = llList2String(parts, 1);
                if (cmd == "UPDATE") // someone just clicked the upgrade button on their collar.
                    llRegionSay(channel, "get ready");
                else if (cmd == "ready") 
                {// person clicked "Yes I want to update" on the collar menu.
                    // the script pin will be in the param
                    iPin = (integer)param;
                    kCollarKey = id;
                    GiveMethodMenu();
                }
            }
            else if (channel == iSecureChannel) 
            {
                if (msg == "reallyready") 
                {
                    Particles(id);
                    iBundleIdx = 0;
                    DoBundle();
                }
            }
        }
    }

    // when we get a BUNDLE_DONE message, move to the next bundle
    link_message(integer sender, integer num, string str, key id) 
    {
        if (num == DIALOG_RESPONSE) 
        {
            if (id == kDialogID) 
            {
                list parts = llParseString2List(str, ["|"], []);
                key av = (key)llList2String(parts, 0);
                string button = llList2String(parts, 1);
                integer page = (integer)llList2String(parts, 2);
                if (button == "START") 
                {// so let's load the shim.
                    string shim = "OpenNC - UpdateShim";
                    iSecureChannel = (integer)llFrand(-2000000000 + 1);
                    llListen(iSecureChannel, "", kCollarKey, "");
                    llRemoteLoadScriptPin(kCollarKey, shim, iPin, TRUE, iSecureChannel);
                }
                else if (button == "Tail" || button == "Standard" || button == "Wings")
                {
                    INSTALL_METHOD = button;
                    SetInstallmode(button);
                    GiveMethodMenu();
                } 
                else if (button == "Custom") 
                    BundleMenu(0);
                else if (button == "Help") 
                {
                    if (slave == TRUE)
                    {
                        llOwnerSay("Hopefully you are updating a slave cuff, so just press START");
                        GiveMethodMenu();
                    }
                    else
                    {
                        llOwnerSay("Unless you are updating an original Gaslight Main Cuff, OR want to install support for wing chains, and/or tail cuff. Just press START");
                        GiveMethodMenu();
                    }
                }
                else 
                {
                    // switch the bundle if appropriate
                    string status = llGetSubString(button, 0, 2);
                    string bundlename = llGetSubString(button, 4, -1);
                    if (status == BTN_REQUIRED) 
                        llOwnerSay("The " + bundlename + " bundle is required and cannot be removed.");
                    else if (status == BTN_DEPRECATED) 
                        llOwnerSay("The " + bundlename + " bundle is deprecated and must be removed.");
                    else if (status == BTN_INSTALL) 
                    {
                        // if the button said +, that means we need to switch it to -
                        // find the bundle in the list, and set to REMOVE
                        SetBundleStatus(bundlename, "REMOVE");
                        llOwnerSay(bundlename + " will be removed if present.");
                    } 
                    else if (status == BTN_UNINSTALL) 
                    {
                        SetBundleStatus(bundlename, "INSTALL");
                        llOwnerSay(bundlename + " will be updated/installed.");
                    }
                    BundleMenu(page);
                }
            }
        }
        else if (num == BUNDLE_DONE) 
        {// see if there's another bundle
            integer count = llGetListLength(lBundles);
            iBundleIdx += 2;
            if (iBundleIdx < count) 
                DoBundle();
            else
            {
                // tell the shim to restore settings, set version, 
                // remove the script pin, and delete himself.
                string myversion = llList2String(llParseString2List(llGetObjectName(), [" - "], []), 1);
                llRegionSayTo(kCollarKey, iSecureChannel, "CLEANUP|" + myversion);
                SetInstructionsText();
                llParticleSystem([]);
            }
        }
    }

    on_rez(integer param) 
    {
        llResetScript();
    }

    changed(integer change) 
    {
        if (change & CHANGED_INVENTORY) // Resetting on inventory change ensures that the bundle list is kept current, and that the ~version card is re-read if it changes.
            llResetScript();
    }

    dataserver(key id, string data) 
    {
        if (id == version_line_id) 
        {
            // make sure that object version matches this card.
            list nameparts = llParseString2List(llGetObjectName(), [" - "], []);
            integer length = llGetListLength(nameparts);
            if (length == 2) 
                nameparts = llListReplaceList(nameparts, [data], 1, 1);
            else if (length == 1) 
                nameparts += [data];
            llSetObjectName(llDumpList2String(nameparts, " - "));
        }
    }
}