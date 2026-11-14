-- Blazzito_CombatText · Display.lua
-- Motor de animación: zonas de texto (Entrante, Saliente, Avisos) donde cada
-- mensaje recorre un camino (parábola, recto, en ángulo o estático). Los
-- críticos pueden "estallar" en el centro de su zona. Los mensajes nuevos
-- empujan a los anteriores para que nunca se pisen.
--
-- Los números suelen llegar como valores secretos: solo se pasan a
-- SetFormattedText y a los formateadores del cliente, nunca se suman ni se
-- comparan.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret = M.IsSecret

local function Area(overrides)
    local d = {
        enabled = true,
        style = "parabola",     -- parabola | straight | angled | static
        direction = "down",     -- down | up
        curve = "left",         -- left | right (hacia dónde se abre el arco)
        height = 260, width = 90,
        fontSize = 18, critScale = 1.6, duration = 2.6,
        pow = true,             -- críticos con golpe en el centro
    }
    for key, value in pairs(overrides) do d[key] = value end
    return d
end

local function Category(area, color, on)
    return { on = on ~= false, area = area, color = color }
end

local CT = ns.NewModule("CombatText", "Texto de combate", {
    font = "russo",             -- ver CT.FONT_LIST (o "lsm:<nombre>")
    outline = "OUTLINE",
    abbreviate = true,
    icons = true,
    glyphs = true,              -- espada (cuerpo a cuerpo), flecha (a distancia) y huella (mascota)
    schoolColors = true,
    hideBlizzardSelf = true,
    -- Agrupar golpes seguidos del mismo hechizo en uno solo ("4.312 ×3").
    merge = { outgoing = true, incoming = false, window = 0.4 },
    cooldownMin = 5,            -- avisos de enfriamiento: solo los de al menos N segundos
    -- Más llamativo (Flair.lua)
    flair = {
        sizeByHit = true,       -- los golpes grandes (respecto a tu media) salen más grandes
        critBurst = true,       -- estallido detrás de los críticos
        critShake = true,       -- temblor breve al aparecer un crítico
        critLabel = true,       -- "¡Crítico!" encima del número
        streak = true,          -- rachas de críticos: "¡Crítico ×3!"
        summary = true,         -- resumen al salir de combate
        killSkull = true,       -- golpe de gracia con calavera
        dotSummary = true,      -- daño en el tiempo: tics pequeños y el total al acabar
        overkill = true,        -- exceso de daño al matar
        minHit = 0,             -- ocultar tus golpes por debajo de esto (0 = todos)
        minHitGroupOnly = true, -- ...solo en grupo o banda
    },
    areas = {
        incoming = Area({ curve = "left" }),
        outgoing = Area({ curve = "right" }),
        notification = Area({ style = "straight", direction = "up", height = 150, width = 0,
                              fontSize = 20, duration = 3, pow = false }),
    },
    categories = {
        incomingDamage = Category("incoming", { 1.00, 0.20, 0.20 }),
        incomingHeal   = Category("incoming", { 0.25, 1.00, 0.35 }),
        incomingAvoid  = Category("incoming", { 1.00, 1.00, 1.00 }),
        incomingPower  = Category("incoming", { 0.35, 0.55, 1.00 }, false),
        outgoingDamage = Category("outgoing", { 1.00, 1.00, 1.00 }),
        outgoingHeal   = Category("outgoing", { 0.25, 1.00, 0.35 }),
        outgoingMiss   = Category("outgoing", { 0.75, 0.75, 0.75 }),
        petDamage      = Category("outgoing", { 0.95, 0.65, 0.25 }),
        combat         = Category("notification", { 1.00, 0.35, 0.35 }),
        buffs          = Category("notification", { 0.45, 0.80, 1.00 }),
        debuffs        = Category("notification", { 1.00, 0.45, 0.45 }),
        procs          = Category("notification", { 1.00, 0.85, 0.20 }),
        cooldowns      = Category("notification", { 0.60, 1.00, 0.60 }),
        lowHealth      = Category("notification", { 1.00, 0.10, 0.10 }),
        killingBlow    = Category("notification", { 1.00, 0.55, 0.10 }),
        reputation     = Category("notification", { 0.55, 0.55, 1.00 }),
        honor          = Category("notification", { 0.90, 0.75, 0.30 }),
        loot           = Category("notification", { 1.00, 1.00, 1.00 }),
        money          = Category("notification", { 1.00, 0.85, 0.30 }),
    },
    positions = {},
})
ns.CombatText = CT

