-- Blazzito_Macros: el motor.
--
-- Las macros son macros de personaje de verdad (CreateMacro), con el nombre
-- «BUI <nombre>». Solo se crean cuando las arrastras desde la ventana (los
-- huecos de macros de personaje son pocos). Después, si cambia algo (aprendes
-- un hechizo, cambias de arma, te quedas sin la comida de la mascota...), se
-- reescriben solas fuera de combate. Solo se reescribe una macro si sigue tal
-- cual la dejamos: si la has editado a mano en /macro, es tuya y no se toca.
--
-- El juego no deja crear ni editar macros en combate: lo que cambie en combate
-- se aplica al salir (ns.AfterCombat). Mientras, la macro anterior funciona.
local ns = BlazzitoUI
if not (ns and ns.MacroCatalog) then return end

local Cat = ns.MacroCatalog
local Readable = ns.Media.Readable

local Mac = ns.NewModule("Macros", "Macros de clase", {
    button = true,          -- botón junto al libro de hechizos
    autoUpdate = true,      -- reescribir solas las macros que ya creaste
    open = false,           -- la ventana estaba abierta al cerrar el libro
    weapons = {},           -- { two = id, one = id, shield = id }
    foods = {},             -- [nombre de la mascota] = { id, id, ... } (la última primero)
    written = {},           -- [nombre de macro] = el texto que escribimos
    -- Qué tecla usan las macros donde el catálogo dice Mayús, Ctrl o Alt
    -- ("shift", "ctrl", "alt" o "none" = quitar esa opción de las macros).
    mods = { shift = "shift", ctrl = "ctrl", alt = "alt" },
    markBars = true,        -- barrita del color de la clase en los botones con nuestras macros
    markAll = false,        -- también en tus otras macros (en gris)
})
ns.Macros = Mac

Mac.PREFIX = "BUI "
Mac.MAX_BODY = 255
Mac.ICON_DEFAULT = 134400   -- signo de interrogación: con #showtooltip el juego pone el icono del hechizo

local function Trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function Combat() return InCombatLockdown and InCombatLockdown() end

function Mac.Say(msg) ns.Print(msg) end

---------------------------------------------------------------------------
-- Hechizos: nombre en tu idioma y si lo conoces
---------------------------------------------------------------------------
local function SpellName(id)
    if not id then return nil end
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok then name = Readable(n) end
    elseif GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then name = Readable(n) end
    end
    return (type(name) == "string" and name ~= "") and name or nil
end
Mac.SpellName = SpellName

local function SpellSub(id)
    local fn = (C_Spell and C_Spell.GetSpellSubtext) or GetSpellSubtext
    if not fn then return nil end
    local ok, sub = pcall(fn, id)
    sub = ok and Readable(sub)
    return (type(sub) == "string" and sub ~= "") and sub or nil
end

local function Kind(name) return Enum and Enum.SpellBookItemType and Enum.SpellBookItemType[name] end
local function Bank(name)
    local b = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank[name]
    if b ~= nil then return b end
    return name == "Pet" and 1 or 0
end

-- Los nombres de todo lo que sabes: libro, grupos de hechizos (aspectos,
-- rastreos...) y los hechizos de tu mascota. Se rehace al cambiar los hechizos.
local known
function Mac.Forget() known = nil end

local function AddFlyout(set, id)
    if not (GetFlyoutInfo and GetFlyoutSlotInfo and id) then return end
    local ok, _, _, count = pcall(GetFlyoutInfo, id)
    for i = 1, (ok and Readable(count)) or 0 do
        local okS, spellID, _, isKnown, name = pcall(GetFlyoutSlotInfo, id, i)
        if okS and Readable(isKnown) ~= false then
            name = Readable(name) or SpellName(Readable(spellID))
            if type(name) == "string" then set[name] = true end
        end
    end
end

