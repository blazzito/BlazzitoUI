-- Blazzito_Windows: el mapa del mundo y el registro de misiones (en Forever
-- van juntos: WorldMapFrame con QuestMapFrame en su panel lateral).
--
-- Solo aspecto, y con cuidado: los scripts del registro de misiones van
-- ligados al rastreador de objetivos, los puntos del mapa y sus botones
-- (seguimiento, chinchetas, plantas) son delicados. Nada de eso se toca:
-- solo se ocultan sus texturas de marco y se pintan las nuestras.
--
-- - Marco, barra superior, cerrar y plegar/desplegar como el resto.
-- - La barra de ruta (Kalimdor > Durotar...) sobre una franja oscura.
-- - Registro de misiones: sin fondo de pergamino en la lista, cabeceras de
--   zona con el color de acento (como reputación), pestañas laterales
--   (misiones, eventos, leyenda) cuadradas con borde.
-- - El texto de cada misión (detalles) conserva su pergamino: su letra es
--   oscura y sobre fondo oscuro no se leería.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win = ns.Windows
local M = ns.Media
local Child, Hold = Win.Child, Win.Hold
local Readable = M.Readable

local Map = {}
Win.Map = Map

local function Opts() return Win.db.worldmap end

---------------------------------------------------------------------------
-- Marco de la ventana (BorderFrame lleva el arte por encima del mapa)
---------------------------------------------------------------------------
local function Border(frame, on)
    local bf = Child(frame, "BorderFrame")
    if not bf then return end
    Win.Strip(bf, on)
    for _, key in ipairs({ "NineSlice", "TitleContainer", "Bg", "TopTileStreaks" }) do
        local part = Child(bf, key)
        if part then
            if Win.IsTexture(part) then Hold(part, on) else Win.Strip(part, on) end
        end
    end
    for _, region in ipairs(Win.PortraitArt(bf)) do Hold(region, on and Win.db.hidePortrait) end
    local portrait = _G.WorldMapFramePortrait
    if portrait then Hold(portrait, on and Win.db.hidePortrait) end
    local close = Child(bf, "CloseButton") or Child(frame, "CloseButton")
    if close then Win.ModernButton(close, M.ICONS.close, 20, on and Win.db.modernClose) end
    local mm = Child(bf, "MaximizeMinimizeFrame") or Child(frame, "MaximizeMinimizeFrame")
    if mm then
        Win.Strip(mm, on)
        Win.ModernButton(Child(mm, "MaximizeButton"), M.ICONS.maximize, 20, on)
        Win.ModernButton(Child(mm, "MinimizeButton"), M.ICONS.minimize, 20, on)
    end
    local mini = Child(frame, "MiniBorderFrame")
    if mini then Win.Strip(mini, on) end
end

