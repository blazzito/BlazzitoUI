-- Blazzito_Windows: la ventana de talentos (PlayerSpellsFrame de Forever, con
-- los tres árboles clásicos dentro).
--
-- - Marco, barra superior y cierre como el resto de ventanas.
-- - Pestañas Principal/Secundario (y las de abajo, si las hay) planas.
-- - Cada talento: icono cuadrado recortado con un anillo del color de su
--   estado (al máximo: tu color de clase con brillo; con puntos: tu color;
--   disponible: claro; bloqueado: oscuro) y su rango "2/5" en una pastilla.
-- - El arte de los árboles se queda, pero tenue (el contenido manda).
-- - Arriba a la izquierda, el reparto de puntos: "Puntería  0 / 2 / 0".
-- - "Aplicar cambios", buscador y demás botones, planos.
--
-- Nunca se escribe en los marcos de Blizzard ni se llama a sus métodos de
-- talentos: solo se leen sus datos (nodeInfo, visualState) y se pinta encima
-- con texturas propias. Mientras la ventana está abierta, un repaso ligero
-- (unas 6 veces por segundo) mantiene los colores al día.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win = ns.Windows
local M = ns.Media
local Child, Hold, IsTexture = Win.Child, Win.Hold, Win.IsTexture
local Readable = M.Readable

local T = {}
Win.Talents = T

local function Opts() return Win.db.talents end

---------------------------------------------------------------------------
-- Qué es cada cosa
---------------------------------------------------------------------------
local function Talents(frame)
    return frame and Child(frame, "TalentsFrame")
end

local function IconOf(button)
    local icon = Child(button, "Icon") or Child(button, "icon")
    return IsTexture(icon) and icon or nil
end

-- Un talento: botón con icono y datos de talento (o, dentro del contenedor
-- de botones, con forma de casilla).
function T.IsTalentButton(f, buttonsParent)
    if not (f.GetObjectType and f:GetObjectType() == "Button") then return false end
    if not IconOf(f) then return false end
    if rawget(f, "GetNodeInfo") or rawget(f, "UpdateVisualState") or rawget(f, "nodeInfo") or rawget(f, "nodeID")
        or rawget(f, "talentIndex") or rawget(f, "GetSpellID") then
        return true
    end
    if buttonsParent and f:GetParent() == buttonsParent then
        local w, h = f:GetSize()
        w, h = Readable(w), Readable(h)
        return type(w) == "number" and type(h) == "number" and w >= 24 and w <= 64 and math.abs(w - h) < 4
    end
    return false
end

local function IsTabSystem(f)
    return type(f) == "table" and type(rawget(f, "tabs")) == "table"
end

