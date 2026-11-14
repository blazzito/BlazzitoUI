-- Blazzito_Minimap: el minimapa de Blizzard con el estilo de BlazzitoUI. El
-- mapa sigue siendo el del juego (puntos, misiones, seguimiento, clics);
-- aquí cambian su tamaño, su forma (las mismas que el resto de BlazzitoUI) y
-- lo que lo rodea:
--  * Borde con la forma, puntos cardinales (N, S, E, O) bien visibles.
--  * Zona encima (con el color de su tipo: santuario, amistosa, hostil...).
--  * Debajo, coordenadas y hora; botón de calendario.
--  * Los botones de los addons recogidos en un solo botón que los despliega.
--  * Zoom con la rueda del ratón. Se mueve con el modo mover de BlazzitoUI.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret, Readable = M.IsSecret, M.Readable
local MEDIA = "Interface\\AddOns\\Blazzito_Minimap\\Media\\"

local MM = ns.NewModule("Minimap", "Minimapa", {
    size = 220, shape = "rounded", flipH = false, flipV = false,
    border = 2, borderColor = { 0, 0, 0 },
    compass = true, compassSize = 13, compassAlpha = 80,
    zone = true, clock = true, clock24 = true, localTime = true, coords = true, calendar = true,
    fontSize = 12, wheelZoom = true, collectButtons = true, buttonsPerRow = 5, showCompartment = false,
    positions = {},
    petPaw = true, pawSize = 18, pawHappiness = true,
})
ns.Minimap = MM

local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local function Hold(region, hide)
    if type(region) ~= "table" or not region.SetAlpha then return end
    if hide then
        held[region] = true
        if not hooked[region] then
            hooked[region] = true
            hooksecurefunc(region, "SetAlpha", function(self, alpha)
                if held[self] and (IsSecret(alpha) or alpha ~= 0) then self:SetAlpha(0) end
            end)
        end
        region:SetAlpha(0)
        if region.EnableMouse and region.GetObjectType and region:GetObjectType() ~= "Texture" then
            pcall(region.EnableMouse, region, false)
        end
    elseif held[region] then
        held[region] = nil
        region:SetAlpha(1)
    end
end
MM.Hold = Hold

local function Field(owner, key)
    local value = type(owner) == "table" and owner[key]
    return type(value) == "table" and value or nil
end

local function MapFile(cfg)
    local shape = M.BUTTON_SHAPES[cfg.shape] and cfg.shape or "square"
    local suffix = M.BUTTON_SHAPES[shape].flips and ((cfg.flipH and "h" or "") .. (cfg.flipV and "v" or "")) or ""
    return MEDIA .. "map_" .. shape .. (suffix ~= "" and ("_" .. suffix) or "")
end
MM.MapFile = MapFile

---------------------------------------------------------------------------
-- Piezas de Blizzard que sobran (borde, brújula, zoom, reloj, calendario...)
---------------------------------------------------------------------------
local BLIZZARD_ART = { "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag", "MinimapCompassTexture",
                       "MinimapCompassTextureUnderlay", "MinimapZoomIn", "MinimapZoomOut", "MinimapZoneTextButton",
                       "MinimapToggleButton", "TimeManagerClockButton", "GameTimeFrame", "MiniMapWorldMapButton" }

