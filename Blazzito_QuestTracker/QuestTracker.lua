-- Blazzito_QuestTracker: el rastreador de misiones de Questie con detalles de
-- BlazzitoUI, sin reemplazar nada (Questie sigue dibujando su lista y SkillUp
-- Forever su sección de profesiones):
--  * Misión destacada en las dos direcciones: el botón de Questie delante de
--    cada misión la destaca (mapa, flecha del juego) y, al destacarla en el
--    mapa de Blizzard, también se marca en el rastreador. Son opciones de
--    Questie que solo se activan.
--  * Ese botón pasa a ser una casilla de BlazzitoUI: vacía, o marcada en azul
--    cuando la misión está destacada (borde verde si ya está completada).
--  * Las secciones con el estilo del rastreador de Blizzard que se colocan
--    bajo Questie ("Componentes de profesión" de SkillUp Forever...) toman la
--    letra, los tamaños, los colores y las sangrías de Questie.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret = M.IsSecret

local QT = ns.NewModule("QuestTracker", "Rastreador de misiones", {
    followMap = true,      -- destacar en el mapa = destacar en el rastreador
    checkboxes = true,     -- casillas de BlazzitoUI en lugar de los iconos de Questie
    matchSections = true,  -- secciones de otros addons con el estilo de Questie
    rowHighlight = true,   -- franja de color en la misión destacada y en las completadas
    distance = true,       -- (125m) junto al nombre: distancia al objetivo más cercano
    positions = {},
})
ns.QuestTracker = QT

local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local function Hold(region, hide)
    if type(region) ~= "table" or not region.SetAlpha then return end
    if hide then
        held[region] = true
        if not hooked[region] then
            hooked[region] = true
            hooksecurefunc(region, "SetAlpha", function(self, alpha)
                if held[self] and (IsSecret(alpha) or alpha ~= 0) then self:SetAlpha(0) end
            end)
        end
        region:SetAlpha(0)
    elseif held[region] then
        held[region] = nil
        region:SetAlpha(1)
    end
end

local function Questie() return _G.Questie end
local function QuestieModule(name)
    local loader = _G.QuestieLoader
    if not (loader and loader.ImportModule) then return nil end
    local ok, module = pcall(loader.ImportModule, loader, name)
    return ok and module or nil
end

---------------------------------------------------------------------------
-- Opciones de Questie
---------------------------------------------------------------------------
function QT.ApplyQuestie()
    local q = Questie()
    local profile = q and q.db and q.db.profile
    if not profile then return false end
    local changed = false
    if profile.trackerShowQuestFocusButtons ~= true then
        profile.trackerShowQuestFocusButtons = true
        changed = true
    end
    local follow = QT.db.followMap and true or false
    if profile.trackerFollowSuperTracking ~= follow then
        profile.trackerFollowSuperTracking = follow
        changed = true
    end
    if changed then
        local tracker = QuestieModule("QuestieTracker")
        if tracker and tracker.Update then pcall(tracker.Update, tracker) end
    end
    return true
end

---------------------------------------------------------------------------
-- Casillas en lugar de los iconos de destacar de Questie
---------------------------------------------------------------------------
local boxes = setmetatable({}, { __mode = "k" })
QT.boxes = boxes

-- Franja de fondo en la fila de la misión: azul si está destacada, verde si
-- está completada (para que se vea de un vistazo).
local function PaintRow(button, d)
    local line = button:GetParent()
    if not (line and line.CreateTexture) then return end
    if not d.row then
        d.row = line:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.row:SetTexture(M.TEXTURE)
        d.row:SetGradient("HORIZONTAL", CreateColor and CreateColor(1, 1, 1, 1) or { r = 1, g = 1, b = 1, a = 1 },
            CreateColor and CreateColor(1, 1, 1, 0) or { r = 1, g = 1, b = 1, a = 0 })
    end
    d.row:ClearAllPoints()
    d.row:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    d.row:SetPoint("BOTTOM", line, "BOTTOM", 0, 0)
    d.row:SetWidth(math.max(60, (line:GetWidth() or 200) + 20))
    local visible = button:IsShown() and QT.db.rowHighlight
    if visible and d.focused then
        local a = M.COLORS.accent
        d.row:SetVertexColor(a[1], a[2], a[3], 0.28)
        d.row:Show()
    elseif visible and d.complete then
        d.row:SetVertexColor(0.3, 0.9, 0.35, 0.22)
        d.row:Show()
    else
        d.row:Hide()
    end
end

