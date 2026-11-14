-- Partes de un marco de unidad: cómo se dibuja cada una, cómo se coloca según
-- la configuración (ApplyLayout) y cómo se actualiza.
-- Todo lo que viene de la unidad puede ser un valor secreto: se pasa directo
-- a las barras y textos, y solo se compara tras pasar por Readable().
local _, ns = ...

local UF = ns.UnitFrames
local M = ns.Media
local Readable = M.Readable
local COLORS = M.COLORS

local PORTRAIT_GAP = 4

-- Relleno suave: el cliente anima la barra hasta el valor nuevo (también con
-- valores secretos). nil = salto inmediato.
local function Smooth()
    if UF.db.style.smooth and Enum and Enum.StatusBarInterpolation then
        return Enum.StatusBarInterpolation.ExponentialEaseOut
    end
end

---------------------------------------------------------------------------
-- Construcción (una vez por marco)
---------------------------------------------------------------------------
-- Cada barra tiene su propia máscara de forma (todas con el mismo contorno);
-- ApplyLayout les pone la textura y la posición.
local function NewMask(frame, owner)
    local mask = owner:CreateMaskTexture()
    frame.masks[#frame.masks + 1] = mask
    return mask
end

-- Máscara de extremo: viaja con el final del relleno y le da el contorno de la
-- forma (inclinado, en punta, redondeado...). vertical: "TOP" si la barra está
-- arriba en el bloque (vida) o "BOTTOM" si está abajo (recurso), para que el
-- contorno siga la misma línea que el borde del bloque.
local function LeadMask(frame, bar, vertical, extra)
    local mask = bar:CreateMaskTexture()
    frame.leadMasks[#frame.leadMasks + 1] = { mask = mask, bar = bar, vertical = vertical }
    bar:GetStatusBarTexture():AddMaskTexture(mask)
    if extra then extra:AddMaskTexture(mask) end
    return mask
end

-- Barra recortada por la máscara de forma, con un brillo encima del relleno.
local function ShapedBar(frame, parent, vertical)
    local bar = M.StatusBar(parent)
    local mask = NewMask(frame, bar)
    local fill = bar:GetStatusBarTexture()
    fill:AddMaskTexture(mask)
    bar.bg:AddMaskTexture(mask)

    local gloss = bar:CreateTexture(nil, "OVERLAY")
    gloss:SetPoint("TOPLEFT", fill, "TOPLEFT")
    gloss:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    gloss:SetColorTexture(1, 1, 1, 1)
    if CreateColor then
        gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.22))
    else
        gloss:SetAlpha(0.1)
    end
    gloss:AddMaskTexture(mask)
    LeadMask(frame, bar, vertical, gloss)

    bar.mask, bar.gloss = mask, gloss
    return bar
end

-- Barra auxiliar sin fondo (curación, escudo) con la forma y su extremo.
local function OverlayBar(frame, parent, vertical)
    local bar = M.StatusBar(parent)
    bar.bg:Hide()
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:GetStatusBarTexture():AddMaskTexture(NewMask(frame, bar))
    LeadMask(frame, bar, vertical)
    return bar
end

-- Barra de lanzamiento: caja del icono a un lado y la barra con su propia
-- forma (borde, fondo, máscara y extremo), igual que el bloque de vida.
local function BuildCastbar(frame, px)
    local cast = CreateFrame("Frame", nil, frame)

    local iconBox = CreateFrame("Frame", nil, cast)
    M.SetBackdrop(iconBox)
    local icon = iconBox:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", px, -px)
    icon:SetPoint("BOTTOMRIGHT", -px, px)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.iconBox, cast.Icon = iconBox, icon

    local block = CreateFrame("Frame", nil, cast)
    block.border = block:CreateTexture(nil, "BACKGROUND", nil, -8)
    block.border:SetAllPoints()
    block.bg = block:CreateTexture(nil, "BACKGROUND", nil, -7)
    cast.block = block

    local bar = M.StatusBar(block)
    local fill = bar:GetStatusBarTexture()
    bar.mask = bar:CreateMaskTexture()
    fill:AddMaskTexture(bar.mask)
    bar.bg:AddMaskTexture(bar.mask)
    bar.lead = bar:CreateMaskTexture()
    fill:AddMaskTexture(bar.lead)
    cast.Bar = bar

    cast.Text = M.Font(bar, 11, "LEFT")
    cast.Text:SetPoint("LEFT", 4, 0)
    cast.Time = M.Font(bar, 11, "RIGHT")
    cast.Time:SetPoint("RIGHT", -4, 0)
    cast.Text:SetPoint("RIGHT", cast.Time, "LEFT", -4, 0)

    cast:SetScript("OnUpdate", function(self)
        local now = GetTime() * 1000
        if now >= self.endMS then
            if self.fake then
                -- El lanzamiento de prueba vuelve a empezar.
                self.startMS, self.endMS = now, now + (self.endMS - self.startMS)
            else
                self:Hide()
                return
            end
        end
        self.Bar:SetValue(self.channel and (self.endMS - now) or (now - self.startMS))
        self.Time:SetFormattedText("%.1f", (self.endMS - now) / 1000)
    end)
    cast:Hide()
    return cast
