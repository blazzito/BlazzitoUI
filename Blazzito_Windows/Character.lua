-- Ventana de personaje (C) con el estilo de BlazzitoUI.
--
-- Encima de la ventana de Blizzard:
--  * Casillas de equipo con la forma elegida, icono recortado y borde del
--    color de la calidad (gris oscuro si está vacía).
--  * Nivel de objeto en cada pieza y nivel medio sobre el personaje.
--  * Durabilidad baja en la casilla (amarilla y, casi rota, roja).
--  * Fondo del personaje con un degradado del color de tu clase.
--  * Lista de estadísticas sin el arte clásico: cabeceras con el color de
--    acento y filas con separador. Los valores conservan sus colores (verde
--    si están mejorados, rojo si están reducidos).
--  * Los paneles, la franja de piedra y los marcos de bronce, fuera.
--  * Junto a cada pieza, su encantamiento y sus huecos de gema.
--  * Reputación y habilidades: barras planas y cabeceras con el acento.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win, M = ns.Windows, ns.Media
local IsSecret, Readable = M.IsSecret, M.Readable
local Hold, Child, Textures, Strip = Win.Hold, Win.Child, Win.Textures, Win.Strip

local C = {}
Win.Character = C

C.SLOTS = {
    "CharacterHeadSlot", "CharacterNeckSlot", "CharacterShoulderSlot", "CharacterBackSlot",
    "CharacterChestSlot", "CharacterShirtSlot", "CharacterTabardSlot", "CharacterWristSlot",
    "CharacterHandsSlot", "CharacterWaistSlot", "CharacterLegsSlot", "CharacterFeetSlot",
    "CharacterFinger0Slot", "CharacterFinger1Slot", "CharacterTrinket0Slot", "CharacterTrinket1Slot",
    "CharacterMainHandSlot", "CharacterSecondaryHandSlot", "CharacterRangedSlot", "CharacterAmmoSlot",
}
-- Sin nivel de objeto: camisa, tabardo y munición (no significa nada en ellos).
local NO_LEVEL = { CharacterShirtSlot = true, CharacterTabardSlot = true, CharacterAmmoSlot = true }
-- Otras pestañas cuyo fondo clásico se quita.
local OTHER_TABS = { "ReputationFrame", "SkillFrame", "HonorFrame", "PVPFrame", "TokenFrame", "PetPaperDollFrame" }
local STAT_BOXES = { "CharacterStatsPaneScrollBox", "CharacterStatsPanePetScrollBox" }

local function Opts() return Win.db.character end
local slotData = setmetatable({}, { __mode = "k" })
C.slotData = slotData

---------------------------------------------------------------------------
-- Datos de cada pieza
---------------------------------------------------------------------------
local function SlotID(slot, name)
    local id = slot.GetID and slot:GetID()
    if type(id) == "number" and not IsSecret(id) and id > 0 then return id end
    if GetInventorySlotInfo and name then
        local ok, sid = pcall(GetInventorySlotInfo, (name:gsub("^Character", "")))
        if ok and type(sid) == "number" then return sid end
    end
    return nil
end

function C.ItemLevel(slotID)
    if not GetInventoryItemLink("player", slotID) then return nil end
    if not (ItemLocation and ItemLocation.CreateFromEquipmentSlot and C_Item and C_Item.GetCurrentItemLevel) then return nil end
    local ok, level = pcall(C_Item.GetCurrentItemLevel, ItemLocation:CreateFromEquipmentSlot(slotID))
    level = ok and Readable(level) or nil
    return type(level) == "number" and level > 1 and level or nil
end

-- Porcentaje de durabilidad (nil si la pieza no tiene).
function C.Durability(slotID)
    if not GetInventoryItemDurability then return nil end
    local ok, current, max = pcall(GetInventoryItemDurability, slotID)
    current, max = ok and Readable(current), ok and Readable(max)
    if type(current) ~= "number" or type(max) ~= "number" or max <= 0 then return nil end
    return current / max * 100
end

function C.AverageLevel()
    if not GetAverageItemLevel then return nil end
    local ok, overall, equipped = pcall(GetAverageItemLevel)
    local value = ok and Readable(equipped or overall)
    if type(value) ~= "number" or value <= 0 then return nil end
    return value
end

