-- Blazzito_ActionBars: cambia el aspecto de las barras de Blizzard sin
-- reemplazarlas. Las barras, los botones, las teclas, el modo edición y las
-- posiciones siguen siendo los de WoW; aquí solo se pintan encima.
--
-- Reglas para no "contaminar" (taint) los botones seguros de Blizzard:
--  * Nunca se escribe un campo en un botón ni en una barra de Blizzard. Lo
--    nuestro va en tablas aparte (débiles) indexadas por el botón.
--  * Solo se crean texturas propias, se cambia el alfa o el anclaje de las
--    texturas de Blizzard y se les pone una máscara. Nada de Show/Hide,
--    SetParent ni SetScript sobre los marcos de Blizzard.
--  * El aspecto se aplica fuera de combate (anclar regiones de un botón
--    protegido en combate puede estar bloqueado); la visibilidad (alfa) sí
--    funciona en combate.
--  * Ocultar una barra = alfa 0: sigue ahí y sus atajos de teclado funcionan.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret = M.IsSecret
---------------------------------------------------------------------------
-- Formas de los botones (cuadradas, del núcleo: las comparten las bolsas) y
-- de la barra de experiencia (las alargadas de BlazzitoUI).
---------------------------------------------------------------------------
local BUTTON_SHAPES, BUTTON_SHAPE_ORDER, ButtonShape = M.BUTTON_SHAPES, M.BUTTON_SHAPE_ORDER, M.ButtonShape