end

-- El recuadro (borde y fondo) solo se usa en 2D y clase; el 3D va sin nada.
local function BuildPortrait(frame)
    local portrait = CreateFrame("Frame", nil, frame)
    portrait.border = portrait:CreateTexture(nil, "BACKGROUND", nil, -8)
    portrait.border:SetAllPoints()
    portrait.border:SetColorTexture(0, 0, 0, 1)
    portrait.bg = portrait:CreateTexture(nil, "BACKGROUND", nil, -7)
    portrait.tex = portrait:CreateTexture(nil, "ARTWORK")
    portrait.model = CreateFrame("PlayerModel", nil, portrait)
    portrait.model:SetAllPoints()
    return portrait
end

function UF.Build(frame, info)
    local px = M.PixelSize()
    frame.px = px

    local bars = CreateFrame("Frame", nil, frame)
    frame.Bars = bars
    bars.border = bars:CreateTexture(nil, "BACKGROUND", nil, -8)
    bars.border:SetAllPoints()
    bars.bg = bars:CreateTexture(nil, "BACKGROUND", nil, -7)
    bars.bg:SetPoint("TOPLEFT", px, -px)
    bars.bg:SetPoint("BOTTOMRIGHT", -px, px)

    frame.masks, frame.leadMasks = {}, {}
    local base = bars:GetFrameLevel()

    -- Capas, de abajo arriba: fondo de la vida perdida, curación entrante,
    -- vida, escudo y textos. La curación va debajo de la vida y arranca un poco
    -- antes de su final: así su comienzo sigue exactamente el contorno del
    -- extremo de la vida, sea cual sea la forma.
    frame.HealPred = OverlayBar(frame, bars, "TOP")
    frame.HealPred:SetFrameLevel(base + 1)

    local health = ShapedBar(frame, bars, "TOP")
    health:SetFrameLevel(base + 2)
    local healthBg = bars:CreateTexture(nil, "BACKGROUND", nil, -6)
    healthBg:SetTexture(M.TEXTURE)
    healthBg:SetAllPoints(health)
    healthBg:AddMaskTexture(NewMask(frame, bars))
    health.bg:Hide()
    health.bg = healthBg
    frame.Health = health

    frame.Power = ShapedBar(frame, bars, "BOTTOM")
    frame.Power:SetFrameLevel(base + 2)

    -- Escudo: franja en la parte de arriba de la barra de vida.
    frame.Absorb = OverlayBar(frame, health, "TOP")

    local text = CreateFrame("Frame", nil, bars)
    text:SetAllPoints(health)
    text:SetFrameLevel(base + 8)
    frame.TextLayer = text
    frame.Name = M.Font(text, 12, "LEFT")
    frame.Level = M.Font(text, 11, "LEFT")
    frame.HealthText = M.Font(text, 11, "RIGHT")

    local powerText = CreateFrame("Frame", nil, bars)
    powerText:SetAllPoints(frame.Power)
    powerText:SetFrameLevel(base + 8)
    frame.PowerText = M.Font(powerText, 9, "CENTER")
    frame.PowerText:SetPoint("CENTER")

    local raid = text:CreateTexture(nil, "OVERLAY")
    raid:SetSize(16, 16)
    raid:SetPoint("CENTER", bars, "TOP", 0, 0)
    raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    raid:Hide()
    frame.RaidIcon = raid

    frame.Portrait = BuildPortrait(frame)
    if info.combo then frame.Combo = UF.BuildCombo(frame) end   -- Combo.lua
    frame.Cast = BuildCastbar(frame, px)
