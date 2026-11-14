-- Controles con el estilo de BlazzitoUI para la ventana de configuración.
-- Cada control tiene :Refresh() (relee su valor) y :SetActive(bool).
-- Estilo «Taller»: casi recto (radio 2 px), líneas de 1 px, sin sombras ni
-- brillos, fuente Barlow y el ACENTO = color de la clase del personaje, usado
-- con moderación. Todos los colores y medidas salen de W.T (tokens).
-- La API (W.Toggle, W.Slider, W.Dropdown, W.Color, W.Button, W.IconButton,
-- W.Tabs, W.Layout) no cambia.
local _, ns = ...

local M = ns.Media
local W = {}
ns.Widgets = W
-- Idioma: los controles traducen solos lo que muestran (Locale.lua).
local Tr = ns.Translate

local function hex(h)
    return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, 1 }
end

-- Tokens del sistema visual.
local T = {
    bg = hex("0D0E10"),          -- ventana y campos de texto
    chrome = hex("111316"),      -- cabecera y menú lateral
    surface = hex("16181C"),     -- superficies
    field = hex("1C1F23"),       -- botones, interruptor apagado, elemento activo del menú
    rowHover = hex("15171B"),
    navHover = hex("181A1E"),
    line = hex("24272C"),        -- separadores
    ctrlBorder = hex("2E3238"),  -- bordes de controles
    btnBorder = hex("33373D"),
    btnBorderHot = hex("4A5059"),
    switchBorder = hex("3A3F46"),
    switchKnob = hex("6B717A"),
    rowLine = hex("1E2125"),     -- entre filas
    sectionLine = hex("2A2E33"),
    text = hex("E6E8EB"),
    textSoft = hex("C9CDD3"),
    navText = hex("AEB4BC"),
    muted = hex("9BA1A9"),
    dim = hex("8A9099"),
    min = hex("7D838C"),
    warn = hex("E8B04A"),        -- avisos «al recargar» (solo texto pequeño)
    onAccent = hex("0D0E10"),    -- texto y pulgar sobre el acento
    radius = 2,
    rowH = 34,
}
W.T = T

-- Acento: el color de la clase del personaje (se rellena al cargar y al entrar).
local ACCENT = { M.COLORS.accent[1], M.COLORS.accent[2], M.COLORS.accent[3], 1 }
function W.RefreshAccent()
    local class = UnitClass and select(2, UnitClass("player"))
    local c = class and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if c and c.r then ACCENT[1], ACCENT[2], ACCENT[3] = c.r, c.g, c.b end
    return ACCENT
end
pcall(W.RefreshAccent)
if ns.On then ns.On("PLAYER_LOGIN", function() W.RefreshAccent() end) end

local TEXT, MUTED, DIM = T.text, T.muted, T.dim
W.COLORS = { accent = ACCENT, text = TEXT, muted = MUTED, dim = DIM, min = T.min, warn = T.warn,
    field = T.field, fieldBorder = T.ctrlBorder, hover = T.rowHover, card = T.surface, cardBorder = T.line }

local function Color(region, c, alpha)
    region:SetColorTexture(c[1], c[2], c[3], alpha or c[4] or 1)
end

-- Mayúsculas que respetan las tildes y la ñ (string.upper no las cambia).
local UPPER = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
function W.Upper(s)
    return (tostring(s or ""):upper():gsub("\195[\128-\191]", function(c) return UPPER[c] end))
end

-- weight: nil (normal), "medium", "bold" o "head" (títulos, condensada).
local WEIGHTS = { medium = "UI_FONT_MEDIUM", bold = "UI_FONT_BOLD", head = "UI_FONT_HEAD" }
function W.Text(parent, size, color, wrap, weight)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    size = size or 12
    -- Barlow es algo más pequeña que la fuente del juego: un punto más.
    if not fs:SetFont(M[WEIGHTS[weight] or "UI_FONT"], size + 1, "") then
        fs:SetFont(M.FONT, size, "")
    end
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(wrap and true or false)
    fs:SetTextColor(unpack(color or TEXT))
    return fs
end

-- Título de sección: condensada, mayúsculas, color secundario.
function W.SectionTitle(parent, text, size)
    local fs = W.Text(parent, size or 12, DIM, false, "head")
    fs:SetText(W.Upper(Tr(text)))
    return fs
end

---------------------------------------------------------------------------
-- Rectángulo con esquinas (casi rectas): 4 esquinas (cuartos de ui_circle) y
-- 3 franjas. r:SetColor(r, g, b, a), r:Place(margen), r:SetShown(bool)
---------------------------------------------------------------------------
local QUARTERS = { tl = { 0, 0.5, 0, 0.5 }, tr = { 0.5, 1, 0, 0.5 }, bl = { 0, 0.5, 0.5, 1 }, br = { 0.5, 1, 0.5, 1 } }

