-- Blazzito_Macros: la ventana y el botón junto al libro de hechizos.
--
-- Todo es nuestro y cuelga de UIParent: el botón y la ventana solo se anclan
-- al libro de Blizzard (y se muestran u ocultan con él mediante HookScript),
-- sin meter nada dentro de sus marcos.
local ns = BlazzitoUI
local Mac = ns and ns.Macros
if not Mac then return end

local M, W = ns.Media, ns.Widgets
local T = W.T
local Readable = M.Readable

local WIDTH, MIN_HEIGHT = 380, 480
local ICON = 32
local CLASS_NAMES = { HUNTER = "Cazador", WARRIOR = "Guerrero", PALADIN = "Paladín", ROGUE = "Pícaro", MAGE = "Mago",
    PRIEST = "Sacerdote", WARLOCK = "Brujo", DRUID = "Druida", SHAMAN = "Chamán" }
local TAB_ICON = "Interface\\Icons\\INV_Misc_Note_01"

local win, tab, rows, headers = nil, nil, {}, {}
Mac.rows = rows

local function Accent() return W.COLORS.accent end

---------------------------------------------------------------------------
-- Dónde está el libro (Forever: PlayerSpellsFrame; por si acaso, el clásico)
---------------------------------------------------------------------------
function Mac.Book()
    local psf = _G.PlayerSpellsFrame
    local sb = psf and rawget(psf, "SpellBookFrame")
    if sb then return sb, psf end
    if psf then return psf, psf end
    if _G.SpellBookFrame then return _G.SpellBookFrame, _G.SpellBookFrame end
end

---------------------------------------------------------------------------
-- Filas
---------------------------------------------------------------------------
local function Tooltip(row)
    local entry = row.entry
    if not entry then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(entry.title, 1, 1, 1)
    GameTooltip:AddLine(Mac.Describe(entry.desc), T.muted[1], T.muted[2], T.muted[3], true)
    local body, note = Mac.Body(entry)
    GameTooltip:AddLine(" ")
    local a = Accent()
    for line in (body .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then GameTooltip:AddLine(line, a[1], a[2], a[3], true) end
    end
    if note then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(note, T.warn[1], T.warn[2], T.warn[3], true)
    end
    GameTooltip:AddLine(" ")
    if row.state == "ready" then
        GameTooltip:AddLine("Arrástrala (o haz clic) y suéltala en una barra.", T.dim[1], T.dim[2], T.dim[3], true)
    end
    GameTooltip:Show()
end

local function Take(row)
    if row.entry and row.state == "ready" and Mac.Pickup(row.entry) then
        GameTooltip:Hide()
        if Mac.Repaint then Mac.Repaint() end
    end
end

local function Row(parent, i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, parent)
    row:RegisterForClicks("LeftButtonUp")
    row:RegisterForDrag("LeftButton")
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(T.rowHover[1], T.rowHover[2], T.rowHover[3], 1)
    row.hover:Hide()
    row.edge = row:CreateTexture(nil, "BORDER")
    row.edge:SetSize(ICON + 2, ICON + 2)
    row.edge:SetPoint("TOPLEFT", 0, -6)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("CENTER", row.edge)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    -- Ya creada: la misma barrita del color de la clase que en tus barras de acción.
    row.created = row:CreateTexture(nil, "ARTWORK")
    row.created:SetSize(ICON, 2)
    row.created:SetPoint("TOP", row.edge, "BOTTOM", 0, -3)
    row.created:Hide()
    row.title = W.Text(row, 13, T.text, false, "medium")
    row.title:SetPoint("TOPLEFT", row.edge, "TOPRIGHT", 10, 1)
    row.title:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.desc = W.Text(row, 11.5, T.muted, true)
    row.desc:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -3)
    row.desc:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.status = W.Text(row, 11, T.dim, true, "medium")
    row.status:SetPoint("TOPLEFT", row.desc, "BOTTOMLEFT", 0, -4)
    row.status:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.line = W.Line(row, T.rowLine)
    row.line:SetPoint("BOTTOMLEFT")
    row.line:SetPoint("BOTTOMRIGHT")
    row:SetScript("OnEnter", function(self) self.hover:Show(); Tooltip(self) end)
    row:SetScript("OnLeave", function(self) self.hover:Hide(); GameTooltip:Hide() end)
    row:SetScript("OnDragStart", Take)
    row:SetScript("OnClick", Take)
    rows[i] = row
    return row
end

