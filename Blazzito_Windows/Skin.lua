-- Blazzito_Windows: las ventanas de Blizzard (personaje, y poco a poco las
-- demás) con el estilo de BlazzitoUI. Las ventanas siguen siendo las de
-- Blizzard: abrir, cerrar, pestañas, equipar y todo lo demás es suyo; aquí
-- solo se cambia el aspecto.
--
-- Este archivo es el motor común a todas las ventanas: fondo y borde
-- propios, barra superior, botón de cerrar, pestañas y retrato. Cada
-- ventana es un "paquete" aparte (Character.lua...) que se registra con
-- Win.Register y pone el resto.
--
-- Reglas anti-taint: nunca se escribe un campo en un marco de Blizzard (lo
-- nuestro va en tablas débiles), el arte de Blizzard se oculta con alfa 0
-- (y se mantiene así con un gancho a SetAlpha) y solo se crean texturas y
-- marcos propios encima.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret = M.IsSecret

local Win = ns.NewModule("Windows", "Ventanas", {
    background = 92, topBar = true, accent = "class", hidePortrait = true,
    modernClose = true, tabs = true, scrollBars = true, menus = true,
    character = {
        enabled = true, slotShape = "square", slotFlipH = false, slotFlipV = false, slotBorder = 2,
        qualityBorder = true, itemLevel = true, itemLevelSize = 12, itemLevelPos = "BOTTOM", itemLevelQuality = true,
        durability = true, durabilityWarn = 50, averageLevel = true, modelBackground = true,
        stats = true, otherTabs = true, modernToggle = true, iconTabs = true,
        slotText = true, watermark = true, bars = true,
    },
    pet = { enabled = true, hideTab = true, rotate = true, moveHappiness = true },
    talents = { enabled = true, art = 40, ranks = true, summary = true, glow = true },
    spellbook = { enabled = true, expand = true, markUnbound = true, markOldRank = true },
    worldmap = { enabled = true, headers = true, cards = true },
    trainer = { enabled = true }, loot = { enabled = true }, merchant = { enabled = true },
    mail = { enabled = true }, professions = { enabled = true }, auction = { enabled = true },
})
ns.Windows = Win
-- Con el estilo de mando se aparta (BlazzitoUI/Core/Pad.lua): la cruceta recorre las
-- ventanas de Blizzard y pulsaría los botones que les añadimos.
Win.padStandDown = true

local skins = setmetatable({}, { __mode = "k" })    -- marco de Blizzard -> nuestras piezas
local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local ours = setmetatable({}, { __mode = "k" })     -- texturas creadas por nosotros
Win.skins = skins

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------
-- Oculta (o devuelve) una pieza de Blizzard. Si Blizzard le vuelve a poner
-- alfa, se le quita otra vez. "level" (opcional) la deja tenue en vez de
-- oculta (0-1).
function Win.Hold(region, hide, level)
    if type(region) ~= "table" or not region.SetAlpha or ours[region] then return end
    if hide then
        level = level or 0
        held[region] = level
        if not hooked[region] then
            hooked[region] = true
            hooksecurefunc(region, "SetAlpha", function(self, alpha)
                local want = held[self]
                if want and (IsSecret(alpha) or math.abs(alpha - want) > 0.001) then self:SetAlpha(want) end
            end)
        end
        region:SetAlpha(level)
    elseif held[region] then
        held[region] = nil
        region:SetAlpha(1)
    end
end
local Hold = Win.Hold

-- Una pieza de un marco por su clave o por su nombre global (Nombre..sufijo).
function Win.Child(owner, key, suffix)
    if type(owner) ~= "table" then return nil end
    local region = key and owner[key]
    if type(region) ~= "table" then region = nil end
    if not region and suffix and owner.GetName then
        local name = owner:GetName()
        if type(name) == "string" then region = _G[name .. suffix] end
    end
    return type(region) == "table" and region or nil
end
local Child = Win.Child

local function IsTexture(region)
    return type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture"
end
Win.IsTexture = IsTexture

