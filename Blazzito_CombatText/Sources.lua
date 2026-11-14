-- Blazzito_CombatText · Sources.lua
-- De dónde salen los mensajes. En este cliente el registro de combate está
-- protegido (un addon no puede escucharlo directamente), así que:
--  1. Lo que recibes (daño, curas, esquivas, beneficios, procs, reputación...):
--     el texto de combate del cliente (COMBAT_TEXT_UPDATE). Fiable.
--  2. Lo que haces: se escucha el registro de combate de Blizzard cuando él lo
--     procesa (como hacen otros addons de Forever). Si en esta sesión no llega
--     nada por ahí, respaldo: el daño que recibe tu objetivo (UNIT_COMBAT).
--  3. Botín y dinero: los mensajes del chat.
-- Los valores pueden ser secretos: solo se muestran, nunca se comparan.
local ns = BlazzitoUI
if not (ns and ns.CombatText) then return end

local CT = ns.CombatText
local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret

CT.stats = { combatText = 0, combatLog = 0, combatLogHooked = false, fallback = 0, chat = 0, guessed = 0, ignored = 0 }

-- Dibujos propios para los ataques básicos (blancos con borde: se tiñen del
-- color del número).
local MEDIA = "Interface\\AddOns\\Blazzito_CombatText\\Media\\"
CT.GLYPH = { melee = MEDIA .. "glyph_melee", ranged = MEDIA .. "glyph_ranged", pet = MEDIA .. "glyph_pet" }
CT.IS_GLYPH = {}
for _, path in pairs(CT.GLYPH) do CT.IS_GLYPH[path] = true end

-- Disparo automático, disparar (varita), lanzar: ataques básicos a distancia.
local RANGED_AUTO = { [75] = true, [5019] = true, [2764] = true, [3018] = true }

---------------------------------------------------------------------------
-- Qué causó un golpe cuando el juego no lo dice (respaldo por tu objetivo):
-- lo último que hiciste. Un hechizo lanzado hace menos de 1,2 s, o tu último
-- golpe automático (cuerpo a cuerpo o a distancia, por PLAYER_SWING).
---------------------------------------------------------------------------
local recent = { spell = nil, spellAt = 0, melee = 0, ranged = 0 }
CT.recent = recent

function CT.NoteCast(spellID)
    spellID = Readable(spellID)
    if type(spellID) ~= "number" then return end
    local now = GetTime()
    if RANGED_AUTO[spellID] then recent.ranged = now
    else recent.spell, recent.spellAt = spellID, now end
end

function CT.NoteSwing(swingType)
    local now = GetTime()
    local ranged = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.Ranged or 2
    if Readable(swingType) == ranged then recent.ranged = now else recent.melee = now end
end

-- Devuelve el icono y una clave para agrupar.
function CT.GuessSource()
    local now = GetTime()
    local spellAge = recent.spell and now - recent.spellAt or 99
    local rangedAge, meleeAge = now - recent.ranged, now - recent.melee
    if spellAge < 1.2 and spellAge <= math.min(rangedAge, meleeAge) + 0.3 then
        local id = recent.spell
        recent.spell = nil          -- un hechizo, un golpe
        local okN, name = pcall(function() return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id) end)
        return CT.SpellIcon(id), "s" .. id, okN and Readable(name) or nil
    end
    -- Un golpe automático, un golpe: así el de otro que llegue justo después
    -- no se te atribuye.
    if rangedAge < 0.8 and rangedAge <= meleeAge then recent.ranged = 0; return CT.GLYPH.ranged, "ranged" end
    if meleeAge < 0.8 then recent.melee = 0; return CT.GLYPH.melee, "melee" end
    return nil, "target"
end

local function Cat(name)
    local cat = CT.db.categories[name]
    if cat and cat.on then return cat end
end

local function Show(name, fmt, a, b, crit, icon, color)
    local cat = Cat(name)
    if not cat then return end
    CT.Emit(cat.area, ns.Translate(fmt), a, b, color or cat.color, crit, icon)
end

---------------------------------------------------------------------------
-- Agrupar golpes: los del mismo origen (un hechizo, el cuerpo a cuerpo, la
-- mascota...) que llegan dentro de una ventana corta salen como uno solo con
-- el total y el número de golpes. Solo se pueden sumar números legibles: los
-- secretos salen uno a uno.
---------------------------------------------------------------------------
local merges = {}

