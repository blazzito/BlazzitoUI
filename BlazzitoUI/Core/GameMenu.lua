-- Botón "BlazzitoUI" en el menú de Escape, para abrir la configuración sin
-- escribir /bui. Se coloca debajo de "AddOns" (u "Opciones") y empuja hacia
-- abajo los botones de Blizzard que van después.
local _, ns = ...

if not GameMenuFrame then return end

local GAP, EXTRA = 12, 40
local button, baseHeight

local function CreateButton()
    local ok, b = pcall(CreateFrame, "Button", "BlazzitoUI_GameMenuButton", GameMenuFrame, "MainMenuFrameButtonTemplate")
    if not ok then
        b = CreateFrame("Button", "BlazzitoUI_GameMenuButton", GameMenuFrame, "UIPanelButtonTemplate")
    end
    b:SetSize(200, 35)
    b:SetText("|cff4fc3f7Blazzito|r|cffffffffUI|r")
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
    button:ClearAllPoints()
    button:SetPoint("TOP", anchor, "BOTTOM", 0, -GAP)
    button:Show()

    -- Hace sitio: baja los botones que están por debajo del de referencia.
    local anchorBottom = anchor:GetBottom()
    if anchorBottom then
        for menuButton in GameMenuFrame.buttonPool:EnumerateActive() do
            local top = menuButton:GetTop()
            if top and top < anchorBottom + 2 then
                local point, relative, relativePoint, x, y = menuButton:GetPoint(1)
                if point then
                    menuButton:ClearAllPoints()
                    menuButton:SetPoint(point, relative, relativePoint, x, (y or 0) - EXTRA)
                end
            end
        end
    end
    baseHeight = baseHeight or GameMenuFrame:GetHeight()
    GameMenuFrame:SetHeight(baseHeight + EXTRA)
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
