-- Blazzito_Nameplates: placas de nombre de los enemigos con el estilo de
-- BlazzitoUI (barra con forma, nombre, % de vida, lanzamiento, objetivo
-- resaltado) y un indicador de rango que brilla cuando el enemigo está a tu
-- alcance.
--
-- Cómo convive con Blizzard: la placa de Blizzard sigue existiendo (es la que
-- recibe el clic para seleccionar), pero queda invisible mientras es nuestra.
-- Cuando el cliente reutiliza esa placa para un aliado, se le devuelve tal
-- cual. Las placas "prohibidas" para los addons no se tocan.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret
local MEDIA = "Interface\\AddOns\\Blazzito_Nameplates\\Media\\"

local NP = ns.NewModule("Nameplates", "Placas de nombre", {
    width = 140, height = 12, fontSize = 10,
    shape = "slant", flipH = false, flipV = false, border = 1, gloss = true,
    colorMode = "reaction",        -- reaction | threat
    healthText = "percent",        -- percent | none
    showName = true, fontColor = { 1, 1, 1 },
    castbar = true, castHeight = 10, castColor = { 0.95, 0.75, 0.25 },
    targetHighlight = true, otherAlpha = 80,
    range = true, rangePulse = true, rangeSize = 16, rangeColor = { 0.35, 1.00, 0.45 },
})
ns.Nameplates = NP
NP.plates = {}   -- placa base de Blizzard -> nuestra placa
NP.byUnit = {}   -- unidad (nameplateN) -> nuestra placa

local COLORS = M.COLORS

---------------------------------------------------------------------------
-- Rango: no hay forma de medir la distancia a un enemigo, así que se pregunta
-- si tus hechizos llegan (como hacen Blizzard y EllesmereUI). Con varios
-- hechizos (distancia y cuerpo a cuerpo) vale con que llegue uno; en el
-- cazador eso hace que la zona muerta de 5 a 8 m cuente como fuera de rango.
---------------------------------------------------------------------------
local RANGE_SPELLS = {
    HUNTER  = { 75, 3044, 2973, 2974 },  -- Disparo automático, Disparo arcano, Golpe de raptor, Cortar alas
    WARRIOR = { 78, 772, 6343, 100 },    -- Golpe heroico, Desgarrar, Atronar, Cargar
    ROGUE   = { 1752, 53, 2098 },        -- Golpe siniestro, Puñalada, Eviscerar
    PALADIN = { 20271, 879 },            -- Sentencia, Exorcismo
    MAGE    = { 133, 116, 5143 },        -- Bola de Fuego, Descarga de Escarcha, Misiles arcanos
    WARLOCK = { 686, 172 },              -- Descarga de las Sombras, Corrupción
    PRIEST  = { 585, 589 },              -- Castigo, Palabra de las Sombras: dolor
    DRUID   = { 5176, 8921, 1082, 6807 },-- Cólera, Fuego lunar, Garra, Vapulear
    SHAMAN  = { 403, 8042 },             -- Descarga de relámpagos, Choque de tierra
}

local function Knows(spellID)
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    return IsSpellKnown and IsSpellKnown(spellID) or false
end

local function SpellInRange(spellID, unit)
    local result
    if C_Spell and C_Spell.IsSpellInRange then
        result = C_Spell.IsSpellInRange(spellID, unit)
    elseif IsSpellInRange and GetSpellInfo then
        result = IsSpellInRange(GetSpellInfo(spellID), unit)
    end
    result = Readable(result)
    if result == 1 then return true end
    if result == 0 then return false end
    return result
end

-- true a rango · false fuera · nil no se sabe (sin hechizos o respuesta secreta)
function NP.InRange(unit)
    local _, class = UnitClass("player")
    local answered
    for _, spellID in ipairs(RANGE_SPELLS[class] or {}) do
        if Knows(spellID) then
            local result = SpellInRange(spellID, unit)
            if result == true then return true end
            if result == false then answered = false end
        end
    end
    return answered
end

