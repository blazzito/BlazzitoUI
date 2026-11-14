-- ¿Este enemigo cuenta para una misión que llevas? Detección propia, sin
-- depender de otros addons.
--
-- Cómo lo hace Questie (como referencia): lleva una base de datos enorme con
-- qué PNJ hay que matar y qué PNJ suelta cada objeto, y la cruza con tu
-- registro de misiones. Aquí no hay base de datos; en su lugar, tres capas:
--  1. El juego: UnitIsRelatedToActiveQuest (en Forever no siempre responde).
--  2. Objetivos de matar: el registro dice "Lobo joven pulgoso muerto: 2/8";
--     si el nombre del enemigo está en un objetivo sin terminar, cuenta.
--  3. Objetivos de objetos ("Piel de lobo: 1/5"): se aprenden al saquear.
--     Cuando sacas un objeto que pide una misión abierta, se apunta qué tipo
--     de PNJ lo soltó (BlazzitoUIDB.npQuestDrops, para toda la cuenta); desde
--     entonces los de ese tipo se marcan mientras la misión siga abierta.
--     El cadáver se apunta al abrir el botín (LOOT_READY), antes de que el
--     botín rápido se lleve los objetos; el objeto se reconoce en la ventana
--     de botín o, si ya no está, en el mensaje "Recibes botín: [objeto]".
local ns = BlazzitoUI
if not (ns and ns.Nameplates) then return end

local NP, M = ns.Nameplates, ns.Media
local Readable = M.Readable

local Q = {}
NP.Quest = Q
Q.kills = {}   -- objetivos de matar sin terminar (texto en minúsculas)
Q.items = {}   -- objetos que piden misiones sin terminar (nombre en minúsculas)
Q.seen = {}    -- todo lo leído del registro (para /bui placas misiones)

-- El objetivo sin el contador, en minúsculas. Forever lo pone delante
-- ("3/4 Trozo de carne de jabalí"); el registro clásico, detrás
-- ("Lobo joven pulgoso muerto: 2/8").
local function Subject(text)
    text = text:gsub("^%s*%d+%s*/%s*%d+%s*", "")
    text = text:gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
    return text:lower()
end
Q.Subject = Subject

