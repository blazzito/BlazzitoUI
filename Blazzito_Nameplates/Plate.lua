-- Una placa: construcción, colocación y pintado.
--
-- Distribución fija (nada cambia de sitio según el estado):
--
--              [tus debuffs]
--     [!]          Nombre          [huella]
--   [x] [12+ ====vida===== 72%] 85%
--       [ic][== lanzamiento ==]
--
-- [!] misión · [huella] lo ataca tu mascota · [x] marca de banda · 85% aggro
-- · nivel dentro de la barra. Fuera de alcance, la placa entera baja de
-- opacidad. Los aliados (p.kind == "friend") llevan solo el nombre.
local ns = BlazzitoUI
if not (ns and ns.Nameplates and ns.Nameplates.Shape) then return end

local NP, M = ns.Nameplates, ns.Media
local Shape = NP.Shape
local Readable, IsSecret = M.Readable, M.IsSecret
local COLORS = M.COLORS
local Font = NP.Font
local MEDIA = NP.MEDIA
local WARN = { 1.00, 0.25, 0.25 }
local QUEST = { 1.00, 0.82, 0.10 }
local RARE = { 0.80, 0.85, 0.95 }
local PAW = { 0.95, 0.72, 0.45 }

local function Accent()
    local W = ns.Widgets
    return (W and W.COLORS and W.COLORS.accent) or COLORS.accent
end

local function Smooth()
    return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
end

---------------------------------------------------------------------------
-- Construcción
---------------------------------------------------------------------------
local function CastOnUpdate(self)
    local now = GetTime()
    if self.holdUntil then
        if now >= self.holdUntil then
            self.holdUntil = nil
            self:Hide()
        end
        return
    end
    local ms = now * 1000
    if ms >= self.endMS then
        if not self.fake then
            self:Hide()
            return
        end
        self.startMS, self.endMS = ms, ms + (self.endMS - self.startMS)
    end
    self.bar:SetValue(self.channel and (self.endMS - ms) or (ms - self.startMS))
    if self.time:IsShown() then self.time:SetFormattedText("%.1f", (self.endMS - ms) / 1000) end
end

local function BuildCast(p)
    local cast = CreateFrame("Frame", nil, p)
    cast.iconBox = CreateFrame("Frame", nil, cast)
    cast.iconBorder = cast.iconBox:CreateTexture(nil, "BACKGROUND")
    cast.iconBorder:SetAllPoints()
    cast.iconBorder:SetColorTexture(0, 0, 0, 1)
    cast.icon = cast.iconBox:CreateTexture(nil, "ARTWORK")
    cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Escudo: el lanzamiento no se puede interrumpir.
    cast.shield = cast.iconBox:CreateTexture(nil, "OVERLAY")
    cast.shield:SetTexture(MEDIA .. "shield")
    cast.shield:SetVertexColor(0.85, 0.85, 0.88, 1)
    cast.shield:Hide()
    cast.block = Shape.NewBlock(cast)
    cast.bar = cast.block.bar
    local texts = CreateFrame("Frame", nil, cast.block)
    texts:SetAllPoints(cast.block)
    texts:SetFrameLevel(cast.bar:GetFrameLevel() + 4)
    cast.text = Font(texts, 8, "LEFT")
    cast.time = Font(texts, 8, "RIGHT")
    cast.target = Font(texts, 8, "RIGHT")
    cast:SetScript("OnUpdate", CastOnUpdate)
    cast:Hide()
    return cast
end

