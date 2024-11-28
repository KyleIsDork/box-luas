--region == Brief Setup Instructions ==
--[[
    1. Install the lnxLib library, sniperbuybot, and vaccibucks. These are typically in %localappdata%
    2. Create an autoload.lua file in the same directory as your other scripts.
        - If you're using Sandboxie+, you can use the following code:
        https://github.com/KyleIsDork/box-luas/tree/main/lua/mboxsetup
        - Preloading the scripts allows Sandboxie+ to interface with dynamic directory locations - os.getenv('localappdata').
        - This should be compatible with other virtualization methods, but I've not personally tested.
    3. Issue commands to bots via party chat, addressed from assigned IDs.
]] --
--endregion

--region == Credits ==
-- Bot helper by __null
-- Forked by Dr_Coomer -- I want people to note that some comments were made by me, and some were made by the original author. I try to keep what is mine and what was by the original as coherent as possible, even if my rambalings themselfs are not. Such as this long useless comment. The unfinished medi gun and inventory manager is by the original author and such. I am just passionate about multi-boxing, and when I found this lua I saw things that could be changed around or added, so that multiboxing can be easier and less of a slog of going to each client or computer and manually changing classes, loadout, or turning on and off features.
-- Additional edits by Cogcie, integrating partial functionality with Vaccibucks and a SniperBuyBot that's a modified version of the one in Vaccibucks.
-- I'm (cogcie) a b1g pasta, huge credit to Spark-Init & StanSmits for their work.
-- Library by Lnx00
--endregion

--region == UI ==
-- UI stuff stolen from vacbux, thanks vacbux
-- I (cogcie) changed some values to make it visually distinct from the original UI, as we're loading both.
-- Integrated dragging from a vacbux PR.
local UI = {
    x = 40,
    y = 300,
    width = 450,
    height = 115,
    cornerRadius = 4,
    titleFont = draw.CreateFont("Verdana Bold", 22, 800),
    mainFont = draw.CreateFont("Consolas", 16, 400),
    colors = {
        background = { 15, 15, 15, 240 },
        accent = { 65, 185, 155 },
        success = { 50, 205, 50 },
        warning = { 255, 165, 0 },
        error = { 255, 64, 64 },
        text = { 255, 255, 255 },
        textDim = { 180, 180, 180 }
    },
    notifications = {},
    maxNotifications = 10,
    notificationLifetime = 3,
    notificationHeight = 28,
    notificationSpacing = 4
}

-- basic drawing stuff that i might reuse later
local function DrawRoundedRect(x, y, w, h, radius, color)
    draw.Color(
        math.floor(color[1]),
        math.floor(color[2]),
        math.floor(color[3]),
        math.floor(color[4] or 255)
    )
    draw.FilledRect(
        math.floor(x),
        math.floor(y),
        math.floor(x + w),
        math.floor(y + h)
    )
end

local function DrawNotification(notif, x, y)
    if notif.alpha <= 1 then return end

    draw.SetFont(UI.mainFont)
    local iconWidth, _ = draw.GetTextSize(notif.icon)
    local messageWidth, _ = draw.GetTextSize(notif.message)
    local width = math.floor(iconWidth + messageWidth + 30)
    local height = math.floor(UI.notificationHeight)

    local progress = 1 - ((globals.CurTime() - notif.time) / UI.notificationLifetime)
    local alpha = math.floor(notif.alpha * progress)

    draw.Color(0, 0, 0, 178)
    draw.FilledRect(x, y, x + width, y + height)

    draw.Color(notif.color[1], notif.color[2], notif.color[3], alpha)
    draw.Text(math.floor(x + 5), math.floor(y + height / 2 - 7), notif.icon)

    draw.Color(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], alpha)
    draw.Text(math.floor(x + iconWidth + 15), math.floor(y + height / 2 - 7), notif.message)

    if progress > 0 then
        DrawRoundedRect(
            math.floor(x + 1),
            math.floor(y + height - 2),
            math.floor((width - 2) * progress),
            2,
            1,
            { 199, 170, 255, math.floor(alpha * 0.7) }
        )
    end
end
--endregion

--region == Library Imports ==
if UnloadLib then UnloadLib() end -- I really didnt want to use LnxLib since I wanted this script to be a single be all script. Some day I will make it that, but the times I tried I couldn't export what I needed out of lnxLib.lua

---@type boolean, lnxLib
---@diagnostic disable-next-line: assign-type-mismatch
local libLoaded, lnxLib = pcall(require, "lnxLib") --lnxLib is marked as a warning in my text editor because it "haS ThE POsiBiliTY tO Be NiL"
assert(libLoaded, "lnxLib not found, please install it!")
if lnxLib == nil then return end                   -- To make the text editor stop be mad :)
assert(lnxLib.GetVersion() >= 0.987, "lnxLib version is too old, please update it!")
--endregion

--region == Utility Functions & Variables ==
local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer

-- On-load presets:
-- Trigger symbol. All commands should start with this symbol.
local triggerSymbol = "!";
-- Process messages only from lobby owner.
local lobbyOwnerOnly = false;
-- Check if we want to me mic spamming or not.
local PlusVoiceRecord = false;
-- Global check for if we want to autovote
local AutoVoteCheck = false;
-- Global check for if we want ZoomDistance to be enabled
local ZoomDistanceCheck = true;
-- Global check for if we want Auto-melee to be enabled
local AutoMeleeCheck = false;
-- Keep the table of command arguments outside of all functions, so we can just jack this when ever we need anymore than a single argument.
local commandArgs;

-- Determine the current class
local function GetCurrentClassName()
    local me = entities.GetLocalPlayer()
    if not me then
        return "Unknown"
    end
    -- Lookup table for class names
    local class_lookup = {
        [1] = "Scout",
        [2] = "Sniper",
        [3] = "Soldier",
        [4] = "Demoman",
        [5] = "Medic",
        [6] = "Heavy",
        [7] = "Pyro",
        [8] = "Spy",
        [9] = "Engineer"
    }
    local class = me:GetPropInt('m_iClass')
    return class_lookup[class] or "Unknown"
end

local friend = -1
local myFriends = steam.GetFriends() -- Recusively creating a table of the bot's steam friends causes lag and poor performans down to a single frame. Why? Answer: LMAObox
local k_eTFPartyChatType_MemberChat = 1;
local steamid64Ident = 76561197960265728;
local partyChatEventName = "party_chat";
local playerJoinEventName = "player_spawn";
local availableClasses = { "scout", "soldier", "pyro", "demoman", "heavy", "engineer", "medic", "sniper", "spy", "random" };
local availableOnOffArguments = { "1", "0", "on", "off" };
local availableSpam = { "none", "branded", "custom" };
local availableSpamSecondsString = {}
for i = 1, 60 do table.insert(availableSpamSecondsString, tostring(i)) end -- Generates "1" to "60" dynamically
local medigunTypedefs = {
    default = { 29, 211, 663, 796, 805, 885, 894, 903, 912, 961, 970 },
    quickfix = { 411 },
    kritz = { 35 }
};

-- Command container
local commands = {};

-- Found mediguns in inventory.
local foundMediguns = {
    default = -1,
    quickfix = -1,
    kritz = -1
};

