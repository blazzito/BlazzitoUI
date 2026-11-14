-- Módulo de marcos de unidad: jugador, objetivo, objetivo del objetivo y mascota.
-- Este archivo crea los marcos seguros y los conecta a los eventos. El dibujo
-- está en Elements.lua y la página de configuración en Config.lua.
local _, ns = ...

local function UnitDefaults(overrides)
    local d = {
        enabled = true,
        width = 230, height = 38, power = 8,
        shape = "slant",            -- ver Media.SHAPES
        flipH = false,              -- voltear la forma en horizontal
        flipV = false,              -- voltear la forma en vertical
        reverseFill = false,
        portrait = "none",          -- none | 2d | 3d | class
        portraitSize = 100,         -- % del alto del marco
        portraitZoom = 100,         -- solo 3D: % de acercamiento
        portraitOffset = 0,         -- solo 3D: subir o bajar el encuadre
        portraitFacing = 0,         -- solo 3D: giro del modelo en grados (+ = hacia su izquierda)
        portraitInvert = false,     -- retrato al otro lado (efecto espejo; el 3D además se gira)
        portraitShift = 0,          -- solo 3D: mover la imagen en horizontal (% de medio ancho; + = derecha)
        portraitBarAlpha = 55,      -- "3D dentro de la barra": opacidad (%)
        healthColor = "class",      -- class | gradient | custom
        customColor = { 0.30, 0.75, 0.40 },
        healthText = "percent",     -- percent | value | both | none
        healPrediction = true,      -- tramo translúcido con la curación entrante
        absorbs = true,             -- franja con el tamaño del escudo
        absorbColor = { 0.75, 0.90, 1.00 },
        powerColor = "type",        -- type | class | custom
        powerCustomColor = { 0.20, 0.45, 1.00 },
        powerText = "none",         -- percent | value | both | none
        showName = true, showLevel = true, fontSize = 12,
        fontColor = { 1, 1, 1 },    -- nombre y textos de vida y recurso (el nivel va por dificultad)
        castbar = false, castColor = { 0.95, 0.75, 0.25 },
        castShape = "inherit",      -- inherit (igual que el marco) o una forma
        castHeight = 18,
        castWidth = 0,              -- 0 = igual que el marco; si no, centrada debajo
        castIcon = true,
        castFlipH = false,          -- invierte la forma de la barra respecto a la del marco
        castFlipV = false,
        combo = false,
        -- Puntos de combo (Combo.lua). Diseño según la clase del personaje.
        comboStyleRogue = "gems",   -- ver UF.COMBO_STYLES
        comboStyleDruid = "claws",
        comboPosition = "above",    -- above | below | edge (montados en el borde de arriba)
        comboAlign = "center",      -- spread | left | center | right
        comboSize = 16,             -- iconos y número
        comboBarHeight = 5,         -- grosor de los segmentos
        comboSpacing = 3,
        comboOffset = 3,            -- distancia a las barras
        comboColor = "gradient",    -- gradient | class | custom
        comboCustomColor = { 1.00, 0.82, 0.20 },
        comboFull = true,           -- color especial con 5 puntos
        comboFullColor = { 0.95, 0.22, 0.15 },
        comboEmpty = true,          -- mostrar los huecos vacíos
        comboAlways = false,        -- ver los huecos aunque no haya puntos (con un enemigo)
        comboPop = true,            -- animación al ganar un punto
        fade = false,
    }
    for key, value in pairs(overrides) do d[key] = value end
    return d
end

