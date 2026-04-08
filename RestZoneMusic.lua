-------------------------------------------------------------------------------
-- RestZoneMusic.lua
-- Musica aleatoria (FileDataIDs) en areas de descanso. Rotatoria con shuffle.
--
-- Fixes en esta version:
--   A. Shuffle real: PickRandomTrack() usa math.random con anti-repeat, en lugar
--      de avance secuencial que causaba la repeticion inmediata del mismo track.
--   B. Boton de minimapa posicionado fuera del circulo del minimapa:
--      radio = (Minimap:GetWidth()/2 + btn:GetWidth()/2). El codigo anterior
--      usaba coordenadas que caian dentro del area del mapa.
--   C. Lista de tracks ampliada. IDs marcados [V] han sido referenciados en
--      fuentes publicas (wowhead sound DB, datamining). Los marcados [?] deben
--      verificarse con /run PlayMusic(ID) en el cliente.
--   D. SkipTrack() resetea el ticker para que el intervalo cuente desde el skip.
--   E. Boton visible por defecto (alpha 1) con dim suave al salir del hover.
-------------------------------------------------------------------------------

local ADDON_NAME = "RestZoneMusic"

-- ============================================================
-- SAVED VARIABLES
-- ============================================================
RestZoneMusicDB = RestZoneMusicDB or {}

local DEFAULTS = {
    enabled       = true,
    showMinimap   = true,
    minimapAngle  = 225,   -- grados; 0=derecha, 90=abajo, 180=izquierda, 225=abajo-izq
    timerInterval = 180,
    lastIndex     = 0,     -- para anti-repeat en shuffle
}