local function PaintBox(button)
    local d = boxes[button]
    if not d then return end
    pcall(PaintRow, button, d)
    local on = QT.db.checkboxes
    d.border:SetShown(on); d.fill:SetShown(on)
    d.check:SetShown(on and d.focused)
    Hold(button.GetNormalTexture and button:GetNormalTexture(), on)
    Hold(button.GetHighlightTexture and button:GetHighlightTexture(), on)
    if not on then return end
    local a = M.COLORS.accent
    if d.complete then d.border:SetColorTexture(0.3, 0.85, 0.35, 1) else d.border:SetColorTexture(0.55, 0.55, 0.6, 1) end
    if d.focused then
        d.fill:SetColorTexture(a[1], a[2], a[3], 0.9)
    elseif d.complete then
        d.fill:SetColorTexture(0.12, 0.35, 0.14, 0.9)   -- completada: verde oscuro, se distingue sin destacarla
    else
        d.fill:SetColorTexture(0.06, 0.06, 0.07, 0.85)
    end
end

local function StyleFocusButton(button)
    if boxes[button] then return end
    local d = {}
    d.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.border:SetPoint("TOPLEFT", 1, -1)
    d.border:SetPoint("BOTTOMRIGHT", -1, 1)
    d.fill = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.fill:SetPoint("TOPLEFT", d.border, "TOPLEFT", 1, -1)
    d.fill:SetPoint("BOTTOMRIGHT", d.border, "BOTTOMRIGHT", -1, 1)
    d.check = button:CreateTexture(nil, "OVERLAY", nil, 7)
    d.check:SetTexture(M.ICONS.check)
    d.check:SetPoint("TOPLEFT", d.border, "TOPLEFT", 1, -1)
    d.check:SetPoint("BOTTOMRIGHT", d.border, "BOTTOMRIGHT", -1, 1)
    d.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 7)
    d.hover:SetAllPoints(d.border)
    d.hover:SetColorTexture(1, 1, 1, 0.12)
    boxes[button] = d
    -- Questie pone el icono según el estado (destacada o no, completada o no):
    -- de esa textura se lee el estado para pintar la casilla.
    hooksecurefunc(button, "SetNormalTexture", function(self, texture)
        local state = boxes[self]
        if not state or type(texture) ~= "string" then return end
        local lower = texture:lower()
        state.focused = lower:find("focused", 1, true) ~= nil
        state.complete = lower:find("complete", 1, true) ~= nil and lower:find("incomplete", 1, true) == nil
        PaintBox(self)
    end)
    PaintBox(button)
end

function QT.ScanFocusButtons()
    for i = 1, 500 do
        local button = _G["linePool.questFocus" .. i]
        if not button then break end
        StyleFocusButton(button)
        PaintBox(button)
    end
end

---------------------------------------------------------------------------
-- Secciones de otros addons con el estilo de Questie
---------------------------------------------------------------------------
local function QuestieFont(kind)
    local q = Questie()
    local profile = q and q.db and q.db.profile
    local size = profile and profile["trackerFontSize" .. kind] or 10
    local name = profile and profile["trackerFont" .. kind]
    local outline = profile and profile.trackerFontOutline or ""
    local file = M.FONT
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM and name then
        local ok, fetched = pcall(LSM.Fetch, LSM, "font", name)
        if ok and fetched then file = fetched end
    end
    return file, size, outline
end
QT.QuestieFont = QuestieFont

-- Sangrías de Questie: zona, título de misión y objetivos (en píxeles desde
-- el borde izquierdo de su lista).
local function QuestieMargins()
    local layout = QuestieModule("TrackerLayout")
    if layout and layout.GetMargins then
        local ok, margins = pcall(layout.GetMargins)
        if ok and type(margins) == "table" then
            local left = margins.left or 0
            return left, left + (margins.quest or 0), left + (margins.objective or 0)
        end
    end
    return 0, 14, 24
end