local function BlizzardArt()
    local list = {}
    for _, name in ipairs(BLIZZARD_ART) do list[#list + 1] = _G[name] end
    local minimap, cluster = _G.Minimap, _G.MinimapCluster
    list[#list + 1] = Field(minimap, "ZoomIn")
    list[#list + 1] = Field(minimap, "ZoomOut")
    list[#list + 1] = Field(cluster, "BorderTop")
    list[#list + 1] = Field(cluster, "ZoneTextButton")
    return list
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
local holder, info

local function IconButton(parent, icon, tooltip, onClick)
    local button = ns.Widgets.IconButton(parent, icon, tooltip, onClick)
    button:SetSize(20, 20)
    button.icon:SetSize(13, 13)
    button.icon:SetVertexColor(0.9, 0.9, 0.95)
    button.tint = { 0.9, 0.9, 0.95 }
    return button
end

local function Build()
    holder = CreateFrame("Frame", "BlazzitoUIMinimapHolder", UIParent)
    holder:SetFrameStrata("LOW")
    MM.holder = holder
    holder.border = holder:CreateTexture(nil, "BACKGROUND", nil, -8)
    holder.back = holder:CreateTexture(nil, "BACKGROUND", nil, -7)

    -- Por encima del mapa: brújula, botones, textos.
    info = CreateFrame("Frame", nil, holder)
    info:SetAllPoints()
    info:SetFrameLevel(holder:GetFrameLevel() + 20)
    MM.info = info

    info.compass = {}
    for _, letter in ipairs({ "N", "S", "E", "O" }) do
        info.compass[letter] = info:CreateFontString(nil, "OVERLAY")
    end

    -- Zona encima del mapa (pulsar: mapa del mundo).
    info.zoneButton = CreateFrame("Button", nil, info)
    info.zone = info.zoneButton:CreateFontString(nil, "OVERLAY")
    info.zone:SetPoint("CENTER")
    info.zoneButton:SetScript("OnClick", function() if ToggleWorldMap then ToggleWorldMap() end end)

    -- Barra inferior: coordenadas y hora.
    info.bar = CreateFrame("Frame", nil, info)
    info.bar.bg = info.bar:CreateTexture(nil, "BACKGROUND")
    info.bar.bg:SetAllPoints()
    info.bar.bg:SetColorTexture(0.05, 0.05, 0.06, 0.85)
    info.coords = info.bar:CreateFontString(nil, "OVERLAY")
    info.coords:SetPoint("LEFT", 8, 0)
    info.clockButton = CreateFrame("Button", nil, info.bar)
    info.clock = info.clockButton:CreateFontString(nil, "OVERLAY")
    info.clock:SetPoint("RIGHT")
    info.clockButton:SetScript("OnClick", function()
        if TimeManager_Toggle then TimeManager_Toggle()
        elseif TimeManagerFrame then TimeManagerFrame:SetShown(not TimeManagerFrame:IsShown()) end
    end)

    -- Calendario y botones de addons.
    info.calendar = IconButton(info, MEDIA .. "icon_calendar", function()
        local pending = C_Calendar and C_Calendar.GetNumPendingInvites and Readable(C_Calendar.GetNumPendingInvites()) or 0
        return pending and pending > 0 and ns.LF("Calendario (%d invitaciones)", pending) or "Calendario"
    end, function()
        if ToggleCalendar then ToggleCalendar()
        elseif GameTimeFrame and GameTimeFrame.Click then GameTimeFrame:Click() end
    end)
    info.calendar.badge = info.calendar:CreateTexture(nil, "OVERLAY")
    info.calendar.badge:SetSize(6, 6)
    info.calendar.badge:SetPoint("TOPRIGHT", -2, -2)
    local a = M.COLORS.accent
    info.calendar.badge:SetColorTexture(a[1], a[2], a[3], 1)
    info.calendar.badge:Hide()

    info.addons = IconButton(info, MEDIA .. "icon_addons", function()
        return ns.LF("Botones de addons (%d)", #MM.collected)
    end, function() MM.ToggleFlyout() end)
    info.addons.count = info.addons:CreateFontString(nil, "OVERLAY")
    info.addons.count:SetFont(M.FONT, 9, "OUTLINE")
    info.addons.count:SetPoint("BOTTOMRIGHT", 1, -1)

    -- Panel que despliega los botones de los addons.
    MM.flyout = CreateFrame("Frame", "BlazzitoUIMinimapAddons", info)
    -- Misma capa que usan los botones de LibDBIcon ("MEDIUM") y el fondo al
    -- nivel más bajo: así quedan encima aunque fijen su capa.
    MM.flyout:SetFrameStrata("MEDIUM")
    MM.flyout:SetFrameLevel(1)
    M.SetBackdrop(MM.flyout, { 0.07, 0.07, 0.08, 0.95 })
    MM.flyout:Hide()
end

---------------------------------------------------------------------------
-- Colocar el mapa de Blizzard dentro del nuestro
---------------------------------------------------------------------------
local placing = false
local function PlaceMap()
    local minimap = _G.Minimap
    if not (minimap and holder) or placing then return end
    placing = true
    if minimap:GetParent() ~= holder then minimap:SetParent(holder) end
    minimap:ClearAllPoints()
    minimap:SetPoint("CENTER", holder, "CENTER", 0, 0)
    placing = false
end
MM.PlaceMap = PlaceMap

-- Indicadores de Blizzard que se quedan (seguimiento, correo, dificultad,
-- cola) en las esquinas del mapa.
local function Corner(frame, point, x, y)
    if type(frame) ~= "table" or not frame.SetPoint then return end
    pcall(function()
        frame:ClearAllPoints()
        frame:SetPoint(point, _G.Minimap, point, x, y)
    end)
    -- Se cuelgan de nuestra capa de encima del mapa: en el marco de Blizzard
    -- podían quedar debajo del mapa o dentro de una pieza que ocultamos (y
    -- con ella se ocultaban, como la lupa del seguimiento).
    local minimap = _G.Minimap
    pcall(function()
        if frame:GetParent() ~= info then frame:SetParent(info) end
        frame:SetFrameStrata(holder:GetFrameStrata())
        frame:SetFrameLevel((minimap:GetFrameLevel() or 1) + 15)
        if held[frame] then Hold(frame, false) end
        frame:SetAlpha(1)
    end)
end

-- Estilo de BlazzitoUI en un indicador de Blizzard: sin su aro o fondo
-- (texturas de fondo y borde) y con nuestro cuadrito oscuro con borde. El
-- icono (la lupa, el sobre...) se queda.
local styled = setmetatable({}, { __mode = "k" })
local function StyleIndicator(frame)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    local d = styled[frame]
    if not d then
        d = { border = frame:CreateTexture(nil, "BACKGROUND", nil, -8), fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7) }
        styled[frame] = d
    end
    local target = Field(frame, "Button") or frame
    for _, owner in ipairs({ frame, target ~= frame and target or nil }) do
        for _, region in ipairs({ owner:GetRegions() }) do
            if region ~= d.border and region ~= d.fill and region.GetObjectType and region:GetObjectType() == "Texture" then
                local layer = region:GetDrawLayer()
                if layer == "BACKGROUND" or layer == "BORDER" then Hold(region, true) end
            end
        end
    end
    for _, key in ipairs({ "Border", "Background", "IconOverlay" }) do Hold(Field(frame, key), true); Hold(Field(target, key), true) end
    local size = 22
    d.border:ClearAllPoints()
    d.border:SetPoint("CENTER", target, "CENTER")
    d.border:SetSize(size, size)
    d.border:SetColorTexture(0, 0, 0, 1)
    d.fill:ClearAllPoints()
    d.fill:SetPoint("TOPLEFT", d.border, "TOPLEFT", 1, -1)
    d.fill:SetPoint("BOTTOMRIGHT", d.border, "BOTTOMRIGHT", -1, 1)
    d.fill:SetColorTexture(0.08, 0.08, 0.09, 0.9)
end
MM.StyleIndicator = StyleIndicator

-- La lupa del seguimiento con nuestro icono: todo el arte de Blizzard del
-- botón (aro, fondo, la lupa antigua) a alfa 0 y encima nuestra lupa sencilla.
-- El botón es el de Blizzard: al pulsarlo abre su menú de siempre.
local function StyleTracking(frame)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    StyleIndicator(frame)
    local d = styled[frame]
    local target = Field(frame, "Button") or frame
    if not d.icon then
        d.icon = target:CreateTexture(nil, "OVERLAY", nil, 7)
        d.icon:SetTexture(M.ICONS.search)
        d.hover = target:CreateTexture(nil, "HIGHLIGHT", nil, 7)
        d.hover:SetColorTexture(1, 1, 1, 0.1)
    end
    local function Mine(region) return region == d.border or region == d.fill or region == d.icon or region == d.hover end
    for _, owner in ipairs({ frame, target ~= frame and target or nil }) do
        for _, region in ipairs({ owner:GetRegions() }) do
            if not Mine(region) and region.GetObjectType and region:GetObjectType() == "Texture" then Hold(region, true) end
        end
        for _, region in pairs({
            owner.GetNormalTexture and owner:GetNormalTexture(), owner.GetPushedTexture and owner:GetPushedTexture(),
            owner.GetHighlightTexture and owner:GetHighlightTexture(), owner.GetDisabledTexture and owner:GetDisabledTexture(),
        }) do if not Mine(region) then Hold(region, true) end end
    end
    Hold(_G.MiniMapTrackingIcon, true)
    Hold(_G.MiniMapTrackingBorder, true)
    Hold(_G.MiniMapTrackingBackground, true)
    d.icon:ClearAllPoints()
    d.icon:SetPoint("CENTER", d.border, "CENTER")
    d.icon:SetSize(14, 14)
    d.icon:SetVertexColor(0.9, 0.9, 0.95)
    d.hover:ClearAllPoints()
    d.hover:SetAllPoints(d.border)
end
MM.StyleTracking = StyleTracking

local function PlaceIndicators()
    local cluster = _G.MinimapCluster
    Corner(Field(cluster, "Tracking") or _G.MiniMapTracking or _G.MiniMapTrackingFrame or _G.MiniMapTrackingButton, "TOPLEFT", 2, -2)
    Corner(Field(cluster, "InstanceDifficulty") or _G.MiniMapInstanceDifficulty, "TOPLEFT", 2, -26)
    Corner(Field(cluster, "IndicatorFrame") or _G.MiniMapMailFrame, "BOTTOMRIGHT", -2, 2)
    Corner(_G.QueueStatusButton or _G.MiniMapLFGFrame or _G.MiniMapBattlefieldFrame, "BOTTOMLEFT", 2, 2)
    StyleTracking(Field(cluster, "Tracking") or _G.MiniMapTracking or _G.MiniMapTrackingFrame or _G.MiniMapTrackingButton)
    local indicators = Field(cluster, "IndicatorFrame")
    StyleIndicator(Field(indicators, "MailFrame") or _G.MiniMapMailFrame)
    StyleIndicator(Field(indicators, "CraftingOrderFrame"))
end

---------------------------------------------------------------------------
-- Aplicar ajustes
---------------------------------------------------------------------------
function MM.Apply()
    if not (MM.db and holder) then return end
    local cfg, minimap = MM.db, _G.Minimap
    local size = cfg.size or 220
    holder:SetSize(size, size)
    PlaceMap()
    if minimap then
        minimap:SetSize(size, size)
        -- Brújula, botones y textos siempre por encima del mapa.
        info:SetFrameLevel((minimap:GetFrameLevel() or 1) + 10)
        local file = MapFile(cfg)
        pcall(minimap.SetMaskTexture, minimap, file)
        local round = cfg.shape == "circle"
        if minimap.SetArchBlobRingScalar then pcall(minimap.SetArchBlobRingScalar, minimap, round and 1 or 0) end
        if minimap.SetQuestBlobRingScalar then pcall(minimap.SetQuestBlobRingScalar, minimap, round and 1 or 0) end
        -- El mapa se redibuja con el tamaño nuevo al tocar el zoom.
        local okZ, zoom = pcall(minimap.GetZoom, minimap)
        if okZ and type(zoom) == "number" then
            pcall(minimap.SetZoom, minimap, zoom > 0 and zoom - 1 or zoom + 1)
            pcall(minimap.SetZoom, minimap, zoom)
        end
        -- Zoom con la rueda (si Blizzard no lo hace ya).
        if cfg.wheelZoom and minimap.EnableMouseWheel and not minimap:GetScript("OnMouseWheel") then
            minimap:EnableMouseWheel(true)
            minimap:SetScript("OnMouseWheel", function(self, delta)
                local okL, levels = pcall(self.GetZoomLevels, self)
                local now = self:GetZoom()
                local target = now + (delta > 0 and 1 or -1)
                if target >= 0 and (not okL or target < levels) then self:SetZoom(target) end
            end)
        end
    end
    -- Borde y fondo con la forma.
    local file = MapFile(cfg)
    local b = (cfg.border or 0) * M.PixelSize()
    holder.border:ClearAllPoints()
    holder.border:SetPoint("TOPLEFT", -b, b)
    holder.border:SetPoint("BOTTOMRIGHT", b, -b)
    holder.border:SetTexture(file)
    local bc = cfg.borderColor or { 0, 0, 0 }
    holder.border:SetVertexColor(bc[1], bc[2], bc[3], 1)
    holder.border:SetShown(b > 0)
    holder.back:SetAllPoints()
    holder.back:SetTexture(file)
    holder.back:SetVertexColor(0.05, 0.05, 0.06, 1)
    for _, region in pairs(BlizzardArt()) do Hold(region, true) end
    -- El compartimento de addons de Blizzard (el recuadro con un número que
    -- abre un menú con tus addons) repite lo que hace nuestro botón.
    Hold(_G.AddonCompartmentFrame, not cfg.showCompartment)
    PlaceIndicators()

    -- Brújula: N S E O dentro del borde, muy legibles. Con el mapa girando
    -- (opción de Blizzard) no tiene sentido fijarlas: se ocultan.
    local rotating = GetCVar and GetCVar("rotateMinimap") == "1"
    local inset = math.max(8, size * 0.05)
    local spots = { N = { "TOP", 0, -inset * 0.6 }, S = { "BOTTOM", 0, inset * 0.6 }, E = { "RIGHT", -inset * 0.6, 0 }, O = { "LEFT", inset * 0.6, 0 } }
    local a = M.COLORS.accent
    for letter, fs in pairs(info.compass) do
        local spot = spots[letter]
        fs:SetFont(M.FONT, cfg.compassSize or 13, "THICKOUTLINE")
        fs:SetText(ns.Translate(letter))
        fs:ClearAllPoints()
        fs:SetPoint(spot[1], info, spot[1], spot[2], spot[3])
        if letter == "N" then fs:SetTextColor(a[1], a[2], a[3]) else fs:SetTextColor(1, 1, 1) end
        fs:SetAlpha((cfg.compassAlpha or 80) / 100)
        fs:SetShown(cfg.compass and not rotating)
    end

    -- Barra debajo del mapa: arriba la zona (centrada, en su propia línea) y
    -- debajo las coordenadas y la hora.
    local fontSize = cfg.fontSize or 12
    local line = fontSize + 8
    local zoneLine = cfg.zone and line or 0
    local infoLine = (cfg.coords or cfg.clock) and line or 0
    info.bar:ClearAllPoints()
    info.bar:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -2 - b)
    info.bar:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -2 - b)
    info.bar:SetHeight(math.max(1, zoneLine + infoLine))
    info.bar:SetShown(zoneLine + infoLine > 0)
    if info.zoneButton:GetParent() ~= info.bar then info.zoneButton:SetParent(info.bar) end
    info.zone:SetFont(M.FONT, fontSize + 1, "OUTLINE")
    info.zone:SetWidth(size - 16)
    info.zone:SetWordWrap(false)
    info.zoneButton:ClearAllPoints()
    info.zoneButton:SetPoint("TOPLEFT", info.bar, "TOPLEFT", 0, 0)
    info.zoneButton:SetPoint("TOPRIGHT", info.bar, "TOPRIGHT", 0, 0)
    info.zoneButton:SetHeight(line)
    info.zoneButton:SetShown(cfg.zone)
    info.coords:SetFont(M.FONT, fontSize, "OUTLINE")
    info.coords:ClearAllPoints()
    info.coords:SetPoint("BOTTOMLEFT", info.bar, "BOTTOMLEFT", 8, (line - fontSize) / 2)
    info.coords:SetShown(cfg.coords)
    info.clock:SetFont(M.FONT, fontSize, "OUTLINE")
    info.clockButton:ClearAllPoints()
    info.clockButton:SetPoint("BOTTOMRIGHT", info.bar, "BOTTOMRIGHT", -8, 0)
    info.clockButton:SetSize(70, fontSize + 8)
    info.clockButton:SetShown(cfg.clock)

    info.calendar:ClearAllPoints()
    info.calendar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -4)
    info.calendar:SetShown(cfg.calendar)
    info.addons:ClearAllPoints()
    info.addons:SetPoint("TOPRIGHT", info.calendar:IsShown() and info.calendar or holder,
        info.calendar:IsShown() and "BOTTOMRIGHT" or "TOPRIGHT", info.calendar:IsShown() and 0 or -4, info.calendar:IsShown() and -4 or -4)
    MM.Collect()
    MM.UpdateInfo()
end

---------------------------------------------------------------------------
-- Zona, hora, coordenadas y calendario
---------------------------------------------------------------------------
local ZONE_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 }, friendly = { 0.10, 1.00, 0.10 }, hostile = { 1.00, 0.10, 0.10 },
    contested = { 1.00, 0.70, 0.00 }, combat = { 1.00, 0.10, 0.10 }, arena = { 1.00, 0.10, 0.10 },
}