local function Add(text, kind, finished)
    text = Readable(text)
    if type(text) ~= "string" or text == "" then return end
    Q.seen[#Q.seen + 1] = { text = text, kind = tostring(kind), finished = finished and true or false }
    if finished then return end
    if kind == "monster" then
        Q.kills[#Q.kills + 1] = Subject(text)
    elseif kind == "item" then
        Q.items[Subject(text)] = true
    end
end

local function ScanModern()
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetQuestIDForLogIndex and log.GetQuestObjectives) then return end
    for i = 1, (log.GetNumQuestLogEntries() or 0) do
        local questID = log.GetQuestIDForLogIndex(i)
        if questID and questID > 0 then
            for _, o in ipairs(log.GetQuestObjectives(questID) or {}) do
                Add(o.text, o.type, o.finished)
            end
        end
    end
end

local function ScanClassic()
    if not (GetNumQuestLogEntries and GetQuestLogLeaderBoard and GetNumQuestLeaderBoards and GetQuestLogTitle) then return end
    for i = 1, (GetNumQuestLogEntries() or 0) do
        local _, _, _, isHeader = GetQuestLogTitle(i)
        if not isHeader then
            for j = 1, (GetNumQuestLeaderBoards(i) or 0) do
                Add(GetQuestLogLeaderBoard(j, i))
            end
        end
    end
end

-- Lee tu registro de misiones: la API moderna y, si no da nada (en Forever
-- puede existir y venir vacía para misiones clásicas), la clásica.
function Q.Scan()
    wipe(Q.kills)
    wipe(Q.items)
    wipe(Q.seen)
    Q.source = "moderna"
    pcall(ScanModern)
    if #Q.seen == 0 then
        Q.source = "clásica"
        pcall(ScanClassic)
    end
end

-- Número de PNJ de un GUID de criatura ("Creature-0-1-2-3-299-abc" -> "299").
local function NpcID(guid)
    guid = Readable(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)")
    if kind == "Creature" or kind == "Vehicle" then return id end
end
Q.NpcID = NpcID

local function Drops()
    if not BlazzitoUIDB then return {} end
    BlazzitoUIDB.npQuestDrops = BlazzitoUIDB.npQuestDrops or {}
    return BlazzitoUIDB.npQuestDrops
end
Q.Drops = Drops

-- Palabras con significado ("Pelaje de oso grueso" -> pelaje, oso, grueso).
local GENERIC = { de = true, del = true, la = true, el = true, los = true, las = true, una = true, uno = true,
                  con = true, por = true, para = true, the = true, ["of"] = true, ["and"] = true, ["for"] = true }
local function Words(text)
    local list = {}
    for word in text:gmatch("[^%s%p]+") do
        if #word >= 3 and not GENERIC[word] then list[word] = true end
    end
    return list
end

-- ¿El nombre aparece entero (no dentro de otra palabra) en el objetivo?
local function NameIn(subject, name)
    local from, to = subject:find(name, 1, true)
    if not from then return false end
    local before, after = subject:sub(from - 1, from - 1), subject:sub(to + 1, to + 1)
    return not before:match("%a") and not after:match("%a")
end

-- Devuelve si cuenta y por qué (el porqué solo para el diagnóstico).
function Q.Why(unit)
    if UnitIsRelatedToActiveQuest and Readable(UnitIsRelatedToActiveQuest(unit)) == true then return true, "el juego" end
    local name = Readable(UnitName(unit))
    if type(name) == "string" and name ~= "" then
        name = name:lower()
        for _, subject in ipairs(Q.kills) do
            if NameIn(subject, name) then return true, "objetivo de matar: " .. subject end
        end
    end
    local id = NpcID(UnitGUID(unit))
    local learned = id and Drops()[id]
    if learned then
        for item in pairs(learned) do
            if Q.items[item] then return true, "suelta " .. item end
        end
    end
    -- Probable por el nombre: el objeto comparte una palabra con el enemigo
    -- ("Pelaje de oso grueso" y "Oso zarpahelada"). Hasta saquear uno.
    if type(name) == "string" and name ~= "" and next(Q.items) then
        local words = Words(name)
        for item in pairs(Q.items) do
            for word in pairs(Words(item)) do
                if words[word] then return true, "probable por el nombre: " .. item end
            end
        end
    end
    if learned then
        return false, "PNJ " .. id .. " aprendido, pero sus objetos no los pide ninguna misión abierta"
    end
    return false, id and ("PNJ " .. id .. " sin aprender") or "sin número de PNJ"
end

function Q.IsQuestUnit(unit)
    return (Q.Why(unit))
end

---------------------------------------------------------------------------
-- Aprender qué PNJ sueltan los objetos de tus misiones
---------------------------------------------------------------------------
local function Remember(guids, item)
    local learned = false
    for _, guid in ipairs(guids) do
        local id = NpcID(guid)
        if id then
            local drops = Drops()
            drops[id] = drops[id] or {}
            if not drops[id][item] then
                drops[id][item] = true
                learned = true
            end
        end
    end
    return learned
end

-- Al abrir el botín: de qué cadáveres es (antes de que se vacíe).
function Q.NoteCorpse()
    local guids = {}
    if GetLootSourceInfo and GetNumLootItems then
        for slot = 1, (GetNumLootItems() or 0) do
            local info = { GetLootSourceInfo(slot) }
            for i = 1, #info, 2 do guids[#guids + 1] = info[i] end
        end
    end
    if #guids == 0 then
        for _, unit in ipairs({ "target", "mouseover" }) do
            if UnitExists(unit) and Readable(UnitIsDead(unit)) then guids[#guids + 1] = UnitGUID(unit) end
        end
    end
    if #guids > 0 then Q.corpse = { guids = guids, time = GetTime() } end
end

local function SlotName(slot)
    local link = GetLootSlotLink and GetLootSlotLink(slot)
    local name = type(link) == "string" and link:match("%[(.-)%]")
    if not name and GetLootSlotInfo then name = select(2, GetLootSlotInfo(slot)) end
    name = Readable(name)
    return type(name) == "string" and name:lower() or nil
end

-- Ventana de botín: objetos de misión que haya, con sus cadáveres.
-- Devuelve true si aprendió algo nuevo.
function Q.Learn()
    Q.NoteCorpse()
    if not (next(Q.items) and GetNumLootItems) then return false end
    local learned = false
    for slot = 1, (GetNumLootItems() or 0) do
        local item = SlotName(slot)
        if item and Q.items[item] then
            local guids = {}
            if GetLootSourceInfo then
                local info = { GetLootSourceInfo(slot) }
                for i = 1, #info, 2 do guids[#guids + 1] = info[i] end
            end
            if #guids == 0 and Q.corpse then guids = Q.corpse.guids end
            if Remember(guids, item) then learned = true end
        end
    end
    return learned
end

-- "Recibes botín: [Piel de lobo]." (si el botín rápido ya vació la ventana).
function Q.LearnFromChat(message)
    message = Readable(message)
    if type(message) ~= "string" or not Q.corpse or GetTime() - Q.corpse.time > 10 then return false end
    -- Solo lo que recibes tú: el mensaje empieza como LOOT_ITEM_SELF.
    local prefix = LOOT_ITEM_SELF and LOOT_ITEM_SELF:match("^(.-)%%s")
    if prefix and message:sub(1, #prefix) ~= prefix then return false end
    local item = message:match("%[(.-)%]")
    if not item then return false end
    item = item:lower()
    if not Q.items[item] then return false end
    return Remember(Q.corpse.guids, item)
end

---------------------------------------------------------------------------
-- /bui placas misiones
---------------------------------------------------------------------------
function Q.Diagnose()
    Q.Scan()
    ns.Print("placas: misiones")
    print(string.format("  registro (API %s): %d objetivos leídos", tostring(Q.source), #Q.seen))
    for _, o in ipairs(Q.seen) do
        print(string.format("    [%s]%s %s", o.kind, o.finished and " (hecho)" or "", o.text))
    end
    local n = 0
    for id, items in pairs(Drops()) do
        local list = {}
        for item in pairs(items) do list[#list + 1] = item end
        print(string.format("  PNJ %s suelta: %s", id, table.concat(list, ", ")))
        n = n + 1
    end
    if n == 0 then print("  aún no se ha aprendido ningún PNJ (saquea un objeto de misión)") end
    if UnitExists("target") then
        local yes, why = Q.Why("target")
        print(string.format("  tu objetivo (%s): %s · %s", tostring(Readable(UnitName("target"))),
            yes and "cuenta" or "no cuenta", why))
    else
        print("  selecciona un enemigo para ver si cuenta y por qué")
    end
end
