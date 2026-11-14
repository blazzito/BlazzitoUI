-- Panel de la mascota pegado debajo de la ventana de personaje.
--
-- Todo lo de la pestaña "Mascota" de un vistazo, sin cambiar de pestaña:
-- modelo (se gira arrastrando), nombre, nivel y familia, felicidad, lealtad,
-- vida, foco, experiencia, atributos, armadura, ataque, resistencias, dieta
-- y puntos de adiestramiento. Los datos son los de Blizzard; el panel es
-- nuestro y va colgado de la ventana, así que se abre y se cierra con ella
-- (y se mueve con ella si la mueves con BlizzMove).
--
-- La vista "Mascota" de Blizzard (botón de arriba del panel derecho o
-- pestaña de abajo, según el cliente) se puede ocultar: queda en el juego,
-- solo deja de verse. Su icono de felicidad se muda junto al nombre.
local ns = BlazzitoUI
if not (ns and ns.Windows and ns.Windows.Character) then return end

local Win, M, C = ns.Windows, ns.Media, ns.Windows.Character
local Readable = M.Readable

local P = {}
Win.Pet = P

local HEIGHT, MODEL = 186, 150
local function Opts() return Win.db.pet end

local function Pack(...) return { n = select("#", ...), ... } end
-- Llama a una función del juego si existe, sin dejar que un error la corte.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local res = Pack(pcall(fn, ...))
    if not res[1] then return nil end
    return unpack(res, 2, res.n)
end
local function Num(v)
    v = Readable(v)
    return type(v) == "number" and v or nil
end
P.Call, P.Num = Call, Num

-- Forever tiene estas funciones en C_PetInfo; el clásico, sueltas.
local function PetAPI(name)
    local fn = C_PetInfo and C_PetInfo[name]
    if type(fn) == "function" then return fn end
    return _G[name]
end
P.PetAPI = PetAPI

-- Los nombres son los de Blizzard (PET_HAPPINESS1..3) si existen.
local HAPPINESS = {
    [1] = { "Infeliz", 1, 0.3, 0.3 },
    [2] = { "Contenta", 1, 0.82, 0.25 },
    [3] = { "Feliz", 0.3, 0.95, 0.4 },
}
local STATS = { "Fuerza", "Agilidad", "Aguante", "Intelecto", "Espíritu" }
local SCHOOLS = {
    { 2, "Fuego", "ff7333" }, { 3, "Naturaleza", "4cf266" }, { 4, "Escarcha", "73bfff" },
    { 5, "Sombras", "b373ff" }, { 6, "Arcano", "f2e6ff" },
}

local function Hex(r, g, b) return string.format("%02x%02x%02x", r * 255, g * 255, b * 255) end
local function Cell(label, value)
    return "|cffa0a0a8" .. label .. "|r  " .. (value ~= nil and tostring(value) or "|cff666666—|r")