-- Los talentos de la ventana (se recuerdan; se vuelven a buscar cada segundo
-- por si Blizzard crea más al cambiar de pestaña).
local cache, cacheAt = {}, 0
function T.Buttons(frame, force)
    local now = GetTime and GetTime() or 0
    if not force and now - cacheAt < 1 and #cache > 0 then return cache end
    cacheAt = now
    local list = {}
    local tf = Talents(frame)
    if tf then
        local parent = Child(tf, "ButtonsParent")
        Win.Walk(tf, function(f)
            if T.IsTalentButton(f, parent) then
                list[#list + 1] = f
                return false
            end
            if IsTabSystem(f) then return false end
        end, 6)
    end
    cache = list
    return list
end

---------------------------------------------------------------------------
-- Estado de un talento
---------------------------------------------------------------------------
-- "max", "some" (con puntos), "open" (se le pueden poner), "locked", "error".
local function RankText(button)
    local fs = Child(button, "SpendText") or Child(button, "RankText") or Child(button, "Rank")
    if fs and fs.GetText then return fs end
    for _, region in pairs({ button:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then return region end
    end
    return nil
end

-- El color que Blizzard le pone al marco del talento (talents-node-square-
-- locked / gray / green / yellow / red). En Forever es lo más fiable: el
-- número de visualState no siempre coincide con lo que se ve.
local ATLAS_STATE = { locked = "locked", gray = "open", green = "green", yellow = "max", red = "error" }
function T.AtlasState(button)
    for _, region in pairs({ button:GetRegions() }) do
        if IsTexture(region) and region.GetAtlas then
            local atlas = Readable(region:GetAtlas())
            if type(atlas) == "string" and atlas:find("^talents%-node") and not atlas:find("shadow", 1, true) then
                local color = atlas:match("%-(%a+)$")
                if color and ATLAS_STATE[color] then return ATLAS_STATE[color] end
            end
        end
    end
    return nil
end

function T.State(button)
    local info = button.nodeInfo
    local cur, max
    if type(info) == "table" then
        cur = Readable(info.ranksPurchased) or Readable(info.currentRank)
        max = Readable(info.maxRanks)
    end
    if type(cur) ~= "number" then cur = nil end
    if type(max) ~= "number" then max = nil end
    if not cur then
        local fs = RankText(button)
        local text = fs and Readable(fs:GetText())
        cur = type(text) == "string" and tonumber(text:match("^(%d+)")) or nil
        local top = type(text) == "string" and tonumber(text:match("/(%d+)")) or nil
        max = max or top
    end
    local state = T.AtlasState(button)
    if state == "green" then
        state = (cur and max and max > 0 and cur >= max) and "max" or ((cur and cur > 0) and "some" or "open")
    end
    local vs = Readable(button.visualState)
    local V = TalentButtonUtil and TalentButtonUtil.BaseVisualState
    if not state and V and type(vs) == "number" then
        if vs == V.Maxed then state = "max"
        elseif vs == V.RefundInvalid or vs == V.DisplayError then state = "error"
        elseif vs == V.Selectable then state = (cur and cur > 0) and "some" or "open"
        elseif vs == V.Locked or vs == V.Gated or vs == V.Disabled then state = (cur and cur > 0) and "some" or "locked"
        end
    end
    if not state then
        if cur and max and max > 0 and cur >= max then state = "max"
        elseif cur and cur > 0 then state = "some"
        else
            local icon = IconOf(button)
            local dim = icon and icon.IsDesaturated and Readable(icon:IsDesaturated())
            state = dim and "locked" or "open"
        end
    end
    return state, cur, max
end

---------------------------------------------------------------------------
-- Pintar un talento
---------------------------------------------------------------------------
local CROP = 0.08

local function Ring(state)
    local r, g, b = Win.Accent()
    if not r then r, g, b = 1, 0.82, 0.2 end
    if state == "max" then return r, g, b, 1 end
    if state == "some" then return r, g, b, 0.75 end
    if state == "open" then return 0.85, 0.87, 0.92, 0.55 end
    if state == "error" then return 0.95, 0.25, 0.25, 1 end
    return 0.16, 0.16, 0.18, 1
end

function T.SkinButton(button, on)
    local d = Win.Parts(button)
    if not on and not d.tRing then return end
    local icon = IconOf(button)
    if not icon then return end
    if not d.tRing then
        d.tEdge = Win.Texture(button, "BACKGROUND", -8)
        d.tRing = Win.Texture(button, "BACKGROUND", -7)
        d.tInner = Win.Texture(button, "BACKGROUND", -6)
        d.tGlow = Win.Texture(button, "BACKGROUND", -8)
        d.tHover = Win.Texture(button, "HIGHLIGHT", 7)
        d.tPill = Win.Texture(button, "OVERLAY", 6)
        d.tRank = button:CreateFontString(nil, "OVERLAY")
        d.tRank:SetFont(M.FONT, 9, "OUTLINE")
    end
    -- El arte de Blizzard (marco, sombra, brillo...) fuera; el icono y el texto se quedan.
    local keep = { [icon] = true }
    for _, region in pairs({ button:GetRegions() }) do
        if IsTexture(region) and not keep[region] then Hold(region, on) end
    end
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(), button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
    }) do if region ~= icon then Hold(region, on) end end
    -- El marco del talento va en capas hijas (borde, sombra, brillo de estado):
    -- también fuera. Los textos se quedan.
    Win.Walk(button, function(f)
        for _, region in pairs({ f:GetRegions() }) do
            if IsTexture(region) and region ~= icon then Hold(region, on) end
        end
    end, 2)
    -- Icono cuadrado y recortado (sin máscara: con máscara no se puede recortar).
    if on and not d.tMasks and icon.GetNumMaskTextures then
        d.tMasks = {}
        for i = icon:GetNumMaskTextures(), 1, -1 do
            local mask = icon:GetMaskTexture(i)
            if mask then
                d.tMasks[#d.tMasks + 1] = mask
                icon:RemoveMaskTexture(mask)
            end
        end
    end
    if on then
        local a = icon.GetTexCoord and icon:GetTexCoord()
        if a ~= CROP then pcall(icon.SetTexCoord, icon, CROP, 1 - CROP, CROP, 1 - CROP) end
    elseif d.tMasks then
        pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        for _, mask in ipairs(d.tMasks) do icon:AddMaskTexture(mask) end
        d.tMasks = nil
    end

    local px = M.PixelSize()
    d.tEdge:ClearAllPoints()
    d.tEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -4, 4)
    d.tEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
    d.tEdge:SetColorTexture(0, 0, 0, 1)
    d.tRing:ClearAllPoints()
    d.tRing:SetPoint("TOPLEFT", d.tEdge, "TOPLEFT", px, -px)
    d.tRing:SetPoint("BOTTOMRIGHT", d.tEdge, "BOTTOMRIGHT", -px, px)
    d.tInner:ClearAllPoints()
    d.tInner:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    d.tInner:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    d.tInner:SetColorTexture(0, 0, 0, 1)
    d.tGlow:ClearAllPoints()
    d.tGlow:SetPoint("TOPLEFT", icon, "TOPLEFT", -9, 9)
    d.tGlow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 9, -9)
    d.tGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    d.tHover:ClearAllPoints()
    d.tHover:SetAllPoints(icon)
    d.tHover:SetColorTexture(1, 1, 1, 0.12)
    d.tRank:ClearAllPoints()
    d.tRank:SetPoint("CENTER", icon, "BOTTOMRIGHT", -2, 2)
    d.tPill:ClearAllPoints()
    d.tPill:SetPoint("TOPLEFT", d.tRank, "TOPLEFT", -3, 2)
    d.tPill:SetPoint("BOTTOMRIGHT", d.tRank, "BOTTOMRIGHT", 3, -2)
    d.tPill:SetColorTexture(0.03, 0.03, 0.04, 0.92)
    for _, key in ipairs({ "tEdge", "tRing", "tInner", "tHover" }) do d[key]:SetShown(on) end
    if not on then
        d.tGlow:Hide(); d.tPill:Hide(); d.tRank:Hide()
        local fs = RankText(button)
        if fs then Hold(fs, false) end
        return
    end
    T.PaintButton(button)
