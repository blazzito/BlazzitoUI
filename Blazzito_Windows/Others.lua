-- Blazzito_Windows: más ventanas de Blizzard con el estilo de BlazzitoUI:
-- entrenadores, botín y tiradas de grupo, comerciante, correo, profesiones y
-- casa de subastas.
--
-- Todas con lo mismo: marco oscuro con la barra de acento (Win.Shell), y por
-- dentro, reconocidas por su forma (no por su nombre, que cambia entre
-- versiones), las piezas comunes:
--   - botones de texto (tres piezas Left/Middle/Right) → planos;
--   - cajas de texto y buscadores → planas;
--   - casillas de objeto o hechizo (botón cuadrado con icono) → icono
--     recortado con borde fino; el color de calidad de Blizzard se queda;
--   - marcos de fondo interiores (Inset, NineSlice...) → fuera;
--   - barras de desplazamiento → las finas del motor.
-- Solo aspecto: nada de lo que hacen estas ventanas cambia.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win = ns.Windows
local M = ns.Media
local Child, Hold = Win.Child, Win.Hold
local Readable = M.Readable

local O = {}
Win.Others = O

local function Size(f)
    local w, h = f:GetSize()
    return Readable(w) or 0, Readable(h) or 0
end
local function Kind(f) return f.GetObjectType and f:GetObjectType() end
local function IsButton(f) local k = Kind(f); return k == "Button" or k == "CheckButton" end

-- El icono de una casilla: Icon / icon / <Nombre>IconTexture.
local function SlotIcon(f)
    local icon = Child(f, "Icon") or Child(f, "icon") or Child(f, nil, "IconTexture") or Child(f, "IconTexture")
    return Win.IsTexture(icon) and icon or nil
end

---------------------------------------------------------------------------
-- Casilla de objeto: icono recortado, borde fino y fondo oscuro. Se quedan
-- el icono, el número, el color de calidad (IconBorder) y los avisos.
---------------------------------------------------------------------------
local KEEP = { "IconBorder", "IconOverlay", "IconOverlay2", "Count", "Stock", "searchOverlay", "ItemContextOverlay",
    "JunkIcon", "UpgradeIcon", "NewItemTexture", "QuestIcon", "Cooldown", "SelectedTexture" }

