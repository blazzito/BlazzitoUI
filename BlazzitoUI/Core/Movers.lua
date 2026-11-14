-- Modo mover (/bui mover). Muestra una cuadrícula y una capa azul sobre cada
-- marco registrado.
--  * Arrastrar con clic izquierdo mueve el marco.
--  * Clic derecho cambia su pivote: el punto del marco (centro, un borde o una
--    esquina) que se ancla a la cuadrícula.
-- Las posiciones se guardan como { pivote, "CENTER", x, y }: distancia desde el
-- centro de la pantalla hasta el pivote. Con pivotes enfrentados (jugador a la
-- derecha, objetivo a la izquierda) dos marcos son simétricos con x opuestas.
-- Solo fuera de combate: los marcos seguros no se pueden mover en combate.
local _, ns = ...
local Tr = ns.Translate

local Movers = { entries = {}, unlocked = false }
ns.Movers = Movers

Movers.DEFAULTS = { grid = true, snap = true, size = 16 }

local PIVOTS = { "CENTER", "LEFT", "RIGHT", "TOP", "BOTTOM", "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local PIVOT_NAMES = {
    CENTER = "centro", LEFT = "izquierda", RIGHT = "derecha", TOP = "arriba", BOTTOM = "abajo",
    TOPLEFT = "arriba izq.", TOPRIGHT = "arriba der.", BOTTOMLEFT = "abajo izq.", BOTTOMRIGHT = "abajo der.",
}

local function Settings()
    return ns.db.movers
end

local function Round(value)
    return math.floor(value + 0.5)
end

local function Snap(value)
    local s = Settings()
    if not s.snap then return Round(value) end
    return Round(value / s.size) * s.size
end

-- Coordenadas del pivote del marco, relativas al centro de la pantalla.
local function PivotOffset(frame, pivot)
    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    local x = (pivot:find("LEFT") and left) or (pivot:find("RIGHT") and right) or (left + right) / 2
    local y = (pivot:find("TOP") and top) or (pivot:find("BOTTOM") and bottom) or (top + bottom) / 2
    local cx, cy = UIParent:GetCenter()
    return x - cx, y - cy
end

local function Position(entry)
    return entry.store[entry.key] or entry.default
end

function Movers.Apply(entry)
    local p = Position(entry)
    entry.frame:ClearAllPoints()
    entry.frame:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function UpdateOverlay(entry)
    local overlay = entry.overlay
    if not overlay then return end
    local p = Position(entry)
    overlay.dot:ClearAllPoints()
    overlay.dot:SetPoint("CENTER", overlay, p[1], 0, 0)
    overlay.info:SetText(string.format("%s\n|cffbbbbbb%s · %d, %d|r", Tr(entry.label), Tr(PIVOT_NAMES[p[1]] or p[1]), p[3], p[4]))
end

-- Guarda la posición actual usando el pivote indicado, ajustada a la cuadrícula.
local function Save(entry, pivot)
    local x, y = PivotOffset(entry.frame, pivot)
    entry.store[entry.key] = { pivot, "CENTER", Snap(x), Snap(y) }
    Movers.Apply(entry)
    UpdateOverlay(entry)
end

