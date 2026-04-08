-- RestZoneMusic.lua
--
-- Plays a random WoW music track whenever the player enters a rest area
-- (inn or capital city). Uses FileDataIDs — the only valid input for
-- PlayMusic() in retail since patch 8.2.0.
--
-- PlayMusic(id)  : overrides zone music with the given FileDataID.
-- StopMusic()    : stops the override; game resumes zone music on its own.
-- IsResting()    : returns true when inside an inn or capital city.
-- PLAYER_UPDATE_RESTING : fires on every resting state transition.
--
-- FileDataID source: https://wow.tools/files/#search=sound/music
-- Filter by file extension .ogg, type "Sound", path contains "Music".
-- IMPORTANT: IDs below are a curated sample. Verify each one on wow.tools
-- before distributing. PlayMusic() fails silently on invalid IDs.

local ADDON_NAME = "RestZoneMusic"

-- ============================================================
-- CONFIG
-- ============================================================

-- Seconds between automatic track rotations while resting.
-- WoW music tracks range roughly 1–5 minutes; 240s is a safe default.
local ROTATION_INTERVAL = 240

-- Print the playing FileDataID to chat (useful for building/debugging the list).
local ANNOUNCE_TRACK = false

-- ============================================================
-- TRACK POOL  (FileDataIDs)
-- Expand this list using https://wow.tools/files/#search=sound/music
-- ============================================================
local MUSIC_IDS = {
    -- Classic city/zone themes
    53183,   -- Elwynn Forest
    53184,   -- Stormwind City
    53185,   -- Ironforge
    53186,   -- Darnassus
    53187,   -- Orgrimmar
    53188,   -- Thunder Bluff
    53189,   -- Undercity
    -- Inn / tavern ambient music (verify IDs on wow.tools)
    53323,
    53324,
    -- TBC
    53300,   -- Shattrath City (verify)
    -- WotLK
    116289,  -- Dalaran (Northrend)
    -- Legion
    731548,  -- Dalaran (Broken Isles) (verify)
    -- BfA
    1098785, -- Boralus (verify)
    1098786, -- Zuldazar (verify)
    -- Add more IDs here from wow.tools as needed
}

-- ============================================================
-- STATE
-- ============================================================
local lastIndex    = nil   -- index of the last played track, to avoid immediate repeat
local rotationTick = nil   -- C_Timer.NewTicker handle

-- ============================================================
-- CORE
-- ============================================================

local function PickIndex()
    if #MUSIC_IDS == 0 then return nil end
    if #MUSIC_IDS == 1 then return 1 end
    local idx
    repeat
        idx = math.random(1, #MUSIC_IDS)
    until idx ~= lastIndex
    return idx
end

local function PlayRandomTrack()
    local idx = PickIndex()
    if not idx then return end
    lastIndex = idx
    local id = MUSIC_IDS[idx]
    PlayMusic(id)
    if ANNOUNCE_TRACK then
        print(string.format("|cff88ccff[RestZoneMusic]|r Playing FileDataID: %d", id))
    end
end

local function StartRotation()
    -- Cancel any existing ticker before creating a new one.
    if rotationTick then
        rotationTick:Cancel()
        rotationTick = nil
    end
    PlayRandomTrack()
    -- NewTicker fires repeatedly every ROTATION_INTERVAL seconds.
    rotationTick = C_Timer.NewTicker(ROTATION_INTERVAL, function()
        if IsResting() then
            PlayRandomTrack()
        else
            -- Guard: resting state ended during a tick interval.
            StopMusic()
            rotationTick:Cancel()
            rotationTick = nil
        end
    end)
end

local function StopRotation()
    StopMusic()
    if rotationTick then
        rotationTick:Cancel()
        rotationTick = nil
    end
end

-- ============================================================
-- SLASH COMMAND  /rzm
-- ============================================================
SLASH_RESTZONEMUSICL1 = "/rzm"
SlashCmdList["RESTZONEMUSICL"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "skip" then
        if IsResting() then
            -- Restart the ticker so the interval resets from now.
            StartRotation()
            print("|cff88ccff[RestZoneMusic]|r Skipped to next track.")
        else
            print("|cff88ccff[RestZoneMusic]|r Not in a rest area.")
        end
    elseif cmd == "stop" then
        StopRotation()
        print("|cff88ccff[RestZoneMusic]|r Stopped. Zone music restored.")
    elseif cmd == "announce" then
        ANNOUNCE_TRACK = not ANNOUNCE_TRACK
        print("|cff88ccff[RestZoneMusic]|r Track announcements: " .. (ANNOUNCE_TRACK and "ON" or "OFF"))
    elseif cmd == "list" then
        print(string.format("|cff88ccff[RestZoneMusic]|r %d tracks in pool:", #MUSIC_IDS))
        for i, id in ipairs(MUSIC_IDS) do
            print(string.format("  [%d] FileDataID %d", i, id))
        end
    elseif cmd == "status" then
        print("|cff88ccff[RestZoneMusic]|r Resting: " .. tostring(IsResting()))
        print("|cff88ccff[RestZoneMusic]|r Ticker active: " .. tostring(rotationTick ~= nil))
        if lastIndex then
            print(string.format("|cff88ccff[RestZoneMusic]|r Last played: FileDataID %d", MUSIC_IDS[lastIndex]))
        end
    else
        print("|cff88ccff[RestZoneMusic]|r /rzm commands:")
        print("  skip     - play next random track immediately")
        print("  stop     - stop addon music, restore zone music")
        print("  announce - toggle FileDataID printout on each change")
        print("  list     - print all FileDataIDs in the pool")
        print("  status   - show current state")
    end
end

-- ============================================================
-- EVENTS
-- ============================================================
local frame = CreateFrame("Frame", ADDON_NAME .. "_Frame", UIParent)
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Handle the case where the player logs in already inside an inn.
        if IsResting() then
            StartRotation()
        end
    elseif event == "PLAYER_UPDATE_RESTING" then
        if IsResting() then
            -- Only start if not already running, to prevent restart on
            -- sub-zone changes inside the same inn.
            if not rotationTick then
                StartRotation()
            end
        else
            StopRotation()
        end
    end
end)