function W.Round(parent, radius, layer, sublevel)
    local r = { parent = parent, radius = radius or T.radius, inset = 0, parts = {} }
    local function Tex(circle)
        local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
        t:SetTexture(circle and M.ICONS.circle or M.TEXTURE)
        r.parts[#r.parts + 1] = t
        return t
    end
    for key, coords in pairs(QUARTERS) do
        r[key] = Tex(true)
        r[key]:SetTexCoord(unpack(coords))
    end
    r.mid, r.left, r.right = Tex(), Tex(), Tex()

    function r:Place(inset)
        local i, R = inset or self.inset, self.radius
        self.inset = i
        local p = self.parent
        for _, key in ipairs({ "tl", "tr", "bl", "br", "mid", "left", "right" }) do self[key]:ClearAllPoints() end
        for key in pairs(QUARTERS) do self[key]:SetSize(R, R) end
        self.tl:SetPoint("TOPLEFT", p, "TOPLEFT", i, -i)
        self.tr:SetPoint("TOPRIGHT", p, "TOPRIGHT", -i, -i)
        self.bl:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", i, i)
        self.br:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i)
        self.mid:SetPoint("TOPLEFT", p, "TOPLEFT", i + R, -i)
        self.mid:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -(i + R), i)
        self.left:SetPoint("TOPLEFT", p, "TOPLEFT", i, -(i + R))
        self.left:SetPoint("BOTTOMRIGHT", p, "BOTTOMLEFT", i + R, i + R)
        self.right:SetPoint("TOPLEFT", p, "TOPRIGHT", -(i + R), -(i + R))
        self.right:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -i, i + R)
        return self
    end
    -- Deja una esquina recta ("tl", "tr", "bl" o "br").
    function r:SetSquare(key)
        self[key]:SetTexture(M.TEXTURE)
        self[key]:SetTexCoord(0, 1, 0, 1)
        return self
    end
    function r:SetRadius(px)
        self.radius = px
        return self:Place()
    end
    function r:SetColor(cr, cg, cb, ca)
        if type(cr) == "table" then cr, cg, cb, ca = cr[1], cr[2], cr[3], cr[4] end
        for _, t in ipairs(self.parts) do t:SetVertexColor(cr, cg, cb, ca or 1) end
        return self
    end
    function r:SetShown(shown)
        for _, t in ipairs(self.parts) do t:SetShown(shown) end
    end
    function r:SetAlpha(a)
        for _, t in ipairs(self.parts) do t:SetAlpha(a) end
    end
    r:Place(0)
    return r
end

-- Panel con borde de 1 píxel: fondo y borde (los dos son W.Round).
function W.Panel(frame, radius, fill, border, sublevel)
    local sub = sublevel or -8
    radius = radius or T.radius
    local panel = {}
    if border then
        panel.border = W.Round(frame, radius, "BACKGROUND", sub):SetColor(border)
    end
    panel.fill = W.Round(frame, border and math.max(1, radius - 1) or radius, "BACKGROUND", sub + 1)
    panel.fill:Place(border and 1 or 0):SetColor(fill)
    frame.panel = panel
    return panel
end

-- Línea de 1 píxel (horizontal por defecto).
function W.Line(parent, color, vertical, layer)
    local line = parent:CreateTexture(nil, layer or "ARTWORK")
    if vertical then line:SetWidth(1) else line:SetHeight(1) end
    Color(line, color or T.line)
    return line
end

local function SetActive(self, active)
    self.active = active
    self:SetAlpha(active and 1 or 0.35)
    if self.input then self.input:EnableMouse(active) end
end

-- Base común: un marco del ancho pedido con su etiqueta encima.
local function Base(parent, width, height, label)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, height)
    f.SetActive = SetActive
    f.active = true
    if label then
        f.label = W.Text(f, 12.5, T.textSoft)
        f.label:SetPoint("TOPLEFT")
        f.label:SetText(Tr(label))
    end
    return f
end

-- Botón con forma de campo: fondo, borde de 1 px que se aclara al pasar el ratón.
local function Field(parent, fill, border)
    local field = CreateFrame("Button", nil, parent)
    field.fillColor, field.borderColor = fill or T.bg, border or T.ctrlBorder
    local panel = W.Panel(field, T.radius, field.fillColor, field.borderColor)
    function field:SetHover(on)
        panel.border:SetColor(on and T.btnBorderHot or self.borderColor)
    end
    field:SetScript("OnEnter", function(self) self:SetHover(true) end)
    field:SetScript("OnLeave", function(self) self:SetHover(false) end)
    return field
end
W.Field = Field

