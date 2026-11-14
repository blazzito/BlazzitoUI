-- Menús desplegables (el sistema Menu de Blizzard: el de las bolsas, los de
-- botón derecho, los de las listas...) con el estilo de BlazzitoUI: fondo
-- oscuro plano con borde de 1 px en lugar del marco dorado clásico.
--
-- Cada vez que se abre un menú, Blizzard le genera el fondo con
-- MenuStyle*Mixin:Generate() usando texturas de una reserva compartida. Con
-- un gancho posterior (hooksecurefunc) se recolorean esas dos texturas de
-- ese menú. No se ocultan con alfa ni se les pone ningún gancho: al volver a
-- la reserva Blizzard las deja como nuevas, así que nada se queda pegado a
-- otra cosa.
local ns = BlazzitoUI
local Win = ns and ns.Windows
if not Win then return end

local W = ns.Widgets
local T = W.T

local STYLES = { "MenuStyle1Mixin", "MenuStyle1ThinMixin", "MenuStyle2Mixin" }
local hookedStyles = {}

local function Enabled()
    return (Win.active or Win.padResting) and Win.db and Win.db.menus
end

-- La textura con el atlas del fondo clásico: common-dropdown-classic-bg,
-- common-dropdown-classic-b-bg, common-dropdown-bg...
local function IsMenuBackground(region)
    local atlas = region.GetAtlas and region:GetAtlas()
    return type(atlas) == "string" and atlas:find("dropdown", 1, true) and atlas:find("bg", 1, true) and true or false
end

function Win.StyleMenu(style)
    if not Enabled() or type(style) ~= "table" or not style.GetRegions then return false end
    local ok, regions = pcall(function() return { style:GetRegions() } end)
    if not ok then return false end
    local frame, fill
    for _, region in ipairs(regions) do
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then
            if not frame and IsMenuBackground(region) then frame = region
            elseif not fill and not IsMenuBackground(region) then fill = region end
        end
    end
    if not (frame and fill) then return false end
    -- El fondo dorado pasa a ser el borde de 1 px; el negro de dentro, nuestro fondo.
    local line = T.ctrlBorder
    frame:SetColorTexture(line[1], line[2], line[3], 1)
    fill:SetColorTexture(T.bg[1], T.bg[2], T.bg[3], 0.97)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    return true
end

function Win.HookMenus()
    for _, key in ipairs(STYLES) do
        local mixin = _G[key]
        if type(mixin) == "table" and type(mixin.Generate) == "function" and not hookedStyles[key] then
            hookedStyles[key] = true
            hooksecurefunc(mixin, "Generate", function(self) Win.StyleMenu(self) end)
        end
    end
end

Win.HookMenus()
ns.On("ADDON_LOADED", function(_, name) if name == "Blizzard_Menu" then Win.HookMenus() end end)