---------------------------------------------------------------------------
-- Placa de Blizzard: invisible mientras es nuestra, devuelta al reutilizarse
---------------------------------------------------------------------------
local parking = CreateFrame("Frame")
parking:Hide()
local owned = setmetatable({}, { __mode = "k" })     -- UnitFrame de Blizzard -> true si es nuestra
local auraParent = setmetatable({}, { __mode = "k" }) -- UnitFrame -> padre original de sus auras
local hooked = {}

local function TakeOver(base)
    local uf = base.UnitFrame
    if not uf or (uf.IsForbidden and uf:IsForbidden()) then return end
    owned[uf] = true
    uf:SetAlpha(0)
    -- Sus iconos de auras, aunque invisibles, capturan el ratón: fuera de la placa.
    local auras = uf.AurasFrame
    if auras and auras:GetParent() ~= parking then
        auraParent[uf] = auras:GetParent()
        auras:SetParent(parking)
    end
    if not hooked[uf] then
        hooked[uf] = true
        local locked = false
        hooksecurefunc(uf, "SetAlpha", function(self)
            if locked or not owned[self] then return end
            locked = true
            self:SetAlpha(0)
            locked = false
        end)
    end
end

local function GiveBack(base)
    local uf = base.UnitFrame
    if not uf or not owned[uf] or (uf.IsForbidden and uf:IsForbidden()) then return end
    owned[uf] = nil
    uf:SetAlpha(1)
    local auras = uf.AurasFrame
    if auras and auraParent[uf] and auras:GetParent() == parking then auras:SetParent(auraParent[uf]) end
    auraParent[uf] = nil
end

-- Enemigos (y neutrales). Si la respuesta es secreta, casi siempre es un enemigo.
local function IsEnemy(unit)
    local friend = Readable(UnitIsFriend("player", unit))
    if friend == nil then return true end
    return not friend
end

---------------------------------------------------------------------------
-- Construcción de una placa (también la usa la vista previa)
---------------------------------------------------------------------------
local function Font(parent, size, justify)
    local fs = M.Font(parent, size, justify)
    fs:SetFont(M.FONT, size, "OUTLINE")
    return fs
end

-- Bloque con forma: borde, fondo y barra con máscara de forma y de extremo.
local function ShapedBlock(parent)
    local block = CreateFrame("Frame", nil, parent)
    block.border = block:CreateTexture(nil, "BACKGROUND", nil, -7)
    block.border:SetAllPoints()
    block.bg = block:CreateTexture(nil, "BACKGROUND", nil, -6)
    local bar = M.StatusBar(block)
    local fill = bar:GetStatusBarTexture()
    bar.mask = bar:CreateMaskTexture()
    fill:AddMaskTexture(bar.mask)
    bar.bg:AddMaskTexture(bar.mask)
    bar.lead = bar:CreateMaskTexture()
    fill:AddMaskTexture(bar.lead)
    bar.gloss = bar:CreateTexture(nil, "OVERLAY")
    bar.gloss:SetPoint("TOPLEFT", fill, "TOPLEFT")
    bar.gloss:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    bar.gloss:SetColorTexture(1, 1, 1, 1)
    if CreateColor then
        bar.gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.22))
    end
    bar.gloss:AddMaskTexture(bar.mask)
    bar.gloss:AddMaskTexture(bar.lead)
    block.bar = bar
    return block
end