function Mac.Known()
    if known then return known end
    local set = {}
    local SB = C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookItemInfo then
        local bank = Bank("Player")
        local ok, lines = pcall(SB.GetNumSpellBookSkillLines)
        for i = 1, (ok and Readable(lines)) or 0 do
            local line = SB.GetSpellBookSkillLineInfo and SB.GetSpellBookSkillLineInfo(i)
            local off = line and Readable(line.offSpecID)
            if line and line.itemIndexOffset and not (off and off ~= 0) then
                for slot = line.itemIndexOffset + 1, line.itemIndexOffset + (line.numSpellBookItems or 0) do
                    local it = SB.GetSpellBookItemInfo(slot, bank)
                    local kind = it and it.itemType
                    if it and kind == Kind("Flyout") then
                        AddFlyout(set, it.actionID)
                    elseif it and type(it.name) == "string" and (Kind("Spell") == nil or kind == Kind("Spell")) then
                        set[it.name] = true
                    end
                end
            end
        end
        if SB.HasPetSpells then
            local okP, count = pcall(SB.HasPetSpells)
            count = okP and Readable(count)
            for slot = 1, type(count) == "number" and count or 0 do
                local it = SB.GetSpellBookItemInfo(slot, Bank("Pet"))
                if it and type(it.name) == "string" then set[it.name] = true end
            end
        end
    end
    known = set
    return set
end

-- true/false y el nombre (nil si el hechizo no existe en este cliente).
function Mac.KnowsID(id)
    local name = SpellName(id)
    if not name then return false, nil end
    if Mac.Known()[name] then return true, name end
    for _, fn in ipairs({ IsPlayerSpell, IsSpellKnown }) do
        local ok, yes = pcall(fn, id)
        if ok and Readable(yes) == true then return true, name end
    end
    return false, name
end

-- Escudos en tu idioma (para [equipped:...]).
function Mac.ShieldsName()
    local fn = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
    if fn then
        local ok, name = pcall(fn, 4, 6)
        name = ok and Readable(name)
        if type(name) == "string" and name ~= "" then return name end
    end
    return "Shields"
end

---------------------------------------------------------------------------
-- Plantillas -> texto de la macro
---------------------------------------------------------------------------
-- Un {token}: el texto y si lo conoces. «{9634|5487}»: el primero que conozcas.
local function Token(tok)
    if tok == "shields" then return Mac.ShieldsName(), true end
    local ids, rank = tok:match("^([%d|]+)(r?)$")
    if not ids then return nil, false end
    local function Format(name, id)
        if rank == "r" then
            local sub = SpellSub(id)
            if sub then return name .. "(" .. sub .. ")" end
        end
        return name
    end
    local firstName, firstID
    for id in ids:gmatch("%d+") do
        id = tonumber(id)
        local yes, name = Mac.KnowsID(id)
        if yes then return Format(name, id), true end
        if name and not firstName then firstName, firstID = name, id end
    end
    if firstName then return Format(firstName, firstID), false end
    return nil, false
end

-- Cambia los tokens de un trozo. Devuelve el texto y si se conocen todos.
local function Fill(text)
    local all = true
    local out = text:gsub("{([%w|]+)}", function(tok)
        local s, ok = Token(tok)
        if not ok then all = false end
        return s or ("{" .. tok .. "}")
    end)
    return out, all
end
Mac.Fill = Fill

---------------------------------------------------------------------------
-- Modificadores: el catálogo está escrito con Mayús, Ctrl y Alt; cada uno se
-- puede cambiar por otro o quitar (si chocan con tus atajos de teclado). Las
-- macros solo entienden esas tres teclas: un botón del ratón no sirve.
---------------------------------------------------------------------------
Mac.MOD_KEYS = { "shift", "ctrl", "alt" }
Mac.MOD_NAMES = { shift = "Mayús", ctrl = "Ctrl", alt = "Alt", none = "ninguno" }

local function ModMap()
    local m = Mac.db and Mac.db.mods
    return type(m) == "table" and m or {}
end

-- ¿Se queda este grupo de condiciones [..] con los modificadores elegidos?
local function GroupAllowed(group)
    local map = ModMap()
    for role in group:gmatch("mod:(%a+)") do
        if map[role:lower()] == "none" then return false end
    end
    return true
end