local function NextPivot(current)
    for i, pivot in ipairs(PIVOTS) do
        if pivot == current then return PIVOTS[i % #PIVOTS + 1] end
    end
    return PIVOTS[1]
end

local function CreateOverlay(entry)
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetFrameStrata("DIALOG")
    overlay:SetAllPoints(entry.frame)
    overlay:RegisterForDrag("LeftButton")
    overlay:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local tint = overlay:CreateTexture(nil, "OVERLAY")
    tint:SetAllPoints()
    local c = ns.Media.COLORS.accent
    tint:SetColorTexture(c[1], c[2], c[3], 0.30)
    overlay.tint = tint

    local dot = overlay:CreateTexture(nil, "OVERLAY", nil, 2)
    dot:SetSize(7, 7)
    dot:SetColorTexture(1, 1, 1, 1)
    overlay.dot = dot

    local info = ns.Media.Font(overlay, 10, "CENTER")
    info:SetPoint("CENTER")
    info:SetWordWrap(true)
    overlay.info = info

    overlay:SetScript("OnDragStart", function()
        if InCombatLockdown() then return end
        entry.frame:SetMovable(true)
        entry.frame:StartMoving()
    end)
    overlay:SetScript("OnDragStop", function()
        entry.frame:StopMovingOrSizing()
        entry.frame:SetUserPlaced(false)
        if not InCombatLockdown() then Save(entry, Position(entry)[1]) end
        Movers.Select(entry)
    end)
    overlay:SetScript("OnClick", function(_, button)
        if InCombatLockdown() then return end
        if button == "RightButton" then
            Save(entry, NextPivot(Position(entry)[1]))
            if Movers.selected == entry then Movers.RefreshDetail() end
        else
            Movers.Select(entry)
        end
    end)
    overlay:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(Tr(entry.label))
        GameTooltip:AddLine(Tr("Arrastra para mover. Clic: ajustes precisos. Clic derecho: cambiar el pivote.")
            .. (entry.hooks.setSize and (" " .. Tr("Esquina inferior derecha: tamaño.")) or ""), 1, 1, 1, true)
        GameTooltip:Show()
    end)

    -- Tirador de tamaño: arrastrar la esquina cambia ancho y alto en vivo.
    if entry.hooks.setSize then
        local grip = CreateFrame("Button", nil, overlay)
        grip:SetSize(14, 14)
        grip:SetPoint("BOTTOMRIGHT", 0, 0)
        grip:SetFrameLevel(overlay:GetFrameLevel() + 2)
        local gt = grip:CreateTexture(nil, "OVERLAY")
        gt:SetAllPoints()
        gt:SetColorTexture(1, 1, 1, 0.85)
        local gi = grip:CreateTexture(nil, "OVERLAY", nil, 1)
        gi:SetPoint("TOPLEFT", 3, -3)
        gi:SetPoint("BOTTOMRIGHT", -3, 3)
        gi:SetColorTexture(c[1], c[2], c[3], 1)
        grip:SetScript("OnMouseDown", function(self)
            if InCombatLockdown() then return end
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            self.startX, self.startY = x / scale, y / scale
            self.w0, self.h0 = entry.hooks.getSize()
            self.resizing = true
            Movers.Select(entry)
        end)
        grip:SetScript("OnMouseUp", function(self) self.resizing = nil end)
        grip:SetScript("OnUpdate", function(self)
            if not self.resizing then return end
            local scale = UIParent:GetEffectiveScale()
            local x, y = GetCursorPosition()
            local w = Round(self.w0 + (x / scale - self.startX))
            local h = Round(self.h0 - (y / scale - self.startY))
            local cw, ch = entry.hooks.getSize()
            if w ~= cw or h ~= ch then
                entry.hooks.setSize(w, h)
                Movers.RefreshDetail()
            end
        end)
        overlay.grip = grip
    end
    overlay:SetScript("OnLeave", function() GameTooltip:Hide() end)
    overlay:Hide()
    return overlay
end

---------------------------------------------------------------------------
-- Cuadrícula
---------------------------------------------------------------------------
local grid

