-- Ciclo de vida de las placas: cuándo una placa de Blizzard pasa a ser
-- nuestra, cuándo se devuelve, y los eventos que las mantienen al día.
--
-- Forever recicla dos cosas por separado: la placa base (una por unidad
-- visible) y su UnitFrame (de un "pool": al quitar la placa, Blizzard suelta
-- el UnitFrame y base.UnitFrame queda en nil). Por eso cada placa nuestra
-- recuerda el UnitFrame que ocultó (p.uf) y se lo devuelve al soltarla.
local ns = BlazzitoUI
if not (ns and ns.Nameplates and ns.Nameplates.Build) then return end

local NP, M = ns.Nameplates, ns.Media
local Readable = M.Readable

NP.plates = {}   -- placa base de Blizzard -> nuestra placa
NP.byUnit = {}   -- unidad (nameplateN) -> nuestra placa activa
NP.tracked = {}  -- unidades con placa visible (nuestras o no)

---------------------------------------------------------------------------
-- El UnitFrame de Blizzard: invisible mientras es nuestro (alfa 0 con un
-- gancho a SetAlpha). Sus iconos de auras, aunque invisibles, capturan el
-- ratón y sacan su descripción: se les quita el ratón solo mientras tanto,
-- con un gancho posterior a RefreshList (nunca SetParent ni Hide).
---------------------------------------------------------------------------
local owned = setmetatable({}, { __mode = "k" })
local alphaHooked = setmetatable({}, { __mode = "k" })
local aurasHooked = setmetatable({}, { __mode = "k" })
local barHooked = setmetatable({}, { __mode = "k" })
local ufUnit = setmetatable({}, { __mode = "k" })    -- UnitFrame -> unidad que muestra

local function SyncAuraMouse(auras, enabled)
    local pool = type(auras) == "table" and auras.auraItemFramePool
    if not (type(pool) == "table" and pool.EnumerateActive) then return end
    for item in pool:EnumerateActive() do
        if item.EnableMouse then item:EnableMouse(enabled) end
    end
end

local function Hold(uf)
    owned[uf] = true
    uf:SetAlpha(0)
    if not alphaHooked[uf] then
        alphaHooked[uf] = true
        local busy = false
        hooksecurefunc(uf, "SetAlpha", function(self)
            if busy or not owned[self] then return end
            busy = true
            self:SetAlpha(0)
            busy = false
        end)
    end
    local auras = uf.AurasFrame
    if type(auras) == "table" and type(auras.RefreshList) == "function" and not aurasHooked[auras] then
        aurasHooked[auras] = true
        hooksecurefunc(auras, "RefreshList", function(self) SyncAuraMouse(self, not owned[uf]) end)
    end
    SyncAuraMouse(auras, false)
end

local function Unhold(uf)
    if not owned[uf] then return end
    owned[uf] = nil
    uf:SetAlpha(1)
    SyncAuraMouse(uf.AurasFrame, true)
end

NP.IsHeld = function(uf) return owned[uf] == true end

---------------------------------------------------------------------------
-- Tomar y soltar
---------------------------------------------------------------------------
local UNIT_EVENTS = {
    UNIT_HEALTH = "health", UNIT_MAXHEALTH = "health",
    UNIT_NAME_UPDATE = "name", UNIT_LEVEL = "level", UNIT_CLASSIFICATION_CHANGED = "level",
    UNIT_THREAT_SITUATION_UPDATE = "threat", UNIT_THREAT_LIST_UPDATE = "threat",
    UNIT_TARGET = "castTarget", UNIT_AURA = "auras",
    UNIT_SPELLCAST_START = "start", UNIT_SPELLCAST_DELAYED = "start",
    UNIT_SPELLCAST_CHANNEL_START = "channel", UNIT_SPELLCAST_CHANNEL_UPDATE = "channel",
    UNIT_SPELLCAST_STOP = "stop", UNIT_SPELLCAST_FAILED = "stop", UNIT_SPELLCAST_CHANNEL_STOP = "stop",
    UNIT_SPELLCAST_INTERRUPTED = "interrupted",
    UNIT_SPELLCAST_INTERRUPTIBLE = "unlock", UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "lock",
}