-- La barra de ruta: su fondo y su borde fuera, una franja oscura debajo.
-- Las migas (botones) se quedan como están: su colocación es delicada.
local function NavBar(frame, on)
    local nav = Child(frame, "NavBar")
    if not nav then return end
    local d = Win.Parts(nav)
    if not d.navBg then
        d.navBg = Win.Texture(nav, "BACKGROUND", -8)
        d.navLine = Win.Texture(nav, "BACKGROUND", -7)
    end
    Win.Strip(nav, on)
    for _, key in ipairs({ "overlay", "InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }) do
        local part = Child(nav, key)
        if part and Win.IsTexture(part) then Hold(part, on) end
    end
    local inset = Child(nav, "Inset") or Child(nav, "InsetBorder")
    if inset then Win.Strip(inset, on) end
    d.navBg:ClearAllPoints()
    d.navBg:SetAllPoints(nav)
    d.navBg:SetColorTexture(0.03, 0.03, 0.035, 0.85)
    d.navLine:ClearAllPoints()
    d.navLine:SetPoint("BOTTOMLEFT", nav, "BOTTOMLEFT")
    d.navLine:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT")
    d.navLine:SetHeight(M.PixelSize())
    local r, g, b = Win.Accent()
    if r then d.navLine:SetColorTexture(r, g, b, 0.5) else d.navLine:SetColorTexture(0, 0, 0, 1) end
    d.navBg:SetShown(on)
    d.navLine:SetShown(on)
end

-- El botón de abrir/cerrar el panel lateral: flecha moderna.
local function SideToggle(frame, on)
    local spt = Child(frame, "SidePanelToggle")
    if not spt then return end
    local open, close = Child(spt, "OpenButton"), Child(spt, "CloseButton")
    for button, angle in pairs({ [open or {}] = 0, [close or {}] = math.pi }) do
        if button.CreateTexture then
            local d = Win.ModernButton(button, M.ICONS.chevron, 22, on)
            if d and d.icon.SetRotation then d.icon:SetRotation(angle) end
        end
    end
end

---------------------------------------------------------------------------
-- Piezas genéricas (Forever usa piezas propias con otros nombres: se
-- reconocen por su forma, no por su nombre)
---------------------------------------------------------------------------
local function Size(f)
    local w, h = f:GetSize()
    return Readable(w) or 0, Readable(h) or 0
end
local function IconOf(f)
    local icon = Child(f, "Icon") or Child(f, "icon")
    return Win.IsTexture(icon) and icon or nil
end
local function IsButton(f)
    local kind = f.GetObjectType and f:GetObjectType()
    return kind == "Button" or kind == "CheckButton"
end

-- Botón cuadrado: cuadro oscuro con borde fino. Su icono se queda; si no
-- tiene, se queda su textura normal (p. ej. un engranaje) o se pone "ownIcon".
function Map.Square(btn, on, ownIcon, angle)
    if not (btn and btn.CreateTexture) then return nil end
    local d = Win.Parts(btn)
    if not on and not d.sqBg then return nil end
    if not d.sqBg then
        d.sqEdge = Win.Texture(btn, "BACKGROUND", -8)
        d.sqBg = Win.Texture(btn, "BACKGROUND", -7)
        d.sqHover = Win.Texture(btn, "HIGHLIGHT", 7)
    end
    local icon = IconOf(btn)
    local keep = {}
    if icon then keep[icon] = true end
    local overlay = Child(btn, "IconOverlay")
    if Win.IsTexture(overlay) then keep[overlay] = true end
    local normal = btn.GetNormalTexture and btn:GetNormalTexture()
    if not icon and not ownIcon and normal then keep[normal] = true end
    for _, region in pairs({ btn:GetRegions() }) do
        if Win.IsTexture(region) and not keep[region] then Hold(region, on) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
        local t = btn[getter] and btn[getter](btn)
        if t and not keep[t] then Hold(t, on) end
    end
    local w = Size(btn)
    if ownIcon then
        d.sqIcon = d.sqIcon or Win.Texture(btn, "OVERLAY", 7)
        d.sqIcon:ClearAllPoints()
        d.sqIcon:SetPoint("CENTER")
        local size = math.max(8, math.floor((w > 0 and w or 18) * 0.55))
        d.sqIcon:SetSize(size, size)
        d.sqIcon:SetTexture(ownIcon)
        d.sqIcon:SetVertexColor(0.88, 0.88, 0.92)
        if d.sqIcon.SetRotation then d.sqIcon:SetRotation(angle or 0) end
        d.sqIcon:SetShown(on)
    end
    local px = M.PixelSize()
    local anchor, pad = icon or btn, icon and 4 or 0
    d.sqEdge:ClearAllPoints()
    d.sqEdge:SetPoint("TOPLEFT", anchor, "TOPLEFT", -pad, pad)
    d.sqEdge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", pad, -pad)
    d.sqEdge:SetColorTexture(0, 0, 0, 1)
    d.sqBg:ClearAllPoints()
    d.sqBg:SetPoint("TOPLEFT", d.sqEdge, "TOPLEFT", px, -px)
    d.sqBg:SetPoint("BOTTOMRIGHT", d.sqEdge, "BOTTOMRIGHT", -px, px)
    d.sqBg:SetColorTexture(0.10, 0.10, 0.12, 0.95)
    d.sqHover:ClearAllPoints()
    d.sqHover:SetAllPoints(d.sqBg)
    d.sqHover:SetColorTexture(1, 1, 1, 0.10)
    if icon and on then pcall(icon.SetTexCoord, icon, 0.1, 0.9, 0.1, 0.9) end
    d.sqEdge:SetShown(on)
    d.sqBg:SetShown(on)
    d.sqHover:SetShown(on)
    return d
end

-- Casilla de seguimiento (✓): nuestro cuadro con nuestro check, solo si está marcada.
function Map.Check(btn, on)
    local d = Map.Square(btn, on, M.ICONS.check)
    if d then Map.PaintCheck(btn) end
end
function Map.PaintCheck(btn)
    local d = Win.Parts(btn)
    if not (d.sqIcon and d.sqBg) then return end
    local checked = btn.GetChecked and btn:GetChecked()
    d.sqIcon:SetShown(d.sqBg:IsShown() and checked and true or false)
    local r, g, b = Win.Accent()
    if checked and r then d.sqIcon:SetVertexColor(r, g, b) end
end

-- Un recuadro (caja de información, como "Misiones: 6/40"): oscuro con borde.
function Map.Box(frame, on)
    local d = Win.Parts(frame)
    if not on and not d.bxBg then return end
    if not d.bxBg then
        d.bxEdge = Win.Texture(frame, "BACKGROUND", -8)
        d.bxBg = Win.Texture(frame, "BACKGROUND", -7)
    end
    Win.Strip(frame, on)
    local px = M.PixelSize()
    d.bxEdge:ClearAllPoints()
    d.bxEdge:SetAllPoints(frame)
    d.bxEdge:SetColorTexture(0, 0, 0, 1)
    d.bxBg:ClearAllPoints()
    d.bxBg:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
    d.bxBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
    d.bxBg:SetColorTexture(0.06, 0.06, 0.07, 0.95)
    d.bxEdge:SetShown(on)
    d.bxBg:SetShown(on)
end

---------------------------------------------------------------------------
-- Ruta (Mundo > Isla Zephras): cada tramo plano y oscuro, texto blanco
---------------------------------------------------------------------------
local function CrumbText(btn)
    local text = Child(btn, "text") or Child(btn, "Text")
    if text and text.SetTextColor then return text end
    return nil
end

function Map.Crumb(btn, on)
    if not (btn and btn.CreateTexture) then return end
    local d = Win.Parts(btn)
    if not on and not d.crBg then return end
    if not d.crBg then
        d.crBg = Win.Texture(btn, "BACKGROUND", -7)
        d.crSep = Win.Texture(btn, "ARTWORK", 7)
        d.crHover = Win.Texture(btn, "HIGHLIGHT", 7)
    end
    for _, region in pairs({ btn:GetRegions() }) do
        if Win.IsTexture(region) then Hold(region, on) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = btn[getter] and btn[getter](btn)
        if t then Hold(t, on) end
    end
    local ma = Child(btn, "MenuArrowButton")
    if ma then Map.Square(ma, on, M.ICONS.chevron, -math.pi / 2) end
    d.crBg:ClearAllPoints()
    d.crBg:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -1)
    d.crBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 1)
    d.crBg:SetColorTexture(0.10, 0.10, 0.12, 0.95)
    d.crHover:ClearAllPoints()
    d.crHover:SetAllPoints(d.crBg)
    d.crHover:SetColorTexture(1, 1, 1, 0.08)
    -- Separador: una flecha fina a la derecha de cada tramo.
    d.crSep:ClearAllPoints()
    d.crSep:SetPoint("CENTER", btn, "RIGHT", 0, 0)
    d.crSep:SetSize(9, 9)
    d.crSep:SetTexture(M.ICONS.chevron)
    if d.crSep.SetRotation then d.crSep:SetRotation(0) end
    local r, g, b = Win.Accent()
    d.crSep:SetVertexColor(r or 0.7, g or 0.7, b or 0.75, 0.9)
    d.crBg:SetShown(on)
    d.crHover:SetShown(on)
    d.crSep:SetShown(on)
    local text = CrumbText(btn)
    if text and on then text:SetTextColor(0.92, 0.92, 0.94) end