local function DrawGrid()
    if not grid then
        grid = CreateFrame("Frame", nil, UIParent)
        grid:SetAllPoints(UIParent)
        grid:SetFrameStrata("BACKGROUND")
        grid.lines = {}
    end
    for _, line in ipairs(grid.lines) do line:Hide() end
    local s = Settings()
    if not (Movers.unlocked and s.grid) then
        grid:Hide()
        return
    end

    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    local step, used = s.size, 0
    local accent = ns.Media.COLORS.accent
    local function Line(vertical, offset, major, center)
        used = used + 1
        local line = grid.lines[used]
        if not line then
            line = grid:CreateTexture(nil, "BACKGROUND")
            grid.lines[used] = line
        end
        line:ClearAllPoints()
        if vertical then
            line:SetPoint("TOP", grid, "TOP", offset, 0)
            line:SetSize(center and 2 or 1, height)
        else
            line:SetPoint("LEFT", grid, "LEFT", 0, offset)
            line:SetSize(width, center and 2 or 1)
        end
        if center then
            line:SetColorTexture(accent[1], accent[2], accent[3], 0.8)
        else
            line:SetColorTexture(1, 1, 1, major and 0.16 or 0.06)
        end
        line:Show()
    end
    -- Desde el centro hacia fuera, para que el centro sea siempre una línea.
    for i = 0, math.floor(width / 2 / step) do
        Line(true, i * step, i % 4 == 0, i == 0)
        if i > 0 then Line(true, -i * step, i % 4 == 0) end
    end
    for i = 0, math.floor(height / 2 / step) do
        Line(false, i * step, i % 4 == 0, i == 0)
        if i > 0 then Line(false, -i * step, i % 4 == 0) end
    end
    grid:Show()
end

---------------------------------------------------------------------------
-- Panel flotante del modo mover
---------------------------------------------------------------------------
local controls

local function CreateControls()
    local W = ns.Widgets
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(300, 196)
    panel:SetPoint("TOP", 0, -120)
    panel:SetFrameStrata("FULLSCREEN")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    ns.Media.SetBackdrop(panel, { 0.07, 0.07, 0.08, 0.96 })

    local title = W.Text(panel, 14, ns.Media.COLORS.accent)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(Tr("Modo mover"))
    local hint = W.Text(panel, 11, W.COLORS.muted)
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    hint:SetText(Tr("Clic: ajustes precisos · Clic derecho: pivote."))

    local s = Settings()
    local widgets = {
        W.Toggle(panel, 270, "Mostrar cuadrícula", function() return s.grid end, function(v)
            s.grid = v
            DrawGrid()
        end),
        W.Toggle(panel, 270, "Ajustar a la cuadrícula", function() return s.snap end, function(v) s.snap = v end),
        W.Slider(panel, 270, "Tamaño de la celda", 4, 64, 4, function() return s.size end, function(v)
            s.size = v
            DrawGrid()
        end),
    }
    local y = -50
    for _, widget in ipairs(widgets) do
        widget:SetPoint("TOPLEFT", 14, y)
        y = y - widget:GetHeight() - 8
    end
    local lock = W.Button(panel, 270, "Bloquear marcos", function() Movers.Lock() end, true)
    lock:SetPoint("TOPLEFT", 14, y - 2)

    function panel:Refresh()
        for _, widget in ipairs(widgets) do widget:Refresh() end
    end
    panel:Hide()
    return panel
end

---------------------------------------------------------------------------
-- Ajustes precisos del elemento elegido (clic sobre él)
---------------------------------------------------------------------------
local detail

local function SetOffset(entry, x, y)
    local p = Position(entry)
    entry.store[entry.key] = { p[1], "CENTER", x, y }
    Movers.Apply(entry)
    UpdateOverlay(entry)
end

local function Nudge(dx, dy)
    local entry = Movers.selected
    if not entry or InCombatLockdown() then return end
    local step = IsShiftKeyDown() and 10 or 1
    local p = Position(entry)
    SetOffset(entry, p[3] + dx * step, p[4] + dy * step)
    Movers.RefreshDetail()
end
Movers.Nudge = Nudge