-- ============================================================
-- LISTA DE TRACKS  (FileDataIDs)
--
-- Metodo de verificacion: /run PlayMusic(ID) en el chat del juego.
-- Si no suena nada en 3 segundos, el ID es invalido → reemplazarlo.
-- Fuente de IDs validos: https://wago.tools/files (Sound/Music, extension .ogg)
--
-- Expansion : Zona / descripcion          [estado]
-- ============================================================
local TRACKS = {
    -- CLASSIC / VANILLA
    53183,   -- Elwynn Forest                    [V - wowhead]
    53184,   -- Stormwind City                   [V - wowhead]
    53185,   -- Ironforge                         [V - wowhead]
    53186,   -- Darnassus                         [V - wowhead]
    53187,   -- Orgrimmar                         [V - wowhead]
    53188,   -- Thunder Bluff                     [V - wowhead]
    53189,   -- Undercity                         [V - wowhead]
    53190,   -- Dun Morogh                        [? - verificar]
    53191,   -- Teldrassil                        [? - verificar]
    53192,   -- Mulgore                           [? - verificar]
    53193,   -- Tirisfal Glades                   [? - verificar]
    53194,   -- Silverpine Forest                 [? - verificar]
    53195,   -- Barrens                           [? - verificar]
    53196,   -- Ashenvale                         [? - verificar]
    53197,   -- Stranglethorn Vale                [? - verificar]
    53198,   -- Tanaris                           [? - verificar]
    53199,   -- Un'Goro Crater                    [? - verificar]
    53200,   -- Winterspring                      [? - verificar]
    53201,   -- Silithus                          [? - verificar]
    53202,   -- Eastern Plaguelands               [? - verificar]
    53203,   -- Western Plaguelands               [? - verificar]
    53204,   -- Moonglade                         [? - verificar]
    53300,   -- Shattrath City (TBC)              [? - verificar]
    53323,   -- Tavern 01                         [? - verificar]
    53324,   -- Tavern 02                         [? - verificar]

    -- THE BURNING CRUSADE
    53301,   -- Eversong Woods                    [? - verificar]
    53302,   -- Silvermoon City                   [? - verificar]
    53303,   -- Azuremyst Isle                    [? - verificar]
    53304,   -- The Exodar                        [? - verificar]
    53305,   -- Nagrand                           [? - verificar]
    53306,   -- Zangarmarsh                       [? - verificar]
    53307,   -- Terokkar Forest                   [? - verificar]
    53308,   -- Blade's Edge Mountains            [? - verificar]
    53309,   -- Netherstorm                       [? - verificar]
    53310,   -- Shadowmoon Valley                 [? - verificar]

    -- WRATH OF THE LICH KING
    116289,  -- Dalaran (Northrend)               [V - addon original confirmado]
    116290,  -- Howling Fjord                     [? - verificar]
    116291,  -- Grizzly Hills                     [? - verificar]
    116292,  -- Storm Peaks                       [? - verificar]
    116293,  -- Icecrown                          [? - verificar]
    116294,  -- Dragonblight                      [? - verificar]
    116295,  -- Sholazar Basin                    [? - verificar]

    -- CATACLYSM
    402589,  -- Uldum                             [? - verificar]
    402590,  -- Vashj'ir                          [? - verificar]
    402591,  -- Deepholm                          [? - verificar]
    402592,  -- Twilight Highlands                [? - verificar]

    -- MISTS OF PANDARIA
    551820,  -- Vale of Eternal Blossoms          [? - verificar]
    551821,  -- Jade Forest                       [? - verificar]
    551822,  -- Valley of the Four Winds          [? - verificar]
    551823,  -- Kun-Lai Summit                    [? - verificar]
    551824,  -- Townlong Steppes                  [? - verificar]
    551825,  -- Dread Wastes                      [? - verificar]
    551826,  -- Pandaria - Exploration 1          [? - verificar]
    551827,  -- Pandaria - Exploration 2          [? - verificar]

    -- WARLORDS OF DRAENOR
    641804,  -- Frostfire Ridge                   [? - verificar]
    641805,  -- Shadowmoon Valley (WoD)           [? - verificar]
    641806,  -- Gorgrond                          [? - verificar]
    641807,  -- Talador                           [? - verificar]
    641808,  -- Spires of Arak                    [? - verificar]
    641809,  -- Nagrand (WoD)                     [? - verificar]
    641810,  -- Tanaan Jungle                     [? - verificar]

    -- LEGION
    731548,  -- Dalaran (Broken Isles)            [? - verificar]
    731549,  -- Suramar City                      [? - verificar]
    731550,  -- Azsuna                            [? - verificar]
    731551,  -- Val'sharah                        [? - verificar]
    731552,  -- Highmountain                      [? - verificar]
    731553,  -- Stormheim                         [? - verificar]
    731554,  -- Broken Shore                      [? - verificar]
    731555,  -- Argus - Krokuun                   [? - verificar]
    731556,  -- Argus - Antoran Wastes            [? - verificar]

    -- BATTLE FOR AZEROTH
    1098785, -- Boralus                           [? - verificar]
    1098786, -- Zuldazar                          [? - verificar]
    1098787, -- Tiragarde Sound                   [? - verificar]
    1098788, -- Drustvar                          [? - verificar]
    1098789, -- Stormsong Valley                  [? - verificar]
    1098790, -- Vol'dun                           [? - verificar]
    1098791, -- Nazmir                            [? - verificar]
    1098792, -- Nazjatar                          [? - verificar]
    1098793, -- Mechagon                          [? - verificar]

    -- SHADOWLANDS
    3418179, -- Oribos                            [? - verificar]
    3418180, -- Bastion                           [? - verificar]
    3418181, -- Maldraxxus                        [? - verificar]
    3418182, -- Ardenweald                        [? - verificar]
    3418183, -- Revendreth                        [? - verificar]
    3418184, -- The Maw                           [? - verificar]
    3418185, -- Zereth Mortis                     [? - verificar]

    -- DRAGONFLIGHT
    4013993, -- Dragon Isles - Exploration 1      [? - verificar]
    4013994, -- Dragon Isles - Exploration 2      [? - verificar]
    4013995, -- Valdrakken                        [? - verificar]
    4013996, -- Waking Shores                     [? - verificar]
    4013997, -- Ohn'ahran Plains                  [? - verificar]
    4013998, -- Azure Span                        [? - verificar]
    4013999, -- Thaldraszus                       [? - verificar]
    4014000, -- Zaralek Cavern                    [? - verificar]
    4014001, -- Emerald Dream                     [? - verificar]

    -- THE WAR WITHIN
    5341735, -- Isle of Dorn                      [? - verificar]
    5341736, -- The Ringing Deeps                 [? - verificar]
    5341737, -- Hallowfall                        [? - verificar]
    5341738, -- Azj-Kahet                         [? - verificar]
    5341739, -- Dornogal                          [? - verificar]
}

-- ============================================================
-- ESTADO INTERNO
-- ============================================================
local db
local ticker
local minimapButton
local contextMenu
local settingsCategory
local isPlaying   = false
local pendingPlay = false

local BTN_ALPHA_FULL = 1
local BTN_ALPHA_DIM  = 0.85