end

function T.PaintButton(button)
    local d = Win.Parts(button)
    if not d.tRing then return end
    local opts = Opts()
    local state, cur, max = T.State(button)
    local r, g, b, a = Ring(state)
    d.tRing:SetColorTexture(r, g, b, a)
    -- Al máximo: un halo suave de tu color detrás.
    local glow = opts.glow and state == "max"
    if glow then d.tGlow:SetVertexColor(r, g, b, 0.22) end
    d.tGlow:SetShown(glow)
    -- Rango propio "2/5" (solo si se conoce el máximo); el de Blizzard, fuera.
    local fs = RankText(button)
    local own = opts.ranks and cur and max and max > 0
    if own then
        d.tRank:SetText(cur .. "/" .. max)
        if state == "max" then d.tRank:SetTextColor(r, g, b)
        elseif cur > 0 then d.tRank:SetTextColor(1, 1, 1)
        else d.tRank:SetTextColor(0.55, 0.55, 0.6) end
    end
    d.tRank:SetShown(own and true or false)
    d.tPill:SetShown(own and true or false)
    if fs then Hold(fs, own and true or false) end
end

---------------------------------------------------------------------------
-- Arte de los árboles, pestañas, botones y buscador
---------------------------------------------------------------------------
local function Size(region)
    local w, h = region:GetSize()
    w, h = Readable(w), Readable(h)
    return type(w) == "number" and w or 0, type(h) == "number" and h or 0
end