---------------------------------------------------------------------------
-- Casillas de equipo
---------------------------------------------------------------------------
local function SlotArt(slot, d)
    local list = {}
    local border = Child(slot, "BorderFrame")
    if border then for _, region in ipairs(Textures(border)) do list[#list + 1] = region end end
    for _, region in pairs({ slot.GetNormalTexture and slot:GetNormalTexture(), Child(slot, nil, "NormalTexture"),
                             Child(slot, "IconBorder"), Child(slot, "IconOverlay") }) do
        list[#list + 1] = region
    end
    -- El marco de piedra de la casilla (textura aparte: "<casilla>Frame").
    for _, region in pairs({ Child(slot, "Frame", "Frame"), Child(slot, "SlotFrame"), Child(slot, "SlotBackground") }) do
        if Win.IsTexture(region) then list[#list + 1] = region end
    end
    -- El resto de texturas sueltas (el aro de la munición, fondos de ranura)
    -- salvo el icono, la marca de ignorar y el resaltado.
    local keep = {}
    for _, region in pairs({ d.icon, Child(slot, "ignoreTexture"), slot.GetHighlightTexture and slot:GetHighlightTexture(),
                             slot.GetPushedTexture and slot:GetPushedTexture() }) do keep[region] = true end
    for _, region in ipairs(Textures(slot)) do
        if not keep[region] then list[#list + 1] = region end
    end
    return list
end

local function Parts(slot)
    local d = slotData[slot]
    if d then return d end
    d = {}
    d.border = Win.Texture(slot, "BACKGROUND", -7)
    d.bg = Win.Texture(slot, "BACKGROUND", -6)
    d.mask = slot:CreateMaskTexture()
    d.level = slot:CreateFontString(nil, "OVERLAY")
    d.dura = slot:CreateFontString(nil, "OVERLAY")
    d.icon = Child(slot, "icon", "IconTexture") or Child(slot, "Icon")
    if d.icon and d.icon.GetNumPoints then
        d.iconPoints = {}
        for i = 1, d.icon:GetNumPoints() or 0 do d.iconPoints[i] = { d.icon:GetPoint(i) } end
    end
    d.cooldown = Child(slot, "Cooldown", "Cooldown")
    slotData[slot] = d
    return d
end

local function Inset(region, owner, n)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", owner, "TOPLEFT", n, -n)
    region:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", -n, n)
end

function C.SkinSlot(slot, name, on)
    local o = Opts()
    local d = Parts(slot)
    d.name = name
    if not on then
        if not d.active then return end
        d.active = false
        d.border:Hide(); d.bg:Hide(); d.level:Hide(); d.dura:Hide()
        C.HideSlotText(d)
        if d.icon then
            if d.dim then
                d.dim = false
                d.icon:SetDesaturated(false)
                d.icon:SetAlpha(1)
            end
            if d.cropped then
                d.icon:RemoveMaskTexture(d.mask)
                pcall(d.icon.SetTexCoord, d.icon, 0, 1, 0, 1)
                d.cropped = false
                d.crop = nil
            end
            d.icon:ClearAllPoints()
            if d.iconPoints and #d.iconPoints > 0 then
                for _, point in ipairs(d.iconPoints) do d.icon:SetPoint(unpack(point)) end
            else
                d.icon:SetAllPoints(slot)
            end
        end
        for _, region in ipairs(SlotArt(slot, d)) do Hold(region, false) end
        return
    end
    local px = M.PixelSize()
    local b = (o.slotBorder or 2) * px
    local file = M.ButtonShape(o.slotShape, o.slotFlipH, o.slotFlipV)
    Inset(d.border, slot, 0)
    d.border:SetTexture(file)
    d.border:SetShown(b > 0)
    Inset(d.bg, slot, b)
    d.bg:SetTexture(file)
    d.bg:SetVertexColor(0.08, 0.08, 0.09, 0.9)
    d.bg:Show()
    Inset(d.mask, slot, b)
    d.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if d.icon then
        if not d.cropped then
            if d.icon.GetNumMaskTextures then
                local okCount, count = pcall(d.icon.GetNumMaskTextures, d.icon)
                if okCount and type(count) == "number" and not IsSecret(count) then
                    for i = count, 1, -1 do
                        local okMask, mask = pcall(d.icon.GetMaskTexture, d.icon, i)
                        if okMask and mask then pcall(d.icon.RemoveMaskTexture, d.icon, mask) end
                    end
                end
            end
            pcall(d.icon.SetTexCoord, d.icon, 0.08, 0.92, 0.08, 0.92)
            d.icon:AddMaskTexture(d.mask)
            d.cropped = true
            d.crop = 0.08
        end
        Inset(d.icon, slot, b)
    end
    if d.cooldown then
        Inset(d.cooldown, slot, b)
        if d.cooldown.SetSwipeTexture then pcall(d.cooldown.SetSwipeTexture, d.cooldown, file) end
    end
    for _, region in ipairs(SlotArt(slot, d)) do Hold(region, true) end

    d.level:SetFont(M.FONT, o.itemLevelSize or 12, "OUTLINE")
    d.level:ClearAllPoints()
    local pos = o.itemLevelPos or "BOTTOM"
    local x = pos:find("LEFT") and 2 or (pos:find("RIGHT") and -1 or 0)
    local y = pos:find("TOP") and -2 or 2
    d.level:SetPoint(pos, slot, pos, x, y)
    d.dura:SetFont(M.FONT, 10, "OUTLINE")
    d.dura:ClearAllPoints()
    d.dura:SetPoint(pos:find("TOP") and "BOTTOM" or "TOP", slot, pos:find("TOP") and "BOTTOM" or "TOP", 0, pos:find("TOP") and 2 or -2)
    d.active = true
    C.UpdateSlot(slot)
end

function C.UpdateSlot(slot)
    local d = slotData[slot]
    if not (d and d.active) then return end
    local o = Opts()
    local id = SlotID(slot, d.name)
    local quality = id and GetInventoryItemQuality and GetInventoryItemQuality("player", id)
    local hasItem = id and GetInventoryItemLink("player", id) ~= nil

    local r, g, b
    if hasItem and o.qualityBorder then r, g, b = Win.QualityColor(quality) end
    if r and (quality or 0) >= 2 then d.border:SetVertexColor(r, g, b, 1)
    elseif hasItem then d.border:SetVertexColor(0.3, 0.3, 0.32, 1)
    else d.border:SetVertexColor(0.16, 0.16, 0.18, 1) end

    -- Casilla vacía: el dibujo de Blizzard trae su marco antiguo pintado
    -- dentro; se recorta más y queda como una silueta tenue.
    if d.icon and d.cropped then
        -- Con la máscara puesta no se puede cambiar el recorte: fuera y dentro.
        local crop = hasItem and 0.08 or 0.2
        if d.crop ~= crop then
            d.icon:RemoveMaskTexture(d.mask)
            pcall(d.icon.SetTexCoord, d.icon, crop, 1 - crop, crop, 1 - crop)
            d.icon:AddMaskTexture(d.mask)
            d.crop = crop
        end
        if hasItem then
            if d.dim then
                d.dim = false
                d.icon:SetDesaturated(false)
                d.icon:SetAlpha(1)
            end
        else
            d.dim = true
            d.icon:SetDesaturated(true)
            d.icon:SetAlpha(0.3)
        end
    end

    local level = id and o.itemLevel and not NO_LEVEL[d.name] and C.ItemLevel(id)
    if level then
        d.level:SetText(level)
        local qr, qg, qb = Win.QualityColor(quality)
        if o.itemLevelQuality and qr then d.level:SetTextColor(qr, qg, qb) else d.level:SetTextColor(1, 1, 1) end
        d.level:Show()
    else
        d.level:Hide()
    end

    local pct = id and o.durability and hasItem and C.Durability(id)
    if pct and pct <= (o.durabilityWarn or 50) then
        d.dura:SetText(string.format("%d%%", math.floor(pct + 0.5)))
        if pct <= 20 then d.dura:SetTextColor(1, 0.25, 0.25) else d.dura:SetTextColor(1, 0.8, 0.25) end
        d.dura:Show()
    else
        d.dura:Hide()
    end
    C.SlotText(slot, d, id, hasItem, quality)
end

---------------------------------------------------------------------------
-- Encantamiento y gemas junto a cada pieza (hacia el personaje)
---------------------------------------------------------------------------
-- Columna izquierda: a su derecha; columna derecha: a su izquierda. Las
-- armas (fila de abajo) no llevan: no hay sitio entre ellas.
C.TEXT_SIDE = {
    CharacterHeadSlot = "R", CharacterNeckSlot = "R", CharacterShoulderSlot = "R", CharacterBackSlot = "R",
    CharacterChestSlot = "R", CharacterShirtSlot = "R", CharacterTabardSlot = "R", CharacterWristSlot = "R",
    CharacterHandsSlot = "L", CharacterWaistSlot = "L", CharacterLegsSlot = "L", CharacterFeetSlot = "L",
    CharacterFinger0Slot = "L", CharacterFinger1Slot = "L", CharacterTrinket0Slot = "L", CharacterTrinket1Slot = "L",
}
local TEXT_WIDTH, GEM_SIZE, MAX_GEMS = 104, 14, 4
local enchantCache = {}

local function EnchantPattern()
    local fmt = ENCHANTED_TOOLTIP_LINE
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%s", "(.+)")
    return "^" .. p .. "$"
end

-- El nombre del encantamiento sale de la descripción del objeto (solo si el
-- enlace dice que lleva uno). Se guarda por enlace.
function C.EnchantName(slotID, link)
    local enchantID = link:match("item:%-?%d+:(%d*)")
    if not enchantID or enchantID == "" or enchantID == "0" then return nil end
    if enchantCache[link] ~= nil then return enchantCache[link] or nil end
    local found = false
    local pattern = EnchantPattern()
    if pattern and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slotID)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                local text = Readable(line.leftText)
                local name = type(text) == "string" and text:match(pattern)
                if name then found = name; break end
            end
        end
    end
    enchantCache[link] = found
    return found or nil
end

-- Huecos de gema: los que trae la pieza (sus estadísticas) y las gemas ya
-- puestas (van en el enlace: item:id:encantamiento:gema1:gema2:gema3:gema4).
-- Cada hueco: { icon = gema } o { color = "RED"... } si está vacío.
local SOCKET_RANK = { META = 1, RED = 2, YELLOW = 3, BLUE = 4, PRISMATIC = 5 }
local SOCKET_FILE = {
    META = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Meta", RED = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Red",
    YELLOW = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Yellow", BLUE = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue",
    PRISMATIC = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic",
}
C.SOCKET_FILE = SOCKET_FILE

local function GemIcon(gemID)
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, gemID)
        if ok and icon then return icon end
    end
    if GetItemIcon then
        local ok, icon = pcall(GetItemIcon, gemID)
        if ok and icon then return icon end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function C.Sockets(link)
    local colors = {}
    local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
    if getStats then
        local ok, stats = pcall(getStats, link)
        if ok and type(stats) == "table" then
            for key, count in pairs(stats) do
                local color = type(key) == "string" and key:match("^EMPTY_SOCKET_(%u+)$")
                count = Readable(count)
                if color and type(count) == "number" then
                    for _ = 1, count do colors[#colors + 1] = color end
                end
            end
        end
    end
    table.sort(colors, function(a, b)
        local ra, rb = SOCKET_RANK[a] or 9, SOCKET_RANK[b] or 9
        if ra ~= rb then return ra < rb end
        return a < b
    end)
    local gems = { link:match("item:%-?%d+:%-?%d*:(%-?%d*):(%-?%d*):(%-?%d*):(%-?%d*)") }
    local count = #colors
    for i = 1, MAX_GEMS do
        local id = tonumber(gems[i] or "")
        if id and id > 0 and i > count then count = i end
    end
    local list = {}
    for i = 1, math.min(count, MAX_GEMS) do
        local id = tonumber(gems[i] or "")
        if id and id > 0 then list[i] = { icon = GemIcon(id) } else list[i] = { color = colors[i] or "PRISMATIC" } end
    end
    return list
end

function C.HideSlotText(d)
    if d.ench then d.ench:Hide() end
    if d.gems then for _, gem in ipairs(d.gems) do gem:Hide() end end
end

function C.SlotText(slot, d, id, hasItem)
    local side = C.TEXT_SIDE[d.name]
    local on = side and Opts().slotText and d.active
    local link = on and hasItem and GetInventoryItemLink("player", id)
    if type(link) ~= "string" or IsSecret(link) then
        C.HideSlotText(d)
        return
    end
    if not d.ench then
        d.ench = slot:CreateFontString(nil, "OVERLAY")
        d.ench:SetWordWrap(false)
        d.ench:SetShadowOffset(1, -1)
        d.ench:SetShadowColor(0, 0, 0, 1)
        d.gems = {}
        for i = 1, MAX_GEMS do d.gems[i] = Win.Texture(slot, "OVERLAY", 2) end
    end
    local enchant = C.EnchantName(id, link)
    local sockets = C.Sockets(link)
    local left = side == "R"
    local point, rel, x = left and "LEFT" or "RIGHT", left and "RIGHT" or "LEFT", left and 6 or -6
    -- Con las dos cosas: el encantamiento arriba y las gemas debajo; con una,
    -- centrada a la altura de la casilla.
    local both = enchant and #sockets > 0
    d.ench:SetFont(M.FONT, 10, "")
    d.ench:SetWidth(TEXT_WIDTH)
    d.ench:SetJustifyH(left and "LEFT" or "RIGHT")
    d.ench:ClearAllPoints()
    d.ench:SetPoint(point, slot, rel, x, both and 8 or 0)
    if enchant then
        d.ench:SetText(enchant)
        d.ench:SetTextColor(0.3, 0.95, 0.4)
        d.ench:Show()
    else
        d.ench:Hide()
    end
    for i, gem in ipairs(d.gems) do
        local socket = sockets[i]
        if socket then
            gem:SetSize(GEM_SIZE, GEM_SIZE)
            gem:ClearAllPoints()
            local step = (i - 1) * (GEM_SIZE + 3)
            gem:SetPoint(point, slot, rel, x + (left and step or -step), both and -7 or 0)
            if socket.icon then
                gem:SetTexture(socket.icon)
                gem:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                gem:SetVertexColor(1, 1, 1, 1)
            else
                gem:SetTexture(SOCKET_FILE[socket.color] or SOCKET_FILE.PRISMATIC)
                gem:SetTexCoord(0, 1, 0, 1)
                gem:SetVertexColor(1, 1, 1, 0.9)
            end
            gem:Show()
        else
            gem:Hide()
        end
    end
end

function C.UpdateSlots()
    for slot in pairs(slotData) do C.UpdateSlot(slot) end
    C.UpdateAverage()
end

---------------------------------------------------------------------------
-- Personaje: fondo, nivel medio y paneles
---------------------------------------------------------------------------
local extra = {}
C.extra = extra

function C.ModelBackground(on)
    local scene = _G.CharacterModelScene or _G.CharacterModelFrame
    if not scene then return end
    if not extra.model then
        local parent = scene.GetParent and scene:GetParent() or _G.PaperDollFrame
        local host = Win.Own(CreateFrame("Frame", nil, parent))
        host:SetAllPoints(scene)
        host:SetFrameLevel(math.max(0, (scene:GetFrameLevel() or 1) - 1))
        extra.model = host
        extra.modelTex = Win.Texture(host, "BACKGROUND", 0)
        extra.modelTex:SetAllPoints(host)
        extra.modelShade = Win.Texture(host, "BACKGROUND", 1)
        extra.modelShade:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT")
        extra.modelShade:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT")
    end
    -- El fondo propio de la escena (si lo tiene) se quita.
    Strip(scene, on)
    local show = on and Opts().modelBackground
    extra.model:SetShown(show)
    if not show then return end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.5, 0.5, 0.55 end
    local tex = extra.modelTex
    tex:SetColorTexture(1, 1, 1, 1)
    if tex.SetGradient and CreateColor then
        -- Abajo, el color de la clase apagado; arriba, casi negro.
        pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r * 0.30, g * 0.30, b * 0.30, 0.85), CreateColor(0.03, 0.03, 0.04, 0.5))
    else
        tex:SetColorTexture(r * 0.2, g * 0.2, b * 0.2, 0.7)
    end
    -- Una línea de "suelo" donde pisa el personaje.
    extra.modelShade:SetHeight(M.PixelSize())
    extra.modelShade:SetColorTexture(r, g, b, 0.35)
    -- El emblema de tu clase, grande y muy tenue, detrás del personaje.
    if not extra.crest then
        extra.crest = Win.Texture(extra.model, "BACKGROUND", 2)
        extra.crest:SetPoint("CENTER", extra.model, "CENTER", 0, 10)
    end
    local _, class = UnitClass("player")
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    if coords and Opts().watermark then
        extra.crest:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        extra.crest:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        local h = Readable(extra.model:GetHeight())
        local size = (type(h) == "number" and h > 0) and math.min(220, h * 0.6) or 180
        extra.crest:SetSize(size, size)
        extra.crest:SetDesaturated(true)
        extra.crest:SetVertexColor(r, g, b, 0.10)
        extra.crest:Show()
    else
        extra.crest:Hide()
    end
end

function C.UpdateAverage()
    local text = extra.average
    if not text then return end
    local o = Opts()
    local r, g, b = Win.Accent()
    local hex = r and string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255) or "|cffffffff"
    local parts = {}
    local value = o.averageLevel and extra.on and C.AverageLevel()
    if value then parts[#parts + 1] = "Nivel de objeto " .. hex .. string.format("%.1f", value) .. "|r" end
    local dura = o.durability and extra.on and C.TotalDurability()
    if dura then
        local color = dura <= 20 and "|cffff4040" or (dura <= (o.durabilityWarn or 50) and "|cffffcc40" or "|cffffffff")
        parts[#parts + 1] = "Durabilidad " .. color .. string.format("%d%%", math.floor(dura + 0.5)) .. "|r"
    end
    if #parts > 0 then
        text:SetText(table.concat(parts, "  |cff666666·|r  "))
        text:Show()
    else
        text:Hide()
    end
end

-- Durabilidad de todo el equipo junto (nil si nada tiene).
function C.TotalDurability()
    if not GetInventoryItemDurability then return nil end
    local current, max = 0, 0
    for slotID = 1, 19 do
        local ok, c, m = pcall(GetInventoryItemDurability, slotID)
        c, m = ok and Readable(c), ok and Readable(m)
        if type(c) == "number" and type(m) == "number" and m > 0 then current, max = current + c, max + m end
    end
    if max <= 0 then return nil end
    return current / max * 100
end

function C.Average(on)
    local scene = _G.CharacterModelScene or _G.CharacterModelFrame
    if not scene then return end
    if not extra.average then
        local host = Win.Own(CreateFrame("Frame", nil, scene))
        host:SetAllPoints(scene)
        host:SetFrameLevel((scene:GetFrameLevel() or 1) + 5)
        extra.average = host:CreateFontString(nil, "OVERLAY")
        extra.average:SetJustifyH("CENTER")
    end
    -- Debajo de las armas (arriba quedaba sobre los botones de zoom y giro
    -- del modelo). Sin armas a la vista, arriba como antes.
    local text = extra.average
    local first = _G.CharacterMainHandSlot
    local last = _G.CharacterRangedSlot or _G.CharacterSecondaryHandSlot
    text:ClearAllPoints()
    if first and last then
        text:SetPoint("TOPLEFT", first, "BOTTOMLEFT", -60, -5)
        text:SetPoint("TOPRIGHT", last, "BOTTOMRIGHT", 60, -5)
    else
        text:SetPoint("TOP", text:GetParent(), "TOP", 0, -6)
    end
    extra.average:SetFont(M.FONT, 12, "OUTLINE")
    extra.average:SetTextColor(0.9, 0.9, 0.9)
    extra.on = on
    C.UpdateAverage()
end

local function Panes(frame, on)
    local statBoxes = {}
    for _, key in ipairs(STAT_BOXES) do if _G[key] then statBoxes[_G[key]] = true end end
    for _, key in ipairs({ "LeftPaneHost", "RightPaneHost" }) do
        local pane = Child(frame, key)
        if pane then
            Strip(pane, on)
            for _, child in ipairs(Win.Children(pane)) do
                -- Ni las listas de estadísticas, ni la flecha, ni las casillas
                -- (si cuelgan directamente del panel): esas tienen su trato.
                if not statBoxes[child] and not slotData[child] and child ~= Child(frame, "RightPaneToggleButton") then
                    Strip(child, on)
                end
            end
            local stone = Child(pane, "StoneBg")
            if stone then Hold(stone, on) end
        end
    end
    local doll = _G.PaperDollFrame
    if doll then
        Strip(doll, on)
        Strip(Child(doll, "TopBackgroundStripHost"), on)
    end
    Strip(_G.PaperDollItemsFrame, on)
    for box in pairs(statBoxes) do Strip(box, on) end
    if Opts().otherTabs then
        for _, key in ipairs(OTHER_TABS) do
            local tab = _G[key]
            if tab then
                Strip(tab, on)
                local inset = Child(tab, "Inset")
                if inset then Strip(inset, on); Strip(Child(inset, "NineSlice"), on) end
            end
        end
    end
end

-- La flecha que pliega el panel de estadísticas: nuestro cuadro con una
-- flechita que apunta hacia donde se moverá el panel.
function C.Toggle(frame, on)
    local toggle = Child(frame, "RightPaneToggleButton")
    if not toggle then return end
    local d = Win.ModernButton(toggle, M.ICONS.chevron, 18, on and Opts().modernToggle)
    if not d then return end
    local collapsed = frame.IsRightPaneCollapsed and frame:IsRightPaneCollapsed()
    if IsSecret(collapsed) then collapsed = false end
    -- La flecha mira a la derecha: plegado = abrir (derecha), abierto = cerrar (izquierda).
    if d.icon.SetRotation then d.icon:SetRotation(collapsed and 0 or math.pi) end
    if not extra.toggleHooked then
        extra.toggleHooked = true
        toggle:HookScript("OnClick", function() C_Timer.After(0, function() C.Toggle(frame, Win.PackOn(C.pack)) end) end)
    end
end

---------------------------------------------------------------------------
-- Estadísticas
---------------------------------------------------------------------------
local rowData = setmetatable({}, { __mode = "k" })
local boxHooked = setmetatable({}, { __mode = "k" })

local function StatsOn()
    return Win.active and Win.PackOn(C.pack) and Opts().stats
end

function C.SkinStat(frame, elementData)
    if type(frame) ~= "table" or not frame.CreateTexture then return end
    local on = StatsOn()
    local d = rowData[frame]
    if not d then
        d = { left = Win.Texture(frame, "ARTWORK", 1), right = Win.Texture(frame, "ARTWORK", 1), divider = Win.Texture(frame, "ARTWORK", 1) }
        rowData[frame] = d
    end
    local header = type(elementData) == "table" and elementData.isHeader
    local bg = Child(frame, "Background")
    if bg then Hold(bg, on) else Strip(frame, on) end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 1, 0.82, 0 end
    local px = M.PixelSize()
    local title = Child(frame, "Title")
    if header and title then
        d.left:ClearAllPoints()
        d.left:SetPoint("LEFT", frame, "LEFT", 8, 0)
        d.left:SetPoint("RIGHT", title, "LEFT", -6, 0)
        d.left:SetHeight(px)
        d.right:ClearAllPoints()
        d.right:SetPoint("LEFT", title, "RIGHT", 6, 0)
        d.right:SetPoint("RIGHT", frame, "RIGHT", -8, 0)
        d.right:SetHeight(px)
        d.left:SetColorTexture(r, g, b, 0.7)
        d.right:SetColorTexture(r, g, b, 0.7)
        if on then
            title:SetFont(M.FONT, 12, "")
            title:SetTextColor(r, g, b)
        end
    end
    d.left:SetShown(on and header and title ~= nil or false)
    d.right:SetShown(on and header and title ~= nil or false)
    d.divider:ClearAllPoints()
    d.divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 0)
    d.divider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 0)
    d.divider:SetHeight(px)
    d.divider:SetColorTexture(1, 1, 1, 0.06)
    d.divider:SetShown(on and not header or false)
    if on and not header then
        local label, value = Child(frame, "Label"), Child(frame, "Value")
        if label and label.SetFont then label:SetFont(M.FONT, 11, ""); label:SetTextColor(0.72, 0.72, 0.76) end
        if value and value.SetFont then value:SetFont(M.FONT, 11, ""); value:SetTextColor(1, 1, 1) end
    end
