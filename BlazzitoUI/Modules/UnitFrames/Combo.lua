-- Puntos de combo de los marcos de unidad (Jugador y Objetivo).
-- Diseños: segmentos, gemas, rombos, dagas, zarpazos, huellas o un número
-- grande. El diseño depende de la clase del personaje (uno para druida y otro
-- para los demás, o sea pícaros). Se pueden poner encima, debajo o montados en
-- el borde de las barras, con colores en degradado y un color especial al
-- llegar a 5 puntos (el momento del remate).
-- Las texturas (Media/combo_*.tga) se generan con tools/make_combo.py.
local _, ns = ...

local UF = ns.UnitFrames
local M = ns.Media
local Readable = M.Readable

local MAX = 5
local MEDIA = "Interface\\AddOns\\BlazzitoUI\\Media\\"

-- icon: textura con el interior en gris (se tiñe) y el contorno negro.
UF.COMBO_STYLES = {
    gems     = { text = "Gemas (como las originales)", icon = "combo_gem" },
    bars     = { text = "Segmentos" },
    diamonds = { text = "Rombos", icon = "combo_diamond" },
    blades   = { text = "Dagas", icon = "combo_blade" },
    claws    = { text = "Zarpazos", icon = "combo_claw" },
    paws     = { text = "Huellas", icon = "combo_paw" },
    number   = { text = "Número grande" },
}
UF.COMBO_STYLE_ORDER = { "gems", "bars", "diamonds", "blades", "claws", "paws", "number" }

-- Degradado por posición: del amarillo del primer punto al naranja del quinto.
local LOW, HIGH = { 1.00, 0.86, 0.25 }, { 1.00, 0.45, 0.10 }
local EMPTY = { 0.13, 0.13, 0.14 }

-- Diseño que toca según la clase del personaje.
function UF.ComboStyle(cfg)
    local class = Readable(select(2, UnitClass("player")))
    local style = class == "DRUID" and cfg.comboStyleDruid or cfg.comboStyleRogue
    return UF.COMBO_STYLES[style] and style or "gems"
end

-- Clases que tienen puntos de combo. El druida solo los usa en forma de
-- gato (la que gasta energía); el resto (guerrero, cazador…) nunca los ve.
local COMBO_CLASSES = { ROGUE = true, DRUID = true }
local ENERGY = (Enum and Enum.PowerType and Enum.PowerType.Energy) or 3

function UF.ClassHasCombo()
    return COMBO_CLASSES[Readable(select(2, UnitClass("player")))] or false
end

-- ¿Puede usar puntos ahora mismo? (druida: solo en forma de gato)
function UF.CanUseCombo()
    if not UF.ClassHasCombo() then return false end
    if Readable(select(2, UnitClass("player"))) ~= "DRUID" then return true end
    local power = Readable(UnitPowerType("player"))
    return power == nil or power == ENERGY
end

local function ClassColor()
    local class = Readable(select(2, UnitClass("player")))
    local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if color then return color.r, color.g, color.b end
end

local function PipColor(cfg, i)
    if cfg.comboColor == "custom" then
        return unpack(cfg.comboCustomColor)
    elseif cfg.comboColor == "class" then
        local r, g, b = ClassColor()
        if r then return r, g, b end
    end
    local t = (i - 1) / (MAX - 1)
    return LOW[1] + (HIGH[1] - LOW[1]) * t, LOW[2] + (HIGH[2] - LOW[2]) * t, LOW[3] + (HIGH[3] - LOW[3]) * t
end

-- Alto de la fila de puntos.
local function RowHeight(cfg, style)
    if style == "bars" then return cfg.comboBarHeight end
    if style == "number" then return math.floor(cfg.comboSize * 1.3 + 0.5) end
    return cfg.comboSize
end

-- Sitio que ocupan los puntos encima ("above") o debajo ("below") de las
-- barras: lo usan la barra de lanzamiento y las auras para apartarse.
function UF.ComboSpace(frame, side)
    local cfg = UF.Cfg(frame)
    if not (frame.Combo and cfg.combo) then return 0 end
    -- Sin puntos en esta clase no se aparta nada (la vista previa de la
    -- configuración, sin buiUnit, los enseña igual para poder diseñarlos).
    if frame.buiUnit and not UF.ClassHasCombo() then return 0 end
    local height = RowHeight(cfg, UF.ComboStyle(cfg))
    if cfg.comboPosition == "edge" then
        return side == "above" and math.ceil(height / 2) or 0
    end
    if (cfg.comboPosition == "below") == (side == "below") then
        return cfg.comboOffset + height + 1
    end
    return 0
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
-- Vista previa (configuración abierta o modo mover): los puntos suben solos
-- de 1 a 5 para ver el diseño, el color del remate y la animación.
local function DemoTick(self, elapsed)
    self.demoTime = (self.demoTime or 0) + elapsed
    if self.demoTime < 0.8 then return end
    self.demoTime = 0
    self.demo = (self.demo or 0) % MAX + 1
    UF.UpdateCombo(self.owner)