-- Las secciones colocadas bajo Questie (su columna compartida o SkillUp).
local function Sections()
    local list, seen = {}, {}
    local function Add(frame)
        if type(frame) == "table" and type(frame.Header) == "table" and not seen[frame] then
            seen[frame] = true
            list[#list + 1] = frame
        end
    end
    Add(_G.SkillUpForeverObjectiveTracker)
    local host = _G.ForeverTrackerCompanion
    if type(host) == "table" and host.GetChildren then
        for _, child in ipairs({ host:GetChildren() }) do Add(child) end
    end
    return list
end
QT.Sections = Sections

-- Pone una cadena de texto a la sangría de Questie (en coordenadas de pantalla).
local function AlignLeft(fs, frame, targetLeft)
    if not (fs and frame and targetLeft) then return end
    local left = frame:GetLeft()
    if not left or IsSecret(left) then return end
    local count = fs:GetNumPoints() or 0
    if count == 0 then return end
    local points = {}
    for i = 1, count do points[i] = { fs:GetPoint(i) } end
    -- Solo se mueve el primer anclaje (el izquierdo); los demás se conservan
    -- (p. ej. el derecho, que da el ancho y el ajuste de línea).
    local first = points[1]
    local x = targetLeft - left
    if first[4] == x then return end
    fs:ClearAllPoints()
    fs:SetPoint(first[1], first[2] or frame, first[3] or first[1], x, first[5] or 0)
    for i = 2, #points do
        local p = points[i]
        fs:SetPoint(p[1], p[2], p[3], p[4], p[5])
    end
end

local function Blocks(module)
    local list = {}
    local function Walk(frame, depth)
        if depth > 4 then return end
        for _, child in ipairs({ frame:GetChildren() }) do
            if type(child.HeaderText) == "table" then list[#list + 1] = child end
            Walk(child, depth + 1)
        end
    end
    pcall(Walk, module, 0)
    return list
end

local function Lines(block)
    local list = {}
    for _, child in ipairs({ block:GetChildren() }) do
        if type(child.Text) == "table" and child.Text.SetFont then list[#list + 1] = child end
    end
    return list
end

function QT.StyleSections()
    if not QT.db.matchSections then return end
    local base = _G.Questie_BaseFrame
    local baseLeft = base and base:IsShown() and base:GetLeft()
    if IsSecret(baseLeft) then baseLeft = nil end
    local zoneX, questX, objectiveX = QuestieMargins()
    local zoneFont, zoneSize, outline = QuestieFont("Zone")
    local questFont, questSize = QuestieFont("Quest")
    local objFont, objSize = QuestieFont("Objective")
    for _, module in ipairs(Sections()) do
        local header = module.Header
        -- Cabecera como las zonas de Questie: sin fondo ni línea, letra de zona.
        for _, region in ipairs({ header:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "Texture" then Hold(region, true) end
        end
        Hold(header.Background, true)
        if type(header.Text) == "table" then
            header.Text:SetFont(zoneFont, zoneSize, outline)
            header.Text:SetTextColor(0.9, 0.9, 0.9)
            if baseLeft then AlignLeft(header.Text, header, baseLeft + zoneX) end
        end
        for _, block in ipairs(Blocks(module)) do
            block.HeaderText:SetFont(questFont, questSize, outline)
            if baseLeft then AlignLeft(block.HeaderText, block, baseLeft + questX) end
            for _, line in ipairs(Lines(block)) do
                line.Text:SetFont(objFont, objSize, outline)
                if type(line.Dash) == "table" and line.Dash.SetFont then
                    line.Dash:SetFont(objFont, objSize, outline)
                    if baseLeft then AlignLeft(line.Dash, line, baseLeft + objectiveX - 8) end
                elseif baseLeft then
                    AlignLeft(line.Text, line, baseLeft + objectiveX)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Distancia junto al nombre de cada misión: (125m). La calcula Questie con
-- sus datos (objetivo pendiente más cercano o, si está completada, quien la
-- entrega); si Questie no conoce la misión, la del juego. En yardas, que el
-- cliente en español muestra como "m".
---------------------------------------------------------------------------
local FAR = 50000

function QT.Distance(button)
    local questId = button.questId
    if type(questId) ~= "number" then return nil end
    local utils = QuestieModule("DistanceUtils")
    local quest = button.expectedQuest
    if not quest then
        local db = QuestieModule("QuestieDB")
        if db and db.GetQuest then
            local ok, q = pcall(db.GetQuest, questId)
            if ok then quest = q end
        end
    end
    if utils and utils.GetNearestSpawnForQuest and quest then
        local ok, _, _, _, distance = pcall(utils.GetNearestSpawnForQuest, quest)
        if ok and type(distance) == "number" and distance < FAR then return distance end
    end
    if C_QuestLog and C_QuestLog.GetDistanceSqToQuest then
        local ok, distSq, onContinent = pcall(C_QuestLog.GetDistanceSqToQuest, questId)
        if ok and type(distSq) == "number" and not IsSecret(distSq) and onContinent ~= false then
            local distance = math.sqrt(distSq)
            if distance < FAR then return distance end
        end
    end
    return nil
end

function QT.FormatDistance(distance)
    if distance >= 1000 then return string.format("(%.1fkm)", distance / 1000) end
    return string.format("(%dm)", math.floor(distance + 0.5))
end

function QT.UpdateDistances()
    for button, d in pairs(boxes) do
        local line = button:GetParent()
        local label = line and type(line.label) == "table" and line.label
        if label and not d.distance then
            d.distance = line:CreateFontString(nil, "OVERLAY")
        end
        local distance = QT.db.distance and button:IsShown() and label and QT.Distance(button)
        if distance and d.distance then
            local font, size, outline = QuestieFont("Quest")
            d.distance:SetFont(font, math.max(8, size - 1), outline)
            d.distance:SetTextColor(0.55, 0.75, 0.85)
            d.distance:SetText(QT.FormatDistance(distance))
            -- Justo detrás del nombre (o al final de la línea si el nombre la llena).
            local textWidth = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth()
            local width = label:GetWidth() or textWidth
            d.distance:ClearAllPoints()
            d.distance:SetPoint("TOPLEFT", label, "TOPLEFT", math.min(textWidth, width) + 4, 0)
            d.distance:Show()
        elseif d.distance then
            d.distance:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- Tamaño y posición: en los datos del propio Questie (TrackerWidth,
-- TrackerHeight y TrackerLocation), así Questie los respeta siempre.
---------------------------------------------------------------------------
local function Profile()
    local q = Questie()
    return q and q.db and q.db.profile
end

-- 0 = automático (Questie ajusta al contenido).
function QT.SetSize(width, height)
    local profile = Profile()
    if not profile then return false end
    if width then profile.TrackerWidth = width end
    if height then profile.TrackerHeight = height end
    local tracker = QuestieModule("QuestieTracker")
    if tracker and tracker.Update then pcall(tracker.Update, tracker) end
    return true
end

function QT.GetSize()
    local profile = Profile()
    return profile and profile.TrackerWidth or 0, profile and profile.TrackerHeight or 0
end

-- Posición guardada por el modo mover -> TrackerLocation de Questie.
function QT.SyncLocation(position)
    local profile = Profile()
    if not (profile and position) then return end
    profile.TrackerLocation = { position[1], "UIParent", position[2], position[3], position[4] }
end

function QT.RegisterMover()
    local base = _G.Questie_BaseFrame
    if QT.mover or not (base and ns.Movers) then return end
    local left, top = base:GetLeft(), base:GetTop()
    if not left or not top or IsSecret(left) or IsSecret(top) then return end
    -- Por defecto, donde Questie ya lo tiene (no salta al registrarlo).
    local default = { "TOPLEFT", "CENTER", math.floor(left - UIParent:GetWidth() / 2 + 0.5), math.floor(top - UIParent:GetHeight() / 2 + 0.5) }
    local backing = QT.db.positions
    local store = setmetatable({}, {
        __index = backing,
        __newindex = function(_, key, value)
            backing[key] = value
            QT.SyncLocation(value or default)
        end,
    })
    QT.mover = ns.Movers.Register(base, "questtracker", "Rastreador de misiones", default, store, {
        getSize = function()
            local w, h = base:GetWidth(), base:GetHeight()
            return math.floor((w or 0) + 0.5), math.floor((h or 0) + 0.5)
        end,
        setSize = function(w, h)
            QT.SetSize(math.max(150, math.min(700, w)), math.max(80, math.min(1000, h)))
        end,
    })
    -- Si el modo mover ya estaba abierto, se reabre para que aparezca su recuadro.
    if ns.Movers.unlocked then
        ns.Movers.Lock()
        ns.Movers.Unlock()
    end
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function QT.ApplyAll()
    if not QT.db then return end
    QT.ApplyQuestie()
    QT.ScanFocusButtons()
    QT.StyleSections()
end

function QT:OnEnable()
    -- Questie y SkillUp se preparan tras entrar al mundo: se aplica entonces.
    ns.On("PLAYER_ENTERING_WORLD", function()
        if QT.active then
            C_Timer.After(2, QT.ApplyAll)
            C_Timer.After(3, QT.RegisterMover)
        end
    end)
    local clock = CreateFrame("Frame")
    local waited = 0
    clock:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < 0.5 then return end
        waited = 0
        if not QT.active then return end
        pcall(QT.ScanFocusButtons)
        pcall(QT.StyleSections)
        pcall(QT.UpdateDistances)
        -- Questie monta su rastreador varios segundos después de entrar: se
        -- reintenta hasta que exista para que salga en el modo mover.
        if not QT.mover and not InCombatLockdown() then pcall(QT.RegisterMover) end
    end)
    QT.ApplyAll()
    ns.RegisterCommand("misiones", function()
        ns.Print("rastreador de misiones:")
        local q = Questie()
        local profile = q and q.db and q.db.profile
        print("  Questie: " .. (profile and "sí" or "no está cargado"))
        if profile then
            print("  botones de destacar: " .. tostring(profile.trackerShowQuestFocusButtons) ..
                  " · seguir el mapa: " .. tostring(profile.trackerFollowSuperTracking))
        end
        local count = 0
        for _ in pairs(boxes) do count = count + 1 end
        print("  casillas con estilo: " .. count)
        local names = {}
        for _, module in ipairs(Sections()) do names[#names + 1] = module:GetName() or "(sin nombre)" end
        print("  secciones bajo Questie: " .. (#names > 0 and table.concat(names, ", ") or "ninguna"))
    end, "estado del rastreador de misiones")
end