end

-- El aviso de un marco nuevo llega como (marco, datos) o (dueño, marco, datos).
local function StatCallback(a, b, c)
    if type(a) == "table" and a.CreateTexture and not (type(b) == "table" and b.CreateTexture) then
        C.SkinStat(a, b)
    else
        C.SkinStat(b, c)
    end
end

function C.HookStats()
    for _, key in ipairs(STAT_BOXES) do
        local box = _G[key]
        local scroll = box and (Child(box, "ScrollBox") or box)
        if scroll and not boxHooked[scroll] then
            boxHooked[scroll] = true
            if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
                pcall(ScrollUtil.AddInitializedFrameCallback, scroll, StatCallback, nil, false)
            end
        end
        if scroll and scroll.ForEachFrame then
            pcall(scroll.ForEachFrame, scroll, function(frame, data) C.SkinStat(frame, data) end)
        end
    end
end

---------------------------------------------------------------------------
-- Reputación, habilidades y demás listas: barras planas y cabeceras
---------------------------------------------------------------------------
-- En estas dos, una fila sin barra es una cabecera ("Horda", "Profesiones").
C.LIST_TABS = { "ReputationFrame", "SkillFrame" }
local headerData = setmetatable({}, { __mode = "k" })
local listBoxes = setmetatable({}, { __mode = "k" })   -- ScrollBox -> true si sus filas sin barra son cabeceras
local tabHooked = setmetatable({}, { __mode = "k" })