CT.AREAS = {
    { key = "incoming", label = "Texto entrante", pos = { "CENTER", "CENTER", -160, -10 } },
    { key = "outgoing", label = "Texto saliente", pos = { "CENTER", "CENTER", 160, -10 } },
    { key = "notification", label = "Avisos", pos = { "CENTER", "CENTER", 0, 190 } },
}

local FONT_DIR = "Interface\\AddOns\\Blazzito_CombatText\\Media\\Fonts\\"
-- Fuentes: las del juego, las incluidas (libres, gruesas: buenas para números)
-- y las que otros addons comparten con LibSharedMedia ("lsm:<nombre>").
CT.FONT_LIST = {
    { key = "russo", text = "Russo One", path = function() return FONT_DIR .. "RussoOne.ttf" end },
    { key = "changa", text = "Changa", path = function() return FONT_DIR .. "Changa.ttf" end },
    { key = "barlow", text = "Barlow Condensed", path = function() return FONT_DIR .. "BarlowCondensed.ttf" end },
    { key = "ptsans", text = "PT Sans Narrow", path = function() return FONT_DIR .. "PTSansNarrowBold.ttf" end },
    { key = "combat", text = "De combate (la del juego)", path = function()
        local font = _G.CombatTextFont and _G.CombatTextFont:GetFont()
        return font or _G.DAMAGE_TEXT_FONT or M.FONT
    end },
    { key = "ui", text = "De BlazzitoUI", path = function() return M.FONT end },
    { key = "skurri", text = "Skurri", path = function() return "Fonts\\SKURRI.TTF" end },
    { key = "morpheus", text = "Morpheus", path = function() return "Fonts\\MORPHEUS.TTF" end },
}
local BY_KEY = {}
for _, f in ipairs(CT.FONT_LIST) do BY_KEY[f.key] = f end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
end