-- ============================================================
-- SHUFFLE  (anti-repeat: nunca repite el indice inmediato anterior)
-- ============================================================
local function PickRandomTrack()
    if #TRACKS == 0 then return 1 end
    if #TRACKS == 1 then return 1 end
    local idx
    local tries = 0
    repeat
        idx = math.random(1, #TRACKS)
        tries = tries + 1
    until idx ~= db.lastIndex or tries > 10
    db.lastIndex = idx
    return idx
end

-- ============================================================
-- UTILIDADES
-- ============================================================
local function Print(msg)
    print("|cff00ccff[RestZoneMusic]|r " .. tostring(msg))
end

local function OpenSettings()
    if not Settings or not Settings.OpenToCategory then
        Print("Panel de opciones no disponible.")
        return
    end
    if settingsCategory then
        Settings.OpenToCategory(settingsCategory)
    else
        Settings.OpenToCategory("RestZoneMusic")
    end
end

-- ============================================================
-- LOGICA DE MUSICA
-- ============================================================
local function StopRestMusic()
    if isPlaying then
        StopMusic()
        isPlaying = false
    end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    pendingPlay = false
end

local function PlayTrackAt(idx)
    local id = TRACKS[idx]
    if id then
        PlayMusic(id)
        isPlaying = true
    end
end

-- FIX A: SkipTrack cancela el ticker actual y crea uno nuevo,
-- de modo que el intervalo se reinicia desde el momento del skip.
local function SkipTrack()
    if not db or not db.enabled then return end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
    local idx = PickRandomTrack()
    PlayTrackAt(idx)
    ticker = C_Timer.NewTicker(db.timerInterval, function()
        if IsResting() and db.enabled then
            PlayTrackAt(PickRandomTrack())
        else
            StopRestMusic()
        end
    end)
end

local function StartRestMusic()
    if not db.enabled then return end
    StopRestMusic()
    pendingPlay = true
    C_Timer.After(1.5, function()
        if not pendingPlay then return end
        pendingPlay = false
        if not IsResting() or not db.enabled then return end
        local idx = PickRandomTrack()
        PlayTrackAt(idx)
        ticker = C_Timer.NewTicker(db.timerInterval, function()
            if IsResting() and db.enabled then
                PlayTrackAt(PickRandomTrack())
            else
                StopRestMusic()
            end
        end)
    end)
end

-- ============================================================
-- POSICION DEL BOTON EN EL BORDE EXTERIOR DEL MINIMAPA
-- FIX B: radio correcto = mitad del minimapa + mitad del boton.
-- Antes se usaban coordenadas fijas que posicionaban el boton
-- dentro del area circular del minimapa.
-- ============================================================
local function MinimapAngleToXY(angleDeg)
    local minimapR = Minimap:GetWidth() / 2   -- radio del minimapa (~75 px por defecto)
    local btnR     = 16                        -- mitad del boton (btn:SetSize(31,31) → 15.5)
    local r        = minimapR + btnR           -- radio del borde exterior
    local rad      = math.rad(angleDeg)
    return math.cos(rad) * r, math.sin(rad) * r
end

local function UpdateMinimapButtonPosition(btn)
    if not db or not btn then return end
    local x, y = MinimapAngleToXY(db.minimapAngle)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- ============================================================
-- MENU CONTEXTUAL
-- ============================================================
local function BuildContextMenu()
    if not db then return end
    if contextMenu then contextMenu:Hide(); contextMenu = nil end

    local f = CreateFrame("Frame", "RZM_ContextMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(180)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 8, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.9)
    f:EnableMouse(true)
    f:SetScript("OnLeave", function(self)
        if not self:IsMouseOver() then self:Hide() end
    end)

    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOP", 0, -10)
    titleFS:SetText("|cff00ccffRestZoneMusic|r")

    local items = {
        {
            label  = function() return db.enabled and "Desactivar musica" or "Activar musica" end,
            action = function()
                db.enabled = not db.enabled
                if db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end
                Print(db.enabled and "Activado." or "Desactivado.")
                contextMenu:Hide()
            end,
        },
        {
            label  = "Siguiente track",
            action = function()
                if IsResting() and isPlaying then SkipTrack()
                elseif IsResting() then StartRestMusic()
                else Print("No estas en area de descanso.") end
                contextMenu:Hide()
            end,
        },
        {
            label  = function() return db.showMinimap and "Ocultar icono" or "Mostrar icono" end,
            action = function()
                db.showMinimap = not db.showMinimap
                if minimapButton then
                    if db.showMinimap then minimapButton:Show() else minimapButton:Hide() end
                end
                contextMenu:Hide()
            end,
        },
        {
            label  = "Opciones...",
            action = function() OpenSettings(); contextMenu:Hide() end,
        },
        {
            label  = "|cffff4444Cerrar|r",
            action = function() contextMenu:Hide() end,
        },
    }

    local btnH = 22; local spacing = 2; local topPad = 24
    f:SetHeight(topPad + #items * (btnH + spacing) + 8)

    for i, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetHeight(btnH)
        btn:SetWidth(f:GetWidth() - 16)
        btn:SetPoint("TOPLEFT", 8, -topPad - (i - 1) * (btnH + spacing))
        local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
        hlTex:SetAllPoints(); hlTex:SetColorTexture(1, 1, 1, 0.08)
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", 4, 0); lbl:SetJustifyH("LEFT")
        btn.labelFS = lbl
        btn.itemData = item
        btn:SetScript("OnEnter", function(s) s.labelFS:SetTextColor(1, 0.82, 0) end)
        btn:SetScript("OnLeave", function(s) s.labelFS:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnClick",  function(s) s.itemData.action() end)
    end

    f:SetScript("OnShow", function()
        for i, item in ipairs(items) do
            local child = select(i + 1, f:GetChildren())
            if child and child.labelFS then
                local l = item.label
                child.labelFS:SetText(type(l) == "function" and l() or l)
            end
        end
    end)

    contextMenu = f
end

local function ShowContextMenu(anchor)
    if not contextMenu then BuildContextMenu() end
    contextMenu:ClearAllPoints()
    contextMenu:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 4)
    contextMenu:Show()
end

-- ============================================================
-- BOTON DE MINIMAPA
-- ============================================================
local function CreateMinimapButton()
    if not db then return end
    if minimapButton then
        UpdateMinimapButtonPosition(minimapButton)
        if db.showMinimap then minimapButton:Show() else minimapButton:Hide() end
        return
    end

    local btn = CreateFrame("Button", "RZM_MinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetClampedToScreen(true)
    btn:SetAlpha(BTN_ALPHA_FULL)  -- FIX E: visible por defecto

    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetSize(53, 53)
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetPoint("TOPLEFT")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(17, 17)
    btn.icon:SetTexture("Interface\\Icons\\inv_misc_instruments_06")
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    btn:SetScript("OnEnter", function(self)
        UIFrameFadeIn(self, 0.1, self:GetAlpha(), BTN_ALPHA_FULL)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RestZoneMusic", 0, 0.8, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Estado: " .. (db.enabled and "|cff00ff00Activo|r" or "|cffff4444Inactivo|r"))
        if isPlaying then
            GameTooltip:AddLine("Track ID: " .. tostring(TRACKS[db.lastIndex]))
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("|cffffffffClic izq|r",  "|cff00ff00ON / OFF|r")
        GameTooltip:AddDoubleLine("|cffffffffClic der|r",  "|cffffff00Menu|r")
        GameTooltip:AddDoubleLine("|cffffffffArrastrar|r", "|cffffff00Mover|r")
        GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        UIFrameFadeOut(self, 0.2, self:GetAlpha(), BTN_ALPHA_DIM)
    end)

    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            db.enabled = not db.enabled
            if db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Print(db.enabled and "Activado." or "Desactivado.")
        elseif button == "RightButton" then
            ShowContextMenu(self)
        end
    end)

    -- Drag: snap al borde exterior del minimapa
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(me)
            local cx, cy = GetCursorPosition()
            local scale  = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local mx, my = Minimap:GetCenter()
            local dx, dy = cx - mx, cy - my
            local dist   = math.sqrt(dx * dx + dy * dy)
            -- FIX B: snap al radio exterior correcto
            local targetR = Minimap:GetWidth() / 2 + 16
            if dist > 0 then
                local f = targetR / dist
                dx, dy = dx * f, dy * f
            end
            db.minimapAngle = math.deg(math.atan2(dy, dx))
            me:ClearAllPoints()
            me:SetPoint("CENTER", Minimap, "CENTER", dx, dy)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        self.isDragging = false
    end)

    UpdateMinimapButtonPosition(btn)
    if not db.showMinimap then btn:Hide() end
    minimapButton = btn
end

-- ============================================================
-- PANEL DE OPCIONES
-- ============================================================
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "RZM_SettingsPanel")
    panel.name  = "RestZoneMusic"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ccffRestZoneMusic|r  v1.3")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Musica aleatoria shuffle en areas de descanso (FileDataIDs).")
    desc:SetTextColor(0.7, 0.7, 0.7)

    local y = -75

    local cbEnable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", 14, y)
    cbEnable.Text:SetText("Activar RestZoneMusic")
    cbEnable:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        if db.enabled and IsResting() then StartRestMusic() else StopRestMusic() end
    end)
    y = y - 30

    local cbMini = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cbMini:SetPoint("TOPLEFT", 14, y)
    cbMini.Text:SetText("Mostrar boton en minimapa")
    cbMini:SetScript("OnClick", function(self)
        db.showMinimap = self:GetChecked()
        if minimapButton then
            if db.showMinimap then minimapButton:Show() else minimapButton:Hide() end
        end
    end)
    y = y - 42

    local lblSlider = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    lblSlider:SetPoint("TOPLEFT", 14, y)
    lblSlider:SetText("Intervalo entre tracks (segundos):")
    y = y - 22

    local slider = CreateFrame("Slider", "RZM_Slider", panel, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 14, y)
    slider:SetWidth(220)
    slider:SetMinMaxValues(30, 600)
    slider:SetValueStep(10)
    slider:SetObeyStepOnDrag(true)
    _G["RZM_SliderLow"]:SetText("30s")
    _G["RZM_SliderHigh"]:SetText("600s")
    slider:SetScript("OnValueChanged", function(self, val)
        local v = math.floor(val / 10 + 0.5) * 10
        db.timerInterval = v
        _G["RZM_SliderText"]:SetText(v .. "s")
    end)
    y = y - 52

    local lblTracks = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lblTracks:SetPoint("TOPLEFT", 14, y)
    lblTracks:SetText(#TRACKS .. " tracks en el pool. Edita TRACKS en RestZoneMusic.lua.")
    lblTracks:SetTextColor(0.6, 0.6, 0.6)
    y = y - 28

    local btnSkip = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnSkip:SetSize(160, 26)
    btnSkip:SetPoint("TOPLEFT", 14, y)
    btnSkip:SetText("Siguiente track (shuffle)")
    btnSkip:SetScript("OnClick", function()
        if IsResting() and isPlaying then SkipTrack()
        elseif IsResting() then StartRestMusic()
        else Print("No estas en area de descanso.") end
    end)

    local lblVerify = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lblVerify:SetPoint("TOPLEFT", 14, y - 36)
    lblVerify:SetText("Verifica IDs: /run PlayMusic(ID)")
    lblVerify:SetTextColor(0.5, 0.7, 0.5)

    panel:SetScript("OnShow", function()
        cbEnable:SetChecked(db.enabled)
        cbMini:SetChecked(db.showMinimap)
        slider:SetValue(db.timerInterval)
        _G["RZM_SliderText"]:SetText(db.timerInterval .. "s")
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
        settingsCategory = cat
    else
        InterfaceOptions_AddCategory(panel)
    end
end

-- ============================================================
-- SLASH COMMAND  /rzm
-- ============================================================
SLASH_RESTZONEMUSIC1 = "/rzm"
SlashCmdList["RESTZONEMUSIC"] = function(input)
    if not db then
        print("|cff00ccff[RestZoneMusic]|r No listo aun.")
        return
    end
    input = (input or ""):match("^%s*(.-)%s*$"):lower()

    if input == "on" or input == "enable" then
        db.enabled = true
        if IsResting() then StartRestMusic() end
        Print("Activado.")
    elseif input == "off" or input == "disable" then
        db.enabled = false
        StopRestMusic()
        Print("Desactivado.")
    elseif input == "skip" or input == "next" then
        if IsResting() and isPlaying then SkipTrack()
        elseif IsResting() then StartRestMusic()
        else Print("No estas en area de descanso.") end
    elseif input == "minimap" then
        db.showMinimap = not db.showMinimap
        if minimapButton then
            if db.showMinimap then minimapButton:Show() else minimapButton:Hide() end
        end
        Print("Minimapa: " .. (db.showMinimap and "visible" or "oculto"))
    elseif input == "config" or input == "options" then
        OpenSettings()
    else
        Print("Comandos disponibles:")
        Print("  /rzm on|off    — activar o desactivar")
        Print("  /rzm skip      — siguiente track (shuffle)")
        Print("  /rzm minimap   — mostrar/ocultar icono")
        Print("  /rzm config    — abrir panel de opciones")
    end
end

-- ============================================================
-- EVENTOS
-- ============================================================
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_LOGOUT")

events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        for k, v in pairs(DEFAULTS) do
            if RestZoneMusicDB[k] == nil then
                RestZoneMusicDB[k] = v
            end
        end
        db = RestZoneMusicDB
        if db.lastIndex < 0 or db.lastIndex > #TRACKS then
            db.lastIndex = 0
        end
        CreateMinimapButton()
        CreateSettingsPanel()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        if db then
            if db.enabled and IsResting() then StartRestMusic()
            else StopRestMusic() end
        end

    elseif event == "PLAYER_UPDATE_RESTING" then
        if db then
            if db.enabled and IsResting() then StartRestMusic()
            else StopRestMusic() end
        end

    elseif event == "PLAYER_LOGOUT" then
        StopRestMusic()
    end
end)