-- Quita de una opción los grupos [..] con un modificador quitado. nil si
-- tenía condiciones y no le queda ninguna (entonces la opción entera sobra).
local function DropMods(clause)
    if not clause:find("mod:") then return clause end
    local rest, kept, had = clause, {}, false
    while true do
        local group, after = rest:match("^(%b[])%s*(.*)$")
        if not group then break end
        had = true
        if GroupAllowed(group) then kept[#kept + 1] = group end
        rest = after
    end
    if had and #kept == 0 then return nil end
    return table.concat(kept) .. ((#kept > 0 and rest ~= "") and " " or "") .. rest
end

-- Cambia cada mod:x por la tecla elegida (de una pasada: se pueden intercambiar).
local function RenameMods(text)
    local map = ModMap()
    return (text:gsub("mod:(%a+)", function(role)
        local to = map[role:lower()]
        if to and to ~= "none" then return "mod:" .. to end
    end))
end

-- Las descripciones dicen «Mayús:», «Ctrl:»...: con la tecla elegida.
function Mac.Describe(text)
    local map = ModMap()
    local marks = { shift = "\1", ctrl = "\2", alt = "\3" }
    text = tostring(text or ""):gsub("Mayús", "\1"):gsub("Ctrl", "\2"):gsub("Alt", "\3")
    for role, mark in pairs(marks) do
        local to = map[role] or role
        local name = to == "none" and (Mac.MOD_NAMES[role] .. " (quitado)") or Mac.MOD_NAMES[to]
        text = text:gsub(mark, name)
    end
    return text
end

function Mac.Expand(template)
    local lines = {}
    for line in (template .. "\n"):gmatch("(.-)\n") do
        -- Órdenes con un modificador quitado: fuera sus condiciones, o la línea entera.
        local cmd, args = line:match("^(/%a+)%s+(.*)$")
        if cmd and cmd ~= "/cast" and cmd ~= "/use" and line:find("mod:") then
            args = DropMods(args)
            line = args and (cmd .. " " .. args) or ""
        end
        if line == "" then
            -- nada
        elseif line:find("^#show") then
            local filled, all = Fill(line)
            lines[#lines + 1] = all and filled or line:match("^(#%S+)")
        elseif line:find("^/castsequence%s") then
            local rest = line:match("^/castsequence%s+(.*)$")
            local reset, steps = rest:match("^(reset=%S+)%s+(.*)$")
            steps = steps or rest
            local keep = {}
            for step in steps:gmatch("[^,]+") do
                local filled, all = Fill(Trim(step))
                if all then keep[#keep + 1] = filled end
            end
            if #keep > 0 then
                lines[#lines + 1] = "/castsequence " .. (reset and (reset .. " ") or "") .. table.concat(keep, ", ")
            end
        elseif line:find("^/cast%s") or line:find("^/use%s") then
            local cmd, rest = line:match("^(/%a+)%s+(.*)$")
            local keep = {}
            for clause in (rest .. ";"):gmatch("([^;]*);") do
                clause = DropMods(Trim(clause))
                if clause and clause ~= "" then
                    local filled, all = Fill(clause)
                    if all then keep[#keep + 1] = filled end
                end
            end
            if #keep > 0 then lines[#lines + 1] = cmd .. " " .. table.concat(keep, "; ") end
        else
            local filled, all = Fill(line)
            if all then lines[#lines + 1] = filled end
        end
    end
    return RenameMods(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Objetos (consumibles, armas)
---------------------------------------------------------------------------
local function Count(id)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not (fn and id) then return 0 end
    local ok, n = pcall(fn, id)
    n = ok and Readable(n)
    return type(n) == "number" and n or 0
end
Mac.Count = Count

local function PlayerLevel()
    local lvl = UnitLevel and Readable(UnitLevel("player"))
    return type(lvl) == "number" and lvl or 60
end

-- El primero de la lista que llevas en las bolsas y puedes usar por nivel.
-- La lista va de mejor a peor: { id, nivel } o solo id.
function Mac.Best(list)
    local level = PlayerLevel()
    for _, e in ipairs(list) do
        local id, need = e, 0
        if type(e) == "table" then id, need = e[1], e[2] or 0 end
        if need <= level and Count(id) > 0 then return id end
    end
    return nil
end

-- Listas de mejor a peor.
Mac.ITEMS = {
    healthstone = { 19013, 19012, 9421, 19011, 19010, 5510, 19009, 19008, 5509, 19007, 19006, 5511, 19005, 19004, 5512 },
    healing = { { 13446, 45 }, { 3928, 35 }, { 1710, 21 }, { 929, 12 }, { 858, 3 }, { 118, 1 } },
    mana = { { 13444, 49 }, { 13443, 41 }, { 6149, 31 }, { 3827, 22 }, { 3385, 14 }, { 2455, 5 } },
    -- Bebida: conjurada primero en cada nivel.
    drink = { { 8079, 55 }, { 8078, 45 }, { 8766, 45 }, { 8077, 35 }, { 1645, 35 }, { 3772, 25 }, { 1708, 25 },
        { 2136, 15 }, { 1205, 15 }, { 2288, 5 }, { 1179, 5 }, { 5350, 1 }, { 159, 1 } },
    conjuredDrink = { { 8079, 55 }, { 8078, 45 }, { 8077, 35 }, { 3772, 25 }, { 2136, 15 }, { 2288, 5 }, { 5350, 1 } },
    -- Comida: conjurada, pan, carne, pescado, fruta, queso y setas de cada nivel.
    food = { { 22895, 55 },
        { 8076, 45 }, { 8950, 45 }, { 8952, 45 }, { 8957, 45 }, { 8953, 45 }, { 8932, 45 }, { 8948, 45 },
        { 8075, 35 }, { 4601, 35 }, { 4599, 35 }, { 21552, 35 }, { 4602, 35 }, { 3927, 35 }, { 4608, 35 },
        { 1487, 25 }, { 4544, 25 }, { 3771, 25 }, { 4594, 25 }, { 4539, 25 }, { 1707, 25 }, { 4607, 25 },
        { 1114, 15 }, { 4542, 15 }, { 3770, 15 }, { 4593, 15 }, { 4538, 15 }, { 422, 15 }, { 4606, 15 },
        { 1113, 5 }, { 4541, 5 }, { 2287, 5 }, { 4592, 5 }, { 4537, 5 }, { 414, 5 }, { 4605, 5 },
        { 5349, 1 }, { 4540, 1 }, { 117, 1 }, { 787, 1 }, { 4536, 1 }, { 2070, 1 }, { 4604, 1 } },
    gem = { 8008, 8007, 5513, 5514 },
    instant = { { 8928, 52 }, { 8927, 44 }, { 8926, 36 }, { 6950, 28 }, { 6949, 28 }, { 6947, 20 } },
    offhand = { { 20844, 60 }, { 8985, 54 }, { 8984, 46 }, { 2893, 38 }, { 2892, 30 }, { 3776, 50 }, { 3775, 20 } },
}

local NO_MANA = { WARRIOR = true, ROGUE = true }
local function PlayerClass() return UnitClass and select(2, UnitClass("player")) end
function Mac.UsesMana() return not NO_MANA[PlayerClass() or ""] end

---------------------------------------------------------------------------
-- Armas: la última de dos manos y la última de una mano con lo que llevabas
-- en la otra (escudo, arma, objeto de mano izquierda o nada).
-- La macro pregunta si llevas puesto el TIPO de tu arma de dos manos
-- ([equipped:Bastones], [equipped:Mazas de dos manos]...): nunca coincide con
-- un arma de una mano, así que funciona con escudo, sin él o con dos armas.
---------------------------------------------------------------------------
local function ItemInstant(id)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not (fn and id) then return nil end
    local ok, _, _, subType, loc = pcall(fn, id)
    if not ok then return nil end
    return loc, Readable(subType)
end

local ONE_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }

function Mac.TrackWeapons()
    if not Mac.db then return end
    local mh = GetInventoryItemID and Readable(GetInventoryItemID("player", 16))
    local oh = GetInventoryItemID and Readable(GetInventoryItemID("player", 17))
    local w = Mac.db.weapons
    if w.shield and w.off == nil then w.off, w.shield = w.shield, nil end   -- datos de la versión anterior
    local loc, subType = ItemInstant(mh)
    local changed = false
    if mh and loc == "INVTYPE_2HWEAPON" then
        if w.two ~= mh or w.twoType ~= subType then w.two, w.twoType, changed = mh, subType, true end
    elseif mh and ONE_HAND[loc] then
        local off = oh or false     -- false = nada en la otra mano
        if w.one ~= mh or w.off ~= off then w.one, w.off, changed = mh, off, true end
    end
    return changed
end

-- Al cambiar de arma llegan dos avisos (una mano y la otra): se mira al final.
local weaponPending = false
function Mac.WeaponsChanged()
    if weaponPending then return end
    weaponPending = true
    local function Run()
        weaponPending = false
        if Mac.TrackWeapons() then Mac.Schedule() end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.8, Run) else Run() end
end

---------------------------------------------------------------------------
-- Mascota: la comida que le diste
---------------------------------------------------------------------------
local function PetKey()
    local name = UnitName and Readable(UnitName("pet"))
    if type(name) == "string" and name ~= "" then
        Mac.lastPet = name
        return name
    end
    return Mac.lastPet or "?"
end
Mac.PetKey = PetKey

function Mac.RememberFood(id)
    if not (Mac.db and id) then return end
    local key = PetKey()
    local list = Mac.db.foods[key] or {}
    for i = #list, 1, -1 do if list[i] == id then table.remove(list, i) end end
    table.insert(list, 1, id)
    while #list > 10 do table.remove(list) end
    Mac.db.foods[key] = list
    Mac.Schedule()
end

-- La primera comida de la lista que te queda en las bolsas.
function Mac.PetFood()
    local list = Mac.db and Mac.db.foods[PetKey()]
    for _, id in ipairs(list or {}) do
        if Count(id) > 0 then return id end
    end
    return nil, list and #list > 0
end

---------------------------------------------------------------------------
-- Macros que se escriben con lo que llevas: devuelven plantilla y nota
---------------------------------------------------------------------------
local function Uses(lines, prefix, id) if id then lines[#lines + 1] = prefix .. "item:" .. id end end

Mac.DYNAMIC = {}

Mac.DYNAMIC.emergency = function()
    local hs, pot = Mac.Best(Mac.ITEMS.healthstone), Mac.Best(Mac.ITEMS.healing)
    local lines = { "#showtooltip" }
    Uses(lines, "/use ", hs)
    Uses(lines, "/use ", pot)
    local note = (hs or pot) and nil or "No llevas piedras de salud ni pociones de vida."
    return table.concat(lines, "\n"), note
end

Mac.DYNAMIC.manapot = function()
    local pot = Mac.Best(Mac.ITEMS.mana)
    local lines = { "#showtooltip" }
    Uses(lines, "/use ", pot)
    return table.concat(lines, "\n"), (not pot) and "No llevas pociones de maná." or nil
end

Mac.DYNAMIC.food = function()
    local food = Mac.Best(Mac.ITEMS.food)
    local drink = Mac.UsesMana() and Mac.Best(Mac.ITEMS.drink) or nil
    local lines = { "#showtooltip" }
    Uses(lines, "/use ", food)
    Uses(lines, "/use ", drink)
    if not (food or drink) then return table.concat(lines, "\n"), "No llevas comida ni bebida de tu nivel." end
    return table.concat(lines, "\n"), nil
end

Mac.DYNAMIC.feed = function()
    local food, tried = Mac.PetFood()
    local lines = { "#showtooltip {6991}", "/cast {6991}" }
    Uses(lines, "/use ", food)
    local note
    if not food then
        note = tried and "Ya no te queda ninguna comida que haya comido tu mascota: dale otra a mano."
            or "Dale de comer una vez a mano y la recordaré."
    end
    return table.concat(lines, "\n"), note
end

Mac.DYNAMIC.weapon = function()
    local w = Mac.db and Mac.db.weapons or {}
    local lines = { "#showtooltip" }
    local twoType = w.two and (w.twoType or select(2, ItemInstant(w.two)))
    if w.two and w.one and twoType then
        local cond = "[equipped:" .. twoType .. "]"
        lines[#lines + 1] = "/equipslot " .. cond .. " 16 item:" .. w.one
        if w.off then lines[#lines + 1] = "/equipslot " .. cond .. " 17 item:" .. w.off end
        lines[#lines + 1] = "/equip [noequipped:" .. twoType .. "] item:" .. w.two
    elseif w.two then
        lines[#lines + 1] = "/equip item:" .. w.two
    elseif w.one then
        lines[#lines + 1] = "/equipslot 16 item:" .. w.one
        if w.off then lines[#lines + 1] = "/equipslot 17 item:" .. w.off end
    end
    local note
    if not w.two and not w.one then note = "Ponte una vez el arma de dos manos y una vez la de una mano."
    elseif not w.two then note = "Ponte una vez tu arma de dos manos y la recordaré."
    elseif not w.one then note = "Ponte una vez tu arma de una mano (con escudo o sin él) y la recordaré." end
    return table.concat(lines, "\n"), note
end

Mac.DYNAMIC.poison = function()
    local main, off = Mac.Best(Mac.ITEMS.instant), Mac.Best(Mac.ITEMS.offhand)
    local lines = { "#showtooltip" }
    if main and off then
        lines[#lines + 1] = "/use [mod:shift] item:" .. off .. "; item:" .. main
    elseif main then
        lines[#lines + 1] = "/use [nomod] item:" .. main
    elseif off then
        lines[#lines + 1] = "/use [mod:shift] item:" .. off
    end
    if main or off then lines[#lines + 1] = "/use [mod:shift] 17; 16" end
    return table.concat(lines, "\n"), (not (main or off)) and "No llevas venenos." or nil
end

Mac.DYNAMIC.water = function()
    local water = Mac.Best(Mac.ITEMS.conjuredDrink)
    if water then return "#showtooltip\n/use [nomod] item:" .. water .. "\n/cast [mod:shift] {5504}", nil end
    return "#showtooltip\n/cast {5504}", "No te queda agua conjurada: la macro conjura."
end

Mac.DYNAMIC.gem = function()
    local gem = Mac.Best(Mac.ITEMS.gem)
    if gem then return "#showtooltip\n/use item:" .. gem, nil end
    return "#showtooltip\n/cast {10054|10053|3552|759}", "No llevas gema: la macro crea una."
end

Mac.DYNAMIC.healthstone = function()
    local hs = Mac.Best(Mac.ITEMS.healthstone)
    if hs then return "#showtooltip\n/use item:" .. hs, nil end
    return "#showtooltip\n/cast {11730|11729|5699|6202|6201}", "No llevas piedra: la macro crea una."
end

---------------------------------------------------------------------------
-- Las macros de tu clase
---------------------------------------------------------------------------
function Mac.Entries(class)
    class = class or PlayerClass()
    local list = {}
    for _, e in ipairs(Cat[class or ""] or {}) do list[#list + 1] = e end
    for _, e in ipairs(Cat.ALL) do
        if not (e.mana and NO_MANA[class or ""]) then list[#list + 1] = e end
    end
    return list
end

-- Requisitos: los de req o todos los hechizos de la plantilla.
local function Requirements(entry)
    if entry.req then return entry.req end
    if not entry.body then return {} end
    local reqs = {}
    for tok in entry.body:gmatch("{([%d|]+)r?}") do reqs[#reqs + 1] = tok end
    return reqs
end

-- "ready", "locked" (con el nombre del hechizo que falta) o "missing" (el
-- hechizo no existe en este cliente: no se muestra).
function Mac.State(entry)
    for _, req in ipairs(Requirements(entry)) do
        local okAny, firstName = false, nil
        for id in tostring(req):gmatch("%d+") do
            local yes, name = Mac.KnowsID(tonumber(id))
            if yes then okAny = true; break end
            firstName = firstName or name
        end
        if not okAny then
            if not firstName then return "missing" end
            return "locked", firstName
        end
    end
    return "ready"
end

-- El texto final de la macro y una nota (para las dinámicas).
function Mac.Body(entry)
    local template, note = entry.body, nil
    if entry.dynamic and Mac.DYNAMIC[entry.dynamic] then template, note = Mac.DYNAMIC[entry.dynamic](entry) end
    return Mac.Expand(template or "#showtooltip"), note
end

function Mac.MacroName(entry) return Mac.PREFIX .. entry.name end

function Mac.Icon(entry)
    local icon = entry.icon
    if type(icon) == "number" and icon < 100000 then
        local fn = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
        local ok, tex = pcall(fn, icon)
        tex = ok and Readable(tex)
        return tex or Mac.ICON_DEFAULT
    end
    return icon or Mac.ICON_DEFAULT
end

-- Icono para la ventana: el del primer hechizo de la macro (o el suyo).
function Mac.PreviewIcon(entry)
    if entry.icon then return Mac.Icon(entry) end
    local reqs = Requirements(entry)
    local first = reqs[1] and tonumber(tostring(reqs[1]):match("%d+"))
    if first then
        local fn = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
        local ok, tex = pcall(fn, first)
        tex = ok and Readable(tex)
        if tex then return tex end
    end
    return Mac.DYNAMIC_ICONS[entry.dynamic or ""] or Mac.ICON_DEFAULT
end

Mac.DYNAMIC_ICONS = {
    emergency = "Interface\\Icons\\INV_Stone_04",
    food = "Interface\\Icons\\INV_Misc_Food_14",
    manapot = "Interface\\Icons\\INV_Potion_76",
    weapon = "Interface\\Icons\\INV_Shield_06",
    poison = "Interface\\Icons\\Ability_Poisons",
}

---------------------------------------------------------------------------
-- Crear, coger y reescribir
---------------------------------------------------------------------------
local function Norm(s) return (tostring(s or ""):gsub("[%s]+$", "")) end

local function MacroIndex(name)
    if not GetMacroIndexByName then return nil end
    local ok, i = pcall(GetMacroIndexByName, name)
    i = ok and Readable(i)
    return (type(i) == "number" and i > 0) and i or nil
end
Mac.MacroIndex = MacroIndex

local function MacroBody(index)
    if not GetMacroBody then return nil end
    local ok, body = pcall(GetMacroBody, index)
    return ok and Readable(body) or nil
end

function Mac.MaxCharacter()
    local c = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_CHARACTER_MACROS
    return c or MAX_CHARACTER_MACROS or 18
end

function Mac.CharacterCount()
    if not GetNumMacros then return 0 end
    local ok, _, perChar = pcall(GetNumMacros)
    perChar = ok and Readable(perChar)
    return type(perChar) == "number" and perChar or 0
end

-- Crea (o pone al día) la macro y la deja en el cursor para soltarla en una barra.
function Mac.Pickup(entry)
    if Combat() then
        Mac.Say("las macros se crean y se cogen fuera de combate.")
        return false
    end
    local state, missing = Mac.State(entry)
    if state ~= "ready" then
        if missing then Mac.Say("esta macro se desbloquea con |cffffffff" .. missing .. "|r.") end
        return false
    end
    local body = Mac.Body(entry)
    if #body > Mac.MAX_BODY then
        Mac.Say(string.format("«%s» ocupa %d caracteres en tu idioma y el máximo son %d.", entry.title, #body, Mac.MAX_BODY))
        return false
    end
    local name = Mac.MacroName(entry)
    local index = MacroIndex(name)
    if index then
        if Norm(MacroBody(index)) ~= Norm(body) then
            local ok, new = pcall(EditMacro, index, name, Mac.Icon(entry), body)
            index = (ok and Readable(new)) or MacroIndex(name)
        end
    else
        if Mac.CharacterCount() >= Mac.MaxCharacter() then
            Mac.Say(string.format("no te quedan huecos de macros de personaje (%d/%d). Borra alguna en /macro.",
                Mac.CharacterCount(), Mac.MaxCharacter()))
            return false
        end
        local ok, new = pcall(CreateMacro, name, Mac.Icon(entry), body, true)
        index = (ok and Readable(new)) or MacroIndex(name)
    end
    if not index then
        Mac.Say("no se pudo crear la macro «" .. name .. "».")
        return false
    end
    Mac.db.written[name] = Norm(body)
    if PickupMacro then PickupMacro(index) end
    return true
end

-- Pone al día las macros que ya creaste (solo las que no editaste a mano).
function Mac.RefreshAll()
    if not (Mac.db and Mac.active) then return end
    if Combat() then
        ns.AfterCombat("bui-macros", Mac.RefreshAll)
        return
    end
    if Mac.db.autoUpdate then
        for _, entry in ipairs(Mac.Entries()) do
            local name = Mac.MacroName(entry)
            local index = MacroIndex(name)
            if index and Mac.State(entry) == "ready" then
                local current = Norm(MacroBody(index))
                local body = Mac.Body(entry)
                if Norm(body) ~= current and #body <= Mac.MAX_BODY and Mac.db.written[name] == current then
                    local ok = pcall(EditMacro, index, nil, nil, body)
                    if ok then Mac.db.written[name] = Norm(body) end
                end
            end
        end
    end
    if Mac.Repaint then Mac.Repaint() end
end

local scheduled = false
function Mac.Schedule()
    if scheduled or not Mac.active then return end
    scheduled = true
    local function Run()
        scheduled = false
        Mac.RefreshAll()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, Run) else Run() end
end

-- ¿Qué macros nuestras están en tus barras? [nombre] = true
function Mac.OnBars()
    local set = {}
    if not (GetActionInfo and Mac.SlotMacroName) then return set end
    for slot = 1, 180 do
        local name = Mac.SlotMacroName(slot)
        if name and name ~= "" then set[name] = true end
    end
    return set
end

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------
-- La comida de la mascota: al alimentarla, la última comida que usaste de las bolsas.
local lastUse
local function Used(bag, slot)
    if not (C_Container and C_Container.GetContainerItemID) then return end
    local ok, id = pcall(C_Container.GetContainerItemID, bag, slot)
    id = ok and Readable(id)
    if id then lastUse = { id = id, t = GetTime and GetTime() or 0 } end
end
if hooksecurefunc then
    if C_Container and C_Container.UseContainerItem then pcall(hooksecurefunc, C_Container, "UseContainerItem", Used) end
    if _G.UseContainerItem then pcall(hooksecurefunc, "UseContainerItem", Used) end
end

function Mac.OnCast(unit, spellID)
    if unit ~= "player" or not Mac.active then return end
    spellID = Readable(spellID)
    local feed = SpellName(6991)
    local name = spellID and SpellName(spellID)
    local isFeed = spellID == 6991 or (feed and name and name:find(feed, 1, true))
    if not isFeed or not lastUse then return end
    local now = GetTime and GetTime() or 0
    if now - lastUse.t <= 6 then Mac.RememberFood(lastUse.id) end
    lastUse = nil
end

local function On(event, fn) pcall(ns.On, event, fn) end
On("SPELLS_CHANGED", function() Mac.Forget(); Mac.Schedule() end)
On("LEARNED_SPELL_IN_SKILL_LINE", function() Mac.Forget(); Mac.Schedule() end)
On("PET_BAR_UPDATE", function() Mac.Forget(); Mac.Schedule() end)
On("UNIT_PET", function(_, unit) if unit == "player" then Mac.Forget(); PetKey(); Mac.Schedule() end end)
On("PLAYER_LEVEL_UP", function() Mac.Schedule() end)
On("BAG_UPDATE_DELAYED", function() Mac.Schedule() end)
On("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
    if slot == 16 or slot == 17 then Mac.WeaponsChanged() end
end)
On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID) Mac.OnCast(unit, spellID) end)
On("UPDATE_MACROS", function() if Mac.Repaint then Mac.Repaint() end end)
On("ACTIONBAR_SLOT_CHANGED", function() if Mac.Repaint then Mac.Repaint() end end)

function Mac:OnEnable()
    PetKey()
    Mac.TrackWeapons()
    Mac.Schedule()
    if Mac.SetupWindow then Mac.SetupWindow() end
    if Mac.ScheduleMarks then Mac.ScheduleMarks() end
end

---------------------------------------------------------------------------
-- /bui macros  (abre la ventana)  ·  /bui macros ver  (texto de cada una)
---------------------------------------------------------------------------
ns.RegisterCommand("macros", function(arg)
    if arg == "ver" or arg == "lista" then
        ns.Print("macros de tu clase:")
        for _, entry in ipairs(Mac.Entries()) do
            local state, missing = Mac.State(entry)
            if state ~= "missing" then
                local body, note = Mac.Body(entry)
                print(string.format("|cffffffff%s|r (%s%s) %d car.", Mac.MacroName(entry),
                    state == "ready" and "disponible" or ("con " .. tostring(missing)),
                    MacroIndex(Mac.MacroName(entry)) and ", creada" or "", #body))
                for line in (body .. "\n"):gmatch("(.-)\n") do print("    " .. line) end
                if note then print("    |cff999999" .. note .. "|r") end
            end
        end
        return
    end
    if Mac.Toggle then Mac.Toggle() end
end, "ventana de macros de clase (ver: su texto en el chat)")