-- preview: la placa vive en la ventana de opciones (usa la escala de esta).
function NP.Build(parent, preview)
    local p = CreateFrame("Frame", nil, parent)
    p.preview = preview and true or false
    if not preview and p.SetIgnoreParentScale then p:SetIgnoreParentScale(true) end
    p.base = parent

    p.block = Shape.NewBlock(p)
    p.block:SetPoint("CENTER")
    p.health = p.block.bar

    local texts = CreateFrame("Frame", nil, p.block)
    texts:SetAllPoints(p.block)
    texts:SetFrameLevel(p.health:GetFrameLevel() + 4)
    p.level = Font(texts, 9, "LEFT")
    p.rare = texts:CreateTexture(nil, "OVERLAY")
    p.rare:SetTexture(MEDIA .. "rare")
    p.rare:SetVertexColor(RARE[1], RARE[2], RARE[3], 1)
    p.rare:Hide()
    p.hp = Font(texts, 9, "RIGHT")

    p.name = Font(p, 10, "CENTER")
    p.quest = p:CreateTexture(nil, "OVERLAY")
    p.quest:SetTexture(MEDIA .. "quest")
    p.quest:SetVertexColor(QUEST[1], QUEST[2], QUEST[3], 1)
    p.quest:Hide()
    p.pet = p:CreateTexture(nil, "OVERLAY")
    p.pet:SetTexture(MEDIA .. "paw")
    p.pet:SetVertexColor(PAW[1], PAW[2], PAW[3], 1)
    p.pet:Hide()
    p.raid = p:CreateTexture(nil, "OVERLAY")
    p.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    p.raid:Hide()
    NP.BuildThreatBadge(p)

    p.cast = BuildCast(p)
    p.debuffs = NP.BuildDebuffs(p)
    NP.Apply(p)
    return p
end