local UF = ns.NewModule("UnitFrames", "Marcos de unidad", {
    style = { gloss = true, background = { 0.06, 0.06, 0.07 }, border = 1, smooth = true },
    units = {
        player = UnitDefaults({ portrait = "3d" }),
        target = UnitDefaults({ portrait = "3d", castbar = true, combo = true }),
        targettarget = UnitDefaults({ width = 130, height = 22, power = 0, healthText = "none", showLevel = false, fontSize = 10 }),
        pet = UnitDefaults({ width = 130, height = 22, power = 4, healthText = "none", showLevel = false, fontSize = 10 }),
        focus = UnitDefaults({ width = 180, height = 30, power = 6, fontSize = 11, castbar = true, castHeight = 14 }),
        focustarget = UnitDefaults({ width = 120, height = 20, power = 0, healthText = "none", showLevel = false, fontSize = 10 }),
    },
    positions = {},
})
ns.UnitFrames = UF
UF.frames = {}
UF.UnitDefaults = UnitDefaults   -- para otros módulos (p. ej. Blazzito_Group)

-- Ganchos para otros módulos (p. ej. Blazzito_Auras):
--   layout(frame, cfg)  tras colocar el marco según su configuración
--   update(frame, tick) tras repintarlo entero
--   preview(active)     al entrar o salir de la vista previa
UF.hooks = { layout = {}, update = {}, preview = {} }

function UF.RunHooks(kind, ...)
    for _, fn in ipairs(UF.hooks[kind]) do fn(...) end
end

UF.UNITS = { "player", "target", "targettarget", "pet", "focus", "focustarget" }

-- Rasgos fijos de cada marco. mirrored: el objetivo es el espejo del jugador
-- (retrato a la derecha e inclinación al revés). combo: puede mostrar puntos de
-- combo. castbarBlizzard: barra de Blizzard que se silencia si se usa la nuestra.
-- poll: no tiene eventos propios (se repinta unas veces por segundo).
-- needs: solo existe si también está activo ese otro marco.
-- pos: { pivote, "CENTER", x, y } con pivotes enfrentados para que cada pareja
-- sea simétrica respecto al centro.
UF.INFO = {
    player       = { label = "Jugador", combo = true, castbarBlizzard = { "PlayerCastingBarFrame", "CastingBarFrame" }, pos = { "RIGHT", "CENTER", -120, -208 } },
    target       = { label = "Objetivo", mirrored = true, combo = true, pos = { "LEFT", "CENTER", 120, -208 } },
    targettarget = { label = "Obj. del objetivo", mirrored = true, poll = true, needs = "target", pos = { "LEFT", "CENTER", 400, -216 } },
    pet          = { label = "Mascota", castbarBlizzard = { "PetCastingBarFrame" }, pos = { "RIGHT", "CENTER", -400, -216 } },
    focus        = { label = "Foco", pos = { "RIGHT", "CENTER", -330, -120 } },
    focustarget  = { label = "Obj. del foco", mirrored = true, poll = true, needs = "focus", pos = { "LEFT", "CENTER", -310, -120 } },
}

-- Un marco puede traer su propia configuración y rasgos (p. ej. los de grupo
-- y banda de Blazzito_Group); si no, se usan los de su unidad.
function UF.Cfg(frame)
    return frame.cfg or UF.db.units[frame.buiUnit]
end

function UF.Info(frame)
    return frame.info or UF.INFO[frame.buiUnit]
end

function UF.UnitOf(frame)
    return frame.previewUnit or frame.buiUnit
end

-- Eventos de unidad y qué parte del marco repintan.
local UNIT_EVENTS = {
    UNIT_HEALTH = "health",
    UNIT_MAXHEALTH = "health",
    UNIT_POWER_UPDATE = "power",
    UNIT_POWER_FREQUENT = "power",
    UNIT_MAXPOWER = "power",
    UNIT_DISPLAYPOWER = "power",
    -- Llega cuando los datos de la unidad (nombre, clase) ya están: al entrar en
    -- grupo o recargar, el marco pudo pintarse antes, gris y sin nombre. Todo.
    UNIT_NAME_UPDATE = "all",
    UNIT_LEVEL = "name",
    UNIT_CLASSIFICATION_CHANGED = "name",
    UNIT_FACTION = "color",
    UNIT_FLAGS = "color",
    UNIT_HEAL_PREDICTION = "predict",
    UNIT_ABSORB_AMOUNT_CHANGED = "predict",
    UNIT_PORTRAIT_UPDATE = "portrait",
    UNIT_MODEL_CHANGED = "portrait",
    UNIT_CONNECTION = "all",
}