local function Flush(id)
    local m = merges[id]
    merges[id] = nil
    if not m then return end
    local opts = m.damage and CT.Flair and CT.Flair.Options(m.total, m.crits > 0) or nil
    if m.hits > 1 then
        CT.Emit(m.area, m.prefix .. "%s |cffd0d0d0×%d|r", CT.Amount(m.total), m.hits, m.color, m.crits > 0, m.icon, opts)
    else
        CT.Emit(m.area, m.prefix .. "%s", CT.Amount(m.total), nil, m.color, m.crits > 0, m.icon, opts)
    end
end

-- prefix: "-" (daño recibido), "+" (curas) o "" (tu daño). key: qué se agrupa
-- con qué (nil = no agrupar). extra (opcional, tu daño): spellName, spellID,
-- periodic (tic de daño en el tiempo), target (a quién), overkill (exceso).
function CT.EmitAmount(name, prefix, amount, crit, icon, color, key, extra)
    local cat = Cat(name)
    if not cat then return end
    color = color or cat.color
    local side = cat.area == "incoming" and "incoming" or "outgoing"
    local value = Readable(amount)
    local F = CT.Flair
    local damage = F and (name == "outgoingDamage" or name == "petDamage")
    if damage then
        if name == "outgoingDamage" then F.Crit(crit) end
        F.Record(value, extra and extra.spellName, icon)
        if extra and extra.overkill then F.Overkill(extra.overkill, cat.area) end
        -- Daño en el tiempo: el tic sale pequeño y el total al acabar.
        if extra and extra.periodic and F.Tick(extra.spellID or key, extra.target, value, icon, extra.spellName, color, cat.area) then
            CT.Emit(cat.area, prefix .. "%s", CT.Amount(amount), nil, color, false, icon, { scale = 0.75, faded = true })
            return
        end
        if F.Hidden(value) then return end
    end
    if not (key and CT.db.merge[side] and type(value) == "number") then
        CT.Emit(cat.area, prefix .. "%s", CT.Amount(amount), nil, color, crit, icon, damage and F.Options(value, crit) or nil)
        return
    end
    local id = name .. ":" .. key
    local m = merges[id]
    if not m then
        m = { area = cat.area, prefix = prefix, color = color, icon = icon, total = 0, hits = 0, crits = 0, damage = damage }
        merges[id] = m
        C_Timer.After(CT.db.merge.window, function() Flush(id) end)
    end
    m.total = m.total + value
    m.hits = m.hits + 1
    if crit then m.crits = m.crits + 1 end
end

---------------------------------------------------------------------------
-- 1. Texto de combate del cliente (lo que te pasa a ti)
---------------------------------------------------------------------------
local GetEventInfo = (C_CombatText and C_CombatText.GetCurrentEventInfo) or GetCurrentCombatTextEventInfo

-- tipo -> categoría, si es crítico
local DAMAGE = { DAMAGE = false, SPELL_DAMAGE = false, DAMAGE_CRIT = true, SPELL_DAMAGE_CRIT = true }
local HEAL = { HEAL = false, PERIODIC_HEAL = false, HEAL_CRIT = true, PERIODIC_HEAL_CRIT = true }
local AVOID = { "MISS", "DODGE", "PARRY", "EVADE", "IMMUNE", "DEFLECT", "REFLECT", "RESIST", "BLOCK", "ABSORB",
    "SPELL_MISS", "SPELL_DODGE", "SPELL_PARRY", "SPELL_EVADE", "SPELL_IMMUNE", "SPELL_DEFLECT", "SPELL_REFLECT",
    "SPELL_RESIST", "SPELL_BLOCK", "SPELL_ABSORB" }
local AVOID_LABEL = {}
for _, kind in ipairs(AVOID) do
    local base = kind:gsub("^SPELL_", "")
    AVOID_LABEL[kind] = _G["COMBAT_TEXT_" .. base] or _G[base] or (base:sub(1, 1) .. base:sub(2):lower())
end