local function LayoutBlock(block, tex, width, height, edge, gloss)
    local bg = COLORS.background
    block:SetSize(width, height)
    block.border:SetTexture(tex)
    block.border:SetVertexColor(0, 0, 0, 1)
    block.border:SetShown(edge > 0)
    block.bg:SetTexture(tex)
    block.bg:SetVertexColor(bg[1], bg[2], bg[3], 0.92)
    block.bg:ClearAllPoints()
    block.bg:SetPoint("TOPLEFT", edge, -edge)
    block.bg:SetPoint("BOTTOMRIGHT", -edge, edge)
    local bar = block.bar
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", edge, -edge)
    bar:SetPoint("BOTTOMRIGHT", -edge, edge)
    bar.mask:SetTexture(tex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bar.mask:ClearAllPoints()
    bar.mask:SetAllPoints(bar)
    bar.lead:SetTexture(tex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    bar.lead:ClearAllPoints()
    bar.lead:SetSize(width - 2 * edge, height - 2 * edge)
    bar.lead:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
    bar.gloss:SetShown(gloss)
end

function NP.Build(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(1, 1)
    p:SetPoint("CENTER")

    p.block = ShapedBlock(p)
    p.block:SetPoint("CENTER")
    p.health = p.block.bar
    -- Contorno del objetivo: la misma forma, 2 px más grande y del color de acento.
    p.highlight = p.block:CreateTexture(nil, "BACKGROUND", nil, -8)
    p.highlight:SetPoint("TOPLEFT", -2, 2)
    p.highlight:SetPoint("BOTTOMRIGHT", 2, -2)
    p.highlight:Hide()

    local text = CreateFrame("Frame", nil, p.block)
    text:SetAllPoints(p.health)
    text:SetFrameLevel(p.health:GetFrameLevel() + 5)
    p.hp = Font(text, 9, "RIGHT")
    p.name = Font(p, 10, "CENTER")
    p.name:SetPoint("BOTTOM", p.block, "TOP", 0, 3)

    p.raid = text:CreateTexture(nil, "OVERLAY")
    p.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    p.raid:Hide()

    -- Barra de lanzamiento con la misma forma
    local cast = CreateFrame("Frame", nil, p)
    cast.iconBox = CreateFrame("Frame", nil, cast)
    M.SetBackdrop(cast.iconBox)
    cast.icon = cast.iconBox:CreateTexture(nil, "ARTWORK")
    cast.icon:SetPoint("TOPLEFT", 1, -1)
    cast.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cast.block = ShapedBlock(cast)
    cast.bar = cast.block.bar
    cast.text = Font(cast.bar, 8, "LEFT")
    cast.time = Font(cast.bar, 8, "RIGHT")
    cast:SetScript("OnUpdate", function(self)
        local now = GetTime() * 1000
        if now >= self.endMS then
            if self.fake then
                self.startMS, self.endMS = now, now + (self.endMS - self.startMS)
            else
                self:Hide()
                return
            end
        end
        self.bar:SetValue(self.channel and (self.endMS - now) or (now - self.startMS))
        self.time:SetFormattedText("%.1f", (self.endMS - now) / 1000)
    end)
    cast:Hide()
    p.cast = cast

    -- Indicador de rango: check con halo que late
    local range = CreateFrame("Frame", nil, p)
    range:SetFrameLevel(p.block:GetFrameLevel() + 8)
    range.glow = range:CreateTexture(nil, "ARTWORK")
    range.glow:SetTexture(MEDIA .. "check_glow")
    range.glow:SetPoint("CENTER")
    range.glow:SetBlendMode("ADD")
    range.check = range:CreateTexture(nil, "OVERLAY")
    range.check:SetTexture(MEDIA .. "check")
    range.check:SetAllPoints()
    range.pulse = range.glow:CreateAnimationGroup()
    local fade = range.pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.25)
    fade:SetToAlpha(0.95)
    fade:SetDuration(0.7)
    fade:SetSmoothing("IN_OUT")
    range.pulse:SetLooping("BOUNCE")
    range:Hide()
    p.range = range

    NP.Apply(p)
    return p
end

-- Coloca todo según la configuración.
function NP.Apply(p)
    local db = NP.db
    local px = M.PixelSize()
    local edge = db.border * px
    local tex = M.ShapeTexture(db.shape, db.flipH, db.flipV)
    local a = COLORS.accent

    LayoutBlock(p.block, tex, db.width, db.height, edge, db.gloss)
    p.highlight:SetTexture(tex)
    p.highlight:SetVertexColor(a[1], a[2], a[3], 1)

    local fc = db.fontColor
    p.name:SetFont(M.FONT, db.fontSize, "OUTLINE")
    p.name:SetTextColor(fc[1], fc[2], fc[3])
    p.name:SetWidth(db.width + 20)
    p.name:SetShown(db.showName)
    p.hp:SetFont(M.FONT, math.max(7, db.fontSize - 1), "OUTLINE")
    p.hp:SetTextColor(fc[1], fc[2], fc[3])
    p.hp:ClearAllPoints()
    p.hp:SetPoint("RIGHT", -M.ShapeInset(db.shape, db.width), 0)
    p.hp:SetShown(db.healthText ~= "none" and db.height >= 8)

    p.raid:SetSize(db.height + 6, db.height + 6)
    p.raid:ClearAllPoints()
    p.raid:SetPoint("RIGHT", p.block, "LEFT", -4, 0)

    local cast, h = p.cast, db.castHeight
    cast:ClearAllPoints()
    cast:SetPoint("TOP", p.block, "BOTTOM", 0, -3)
    cast:SetSize(db.width, h)
    cast.iconBox:ClearAllPoints()
    cast.iconBox:SetSize(h, h)
    cast.iconBox:SetPoint("LEFT")
    cast.block:ClearAllPoints()
    cast.block:SetPoint("LEFT", cast.iconBox, "RIGHT", 2, 0)
    LayoutBlock(cast.block, tex, db.width - h - 2, h, edge, db.gloss)
    local castInset = M.ShapeInset(db.shape, db.width - h - 2)
    cast.text:SetFont(M.FONT, math.max(7, h - 2), "OUTLINE")
    cast.time:SetFont(M.FONT, math.max(7, h - 2), "OUTLINE")
    cast.text:ClearAllPoints()
    cast.text:SetPoint("LEFT", castInset, 0)
    cast.time:ClearAllPoints()
    cast.time:SetPoint("RIGHT", -castInset, 0)
    cast.text:SetPoint("RIGHT", cast.time, "LEFT", -3, 0)

    local c, size = db.rangeColor, db.rangeSize
    p.range:SetSize(size, size)
    p.range.check:SetVertexColor(c[1], c[2], c[3], 1)
    p.range.glow:SetVertexColor(c[1], c[2], c[3], 1)
    p.range.glow:SetSize(size * 1.6, size * 1.6)
    p.range.glow:SetShown(db.rangePulse)
end

---------------------------------------------------------------------------
-- Actualización
---------------------------------------------------------------------------
local function Smooth()
    return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.ExponentialEaseOut
end

local inCombat = false

local function HealthColor(unit)
    if UnitIsTapDenied and Readable(UnitIsTapDenied(unit)) then return unpack(COLORS.tapped) end
    if NP.db.colorMode == "threat" and inCombat then
        local status = Readable(UnitThreatSituation("player", unit))
        if status then
            local ok, r, g, b = pcall(GetThreatStatusColor, status)
            if ok and status > 0 then return r, g, b end
        end
    end
    if Readable(UnitIsPlayer(unit)) then
        local class = Readable(select(2, UnitClass(unit)))
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    local reaction = Readable(UnitReaction(unit, "player"))
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if color then return color.r, color.g, color.b end
    return 0.85, 0.20, 0.20
end

function NP.UpdateHealth(p)
    local unit, bar = p.unit, p.health
    bar:SetMinMaxValues(0, UnitHealthMax(unit))
    bar:SetValue(UnitHealth(unit), Smooth())
    if p.hp:IsShown() then
        local percent, ok = M.HealthPercent(unit)
        if ok then p.hp:SetFormattedText("%d%%", percent) else p.hp:SetText("") end
    end
end

function NP.UpdateColor(p)
    M.ColorBar(p.health, HealthColor(p.unit))
end

function NP.UpdateName(p)
    local name = UnitName(p.unit)
    p.name:SetText(name)
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

-- Objetivo: contorno de acento; el resto, algo transparentes.
function NP.UpdateTarget(p)
    local db = NP.db
    local isTarget = Readable(UnitIsUnit(p.unit, "target"))
    p.highlight:SetShown(db.targetHighlight and isTarget == true)
    local dim = UnitExists("target") and isTarget == false
    p:SetAlpha(dim and db.otherAlpha / 100 or 1)
end

function NP.UpdateCast(p, kind)
    local cast = p.cast
    if kind == "stop" or not NP.db.castbar then
        cast:Hide()
        return
    end
    local name, _, texture, startMS, endMS, notInterruptible, _
    if kind == "channel" then
        name, _, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(p.unit)
    else
        name, _, texture, startMS, endMS, _, _, notInterruptible = UnitCastingInfo(p.unit)
    end
    name, startMS, endMS = Readable(name), Readable(startMS), Readable(endMS)
    if not (name and startMS and endMS) or endMS <= startMS then
        cast:Hide()
        return
    end
    cast.fake = nil
    cast.channel = kind == "channel"
    cast.startMS, cast.endMS = startMS, endMS
    cast.bar:SetMinMaxValues(0, endMS - startMS)
    cast.icon:SetTexture(texture)
    cast.text:SetText(name)
    local color = Readable(notInterruptible) and COLORS.castLocked or NP.db.castColor
    M.ColorBar(cast.bar, color[1], color[2], color[3])
    cast:Show()
end

-- Indicador de rango: al lado de la insignia de aggro si está visible; si no,
-- a la derecha de la barra.
function NP.PlaceRange(p)
    local range = p.range
    range:ClearAllPoints()
    local badge = ns.ThreatPlate and ns.ThreatPlate.BadgeFor and ns.ThreatPlate.BadgeFor(p:GetParent())
    if badge and badge:IsShown() then
        range:SetPoint("LEFT", badge, "RIGHT", 3, 0)
    else
        range:SetPoint("LEFT", p.block, "RIGHT", 4, 0)
    end
end

function NP.UpdateRange(p)
    local range = p.range
    local show = NP.db.range and NP.InRange(p.unit) == true
    if show then
        NP.PlaceRange(p)
        if not range:IsShown() then
            range:Show()
            if NP.db.rangePulse then range.pulse:Play() end
        end
    elseif range:IsShown() then
        range.pulse:Stop()
        range:Hide()
    end
end

function NP.UpdateAll(p)
    if not UnitExists(p.unit) then return end
    NP.UpdateColor(p)
    NP.UpdateHealth(p)
    NP.UpdateName(p)
    NP.UpdateRaid(p)
    NP.UpdateTarget(p)
    if Readable(UnitCastingInfo(p.unit)) then
        NP.UpdateCast(p, "start")
    elseif Readable(UnitChannelInfo(p.unit)) then
        NP.UpdateCast(p, "channel")
    else
        NP.UpdateCast(p, "stop")
    end
    NP.UpdateRange(p)
end

function NP.ApplyAll()
    for _, p in pairs(NP.plates) do
        NP.Apply(p)
        if p.unit and p:IsShown() then NP.UpdateAll(p) end
    end
    if NP.preview then NP.PaintPreview(NP.preview) end
end

-- Placa de ejemplo para la página de configuración.
function NP.PaintPreview(p)
    NP.Apply(p)
    local hostile = FACTION_BAR_COLORS and FACTION_BAR_COLORS[2]
    M.ColorBar(p.health, hostile and hostile.r or 0.85, hostile and hostile.g or 0.2, hostile and hostile.b or 0.2)
    p.health:SetMinMaxValues(0, 100)
    p.health:SetValue(65)
    p.hp:SetText("65%")
    p.name:SetText(ns.Translate("Ogro salvaje"))
    p.highlight:SetShown(NP.db.targetHighlight)
    local cast = p.cast
    if NP.db.castbar then
        local now = GetTime() * 1000
        cast.fake, cast.channel = true, false
        cast.startMS, cast.endMS = now, now + 2500
        cast.bar:SetMinMaxValues(0, 2500)
        cast.icon:SetTexture("Interface\\Icons\\Spell_Fire_Fireball02")
        cast.text:SetText(ns.Translate("Bola de fuego"))
        M.ColorBar(cast.bar, NP.db.castColor[1], NP.db.castColor[2], NP.db.castColor[3])
        cast:Show()
    else
        cast:Hide()
    end
    p.range:ClearAllPoints()
    p.range:SetPoint("LEFT", p.block, "RIGHT", 4, 0)
    p.range:SetShown(NP.db.range)
    if NP.db.range and NP.db.rangePulse then p.range.pulse:Play() else p.range.pulse:Stop() end
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
local UNIT_EVENTS = {
    UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health",
    UNIT_NAME_UPDATE = "name", UNIT_FACTION = "color", UNIT_FLAGS = "color",
    UNIT_THREAT_SITUATION_UPDATE = "color", UNIT_THREAT_LIST_UPDATE = "color",
    UNIT_SPELLCAST_START = "start", UNIT_SPELLCAST_DELAYED = "start",
    UNIT_SPELLCAST_CHANNEL_START = "channel", UNIT_SPELLCAST_CHANNEL_UPDATE = "channel",
    UNIT_SPELLCAST_STOP = "stop", UNIT_SPELLCAST_FAILED = "stop",
    UNIT_SPELLCAST_INTERRUPTED = "stop", UNIT_SPELLCAST_CHANNEL_STOP = "stop",
}

local function Bind(p, unit)
    local driver = p.driver
    if not driver then
        driver = CreateFrame("Frame")
        driver:SetScript("OnEvent", function(_, event)
            local part = UNIT_EVENTS[event]
            if part == "health" then
                NP.UpdateHealth(p)
            elseif part == "name" then
                NP.UpdateName(p)
            elseif part == "color" then
                NP.UpdateColor(p)
            else
                NP.UpdateCast(p, part)
            end
        end)
        p.driver = driver
    end
    driver:UnregisterAllEvents()
    if unit then
        for event in pairs(UNIT_EVENTS) do pcall(driver.RegisterUnitEvent, driver, event, unit) end
    end
end

local function OnAdded(unit)
    local base = C_NamePlate.GetNamePlateForUnit(unit)
    if not base or (base.IsForbidden and base:IsForbidden()) then return end
    if not IsEnemy(unit) then
        GiveBack(base)
        local p = NP.plates[base]
        if p then p:Hide() end
        return
    end
    TakeOver(base)
    local p = NP.plates[base]
    if not p then
        p = NP.Build(base)
        NP.plates[base] = p
    end
    p.unit = unit
    NP.byUnit[unit] = p
    Bind(p, unit)
    p:Show()
    NP.UpdateAll(p)
end

local function OnRemoved(unit)
    local p = NP.byUnit[unit]
    if not p then return end
    NP.byUnit[unit] = nil
    Bind(p, nil)
    p.range.pulse:Stop()
    p.range:Hide()
    p.cast:Hide()
    p:Hide()
    p.unit = nil
end

-- Para Blazzito_ThreatPlate: dónde colocar la insignia de aggro.
function NP.AnchorFor(base)
    local p = NP.plates[base]
    if p and p.unit and p:IsShown() then return p.block end
end

function NP:OnEnable()
    local events = CreateFrame("Frame")
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
                             "RAID_TARGET_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        events:RegisterEvent(event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            OnAdded(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            OnRemoved(unit)
        elseif event == "PLAYER_TARGET_CHANGED" then
            for _, p in pairs(NP.byUnit) do NP.UpdateTarget(p) end
        elseif event == "RAID_TARGET_UPDATE" then
            for _, p in pairs(NP.byUnit) do NP.UpdateRaid(p) end
        else
            inCombat = event == "PLAYER_REGEN_DISABLED"
            for _, p in pairs(NP.byUnit) do NP.UpdateColor(p) end
        end
    end)

    -- Rango: 5 veces por segundo, solo en las placas visibles.
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        for _, p in pairs(NP.byUnit) do NP.UpdateRange(p) end
    end)

    -- Placas que ya estaban en pantalla al cargar (p. ej. tras /reload).
    if C_NamePlate.GetNamePlates then
        for _, base in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = base.namePlateUnitToken or (base.UnitFrame and base.UnitFrame.unit)
            if unit then OnAdded(unit) end
        end
    end
end
