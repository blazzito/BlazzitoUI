-- Estilo común: texturas, colores, fuentes y piezas visuales reutilizables.
--
-- Valores secretos: este cliente usa el motor 12.1. En contenido restringido
-- algunos datos de unidades (vida, nombre, reacción...) llegan como valores
-- "secretos": se pueden pasar a SetValue, SetText o SetFormattedText, pero no
-- comparar, sumar ni usar en un if. Readable() devuelve nil en ese caso.
local _, ns = ...

local M = {}
ns.Media = M

M.TEXTURE = "Interface\\Buttons\\WHITE8X8"
M.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Fuentes de la ventana de opciones: Barlow (OFL, Media/Fonts/FONTS-LICENSE.txt).
local FONTS = "Interface\\AddOns\\BlazzitoUI\\Media\\Fonts\\"
M.UI_FONT = FONTS .. "Barlow-Regular.ttf"
M.UI_FONT_MEDIUM = FONTS .. "Barlow-Medium.ttf"
M.UI_FONT_BOLD = FONTS .. "Barlow-SemiBold.ttf"
M.UI_FONT_HEAD = FONTS .. "BarlowCondensed-SemiBold.ttf"

M.COLORS = {
    background = { 0.06, 0.06, 0.07, 0.92 },
    border     = { 0, 0, 0, 1 },
    fallback   = { 0.30, 0.75, 0.40 },
    tapped     = { 0.55, 0.55, 0.55 },
    dead       = { 0.35, 0.35, 0.35 },
    power      = { 0.20, 0.45, 1.00 },
    cast       = { 0.95, 0.75, 0.25 },
    castLocked = { 0.60, 0.60, 0.60 },
    combo      = { 1.00, 0.82, 0.20 },
    accent     = { 0.31, 0.76, 0.97 },
}

local issecretvalue = issecretvalue