-- This method gives the distance between two points
function DistanceFrom(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- This method gives the difference in only a axis between two points
function DifferenceInHight(y1, y2)
    return math.floor((y2 - y1))
end

-- Helper method that converts SteamID64 to SteamID3
local function SteamID64ToSteamID3(steamId64)
    return "[U:1:" .. steamId64 - steamid64Ident .. "]";
end

-- Thanks, LUA!
local function SplitString(input, separator)
    if separator == nil then
        separator = "%s";
    end

    local t = {};

    for str in string.gmatch(input, "([^" .. separator .. "]+)") do
        table.insert(t, str);
    end

    return t;
end

-- Helper that sends a message to party chat
local function Respond(input)
    client.Command("say_party " .. input, true);
end

-- Helper that checks if table contains a value
function Contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true;
        end
    end

    return false;
end

--endregion

--region == Commands ==
-- Note: I (cogcie) have attempted to attribute all sections below as accurately as possible.
-- If you see any errors, please let me know.

--region null's additions
local function KillCommand()
    client.Command("kill", true);
    Respond("my time nears, goodbye cruel world");
end

local function ExplodeCommand()
    client.Command("explode", true);
    Respond("Kaboom!");
end

local function SwitchWeapon(args)
    local slotStr = args[1];

    if slotStr == nil then
        Respond("Usage: " .. triggerSymbol .. "slot <slot number>");
        return;
    end

    local slot = tonumber(slotStr);

    if slot == nil then
        Respond("Unknown slot [" .. slotStr .. "]. Available are 0-10.");
        return;
    end

    if slot < 0 or slot > 10 then
        Respond("Unknown slot [" .. slotStr .. "]. Available are 0-10.");
        return;
    end

    Respond("Switched weapon to slot [" .. slot .. "]");
    client.Command("slot" .. slot, true);
end

local function SwitchClass(args)
    local class = args[1];

    if class == nil then
        Respond("Usage: " .. triggerSymbol .. "class <" .. table.concat(availableClasses, ", ") .. ">");
        return;
    end

    class = string.lower(args[1]);

    if not Contains(availableClasses, class) then
        Respond("Unknown class [" .. class .. "]");
        return;
    end

    if class == "heavy" then
        -- Wtf Valve
        -- ^^ true true, I agree.
        class = "heavyweapons";
    end

    Respond("Switched to [" .. class .. "]");
    gui.SetValue("Class Auto-Pick", class);
    client.Command("join_class " .. class, true);
end

local function Say(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say <text>");
        return;
    end

    client.Command("say " .. string.gsub(msg, "|", " "), true);
end

local function SayTeam(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say_team <text>");
        return;
    end

    client.Command("say_team " .. string.gsub(msg, "|", " "), true);
end

local function SayParty(args)
    local msg = args[1];

    if msg == nil then
        Respond("Usage: " .. triggerSymbol .. "say_party <text>");
        return;
    end

    client.Command("say_party " .. string.gsub(msg, "|", " "), true);
end

local function Taunt(args)
    client.Command("taunt", true);
end

local function TauntByName(args)
    local firstArg = args[1];

    if firstArg == nil then
        Respond("Usage: " .. triggerSymbol .. "tauntn <Full taunt name>.");
        Respond("For example: " .. triggerSymbol .. "tauntn Taunt: The Schadenfreude");
        return;
    end

    local fullTauntName = table.concat(args, " ");
    client.Command("taunt_by_name " .. fullTauntName, true);
end

--endregion

--region Dr_Coomer's Additions
-- Follow bot switcher added by Dr_Coomer - doctor.coomer
local function FollowBotSwitcher(args)
    local fbot = args[1];

    if fbot == nil then
        Respond("Usage: " .. triggerSymbol .. "fbot stop/friends/all");
        return;
    end

    fbot = string.lower(args[1]);

    if fbot == "stop" then
        Respond("Disabling followbot!");
        fbot = "none";
    end

    if fbot == "friends" then
        Respond("Following only friends!");
        fbot = "friends only";
    end

    if fbot == "all" then
        Respond("Following everyone!");
        fbot = "all players";
    end

    gui.SetValue("follow bot", fbot);
end

-- Loudout changer added by Dr_Coomer - doctor.coomer
local function LoadoutChanger(args)
    local lout = args[1];

    if lout == nil then
        Respond("Usage: " .. triggerSymbol .. "lout A/B/C/D");
        return;
    end

    --Ahhhhh
    --More args, more checks, more statements.

    if string.lower(lout) == "a" then
        Respond("Switching to loudout A!");
        lout = "0";
    elseif lout == "1" then
        Respond("Switching to loudout A!");
        lout = "0"; --valve counts from zero. to make it user friendly since humans count from one, the args are between 1-4 and not 0-3
    end

    if string.lower(lout) == "b" then
        Respond("Switching to loutoud B!");
        lout = "1";
    elseif lout == "2" then
        Respond("Switching to loutoud B!");
        lout = "1"
    end

    if string.lower(lout) == "c" then
        Respond("Switching to loudout C!");
        lout = "2";
    elseif lout == "3" then
        Respond("Switching to loudout C!");
        lout = "2";
    end

    if string.lower(lout) == "d" then
        Respond("Switching to loudout D!");
        lout = "3";
    elseif lout == "4" then
        Respond("Switching to loudout D!");
        lout = "3";
    end

    client.Command("load_itempreset " .. lout, true);
end


-- Lobby Owner Only Toggle added by Dr_Coomer - doctor.coomer
local function TogglelobbyOwnerOnly(args)
    local OwnerOnly = args[1]

    if OwnerOnly == nil or not Contains(availableOnOffArguments, OwnerOnly) then
        Respond("Usage: " .. triggerSymbol .. "OwnerOnly 1/0 or on/off");
        return;
    end

    if OwnerOnly == "1" then
        lobbyOwnerOnly = true;
    elseif string.lower(OwnerOnly) == "on" then
        lobbyOwnerOnly = true;
    end

    if OwnerOnly == "0" then
        lobbyOwnerOnly = false;
    elseif string.lower(OwnerOnly) == "off" then
        lobbyOwnerOnly = false;
    end

    Respond("Lobby Owner Only is now: " .. OwnerOnly)
end

-- Toggle ignore friends added by Dr_Coomer - doctor.coomer
local function ToggleIgnoreFriends(args)
    local IgnoreFriends = args[1]

    if IgnoreFriends == nil or not Contains(availableOnOffArguments, IgnoreFriends) then
        Respond("Usage: " .. triggerSymbol .. "IgnoreFriends 1/0 or on/off")
        return;
    end

    if IgnoreFriends == "1" then
        IgnoreFriends = 1;
    elseif string.lower(IgnoreFriends) == "on" then
        IgnoreFriends = 1;
    end

    if IgnoreFriends == "0" then
        IgnoreFriends = 0;
    elseif string.lower(IgnoreFriends) == "off" then
        IgnoreFriends = 0;
    end

    Respond("Ignore Steam Friends is now: " .. IgnoreFriends)
    gui.SetValue("Ignore Steam Friends", IgnoreFriends)
end

-- connect to servers via IP re implemented by Dr_Coomer - doctor.coomer
-- Context: There was a registered callback for a command called "connect" but there was no function for it. So, via the name of the registered callback, I added it how I thought he would have.
local function Connect(args)
    local Connect = args[1]

    Respond("Joining server " .. Connect .. "...")

    client.Command("connect " .. Connect, true);
end

-- Chatspam switcher added by Dr_Coomer - doctor.coomer
local function cspam(args)
    local cspam = args[1];

    if cspam == nil then
        Respond("Usage: " .. triggerSymbol .. "cspam none/branded/custom")
        return;
    end

    local cspamSeconds = table.remove(commandArgs, 2)
    cspam = string.lower(args[1])

    --Code:
    --Readable: N
    --Works: Y
    --I hope no one can see how bad this is, oh wait...

    if not Contains(availableSpam, cspam) then
        if Contains(availableSpamSecondsString, cspam) then
            print("switching seconds")
            Respond("Chat spamming with " .. cspam .. " second interval")
            gui.SetValue("Chat Spam Interval (s)", tonumber(cspam, 10))
            return;
        end

        Respond("Unknown chatspam: [" .. cspam .. "]")
        return;
    end

    if Contains(availableSpam, cspam) then
        if Contains(availableSpamSecondsString, cspamSeconds) then
            print("switching both")
            gui.SetValue("Chat Spam Interval (s)", tonumber(cspamSeconds, 10)) --I hate this god damn "tonumber" function. Doesn't do as advertised. It needs a second argument called "base". Setting it anything over 10, then giving the seconds input anything over 9, will then force it to be to that number. Seconds 1-9 will work just fine, but if you type 10 it will be forced to that number. --mentally insane explination
            gui.SetValue("Chat spammer", cspam)
            Respond("Chat spamming " .. cspam .. " with " .. tostring(cspamSeconds) .. " second interval")
            return;
        end
    end

    if not Contains(availableSpamSecondsString, cspam) then
        if Contains(availableSpam, cspam) then
            print("switching spam")
            gui.SetValue("Chat spammer", cspam)
            Respond("Chat spamming " .. cspam)
            return;
        end
    end
end

-- ZoomDistance from cathook, added by Dr_Coomer
-- Zoom Distance means that it will automatically zoomin when you are in a cirtant distance from a player regardless if there is a line of site of the enemy
-- it will not change the visual zoom distance when scoping in
local ZoomDistanceIsInRange = false;
local closestplayer

local CurrentClosestX
local CurrentClosestY

local playerInfo
local partyMemberTable

local ZoomDistanceDistance = 950; --defaults distance

local function zoomdistance(args)
    local zoomdistance = args[1]
    local zoomdistanceDistance = tonumber(table.remove(commandArgs, 2))

    if zoomdistance == nil then
        Respond("Example: " .. triggerSymbol .. "zd on 650")
        return
    end

    zoomdistance = string.lower(args[1])

    if zoomdistance == "1" then
        ZoomDistanceCheck = true
        Respond("Zoom Distance is now: " .. tostring(ZoomDistanceCheck))
    elseif zoomdistance == "on" then
        ZoomDistanceCheck = true
        Respond("Zoom Distance is now: " .. tostring(ZoomDistanceCheck))
    end

    if zoomdistance == "0" then
        ZoomDistanceCheck = false
        Respond("Zoom Distance is now: " .. tostring(ZoomDistanceCheck))
    elseif zoomdistance == "off" then
        ZoomDistanceCheck = false
        Respond("Zoom Distance is now: " .. tostring(ZoomDistanceCheck))
    end

    if zoomdistanceDistance == nil then
        return;
    end

    ZoomDistanceDistance = zoomdistanceDistance
    Respond("The minimum range is now: " .. tostring(ZoomDistanceDistance))
end

local function GetPlayerLocations()
    local localp = entities.GetLocalPlayer()
    local players = entities.FindByClass("CTFPlayer")

    if localp == nil then
        return;
    end

    if ZoomDistanceCheck == false then
        return;
    end

    local localpOrigin = localp:GetAbsOrigin();
    local localX = localpOrigin.x
    local localY = localpOrigin.y

    for i, player in pairs(players) do
        playerInfo = client.GetPlayerInfo(player:GetIndex())
        partyMemberTable = party.GetMembers()
        if partyMemberTable == nil then goto Skip end
        if Contains(partyMemberTable, playerInfo.SteamID) then goto Ignore end
        ::Skip::

        --Skip players we don't want to enumerate
        if not player:IsAlive() then
            goto Ignore
        end

        if player:IsDormant() then
            goto Ignore
        end

        if player == localp then
            goto Ignore
        end
        if player:GetTeamNumber() == localp:GetTeamNumber() then
            goto Ignore
        end

        if Contains(myFriends, playerInfo.SteamID) then
            goto Ignore
        end

        if playerlist.GetPriority(player) == friend then
            goto Ignore
        end

        --Get the current enumerated player's vector2 from their vector3
        local Vector3Players = player:GetAbsOrigin()
        local X = Vector3Players.x
        local Y = Vector3Players.y

        localX = localpOrigin.x
        localY = localpOrigin.y

        if IsInRange == false then
            if DistanceFrom(localX, localY, X, Y) < ZoomDistanceDistance then --If we get someone that is in range then we save who they are and their vector2
                IsInRange = true;

                closestplayer = player;

                CurrentClosestX = closestplayer:GetAbsOrigin().x
                CurrentClosestY = closestplayer:GetAbsOrigin().y
            end
        end
        ::Ignore::
    end

    if IsInRange == true then
        if localp == nil or not localp:IsAlive() then -- check if you died or dont exist
            IsInRange = false;
            return;
        end

        if closestplayer == nil then -- ? despite this becoming nil after the player leaving, this never gets hit.
            error("\n\n\n\n\n\n\n\n\n\n\nthis will never get hit\n\n\n\n\n\n\n\n\n\n\n")
            IsInRange = false;
            return;
        end

        if closestplayer:IsDormant() then -- check if they have gone dormant
            IsInRange = false;
            return;
        end

        if not closestplayer:IsAlive() then --Check if the current closest player has died
            IsInRange = false;
            return;
        end

        if DistanceFrom(localX, localY, CurrentClosestX, CurrentClosestY) > ZoomDistanceDistance then --Check if they have left our range
            IsInRange = false;
            return;
        end

        if playerlist.GetPriority(closestplayer) == friend then
            IsInRange = false
            return;
        end

        CurrentClosestX = closestplayer:GetAbsOrigin().x
        CurrentClosestY = closestplayer:GetAbsOrigin().y
    end
end

-- Auto unzoom. Needs improvement. Took it from some random person in the telegram months ago.
local stopScope = false;
local countUp = 0;
local function AutoUnZoom(cmd)
    local localp = entities.GetLocalPlayer();

    if (localp == nil or not localp:IsAlive()) then
        return;
    end

    if ZoomDistanceIsInRange == true then
        if not (localp:InCond(TFCond_Zoomed)) then
            cmd.buttons = cmd.buttons | IN_ATTACK2
        end
    elseif ZoomDistanceIsInRange == false then
        if stopScope == false then
            if (localp:InCond(TFCond_Zoomed)) then
                cmd.buttons = cmd.buttons | IN_ATTACK2
                stopScope = true;
            end
        end
    end


    --Wait logic
    if stopScope == true then
        countUp = countUp + 1;
        if countUp == 66 then
            countUp = 0;
            stopScope = false;
        end
    end
end

--Toggle noisemaker spam, Dr_Coomer
local function noisemaker(args)
    local nmaker = args[1];

    if nmaker == nil or not Contains(availableOnOffArguments, nmaker) then
        Respond("Usage: " .. triggerSymbol .. "nmaker 1/0 or on/off")
        return;
    end

    if nmaker == "1" then
        nmaker = 1;
    elseif string.lower(nmaker) == "on" then
        nmaker = 1;
    end

    if nmaker == "0" then
        nmaker = 0;
    elseif string.lower(nmaker) == "off" then
        nmaker = 0;
    end

    Respond("Noise maker spam is now: " .. nmaker)
    gui.SetValue("Noisemaker Spam", nmaker)
end

-- Autovote casting, added by Dr_Coomer, pasted from drack's autovote caster to vote out bots (proof I did this before drack887: https://free.novoline.pro/ouffcjhnm8yhfjomdf.png)
local function autovotekick(args) -- toggling the boolean
    local autovotekick = args[1]

    if autovotekick == nil or not Contains(availableOnOffArguments, autovotekick) then
        Respond("Usage: " .. triggerSymbol .. "autovotekick 1/0 or on/off")
        return;
    end

    if autovotekick == "1" then
        AutoVoteCheck = true;
    elseif string.lower(autovotekick) == "on" then
        AutoVoteCheck = true;
    end

    if autovotekick == "0" then
        AutoVoteCheck = false;
    elseif string.lower(autovotekick) == "off" then
        AutoVoteCheck = false;
    end

    Respond("Autovoting is now " .. autovotekick)
end

local timer = 0;
local function autocastvote() --all the logic to actually cast the vote
    if AutoVoteCheck == false then
        return;
    end
    if (gamerules.IsMatchTypeCasual() and timer <= os.time()) then
        timer = os.time() + 2
        local resources = entities.GetPlayerResources()
        local me = entities.GetLocalPlayer()
        if (resources ~= nil and me ~= nil) then
            local teams = resources:GetPropDataTableInt("m_iTeam")
            local userids = resources:GetPropDataTableInt("m_iUserID")
            local accounts = resources:GetPropDataTableInt("m_iAccountID")
            local partymembers = party.GetMembers()

            for i, m in pairs(teams) do
                local steamid = "[U:1:" .. accounts[i] .. "]"
                local playername = client.GetPlayerNameByUserID(userids[i])

                if (me:GetTeamNumber() == m and userids[i] ~= 0 and steamid ~= partymembers[1] and
                        steamid ~= partymembers[2] and
                        steamid ~= partymembers[3] and
                        steamid ~= partymembers[4] and
                        steamid ~= partymembers[5] and
                        steamid ~= partymembers[6] and
                        steamid ~= "[U:1:0]" and
                        not steam.IsFriend(steamid) and
                        playerlist.GetPriority(userids[i]) > -1) then
                    --Respond("Calling Vote on player " .. playername .. " " .. steamid) --This gets spammed a lot
                    client.Command('callvote kick "' .. userids[i] .. ' cheating"', true)
                    goto CalledVote
                end
            end
        end
    end
    ::CalledVote::
end

local function responsecheck_message(msg) --If the vote failed respond with the reason
    if AutoVoteCheck == true then
        if (msg:GetID() == CallVoteFailed) then
            local reason = msg:ReadByte()
            local cooldown = msg:ReadInt(16)

            if (cooldown > 0) then
                if cooldown == 65535 then
                    Respond("Something odd is going on, waiting even longer.")
                    cooldown = 35
                    timer = os.time() + cooldown
                    return;
                end

                Respond("Vote Cooldown " .. cooldown .. " Seconds") --65535
                timer = os.time() + cooldown
            end
        end
    end
end
--End of the Autovote casting functions

-- Auto Melee, I entirely based this of Lnx's aimbot lua, because all I knew that I needed was some way to lock onto players, and the lmaobox api doesnt have all the built it features to do this.
-- Made it a script that automatically pulls out the third weapon slot (aka the melee weapon) when a players gets too close, and walks at them.
-- still subject to plenty of improvements, since right now this is as good as its most likely going to get.
local AutoMeleeIsInRange = false
local AutoMeleeDistance = 400 --350
local lateralRange = 80       -- 80

local function AutoMelee(args)
    local AutoM = string.lower(args[1])
    local AutoMDistance = tonumber(table.remove(commandArgs, 2))

    if AutoM == nil or not Contains(availableOnOffArguments, AutoM) then
        Respond("Usage: " .. triggerSymbol .. "AutoM on/off an-number")
        return
    end

    if AutoM == "on" then
        AutoMeleeCheck = true
        Respond("Auto-melee is now: " .. tostring(AutoMeleeCheck))
    elseif AutoM == "off" then
        AutoMeleeCheck = false
        Respond("Auto-melee is now: " .. tostring(AutoMeleeCheck))
    end

    if AutoMDistance == nil then
        return
    end

    AutoMeleeDistance = AutoMDistance
    Respond("Minimum range is now: " .. tostring(AutoMeleeDistance))
end

---Pasted directly out of Lnx's library, since something with MASK_SHOT broke on lmaobox's end (thanks you Mr Curda)
function VisPos(target, from, to)
    local trace = engine.TraceLine(from, to, (0x1|0x4000|0x2000000|0x2|0x4000000|0x40000000) | CONTENTS_GRATE)
    return (trace.entity == target) or (trace.fraction > 0.99)
end

-- Finds the best position for hitscan weapons
local function CheckHitscanTarget(me, player)
    -- FOV Check
    local aimPos = player:GetHitboxPos(5) -- body
    if not aimPos then return nil end
    local angles = Math.PositionAngles(me:GetEyePos(), aimPos)

    -- Visiblity Check
    if not VisPos(player:Unwrap(), me:GetEyePos(), player:GetHitboxPos(5)) then return nil end

    -- The target is valid
    return angles
end

-- Checks the given target for the given weapon
local function CheckTarget(me, entity, weapon) -- this entire function needs more documentation for whats going on
    partyMemberTable = party.GetMembers()
    playerInfo = client.GetPlayerInfo(entity:GetIndex())
    if partyMemberTable == nil then goto Skip end
    if Contains(partyMemberTable, playerInfo.SteamID) then return nil end
    ::Skip::

    if not entity then return nil end
    if not entity:IsAlive() then return nil end
    if entity:IsDormant() then return nil end
    if entity:GetTeamNumber() == me:GetTeamNumber() then return nil end
    if entity:InCond(TFCond_Bonked) then return nil end

    if Contains(myFriends, playerInfo.SteamID) then return nil end
    if playerlist.GetPriority(entity) == friend then return nil end

    if DistanceFrom(me:GetAbsOrigin().x, me:GetAbsOrigin().y, entity:GetAbsOrigin().x, entity:GetAbsOrigin().y) > AutoMeleeDistance then return nil end

    local player = WPlayer.FromEntity(entity)

    return CheckHitscanTarget(me, player)
end

-- Returns the best target for the given weapon
local function GetBestTarget(me, weapon)
    local players = entities.FindByClass("CTFPlayer")
    local meVec
    local playerVec
    local currentPlayerVec
    local bestTarget = nil
    local currentEnt

    -- Check all players
    for _, entity in pairs(players) do
        meVec = me:GetAbsOrigin()
        playerVec = entity:GetAbsOrigin()

        local target = CheckTarget(me, entity, weapon)
        if DifferenceInHight(meVec.z, playerVec.z) >= lateralRange then goto continue end
        if not target or target == nil then goto continue end

        if DistanceFrom(meVec.x, meVec.y, playerVec.x, playerVec.y) < AutoMeleeDistance then --If we get someone that is in range then we save who they are and their vector2
            bestTarget = target;
            currentEnt = entity;
            currentPlayerVec = currentEnt:GetAbsOrigin()
            client.Command("slot3", true)
            client.Command("+forward", true)
            AutoMeleeIsInRange = true
        end

        ::continue::
    end

    if AutoMeleeIsInRange == true then
        if me == nil or not me:IsAlive() then -- check if you died or dont exist
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil;
        end

        if currentEnt == nil then
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil;
        end

        if currentEnt:IsDormant() then -- check if they have gone dormant
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil;
        end

        if not currentEnt:IsAlive() then --Check if the current closest player has died
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil;
        end

        if DistanceFrom(meVec.x, meVec.y, currentPlayerVec.x, currentPlayerVec.y) > AutoMeleeDistance then --Check if they have left our range
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil;
        end

        if playerlist.GetPriority(currentEnt) == -1 then -- if they become your friend all of a suden
            AutoMeleeIsInRange = false;
            client.Command("-forward", true)
            client.Command("slot1", true)
            return nil
        end

        meVec = me:GetAbsOrigin()
        currentPlayerVec = currentEnt:GetAbsOrigin()
    end

    return bestTarget
end

local function AutoMeleeAimbot()
    if AutoMeleeCheck == false then return end

    local me = WPlayer.GetLocal()
    if not me or not me:IsAlive() then return end

    local weapon = me:GetActiveWeapon()
    if not weapon then return end

    -- Get the best target
    local currentTarget = GetBestTarget(me, weapon)
    if not currentTarget then return end

    -- Aim at the target
    engine.SetViewAngles(currentTarget)
end

callbacks.Register("Unload", function()
    client.Command("-forward", true) -- if for some reason unloaded while running at someone
end)
-- End of auto-melee



-- Reworked Mic Spam, added by Dr_Coomer - doctor.coomer
local function Speak(args)
    Respond("Listen to me!")
    PlusVoiceRecord = true;
    client.Command("+voicerecord", true)
end

local function Shutup(args)
    Respond("I'll shut up now...")
    PlusVoiceRecord = false;
    client.Command("-voicerecord", true)
end

local function MicSpam(event)
    if event:GetName() ~= playerJoinEventName then
        return;
    end

    if PlusVoiceRecord == true then
        client.Command("+voicerecord", true);
    end
end
--endregion

--region StoreMilk's Additions
local function Leave(args)
    gamecoordinator.AbandonMatch();

    --Fall back. If you are in a community server then AbandonMatch() doesn't work.
    client.Command("disconnect", true)
end

local function Console(args)
    local cmd = args[1];

    if cmd == nil then
        Respond("Usage: " .. triggerSymbol .. "console <text>");
        return;
    end

    client.Command(cmd, true);
end
--endregion

--region thyraxis' Additions
local function ducktoggle(args)
    local duck = args[1]

    if duck == nil or not Contains(availableOnOffArguments, duck) then
        Respond("Usage: " .. triggerSymbol .. "duck 1/0 or on/off");
        return;
    end

    if duck == "on" then
        duck = 1;
        client.Command("+duck", true);
    elseif duck == "1" then
        duck = 1;
        client.Command("+duck", true);
    end

    if duck == "off" then
        duck = 0;
        client.Command("-duck", true);
    elseif duck == "0" then
        duck = 0;
        client.Command("-duck", true);
    end

    gui.SetValue("duck speed", duck);
    Respond("Ducking is now " .. duck)
end

local function spintoggle(args)
    local spin = args[1]

    if spin == nil or not Contains(availableOnOffArguments, spin) then
        Respond("Usage: " .. triggerSymbol .. "spin 1/0 or on/off");
        return;
    end

    if spin == "on" then
        spin = 1;
    elseif spin == "1" then
        spin = 1;
    end

    if spin == "off" then
        spin = 0;
    elseif spin == "0" then
        spin = 0;
    end

    gui.SetValue("Anti aim", spin);
    Respond("Anti-Aim is now " .. spin)
end

--endregion

--region cogcie's Command Additions
-- Store assigned IDs for bots
local botIDStorage = {} -- Table that maps bot names to their IDs

-- Print Name of Self
local function SayName(args)
    local playerIndex = entities.GetLocalPlayer():GetIndex();
    local playerInfo = client.GetPlayerInfo(playerIndex);

    if playerInfo == nil or playerInfo.Name == nil then
        Respond("Could not retrieve player information.");
        return;
    end

    local name = playerInfo.Name;
    Respond("My name is " .. string.gsub(name, "|", " "), true);
end

-- Assign IDs to self after checks
local assignedID = nil -- Variable to store the assigned ID

local function AssignID(args)
    local givenName = table.concat(args, " ", 1, #args - 1);
    local givenID = args[#args];

    if givenName == nil or givenID == nil then
        Respond("Invalid Syntax. Usage: " .. triggerSymbol .. "assign <name> <ID>");
        return;
    end

    local playerIndex = entities.GetLocalPlayer():GetIndex();
    local playerInfo = client.GetPlayerInfo(playerIndex);

    if playerInfo == nil or playerInfo.Name == nil then
        Respond("Could not retrieve player information.");
        return;
    end

    local name = playerInfo.Name;

    if string.lower(name) == string.lower(givenName) then
        botIDStorage[name] = tonumber(givenID);
        assignedID = tonumber(givenID)                         -- Update assignedID for the current bot
        Respond("Assigned ID " .. givenID .. " to player " .. name);
        print("Assigned ID to bot: " .. tostring(assignedID)); -- Debugging message
    end
end

-- Allow bots to return their IDs or Names
local function IdentifyID(args)
    local givenInput = table.concat(args, " ");
    if givenInput == nil then
        Respond("Invalid Syntax. Usage: " .. triggerSymbol .. "identify <name or ID>");
        return;
    end

    local playerIndex = entities.GetLocalPlayer():GetIndex();
    local playerInfo = client.GetPlayerInfo(playerIndex);

    if playerInfo == nil or playerInfo.Name == nil then
        Respond("Could not retrieve player information.");
        return;
    end

    local name = playerInfo.Name;
    local id = botIDStorage[name];

    if tonumber(givenInput) ~= nil then
        -- If the input is a number, check if it's an ID in the botIDStorage
        local found = false
        for botName, botID in pairs(botIDStorage) do
            if tonumber(botID) == tonumber(givenInput) then
                Respond("Bot name for ID " .. givenInput .. " is: " .. botName);
                found = true
                break
            end
        end
        if not found then
            Respond("No bot found with ID: " .. givenInput);
        end
    elseif string.lower(name) == string.lower(givenInput) then
        -- If the input is a name, treat it as such
        if id ~= nil then
            Respond("I am ID value: " .. id);
        else
            Respond("No ID has been assigned yet.");
        end
    else
        print("Input mismatch. Player name is " .. name .. ", but given input is " .. givenInput);
    end
end

-- Command to list all assigned IDs and current classes
local function ListAssignedIDs(args)
    local message = "Assigned IDs and Classes: "

    if next(botIDStorage) == nil then
        botIDStorage = {} -- Initialize botIDStorage if it is nil to avoid errors
    end

    for name, id in pairs(botIDStorage) do
        local currentClass = GetCurrentClassName() -- Get the current class using the new function
        if id == nil then
            id = "N/A"
        end
        message = message .. name .. ": ID " .. id .. ", Class: " .. currentClass .. "  "
    end

    -- Respond in chat
    Respond(message)
    print(message) -- Also print to console for debugging
end

-- Auto-assign IDs to all bots/users based on their index
local function AutoAssignID()
    local playerIndex = entities.GetLocalPlayer():GetIndex()
    local playerInfo = client.GetPlayerInfo(playerIndex)

    -- Ensure we can retrieve the player's information
    if playerInfo == nil or playerInfo.Name == nil then
        Respond("Could not retrieve player information.")
        return
    end

    local name = playerInfo.Name

    -- Check if the player already has an assigned ID
    if botIDStorage[name] == nil then
        botIDStorage[name] =
            playerIndex                                                             -- Assign ID equal to the player's index
        assignedID =
            playerIndex                                                             -- Update the assignedID variable for the current player
        Respond("Automatically assigned ID " .. playerIndex .. " to player " .. name)
        print("Automatically assigned ID " .. playerIndex .. " to player " .. name) -- Debugging message
    else
        Respond("Player " .. name .. " already has an assigned ID: " .. botIDStorage[name])
    end
end

-- Set priority, basically directly from docs
-- Doesn't utilize "assigned IDs" from this script, needs improvement for this reason.
local function SetPlayerPriority(args)
    -- Validate input
    local target = args[1]
    local priority = tonumber(args[2])

    if not target or not priority then
        Respond("Usage: !priority <entity/userID/SteamID> <priority>")
        return
    end

    -- Attempt to determine the type of target and apply the priority
    if tonumber(target) then
        -- Assume the target is a numeric user ID
        local userID = tonumber(target)
        playerlist.SetPriority(userID, priority)
        Respond("Priority set for User ID " .. userID .. " to " .. priority)
    elseif string.match(target, "^%[U:%d:%d+%]$") then
        -- Assume the target is a SteamID
        local steamID = target
        playerlist.SetPriority(steamID, priority)
        Respond("Priority set for Steam ID " .. steamID .. " to " .. priority)
    else
        -- Assume the target is an entity
        local entity = entities.FindByIndex(tonumber(target))
        if entity then
            playerlist.SetPriority(entity, priority)
            Respond("Priority set for entity " .. target .. " to " .. priority)
        else
            Respond("Invalid entity ID: " .. target)
        end
    end
end

-- Retrieve currency from local player
local function GetCurrentPlayerMoney()
    local localPlayer = entities.GetLocalPlayer() -- Get the local player entity
    if localPlayer then
        -- Attempt to retrieve currency property
        local currency = localPlayer:GetPropInt("tflocaldata", "m_nCurrency")
        if currency then
            return currency
        else
            print("Currency property not found.")
            return nil
        end
    else
        print("Local player not found.")
        return nil
    end
end

-- Monitor currency for related commands (VacciBucks, SniperBuyBot)
local function MonitorCurrency()
    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then
        print("Local player not found.")
        return false
    end

    -- Retrieve the current MVM currency
    local currency = localPlayer:GetPropInt("tflocaldata", "m_nCurrency")
    if not currency then
        print("Currency data not found.")
        return false
    end

    print("Current Currency: " .. tostring(currency))

    -- For VacciBucks (Medic)
    if MonitorVacCurrency == true and currency >= 9500 then
        print("Currency limit reached for VacciBucks: " .. currency)
        Respond("Max currency reached (9500). Stopping VacciBucks.")
        return true
    end

    -- For SniperBuyBot
    if MonitorSSCurrency == true then
        -- Check if we've spent enough (at or below 400)
        if currency <= 400 then
            print("Currency spent for SniperBuyBot (hit 400 threshold): " .. currency)
            Respond("Currency spent for SniperBuyBot (hit 400 threshold): " .. currency)
            return true
        end
        -- Check if we started with less than required (9500)
        if currency < 9500 then
            print("Initial currency too low for SniperBuyBot (less than 9500): " .. currency)
            Respond("Initial currency too low for SniperBuyBot (less than 9500): " .. currency)
            return true
        end
    end
    return false
end

-- Interface with vaccibucks.lua
local function MedicBotCommand(args)
    -- Communicate with VacciBucks
    -- Ensure an action is provided
    local action = args[1]
    if not action then
        Respond("Usage: !medicbot <Bot ID> <start|stop>")
        return
    end

    -- Handle actions
    if action == "start" and StartVacciExploit then
        MonitorVacCurrency = true
        -- This isn't pretty. I'm sorry.
        -- Unload and reload the script to ensure that only 1 version is running
        -- Requires preloading in sandbox environments (in my testing)
        local path = os.getenv('localappdata')
        UnloadScript(path .. [[\vaccibucks.lua ]])
        LoadScript(path .. [[\vaccibucks.lua ]])
        -- Switch class to Medic
        client.Command("join_class medic", true)
        Respond("Switched to Medic.")
        StartVacciExploit()

        -- Monitor currency every tick
        callbacks.Register("Draw", "MonitorCurrencyDrawCallback", function()
            if MonitorCurrency() then
                MonitorVacCurrency = false
                StopVacciExploit()
                -- Once the currency limit is reached, unload the script
                UnloadScript(path .. [[\vaccibucks.lua ]])
                callbacks.Unregister("Draw", "MonitorCurrencyDrawCallback")
            end
        end)
    elseif action == "stop" and StopVacciExploit then
        MonitorVacCurrency = false
        local path = os.getenv('localappdata')
        StopVacciExploit()
        -- We don't need to keep the script loaded now
        UnloadScript(path .. [[\vaccibucks.lua ]])
        Respond("Stopped VacciBucks.")
        callbacks.Unregister("Draw", "MonitorCurrency") -- Stop monitoring
    end

    -- Check if VacciBucks is loaded
    if not StartVacciExploit or not StopVacciExploit then
        Respond("Error: VacciBucks is not loaded. Ensure vaccibucks.lua is running")
        return
    end
end

-- Interface with sniperbuybot.lua
local function SniperBuyBot(args)
    local action = args[1]
    if not action then
        Respond("Usage: !sniperbuybot <Bot ID> <start|stop>")
        return
    end

    if action == "start" and StartSSBuybot then
        MonitorSSCurrency = true
        -- Unload and reload the script to ensure that only 1 version is running
        -- Just like the MedicBotCommand
        local path = os.getenv('localappdata')
        UnloadScript(path .. [[\sniperbuybot.lua ]])
        LoadScript(path .. [[\sniperbuybot.lua ]])
        -- Switch class to Sniper
        client.Command("join_class sniper", true)
        Respond("Switched to Sniper.")
        StartSSBuybot()

        callbacks.Register("Draw", "MonitorCurrencyDrawCallback", function()
            if MonitorCurrency() then
                MonitorSSCurrency = false
                StopSSBuybot()
                -- Once the currency limit is reached, unload the script
                UnloadScript(path .. [[\sniperbuybot.lua ]])
                callbacks.Unregister("Draw", "MonitorCurrencyDrawCallback")
            end
        end)
    elseif action == "stop" and StopSSBuybot then
        MonitorSSCurrency = false
        local path = os.getenv('localappdata')
        StopSSBuybot()
        UnloadScript(path .. [[\sniperbuybot.lua ]])
        Respond("Stopped SniperBuyBot.")
    end

    -- Check if SniperBuyBot is loaded
    if not StartSSBuybot or not StopSSBuybot then
        Respond("Error: SniperBuyBot is not loaded. Ensure sniperbuybot.lua is running")
        return
    end
end

-- Basic Help, prints to console or responds in party chat.

--region Later convert to a table of tables for cleaner code.
--[[
-- Define all pages as a table of tables
local helpPages = {
    [1] = {
        "Responding Help Page 1/12.",
        "[Start Commands] - Necessary for multiple bots.",
        "Note: All commands expect a bot ID, designated by <ID>. If no ID (or *) is provided, all bots will respond to the command.",
        "!autoassign <ID> - Assigns all party members an ID based on their index. Recommended to target all (*).",
        "!help <ID> [1-4] - Bot returns specified page in party chat. 4 pages.",
        "!help <ID> [2] - Bot returns table of contents in party chat. Useful to find specific commands.",
        "!chelp <ID> [1-4] - Bot returns table of commands in their OWN console. 4 pages.",
        "!chelp <ID> [2] - Bot returns table of contents in console. Useful to find specific commands."
    },
    [2] = {
        "Responding Help Page 2/12.",
        "[Table of Contents 1]",
        "Page 1: [Start Commands] - Necessary for multiple bots.",
        "Page 2: [Table of Contents 1]",
        "Page 3: [Table of Contents 2]",
        "Page 4: [Information Retrieval] - Get key information about bots.",
        "Page 5: [Bot Communication] - Make your bot say things.",
        "Page 6: [Bot Management 1] - Commands that allow the hoster (or party members) to manage bots."
    },
    -- Add additional pages here...
}
-- Function to format a help message with prefix
local function formatHelpMessage(page, message)
    return string.format("[H:%d] %s", page, message)
end

-- Function to generate messages for a given page
local function DisplayHelpPage(page, useRespond)
    local pageContent = helpPages[page]
    if not pageContent then
        if useRespond then
            Respond("Invalid page number. Please use !help 1-12.")
        else
            print("Invalid page number. Please use !chelp 1-12.")
        end
        return
    end

    for _, message in ipairs(pageContent) do
        local messages = {}
        table.insert(messages, formatHelpMessage(page, message))
    end
end
]] --
--endregion

--region Initial help implementation
-- clunky, but it works for now
local function DisplayHelpPage(page, useRespond)
    local messages = {}

    -- Append page to the messages table
    local function formatHelpMessage(page, message)
        return string.format("[H:%d] %s", page, message)
    end

    -- Add messages for page 1
    if page == 1 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages, formatHelpMessage(page, "[Start Commands] - Necessary for multiple bots."))
        table.insert(messages,
            formatHelpMessage(page,
                "Note: All commands expect a bot ID, designated by <ID>. If no ID (or *) is provided, all bots will respond to the command."))
        table.insert(messages,
            formatHelpMessage(page,
                "!autoassign <ID> - Assigns all party members an ID based on their index. Recommended to target all (*)."))
        table.insert(messages,
            formatHelpMessage(page, "!help <ID> [1-4] - Bot returns specified page in party chat. 4 pages."))
        table.insert(messages,
            formatHelpMessage(page,
                "!help <ID> [2] - Bot returns table of contents in party chat. Useful to find specific commands."))
        table.insert(messages,
            formatHelpMessage(page, "!chelp <ID> [1-4] - Bot returns table of commands in their OWN console. 4 pages."))
        table.insert(messages,
            formatHelpMessage(page,
                "!chelp <ID> [2] - Bot returns table of contents in console. Useful to find specific commands."))
        -- Add messages for page 2
    elseif page == 2 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages, formatHelpMessage(page, "[Table of Contents 1]"))
        table.insert(messages, formatHelpMessage(page, "Page 1: [Start Commands] - Necessary for multiple bots."))
        table.insert(messages, formatHelpMessage(page, "Page 2: [Table of Contents 1]"))
        table.insert(messages, formatHelpMessage(page, "Page 3: [Table of Contents 2]"))
        table.insert(messages,
            formatHelpMessage(page, "Page 4: [Information Retrieval] - Get key information about bots."))
        table.insert(messages, formatHelpMessage(page, "Page 5: [Bot Communication] - Make your bot say things."))
        table.insert(messages,
            formatHelpMessage(page,
                "Page 6: [Bot Management 1] - Commands that allow the hoster (or party members) to manage bots."))
        -- Add messages for page 3
    elseif page == 3 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages, formatHelpMessage(page, "[Table of Contents 2]"))
        table.insert(messages,
            formatHelpMessage(page,
                "Page 7: [Bot Management 2] - Commands that allow the hoster (or party members) to manage bots."))
        table.insert(messages,
            formatHelpMessage(page,
                "Page 8: [Bot Spam] - Commands that annoy the lobby or negatively impact other player experiences."))
        table.insert(messages,
            formatHelpMessage(page, "Page 9: [Game Interactions 1] - Commands to modify what the bot is doing in game."))
        table.insert(messages,
            formatHelpMessage(page, "Page 10: [Game Interactions 2] - Commands to modify what the bot is doing in game."))
        table.insert(messages,
            formatHelpMessage(page,
                "Page 11: [Server & Player Interaction 1] - Connect your bots and modify their interactions with players."))
        table.insert(messages,
            formatHelpMessage(page,
                "Page 12: [Server & Player Interaction 2] - Connect your bots and modify their interactions with players."))
        -- Add messages for page 4
    elseif page == 4 then
        table.insert(messages, formatHelpMessage(page, "[Information Retrieval] - Get key information about bots."))
        table.insert(messages,
            formatHelpMessage(page,
                "!autoassign <ID> - Assigns all party members an ID based on their index. Recommended to target all (*)."))
        table.insert(messages,
            formatHelpMessage(page,
                "!list <ID> - Lists all active bots and their current status. Recommended to target all (*)."))
        table.insert(messages,
            formatHelpMessage(page,
                "!identify [name] - Identify a name to an ID. No ID argument necessary Arguments: player name."))
        table.insert(messages,
            formatHelpMessage(page, "!assign <name> [ID] - Assign an ID to a bot. Arguments: bot name and desired ID."))
        table.insert(messages,
            formatHelpMessage(page, "!name <ID> - Prints the usable name of a bot. Recommended to target all (*)."))
        table.insert(messages, formatHelpMessage(page, "!money <ID> - Bot responds with current MVM currency value."))

        -- Add messages for page 5
    elseif page == 5 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages, formatHelpMessage(page, "[Bot Communication] - Make your bot say things."))
        table.insert(messages,
            formatHelpMessage(page,
                "!say, !say_team, !say_party <ID> [msg] - Says text to the corresponding channel. You can use \"|\" as a space character. \"Hello|World\" will be printed as \"Hello World\" in chat."))
        table.insert(messages,
            formatHelpMessage(page, "!speak <ID> - Turns on microphone for mic spamming. No Arguments."))
        table.insert(messages, formatHelpMessage(page, "!shutup <ID> - Turns off microphone. No Arguments."))
        table.insert(messages,
            formatHelpMessage(page,
                "!cspam <ID> [arg] - Change the chatspam type and period. Arguments: none/branded/custom or a number 1-60."))
        table.insert(messages,
            formatHelpMessage(page, "!nmaker <ID> [1|0] - Toggle noisemaker spam. Arguments: 1/0 or on/off."))

        -- Add messages for page 6
    elseif page == 6 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page, "[Game Interactions 1] - Commands to modify what the bot is doing in game."))
        table.insert(messages,
            formatHelpMessage(page,
                "!slot <ID> [arg] - Changes the current weapon. Arguments: 1-X, between 1 and however many slots there are on that class."))
        table.insert(messages,
            formatHelpMessage(page,
                "!class <ID> [arg] - Changes the current class. Arguments: Name of the class. \"Random\" also works."))
        table.insert(messages, formatHelpMessage(page, "!kill <ID> - Suicide. No Arguments."))
        table.insert(messages, formatHelpMessage(page, "!explode <ID> - Suicide by explosion. No Arguments."))
        table.insert(messages,
            formatHelpMessage(page, "!lout <ID> [arg] - Change the current loadout. Arguments: a/b/c/d or 1/2/3/4."))

        -- Add messages for page 7
    elseif page == 7 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page, "[Game Interactions 2] - Commands to modify what the bot is doing in game."))
        table.insert(messages, formatHelpMessage(page, "!taunt <ID> - Bot will execute a taunt. No Arguments."))
        table.insert(messages,
            formatHelpMessage(page,
                "!tauntn <ID> [tname] - Bot will execute a taunt by name. Example: \"!tauntn 4 Taunt: The Schadenfreude\"."))
        table.insert(messages, formatHelpMessage(page, "!spin <ID> [1|0] - Toggle anti-aim. Arguments: on/off or 1/0."))
        table.insert(messages,
            formatHelpMessage(page, "!duck <ID> [1|0] - Toggle ducking & duck speed. Arguments: on/off or 1/0."))
        table.insert(messages,
            formatHelpMessage(page,
                "!zd <ID> [1|0] [#] - aka Zoom Distance. Arguments: on/off or 1/0 and a distance. Example: \"!zd 1 600\"."))
        table.insert(messages,
            formatHelpMessage(page,
                "!autom <ID> [1|0] [#] - aka Auto-melee. Arguments: on/off or 1/0 and a distance. Example: \"!autom on 500\"."))

        -- Add messages for page 8
    elseif page == 8 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page,
                "[Bot Management 1] - Commands that allow the hoster (or party members) to manage bots."))
        table.insert(messages,
            formatHelpMessage(page,
                "!list <ID> - Lists all active bots and their current status. Recommended to target all (*)."))
        table.insert(messages,
            formatHelpMessage(page, "!fbot <ID> [arg] - Switch the follow bot type. Arguments: stop/friends/all."))
        table.insert(messages,
            formatHelpMessage(page, "!lout <ID> [arg] - Change the current loadout. Arguments: a/b/c/d or 1/2/3/4."))
        table.insert(messages,
            formatHelpMessage(page,
                "!owneronly <ID> [1|0] - Toggle if only the owner of the party should be able to command the bots. Arguments: 1/0 or true/false."))
        table.insert(messages,
            formatHelpMessage(page,
                "!ignorefriends <ID> [1|0] - Toggle if the bots should ignore people it has friended on steam/people that are in the party. Arguments: 1/0 or true/false."))

        -- Add messages for page 9
    elseif page == 9 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page,
                "[Bot Management 2] - Commands that allow the hoster (or party members) to manage bots."))
        table.insert(messages,
            formatHelpMessage(page,
                "!console <ID> [command] - Sends the console command provided into the console of the bots. Arguments: the name of the console command."))
        table.insert(messages,
            formatHelpMessage(page,
                "!medicbot <ID> [start|stop] - Enable Vaccibucks to exploit MVM currency amounts. Vaccibucks.lua required."))
        table.insert(messages,
            formatHelpMessage(page,
                "!sniperbuybot <ID> [start|stop] - Enable Buybot. Switches bot to Sniper and upgrades Hitman's Heatmaker. Sniperbuybot.lua required."))
        table.insert(messages,
            formatHelpMessage(page,
                "!leave <ID> - Abandons the game and doesn't do the automatically rejoining thing. No Arguments."))

        -- Add messages for page 10
    elseif page == 10 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page,
                "[Bot Spam] - Commands that annoy the lobby or negatively impact other player experiences."))
        table.insert(messages,
            formatHelpMessage(page,
                "!autovotekick <ID> [1|0] - Automatically call votes on teammates. Arguments: 1/0 or on/off."))
        table.insert(messages,
            formatHelpMessage(page,
                "!cspam <ID> [arg] - Change the chatspam type and period. Arguments: none/branded/custom or a number 1-60."))
        table.insert(messages,
            formatHelpMessage(page, "!nmaker <ID> [1|0] - Toggle noisemaker spam. Arguments: 1/0 or on/off."))

        -- Add messages for page 11
    elseif page == 11 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page,
                "[Server & Player Interaction 1] - Connect your bots and modify their interactions with players."))
        table.insert(messages,
            formatHelpMessage(page,
                "!connect <ID> [IP] - Connects all the bots to a server via IP. Example: \"!connect 172.0.0.1:1234\""))
        table.insert(messages,
            formatHelpMessage(page,
                "!ignorefriends <ID> [1|0] - Toggle if the bots should ignore people it has friended on steam/people that are in the party. Arguments: 1/0 or true/false."))
        table.insert(messages,
            formatHelpMessage(page,
                "!leave <ID> - Abandons the game and doesn't do the automatically rejoining thing. No Arguments."))

        -- Add messages for page 12
    elseif page == 12 then
        table.insert(messages, string.format("Responding Help Page %d/12.", page))
        table.insert(messages,
            formatHelpMessage(page,
                "[Server & Player Interaction 2] - Connect your bots and modify their interactions with players."))
        table.insert(messages,
            formatHelpMessage(page,
                "!console <ID> [command] - Sends the console command provided into the console of the bots. Arguments: the name of the console command."))
        table.insert(messages,
            formatHelpMessage(page,
                "!autovotekick <ID> [1|0] - Automatically call votes on teammates. Arguments: 1/0 or on/off."))
        table.insert(messages,
            formatHelpMessage(page,
                "!priority <ID> [type] [prio] - Assigns playerlist priority of an entity/userID/SteamID to the priority number. Use status for userIDs."))
    else
        if useRespond then
            Respond("Invalid page number. Please use !help 1-4.")
        else
            print("Invalid page number. Please use !chelp 1-4.")
        end
        return
    end

    if useRespond then
        -- Ensure the callback is not already registered
        callbacks.Unregister("Draw", "processNextMessageCallback") -- Safely unregister any existing instance

        -- Initialize state variables
        local currentIndex = 1
        local lastSendTime = globals.CurTime()
        local sendDelay = 0.5

        -- Function to process the next message
        local function processNextMessage()
            local currentTime = globals.CurTime()

            -- Check if enough time has passed since the last message
            if currentTime >= lastSendTime + sendDelay then
                if currentIndex <= #messages then
                    Respond(messages[currentIndex]) -- Send the current message
                    currentIndex = currentIndex + 1 -- Move to the next message
                    lastSendTime = currentTime      -- Update the last send time
                end
            end

            -- Unregister the callback if all messages are processed
            if currentIndex > #messages then
                callbacks.Unregister("Draw", "processNextMessageCallback")
            end
        end

        -- Register the callback once
        callbacks.Register("Draw", "processNextMessageCallback", processNextMessage)
    else
        -- If not using Respond, just print all messages immediately
        for _, message in ipairs(messages) do
            print(message)
        end
    end
