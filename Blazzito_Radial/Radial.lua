-- Menú radial: una tecla (o un botón de tu barra) abre un anillo con el menú
-- del juego, tus ventanas, tus monturas y gestos.
--
-- Todo lo que se pulsa es un botón seguro propio (SecureActionButtonTemplate)
-- con una macro ("/click CharacterMicroButton", "/dance") o un hechizo (las
-- monturas, por su nombre): funciona en combate y no toca nada de Blizzard.
-- Abrir, cerrar, cambiar de página y elegir al soltar la tecla se hace en
-- código seguro (SecureHandlerWrapScript), que también corre en combate.
--
-- La tecla:
--  * pulsar abre el anillo; pulsar otra vez (o Esc) lo cierra;
--  * mantenerla, llevar el ratón a un botón y soltar usa ese botón;
--  * un toque corto lo deja abierto para elegir con el ratón; si la mantuviste
--    y sueltas sin botón debajo, se cierra.
-- Para usar al soltar, la tecla lleva copia de la acción de cada botón con el
-- sufijo rN (type-r3, macrotext-r3...) y el código seguro devuelve "r3" como
-- botón del clic: la acción la hace la propia tecla.
local ns = BlazzitoUI
if not ns then return end
local M = ns.Media
local W = ns.Widgets

local R = ns.NewModule("Radial", "Menú radial", {
    scale = 100,          -- %
    radius = 120,         -- distancia del centro a los botones
    iconSize = 52,
    labels = true,        -- nombre bajo cada icono
    backdrop = 70,        -- opacidad del fondo (%)
    maxMounts = 10,
    shape = "circle",     -- forma de los botones (las de las barras de acción)
    border = 1,           -- grosor del borde (px)
    orbit = true,         -- línea por donde van los botones
    pointer = true,       -- arco del acento que señala el elegido
    centerIcon = true,    -- icono del elegido en el centro
    dimOthers = true,     -- atenuar los demás mientras eliges
    accentMode = "class", -- "class" o "custom"
    accent = { 0.31, 0.76, 0.97 },
    items = { menu = true, character = true, spellbook = true, talents = true, professions = true,
              mounts = true, emotes = true, quests = false, bags = false, map = false },
    emotes = { dance = true, sit = true, wave = true, bow = true, laugh = true, cheer = true, applaud = true,
               roar = true, kneel = false, sleep = false, thank = false, hello = false, flex = false,
               cry = false, kiss = false, chicken = false, salute = false, point = false },
    positions = {},
})
ns.Radial = R

local MEDIA = "Interface\\AddOns\\Blazzito_Radial\\Media\\"
local ICON = "Interface\\Icons\\"
R.MEDIA = MEDIA
R.BINDING = "CLICK BlazzitoUIRadialKey:LeftButton"
R.MACRO_NAME = "BUI Radial"
R.MACRO_BODY = "/click BlazzitoUIRadialKey Tap"
R.MACRO_ICON = ICON .. "Ability_Hunter_Pathfinding"
R.PAGES = { "root", "emotes", "mounts" }
R.PAGE_TITLES = { root = "BlazzitoUI", emotes = "Gestos", mounts = "Monturas" }

local function Tr(s) return ns.Translate and ns.Translate(s) or s end
local function Combat() return InCombatLockdown and InCombatLockdown() end

-- Nombres de la lista de teclas de Blizzard (Opciones > Atajos > AddOns).
BINDING_HEADER_BLAZZITOUI = "BlazzitoUI"
_G["BINDING_NAME_" .. R.BINDING] = "Menú radial (mantener y soltar)"

