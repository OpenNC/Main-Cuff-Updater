////////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------ //
//                            OpenNC - UpdateShim                                 //
//                                 version 3.950                                  //
// ------------------------------------------------------------------------------ //
// Licensed under the GPLv2 with additional requirements specific to Second Life® //
// and other virtual metaverse environments.  ->  www.opencollar.at/license.html  //
// ------------------------------------------------------------------------------ //
// ©   2008 - 2013  Individual Contributors and OpenCollar - submission set free™ //
// ------------------------------------------------------------------------------ //
////////////////////////////////////////////////////////////////////////////////////

// This script is like a kamikaze missile.  It sits dormant in the updater
// until an update process starts.  Once the initial handshake is done, it's
// then inserted into the object being updated, where it chats with the bundle
// giver script inside the updater to let it know what to send over.  When the
// update is finished, this script does a little final cleanup and then deletes
// itself.

integer iStartParam;

// a strided list of all scripts in inventory, with their names,versions,uuids
// built on startup
list lScripts;

// list where we'll record all the settings and local settings we're sent, for replay later.
// they're stored as strings, in form "<cmd>|<data>", where cmd is either LM_SETTING_SAVE
list lSettings;

// Return the name and version of an item as a list.  If item has no version, return empty string for that part.
list GetNameParts(string name) 
{
    list nameparts = llParseString2List(name, [" - "], []);
    string shortname = llDumpList2String(llList2List(nameparts, 0, 1), " - ");
    string version;
    if (llGetListLength(nameparts) > 2) 
    {
        version = llList2String(nameparts, -1);
    } 
    else 
    {
        version = "";
    }
    return [shortname, version];
}

// Given the name (but not version) of a script, look it up in our list and return the key
// returns "" if not found.
key GetScriptFullname(string name) 
{
    integer idx = llListFindList(lScripts, [name]);
    if (idx == -1) 
    {
        return (key)"";
    }
    
    string version = llList2String(lScripts, idx + 1);
    if (version == "") {
        return name;
    } 
    else 
    {
        return llDumpList2String([name, version], " - ");
    }
}

integer COMMAND_NOAUTH = 0;
integer LM_SETTING_SAVE = 2000;//scripts send messages on this channel to have settings saved to settings store
integer LM_SETTING_REQUEST = 2001;//when startup, scripts send requests for settings on this channel
integer LM_SETTING_RESPONSE = 2002;//the settings script will send responses on this channel
integer LM_SETTING_DELETE = 2003;//delete token from store
integer LM_SETTING_EMPTY = 2004;//sent when a token has no value in the settings store

default
{
    state_entry()
    {
        iStartParam = llGetStartParameter();
        // build script list
        integer n;
        integer stop = llGetInventoryNumber(INVENTORY_SCRIPT);
        for (n = 0; n < stop; n++) {
            string name = llGetInventoryName(INVENTORY_SCRIPT, n);
            // add to script list
            lScripts += GetNameParts(name);
        }
        // listen on the start param channel
        llListen(iStartParam, "", "", "");
        // let mama know we're ready
        llWhisper(iStartParam, "reallyready");

    }
    
    listen(integer channel, string name, key id, string msg) 
    {
        if (llGetOwnerKey(id) == llGetOwner()) 
        {
            list parts = llParseString2List(msg, ["|"], []);
            if (llGetListLength(parts) == 4) {
                string type = llList2String(parts, 0);
                string name = llList2String(parts, 1);
                key uuid = (key)llList2String(parts, 2);
                string mode = llList2String(parts, 3);
                string cmd;
                if (mode == "INSTALL" || mode == "REQUIRED") 
                {
                    if (type == "SCRIPT") 
                    {
                        // see if we have that script in our list.
                        integer idx = llListFindList(lScripts, [name]);
                        if (idx == -1) 
                        {
                            // script isn't in our list.
                            cmd = "GIVE";
                        } 
                        else 
                        {
                            // it's in our list.  Check UUID.
                            string script_name = GetScriptFullname(name);
                            key script_id = llGetInventoryKey(script_name);
                            if (script_id == uuid) 
                            {
                                // already have script.  skip
                                cmd = "SKIP";
                            } 
                            else 
                            {
                                // we have the script but it's the wrong version.  delete and get new one.
                                llRemoveInventory(script_name);
                                cmd = "GIVE";
                            }
                        }
                    } 
                    else if (type == "ITEM") 
                    {
                        if (llGetInventoryType(name) != INVENTORY_NONE) 
                        {
                            // item exists.  check uuid.
                            if (llGetInventoryKey(name) != uuid) 
                            {
                                // mismatch.  delete and report
                                llRemoveInventory(name);
                                cmd = "GIVE";
                            } 
                            else 
                            {
                                // match.  Skip
                                cmd = "SKIP";
                            }
                        } 
                        else 
                        {
                            // we don't have item. get it.
                            cmd = "GIVE";
                        }
                    }                
                } 
                else if (mode == "REMOVE" || mode == "DEPRECATED") 
                {

                    if (type == "SCRIPT") 
                    {
                        string script_name = GetScriptFullname(name);
                        
                        if (llGetInventoryType(script_name) != INVENTORY_NONE) 
                        {
                            llRemoveInventory(script_name);
                        }
                    } 
                    else if (type == "ITEM") 
                    {
                        if (llGetInventoryType(name) != INVENTORY_NONE) 
                        {
                            llRemoveInventory(name);
                        }
                    }
                    cmd = "OK";
                }
                string response = llDumpList2String([type, name, cmd], "|");
                llRegionSayTo(id, channel, response);                                                                
            } 
            else 
            {
                if (llSubStringIndex(msg, "CLEANUP") == 0) 
                {
                    list msgparts = llParseString2List(msg, ["|"], []);
                    // look for a version in the name and remove if present
                    list nameparts = llParseString2List(llGetObjectName(), [" - "], []);
                    if (llGetListLength(nameparts) == 2 && (integer)llList2String(nameparts, 1)) 
                    {// looks like there's a version in the name.  Remove
                        // it!  
                        string just_name = llList2String(nameparts, 0);
                        llSetObjectName(just_name);
                    }
                    //restore settings 
                    integer n;
                    integer stop = llGetListLength(lSettings); 
                    for (n = 0; n < stop; n++) 
                    {
                        string setting = llList2String(lSettings, n);
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, setting, "");
                    }
                    // tell scripts to rebuild menus (in case plugins have been removed)
                    llMessageLinked(LINK_SET, COMMAND_NOAUTH, "refreshmenu", llGetOwner());
                    // remove the script pin
                    llSetRemoteScriptAccessPin(0);
                    // celebrate
                    llOwnerSay("Update complete!");
                    // delete shim script
                    llRemoveInventory(llGetScriptName());
                }
            }
        }
    }
    
    link_message(integer sender, integer num, string str, key id) 
    {// The settings script will dump all its settings when an inventory change happens, so listen for that and remember them 
        // so they can be restored when we're done.
        if (num == LM_SETTING_RESPONSE) 
        {
            if (str != "settings=sent") 
            {
                if (llListFindList(lSettings, [str]) == -1) 
                {
                    lSettings += [str];
                }
            }
        }
    }
}