local function Paint(row, entry, onBars)
    row.entry = entry
    local state, missing = Mac.State(entry)
    row.state = state
    local _, note = Mac.Body(entry)
    local a = Accent()
    local ready = state == "ready"
    row.icon:SetTexture(Mac.PreviewIcon(entry))
    row.icon:SetDesaturated(not ready)
    row.icon:SetAlpha(ready and 1 or 0.5)
    if ready then row.edge:SetColorTexture(a[1] * 0.7, a[2] * 0.7, a[3] * 0.7, 1)
    else row.edge:SetColorTexture(T.ctrlBorder[1], T.ctrlBorder[2], T.ctrlBorder[3], 1) end
    local created = Mac.MacroIndex(Mac.MacroName(entry)) ~= nil
    row.created:SetColorTexture(a[1], a[2], a[3], 1)
    row.created:SetShown(created)
    row.title:SetText(entry.title)
    row.title:SetTextColor(unpack(ready and T.text or T.min))
    row.desc:SetText(Mac.Describe(entry.desc))
    local status, color
    if not ready then
        status, color = "Se desbloquea con " .. tostring(missing), T.min
    elseif onBars[Mac.MacroName(entry)] then
        status, color = "En tus barras", a
        if note then status, color = status .. " · " .. note, T.warn end
    elseif note then
        status, color = note, T.warn
    elseif created then
        status, color = "Creada · arrástrala a una barra", T.dim
    else
        status, color = "Arrastra a tus barras", T.dim
    end
    if entry.dynamic and ready then status = "Se actualiza sola · " .. status end
    row.status:SetText(status)
    row.status:SetTextColor(color[1], color[2], color[3], 1)
    local h = 6 + 1 + row.title:GetStringHeight() + 3 + row.desc:GetStringHeight() + 4 + row.status:GetStringHeight() + 10
    row:SetHeight(math.max(ICON + 14, h))
end

local function Header(parent, i)
    local h = headers[i]
    if h then return h end
    h = CreateFrame("Frame", nil, parent)
    h:SetHeight(34)
    h.text = W.SectionTitle(h, "")
    h.text:SetPoint("BOTTOMLEFT", 0, 9)
    h.line = W.Line(h, T.sectionLine)
    h.line:SetPoint("BOTTOMLEFT", 0, 2)
    h.line:SetPoint("BOTTOMRIGHT", 0, 2)
    headers[i] = h
    return h
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function Build()
    win = CreateFrame("Frame", "BlazzitoUIMacrosFrame", UIParent)
    Mac.window = win
    win:SetSize(WIDTH, 560)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetClampedToScreen(true)
    win:Hide()
    W.Panel(win, T.radius, T.bg, T.line)

    win.title = W.Text(win, 15, T.text, false, "head")
    win.title:SetPoint("TOPLEFT", 18, -16)
    win.title:SetText(W.Upper("Macros de clase"))
    win.sub = W.Text(win, 12, T.muted, false, "medium")
    win.sub:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -4)
    win.close = W.IconButton(win, M.ICONS.close, function() return "Cerrar" end, function() Mac.Close() end)
    win.close:SetPoint("TOPRIGHT", -10, -10)
    local top = W.Line(win, T.line)
    top:SetPoint("TOPLEFT", 1, -62)
    top:SetPoint("TOPRIGHT", -1, -62)

    win.scroll = CreateFrame("ScrollFrame", nil, win)
    win.scroll:SetPoint("TOPLEFT", 18, -66)
    win.scroll:SetPoint("BOTTOMRIGHT", -22, 40)
    win.content = CreateFrame("Frame", nil, win.scroll)
    win.content:SetSize(WIDTH - 40, 10)
    win.scroll:SetScrollChild(win.content)
    win.scroll:EnableMouseWheel(true)
    win.scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = Readable(self:GetVerticalScrollRange()) or 0
        local now = Readable(self:GetVerticalScroll()) or 0
        self:SetVerticalScroll(math.max(0, math.min(range, now - delta * 50)))
    end)
    if W.ScrollBar then pcall(W.ScrollBar, win.scroll, 6) end

    local bottom = W.Line(win, T.line)
    bottom:SetPoint("BOTTOMLEFT", 1, 34)
    bottom:SetPoint("BOTTOMRIGHT", -1, 34)
    win.foot = W.Text(win, 11.5, T.dim, false)
    win.foot:SetPoint("BOTTOMLEFT", 18, 12)
    win.foot:SetPoint("RIGHT", win, "RIGHT", -18, 0)

    win:SetScript("OnShow", function() Mac.Repaint() end)
end