---------------------------------------------------------------------------
-- Colocación según los ajustes
---------------------------------------------------------------------------
function NP.Apply(p)
    local db = NP.db
    if not p.preview then
        p:SetScale((UIParent:GetEffectiveScale() or 1) * db.scale)
        p:ClearAllPoints()
        p:SetPoint("CENTER", p.base, "CENTER", 0, db.offsetY)
    else
        -- Vista previa: ampliada para que se distinga todo (hasta 1,8 veces),
        -- sin salirse de su mitad de la zona fija (marca de banda a la
        -- izquierda e insignia de aggro a la derecha incluidas).
        local space = (NP.previewSpace or 300) - 30
        local scale = math.max(0.6, math.min(1.8, space / (db.width + 80)))
        p:SetScale(scale)
        -- Su sitio (previewX/Y, en la escala de la ventana): los desplazamientos
        -- de un marco escalado van en su escala, así que se recoloca aquí.
        if p.previewX then
            p:ClearAllPoints()
            p:SetPoint("CENTER", p:GetParent(), "CENTER", p.previewX / scale, p.previewY / scale)
        end
    end
    p:SetSize(db.width, db.height)
    local px = NP.Pixel(p)
    -- Con el borde teñido por el aggro, el borde gana un píxel (se ve mejor).
    local layout = {
        width = db.width, height = db.height, edge = (db.border + (p.tinted and 1 or 0)) * px, outline = 2 * px,
        shape = db.shape, flipH = db.flipH, flipV = db.flipV, gloss = db.gloss,
    }
    p.layout = layout
    Shape.Layout(p.block, layout)
    local a = Accent()
    p.block.outline:SetVertexColor(a[1], a[2], a[3], 1)

    local fc, size = db.fontColor, db.fontSize
    local small = math.max(7, size - 1)
    local block = p.block
    local textsFit = db.height >= 8

    p.level:SetFont(M.FONT, small, "OUTLINE")
    p.level:ClearAllPoints()
    p.level:SetPoint("LEFT", block, "LEFT", block.insetL + 2, 0)
    p.level:SetShown(db.showLevel and textsFit)
    p.rare:SetSize(small - 1, small - 1)
    p.rare:ClearAllPoints()
    p.rare:SetPoint("LEFT", p.level, "RIGHT", 1, 0)

    p.hp:SetFont(M.FONT, small, "OUTLINE")
    p.hp:SetTextColor(fc[1], fc[2], fc[3])
    p.hp:ClearAllPoints()
    p.hp:SetPoint("RIGHT", block, "RIGHT", -(block.insetR + 2), 0)
    p.hp:SetShown(db.healthText ~= "none" and textsFit)

    -- Fila del nombre: misión a la izquierda, huella a la derecha; los dos
    -- huecos miden lo mismo para que el nombre siga centrado.
    local questSize = size + 2
    local side = (db.quest or db.petTarget) and (questSize + 2) or 0
    p.name:SetFont(M.FONT, size, "OUTLINE")
    p.name:SetTextColor(fc[1], fc[2], fc[3])
    p.name:ClearAllPoints()
    p.name:SetPoint("BOTTOMLEFT", block, "TOPLEFT", side, 3)
    p.name:SetPoint("BOTTOMRIGHT", block, "TOPRIGHT", -side, 3)
    p.name:SetShown(db.showName)
    p.quest:SetSize(questSize, questSize)
    p.quest:ClearAllPoints()
    p.quest:SetPoint("BOTTOMLEFT", block, "TOPLEFT", 0, 2)
    p.pet:SetSize(questSize, questSize)
    p.pet:ClearAllPoints()
    p.pet:SetPoint("BOTTOMRIGHT", block, "TOPRIGHT", 0, 2)

    local raid = math.min(24, db.height + 8)
    p.raid:SetSize(raid, raid)
    p.raid:ClearAllPoints()
    p.raid:SetPoint("RIGHT", block, "LEFT", -4, 0)

    NP.LayoutThreatBadge(p, math.max(8, small), px)

    -- Lanzamiento: icono cuadrado + barra con la misma forma.
    local cast, h = p.cast, db.castHeight
    cast:ClearAllPoints()
    cast:SetPoint("TOP", block, "BOTTOM", 0, -3)
    cast:SetSize(db.width, h)
    cast.iconBox:ClearAllPoints()
    cast.iconBox:SetSize(h, h)
    cast.iconBox:SetPoint("LEFT")
    cast.icon:ClearAllPoints()
    cast.icon:SetPoint("TOPLEFT", px, -px)
    cast.icon:SetPoint("BOTTOMRIGHT", -px, px)
    cast.shield:ClearAllPoints()
    cast.shield:SetPoint("CENTER")
    cast.shield:SetSize(h * 0.8, h * 0.8)
    cast.block:ClearAllPoints()
    cast.block:SetPoint("LEFT", cast.iconBox, "RIGHT", 2, 0)
    local castLayout = {}
    for k, v in pairs(layout) do castLayout[k] = v end
    castLayout.width, castLayout.height, castLayout.gloss = db.width - h - 2, h, false
    castLayout.edge = db.border * px
    Shape.Layout(cast.block, castLayout)
    local castFont = math.max(7, h - 2)
    for _, fs in ipairs({ cast.text, cast.time, cast.target }) do
        fs:SetFont(M.FONT, castFont, "OUTLINE")
        fs:SetTextColor(fc[1], fc[2], fc[3])
    end
    cast.time:ClearAllPoints()
    cast.time:SetPoint("RIGHT", cast.block, "RIGHT", -(cast.block.insetR + 2), 0)
    cast.target:ClearAllPoints()
    cast.target:SetPoint("RIGHT", cast.block, "RIGHT", -(cast.block.insetR + 2), 0)
    cast.target:SetWidth(math.floor(castLayout.width * 0.42))
    NP.PlaceCastText(p)

    NP.LayoutDebuffs(p)
    NP.ApplyKind(p)
end

