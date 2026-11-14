-- Botón "BlazzitoUI" en el menú de Escape, para abrir la configuración sin
-- escribir /bui. Se coloca debajo de "AddOns" (u "Opciones") y empuja hacia
-- abajo los botones de Blizzard que van después.
local _, ns = ...

if not GameMenuFrame then return end

local GAP = 12           -- separación si no se puede medir la de Blizzard
local button

-- Nuestro botón (es nuestro: se pinta directamente): relleno del color de tu
-- clase, borde fino oscuro y texto oscuro o claro según lo claro que sea
-- el color, para que siempre se lea.
local function Paint(b)
    local W = ns.Widgets
    local a = (W and W.COLORS and W.COLORS.accent) or ns.Media.COLORS.accent
    for _, region in pairs({ b:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not b.bui[region] then region:SetAlpha(0) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture" }) do
        local t = b[getter] and b[getter](b)
        if t and not b.bui[t] then t:SetAlpha(0) end
    end
    local px = ns.Media.PixelSize()
    b.bui.edge:SetPoint("TOPLEFT", 2, -2)
    b.bui.edge:SetPoint("BOTTOMRIGHT", -2, 2)
    b.bui.edge:SetColorTexture(0, 0, 0, 1)
    b.bui.fill:SetPoint("TOPLEFT", b.bui.edge, "TOPLEFT", px, -px)
    b.bui.fill:SetPoint("BOTTOMRIGHT", b.bui.edge, "BOTTOMRIGHT", -px, px)
    b.bui.fill:SetColorTexture(a[1], a[2], a[3], 0.92)
    b.bui.hover:SetAllPoints(b.bui.fill)
    b.bui.hover:SetColorTexture(1, 1, 1, 0.18)
    -- Luminancia del color: texto oscuro sobre colores claros, claro sobre oscuros.
    local light = 0.299 * a[1] + 0.587 * a[2] + 0.114 * a[3] > 0.5
    b:SetText(light and "|cff0d0e10BlazzitoUI|r" or "|cffffffffBlazzitoUI|r")
end

local function CreateButton()
    local ok, b = pcall(CreateFrame, "Button", "BlazzitoUI_GameMenuButton", GameMenuFrame, "MainMenuFrameButtonTemplate")
    if not ok then
        b = CreateFrame("Button", "BlazzitoUI_GameMenuButton", GameMenuFrame, "UIPanelButtonTemplate")
    end
    b:SetSize(200, 35)
    b.bui = {}
    b.bui.edge = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    b.bui.fill = b:CreateTexture(nil, "BACKGROUND", nil, -7)
    b.bui.hover = b:CreateTexture(nil, "HIGHLIGHT", nil, 7)
    for _, t in ipairs({ b.bui.edge, b.bui.fill, b.bui.hover }) do b.bui[t] = true end
    Paint(b)
    b:HookScript("OnShow", Paint)
    b:SetScript("OnClick", function()
        if InCombatLockdown() then
            ns.Print("abre la configuración fuera de combate.")
            return
        end
        HideUIPanel(GameMenuFrame)
        ns.Config.Open()
    end)
    return b
end

local function FindAnchor()
    local anchor
    for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
        local text = menuButton:GetText()
        if text == ADDONS then return menuButton end
        if text == GAMEMENU_OPTIONS then anchor = menuButton end
    end
    return anchor
end

local function Layout()
    if InCombatLockdown() then
        button:Hide()
        return
    end
    local anchor = FindAnchor()
    if not anchor then
        button:Hide()
        return
    end
    local width, height = anchor:GetWidth(), anchor:GetHeight()
    if width and width > 0 then button:SetSize(width, height or 35) end
    height = button:GetHeight()

    -- Nuestro botón va en su propio grupo, con la misma separación que usa
    -- Blizzard entre grupos (la que hay entre "AddOns" y el siguiente).
    local anchorBottom = anchor:GetBottom()
    local gap = GAP
    if anchorBottom then
        local nextTop
        for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
            local top = menuButton:GetTop()
            if top and top < anchorBottom + 2 and (not nextTop or top > nextTop) then nextTop = top end
        end
        if nextTop and anchorBottom - nextTop >= 4 and anchorBottom - nextTop <= 40 then
            gap = anchorBottom - nextTop
        end
    end
    button:ClearAllPoints()
    button:SetPoint("TOP", anchor, "BOTTOM", 0, -gap)
    button:Show()

    -- Hace sitio: baja los botones de debajo lo que mide el nuestro más una separación.
    local extra = height + gap
    if anchorBottom then
        for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
            local top = menuButton:GetTop()
            if top and top < anchorBottom + 2 then
                local point, relative, relativePoint, x, y = menuButton:GetPoint(1)
                if point then
                    menuButton:ClearAllPoints()
                    menuButton:SetPoint(point, relative, relativePoint, x, (y or 0) - extra)
                end
            end
        end
    end
    -- Blizzard rehace el alto en cada Layout (y este gancho va justo después).
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + extra)
end

-- Al entrar al juego, cuando ya se sabe el estilo de interfaz: con el de
-- mando la cruceta recorre este menú y pulsaría nuestro botón, que lo cierra
-- desde nuestro código (contamina su navegación). Ahí solo si se pide (Pad.lua).
local function Setup()
    if button then return end
    if ns.Pad and not ns.Pad.Keep("GameMenu") then return end
    button = CreateButton()
    if GameMenuFrame.buttonPool and GameMenuFrame.Layout then
        hooksecurefunc(GameMenuFrame, "Layout", Layout)
    else
        -- Menú antiguo sin lista de botones: el botón queda justo debajo del menú.
        button:SetPoint("TOP", GameMenuFrame, "BOTTOM", 0, -4)
    end
end
ns.On("PLAYER_LOGIN", Setup)