end

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------
function P.Info()
    local info = {}
    info.level = Num(UnitLevel("pet"))
    info.family = Readable(Call(UnitCreatureFamily, "pet"))
    local happiness, damage = Call(PetAPI("GetPetHappiness"))
    happiness, damage = Num(happiness), Num(damage)
    if happiness and HAPPINESS[happiness] then
        local h = HAPPINESS[happiness]
        local label = _G["PET_HAPPINESS" .. happiness]
        info.happiness = { type(label) == "string" and label or h[1], h[2], h[3], h[4] }
        info.damage = damage
    end
    info.loyalty = Readable(Call(PetAPI("GetPetLoyalty")))
    local xp, xpMax = Call(PetAPI("GetPetExperience"))
    info.xp, info.xpMax = Num(xp), Num(xpMax)
    local total, spent = Call(PetAPI("GetPetTrainingPoints"))
    total, spent = Num(total), Num(spent)
    if total and total > 0 then info.training = total - (spent or 0) end
    local foods = Pack(Call(PetAPI("GetPetFoodTypes")))
    local list = {}
    for i = 1, foods.n do
        local food = Readable(foods[i])
        if type(food) == "string" and food ~= "" then list[#list + 1] = food end
    end
    info.diet = #list > 0 and table.concat(list, ", ") or nil
    info.stats = {}
    for i = 1, 5 do
        local _, effective = Call(UnitStat, "pet", i)
        info.stats[i] = Num(effective)
    end
    local _, armor = Call(UnitArmor, "pet")
    info.armor = Num(armor)
    local base, pos, neg = Call(UnitAttackPower, "pet")
    base, pos, neg = Num(base), Num(pos), Num(neg)
    if base then info.attack = base + (pos or 0) + (neg or 0) end
    local low, high = Call(UnitDamage, "pet")
    low, high = Num(low), Num(high)
    if low and high then info.hit = string.format("%d - %d", math.floor(low), math.floor(high + 0.5)) end
    local speed = Num(Call(UnitAttackSpeed, "pet"))
    if speed then info.speed = string.format("%.2f s", speed) end
    info.resist = {}
    for i, school in ipairs(SCHOOLS) do
        local _, totalRes = Call(UnitResistance, "pet", school[1])
        info.resist[i] = Num(totalRes)
    end
    return info
end

---------------------------------------------------------------------------
-- El panel
---------------------------------------------------------------------------
local panel

local function Bar(parent, height)
    local bar = M.StatusBar(parent)
    bar:SetHeight(height)
    local px = M.PixelSize()
    local edge = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
    edge:SetPoint("TOPLEFT", -px, px)
    edge:SetPoint("BOTTOMRIGHT", px, -px)
    edge:SetColorTexture(0, 0, 0, 1)
    return bar
end

function P.Build(cf)
    if panel then return panel end
    panel = Win.Own(CreateFrame("Frame", "BlazzitoUICharacterPet", cf))
    panel:SetHeight(HEIGHT)
    panel:EnableMouse(true)
    P.panel = panel
    local px = M.PixelSize()
    panel.border = panel:CreateTexture(nil, "BACKGROUND", nil, -8)
    panel.border:SetAllPoints()
    panel.border:SetColorTexture(0, 0, 0, 1)
    panel.fill = panel:CreateTexture(nil, "BACKGROUND", nil, -7)
    panel.fill:SetPoint("TOPLEFT", px, -px)
    panel.fill:SetPoint("BOTTOMRIGHT", -px, px)
    panel.line = panel:CreateTexture(nil, "ARTWORK")
    panel.line:SetPoint("TOPLEFT", px, -px)
    panel.line:SetPoint("TOPRIGHT", -px, -px)
    panel.line:SetHeight(2 * px)

    -- Modelo con su fondo de degradado; se gira arrastrando con el ratón.
    panel.modelBg = panel:CreateTexture(nil, "BACKGROUND", nil, -6)
    panel.modelBg:SetPoint("TOPLEFT", 8, -8)
    panel.modelBg:SetSize(MODEL, HEIGHT - 16)
    local model = CreateFrame("PlayerModel", nil, panel)
    model:SetAllPoints(panel.modelBg)
    model:EnableMouse(true)
    model:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and Opts().rotate and GetCursorPosition then self.dragX = GetCursorPosition() end
    end)
    model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
    model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = GetCursorPosition()
        self.facing = (self.facing or 0) + (x - self.dragX) * 0.015
        self.dragX = x
        self:SetFacing(self.facing)
    end)
    panel.model = model
    panel.tag = M.Font(model, 10)
    panel.tag:SetPoint("TOPLEFT", panel.modelBg, "TOPLEFT", 5, -4)
    panel.tag:SetText("MASCOTA")

    local x = MODEL + 20
    panel.name = M.Font(panel, 15)
    panel.name:SetPoint("TOPLEFT", x, -10)
    panel.happy = M.Font(panel, 11, "RIGHT")
    panel.happy:SetPoint("TOPRIGHT", -10, -13)
    panel.sub = M.Font(panel, 11)
    panel.sub:SetPoint("TOPLEFT", panel.name, "BOTTOMLEFT", 0, -4)
    panel.sub:SetTextColor(0.75, 0.75, 0.8)

    panel.health = Bar(panel, 13)
    panel.health:SetPoint("TOPLEFT", x, -50)
    panel.health:SetPoint("TOPRIGHT", -10, -50)
    panel.healthText = M.Font(panel.health, 10, "CENTER")
    panel.healthText:SetPoint("CENTER")
    panel.power = Bar(panel, 6)
    panel.power:SetPoint("TOPLEFT", panel.health, "BOTTOMLEFT", 0, -3)
    panel.power:SetPoint("TOPRIGHT", panel.health, "BOTTOMRIGHT", 0, -3)
    panel.xp = Bar(panel, 6)
    panel.xp:SetPoint("TOPLEFT", panel.power, "BOTTOMLEFT", 0, -3)
    panel.xp:SetPoint("TOPRIGHT", panel.power, "BOTTOMRIGHT", 0, -3)
    M.ColorBar(panel.xp, 0.58, 0.3, 0.85)
    panel.xpText = M.Font(panel, 10)
    panel.xpText:SetPoint("TOPLEFT", panel.xp, "BOTTOMLEFT", 0, -3)
    panel.xpText:SetTextColor(0.75, 0.75, 0.8)
    panel.training = M.Font(panel, 10, "RIGHT")
    panel.training:SetPoint("TOPRIGHT", panel.xp, "BOTTOMRIGHT", 0, -3)

    -- Rejilla de 3 columnas: atributos, armadura, ataque, daño y velocidad.
    panel.cells = {}
    for i = 1, 9 do panel.cells[i] = M.Font(panel, 11) end
    panel.resist = M.Font(panel, 10)
    panel.diet = M.Font(panel, 10)
    panel.diet:SetTextColor(0.75, 0.75, 0.8)
    panel:SetScript("OnSizeChanged", function() P.Layout() end)
    panel:SetScript("OnShow", function(self)
        self.model:SetUnit("pet")
        P.Update()
    end)
    return panel