local function OnUnitEvent(driver, event)
    local p = driver.plate
    if not p.unit then return end
    local part = UNIT_EVENTS[event]
    if p.kind == "friend" then
        if part == "name" then NP.UpdateName(p) end
        return
    end
    if part == "health" then
        NP.UpdateHealth(p)
        if NP.db.execute > 0 then NP.UpdateColor(p) end
    elseif part == "name" then
        NP.UpdateName(p)
    elseif part == "level" then
        NP.UpdateLevel(p)
    elseif part == "threat" then
        NP.UpdateThreat(p)
        NP.UpdateColor(p)
    elseif part == "castTarget" then
        if p.cast:IsShown() and not p.cast.holdUntil then NP.UpdateCastTarget(p) end
    elseif part == "auras" then
        NP.UpdateDebuffs(p)
    else
        NP.UpdateCast(p, part)
    end
end

-- Los aliados solo necesitan el nombre (en las ciudades hay muchos).
local function Bind(p, unit, kind)
    local driver = p.driver
    if not driver then
        driver = CreateFrame("Frame")
        driver.plate = p
        driver:SetScript("OnEvent", OnUnitEvent)
        p.driver = driver
    end
    driver:UnregisterAllEvents()
    if unit and kind == "friend" then
        pcall(driver.RegisterUnitEvent, driver, "UNIT_NAME_UPDATE", unit)
    elseif unit then
        for event in pairs(UNIT_EVENTS) do pcall(driver.RegisterUnitEvent, driver, event, unit) end
    end
end

local function Release(p)
    if p.uf then Unhold(p.uf) end
    if p.unit and NP.byUnit[p.unit] == p then NP.byUnit[p.unit] = nil end
    Bind(p, nil)
    NP.DetachDebuffs(p)
    p.cast.holdUntil = nil
    p.cast:Hide()
    p:Hide()
    p.unit, p.uf, p.inRange, p.threatStatus = nil, nil, nil, nil
end

local function Acquire(base, unit, kind)
    local p = NP.plates[base]
    if not p then
        p = NP.Build(base)
        NP.plates[base] = p
    end
    if p.kind ~= kind then
        p.kind = kind
        NP.Apply(p)
    end
    local other = NP.byUnit[unit]
    if other and other ~= p then Release(other) end
    if p.unit and p.unit ~= unit and NP.byUnit[p.unit] == p then NP.byUnit[p.unit] = nil end
    local uf = base.UnitFrame
    if p.uf and p.uf ~= uf then Unhold(p.uf) end
    p.unit, p.uf = unit, uf
    if uf then Hold(uf) end
    NP.byUnit[unit] = p
    Bind(p, unit, kind)
    if kind == "enemy" then NP.AttachDebuffs(p, unit) else NP.DetachDebuffs(p) end
    p:Show()
    NP.UpdateAll(p)
end

-- Si Blizzard muestra u oculta la barra de vida de su placa (p. ej. pasa a
-- "solo nombre"), se vuelve a decidir.
local function WatchHealthBar(uf)
    local bar = NP.BlizzardHealthBar(uf)
    if not bar or barHooked[bar] then return end
    barHooked[bar] = true
    local function Recheck()
        local unit = ufUnit[uf]
        if unit and NP.tracked[unit] then NP.Evaluate(unit) end
    end
    hooksecurefunc(bar, "Show", Recheck)
    hooksecurefunc(bar, "Hide", Recheck)
end

-- Decide si la placa de esta unidad es nuestra y actúa en consecuencia.
function NP.Evaluate(unit)
    local base = C_NamePlate.GetNamePlateForUnit(unit)
    local p = NP.byUnit[unit]
    if not base or (base.IsForbidden and base:IsForbidden()) then
        if p then Release(p) end
        return
    end
    local uf = base.UnitFrame
    if uf then
        ufUnit[uf] = unit
        WatchHealthBar(uf)
    end
    local kind = NP.Kind(unit, uf)
    if kind then
        if p and p.base == base and p.uf == uf and p.kind == kind then
            NP.UpdateColor(p)    -- ya es nuestra: quizá cambió de color
            return
        end
        if p and p.base ~= base then Release(p) end
        Acquire(base, unit, kind)
    elseif p then
        Release(p)
    end