---------------------------------------------------------------------------
-- Interruptor: rectangular 30×16, pulgar cuadrado. Encendido = fondo neutro
-- (#2E3238) y el pulgar del acento a la derecha; apagado = pulgar gris a la
-- izquierda. Se distinguen por la posición del pulgar, no solo por el color,
-- y una columna de interruptores no llena la pantalla del color de la clase.
---------------------------------------------------------------------------
local SWITCH_W, SWITCH_H, KNOB = 30, 16, 10

function W.Switch(parent)
    local track = CreateFrame("Frame", nil, parent)
    track:SetSize(SWITCH_W, SWITCH_H)
    local panel = W.Panel(track, T.radius, T.field, T.switchBorder, 0)
    track.knob = track:CreateTexture(nil, "ARTWORK", nil, 2)
    track.knob:SetTexture(M.TEXTURE)
    track.knob:SetSize(KNOB, KNOB)
    function track:SetOn(on, hot)
        if on then
            panel.fill:SetColor(T.ctrlBorder)
            panel.border:SetColor(hot and T.btnBorderHot or T.switchBorder)
            self.knob:SetVertexColor(unpack(ACCENT))
        else
            panel.fill:SetColor(T.field)
            panel.border:SetColor(hot and T.btnBorderHot or T.switchBorder)
            self.knob:SetVertexColor(unpack(hot and T.textSoft or T.switchKnob))
        end
        self.knob:ClearAllPoints()
        self.knob:SetPoint(on and "RIGHT" or "LEFT", on and -3 or 3, 0)
    end
    return track
end

function W.Toggle(parent, width, label, get, set)
    local f = Base(parent, width, 26)
    local button = CreateFrame("Button", nil, f)
    button:SetAllPoints()
    f.input = button

    local switch = W.Switch(button)
    switch:SetPoint("RIGHT")
    f.switch = switch

    local text = W.Text(button, 13, T.textSoft)
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    text:SetText(Tr(label))

    local hot = false
    button:SetScript("OnClick", function()
        set(not get())
        f:Refresh()
    end)
    button:SetScript("OnEnter", function()
        hot = true
        text:SetTextColor(unpack(TEXT))
        f:Refresh()
    end)
    button:SetScript("OnLeave", function()
        hot = false
        text:SetTextColor(unpack(T.textSoft))
        f:Refresh()
    end)

    function f:Refresh()
        switch:SetOn(get() and true or false, hot)
    end
    return f
end

---------------------------------------------------------------------------
-- Deslizador: etiqueta y caja numérica arriba; pista de 2 px y pulgar
-- rectangular 8×14.
---------------------------------------------------------------------------
function W.Slider(parent, width, label, min, max, step, get, set)
    local f = Base(parent, width, 44, label)

    local function Snap(v)
        v = math.max(min, math.min(max, v))
        return math.floor(v / step + 0.5) * step
    end
    -- Pasos decimales (0,5 / 0,1) se muestran con un decimal.
    local function Show(v)
        if step < 1 then return string.format("%.1f", v) end
        return tostring(math.floor(v + 0.5))
    end

    -- Número: se puede escribir y se aplica con Intro.
    local box = CreateFrame("EditBox", nil, f)
    box:SetSize(52, 22)
    box:SetPoint("TOPRIGHT", 0, 3)
    box:SetAutoFocus(false)
    box:SetJustifyH("RIGHT")
    if not box:SetFont(M.UI_FONT_MEDIUM, 13, "") then box:SetFont(M.FONT, 12, "") end
    box:SetTextColor(unpack(TEXT))
    box:SetTextInsets(6, 6, 0, 0)
    W.Panel(box, T.radius, T.bg, T.ctrlBorder)
    f.value = box

    local slider = CreateFrame("Slider", nil, f)
    slider:SetPoint("TOPLEFT", 0, -24)
    slider:SetPoint("TOPRIGHT", 0, -24)
    slider:SetHeight(16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    f.input = slider

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    track:SetHeight(2)
    Color(track, T.ctrlBorder)

    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(M.TEXTURE)
    thumb:SetSize(8, 14)
    thumb:SetVertexColor(unpack(TEXT))
    slider:SetThumbTexture(thumb)

    -- Tramo recorrido: del inicio al pulgar, en el acento.
    local fill = slider:CreateTexture(nil, "BORDER")
    fill:SetPoint("LEFT", track, "LEFT")
    fill:SetPoint("RIGHT", thumb, "CENTER")
    fill:SetHeight(2)
    fill:SetTexture(M.TEXTURE)
    f.fill = fill

    local updating
    slider:SetScript("OnValueChanged", function(_, v)
        v = Snap(v)
        if not box:HasFocus() then box:SetText(Show(v)) end
        if not updating and v ~= get() then set(v) end
    end)
    slider:SetScript("OnEnter", function() thumb:SetVertexColor(unpack(ACCENT)) end)
    slider:SetScript("OnLeave", function() thumb:SetVertexColor(unpack(TEXT)) end)
    -- Sin rueda: al desplazar la página con la rueda no se cambian valores sin querer.
    slider:EnableMouseWheel(false)

    local function Commit(self)
        local typed = (self:GetText() or ""):gsub(",", ".")
        local v = tonumber(typed)
        if v then
            v = Snap(v)
            if v ~= get() then set(v) end
        end
        self:ClearFocus()
        f:Refresh()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEditFocusLost", function() f:Refresh() end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Refresh()
    end)

    local baseActive = f.SetActive
    function f:SetActive(active)
        baseActive(self, active)
        box:EnableMouse(active)
    end

    function f:Refresh()
        updating = true
        local current = get() or min
        fill:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
        slider:SetValue(current)
        box:SetText(Show(current))
        updating = false
    end
    return f
end

---------------------------------------------------------------------------
-- Desplegable: choices = { { value = ..., text = ... }, ... }
---------------------------------------------------------------------------
local catcher, list
local ITEM_H = 24

function W.CloseMenu()
    if catcher then catcher:Hide() end
end

local function OpenMenu(owner, choices, current, onPick)
    if not catcher then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("FULLSCREEN_DIALOG")
        catcher:SetScript("OnClick", W.CloseMenu)
        list = CreateFrame("Frame", nil, catcher)
        list:SetFrameLevel(catcher:GetFrameLevel() + 5)
        W.Panel(list, T.radius, T.chrome, T.ctrlBorder)
        list.items = {}
    end
    local width = owner:GetWidth()
    for i, choice in ipairs(choices) do
        local item = list.items[i]
        if not item then
            item = CreateFrame("Button", nil, list)
            item:SetHeight(ITEM_H)
            item.bg = item:CreateTexture(nil, "BACKGROUND", nil, 2)
            item.bg:SetAllPoints()
            Color(item.bg, T.field)
            item.bg:Hide()
            item.text = W.Text(item, 12.5)
            item.text:SetPoint("LEFT", 10, 0)
            item.text:SetPoint("RIGHT", -22, 0)
            item.mark = item:CreateTexture(nil, "ARTWORK")
            item.mark:SetSize(11, 11)
            item.mark:SetPoint("RIGHT", -8, 0)
            item.mark:SetTexture(M.ICONS.check)
            item:SetScript("OnEnter", function(self) self.bg:Show() end)
            item:SetScript("OnLeave", function(self) self.bg:Hide() end)
            list.items[i] = item
        end
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", 1, -1 - (i - 1) * ITEM_H)
        item:SetWidth(width - 2)
        item.text:SetText(Tr(choice.text))
        item.text:SetTextColor(unpack(choice.value == current and TEXT or T.textSoft))
        item.mark:SetVertexColor(unpack(ACCENT))
        item.mark:SetShown(choice.value == current)
        item:SetScript("OnClick", function()
            W.CloseMenu()
            onPick(choice.value)
        end)
        item:Show()
    end
    for i = #choices + 1, #list.items do list.items[i]:Hide() end
    list:SetSize(width, #choices * ITEM_H + 2)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
    catcher:Show()
end

function W.Dropdown(parent, width, label, choices, get, set)
    local f = Base(parent, width, 46, label)
    local field = Field(f)
    field:SetPoint("TOPLEFT", 0, -20)
    field:SetPoint("TOPRIGHT", 0, -20)
    field:SetHeight(24)
    f.input = field

    local text = W.Text(field, 13)
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -24, 0)
    local arrow = field:CreateTexture(nil, "ARTWORK")
    arrow:SetSize(10, 10)
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetTexture(M.ICONS.chevron)
    arrow:SetRotation(-math.pi / 2)
    arrow:SetVertexColor(unpack(T.min))

    field:SetScript("OnClick", function(self)
        OpenMenu(self, choices, get(), function(value)
            set(value)
            f:Refresh()
        end)
    end)

    -- Sin elección: texto de ayuda en gris (f.placeholder; con la lista vacía,
    -- f.emptyText). Se pueden cambiar tras crear el desplegable.
    f.placeholder, f.emptyText = "Elige una opción", "No hay opciones"
    function f:Refresh()
        local current = get()
        for _, choice in ipairs(choices) do
            if choice.value == current then
                text:SetText(Tr(choice.text))
                text:SetTextColor(unpack(TEXT))
                return
            end
        end
        if current ~= nil and #choices > 0 then
            text:SetText(tostring(current))
            text:SetTextColor(unpack(TEXT))
        else
            text:SetText(Tr(#choices == 0 and self.emptyText or self.placeholder))
            text:SetTextColor(unpack(T.min))
        end
    end
    return f
end

---------------------------------------------------------------------------
-- Selector de color: get() devuelve { r, g, b }; set(r, g, b)
---------------------------------------------------------------------------
local function OpenColorPicker(color, onChange)
    local r, g, b = color[1], color[2], color[3]
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() onChange(ColorPickerFrame:GetColorRGB()) end,
            cancelFunc = function(previous) onChange(previous.r, previous.g, previous.b) end,
        })
    else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = function() onChange(ColorPickerFrame:GetColorRGB()) end
        ColorPickerFrame.cancelFunc = function(previous) onChange(unpack(previous)) end
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Show()
    end
end

function W.Color(parent, width, label, get, set)
    local f = Base(parent, width, 26)
    local button = CreateFrame("Button", nil, f)
    button:SetAllPoints()
    f.input = button

    -- Muestra rectangular 30×16 a la derecha (como el interruptor).
    local swatch = CreateFrame("Frame", nil, button)
    swatch:SetSize(SWITCH_W, SWITCH_H)
    swatch:SetPoint("RIGHT")
    local panel = W.Panel(swatch, T.radius, { 1, 1, 1, 1 }, T.switchBorder, 0)

    local text = W.Text(button, 13, T.textSoft)
    text:SetPoint("LEFT")
    text:SetPoint("RIGHT", swatch, "LEFT", -10, 0)
    text:SetText(Tr(label))

    button:SetScript("OnClick", function()
        OpenColorPicker(get(), function(r, g, b)
            set(r, g, b)
            f:Refresh()
        end)
    end)
    button:SetScript("OnEnter", function()
        text:SetTextColor(unpack(TEXT))
        panel.border:SetColor(T.btnBorderHot)
    end)
    button:SetScript("OnLeave", function()
        text:SetTextColor(unpack(T.textSoft))
        panel.border:SetColor(T.switchBorder)
    end)

    function f:Refresh()
        local c = get() or { 1, 1, 1 }
        panel.fill:SetColor(c[1], c[2], c[3], 1)
    end
    return f
end

---------------------------------------------------------------------------
-- Botón: 24 px de alto, borde de 1 px, texto 12 px.
-- primary (el antiguo «accent»): botón principal, relleno del acento con
-- texto oscuro; como mucho uno por sección. Desactivado, cualquier botón se
-- ve neutro (fondo #16181C, borde #24272C, texto #7D838C), sin transparencia.
---------------------------------------------------------------------------
function W.Button(parent, width, label, onClick, primary, height)
    local button = Field(parent, T.field, T.btnBorder)
    local text = W.Text(button, 12, TEXT, false, primary and "bold" or "medium")
    text:SetPoint("CENTER")
    text:SetText(Tr(label))
    -- Sin ancho: el del texto más un margen.
    button:SetSize(width or math.ceil(text:GetStringWidth() + 22), height or 24)
    button.text = text
    button.primary = primary and true or false
    button.active = true
    local panel = button.panel

    local function Paint(self, hot)
        if not self.active then
            panel.fill:SetColor(T.surface)
            panel.border:SetColor(T.line)
            text:SetTextColor(unpack(T.min))
        elseif self.primary then
            panel.fill:SetColor(ACCENT)
            panel.border:SetColor(ACCENT)
            text:SetTextColor(unpack(T.onAccent))
            panel.fill:SetAlpha(hot and 0.85 or 1)
        else
            panel.fill:SetColor(T.field)
            panel.border:SetColor(hot and T.btnBorderHot or T.btnBorder)
            text:SetTextColor(unpack(TEXT))
        end
    end
    function button:SetHover(on) Paint(self, on) end
    function button:SetActive(active)
        self.active = active and true or false
        self:EnableMouse(self.active)
        Paint(self, false)
    end
    button:SetScript("OnClick", onClick)
    button.Refresh = function(self) Paint(self, false) end
    Paint(button, false)
    return button
end

---------------------------------------------------------------------------
-- Botón de icono con descripción emergente: sin fondo; borde solo al pasar
-- el ratón. label (opcional): texto al lado del icono.
---------------------------------------------------------------------------
function W.IconButton(parent, icon, tooltip, onClick, label)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(28, 28)
    local panel = W.Panel(button, T.radius, { 0, 0, 0, 0 }, T.btnBorder, 0)
    panel.border:SetShown(false)
    panel.fill:SetShown(false)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(15, 15)
    button.icon:SetTexture(icon)
    button.tint = MUTED
    button.icon:SetVertexColor(unpack(MUTED))
    if label then
        button.label = W.Text(button, 12, MUTED, false, "medium")
        button.label:SetText(Tr(label))
        button.icon:SetPoint("LEFT", 8, 0)
        button.label:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
        button:SetWidth(8 + 15 + 6 + button.label:GetStringWidth() + 10)
    else
        button.icon:SetPoint("CENTER")
    end

    local function Paint(self, hot)
        local c = hot and TEXT or self.tint
        self.icon:SetVertexColor(unpack(c))
        if self.label then self.label:SetTextColor(unpack(c)) end
    end
    function button:SetTint(color)
        self.tint = color or MUTED
        if not self.hovered then Paint(self, false) end
    end
    function button:UpdateTooltip()
        if self.hovered then
            GameTooltip:SetText(Tr(tooltip()))
            GameTooltip:Show()
        end
    end

    button:SetScript("OnEnter", function(self)
        self.hovered = true
        panel.border:SetShown(true)
        Paint(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        self:UpdateTooltip()
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        panel.border:SetShown(false)
        Paint(self, false)
        GameTooltip:Hide()
    end)
    button:SetScript("OnClick", function(self)
        onClick(self)
        self:UpdateTooltip()
    end)
    return button
end

---------------------------------------------------------------------------
-- Pestañas: items = { { value = ..., text = ..., dim = función opcional }, ... }
-- maxWidth (opcional): si no caben en una fila, siguen en la de abajo.
-- dim(): true = pestaña atenuada (p. ej. una barra desactivada).
-- Aspecto: texto con subrayado del acento en la elegida y una línea debajo.
---------------------------------------------------------------------------
local TAB_H, TAB_GAP = 30, 20

function W.Tabs(parent, items, get, set, maxWidth)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(TAB_H)
    f.SetActive = SetActive

    -- Si no caben en una fila, se reparten en filas EQUILIBRADAS (nada de una
    -- pestaña huérfana en la última línea).
    local widths, total = {}, 0
    local probe = W.Text(f, 13, MUTED, false, "medium")
    for i, item in ipairs(items) do
        probe:SetText(Tr(item.text))
        widths[i] = probe:GetStringWidth()
        total = total + widths[i] + (i > 1 and TAB_GAP or 0)
    end
    probe:Hide()
    local limit = maxWidth
    if maxWidth and total > maxWidth then
        local rows = math.ceil(total / maxWidth)
        limit = math.min(maxWidth, total / rows + TAB_GAP)
        -- Si al repartir saldría una fila de más, se usa el ancho completo.
        local sx, srows = 0, 1
        for i = 1, #widths do
            if sx > 0 and sx + widths[i] > limit then sx, srows = 0, srows + 1 end
            sx = sx + widths[i] + TAB_GAP
        end
        if srows > rows then limit = maxWidth end
    end

    local buttons, x, row = {}, 0, 0
    for i, item in ipairs(items) do
        local button = CreateFrame("Button", nil, f)
        button.text = W.Text(button, 13, MUTED, false, "medium")
        button.text:SetPoint("LEFT", 0, 1)
        button.text:SetText(Tr(item.text))
        local width = button.text:GetStringWidth()
        if limit and x > 0 and x + width > limit then
            x, row = 0, row + 1
        end
        button:SetSize(width, TAB_H)
        button:SetPoint("TOPLEFT", x, -row * TAB_H)
        x = x + width + TAB_GAP
        button.bar = button:CreateTexture(nil, "ARTWORK", nil, 2)
        button.bar:SetPoint("BOTTOMLEFT", 0, 0)
        button.bar:SetPoint("BOTTOMRIGHT", 0, 0)
        button.bar:SetHeight(2)
        button.bar:SetTexture(M.TEXTURE)
        button:SetScript("OnClick", function()
            set(item.value)
            f:Refresh()
        end)
        button:SetScript("OnEnter", function(self) if not self.selected then self.text:SetTextColor(unpack(TEXT)) end end)
        button:SetScript("OnLeave", function(self) if not self.selected then self.text:SetTextColor(unpack(MUTED)) end end)
        buttons[i] = button
    end
    -- Línea de 1 px bajo cada fila de pestañas.
    for r = 0, row do
        local line = W.Line(f, T.line, false, "BACKGROUND")
        line:SetPoint("TOPLEFT", 0, -(r + 1) * TAB_H + 1)
        line:SetPoint("RIGHT")
    end
    f:SetHeight((row + 1) * TAB_H)
    f.buttons = buttons

    function f:Refresh()
        local current = get()
        for i, item in ipairs(items) do
            local button = buttons[i]
            local selected = item.value == current
            button.selected = selected
            button.bar:SetShown(selected)
            button.bar:SetVertexColor(unpack(ACCENT))
            button.text:SetTextColor(unpack(selected and TEXT or MUTED))
            button.text:SetAlpha((item.dim and item.dim()) and 0.4 or 1)
        end
    end
    return f
end

-- Control segmentado pequeño: items = { { value, text } }; devuelve el marco
-- con :Refresh(). Botones de 24 px pegados, el elegido con fondo.
function W.Segmented(parent, items, get, set)
    local f = CreateFrame("Frame", nil, parent)
    f:SetHeight(24)
    W.Panel(f, T.radius, T.bg, T.ctrlBorder)
    local x = 1
    f.buttons = {}
    for i, item in ipairs(items) do
        local b = CreateFrame("Button", nil, f)
        b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        b.bg:SetAllPoints()
        Color(b.bg, T.line)
        b.text = W.Text(b, 12, MUTED, false, "medium")
        b.text:SetPoint("CENTER")
        b.text:SetText(Tr(item.text or item[2]))
        local w = b.text:GetStringWidth() + 20
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", x, -1)
        x = x + w
        b.value = item.value or item[1]
        b:SetScript("OnClick", function()
            set(b.value)
            f:Refresh()
        end)
        f.buttons[i] = b
    end
    f:SetWidth(x + 1)
    function f:Refresh()
        local current = get()
        for _, b in ipairs(self.buttons) do
            local sel = b.value == current
            b.bg:SetShown(sel)
            b.text:SetTextColor(unpack(sel and TEXT or MUTED))
        end
    end
    return f
end

---------------------------------------------------------------------------
-- Barra de desplazamiento fina para un ScrollFrame sin plantilla: carril casi
-- invisible y un asa que se ensancha al pasar el ratón. Sin flechas; se oculta
-- si no hay nada que desplazar.
---------------------------------------------------------------------------
local BAR_THIN, BAR_WIDE, BAR_HIT, THUMB_MIN = 4, 7, 14, 28

function W.ScrollBar(scroll, offsetX)
    local bar = CreateFrame("Frame", nil, scroll:GetParent())
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", offsetX or 4, -2)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", offsetX or 4, 2)
    bar:SetWidth(BAR_HIT)   -- la zona del ratón es más ancha que lo que se ve
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP")
    track:SetPoint("BOTTOM")
    track:SetColorTexture(1, 1, 1, 1)

    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(BAR_HIT)
    thumb:EnableMouse(true)
    local grip = thumb:CreateTexture(nil, "ARTWORK")
    grip:SetPoint("TOP")
    grip:SetPoint("BOTTOM")
    Color(grip, ACCENT)
    bar.thumb, bar.grip, bar.track = thumb, grip, track

    local hoverBar, hoverThumb, drag = false, false, nil
    local function Paint()
        local hot = hoverBar or hoverThumb or drag ~= nil
        track:SetWidth(hot and BAR_WIDE or BAR_THIN)
        track:SetAlpha(hot and 0.08 or 0.04)
        grip:SetWidth(hot and BAR_WIDE or BAR_THIN)
        grip:SetAlpha((drag or hoverThumb) and 1 or hot and 0.75 or 0.45)
    end

    local function Range() return scroll:GetVerticalScrollRange() or 0 end
    local function Clamp(v) return math.max(0, math.min(Range(), v)) end

    function bar:Update()
        local range, height = Range(), self:GetHeight() or 0
        if range <= 0.5 or height <= 0 then
            self:Hide()
            return
        end
        self:Show()
        local view = scroll:GetHeight() or height
        local thumbH = math.max(THUMB_MIN, math.min(height, height * view / (view + range)))
        local pos = (scroll:GetVerticalScroll() or 0) / range
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", self, "TOP", 0, -(height - thumbH) * math.max(0, math.min(1, pos)))
    end

    local function CursorY()
        local _, y = GetCursorPosition()
        return y / bar:GetEffectiveScale()
    end

    local function Dragging()
        local free = bar:GetHeight() - thumb:GetHeight()
        if free <= 0 then return end
        scroll:SetVerticalScroll(Clamp(drag.start + (drag.y - CursorY()) * Range() / free))
        bar:Update()
    end
    thumb:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        scroll.scrollTarget = nil
        drag = { y = CursorY(), start = scroll:GetVerticalScroll() or 0 }
        thumb:SetScript("OnUpdate", Dragging)
        Paint()
    end)
    thumb:SetScript("OnMouseUp", function()
        drag = nil
        thumb:SetScript("OnUpdate", nil)
        Paint()
    end)
    thumb:SetScript("OnEnter", function() hoverThumb = true; Paint() end)
    thumb:SetScript("OnLeave", function() hoverThumb = false; Paint() end)
    bar:SetScript("OnEnter", function() hoverBar = true; Paint() end)
    bar:SetScript("OnLeave", function() hoverBar = false; Paint() end)

    -- Clic en el carril: una página hacia donde se pulsó.
    bar:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        local top = thumb:GetTop()
        local dir = (top and CursorY() > top) and -1 or 1
        local view = scroll:GetHeight() or 0
        local from = scroll.scrollTarget or scroll:GetVerticalScroll() or 0
        local target = Clamp(from + dir * view * 0.9)
        if scroll.smoothScroll then
            scroll.scrollTarget = target
        else
            scroll:SetVerticalScroll(target)
        end
        bar:Update()
    end)
    bar:SetScript("OnMouseWheel", function(_, delta)
        local wheel = scroll:GetScript("OnMouseWheel")
        if wheel then wheel(scroll, delta) end
    end)

    scroll:HookScript("OnScrollRangeChanged", function() bar:Update() end)
    scroll:HookScript("OnVerticalScroll", function() bar:Update() end)
    scroll:HookScript("OnSizeChanged", function() bar:Update() end)
    scroll:HookScript("OnShow", function() bar:Update() end)
    Paint()
    bar:Update()
    return bar
