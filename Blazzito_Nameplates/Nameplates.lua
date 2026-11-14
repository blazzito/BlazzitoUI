-- Blazzito_Nameplates: placas de nombre de los enemigos con el estilo de
-- BlazzitoUI. Reescritas desde cero (v2):
--
--  * Nameplates.lua  módulo, ajustes y utilidades (alcance, aggro, colores)
--  * Shape.lua       bloques con forma de ángulo fijo (tapas de 64x64)
--  * Plate.lua       construcción y pintado de una placa
--  * Debuffs.lua     tus debuffs sobre la placa
--  * Driver.lua      ciclo de vida, eventos y /bui placas
--  * Config.lua      página de opciones con vista previa
--
-- Cómo convive con Blizzard: su placa sigue existiendo (es la que recibe el
-- clic), pero su UnitFrame queda con alfa 0 mientras la placa es nuestra.
-- Forever recicla esos UnitFrame entre placas: al soltarla se le devuelve tal
-- cual. Las placas "prohibidas" no se tocan.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local Readable = M.Readable

-- "v" (versión de los ajustes) no va aquí: el núcleo rellena estos valores
-- antes de OnInitialize y la migración no llegaría a correr.
local NP = ns.NewModule("Nameplates", "Placas de nombre", {
    -- Tamaño
    scale = 1, width = 136, height = 12, offsetY = 0, fontSize = 10,
    -- Forma
    shape = "rect", flipH = false, flipV = false, border = 1, gloss = false,
    -- Vida y textos
    colorMode = "reaction",        -- reaction | threat
    healthText = "percent",        -- percent | value | both | none
    showName = true, showLevel = true, fontColor = { 1, 1, 1 },
    -- Objetivo y alcance
    targetHighlight = true, otherAlpha = 70,
    range = true, rangeAlpha = 45,
    -- Aggro
    threat = true, threatBorder = true,
    -- Lanzamiento
    castbar = true, castHeight = 10, castColor = { 0.95, 0.75, 0.25 },
    castTarget = true, castWarn = true,
    -- Tus debuffs y marcas
    auras = true, auraSize = 18, auraMax = 5,
    quest = true, petTarget = true,
    -- Remate: la barra cambia de color por debajo de este % (0 = no)
    execute = 20, executeColor = { 0.75, 0.35, 1.00 },
    -- Área de clic del tamaño de nuestra placa
    clickArea = true,
    -- Aliados: solo el nombre, con nuestro estilo
    friendly = true,
})
ns.Nameplates = NP
NP.MEDIA = "Interface\\AddOns\\Blazzito_Nameplates\\Media\\"

-- Ajustes de la versión anterior: la forma pasa a rectángulo (las formas
-- viejas se deformaban) y el indicador de rango deja de existir.
function NP:OnInitialize()
    local db = self.db
    if (db.v or 1) < 2 then
        db.shape = "rect"
        db.gloss = false
        db.rangePulse, db.rangeSize, db.rangeColor = nil, nil, nil
        if db.otherAlpha == 80 then db.otherAlpha = 70 end
        db.v = 2
    end
end

---------------------------------------------------------------------------
-- Alcance: no hay forma de medir la distancia a un enemigo, así que se
-- pregunta si tus hechizos llegan. Con varios (distancia y cuerpo a cuerpo)
-- vale con que llegue uno; al cazador la zona muerta de 5 a 8 m le cuenta
-- como fuera de alcance.
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

-- true a tiro · false fuera · nil no se sabe (sin hechizos o respuesta secreta)
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
-- ¿Placa nuestra, y de qué tipo?
--  * "enemy": se puede atacar y Blizzard la pinta con barra de vida.
--  * "friend": no se puede atacar (aliados y neutrales): solo el nombre.
-- Nunca: objetos interactivos, placas de "solo widgets", tu placa personal,
-- ni enemigos a los que Blizzard no pone barra (eran las placas que salían
-- "donde no hay nada").
---------------------------------------------------------------------------
-- La barra de vida de la placa de Blizzard (o nil).
function NP.BlizzardHealthBar(uf)
    if type(uf) ~= "table" then return nil end
    local bar = uf.healthBar
    if type(bar) ~= "table" and type(uf.HealthBarsContainer) == "table" then bar = uf.HealthBarsContainer.healthBar end
    return type(bar) == "table" and bar or nil
end