end
--endregion

-- Command handler for !help command
local function HelpCommand(commandArgs)
    local page = tonumber(commandArgs[1]) or 1
    DisplayHelpPage(page, true)
end

-- Command for console help, !chelp
local function CHelpCommand(commandArgs)
    local page = tonumber(commandArgs[1]) or 1
    DisplayHelpPage(page, false)
end

--endregion

--region cogcie's ID Assignment handler
-- Helper function to parse IDs from command arguments
local function ParseIDs(arg)
    local ids = {}
    print("Parsing argument: " .. arg)

    if arg:find(",") then
        -- Handle comma-separated IDs (e.g., "1,3,5")
        print("Detected comma-separated IDs")
        for id in arg:gmatch("%d+") do
            print("Found ID: " .. id)
            table.insert(ids, tonumber(id))
        end
    elseif arg:find("-") then
        -- Handle range of IDs (e.g., "1-4")
        print("Detected range of IDs")
        local startID, endID = arg:match("(%d+)%-(%d+)")
        startID, endID = tonumber(startID), tonumber(endID)
        if startID and endID then
            print("Range start: " .. startID .. ", Range end: " .. endID)
            for id = startID, endID do
                print("Adding ID from range: " .. id)
                table.insert(ids, id)
            end
        else
            print("Invalid range provided")
        end
    else
        -- Single ID
        local singleID = tonumber(arg)
        print("Detected single ID: " .. (singleID or "Invalid"))
        table.insert(ids, singleID)
    end

    print("Parsed IDs: " .. table.concat(ids, ", "))
    return ids
