-- Ventana de configuración de BlazzitoUI (/bui). Estilo «Taller».
-- Cabecera (logo, ruta, buscador y acciones), menú lateral con categorías y el
-- personaje abajo, cabecera de página y la página en sí. Cada módulo registra
-- la suya con ns.Config.RegisterPage(id, título, orden, build); build(content,
-- ancho) recibe el lienzo y devuelve su maquetación (W.Layout).
-- Grupo, icono, descripción y módulo de cada página están en C.META.
-- Colores y medidas: W.T (tokens). Acento = color de la clase (W.COLORS.accent).
local ADDON_NAME, ns = ...

local M = ns.Media
local W = ns.Widgets
local T = W.T
local C = { pages = {}, openHooks = {}, generalCards = {} }
ns.Config = C

local WIDTH, HEIGHT, SIDEBAR, HEADER, PAGE_HEAD = 1040, 680, 196, 44, 54
local NAV_H, ROW_H = 28, 38

---------------------------------------------------------------------------
-- Datos de cada página: grupo del menú, icono, descripción y el módulo al
-- que corresponde (para su interruptor).
---------------------------------------------------------------------------
C.GROUPS = { "", "MARCOS", "COMBATE", "MUNDO Y VENTANAS", "SISTEMA", "OTROS" }
C.GROUP_NAMES = { MARCOS = "Marcos", COMBATE = "Combate", ["MUNDO Y VENTANAS"] = "Mundo y ventanas",
    SISTEMA = "Sistema", OTROS = "Otros" }
C.META = {
    general      = { group = "", icon = "home", title = "Inicio", desc = "Tus módulos de un vistazo y los ajustes generales." },
    profiles     = { group = "", icon = "layers", desc = "Copia, exporta e importa tu configuración entre personajes." },
    unitframes   = { group = "MARCOS", icon = "unit", module = "UnitFrames", desc = "Jugador, objetivo, foco y mascota: forma, retrato, barras y combo." },
    group        = { group = "MARCOS", icon = "group", module = "Group", desc = "Marcos de grupo y de banda con el mismo motor." },
    auras        = { group = "MARCOS", icon = "aura", module = "Auras", desc = "Beneficios y perjuicios sobre cada marco, como iconos o barras." },
    nameplates   = { group = "MARCOS", icon = "plate", module = "Nameplates", desc = "Placas de nombre enemigas con nuestro estilo y aviso de alcance." },
    threatplate  = { group = "MARCOS", icon = "threat", module = "ThreatPlate", desc = "Porcentaje de amenaza sobre las placas de nombre." },
    actionbars   = { group = "COMBATE", icon = "bars", module = "ActionBars", desc = "Barras de acción con forma, visibilidad y temporizador de golpe." },
    combattext   = { group = "COMBATE", icon = "bolt", module = "CombatText", desc = "Daño y curación en zonas propias, críticos, rachas y resumen." },
    macros       = { group = "COMBATE", icon = "bars", module = "Macros", desc = "Las macros esenciales de tu clase, listas para arrastrar y al día solas." },
    windows      = { group = "MUNDO Y VENTANAS", icon = "window", module = "Windows", desc = "Personaje, talentos, libro, mapa y más con nuestro estilo." },
    minimap      = { group = "MUNDO Y VENTANAS", icon = "compass", module = "Minimap", desc = "Forma, brújula, zona, hora y botones de addons recogidos." },
    bags         = { group = "MUNDO Y VENTANAS", icon = "bag", module = "Bags", desc = "Bolsas y banco: nivel de objeto, mejoras, basura y atajos." },
    questtracker = { group = "MUNDO Y VENTANAS", icon = "quest", module = "QuestTracker", desc = "Ajustes sobre el rastreador de misiones de Questie." },
    chat         = { group = "MUNDO Y VENTANAS", icon = "chat", module = "Chat", desc = "Filtros, enlaces, emoticonos e historial del chat." },
    graphics     = { group = "SISTEMA", icon = "monitor", module = "Graphics", desc = "Presets de un clic, copias de seguridad y límite de FPS." },
    gamepad      = { group = "SISTEMA", icon = "gamepad", module = "Gamepad", desc = "Mando o teclado y ratón al entrar, y cómo se adapta BlazzitoUI al estilo de mando." },
}

-- Módulos sin página propia: dónde aparecen en Inicio y a dónde llevan.
local MODULE_EXTRA = {
    QoL = { group = "SISTEMA", icon = "sliders", page = "general", desc = "Botín rápido, reparación automática y vender basura." },
    Setup = { group = "SISTEMA", icon = "copy", page = "profiles", desc = "Copia opciones del juego de tu main a tus otros personajes." },
}