end

---------------------------------------------------------------------------
-- Colocación según la configuración (se puede repetir; fuera de combate)
---------------------------------------------------------------------------
function UF.ApplyLayout(frame)
    local cfg, info, style = UF.Cfg(frame), UF.Info(frame), UF.db.style
    local px = frame.px
    local edge = (style.border or 1) * px   -- grosor del borde; 0 = sin borde
    local bg = style.background
    -- "3D dentro de la barra" no ocupa sitio al lado: va dentro de la vida.
    local inBar = cfg.portrait == "3dbar"
    local hasPortrait = cfg.portrait ~= "none" and not inBar
    local portraitSize = math.floor(cfg.height * cfg.portraitSize / 100 + 0.5)
    local portraitSpace = hasPortrait and (portraitSize + PORTRAIT_GAP) or 0

    frame:SetSize(cfg.width + portraitSpace, cfg.height)

    local bars = frame.Bars
    bars:ClearAllPoints()
    bars:SetSize(cfg.width, cfg.height)
    -- El objetivo lleva el retrato a la derecha; "invertir" lo cambia de lado.
    local portraitRight = (info.mirrored and true or false) ~= (cfg.portraitInvert and true or false)
    bars:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitRight and 0 or portraitSpace, 0)

    -- Retrato centrado en vertical: si es más alto que el marco sobresale por arriba y abajo.
    local portrait = frame.Portrait
    portrait:ClearAllPoints()
    portrait:SetSize(portraitSize, portraitSize)
    portrait:SetPoint(portraitRight and "RIGHT" or "LEFT")
    portrait:SetShown(hasPortrait)
    portrait:SetAlpha(1)
    portrait:SetFrameLevel(frame:GetFrameLevel() + 1)
    portrait.guid = nil
    local boxed = cfg.portrait ~= "3d" and not inBar
    portrait.border:SetShown(boxed and edge > 0)
    portrait.bg:SetShown(boxed)
    portrait.bg:ClearAllPoints()
    portrait.bg:SetPoint("TOPLEFT", edge, -edge)
    portrait.bg:SetPoint("BOTTOMRIGHT", -edge, edge)
    portrait.bg:SetColorTexture(bg[1], bg[2], bg[3], 0.92)
    portrait.tex:ClearAllPoints()
    portrait.tex:SetPoint("TOPLEFT", edge, -edge)
    portrait.tex:SetPoint("BOTTOMRIGHT", -edge, edge)

    -- Forma: el borde y el fondo usan la textura; las barras, su máscara.
    -- El objetivo ya va en espejo; "voltear horizontal" invierte eso.
    local flipH = (info.mirrored and true or false) ~= (cfg.flipH and true or false)
    local shape = M.ShapeTexture(cfg.shape, flipH, cfg.flipV)
    bars.border:SetTexture(shape)
    bars.border:SetVertexColor(0, 0, 0, 1)
    bars.border:SetShown(edge > 0)
    bars.bg:SetTexture(shape)
    bars.bg:SetVertexColor(bg[1], bg[2], bg[3], 0.92)
    bars.bg:ClearAllPoints()
    bars.bg:SetPoint("TOPLEFT", edge, -edge)
    bars.bg:SetPoint("BOTTOMRIGHT", -edge, edge)
    for _, mask in ipairs(frame.masks) do
        mask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:ClearAllPoints()
        mask:SetPoint("TOPLEFT", bars, "TOPLEFT", edge, -edge)
        mask:SetPoint("BOTTOMRIGHT", bars, "BOTTOMRIGHT", -edge, edge)
    end
    local reverse = cfg.reverseFill and true or false
    for _, bar in ipairs({ frame.Health, frame.Power }) do
        bar.gloss:SetShown(style.gloss)
        bar:SetReverseFill(reverse)
    end

    -- Máscaras de extremo: del tamaño del bloque, con su lado de avance pegado
    -- al final de cada relleno. Así el final toma el contorno de la forma.
    local innerW, innerH = cfg.width - 2 * edge, cfg.height - 2 * edge
    local side = reverse and "LEFT" or "RIGHT"
    for _, lead in ipairs(frame.leadMasks) do
        local mask = lead.mask
        mask:SetTexture(shape, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:ClearAllPoints()
        mask:SetSize(innerW, innerH)
        mask:SetPoint(lead.vertical .. side, lead.bar:GetStatusBarTexture(), lead.vertical .. side)
    end

    -- Entre vida y recurso queda siempre una línea de 1 píxel.
    local health, power = frame.Health, frame.Power
    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", bars, "TOPLEFT", edge, -edge)
    health:SetPoint("TOPRIGHT", bars, "TOPRIGHT", -edge, -edge)
    if cfg.power > 0 then
        power:ClearAllPoints()
        power:SetPoint("BOTTOMLEFT", bars, "BOTTOMLEFT", edge, edge)
        power:SetPoint("BOTTOMRIGHT", bars, "BOTTOMRIGHT", -edge, edge)
        power:SetHeight(cfg.power)
        power:Show()
        health:SetPoint("BOTTOMLEFT", power, "TOPLEFT", 0, px)
        health:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT", 0, px)
    else
        power:Hide()
        health:SetPoint("BOTTOMLEFT", bars, "BOTTOMLEFT", edge, edge)
        health:SetPoint("BOTTOMRIGHT", bars, "BOTTOMRIGHT", -edge, edge)
    end

    -- La curación arranca "depth" píxeles antes del final de la vida (esa parte
    -- queda debajo de la vida) y mide lo mismo que la barra; UpdatePrediction
    -- le suma ese tramo al valor. Lo que pase del borde lo recorta la máscara.
    local depth = innerW * (M.SHAPES[cfg.shape] or M.SHAPES.rect).depth / 256
    frame.predShift = depth / innerW
    local fill = health:GetStatusBarTexture()
    local pred = frame.HealPred
    pred:ClearAllPoints()
    if reverse then
        pred:SetPoint("TOPRIGHT", fill, "TOPLEFT", depth, 0)
        pred:SetPoint("BOTTOMRIGHT", fill, "BOTTOMLEFT", depth, 0)
    else
        pred:SetPoint("TOPLEFT", fill, "TOPRIGHT", -depth, 0)
        pred:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT", -depth, 0)
    end
    pred:SetWidth(innerW)
    pred:SetReverseFill(reverse)
    pred:SetShown(cfg.healPrediction)

    local healthHeight = cfg.height - 2 * edge - (cfg.power > 0 and (cfg.power + px) or 0)
    local absorb = frame.Absorb
    absorb:ClearAllPoints()
    absorb:SetPoint("TOPLEFT", health, "TOPLEFT")
    absorb:SetPoint("TOPRIGHT", health, "TOPRIGHT")
    absorb:SetHeight(math.max(3, math.floor(healthHeight * 0.3 + 0.5)))
    absorb:SetReverseFill(reverse)
    local ac = cfg.absorbColor
    absorb:SetStatusBarColor(ac[1], ac[2], ac[3], 0.85)
    absorb:SetShown(cfg.absorbs)

    -- Retrato 3D dentro de la barra: encima del relleno, semitransparente y por
    -- debajo de los textos. Un modelo no se puede recortar con la forma, así que
    -- va en el rectángulo interior, apartado de los bordes inclinados.
    if inBar then
        local depth = innerW * (M.SHAPES[cfg.shape] or M.SHAPES.rect).depth / 256
        -- Siempre a lo ancho: estrechar el modelo aleja su cámara. Para
        -- moverlo se desplaza la imagen (portraitShift, en UpdatePortrait).
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", health, "TOPLEFT", depth, 0)
        portrait:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", -depth, 0)
        portrait:SetFrameLevel(health:GetFrameLevel() + 1)
        portrait:SetAlpha(cfg.portraitBarAlpha / 100)
        portrait:Show()
    end
    absorb:SetFrameLevel(health:GetFrameLevel() + 2)

    local showPowerText = cfg.power >= 6 and cfg.powerText ~= "none"
    frame.PowerText:SetFont(M.FONT, math.max(8, math.min(cfg.fontSize - 3, cfg.power + 2)), "")
    frame.PowerText:SetShown(showPowerText)

    -- Textos: se apartan del borde inclinado para no quedar cortados.
    local inset = M.ShapeInset(cfg.shape, cfg.width)
    local layer = frame.TextLayer
    local showHealth = cfg.healthText ~= "none"
    frame.Name:SetFont(M.FONT, cfg.fontSize, "")
    frame.Level:SetFont(M.FONT, cfg.fontSize - 1, "")
    frame.HealthText:SetFont(M.FONT, cfg.fontSize - 1, "")
    local fc = cfg.fontColor
    frame.Name:SetTextColor(fc[1], fc[2], fc[3])
    frame.HealthText:SetTextColor(fc[1], fc[2], fc[3])
    frame.PowerText:SetTextColor(fc[1], fc[2], fc[3])
    frame.Name:SetShown(cfg.showName)
    frame.Level:SetShown(cfg.showLevel)
    frame.HealthText:SetShown(showHealth)

    frame.Level:ClearAllPoints()
    frame.Level:SetPoint("LEFT", layer, "LEFT", inset, 0)
    frame.HealthText:ClearAllPoints()
    frame.HealthText:SetPoint("RIGHT", layer, "RIGHT", -inset, 0)
    frame.Name:ClearAllPoints()
    if cfg.showLevel then
        frame.Name:SetPoint("LEFT", frame.Level, "RIGHT", 4, 0)
    else
        frame.Name:SetPoint("LEFT", layer, "LEFT", inset, 0)
    end
    if showHealth then
        frame.Name:SetPoint("RIGHT", frame.HealthText, "LEFT", -6, 0)
    else
        frame.Name:SetPoint("RIGHT", layer, "RIGHT", -inset, 0)
    end
    frame.Name:SetJustifyH((showHealth or cfg.showLevel) and "LEFT" or "CENTER")

    if frame.Combo then UF.LayoutCombo(frame) end
    -- Barra de lanzamiento: debajo de las barras (y de los puntos de combo si
    -- van abajo), con su forma (o la del marco). Sigue la orientación del
    -- marco; sus casillas de invertir la cambian solo a ella. El icono va del
    -- lado exterior.
    local cast, castH = frame.Cast, cfg.castHeight
    local castTotal = (cfg.castWidth or 0) > 0 and cfg.castWidth or cfg.width
    cast:ClearAllPoints()
    cast:SetPoint("TOP", bars, "BOTTOM", 0, -4 - UF.ComboSpace(frame, "below"))
    cast:SetSize(castTotal, castH)
    local castShape = cfg.castShape == "inherit" and cfg.shape or cfg.castShape
    local castFlipH = flipH ~= (cfg.castFlipH and true or false)
    local castFlipV = (cfg.flipV and true or false) ~= (cfg.castFlipV and true or false)
    local castTex = M.ShapeTexture(castShape, castFlipH, castFlipV)
    local iconSpace = cfg.castIcon and (castH + 3) or 0
    cast.iconBox:SetShown(cfg.castIcon)
    cast.iconBox:ClearAllPoints()
    cast.iconBox:SetSize(castH, castH)
    cast.iconBox:SetPoint(info.mirrored and "RIGHT" or "LEFT")
    local block = cast.block
    block:ClearAllPoints()
    block:SetPoint("TOPLEFT", info.mirrored and 0 or iconSpace, 0)
    block:SetPoint("BOTTOMRIGHT", info.mirrored and -iconSpace or 0, 0)
    block.border:SetTexture(castTex)
    block.border:SetVertexColor(0, 0, 0, 1)
    block.border:SetShown(edge > 0)
    block.bg:SetTexture(castTex)
    block.bg:SetVertexColor(bg[1], bg[2], bg[3], 0.92)
    block.bg:ClearAllPoints()
    block.bg:SetPoint("TOPLEFT", edge, -edge)
    block.bg:SetPoint("BOTTOMRIGHT", -edge, edge)
    local castBar = cast.Bar
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", block, "TOPLEFT", edge, -edge)
    castBar:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -edge, edge)
    castBar.mask:SetTexture(castTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    castBar.mask:ClearAllPoints()
    castBar.mask:SetAllPoints(castBar)
    local castW = castTotal - iconSpace - 2 * edge
    castBar.lead:SetTexture(castTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    castBar.lead:ClearAllPoints()
    castBar.lead:SetSize(castW, castH - 2 * edge)
    castBar.lead:SetPoint("RIGHT", castBar:GetStatusBarTexture(), "RIGHT")
    local castInset = M.ShapeInset(castShape, castW)
    cast.Text:ClearAllPoints()
    cast.Text:SetPoint("LEFT", castInset, 0)
    cast.Time:ClearAllPoints()
    cast.Time:SetPoint("RIGHT", -castInset, 0)
    cast.Text:SetPoint("RIGHT", cast.Time, "LEFT", -4, 0)
    if not cfg.castbar then cast:Hide() end
    UF.RunHooks("layout", frame, cfg)
end

---------------------------------------------------------------------------
-- Colores
---------------------------------------------------------------------------
local function ClassOrReaction(unit)
    if Readable(UnitIsPlayer(unit)) then
        local class = Readable(select(2, UnitClass(unit)))
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    if UnitIsTapDenied and Readable(UnitIsTapDenied(unit)) then
        return unpack(COLORS.tapped)
    end
    local reaction = Readable(UnitReaction(unit, "player"))
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if color then return color.r, color.g, color.b end
    return unpack(COLORS.fallback)
end

local function LevelColor(level)
    local color = (GetCreatureDifficultyColor and GetCreatureDifficultyColor(level))
        or (GetQuestDifficultyColor and GetQuestDifficultyColor(level))
    if color then return color.r, color.g, color.b end
    return 1, 0.82, 0
end

local CLASSIFICATION = { elite = "+", rareelite = " R+", rare = " R", worldboss = "" }

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------
-- La curación entrante usa el mismo color que la vida, translúcido.
local function PaintHealth(frame, r, g, b)
    M.ColorBar(frame.Health, r, g, b)
    frame.HealPred:SetStatusBarColor(r, g, b, 0.45)
end

function UF.UpdateColor(frame)
    local unit, cfg = UF.UnitOf(frame), UF.Cfg(frame)
    if Readable(UnitIsDeadOrGhost(unit)) or Readable(UnitIsConnected(unit)) == false then
        PaintHealth(frame, unpack(COLORS.dead))
    elseif cfg.healthColor == "custom" then
        PaintHealth(frame, unpack(cfg.customColor))
    elseif cfg.healthColor == "gradient" then
        local ok, r, g, b = M.HealthGradient(unit)
        if ok then
            PaintHealth(frame, r, g, b)
        else
            PaintHealth(frame, ClassOrReaction(unit))
        end
    else
        PaintHealth(frame, ClassOrReaction(unit))
    end
end

function UF.UpdatePrediction(frame)
    local unit, cfg = UF.UnitOf(frame), UF.Cfg(frame)
    if not UnitExists(unit) then return end
    local max = UnitHealthMax(unit)
    if cfg.healPrediction and UnitGetIncomingHeals then
        local heal = UnitGetIncomingHeals(unit)
        frame.HealPred:SetMinMaxValues(0, max)
        if M.IsSecret(heal) or M.IsSecret(max) then
            -- Con valores secretos no se puede sumar el tramo oculto: la
            -- curación se ve unos píxeles más corta, pero en su sitio.
            frame.HealPred:SetValue(M.OrZero(heal))
        else
            frame.HealPred:SetValue((heal or 0) + (max or 0) * (frame.predShift or 0))
        end
    end
    if cfg.absorbs and UnitGetTotalAbsorbs then
        frame.Absorb:SetMinMaxValues(0, max)
        frame.Absorb:SetValue(M.OrZero(UnitGetTotalAbsorbs(unit)), Smooth())
    end
end

local function UpdateHealthText(frame, unit, dead, offline)
    local text = frame.HealthText
    if offline then
        text:SetText(ns.Translate("Desconectado"))
    elseif dead then
        text:SetText(ns.Translate(Readable(UnitIsGhost(unit)) and "Fantasma" or "Muerto"))
    else
        local mode = UF.Cfg(frame).healthText
        local percent, hasPercent = M.HealthPercent(unit)
        if mode == "none" then
            text:SetText("")
        elseif mode == "value" or not hasPercent then
            text:SetText(M.ShortValue(UnitHealth(unit)))
        elseif mode == "both" then
            text:SetFormattedText("%s  |cffbbbbbb%d%%|r", M.ShortValue(UnitHealth(unit)), percent)
        else
            text:SetFormattedText("%d%%", percent)
        end
    end
end

function UF.UpdateHealth(frame)
    local unit = UF.UnitOf(frame)
    if not UnitExists(unit) then return end
    local bar = frame.Health
    local dead = Readable(UnitIsDeadOrGhost(unit))
    local offline = Readable(UnitIsConnected(unit)) == false
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    if dead then
        bar:SetValue(0)
    elseif offline then
        bar:SetValue(UnitHealthMax(unit))
    else
        bar:SetValue(UnitHealth(unit), Smooth())
    end
    UpdateHealthText(frame, unit, dead, offline)
    UF.UpdatePrediction(frame)
    if UF.Cfg(frame).healthColor == "gradient" then UF.UpdateColor(frame) end
end

function UF.UpdatePower(frame)
    local cfg = UF.Cfg(frame)
    if cfg.power <= 0 then return end
    local bar = frame.Power
    local unit = UF.UnitOf(frame)
    if not UnitExists(unit) then return end
    local powerType, token = UnitPowerType(unit)
    if cfg.powerColor == "custom" then
        M.ColorBar(bar, unpack(cfg.powerCustomColor))
    elseif cfg.powerColor == "class" then
        M.ColorBar(bar, ClassOrReaction(unit))
    else
        local own = M.POWER_COLORS[Readable(token) or ""]
        local color = PowerBarColor and (PowerBarColor[Readable(token) or ""] or PowerBarColor[Readable(powerType) or -1])
        if own then
            M.ColorBar(bar, own[1], own[2], own[3])
        elseif color then
            M.ColorBar(bar, color.r, color.g, color.b)
        else
            M.ColorBar(bar, unpack(COLORS.power))
        end
    end
    bar:SetMinMaxValues(0, UnitPowerMax(unit))
    bar:SetValue(UnitPower(unit), Smooth())

    local mode, text = cfg.powerText, frame.PowerText
    if mode == "none" or cfg.power < 6 then return end
    local percent, hasPercent = M.PowerPercent(unit, powerType)
    if mode == "value" or not hasPercent then
        text:SetText(M.ShortValue(UnitPower(unit)))
    elseif mode == "both" then
        text:SetFormattedText("%s  |cffdddddd%d%%|r", M.ShortValue(UnitPower(unit)), percent)
    else
        text:SetFormattedText("%d%%", percent)
    end
end

function UF.UpdateName(frame)
    local unit = UF.UnitOf(frame)
    if not UnitExists(unit) then return end
    local name = UnitName(unit)
    frame.Name:SetText(name)

    local level = Readable(UnitLevel(unit))
    local classification = Readable(UnitClassification(unit))
    local suffix = classification and CLASSIFICATION[classification] or ""
    if not level then
        frame.Level:SetText("")
    elseif level <= 0 or classification == "worldboss" then
        frame.Level:SetText("??" .. suffix)
        frame.Level:SetTextColor(1, 0.25, 0.25)
    else
        frame.Level:SetText(level .. suffix)
        frame.Level:SetTextColor(LevelColor(level))
    end
end

-- force: recargar aunque sea la misma unidad (evento de modelo, cambio de ajuste).
-- tick: llamado por el repintado periódico; sin GUID legible no se recarga para no parpadear.
function UF.UpdatePortrait(frame, force, tick)
    local cfg = UF.Cfg(frame)
    local mode = cfg.portrait
    if mode == "none" then return end
    local unit = UF.UnitOf(frame)
    local portrait = frame.Portrait
    local guid = Readable(UnitGUID(unit))
    if not force then
        if guid and guid == portrait.guid then return end
        if tick and not guid then return end
    end
    portrait.guid = guid

    local tex, model = portrait.tex, portrait.model
    if mode == "3d" or mode == "3dbar" then
        tex:Hide()
        model:Show()
        model:ClearModel()
        if Readable(UnitIsVisible(unit)) == false then
            model:SetModel("Interface\\Buttons\\TalkToMeQuestionMark.m2")
            model:SetPortraitZoom(0)
            model:SetCamDistanceScale(0.25)
            model:SetPosition(0, 0, 0)
            if model.SetViewTranslation then pcall(model.SetViewTranslation, model, 0, 0) end
        else
            -- Encuadre de retrato (hombros y cabeza); el zoom acerca o aleja la
            -- cámara y el desplazamiento sube o baja el modelo.
            model:SetUnit(unit)
            model:SetPortraitZoom(1)
            model:SetCamDistanceScale(100 / cfg.portraitZoom)
            model:SetPosition(0, 0, -cfg.portraitOffset / 100)
            model:SetFacing(math.rad(cfg.portraitFacing or 0))
            -- Desplazamiento en píxeles: % de medio ancho del modelo.
            if model.SetViewTranslation then
                local half = (Readable(model:GetWidth()) or 0) / 2
                pcall(model.SetViewTranslation, model, math.floor(half * (cfg.portraitShift or 0) / 100 + 0.5), 0)
            end
        end
        return
    end

    model:Hide()
    tex:Show()
    local class = Readable(UnitIsPlayer(unit)) and Readable(select(2, UnitClass(unit)))
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if mode == "class" and coords then
        tex:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        tex:SetTexCoord(unpack(coords))
    else
        -- 2D, y también el modo clase con criaturas (no tienen clase).
        tex:SetTexCoord(0.15, 0.85, 0.15, 0.85)
        SetPortraitTexture(tex, unit)
    end
end

function UF.UpdateRaidIcon(frame)
    local index = Readable(GetRaidTargetIndex(UF.UnitOf(frame)))
    if index and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(frame.RaidIcon, index)
        frame.RaidIcon:Show()
    else
        frame.RaidIcon:Hide()
    end
end

-- kind: "start" (lanzamiento), "channel" (canalización) o "stop".
-- Si el cliente da tiempos secretos la barra se oculta en vez de fallar.
-- Vista previa (configuración abierta o modo mover): un lanzamiento de prueba
-- en bucle para ver la barra mientras se ajusta.
local FAKE_SECONDS = 3
local FAKE_ICON = "Interface\\Icons\\Spell_Nature_Lightning"

local function ShowFakeCast(frame, cfg)
    local cast = frame.Cast
    if cast.fake and cast:IsShown() then return end
    local now = GetTime() * 1000
    cast.fake, cast.channel = true, false
    cast.startMS, cast.endMS = now, now + FAKE_SECONDS * 1000
    cast.Bar:SetMinMaxValues(0, FAKE_SECONDS * 1000)
    cast.Bar:SetValue(0)
    cast.Icon:SetTexture(FAKE_ICON)
    cast.Text:SetText(ns.Translate("Lanzamiento de prueba"))
    M.ColorBar(cast.Bar, cfg.castColor[1], cfg.castColor[2], cfg.castColor[3])
    cast:Show()
end

function UF.UpdateCast(frame, kind)
    local cast = frame.Cast
    if not cast then return end
    local cfg = UF.Cfg(frame)
    if frame.previewUnit then
        if cfg.castbar then
            ShowFakeCast(frame, cfg)
            -- El color puede cambiar mientras está abierta la configuración.
            M.ColorBar(cast.Bar, cfg.castColor[1], cfg.castColor[2], cfg.castColor[3])
        else
            cast.fake = nil
            cast:Hide()
        end
        return
    end
    cast.fake = nil
    if kind == "stop" or not cfg.castbar then
        cast:Hide()
        return
    end
    local unit = UF.UnitOf(frame)
    local name, _, texture, startMS, endMS, notInterruptible, _
    if kind == "channel" then
        name, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
    else
        name, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(unit)
    end
    name, startMS, endMS = Readable(name), Readable(startMS), Readable(endMS)
    if not (name and startMS and endMS) or endMS <= startMS then
        cast:Hide()
        return
    end
    cast.channel = kind == "channel"
    cast.startMS, cast.endMS = startMS, endMS
    cast.Bar:SetMinMaxValues(0, endMS - startMS)
    cast.Icon:SetTexture(texture)
    cast.Text:SetText(name)
    local color = Readable(notInterruptible) and COLORS.castLocked or cfg.castColor
    M.ColorBar(cast.Bar, color[1], color[2], color[3])
    cast:Show()
end

function UF.UpdateAll(frame, tick)
    local unit = UF.UnitOf(frame)
    if not UnitExists(unit) then return end
    UF.UpdateColor(frame)
    UF.UpdateHealth(frame)
    UF.UpdatePower(frame)
    UF.UpdateName(frame)
    UF.UpdatePortrait(frame, false, tick)
    UF.UpdateRaidIcon(frame)
    if frame.Combo then UF.UpdateCombo(frame) end
    -- Al cambiar de unidad se recoge el lanzamiento que ya estaba en curso.
    -- (El objetivo del objetivo no tiene eventos: así se entera en cada repintado.)
    if Readable(UnitCastingInfo(unit)) then
        UF.UpdateCast(frame, "start")
    elseif Readable(UnitChannelInfo(unit)) then
        UF.UpdateCast(frame, "channel")
    else
        UF.UpdateCast(frame, "stop")
    end
    UF.RunHooks("update", frame, tick)
end