-- Devuelve el tipo ("enemy" / "friend") o nil y el motivo.
function NP.Kind(unit, uf)
    if not UnitExists(unit) then return nil, "no existe" end
    if UnitIsGameObject and Readable(UnitIsGameObject(unit)) == true then return nil, "objeto" end
    if UnitNameplateShowsWidgetsOnly and Readable(UnitNameplateShowsWidgetsOnly(unit)) == true then return nil, "solo widgets" end
    if Readable(UnitIsUnit(unit, "player")) == true then return nil, "tu placa personal" end
    local attack = Readable(UnitCanAttack("player", unit))
    if attack == nil then
        -- Respuesta secreta: un aliado casi nunca lo es.
        local friend = Readable(UnitIsFriend("player", unit))
        attack = friend ~= true
    end
    if attack then
        local bar = NP.BlizzardHealthBar(uf)
        if bar and bar.IsShown and bar:IsShown() == false then return nil, "Blizzard no muestra barra" end
        return "enemy"
    end
    if NP.db.friendly then return "friend" end
    return nil, "aliado (placas aliadas desactivadas)"
end

function NP.Wants(unit, uf)
    return NP.Kind(unit, uf) ~= nil
end

---------------------------------------------------------------------------
-- Colores
---------------------------------------------------------------------------
NP.inCombat = false

-- Situación de aggro legible (0..3) o nil.
function NP.ThreatStatus(unit)
    return Readable(UnitThreatSituation("player", unit))
end

function NP.ThreatColor(status)
    if not status then return nil end
    local ok, r, g, b = pcall(GetThreatStatusColor, status)
    if ok and r then return r, g, b end
end

function NP.HealthColor(unit)
    if UnitIsTapDenied and Readable(UnitIsTapDenied(unit)) then return unpack(M.COLORS.tapped) end
    if NP.db.colorMode == "threat" and NP.inCombat then
        local status = NP.ThreatStatus(unit)
        if status and status > 0 then
            local r, g, b = NP.ThreatColor(status)
            if r then return r, g, b end
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

-- Remate: por debajo del umbral, la barra toma el color de remate. Con la
-- vida legible se compara; si es secreta, decide una curva de color del
-- cliente (UnitHealthPercent pinta sin que el addon vea el número).
local curves = {}

local function ExecuteCurve(r, g, b, threshold, e)
    local key = string.format("%.3f:%.3f:%.3f:%d:%.3f:%.3f:%.3f", r, g, b, threshold, e[1], e[2], e[3])
    local curve = curves[key]
    if curve then return curve end
    curve = C_CurveUtil.CreateColorCurve()
    if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then
        curve:SetType(Enum.LuaCurveType.Linear)
    end
    local x = threshold / 100
    curve:AddPoint(0, CreateColor(e[1], e[2], e[3], 1))
    curve:AddPoint(x, CreateColor(e[1], e[2], e[3], 1))
    curve:AddPoint(math.min(1, x + 0.001), CreateColor(r, g, b, 1))
    curve:AddPoint(1, CreateColor(r, g, b, 1))
    curves[key] = curve
    return curve
end

function NP.ExecuteColor(unit, r, g, b)
    local threshold, e = NP.db.execute, NP.db.executeColor
    if not threshold or threshold <= 0 or M.IsSecret(r) then return r, g, b end
    local percent, ok = M.HealthPercent(unit)
    local value = ok and Readable(percent)
    if value then
        if value <= threshold then return e[1], e[2], e[3] end
        return r, g, b
    end
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitHealthPercent and CreateColor) then return r, g, b end
    local done, color = pcall(UnitHealthPercent, unit, true, ExecuteCurve(r, g, b, threshold, e))
    if done and type(color) == "table" and color.GetRGB then return color:GetRGB() end
    return r, g, b
end

-- Color del nombre de un aliado: clase si es jugador, reacción si no.
function NP.FriendColor(unit)
    if Readable(UnitIsPlayer(unit)) then
        local class = Readable(select(2, UnitClass(unit)))
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    local reaction = Readable(UnitReaction(unit, "player"))
    local color = reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]
    if color then return color.r, color.g, color.b end
    return 1, 1, 1
end

-- Tamaño de un píxel real para un marco (las placas ignoran la escala de la
-- placa de Blizzard y llevan la suya).
function NP.Pixel(frame)
    if PixelUtil and PixelUtil.GetNearestPixelSize and frame and frame.GetEffectiveScale then
        return PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1)
    end
    return 1
end

function NP.Font(parent, size, justify)
    local fs = M.Font(parent, size, justify)
    fs:SetFont(M.FONT, size, "OUTLINE")
    return fs
end