function C.Meta(id)
    return C.META[id] or { group = "OTROS", icon = "sliders" }
end

-- Tarjetas que los módulos añaden a la página Inicio: build(L, content).
function C.AddGeneralCard(build)
    C.generalCards[#C.generalCards + 1] = build
end

function C.RegisterPage(id, title, order, build)
    C.pages[#C.pages + 1] = { id = id, title = title, order = order, build = build }
    table.sort(C.pages, function(a, b) return a.order < b.order end)
end

function C.PageTitle(page)
    return C.Meta(page.id).title or page.title
end

-- fn(activa) se llama al abrir y cerrar la ventana, y al encender o apagar la
-- vista previa de marcos desde la cabecera (activa = abierta y con vista previa).
function C.OnOpenChanged(fn)
    C.openHooks[#C.openHooks + 1] = fn
end

function C.PreviewEnabled()
    return not (ns.db and ns.db.configPreview == false)
end

local function NotifyOpen()
    local on = C.window and C.window:IsShown() and C.PreviewEnabled() and true or false
    for _, fn in ipairs(C.openHooks) do fn(on) end
end

-- Rueda del ratón suave: cada giro mueve un destino y la página se desliza
-- hasta él en vez de saltar.
local WHEEL_STEP = 70
local function SmoothScroll(scroll)
    scroll.smoothScroll = true
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local from = self.scrollTarget or self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange() or 0
        self.scrollTarget = math.max(0, math.min(max, from - delta * WHEEL_STEP))
    end)
    scroll:HookScript("OnUpdate", function(self, elapsed)
        local target = self.scrollTarget
        if not target then return end
        local current = self:GetVerticalScroll()
        local diff = target - current
        if math.abs(diff) < 0.5 then
            self:SetVerticalScroll(target)
            self.scrollTarget = nil
        else
            self:SetVerticalScroll(current + diff * math.min(1, elapsed * 14))
        end
    end)
end
C.SmoothScroll = SmoothScroll

local function Fill(region, c)
    region:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end

---------------------------------------------------------------------------
-- Páginas
---------------------------------------------------------------------------
local function BuildPage(page, host)
    -- Sin plantilla de Blizzard: la barra es la nuestra (fina, sin flechas).
    local scroll = CreateFrame("ScrollFrame", nil, host)
    SmoothScroll(scroll)
    scroll:SetPoint("TOPLEFT", 0, -PAGE_HEAD)
    scroll:SetPoint("BOTTOMRIGHT", -12, 2)
    local content = CreateFrame("Frame", nil, scroll)
    local width = WIDTH - SIDEBAR - 14
    content:SetWidth(width)
    scroll:SetScrollChild(content)
    page.layout = page.build(content, width)
    content:SetHeight(page.layout:Height())
    page.scroll = scroll
    page.scrollBar = W.ScrollBar(scroll, 1)
    -- La barra es hermana del scroll: se muestra y oculta con su página.
    scroll:HookScript("OnHide", function() page.scrollBar:Hide() end)
end

local function PaintNav(nav, selected)
    nav.bg:SetShown(selected or nav.hovered)
    Fill(nav.bg, selected and T.field or T.navHover)
    nav.text:SetTextColor(unpack(selected and W.COLORS.accent or ((nav.hovered) and T.text or T.navText)))
end

-- Cabecera de la página: título en mayúsculas e interruptor del módulo.
local function ShowPageHead(window, page)
    local head, meta = window.pageHead, C.Meta(page.id)
    head.title:SetText(W.Upper(C.PageTitle(page)))
    local module = meta.module and ns.modules[meta.module]
    head.module = module
    head.toggle:SetShown(module ~= nil)
    if module then head.toggle:Refresh() end
    local group = C.GROUP_NAMES[meta.group]
    window.crumb:SetText((group and (group .. "  /  ") or "") .. "|cffc9cdd3" .. C.PageTitle(page) .. "|r")
end

local function Select(window, id)
    W.CloseMenu()
    for _, page in ipairs(C.pages) do
        local selected = page.id == id
        if selected and not page.scroll then BuildPage(page, window.host) end
        if page.scroll then page.scroll:SetShown(selected) end
        if selected then
            page.layout:Refresh()
            ShowPageHead(window, page)
        end
        local nav = window.nav[page.id]
        nav.selected = selected
        PaintNav(nav, selected)
    end
    C.current = id
end
C.Select = function(id) if C.window then Select(C.window, id) end end

function C.RefreshCurrent()
    for _, page in ipairs(C.pages) do
        if page.id == C.current and page.layout then page.layout:Refresh() end
    end
    if C.window then
        C.RefreshFooter()
        for _, page in ipairs(C.pages) do PaintNav(C.window.nav[page.id], page.id == C.current) end
    end
end

---------------------------------------------------------------------------
-- Menú lateral: categorías, entradas y el personaje abajo
---------------------------------------------------------------------------
local function MatchesSearch(page, query)
    if query == "" then return true end
    local meta = C.Meta(page.id)
    local hay = string.lower(C.PageTitle(page) .. " " .. (meta.desc or "") .. " " .. (C.GROUP_NAMES[meta.group] or ""))
    return hay:find(query, 1, true) ~= nil
end

local function LayoutNav(window)
    local query = string.lower((window.search:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    local list, y = window.navList, 0
    for _, header in pairs(window.groupHeads) do header:Hide() end
    local count = 0
    for _, group in ipairs(C.GROUPS) do
        local first = true
        for _, page in ipairs(C.pages) do
            local nav = window.nav[page.id]
            if (C.Meta(page.id).group or "OTROS") == group then
                local show = MatchesSearch(page, query)
                nav:SetShown(show)
                if show then
                    if first and group ~= "" then
                        local head = window.groupHeads[group]
                        head:ClearAllPoints()
                        head:SetPoint("TOPLEFT", list, "TOPLEFT", 10, y - 14)
                        head:Show()
                        y = y - 32
                    end
                    first = false
                    nav:ClearAllPoints()
                    nav:SetPoint("TOPLEFT", list, "TOPLEFT", 0, y)
                    nav:SetPoint("RIGHT", list, "RIGHT", 0, 0)
                    y = y - NAV_H
                    count = count + 1
                end
            end
        end
    end
    window.noResults:SetShown(count == 0)
    list:SetHeight(-y + 8)
end

function C.RefreshFooter()
    local foot = C.window and C.window.footer
    if not foot then return end
    local key = ns.charKey or "?"
    local info = ns.root and ns.root.chars and ns.root.chars[key] or {}
    local a = W.RefreshAccent()
    foot.name:SetText(key)
    foot.name:SetTextColor(a[1], a[2], a[3])
    local className = UnitClass("player") or ""
    local level = info.level or UnitLevel("player") or "?"
    local profile = ns.profileCreatedFrom and ("copiado de " .. (ns.profileCreatedFrom:match("(%S+)$") or ns.profileCreatedFrom))
        or "Perfil propio"
    foot.sub:SetText(className .. " " .. tostring(level) .. " · " .. profile)
end

local function BuildSidebar(window, sidebar)
    -- Personaje (abajo): abre Perfiles.
    local foot = CreateFrame("Button", nil, sidebar)
    foot:SetPoint("BOTTOMLEFT", 0, 0)
    foot:SetPoint("BOTTOMRIGHT", -1, 0)
    foot:SetHeight(50)
    local footLine = W.Line(foot, T.line)
    footLine:SetPoint("TOPLEFT")
    footLine:SetPoint("TOPRIGHT")
    local footHover = foot:CreateTexture(nil, "BACKGROUND")
    footHover:SetAllPoints()
    Fill(footHover, T.navHover)
    footHover:Hide()
    foot.name = W.Text(foot, 13, nil, false, "bold")
    foot.name:SetPoint("TOPLEFT", 14, -10)
    foot.name:SetPoint("RIGHT", -10, 0)
    foot.sub = W.Text(foot, 11, T.dim)
    foot.sub:SetPoint("TOPLEFT", foot.name, "BOTTOMLEFT", 0, -3)
    foot.sub:SetPoint("RIGHT", -10, 0)
    foot:SetScript("OnClick", function() Select(window, "profiles") end)
    foot:SetScript("OnEnter", function()
        footHover:Show()
        GameTooltip:SetOwner(foot, "ANCHOR_RIGHT")
        GameTooltip:SetText("Perfiles: copiar, exportar e importar")
        GameTooltip:Show()
    end)
    foot:SetScript("OnLeave", function()
        footHover:Hide()
        GameTooltip:Hide()
    end)
    window.footer = foot

    -- Lista con desplazamiento
    local scroll = CreateFrame("ScrollFrame", nil, sidebar)
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", -8, 6)
    SmoothScroll(scroll)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetWidth(SIDEBAR - 17)
    list:SetHeight(1)
    scroll:SetScrollChild(list)
    window.navList = list
    W.ScrollBar(scroll, 2)

    window.groupHeads = {}
    for _, group in ipairs(C.GROUPS) do
        if group ~= "" then
            local head = W.SectionTitle(list, C.GROUP_NAMES[group], 11)
            head:SetTextColor(unpack(T.min))
            head:Hide()
            window.groupHeads[group] = head
        end
    end
    window.noResults = W.Text(list, 12, T.dim, true)
    window.noResults:SetPoint("TOPLEFT", 10, -8)
    window.noResults:SetPoint("RIGHT", -10, 0)
    window.noResults:SetText("Nada coincide. Prueba con otra palabra.")
    window.noResults:Hide()

    window.nav = {}
    for _, page in ipairs(C.pages) do
        local nav = CreateFrame("Button", nil, list)
        nav:SetHeight(NAV_H)
        nav.bg = nav:CreateTexture(nil, "BACKGROUND")
        nav.bg:SetAllPoints()
        nav.bg:Hide()
        nav.text = W.Text(nav, 13)
        nav.text:SetPoint("LEFT", 10, 0)
        nav.text:SetPoint("RIGHT", -8, 0)
        nav.text:SetText(C.PageTitle(page))
        nav:SetScript("OnClick", function() Select(window, page.id) end)
        nav:SetScript("OnEnter", function(self)
            self.hovered = true
            PaintNav(self, self.selected)
        end)
        nav:SetScript("OnLeave", function(self)
            self.hovered = false
            PaintNav(self, self.selected)
        end)
        window.nav[page.id] = nav
    end
end

---------------------------------------------------------------------------
-- Cabecera: logo, ruta, buscador y acciones
---------------------------------------------------------------------------
local function BuildSearch(window, header)
    local box = CreateFrame("EditBox", nil, header)
    box:SetSize(200, 26)
    box:SetAutoFocus(false)
    if not box:SetFont(M.UI_FONT, 14, "") then box:SetFont(M.FONT, 12, "") end
    box:SetTextColor(unpack(T.text))
    box:SetTextInsets(26, 8, 0, 0)
    local panel = W.Panel(box, T.radius, T.bg, T.ctrlBorder)
    local glass = box:CreateTexture(nil, "ARTWORK")
    glass:SetTexture(M.NAV_ICONS.search)
    glass:SetSize(13, 13)
    glass:SetPoint("LEFT", 8, 0)
    glass:SetVertexColor(unpack(T.min))
    local hint = W.Text(box, 13, T.min)
    hint:SetPoint("LEFT", 26, 0)
    hint:SetText("Buscar sección…")
    box:SetScript("OnTextChanged", function(self)
        hint:SetShown((self:GetText() or "") == "")
        LayoutNav(window)
    end)
    box:SetScript("OnEditFocusGained", function()
        panel.border:SetColor(T.btnBorderHot)
        glass:SetVertexColor(unpack(T.text))
    end)
    box:SetScript("OnEditFocusLost", function()
        panel.border:SetColor(T.ctrlBorder)
        glass:SetVertexColor(unpack(T.min))
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        -- Intro: abre la primera sección que coincide.
        self:ClearFocus()
        for _, group in ipairs(C.GROUPS) do
            for _, page in ipairs(C.pages) do
                if (C.Meta(page.id).group or "OTROS") == group and window.nav[page.id]:IsShown() then
                    Select(window, page.id)
                    return
                end
            end
        end
    end)
    window.search = box
    return box
end

local function BuildHeader(window)
    local header = CreateFrame("Frame", nil, window)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() window:StartMoving() end)
    header:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    local bg = header:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Fill(bg, T.chrome)
    local line = W.Line(header, T.line)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")

    -- Logo: BLAZZITO + UI en el acento, y la versión en gris.
    window.logo = W.Text(header, 18, T.text, false, "head")
    window.logo:SetPoint("LEFT", 14, 0)
    local version = W.Text(header, 11, T.min)
    version:SetPoint("LEFT", window.logo, "RIGHT", 8, -1)
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    version:SetText(getMetadata and getMetadata(ADDON_NAME, "Version") or "")
    window.crumb = W.Text(header, 12, T.min)
    window.crumb:SetPoint("LEFT", version, "RIGHT", 16, 0)

    -- Acciones, de derecha a izquierda: cerrar (apartado), recargar,
    -- restablecer, vista previa, mover marcos y el buscador.
    local icons = M.ICONS
    local close = W.IconButton(header, icons.close, function() return "Cerrar" end, function() window:Hide() end)
    close:SetPoint("RIGHT", -8, 0)
    local sep = W.Line(header, T.sectionLine, true)
    sep:SetHeight(20)
    sep:SetPoint("RIGHT", close, "LEFT", -12, 0)
    local reload = W.IconButton(header, icons.reload, function() return "Recargar la interfaz" end, function() ReloadUI() end)
    reload:SetPoint("RIGHT", sep, "LEFT", -12, 0)
    local reset = W.IconButton(header, icons.reset, function() return "Devolver los marcos a su posición" end, function()
        StaticPopup_Show("BLAZZITOUI_RESET_POSITIONS")
    end)
    reset:SetPoint("RIGHT", reload, "LEFT", -2, 0)

    local preview = CreateFrame("Button", nil, header)
    preview:SetSize(112, 28)
    preview:SetPoint("RIGHT", reset, "LEFT", -10, 0)
    local label = W.Text(preview, 12, T.muted, false, "medium")
    label:SetPoint("LEFT", 0, 0)
    label:SetText("Vista previa")
    local switch = W.Switch(preview)
    switch:SetPoint("RIGHT")
    function preview:Refresh() switch:SetOn(C.PreviewEnabled()) end
    preview:SetScript("OnClick", function(self)
        ns.db.configPreview = not C.PreviewEnabled()
        self:Refresh()
        NotifyOpen()
    end)
    preview:SetScript("OnEnter", function()
        label:SetTextColor(unpack(T.text))
        GameTooltip:SetOwner(preview, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Muestra los marcos ocultos con tus datos mientras ajustas")
        GameTooltip:Show()
    end)
    preview:SetScript("OnLeave", function()
        label:SetTextColor(unpack(T.muted))
        GameTooltip:Hide()
    end)
    window.previewToggle = preview

    local move = W.IconButton(header, icons.move, function()
        return ns.Movers.unlocked and "Salir del modo mover (bloquea los marcos)" or "Desbloquea los marcos para colocarlos"
    end, function()
        ns.Movers.Toggle()
        C.RefreshTools()
    end, "Mover marcos")
    move:SetPoint("RIGHT", preview, "LEFT", -14, 0)
    window.tools = { move = move, reset = reset, reload = reload, close = close }

    local search = BuildSearch(window, header)
    search:SetPoint("RIGHT", move, "LEFT", -14, 0)
end

local function BuildPageHead(window)
    local head = CreateFrame("Frame", nil, window.host)
    head:SetPoint("TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", 0, 0)
    head:SetHeight(PAGE_HEAD)
    head.title = W.Text(head, 25, T.text, false, "head")
    head.title:SetPoint("TOPLEFT", 22, -16)

    -- Interruptor del módulo de la página (cambiarlo pide recargar).
    local toggle = CreateFrame("Button", nil, head)
    toggle:SetSize(170, 26)
    toggle:SetPoint("TOPRIGHT", -22, -18)
    local switch = W.Switch(toggle)
    switch:SetPoint("RIGHT")
    local label = W.Text(toggle, 12, T.muted)
    label:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    local warn = W.Text(toggle, 11, T.warn)
    warn:SetPoint("RIGHT", label, "LEFT", -10, 0)
    warn:SetText("al recargar")
    function toggle:Refresh()
        local module = head.module
        local on = module and module.db and module.db.enabled and true or false
        switch:SetOn(on)
        label:SetText(on and "Módulo encendido" or "Módulo apagado")
        local resting = on and module.padResting == true
        warn:SetText(resting and (module.padLite and "en parte, por el mando" or "apartado por el mando") or "al recargar")
        warn:SetShown(module ~= nil and (resting or on ~= (module.active and true or false)))
    end
    toggle:SetScript("OnClick", function(self)
        local module = head.module
        if not (module and module.db) then return end
        module.db.enabled = not module.db.enabled
        self:Refresh()
        ns.AskReload()
    end)
    toggle:SetScript("OnEnter", function()
        GameTooltip:SetOwner(toggle, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Encender o apagar este módulo (se aplica al recargar)")
        GameTooltip:Show()
    end)
    toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    head.toggle = toggle
    window.pageHead = head
end

local function Create()
    local window = CreateFrame("Frame", "BlazzitoUIConfig", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetPoint("CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    W.Panel(window, T.radius, T.bg, T.sectionLine)
    table.insert(UISpecialFrames, "BlazzitoUIConfig")

    BuildHeader(window)

    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT", 1, -HEADER - 1)
    sidebar:SetPoint("BOTTOMLEFT", 1, 1)
    sidebar:SetWidth(SIDEBAR)
    local sideBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints()
    Fill(sideBg, T.chrome)
    local sideLine = W.Line(sidebar, T.line, true)
    sideLine:SetPoint("TOPRIGHT")
    sideLine:SetPoint("BOTTOMRIGHT")

    window.host = CreateFrame("Frame", nil, window)
    window.host:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    window.host:SetPoint("BOTTOMRIGHT", -1, 1)
    BuildPageHead(window)
    BuildSidebar(window, sidebar)
    LayoutNav(window)

    window:SetScript("OnShow", function()
        local a = W.RefreshAccent()
        window.logo:SetText(string.format("BLAZZITO|cff%02x%02x%02xUI|r", a[1] * 255, a[2] * 255, a[3] * 255))
        NotifyOpen()
        C.RefreshCurrent()
        C.RefreshTools()
        window.previewToggle:Refresh()
    end)
    window:SetScript("OnHide", function()
        W.CloseMenu()
        for _, fn in ipairs(C.openHooks) do fn(false) end
    end)

    window:Hide()
    C.window = window
    Select(window, C.pages[1].id)
end

-- El botón de mover se queda en el color del acento mientras el modo mover
-- está activo.
function C.RefreshTools()
    local tools = C.window and C.window.tools
    if tools then tools.move:SetTint(ns.Movers.unlocked and W.COLORS.accent or nil) end
end

StaticPopupDialogs["BLAZZITOUI_RESET_POSITIONS"] = {
    text = "BlazzitoUI: ¿devolver los marcos que has movido a su posición original?\n\nSolo cambian las posiciones: formas, colores, tamaños y demás ajustes se quedan como están.",
    button1 = "Restablecer posiciones",
    button2 = "Cancelar",
    OnAccept = function() ns.Movers.ResetAll() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function C.Toggle(id)
    if not C.window then Create() end
    if id then Select(C.window, id) end
    if C.window:IsShown() and not id then
        C.window:Hide()
    else
        C.window:Show()
    end
end

function C.Open(id)
    if not C.window then Create() end
    if id then Select(C.window, id) end
    C.window:Show()
end

ns.OpenOptions = function() C.Toggle() end

---------------------------------------------------------------------------
-- Página Inicio (id "general"): tira de estado, módulos en filas agrupadas y
-- los ajustes generales.
---------------------------------------------------------------------------
-- Página, grupo, icono y descripción de un módulo para su fila.
local function ModuleInfo(name)
    for id, meta in pairs(C.META) do
        if meta.module == name then return { page = id, group = meta.group, icon = meta.icon, desc = meta.desc } end
    end
    return MODULE_EXTRA[name] or { group = "OTROS", icon = "sliders" }
end

-- Segmento de la tira de estado: etiqueta, valor y un botón.
local function StatusSegment(parent, label, button, onClick)
    local seg = CreateFrame("Frame", nil, parent)
    seg:SetHeight(44)
    seg.label = W.Text(seg, 12, T.dim)
    seg.label:SetPoint("LEFT", 12, 0)
    seg.label:SetText(label)
    seg.button = W.Button(seg, nil, button, onClick)
    seg.button:SetPoint("RIGHT", -10, 0)
    seg.value = W.Text(seg, 13, T.text, false, "medium")
    seg.value:SetPoint("LEFT", seg.label, "RIGHT", 10, 0)
    seg.value:SetPoint("RIGHT", seg.button, "LEFT", -8, 0)
    return seg
end

-- Fila de un módulo: icono | nombre | descripción | interruptor | chevron.
local function ModuleRow(parent, module, info, onChange)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row.module = module
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints()
    Fill(hover, T.rowHover)
    hover:Hide()
    local line = W.Line(row, T.rowLine)
    line:SetPoint("BOTTOMLEFT")
    line:SetPoint("BOTTOMRIGHT")

    local box = CreateFrame("Frame", nil, row)
    box:SetSize(26, 26)
    box:SetPoint("LEFT", 10, 0)
    W.Panel(box, T.radius, { 0.102, 0.114, 0.129, 1 }, T.btnBorder, 0)
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetSize(15, 15)
    icon:SetPoint("CENTER")
    icon:SetTexture(M.NAV_ICONS[info.icon] or M.NAV_ICONS.sliders)
    icon:SetVertexColor(unpack(T.textSoft))

    local name = W.Text(row, 14, T.text, false, "medium")
    name:SetPoint("LEFT", box, "RIGHT", 12, 0)
    name:SetWidth(186)
    name:SetText(module.title)

    -- A la derecha: chevron a los ajustes, interruptor y aviso «al recargar».
    local go = CreateFrame("Button", nil, row)
    go:SetSize(30, ROW_H)
    go:SetPoint("RIGHT", 0, 0)
    local chevron = go:CreateTexture(nil, "ARTWORK")
    chevron:SetSize(12, 12)
    chevron:SetPoint("CENTER")
    chevron:SetTexture(M.ICONS.chevron)
    chevron:SetVertexColor(unpack(T.min))
    go:SetShown(info.page ~= nil)
    go:SetScript("OnClick", function() if info.page then C.Select(info.page) end end)
    go:SetScript("OnEnter", function()
        chevron:SetVertexColor(unpack(T.text))
        GameTooltip:SetOwner(go, "ANCHOR_RIGHT")
        GameTooltip:SetText("Ajustes de " .. module.title)
        GameTooltip:Show()
    end)
    go:SetScript("OnLeave", function()
        chevron:SetVertexColor(unpack(T.min))
        GameTooltip:Hide()
    end)

    local switch = W.Switch(row)
    switch:SetPoint("RIGHT", go, "LEFT", -6, 0)
    local hit = CreateFrame("Button", nil, row)
    hit:SetAllPoints(switch)
    local warn = W.Text(row, 11, T.warn)
    warn:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    warn:SetText("al recargar")

    local desc = W.Text(row, 12, T.dim)
    desc:SetPoint("LEFT", name, "RIGHT", 12, 0)
    desc:SetPoint("RIGHT", warn, "LEFT", -10, 0)
    desc:SetText(info.desc or "")

    row:EnableMouse(true)
    row:SetScript("OnEnter", function() hover:Show() end)
    row:SetScript("OnLeave", function() hover:Hide() end)
    hit:SetScript("OnClick", function()
        if not module.db then return end
        module.db.enabled = not module.db.enabled
        onChange()
        ns.AskReload()
    end)
    hit:SetScript("OnEnter", function() hover:Show() end)
    hit:SetScript("OnLeave", function() hover:Hide() end)

    function row:Refresh()
        local on = module.db and module.db.enabled and true or false
        switch:SetOn(on)
        -- Solo se avisa si el estado guardado no es el que está funcionando;
        -- sin aviso, la descripción usa también ese hueco.
        local resting = on and module.padResting == true
        local pending = resting or on ~= (module.active and true or false)
        warn:SetText(resting and (module.padLite and "en parte, por el mando" or "apartado por el mando") or "al recargar")
        warn:SetShown(pending)
        desc:ClearAllPoints()
        desc:SetPoint("LEFT", name, "RIGHT", 12, 0)
        desc:SetPoint("RIGHT", pending and warn or switch, "LEFT", -10, 0)
    end
    return row
end

C.RegisterPage("general", "Inicio", 0, function(content, width)
    local L = W.Layout(content, width)
    local G = ns.Graphics

    -- Tira de estado: gráficos, perfil y marcos.
    local strip = CreateFrame("Frame", nil, content)
    strip:SetHeight(46)
    W.Panel(strip, T.radius, T.chrome, T.line)
    local segs = {
        StatusSegment(strip, "Gráficos", "Cambiar", function() C.Select("graphics") end),
        StatusSegment(strip, "Perfil", "Perfiles", function() C.Select("profiles") end),
        StatusSegment(strip, "Marcos", "Mover", function()
            ns.Movers.Toggle()
            C.RefreshTools()
            strip:Refresh()
        end),
    }
    local dividers = {}
    for i = 1, 2 do dividers[i] = W.Line(strip, T.line, true) end
    function strip:Refresh()
        local w = (L.width - 2) / 3
        for i, seg in ipairs(segs) do
            seg:ClearAllPoints()
            seg:SetPoint("TOPLEFT", 1 + (i - 1) * w, -1)
            seg:SetWidth(w)
        end
        for i, d in ipairs(dividers) do
            d:ClearAllPoints()
            d:SetPoint("TOPLEFT", 1 + i * w, -1)
            d:SetPoint("BOTTOMLEFT", 1 + i * w, 1)
        end
        local current = G and G.Current and G.Current()
        segs[1].value:SetText(current and G.byKey and G.byKey[current] and G.byKey[current].name
            or (G and "Personalizados" or "Módulo apagado"))
        segs[2].value:SetText("Propio")
        segs[3].value:SetText(ns.Movers.unlocked and "Desbloqueados" or "Bloqueados")
        local b = segs[3].button
        b.text:SetText(ns.Movers.unlocked and "Bloquear" or "Mover")
        b:SetWidth(math.ceil(b.text:GetStringWidth() + 22))
    end
    L:Full(strip)
    L.y = L.y - 6

    -- Módulos: título, cuenta y filtro segmentado.
    local filter = "all"
    local rows, groupHeads = {}, {}
    local list = CreateFrame("Frame", nil, content)
    local head = CreateFrame("Frame", nil, content)
    head:SetHeight(26)
    local headText = W.Text(head, 17, T.text, false, "head")
    headText:SetPoint("LEFT")
    headText:SetText(W.Upper("Módulos"))
    local count = W.Text(head, 12, T.dim)
    count:SetPoint("LEFT", headText, "RIGHT", 10, 0)
    local function RefreshAll()
        list:Refresh()
        head:Refresh()
    end
    local seg = W.Segmented(head, { { "all", "Todos" }, { "on", "Encendidos" }, { "off", "Apagados" } },
        function() return filter end, function(value)
            filter = value
            RefreshAll()
        end)
    seg:SetPoint("RIGHT")
    function head:Refresh()
        local on, total = 0, 0
        for _, row in ipairs(rows) do
            total = total + 1
            if row.module.db and row.module.db.enabled then on = on + 1 end
        end
        count:SetText(on .. " de " .. total .. " encendidos")
        seg:Refresh()
    end
    L:Full(head)

    -- Filas agrupadas por categoría.
    for _, key in ipairs(ns.moduleOrder) do
        local module = ns.modules[key]
        local info = ModuleInfo(module.name)
        local row = ModuleRow(list, module, info, RefreshAll)
        row.group = info.group or "OTROS"
        rows[#rows + 1] = row
    end
    for _, group in ipairs(C.GROUPS) do
        if group ~= "" then
            local gh = CreateFrame("Frame", nil, list)
            gh:SetHeight(30)
            local title = W.SectionTitle(gh, C.GROUP_NAMES[group])
            title:SetPoint("BOTTOMLEFT", 10, 7)
            local line = W.Line(gh, T.sectionLine)
            line:SetPoint("BOTTOMLEFT")
            line:SetPoint("BOTTOMRIGHT")
            groupHeads[group] = gh
        end
    end
    function list:Refresh()
        local y = 0
        for _, group in ipairs(C.GROUPS) do
            local gh = groupHeads[group]
            local any = false
            for _, row in ipairs(rows) do
                if row.group == group then
                    local on = row.module.db and row.module.db.enabled and true or false
                    local show = filter == "all" or (filter == "on") == on
                    row:SetShown(show)
                    if show then
                        if not any and gh then
                            gh:ClearAllPoints()
                            gh:SetPoint("TOPLEFT", 0, y)
                            gh:SetPoint("RIGHT")
                            gh:Show()
                            y = y - 30
                        end
                        any = true
                        row:ClearAllPoints()
                        row:SetPoint("TOPLEFT", 0, y)
                        row:SetPoint("RIGHT")
                        row:Refresh()
                        y = y - ROW_H
                    end
                end
            end
            if gh and not any then gh:Hide() end
        end
        self:SetHeight(math.max(1, -y))
    end
    list:Refresh()
    L:Full(list)
    L.y = L.y - 4

    for _, build in ipairs(C.generalCards) do build(L, content) end

    L:Card("Atajos")
    L:Note("/bui abre esta ventana · /bui mover desbloquea los marcos para moverlos · /bui reset los devuelve a su sitio · /blazz abre los ajustes del juego de tu main (en Perfiles).")
    L:EndCard()

    return L
end)

---------------------------------------------------------------------------
-- Acceso desde Esc > Opciones > AddOns
---------------------------------------------------------------------------
function ns.BuildOptions()
    local panel = CreateFrame("Frame")
    panel.name = "BlazzitoUI"
    panel:Hide()
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff4fc3f7BlazzitoUI|r")
    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    desc:SetText("Toda la configuración está en su propia ventana (también con /bui).")
    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(220, 26)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    open:SetText("Abrir configuración")
    open:SetScript("OnClick", function() C.Toggle("general") end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "BlazzitoUI")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