local function ListsOn()
    return Win.active and Win.PackOn(C.pack) and Opts().bars and true or false
end

local function IsStatusBar(f)
    return type(f) == "table" and f.GetObjectType and f:GetObjectType() == "StatusBar"
end

local function BarsIn(frame, list, depth)
    list = list or {}
    for _, child in ipairs(Win.Children(frame)) do
        if not Win.IsOwn(child) then
            if IsStatusBar(child) then list[#list + 1] = child
            elseif depth > 1 then BarsIn(child, list, depth - 1) end
        end
    end
    return list
end

-- Cabecera: fuera el arte estirado (no los iconos pequeños como el "−"),
-- un fondo oscuro teñido del acento y una marca a la izquierda.
function C.SkinHeader(frame, on)
    local d = headerData[frame]
    if not d then
        if not on then return end
        d = { fill = Win.Texture(frame, "BACKGROUND", -8), mark = Win.Texture(frame, "ARTWORK", 7) }
        headerData[frame] = d
    end
    for _, region in ipairs(Textures(frame)) do
        local layer = region.GetDrawLayer and region:GetDrawLayer()
        if layer ~= "HIGHLIGHT" then
            local width = Readable(region:GetWidth())
            local points = Readable(region.GetNumPoints and region:GetNumPoints()) or 0
            if points >= 2 or (type(width) == "number" and width > 40) then Hold(region, on) end
        end
    end
    local r, g, b = Win.Accent()
    if not r then r, g, b = 0.8, 0.8, 0.8 end
    d.fill:ClearAllPoints()
    d.fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -1)
    d.fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 1)
    d.fill:SetColorTexture(r * 0.16, g * 0.16, b * 0.16, 0.9)
    d.mark:ClearAllPoints()
    d.mark:SetPoint("TOPLEFT", d.fill, "TOPLEFT")
    d.mark:SetPoint("BOTTOMLEFT", d.fill, "BOTTOMLEFT")
    d.mark:SetWidth(2 * M.PixelSize())
    d.mark:SetColorTexture(r, g, b, 1)
    d.fill:SetShown(on)
    d.mark:SetShown(on)