end

local function OnAdded(unit)
    NP.tracked[unit] = true
    NP.Evaluate(unit)
end

local function OnRemoved(unit)
    NP.tracked[unit] = nil
    local p = NP.byUnit[unit]
    if p then Release(p) end
end

---------------------------------------------------------------------------
-- Para Blazzito_ThreatPlate
---------------------------------------------------------------------------
-- Dónde colocar su insignia (si la usa).
function NP.AnchorFor(base)
    local p = NP.plates[base]
    if p and p.unit and p:IsShown() then return p.block end
end

-- Si el aggro ya va dentro de nuestra placa, la insignia aparte sobra.
function NP.HandlesThreat(base)
    local p = NP.active and NP.db.threat and NP.plates[base]
    return (p and p.unit and p.kind == "enemy" and p:IsShown()) and true or false
end

---------------------------------------------------------------------------
-- Área de clic: el cliente usa una sola medida para todas las placas
-- (C_NamePlate.SetNamePlateSize). Se pone la de nuestra placa (barra y
-- nombre), fuera de combate. Blizzard la vuelve a fijar al cambiar sus
-- opciones: un gancho posterior guarda la suya y repone la nuestra. Al
-- desactivarlo se devuelve la de Blizzard.
---------------------------------------------------------------------------
local blizzardSize

function NP.ClickSize()
    local db = NP.db
    local height = db.height + (db.showName and (db.fontSize + 5) or 0)
    return db.width * db.scale, height * db.scale
end

function NP.ApplyClickArea()
    if not (C_NamePlate and C_NamePlate.SetNamePlateSize and C_NamePlate.GetNamePlateSize) then return end
    ns.AfterCombat("nameplates-click", function()
        if not blizzardSize then
            local w, h = C_NamePlate.GetNamePlateSize()
            if w and h then blizzardSize = { w, h } end
        end
        local w, h
        if NP.active and NP.db.clickArea then
            w, h = NP.ClickSize()
        elseif blizzardSize then
            w, h = blizzardSize[1], blizzardSize[2]
        end
        if w and h then
            NP.clickApplied = pcall(C_NamePlate.SetNamePlateSize, w, h) and { w, h } or false
        end
    end)
end

local function HookBlizzardSize()
    local driver = NamePlateDriverFrame
    if not (driver and type(driver.UpdateNamePlateSize) == "function") then return end
    hooksecurefunc(driver, "UpdateNamePlateSize", function()
        local w, h = C_NamePlate.GetNamePlateSize()
        if w and h then blizzardSize = { w, h } end
        NP.ApplyClickArea()
    end)
end

---------------------------------------------------------------------------
-- Ajustes en vivo
---------------------------------------------------------------------------
function NP.ApplyAll()
    for _, p in pairs(NP.plates) do
        NP.Apply(p)
        if p.unit and p:IsShown() then NP.UpdateAll(p) end
    end
    if NP.previews then
        for variant, p in pairs(NP.previews) do NP.PaintPreview(p, variant) end
    end
    -- Aliados que dejan de serlo (o vuelven) al cambiar la opción.
    for unit in pairs(NP.tracked) do NP.Evaluate(unit) end
    NP.ApplyClickArea()
    if ns.ThreatPlate and ns.ThreatPlate.RestyleAll and ns.ThreatPlate.db then ns.ThreatPlate.RestyleAll() end
end

local function ForEach(fn)
    for _, p in pairs(NP.byUnit) do fn(p) end
end