-- Aliado: solo el nombre, centrado donde iría la barra (con la marca de
-- banda a su izquierda). Enemigo: todo.
function NP.ApplyKind(p)
    local friend = p.kind == "friend"
    p.block:SetShown(not friend)
    if not friend then return end
    local db = NP.db
    p.name:ClearAllPoints()
    p.name:SetPoint("CENTER", p.block, "CENTER", 0, 0)
    p.name:SetWidth(db.width + 40)
    p.name:SetFont(M.FONT, db.fontSize + 1, "OUTLINE")
    p.name:Show()
    p.raid:ClearAllPoints()
    p.raid:SetPoint("RIGHT", p.name, "CENTER", -(db.width / 2) - 4, 0)
    p.cast:Hide()
    p.debuffs:Hide()
    p.threatBox:Hide()
    p.quest:Hide()
    p.pet:Hide()
end

-- El nombre del hechizo ocupa lo que deja libre el hueco de la derecha
-- (el tiempo, o a quién va dirigido).
function NP.PlaceCastText(p)
    local cast = p.cast
    local slot = cast.target:IsShown() and cast.target:GetWidth() or 24
    cast.text:ClearAllPoints()
    cast.text:SetPoint("LEFT", cast.block, "LEFT", cast.block.insetL + 2, 0)
    cast.text:SetPoint("RIGHT", cast.block, "RIGHT", -(cast.block.insetR + 2 + slot + 3), 0)
end

---------------------------------------------------------------------------
-- Pintado
---------------------------------------------------------------------------
function NP.UpdateHealth(p)
    local unit, bar = p.unit, p.health
    local current = UnitHealth(unit)
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(current, Smooth())
    if not p.hp:IsShown() then return end
    local mode = NP.db.healthText
    local percent, ok = M.HealthPercent(unit)
    if mode == "value" then
        p.hp:SetText(M.ShortValue(current))
    elseif not ok then
        p.hp:SetText("")
    elseif mode == "both" then
        p.hp:SetFormattedText("%s · %d%%", M.ShortValue(current), percent)
    else
        p.hp:SetFormattedText("%d%%", percent)
    end
end

function NP.UpdateColor(p)
    if p.kind == "friend" then
        p.name:SetTextColor(NP.FriendColor(p.unit))
        return
    end
    local r, g, b = NP.HealthColor(p.unit)
    M.ColorBar(p.health, NP.ExecuteColor(p.unit, r, g, b))
end

-- Borde: del color del aggro en combate (si tienes aggro con él), si no negro.
function NP.UpdateBorder(p)
    local db = NP.db
    local status = p.threatStatus
    local r, g, b
    if db.threat and db.threatBorder and NP.inCombat and status and status > 0 then
        r, g, b = NP.ThreatColor(status)
    end
    NP.TintBorder(p, r, g, b)
end

-- Borde del color del aggro (r = nil: negro). Teñido mide un píxel más,
-- para que se note (1 px naranja junto a una barra roja casi no se ve).
function NP.TintBorder(p, r, g, b)
    local tinted = r ~= nil
    if tinted ~= (p.tinted or false) and p.layout then
        p.tinted = tinted
        p.layout.edge = (NP.db.border + (tinted and 1 or 0)) * NP.Pixel(p)
        Shape.Layout(p.block, p.layout)
    end
    local border = p.block.border
    if tinted then
        border:SetVertexColor(r, g, b, 1)
        border:Show()
    else
        border:SetVertexColor(0, 0, 0, 1)
        border:SetShown(NP.db.border > 0)
    end
end

function NP.UpdateName(p)
    p.name:SetText(UnitName(p.unit))
end

-- Nivel con el color de dificultad; "+" élite, "??" jefe; rombo si es raro.
function NP.UpdateLevel(p)
    local unit = p.unit
    local class = Readable(UnitClassification(unit)) or "normal"
    p.rare:SetShown(p.level:IsShown() and (class == "rare" or class == "rareelite"))
    if not p.level:IsShown() then return end
    local level = Readable(UnitLevel(unit))
    if not level then
        p.level:SetText("")
        return
    end
    if level < 0 or class == "worldboss" then
        p.level:SetText("??")
        p.level:SetTextColor(WARN[1], WARN[2], WARN[3])
        return
    end
    local elite = class == "elite" or class == "rareelite"
    p.level:SetText(elite and (level .. "+") or tostring(level))
    local color = GetCreatureDifficultyColor and GetCreatureDifficultyColor(level)
    if color then
        p.level:SetTextColor(color.r, color.g, color.b)
    else
        p.level:SetTextColor(1, 0.82, 0)
    end
