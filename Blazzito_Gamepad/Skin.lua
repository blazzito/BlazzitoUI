-- Nuestro estilo sobre el HUD de mando de Blizzard (solo con el estilo de
-- mando, decidido al entrar: Pad.Session).
--
--  * Botones de las barras de mando: el aro dorado, la sombra y el brillo de
--    Blizzard se apagan y se pone un borde de 1 px (aro en los redondos, recto
--    en los cuadrados): negro normal, color de la clase en la barra activa (al
--    mantener LT/RT) o con el botón marcado, claro al pulsar. La «piedra» de
--    cada casilla (SlotArt: disco o flecha con bisel, siempre detrás del
--    icono) se cambia por un fondo oscuro con la forma del botón y, en las
--    casillas vacías, la letra (A/B/X/Y) o una flecha fina de la cruceta.
--  * Leyenda de botones: el marco de diálogo y la línea dorada se cambian por
--    un panel recto oscuro con línea de 1 px del acento arriba.
--
-- Cómo, sin contaminar nada (los botones son seguros):
--  * Solo texturas: nada de marcos hijos (la navegación de mando recorre
--    marcos), ni scripts, ni campos escritos en lo de Blizzard (lo nuestro va
--    en tablas débiles).
--  * Apagar = alfa del COLOR a 0 (SetVertexColor), con un gancho posterior por
--    si alguien lo vuelve a poner. Las animaciones de Blizzard cambian el alfa
--    de la región, no el del color, así que tampoco lo encienden.
--  * El estado (barra activa, marcado, pulsado) se lee cada 0,1 s.
--  * Lo nuevo se viste fuera de combate (ns.AfterCombat).
local ns = BlazzitoUI
local GP = ns and ns.Gamepad
if not GP then return end

local Pad, W = ns.Pad, ns.Widgets
-- Motor 12.x: lo que se lee de un botón de acción (marcado, pulsado, icono…)
-- puede ser un valor secreto. Solo se usa tras Readable (nil si es secreto).
local Readable = ns.Media.Readable
local T = W.T
local ACCENT = W.COLORS.accent
local RING = "Interface\\AddOns\\Blazzito_Gamepad\\Media\\gp_ring"
local DISC = "Interface\\AddOns\\BlazzitoUI\\Media\\ui_circle"
local ARROW = ns.Media.ICONS.chevron   -- apunta a la derecha

local BASE = { 0, 0, 0, 0.9 }
local PRESS = { 0.95, 0.95, 0.95, 1 }
local PANEL = { T.bg[1], T.bg[2], T.bg[3], 0.86 }
local SLOT = { T.bg[1], T.bg[2], T.bg[3], 0.72 }   -- fondo de cada casilla

-- Posición del botón en su grupo (buttonIndexOnActionBar de Blizzard):
-- izquierda, arriba, derecha, abajo. Letras de los botones de la cara (Xbox)
-- si el dibujo de Blizzard no dice otra cosa, y giro de la flecha de la cruceta.
local FACE_LETTERS = { "X", "Y", "B", "A" }
local ARROW_ROTATION = { math.pi, math.pi / 2, 0, -math.pi / 2 }

local S = {}
GP.Skin = S

local skins = setmetatable({}, { __mode = "k" })    -- botón -> nuestras piezas
local muted = setmetatable({}, { __mode = "k" })    -- textura de Blizzard apagada
local held = setmetatable({}, { __mode = "k" })     -- marco de Blizzard con alfa 0
local legendSkins = setmetatable({}, { __mode = "k" })
local buttons = {}

---------------------------------------------------------------------------
-- Apagar piezas de Blizzard
---------------------------------------------------------------------------
local function Mute(tex)
    if type(tex) ~= "table" or not tex.SetVertexColor or muted[tex] then return end
    muted[tex] = true
    local r, g, b = tex:GetVertexColor()
    tex:SetVertexColor(r or 1, g or 1, b or 1, 0)
    hooksecurefunc(tex, "SetVertexColor", function(self, r2, g2, b2, a)
        local alpha = Readable(a)
        if muted[self] and (alpha == nil or alpha > 0) then self:SetVertexColor(r2 or 1, g2 or 1, b2 or 1, 0) end
    end)
