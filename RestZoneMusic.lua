local ADDON_NAME = "RestZoneMusic"

local AceConfig = assert(LibStub("AceConfig-3.0", true), "RestZoneMusic: Falla crítica. AceConfig-3.0 no está cargado.")
local AceConfigDialog = assert(LibStub("AceConfigDialog-3.0", true), "RestZoneMusic: Falla crítica. AceConfigDialog-3.0 no está cargado.")
local ldb = assert(LibStub("LibDataBroker-1.1", true), "RestZoneMusic: Falla crítica. LibDataBroker-1.1 no está cargado.")
local icon = assert(LibStub("LibDBIcon-1.0", true), "RestZoneMusic: Falla crítica. LibDBIcon-1.0 no está cargado.")

math.random()
math.random()
math.random()

RestZoneMusicDB = RestZoneMusicDB or {}
local db
local ticker
local isPlaying = false
local pendingPlay = false

local DEFAULTS = {
    enabled = true,
    timerInterval = 180,
    lastIndex = 0,
}

local TRACKS = {
    -- Classic
    53183, 53184, 53185, 53186, 53187, 53188, 53189, 53190, 53191, 53192,
    53193, 53194, 53195, 53196, 53197, 53198, 53199, 53200, 53201, 53202,
    53203, 53204, 53323, 53324, 53325, 53326, 53327, 53328, 53329, 53330,
    53331, 53332, 53333, 53334, 53335, 53336, 53337, 53338, 53339, 53340,

    -- The Burning Crusade
    53300, 53301, 53302, 53303, 53304, 53305, 53306, 53307, 53308, 53309, 53310,

    -- Wrath of the Lich King
    116289, 116290, 116291, 116292, 116293, 116294, 116295,

    -- Cataclysm
    402589, 402590, 402591, 402592,

    -- Mists of Pandaria
    551820, 551821, 551822, 551823, 551824, 551825, 551826, 551827,

    -- Warlords of Draenor
    641804, 641805, 641806, 641807, 641808, 641809, 641810, 642878,

    -- Legion
    731548, 731549, 731550, 731551, 731552, 731553, 731554, 731555, 731556,

    -- Battle for Azeroth
    1098785, 1098786, 1098787, 1098788, 1098789, 1098790, 1098791, 1098792,
    1098793, 1098794, 1098795, 1098796, 1098797, 1098798,

    -- Shadowlands
    3418179, 3418180, 3418181, 3418182, 3418183, 3418184, 3418185, 3418186,
    3418187, 3418188, 3418189,

    -- Dragonflight
    4013993, 4013994, 4013995, 4013996, 4013997, 4013998, 4013999, 4014000,
    4014001, 4014002, 4014003, 4014004, 4014005,

    -- The War Within
    5341735, 5341736, 5341737, 5341738, 5341739, 5341740, 5341741, 5341742,

    -- Additional Tracks
    642866, 642867, 642868, 1390342, 1390344, 2005952, 2005953, 2005954,
    4622170, 4622171, 5341743, 5341744
}