-- Texturas propias de un marco (no las de sus hijos). Sin huecos: con pairs,
-- para que una pieza que falte no corte la lista.
function Win.Textures(frame)
    local list = {}
    if type(frame) ~= "table" or not frame.GetRegions then return list end
    for _, region in pairs({ frame:GetRegions() }) do
        if IsTexture(region) and not ours[region] then list[#list + 1] = region end
    end
    return list
end
local Textures = Win.Textures

function Win.Children(frame)
    local list = {}
    if type(frame) ~= "table" or not frame.GetChildren then return list end
    for _, child in pairs({ frame:GetChildren() }) do
        if type(child) == "table" and not (child.IsForbidden and child:IsForbidden()) then list[#list + 1] = child end
    end
    return list
end

-- Oculta las texturas propias de un marco salvo las de "keep".
function Win.Strip(frame, hide, keep)
    for _, region in ipairs(Textures(frame)) do
        if not (keep and keep[region]) then Hold(region, hide) end
    end
end

-- Una textura nuestra (el motor nunca la oculta).
function Win.Texture(frame, layer, sub)
    local t = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
    ours[t] = true
    return t
end

function Win.Parts(frame)
    local d = skins[frame]
    if not d then
        d = {}
        skins[frame] = d
    end
    return d
end

-- Color de acento: el de tu clase, el azul de BlazzitoUI o ninguno.
function Win.Accent()
    local mode = Win.db and Win.db.accent or "class"
    if mode == "none" then return nil end
    if mode == "class" and UnitClass then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    local a = M.COLORS.accent
    return a[1], a[2], a[3]
end

function Win.QualityColor(quality)
    if type(quality) ~= "number" or IsSecret(quality) then return nil end
    if C_Item and C_Item.GetItemQualityColor then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
        if ok and type(r) == "number" then return r, g, b end
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color then return color.r, color.g, color.b end
    return nil
end

---------------------------------------------------------------------------
-- Botón moderno: el arte de Blizzard oculto y un cuadro con icono encima
---------------------------------------------------------------------------
function Win.ModernButton(button, icon, size, on)
    if type(button) ~= "table" or not button.CreateTexture then return nil end
    local d = Win.Parts(button)
    if not d.bg then
        d.bg = Win.Texture(button, "BACKGROUND", -8)
        d.bg:SetPoint("CENTER")
        d.icon = Win.Texture(button, "OVERLAY", 7)
        d.icon:SetPoint("CENTER")
        d.hover = Win.Texture(button, "HIGHLIGHT", 7)
        d.hover:SetAllPoints(d.bg)
        d.hover:SetColorTexture(1, 1, 1, 0.08)
    end
    local art = {}
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(), button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(), button.GetDisabledTexture and button:GetDisabledTexture(),
    }) do art[#art + 1] = region end
    for _, region in ipairs(Textures(button)) do art[#art + 1] = region end
    for _, region in ipairs(art) do Hold(region, on) end
    size = size or 20
    d.bg:SetSize(size, size)
    d.bg:SetColorTexture(0.12, 0.12, 0.14, 0.95)
    d.icon:SetSize(size - 8, size - 8)
    d.icon:SetTexture(icon)
    d.icon:SetVertexColor(0.85, 0.85, 0.9)
    d.bg:SetShown(on)
    d.icon:SetShown(on)
    d.hover:SetShown(on)
    return d
end

---------------------------------------------------------------------------
-- Marcos nuestros y recorrido de los de Blizzard
---------------------------------------------------------------------------
local own = setmetatable({}, { __mode = "k" })
function Win.Own(frame)
    if type(frame) == "table" then own[frame] = true end
    return frame
end
function Win.IsOwn(frame) return own[frame] == true end

-- Visita los hijos de "root" (nunca los nuestros) hasta "depth" niveles. Si
-- visit devuelve false, no entra en ese marco.
-- Marcos que el recorrido no visita nunca (p. ej. el lienzo del mapa, con
-- cientos de puntos).
Win.noWalk = setmetatable({}, { __mode = "k" })
function Win.Walk(root, visit, depth)
    depth = depth or 8
    local function Step(frame, level)
        for _, child in ipairs(Win.Children(frame)) do
            if not own[child] and not Win.noWalk[child] and visit(child) ~= false and level < depth then Step(child, level + 1) end
        end
    end
    Step(root, 1)
end

---------------------------------------------------------------------------
-- Barras de desplazamiento: una línea fina con el tirador del color de acento
---------------------------------------------------------------------------
-- La moderna (Track/Thumb/Back/Forward) y la clásica (Slider con flechas).
function Win.IsScrollBar(f)
    if type(f) ~= "table" then return false end
    local track = Child(f, "Track")
    if track and (Child(f, "Back") or Child(f, "Forward") or Child(track, "Thumb")) then return true end
    if f.GetObjectType and f:GetObjectType() == "Slider" and f.GetThumbTexture
        and Child(f, "ScrollUpButton", "ScrollUpButton") then return true end
    return false
end

local function Arrow(button, angle, on)
    local d = Win.ModernButton(button, M.ICONS.chevron, 14, on)
    if not d then return end
    d.bg:SetColorTexture(0, 0, 0, 0)
    d.icon:SetSize(9, 9)
    if d.icon.SetRotation then d.icon:SetRotation(angle) end
end

function Win.ScrollBar(bar, on)
    local d = Win.Parts(bar)
    if not on and not d.sbTrack then return end
    local track = Child(bar, "Track")
    local thumb = track and Child(track, "Thumb")
    local thumbTex = not thumb and bar.GetThumbTexture and bar:GetThumbTexture() or nil
    local host = track or bar
    if not d.sbTrack then
        d.sbTrack = Win.Texture(host, "BACKGROUND", -8)
        d.sbThumb = Win.Texture(thumb or bar, "OVERLAY", 7)
    end
    Win.Strip(bar, on)
    Win.Strip(track, on)
    Win.Strip(thumb, on)
    local bg = Child(bar, "Background")
    if IsTexture(bg) then Hold(bg, on) elseif bg then Win.Strip(bg, on) end
    if thumbTex then Hold(thumbTex, on) end
    local width = 4
    d.sbTrack:ClearAllPoints()
    d.sbTrack:SetPoint("TOP", host, "TOP", 0, 0)
    d.sbTrack:SetPoint("BOTTOM", host, "BOTTOM", 0, 0)
    d.sbTrack:SetWidth(width)
    d.sbTrack:SetColorTexture(1, 1, 1, 0.07)
    local grip = thumb or thumbTex
    d.sbThumb:ClearAllPoints()
    if grip then
        local inset = thumb and 1 or 4
        d.sbThumb:SetPoint("TOP", grip, "TOP", 0, -inset)
        d.sbThumb:SetPoint("BOTTOM", grip, "BOTTOM", 0, inset)
    end
    d.sbThumb:SetWidth(width)
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.6, 0.6, 0.65 end
    d.sbThumb:SetColorTexture(r, g, b, 0.85)
    d.sbTrack:SetShown(on)
    d.sbThumb:SetShown(on and grip ~= nil)
    Arrow(Child(bar, "Back") or Child(bar, "ScrollUpButton", "ScrollUpButton"), math.pi / 2, on)
    Arrow(Child(bar, "Forward") or Child(bar, "ScrollDownButton", "ScrollDownButton"), -math.pi / 2, on)
end

function Win.SkinScrollBars(root, on)
    if type(root) ~= "table" then return end
    Win.Walk(root, function(f)
        if Win.IsScrollBar(f) then
            Win.ScrollBar(f, on)
            return false
        end
    end)
end

---------------------------------------------------------------------------
-- Botones de texto y cajas de texto planos
---------------------------------------------------------------------------
-- Botón de Blizzard con arte de tres piezas (Left/Middle/Right): cuadro
-- oscuro con borde fino y brillo al pasar el ratón.
function Win.IsPanelButton(b)
    return type(b) == "table" and b.GetObjectType and b:GetObjectType() == "Button"
        and IsTexture(Child(b, "Left")) and IsTexture(Child(b, "Middle")) and IsTexture(Child(b, "Right"))
end

function Win.FlatButton(button, on)
    if type(button) ~= "table" or not button.CreateTexture then return end
    local d = Win.Parts(button)
    if not on and not d.fbBg then return end
    if not d.fbBg then
        d.fbEdge = Win.Texture(button, "BACKGROUND", -8)
        d.fbBg = Win.Texture(button, "BACKGROUND", -7)
        d.fbHover = Win.Texture(button, "HIGHLIGHT", 7)
    end
    local art = {}
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(), button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(), button.GetDisabledTexture and button:GetDisabledTexture(),
    }) do art[#art + 1] = region end
    for _, region in ipairs(Textures(button)) do art[#art + 1] = region end
    for _, region in ipairs(art) do Hold(region, on) end
    local px = M.PixelSize()
    d.fbEdge:ClearAllPoints()
    d.fbEdge:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    d.fbEdge:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    d.fbEdge:SetColorTexture(0, 0, 0, 1)
    d.fbBg:ClearAllPoints()
    d.fbBg:SetPoint("TOPLEFT", d.fbEdge, "TOPLEFT", px, -px)
    d.fbBg:SetPoint("BOTTOMRIGHT", d.fbEdge, "BOTTOMRIGHT", -px, px)
    local r, g, b = Win.Accent()
    if r then d.fbBg:SetColorTexture(r * 0.22, g * 0.22, b * 0.22, 0.95) else d.fbBg:SetColorTexture(0.12, 0.12, 0.14, 0.95) end
    d.fbHover:ClearAllPoints()
    d.fbHover:SetAllPoints(d.fbBg)
    d.fbHover:SetColorTexture(1, 1, 1, 0.08)
    d.fbEdge:SetShown(on)
    d.fbBg:SetShown(on)
    d.fbHover:SetShown(on)
end

-- Caja de texto (buscador...): fondo oscuro con borde; la lupa se queda.
function Win.FlatEditBox(box, on)
    if type(box) ~= "table" or not box.CreateTexture then return end
    local d = Win.Parts(box)
    if not on and not d.ebBg then return end
    if not d.ebBg then
        d.ebEdge = Win.Texture(box, "BACKGROUND", -8)
        d.ebBg = Win.Texture(box, "BACKGROUND", -7)
    end
    local keep = {}
    for _, key in ipairs({ "searchIcon", "SearchIcon", "Icon" }) do
        local icon = Child(box, key)
        if icon then keep[icon] = true end
    end
    Win.Strip(box, on, keep)
    local px = M.PixelSize()
    d.ebEdge:ClearAllPoints()
    d.ebEdge:SetPoint("TOPLEFT", box, "TOPLEFT", -6, 0)
    d.ebEdge:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    d.ebEdge:SetColorTexture(0, 0, 0, 1)
    d.ebBg:ClearAllPoints()
    d.ebBg:SetPoint("TOPLEFT", d.ebEdge, "TOPLEFT", px, -px)
    d.ebBg:SetPoint("BOTTOMRIGHT", d.ebEdge, "BOTTOMRIGHT", -px, px)
    d.ebBg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
    d.ebEdge:SetShown(on)
    d.ebBg:SetShown(on)
end

---------------------------------------------------------------------------
-- Barras de progreso de Blizzard (reputación, habilidades...): planas
---------------------------------------------------------------------------
local barHooked = setmetatable({}, { __mode = "k" })

function Win.SkinBar(bar, on)
    if type(bar) ~= "table" or not bar.GetStatusBarTexture then return end
    local d = Win.Parts(bar)
    if not on and not d.barEdge then return end
    if not d.barEdge then
        d.barEdge = Win.Texture(bar, "BACKGROUND", -8)
        d.barBg = Win.Texture(bar, "BACKGROUND", -7)
    end
    local fill = bar:GetStatusBarTexture()
    local keep = {}
    if fill then keep[fill] = true end
    Win.Strip(bar, on, keep)
    for _, child in ipairs(Win.Children(bar)) do
        if not own[child] then Win.Strip(child, on) end
    end
    local px = M.PixelSize()
    d.barEdge:ClearAllPoints()
    d.barEdge:SetPoint("TOPLEFT", bar, "TOPLEFT", -px, px)
    d.barEdge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", px, -px)
    d.barEdge:SetColorTexture(0, 0, 0, 1)
    d.barBg:ClearAllPoints()
    d.barBg:SetAllPoints(bar)
    d.barBg:SetColorTexture(0.05, 0.05, 0.06, 0.95)
    d.barEdge:SetShown(on)
    d.barBg:SetShown(on)
    d.barOn = on
    -- Relleno plano, solo si el color lo pone Blizzard aparte (si viene
    -- pintado en la propia textura, al aplanarlo se perdería).
    if on and not d.flat and fill then
        local r, g, b = bar:GetStatusBarColor()
        r, g, b = M.Readable(r), M.Readable(g), M.Readable(b)
        if type(r) == "number" and type(g) == "number" and type(b) == "number" and not (r > 0.95 and g > 0.95 and b > 0.95) then
            d.orig = (fill.GetAtlas and fill:GetAtlas()) or fill:GetTexture()
            d.flat = true
            if not barHooked[bar] then
                barHooked[bar] = true
                hooksecurefunc(bar, "SetStatusBarTexture", function(self, tex)
                    local s = skins[self]
                    if s and s.flat and s.barOn and tex ~= M.TEXTURE then self:SetStatusBarTexture(M.TEXTURE) end
                end)
            end
            bar:SetStatusBarTexture(M.TEXTURE)
        end
    elseif not on and d.flat then
        d.flat = false
        if d.orig then bar:SetStatusBarTexture(d.orig) end
    end
end

---------------------------------------------------------------------------
-- La ventana: fondo, borde, barra superior y retrato
---------------------------------------------------------------------------
local TOP_BAR = 24

local function PortraitArt(frame)
    local list = {}
    for _, key in ipairs({ "PortraitContainer", "PortraitButton", "PortraitFrame" }) do
        local container = Child(frame, key)
        if container then
            if IsTexture(container) then list[#list + 1] = container end
            for _, region in ipairs(Textures(container)) do list[#list + 1] = region end
        end
    end
    local portrait = Child(frame, "portrait", "Portrait") or Child(frame, "Portrait")
    if IsTexture(portrait) then list[#list + 1] = portrait end
    return list
end
Win.PortraitArt = PortraitArt

-- El arte del marco: el moderno (NineSlice, Bg, Inset...) y el clásico
-- (texturas sueltas de la propia ventana).
local SHELL_PARTS = { "NineSlice", "Bg", "Background", "TitleContainer", "TopTileStreaks", "Inset", "TitleBg" }

local function ShellArt(frame)
    local list, skip = {}, {}
    for _, region in ipairs(PortraitArt(frame)) do skip[region] = true end
    local function Add(part)
        if not part then return end
        if IsTexture(part) then
            list[#list + 1] = part
        else
            for _, region in ipairs(Textures(part)) do list[#list + 1] = region end
            local inner = Child(part, "NineSlice")
            if inner then for _, region in ipairs(Textures(inner)) do list[#list + 1] = region end end
            local bg = Child(part, "Bg")
            if IsTexture(bg) then list[#list + 1] = bg end
        end
    end
    for _, key in ipairs(SHELL_PARTS) do Add(Child(frame, key)) end
    Add(Child(frame, nil, "Inset"))
    for _, region in ipairs(Textures(frame)) do
        if not skip[region] then list[#list + 1] = region end
    end
    return list
end

-- compact: sin barra superior (ventanas muy bajas, como las tiradas de botín).
function Win.Shell(frame, on, compact)
    if type(frame) ~= "table" or not frame.CreateTexture then return nil end
    local db = Win.db
    local d = Win.Parts(frame)
    if not d.border then
        d.border = Win.Texture(frame, "BACKGROUND", -8)
        d.fill = Win.Texture(frame, "BACKGROUND", -7)
        d.bar = Win.Texture(frame, "BACKGROUND", -6)
        d.line = Win.Texture(frame, "BACKGROUND", -5)
    end
    for _, region in ipairs(ShellArt(frame)) do Hold(region, on) end
    for _, region in ipairs(PortraitArt(frame)) do Hold(region, on and db.hidePortrait) end

    local px = M.PixelSize()
    d.border:ClearAllPoints()
    d.border:SetAllPoints(frame)
    d.border:SetColorTexture(0, 0, 0, 1)
    d.fill:ClearAllPoints()
    d.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", px, -px)
    d.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -px, px)
    d.fill:SetColorTexture(0.06, 0.06, 0.07, (db.background or 92) / 100)
    d.bar:ClearAllPoints()
    d.bar:SetPoint("TOPLEFT", d.fill, "TOPLEFT")
    d.bar:SetPoint("TOPRIGHT", d.fill, "TOPRIGHT")
    d.bar:SetHeight(TOP_BAR)
    d.bar:SetColorTexture(0.02, 0.02, 0.025, 0.9)
    d.line:ClearAllPoints()
    d.line:SetPoint("TOPLEFT", d.bar, "BOTTOMLEFT")
    d.line:SetPoint("TOPRIGHT", d.bar, "BOTTOMRIGHT")
    d.line:SetHeight(px)
    local r, g, b = Win.Accent()
    if r then d.line:SetColorTexture(r, g, b, 0.9) else d.line:SetColorTexture(0, 0, 0, 1) end

    d.border:SetShown(on)
    d.fill:SetShown(on)
    d.bar:SetShown(on and db.topBar and not compact)
    d.line:SetShown(on and db.topBar and not compact)

    local close = Child(frame, "CloseButton", "CloseButton")
    if close then Win.ModernButton(close, M.ICONS.close, 20, on and db.modernClose) end
    Win.SkinTabs(frame, on and db.tabs)
    return d
end

---------------------------------------------------------------------------
-- Pestañas (las de abajo de la ventana)
---------------------------------------------------------------------------
local tabOwners = setmetatable({}, { __mode = "k" })   -- pestaña -> ventana
local tabSelected = setmetatable({}, { __mode = "k" }) -- pestaña -> función "¿elegida?"

function Win.Tabs(frame)
    local list, seen = {}, {}
    local function Add(tab)
        if type(tab) == "table" and tab.CreateTexture and not seen[tab] then
            seen[tab] = true
            list[#list + 1] = tab
        end
    end
    local tabs = Child(frame, "Tabs")
    if tabs then for _, tab in pairs(tabs) do Add(tab) end end
    local name = frame.GetName and frame:GetName()
    if type(name) == "string" then
        for i = 1, 12 do
            local tab = _G[name .. "Tab" .. i]
            if not tab then break end
            Add(tab)
        end
    end
    table.sort(list, function(a, b)
        local ia, ib = a.GetID and a:GetID() or 0, b.GetID and b:GetID() or 0
        if IsSecret(ia) or IsSecret(ib) then return false end
        return ia < ib
    end)
    return list
end

local function SelectedTab(frame)
    if PanelTemplates_GetSelectedTab then
        local ok, id = pcall(PanelTemplates_GetSelectedTab, frame)
        if ok and type(id) == "number" and not IsSecret(id) then return id end
    end
    return nil
end

local function TabText(tab)
    local text = Child(tab, "Text", "Text")
    if text and text.SetTextColor then return text end
    return nil
end

function Win.PaintTab(tab)
    local d = skins[tab]
    if not (d and d.bg) then return end
    local frame = tabOwners[tab]
    local selected
    if tabSelected[tab] then selected = tabSelected[tab](tab) and true or false
    else selected = frame and SelectedTab(frame) == (tab.GetID and tab:GetID()) end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.8, 0.8, 0.8 end
    d.bg:SetColorTexture(selected and 0.10 or 0.05, selected and 0.10 or 0.05, selected and 0.12 or 0.06, 0.95)
    d.mark:SetColorTexture(r, g, b, 1)
    d.mark:SetShown(d.on and selected or false)
    local text = TabText(tab)
    if text and d.on then
        if selected then text:SetTextColor(1, 1, 1) else text:SetTextColor(0.65, 0.65, 0.7) end
    end
end

-- isSelected (opcional): función que dice si la pestaña es la elegida, para
-- pestañas que no son de PanelTemplates (los TabSystem modernos).
function Win.SkinTab(tab, frame, on, isSelected)
    local d = Win.Parts(tab)
    tabOwners[tab] = frame
    if isSelected then tabSelected[tab] = isSelected end
    if not d.bg then
        d.border = Win.Texture(tab, "BACKGROUND", -8)
        d.bg = Win.Texture(tab, "BACKGROUND", -7)
        d.mark = Win.Texture(tab, "ARTWORK", 7)
        d.hover = Win.Texture(tab, "HIGHLIGHT", 7)
        d.hover:SetColorTexture(1, 1, 1, 0.06)
    end
    d.on = on
    local art = {}
    for _, region in pairs({
        tab.GetNormalTexture and tab:GetNormalTexture(), tab.GetHighlightTexture and tab:GetHighlightTexture(),
        tab.GetDisabledTexture and tab:GetDisabledTexture(), tab.GetPushedTexture and tab:GetPushedTexture(),
    }) do art[#art + 1] = region end
    for _, region in ipairs(Textures(tab)) do art[#art + 1] = region end
    for _, region in ipairs(art) do Hold(region, on) end
    -- Las pestañas clásicas tienen arte más grande que el botón: el cuadro
    -- queda un poco hacia dentro, pegado a la ventana por arriba.
    local px = M.PixelSize()
    d.border:ClearAllPoints()
    d.border:SetPoint("TOPLEFT", tab, "TOPLEFT", 4, -2)
    d.border:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 4)
    d.border:SetColorTexture(0, 0, 0, 1)
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", d.border, "TOPLEFT", px, -px)
    d.bg:SetPoint("BOTTOMRIGHT", d.border, "BOTTOMRIGHT", -px, px)
    d.mark:ClearAllPoints()
    d.mark:SetPoint("BOTTOMLEFT", d.bg, "BOTTOMLEFT")
    d.mark:SetPoint("BOTTOMRIGHT", d.bg, "BOTTOMRIGHT")
    d.mark:SetHeight(2 * px)
    d.hover:ClearAllPoints()
    d.hover:SetAllPoints(d.bg)
    d.border:SetShown(on)
    d.bg:SetShown(on)
    d.hover:SetShown(on)
    local text = TabText(tab)
    if text and not on then text:SetTextColor(1, 0.82, 0) end
    Win.PaintTab(tab)
end

function Win.SkinTabs(frame, on)
    for _, tab in ipairs(Win.Tabs(frame)) do Win.SkinTab(tab, frame, on) end
end

local tabsHooked = false
local function HookTabs()
    if tabsHooked then return end
    tabsHooked = true
    local function Repaint()
        for tab in pairs(tabOwners) do Win.PaintTab(tab) end
    end
    for _, fn in ipairs({ "PanelTemplates_SetTab", "PanelTemplates_UpdateTabs", "PanelTemplates_SelectTab", "PanelTemplates_DeselectTab" }) do
        if type(_G[fn]) == "function" then hooksecurefunc(fn, Repaint) end
    end
end

---------------------------------------------------------------------------
-- Paquetes de ventanas
---------------------------------------------------------------------------
-- pack = { key, title, frame = function() return marco end, apply = function(frame, on) }
Win.packs = {}
local showHooked = setmetatable({}, { __mode = "k" })

function Win.Register(pack)
    Win.packs[#Win.packs + 1] = pack
    if Win.active then Win.ApplyPack(pack) end
end

function Win.PackOn(pack)
    local opts = pack.key and Win.db[pack.key]
    return not (type(opts) == "table" and opts.enabled == false)
end

-- Solo el aspecto (sin el gancho de OnShow): lo usan ApplyPack y el modo mando.
local function Paint(pack, frame)
    local on = Win.PackOn(pack)
    local d = skins[frame]
    -- Si está apagada y nunca se tocó, no hay nada que devolver.
    if not on and not (d and d.border) then return true end
    Win.Shell(frame, on, pack.compact)
    if pack.apply then pack.apply(frame, on) end
    Win.SkinScrollBars(frame, on and Win.db.scrollBars)
    return true
end

function Win.ApplyPack(pack)
    local frame = pack.frame()
    if not frame then return false end
    if not showHooked[frame] then
        showHooked[frame] = true
        -- Al abrirse se repasa (Blizzard cambia piezas al mostrar la ventana).
        frame:HookScript("OnShow", function() Win.ApplyPack(pack) end)
    end
    return Paint(pack, frame)
end

-- Cada ventana por separado: si una falla, se avisa del error y las demás
-- se aplican igual.
function Win.ApplyAll()
    if not (Win.active and Win.db) then return end
    for _, pack in ipairs(Win.packs) do
        xpcall(function() Win.ApplyPack(pack) end, geterrorhandler())
    end
end

---------------------------------------------------------------------------
-- Diagnóstico: /bui ventanas
---------------------------------------------------------------------------
local function KeyOf(parent, child)
    if type(parent) ~= "table" then return nil end
    local ok, key = pcall(function()
        for k, v in pairs(parent) do
            if v == child and type(k) == "string" then return k end
        end
    end)
    return ok and key or nil
end

local function Describe(region, parent)
    local name = region.GetName and region:GetName()
    local key = KeyOf(parent, region)
    local kind = region.GetObjectType and region:GetObjectType() or "?"
    local label = (type(name) == "string" and name) or (key and ("." .. key)) or "(sin nombre)"
    return label .. " [" .. kind .. "]"
end

function Win.Dump(frame, depth, prefix, lines)
    lines = lines or {}
    prefix = prefix or ""
    depth = depth or 2
    if type(frame) ~= "table" then return lines end
    local tex, atlases = 0, {}
    for _, region in ipairs(Textures(frame)) do
        tex = tex + 1
        local atlas = region.GetAtlas and region:GetAtlas()
        if type(atlas) == "string" and #atlases < 3 then atlases[#atlases + 1] = atlas end
    end
    lines[#lines + 1] = prefix .. Describe(frame, frame.GetParent and frame:GetParent()) ..
        (frame.IsShown and not frame:IsShown() and " oculto" or "") ..
        (tex > 0 and (" texturas:" .. tex) or "") .. (#atlases > 0 and (" " .. table.concat(atlases, ",")) or "")
    if depth > 0 then
        for _, child in ipairs(Win.Children(frame)) do Win.Dump(child, depth - 1, prefix .. "  ", lines) end
    end
    return lines
end

-- Nombres en español para /bui ventanas <ventana>.
local ALIASES = { personaje = "character", talentos = "talents", libro = "spellbook", mapa = "worldmap", entrenador = "trainer",
    botin = "loot", ["botín"] = "loot", comerciante = "merchant", correo = "mail", profesiones = "professions", subastas = "auction" }

function Win.Diagnose(which)
    if which == "" then which = nil end
    which = which and (ALIASES[which] or which)
    local list = {}
    for _, pack in ipairs(Win.packs) do
        if not which or which == pack.key then list[#list + 1] = pack end
    end
    for _, pack in ipairs(list) do
        local frame = pack.frame()
        ns.Print(pack.title .. ": " .. (frame and "encontrada" or "no existe en este cliente") ..
            (frame and (Win.PackOn(pack) and ", con estilo" or ", sin estilo") or ""))
        if frame then
            for _, line in ipairs(Win.Dump(frame, 2)) do print("  " .. line) end
            if pack.diagnose then pack.diagnose(frame) end
        end
    end
end

---------------------------------------------------------------------------
-- Con el estilo de mando (BlazzitoUI/Core/Pad.lua) el módulo se aparta: la
-- cruceta recorre las ventanas y pulsaría los botones que añadimos en
-- personaje, talentos, libro o mapa. Las ventanas sencillas del motor común
-- (pack.padSafe: botín y tiradas, comerciante, entrenadores, correo,
-- profesiones, subastas) solo reciben texturas, sin marcos ni botones
-- nuestros: esas siguen con estilo. Y sin ganchos en sus scripts: se mira
-- cada 0,15 s si están abiertas (tres repasos al abrirse, mientras Blizzard
-- llena el contenido, y luego uno por segundo).
---------------------------------------------------------------------------
local padPasses = setmetatable({}, { __mode = "k" })   -- ventana -> repasos hechos
local padClock = setmetatable({}, { __mode = "k" })

function Win.PadTick(elapsed)
    for _, pack in ipairs(Win.packs) do
        if pack.padSafe then
            local frame = pack.frame()
            local shown = frame and M.Readable(frame:IsShown()) == true
            if shown then
                local passes = padPasses[frame] or 0
                padClock[frame] = (padClock[frame] or 0) + (elapsed or 0)
                if passes < 3 or padClock[frame] >= 1 then
                    padPasses[frame] = passes + 1
                    padClock[frame] = 0
                    xpcall(function() Paint(pack, frame) end, geterrorhandler())
                end
            elseif frame then
                padPasses[frame], padClock[frame] = nil, nil
            end
        end
    end
end

function Win:OnPadRest()
    Win.padLite = true
    HookTabs()
    ns.RegisterCommand("ventanas", function(which) Win.Diagnose(which) end, "diagnóstico de las ventanas (opcional: personaje, talentos, mapa…)")
    local driver = CreateFrame("Frame")
    local clock = 0
    driver:SetScript("OnUpdate", function(_, elapsed)
        clock = clock + elapsed
        if clock < 0.15 then return end
        Win.PadTick(clock)
        clock = 0
    end)
end

function Win:OnEnable()
    HookTabs()
    Win.ApplyAll()
    -- Algunas ventanas aparecen tarde (cargan bajo demanda): se reintenta.
    ns.On("ADDON_LOADED", function() if Win.active then C_Timer.After(0, Win.ApplyAll) end end)
    ns.RegisterCommand("ventanas", function(which) Win.Diagnose(which) end, "diagnóstico de las ventanas (opcional: personaje, talentos, mapa…)")
end