end

function UF.BuildCombo(frame)
    local combo = CreateFrame("Frame", nil, frame)
    combo.owner = frame
    for i = 1, MAX do
        local pip = CreateFrame("Frame", nil, combo)
        pip.glow = pip:CreateTexture(nil, "BACKGROUND", nil, -8)
        pip.glow:SetTexture(MEDIA .. "combo_glow")
        pip.glow:SetBlendMode("ADD")
        pip.glow:Hide()
        pip.border = pip:CreateTexture(nil, "BACKGROUND", nil, -7)   -- solo segmentos
        pip.slot = pip:CreateTexture(nil, "BACKGROUND", nil, -6)     -- hueco vacío
        pip.fill = pip:CreateTexture(nil, "ARTWORK")

        -- Al ganar el punto: aparece un poco más grande y se asienta.
        local pop = pip:CreateAnimationGroup()
        local scale = pop:CreateAnimation("Scale")
        if scale.SetScaleFrom then
            scale:SetScaleFrom(1.6, 1.6)
            scale:SetScaleTo(1, 1)
        else
            scale:SetScale(1, 1)
        end
        scale:SetDuration(0.2)
        scale:SetOrigin("CENTER", 0, 0)
        scale:SetSmoothing("OUT")
        pip.pop = pop
        combo[i] = pip
    end
    combo.Number = M.Font(combo, 20, "CENTER")
    combo.Number:SetPoint("CENTER")
    combo:Hide()
    return combo
end

---------------------------------------------------------------------------
-- Colocación
---------------------------------------------------------------------------
function UF.LayoutCombo(frame)
    local combo = frame.Combo
    if not combo then return end
    local cfg, bars, px = UF.Cfg(frame), frame.Bars, frame.px or 1
    local style = UF.ComboStyle(cfg)
    local info = UF.COMBO_STYLES[style]
    local width, gap = cfg.width, cfg.comboSpacing
    local height = RowHeight(cfg, style)
    combo.style = style

    combo:ClearAllPoints()
    combo:SetSize(width, height)
    if cfg.comboPosition == "below" then
        combo:SetPoint("TOP", bars, "BOTTOM", 0, -cfg.comboOffset)
    elseif cfg.comboPosition == "edge" then
        combo:SetPoint("CENTER", bars, "TOP", 0, 0)
    else
        combo:SetPoint("BOTTOM", bars, "TOP", 0, cfg.comboOffset)
    end
    -- Por encima de los textos de las barras (montados en el borde se tapan).
    combo:SetFrameLevel(bars:GetFrameLevel() + 12)

    local spread = cfg.comboAlign == "spread"
    local pipW, pipH = cfg.comboSize, cfg.comboSize
    if style == "bars" then
        pipH = cfg.comboBarHeight
        pipW = spread and (width - gap * (MAX - 1)) / MAX or math.floor(cfg.comboSize * 1.8 + 0.5)
    end
    local total = pipW * MAX + gap * (MAX - 1)
    local startX = 0
    if cfg.comboAlign == "right" then
        startX = width - total
    elseif cfg.comboAlign ~= "left" then
        startX = (width - total) / 2
    end
    -- "Rellenar de derecha a izquierda" también invierte el orden de los puntos.
    local reverse = cfg.reverseFill
    local glowW, glowH = pipW * 0.55, pipH * 0.55

    for i = 1, MAX do
        local pip = combo[i]
        local slot = reverse and (MAX - i + 1) or i
        local x
        if spread and style ~= "bars" then
            x = width * (slot - 0.5) / MAX - pipW / 2
        else
            x = startX + (slot - 1) * (pipW + gap)
        end
        pip:ClearAllPoints()
        pip:SetSize(pipW, pipH)
        pip:SetPoint("LEFT", combo, "LEFT", x, 0)

        pip.fill:ClearAllPoints()
        pip.slot:ClearAllPoints()
        if info.icon then
            local tex = MEDIA .. info.icon
            pip.border:Hide()
            pip.slot:SetTexture(tex)
            pip.slot:SetAllPoints()
            pip.fill:SetTexture(tex)
            pip.fill:SetAllPoints()
        else
            -- Segmentos: borde negro de 1 píxel, hueco oscuro y relleno.
            pip.border:SetTexture(M.TEXTURE)
            pip.border:SetVertexColor(0, 0, 0, 1)
            pip.border:SetAllPoints()
            pip.border:Show()
            pip.slot:SetTexture(M.TEXTURE)
            pip.slot:SetPoint("TOPLEFT", px, -px)
            pip.slot:SetPoint("BOTTOMRIGHT", -px, px)
            pip.fill:SetTexture(M.TEXTURE)
            pip.fill:SetPoint("TOPLEFT", px, -px)
            pip.fill:SetPoint("BOTTOMRIGHT", -px, px)
        end
        pip.slot:SetVertexColor(EMPTY[1], EMPTY[2], EMPTY[3], 0.9)
        pip.glow:ClearAllPoints()
        pip.glow:SetPoint("TOPLEFT", -glowW, glowH)
        pip.glow:SetPoint("BOTTOMRIGHT", glowW, -glowH)
    end

    combo.Number:SetFont(M.FONT, height, "OUTLINE")
    combo.Number:ClearAllPoints()
    local side = cfg.comboAlign == "left" and "LEFT" or cfg.comboAlign == "right" and "RIGHT" or "CENTER"
    combo.Number:SetPoint(side, combo, side)
    combo.Number:SetJustifyH(side == "CENTER" and "CENTER" or side)

    combo.last = nil
    if not cfg.combo then combo:Hide() end
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------
local function ReadPoints()
    local points = 0
    if GetComboPoints then
        points = GetComboPoints("player", "target")
    elseif Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        points = UnitPower("player", Enum.PowerType.ComboPoints)
    end
    return Readable(points) or 0
