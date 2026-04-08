local ADDON_NAME = "RestZoneMusic"

-- Validacion de dependencias al inicio (visible en BugSack / BugGrabber si falla)
local AceConfig = assert(
    LibStub("AceConfig-3.0", true),
    "RestZoneMusic: Falla crítica. AceConfig-3.0 no está cargado."
)
local AceConfigDialog = assert(
    LibStub("AceConfigDialog-3.0", true),
    "RestZoneMusic: Falla crítica. AceConfigDialog-3.0 no está cargado."
)

-- Descartar primeros valores de la secuencia PRNG del cliente (sin math.randomseed; lo gestiona el motor)
math.random()
math.random()
math.random()

RestZoneMusicDB = RestZoneMusicDB or {}
local db
local ticker
local minimapButton
local isPlaying = false
local pendingPlay = false

local DEFAULTS = {
    enabled = true,
    showMinimap = true,
    minimapAngle = 225,
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
    5341735, 5341736, 5341737, 5341738, 5341739, 5341740, 5341741, 5341742
}

local function PickRandomTrack()
    if #TRACKS <= 1 then return 1 end
    local idx
    local tries = 0
    repeat
        idx = math.random(1, #TRACKS)
        tries = tries + 1
    until idx ~= db.lastIndex or tries > 10
    db.lastIndex = idx
    return idx
end

local function StopRestMusic()
    if isPlaying then StopMusic(); isPlaying = false end
    if ticker then ticker:Cancel(); ticker = nil end
    pendingPlay = false
end

local function PlayTrackAt(idx)
    assert(
        type(idx) == "number",
        "RestZoneMusic: PlayTrackAt requiere un índice numérico. Valor recibido: " .. tostring(idx)
    )

    local id = TRACKS[idx]
    if not id then
        error(
            "RestZoneMusic: Índice fuera de rango o FileDataID inexistente en la tabla TRACKS. Índice: "
                .. tostring(idx),
            2
        )
    end

    PlayMusic(id)
    isPlaying = true
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

local function MinimapAngleToXY(angleDeg)
    local r = Minimap:GetWidth() / 2 + 16
    local rad = math.rad(angleDeg)
    return math.cos(rad) * r, math.sin(rad) * r
end

local function UpdateMinimapButtonPosition()
    if not db or not minimapButton then return end
    local x, y = MinimapAngleToXY(db.minimapAngle)
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    if minimapButton then return end
    local btn = CreateFrame("Button", "RZM_MinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetClampedToScreen(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("AnyUp")

    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetSize(53, 53)
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetPoint("TOPLEFT")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(20, 20)
    btn.icon:SetTexture(133868)
    btn.icon:SetPoint("CENTER", 0, 1)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetSize(31, 31)
    btn.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn.highlight:SetBlendMode("ADD")
    btn.highlight:SetPoint("CENTER")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RestZoneMusic", 0, 0.8, 1)
        GameTooltip:AddLine("Clic Izquierdo: Abrir opciones", 1, 1, 1)
        GameTooltip:AddLine("Clic Derecho: Siguiente pista", 1, 1, 1)
        GameTooltip:AddLine("Shift + Clic: Activar / Desactivar", 0.5, 0.5, 0.5)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    btn:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() then
            db.enabled = not db.enabled
            if db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end
            print("|cff00ccff[RestZoneMusic]|r " .. (db.enabled and "Activado" or "Desactivado"))
        elseif button == "LeftButton" then
            AceConfigDialog:Open("RestZoneMusic")
        elseif button == "RightButton" then
            if IsResting() then SkipTrack() else print("|cff00ccff[RestZoneMusic]|r Fuera de zona de descanso.") end
        end
    end)

    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            local mx, my = Minimap:GetCenter()
            local dx, dy = (cx / scale) - mx, (cy / scale) - my
            db.minimapAngle = math.deg(math.atan2(dy, dx))
            UpdateMinimapButtonPosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

    minimapButton = btn
    UpdateMinimapButtonPosition()
    if not db.showMinimap then btn:Hide() end
end

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
                get = function() return db.showMinimap end,
                set = function(_, val)
                    db.showMinimap = val
                    if minimapButton then
                        if val then minimapButton:Show() else minimapButton:Hide() end
                    end
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

        BuildAceConfig()
        CreateMinimapButton()
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