function M.Readable(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function M.IsSecret(value)
    return (issecretvalue and issecretvalue(value)) and true or false
end

-- Dinero como lo escribe WoW: oro, plata y cobre, cada número del color de su
-- moneda y con su icono; se saltan las monedas a 0 ("2 oro 4 cobre"). No se
-- usa GetCoinTextureString: en Forever lo deja todo en cobre.
M.COIN = {
    { div = 10000, color = "ffd100", icon = "Interface\\MoneyFrame\\UI-GoldIcon" },
    { div = 100,   color = "e6e6e6", icon = "Interface\\MoneyFrame\\UI-SilverIcon" },
    { div = 1,     color = "eda55f", icon = "Interface\\MoneyFrame\\UI-CopperIcon" },
}
function M.Money(copper)
    copper = M.Readable(copper)
    if type(copper) ~= "number" then return "" end
    copper = math.floor(copper + 0.5)
    local parts = {}
    for i, coin in ipairs(M.COIN) do
        local n = math.floor(copper / coin.div)
        copper = copper - n * coin.div
        -- El cobre sale aunque sea 0 si no hay nada más (0 cobre).
        if n > 0 or (i == #M.COIN and #parts == 0) then
            parts[#parts + 1] = ("|cff%s%d|r|T%s:0:0:2:0|t"):format(coin.color, n, coin.icon)
        end
    end
    return table.concat(parts, " ")
end

-- Colores de recurso propios donde el de Blizzard es demasiado fuerte.
M.POWER_COLORS = {
    MANA = { 0.24, 0.47, 0.86 },
}

-- Tamaño de un píxel real en unidades de interfaz, para bordes nítidos.
function M.PixelSize()
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, UIParent:GetEffectiveScale(), 1)
    end
    return 1
end

-- Fondo oscuro con borde negro de 1 píxel. Devuelve el grosor del borde.
function M.SetBackdrop(frame, color)
    local px = M.PixelSize()
    local border = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    border:SetAllPoints()
    border:SetColorTexture(unpack(M.COLORS.border))
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    bg:SetPoint("TOPLEFT", px, -px)
    bg:SetPoint("BOTTOMRIGHT", -px, px)
    bg:SetColorTexture(unpack(color or M.COLORS.background))
    return px
end

function M.Font(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(M.FONT, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Barra plana con fondo del mismo color pero oscurecido.
function M.StatusBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(M.TEXTURE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(M.TEXTURE)
    bar.bg = bg
    return bar
end

-- Con un color secreto (modo "según vida" en contenido restringido) no se
-- puede calcular el tono oscuro del fondo: se usa uno neutro.
function M.ColorBar(bar, r, g, b)
    bar:SetStatusBarColor(r, g, b)
    if issecretvalue and issecretvalue(r) then
        bar.bg:SetVertexColor(0.12, 0.12, 0.13, 1)
    else
        bar.bg:SetVertexColor(r * 0.22, g * 0.22, b * 0.22, 1)
    end
end

---------------------------------------------------------------------------
-- Formas de las barras
---------------------------------------------------------------------------
-- La forma se aplica con una máscara del tamaño de todo el bloque de barras,
-- así vida y recurso comparten los mismos bordes inclinados.
-- Las texturas miden 256x64 (Media/*.tga, generadas por script).
-- edge: cuánto entra el borde de la forma, en píxeles de esa textura; con él
-- se aparta el texto para que no quede cortado. depth: lo máximo que entra el
-- contorno en horizontal (para empalmar la curación con el final de la vida).
-- flips: la forma no es simétrica y tiene versiones volteadas en disco
-- (_h horizontal, _v vertical, _hv ambas). Las simétricas no cambian al voltear.
local SHAPE_PATH = "Interface\\AddOns\\BlazzitoUI\\Media\\"
M.SHAPES = {
    rect    = { text = "Rectángulo", edge = 0, depth = 0 },
    slant   = { text = "Inclinada", file = "slant", flips = true, edge = 11, depth = 18 },
    wing    = { text = "Ala (solo un lado inclinado)", file = "wing", flips = true, edge = 11, depth = 18 },
    bevel   = { text = "Chaflán (esquinas cortadas)", file = "bevel", edge = 4, depth = 12 },
    rounded = { text = "Redondeada", file = "rounded", edge = 4, depth = 14 },
    hex     = { text = "Hexagonal (en punta)", file = "hex", edge = 9, depth = 18 },
}
M.SHAPE_ORDER = { "slant", "wing", "rect", "bevel", "rounded", "hex" }

-- flipH / flipV: voltear la forma en horizontal o en vertical.
function M.ShapeTexture(shape, flipH, flipV)
    local info = M.SHAPES[shape]
    if not (info and info.file) then return M.TEXTURE end
    if not info.flips then return SHAPE_PATH .. info.file end
    local suffix = (flipH and "h" or "") .. (flipV and "v" or "")
    return SHAPE_PATH .. info.file .. (suffix ~= "" and ("_" .. suffix) or "")
end

-- Formas cuadradas (64x64) para botones y casillas: barras de acción,
-- bolsas... Comparten las máscaras btn_<forma>[_h|_v|_hv].
M.BUTTON_SHAPES = {
    square  = { text = "Cuadrado" },
    slant   = { text = "Inclinado", flips = true },
    wing    = { text = "Ala (un lado inclinado)", flips = true },
    bevel   = { text = "Chaflán (esquinas cortadas)" },
    rounded = { text = "Redondeado" },
    hex     = { text = "Hexagonal" },
    circle  = { text = "Círculo" },
}
M.BUTTON_SHAPE_ORDER = { "slant", "wing", "square", "bevel", "rounded", "hex", "circle" }

function M.ButtonShape(shape, flipH, flipV)
    if not M.BUTTON_SHAPES[shape] then shape = "square" end
    local info = M.BUTTON_SHAPES[shape]
    local suffix = info.flips and ((flipH and "h" or "") .. (flipV and "v" or "")) or ""
    return SHAPE_PATH .. "btn_" .. shape .. (suffix ~= "" and ("_" .. suffix) or "")
end

-- Margen para el texto en un bloque de barras de este ancho.
function M.ShapeInset(shape, width)
    local info = M.SHAPES[shape] or M.SHAPES.rect
    return width * info.edge / 256 + 6
end

---------------------------------------------------------------------------
-- Color según la vida: verde -> amarillo -> rojo
---------------------------------------------------------------------------
local GRADIENT = {
    { 0.0, 0.85, 0.15, 0.15 },
    { 0.5, 0.95, 0.80, 0.20 },
    { 1.0, 0.25, 0.80, 0.30 },
}
local curve

-- Devuelve ok, r, g, b. Con la curva del cliente el color sale aunque la vida
-- sea secreta (los r, g, b también pueden serlo: solo sirven para pintar).
function M.HealthGradient(unit)
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor then
        if not curve then
            curve = C_CurveUtil.CreateColorCurve()
            if curve.SetType and Enum and Enum.LuaCurveType then
                curve:SetType(Enum.LuaCurveType.Linear)
            end
            for _, p in ipairs(GRADIENT) do
                curve:AddPoint(p[1], CreateColor(p[2], p[3], p[4], 1))
            end
        end
        local color = UnitHealthPercent(unit, true, curve)
        if type(color) == "table" and color.GetRGB then
            return true, color:GetRGB()
        end
    end
    local percent, ok = M.HealthPercent(unit)
    percent = ok and M.Readable(percent)
    if not percent then return false end
    local t = math.max(0, math.min(1, percent / 100))
    local low, high = GRADIENT[1], GRADIENT[2]
    if t > 0.5 then low, high = GRADIENT[2], GRADIENT[3] end
    local f = (t - low[1]) / (high[1] - low[1])
    return true, low[2] + (high[2] - low[2]) * f, low[3] + (high[3] - low[3]) * f, low[4] + (high[4] - low[4]) * f
end

---------------------------------------------------------------------------
-- Números (aceptan valores secretos)
---------------------------------------------------------------------------
local Abbreviate = AbbreviateNumbers or AbbreviateLargeNumbers

function M.ShortValue(value)
    if Abbreviate then return Abbreviate(value) end
    return value
end

-- Un valor que puede venir nil (sin curación entrante, sin escudo) o secreto.
-- Con un secreto no se puede usar "or 0" (eso ya es una comprobación).
function M.OrZero(value)
    if issecretvalue and issecretvalue(value) then return value end
    return value or 0
end

-- Porcentaje del recurso 0-100. El segundo valor es false si no se pudo calcular.
function M.PowerPercent(unit, powerType)
    if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
        return UnitPowerPercent(unit, powerType, true, CurveConstants.ScaleTo100), true
    end
    local current, max = M.Readable(UnitPower(unit)), M.Readable(UnitPowerMax(unit))
    if current and max and max > 0 then
        return current / max * 100, true
    end
    return 0, false
end

M.ICONS = {
    copy = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_copy",
    revert = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_revert",
    move   = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_move",
    reset  = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_reset",
    reload = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_reload",
    close  = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_close",
    sort   = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_sort",
    chevron = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_chevron",
    check  = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_check",
    search = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_search",
    maximize = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_maximize",
    minimize = "Interface\\AddOns\\BlazzitoUI\\Media\\icon_minimize",
    circle = "Interface\\AddOns\\BlazzitoUI\\Media\\ui_circle",
}

-- Iconos de trazo de la barra lateral de opciones (tools/make_ui.py).
M.NAV_ICONS = {}
for _, key in ipairs({ "home", "unit", "group", "aura", "plate", "threat", "bars", "bolt", "window", "compass",
                       "bag", "quest", "chat", "monitor", "layers", "sliders", "copy", "search", "eye", "gamepad", "radial" }) do
    M.NAV_ICONS[key] = "Interface\\AddOns\\BlazzitoUI\\Media\\nav_" .. key
end

-- Porcentaje de vida 0-100. El segundo valor es false si no se pudo calcular.
function M.HealthPercent(unit)
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        return UnitHealthPercent(unit, true, CurveConstants.ScaleTo100), true
    end
    local current, max = M.Readable(UnitHealth(unit)), M.Readable(UnitHealthMax(unit))
    if current and max and max > 0 then
        return current / max * 100, true
    end
    return 0, false
end