end

function NP.UpdateRaid(p)
    local index = Readable(GetRaidTargetIndex(p.unit))
    if index and SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(p.raid, index)
        p.raid:Show()
    else
        p.raid:Hide()
    end
end

-- Enemigo de misión (detección propia: Quest.lua).
function NP.UpdateQuest(p)
    local related = p.kind ~= "friend" and NP.db.quest and NP.Quest and NP.Quest.IsQuestUnit(p.unit)
    p.quest:SetShown(related and true or false)
end

-- Huella: el enemigo al que ataca tu mascota.
function NP.UpdatePet(p)
    local attacked = p.kind ~= "friend" and NP.db.petTarget and UnitExists("pet")
        and Readable(UnitIsUnit(p.unit, "pettarget"))
    p.pet:SetShown(attacked == true)
end

-- Insignia con tu % de aggro, en el centro de la barra. Es la insignia del módulo
-- «Aggro en placas» (Blazzito_ThreatPlate: un solo diseño y unos solos
-- ajustes para todas las placas, y se ve en la vista previa). Si ese addon
-- no está cargado, una sencilla propia. Los valores pueden venir secretos:
-- se pintan tal cual, sin compararlos (borde neutro).
local NEUTRAL = { 0.45, 0.47, 0.52 }

local function SharedBadges()
    local TP = ns.ThreatPlate
    return TP and TP.NewBadge and TP.db and TP or nil
end

function NP.BuildThreatBadge(p)
    local TP = SharedBadges()
    if TP then
        -- En el centro de la barra; Horizontal y Vertical la mueven desde ahí.
        p.threatBox = TP.NewBadge(p, function(badge)
            badge:ClearAllPoints()
            badge:SetPoint("CENTER", p.block, "CENTER", TP.db.offsetX, TP.db.offsetY)
        end)
        p.threatShared = true
    else
        local box = CreateFrame("Frame", nil, p)
        box.border = box:CreateTexture(nil, "BACKGROUND", nil, -1)
        box.border:SetAllPoints()
        box.border:SetColorTexture(1, 1, 1, 1)
        box.bg = box:CreateTexture(nil, "BACKGROUND", nil, 0)
        box.bg:SetColorTexture(COLORS.background[1], COLORS.background[2], COLORS.background[3], 0.95)
        box.text = Font(box, 9, "CENTER")
        box.text:SetPoint("CENTER", 0, 0)
        box:Hide()
        p.threatBox = box
    end
    p.threat = p.threatBox.text
end

function NP.LayoutThreatBadge(p, font, px)
    local box = p.threatBox
    -- Por encima de la barra y de sus textos.
    box:SetFrameLevel(p.health:GetFrameLevel() + 6)
    if p.threatShared then
        ns.ThreatPlate.StyleBadge(box)
        return
    end
    p.threat:SetFont(M.FONT, font, "OUTLINE")
    p.threat:SetTextColor(1, 1, 1)
    box:ClearAllPoints()
    box:SetPoint("CENTER", p.block, "CENTER", 0, 0)
    -- Ancho fijo para "100%": nunca cambia de tamaño ni de sitio.
    box:SetSize(math.ceil(font * 2.6) + 8, math.max(NP.db.height, font + 6))
    box.bg:ClearAllPoints()
    box.bg:SetPoint("TOPLEFT", px, -px)
    box.bg:SetPoint("BOTTOMRIGHT", -px, px)
end

-- Color de la insignia según la situación de aggro (legible o nil).
local function PaintThreatBadge(p, status)
    if p.threatShared then
        ns.ThreatPlate.SetBadgeStatus(p.threatBox, status)
        return
    end
    local r, g, b = NP.ThreatColor(status)
    if not r then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
    p.threatBox.border:SetVertexColor(r, g, b, 1)