-- Fondos grandes de los árboles: tenues. Adornos (líneas y bandas doradas,
-- brillos bajo los nombres, esquinas del borde): fuera.
local FRAME_ART = { NineSlice = true, Border = true, BorderFrame = true, Frame = true }
function T.Art(tf, on)
    local level = math.max(0, math.min(100, Opts().art or 40)) / 100
    local function Visit(frame)
        for _, region in ipairs(Win.Textures(frame)) do
            local w, h = Size(region)
            if w >= 180 and h >= 180 then
                Hold(region, on, level)
            elseif (h > 0 and h <= 12 and w >= 80) or (w >= 300 and h > 0 and h <= 80) then
                Hold(region, on)
            end
        end
    end
    -- Forever pone aparte un fondo más alto que la página, encima de la barra superior.
    Visit(tf)
    -- Las texturas propias de la página que no son el arte de los árboles son
    -- adornos del borde (esquinas, filos): fuera.
    for _, region in ipairs(Win.Textures(tf)) do
        local w, h = Size(region)
        if not (w >= 180 and h >= 180) then Hold(region, on) end
    end
    local bg = Child(tf, "Background")
    if Child(tf, "ClassBackground") and IsTexture(bg) then Hold(bg, on) end
    Win.Walk(tf, function(f)
        if T.IsTalentButton(f) or IsTabSystem(f) or f.GetObjectType and f:GetObjectType() == "Button" then return false end
        local key
        for k in pairs(FRAME_ART) do if Child(f:GetParent(), k) == f then key = k end end
        if key then
            Win.Strip(f, on)
            return false
        end
        Visit(f)
    end, 3)
end

local function TabSelected(tab)
    local v = rawget(tab, "isSelected")
    if v ~= nil then return v end
    return tab.IsEnabled and not tab:IsEnabled()
end