function Mac.Repaint()
    if not (win and win:IsShown()) then return end
    local class = UnitClass and select(2, UnitClass("player"))
    local entries = Mac.Entries()
    local onBars = Mac.OnBars()
    local groups, ready = {}, 0
    for _, entry in ipairs(entries) do
        local state = Mac.State(entry)
        if state ~= "missing" then
            groups[entry.group] = groups[entry.group] or {}
            table.insert(groups[entry.group], entry)
            if state == "ready" then ready = ready + 1 end
        end
    end
    local width = WIDTH - 40
    local y, ri, hi = 0, 0, 0
    for _, group in ipairs(ns.MacroCatalog.GROUPS) do
        local list = groups[group]
        if list then
            -- Primero las disponibles.
            table.sort(list, function(a, b)
                local ra, rb = Mac.State(a) == "ready", Mac.State(b) == "ready"
                if ra ~= rb then return ra end
                return false
            end)
            hi = hi + 1
            local h = Header(win.content, hi)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -y)
            h:SetWidth(width)
            h.text:SetText(W.Upper(group))
            h:Show()
            y = y + 34
            for _, entry in ipairs(list) do
                ri = ri + 1
                local row = Row(win.content, ri)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", win.content, "TOPLEFT", 0, -y)
                row:SetWidth(width)
                Paint(row, entry, onBars)
                row:Show()
                y = y + (Readable(row:GetHeight()) or 50)
            end
            y = y + 6
        end
    end
    for i = ri + 1, #rows do rows[i]:Hide(); rows[i].entry = nil end
    for i = hi + 1, #headers do headers[i]:Hide() end
    win.content:SetHeight(math.max(10, y))
    local a = Accent()
    win.sub:SetText(string.format("%s · %d disponibles", CLASS_NAMES[class or ""] or (class or "?"), ready))
    win.sub:SetTextColor(a[1], a[2], a[3], 1)
    win.foot:SetText(string.format("Macros de personaje: %d/%d · se crean al arrastrarlas",
        Mac.CharacterCount(), Mac.MaxCharacter()))
    Mac.PaintTab()
end

-- Al lado del libro si está abierto; si no, en el centro.
local function Place()
    local _, outer = Mac.Book()
    win:ClearAllPoints()
    if outer and outer:IsShown() then
        win:SetPoint("TOPLEFT", outer, "TOPRIGHT", 6, 0)
        local h = Readable(outer:GetHeight()) or 0
        win:SetHeight(math.max(MIN_HEIGHT, h))
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
        win:SetHeight(600)
    end
end

function Mac.Open()
    if not win then Build() end
    Place()
    win:Show()
    if Mac.db then Mac.db.open = true end
    Mac.PaintTab()
end

function Mac.Close(keep)
    if win then win:Hide() end
    if Mac.db and not keep then Mac.db.open = false end
    Mac.PaintTab()
end

function Mac.Toggle()
    if win and win:IsShown() then Mac.Close() else Mac.Open() end
end

---------------------------------------------------------------------------
-- El botón junto al libro
---------------------------------------------------------------------------
function Mac.PaintTab()
    if not tab then return end
    local open = win and win:IsShown()
    local a = Accent()
    tab.ring:SetColorTexture(a[1], a[2], a[3], open and 1 or 0)
    tab.icon:SetDesaturated(not open)
end

local function PlaceTab()
    local book, outer = Mac.Book()
    tab:ClearAllPoints()
    local strip = ns.Windows and ns.Windows.Spellbook and ns.Windows.Spellbook.tabStrip
    if strip and strip:IsShown() then
        -- Junto a nuestras pestañas Hechizos / Mascota del libro unificado.
        tab:SetPoint("LEFT", strip, "RIGHT", 6, 0)
    elseif outer then
        tab:SetPoint("TOPLEFT", outer, "TOPRIGHT", 2, -70)
    end
end

local function BuildTab()
    tab = CreateFrame("Button", "BlazzitoUIMacrosButton", UIParent)
    Mac.tab = tab
    tab:SetSize(36, 36)
    tab:SetFrameStrata("HIGH")
    tab:Hide()
    tab.ring = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
    tab.ring:SetPoint("TOPLEFT", -2, 2)
    tab.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    local edge = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 1)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetPoint("TOPLEFT", 1, -1)
    tab.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.icon:SetTexture(TAB_ICON)
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(tab.icon)
    hover:SetColorTexture(1, 1, 1, 0.12)
    tab:SetScript("OnClick", function() Mac.Toggle() end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Macros de clase")
        GameTooltip:AddLine("Las macros esenciales de tu clase, listas para arrastrar a tus barras.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Mac.PaintTab()
end

local function BookShown()
    if not (Mac.active and Mac.db) then return end
    if Mac.db.button then
        if not tab then BuildTab() end
        PlaceTab()
        tab:Show()
        -- Nuestras pestañas del libro se colocan en el mismo momento: otra vez al siguiente fotograma.
        if C_Timer and C_Timer.After then C_Timer.After(0, function() if tab:IsShown() then PlaceTab() end end) end
    end
    if Mac.db.open then Mac.Open() end
end

local function BookHidden()
    if tab then tab:Hide() end
    if win and win:IsShown() then Mac.Close(true) end
end

local hooked = setmetatable({}, { __mode = "k" })
function Mac.SetupWindow()
    local book = Mac.Book()
    if not book or hooked[book] then return end
    hooked[book] = true
    book:HookScript("OnShow", BookShown)
    book:HookScript("OnHide", BookHidden)
    if book:IsShown() then BookShown() end
end

-- El libro de Forever se carga cuando lo abres por primera vez.
pcall(ns.On, "ADDON_LOADED", function(_, name)
    if name == "Blizzard_PlayerSpells" and Mac.active then Mac.SetupWindow() end
end)

-- Desde las opciones.
function Mac.ApplyButton()
    if not tab then return end
    local book = Mac.Book()
    tab:SetShown(Mac.db.button and book and book:IsShown() or false)
end