end
S.Mute = Mute

local function Hold(frame)
    if type(frame) ~= "table" or not frame.SetAlpha or held[frame] then return end
    held[frame] = true
    frame:SetAlpha(0)
    hooksecurefunc(frame, "SetAlpha", function(self, a)
        if held[self] and Readable(a) ~= 0 then self:SetAlpha(0) end
    end)
end

local function Shown(region)
    return type(region) == "table" and region.IsShown and Readable(region:IsShown()) == true
end

---------------------------------------------------------------------------
-- Botones de las barras de mando
---------------------------------------------------------------------------
-- Lo de Blizzard que se apaga en cada botón.
local MUTE_KEYS = { "SlotArt", "NormalTexture", "PushedTexture", "HighlightTexture", "CheckedTexture", "Border",
    "CircleShadow", "SquareShadow", "CircleShadowFocus", "SquareShadowFocus", "CircleGlowFocus", "SquareGlowFocus" }

local function IsGamepadButton(f)
    return f.SlotArt ~= nil and (f.CircleMask ~= nil or f.SquareMask ~= nil)
        and f.IsObjectType ~= nil and f:IsObjectType("CheckButton")
end

local function Collect(frame, depth, out)
    if depth > 10 or not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not (child.IsForbidden and child:IsForbidden()) then
            if IsGamepadButton(child) then
                out[#out + 1] = child
            else
                Collect(child, depth + 1, out)
            end
        end
    end
end

local function Edge(button)
    local t = button:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

local function SkinButton(button)
    if skins[button] then return end
    for _, key in ipairs(MUTE_KEYS) do Mute(button[key]) end
    local d = {}
    -- Redondo: el aro, un píxel por fuera del icono.
    d.ring = button:CreateTexture(nil, "OVERLAY", nil, 6)
    d.ring:SetTexture(RING)
    d.ring:SetPoint("TOPLEFT", -1, 1)
    d.ring:SetPoint("BOTTOMRIGHT", 1, -1)
    -- Cuadrado: cuatro líneas de 1 px.
    d.edges = { Edge(button), Edge(button), Edge(button), Edge(button) }
    local top, bottom, left, right = d.edges[1], d.edges[2], d.edges[3], d.edges[4]
    top:SetPoint("TOPLEFT", -1, 1); top:SetPoint("TOPRIGHT", 1, 1); top:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", -1, -1); bottom:SetPoint("BOTTOMRIGHT", 1, -1); bottom:SetHeight(1)
    left:SetPoint("TOPLEFT", -1, 1); left:SetPoint("BOTTOMLEFT", -1, -1); left:SetWidth(1)
    right:SetPoint("TOPRIGHT", 1, 1); right:SetPoint("BOTTOMRIGHT", 1, -1); right:SetWidth(1)
    -- Fondo oscuro con la forma del botón (en lugar de la «piedra» de SlotArt).
    d.disc = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.disc:SetTexture(DISC)
    d.disc:SetVertexColor(SLOT[1], SLOT[2], SLOT[3], SLOT[4])
    d.disc:SetAllPoints()
    d.square = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.square:SetColorTexture(SLOT[1], SLOT[2], SLOT[3], SLOT[4])
    d.square:SetAllPoints()
    -- Casilla vacía: qué botón es (letra en los redondos, flecha en los cuadrados).
    d.letter = W.Text(button, 13, T.muted, false, "medium")
    d.letter:SetPoint("CENTER", 0, 0)
    d.arrow = button:CreateTexture(nil, "ARTWORK", nil, 7)
    d.arrow:SetTexture(ARROW)
    d.arrow:SetVertexColor(T.muted[1], T.muted[2], T.muted[3], 1)
    d.arrow:SetSize(10, 10)
    d.arrow:SetPoint("CENTER")
    skins[button] = d
end

-- La letra del botón: del dibujo de Blizzard («…-xbox-y-normal»), o por su posición.
function S.FaceLetter(button)
    local art = button.SlotArt
    local atlas = art and art.GetAtlas and Readable(art:GetAtlas())
    if type(atlas) == "string" then
        local letter = atlas:lower():match("%-xbox%-(%a)%-")
        if letter then return letter:upper() end
    end
    local index = button.buttonIndexOnActionBar
    return type(index) == "number" and FACE_LETTERS[index] or nil
end

-- ¿Casilla vacía? (sin icono a la vista)
local function Empty(button)
    local icon = button.icon
    if type(icon) ~= "table" or not icon.IsShown then return false end
    local shown = Readable(icon:IsShown())
    if shown == nil then return false end
    if not shown then return true end
    local texture = icon:GetTexture()
    -- Una textura secreta es una textura: la casilla no está vacía.
    if ns.Media.IsSecret(texture) then return false end
    return texture == nil
end

local function SetColor(d, c)
    d.ring:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
    for _, e in ipairs(d.edges) do e:SetVertexColor(c[1], c[2], c[3], c[4] or 1) end
end

-- Color según el estado: pulsado, barra activa o marcado, normal.
function S.ButtonColor(button)
    if button.GetButtonState and Readable(button:GetButtonState()) == "PUSHED" then return PRESS end
    local checked = button.GetChecked and Readable(button:GetChecked())
    if checked == true or Shown(button.CircleShadowFocus) or Shown(button.SquareShadowFocus) then
        return ACCENT
    end
    return BASE
end

local function PaintButton(button, d)
    local circle = Shown(button.CircleMask) or not Shown(button.SquareMask)
    if d.circle ~= circle then
        d.circle = circle
        d.ring:SetShown(circle)
        d.disc:SetShown(circle)
        d.square:SetShown(not circle)
        for _, e in ipairs(d.edges) do e:SetShown(not circle) end
        d.empty = nil
    end
    local empty = Empty(button)
    if d.empty ~= empty then
        d.empty = empty
        local letter = empty and circle and S.FaceLetter(button) or nil
        d.letter:SetText(letter or "")
        d.letter:SetShown(letter ~= nil)
        local index = button.buttonIndexOnActionBar
        local rotation = empty and not circle and type(index) == "number" and ARROW_ROTATION[index] or nil
        d.arrow:SetShown(rotation ~= nil)
        if rotation then d.arrow:SetRotation(rotation) end
    end
    local c = S.ButtonColor(button)
    if d.color ~= c then
        d.color = c
        SetColor(d, c)
    end
end

---------------------------------------------------------------------------
-- Leyenda de botones (un fondo por grupo: GamepadPersistentInputLegendBackgroundTemplate)
---------------------------------------------------------------------------
local function SkinLegendBackground(bg)
    if legendSkins[bg] then return end
    Hold(bg.Background)
    Mute(bg.HeaderTrim)
    local d = {}
    d.fill = bg:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.fill:SetAllPoints()
    d.fill:SetColorTexture(PANEL[1], PANEL[2], PANEL[3], PANEL[4])
    d.edges = {}
    for i = 1, 4 do
        local e = bg:CreateTexture(nil, "BORDER", nil, 1)
        e:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
        d.edges[i] = e
    end
    d.edges[1]:SetPoint("TOPLEFT"); d.edges[1]:SetPoint("TOPRIGHT"); d.edges[1]:SetHeight(1)
    d.edges[2]:SetPoint("BOTTOMLEFT"); d.edges[2]:SetPoint("BOTTOMRIGHT"); d.edges[2]:SetHeight(1)
    d.edges[3]:SetPoint("TOPLEFT"); d.edges[3]:SetPoint("BOTTOMLEFT"); d.edges[3]:SetWidth(1)
    d.edges[4]:SetPoint("TOPRIGHT"); d.edges[4]:SetPoint("BOTTOMRIGHT"); d.edges[4]:SetWidth(1)
    -- Arriba, la línea del acento (como la cabecera de /bui).
    d.top = bg:CreateTexture(nil, "BORDER", nil, 2)
    d.top:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    d.top:SetPoint("TOPLEFT", 1, -1); d.top:SetPoint("TOPRIGHT", -1, -1); d.top:SetHeight(1)
    -- En lugar de la línea dorada bajo el título: una de 1 px.
    if type(bg.HeaderTrim) == "table" then
        d.trim = bg:CreateTexture(nil, "ARTWORK", nil, 1)
        d.trim:SetColorTexture(T.sectionLine[1], T.sectionLine[2], T.sectionLine[3], 1)
        d.trim:SetPoint("LEFT", bg.HeaderTrim, "LEFT")
        d.trim:SetPoint("RIGHT", bg.HeaderTrim, "RIGHT")
        d.trim:SetHeight(1)
    end
    legendSkins[bg] = d
end

local function PaintLegendBackground(bg, d)
    if d.trim then
        local show = Shown(bg.HeaderTrim)
        if d.trimShown ~= show then d.trimShown = show; d.trim:SetShown(show) end
    end
end

local function LegendBackgrounds()
    local list = {}
    local legend = _G.GamepadPersistentInputLegend
    if not (legend and legend.GetChildren) then return list end
    for _, child in ipairs({ legend:GetChildren() }) do
        if child.Background ~= nil and child.HeaderTrim ~= nil then list[#list + 1] = child end
    end
    return list
end

---------------------------------------------------------------------------
-- Buscar, vestir y repasar
---------------------------------------------------------------------------
function S.Scan()
    if not S.running then return end
    ns.AfterCombat("bui-gamepad-skin", function()
        if GP.db.skinButtons then
            local list = {}
            local root = _G.GamepadMainActionBarFrame
            if root then Collect(root, 0, list) end
            for _, button in ipairs(list) do SkinButton(button) end
            buttons = list
        end
        if GP.db.skinLegend then
            for _, bg in ipairs(LegendBackgrounds()) do SkinLegendBackground(bg) end
        end
    end)
end

function S.Paint()
    for _, button in ipairs(buttons) do
        local d = skins[button]
        if d and Readable(button:IsVisible()) == true then PaintButton(button, d) end
    end
    for bg, d in pairs(legendSkins) do PaintLegendBackground(bg, d) end
end

-- Nuestras piezas de un botón o fondo de la leyenda (diagnóstico y pruebas).
function S.Pieces(frame)
    return skins[frame] or legendSkins[frame]
end

function S.Count()
    local n, l = 0, 0
    for _ in pairs(skins) do n = n + 1 end
    for _ in pairs(legendSkins) do l = l + 1 end
    return n, l
end

local driver
function S.Start()
    if S.running or not Pad.Session() then return false end
    if not (GP.db.skinButtons or GP.db.skinLegend) then return false end
    S.running = true
    driver = CreateFrame("Frame")
    local paintClock, scanClock = 0, 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        paintClock = paintClock + elapsed
        if paintClock >= 0.1 then paintClock = 0; S.Paint() end
        -- Blizzard crea piezas al cambiar de juego de barras o de grupo de la leyenda.
        scanClock = scanClock + elapsed
        if scanClock >= 10 then scanClock = 0; S.Scan() end
    end)
    S.Scan()
    -- Al entrar, las barras de mando aún se están montando: otro repaso enseguida.
    C_Timer.After(1, S.Scan)
    C_Timer.After(4, S.Scan)
    for _, event in ipairs({ "UPDATE_BINDINGS", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
                             "GAMEPAD_STANCE_BAR_OVERRIDE_CHANGED", "GAMEPAD_POSSESS_BAR_OVERRIDE_CHANGED" }) do
        pcall(ns.On, event, function() C_Timer.After(0.2, S.Scan) end)
    end
    return true
end