local CAST_EVENTS = {
    UNIT_SPELLCAST_START = "start",
    UNIT_SPELLCAST_DELAYED = "start",
    UNIT_SPELLCAST_CHANNEL_START = "channel",
    UNIT_SPELLCAST_CHANNEL_UPDATE = "channel",
    UNIT_SPELLCAST_STOP = "stop",
    UNIT_SPELLCAST_FAILED = "stop",
    UNIT_SPELLCAST_INTERRUPTED = "stop",
    UNIT_SPELLCAST_CHANNEL_STOP = "stop",
}

-- Algunos eventos no existen en todos los clientes; registrarlos así no da error.
local function TryRegisterUnitEvent(frame, event, unit)
    pcall(frame.RegisterUnitEvent, frame, event, unit)
end

local function OnEnter(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetUnit(UF.UnitOf(self))
    GameTooltip:Show()
end

local function OnLeave()
    GameTooltip:Hide()
end

-- opts (opcional, para otros módulos): cfg e info propios, parent (dónde va el
-- contenedor), name (nombre global) y keep = false para no contarlo entre los
-- marcos principales (UF.frames).
local function Spawn(unit, opts)
    opts = opts or {}
    local info = opts.info or UF.INFO[unit]
    local name = opts.name or ("BlazzitoUI_" .. unit:gsub("^%l", string.upper))
    -- El contenedor no es seguro: su transparencia atenúa el marco sin tocarlo.
    local wrapper = CreateFrame("Frame", nil, opts.parent or UIParent)
    wrapper:SetAllPoints(opts.parent or UIParent)
    local ok, frame = pcall(CreateFrame, "Button", name, wrapper, "SecureUnitButtonTemplate, PingableUnitFrameTemplate")
    if not ok then
        frame = CreateFrame("Button", name, wrapper, "SecureUnitButtonTemplate")
    end
    -- La unidad va en el atributo y en buiUnit, nunca en frame.unit: Blizzard
    -- lee ese campo en su código seguro y un valor puesto por un addon lo contamina.
    frame.buiUnit = unit
    frame.wrapper = wrapper
    frame.cfg, frame.info = opts.cfg, opts.info
    frame:SetAttribute("unit", unit)
    frame:SetAttribute("*type1", "target")
    frame:RegisterForClicks("AnyUp")
    ns.AttachUnitMenu(frame)
    frame:HookScript("OnEnter", OnEnter)
    frame:HookScript("OnLeave", OnLeave)
    if type(ClickCastFrames) ~= "table" then ClickCastFrames = {} end
    ClickCastFrames[frame] = true

    UF.Build(frame, info)
    UF.ApplyLayout(frame)

    local driver = CreateFrame("Frame")
    frame.driver = driver
    if info.poll then
        -- No tiene eventos propios: se repinta unas veces por segundo mientras se ve.
        local elapsed = 0
        driver:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.2 then return end
            elapsed = 0
            UF.UpdateAll(frame, true)
        end)
        driver:Hide()
        frame:HookScript("OnShow", function() driver:Show() end)
        frame:HookScript("OnHide", function() driver:Hide() end)
    else
        for event in pairs(UNIT_EVENTS) do TryRegisterUnitEvent(driver, event, unit) end
        for event in pairs(CAST_EVENTS) do TryRegisterUnitEvent(driver, event, unit) end
        driver:SetScript("OnEvent", function(_, event)
            local part = UNIT_EVENTS[event]
            if part == "health" then
                UF.UpdateHealth(frame)
            elseif part == "power" then
                UF.UpdatePower(frame)
            elseif part == "name" then
                UF.UpdateName(frame)
            elseif part == "color" then
                UF.UpdateColor(frame)
                UF.UpdateHealth(frame)
            elseif part == "predict" then
                UF.UpdatePrediction(frame)
            elseif part == "portrait" then
                UF.UpdatePortrait(frame, true)
            elseif part == "all" then
                UF.UpdateAll(frame)
            elseif CAST_EVENTS[event] then
                UF.UpdateCast(frame, CAST_EVENTS[event])
            end
        end)
    end

    frame:HookScript("OnShow", function(self) UF.UpdateAll(self) end)
    -- Los modelos 3D se vacían al ocultarse: al volver se cargan de nuevo.
    frame:HookScript("OnHide", function(self) self.Portrait.guid = nil end)
    RegisterUnitWatch(frame)
    if opts.keep ~= false then UF.frames[unit] = frame end
    return frame