-- Casilla numérica: Intro aplica, Escape deshace.
local function NumberBox(parent, label, width, get, set)
    local W = ns.Widgets
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 40)
    local text = W.Text(f, 11, W.COLORS.muted)
    text:SetPoint("TOPLEFT")
    text:SetText(Tr(label))
    local box = CreateFrame("EditBox", nil, f)
    box:SetPoint("TOPLEFT", 0, -16)
    box:SetSize(width, 22)
    box:SetAutoFocus(false)
    box:SetFont(ns.Media.FONT, 12, "")
    box:SetTextInsets(6, 6, 0, 0)
    ns.Media.SetBackdrop(box, W.COLORS.field)
    box:SetScript("OnEnterPressed", function(self)
        local value = tonumber(self:GetText())
        if value and not InCombatLockdown() then set(Round(value)) end
        self:ClearFocus()
        f:Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Refresh()
    end)
    function f:Refresh()
        if not box:HasFocus() then box:SetText(tostring(get() or "")) end
    end
    f.box = box
    return f
end

local function CreateDetail()
    local W = ns.Widgets
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(300, 246)
    panel:SetFrameStrata("FULLSCREEN")
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:SetClampedToScreen(true)
    ns.Media.SetBackdrop(panel, { 0.07, 0.07, 0.08, 0.96 })

    panel.title = W.Text(panel, 14, ns.Media.COLORS.accent)
    panel.title:SetPoint("TOPLEFT", 14, -12)
    local close = W.Button(panel, 24, "X", function() Movers.Select(nil) end, false, 22)
    close:SetPoint("TOPRIGHT", -8, -8)
    local hint = W.Text(panel, 11, W.COLORS.muted)
    hint:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
    hint:SetText(Tr("Flechas: 1 px (con Mayús: 10 px)."))

    -- Flechas en cruz
    local pad = CreateFrame("Frame", nil, panel)
    pad:SetSize(90, 90)
    pad:SetPoint("TOPLEFT", 14, -52)
    panel.arrows = {}
    local function Arrow(text, dx, dy, point)
        local b = W.Button(pad, 28, text, function() Nudge(dx, dy) end, false, 28)
        b:SetPoint(point)
        panel.arrows[text] = b
        return b
    end
    Arrow("^", 0, 1, "TOP")
    Arrow("v", 0, -1, "BOTTOM")
    Arrow("<", -1, 0, "LEFT")
    Arrow(">", 1, 0, "RIGHT")

    local function Sel() return Movers.selected end
    panel.x = NumberBox(panel, "X", 76, function() return Sel() and Position(Sel())[3] end,
        function(v) local p = Position(Sel()); SetOffset(Sel(), v, p[4]) end)
    panel.x:SetPoint("TOPLEFT", 118, -52)
    panel.y = NumberBox(panel, "Y", 76, function() return Sel() and Position(Sel())[4] end,
        function(v) local p = Position(Sel()); SetOffset(Sel(), p[3], v) end)
    panel.y:SetPoint("LEFT", panel.x, "RIGHT", 10, 0)

    local function Size(i)
        local e = Sel()
        if not (e and e.hooks.getSize) then return "" end
        return (select(i, e.hooks.getSize()))
    end
    panel.w = NumberBox(panel, "Ancho", 76, function() return Size(1) end,
        function(v) local e = Sel(); if e.hooks.setSize then e.hooks.setSize(v, (select(2, e.hooks.getSize()))) end end)
    panel.w:SetPoint("TOPLEFT", panel.x, "BOTTOMLEFT", 0, -8)
    panel.h = NumberBox(panel, "Alto", 76, function() return Size(2) end,
        function(v) local e = Sel(); if e.hooks.setSize then e.hooks.setSize((e.hooks.getSize()), v) end end)
    panel.h:SetPoint("LEFT", panel.w, "RIGHT", 10, 0)

    local pivots = {}
    for i, pivot in ipairs(PIVOTS) do pivots[i] = { value = pivot, text = PIVOT_NAMES[pivot] } end
    panel.pivot = W.Dropdown(panel, 272, "Pivote (el punto que se ancla)", pivots,
        function() return Sel() and Position(Sel())[1] end,
        function(v) if Sel() and not InCombatLockdown() then Save(Sel(), v) end end)
    panel.pivot:SetPoint("TOPLEFT", 14, -156)

    panel:Hide()
    return panel
