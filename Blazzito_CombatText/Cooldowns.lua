-- Blazzito_CombatText · Cooldowns.lua
-- Avisos de enfriamiento: cuando lanzas un hechizo con enfriamiento largo, se
-- vigila y, al terminar, sale "Listo: <hechizo>" con su icono en los avisos.
--
-- Si el cliente da el enfriamiento legible se usa el tiempo exacto. Si lo da
-- en secreto (puede pasar en combate), se usa el enfriamiento base del hechizo
-- y, al llegar la hora, se vuelve a comprobar por si aún no estaba listo.
local ns = BlazzitoUI
if not (ns and ns.CombatText) then return end

local CT = ns.CombatText
local M = ns.Media
local Readable = M.Readable

CT.watching = {}    -- spellID -> momento (GetTime) en que debería estar listo

-- Fin del enfriamiento: tiempo exacto, o nil si no está en enfriamiento o es secreto.
-- Segundo valor: true si el dato era secreto.
local function CooldownEnd(spellID)
    local start, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then start, duration = info.startTime, info.duration end
    elseif GetSpellCooldown then
        start, duration = GetSpellCooldown(spellID)
    end
    start, duration = Readable(start), Readable(duration)
    if start == nil or duration == nil then return nil, true end
    if start <= 0 or duration <= 0 then return nil, false end
    return start + duration, false
end

local function BaseCooldown(spellID)
    if not GetSpellBaseCooldown then return nil end
    local ok, ms = pcall(GetSpellBaseCooldown, spellID)
    ms = ok and Readable(ms)
    if type(ms) == "number" and ms > 0 then return ms / 1000 end
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and (GetSpellInfo(spellID))
end

-- Solo el icono (GetSpellTexture devuelve también el original: un segundo
-- valor que, al final de una llamada, se colaría como otro argumento).
local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return (C_Spell.GetSpellTexture(spellID)) end
    return GetSpellTexture and (GetSpellTexture(spellID))
end

-- Tras lanzar un hechizo: ¿tiene un enfriamiento que merezca aviso?
local function Watch(spellID)
    local finish, secret = CooldownEnd(spellID)
    local now = GetTime()
    if finish then
        if finish - now >= CT.db.cooldownMin then CT.watching[spellID] = finish end
    elseif secret then
        local base = BaseCooldown(spellID)
        if base and base >= CT.db.cooldownMin then CT.watching[spellID] = now + base end
    end
end

local function Notify(spellID)
    local cat = CT.db.categories.cooldowns
    if not cat.on then return end
    CT.Emit(cat.area, ns.Translate("Listo: %s"), SpellName(spellID), nil, cat.color, false, SpellIcon(spellID))
end

-- Revisa los vigilados (10 veces por segundo).
function CT.CheckCooldowns()
    local now = GetTime()
    for spellID, finish in pairs(CT.watching) do
        if now >= finish - 0.05 then
            local realFinish = CooldownEnd(spellID)
            if realFinish and realFinish > now + 0.2 then
                -- Aún no estaba listo (o se reinició): se vuelve a esperar.
                CT.watching[spellID] = realFinish
            else
                CT.watching[spellID] = nil
                Notify(spellID)
            end
        end
    end
end

function CT.StartCooldowns()
    local events = CreateFrame("Frame")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    events:SetScript("OnEvent", function(_, event, _, _, spellID)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            spellID = Readable(spellID)
            if not spellID or not CT.db.categories.cooldowns.on then return end
            -- El enfriamiento empieza justo después del lanzamiento.
            C_Timer.After(0.1, function() Watch(spellID) end)
        else
            -- Algo cambió enfriamientos (reinicios, reducciones): se reajustan los vigilados.
            for id in pairs(CT.watching) do
                local finish = CooldownEnd(id)
                if finish then CT.watching[id] = finish end
            end
        end
    end)
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        if next(CT.watching) then CT.CheckCooldowns() end
    end)
end