end

function Map.Crumbs(nav, on)
    if not nav then return end
    local seen = {}
    local function Add(btn)
        if type(btn) == "table" and btn.CreateTexture and not seen[btn] then
            seen[btn] = true
            Map.Crumb(btn, on)
        end
    end
    Add(Child(nav, "homeButton") or Child(nav, "HomeButton"))
    local list = rawget(nav, "navList")
    if type(list) == "table" then for _, btn in ipairs(list) do Add(btn) end end
    Add(Child(nav, "overflowButton") or Child(nav, "OverflowButton"))
    for _, child in ipairs(Win.Children(nav)) do
        if IsButton(child) then Add(child) end
    end
end

---------------------------------------------------------------------------
-- Botones sobre el mapa (filtro, seguimiento, chinchetas...)
---------------------------------------------------------------------------
local function SmallSquare(f)
    local w, h = Size(f)
    return w >= 16 and w <= 56 and math.abs(w - h) <= 8
end

function Map.Overlays(frame, on)
    local list = rawget(frame, "overlayFrames")
    if type(list) ~= "table" then return end
    for _, overlay in ipairs(list) do
        if type(overlay) == "table" and overlay.CreateTexture then
            if IsButton(overlay) and SmallSquare(overlay) then
                Map.Square(overlay, on)
            else
                for _, child in ipairs(Win.Children(overlay)) do
                    if IsButton(child) and SmallSquare(child) then Map.Square(child, on) end
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Registro de misiones
---------------------------------------------------------------------------
local function IsHeader(button)
    return Child(button, "CollapseButton") ~= nil or (Child(button, "ButtonText") ~= nil and Child(button, "Text") == nil)