-- Las de LibSharedMedia que no son de las de arriba.
function CT.SharedFonts()
    local lsm, out = LSM(), {}
    if not (lsm and lsm.List) then return out end
    local ok, list = pcall(lsm.List, lsm, "font")
    if not ok or type(list) ~= "table" then return out end
    for _, name in ipairs(list) do out[#out + 1] = { key = "lsm:" .. name, text = name } end
    return out
end

function CT.FontPath(key)
    key = key or CT.db.font
    local f = BY_KEY[key]
    if f then return f.path() end
    local name = type(key) == "string" and key:match("^lsm:(.+)$")
    local lsm = name and LSM()
    if lsm then
        local ok, path = pcall(lsm.Fetch, lsm, "font", name, true)
        if ok and path then return path end
    end
    return BY_KEY.combat.path()
end

local POOL_MAX = 60
local BURST = "Interface\\AddOns\\Blazzito_CombatText\\Media\\glyph_burst"
local SHAKE_TIME, BURST_TIME = 0.25, 0.55
local POP_TIME = 0.14       -- duración del golpe de un crítico
local POP_SCALE = 0.9       -- cuánto más grande empieza (+90 %)
local FADE_IN, FADE_OUT = 0.06, 0.30

CT.frames = {}              -- zona -> marco (se puede mover)
CT.live = {}                -- mensajes en pantalla
local pool = {}
local layer

---------------------------------------------------------------------------
-- Zonas
---------------------------------------------------------------------------
local function AreaCfg(key) return CT.db.areas[key] end

-- El marco de la zona mide lo que ocupa el recorrido (para moverlo con /bui mover).
function CT.LayoutArea(key)
    local a, frame = AreaCfg(key), CT.frames[key]
    if not frame then return end
    frame:SetSize(math.max(80, a.width + 140), math.max(40, a.height))
    frame:SetShown(a.enabled)
end

local function BuildAreas()
    layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints(UIParent)
    layer:SetFrameStrata("HIGH")
    for _, info in ipairs(CT.AREAS) do
        local frame = CreateFrame("Frame", nil, layer)
        frame:SetSize(1, 1)
        CT.frames[info.key] = frame
        ns.Movers.Register(frame, "sct_" .. info.key, info.label, info.pos, CT.db.positions, {
            onUnlock = function() CT.SetPreview("movers", true) end,
            onLock = function() CT.SetPreview("movers", false) end,
            -- Tamaño de la zona: ancho = curvatura del arco, alto = recorrido.
            getSize = function() local a = CT.db.areas[info.key]; return a.width, a.height end,
            setSize = function(w, h)
                local a = CT.db.areas[info.key]
                a.width = math.max(0, math.min(250, w))
                a.height = math.max(60, math.min(500, h))
                CT.LayoutArea(info.key)
            end,
        })
        CT.LayoutArea(info.key)
    end
    layer:SetScript("OnUpdate", function() CT.Animate() end)
end

---------------------------------------------------------------------------
-- Mensajes
---------------------------------------------------------------------------
local function Acquire()
    local e = table.remove(pool)
    if e then return e end
    if #CT.live >= POOL_MAX then
        -- Ráfaga enorme: se recicla el más viejo.
        e = table.remove(CT.live, 1)
        return e
    end
    e = {}
    e.fs = layer:CreateFontString(nil, "OVERLAY")
    e.icon = layer:CreateTexture(nil, "OVERLAY")
    e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    e.tag = layer:CreateFontString(nil, "OVERLAY")
    e.burst = layer:CreateTexture(nil, "ARTWORK")
    e.burst:SetTexture(BURST)
    if e.burst.SetBlendMode then e.burst:SetBlendMode("ADD") end
    e.tag:Hide()
    e.burst:Hide()
    return e
end

local function Release(index)
    local e = table.remove(CT.live, index)
    e.fs:Hide()
    e.icon:Hide()
    if e.tag then e.tag:Hide() end
    if e.burst then e.burst:Hide() end
    pool[#pool + 1] = e
end

-- Distancia recorrida por un mensaje que avanza (sin contar el golpe).
local function Travel(e, now)
    local a = e.a
    if a.style == "static" then return e.push end
    return (now - e.t0) / e.dur * a.height + e.push
end

-- Mensajes nuevos empujan a los anteriores a lo largo del camino para que no
-- se pisen (cada uno deja sitio para su propia altura de línea).
local function Spread(key, now)
    local list = {}
    for _, e in ipairs(CT.live) do
        if e.key == key and not e.pow then
            list[#list + 1] = { e = e, d = Travel(e, now) }
        end
    end
    table.sort(list, function(x, y) return x.d < y.d end)
    for i = 2, #list do
        local need = list[i - 1].d + list[i - 1].e.lineH
        if list[i].d < need then
            list[i].e.push = list[i].e.push + (need - list[i].d)
            list[i].d = need
        end
    end
end

local function FormatOrText(fs, fmt, a, b)
    if IsSecret(b) or b ~= nil then
        fs:SetFormattedText(fmt, a, b)
    elseif IsSecret(a) or a ~= nil then
        fs:SetFormattedText(fmt, a)
    else
        fs:SetText(fmt)
    end
end

-- Iconos que van enteros y sin teñir (la calavera del golpe de gracia).
CT.PLAIN = { ["Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"] = true }

-- Muestra un mensaje en una zona. fmt + valores: lo que se escribe (los
-- valores pueden ser secretos). color = { r, g, b }. icon = textura opcional.
-- opts (opcional): scale (tamaño), label (texto encima, p. ej. "¡Crítico!"),
-- burst (estallido detrás), shake (temblor), faded (más tenue).
function CT.Emit(key, fmt, a, b, color, crit, icon, opts)
    if not layer then return end
    local area = AreaCfg(key)
    if not (area and area.enabled) then return end
    local now = GetTime()
    local e = Acquire()
    e.key, e.a = key, area
    e.t0, e.push, e.crit = now, 0, crit and true or false
    e.pow = e.crit and area.pow
    e.dur = area.duration * (e.pow and 0.8 or 1)
    if type(opts) ~= "table" then opts = {} end
    e.size = math.floor(area.fontSize * (e.crit and area.critScale or 1) * (opts.scale or 1) + 0.5)
    e.shake = opts.shake and true or false
    e.faded = opts.faded and true or false
    e.lineH = e.size * 1.15
    e.popDone = not e.pow

    local fs = e.fs
    fs:SetFont(CT.FontPath(), e.size, CT.db.outline)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetTextColor(color[1], color[2], color[3])
    FormatOrText(fs, fmt, a, b)
    fs:SetAlpha(0)
    fs:Show()

    local glyph = icon and CT.IS_GLYPH and CT.IS_GLYPH[icon]
    local plain = icon and CT.PLAIN[icon]
    if icon and (plain or (glyph and CT.db.glyphs) or (not glyph and CT.db.icons)) then
        e.icon:SetTexture(icon)
        -- Los dibujos (espada, flecha, huella) van enteros y del color del número;
        -- los iconos de hechizo, recortados y con su color.
        if plain then
            e.icon:SetTexCoord(0, 1, 0, 1)
            e.icon:SetVertexColor(1, 1, 1)
            e.icon:SetSize(e.size * 1.1, e.size * 1.1)
        elseif glyph then
            e.icon:SetTexCoord(0, 1, 0, 1)
            e.icon:SetVertexColor(color[1], color[2], color[3])
            e.icon:SetSize(e.size * 1.1, e.size * 1.1)
        else
            e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            e.icon:SetVertexColor(1, 1, 1)
            e.icon:SetSize(e.size, e.size)
        end
        e.icon:Show()
        e.hasIcon = true
    else
        e.icon:Hide()
        e.hasIcon = false
    end

    -- Etiqueta encima ("¡Crítico ×3!") y estallido detrás.
    if opts.label then
        e.tag:SetFont(CT.FontPath(), math.max(9, math.floor(e.size * 0.42)), CT.db.outline)
        e.tag:SetTextColor(color[1], color[2], color[3])
        e.tag:SetText(opts.label)
        e.tag:SetAlpha(0)
        e.tag:Show()
        e.hasTag = true
    else
        e.tag:Hide()
        e.hasTag = false
    end
    if opts.burst then
        e.burst:SetVertexColor(color[1], color[2], color[3])
        e.burst:SetAlpha(0)
        e.burst:Show()
        e.hasBurst = true
    else
        e.burst:Hide()
        e.hasBurst = false
    end

    if e.pow then
        -- Los críticos anteriores de la zona se apartan hacia abajo.
        for _, other in ipairs(CT.live) do
            if other.key == key and other.pow then other.stack = (other.stack or 0) + other.lineH end
        end
        e.stack = 0
    end
    CT.live[#CT.live + 1] = e
    if not e.pow then Spread(key, now) end
    CT.Place(e, now)
    return e
end

-- Coloca un mensaje según su progreso.
function CT.Place(e, now)
    local a, frame = e.a, CT.frames[e.key]
    local elapsed = now - e.t0
    local t = elapsed / e.dur
    local x, y
    local down = a.direction == "down"
    local origin = down and "TOP" or "BOTTOM"

    if e.pow then
        if elapsed < POP_TIME then
            e.fs:SetTextHeight(e.size * (1 + (1 - elapsed / POP_TIME) * POP_SCALE))
        elseif not e.popDone then
            e.popDone = true
            e.fs:SetTextHeight(e.size)
        end
        x = 0
        y = (down and -1 or 1) * (a.height / 2) - (down and 1 or -1) * (e.stack or 0)
    else
        local dist = Travel(e, now)
        local side = a.curve == "left" and -1 or 1
        if a.style == "parabola" and a.height > 0 then
            local mid = a.height / 2
            local k = (dist - mid) / mid
            x = side * a.width * (1 - k * k)
        elseif a.style == "angled" and a.height > 0 then
            x = side * a.width * dist / a.height
        else
            x = 0
        end
        y = down and -dist or dist
    end

    -- Temblor breve al aparecer (se calma enseguida).
    if e.shake and elapsed < SHAKE_TIME then
        local k = 1 - elapsed / SHAKE_TIME
        x = x + math.sin(elapsed * 90) * 3.5 * k
        y = y + math.cos(elapsed * 70) * 1.5 * k
    end

    e.fs:ClearAllPoints()
    e.fs:SetPoint("CENTER", frame, origin, x, y)
    if e.hasIcon then
        e.icon:ClearAllPoints()
        e.icon:SetPoint("RIGHT", e.fs, "LEFT", -3, 0)
    end

    local alpha = 1
    if t < FADE_IN then
        alpha = t / FADE_IN
    elseif t > 1 - FADE_OUT then
        alpha = math.max(0, (1 - t) / FADE_OUT)
    end
    if e.faded then alpha = alpha * 0.7 end
    e.fs:SetAlpha(alpha)
    e.icon:SetAlpha(alpha)
    if e.hasTag then
        e.tag:ClearAllPoints()
        e.tag:SetPoint("BOTTOM", e.fs, "TOP", 0, 1)
        e.tag:SetAlpha(alpha)
    end
    if e.hasBurst then
        -- Crece y se apaga en medio segundo.
        local k = math.min(1, elapsed / BURST_TIME)
        local size = e.size * (1.6 + 1.4 * k)
        e.burst:ClearAllPoints()
        e.burst:SetPoint("CENTER", e.fs, "CENTER")
        e.burst:SetSize(size, size)
        e.burst:SetAlpha(math.max(0, 0.75 * (1 - k)) * alpha)
    end
end

function CT.Animate()
    local now = GetTime()
    for i = #CT.live, 1, -1 do
        local e = CT.live[i]
        local finished = now - e.t0 >= e.dur
        if not finished and not e.pow and e.a.style ~= "static" then
            finished = Travel(e, now) > e.a.height
        end
        if finished then
            Release(i)
        else
            CT.Place(e, now)
        end
    end
end

function CT.ClearAll()
    for i = #CT.live, 1, -1 do Release(i) end
end

---------------------------------------------------------------------------
-- Formato de números (los formateadores del cliente aceptan valores secretos)
---------------------------------------------------------------------------
function CT.Amount(value)
    if CT.db.abbreviate and AbbreviateNumbers then return AbbreviateNumbers(value) end
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(value) end
    return value
end

-- Colores por escuela de magia (solo si la escuela es legible).
CT.SCHOOL_COLORS = {
    [1] = { 1.00, 1.00, 1.00 },  -- física
    [2] = { 1.00, 0.90, 0.50 },  -- sagrado
    [4] = { 1.00, 0.50, 0.00 },  -- fuego
    [8] = { 0.30, 1.00, 0.30 },  -- naturaleza
    [16] = { 0.50, 1.00, 1.00 }, -- escarcha
    [32] = { 0.60, 0.40, 1.00 }, -- sombras
    [64] = { 1.00, 0.50, 1.00 }, -- arcano
}

---------------------------------------------------------------------------
-- Vista previa: mensajes de ejemplo mientras está abierta la configuración o
-- el modo mover, para ver los arcos al ajustarlos.
---------------------------------------------------------------------------
local SAMPLES = {
    { "incoming", "-%s", 1234, "incomingDamage" },
    { "outgoing", "%s", 2875, "outgoingDamage", false, "Interface\\Icons\\Ability_Hunter_SteadyShot" },
    { "incoming", "+%s", 640, "incomingHeal" },
    { "outgoing", "%s", 5310, "outgoingDamage", true, "Interface\\Icons\\Ability_Marksmanship" },
    { "incoming", "Esquiva", nil, "incomingAvoid" },
    { "outgoing", "%s", 412, "petDamage" },
    { "notification", "+Aspecto del halcón", nil, "buffs" },
    { "incoming", "-%s", 3102, "incomingDamage", true },
    { "outgoing", "+%s", 880, "outgoingHeal", false, "Interface\\Icons\\Spell_Holy_Heal" },
    { "notification", "¡Fuego a discreción!", nil, "procs" },
}
local previewReasons, previewTicker, sampleIndex = {}, nil, 0

function CT.EmitSample(i)
    local s = SAMPLES[i]
    local cat = CT.db.categories[s[4]]
    local value = s[3] and CT.Amount(s[3]) or nil
    CT.Emit(cat.area, ns.Translate(s[2]), value, nil, cat.color, s[5], s[6])
end

function CT.SetPreview(reason, on)
    previewReasons[reason] = on or nil
    local active = next(previewReasons) ~= nil
    if active and not previewTicker then
        previewTicker = C_Timer.NewTicker(0.55, function()
            sampleIndex = sampleIndex % #SAMPLES + 1
            CT.EmitSample(sampleIndex)
        end)
    elseif not active and previewTicker then
        previewTicker:Cancel()
        previewTicker = nil
    end
end

function CT.Burst()
    for i = 1, #SAMPLES do
        C_Timer.After(i * 0.18, function() CT.EmitSample(i) end)
    end
end

function CT:OnEnable()
    BuildAreas()
    if CT.StartFlair then CT.StartFlair() end
    ns.Config.OnOpenChanged(function(open) CT.SetPreview("config", open) end)
    if CT.StartSources then CT.StartSources() end
    if CT.StartCooldowns then CT.StartCooldowns() end
end