local function OnCombatText(kind)
    CT.stats.combatText = CT.stats.combatText + 1
    local crit = DAMAGE[kind]
    if crit ~= nil then
        local amount = GetEventInfo()
        CT.EmitAmount("incomingDamage", "-", amount, crit, nil, nil, kind:find("SPELL") and "spell" or "melee")
        return
    end
    crit = HEAL[kind]
    if crit ~= nil then
        local _, amount = GetEventInfo()   -- data = quién cura, arg3 = cantidad
        CT.EmitAmount("incomingHeal", "+", amount, crit, nil, nil, kind:find("PERIODIC") and "hot" or "heal")
        return
    end
    if AVOID_LABEL[kind] then
        Show("incomingAvoid", AVOID_LABEL[kind])
    elseif kind == "ENERGIZE" or kind == "PERIODIC_ENERGIZE" then
        local amount, powerToken = GetEventInfo()
        local label = not IsSecret(powerToken) and powerToken and _G[powerToken] or nil
        if label then Show("incomingPower", "+%s " .. label, CT.Amount(amount)) else Show("incomingPower", "+%s", CT.Amount(amount)) end
    elseif kind == "AURA_START" then
        Show("buffs", "+%s", (GetEventInfo()))
    elseif kind == "AURA_END" then
        Show("buffs", "-%s", (GetEventInfo()))
    elseif kind == "AURA_START_HARMFUL" then
        Show("debuffs", "+%s", (GetEventInfo()))
    elseif kind == "AURA_END_HARMFUL" then
        Show("debuffs", "-%s", (GetEventInfo()))
    elseif kind == "SPELL_ACTIVE" then
        Show("procs", "¡%s!", (GetEventInfo()), nil, true)
    elseif kind == "FACTION" then
        local faction, amount = GetEventInfo()
        Show("reputation", "%s %s", faction, amount)
    elseif kind == "HONOR_GAINED" then
        Show("honor", "+%s " .. (_G.HONOR or "honor"), (GetEventInfo()))
    elseif kind == "HEALTH_LOW" then
        Show("lowHealth", "¡Vida baja!", nil, nil, true)
    elseif kind == "MANA_LOW" then
        Show("lowHealth", "¡Maná bajo!", nil, nil, true)
    end
end

