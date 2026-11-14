-- Menú de Esc (GameMenuFrame) con el estilo de BlazzitoUI: marco oscuro con
-- la barra de acento y el título dentro, y botones planos.
--
-- Solo texturas: el borde clásico y la cabecera "Menú de juego" de Blizzard
-- quedan con alfa 0 (Win.Hold), los botones rojos se pintan planos
-- (Win.FlatButton) y el título es un texto nuestro. Los botones no se tocan
-- por dentro: "Cerrar sesión" y "Salir del juego" son acciones protegidas.
-- Como solo son texturas, también vale con el estilo de mando (padSafe).
--
-- Estructura en Forever (MainMenuFrameTemplate): GameMenuFrame.Border
-- (DialogBorderTemplate), GameMenuFrame.Header (DialogHeaderTemplate, por
-- encima del borde superior) y botones de un "pool" que Blizzard rehace al
-- abrir el menú (por eso se repasa en cada OnShow).
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win, M = ns.Windows, ns.Media
local Hold = Win.Hold

local function IsKind(region, kind)
    return type(region) == "table" and region.GetObjectType and region:GetObjectType() == kind
end

-- Título nuestro, centrado en la barra superior del marco.
local function Title(frame, on)
    local d = Win.Parts(frame)
    if not d.gmTitle then
        d.gmTitle = frame:CreateFontString(nil, "OVERLAY")
    end
    local fs = d.gmTitle
    if not fs:SetFont(M.UI_FONT_HEAD, 15, "") then fs:SetFont(M.FONT, 13, "") end
    fs:SetShadowOffset(0, 0)
    fs:ClearAllPoints()
    fs:SetPoint("CENTER", frame, "TOP", 0, -12)
    local W = ns.Widgets
    local text = MAINMENU_BUTTON or "Menú de juego"
    fs:SetText(W and W.Upper and W.Upper(text) or text)
    fs:SetTextColor(0.90, 0.91, 0.92)
    fs:SetShown(on)
end

local function Apply(frame, on)
    -- Borde y cabecera de Blizzard (con el texto de la cabecera).
    for _, key in ipairs({ "Border", "Header" }) do
        local part = Win.Child(frame, key)
        if part then
            for _, region in ipairs(Win.Textures(part)) do Hold(region, on) end
            if part.GetRegions then
                for _, region in pairs({ part:GetRegions() }) do
                    if IsKind(region, "FontString") then Hold(region, on) end
                end
            end
        end
    end
    Title(frame, on)
    -- Botones (los de Blizzard, el de BlazzitoUI y los que añadan otros addons).
    -- El de BlazzitoUI se pinta solo (color de tu clase, Core/GameMenu.lua).
    for _, child in ipairs(Win.Children(frame)) do
        if IsKind(child, "Button") and child ~= BlazzitoUI_GameMenuButton then Win.FlatButton(child, on) end
    end
end

Win.Register({
    key = "gamemenu", title = "Menú de Esc",
    padSafe = true,   -- solo texturas: también con el estilo de mando (Skin.lua)
    frame = function() return GameMenuFrame end,
    apply = Apply,
})