end

function NP.UpdateThreat(p)
    local fs, box = p.threat, p.threatBox
    p.threatStatus = nil
    if p.kind == "friend" then
        box:Hide()
        return
    end
    if not NP.db.threat then
        box:Hide()
        NP.UpdateBorder(p)
        return
    end
    local _, status, pct = UnitDetailedThreatSituation("player", p.unit)
    local shown = false
    if p.threatShared then
        shown = ns.ThreatPlate.SetBadgeValue(box, p.unit, pct)
    elseif IsSecret(pct) then
        shown = pcall(fs.SetFormattedText, fs, "%d%%", pct) and true or false
    elseif pct ~= nil and (pct > 0 or Readable(UnitAffectingCombat(p.unit)) == true) then
        fs:SetFormattedText("%d%%", pct)
        shown = true
    end
    status = Readable(status)
    p.threatStatus = status
    PaintThreatBadge(p, status)
    box:SetShown(shown)
    NP.UpdateBorder(p)
end

-- Opacidad: objetivo entero, el resto atenuado; fuera de alcance, más.
function NP.UpdateAlpha(p)
    local db = NP.db
    local isTarget = Readable(UnitIsUnit(p.unit, "target"))
    p.isTarget = isTarget == true
    p.block.outline:SetShown(db.targetHighlight and p.isTarget)
    local alpha = 1
    if not p.isTarget and isTarget == false and UnitExists("target") then
        alpha = db.otherAlpha / 100
    end
    if db.range and p.inRange == false then
        alpha = alpha * db.rangeAlpha / 100
    end
    p:SetAlpha(alpha)
end

-- true / false / nil (sin comprobar o sin respuesta: cuenta como a tiro).
local function RangeOf(p)
    if not NP.db.range or p.kind == "friend" then return nil end
    return NP.InRange(p.unit)
end

function NP.UpdateRange(p)
    local before = p.inRange
    p.inRange = RangeOf(p)
    if p.inRange ~= before then NP.UpdateAlpha(p) end
end

---------------------------------------------------------------------------
-- Lanzamiento
---------------------------------------------------------------------------
local function PaintCastColor(p, locked)
    local cast, db = p.cast, NP.db
    local color = locked and COLORS.castLocked or db.castColor
    M.ColorBar(cast.bar, color[1], color[2], color[3])
end

-- A quién va dirigido (puede ser secreto: se pinta tal cual).
function NP.UpdateCastTarget(p)
    local cast, db, unit = p.cast, NP.db, p.unit
    local border = cast.block.border
    border:SetVertexColor(0, 0, 0, 1)
    cast.target:Hide()
    cast.time:Show()
    if db.castTarget or db.castWarn then
        local name, toYou
        if UnitSpellTargetName then name = UnitSpellTargetName(unit) end
        local readable = Readable(name)
        if readable then
            toYou = readable == UnitName("player")
        elseif not IsSecret(name) then
            name = nil
        end
        if toYou == nil then
            toYou = Readable(UnitIsUnit(unit .. "target", "player")) == true and (name ~= nil or not UnitSpellTargetName)
        end
        if toYou and db.castWarn then
            border:SetVertexColor(WARN[1], WARN[2], WARN[3], 1)
        end
        if db.castTarget and (name ~= nil or toYou) then
            if toYou then
                cast.target:SetText(ns.Translate("Tú"))
                cast.target:SetTextColor(WARN[1], WARN[2], WARN[3])
            else
                local fc = db.fontColor
                cast.target:SetText(name)
                cast.target:SetTextColor(fc[1], fc[2], fc[3])
            end
            cast.target:Show()
            cast.time:Hide()
        end
    end
    NP.PlaceCastText(p)
end

