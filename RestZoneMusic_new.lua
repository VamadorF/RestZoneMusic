-------------------------------------------------------------------------------
-- RestZoneMusic.lua
-- Plays random WoW music (via FileDataIDs) when the player is resting
-- (inn / capital city). Replaces zone music. Track rotates on a timer.
--
-- Bugs corregidos vs original:
--   1. TOC faltaba ## SavedVariables → DB se reseteaba en cada recarga.
--   2. PlayMusic se llamaba sin delay → zone-music del cliente sobreescribia
--      el track inmediatamente despues de PLAYER_UPDATE_RESTING/ENTERING_WORLD.
--   3. El ticker no se cancelaba al salir del area de descanso.
--   4. No se verificaba IsResting() en PLAYER_ENTERING_WORLD (reload en inn).
--
-- Nuevo:
--   • Boton de minimapa con icono, arrastrable, fade in/out.
--   • Menu contextual (clic derecho) con opciones rapidas.
--   • Panel de opciones en Interface → AddOns.
--   • Comando slash /rzm.
-------------------------------------------------------------------------------

local ADDON_NAME = "RestZoneMusic"

-- ============================================================
-- SAVED VARIABLES  (declaradas en el TOC: ## SavedVariables)
-- ============================================================
RestZoneMusicDB = RestZoneMusicDB or {}

local DEFAULTS = {
    enabled       = true,
    showMinimap   = true,
    minimapX      = math.cos(math.rad(225)) * 80,
    minimapY      = math.sin(math.rad(225)) * 80,
    timerInterval = 180,    -- segundos entre cambios automaticos de track
    trackIndex    = 1,
}

-- ============================================================
-- LISTA DE TRACKS  (FileDataIDs de archivos de musica de WoW)
-- Agrega o reemplaza IDs segun preferencia.
-- Referencia: https://wago.tools/files  (filtra por Sound/Music)
-- ============================================================
local TRACKS = {
    -- Musica de taberna / ambiente clasico
    566566,   -- Tavern 01
    566567,   -- Tavern 02
    566568,   -- Tavern 03
    566569,   -- Tavern 04
    -- Zonas de descanso por expansion
    1402609,  -- Suramar (Legion)
    1339023,  -- Dalaran (Legion)
    2145490,  -- Zuldazar (BfA)
    2569571,  -- Bastion (Shadowlands)
    2569584,  -- Ardenweald (Shadowlands)
    2858780,  -- Dragon Isles Ambient 1 (Dragonflight)
    2858788,  -- Dragon Isles Ambient 2 (Dragonflight)
    3609644,  -- Emerald Dream (Dragonflight)
    3686450,  -- Isle of Dorn (TWW)
    3686451,  -- Hallowfall (TWW)
    3686452,  -- Azj-Kahet (TWW)
}

-- ============================================================
-- ESTADO INTERNO
-- ============================================================
local db             -- alias a RestZoneMusicDB, iniciado en ADDON_LOADED
local ticker         -- C_Timer.NewTicker handle
local minimapButton  -- frame del boton de minimapa
local contextMenu    -- frame del menu contextual
local isPlaying  = false
local pendingPlay    -- flag para cancelar el delay de inicio

-- ============================================================
-- UTILIDADES
-- ============================================================
local function NextTrackIndex()
    db.trackIndex = (db.trackIndex % #TRACKS) + 1
    return db.trackIndex
end

local function Print(msg)
    print("|cff00ccff[RestZoneMusic]|r " .. tostring(msg))
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
    pendingPlay = false   -- cancela cualquier delay en vuelo
end

local function PlayCurrentTrack()
    if not db.enabled then return end
    local id = TRACKS[db.trackIndex]
    if id then
        PlayMusic(id)
        isPlaying = true
    end
end

local function AdvanceAndPlay()
    NextTrackIndex()
    PlayCurrentTrack()
end

local function StartRestMusic()
    if not db.enabled then return end
    StopRestMusic()

    -- BUG FIX #2: se usa delay de 1.5 s para que el sistema de
    -- zone-music del cliente finalice su PlayMusic antes de ser reemplazado.
    pendingPlay = true
    C_Timer.After(1.5, function()
        if not pendingPlay then return end  -- fue cancelado
        pendingPlay = false
        if not IsResting() or not db.enabled then return end
        PlayCurrentTrack()
        -- Ticker: rota el track cada timerInterval segundos
        ticker = C_Timer.NewTicker(db.timerInterval, function()
            if IsResting() and db.enabled then
                AdvanceAndPlay()
            else
                StopRestMusic()
            end
        end)
    end)
end

-- ============================================================
-- MENU CONTEXTUAL  (clic derecho en el boton de minimapa)
-- Implementacion custom; EasyMenu fue eliminado en TWW.
-- ============================================================
local function BuildContextMenu()
    if contextMenu then
        contextMenu:Hide()
        contextMenu = nil
    end

    local f = CreateFrame("Frame", "RZM_ContextMenu", UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetWidth(180)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile     = true, tileSize = 8, edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropColor(0, 0, 0, 0.88)
    f:EnableMouse(true)
    f:SetScript("OnLeave", function(self)
        if not self:IsMouseOver() then self:Hide() end
    end)

    local titleFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("TOP", 0, -10)
    titleFS:SetText("|cff00ccffRestZoneMusic|r")

    local items = {
        {
            label = function()
                return db.enabled and "Desactivar musica" or "Activar musica"
            end,
            action = function()
                db.enabled = not db.enabled
                if db.enabled and IsResting() then StartRestMusic()
                else StopRestMusic() end
                Print(db.enabled and "Activado." or "Desactivado.")
                contextMenu:Hide()
            end,
        },
        {
            label = "Siguiente track",
            action = function()
                if IsResting() then AdvanceAndPlay()
                else Print("No estas en area de descanso.") end
                contextMenu:Hide()
            end,
        },
        {
            label = function()
                return db.showMinimap and "Ocultar icono" or "Mostrar icono"
            end,
            action = function()
                db.showMinimap = not db.showMinimap
                if minimapButton then
                    if db.showMinimap then minimapButton:Show()
                    else minimapButton:Hide() end
                end
                contextMenu:Hide()
            end,
        },
        {
            label = "Opciones...",
            action = function()
                Settings.OpenToCategory("RestZoneMusic")
                contextMenu:Hide()
            end,
        },
        {
            label = "|cffff4444Cerrar|r",
            action = function() contextMenu:Hide() end,
        },
    }

    local btnH    = 22
    local spacing = 2
    local topPad  = 24
    f:SetHeight(topPad + #items * (btnH + spacing) + 8)

    for i, item in ipairs(items) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetHeight(btnH)
        btn:SetWidth(f:GetWidth() - 16)
        btn:SetPoint("TOPLEFT", 8, -topPad - (i - 1) * (btnH + spacing))

        local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
        hlTex:SetAllPoints()
        hlTex:SetColorTexture(1, 1, 1, 0.08)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("LEFT", 4, 0)
        lbl:SetJustifyH("LEFT")
        btn.labelFS = lbl

        btn.itemData = item
        btn:SetScript("OnEnter", function(s) s.labelFS:SetTextColor(1, 0.8, 0) end)
        btn:SetScript("OnLeave", function(s) s.labelFS:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnClick", function(s) s.itemData.action() end)
    end

    -- Actualiza labels dinamicos cada vez que se muestra el menu
    f:SetScript("OnShow", function()
        for i, item in ipairs(items) do
            local child = select(i + 1, f:GetChildren())   -- +1 por el frame vacio
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
local function UpdateMinimapButtonPosition(btn)
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", db.minimapX, db.minimapY)
end

local function CreateMinimapButton()
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
    btn:SetAlpha(0.01)

    -- Borde circular estandar de tracking buttons
    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetSize(53, 53)
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetPoint("TOPLEFT")

    -- Icono: instrumento musical (laud)
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(17, 17)
    btn.icon:SetTexture("Interface\\Icons\\inv_misc_instruments_06")
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("RestZoneMusic", 0, 0.8, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Estado: " .. (db.enabled and "|cff00ff00Activo|r" or "|cffff4444Inactivo|r"))
        if isPlaying then
            GameTooltip:AddLine("Track ID: " .. tostring(TRACKS[db.trackIndex]))
            GameTooltip:AddLine("Siguiente en " .. tostring(db.timerInterval) .. "s")
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("|cffffffffClic izq|r",  "|cff00ff00Activar / Desactivar|r")
        GameTooltip:AddDoubleLine("|cffffffffClic der|r",  "|cffffff00Menu de opciones|r")
        GameTooltip:AddDoubleLine("|cffffffffArrastrar|r", "|cffffff00Mover icono|r")
        GameTooltip:Show()
        UIFrameFadeIn(self, 0.15, self:GetAlpha(), 1)
    end)

    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not Minimap:IsMouseOver() then
            UIFrameFadeOut(self, 0.15, self:GetAlpha(), 0.01)
        end
    end)

    Minimap:HookScript("OnEnter", function()
        if not btn.isDragging and db.showMinimap then
            UIFrameFadeIn(btn, 0.15, btn:GetAlpha(), 1)
        end
    end)
    Minimap:HookScript("OnLeave", function()
        if not btn.isDragging and not btn:IsMouseOver() and db.showMinimap then
            UIFrameFadeOut(btn, 0.15, btn:GetAlpha(), 0.01)
        end
    end)

    -- Clicks
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            db.enabled = not db.enabled
            if db.enabled and IsResting() then StartRestMusic()
            else StopRestMusic() end
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            Print(db.enabled and "Activado." or "Desactivado.")
        elseif button == "RightButton" then
            ShowContextMenu(self)
        end
    end)

    -- Drag con snap al borde del minimapa
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
        local minimap      = Minimap
        local minimapW     = minimap:GetWidth()
        local buttonW      = self:GetWidth()
        local edgeRadius   = (minimapW + buttonW) / 2
        local snapRadius   = edgeRadius - 5
        local pullRadius   = edgeRadius + buttonW * 0.2
        local freeRadius   = edgeRadius + buttonW * 0.7

        self:SetScript("OnUpdate", function(me)
            local cx, cy = GetCursorPosition()
            local scale  = minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local mx, my = minimap:GetCenter()
            local dx, dy = cx - mx, cy - my
            local dist   = math.sqrt(dx * dx + dy * dy)
            local clamp

            if dist <= snapRadius then
                me.snapped = true; clamp = snapRadius
            elseif dist < pullRadius and me.snapped then
                clamp = snapRadius
            elseif dist < freeRadius and me.snapped then
                clamp = snapRadius + (dist - pullRadius) / 2
            else
                me.snapped = false
            end

            if clamp and dist > 0 then
                local factor = clamp / dist
                dx, dy = dx * factor, dy * factor
            end

            db.minimapX = dx
            db.minimapY = dy
            me:ClearAllPoints()
            me:SetPoint("CENTER", minimap, "CENTER", dx, dy)
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
-- PANEL DE OPCIONES  (Interface → AddOns → RestZoneMusic)
-- ============================================================
local function CreateSettingsPanel()
    local panel = CreateFrame("Frame", "RZM_SettingsPanel")
    panel.name  = "RestZoneMusic"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff00ccffRestZoneMusic|r  v1.1")

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    desc:SetText("Musica aleatoria en areas de descanso mediante FileDataIDs.")
    desc:SetTextColor(0.7, 0.7, 0.7)

    local y = -75

    -- Activar addon
    local cbEnable = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", 14, y)
    cbEnable.Text:SetText("Activar RestZoneMusic")
    cbEnable:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        if db.enabled and IsResting() then StartRestMusic()
        else StopRestMusic() end
    end)
    y = y - 30

    -- Mostrar boton en minimapa
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

    -- Intervalo de rotacion
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

    -- Info tracks
    local lblTracks = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lblTracks:SetPoint("TOPLEFT", 14, y)
    lblTracks:SetText("Tracks en la lista: " .. #TRACKS ..
        "  |  Edita TRACKS en RestZoneMusic.lua para modificarla.")
    lblTracks:SetTextColor(0.6, 0.6, 0.6)
    y = y - 28

    -- Boton saltar track
    local btnSkip = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btnSkip:SetSize(150, 26)
    btnSkip:SetPoint("TOPLEFT", 14, y)
    btnSkip:SetText("Siguiente track ahora")
    btnSkip:SetScript("OnClick", function()
        if IsResting() then AdvanceAndPlay()
        else Print("No estas en area de descanso.") end
    end)

    -- Sincronizar UI al abrir el panel
    panel:SetScript("OnShow", function()
        cbEnable:SetChecked(db.enabled)
        cbMini:SetChecked(db.showMinimap)
        slider:SetValue(db.timerInterval)
        _G["RZM_SliderText"]:SetText(db.timerInterval .. "s")
    end)

    -- Registrar con Settings (moderno TWW) o fallback
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local cat = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(cat)
    else
        InterfaceOptions_AddCategory(panel)
    end
end

-- ============================================================
-- SLASH COMMAND   /rzm
-- ============================================================
SLASH_RESTZONEMUSIC1 = "/rzm"
SlashCmdList["RESTZONEMUSIC"] = function(input)
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
        if IsResting() then AdvanceAndPlay()
        else Print("No estas en area de descanso.") end

    elseif input == "minimap" then
        db.showMinimap = not db.showMinimap
        if minimapButton then
            if db.showMinimap then minimapButton:Show() else minimapButton:Hide() end
        end
        Print("Minimapa: " .. (db.showMinimap and "visible" or "oculto"))

    elseif input == "config" or input == "options" then
        Settings.OpenToCategory("RestZoneMusic")

    else
        Print("Comandos:")
        Print("  /rzm on|off   — activar o desactivar")
        Print("  /rzm skip     — saltar al siguiente track")
        Print("  /rzm minimap  — mostrar u ocultar icono en minimapa")
        Print("  /rzm config   — abrir panel de opciones")
    end
end

-- ============================================================
-- INICIALIZACION
-- ============================================================
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_UPDATE_RESTING")
events:RegisterEvent("PLAYER_LOGOUT")

events:SetScript("OnEvent", function(self, event, arg1)

    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        -- Poblar SavedVariables con defaults donde falten
        for k, v in pairs(DEFAULTS) do
            if RestZoneMusicDB[k] == nil then
                RestZoneMusicDB[k] = v
            end
        end
        db = RestZoneMusicDB

        if db.trackIndex < 1 or db.trackIndex > #TRACKS then
            db.trackIndex = 1
        end

        CreateMinimapButton()
        CreateSettingsPanel()
        self:UnregisterEvent("ADDON_LOADED")

    elseif event == "PLAYER_ENTERING_WORLD" then
        -- BUG FIX #4: comprobar estado de descanso en cada carga/reload
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