function MM.UpdateZone()
    if not info then return end
    local text = GetMinimapZoneText and GetMinimapZoneText() or ""
    local pvp = (C_PvP and C_PvP.GetZonePVPInfo and C_PvP.GetZonePVPInfo()) or (GetZonePVPInfo and GetZonePVPInfo())
    local color = ZONE_COLORS[pvp] or { 1, 0.85, 0.3 }
    info.zone:SetText(text)
    info.zone:SetTextColor(color[1], color[2], color[3])
end

function MM.FormatTime(hour, minute)
    if MM.db.clock24 then return string.format("%02d:%02d", hour, minute) end
    local suffix = hour < 12 and "am" or "pm"
    local h = hour % 12
    if h == 0 then h = 12 end
    return string.format("%d:%02d %s", h, minute, suffix)
end

function MM.UpdateInfo()
    if not (info and MM.db) then return end
    local cfg = MM.db
    if cfg.clock then
        local hour, minute
        if cfg.localTime then
            hour, minute = tonumber(date("%H")), tonumber(date("%M"))
        elseif GetGameTime then
            hour, minute = GetGameTime()
        end
        if hour then info.clock:SetText(MM.FormatTime(hour, minute)) end
    end
    if cfg.coords then
        local text = "--, --"
        local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if mapID and not IsSecret(mapID) then
            local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
            if ok and pos and pos.GetXY then
                local x, y = pos:GetXY()
                x, y = Readable(x), Readable(y)
                if type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
                    text = string.format("%.1f, %.1f", x * 100, y * 100)
                end
            end
        end
        info.coords:SetText(text)
    end
    if cfg.calendar and C_Calendar and C_Calendar.GetNumPendingInvites then
        local pending = Readable(C_Calendar.GetNumPendingInvites())
        info.calendar.badge:SetShown(type(pending) == "number" and pending > 0)
    end