-- kind: start | channel | stop | interrupted | lock | unlock
function NP.UpdateCast(p, kind)
    local cast = p.cast
    if not NP.db.castbar then
        cast.holdUntil = nil
        cast:Hide()
        return
    end
    if kind == "stop" then
        if not cast.holdUntil then cast:Hide() end
        return
    end
    if kind == "interrupted" then
        -- Se queda un momento en rojo con "Interrumpido".
        if cast.endMS and GetTime() * 1000 <= cast.endMS + 250 then
            cast.holdUntil = GetTime() + 0.6
            cast.bar:SetMinMaxValues(0, 1)
            cast.bar:SetValue(1)
            M.ColorBar(cast.bar, WARN[1], WARN[2], WARN[3])
            cast.text:SetText(ns.Translate("Interrumpido"))
            cast.time:SetText("")
            cast.target:Hide()
            cast.shield:Hide()
            cast:Show()
        else
            cast:Hide()
        end
        return
    end
    if kind == "lock" or kind == "unlock" then
        if cast:IsShown() and not cast.holdUntil then
            cast.shield:SetShown(kind == "lock")
            PaintCastColor(p, kind == "lock")
        end
        return
    end

    local name, texture, startMS, endMS, locked, _
    if kind == "channel" then
        name, _, texture, startMS, endMS, _, locked = UnitChannelInfo(p.unit)
    else
        name, _, texture, startMS, endMS, _, _, locked = UnitCastingInfo(p.unit)
    end
    local rName, rStart, rEnd = Readable(name), Readable(startMS), Readable(endMS)
    if not (rName and rStart and rEnd) or rEnd <= rStart then
        cast:Hide()
        return
    end
    cast.fake, cast.holdUntil = nil, nil
    cast.channel = kind == "channel"
    cast.startMS, cast.endMS = rStart, rEnd
    cast.bar:SetMinMaxValues(0, rEnd - rStart)
    cast.icon:SetTexture(texture)
    cast.text:SetText(rName)
    local lockedValue = Readable(locked)
    if lockedValue ~= nil then
        cast.shield:SetShown(lockedValue and true or false)
        PaintCastColor(p, lockedValue)
    else
        -- Secreto: el escudo se muestra con la API que acepta booleanos secretos.
        cast.shield:Show()
        if not (cast.shield.SetAlphaFromBoolean and pcall(cast.shield.SetAlphaFromBoolean, cast.shield, locked, 1, 0)) then
            cast.shield:Hide()
        end
        PaintCastColor(p, false)
    end
    NP.UpdateCastTarget(p)
    cast:Show()
    CastOnUpdate(cast)
end

function NP.RefreshCast(p)
    if Readable(UnitCastingInfo(p.unit)) then
        NP.UpdateCast(p, "start")
    elseif Readable(UnitChannelInfo(p.unit)) then
        NP.UpdateCast(p, "channel")
    else
        p.cast.holdUntil = nil
        NP.UpdateCast(p, "stop")
    end
end

function NP.UpdateAll(p)
    if not UnitExists(p.unit) then return end
    if p.kind == "friend" then
        NP.UpdateName(p)
        NP.UpdateColor(p)
        NP.UpdateRaid(p)
        p.inRange = nil
        NP.UpdateAlpha(p)
        return
    end
    NP.UpdatePet(p)
    NP.UpdateColor(p)
    NP.UpdateHealth(p)
    NP.UpdateName(p)
    NP.UpdateLevel(p)
    NP.UpdateRaid(p)
    NP.UpdateQuest(p)
    NP.UpdateThreat(p)
    p.inRange = RangeOf(p)
    NP.UpdateAlpha(p)
    NP.RefreshCast(p)
    NP.UpdateDebuffs(p)
end

