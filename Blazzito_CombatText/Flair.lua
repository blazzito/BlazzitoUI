-- Blazzito_CombatText · Flair.lua
-- Lo que lo hace más llamativo (en Classic los golpes son pocos y espaciados:
-- que cada uno se note):
--  1. Tamaño según el golpe: cuanto mayor respecto a tu media, más grande.
--  2. Críticos: estallido detrás, temblor breve y "¡Crítico!" encima.
--  3. Rachas: críticos seguidos, "¡Crítico ×3!".
--  4. Resumen al salir de combate: daño, daño por segundo y tu mayor golpe.
--  5. Golpe de gracia con calavera.
--  6. Daño en el tiempo: los tics salen pequeños y, al acabar, el total
--     ("Picadura de serpiente ×5: 230").
--  7. Exceso de daño al matar ("+48 de exceso").
--  9. Ocultar tus golpes pequeños (opcional, p. ej. solo en grupo).
-- Solo se suman y comparan números legibles; los secretos se muestran tal cual.
local ns = BlazzitoUI
if not (ns and ns.CombatText) then return end

local CT, M = ns.CombatText, ns.Media
local Readable = M.Readable

local F = {}
CT.Flair = F
F.SKULL = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local GOLD = { 1.00, 0.85, 0.35 }
local GREY = { 0.62, 0.62, 0.66 }

local function O() return CT.db.flair end

---------------------------------------------------------------------------
-- 1. Tamaño según el golpe
---------------------------------------------------------------------------
F.avg = nil
-- Golpe medio: 1; el doble: 1,2; cuatro veces: 1,6 (tope). Pequeños: 0,85.
function F.Scale(value)
    if not (O().sizeByHit and type(value) == "number" and value > 0) then return 1 end
    local avg = F.avg
    F.avg = avg and (avg * 0.92 + value * 0.08) or value
    if not avg or avg <= 0 then return 1 end
    return math.max(0.85, math.min(1.6, 0.8 + 0.2 * value / avg))
end

---------------------------------------------------------------------------
-- 2 y 3. Críticos y rachas
---------------------------------------------------------------------------
F.streak = 0
function F.Crit(crit)
    if crit then F.streak = F.streak + 1 else F.streak = 0 end
end

-- Opciones de dibujo para un golpe tuyo.
function F.Options(value, crit)
    local o = O()
    local opts = { scale = F.Scale(value) }
    if crit then
        opts.burst = o.critBurst
        opts.shake = o.critShake
        if o.critLabel then
            opts.label = (o.streak and F.streak >= 2) and ("¡Crítico ×" .. F.streak .. "!") or "¡Crítico!"
        end
    end
    return opts
end

---------------------------------------------------------------------------
-- 4. Resumen del combate
---------------------------------------------------------------------------
F.fight = nil
function F.StartFight()
    F.fight = { start = GetTime(), hits = 0, total = 0, best = 0 }
    F.streak = 0
end

function F.Record(value, spellName, icon)
    local f = F.fight
    if not f then return end
    f.hits = f.hits + 1
    if type(value) == "number" then
        f.total = f.total + value
        f.readable = true
        if value > f.best then f.best, f.bestName, f.bestIcon = value, spellName, icon end
    end
end

local function Escape(text) return (tostring(text):gsub("%%", "%%%%")) end

function F.EndFight()
    local f = F.fight
    F.fight = nil
    if not (f and O().summary) or f.hits == 0 then return end
    local secs = math.max(1, GetTime() - f.start)
    if f.readable and f.total > 0 then
        CT.Emit("notification", "Combate: %s de daño · %s por segundo", CT.Amount(f.total),
            CT.Amount(math.floor(f.total / secs + 0.5)), GOLD, false, nil, { scale = 0.85 })
        if f.best > 0 then
            local text = "Mayor golpe: %s" .. (f.bestName and (" (" .. Escape(f.bestName) .. ")") or "")
            C_Timer.After(0.35, function()
                CT.Emit("notification", text, CT.Amount(f.best), nil, GOLD, false, f.bestIcon, { scale = 0.8 })
            end)
        end
    else
        CT.Emit("notification", string.format("Combate: %d %s en %d s", f.hits, f.hits == 1 and "golpe" or "golpes",
            math.floor(secs + 0.5)), nil, nil, GOLD, false, nil, { scale = 0.85 })
    end
end

---------------------------------------------------------------------------
-- 5. Golpe de gracia (una vez por enemigo)
---------------------------------------------------------------------------
local killed = {}
function F.Kill(guid, name)
    if guid then
        if killed[guid] then return end
        killed[guid] = GetTime()
    end
    local cat = CT.db.categories.killingBlow
    if not (cat and cat.on) then return end
    CT.Emit(cat.area, "¡Golpe de gracia! %s", name or "", nil, cat.color, true, O().killSkull and F.SKULL or nil)
end

---------------------------------------------------------------------------
-- 6. Daño en el tiempo
---------------------------------------------------------------------------
F.dots = {}
local DOT_GAP = 3.5      -- sin tics durante este tiempo: el efecto acabó

function F.DotDone(d)
    if d.ticks < 2 then return end
    local name = Escape(d.name or "")
    if d.secret then
        CT.Emit(d.area, name .. " ×%d", d.ticks, nil, d.color, false, d.icon, { scale = 0.9 })
    else
        CT.Emit(d.area, name .. " ×%d: %s", d.ticks, CT.Amount(d.total), d.color, false, d.icon, { scale = 0.9 })
    end
end

-- Devuelve true si el tic se trata como daño en el tiempo (sale pequeño).
function F.Tick(id, target, value, icon, name, color, area)
    if not O().dotSummary or not id then return false end
    local key = tostring(id) .. ":" .. tostring(target)
    local d = F.dots[key]
    if not d then
        d = { total = 0, ticks = 0, icon = icon, name = name, color = color, area = area }
        F.dots[key] = d
    end
    d.ticks = d.ticks + 1
    if type(value) == "number" then d.total = d.total + value else d.secret = true end
    d.last = GetTime()
    C_Timer.After(DOT_GAP + 0.1, function()
        if F.dots[key] == d and GetTime() - d.last >= DOT_GAP then
            F.dots[key] = nil
            F.DotDone(d)
        end
    end)
    return true
end

---------------------------------------------------------------------------
-- 7. Exceso de daño
---------------------------------------------------------------------------
function F.Overkill(over, area)
    over = Readable(over)
    if not (O().overkill and type(over) == "number" and over > 0) then return end
    C_Timer.After(0.12, function()
        CT.Emit(area, "+%s de exceso", CT.Amount(over), nil, GREY, false, nil, { scale = 0.7, faded = true })
    end)
end

---------------------------------------------------------------------------
-- 9. Golpes pequeños
---------------------------------------------------------------------------
function F.Hidden(value)
    local o = O()
    if not (o.minHit and o.minHit > 0 and type(value) == "number" and value < o.minHit) then return false end
    if o.minHitGroupOnly and not (IsInGroup and IsInGroup()) then return false end
    return true
end

---------------------------------------------------------------------------
function CT.StartFlair()
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            F.StartFight()
        else
            -- Un momento después: llegan los últimos golpes.
            C_Timer.After(0.4, F.EndFight)
            -- Los muertos de hace rato ya no hacen falta.
            local now = GetTime()
            for guid, at in pairs(killed) do if now - at > 60 then killed[guid] = nil end end
        end
    end)
end