---------------------------------------------------------------------------
-- Las barras de Blizzard que se pueden vestir
---------------------------------------------------------------------------
local function Numbered(prefix, count)
    return function()
        local list = {}
        for i = 1, count do
            local button = _G[prefix .. i]
            if button then list[#list + 1] = button end
        end
        return list
    end
end

local BAG_BUTTONS = { "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot",
                      "CharacterBag3Slot", "CharacterReagentBag0Slot", "KeyRingButton" }

local BARS = {
    -- toggle: posición de la barra en las casillas de Blizzard (Opciones >
    -- Barras de acción), para activarla o quitarla de verdad.
    -- art: la barra tiene una tira de fondo de Blizzard que se puede quitar.
    { key = "main",   label = "Barra 1 (principal)", tab = "1", kind = "buttons", frames = { "MainActionBar", "MainMenuBar" }, buttons = Numbered("ActionButton", 12) },
    { key = "bar2",   label = "Barra 2",  tab = "2", toggle = 1, kind = "buttons", frames = { "MultiBarBottomLeft" },  buttons = Numbered("MultiBarBottomLeftButton", 12) },
    { key = "bar3",   label = "Barra 3",  tab = "3", toggle = 2, kind = "buttons", frames = { "MultiBarBottomRight" }, buttons = Numbered("MultiBarBottomRightButton", 12) },
    { key = "bar4",   label = "Barra 4 (derecha)", tab = "4", toggle = 3, kind = "buttons", frames = { "MultiBarRight" }, buttons = Numbered("MultiBarRightButton", 12) },
    { key = "bar5",   label = "Barra 5 (derecha 2)", tab = "5", toggle = 4, kind = "buttons", frames = { "MultiBarLeft" }, buttons = Numbered("MultiBarLeftButton", 12) },
    { key = "bar6",   label = "Barra 6",  tab = "6", toggle = 5, kind = "buttons", frames = { "MultiBar5" }, buttons = Numbered("MultiBar5Button", 12) },
    { key = "bar7",   label = "Barra 7",  tab = "7", toggle = 6, kind = "buttons", frames = { "MultiBar6" }, buttons = Numbered("MultiBar6Button", 12) },
    { key = "bar8",   label = "Barra 8",  tab = "8", toggle = 7, kind = "buttons", frames = { "MultiBar7" }, buttons = Numbered("MultiBar7Button", 12) },
    { key = "pet",    label = "Mascota",  tab = "Mascota", kind = "buttons", frames = { "PetActionBar" }, buttons = Numbered("PetActionButton", 10) },
    { key = "stance", label = "Posturas y formas", tab = "Posturas", kind = "buttons", frames = { "StanceBar" }, buttons = Numbered("StanceButton", 10) },
    { key = "bags",   label = "Bolsas", tab = "Bolsas", art = true, kind = "buttons", frames = { "BagsBar" }, buttons = function()
        local list = {}
        for _, name in ipairs(BAG_BUTTONS) do
            if _G[name] then list[#list + 1] = _G[name] end
        end
        return list
    end },
    { key = "micro",  label = "Menú (microbotones)", tab = "Menú", art = true, kind = "micro", frames = { "MicroMenuContainer", "MicroMenu" } },
    { key = "xp",     label = "Experiencia y reputación", tab = "Experiencia", kind = "status",
      frames = { "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer" } },
    -- Temporizadores de golpe (WoW Forever): los datos son los del juego
    -- (C_SwingTimer); las barras las dibuja Swing.lua con este estilo.
    { key = "swing_mh",     label = "Golpe: mano derecha",  tab = "Mano der.", kind = "swing", frames = { "BlazzitoUISwingMainHand" } },
    { key = "swing_oh",     label = "Golpe: mano izquierda", tab = "Mano izq.", kind = "swing", frames = { "BlazzitoUISwingOffHand" } },
    { key = "swing_ranged", label = "Golpe: a distancia",   tab = "Distancia", kind = "swing", frames = { "BlazzitoUISwingRanged" } },
}
local BAR_BY_KEY = {}
for _, bar in ipairs(BARS) do BAR_BY_KEY[bar.key] = bar end

local function CommonDefaults(shape)
    return {
        skin = true, shape = shape, flipH = false, flipV = false,
        border = 1, borderColor = { 0, 0, 0 }, background = 60,
        visibility = "always", hiddenAlpha = 0,
        shown = true,   -- barras que WoW no deja quitar: false = invisible
    }
end

local function BarDefaults(bar)
    if bar.kind == "status" then
        local d = CommonDefaults("slant")
        d.borderColor = { 0, 0, 0 }
        return d
    end
    if bar.kind == "swing" then
        local d = CommonDefaults("slant")
        local colors = { swing_mh = { 0.90, 0.68, 0.25 }, swing_oh = { 0.55, 0.75, 0.95 }, swing_ranged = { 0.45, 0.85, 0.45 } }
        d.color = colors[bar.key]
        d.width, d.height = 200, 12
        d.timeText, d.label, d.hideIdle, d.rangeTint = true, true, false, true
        return d
    end
    local d = CommonDefaults(bar.kind == "micro" and "rounded" or "slant")
    if bar.art then d.hideArt = true end
    if bar.kind == "buttons" then
        d.hotkey = true
        d.macroName = false
        d.count = true
        d.hoverGlow = true
    end
    return d
end

local defaults = { bars = {}, positions = {},
                   style = { hideArt = true, fadeTime = 0.25, showWhileDragging = true, hideBlizzardSwing = true,
                             lockPaging = false } }
for _, bar in ipairs(BARS) do defaults.bars[bar.key] = BarDefaults(bar) end

local AB = ns.NewModule("ActionBars", "Barras de acción", defaults)
ns.ActionBars = AB
AB.BARS, AB.BAR_BY_KEY = BARS, BAR_BY_KEY
AB.BUTTON_SHAPES, AB.BUTTON_SHAPE_ORDER = BUTTON_SHAPES, BUTTON_SHAPE_ORDER
AB.ButtonShape = ButtonShape
AB.editing = "main"

local function Frames(bar)
    local list = {}
    for _, name in ipairs(bar.frames) do
        local frame = _G[name]
        if frame and not (frame.IsForbidden and frame:IsForbidden()) then list[#list + 1] = frame end
    end
    -- Barra 1: con MainActionBar no hace falta MainMenuBar (no existe en 12.1).
    if bar.key == "main" or bar.key == "micro" then return { list[1] } end
    return list
end
AB.Frames = Frames

---------------------------------------------------------------------------
-- Datos propios por objeto de Blizzard (tablas débiles: nunca se escribe en
-- el objeto).
---------------------------------------------------------------------------
local skins = setmetatable({}, { __mode = "k" })     -- botón/barra -> nuestras piezas
local held = setmetatable({}, { __mode = "k" })      -- región -> true mientras la ocultamos
local hooked = setmetatable({}, { __mode = "k" })
AB.skins = skins

-- Mantiene una región de Blizzard a alfa 0 (o la suelta). El gancho va en la
-- propia textura o cadena de texto, nunca en el botón seguro.
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
AB.Hold = Hold

local function Child(button, key, suffix)
    local region = button[key]
    if type(region) ~= "table" then region = nil end
    if region == nil and suffix and button.GetName then
        local name = button:GetName()
        if name then region = _G[name .. suffix] end
    end
    return type(region) == "table" and region or nil
end

-- Tamaño de n píxeles reales para un marco con su propia escala.
local function Pixels(frame, n)
    if n <= 0 then return 0 end
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(n, frame:GetEffectiveScale(), n)
    end
    return n
end

local function SavePoints(region)
    local points = {}
    for i = 1, region:GetNumPoints() or 0 do points[i] = { region:GetPoint(i) } end
    return points
end

local function RestorePoints(region, points)
    if not points then return end
    region:ClearAllPoints()
    for _, p in ipairs(points) do region:SetPoint(unpack(p)) end
end

-- Quita las máscaras de Blizzard de una textura (y las recuerda para
-- devolverlas). Con máscara, SetTexCoord falla.
local function Unmask(texture, keep, removed)
    if not (texture and texture.GetNumMaskTextures) then return end
    local ok, count = pcall(texture.GetNumMaskTextures, texture)
    if not ok or IsSecret(count) or type(count) ~= "number" then return end
    for i = count, 1, -1 do
        local okMask, mask = pcall(texture.GetMaskTexture, texture, i)
        if okMask and mask and mask ~= keep then
            pcall(texture.RemoveMaskTexture, texture, mask)
            if removed then removed[#removed + 1] = mask end
        end
    end
end

---------------------------------------------------------------------------
-- Botones (barras de acción, mascota, posturas y bolsas)
---------------------------------------------------------------------------
local function ButtonParts(button)
    local d = skins[button]
    if d then return d end
    d = {}
    d.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.bg = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.mask = button:CreateMaskTexture()
    -- Capa HIGHLIGHT: el propio juego la enciende al pasar el ratón.
    d.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 7)
    d.hover:SetBlendMode("ADD")
    d.state = button:CreateTexture(nil, "OVERLAY", nil, 6)   -- pulsado / activo
    d.state:Hide()
    local icon = Child(button, "icon", "Icon") or Child(button, "Icon", "IconTexture")
    d.icon = icon
    d.cooldown = Child(button, "cooldown", "Cooldown")
    if icon then d.iconPoints = SavePoints(icon) end
    if d.cooldown then d.cooldownPoints = SavePoints(d.cooldown) end
    skins[button] = d
    return d
end

-- Texturas decorativas de Blizzard que tapan nuestra forma.
local function ButtonArt(button)
    -- Sin huecos: si falta una, ipairs se pararía ahí y no se ocultaría el resto.
    local list = {}
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
        button.GetCheckedTexture and button:GetCheckedTexture(),
        Child(button, "SlotBackground"), Child(button, "SlotArt"),
        Child(button, "Border", "Border"), Child(button, "IconBorder"),
        Child(button, "FloatingBG", "FloatingBG"),
    }) do list[#list + 1] = region end
    return list
end

-- Texturas de Blizzard que son marco o fondo (por su atlas), p. ej. el marco
-- de las ranuras de bolsa o el fondo de los microbotones.
local ART_ATLAS = { "iconframe", "buttonbg", "background", "actionbar-frame", "-frame" }
local function IsArtAtlas(region)
    local atlas = region.GetAtlas and region:GetAtlas()
    if type(atlas) ~= "string" or IsSecret(atlas) then return false end
    atlas = atlas:lower()
    for _, want in ipairs(ART_ATLAS) do
        if atlas:find(want, 1, true) then return true end
    end
    return false
end

local function Textures(frame)
    local list = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then list[#list + 1] = region end
    end
    return list
end

-- Quita (o devuelve) el arte de fondo de una barra: las texturas de sus
-- propios marcos y de los marcos que no son botones, y el marco/fondo de
-- cada botón. Nunca toca el icono ni lo nuestro.
local function HoldBarArt(bar, hide, buttons)
    for _, frame in ipairs(bar.frames) do
        frame = _G[frame]
        if type(frame) == "table" and frame.GetRegions then
            for _, region in ipairs(Textures(frame)) do Hold(region, hide) end
            for _, child in ipairs({ frame:GetChildren() }) do
                if type(child) == "table" and child.GetObjectType and child:GetObjectType() == "Frame" and not skins[child] then
                    for _, region in ipairs(Textures(child)) do Hold(region, hide) end
                end
            end
        end
    end
    for _, button in ipairs(buttons) do
        local d = skins[button]
        -- Con nuestro estilo puesto, el marco del botón ya está oculto por él.
        if not hide and d and d.active then break end
        local icon = d and d.icon or Child(button, "icon", "Icon")
        for _, region in ipairs(Textures(button)) do
            local ours = d and (region == d.border or region == d.bg or region == d.hover or region == d.state)
            if region ~= icon and not ours and IsArtAtlas(region) then Hold(region, hide) end
        end
        Hold(Child(button, "Background"), hide)
        Hold(Child(button, "PushedBackground"), hide)
        Hold(Child(button, "IconBorder"), hide)
    end
end
AB.HoldBarArt = HoldBarArt

local function SkinButton(button, cfg)
    local d = ButtonParts(button)
    local file = ButtonShape(cfg.shape, cfg.flipH, cfg.flipV)
    local b = Pixels(button, cfg.border or 0)
    d.file, d.cfg = file, cfg

    d.border:ClearAllPoints()
    d.border:SetAllPoints(button)
    d.border:SetTexture(file)
    local bc = cfg.borderColor or { 0, 0, 0 }
    d.border:SetVertexColor(bc[1], bc[2], bc[3], 1)
    d.border:SetShown(b > 0)

    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
    d.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
    d.bg:SetTexture(file)
    d.bg:SetVertexColor(0.05, 0.05, 0.06, (cfg.background or 60) / 100)
    d.bg:Show()

    d.mask:ClearAllPoints()
    d.mask:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
    d.mask:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
    d.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    for _, region in ipairs({ d.hover, d.state }) do
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
        region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
        region:SetTexture(file)
    end
    d.hover:SetVertexColor(1, 1, 1, cfg.hoverGlow == false and 0 or 0.22)

    local icon = d.icon
    if icon then
        if not d.blizzMasks then
            d.blizzMasks = {}
            Unmask(icon, d.mask, d.blizzMasks)
        else
            Unmask(icon, d.mask)
        end
        if not d.masked then
            pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
            icon:AddMaskTexture(d.mask)
            d.masked = true
        end
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
    end

    local cooldown = d.cooldown
    if cooldown then
        cooldown:ClearAllPoints()
        cooldown:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
        cooldown:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
        if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, file) end
    end

    for _, region in ipairs(ButtonArt(button)) do Hold(region, true) end
    if cfg.hotkey ~= nil then Hold(Child(button, "HotKey", "HotKey"), not cfg.hotkey) end
    if cfg.macroName ~= nil then Hold(Child(button, "Name", "Name"), not cfg.macroName) end
    if cfg.count ~= nil then Hold(Child(button, "Count", "Count"), not cfg.count) end
    d.active = true
end

local function UnskinButton(button)
    local d = skins[button]
    if not (d and d.active) then return end
    d.active = false
    d.border:Hide(); d.bg:Hide(); d.state:Hide()
    d.hover:SetVertexColor(1, 1, 1, 0)
    local icon = d.icon
    if icon then
        if d.masked then
            icon:RemoveMaskTexture(d.mask)
            d.masked = false
        end
        pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        for _, mask in ipairs(d.blizzMasks or {}) do pcall(icon.AddMaskTexture, icon, mask) end
        d.blizzMasks = nil
        RestorePoints(icon, d.iconPoints)
    end
    if d.cooldown then
        RestorePoints(d.cooldown, d.cooldownPoints)
        if d.cooldown.SetSwipeTexture then pcall(d.cooldown.SetSwipeTexture, d.cooldown, "") end
    end
    for _, region in ipairs(ButtonArt(button)) do Hold(region, false) end
    Hold(Child(button, "HotKey", "HotKey"), false)
    Hold(Child(button, "Name", "Name"), false)
    Hold(Child(button, "Count", "Count"), false)
end

-- Estado pulsado / activo (el de Blizzard queda oculto): se lee del botón.
local function UpdateButtonState(button, d)
    if not d.active then return end
    local checked = button.GetChecked and button:GetChecked()
    local pushed = button.GetButtonState and button:GetButtonState() == "PUSHED"
    if IsSecret(checked) then checked = false end
    if pushed then
        d.state:SetVertexColor(0, 0, 0, 0.45)
        d.state:SetBlendMode("BLEND")
        d.state:Show()
    elseif checked then
        local a = M.COLORS.accent
        d.state:SetVertexColor(a[1], a[2], a[3], 0.35)
        d.state:SetBlendMode("ADD")
        d.state:Show()
    else
        d.state:Hide()
    end
end

---------------------------------------------------------------------------
-- Microbotones del menú: la ilustración de cada uno es su propio icono, así
-- que se deja y se le pone debajo un fondo con forma y borde.
---------------------------------------------------------------------------
local function MicroButtons()
    local list = {}
    local menu = _G.MicroMenu
    if not menu then return list end
    for _, child in ipairs({ menu:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" and not (child.IsForbidden and child:IsForbidden()) then
            list[#list + 1] = child
        end
    end
    return list
end
AB.MicroButtons = MicroButtons

local function SkinMicro(button, cfg)
    local d = skins[button]
    if not d then
        d = { border = button:CreateTexture(nil, "BACKGROUND", nil, -8), bg = button:CreateTexture(nil, "BACKGROUND", nil, -7) }
        skins[button] = d
    end
    local file = ButtonShape(cfg.shape, cfg.flipH, cfg.flipV)
    local b = Pixels(button, cfg.border or 0)
    d.border:ClearAllPoints()
    d.border:SetAllPoints(button)
    d.border:SetTexture(file)
    local bc = cfg.borderColor or { 0, 0, 0 }
    d.border:SetVertexColor(bc[1], bc[2], bc[3], 1)
    d.border:SetShown(b > 0)
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", button, "TOPLEFT", b, -b)
    d.bg:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -b, b)
    d.bg:SetTexture(file)
    d.bg:SetVertexColor(0.05, 0.05, 0.06, (cfg.background or 60) / 100)
    d.bg:Show()
    Hold(Child(button, "Background"), true)
    Hold(Child(button, "PushedBackground"), true)
    d.active = true
end

local function UnskinMicro(button)
    local d = skins[button]
    if not (d and d.active) then return end
    d.active = false
    d.border:Hide(); d.bg:Hide()
    if not (AB.db and AB.db.bars.micro.hideArt) then
        Hold(Child(button, "Background"), false)
        Hold(Child(button, "PushedBackground"), false)
    end
end

---------------------------------------------------------------------------
-- Barra de experiencia / reputación: cada StatusBar de los contenedores de
-- Blizzard recibe la forma alargada (con el final del relleno siguiendo la
-- forma, como las barras de vida) y un fondo y borde propios.
---------------------------------------------------------------------------
local function FindStatusBars(frame, list, depth)
    list = list or {}
    depth = depth or 0
    if depth > 4 then return list end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "StatusBar" then
            list[#list + 1] = child
        end
        FindStatusBars(child, list, depth + 1)
    end
    return list
end
AB.FindStatusBars = FindStatusBars

local function SkinStatus(bar, cfg)
    local d = skins[bar]
    if not d then
        d = {
            border = bar:CreateTexture(nil, "BACKGROUND", nil, -8),
            bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7),
            mask = bar:CreateMaskTexture(),
            lead = bar:CreateMaskTexture(),
        }
        skins[bar] = d
    end
    local file = M.ShapeTexture(cfg.shape, cfg.flipH, cfg.flipV)
    local b = Pixels(bar, cfg.border or 0)
    d.border:ClearAllPoints()
    d.border:SetPoint("TOPLEFT", bar, "TOPLEFT", -b, b)
    d.border:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", b, -b)
    d.border:SetTexture(file)
    local bc = cfg.borderColor or { 0, 0, 0 }
    d.border:SetVertexColor(bc[1], bc[2], bc[3], 1)
    d.border:SetShown(b > 0)
    d.bg:SetAllPoints(bar)
    d.bg:SetTexture(file)
    d.bg:SetVertexColor(0.05, 0.05, 0.06, (cfg.background or 60) / 100)
    d.bg:Show()
    d.mask:SetAllPoints(bar)
    d.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
    if fill and fill ~= d.fill then
        if d.fill and d.masked then
            d.fill:RemoveMaskTexture(d.mask)
            d.fill:RemoveMaskTexture(d.lead)
        end
        d.fill, d.masked = fill, false
    end
    if fill then
        -- Máscara "de punta": del tamaño de la barra y pegada al final del
        -- relleno, para que el borde del relleno tenga la misma forma.
        local w, h = bar:GetSize()
        d.lead:ClearAllPoints()
        d.lead:SetSize(math.max(w or 1, 1), math.max(h or 1, 1))
        d.lead:SetPoint("RIGHT", fill, "RIGHT", 0, 0)
        d.lead:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not d.masked then
            Unmask(fill, nil)
            fill:AddMaskTexture(d.mask)
            if (M.SHAPES[cfg.shape] or {}).file then fill:AddMaskTexture(d.lead) end
            d.masked = true
        end
    end
    -- Arte de fondo de Blizzard dentro de la barra (lo nuestro lo sustituye).
    for _, region in ipairs({ bar:GetRegions() }) do
        if region ~= fill and region ~= d.border and region ~= d.bg and region.GetDrawLayer
           and region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
            Hold(region, true)
        end
    end
    d.active = true
end

local function UnskinStatus(bar)
    local d = skins[bar]
    if not (d and d.active) then return end
    d.active = false
    d.border:Hide(); d.bg:Hide()
    if d.fill and d.masked then
        d.fill:RemoveMaskTexture(d.mask)
        d.fill:RemoveMaskTexture(d.lead)
        d.masked = false
    end
    for _, region in ipairs({ bar:GetRegions() }) do Hold(region, false) end
end

-- El marco del contenedor (BarFrameTexture y similares) se oculta con la skin.
local function HoldContainerArt(container, hide)
    for _, region in ipairs({ container:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then Hold(region, hide) end
    end
    Hold(container.BarFrameTexture, hide)
end

---------------------------------------------------------------------------
-- Arte de la barra principal (grifos, marco, fondo)
---------------------------------------------------------------------------
local function MainArt()
    local main = _G.MainActionBar or _G.MainMenuBar
    if not main then return {} end
    return { main.EndCaps, main.BorderArt, main.Background, main.BackgroundArt,
             _G.MainMenuBarArtFrame, _G.MainMenuBarArtFrameBackground }
end

---------------------------------------------------------------------------
-- Aplicar
---------------------------------------------------------------------------
function AB.ApplyBar(key)
    local bar = BAR_BY_KEY[key]
    if not (bar and AB.db) then return end
    ns.AfterCombat("ActionBars:" .. key, function()
        local cfg = AB.db.bars[key]
        if bar.kind == "buttons" then
            local buttons = bar.buttons()
            for _, button in ipairs(buttons) do
                if cfg.skin then SkinButton(button, cfg) else UnskinButton(button) end
            end
            if bar.art then HoldBarArt(bar, cfg.hideArt, buttons) end
        elseif bar.kind == "micro" then
            local buttons = MicroButtons()
            for _, button in ipairs(buttons) do
                if cfg.skin then SkinMicro(button, cfg) else UnskinMicro(button) end
            end
            if bar.art then HoldBarArt(bar, cfg.hideArt or cfg.skin, buttons) end
        elseif bar.kind == "status" then
            for _, container in ipairs(Frames(bar)) do
                HoldContainerArt(container, cfg.skin)
                for _, statusBar in ipairs(FindStatusBars(container)) do
                    if cfg.skin then SkinStatus(statusBar, cfg) else UnskinStatus(statusBar) end
                end
            end
        elseif bar.kind == "swing" then
            if AB.Swing then AB.Swing.Apply(key) end
        end
        AB.UpdateVisibility(true)
    end)
end

---------------------------------------------------------------------------
-- Activar o quitar una barra. Las barras 2 a 8 usan las mismas casillas que
-- Opciones > Barras de acción de Blizzard (la barra desaparece de verdad).
-- Las que WoW no deja quitar (1, mascota, posturas, bolsas, menú,
-- experiencia) se vuelven invisibles.
---------------------------------------------------------------------------
local function BlizzardToggles()
    if not GetActionBarToggles then return nil end
    local ok, a, b, c, d, e, f, g = pcall(GetActionBarToggles)
    if not ok then return nil end
    return { a, b, c, d, e, f, g }
end

function AB.CanRemove(key)
    return BAR_BY_KEY[key].toggle ~= nil and BlizzardToggles() ~= nil
end

function AB.IsBarEnabled(key)
    local bar = BAR_BY_KEY[key]
    if bar.toggle then
        local toggles = BlizzardToggles()
        if toggles then return toggles[bar.toggle] and true or false end
    end
    return AB.db.bars[key].shown ~= false
end

function AB.SetBarEnabled(key, on)
    local bar = BAR_BY_KEY[key]
    local toggles = bar.toggle and BlizzardToggles()
    if not toggles then
        AB.db.bars[key].shown = on and true or false
        AB.UpdateVisibility(true)
        return true
    end
    if InCombatLockdown() then
        ns.Print("no se pueden activar ni quitar barras en combate.")
        return false
    end
    -- Primero la opción de Blizzard (la que guarda su panel); si no existe,
    -- las casillas de siempre.
    local setting = Settings and Settings.GetSetting and Settings.GetSetting("PROXY_SHOW_ACTIONBAR_" .. (bar.toggle + 1))
    if setting and setting.SetValue then
        pcall(setting.SetValue, setting, on and true or false)
    elseif SetActionBarToggles then
        toggles[bar.toggle] = on and true or false
        pcall(SetActionBarToggles, unpack(toggles, 1, 7))
        if MultiActionBar_Update then pcall(MultiActionBar_Update) end
    end
    C_Timer.After(0.1, AB.ApplyAll)
    return true
end

function AB.ApplyArt()
    for _, region in pairs(MainArt()) do Hold(region, AB.db.style.hideArt) end
end

---------------------------------------------------------------------------
-- Página fija en la barra 1: las teclas de «página siguiente / anterior»
-- (de serie Mayús + rueda) se tapan con un atajo prioritario (override) que
-- pulsa un botón propio que no hace nada. Tus atajos no se cambian: al quitar
-- la opción se borran los override y todo vuelve a ser como antes.
---------------------------------------------------------------------------
AB.PAGING_ACTIONS = { "NEXTACTIONPAGE", "PREVIOUSACTIONPAGE" }
local pagingBlocker

function AB.ApplyPaging()
    if not (AB.db and SetOverrideBindingClick and ClearOverrideBindings and GetBindingKey) then return end
    ns.AfterCombat("ActionBars:paging", function()
        pagingBlocker = pagingBlocker or CreateFrame("Button", "BlazzitoUIPagingBlocker", UIParent)
        -- Primero se quitan los nuestros, para leer tus atajos de verdad.
        ClearOverrideBindings(pagingBlocker)
        AB.pagingKeys = {}
        if not (AB.active and AB.db.style.lockPaging) then return end
        for _, action in ipairs(AB.PAGING_ACTIONS) do
            for _, key in ipairs({ GetBindingKey(action) }) do
                SetOverrideBindingClick(pagingBlocker, true, key, "BlazzitoUIPagingBlocker")
                AB.pagingKeys[#AB.pagingKeys + 1] = key
            end
        end
    end)
end

function AB.ApplyAll()
    if not AB.db then return end
    ns.AfterCombat("ActionBars:art", AB.ApplyArt)
    for _, bar in ipairs(BARS) do AB.ApplyBar(bar.key) end
end

---------------------------------------------------------------------------
-- Visibilidad: siempre, solo en combate, fuera de combate, al pasar el ratón
-- o en combate + ratón. Con alfa (la barra sigue funcionando).
---------------------------------------------------------------------------
AB.VISIBILITY = {
    { value = "always",      text = "Siempre" },
    { value = "nocombat",    text = "Ocultar en combate" },
    { value = "combat",      text = "Solo en combate" },
    { value = "mouseover",   text = "Al pasar el ratón" },
    { value = "combatmouse", text = "En combate o al pasar el ratón" },
}

local inCombat = false
local current = {}   -- clave de barra -> alfa actual (animado)

local function Hovered(bar)
    for _, frame in ipairs(Frames(bar)) do
        if frame:IsVisible() and frame:IsMouseOver() then return true end
    end
    return false
end

local function Forced()
    if AB.preview then return true end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then return true end
    if AB.db.style.showWhileDragging and GetCursorInfo then
        local kind = GetCursorInfo()
        if kind == "spell" or kind == "item" or kind == "macro" or kind == "petaction" or kind == "mount" then return true end
    end
    return false
end

local function Target(bar, cfg, forced)
    local mode = cfg.visibility
    if cfg.shown == false and not bar.toggle then return 0 end
    if forced or AB.HighlightKey() == bar.key then return 1 end
    if mode == "always" then return 1 end
    local hidden = (cfg.hiddenAlpha or 0) / 100
    local shown
    if mode == "nocombat" then shown = not inCombat
    elseif mode == "combat" then shown = inCombat
    elseif mode == "mouseover" then shown = Hovered(bar)
    elseif mode == "combatmouse" then shown = inCombat or Hovered(bar)
    else shown = true end
    return shown and 1 or hidden
end

-- instant: sin animación (al aplicar ajustes).
function AB.UpdateVisibility(instant, elapsed)
    if not AB.db then return end
    local forced = Forced()
    local step = instant and 1 or (elapsed or 0) / math.max(0.01, AB.db.style.fadeTime or 0.25)
    for _, bar in ipairs(BARS) do
        local cfg = AB.db.bars[bar.key]
        local target = Target(bar, cfg, forced)
        local alpha = current[bar.key]
        local untouched = cfg.visibility == "always" and (cfg.shown ~= false or bar.toggle)
        if untouched and alpha == nil then
            -- Nunca se ha tocado: se deja la barra tal cual.
        else
            alpha = alpha or 1
            if alpha < target then alpha = math.min(target, alpha + step)
            elseif alpha > target then alpha = math.max(target, alpha - step) end
            for _, frame in ipairs(Frames(bar)) do
                local now = frame:GetAlpha()
                if IsSecret(now) or math.abs(now - alpha) > 0.001 then frame:SetAlpha(alpha) end
            end
            -- De vuelta a "siempre" y ya visible: se suelta.
            if untouched and alpha >= 1 then alpha = nil end
            current[bar.key] = alpha
        end
    end
end

---------------------------------------------------------------------------
-- Resaltado: mientras la página de barras está abierta, la barra de la
-- pestaña elegida brilla en pantalla (marco propio encima, sin tocarla).
---------------------------------------------------------------------------
local glow = CreateFrame("Frame", nil, UIParent)
glow:SetFrameStrata("HIGH")
glow:EnableMouse(false)
glow:Hide()
do
    local a = M.COLORS.accent
    glow.fill = glow:CreateTexture(nil, "BACKGROUND")
    glow.fill:SetAllPoints()
    glow.fill:SetColorTexture(a[1], a[2], a[3], 0.12)
    glow.edges = {}
    for i = 1, 4 do
        local edge = glow:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(a[1], a[2], a[3], 1)
        if i <= 2 then edge:SetHeight(2) else edge:SetWidth(2) end
        glow.edges[i] = edge
    end
    -- Marco de 2 px por fuera de la barra: arriba, abajo, izquierda, derecha.
    glow.edges[1]:ClearAllPoints(); glow.edges[1]:SetPoint("BOTTOMLEFT", glow, "TOPLEFT", -2, 0); glow.edges[1]:SetPoint("BOTTOMRIGHT", glow, "TOPRIGHT", 2, 0)
    glow.edges[2]:ClearAllPoints(); glow.edges[2]:SetPoint("TOPLEFT", glow, "BOTTOMLEFT", -2, 0); glow.edges[2]:SetPoint("TOPRIGHT", glow, "BOTTOMRIGHT", 2, 0)
    glow.edges[3]:ClearAllPoints(); glow.edges[3]:SetPoint("TOPRIGHT", glow, "TOPLEFT", 0, 2); glow.edges[3]:SetPoint("BOTTOMRIGHT", glow, "BOTTOMLEFT", 0, -2)
    glow.edges[4]:ClearAllPoints(); glow.edges[4]:SetPoint("TOPLEFT", glow, "TOPRIGHT", 0, 2); glow.edges[4]:SetPoint("BOTTOMLEFT", glow, "BOTTOMRIGHT", 0, -2)
    glow.label = M.Font(glow, 12, "CENTER")
    glow.label:SetPoint("BOTTOM", glow, "TOP", 0, 6)
    glow.label:SetTextColor(a[1], a[2], a[3])
end
AB.glow = glow

-- La barra que se resalta ahora mismo (nil si la página no está a la vista).
function AB.HighlightKey()
    local C = ns.Config
    if not (C and C.window and C.window:IsShown() and C.current == "actionbars") then return nil end
    return AB.editing
end

local glowTime = 0
local function UpdateGlow(elapsed)
    local key = AB.HighlightKey()
    local target
    if key and AB.IsBarEnabled(key) then
        for _, frame in ipairs(Frames(BAR_BY_KEY[key])) do
            if frame:IsVisible() then target = frame; break end
        end
    end
    if not target then
        glow:Hide()
        glow.target = nil
        return
    end
    if glow.target ~= target then
        glow:ClearAllPoints()
        glow:SetAllPoints(target)
        glow.target = target
        glow.label:SetText(ns.Translate(BAR_BY_KEY[key].label))
    end
    glow.label:SetText(ns.Translate(BAR_BY_KEY[key].label))
    glowTime = glowTime + (elapsed or 0)
    glow:SetAlpha(0.55 + 0.45 * math.abs(math.sin(glowTime * 2.5)))
    glow:Show()
end
AB.UpdateGlow = UpdateGlow

-- Un solo marco propio hace de reloj: visibilidad y estado de los botones.
local driver = CreateFrame("Frame")
local stateClock, visClock = 0, 0
driver:SetScript("OnUpdate", function(_, elapsed)
    if not (AB.db and AB.active) then return end
    visClock = visClock + elapsed
    if visClock >= 0.03 then
        AB.UpdateVisibility(false, visClock)
        UpdateGlow(visClock)
        visClock = 0
    end
    stateClock = stateClock + elapsed
    if stateClock >= 0.05 then
        stateClock = 0
        for button, d in pairs(skins) do
            if d.state and d.active and button:IsVisible() then UpdateButtonState(button, d) end
        end
    end
end)

function AB.SetPreview(on)
    AB.preview = on or nil
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function AB:OnEnable()
    -- Blizzard rehace el arte de los botones al cambiar de página, de
    -- vehículo o de diseño del modo edición: se vuelve a aplicar después.
    local pending = false
    local function Reapply()
        if pending then return end
        pending = true
        C_Timer.After(0.1, function()
            pending = false
            AB.ApplyAll()
        end)
    end
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "UPDATE_BONUS_ACTIONBAR", "UPDATE_VEHICLE_ACTIONBAR",
                             "UPDATE_OVERRIDE_ACTIONBAR", "PET_BAR_UPDATE", "UPDATE_SHAPESHIFT_FORMS",
                             "EDIT_MODE_LAYOUTS_UPDATED", "UPDATE_EXHAUSTION", "UPDATE_FACTION",
                             "PLAYER_LEVEL_UP", "BAG_UPDATE_DELAYED" }) do
        ns.On(event, function() if AB.active then Reapply() end end)
    end
    ns.On("PLAYER_REGEN_DISABLED", function() inCombat = true end)
    ns.On("PLAYER_REGEN_ENABLED", function() inCombat = false end)
    inCombat = InCombatLockdown() and true or false
    AB.ApplyAll()
    AB.ApplyPaging()
    ns.On("PLAYER_ENTERING_WORLD", function() if AB.active then AB.ApplyPaging() end end)
end