end

---------------------------------------------------------------------------
-- Botones de los addons: recogidos en un panel que se despliega
---------------------------------------------------------------------------
MM.collected = {}
local isCollected = setmetatable({}, { __mode = "k" })
local placingButton = false

-- Puntos del mapa de otros addons (no son botones): se dejan en el mapa.
local PIN_PATTERNS = { "^HandyNotes", "^TomTom", "^HereBeDragons", "^Questie", "^GatherMate", "^[Pp]in" }
-- Piezas de Blizzard que se quedan en el mapa.
local KEEP = { MinimapZoomIn = true, MinimapZoomOut = true, MinimapBackdrop = true, GameTimeFrame = true,
               ExpansionLandingPageMinimapButton = true, AddonCompartmentFrame = true }

-- Mismo criterio que EllesmereUI: cualquier botón con nombre hijo del mapa
-- que no sea de Blizzard ni un punto del mapa (los puntos suelen acabar en
-- número) y que mida al menos 20 píxeles; y los LibDBIcon10_ siempre.
local function IsAddonButton(frame)
    if type(frame) ~= "table" or not frame.GetName or isCollected[frame] then return false end
    if frame == info or frame == holder or frame == MM.flyout then return false end
    local okN, name = pcall(frame.GetName, frame)
    if not okN or type(name) ~= "string" then return false end
    if name:find("^LibDBIcon10_") then return true end
    if KEEP[name] or name:find("^Blazzito") or name:find("%d+$") then return false end
    for _, pattern in ipairs(PIN_PATTERNS) do if name:find(pattern) then return false end end
    if issecurevariable and issecurevariable(_G, name) then return false end
    if name:find("^MiniMap") or name:find("^QueueStatus") or name:find("^TimeManager") then return false end
    local okT, isButton = pcall(frame.IsObjectType, frame, "Button")
    if not (okT and isButton) then return false end
    local okW, w = pcall(frame.GetWidth, frame)
    return okW and type(w) == "number" and not IsSecret(w) and w >= 20