end

-- Helper function to check if the bot should execute based on ID
local function ShouldExecuteForID(targetIDs)
    if assignedID == nil then return true end -- If no ID is assigned, assume it applies
    for _, id in ipairs(targetIDs) do
        if assignedID == id then
            return true
        end
    end
    return false
end
--endregion

--endregion

--region == Game Event Handlers ==
local function newmap_event(event) --reset what ever data we want to reset when we switch maps
    if (event:GetName() == "game_newmap") then
        timer = 0
        IsInRange = false;
        CurrentClosestX = nil
        CurrentClosestY = nil
        closestplayer = nil;
    end
end

-- This method is an inventory enumerator. Used to search for mediguns in the inventory.
local function EnumerateInventory(item)
    -- Broken for now. Will fix later.

    local itemName = item:GetName();
    local itemDefIndex = item:GetDefIndex();

    if Contains(medigunTypedefs.default, itemDefIndex) then
        -- We found a default medigun.
        --foundMediguns.default = item:GetItemId();
        local id = item:GetItemId();
    end

    if Contains(medigunTypedefs.quickfix, itemDefIndex) then
        -- We found a quickfix.
        -- foundMediguns.quickfix = item:GetItemId();
        local id = item:GetItemId();
    end

    if Contains(medigunTypedefs.kritz, itemDefIndex) then
        -- We found a kritzkrieg.
        --foundMediguns.kritz = item:GetItemId();
        local id = item:GetItemId();
    end