end
UF.Spawn = Spawn

---------------------------------------------------------------------------
-- Aplicar cambios de configuración (los tamaños esperan a salir de combate)
---------------------------------------------------------------------------
function UF.ApplyUnit(unit)
    local frame = UF.frames[unit]
    if not frame then return end
    ns.AfterCombat("UFLayout" .. unit, function()
        UF.ApplyLayout(frame)
        if frame:IsShown() then UF.UpdateAll(frame) end
    end)
    if unit == "player" then UF.UpdateFade() end
end

function UF.ApplyAll()
    for _, unit in ipairs(UF.UNITS) do UF.ApplyUnit(unit) end
end

function UF.RefreshAll()
    for _, frame in pairs(UF.frames) do
        if frame:IsShown() then UF.UpdateAll(frame) end
    end
end

---------------------------------------------------------------------------
-- Vista previa: todos los marcos visibles con tus datos, mientras se mueven
-- los marcos o está abierta la configuración. Solo fuera de combate.
---------------------------------------------------------------------------
local previewReasons = {}

local function ApplyPreview()
    local active = next(previewReasons) ~= nil
    UF.previewActive = active
    for _, frame in pairs(UF.frames) do
        if active and not frame.previewUnit then
            UnregisterUnitWatch(frame)
            frame.previewUnit = "player"
            frame:Show()
            UF.UpdateAll(frame)
        elseif not active and frame.previewUnit then
            frame.previewUnit = nil
            RegisterUnitWatch(frame)
            if frame:IsShown() then UF.UpdateAll(frame) end
        end
    end
    UF.UpdateFade()
    UF.RunHooks("preview", active)
end

function UF.SetPreview(reason, on)
    previewReasons[reason] = on or nil
    ns.AfterCombat("UFPreview", ApplyPreview)
end

---------------------------------------------------------------------------
-- Atenuar fuera de combate. Jugador y mascota además vuelven a verse al
-- tener un objetivo.
---------------------------------------------------------------------------
local inCombat = false

function UF.UpdateFade()
    local hasTarget = UnitExists("target")
    for unit, frame in pairs(UF.frames) do
        local cfg = UF.db.units[unit]
        local ownTarget = (unit == "player" or unit == "pet") and hasTarget
        local faded = cfg.fade and not inCombat and not ownTarget and not UF.previewActive
        frame.wrapper:SetAlpha(faded and 0.35 or 1)
    end
end

---------------------------------------------------------------------------
-- Activación
---------------------------------------------------------------------------
local BLIZZARD_FRAMES = {
    player = { "PlayerFrame" },
    target = { "TargetFrame", "ComboFrame" },
    pet = { "PetFrame" },
    focus = { "FocusFrame" },   -- su objetivo del foco (FocusFrameToT) cuelga de él
}
-- Con el estilo de mando, el botón Y abre el menú del objetivo con el marco de
-- Blizzard como dueño: ese se queda visible a alfa 0 y sin ratón (Blizzard.lua).
local BLIZZARD_PAD = { TargetFrame = { padVisible = true, noMouse = true } }