---------------------------------------------------------------------------
-- /bui placas: qué placas hay y por qué son (o no) nuestras
---------------------------------------------------------------------------
function NP.Diagnose()
    ns.Print("placas de nombre:")
    print(string.format("  módulo activo: %s · motor de auras: %s · en combate: %s",
        tostring(NP.active == true), tostring(NP.AuraEngine()), tostring(NP.inCombat)))
    if C_NamePlate.GetNamePlateSize then
        local w, h = C_NamePlate.GetNamePlateSize()
        local applied = NP.clickApplied
        print(string.format("  área de clic: %s x %s · Blizzard: %s · aplicada: %s", tostring(w), tostring(h),
            blizzardSize and string.format("%s x %s", tostring(blizzardSize[1]), tostring(blizzardSize[2])) or "?",
            applied and "sí" or (applied == false and "falló" or "no")))
    end
    local Q, items, npcs = NP.Quest, 0, 0
    for _ in pairs(Q.items) do items = items + 1 end
    for _ in pairs(BlazzitoUIDB and BlazzitoUIDB.npQuestDrops or {}) do npcs = npcs + 1 end
    print(string.format("  misiones: %d objetivos de matar · %d objetos pendientes · %d PNJ aprendidos que sueltan objetos",
        #Q.kills, items, npcs))
    local count = 0
    for unit in pairs(NP.tracked) do
        count = count + 1
        local base = C_NamePlate.GetNamePlateForUnit(unit)
        local p = NP.byUnit[unit]
        local name = Readable(UnitName(unit)) or "?"
        local kind, why
        if not base then why = "sin placa"
        elseif base.IsForbidden and base:IsForbidden() then why = "prohibida"
        else kind, why = NP.Kind(unit, base.UnitFrame) end
        print(string.format("  %s (%s): %s%s · alcance %s · aggro %s", unit, name,
            p and ("nuestra, " .. (kind == "friend" and "aliado" or "enemigo")) or "de Blizzard", why and (" · " .. why) or "",
            tostring(p and p.inRange), tostring(p and p.threatStatus)))
    end
    if count == 0 then print("  no hay placas en pantalla") end
end

ns.RegisterCommand("placas", function(arg)
    if arg == "misiones" then NP.Quest.Diagnose() else NP.Diagnose() end
end, "Diagnóstico de las placas de nombre")

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function NP:OnEnable()
    local events = CreateFrame("Frame")
    NP.manager = events
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED",
                             "RAID_TARGET_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                             "UNIT_FACTION", "UNIT_FLAGS", "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED",
                             "UNIT_TARGET", "UNIT_PET", "LOOT_READY", "LOOT_OPENED", "CHAT_MSG_LOOT", "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            OnAdded(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            OnRemoved(unit)
        elseif event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
            -- Un enemigo que pasa a aliado (o al revés): duelo, misión...
            if unit and NP.tracked[unit] then NP.Evaluate(unit) end
        elseif event == "UNIT_TARGET" or event == "UNIT_PET" then
            -- Tu mascota cambia de objetivo (o aparece / se va).
            if unit == "pet" or unit == "player" then ForEach(NP.UpdatePet) end
        elseif event == "PLAYER_TARGET_CHANGED" then
            ForEach(NP.UpdateAlpha)
        elseif event == "RAID_TARGET_UPDATE" then
            ForEach(NP.UpdateRaid)
        elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
            NP.Quest.Scan()
            ForEach(NP.UpdateQuest)
        elseif event == "CHAT_MSG_LOOT" then
            if NP.Quest.LearnFromChat(unit) then ForEach(NP.UpdateQuest) end
        elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
            -- Aprende qué PNJ sueltan los objetos de tus misiones.
            if NP.Quest.Learn() then ForEach(NP.UpdateQuest) end
        elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
            NP.ApplyAll()
        else
            NP.inCombat = event == "PLAYER_REGEN_DISABLED"
            ForEach(function(p)
                NP.UpdateThreat(p)
                NP.UpdateColor(p)
            end)
        end
    end)

    -- Alcance (y aggro en combate, por si algún evento no llega): 5 veces
    -- por segundo, solo en nuestras placas.
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.2 then return end
        elapsed = 0
        for _, p in pairs(NP.byUnit) do
            if p.kind == "enemy" then
                NP.UpdateRange(p)
                if NP.inCombat then NP.UpdateThreat(p) end
            end
        end
    end)

    HookBlizzardSize()
    NP.ApplyClickArea()
    -- Registro de misiones ya cargado (p. ej. tras /reload).
    pcall(NP.Quest.Scan)

    -- Placas que ya estaban en pantalla al cargar (p. ej. tras /reload).
    if C_NamePlate.GetNamePlates then
        for _, base in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = base.namePlateUnitToken or base.unitToken or (base.GetUnit and base:GetUnit())
            if unit then OnAdded(unit) end
        end
    end
end
