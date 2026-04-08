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

assert(
    type(RestZoneMusic_Data) == "table"
        and type(RestZoneMusic_Data.TRACKS) == "table"
        and type(RestZoneMusic_Data.TRACK_NAMES) == "table",
    "RestZoneMusic: falta RestZoneMusic_Data.lua en el TOC o está corrupto."
)

local TRACKS = RestZoneMusic_Data.TRACKS
local TRACK_NAMES = RestZoneMusic_Data.TRACK_NAMES

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