end

function P.Layout()
    if not panel then return end
    local width = Num(panel:GetWidth()) or 540
    local x = MODEL + 20
    local colW = math.max(80, (width - x - 10) / 3)
    for i, cell in ipairs(panel.cells) do
        local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", panel, "TOPLEFT", x + col * colW, -100 - row * 16)
        cell:SetWidth(colW - 6)
    end
    panel.resist:ClearAllPoints()
    panel.resist:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -152)
    panel.resist:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    panel.diet:ClearAllPoints()
    panel.diet:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -168)
    panel.diet:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
end

-- Justo debajo de las pestañas (las de Blizzard cuelgan bajo la ventana).
function P.Place(cf)
    local gap = 30
    local tab = Win.Tabs(cf)[1]
    if tab then
        local tb, fb = Num(tab:GetBottom()), Num(cf:GetBottom())
        if tb and fb then gap = math.max(0, fb - tb) end
    end
    local y = -(math.max(0, gap - 4) + 3)
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", cf, "BOTTOMLEFT", 0, y)
    panel:SetPoint("TOPRIGHT", cf, "BOTTOMRIGHT", 0, y)
end

function P.Wanted()
    return Win.active and Win.PackOn(C.pack) and Opts().enabled and UnitExists("pet") and true or false
end

function P.Update()
    if not panel then return end
    local show = P.Wanted()
    panel:SetShown(show)
    if not show then return end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.6, 0.6, 0.65 end
    panel.fill:SetColorTexture(0.06, 0.06, 0.07, (Win.db.background or 92) / 100)
    panel.line:SetColorTexture(r, g, b, 0.9)
    panel.modelBg:SetColorTexture(1, 1, 1, 1)
    if panel.modelBg.SetGradient and CreateColor then
        pcall(panel.modelBg.SetGradient, panel.modelBg, "VERTICAL", CreateColor(r * 0.3, g * 0.3, b * 0.3, 0.85), CreateColor(0.03, 0.03, 0.04, 0.6))
    end
    panel.tag:SetTextColor(r, g, b)

    local info = P.Info()
    panel.name:SetText(UnitName("pet") or "")
    local sub = {}
    if info.level then sub[#sub + 1] = "Nivel " .. info.level end
    if type(info.family) == "string" then sub[#sub + 1] = info.family end
    if type(info.loyalty) == "string" and info.loyalty ~= "" then sub[#sub + 1] = info.loyalty end
    panel.sub:SetText(table.concat(sub, "  ·  "))
    if info.happiness then
        local h = info.happiness
        local dot = string.format("|T%s:9:9:0:0:64:64:0:64:0:64:%d:%d:%d|t", M.ICONS.circle,
            math.floor(h[2] * 255 + 0.5), math.floor(h[3] * 255 + 0.5), math.floor(h[4] * 255 + 0.5))
        local text = dot .. "  |cff" .. Hex(h[2], h[3], h[4]) .. h[1] .. "|r"
        if info.damage then text = text .. string.format("  |cffa0a0a8·  %d%% de daño|r", info.damage) end
        panel.happy:SetText(text)
        panel.happy:Show()
    else
        panel.happy:Hide()
    end

    -- Vida y recurso: valores directos a la barra (sirven aunque sean secretos).
    panel.health:SetMinMaxValues(0, UnitHealthMax("pet") or 1)
    panel.health:SetValue(UnitHealth("pet") or 0)
    M.ColorBar(panel.health, 0.3, 0.75, 0.4)
    panel.healthText:SetFormattedText("%s / %s", M.ShortValue(UnitHealth("pet") or 0), M.ShortValue(UnitHealthMax("pet") or 0))
    local _, token = UnitPowerType("pet")
    local pc = token and PowerBarColor and PowerBarColor[token]
    panel.power:SetMinMaxValues(0, UnitPowerMax("pet") or 1)
    panel.power:SetValue(UnitPower("pet") or 0)
    if pc then M.ColorBar(panel.power, pc.r, pc.g, pc.b) else M.ColorBar(panel.power, 1, 0.5, 0.25) end

    if info.xp and info.xpMax and info.xpMax > 0 then
        panel.xp:SetMinMaxValues(0, info.xpMax)
        panel.xp:SetValue(info.xp)
        panel.xp:Show()
        panel.xpText:SetText(string.format("Experiencia %d%%  |cff666666(%s / %s)|r", math.floor(info.xp / info.xpMax * 100),
            M.ShortValue(info.xp), M.ShortValue(info.xpMax)))
    else
        panel.xp:Hide()
        panel.xpText:SetText("")
    end
    if info.training then
        panel.training:SetText("Adiestramiento |cffffffff" .. info.training .. "|r libres")
        panel.training:SetTextColor(0.75, 0.75, 0.8)
        panel.training:Show()
    else
        panel.training:Hide()
    end

    local values = {
        Cell(STATS[1], info.stats[1]), Cell(STATS[2], info.stats[2]), Cell(STATS[3], info.stats[3]),
        Cell(STATS[4], info.stats[4]), Cell(STATS[5], info.stats[5]), Cell("Armadura", info.armor),
        Cell("Poder de ataque", info.attack), Cell("Daño", info.hit), Cell("Velocidad", info.speed),
    }
    for i, cell in ipairs(panel.cells) do
        cell:SetText(values[i])
        cell:SetTextColor(1, 1, 1)
    end
    local res = {}
    for i, school in ipairs(SCHOOLS) do
        res[#res + 1] = "|cff" .. school[3] .. school[2] .. "|r " .. (info.resist[i] or 0)
    end
    panel.resist:SetText("|cffa0a0a8Resistencias|r   " .. table.concat(res, "   "))
    if info.diet then panel.diet:SetText("|cffa0a0a8Come|r  " .. info.diet); panel.diet:Show() else panel.diet:Hide() end
end

---------------------------------------------------------------------------
-- La pestaña y el botón "Mascota" de Blizzard
---------------------------------------------------------------------------
local moved = setmetatable({}, { __mode = "k" })    -- pestaña desplazada -> sus anclajes originales
local hiddenTab, hiddenSide

local function IsPetName(text)
    text = Readable(text)
    if type(text) ~= "string" then return false end
    local low = text:lower()
    return (PET and text == PET) or low == "mascota" or low == "pet"
end

-- Pestaña de abajo (en clientes que la tienen ahí).
function P.FindPetTab(cf)
    for _, tab in ipairs(Win.Tabs(cf)) do
        local text = Win.Child(tab, "Text", "Text")
        if text and text.GetText and IsPetName(text:GetText()) then return tab end
    end
    return nil
end

-- Botón de la fila de arriba del panel derecho (Personaje, Títulos,
-- Equipo... y Mascota). Se busca en la lista de Blizzard.
function P.FindPetSidebar()
    local list = _G.PAPERDOLL_SIDEBARS
    if type(list) ~= "table" then return nil end
    for i, info in ipairs(list) do
        if type(info) == "table" then
            local frame = Readable(info.frame)
            if (type(frame) == "string" and frame:find("Pet")) or IsPetName(info.name) then
                return _G["PaperDollSidebarTab" .. i], i, frame
            end
        end
    end
    return nil
end

local function Points(region)
    local list = {}
    for i = 1, (region.GetNumPoints and region:GetNumPoints()) or 0 do list[i] = { region:GetPoint(i) } end
    return list
end
P.Points = Points

local function HideWanted() return P.Wanted() and Opts().hideTab end

local function BottomTab(cf)
    local tab = P.FindPetTab(cf) or hiddenTab
    if not tab then return end
    local tabs = Win.Tabs(cf)
    local nextTab
    for i, t in ipairs(tabs) do if t == tab then nextTab = tabs[i + 1] end end
    local hide = HideWanted() and tab:IsShown()
    if hide then
        hiddenTab = tab
        Win.Hold(tab, true)
        tab:EnableMouse(false)
        if nextTab then
            if not moved[nextTab] then moved[nextTab] = Points(nextTab) end
            local point = Points(tab)[1]
            if point then
                nextTab:ClearAllPoints()
                nextTab:SetPoint(unpack(point))
            end
        end
    elseif hiddenTab == tab then
        hiddenTab = nil
        Win.Hold(tab, false)
        tab:EnableMouse(true)
        if nextTab and moved[nextTab] then
            nextTab:ClearAllPoints()
            for _, point in ipairs(moved[nextTab]) do nextTab:SetPoint(unpack(point)) end
            moved[nextTab] = nil
        end
    end
end

local function SideTab()
    local tab, _, paneName = P.FindPetSidebar()
    tab = tab or hiddenSide
    if not tab then return end
    if HideWanted() then
        hiddenSide = tab
        Win.Hold(tab, true)
        tab:EnableMouse(false)
        -- Si estaba abierta la vista de mascota, se vuelve a la del personaje.
        local pane = type(paneName) == "string" and _G[paneName]
        if pane and pane.IsShown and pane:IsShown() and PaperDollFrame_SetSidebar and _G.PaperDollSidebarTab1 then
            pcall(PaperDollFrame_SetSidebar, _G.PaperDollSidebarTab1, 1)
        end
    elseif hiddenSide == tab then
        hiddenSide = nil
        Win.Hold(tab, false)
        tab:EnableMouse(true)
    end
end

function P.TabLayout(cf)
    BottomTab(cf)
    SideTab()
    P.Happiness(cf)
end

---------------------------------------------------------------------------
-- El icono de felicidad de Blizzard, junto al nombre de la mascota
---------------------------------------------------------------------------
-- Es el de Blizzard (con su descripción al pasar el ratón: daño, lealtad,
-- dieta); solo se cambia de sitio. Al apagarlo vuelve a donde estaba.
local happyButton
local docked = setmetatable({}, { __mode = "k" })    -- botón -> { anclajes, nivel }
local pinning = false

local function LooksLikeHappiness(f)
    -- La función viene de su mixin, copiada en el propio marco.
    if type(rawget(f, "UpdateHappiness")) == "function" then return true end
    local name = f.GetName and f:GetName()
    if type(name) == "string" and (name:find("Happiness") or name:find("PetInfo")) then return true end
    for _, region in ipairs(Win.Textures(f)) do
        local file = region.GetTexture and region:GetTexture()
        if type(file) == "string" and file:lower():find("pethappiness") then return true end
    end
    return false
end

function P.FindHappiness(cf)
    if happyButton then return happyButton end
    local hit
    Win.Walk(cf, function(f)
        if hit then return false end
        if LooksLikeHappiness(f) then
            hit = f
            return false
        end
    end)
    happyButton = hit
    return hit
end

local function Pin(button)
    pinning = true
    button:ClearAllPoints()
    button:SetPoint("LEFT", panel.name, "RIGHT", 6, 0)
    button:SetFrameLevel((panel:GetFrameLevel() or 1) + 10)
    pinning = false
end

function P.Happiness(cf)
    local button = P.FindHappiness(cf)
    if not button then return end
    if panel and P.Wanted() and Opts().moveHappiness then
        if not docked[button] then
            docked[button] = { points = Points(button), level = button:GetFrameLevel() }
            if not P.happyHooked then
                P.happyHooked = true
                -- Si Blizzard lo vuelve a colocar, vuelve con nosotros.
                hooksecurefunc(button, "SetPoint", function(self)
                    if not pinning and docked[self] then Pin(self) end
                end)
            end
        end
        Pin(button)
    elseif docked[button] then
        local saved = docked[button]
        docked[button] = nil
        pinning = true
        button:ClearAllPoints()
        for _, point in ipairs(saved.points) do button:SetPoint(unpack(point)) end
        if saved.level then button:SetFrameLevel(saved.level) end
        pinning = false
    end
end

---------------------------------------------------------------------------
-- Enganche con el paquete de personaje y eventos
---------------------------------------------------------------------------
function P.Apply(cf, on)
    if on and Opts().enabled then P.Build(cf) end
    if panel then
        P.Place(cf)
        P.Layout()
        P.Update()
    end
    P.TabLayout(cf)
end

local queued = false
local function Queue()
    if queued then return end
    queued = true
    C_Timer.After(0.1, function()
        queued = false
        local cf = _G.CharacterFrame
        if not (panel and cf and cf:IsShown()) then return end
        P.Update()
        P.TabLayout(cf)
    end)
end
P.Queue = Queue

local events = CreateFrame("Frame")
for _, event in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_LEVEL",
                         "UNIT_NAME_UPDATE", "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_DAMAGE",
                         "UNIT_ATTACK_SPEED", "UNIT_HAPPINESS", "UNIT_PET_EXPERIENCE", "UNIT_PET_TRAINING_POINTS",
                         "UNIT_MODEL_CHANGED" }) do
    pcall(events.RegisterUnitEvent, events, event, "pet")
end
pcall(events.RegisterUnitEvent, events, "UNIT_PET", "player")
for _, event in ipairs({ "PET_UI_UPDATE", "PET_BAR_UPDATE", "PLAYER_ENTERING_WORLD" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if not Win.active then return end
    if (event == "UNIT_PET" or event == "UNIT_MODEL_CHANGED") and panel then panel.model:SetUnit("pet") end
    -- Mascota invocada o retirada con la ventana abierta: aparece o se va.
    if event == "UNIT_PET" and panel and _G.CharacterFrame and _G.CharacterFrame:IsShown() then
        P.Update()
        P.TabLayout(_G.CharacterFrame)
        return
    end
    Queue()
end)