local TRACK_NAMES = {
    [53183] = "Classic Inn 1", [53184] = "Classic Inn 2", [53185] = "Classic Inn 3", [53186] = "Classic Inn 4", [53187] = "Classic Inn 5",
    [53188] = "Classic Inn 6", [53189] = "Classic Inn 7", [53190] = "Classic Inn 8", [53191] = "Classic Inn 9", [53192] = "Classic Inn 10",
    [53193] = "Classic Inn 11", [53194] = "Classic Inn 12", [53195] = "Classic Inn 13", [53196] = "Classic Inn 14", [53197] = "Classic Inn 15",
    [53198] = "Classic Inn 16", [53199] = "Classic Inn 17", [53200] = "Classic Inn 18", [53201] = "Classic Inn 19", [53202] = "Classic Inn 20",
    [53203] = "Classic Inn 21", [53204] = "Classic Inn 22", [53323] = "Classic Inn 23", [53324] = "Classic Inn 24", [53325] = "Classic Inn 25",
    [53326] = "Classic Inn 26", [53327] = "Classic Inn 27", [53328] = "Classic Inn 28", [53329] = "Classic Inn 29", [53330] = "Classic Inn 30",
    [53331] = "Classic Inn 31", [53332] = "Classic Inn 32", [53333] = "Classic Inn 33", [53334] = "Classic Inn 34", [53335] = "Classic Inn 35",
    [53336] = "Classic Inn 36", [53337] = "Classic Inn 37", [53338] = "Classic Inn 38", [53339] = "Classic Inn 39", [53340] = "Classic Inn 40",

    [53300] = "TBC Inn 1", [53301] = "TBC Inn 2", [53302] = "TBC Inn 3", [53303] = "TBC Inn 4", [53304] = "TBC Inn 5",
    [53305] = "TBC Inn 6", [53306] = "TBC Inn 7", [53307] = "TBC Inn 8", [53308] = "TBC Inn 9", [53309] = "TBC Inn 10", [53310] = "TBC Inn 11",

    [116289] = "WotLK Inn 1", [116290] = "WotLK Inn 2", [116291] = "WotLK Inn 3", [116292] = "WotLK Inn 4", [116293] = "WotLK Inn 5", [116294] = "WotLK Inn 6", [116295] = "WotLK Inn 7",

    [402589] = "Cataclysm Inn 1", [402590] = "Cataclysm Inn 2", [402591] = "Cataclysm Inn 3", [402592] = "Cataclysm Inn 4",

    [551820] = "MoP Inn 1", [551821] = "MoP Inn 2", [551822] = "MoP Inn 3", [551823] = "MoP Inn 4", [551824] = "MoP Inn 5", [551825] = "MoP Inn 6", [551826] = "MoP Inn 7", [551827] = "MoP Inn 8",

    [641804] = "WoD Inn 1", [641805] = "WoD Inn 2", [641806] = "WoD Inn 3", [641807] = "WoD Inn 4", [641808] = "WoD Inn 5", [641809] = "WoD Inn 6", [641810] = "WoD Inn 7", [642878] = "WoD Inn 8",

    [731548] = "Legion Inn 1", [731549] = "Legion Inn 2", [731550] = "Legion Inn 3", [731551] = "Legion Inn 4", [731552] = "Legion Inn 5", [731553] = "Legion Inn 6", [731554] = "Legion Inn 7", [731555] = "Legion Inn 8", [731556] = "Legion Inn 9",

    [1098785] = "BfA Inn 1", [1098786] = "BfA Inn 2", [1098787] = "BfA Inn 3", [1098788] = "BfA Inn 4", [1098789] = "BfA Inn 5", [1098790] = "BfA Inn 6", [1098791] = "BfA Inn 7", [1098792] = "BfA Inn 8", [1098793] = "BfA Inn 9", [1098794] = "BfA Inn 10", [1098795] = "BfA Inn 11", [1098796] = "BfA Inn 12", [1098797] = "BfA Inn 13", [1098798] = "BfA Inn 14",

    [3418179] = "Shadowlands Inn 1", [3418180] = "Shadowlands Inn 2", [3418181] = "Shadowlands Inn 3", [3418182] = "Shadowlands Inn 4", [3418183] = "Shadowlands Inn 5", [3418184] = "Shadowlands Inn 6", [3418185] = "Shadowlands Inn 7", [3418186] = "Shadowlands Inn 8", [3418187] = "Shadowlands Inn 9", [3418188] = "Shadowlands Inn 10", [3418189] = "Shadowlands Inn 11",

    [4013993] = "Dragonflight Inn 1", [4013994] = "Dragonflight Inn 2", [4013995] = "Dragonflight Inn 3", [4013996] = "Dragonflight Inn 4", [4013997] = "Dragonflight Inn 5", [4013998] = "Dragonflight Inn 6", [4013999] = "Dragonflight Inn 7", [4014000] = "Dragonflight Inn 8", [4014001] = "Dragonflight Inn 9", [4014002] = "Dragonflight Inn 10", [4014003] = "Dragonflight Inn 11", [4014004] = "Dragonflight Inn 12", [4014005] = "Dragonflight Inn 13",

    [5341735] = "The War Within Inn 1", [5341736] = "The War Within Inn 2", [5341737] = "The War Within Inn 3", [5341738] = "The War Within Inn 4", [5341739] = "The War Within Inn 5", [5341740] = "The War Within Inn 6", [5341741] = "The War Within Inn 7", [5341742] = "The War Within Inn 8",

    [642866] = "Additional Inn 1", [642867] = "Additional Inn 2", [642868] = "Additional Inn 3", [1390342] = "Additional Inn 4", [1390344] = "Additional Inn 5", [2005952] = "Additional Inn 6", [2005953] = "Additional Inn 7", [2005954] = "Additional Inn 8", [4622170] = "Additional Inn 9", [4622171] = "Additional Inn 10", [5341743] = "Additional Inn 11", [5341744] = "Additional Inn 12"
}

local shuffleBag = {}
local bagIndex = 0

local function FillAndShuffleBag()
    for i = 1, #TRACKS do
        shuffleBag[i] = i
    end
    for i = #shuffleBag, 2, -1 do
        local j = math.random(i)
        shuffleBag[i], shuffleBag[j] = shuffleBag[j], shuffleBag[i]
    end
    bagIndex = 1
end

local function PickRandomTrack()
    if #TRACKS <= 1 then return 1 end
    if #shuffleBag == 0 or bagIndex > #shuffleBag then
        FillAndShuffleBag()
    end

    local idx = shuffleBag[bagIndex]
    bagIndex = bagIndex + 1
    db.lastIndex = idx

    return idx
end

local function StopRestMusic()
    if isPlaying then StopMusic(); isPlaying = false end
    if ticker then ticker:Cancel(); ticker = nil end
    pendingPlay = false
end

local function PlayTrackAt(idx)
    assert(type(idx) == "number", "RestZoneMusic: PlayTrackAt requiere un índice numérico.")

    local id = TRACKS[idx]
    if not id then
        error("RestZoneMusic: Índice fuera de rango o FileDataID inexistente.", 2)
    end

    PlayMusic(id)
    isPlaying = true

    local trackName = TRACK_NAMES[id] or "Pista Desconocida"
    print("|cff00ccff[RestZoneMusic]|r Reproduciendo: " .. trackName .. " (ID: " .. id .. ")")