---------------------------------------------------------------------------
-- Vista previa (página de opciones): datos de ejemplo.
-- variant "target": tu objetivo con todo a la vista: élite y raro, de
-- misión, atacado por tu mascota, lanzando hacia ti, con aggro (insignia y
-- borde) y tus debuffs; con poca vida si el remate está activo.
-- variant "friend": un aliado (solo el nombre).
---------------------------------------------------------------------------
local function PreviewFriend(p)
    local db = NP.db
    p.kind = "friend"
    NP.Apply(p)
    local friendly = FACTION_BAR_COLORS and FACTION_BAR_COLORS[5]
    p.name:SetText(ns.Translate("Guardia de la ciudad"))
    p.name:SetTextColor(friendly and friendly.r or 0.3, friendly and friendly.g or 0.9, friendly and friendly.b or 0.3)
    p.raid:Hide()
    -- Desactivadas: se ve apagada, para que se note qué cambia.
    p:SetAlpha(db.friendly and 1 or 0.25)
end

function NP.PaintPreview(p, variant)
    if variant == "friend" then return PreviewFriend(p) end
    local db = NP.db
    NP.Apply(p)
    -- Con remate, por debajo del umbral (para ver su color); si no, 65 %.
    local percent = db.execute > 0 and math.max(5, db.execute - 5) or 65
    local hostile = FACTION_BAR_COLORS and FACTION_BAR_COLORS[2]
    local r, g, b = hostile and hostile.r or 0.85, hostile and hostile.g or 0.2, hostile and hostile.b or 0.2
    if db.execute > 0 then
        r, g, b = db.executeColor[1], db.executeColor[2], db.executeColor[3]
    end
    M.ColorBar(p.health, r, g, b)
    p.health:SetMinMaxValues(0, 100)
    p.health:SetValue(percent)
    local value = math.floor(1240 * percent / 100)
    local hpText = { percent = percent .. "%", value = tostring(value), both = value .. " · " .. percent .. "%", none = "" }
    p.hp:SetText(hpText[db.healthText] or "")
    p.name:SetText(ns.Translate("Ogro salvaje"))
    p.level:SetText("24+")
    p.level:SetTextColor(1, 0.5, 0.25)
    p.rare:SetShown(p.level:IsShown())
    p.quest:SetShown(db.quest)
    p.pet:SetShown(db.petTarget)
    p.raid:Show()
    if SetRaidTargetIconTexture then SetRaidTargetIconTexture(p.raid, 1) end

    -- Aggro: alto (naranja), en la insignia y, si está activado, en el borde.
    p.threatBox:SetShown(db.threat)
    p.threat:SetText("85%")
    r, g, b = NP.ThreatColor(2)
    PaintThreatBadge(p, 2)
    if db.threat and db.threatBorder and r then
        NP.TintBorder(p, r, g, b)
    else
        NP.TintBorder(p, nil)
    end
    p.block.outline:SetShown(db.targetHighlight)
    p:SetAlpha(1)

    local cast = p.cast
    if db.castbar then
        local now = GetTime() * 1000
        cast.fake, cast.channel, cast.holdUntil = true, false, nil
        cast.startMS, cast.endMS = now, now + 2500
        cast.bar:SetMinMaxValues(0, 2500)
        cast.icon:SetTexture("Interface\\Icons\\Spell_Fire_Fireball02")
        cast.text:SetText(ns.Translate("Bola de fuego"))
        cast.shield:Hide()
        PaintCastColor(p, false)
        cast.block.border:SetVertexColor(0, 0, 0, 1)
        cast.target:Hide()
        cast.time:Show()
        if db.castTarget then
            cast.target:SetText(ns.Translate("Tú"))
            cast.target:SetTextColor(WARN[1], WARN[2], WARN[3])
            cast.target:Show()
            cast.time:Hide()
        end
        if db.castWarn then cast.block.border:SetVertexColor(WARN[1], WARN[2], WARN[3], 1) end
        NP.PlaceCastText(p)
        cast:Show()
    else
        cast:Hide()
    end
    NP.PreviewDebuffs(p, true)
end