---------------------------------------------------------------------------
-- Catálogo
---------------------------------------------------------------------------
-- Macro "/click" sobre el primer botón de Blizzard que exista (nil si ninguno).
local function ClickMacro(...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        if _G[name] then return "/click " .. name end
    end
end
R.ClickMacro = ClickMacro

-- En el sentido de las agujas del reloj, empezando arriba.
R.ROOT = {
    { key = "menu", title = "Menú del juego", icon = ICON .. "INV_Misc_Gear_01",
      macro = function() return ClickMacro("MainMenuMicroButton") end },
    { key = "character", title = "Personaje", portrait = true,
      macro = function() return ClickMacro("CharacterMicroButton") end },
    { key = "spellbook", title = "Libro de hechizos", icon = ICON .. "INV_Misc_Book_09",
      macro = function() return ClickMacro("SpellbookMicroButton", "PlayerSpellsMicroButton") end },
    { key = "talents", title = "Talentos", icon = ICON .. "Ability_Marksmanship",
      macro = function() return ClickMacro("TalentMicroButton", "PlayerSpellsMicroButton") end },
    { key = "professions", title = "Profesiones", icon = ICON .. "Trade_BlackSmithing",
      macro = function() return ClickMacro("ProfessionMicroButton") end },
    { key = "mounts", title = "Monturas", icon = ICON .. "Ability_Mount_RidingHorse", sub = "mounts" },
    { key = "emotes", title = "Gestos", icon = ICON .. "Ability_Warrior_BattleShout", sub = "emotes" },
    { key = "quests", title = "Registro de misiones", icon = ICON .. "INV_Misc_Note_01",
      macro = function() return ClickMacro("QuestLogMicroButton") end },
    { key = "bags", title = "Bolsas", icon = ICON .. "INV_Misc_Bag_08",
      macro = function() return ClickMacro("MainMenuBarBackpackButton") end },
    { key = "map", title = "Mapa del mundo", icon = ICON .. "INV_Misc_Map_01",
      macro = function() return ClickMacro("WorldMapMicroButton") end },
}

-- Los comandos en inglés valen en cualquier idioma del juego.
R.EMOTES = {
    { key = "dance", cmd = "/dance", title = "Bailar" },
    { key = "sit", cmd = "/sit", title = "Sentarse" },
    { key = "wave", cmd = "/wave", title = "Saludar" },
    { key = "bow", cmd = "/bow", title = "Reverencia" },
    { key = "laugh", cmd = "/laugh", title = "Reír" },
    { key = "cheer", cmd = "/cheer", title = "Animar" },
    { key = "applaud", cmd = "/applaud", title = "Aplaudir" },
    { key = "roar", cmd = "/roar", title = "Rugir" },
    { key = "kneel", cmd = "/kneel", title = "De rodillas" },
    { key = "sleep", cmd = "/sleep", title = "Dormir" },
    { key = "thank", cmd = "/thank", title = "Gracias" },
    { key = "hello", cmd = "/hello", title = "Hola" },
    { key = "flex", cmd = "/flex", title = "Músculo" },
    { key = "cry", cmd = "/cry", title = "Llorar" },
    { key = "kiss", cmd = "/kiss", title = "Beso" },
    { key = "chicken", cmd = "/chicken", title = "Gallina" },
    { key = "salute", cmd = "/salute", title = "Firmes" },
    { key = "point", cmd = "/point", title = "Señalar" },
}

-- ¿Existe en este cliente? (los que van por "/click" necesitan su botón).
function R.Available(entry)
    if entry.sub then return true end
    return entry.macro() ~= nil
end

-- Tus monturas: primero las favoritas y luego las demás por nombre. Se montan
-- con su hechizo por el NOMBRE (por número no funciona para monturas).
function R.Mounts(max)
    local list = {}
    local J = C_MountJournal
    if not (J and J.GetMountIDs and J.GetMountInfoByID) then return list end
    local favorites, others = {}, {}
    local ok, ids = pcall(J.GetMountIDs)
    for _, id in ipairs(ok and ids or {}) do
        local name, spellID, icon, _, _, _, isFavorite, _, _, hide, isCollected = J.GetMountInfoByID(id)
        if isCollected and not hide and spellID then
            local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
            local cast = (info and info.name) or name
            if type(cast) == "string" and cast ~= "" then
                local item = { title = name or cast, spell = cast, icon = icon }
                if isFavorite then favorites[#favorites + 1] = item else others[#others + 1] = item end
            end
        end
    end
    local function byName(a, b) return tostring(a.title) < tostring(b.title) end
    table.sort(favorites, byName)
    table.sort(others, byName)
    for _, set in ipairs({ favorites, others }) do
        for _, item in ipairs(set) do
            if #list >= (max or 10) then return list end
            list[#list + 1] = item
        end
    end
    return list
end

-- Lo que sale en cada página, ya filtrado por tus ajustes.
function R.PageItems(page)
    local db, list = R.db, {}
    if page == "root" then
        for _, entry in ipairs(R.ROOT) do
            if db.items[entry.key] and R.Available(entry) then
                list[#list + 1] = { key = entry.key, title = entry.title, icon = entry.icon, portrait = entry.portrait,
                                    sub = entry.sub, macro = not entry.sub and entry.macro() or nil }
            end
        end
    elseif page == "emotes" then
        for _, entry in ipairs(R.EMOTES) do
            if db.emotes[entry.key] then
                list[#list + 1] = { key = entry.key, title = entry.title, macro = entry.cmd, textOnly = true }
            end
        end
    elseif page == "mounts" then
        local journal = ClickMacro("CollectionsMicroButton")
        if journal then
            list[#list + 1] = { key = "journal", title = "Colección de monturas", icon = ICON .. "INV_Misc_Book_08",
                                macro = journal }
        end
        for _, mount in ipairs(R.Mounts(db.maxMounts)) do
            list[#list + 1] = { key = "mount", title = mount.title, icon = mount.icon, spell = mount.spell, raw = true }
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Geometría
---------------------------------------------------------------------------
-- Radio para n botones: el de tus ajustes o más, para que no se pisen.
function R.RadiusFor(n, textOnly)
    local db = R.db
    local size = db.iconSize + (textOnly and 8 or 0)
    local gap = (db.labels and not textOnly) and 30 or 12
    return math.max(db.radius, math.ceil(n * (size + gap) / (2 * math.pi)))
end

-- Posición del botón i de n (arriba el primero, en el sentido del reloj).
function R.Position(i, n, radius)
    local angle = math.rad(90 - (i - 1) * 360 / n)
    return radius * math.cos(angle), radius * math.sin(angle)
end

---------------------------------------------------------------------------
-- Código seguro
---------------------------------------------------------------------------
-- Cambiar de página (want: nombre de una variable del fragmento).
local function SwitchCode(want)
    local lines = { "local p" }
    for _, name in ipairs(R.PAGES) do
        lines[#lines + 1] = ('p = ring:GetFrameRef("page-%s"); if %s == "%s" then p:Show() else p:Hide() end')
            :format(name, want, name)
    end
    lines[#lines + 1] = ('ring:SetAttribute("hover", nil); ring:SetAttribute("page", %s)'):format(want)
    return table.concat(lines, "\n")
end
R.SwitchCode = SwitchCode

local ON_SHOW = [[
local ring = self
local want = "root"
]] .. SwitchCode("want") .. [[

self:SetBindingClick(true, "ESCAPE", "BlazzitoUIRadialClose")
]]

local ON_HIDE = [[
self:ClearBindings()
self:SetAttribute("held", nil)
self:SetAttribute("hover", nil)
]]

-- La tecla (o la macro de la barra, que manda el botón "Tap").
local KEY_PRE = [[
local ring = owner
if button == "Tap" then
    if ring:IsShown() then ring:Hide() else ring:Show() end
    return false
end
if down then
    if ring:IsShown() then ring:Hide() return false end
    ring:Show()
    ring:SetAttribute("held", GetTime and GetTime() or 0)
    return false
end
local held = ring:GetAttribute("held")
ring:SetAttribute("held", nil)
if not held or not ring:IsShown() then return false end
local hover = ring:GetAttribute("hover")
if hover and self:GetAttribute("type-r" .. hover) then
    ring:Hide()
    return "r" .. hover
end
if GetTime and GetTime() - held > 0.35 then ring:Hide() end
return false
]]

-- Un botón del anillo: los que abren otra página no hacen nada más.
local ITEM_PRE = [[
local ring = owner
local want = self:GetAttribute("bui-sub")
if want then
]] .. SwitchCode("want") .. [[

    return false
end
]]
local ITEM_POST = [[ owner:Hide() ]]

local ITEM_ENTER = [[
local ring = owner
ring:SetAttribute("hover", self:GetAttribute("bui-slot"))
local want = self:GetAttribute("bui-sub")
if want and ring:GetAttribute("held") then
]] .. SwitchCode("want") .. [[

end
]]

local ITEM_LEAVE = [[
if owner:GetAttribute("hover") == self:GetAttribute("bui-slot") then owner:SetAttribute("hover", nil) end
]]

-- El centro: en una página de dentro vuelve atrás; en la principal, cierra.
local CENTER_PRE = [[
local ring = owner
if ring:GetAttribute("page") ~= "root" then
    local want = "root"
]] .. SwitchCode("want") .. [[

else
    ring:Hide()
end
return false
]]

R.SNIPPETS = { ON_SHOW = ON_SHOW, ON_HIDE = ON_HIDE, KEY_PRE = KEY_PRE, ITEM_PRE = ITEM_PRE, ITEM_POST = ITEM_POST,
               ITEM_ENTER = ITEM_ENTER, ITEM_LEAVE = ITEM_LEAVE, CENTER_PRE = CENTER_PRE }

---------------------------------------------------------------------------
-- Dibujo (el mismo para el anillo de verdad y para la vista previa)
---------------------------------------------------------------------------
-- Cada «vista» es un marco con fondo, borde, órbita, indicador y centro.
-- El anillo de verdad pinta según los atributos que pone el código seguro;
-- la vista previa, según el ratón. Todo son texturas: se pueden cambiar en
-- combate (los marcos seguros no se mueven ni se redimensionan).
local function Tex(parent, layer, file, sublevel)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    if file then t:SetTexture(file) end
    return t
end

local function Paint(t, c, alpha)
    t:SetVertexColor(c[1], c[2], c[3], alpha or c[4] or 1)
end

-- Color del acento: el de tu clase o el elegido.
function R.Accent()
    local db = R.db
    if db and db.accentMode == "custom" and type(db.accent) == "table" then return db.accent end
    return W.COLORS.accent
end

function R.ShapeFile()
    return M.ButtonShape(R.db.shape or "circle")
end

local function DecorateView(f)
    f.backdrop = Tex(f, "BACKGROUND", MEDIA .. "radial_disc", -8)
    f.backdrop:SetPoint("CENTER")
    f.edge = Tex(f, "BACKGROUND", MEDIA .. "radial_edge", -7)
    f.edge:SetPoint("CENTER")
    f.orbit = Tex(f, "BACKGROUND", MEDIA .. "radial_orbit", -6)
    f.orbit:SetPoint("CENTER")
    f.pointer = Tex(f, "BORDER", MEDIA .. "radial_arc", 1)
    f.pointer:SetPoint("CENTER")
    f.pointer:Hide()
end

local function DecorateCenter(c)
    c.bg = Tex(c, "BACKGROUND", MEDIA .. "radial_disc")
    c.bg:SetAllPoints()
    c.edge = Tex(c, "BORDER", MEDIA .. "radial_edge")
    c.edge:SetAllPoints()
    c.icon = Tex(c, "ARTWORK")
    c.icon:SetSize(34, 34)
    c.icon:SetPoint("CENTER", 0, 14)
    c.iconMask = c:CreateMaskTexture()
    c.iconMask:SetAllPoints(c.icon)
    c.icon:AddMaskTexture(c.iconMask)
    c.icon:Hide()
    c.title = W.Text(c, 13, W.T.text, true, "bold")
    c.title:SetWidth(88)
    c.title:SetJustifyH("CENTER")
    if c.title.SetMaxLines then c.title:SetMaxLines(2) end
    c.hint = W.Text(c, 9, W.T.dim, true)
    c.hint:SetPoint("TOP", c.title, "BOTTOM", 0, -4)
    c.hint:SetWidth(84)
    c.hint:SetJustifyH("CENTER")
end

local function DecorateButton(b)
    b.edge = Tex(b, "BACKGROUND", nil, -2)
    b.edge:SetAllPoints()
    b.bg = Tex(b, "BACKGROUND", nil, -1)
    b.icon = Tex(b, "ARTWORK")
    b.mask = b:CreateMaskTexture()
    b.mask:SetAllPoints(b.icon)
    b.icon:AddMaskTexture(b.mask)
    b.text = W.Text(b, 10, W.T.text, true, "medium")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    if b.text.SetMaxLines then b.text:SetMaxLines(2) end
    b.label = W.Text(b, 11, W.T.textSoft, false, "medium")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -4)
    b.label:SetJustifyH("CENTER")
end

local function SetIcon(icon, item)
    icon:SetTexCoord(0, 1, 0, 1)
    if item.portrait and SetPortraitTexture then
        SetPortraitTexture(icon, "player")
    elseif item.icon then
        icon:SetTexture(item.icon)
        -- Los iconos del juego traen un marco de 1-2 px: se recorta.
        if not item.raw then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
end

-- Forma, icono y textos de un botón (fuera de combate, al montar).
local function StyleButton(b, item, size)
    local db, file = R.db, R.ShapeFile()
    b.title, b.item = item.title, item
    b:SetSize(size, size)
    b.edge:SetTexture(file)
    b.bg:SetTexture(file)
    b.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.icon:SetShown(not item.textOnly)
    b.text:SetShown(item.textOnly and true or false)
    b.text:SetWidth(size - 10)
    b.text:SetText(Tr(item.title))
    if not item.textOnly then SetIcon(b.icon, item) end
    b.label:SetShown(db.labels and not item.textOnly)
    b.label:SetText(Tr(item.title))
end

-- state: "hot" (el elegido), "dim" (otro está elegido) o nil.
local function PaintButton(b, state)
    local T, db = W.T, R.db
    local e = math.max(1, db.border or 1) + (state == "hot" and 1 or 0)
    b.bg:ClearAllPoints()
    b.bg:SetPoint("TOPLEFT", e, -e)
    b.bg:SetPoint("BOTTOMRIGHT", -e, e)
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", e + 1, -(e + 1))
    b.icon:SetPoint("BOTTOMRIGHT", -(e + 1), e + 1)
    Paint(b.bg, state == "hot" and T.field or T.chrome, 0.96)
    Paint(b.edge, state == "hot" and R.Accent() or T.btnBorder, 1)
    local faded = state == "dim" and db.dimOthers
    b.icon:SetAlpha(faded and 0.4 or 1)
    b.icon:SetDesaturated(faded and true or false)
    local color = state == "hot" and T.text or T.textSoft
    b.label:SetTextColor(color[1], color[2], color[3], faded and 0.45 or 1)
    b.text:SetTextColor(color[1], color[2], color[3], faded and 0.45 or 1)
end
R.PaintButton = PaintButton

-- Colores de las piezas fijas de una vista (al aplicar los ajustes).
local function StyleView(f, c)
    local T, db = W.T, R.db
    local alpha = (db.backdrop or 70) / 100
    Paint(f.backdrop, T.bg, alpha)
    f.backdrop:SetShown(alpha > 0)
    Paint(f.edge, T.line, 1)
    f.edge:SetShown(alpha > 0)
    Paint(f.orbit, T.line, 1)
    Paint(f.pointer, R.Accent(), 1)
    Paint(c.bg, T.chrome, 0.98)
    Paint(c.edge, T.sectionLine, 1)
    c.iconMask:SetTexture(R.ShapeFile(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
end

-- Estado de una vista: tamaño del fondo y de la órbita de la página, botón
-- elegido (indicador, resaltado, atenuado) y lo que dice el centro.
-- info = { backdrop, radius, buttons = { ... } }; hot = botón elegido o nil.
local function PaintView(f, c, page, info, hot)
    local db = R.db
    local size = info and info.backdrop or 300
    f.backdrop:SetSize(size, size)
    f.edge:SetSize(size, size)
    local orbit = 2 * (info and info.radius or 100)
    f.orbit:SetSize(orbit, orbit)
    f.orbit:SetShown(db.orbit and true or false)
    for _, b in ipairs(info and info.buttons or {}) do
        PaintButton(b, (b == hot and "hot") or (hot and "dim") or nil)
    end
    if hot and db.pointer and hot.angle then
        f.pointer:SetSize(size, size)
        f.pointer:SetRotation(-hot.angle)
        f.pointer:Show()
    else
        f.pointer:Hide()
    end
    local item = hot and hot.item
    local showIcon = item and not item.textOnly and db.centerIcon
    c.icon:SetShown(showIcon and true or false)
    if showIcon then SetIcon(c.icon, item) end
    c.title:ClearAllPoints()
    if showIcon then
        c.title:SetPoint("TOP", c.icon, "BOTTOM", 0, -5)
    else
        c.title:SetPoint("CENTER", 0, hot and 0 or 6)
    end
    c.title:SetText(Tr(hot and hot.title or R.PAGE_TITLES[page]))
    c.hint:SetShown(not hot)
    c.hint:SetText(Tr(page == "root" and "Esc o la tecla para cerrar" or "Pulsa aquí para volver"))
end

-- Coloca los botones de una página y devuelve su info.
local function PlaceButtons(list, items, anchor, makeButton)
    local db = R.db
    local textOnly = items.textOnly
    local radius = R.RadiusFor(#items, textOnly)
    local size = db.iconSize + (textOnly and 8 or 0)
    for i, item in ipairs(items) do
        local b = list[i] or makeButton()
        list[i] = b
        StyleButton(b, item, size)
        b.angle = (i - 1) * 2 * math.pi / #items
        b:ClearAllPoints()
        b:SetPoint("CENTER", anchor, "CENTER", R.Position(i, #items, radius))
        b:Show()
    end
    for i = #items + 1, #list do list[i]:Hide() end
    local labelRoom = (db.labels and not textOnly) and 26 or 0
    local shown = {}
    for i = 1, #items do shown[i] = list[i] end
    return { radius = radius, backdrop = 2 * (radius + size / 2 + labelRoom + 16), buttons = shown }
end

local function PageItemsFor(name)
    local items = R.PageItems(name)
    items.textOnly = name == "emotes"
    return items
end

---------------------------------------------------------------------------
-- El anillo de verdad (seguro)
---------------------------------------------------------------------------
local ring, key, center
local pages = {}        -- nombre -> marco de la página
local buttons = {}      -- nombre de página -> { botones }
local slots = {}        -- número de casilla -> botón (para el resaltado)
local pageInfo = {}     -- nombre de página -> { radius, backdrop, buttons }
local maxSlot = 0
R.pages, R.buttons, R.slots, R.pageInfo = pages, buttons, slots, pageInfo

local function NewButton(page)
    local b = CreateFrame("Button", nil, pages[page], "SecureActionButtonTemplate")
    b:RegisterForClicks("AnyUp")
    -- Con «ActionButtonUseKeyDown» activado, Forever descarta la acción al
    -- soltar el ratón si no se le dice que la quieres al soltar.
    b:SetAttribute("useOnKeyDown", false)
    DecorateButton(b)
    SecureHandlerWrapScript(b, "OnClick", ring, ITEM_PRE, ITEM_POST)
    SecureHandlerWrapScript(b, "OnEnter", ring, ITEM_ENTER)
    SecureHandlerWrapScript(b, "OnLeave", ring, ITEM_LEAVE)
    -- /bui radial depurar: cada clic al chat (gancho posterior, solo lectura).
    b:HookScript("OnClick", function(self, button, down)
        if R.debug then
            print(string.format("radial: clic en %s (%s, %s) tipo=%s macro=%s hechizo=%s", tostring(self.title),
                tostring(button), down and "pulsar" or "soltar", tostring(self:GetAttribute("type")),
                tostring(self:GetAttribute("macrotext")), tostring(self:GetAttribute("spell"))))
        end
    end)
    return b
end

-- Resaltado y título del centro: siguen a los atributos que pone el código
-- seguro ("hover" y "page"), así también se ven en combate.
function R.PaintState()
    if not ring then return end
    local hover = ring:GetAttribute("hover")
    local page = ring:GetAttribute("page") or "root"
    PaintView(ring, center, page, pageInfo[page], hover and slots[hover] or nil)
end

local function Build()
    if ring then return end
    ring = CreateFrame("Frame", "BlazzitoUIRadial", UIParent, "SecureHandlerShowHideTemplate")
    ring:SetFrameStrata("FULLSCREEN_DIALOG")
    ring:SetFrameLevel(10)   -- deja sitio debajo para la capa de «clic fuera»
    ring:SetSize(300, 300)
    ring:SetPoint("CENTER")
    ring:EnableMouse(true)
    ring:Hide()
    DecorateView(ring)
    R.ring = ring

    for _, name in ipairs(R.PAGES) do
        local page = CreateFrame("Frame", nil, ring, "SecureFrameTemplate")
        page:SetAllPoints()
        page:Hide()
        pages[name] = page
        buttons[name] = {}
        SecureHandlerSetFrameRef(ring, "page-" .. name, page)
    end

    center = CreateFrame("Button", "BlazzitoUIRadialCenter", ring, "SecureActionButtonTemplate")
    center:RegisterForClicks("AnyUp")
    center:SetAttribute("useOnKeyDown", false)
    center:SetSize(104, 104)
    center:SetPoint("CENTER")
    center:SetFrameLevel(ring:GetFrameLevel() + 5)
    DecorateCenter(center)
    SecureHandlerWrapScript(center, "OnClick", ring, CENTER_PRE)
    SecureHandlerWrapScript(center, "OnEnter", ring, [[ owner:SetAttribute("hover", nil) ]])
    R.center = center

    ring:SetAttribute("_onshow", ON_SHOW)
    ring:SetAttribute("_onhide", ON_HIDE)
    ring:HookScript("OnAttributeChanged", function(_, name)
        if name == "hover" or name == "page" then R.PaintState() end
        if R.debug and name == "page" then print("radial: página " .. tostring(ring:GetAttribute("page"))) end
    end)

    -- Clic fuera del anillo: una capa invisible a pantalla completa, debajo
    -- de todo lo del anillo, que lo cierra (botón seguro: vale en combate).
    -- Se muestra y se oculta con el anillo, porque es hija suya.
    local outside = CreateFrame("Button", "BlazzitoUIRadialOutside", ring, "SecureHandlerClickTemplate")
    outside:SetAllPoints(UIParent)
    outside:SetFrameLevel(1)
    outside:RegisterForClicks("AnyDown")
    SecureHandlerSetFrameRef(outside, "ring", ring)
    outside:SetAttribute("_onclick", [[ self:GetFrameRef("ring"):Hide() ]])
    R.outside = outside

    -- Esc: una pulsación sobre este botón (atajo que pone el anillo al abrirse).
    local close = CreateFrame("Button", "BlazzitoUIRadialClose", UIParent, "SecureHandlerClickTemplate")
    close:SetSize(1, 1)
    close:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    close:EnableMouse(false)
    close:RegisterForClicks("AnyUp", "AnyDown")
    SecureHandlerSetFrameRef(close, "ring", ring)
    close:SetAttribute("_onclick", [[ self:GetFrameRef("ring"):Hide() ]])

    key = CreateFrame("Button", "BlazzitoUIRadialKey", UIParent, "SecureActionButtonTemplate")
    key:SetSize(1, 1)
    key:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -10, 10)
    key:EnableMouse(false)
    key:RegisterForClicks("AnyDown", "AnyUp")
    -- La acción de la tecla va al soltar (al pulsar solo se abre el anillo).
    key:SetAttribute("useOnKeyDown", false)
    SecureHandlerWrapScript(key, "OnClick", ring, KEY_PRE)
    R.key = key
end
R.Build = Build

-- Copia en la tecla la acción de la casilla (para usarla al soltar).
local function Mirror(slot, item)
    local suffix = "-r" .. slot
    key:SetAttribute("type" .. suffix, item and (item.spell and "spell" or item.macro and "macro") or nil)
    key:SetAttribute("macrotext" .. suffix, item and not item.spell and item.macro or nil)
    key:SetAttribute("spell" .. suffix, item and item.spell or nil)
end

local function Layout()
    local slot = 0
    wipe(slots)
    local biggest = 0
    for _, name in ipairs(R.PAGES) do
        local items = PageItemsFor(name)
        local info = PlaceButtons(buttons[name], items, ring, function() return NewButton(name) end)
        pageInfo[name] = info
        for i, item in ipairs(items) do
            slot = slot + 1
            local b = buttons[name][i]
            b.slot = slot
            slots[slot] = b
            b:SetAttribute("bui-slot", slot)
            b:SetAttribute("bui-sub", item.sub)
            b:SetAttribute("type", item.spell and "spell" or item.macro and "macro" or nil)
            b:SetAttribute("macrotext", not item.spell and item.macro or nil)
            b:SetAttribute("spell", item.spell)
            Mirror(slot, (not item.sub) and item or nil)
        end
        for i = #items + 1, #buttons[name] do buttons[name][i]:SetAttribute("bui-slot", nil) end
        biggest = math.max(biggest, info.backdrop)
    end
    for s = slot + 1, maxSlot do Mirror(s, nil) end
    maxSlot = slot
    ring:SetSize(biggest, biggest)
    -- El anillo es redondo y su marco cuadrado: solo el cuadrado de dentro
    -- del círculo cuenta como «dentro»; las esquinas son ya «fuera».
    local inset = math.floor(biggest / 2 * (1 - 1 / math.sqrt(2)))
    ring:SetHitRectInsets(inset, inset, inset, inset)
end

---------------------------------------------------------------------------
-- Vista previa (página de opciones): marcos normales, sin acciones
---------------------------------------------------------------------------
R.previews = {}

local function RefreshPreview(v)
    local info = PlaceButtons(v.buttons[v.page], PageItemsFor(v.page), v, function()
        local b = CreateFrame("Button", nil, v)
        DecorateButton(b)
        b:SetScript("OnEnter", function(self) v.hot = self; PaintView(v, v.center, v.page, v.info, self) end)
        b:SetScript("OnLeave", function(self)
            if v.hot == self then v.hot = nil end
            PaintView(v, v.center, v.page, v.info, v.hot)
        end)
        b:SetScript("OnClick", function(self)
            if self.item and self.item.sub then
                v.page, v.hot = self.item.sub, nil
                RefreshPreview(v)
            end
        end)
        return b
    end)
    for name, list in pairs(v.buttons) do
        if name ~= v.page then for _, b in ipairs(list) do b:Hide() end end
    end
    v.info = info
    StyleView(v, v.center)
    PaintView(v, v.center, v.page, info, nil)
    -- Que quepa en el hueco: se encoge si hace falta.
    v:SetSize(info.backdrop, info.backdrop)
    v:SetScale(math.min(1, (v.space or 300) / info.backdrop))
end

-- Vista previa dentro de parent; space: alto disponible.
function R.NewPreview(parent, space)
    local v = CreateFrame("Frame", nil, parent)
    v.space, v.page, v.buttons = space, "root", {}
    for _, name in ipairs(R.PAGES) do v.buttons[name] = {} end
    DecorateView(v)
    local c = CreateFrame("Button", nil, v)
    c:SetSize(104, 104)
    c:SetPoint("CENTER")
    c:SetFrameLevel(v:GetFrameLevel() + 5)
    DecorateCenter(c)
    c:SetScript("OnClick", function()
        if v.page ~= "root" then v.page, v.hot = "root", nil; RefreshPreview(v) end
    end)
    v.center = c
    -- Solo la de la página abierta (si la página se rehace, la vieja sobra).
    R.previews = { v }
    RefreshPreview(v)
    return v
end

function R.RefreshPreviews()
    for _, v in ipairs(R.previews) do RefreshPreview(v) end
end

-- Aplica los ajustes (fuera de combate: son marcos seguros).
function R.Apply()
    if not R.active then return end
    R.RefreshPreviews()
    ns.AfterCombat("bui-radial", function()
        Build()
        local db = R.db
        ring:SetScale(math.max(0.5, math.min(2, (db.scale or 100) / 100)))
        StyleView(ring, center)
        Layout()
        R.PaintState()
    end)
end

-- Abrir y cerrar desde nuestro código (botón «Probar» de las opciones).
function R.Open()
    if Combat() or not ring then return false end
    ring:Show()
    return true
end

function R.Close()
    if Combat() or not ring then return false end
    ring:Hide()
    return true
end

---------------------------------------------------------------------------
-- Tecla y macro para la barra
---------------------------------------------------------------------------
function R.Keys()
    if not GetBindingKey then return {} end
    return { GetBindingKey(R.BINDING) }
end

function R.KeyText()
    local keys = R.Keys()
    if #keys == 0 then return nil end
    local list = {}
    for i, k in ipairs(keys) do list[i] = GetBindingText and GetBindingText(k) or k end
    return table.concat(list, ", ")
end

-- Asigna la tecla (nil = quitarla). Sustituye las que tuviera antes.
function R.SetKey(k)
    if Combat() then
        ns.Print("las teclas se asignan fuera de combate.")
        return false
    end
    if not SetBinding then return false end
    for _, old in ipairs(R.Keys()) do SetBinding(old) end
    if k then SetBinding(k, R.BINDING) end
    if SaveBindings and GetCurrentBindingSet then SaveBindings(GetCurrentBindingSet()) end
    return true
end

-- Tecla pulsada -> nombre de atajo ("CTRL-SHIFT-F"); nil si es solo un modificador.
local MODIFIERS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
                    LMETA = true, RMETA = true, UNKNOWN = true }
function R.KeyName(k)
    if not k or MODIFIERS[k] then return nil end
    local prefix = ""
    if IsAltKeyDown and IsAltKeyDown() then prefix = prefix .. "ALT-" end
    if IsControlKeyDown and IsControlKeyDown() then prefix = prefix .. "CTRL-" end
    if IsShiftKeyDown and IsShiftKeyDown() then prefix = prefix .. "SHIFT-" end
    return prefix .. k
end

-- Icono de la macro: el número de archivo (con una ruta, Forever deja la
-- macro sin icono). Si no se puede averiguar, el interrogante.
local iconProbe
function R.MacroIcon()
    if GetFileIDFromPath then
        local ok, id = pcall(GetFileIDFromPath, R.MACRO_ICON)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    iconProbe = iconProbe or UIParent:CreateTexture()
    iconProbe:SetTexture(R.MACRO_ICON)
    local id = iconProbe.GetTextureFileID and iconProbe:GetTextureFileID()
    if type(id) == "number" and id > 0 then return id end
    return 134400
end

-- Macros globales: las primeras (1..MAX_ACCOUNT_MACROS); las de personaje, detrás.
local function MaxAccount()
    local c = Constants and Constants.MacroConsts and Constants.MacroConsts.MAX_ACCOUNT_MACROS
    return c or MAX_ACCOUNT_MACROS or 120
end

-- Crea (o pone al día) la macro global «BUI Radial» y la deja en el cursor.
-- Es la misma para todos tus personajes. Si quedó una de personaje de una
-- versión anterior, se cambia por la global.
function R.PickupMacro()
    if Combat() then
        ns.Print("las macros se crean y se cogen fuera de combate.")
        return false
    end
    if not (GetMacroIndexByName and CreateMacro and PickupMacro) then return false end
    local icon = R.MacroIcon()
    local index = GetMacroIndexByName(R.MACRO_NAME)
    if index and index > MaxAccount() and DeleteMacro then
        pcall(DeleteMacro, index)
        index = nil
    end
    if not index or index == 0 then
        local ok, new = pcall(CreateMacro, R.MACRO_NAME, icon, R.MACRO_BODY, false)
        index = ok and new or GetMacroIndexByName(R.MACRO_NAME)
    elseif EditMacro then
        local ok, new = pcall(EditMacro, index, R.MACRO_NAME, icon, R.MACRO_BODY)
        if ok and type(new) == "number" and new > 0 then index = new end
    end
    if not index or index == 0 then
        ns.Print("no se pudo crear la macro (¿no te quedan huecos de macros generales?).")
        return false
    end
    PickupMacro(index)
    return true
end

---------------------------------------------------------------------------
-- /bui radial
---------------------------------------------------------------------------
function R.Diagnose()
    ns.Print("menú radial")
    print("  tecla: " .. (R.KeyText() or "sin asignar") .. " · al pulsar (CVar ActionButtonUseKeyDown): "
        .. tostring(GetCVar and GetCVar("ActionButtonUseKeyDown")))
    for _, entry in ipairs(R.ROOT) do
        local where = entry.sub and ("página " .. entry.sub) or (entry.macro() or "NO EXISTE en este cliente")
        local name = not entry.sub and entry.macro() and entry.macro():match("^/click (%S+)")
        local b = name and _G[name]
        if b then
            where = where .. string.format(" (visible: %s, activo: %s)", tostring(b.IsShown and b:IsShown()),
                tostring(b.IsEnabled and b:IsEnabled()))
        end
        print(string.format("  %s %s · %s", R.db.items[entry.key] and "[x]" or "[ ]", entry.key, where))
    end
    local J = C_MountJournal
    local ok, ids = pcall(function() return J and J.GetMountIDs and J.GetMountIDs() end)
    local journal = _G.CollectionsMicroButton
    if journal then
        print(string.format("  colección: visible %s, activo %s", tostring(journal:IsShown()), tostring(journal.IsEnabled and journal:IsEnabled())))
    end
    print(string.format("  monturas en el diario: %s · en el anillo: %d",
        ok and ids and tostring(#ids) or "sin diario", #R.Mounts(R.db.maxMounts)))
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function R:OnEnable()
    if not (SecureHandlerWrapScript and SecureHandlerSetFrameRef) then return end
    Build()
    if ns.Movers then
        ns.Movers.Register(ring, "radial", "Menú radial", { "CENTER", "CENTER", 0, 0 }, R.db.positions)
    end
    R.Apply()
    ns.On("PLAYER_ENTERING_WORLD", function() if R.active then R.Apply() end end)
    ns.On("PLAYER_LOGIN", function()
        _G["BINDING_NAME_" .. R.BINDING] = Tr("Menú radial (mantener y soltar)")
    end)
    for _, event in ipairs({ "NEW_MOUNT_ADDED", "COMPANION_LEARNED", "COMPANION_UNLEARNED" }) do
        pcall(ns.On, event, function() if R.active then R.Apply() end end)
    end
    ns.On("UNIT_PORTRAIT_UPDATE", function(_, unit)
        if unit ~= "player" or not R.active then return end
        for _, b in pairs(slots) do
            if b.item and b.item.portrait then SetIcon(b.icon, b.item) end
        end
    end)
    if ns.RegisterCommand then
        ns.RegisterCommand("radial", function(arg)
            if arg == "depurar" then
                R.debug = not R.debug
                print("radial: depuración " .. (R.debug and "activada (cada clic sale en el chat)" or "desactivada"))
                return
            end
            R.Diagnose()
        end, "menú radial: tecla, botones y monturas (depurar: cada clic al chat)")
    end
end