function O.Slot(btn, on)
    local icon = SlotIcon(btn)
    if not icon then return end
    local d = Win.Parts(btn)
    if not on and not d.slEdge then return end
    if not d.slEdge then
        d.slEdge = Win.Texture(btn, "BACKGROUND", -8)
        d.slBg = Win.Texture(btn, "BACKGROUND", -7)
    end
    local keep = { [icon] = true }
    for _, key in ipairs(KEEP) do
        local part = Child(btn, key) or Child(btn, nil, key)
        if part then keep[part] = true end
    end
    local normal = btn.GetNormalTexture and btn:GetNormalTexture()
    if normal and normal ~= icon then Hold(normal, on) end
    for _, region in pairs({ btn:GetRegions() }) do
        if Win.IsTexture(region) and not keep[region] then
            -- El fondo de casilla y el marco antiguo (grandes o sin nombre de pieza útil).
            local layer = region.GetDrawLayer and region:GetDrawLayer()
            if layer == "BACKGROUND" or layer == "BORDER" then Hold(region, on) end
        end
    end
    if on and icon.GetNumMaskTextures and not d.slMasks then
        d.slMasks = {}
        for i = icon:GetNumMaskTextures(), 1, -1 do
            local mask = icon:GetMaskTexture(i)
            if mask then d.slMasks[#d.slMasks + 1] = mask; icon:RemoveMaskTexture(mask) end
        end
    end
    if on then pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
    elseif d.slMasks then
        pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        for _, mask in ipairs(d.slMasks) do icon:AddMaskTexture(mask) end
        d.slMasks = nil
    end
    local px = M.PixelSize()
    d.slEdge:ClearAllPoints()
    d.slEdge:SetPoint("TOPLEFT", icon, "TOPLEFT", -px, px)
    d.slEdge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", px, -px)
    d.slEdge:SetColorTexture(0, 0, 0, 1)
    d.slBg:ClearAllPoints()
    d.slBg:SetAllPoints(icon)
    d.slBg:SetColorTexture(0.07, 0.07, 0.08, 1)
    d.slEdge:SetShown(on)
    d.slBg:SetShown(on)
end

local function IsSlot(f)
    if not IsButton(f) or not SlotIcon(f) then return false end
    local w, h = Size(f)
    return w >= 24 and w <= 64 and math.abs(w - h) <= 6
end

---------------------------------------------------------------------------
-- Recorrido común
---------------------------------------------------------------------------
local INSETS = { Inset = true, InsetFrame = true, InsetBg = true, NineSlice = true, Bg = true, Background = true }

local function KeyOf(parent, child)
    if type(parent) ~= "table" then return nil end
    for _, key in ipairs({ "Inset", "InsetFrame", "NineSlice", "Bg", "Background" }) do
        if Child(parent, key) == child then return key end
    end
    local name = child.GetName and child:GetName()
    if type(name) == "string" and (name:find("Inset$") or name:find("InsetFrame$")) then return "Inset" end
    return nil
end

function O.Generic(frame, on)
    Win.Walk(frame, function(f)
        if Win.IsScrollBar(f) then return false end
        local kind = Kind(f)
        if kind == "EditBox" then Win.FlatEditBox(f, on); return false end
        if Win.IsPanelButton(f) then Win.FlatButton(f, on); return false end
        if IsSlot(f) then O.Slot(f, on); return false end
        -- Fondos interiores (Inset, NineSlice...): fuera.
        local key = KeyOf(f:GetParent(), f)
        if key and INSETS[key] then Win.Strip(f, on) end
        -- Filas de comerciante (MerchantItemN...): su marco de casilla y nombre, fuera.
        local name = f.GetName and f:GetName()
        if type(name) == "string" and name:find("Item%d+$") and not IsButton(f) then Win.Strip(f, on) end
    end, 6)
end

---------------------------------------------------------------------------
-- Paquetes: un nombre de marco cada uno (las versiones clásicas por si existen)
---------------------------------------------------------------------------
O.LIST = {
    { key = "trainer", title = "Entrenador", frame = "ClassTrainerFrame" },
    { key = "trainer", title = "Entrenador (clásico)", frame = "TrainerFrame" },
    { key = "trainer", title = "Adiestramiento de bestias", frame = "CraftFrame" },
    { key = "loot", title = "Botín", frame = "LootFrame" },
    { key = "loot", title = "Tirada de botín 1", frame = "GroupLootFrame1", compact = true },
    { key = "loot", title = "Tirada de botín 2", frame = "GroupLootFrame2", compact = true },
    { key = "loot", title = "Tirada de botín 3", frame = "GroupLootFrame3", compact = true },
    { key = "loot", title = "Tirada de botín 4", frame = "GroupLootFrame4", compact = true },
    { key = "merchant", title = "Comerciante", frame = "MerchantFrame" },
    { key = "mail", title = "Correo", frame = "MailFrame" },
    { key = "mail", title = "Leer correo", frame = "OpenMailFrame" },
    { key = "professions", title = "Profesiones", frame = "ProfessionsFrame" },
    { key = "professions", title = "Profesiones (clásico)", frame = "TradeSkillFrame" },
    { key = "auction", title = "Casa de subastas", frame = "AuctionHouseFrame" },
    { key = "auction", title = "Casa de subastas (clásica)", frame = "AuctionFrame" },
}

for _, info in ipairs(O.LIST) do
    Win.Register({
        key = info.key, title = info.title, compact = info.compact,
        padSafe = true,   -- solo texturas: también con el estilo de mando (Skin.lua)
        frame = function() return _G[info.frame] end,
        apply = function(frame, on) O.Generic(frame, on) end,
    })
end