---------------------------------------------------------------------------
-- 2. Lo que haces: el registro de combate tal como lo procesa Blizzard
---------------------------------------------------------------------------
local playerGUID
local MISS_LABEL = {}
for _, kind in ipairs({ "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "ABSORB", "IMMUNE", "EVADE", "DEFLECT", "REFLECT" }) do
    MISS_LABEL[kind] = _G["COMBAT_TEXT_" .. kind] or _G[kind] or kind
end

local function SpellIcon(spellID)
    if spellID == nil then return nil end
    local ok, icon = pcall(function()
        if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
        return GetSpellTexture and GetSpellTexture(spellID)
    end)
    if ok then return icon end
end
CT.SpellIcon = SpellIcon

-- Solo las escuelas mágicas colorean; lo físico conserva el color de su
-- categoría (tu daño, el de tu mascota...).
local function SchoolColor(school, fallback)
    school = Readable(school)
    if CT.db.schoolColors and school and school ~= 1 and CT.SCHOOL_COLORS[school] then
        return CT.SCHOOL_COLORS[school]
    end
    return fallback
end

-- Un evento del registro de combate (mismos campos que CombatLogGetCurrentEventInfo).
function CT.OnCombatLog(...)
    local _, sub, _, srcGUID, _, _, _, dstGUID = ...
    sub, srcGUID = Readable(sub), Readable(srcGUID)
    if not (sub and srcGUID) then return end
    playerGUID = playerGUID or UnitGUID("player")
    local petGUID = Readable(UnitGUID("pet"))
    local mine, pet = srcGUID == playerGUID, petGUID ~= nil and srcGUID == petGUID
    if not (mine or pet) then return end
    CT.stats.combatLog = CT.stats.combatLog + 1
    local toSelf = Readable(dstGUID) == playerGUID

    if sub == "SWING_DAMAGE" then
        local amount, overkill, school, _, _, _, critical = select(12, ...)
        local cat = pet and "petDamage" or "outgoingDamage"
        local base = Cat(cat)
        if base then
            CT.EmitAmount(cat, "", amount, Readable(critical), pet and CT.GLYPH.pet or CT.GLYPH.melee,
                SchoolColor(school, base.color), pet and "pet" or "melee",
                { spellName = pet and "Mascota" or "Cuerpo a cuerpo", overkill = overkill })
        end
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "DAMAGE_SHIELD" then
        local spellID, spellName, spellSchool, amount, overkill, _, _, _, _, critical = select(12, ...)
        local cat = pet and "petDamage" or "outgoingDamage"
        local base = Cat(cat)
        if base then
            local id = Readable(spellID)
            local auto = sub == "RANGE_DAMAGE" and id and RANGED_AUTO[id]
            CT.EmitAmount(cat, "", amount, Readable(critical), auto and CT.GLYPH.ranged or SpellIcon(spellID),
                SchoolColor(spellSchool, base.color), auto and "ranged" or (id and ("s" .. id) or nil),
                { spellName = Readable(spellName), spellID = id, overkill = overkill,
                  periodic = sub == "SPELL_PERIODIC_DAMAGE", target = Readable(dstGUID) })
        end
    elseif (sub == "SPELL_HEAL" or sub == "SPELL_PERIODIC_HEAL") and mine and not toSelf then
        -- Las curas a ti mismo ya salen como entrantes.
        local spellID, _, _, amount, _, _, critical = select(12, ...)
        local id = Readable(spellID)
        CT.EmitAmount("outgoingHeal", "+", amount, Readable(critical), SpellIcon(spellID), nil, id and ("s" .. id) or nil)
    elseif sub == "SWING_MISSED" then
        local missType = Readable((select(12, ...)))
        Show("outgoingMiss", MISS_LABEL[missType] or (_G.MISS or "Fallo"))
    elseif sub == "SPELL_MISSED" or sub == "RANGE_MISSED" then
        local spellID, _, _, missType = select(12, ...)
        missType = Readable(missType)
        Show("outgoingMiss", MISS_LABEL[missType] or (_G.MISS or "Fallo"), nil, nil, false, SpellIcon(spellID))
    elseif sub == "PARTY_KILL" and mine then
        if CT.Flair then CT.Flair.Kill(Readable(dstGUID), (select(9, ...)))
        else Show("killingBlow", "¡Golpe de gracia! %s", (select(9, ...)), nil, true) end
    end
end

-- El registro de combate de Blizzard llama a CombatLog_OnEvent con cada evento
-- que procesa. Engancharse ahí no añade ningún oyente propio del evento protegido.
local function HookCombatLog()
    if CT.stats.combatLogHooked or type(CombatLog_OnEvent) ~= "function" then return end
    local ok = pcall(hooksecurefunc, "CombatLog_OnEvent", function(_, ...)
        -- Normalmente recibe los campos del evento; si no tienen esa forma, se
        -- le pide al cliente el evento actual.
        local sub = select(2, ...)
        if IsSecret(sub) or type(sub) == "string" then
            pcall(CT.OnCombatLog, ...)
        elseif CombatLogGetCurrentEventInfo then
            pcall(function() CT.OnCombatLog(CombatLogGetCurrentEventInfo()) end)
        end
    end)
    CT.stats.combatLogHooked = ok
end

---------------------------------------------------------------------------
-- 2b. Respaldo: daño que recibe tu objetivo (si el registro no da nada)
---------------------------------------------------------------------------
-- Un golpe que no se puede atribuir a nada tuyo (tu mascota, tus daños en el
-- tiempo...) solo se enseña si no hay nadie más pegando: vas solo y el
-- enemigo no es de otro jugador.
function CT.MaybeMine()
    if IsInGroup and Readable(IsInGroup()) then return false end
    if UnitIsTapDenied and Readable(UnitIsTapDenied("target")) then return false end
    return true
end

local function OnUnitCombat(unit, action, descriptor, amount, school)
    if CT.stats.combatLog > 0 then return end   -- el registro funciona: mejor dato
    if unit ~= "target" or Readable(UnitIsFriend("player", "target")) then return end
    action = Readable(action)
    if action == "WOUND" then
        CT.stats.fallback = CT.stats.fallback + 1
        local base = Cat("outgoingDamage")
        if base then
            local icon, key, spellName = CT.GuessSource()
            if icon then
                CT.stats.guessed = CT.stats.guessed + 1
            elseif not CT.MaybeMine() then
                -- Nada tuyo explica el golpe y hay más gente pegando: es de otro.
                CT.stats.ignored = CT.stats.ignored + 1
                return
            end
            local label = spellName or (key == "melee" and "Cuerpo a cuerpo") or (key == "ranged" and "Disparo automático") or nil
            CT.EmitAmount("outgoingDamage", "", amount, Readable(descriptor) == "CRITICAL", icon,
                SchoolColor(school, base.color), key, { spellName = label })
            -- Golpe de gracia: si tu golpe (deducido) deja al objetivo muerto.
            if icon and CT.Flair then
                local guid = Readable(UnitGUID("target"))
                C_Timer.After(0.2, function()
                    if guid and Readable(UnitGUID("target")) == guid and UnitIsDead("target") then
                        CT.Flair.Kill(guid, Readable(UnitName("target")))
                    end
                end)
            end
        end
    end
end

---------------------------------------------------------------------------
-- 3. Botín y dinero (mensajes del chat)
---------------------------------------------------------------------------
-- "Recibes botín: %s." -> "^Recibes botín: (.+)%.$"
local function Pattern(format)
    if type(format) ~= "string" then return nil end
    local pattern = format:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. pattern .. "$"
end

local LOOT_PATTERNS = {}
local MONEY_PATTERNS = {}
local function BuildPatterns()
    for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF",
                           "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }) do
        local p = Pattern(_G[key])
        if p then LOOT_PATTERNS[#LOOT_PATTERNS + 1] = p end
    end
    for _, key in ipairs({ "YOU_LOOT_MONEY", "LOOT_MONEY_SPLIT" }) do
        local p = Pattern(_G[key])
        if p then MONEY_PATTERNS[#MONEY_PATTERNS + 1] = p end
    end
end

local function OnLoot(message)
    if IsSecret(message) or type(message) ~= "string" then return end
    for _, p in ipairs(LOOT_PATTERNS) do
        local item, count = message:match(p)
        if item then
            CT.stats.chat = CT.stats.chat + 1
            if count and tonumber(count) and tonumber(count) > 1 then
                Show("loot", "+%s x%s", item, count)
            else
                Show("loot", "+%s", item)
            end
            return
        end
    end
end

local function OnMoney(message)
    if IsSecret(message) or type(message) ~= "string" then return end
    for _, p in ipairs(MONEY_PATTERNS) do
        local money = message:match(p)
        if money then
            CT.stats.chat = CT.stats.chat + 1
            Show("money", "+%s", money)
            return
        end
    end
end

---------------------------------------------------------------------------
-- Ocultar el texto de combate de Blizzard sobre ti (no toca ninguna opción guardada)
---------------------------------------------------------------------------
function CT.ApplyBlizzard()
    local frame = _G.CombatText
    if not frame then return end
    if CT.db.hideBlizzardSelf then frame:Hide() else frame:Show() end
end

---------------------------------------------------------------------------
-- Arranque y diagnóstico
---------------------------------------------------------------------------
function CT.StartSources()
    BuildPatterns()
    if C_CombatText and C_CombatText.SetActiveUnit then pcall(C_CombatText.SetActiveUnit, "player") end

    local events = CreateFrame("Frame")
    events:RegisterEvent("COMBAT_TEXT_UPDATE")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:RegisterEvent("ADDON_LOADED")
    events:RegisterEvent("CHAT_MSG_LOOT")
    events:RegisterEvent("CHAT_MSG_MONEY")
    pcall(events.RegisterEvent, events, "PLAYER_SWING")
    pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
    pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "target")
    events:SetScript("OnEvent", function(_, event, ...)
        if event == "COMBAT_TEXT_UPDATE" then
            OnCombatText((...))
        elseif event == "UNIT_COMBAT" then
            OnUnitCombat(...)
        elseif event == "PLAYER_REGEN_DISABLED" then
            Show("combat", "+" .. (_G.ENTERING_COMBAT or "Combate"), nil, nil, true)
        elseif event == "PLAYER_REGEN_ENABLED" then
            Show("combat", "-" .. (_G.LEAVING_COMBAT or "Combate"))
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            CT.NoteCast(spellID)
        elseif event == "PLAYER_SWING" then
            local _, swingType = ...
            CT.NoteSwing(swingType)
        elseif event == "CHAT_MSG_LOOT" then
            OnLoot((...))
        elseif event == "CHAT_MSG_MONEY" then
            OnMoney((...))
        elseif event == "ADDON_LOADED" then
            local name = ...
            if name == "Blizzard_CombatLog" then HookCombatLog() end
            if name == "Blizzard_CombatText" then CT.ApplyBlizzard() end
        end
    end)

    -- El registro de combate de Blizzard puede no estar cargado todavía.
    if type(CombatLog_OnEvent) ~= "function" and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_CombatLog")
    end
    HookCombatLog()
    CT.ApplyBlizzard()
end

function CT.Diagnose()
    local s = CT.stats
    ns.Print("diagnóstico del texto de combate:")
    print("  texto de combate del cliente (lo que recibes): " .. s.combatText .. " eventos")
    print("  registro de combate (lo que haces): " .. (s.combatLogHooked and "enganchado" or "NO disponible")
        .. " · " .. s.combatLog .. " eventos tuyos")
    print("  respaldo por tu objetivo: " .. s.fallback .. " golpes (" .. s.guessed .. " con icono deducido)"
        .. ", " .. s.ignored .. " de otros descartados"
        .. (s.combatLog > 0 and " (no hace falta: el registro funciona)" or ""))
    print("  botín y dinero: " .. s.chat .. " mensajes")
    print("  Pega a un enemigo y vuelve a escribir /bui sct para ver qué fuentes funcionan.")
end

ns.RegisterCommand("sct", function() CT.Diagnose() end, "diagnóstico del texto de combate")
ns.RegisterCommand("sct prueba", function() CT.Burst() end, "ráfaga de prueba del texto de combate")