end

function C.SkinRow(frame, data, headers)
    if type(frame) ~= "table" or not frame.GetChildren then return end
    local on = ListsOn()
    local bars = BarsIn(frame, {}, 3)
    if IsStatusBar(frame) then bars[#bars + 1] = frame end
    for _, bar in ipairs(bars) do Win.SkinBar(bar, on) end
    local header = type(data) == "table" and (data.isHeader or data.header) and true or false
    if #bars == 0 and (header or headers) then C.SkinHeader(frame, on) end
end

local function HookList(box, headers)
    if listBoxes[box] == nil then
        listBoxes[box] = headers
        if ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
            pcall(ScrollUtil.AddInitializedFrameCallback, box, function(a, b, c)
                if type(a) == "table" and a.GetChildren and not (type(b) == "table" and b.GetChildren) then
                    C.SkinRow(a, b, listBoxes[box])
                else
                    C.SkinRow(b, c, listBoxes[box])
                end
            end, nil, false)
        end
    end
    if box.ForEachFrame then
        pcall(box.ForEachFrame, box, function(frame, data) C.SkinRow(frame, data, listBoxes[box]) end)
    end
end

-- Repasa las listas de las otras pestañas (al abrir la ventana y al cambiar
-- de pestaña: algunas se crean la primera vez que se ven).
function C.SkinLists(cf)
    cf = cf or _G.CharacterFrame
    if not cf then return end
    local on = ListsOn()
    local stat = {}
    for _, key in ipairs(STAT_BOXES) do
        local box = _G[key]
        if box then stat[box] = true; stat[Child(box, "ScrollBox") or box] = true end
    end
    local known = {}
    for _, key in ipairs(C.LIST_TABS) do
        local tab = _G[key]
        if tab then known[tab] = true end
    end
    local function Scan(root, headers)
        Win.Walk(root, function(f)
            if stat[f] or slotData[f] or Win.IsScrollBar(f) then return false end
            if f.ForEachFrame then
                HookList(f, headers)
                return false
            end
            if IsStatusBar(f) then
                Win.SkinBar(f, on)
                return false
            end
        end)
    end
    for tab in pairs(known) do
        Scan(tab, true)
        if not tabHooked[tab] then
            tabHooked[tab] = true
            tab:HookScript("OnShow", function()
                C_Timer.After(0, function()
                    C.SkinLists()
                    Win.SkinScrollBars(tab, Win.active and Win.PackOn(C.pack) and Win.db.scrollBars)
                end)
            end)
        end
    end
    -- El resto de la ventana: solo las barras (nada de cabeceras).
    Win.Walk(cf, function(f)
        if known[f] or stat[f] or slotData[f] or Win.IsScrollBar(f) then return false end
        if f.ForEachFrame then
            HookList(f, false)
            return false
        end
        if IsStatusBar(f) then
            Win.SkinBar(f, on)
            return false
        end
    end)
end

---------------------------------------------------------------------------
-- Pestañas con icono: las de la derecha (Personaje, Reputación, Habilidades…)
-- y las de arriba del panel (Estadísticas, Títulos, Equipo…)
---------------------------------------------------------------------------
-- Fuera el marco de legado (alfa 0); se queda el icono de Blizzard y debajo
-- va un cuadro oscuro con línea de 1 px: del acento en la elegida, las demás
-- con el icono atenuado. Las laterales no tienen nombre conocido: se
-- reconocen por su forma (botón cuadrado con icono, por fuera del borde
-- derecho de la ventana).
local iconTabData = setmetatable({}, { __mode = "k" })
local ICON_KEYS = { "Icon", "icon", "IconTexture" }

local function AtlasOf(t)
    local atlas = t.GetAtlas and Readable(t:GetAtlas())
    return type(atlas) == "string" and atlas ~= "" and atlas or nil
end

local function IconOf(tab, loose)
    for _, key in ipairs(ICON_KEYS) do
        local icon = Child(tab, key, key)
        if Win.IsTexture(icon) then return icon end
    end
    -- Sin clave: una textura sin atlas que sea un icono (ruta Icons o un
    -- número de archivo); a veces es la textura normal del botón.
    local list = Textures(tab)
    local normal = tab.GetNormalTexture and tab:GetNormalTexture()
    if normal then table.insert(list, 1, normal) end
    for _, t in ipairs(list) do
        local atlas = t.GetAtlas and Readable(t:GetAtlas())
        local file = t.GetTexture and Readable(t:GetTexture())
        if not (type(atlas) == "string" and atlas ~= "") and file then
            if type(file) == "number" or (type(file) == "string" and file:lower():find("icons", 1, true)) then return t end
        end
    end
    if loose then
        for _, t in ipairs(Textures(tab)) do
            if not AtlasOf(t) then return t end
        end
    end
    return nil
end

local function Num(v)
    v = Readable(v)
    return type(v) == "number" and v or nil
end

-- Las laterales: botones cuadrados con icono por fuera del borde derecho.
function C.FindSideTabs(frame)
    local list = {}
    for i = 1, 12 do
        local tab = _G["CharacterFrameModeTab" .. i]
        if not tab then break end
        list[#list + 1] = tab
    end
    if #list > 0 then return list end
    local right = frame.GetRight and Num(frame:GetRight())
    if not right then return list end
    Win.Walk(frame, function(child)
        local kind = child.GetObjectType and child:GetObjectType()
        if kind ~= "Button" and kind ~= "CheckButton" and kind ~= "Frame" then return end
        if slotData[child] then return false end
        local w, h = Num(child:GetWidth()), Num(child:GetHeight())
        local left = child.GetLeft and Num(child:GetLeft())
        if w and h and left and w >= 22 and w <= 72 and math.abs(w - h) <= 10 and left >= right - 12 and IconOf(child) then
            list[#list + 1] = child
            return false
        end
    end, 4)
    table.sort(list, function(a, b) return (Num(a:GetTop()) or 0) > (Num(b:GetTop()) or 0) end)
    return list
end

function C.SidebarTabs()
    local list = {}
    for i = 1, 8 do
        local tab = _G["PaperDollSidebarTab" .. i]
        if tab then list[#list + 1] = tab end
    end
    return list
end

-- ¿Está elegida? Cada tipo lo dice a su manera; solo se lee.
local function IsSelected(tab, index, sidebar)
    if sidebar then
        local info = type(_G.PAPERDOLL_SIDEBARS) == "table" and _G.PAPERDOLL_SIDEBARS[index]
        local pane = type(info) == "table" and Readable(info.frame)
        pane = type(pane) == "string" and _G[pane]
        if pane and pane.IsShown then return Readable(pane:IsShown()) == true end
        local hider = Child(tab, "Hider")
        if hider then return Readable(hider:IsShown()) == false end
    end
    local selected = Child(tab, "SelectedTexture") or Child(tab, "Selected")
    if selected and selected.IsShown then return Readable(selected:IsShown()) == true end
    -- Pestañas laterales de Forever: su textura con atlas "...-selected" se
    -- muestra solo en la elegida (la capa de resaltado no cuenta).
    local sawSelected = false
    for _, t in ipairs(Textures(tab)) do
        local atlas = AtlasOf(t)
        if atlas and atlas:lower():find("selected", 1, true) then
            sawSelected = true
            local layer = t.GetDrawLayer and t:GetDrawLayer()
            if layer ~= "HIGHLIGHT" and Readable(t:IsShown()) == true then return true end
        end
    end
    if sawSelected then return false end
    if tab.GetChecked then
        local checked = Readable(tab:GetChecked())
        if type(checked) == "boolean" then return checked end
    end
    return false
end

function C.PaintIconTab(tab)
    local d = iconTabData[tab]
    if not d then return end
    local selected = d.on and IsSelected(tab, d.index, d.sidebar)
    local r, g, b = Win.Accent()
    if not r then r, g, b = 1, 0.82, 0 end
    for _, edge in ipairs(d.edges) do
        if selected then edge:SetColorTexture(r, g, b, 1) else edge:SetColorTexture(0, 0, 0, 1) end
    end
    if d.on then Hold(d.icon, not selected, 0.55) else Hold(d.icon, false) end
end

function C.SkinIconTab(tab, on, index, sidebar)
    local icon = IconOf(tab, not sidebar)
    if not icon then return end
    local d = iconTabData[tab]
    if not d then
        d = { bg = Win.Texture(tab, "BACKGROUND", -8), hover = Win.Texture(tab, "HIGHLIGHT", 7), edges = {} }
        for i = 1, 4 do d.edges[i] = Win.Texture(tab, "OVERLAY", 7) end
        iconTabData[tab] = d
        local function Later() C_Timer.After(0, C.PaintIconTabs) end
        if tab.HasScript and tab:HasScript("OnClick") then
            tab:HookScript("OnClick", Later)
        elseif tab.HasScript and tab:HasScript("OnMouseUp") then
            tab:HookScript("OnMouseUp", Later)
        end
        -- La capa de resaltado solo funciona sola en botones.
        local kind = tab.GetObjectType and tab:GetObjectType()
        if kind ~= "Button" and kind ~= "CheckButton" and tab.HasScript and tab:HasScript("OnEnter") then
            d.hover:SetDrawLayer("OVERLAY", 6)
            d.hover:SetAlpha(0)
            tab:HookScript("OnEnter", function() d.hover:SetAlpha(1) end)
            tab:HookScript("OnLeave", function() d.hover:SetAlpha(0) end)
        end
    end
    d.icon, d.index, d.sidebar, d.on = icon, index, sidebar, on
    -- Todo el arte de Blizzard fuera menos el icono.
    local art = { Child(tab, "Hider"), Child(tab, "TabBg"), Child(tab, "Background"), Child(tab, "SelectedTexture"),
                  Child(tab, "TabGlow"), Child(tab, "Highlight") }
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetCheckedTexture", "GetDisabledTexture" }) do
        if tab[getter] then art[#art + 1] = tab[getter](tab) end
    end
    for _, t in ipairs(Textures(tab)) do art[#art + 1] = t end
    for _, t in pairs(art) do
        if t ~= icon then Hold(t, on) end
    end
    local px = M.PixelSize()
    d.bg:ClearAllPoints()
    d.bg:SetPoint("TOPLEFT", icon, "TOPLEFT", -px, px)
    d.bg:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", px, -px)
    d.bg:SetColorTexture(0.06, 0.06, 0.07, 0.95)
    d.hover:ClearAllPoints()
    d.hover:SetAllPoints(icon)
    d.hover:SetColorTexture(1, 1, 1, 0.12)
    local e = d.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", d.bg); e[1]:SetPoint("TOPRIGHT", d.bg); e[1]:SetHeight(px)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", d.bg); e[2]:SetPoint("BOTTOMRIGHT", d.bg); e[2]:SetHeight(px)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", d.bg); e[3]:SetPoint("BOTTOMLEFT", d.bg); e[3]:SetWidth(px)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", d.bg); e[4]:SetPoint("BOTTOMRIGHT", d.bg); e[4]:SetWidth(px)
    d.bg:SetShown(on)
    d.hover:SetShown(on)
    for _, edge in ipairs(e) do edge:SetShown(on) end
    C.PaintIconTab(tab)
end

function C.PaintIconTabs()
    for tab in pairs(iconTabData) do C.PaintIconTab(tab) end
end

function C.IconTabs(frame, on)
    on = on and Opts().iconTabs ~= false
    for i, tab in ipairs(C.SidebarTabs()) do C.SkinIconTab(tab, on, i, true) end
    local side = C.FindSideTabs(frame)
    for i, tab in ipairs(side) do C.SkinIconTab(tab, on, i, false) end
    -- Recién abierta puede no tener posiciones todavía: un repaso más.
    if on and #side == 0 and not extra.sideRetry then
        extra.sideRetry = true
        C_Timer.After(0.1, function()
            extra.sideRetry = nil
            if frame:IsShown() then
                for i, tab in ipairs(C.FindSideTabs(frame)) do C.SkinIconTab(tab, Opts().iconTabs ~= false and Win.PackOn(C.pack), i, false) end
            end
        end)
    end
    -- Ya pintadas que esta vez no se encontraron (opción apagada): se devuelven.
    if not on then for tab, d in pairs(iconTabData) do if d.on then C.SkinIconTab(tab, false, d.index, d.sidebar) end end end
    if not extra.iconTabsHooked then
        extra.iconTabsHooked = true
        for _, fn in ipairs({ "PaperDollFrame_UpdateSidebarTabs", "CharacterFrame_ShowSubFrame", "ToggleCharacter" }) do
            if type(_G[fn]) == "function" then hooksecurefunc(fn, function() C_Timer.After(0, C.PaintIconTabs) end) end
        end
    end
end

---------------------------------------------------------------------------
-- El paquete
---------------------------------------------------------------------------
function C.Apply(frame, on)
    for _, name in ipairs(C.SLOTS) do
        local slot = _G[name]
        if slot then C.SkinSlot(slot, name, on) end
    end
    Panes(frame, on)
    C.ModelBackground(on)
    C.Average(on)
    C.Toggle(frame, on)
    C.HookStats()
    if Win.Pet then Win.Pet.Apply(frame, on) end
    C.SkinLists(frame)
    C.IconTabs(frame, on)
    local title = _G.CharacterFrameTitleText or Child(Child(frame, "TitleContainer"), "TitleText")
    if title and title.SetFont and on then title:SetFont(M.FONT, 13, "") end
end

C.pack = {
    key = "character", title = "Personaje",
    frame = function() return _G.CharacterFrame end,
    apply = C.Apply,
    diagnose = function()
        local found = 0
        for _, name in ipairs(C.SLOTS) do if _G[name] then found = found + 1 end end
        print(string.format("  casillas: %d de %d · modelo: %s · estadísticas: %s · nivel medio: %s", found, #C.SLOTS,
            (_G.CharacterModelScene or _G.CharacterModelFrame) and "sí" or "no",
            _G.CharacterStatsPaneScrollBox and "sí" or "no", tostring(C.AverageLevel())))
        local P = Win.Pet
        if P then
            local side, index = P.FindPetSidebar()
            local happy = P.FindHappiness(_G.CharacterFrame)
            print(string.format("  mascota: pestaña de abajo %s · botón de arriba %s · icono de felicidad %s",
                P.FindPetTab(_G.CharacterFrame) and "sí" or "no", side and ("nº " .. index) or "no",
                happy and (happy:GetName() or "sin nombre") or "no"))
        end
        local lists = {}
        for _, key in ipairs(C.LIST_TABS) do lists[#lists + 1] = key .. (_G[key] and " sí" or " no") end
        print("  listas: " .. table.concat(lists, " · "))
        local side = {}
        local sideTabs = C.FindSideTabs(_G.CharacterFrame)
        for i, tab in ipairs(sideTabs) do
            side[#side + 1] = ("%d%s%s"):format(i, IconOf(tab, true) and "" or " sin icono", IsSelected(tab, i, false) and " elegida" or "")
        end
        print(string.format("  pestañas con icono: arriba %d · laterales %d (%s)", #C.SidebarTabs(), #side, table.concat(side, ", ")))
        local first = sideTabs[1]
        if first then
            local parts = {}
            for _, t in ipairs(Textures(first)) do
                parts[#parts + 1] = string.format("%s/%s/%s", tostring(AtlasOf(t) or (t.GetTexture and Readable(t:GetTexture()))),
                    tostring(t.GetDrawLayer and t:GetDrawLayer()), Readable(t:IsShown()) and "visible" or "oculta")
            end
            print("  lateral 1: " .. table.concat(parts, " · "))
        end
    end,
}
Win.Register(C.pack)

-- Blizzard repinta cada casilla al cambiar de equipo: detrás, lo nuestro.
if type(_G.PaperDollItemSlotButton_Update) == "function" then
    hooksecurefunc("PaperDollItemSlotButton_Update", function(slot)
        if slotData[slot] then C.UpdateSlot(slot) end
    end)
end

local pending = false
local function Queue()
    if pending or not Win.active then return end
    -- Cerrada no hace falta: al abrirse se repasa entera.
    if not (_G.CharacterFrame and _G.CharacterFrame:IsShown()) then return end
    pending = true
    C_Timer.After(0.1, function()
        pending = false
        C.UpdateSlots()
    end)
end
for _, event in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY", "GET_ITEM_INFO_RECEIVED", "PLAYER_AVG_ITEM_LEVEL_UPDATE",
                        "SOCKET_INFO_UPDATE" }) do
    pcall(ns.On, event, Queue)
end
