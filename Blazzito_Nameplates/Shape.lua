-- Bloques con forma para las placas: borde, barra (con fondo) y contorno de
-- objetivo, todos con la misma silueta.
--
-- Por qué no se usan las máscaras de los marcos de unidad: miden 256x64 y al
-- estirarse a una placa fina (140x12) la inclinación se aplasta y el borde
-- sale borroso. Aquí cada extremo lleva una "tapa" cuadrada del alto de la
-- barra (Media/cap_<forma>[_h|_v|_hv]_<l|r>, de tools/make_platecaps.py)
-- puesta como máscara en modo CLAMP: fuera del cuadrado se repite su columna
-- de borde, que es blanca, así que la tapa solo recorta su extremo. El ángulo
-- es el mismo con cualquier ancho.
local ns = BlazzitoUI
if not (ns and ns.Nameplates) then return end

local NP, M = ns.Nameplates, ns.Media
local WHITE = "Interface\\Buttons\\WHITE8X8"
local SLANT_K = 0.5 + math.sqrt(1.25)

local Shape = {}
NP.Shape = Shape

-- depth: cuánto entra la tapa (en altos de barra), para apartar los textos.
-- k: cuánto hay que separar en horizontal el borde de un lado con tapa para
-- que su grosor, medido en perpendicular, sea el mismo que en los lados rectos.
Shape.INFO = {
    rect    = { text = "Rectángulo", depth = 0 },
    slant   = { text = "Inclinada", flips = true, depth = 0.5, k = SLANT_K },
    wing    = { text = "Ala (un lado inclinado)", flips = true, depth = 0.5, k = SLANT_K, oneSide = true },
    bevel   = { text = "Chaflán (esquinas cortadas)", depth = 0.3, k = 1 },
    rounded = { text = "Redondeada", depth = 0.5, k = 1 },
    hex     = { text = "Hexagonal (en punta)", depth = 0.45, k = math.sqrt(1 + 0.9 * 0.9) },
}
Shape.ORDER = { "rect", "slant", "wing", "bevel", "rounded", "hex" }

-- Texturas de las tapas izquierda y derecha (nil = extremo recto).
function Shape.Caps(shape, flipH, flipV)
    local info = Shape.INFO[shape]
    if not info or shape == "rect" then return nil, nil end
    local suffix = ""
    if info.flips then
        suffix = (flipH and "h" or "") .. (flipV and "v" or "")
        if suffix ~= "" then suffix = "_" .. suffix end
    end
    local base = NP.MEDIA .. "cap_" .. shape .. suffix .. "_"
    local left, right = base .. "l", base .. "r"
    -- El ala solo tiene inclinado el lado de fuera.
    if info.oneSide then
        if flipH then left = nil else right = nil end
    end
    return left, right
end

local function Layer(block, sublevel)
    local t = block:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    t:SetTexture(WHITE)
    t.capL, t.capR = block:CreateMaskTexture(), block:CreateMaskTexture()
    t:AddMaskTexture(t.capL)
    t:AddMaskTexture(t.capR)
    return t
end

function Shape.NewBlock(parent)
    local block = CreateFrame("Frame", nil, parent)
    block.outline = Layer(block, -8)     -- contorno del objetivo
    block.outline:Hide()
    block.border = Layer(block, -7)
    block.border:SetVertexColor(0, 0, 0, 1)

    local bar = M.StatusBar(block)
    local fill = bar:GetStatusBarTexture()
    bar.capL, bar.capR, bar.lead = bar:CreateMaskTexture(), bar:CreateMaskTexture(), bar:CreateMaskTexture()
    -- Relleno: tapa izquierda y, en su final, la tapa derecha ("lead") que
    -- sigue al relleno para que el borde de la vida tenga la misma forma.
    fill:AddMaskTexture(bar.capL)
    fill:AddMaskTexture(bar.lead)
    bar.bg:AddMaskTexture(bar.capL)
    bar.bg:AddMaskTexture(bar.capR)
    bar.gloss = bar:CreateTexture(nil, "OVERLAY")
    bar.gloss:SetPoint("TOPLEFT", fill, "TOPLEFT")
    bar.gloss:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    bar.gloss:SetColorTexture(1, 1, 1, 1)
    if CreateColor and bar.gloss.SetGradient then
        bar.gloss:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.18))
    end
    bar.gloss:AddMaskTexture(bar.capL)
    bar.gloss:AddMaskTexture(bar.lead)
    bar.gloss:Hide()
    block.bar = bar
    return block
end

-- Una tapa: cuadrado del alto de su capa, pegado a un extremo. Sin tapa, un
-- cuadrado blanco (no recorta nada).
local function SetCap(mask, file, point, relative, size)
    mask:SetTexture(file or WHITE, "CLAMP", "CLAMP")
    mask:ClearAllPoints()
    mask:SetSize(size, size)
    mask:SetPoint(point, relative, point)
end

-- o = { width, height, edge (borde), outline (contorno), shape, flipH, flipV, gloss }
-- Deja en el bloque insetL / insetR: dónde pueden empezar los textos.
function Shape.Layout(block, o)
    local info = Shape.INFO[o.shape] or Shape.INFO.rect
    local capL, capR = Shape.Caps(o.shape, o.flipH, o.flipV)
    local kL, kR = capL and info.k or 1, capR and info.k or 1
    local w, h, e = o.width, o.height, o.edge
    block:SetSize(w, h)

    local border = block.border
    border:ClearAllPoints()
    border:SetAllPoints(block)
    border:SetShown(e > 0)
    SetCap(border.capL, capL, "TOPLEFT", block, h)
    SetCap(border.capR, capR, "TOPRIGHT", block, h)

    local bar, inner = block.bar, h - 2 * e
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", block, "TOPLEFT", e * kL, -e)
    bar:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", -e * kR, e)
    SetCap(bar.capL, capL, "TOPLEFT", bar, inner)
    SetCap(bar.capR, capR, "TOPRIGHT", bar, inner)
    SetCap(bar.lead, capR, "TOPRIGHT", bar:GetStatusBarTexture(), inner)
    bar.gloss:SetShown(o.gloss and true or false)

    local out, t = block.outline, o.outline or 2
    out:ClearAllPoints()
    out:SetPoint("TOPLEFT", block, "TOPLEFT", -t * kL, t)
    out:SetPoint("BOTTOMRIGHT", block, "BOTTOMRIGHT", t * kR, -t)
    SetCap(out.capL, capL, "TOPLEFT", out, h + 2 * t)
    SetCap(out.capR, capR, "TOPRIGHT", out, h + 2 * t)

    block.capL, block.capR = capL, capR
    block.insetL = e * kL + (capL and info.depth * inner or 0)
    block.insetR = e * kR + (capR and info.depth * inner or 0)
end