end

-- Los botoncitos de la derecha de una fila (▶, ✓). Los de la izquierda (el
-- icono de estado de la misión) no se tocan.
local function RowButtons(row)
    local list = {}
    local rl, rr = Readable(row:GetLeft()), Readable(row:GetRight())
    local middle = (type(rl) == "number" and type(rr) == "number") and (rl + rr) / 2 or nil
    for _, child in ipairs(Win.Children(row)) do
        if IsButton(child) and child:IsShown() then
            local w = Size(child)
            local cx = Readable(child:GetLeft())
            if w > 0 and w <= 26 and (not middle or (type(cx) == "number" and cx > middle)) and not Child(child, "Display") then
                list[#list + 1] = child
            end
        end
    end
    return list
end

local function IsTitle(row)
    if IsHeader(row) then return false end
    if rawget(row, "questID") or rawget(row, "questLogIndex") or Child(row, "Check") or Child(row, "TaskIcon") then return true end
    return #RowButtons(row) > 0
end

local cards = {}
local function Card(contents, i)
    local c = cards[i]
    if c then return c end
    c = {
        edge = Win.Texture(contents, "BACKGROUND", -8),
        fill = Win.Texture(contents, "BACKGROUND", -7),
        mark = Win.Texture(contents, "BACKGROUND", -6),
    }
    cards[i] = c
    return c
end

local function Top(f)
    local t = Readable(f:GetTop())
    return type(t) == "number" and t or 0
end

function Map.QuestRows(on)
    local qs = _G.QuestScrollFrame
    local contents = qs and (Child(qs, "Contents") or Child(qs, "ScrollChild"))
    if not contents then return end
    local opts = Opts()
    local rows = {}
    for _, row in ipairs(Win.Children(contents)) do
        if row.IsShown and row:IsShown() then rows[#rows + 1] = row end
    end
    table.sort(rows, function(a, b) return Top(a) > Top(b) end)
    local groups, current = {}, nil
    for _, row in ipairs(rows) do
        if IsHeader(row) then
            Win.Character.SkinHeader(row, on and opts.headers)
            current = nil
        elseif IsTitle(row) then
            current = { first = row, last = row }
            groups[#groups + 1] = current
            for _, btn in ipairs(RowButtons(row)) do
                if btn:GetObjectType() == "CheckButton" then Map.Check(btn, on and opts.cards)
                else Map.Square(btn, on and opts.cards, not IconOf(btn) and M.ICONS.chevron or nil, 0) end
            end
        elseif current then
            current.last = row
        end
    end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.6, 0.6, 0.65 end
    local px = M.PixelSize()
    local show = on and opts.cards
    for i, group in ipairs(groups) do
        local c = Card(contents, i)
        c.edge:ClearAllPoints()
        c.edge:SetPoint("TOPLEFT", group.first, "TOPLEFT", -4, 4)
        c.edge:SetPoint("RIGHT", group.first, "RIGHT", 4, 0)
        c.edge:SetPoint("BOTTOM", group.last, "BOTTOM", 0, -4)
        c.edge:SetColorTexture(0, 0, 0, 1)
        c.fill:ClearAllPoints()
        c.fill:SetPoint("TOPLEFT", c.edge, "TOPLEFT", px, -px)
        c.fill:SetPoint("BOTTOMRIGHT", c.edge, "BOTTOMRIGHT", -px, px)
        c.fill:SetColorTexture(0.075, 0.075, 0.085, 0.92)
        c.mark:ClearAllPoints()
        c.mark:SetPoint("TOPLEFT", c.fill, "TOPLEFT")
        c.mark:SetPoint("BOTTOMLEFT", c.fill, "BOTTOMLEFT")
        c.mark:SetWidth(2 * px)
        c.mark:SetColorTexture(r, g, b, 1)
        c.edge:SetShown(show); c.fill:SetShown(show); c.mark:SetShown(show)
    end
    for i = #groups + 1, #cards do
        cards[i].edge:Hide(); cards[i].fill:Hide(); cards[i].mark:Hide()
    end
end

-- Pestañas laterales: cuadradas con borde; la elegida, con el de acento.
local function SideTab(tab, on)
    if not (tab and tab.CreateTexture) then return end
    local d = Win.Parts(tab)
    local icon = IconOf(tab)
    if not d.stBg then
        d.stEdge = Win.Texture(tab, "BACKGROUND", -8)
        d.stBg = Win.Texture(tab, "BACKGROUND", -7)
    end
    for _, region in pairs({ tab:GetRegions() }) do
        if Win.IsTexture(region) and region ~= icon then Hold(region, on) end
    end
    local px = M.PixelSize()
    local anchor = icon or tab
    d.stEdge:ClearAllPoints()
    d.stEdge:SetPoint("TOPLEFT", anchor, "TOPLEFT", -5, 5)
    d.stEdge:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 5, -5)
    d.stBg:ClearAllPoints()
    d.stBg:SetPoint("TOPLEFT", d.stEdge, "TOPLEFT", px, -px)
    d.stBg:SetPoint("BOTTOMRIGHT", d.stEdge, "BOTTOMRIGHT", -px, px)
    d.stBg:SetColorTexture(0.08, 0.08, 0.09, 0.95)
    if icon and on then pcall(icon.SetTexCoord, icon, 0.1, 0.9, 0.1, 0.9) end
    d.stOn = on
    d.stEdge:SetShown(on)
    d.stBg:SetShown(on)
    Map.PaintSideTab(tab)
end

-- La elegida: la de Blizzard enseña su SelectedTexture (o tiene "checked").
function Map.PaintSideTab(tab)
    local d = Win.Parts(tab)
    if not d.stEdge then return end
    local selected = Child(tab, "SelectedTexture")
    local isOn = (selected and selected.IsShown and selected:IsShown()) or (tab.GetChecked and tab:GetChecked())
    local r, g, b = Win.Accent()
    if isOn and r then d.stEdge:SetColorTexture(r, g, b, 1) else d.stEdge:SetColorTexture(0, 0, 0, 1) end
end

local TABS = { "QuestsTab", "EventsTab", "MapLegendTab" }
local sideTabs = {}

-- Lo que rodea la lista: pestañas de la derecha, buscador, cajas y botones sueltos.
local function Panel(qm, on)
    local qs = _G.QuestScrollFrame
    local contents = qs and (Child(qs, "Contents") or Child(qs, "ScrollChild"))
    local tabs = {}
    for _, key in ipairs(TABS) do
        local tab = Child(qm, key)
        if tab then tabs[tab] = true end
    end
    Win.Walk(qm, function(f)
        if f == contents or Win.IsScrollBar(f) then return false end
        local kind = f.GetObjectType and f:GetObjectType()
        if kind == "EditBox" then Win.FlatEditBox(f, on); return false end
        local w, h = Size(f)
        if tabs[f] or (IconOf(f) and w >= 28 and w <= 60 and math.abs(w - h) <= 10) then
            tabs[f] = true
            return false
        end
        if IsButton(f) and w > 0 and w <= 26 then Map.Square(f, on); return false end
        if not IsButton(f) and h > 0 and h <= 32 and w >= 50 then
            for _, region in pairs({ f:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "FontString" then Map.Box(f, on); return false end
            end
        end
    end, 3)
    sideTabs = {}
    for tab in pairs(tabs) do
        SideTab(tab, on)
        sideTabs[#sideTabs + 1] = tab
    end
end

function Map.Quests(on)
    local qm = _G.QuestMapFrame
    if not qm then return end
    for _, key in ipairs({ "Background", "VerticalSeparator" }) do
        local part = Child(qm, key)
        if part and Win.IsTexture(part) then Hold(part, on) end
    end
    local qs = _G.QuestScrollFrame
    if qs then
        local bg = Child(qs, "Background")
        if bg and Win.IsTexture(bg) then Hold(bg, on) end
        Win.Strip(qs, on)
        local edge = Child(qs, "BorderFrame")
        if edge then Win.Strip(edge, on) end
    end
    local session = Child(qm, "QuestSessionManagement")
    if session then Win.Strip(session, on) end
    Panel(qm, on)
    Map.QuestRows(on)
end

-- Repaso ligero mientras el registro está abierto: las filas se reciclan,
-- las pestañas cambian de elegida y la ruta crece al navegar.
local ticker
local function StartTicker(frame)
    if ticker then return end
    ticker = Win.Own(CreateFrame("Frame", nil, frame))
    local waited = 0
    ticker:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < 0.25 then return end
        waited = 0
        if not (Win.active and Win.PackOn(Map.pack)) then return end
        Map.QuestRows(true)
        for _, tab in ipairs(sideTabs) do Map.PaintSideTab(tab) end
        local qs = _G.QuestScrollFrame
        local contents = qs and (Child(qs, "Contents") or Child(qs, "ScrollChild"))
        if contents then
            for _, row in ipairs(Win.Children(contents)) do
                for _, btn in ipairs(RowButtons(row)) do if btn:GetObjectType() == "CheckButton" then Map.PaintCheck(btn) end end
            end
        end
    end)
end

local hooked = false
local function HookUpdates(frame)
    if hooked then return end
    hooked = true
    -- Los tramos de la ruta se crean al navegar (gancho posterior: no cambia nada de Blizzard).
    if type(_G.NavBar_AddButton) == "function" then
        hooksecurefunc("NavBar_AddButton", function(bar)
            if bar == Child(frame, "NavBar") and Win.active and Win.PackOn(Map.pack) then Map.Crumbs(bar, true) end
        end)
    end
end

-- /bui mapa: el árbol del registro, la ruta y los botones del mapa (para afinar).
ns.RegisterCommand("mapa", function()
    local frame = _G.WorldMapFrame
    if not frame then ns.Print("el mapa no está cargado: ábrelo una vez y repite.") return end
    ns.Print("mapa: ruta")
    for _, line in ipairs(Win.Dump(Child(frame, "NavBar"), 2)) do print("  " .. line) end
    ns.Print("mapa: botones sobre el mapa")
    for _, overlay in ipairs(rawget(frame, "overlayFrames") or {}) do
        for _, line in ipairs(Win.Dump(overlay, 1)) do print("  " .. line) end
    end
    ns.Print("mapa: registro de misiones")
    for _, line in ipairs(Win.Dump(_G.QuestMapFrame, 4)) do print("  " .. line) end
end, "estructura del mapa y del registro de misiones")

---------------------------------------------------------------------------
-- Paquete
---------------------------------------------------------------------------
function Map.Apply(frame, on)
    local canvas = Child(frame, "ScrollContainer")
    if canvas then Win.noWalk[canvas] = true end
    Border(frame, on)
    NavBar(frame, on)
    Map.Crumbs(Child(frame, "NavBar"), on)
    SideToggle(frame, on)
    Map.Overlays(frame, on)
    Map.Quests(on)
    HookUpdates(frame)
    if on then StartTicker(frame) end
end

function Map.Diagnose(frame)
    local qm = _G.QuestMapFrame
    local rows, headers = 0, 0
    local qs = _G.QuestScrollFrame
    local contents = qs and (Child(qs, "Contents") or Child(qs, "ScrollChild"))
    if contents then
        for _, row in ipairs(Win.Children(contents)) do
            rows = rows + 1
            if IsHeader(row) then headers = headers + 1 end
        end
    end
    print(string.format("  mapa: marco %s, ruta %s, panel lateral %s, misiones %s (filas %d, cabeceras %d), pestañas %s",
        Child(frame, "BorderFrame") and "sí" or "no", Child(frame, "NavBar") and "sí" or "no",
        Child(frame, "SidePanelToggle") and "sí" or "no", qm and "sí" or "no", rows, headers,
        tostring(#sideTabs) .. " (más detalle: /bui mapa)"))
end

Map.pack = {
    key = "worldmap", title = "Mapa y misiones",
    frame = function() return _G.WorldMapFrame end,
    apply = Map.Apply,
    diagnose = Map.Diagnose,
}
Win.Register(Map.pack)

---------------------------------------------------------------------------
-- El registro de misiones clásico (si este cliente lo tiene aparte)
---------------------------------------------------------------------------
Map.questLog = {
    key = "worldmap", title = "Registro de misiones (clásico)",
    frame = function() return _G.QuestLogFrame end,
    apply = function(frame, on)
        for _, row in ipairs(Win.Children(Child(frame, "QuestLogListScrollFrame") or _G.QuestLogListScrollFrame or {})) do
            if IsHeader(row) then Win.Character.SkinHeader(row, on and Opts().headers) end
        end
    end,
}
Win.Register(Map.questLog)