function UF:OnEnable()
    local db = self.db
    local moverHooks = {
        onUnlock = function() UF.SetPreview("movers", true) end,
        onLock = function() UF.SetPreview("movers", false) end,
    }
    for _, unit in ipairs(UF.UNITS) do
        -- El objetivo del objetivo (y el del foco) cuelga del marco de Blizzard
        -- de su unidad: solo se usa junto con el nuestro.
        local needs = UF.INFO[unit].needs
        local wanted = db.units[unit].enabled and (not needs or db.units[needs].enabled)
        if wanted then
            local frame = Spawn(unit)
            ns.Movers.Register(frame, unit, UF.INFO[unit].label, UF.INFO[unit].pos, db.positions, {
                onUnlock = moverHooks.onUnlock, onLock = moverHooks.onLock,
                -- Tamaño desde el modo mover (casillas y esquina): ancho y alto de las barras.
                getSize = function() return db.units[unit].width, db.units[unit].height end,
                setSize = function(w, h)
                    db.units[unit].width = math.max(80, math.min(400, w))
                    db.units[unit].height = math.max(14, math.min(80, h))
                    UF.ApplyUnit(unit)
                end,
            })
            for _, blizzard in ipairs(BLIZZARD_FRAMES[unit] or {}) do
                ns.HideBlizzardFrame(blizzard, BLIZZARD_PAD[blizzard])
            end
            -- Con nuestra barra de lanzamiento, la de Blizzard sobra (cambiarlo pide recargar).
            if db.units[unit].castbar then
                for _, blizzard in ipairs(UF.INFO[unit].castbarBlizzard or {}) do
                    ns.SilenceBlizzardFrame(blizzard)
                end
            end
        end
    end

    ns.On("PLAYER_ENTERING_WORLD", UF.RefreshAll)
    ns.On("PLAYER_TARGET_CHANGED", function()
        for _, unit in ipairs({ "target", "targettarget" }) do
            local frame = UF.frames[unit]
            if frame and frame:IsShown() then UF.UpdateAll(frame) end
        end
        -- Los puntos son sobre el objetivo: los del jugador cambian con él.
        local player = UF.frames.player
        if player and player.Combo then UF.UpdateCombo(player) end
        UF.UpdateFade()
    end)
    pcall(ns.On, "PLAYER_FOCUS_CHANGED", function()
        for _, unit in ipairs({ "focus", "focustarget" }) do
            local frame = UF.frames[unit]
            if frame and frame:IsShown() then UF.UpdateAll(frame) end
        end
    end)
    ns.On("RAID_TARGET_UPDATE", function()
        for _, frame in pairs(UF.frames) do UF.UpdateRaidIcon(frame) end
    end)
    ns.On("UNIT_PET", function(_, owner)
        local frame = UF.frames.pet
        if owner == "player" and frame and frame:IsShown() then UF.UpdateAll(frame) end
    end)
    ns.On("PLAYER_REGEN_DISABLED", function()
        inCombat = true
        -- Este evento llega justo antes del bloqueo de combate: última ocasión
        -- para quitar la vista previa de los marcos seguros. Se aplica siempre,
        -- aunque otro oyente ya haya retirado su motivo de vista previa.
        wipe(previewReasons)
        ApplyPreview()
        UF.UpdateFade()
    end)
    ns.On("PLAYER_REGEN_ENABLED", function()
        inCombat = false
        UF.UpdateFade()
    end)

    -- Los puntos de combo (del jugador sobre su objetivo) se pueden ver encima
    -- del marco del jugador, del objetivo o de ambos.
    local comboDriver = CreateFrame("Frame")
    TryRegisterUnitEvent(comboDriver, "UNIT_POWER_UPDATE", "player")
    pcall(comboDriver.RegisterEvent, comboDriver, "PLAYER_COMBO_POINTS")
    -- El druida entra y sale de la forma de gato: los huecos aparecen y se van.
    TryRegisterUnitEvent(comboDriver, "UNIT_DISPLAYPOWER", "player")
    pcall(comboDriver.RegisterEvent, comboDriver, "UPDATE_SHAPESHIFT_FORM")
    comboDriver:SetScript("OnEvent", function()
        for _, frame in pairs(UF.frames) do
            if frame.Combo then UF.UpdateCombo(frame) end
        end
    end)

    ns.Config.OnOpenChanged(function(open) UF.SetPreview("config", open) end)
    UF.UpdateFade()
end