end

-- Registers new command.
-- 'commandName' is a command name
-- 'callback' is a function that's called when command is executed.
local function RegisterCommand(commandName, callback)
    if commands[commandName] ~= nil then
        error("Command with name " .. commandName .. " was already registered!");
        return; -- just in case, idk if error() acts as an exception -- it does act as an exception original author.
    end

    commands[commandName] = callback;
end

-- Game event processor
local function FireGameEvent(event)
    -- Validation.
    -- Checking if we've received a party_chat event.
    if event:GetName() ~= partyChatEventName then
        return;
    end

    -- Checking a message type. Should be k_eTFPartyChatType_MemberChat.
    if event:GetInt("type") ~= k_eTFPartyChatType_MemberChat then
        return;
    end

    local partyMessageText = event:GetString("text");

    -- Checking if message starts with a trigger symbol.
    if string.sub(partyMessageText, 1, 1) ~= triggerSymbol then
        return;
    end

    if lobbyOwnerOnly then
        -- Validating that message sender actually owns this lobby
        local senderId = SteamID64ToSteamID3(event:GetString("steamid"));

        if party.GetLeader() ~= senderId then
            return;
        end
    end

    -- Parsing the command
    local fullCommand = string.lower(string.sub(partyMessageText, 2, #partyMessageText));
    commandArgs = SplitString(fullCommand);

    -- Validating if we know this command
    local commandName = commandArgs[1];
    local commandCallback = commands[commandName];

    if commandCallback == nil then
        Respond("Unknown command [" .. commandName .. "]");
        return;
    end

    -- Removing command name
    table.remove(commandArgs, 1);

    -- Check for IDs in the command arguments
    local targetIDs = {}
    if commandArgs[1] == "*" then
        -- If * is used, target all bots
        for botName, _ in pairs(botIDStorage) do
            table.insert(targetIDs, botIDStorage[botName])
        end
        table.remove(commandArgs, 1)
    elseif commandArgs[1] and tonumber(commandArgs[1]) then
        targetIDs = ParseIDs(commandArgs[1])
        table.remove(commandArgs, 1)
    elseif commandArgs[1] and string.find(commandArgs[1], "%d") then
        targetIDs = ParseIDs(commandArgs[1])
        table.remove(commandArgs, 1)
    end

    -- Print information about the command and the IDs for debugging
    print("Received command: " .. commandName)

    if #targetIDs > 0 then
        print("Target IDs specified in the command: " .. table.concat(targetIDs, ", "))
    else
        print("No specific target ID provided; default behavior will apply.")
    end

    -- Decide whether to execute the command based on ID match
    if #targetIDs == 0 then
        -- No IDs provided or * used; execute command for everyone
        print("No target IDs provided. Proceeding to execute the command.")
        print("My Current ID: " .. tostring(assignedID))
        commandCallback(commandArgs);
    elseif ShouldExecuteForID(targetIDs) then
        -- Execute command if the assigned ID matches one of the target IDs
        print("Executing command for matching assigned ID: " .. tostring(assignedID))
        commandCallback(commandArgs);
    else
        -- Do not execute the command if the ID doesn't match
        print("Assigned ID did not match the target IDs; command will not be executed.")
    end
end
--endregion

--region == Command List & Draw UI ==
local function Initialize()
    --region null's commands
    -- Suicide commands
    RegisterCommand("kill", KillCommand);
    RegisterCommand("explode", ExplodeCommand);

    -- Switching things
    RegisterCommand("slot", SwitchWeapon);
    RegisterCommand("class", SwitchClass);

    -- Saying things
    RegisterCommand("say", Say);
    RegisterCommand("say_team", SayTeam);
    RegisterCommand("say_party", SayParty);

    -- Taunting
    RegisterCommand("taunt", Taunt);
    RegisterCommand("tauntn", TauntByName);

    -- Attacking
    --RegisterCommand("attack", Attack); even more useless than Connect

    -- Registering event callback
    callbacks.Register("FireGameEvent", FireGameEvent);

    -- Broken for now! Will fix later.
    --inventory.Enumerate(EnumerateInventory);
    --endregion

    --region Dr_Coomer's commands
    -- Switch Follow Bot
    RegisterCommand("fbot", FollowBotSwitcher);

    -- Switch Loadout
    RegisterCommand("lout", LoadoutChanger);

    -- Toggle Owner Only Mode
    RegisterCommand("owneronly", TogglelobbyOwnerOnly);

    -- Connect to server via IP
    RegisterCommand("connect", Connect);

    -- Toggle Ignore Friends
    RegisterCommand("ignorefriends", ToggleIgnoreFriends);

    -- Switch chat spam
    RegisterCommand("cspam", cspam);

    -- Mic Spam toggle
    RegisterCommand("speak", Speak);
    RegisterCommand("shutup", Shutup);
    callbacks.Register("FireGameEvent", MicSpam);

    --Toggle noisemaker
    RegisterCommand("nmaker", noisemaker)

    --Autovoting
    RegisterCommand("autovotekick", autovotekick)
    callbacks.Register("Draw", "autocastvote", autocastvote)
    callbacks.Register("DispatchUserMessage", "responsecheck_message", responsecheck_message)

    --Zoom Distance
    RegisterCommand("zd", zoomdistance)
    callbacks.Register("CreateMove", "GetPlayerLocations", GetPlayerLocations)

    --Auto melee
    callbacks.Register("CreateMove", "AutoMelee", AutoMeleeAimbot)
    RegisterCommand("autom", AutoMelee)

    --Auto unzoom
    callbacks.Register("CreateMove", "unzoom", AutoUnZoom)

    --New Map Event
    callbacks.Register("FireGameEvent", "newmap_event", newmap_event)
    --endregion

    --region StoreMilk's commands
    RegisterCommand("leave", Leave);
    RegisterCommand("console", Console);
    --endregion

    --region thyraxis's commands
    -- Duck Speed
    RegisterCommand("duck", ducktoggle)
    -- Spin
    RegisterCommand("spin", spintoggle)
    --endregion

    --region cogcie's commands
    -- Print Bot Name
    RegisterCommand("name", SayName);

    -- Registering new command for assigning ID
    RegisterCommand("assign", AssignID);

    -- Registering new command for identifying ID
    RegisterCommand("identify", IdentifyID);

    -- Register the !list command
    RegisterCommand("list", ListAssignedIDs)

    -- Registering new command for auto-assigning ID
    RegisterCommand("autoassign", AutoAssignID);

    -- Register the !help command
    RegisterCommand("help", HelpCommand)

    -- Register the !chelp command (console help)
    RegisterCommand("chelp", CHelpCommand)

    -- Register the !priority command
    RegisterCommand("priority", SetPlayerPriority)

    -- Register the !medicbot command
    RegisterCommand("medicbot", MedicBotCommand)

    -- Register the !sniperbuybot command
    RegisterCommand("sniperbuybot", SniperBuyBot)

    -- Command to display the current MVM money
    RegisterCommand("money", function()
        -- Log the command execution
        print("Executing command 'money' to get MVM currency...")

        -- Get the player's current MVM money
        local money, err = GetCurrentPlayerMoney()

        -- Log whether the money retrieval was successful or not
        if err then
            print("ERROR: " .. err)
            Respond(err)
        else
            print("SUCCESS: Player has collected " .. money .. " MVM currency.")
            Respond("You have collected " .. money .. " MVM currency.")
        end
    end)
    --endregion

    --region Draw UI from vacbux
    local watermarkX, watermarkY = 20, 20 -- Set initial position for draggable UI
    local isDragging = false
    local dragOffsetX, dragOffsetY = 0, 0


    callbacks.Register("Draw", function()
        local offsetX, offsetY = 40, 40
        local paddingX, paddingY = 10, 5
        local baseText = "Multibox Helper |"
        local botIDText = assignedID and ("Bot ID: " .. assignedID) or "Bot ID: Unassigned"
        local playerIndex = entities.GetLocalPlayer() and entities.GetLocalPlayer():GetIndex() or nil
        local playerInfo = playerIndex and client.GetPlayerInfo(playerIndex) or
            nil -- Get player information using client function
        local playerName = playerInfo and playerInfo.Name or "Unknown Player"
        local exploitingText = " (Active)"

        local finalBaseText = isExploiting and (baseText .. exploitingText) or baseText

        local fullText = finalBaseText .. " " .. botIDText .. " | Player: " .. playerName

        draw.SetFont(UI.mainFont)
        local textWidth, textHeight = draw.GetTextSize(fullText)

        local barWidth = textWidth + (paddingX * 2)
        local barHeight = textHeight + (paddingY * 4)
        local barX = offsetX
        local barY = offsetY

        draw.Color(0, 0, 0, 178)
        draw.FilledRect(watermarkX, watermarkY, watermarkX + barWidth, watermarkY + barHeight)

        draw.Color(UI.colors.accent[1], UI.colors.accent[2], UI.colors.accent[3], 255)
        draw.FilledRect(watermarkX, watermarkY, watermarkX + barWidth, watermarkY + 2)

        draw.Color(UI.colors.text[1], UI.colors.text[2], UI.colors.text[3], 255)
        draw.Text(watermarkX + 10, watermarkY + 10, fullText)


        local currentTime = globals.CurTime()

        -- Mouse Logic Start
        -- Handle dragging
        local mouse = {
            x = input.GetMousePos()[1],
            y = input.GetMousePos()[2]
        }

        local mousePos = { input.GetMousePos() }
        local mouseX, mouseY = mousePos[1], mousePos[2]
        local screenWidth, screenHeight = draw.GetScreenSize()

        if input.IsButtonDown(MOUSE_LEFT) then
            if isDragging then
                watermarkX = mouse.x - dragOffsetX
                watermarkY = mouse.y - dragOffsetY

                if watermarkX < 0 then
                    watermarkX = 0
                elseif watermarkX + barWidth > screenWidth then
                    watermarkX = screenWidth - barWidth
                end

                if watermarkY < 0 then
                    watermarkY = 0
                elseif watermarkY + barHeight > screenHeight then
                    watermarkY = screenHeight - barHeight
                end
            else
                if mouse.x >= watermarkX and mouse.x <= (watermarkX + barWidth) and
                    mouse.y >= watermarkY and mouse.y <= (watermarkY + barHeight) then
                    isDragging = true
                    dragOffsetX = mouse.x - watermarkX
                    dragOffsetY = mouse.y - watermarkY
                end
            end
        else
            isDragging = false
        end
        -- Mouse Logic End

        for i = #UI.notifications, 1, -1 do
            local notif = UI.notifications[i]
            local age = currentTime - notif.time

            if age < 0.2 then
                notif.alpha = math.min(notif.alpha + 25, 255)
            elseif age > UI.notificationLifetime - 0.3 then
                notif.alpha = math.max(notif.alpha - 25, 0)
            end

            if age >= UI.notificationLifetime and notif.alpha <= 0 then
                table.remove(UI.notifications, i)
            elseif notif.alpha >= 55 then
                DrawNotification(notif, barX,
                    barY + barHeight + 10 + (i - 1) * (UI.notificationHeight + UI.notificationSpacing))
            end
        end
    end)
    --endregion
end
--endregion

Initialize();