end

local function StartRestMusic()
    if not db.enabled then return end
    if ticker then ticker:Cancel(); ticker = nil end
    pendingPlay = true
    C_Timer.After(3.0, function()
        if not pendingPlay then return end
        pendingPlay = false
        if not IsResting() or not db.enabled then return end
        StopMusic()
        PlayTrackAt(PickRandomTrack())
        ticker = C_Timer.NewTicker(db.timerInterval, function()
            if IsResting() and db.enabled then
                PlayTrackAt(PickRandomTrack())
            else
                StopRestMusic()
            end
        end)
    end)
end

local function SkipTrack()
    if not db or not db.enabled then return end
    if ticker then ticker:Cancel(); ticker = nil end
    PlayTrackAt(PickRandomTrack())
    ticker = C_Timer.NewTicker(db.timerInterval, function()
        if IsResting() and db.enabled then PlayTrackAt(PickRandomTrack()) else StopRestMusic() end
    end)
end

-- Data Broker + LibDBIcon (posicion radial, persistencia de icono)
local rzmDataObject = ldb:NewDataObject("RestZoneMusic", {
    type = "launcher",
    text = "RestZoneMusic",
    icon = 133868,
    OnClick = function(self, button)
        if IsShiftKeyDown() then
            db.enabled = not db.enabled
            if db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end
            print("|cff00ccff[RestZoneMusic]|r " .. (db.enabled and "Activado" or "Desactivado"))
        elseif button == "LeftButton" then
            AceConfigDialog:Open("RestZoneMusic")
        elseif button == "RightButton" then
            if IsResting() then SkipTrack() else print("|cff00ccff[RestZoneMusic]|r Fuera de zona de descanso.") end
        end
    end,
    OnTooltipShow = function(tt)
        tt:AddLine("RestZoneMusic", 0, 0.8, 1)
        tt:AddLine("Clic Izquierdo: Abrir opciones", 1, 1, 1)
        tt:AddLine("Clic Derecho: Siguiente pista", 1, 1, 1)
        tt:AddLine("Shift + Clic: Activar / Desactivar", 0.5, 0.5, 0.5)
    end
})

local function BuildAceConfig()
    local options = {
        type = "group",
        name = "RestZoneMusic",
        args = {
            enabled = {
                order = 1,
                type = "toggle",
                name = "Activar",
                desc = "Habilita la musica en zonas de descanso.",
                get = function() return db.enabled end,
                set = function(_, val)
                    db.enabled = val
                    if val and IsResting() then StartRestMusic() else StopRestMusic() end
                end,
            },
            showMinimap = {
                order = 2,
                type = "toggle",
                name = "Icono en Minimapa",
                get = function() return not db.minimap.hide end,
                set = function(_, val)
                    db.minimap.hide = not val
                    if val then icon:Show("RestZoneMusic") else icon:Hide("RestZoneMusic") end
                end,
            },
            timerInterval = {
                order = 3,
                type = "range",
                name = "Intervalo (segundos)",
                min = 30, max = 600, step = 10,
                get = function() return db.timerInterval end,
                set = function(_, val) db.timerInterval = val end,
            },
            skipTrack = {
                order = 4,
                type = "execute",
                name = "Siguiente Pista",
                func = function()
                    if IsResting() then SkipTrack() else print("Fuera de zona de descanso.") end
                end,
            }
        }
    }
    AceConfig:RegisterOptionsTable("RestZoneMusic", options)
    AceConfigDialog:AddToBlizOptions("RestZoneMusic", "RestZoneMusic")
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_LOGOUT")

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not RestZoneMusicDB then
            error("RestZoneMusic: La tabla global RestZoneMusicDB es nil tras la carga del addon.", 2)
        end
        for k, v in pairs(DEFAULTS) do
            if RestZoneMusicDB[k] == nil then RestZoneMusicDB[k] = v end
        end
        db = RestZoneMusicDB
        if db.lastIndex < 0 or db.lastIndex > #TRACKS then db.lastIndex = 0 end

        -- minimap: tabla propia por jugador (no reutilizar referencia de DEFAULTS)
        if type(db.minimap) ~= "table" then
            db.minimap = { hide = false }
        elseif db.minimap.hide == nil then
            db.minimap.hide = false
        end
        if db.showMinimap ~= nil then
            db.minimap.hide = not db.showMinimap
        end

        wipe(shuffleBag)
        bagIndex = 0

        icon:Register("RestZoneMusic", rzmDataObject, db.minimap)
        BuildAceConfig()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if db and db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end

    elseif event == "PLAYER_UPDATE_RESTING" then
        if db and db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end

    elseif event == "PLAYER_LOGOUT" then
        StopRestMusic()
    end
end)

SLASH_RESTZONEMUSIC1 = "/rzm"
SlashCmdList["RESTZONEMUSIC"] = function()
    AceConfigDialog:Open("RestZoneMusic")
end