end

function Movers.RefreshDetail()
    if not (detail and detail:IsShown() and Movers.selected) then return end
    local entry = Movers.selected
    detail.title:SetText(Tr(entry.label))
    detail.x:Refresh()
    detail.y:Refresh()
    local sized = entry.hooks.getSize ~= nil
    detail.w:SetAlpha(sized and 1 or 0.35)
    detail.h:SetAlpha(sized and 1 or 0.35)
    detail.w.box:EnableMouse(sized)
    detail.h.box:EnableMouse(sized)
    detail.w:Refresh()
    detail.h:Refresh()
    detail.pivot:Refresh()
end

-- Elige el elemento al que se aplican los ajustes precisos (nil = ninguno).
-- El elegido se resalta con un tono más intenso.
function Movers.Select(entry)
    local accent = ns.Media.COLORS.accent
    if Movers.selected and Movers.selected.overlay then
        Movers.selected.overlay.tint:SetColorTexture(accent[1], accent[2], accent[3], 0.30)
    end
    Movers.selected = entry
    if not entry then
        if detail then detail:Hide() end
        return
    end
    if entry.overlay then entry.overlay.tint:SetColorTexture(accent[1], accent[2], accent[3], 0.60) end
    detail = detail or CreateDetail()
    Movers.detail = detail
    detail:ClearAllPoints()
    if controls and controls:IsShown() then
        detail:SetPoint("TOP", controls, "BOTTOM", 0, -6)
    else
        detail:SetPoint("TOP", UIParent, "TOP", 0, -330)
    end
    detail:Show()
    Movers.RefreshDetail()
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------
-- store: tabla donde se guardan las posiciones; default: { pivote, "CENTER", x, y }.
-- hooks.onUnlock / hooks.onLock: para mostrar una vista previa mientras se mueve.
function Movers.Register(frame, key, label, default, store, hooks)
    local entry = { frame = frame, key = key, label = label, default = default, store = store, hooks = hooks or {} }
    Movers.entries[#Movers.entries + 1] = entry
    Movers.Apply(entry)
    return entry
end

function Movers.Unlock()
    if InCombatLockdown() then
        ns.Print("no se pueden mover marcos en combate.")
        return
    end
    Movers.unlocked = true
    for _, entry in ipairs(Movers.entries) do
        if entry.hooks.onUnlock then entry.hooks.onUnlock(entry.frame) end
        entry.overlay = entry.overlay or CreateOverlay(entry)
        UpdateOverlay(entry)
        entry.overlay:Show()
    end
    controls = controls or CreateControls()
    controls:Refresh()
    controls:Show()
    DrawGrid()
end

function Movers.Lock()
    if not Movers.unlocked then return end
    Movers.unlocked = false
    for _, entry in ipairs(Movers.entries) do
        if entry.overlay then entry.overlay:Hide() end
        entry.frame:StopMovingOrSizing()
        if entry.hooks.onLock then entry.hooks.onLock(entry.frame) end
    end
    if controls then controls:Hide() end
    Movers.Select(nil)
    DrawGrid()
end

function Movers.Toggle()
    if Movers.unlocked then Movers.Lock() else Movers.Unlock() end
    -- El icono de la cabecera de la ventana refleja el estado.
    if ns.Config and ns.Config.RefreshTools then ns.Config.RefreshTools() end
end

function Movers.ResetAll()
    ns.AfterCombat("MoversReset", function()
        for _, entry in ipairs(Movers.entries) do
            entry.store[entry.key] = nil
            Movers.Apply(entry)
            UpdateOverlay(entry)
        end
        ns.Print("posiciones restablecidas.")
    end)
end

-- Al entrar en combate se bloquea solo: después ya no se podría.
ns.On("PLAYER_REGEN_DISABLED", function() Movers.Lock() end)