end

---------------------------------------------------------------------------
-- Maquetación de las páginas: SECCIONES (título en mayúsculas con una línea
-- de 1 px debajo), sin cajas; controles en dos columnas.
---------------------------------------------------------------------------
function W.Layout(content, width)
    local L = { content = content, y = -4, x = 22, width = width - 44, widgets = {} }
    L.column = math.floor((L.width - 36) / 2)
    -- Ancho de columna dentro de una sección (para crear los controles).
    L.innerColumn = L.column

    -- Abre una sección: lo que se añada hasta EndCard() va dentro.
    -- card.actions es el hueco a la derecha del título para botones.
    function L:Card(title)
        local card = CreateFrame("Frame", nil, content)
        card:SetPoint("TOPLEFT", self.x, self.y)
        card:SetWidth(self.width)
        local fs = W.SectionTitle(card, title)
        fs:SetPoint("TOPLEFT", 0, -14)
        card.title = fs
        local line = W.Line(card, T.sectionLine)
        line:SetPoint("TOPLEFT", 0, -33)
        line:SetPoint("TOPRIGHT", 0, -33)
        card.actions = CreateFrame("Frame", nil, card)
        card.actions:SetPoint("TOPRIGHT", 0, -4)
        card.actions:SetSize(240, 28)

        self.outer = { x = self.x, width = self.width, column = self.column }
        self.card, self.cardTop = card, self.y
        self.x = 0
        self.column = self.innerColumn
        self.y = -44
        return card
    end

    function L:EndCard()
        local card = self.card
        card:SetHeight(-self.y)
        self.y = self.cardTop + self.y - 6
        self.x, self.width, self.column = self.outer.x, self.outer.width, self.outer.column
        self.card = nil
    end

    -- Dentro de una sección los controles se anclan a ella; fuera, al lienzo.
    local function Host()
        return L.card or content
    end

    local function Track(widget, enabledIf)
        widget.enabledIf = enabledIf
        L.widgets[#L.widgets + 1] = widget
        return widget
    end

    function L:Header(text)
        self.y = self.y - 8
        local fs = W.Text(content, 17, TEXT, false, "head")
        fs:SetPoint("TOPLEFT", self.x, self.y)
        fs:SetText(W.Upper(Tr(text)))
        self.y = self.y - 30
        return fs
    end

    function L:Note(text)
        local fs = W.Text(Host(), 12, DIM, true)
        fs:SetPoint("TOPLEFT", Host(), "TOPLEFT", self.x, self.y)
        fs:SetWidth(self.width)
        fs:SetJustifyH("LEFT")
        fs:SetSpacing(2)
        fs:SetText(Tr(text))
        self.y = self.y - fs:GetStringHeight() - 12
        return fs
    end

    -- Uno o dos controles en la misma fila. enabledIf: función opcional que
    -- decide si el control se puede usar (se reevalúa en cada Refresh).
    function L:Row(left, right, leftIf, rightIf)
        if self.card then
            left:SetParent(self.card)
            if right then right:SetParent(self.card) end
        end
        left:SetPoint("TOPLEFT", Host(), "TOPLEFT", self.x, self.y)
        Track(left, leftIf)
        local height = left:GetHeight()
        if right then
            right:SetPoint("TOPLEFT", Host(), "TOPLEFT", self.x + self.column + 36, self.y)
            Track(right, rightIf)
            height = math.max(height, right:GetHeight())
        end
        self.y = self.y - height - 12
    end

    function L:Full(widget, enabledIf)
        if self.card then widget:SetParent(self.card) end
        widget:SetPoint("TOPLEFT", Host(), "TOPLEFT", self.x, self.y)
        if widget.SetWidth and not widget.keepWidth then widget:SetWidth(self.width) end
        Track(widget, enabledIf)
        self.y = self.y - widget:GetHeight() - 12
    end

    -- Solo reevalúa qué controles se pueden usar (p. ej. el color personalizado
    -- se habilita al elegir "Color personalizado"). Llamar tras cada cambio.
    function L:RefreshStates()
        for _, widget in ipairs(self.widgets) do
            if widget.SetActive then
                widget:SetActive(not widget.enabledIf or widget.enabledIf() and true or false)
            end
        end
    end

    function L:Refresh()
        for _, widget in ipairs(self.widgets) do
            if widget.Refresh then widget:Refresh() end
        end
        self:RefreshStates()
    end

    function L:Height()
        return -self.y + 20
    end

    return L
end