end

local function Layout()
    local perRow = math.max(1, MM.db.buttonsPerRow or 5)
    local cell = 30
    for i, button in ipairs(MM.collected) do
        local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
        placingButton = true
        pcall(function()
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", MM.flyout, "TOPLEFT", 6 + col * cell, -6 - row * cell)
        end)
        placingButton = false
    end
    local count = #MM.collected
    local cols = math.min(perRow, math.max(1, count))
    local rows = math.max(1, math.ceil(count / perRow))
    MM.flyout:SetSize(12 + cols * cell - 2, 12 + rows * cell - 2)
    MM.flyout:ClearAllPoints()
    MM.flyout:SetPoint("TOPRIGHT", info.addons, "TOPLEFT", -4, 0)
    info.addons.count:SetText(count > 0 and count or "")
end

local function Take(button)
    isCollected[button] = true
    MM.collected[#MM.collected + 1] = button
    pcall(button.SetParent, button, MM.flyout)
    MM.Raise(button)
    if button.RegisterForDrag then pcall(button.RegisterForDrag, button) end   -- sin arrastrar alrededor del mapa
    -- Si el addon lo vuelve a colocar alrededor del mapa, se devuelve al panel.
    hooksecurefunc(button, "SetPoint", function()
        if not placingButton and MM.db.collectButtons then C_Timer.After(0, Layout) end
    end)
    -- Algunos addons (OmniCC) vuelven a colgar su botón de la pantalla al
    -- usarlo: entonces ya no se ocultaba al plegar el panel y se quedaba
    -- flotando. Si cambia de padre, vuelve al panel.
    hooksecurefunc(button, "SetParent", function(self, parent)
        if isCollected[self] and parent ~= MM.flyout and MM.db.collectButtons and not placingButton then
            placingButton = true
            pcall(self.SetParent, self, MM.flyout)
            MM.Raise(self)
            placingButton = false
            C_Timer.After(0, Layout)
        end
    end)
    -- LibDBIcon puede volverlos transparentes cuando el ratón sale del mapa
    -- ("mostrar al pasar el ratón"): dentro del panel siempre se ven.
    hooksecurefunc(button, "SetAlpha", function(self, alpha)
        if isCollected[self] and not IsSecret(alpha) and alpha < 1 then self:SetAlpha(1) end
    end)
    button:SetAlpha(1)
end

-- Los botones de LibDBIcon fijan su propia capa ("MEDIUM"): dentro del panel
-- quedaban por debajo de su fondo (capa "DIALOG") y no se veían.
function MM.Raise(button)
    -- Las versiones nuevas de LibDBIcon bloquean la capa del botón: se
    -- desbloquea antes de cambiarla (cada llamada por separado).
    if button.SetFixedFrameStrata then pcall(button.SetFixedFrameStrata, button, false) end
    if button.SetFixedFrameLevel then pcall(button.SetFixedFrameLevel, button, false) end
    pcall(button.SetFrameStrata, button, MM.flyout:GetFrameStrata())
    pcall(button.SetFrameLevel, button, MM.flyout:GetFrameLevel() + 10)
end

function MM.Collect()
    if not (MM.db and MM.db.collectButtons and holder) then
        if info then info.addons:SetShown(false) end
        return
    end
    local sources = { _G.Minimap, _G.MinimapBackdrop }
    for _, parent in ipairs(sources) do
        if type(parent) == "table" and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if IsAddonButton(child) then Take(child) end
            end
        end
    end
    -- Algunos addons cuelgan su botón de la pantalla y solo lo anclan al mapa.
    local function AnchoredToMap(frame)
        local ok, count = pcall(frame.GetNumPoints, frame)
        if not ok or type(count) ~= "number" then return false end
        for i = 1, count do
            local okP, _, relative = pcall(frame.GetPoint, frame, i)
            if okP and (relative == _G.Minimap or relative == _G.MinimapCluster or relative == _G.MinimapBackdrop or relative == holder) then
                return true
            end
        end
        return false
    end
    for _, child in ipairs({ UIParent:GetChildren() }) do
        if IsAddonButton(child) and AnchoredToMap(child) then Take(child) end
    end
    local LDB = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and LDB.GetButtonList then
        for _, name in ipairs(LDB:GetButtonList()) do
            local button = _G["LibDBIcon10_" .. name]
            if button and not isCollected[button] then Take(button) end
        end
    end
    table.sort(MM.collected, function(x, y) return (x:GetName() or "") < (y:GetName() or "") end)
    Layout()
    info.addons:SetShown(#MM.collected > 0)
end

function MM.ToggleFlyout()
    if not MM.flyout then return end
    MM.flyout:SetShown(not MM.flyout:IsShown())
    for _, button in ipairs(MM.collected) do
        if button:GetParent() ~= MM.flyout then pcall(button.SetParent, button, MM.flyout) end
    end
    if MM.flyout:IsShown() then
        for _, button in ipairs(MM.collected) do
            MM.Raise(button)
            button:SetAlpha(1)
        end
    end
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function MM:OnEnable()
    Build()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    ns.Movers.Register(holder, "minimap", "Minimapa", { "TOPRIGHT", "CENTER", math.floor(w / 2 - 20), math.floor(h / 2 - 40) },
        MM.db.positions, {
            getSize = function() return MM.db.size, MM.db.size end,
            setSize = function(sw, sh)
                MM.db.size = math.max(120, math.min(450, math.floor(math.max(sw, sh))))
                MM.Apply()
            end,
        })
    -- Si Blizzard vuelve a colocar el mapa (modo edición...), se devuelve.
    if _G.Minimap then
        hooksecurefunc(_G.Minimap, "SetPoint", function() if not placing then C_Timer.After(0, PlaceMap) end end)
    end
    -- Las librerías de botones preguntan la forma del minimapa.
    function GetMinimapShape() return MM.db.shape == "circle" and "ROUND" or "SQUARE" end
    for _, event in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        ns.On(event, function() if MM.active then MM.UpdateZone() end end)
    end
    ns.On("PLAYER_ENTERING_WORLD", function() if MM.active then C_Timer.After(1, MM.Apply) end end)
    ns.On("ADDON_LOADED", function() if MM.active then C_Timer.After(0.5, MM.Collect) end end)
    local clock = CreateFrame("Frame")
    local waited, slow = 0, 0
    clock:SetScript("OnUpdate", function(_, elapsed)
        waited, slow = waited + elapsed, slow + elapsed
        if waited >= 0.2 then
            waited = 0
            if MM.active then MM.UpdateInfo() end
        end
        -- Cada pocos segundos: botones de addons nuevos e indicadores en su sitio.
        if slow >= 3 then
            slow = 0
            if MM.active and not InCombatLockdown() then MM.Collect(); PlaceIndicators() end
        end
    end)
    -- /bui minimapa: qué hay alrededor del mapa (para ocultar o recoger lo que falte).
    ns.RegisterCommand("minimapa", function()
        ns.Print("minimapa: marcos con nombre alrededor del mapa")
        local seen, pins = {}, {}
        for _, parent in ipairs({ _G.Minimap, _G.MinimapCluster, _G.MinimapBackdrop, MM.flyout }) do
            if type(parent) == "table" and parent.GetChildren then
                for _, child in ipairs({ parent:GetChildren() }) do
                    local okN, name = pcall(child.GetName, child)
                    -- Los puntos del mapa (nombres que acaban en número) se resumen.
                    local base = okN and name and name:match("^(.-)%d+$")
                    if base and base ~= "" then
                        pins[base] = (pins[base] or 0) + 1
                    elseif okN and name and not seen[name] then
                        seen[name] = true
                        local okS, shown = pcall(child.IsShown, child)
                        local okW, w = pcall(child.GetWidth, child)
                        local blizzard = issecurevariable and issecurevariable(_G, name)
                        print(string.format("  %s · %s · %s · ancho %s%s", name, blizzard and "Blizzard" or "addon",
                            (okS and shown) and "visible" or "oculto", okW and tostring(math.floor((Readable(w) or 0) + 0.5)) or "?",
                            isCollected[child] and " · recogido" or ""))
                    end
                end
            end
        end
        for base, count in pairs(pins) do print(string.format("  %s… · %d puntos del mapa (se quedan en el mapa)", base, count)) end
        -- Botones sueltos en la pantalla con pinta de botón de minimapa que no
        -- se han recogido (para saber por qué alguno se queda fuera).
        for _, child in ipairs({ UIParent:GetChildren() }) do
            local okN, name = pcall(child.GetName, child)
            if okN and name and not isCollected[child] and (name:find("[Mm]inimap") or name:find("^LibDBIcon")) then
                local okP, _, relative = pcall(child.GetPoint, child, 1)
                local rel = okP and relative and relative.GetName and relative:GetName() or "?"
                print(string.format("  suelto: %s · anclado a %s", name, tostring(rel)))
            end
        end
        -- Piezas de Blizzard sin nombre propio (la lupa del seguimiento...).
        local cluster = _G.MinimapCluster
        for _, key in ipairs({ "Tracking", "IndicatorFrame", "InstanceDifficulty", "BorderTop", "ZoneTextButton" }) do
            local frame = Field(cluster, key)
            if frame then
                local ok, line = pcall(function()
                    local parent = frame:GetParent()
                    local pname = parent and (parent.GetName and parent:GetName() or tostring(parent)) or "nada"
                    if parent == info then pname = "BlazzitoUI (encima del mapa)" end
                    return string.format("  MinimapCluster.%s · %s · alfa real %.2f · capa %s nivel %s · padre %s", key,
                        frame:IsVisible() and "se ve" or "no se ve", frame:GetEffectiveAlpha(), frame:GetFrameStrata(),
                        frame:GetFrameLevel(), tostring(pname))
                end)
                print(ok and line or ("  MinimapCluster." .. key .. ": " .. tostring(line)))
            else
                print("  MinimapCluster." .. key .. ": no existe en este cliente")
            end
        end
        -- Estado de cada botón recogido (por si alguno no se ve en el panel).
        print(string.format("  panel: capa %s, nivel %s, %s", MM.flyout:GetFrameStrata(), MM.flyout:GetFrameLevel(),
            MM.flyout:IsShown() and "desplegado" or "plegado"))
        for _, button in ipairs(MM.collected) do
            local ok, line = pcall(function()
                local w, h = button:GetSize()
                return string.format("    %s · capa %s nivel %s · alfa %.2f · %s · %dx%d", button:GetName() or "?",
                    button:GetFrameStrata(), button:GetFrameLevel(), button:GetAlpha(), button:IsShown() and "visible" or "oculto",
                    math.floor((Readable(w) or 0) + 0.5), math.floor((Readable(h) or 0) + 0.5))
            end)
            print(ok and line or ("    (no se pudo leer: " .. tostring(line) .. ")"))
        end
        if MM.PawReport then MM.PawReport() end
    end, "lista lo que hay alrededor del minimapa")
    MM.Apply()
    MM.UpdateZone()
end