end

local function StopDemo(combo)
    if combo.demoOn then
        combo:SetScript("OnUpdate", nil)
        combo.demoOn, combo.demo, combo.demoTime = nil, nil, nil
    end
end

function UF.UpdateCombo(frame)
    local combo = frame.Combo
    if not combo then return end
    local cfg = UF.Cfg(frame)
    -- Clase sin puntos de combo (guerrero, cazador…): nunca se ven, aunque
    -- estén activados. Solo la vista previa de la configuración los enseña.
    if not cfg.combo or (frame.buiUnit and not UF.ClassHasCombo()) then
        StopDemo(combo)
        combo:Hide()
        combo.last = 0
        return
    end

    local points
    if frame.previewUnit then
        if not combo.demoOn then
            combo.demoOn, combo.demo, combo.demoTime = true, 3, 0
            combo:SetScript("OnUpdate", DemoTick)
        end
        points = combo.demo
    else
        StopDemo(combo)
        points = ReadPoints()
    end

    local style = combo.style or UF.ComboStyle(cfg)
    local full = points >= MAX and cfg.comboFull
    local hasTarget = UnitExists("target") and Readable(UnitCanAttack("player", "target"))
    local visible = points > 0
        or (cfg.comboAlways and hasTarget and (frame.previewUnit or UF.CanUseCombo()) and true or false)
    local wasShown = combo:IsShown()
    combo:SetShown(visible)

    local last = wasShown and (combo.last or 0) or 0
    for i = 1, MAX do
        local pip = combo[i]
        local on = i <= points
        local r, g, b
        if full then
            r, g, b = unpack(cfg.comboFullColor)
        else
            r, g, b = PipColor(cfg, i)
        end
        pip.fill:SetVertexColor(r, g, b, 1)
        -- Sin el punto queda un rastro tenue de su color sobre el hueco.
        pip.fill:SetAlpha(on and 1 or 0.15)
        pip.glow:SetVertexColor(r, g, b, 0.9)
        pip.glow:SetShown(full and true or false)
        pip:SetShown(style ~= "number" and (on or cfg.comboEmpty))
        if on and i > last and cfg.comboPop and visible then
            pip.pop:Stop()
            pip.pop:Play()
        end
    end

    local number = combo.Number
    number:SetShown(style == "number")
    if style == "number" then
        number:SetText(points)
        local r, g, b
        if full then
            r, g, b = unpack(cfg.comboFullColor)
        else
            r, g, b = PipColor(cfg, math.max(1, points))
        end
        number:SetTextColor(r, g, b)
    end
    combo.last = points
end
