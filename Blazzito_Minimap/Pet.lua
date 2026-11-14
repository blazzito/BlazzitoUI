-- Blazzito_Minimap: tu mascota en el minimapa, con una huella bien visible.
--
-- El punto que pone el juego es diminuto. Aquí se dibuja encima una huella
-- (Media/paw.tga, blanca con borde negro) en la posición de la mascota,
-- teñida según su felicidad (verde feliz, amarillo contenta, rojo infeliz)
-- o con el color de BlazzitoUI. Si la mascota se aleja más allá del borde,
-- la huella se queda pegada al borde en su dirección.
--
-- La posición sale de UnitPosition (la tuya y la de la mascota) y del zoom
-- del minimapa: los metros que abarca cada nivel de zoom son fijos en el
-- juego (distintos en interiores). Con el minimapa girando, se gira igual.
local ns = BlazzitoUI
if not (ns and ns.Minimap) then return end

local MM, M = ns.Minimap, ns.Media
local Readable = M.Readable
local PAW = "Interface\\AddOns\\Blazzito_Minimap\\Media\\paw"

-- Metros de lado a lado del minimapa en cada nivel de zoom.
local OUTDOOR = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local INDOOR = { [0] = 300, 240, 180, 120, 80, 50 }
local EDGE = 0.9

local function Position(unit)
    if not UnitPosition then return nil end
    local ok, y, x, _, instance = pcall(UnitPosition, unit)
    if not ok then return nil end
    x, y, instance = Readable(x), Readable(y), Readable(instance)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    return x, y, instance
end

-- Desplazamiento de la mascota desde el centro del minimapa, en píxeles,
-- y si está fuera (pegada al borde). nil si no se puede saber.
function MM.PetOffset()
    local minimap = _G.Minimap
    if not (minimap and UnitExists and UnitExists("pet")) then return nil end
    local px, py, pi = Position("player")
    local tx, ty, ti = Position("pet")
    if not (px and tx) or pi ~= ti then return nil end
    local okZ, zoom = pcall(minimap.GetZoom, minimap)
    zoom = okZ and Readable(zoom) or 0
    local indoors = IsIndoors and IsIndoors()
    local across = (indoors and INDOOR or OUTDOOR)[zoom] or 300
    local radius = across / 2
    -- UnitPosition da (oeste, norte): el este es lo contrario del oeste.
    local east, north = py - ty, tx - px
    -- Con el minimapa girando, arriba es hacia donde miras: se gira al revés.
    if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
        local facing = Readable(GetPlayerFacing())
        if type(facing) == "number" then
            local s, c = math.sin(facing), math.cos(facing)
            east, north = east * c + north * s, -east * s + north * c
        end
    end
    local fx, fy = east / radius, north / radius
    local len = math.sqrt(fx * fx + fy * fy)
    local outside = len > EDGE
    if outside then fx, fy = fx / len * EDGE, fy / len * EDGE end
    local w, h = minimap:GetWidth() / 2, minimap:GetHeight() / 2
    return fx * w, fy * h, outside, len * radius
end

-- Color: felicidad de la mascota (Forever: C_PetInfo) o el de BlazzitoUI.
local HAPPY = { [1] = { 0.95, 0.25, 0.2 }, [2] = { 1, 0.82, 0.2 }, [3] = { 0.35, 0.9, 0.35 } }
function MM.PawColor()
    if UnitIsDead and UnitIsDead("pet") then return 0.5, 0.5, 0.5 end
    if MM.db.pawHappiness then
        local fn = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness
        if fn then
            local ok, happiness = pcall(fn)
            local c = ok and HAPPY[Readable(happiness)]
            if c then return c[1], c[2], c[3] end
        end
    end
    local a = M.COLORS.accent
    return a[1], a[2], a[3]
end

local paw
local function Build()
    local minimap = _G.Minimap
    if paw or not minimap then return end
    paw = CreateFrame("Frame", nil, minimap)
    paw:SetFrameLevel((minimap:GetFrameLevel() or 1) + 8)
    paw.icon = paw:CreateTexture(nil, "OVERLAY")
    paw.icon:SetAllPoints()
    paw.icon:SetTexture(PAW)
    paw:Hide()
    local waited = 0
    paw:SetScript("OnUpdate", function(self, elapsed)
        waited = waited + elapsed
        if waited < 0.03 then return end
        waited = 0
        MM.UpdatePaw()
    end)
    MM.paw = paw
end

-- El repaso lo hace un marco aparte (la huella oculta no recibe OnUpdate).
local watcher
function MM.UpdatePaw()
    if not paw then return end
    local on = MM.active and MM.db.petPaw
    local x, y, outside, yards
    if on then x, y, outside, yards = MM.PetOffset() end
    if not x then paw:Hide(); return end
    local size = MM.db.pawSize or 18
    paw:SetSize(size, size)
    paw:ClearAllPoints()
    paw:SetPoint("CENTER", _G.Minimap, "CENTER", x, y)
    local r, g, b = MM.PawColor()
    paw.icon:SetVertexColor(r, g, b)
    -- Pegada a ti, más tenue (no tapa tu flecha); fuera del mapa, también.
    paw:SetAlpha((outside and 0.7) or ((yards or 99) < 3 and 0.5) or 1)
    paw:Show()
end

function MM.EnablePaw()
    Build()
    if watcher then return end
    watcher = CreateFrame("Frame")
    local waited = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < 0.1 then return end
        waited = 0
        if paw and not paw:IsShown() then MM.UpdatePaw() end
    end)
end

-- Diagnóstico para /bui minimapa.
function MM.PawReport()
    local px = Position("player")
    local tx = Position("pet")
    local x, y, outside, yards = MM.PetOffset()
    print(string.format("  huella de la mascota: %s · posición tuya %s · de la mascota %s · %s",
        MM.db.petPaw and "activada" or "apagada", px and "sí" or "no", tx and "sí" or "no",
        x and string.format("a %.0f m%s", yards or 0, outside and " (fuera del mapa)" or "") or "sin datos"))
end

local enable = MM.OnEnable
function MM:OnEnable()
    if enable then enable(self) end
    MM.EnablePaw()
end