function T.TabSystems(frame, on)
    local list = {}
    local function Add(system)
        if not IsTabSystem(system) then return end
        for _, tab in pairs(rawget(system, "tabs")) do
            if type(tab) == "table" and tab.CreateTexture then
                Win.SkinTab(tab, frame, on and Win.db.tabs, TabSelected)
                list[#list + 1] = tab
            end
        end
    end
    Add(Child(frame, "TabSystem"))
    Add(Child(Talents(frame), "TabSystem"))
    return list
end

function T.Buttons2(tf, on)
    Win.Walk(tf, function(f)
        if IsTabSystem(f) or T.IsTalentButton(f) then return false end
        if Win.IsPanelButton(f) then
            Win.FlatButton(f, on)
            return false
        end
        if f.GetObjectType and f:GetObjectType() == "EditBox" then
            Win.FlatEditBox(f, on)
            return false
        end
    end, 4)
end

---------------------------------------------------------------------------
-- Reparto de puntos arriba a la izquierda: "Puntería  0 / 2 / 0"
---------------------------------------------------------------------------
local function TreeInfo(i)
    if type(GetTalentTabInfo) ~= "function" then return nil end
    local values = { pcall(GetTalentTabInfo, i) }
    if not values[1] then return nil end
    local name, at
    for k = 2, #values do
        if type(values[k]) == "string" then name, at = values[k], k; break end
    end
    if not name then return nil end
    -- Los puntos: el último número justo después del nombre (cambia de sitio
    -- según la versión: nombre, icono, puntos... o nombre, texto, icono, puntos...).
    local points
    for k = at + 1, math.min(at + 3, #values) do
        local v = Readable(values[k])
        if type(v) == "number" then points = v end
    end
    return name, points
end

function T.Summary()
    if type(GetNumTalentTabs) ~= "function" then return nil end
    local ok, count = pcall(GetNumTalentTabs)
    count = ok and Readable(count)
    if type(count) ~= "number" or count < 1 then return nil end
    local trees, best, bestPoints = {}, nil, -1
    for i = 1, math.min(count, 4) do
        local name, points = TreeInfo(i)
        if not (name and points) then return nil end
        trees[i] = { name = name, points = points }
        if points > bestPoints then best, bestPoints = i, points end
    end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 1, 0.82, 0.2 end
    local hex = string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
    local parts = {}
    for i, tree in ipairs(trees) do
        parts[i] = (i == best and bestPoints > 0) and ("|cffffffff" .. tree.points .. "|r") or ("|cff8a8a92" .. tree.points .. "|r")
    end
    local lead = bestPoints > 0 and (hex .. trees[best].name .. "|r  ") or ""
    return lead .. table.concat(parts, " |cff555560/|r ")
end

local summary
local function PaintSummary(frame, on)
    if not summary then
        local host = Win.Own(CreateFrame("Frame", nil, frame))
        host:SetAllPoints(frame)
        host:SetFrameLevel((frame:GetFrameLevel() or 1) + 20)
        summary = host:CreateFontString(nil, "OVERLAY")
        summary:SetFont(M.FONT, 12, "OUTLINE")
        summary:SetPoint("LEFT", frame, "TOPLEFT", 12, -12)
    end
    local text = on and Opts().summary and T.Summary()
    summary:SetText(text or "")
    summary:SetShown(text and true or false)
end
T.PaintSummary = PaintSummary

---------------------------------------------------------------------------
-- Repaso mientras la ventana está abierta
---------------------------------------------------------------------------
local ticker
local function Tick(frame)
    local on = Win.active and Win.PackOn(T.pack)
    if on then
        for _, button in ipairs(T.Buttons(frame)) do
            local d = Win.Parts(button)
            if not d.tRing then
                T.SkinButton(button, true)
            else
                -- Blizzard puede volver a poner el recorte del icono al actualizarlo.
                local icon = IconOf(button)
                local a = icon and icon.GetTexCoord and icon:GetTexCoord()
                if icon and a ~= CROP then pcall(icon.SetTexCoord, icon, CROP, 1 - CROP, CROP, 1 - CROP) end
                T.PaintButton(button)
            end
        end
    end
    for _, tab in ipairs(T.TabSystems(frame, on)) do Win.PaintTab(tab) end
    PaintSummary(frame, on)
end

local function StartTicker(frame)
    if ticker then return end
    ticker = Win.Own(CreateFrame("Frame", nil, frame))
    local elapsed = 0
    ticker:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.15 then return end
        elapsed = 0
        if Win.PackOn(T.pack) then Tick(frame) end
    end)
end

---------------------------------------------------------------------------
-- Recuadros y anillos dorados: "Talentos sin usar", el anillo del icono de
-- cada árbol y el recuadro de sus puntos. Se reconocen por su arte
-- (Talents-Square-Box, Talents-Main-Ring, Talents-Main-Ring-Box) y se
-- cambian por los nuestros, anclados a la misma pieza.
---------------------------------------------------------------------------
local function AtlasOf(region)
    local atlas = region.GetAtlas and Readable(region:GetAtlas())
    return type(atlas) == "string" and atlas:lower() or nil
end

-- Un recuadro oscuro con borde de acento en el sitio de "tex". Con "label"
-- (un texto a su izquierda, como "Talentos sin usar"), el recuadro lo cubre.
local function Box(tex, on, label)
    local d = Win.Parts(tex)
    if not on and not d.boxEdge then return end
    local parent = tex:GetParent()
    if not d.boxEdge then
        d.boxEdge = Win.Texture(parent, "BORDER", -2)
        d.boxFill = Win.Texture(parent, "BORDER", -1)
    end
    Hold(tex, on)
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.6, 0.6, 0.65 end
    local px = M.PixelSize()
    d.boxEdge:ClearAllPoints()
    if label then
        d.boxEdge:SetPoint("TOP", tex, "TOP", 0, -3)
        d.boxEdge:SetPoint("BOTTOM", tex, "BOTTOM", 0, 3)
        d.boxEdge:SetPoint("LEFT", label, "LEFT", -10, 0)
        d.boxEdge:SetPoint("RIGHT", tex, "RIGHT", -3, 0)
    else
        d.boxEdge:SetPoint("TOPLEFT", tex, "TOPLEFT", 3, -3)
        d.boxEdge:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", -3, 3)
    end
    d.boxEdge:SetColorTexture(r, g, b, 0.85)
    d.boxFill:ClearAllPoints()
    d.boxFill:SetPoint("TOPLEFT", d.boxEdge, "TOPLEFT", px, -px)
    d.boxFill:SetPoint("BOTTOMRIGHT", d.boxEdge, "BOTTOMRIGHT", -px, px)
    d.boxFill:SetColorTexture(0.05, 0.05, 0.06, 0.95)
    d.boxEdge:SetShown(on)
    d.boxFill:SetShown(on)
end

-- El icono del árbol: sin el anillo dorado, cuadrado y con nuestro anillo.
local function TreeIcon(ring, icon, on)
    local d = Win.Parts(ring)
    if not on and not d.ringEdge then return end
    Hold(ring, on)
    if not icon then return end
    local di = Win.Parts(icon)
    if not d.ringEdge then
        local parent = icon:GetParent()
        d.ringEdge = Win.Texture(parent, "BACKGROUND", -2)
        d.ringColor = Win.Texture(parent, "BACKGROUND", -1)
    end
    if on and not di.masks and icon.GetNumMaskTextures then
        di.masks = {}
        for i = icon:GetNumMaskTextures(), 1, -1 do
            local mask = icon:GetMaskTexture(i)
            if mask then di.masks[#di.masks + 1] = mask; icon:RemoveMaskTexture(mask) end
        end
    end
    if on then
        pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
    elseif di.masks then
        pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        for _, mask in ipairs(di.masks) do icon:AddMaskTexture(mask) end
        di.masks = nil
    end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.6, 0.6, 0.65 end
    local px = M.PixelSize()
    d.ringEdge:ClearAllPoints()
    d.ringEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -3, 3)
    d.ringEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
    d.ringEdge:SetColorTexture(0, 0, 0, 1)
    d.ringColor:ClearAllPoints()
    d.ringColor:SetPoint("TOPLEFT", d.ringEdge, "TOPLEFT", px, -px)
    d.ringColor:SetPoint("BOTTOMRIGHT", d.ringEdge, "BOTTOMRIGHT", -px, px)
    d.ringColor:SetColorTexture(r, g, b, 1)
    d.ringEdge:SetShown(on)
    d.ringColor:SetShown(on)
end

-- El texto de un marco (o de sus hijos) que no es un número: la etiqueta.
function T.Label(frame)
    local found
    local function Look(f)
        for _, region in pairs({ f:GetRegions() }) do
            if region.GetObjectType and region:GetObjectType() == "FontString" then
                local text = Readable(region:GetText())
                if type(text) == "string" and text ~= "" and not tonumber(text) then found = found or region end
            end
        end
    end
    Look(frame)
    if not found then Win.Walk(frame, function(f) Look(f) end, 2) end
    return found
end

function T.Chrome(tf, on)
    Win.Walk(tf, function(f)
        if T.IsTalentButton(f) or IsTabSystem(f) then return false end
        local ring, icon
        for _, region in pairs({ f:GetRegions() }) do
            if IsTexture(region) then
                local atlas = AtlasOf(region)
                if atlas and atlas:find("square%-box") then
                    Box(region, on, T.Label(f))
                elseif atlas and atlas:find("main%-ring%-box") then
                    Box(region, on)
                elseif atlas and atlas:find("main%-ring") then
                    ring = region
                elseif atlas and atlas:find("small%-divider") then
                    Hold(region, on)
                elseif not atlas and region.GetTexture and region:GetTexture() then
                    icon = icon or region
                end
            end
        end
        if ring then TreeIcon(ring, icon, on) end
    end, 3)
end

local hookedTalents = setmetatable({}, { __mode = "k" })

function T.Apply(frame, on)
    local tf = Talents(frame)
    if tf then
        if not hookedTalents[tf] then
            hookedTalents[tf] = true
            -- Al cambiar a la pestaña de talentos, Blizzard monta los árboles.
            tf:HookScript("OnShow", function()
                C_Timer.After(0, function() if Win.active then Win.ApplyPack(T.pack) end end)
            end)
        end
        T.Art(tf, on)
        T.Chrome(tf, on)
        T.Buttons2(tf, on)
        for _, button in ipairs(T.Buttons(frame, true)) do T.SkinButton(button, on) end
    end
    T.Buttons2(frame, on)
    T.TabSystems(frame, on)
    PaintSummary(frame, on)
    if Win.Spellbook then Win.Spellbook.Apply(frame, on) end
    if on then StartTicker(frame) end
end

function T.Diagnose(frame)
    local tf = Talents(frame)
    print("  talentos: página " .. (tf and "sí" or "no") .. ", botones " .. #T.Buttons(frame, true) ..
          ", reparto: " .. tostring(T.Summary() or "sin datos"))
    if tf then for _, line in ipairs(Win.Dump(tf, 3)) do print("    " .. line) end end
    if Win.Spellbook then Win.Spellbook.Diagnose() end
    local first = T.Buttons(frame)[1]
    if first then
        local state, cur, max = T.State(first)
        print(string.format("  primer talento: %s  estado %s  rango %s/%s  nodeInfo %s  visualState %s",
            tostring(first:GetName() or "(sin nombre)"), state, tostring(cur), tostring(max),
            type(first.nodeInfo) == "table" and "sí" or "no", tostring(first.visualState)))
    end
end

T.pack = {
    key = "talents", title = "Talentos",
    frame = function() return _G.PlayerSpellsFrame end,
    apply = T.Apply,
    diagnose = T.Diagnose,
}
Win.Register(T.pack)
