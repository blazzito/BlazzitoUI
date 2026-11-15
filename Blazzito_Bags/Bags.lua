-- Blazzito_Bags: las bolsas de WoW (unificadas o separadas, como elijas en
-- el juego) con el estilo de BlazzitoUI. No se sustituye nada: abrir,
-- ordenar, buscar, arrastrar y usar objetos sigue siendo de Blizzard.
--
-- Qué añade sobre cada casilla:
--  * Icono recortado, fondo propio y borde del color de la calidad (dorado
--    para objetos de misión).
--  * Nivel de objeto en el equipo.
--  * Flecha verde (mejora) o roja (peor) comparando el nivel con lo que
--    llevas puesto en esa ranura.
--  * Brillo en los objetos nuevos hasta que les pasas el ratón por encima.
--
-- Reglas anti-taint (los botones de las bolsas usan objetos de forma
-- segura): nunca se escribe un campo en un botón ni en una ventana de
-- Blizzard; solo texturas propias, alfa y ganchos de OnEnter / OnShow.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret, Readable = M.IsSecret, M.Readable
local MEDIA = "Interface\\AddOns\\Blazzito_Bags\\Media\\"

local B = ns.NewModule("Bags", "Bolsas", {
    skin = true, background = 85, slotBackground = 60, border = 1,
    qualityBorder = true, hidePortrait = true,
    itemLevel = true, itemLevelSize = 11, itemLevelPos = "BOTTOMLEFT", itemLevelQuality = true,
    upgrade = true, newGlow = true,
    junkMark = true, autoSellJunk = true, quickActions = true, bank = true,
    lootJunk = true, lootJunkFullOnly = true, lootAll = true,
    slotShape = "square", slotFlipH = false, slotFlipV = false, slotColor = { 0.05, 0.05, 0.06 },
    unusableRed = true, freeSlots = true, modernChrome = true,
    newItems = {},   -- por personaje: casilla -> enlace del objeto nuevo
})
ns.Bags = B
-- Con el estilo de mando se aparta (BlazzitoUI/Core/Pad.lua): la cruceta recorre las bolsas.
B.padStandDown = true

local skins = setmetatable({}, { __mode = "k" })   -- botón o ventana -> nuestras piezas
local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local enterHooked = setmetatable({}, { __mode = "k" })
local showHooked = setmetatable({}, { __mode = "k" })
B.skins = skins

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

local function Child(owner, key, suffix)
    local region = owner[key]
    if type(region) ~= "table" then region = nil end
    if not region and suffix and owner.GetName then
        local name = owner:GetName()
        if name then region = _G[name .. suffix] end
    end
    return type(region) == "table" and region or nil
end

local function Textures(frame)
    local list = {}
    if type(frame) ~= "table" or not frame.GetRegions then return list end
    for _, region in ipairs({ frame:GetRegions() }) do
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then list[#list + 1] = region end
    end
    return list
end

local function Unmask(texture)
    if not (texture and texture.GetNumMaskTextures) then return end
    local ok, count = pcall(texture.GetNumMaskTextures, texture)
    if not ok or IsSecret(count) or type(count) ~= "number" then return end
    for i = count, 1, -1 do
        local okMask, mask = pcall(texture.GetMaskTexture, texture, i)
        if okMask and mask then pcall(texture.RemoveMaskTexture, texture, mask) end
    end
end

---------------------------------------------------------------------------
-- Ventanas de bolsas de Blizzard
---------------------------------------------------------------------------
function B.Frames()
    local list = {}
    if ContainerFrameCombinedBags then list[#list + 1] = ContainerFrameCombinedBags end
    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then list[#list + 1] = frame end
    end
    -- Banco: la ventana (para su marco) y el panel con las casillas de la
    -- pestaña elegida. Las bolsas del banco ya son ContainerFrames.
    if B.db and B.db.bank then
        if BankFrame then list[#list + 1] = BankFrame end
        if BankPanel and BankPanel ~= BankFrame then list[#list + 1] = BankPanel end
    end
    return list
end

function B.Buttons(frame)
    local list = {}
    if frame.EnumerateValidItems then
        local ok = pcall(function()
            -- Las bolsas dan (índice, casilla); el banco, de un grupo de botones,
            -- da (casilla, true): vale el que sea una casilla.
            for a, b in frame:EnumerateValidItems() do
                local button = (type(a) == "table" and a.CreateTexture and a) or (type(b) == "table" and b.CreateTexture and b) or nil
                if button then list[#list + 1] = button end
            end
        end)
        if ok and #list > 0 then return list end
        list = {}
    end
    local items = frame.Items
    if type(items) == "table" then
        for _, button in ipairs(items) do
            if button:IsShown() then list[#list + 1] = button end
        end
        return list
    end
    local name = frame.GetName and frame:GetName()
    for i = 1, 40 do
        local button = name and _G[name .. "Item" .. i]
        if not button then break end
        if button:IsShown() then list[#list + 1] = button end
    end
    return list
end

local function SlotOf(button)
    -- Casillas del banco por pestañas: pestaña = bolsa, y su casilla.
    if button.GetBankTabID and button.GetContainerSlotID then
        local tab, slot = button:GetBankTabID(), button:GetContainerSlotID()
        if IsSecret(tab) or IsSecret(slot) then return nil end
        if tab ~= nil and slot ~= nil then return tab, slot end
    end
    local bag = button.GetBagID and button:GetBagID()
    if bag == nil and button.GetParent then
        local parent = button:GetParent()
        bag = parent and parent.GetID and parent:GetID()
    end
    local slot = button.GetID and button:GetID()
    if IsSecret(bag) or IsSecret(slot) then return nil end
    return bag, slot
end
B.SlotOf = SlotOf

---------------------------------------------------------------------------
-- Datos del objeto: calidad, nivel, si es mejora y si es nuevo
---------------------------------------------------------------------------
-- Ranuras donde va cada tipo de equipo (las de dos ranuras se comparan con
-- la peor de las dos: si una está vacía, cualquier objeto es mejora).
local EQUIP_SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 }, INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 }, INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 }, INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
B.EQUIP_SLOTS = EQUIP_SLOTS

local function ItemInfo(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if ok and type(info) == "table" then return info end
    return nil
end

local function LevelAt(location)
    if not (C_Item and C_Item.GetCurrentItemLevel and location) then return nil end
    local ok, level = pcall(C_Item.GetCurrentItemLevel, location)
    level = ok and Readable(level) or nil
    return type(level) == "number" and level > 0 and level or nil
end

local function BagLocation(bag, slot)
    return ItemLocation and ItemLocation.CreateFromBagAndSlot and ItemLocation:CreateFromBagAndSlot(bag, slot)
end

local function EquipLocOf(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local ok, _, _, _, equipLoc = pcall(C_Item.GetItemInfoInstant, link)
    if ok and type(equipLoc) == "string" and equipLoc ~= "" then return equipLoc end
    return nil
end

-- Nivel de lo que llevas en esa ranura (0 si está vacía).
local function EquippedLevel(slotID)
    if not GetInventoryItemLink("player", slotID) then return 0 end
    local location = ItemLocation and ItemLocation.CreateFromEquipmentSlot and ItemLocation:CreateFromEquipmentSlot(slotID)
    return LevelAt(location) or 0
end

local function CanUse(itemID)
    if C_PlayerInfo and C_PlayerInfo.CanUseItem then
        local ok, can = pcall(C_PlayerInfo.CanUseItem, itemID)
        if ok and can ~= nil and not IsSecret(can) then return can end
    end
    return true
end

-- Devuelve nivel, y +1 (mejora) / -1 (peor) / 0 (igual) / nil (no se compara).
function B.Compare(bag, slot, info)
    local link = info and info.hyperlink
    if type(link) ~= "string" or IsSecret(link) then return nil end
    local equipLoc = EquipLocOf(link)
    local slots = equipLoc and EQUIP_SLOTS[equipLoc]
    if not slots then return nil end
    local level = LevelAt(BagLocation(bag, slot))
    if not level then return nil end
    if not CanUse(info.itemID) then return level, nil end
    local worst
    for _, slotID in ipairs(slots) do
        local equipped = EquippedLevel(slotID)
        if not worst or equipped < worst then worst = equipped end
    end
    if level > worst then return level, 1 end
    if level < worst then return level, -1 end
    return level, 0
end

-- Equipo que tu personaje no puede llevar (tipo de armadura o arma, nivel...).
local EQUIP_OTHER = { INVTYPE_BODY = true, INVTYPE_TABARD = true }
function B.Unusable(info)
    local link = info and info.hyperlink
    if type(link) ~= "string" or IsSecret(link) then return false end
    local equipLoc = EquipLocOf(link)
    if not equipLoc or not (EQUIP_SLOTS[equipLoc] or EQUIP_OTHER[equipLoc]) then return false end
    return not CanUse(info.itemID)
end

-- Objetos nuevos: se toma la marca de Blizzard y se guarda la nuestra hasta
-- que pasas el ratón (Blizzard la borra al cerrar la bolsa).
local function CharKey()
    return UnitGUID and UnitGUID("player") or "player"
end

local function NewStore()
    local all = B.db.newItems
    local key = CharKey()
    all[key] = all[key] or {}
    return all[key]
end

local function SlotKey(bag, slot) return bag .. ":" .. slot end

function B.IsNew(bag, slot, info)
    local store = NewStore()
    local key = SlotKey(bag, slot)
    local link = info and info.hyperlink
    if type(link) ~= "string" or IsSecret(link) then
        store[key] = nil
        return false
    end
    local blizzardNew = C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot)
    if blizzardNew and not IsSecret(blizzardNew) then store[key] = link end
    if store[key] and store[key] ~= link then store[key] = nil end   -- otro objeto en esa casilla
    return store[key] ~= nil
end

function B.ClearNew(bag, slot)
    NewStore()[SlotKey(bag, slot)] = nil
    if C_NewItems and C_NewItems.RemoveNewItem then pcall(C_NewItems.RemoveNewItem, bag, slot) end
end

---------------------------------------------------------------------------
-- Basura: objetos grises que se pueden vender. Al abrir un vendedor se
-- venden solos, uno a uno (como si los pulsaras), y se avisa del total.
---------------------------------------------------------------------------
function B.IsJunk(info)
    if not info then return false end
    local quality = info.quality
    if IsSecret(quality) or quality ~= 0 then return false end
    if info.hasNoValue == true then return false end
    return true
end

local function SellPrice(info)
    local link = info.hyperlink
    if type(link) ~= "string" or IsSecret(link) then return 0 end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return 0 end
    local ok, price = pcall(function() return select(11, getInfo(link)) end)
    price = ok and Readable(price) or 0
    local count = Readable(info.stackCount) or 1
    return (type(price) == "number" and price or 0) * count
end

local BAG_FIRST, BAG_LAST = 0, (NUM_BAG_SLOTS or 4)

function B.JunkList()
    local list = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return list end
    for bag = BAG_FIRST, BAG_LAST do
        local slots = Readable(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local info = ItemInfo(bag, slot)
            if B.IsJunk(info) and not info.isLocked then
                list[#list + 1] = { bag = bag, slot = slot, price = SellPrice(info), link = info.hyperlink }
            end
        end
    end
    return list
end

local merchantOpen = false
local SELL_STEP = 0.2

function B.SellJunk()
    if not (C_Container and C_Container.UseContainerItem) then return end
    local list = B.JunkList()
    if #list == 0 then return end
    local sold, total = 0, 0
    local function Next(i)
        if not merchantOpen then return end
        local item = list[i]
        if not item then
            local money = M.Money(total)
            if sold == 1 then ns.Print("basura vendida: %d objeto por %s.", sold, money)
            else ns.Print("basura vendida: %d objetos por %s.", sold, money) end
            return
        end
        -- Se comprueba de nuevo: puede haberse movido entretanto.
        local info = ItemInfo(item.bag, item.slot)
        if B.IsJunk(info) and info.hyperlink == item.link then
            C_Container.UseContainerItem(item.bag, item.slot)
            sold, total = sold + 1, total + item.price
        end
        C_Timer.After(SELL_STEP, function() Next(i + 1) end)
    end
    Next(1)
end

ns.On("MERCHANT_SHOW", function()
    merchantOpen = true
    -- Vender basura no toca las bolsas: sigue también si el mando las aparta.
    if (B.active or B.padResting) and B.db and B.db.autoSellJunk then B.SellJunk() end
end)
ns.On("MERCHANT_CLOSED", function() merchantOpen = false end)

---------------------------------------------------------------------------
-- Casillas
---------------------------------------------------------------------------
local QUEST_COLOR = { 1, 0.82, 0.2 }

local function QualityColor(quality)
    if type(quality) ~= "number" or IsSecret(quality) then return nil end
    if C_Item and C_Item.GetItemQualityColor then
        local ok, r, g, b = pcall(C_Item.GetItemQualityColor, quality)
        if ok and r then return { r, g, b } end
    end
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    return color and { color.r, color.g, color.b } or nil
end

local function Parts(button)
    local d = skins[button]
    if d then return d end
    d = {}
    -- Debajo del todo, el halo del objeto nuevo (la forma, un poco más grande);
    -- encima, borde y fondo con la forma elegida.
    d.halo = button:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.halo:Hide()
    d.border = button:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.bg = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    d.mask = button:CreateMaskTexture()
    d.glow = button:CreateTexture(nil, "OVERLAY", nil, 6)
    d.glow:SetBlendMode("ADD")
    d.glow:Hide()
    -- Rojo encima del icono si es equipo que no puedes usar.
    d.red = button:CreateTexture(nil, "OVERLAY", nil, 5)
    d.red:SetBlendMode("MOD")
    d.red:Hide()
    d.cooldown = Child(button, "Cooldown", "Cooldown") or Child(button, "cooldown")
    d.level = button:CreateFontString(nil, "OVERLAY")
    d.arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
    d.arrow:SetSize(12, 12)
    d.arrow:Hide()
    d.junk = button:CreateTexture(nil, "OVERLAY", nil, 7)
    d.junk:SetTexture(MEDIA .. "junk")
    d.junk:SetSize(12, 12)
    d.junk:Hide()
    d.icon = Child(button, "icon", "IconTexture") or Child(button, "Icon")
    if d.icon then
        d.iconPoints = {}
        for i = 1, d.icon:GetNumPoints() or 0 do d.iconPoints[i] = { d.icon:GetPoint(i) } end
    end
    skins[button] = d
    return d
end

local function BlizzardArt(button)
    -- Sin huecos: si falta una, ipairs se pararía ahí y no se ocultaría el resto.
    local list = {}
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(),
        Child(button, "IconBorder"), Child(button, "NewItemTexture"), Child(button, "BattlepayItemTexture"),
        Child(button, "UpgradeIcon"), Child(button, "ItemSlotBackground"),
    }) do list[#list + 1] = region end
    return list
end

-- Al pasar el ratón por un objeto nuevo deja de brillar. También avisa a
-- las acciones rápidas de qué objeto está bajo el ratón.
local function HookEnter(button)
    if enterHooked[button] then return end
    enterHooked[button] = true
    button:HookScript("OnEnter", function(self)
        if B.OnItemEnter then B.OnItemEnter(self) end
        local d = skins[self]
        if not (d and d.isNew) then return end
        local bag, slot = SlotOf(self)
        if bag then B.ClearNew(bag, slot) end
        d.isNew = false
        d.glow:Hide()
    end)
    button:HookScript("OnLeave", function(self)
        if B.OnItemLeave then B.OnItemLeave(self) end
    end)
end
B.HookEnter = HookEnter

function B.SkinButton(button)
    local db = B.db
    local d = Parts(button)
    local px = M.PixelSize()
    local b = (db.border or 1) * px
    local file = M.ButtonShape(db.slotShape, db.slotFlipH, db.slotFlipV)
    d.file = file

    local function Inset(region, n)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", button, "TOPLEFT", n, -n)
        region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -n, n)
    end
    Inset(d.halo, -3)
    d.halo:SetTexture(file)
    Inset(d.border, 0)
    d.border:SetTexture(file)
    d.border:SetShown(b > 0)
    Inset(d.bg, b)
    d.bg:SetTexture(file)
    local sc = db.slotColor or { 0.05, 0.05, 0.06 }
    d.bg:SetVertexColor(sc[1], sc[2], sc[3], (db.slotBackground or 60) / 100)
    d.bg:Show()
    Inset(d.mask, b)
    d.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    for _, region in ipairs({ d.glow, d.red }) do
        Inset(region, b)
        region:SetTexture(file)
    end
    if d.icon then
        if not d.cropped then
            Unmask(d.icon)
            pcall(d.icon.SetTexCoord, d.icon, 0.08, 0.92, 0.08, 0.92)
            d.icon:AddMaskTexture(d.mask)
            d.cropped = true
        end
        Inset(d.icon, b)
    end
    if d.cooldown then
        Inset(d.cooldown, b)
        if d.cooldown.SetSwipeTexture then pcall(d.cooldown.SetSwipeTexture, d.cooldown, file) end
    end
    for _, region in ipairs(BlizzardArt(button)) do Hold(region, true) end

    d.level:SetFont(M.FONT, db.itemLevelSize or 11, "OUTLINE")
    d.level:ClearAllPoints()
    local pos = db.itemLevelPos or "BOTTOMLEFT"
    local x = pos:find("LEFT") and 2 or (pos:find("RIGHT") and -1 or 0)
    local y = pos:find("TOP") and -2 or 2
    d.level:SetPoint(pos, button, pos, x, y)
    d.arrow:ClearAllPoints()
    d.arrow:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    d.junk:ClearAllPoints()
    d.junk:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    HookEnter(button)
    d.active = true
    B.UpdateButton(button)
end

function B.UnskinButton(button)
    local d = skins[button]
    if not (d and d.active) then return end
    d.active = false
    d.border:Hide(); d.bg:Hide(); d.glow:Hide(); d.halo:Hide(); d.red:Hide(); d.level:Hide(); d.arrow:Hide(); d.junk:Hide()
    if d.icon then
        if d.cropped then
            d.icon:RemoveMaskTexture(d.mask)
            pcall(d.icon.SetTexCoord, d.icon, 0, 1, 0, 1)
            d.cropped = false
        end
        d.icon:ClearAllPoints()
        if d.iconPoints and #d.iconPoints > 0 then
            for _, point in ipairs(d.iconPoints) do d.icon:SetPoint(unpack(point)) end
        else
            d.icon:SetAllPoints(button)
        end
    end
    for _, region in ipairs(BlizzardArt(button)) do Hold(region, false) end
end

function B.UpdateButton(button)
    local d = skins[button]
    if not (d and d.active) then return end
    local db = B.db
    local bag, slot = SlotOf(button)
    local info = bag and ItemInfo(bag, slot)

    -- Borde: calidad (verde en adelante) o dorado si es de misión.
    local color
    if info and db.qualityBorder then
        local quest = C_Container and C_Container.GetContainerItemQuestInfo and C_Container.GetContainerItemQuestInfo(bag, slot)
        if type(quest) == "table" and (quest.isQuestItem or quest.questID) and not IsSecret(quest.isQuestItem) then
            color = QUEST_COLOR
        elseif type(info.quality) == "number" and not IsSecret(info.quality) and info.quality >= 2 then
            color = QualityColor(info.quality)
        end
    end
    if color then d.border:SetVertexColor(color[1], color[2], color[3], 1)
    else d.border:SetVertexColor(0, 0, 0, 1) end

    -- Equipo que no puedes usar: en rojo.
    d.red:SetShown(db.unusableRed and B.Unusable(info) or false)
    d.red:SetVertexColor(1, 0.25, 0.25, 1)

    -- Nivel y flecha.
    local level, verdict
    if info and (db.itemLevel or db.upgrade) then level, verdict = B.Compare(bag, slot, info) end
    if db.itemLevel and level then
        d.level:SetText(level)
        local qc = db.itemLevelQuality and QualityColor(info.quality)
        if qc then d.level:SetTextColor(qc[1], qc[2], qc[3]) else d.level:SetTextColor(1, 1, 1) end
        d.level:Show()
    else
        d.level:Hide()
    end
    if db.upgrade and verdict == 1 then
        d.arrow:SetTexture(MEDIA .. "arrow_up")
        d.arrow:SetVertexColor(0.25, 1, 0.35, 1)
        d.arrow:Show()
    elseif db.upgrade and verdict == -1 then
        d.arrow:SetTexture(MEDIA .. "arrow_down")
        d.arrow:SetVertexColor(1, 0.3, 0.3, 1)
        d.arrow:Show()
    else
        d.arrow:Hide()
    end

    -- Basura (calidad pobre que se puede vender).
    d.junk:SetShown(db.junkMark and B.IsJunk(info) or false)

    -- Nuevo.
    d.isNew = db.newGlow and info ~= nil and B.IsNew(bag, slot, info) or false
    if d.isNew then
        local a = color or { 1, 0.9, 0.5 }
        d.halo:SetVertexColor(a[1], a[2], a[3], 0.9)
        d.glow:SetVertexColor(a[1], a[2], a[3], 0.35)
        d.halo:Show()
        d.glow:Show()
    else
        d.halo:Hide()
        d.glow:Hide()
    end
end

---------------------------------------------------------------------------
-- Ventana: fondo propio en lugar del marco de Blizzard
---------------------------------------------------------------------------
local function PortraitArt(frame)
    local list = {}
    local container = Child(frame, "PortraitContainer") or Child(frame, "PortraitButton")
    if container then
        for _, region in ipairs(Textures(container)) do list[#list + 1] = region end
    end
    local portrait = Child(frame, "portrait", "Portrait")
    if portrait then list[#list + 1] = portrait end
    return list
end

-- Todo el arte de la ventana: el marco moderno (NineSlice, Bg...) y también
-- el clásico, que dibuja las casillas en el fondo de la propia ventana
-- (texturas sueltas de la ventana). El retrato va aparte (tiene su opción).
local function FrameArt(frame)
    local list, skip = {}, {}
    for _, region in ipairs(PortraitArt(frame)) do skip[region] = true end
    local d = skins[frame]
    if d then skip[d.border] = true; skip[d.fill] = true end
    for _, key in ipairs({ "NineSlice", "Bg", "Background", "TitleContainer" }) do
        local part = Child(frame, key)
        if part then
            if part.GetObjectType and part:GetObjectType() == "Texture" then list[#list + 1] = part
            else for _, region in ipairs(Textures(part)) do list[#list + 1] = region end end
        end
    end
    for _, region in ipairs(Textures(frame)) do
        if not skip[region] then list[#list + 1] = region end
    end
    return list
end

---------------------------------------------------------------------------
-- Cierre, buscador, ordenar y monedas con el estilo de BlazzitoUI
---------------------------------------------------------------------------
-- Un botón de Blizzard con su arte oculto y nuestro cuadro con icono encima.
local function ModernButton(button, icon, size, enabled)
    if type(button) ~= "table" or not button.CreateTexture then return end
    local on = B.db.skin and B.db.modernChrome
    if enabled ~= nil then on = on and enabled end
    local d = skins[button]
    if not d then
        d = {}
        d.bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.bg:SetPoint("CENTER")
        d.icon = button:CreateTexture(nil, "OVERLAY", nil, 7)
        d.icon:SetPoint("CENTER")
        d.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 7)
        d.hover:SetAllPoints(d.bg)
        d.hover:SetColorTexture(1, 1, 1, 0.08)
        skins[button] = d
    end
    local art = {}
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(), button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(), button.GetDisabledTexture and button:GetDisabledTexture(),
    }) do art[#art + 1] = region end
    for _, region in ipairs(Textures(button)) do
        if region ~= d.bg and region ~= d.icon and region ~= d.hover then art[#art + 1] = region end
    end
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
end
B.ModernButton = ModernButton

-- Campo de texto (buscador): sin los bordes clásicos, con fondo plano.
local function ModernField(box)
    if type(box) ~= "table" or not box.CreateTexture then return end
    local on = B.db.skin and B.db.modernChrome
    local d = skins[box]
    if not d then
        d = { border = box:CreateTexture(nil, "BACKGROUND", nil, -8), fill = box:CreateTexture(nil, "BACKGROUND", nil, -7) }
        skins[box] = d
    end
    local icon = Child(box, "searchIcon") or Child(box, "SearchIcon")
    for _, region in ipairs(Textures(box)) do
        if region ~= d.border and region ~= d.fill and region ~= icon then Hold(region, on) end
    end
    if icon then
        icon:SetVertexColor(0.6, 0.6, 0.65)
    end
    local px = M.PixelSize()
    d.border:ClearAllPoints()
    d.border:SetPoint("TOPLEFT", -6, 2)
    d.border:SetPoint("BOTTOMRIGHT", 2, -2)
    d.border:SetColorTexture(0.22, 0.22, 0.26, 1)
    d.fill:ClearAllPoints()
    d.fill:SetPoint("TOPLEFT", d.border, "TOPLEFT", px, -px)
    d.fill:SetPoint("BOTTOMRIGHT", d.border, "BOTTOMRIGHT", -px, px)
    d.fill:SetColorTexture(0.08, 0.08, 0.09, 1)
    d.border:SetShown(on)
    d.fill:SetShown(on)
    ModernButton(Child(box, "clearButton") or Child(box, "ClearButton"), M.ICONS.close, 14)
end

-- Monedas: sin el marco clásico, sobre una franja oscura.
local function ModernMoney(money)
    if type(money) ~= "table" or not money.CreateTexture then return end
    local on = B.db.skin and B.db.modernChrome
    local d = skins[money]
    if not d then
        d = { strip = money:CreateTexture(nil, "BACKGROUND", nil, -8) }
        skins[money] = d
    end
    for _, region in ipairs(Textures(money)) do
        if region ~= d.strip then Hold(region, on) end
    end
    local border = Child(money, "Border")
    if border then for _, region in ipairs(Textures(border)) do Hold(region, on) end end
    d.strip:ClearAllPoints()
    d.strip:SetPoint("TOPLEFT", -6, 3)
    d.strip:SetPoint("BOTTOMRIGHT", 4, -3)
    d.strip:SetColorTexture(0.03, 0.03, 0.04, 0.85)
    d.strip:SetShown(on)
end

function B.SkinChrome(frame)
    local name = frame.GetName and frame:GetName()
    ModernButton(Child(frame, "CloseButton", "CloseButton") or Child(frame, "ClosePanelButton"), M.ICONS.close, 20)
    ModernMoney(Child(frame, "MoneyFrame", "MoneyFrame"))
    ModernField(Child(frame, "SearchBox"))
    -- Sin retrato, el botón del retrato (abre el menú de la bolsa: orden,
    -- asignar a una categoría, unificar o separar) se queda invisible: se le
    -- pone nuestro cuadro con un icono de ajustes.
    ModernButton(Child(frame, "PortraitButton"), M.NAV_ICONS.sliders, 22, B.db.hidePortrait and true or false)
    -- El buscador y el botón de ordenar son globales que Blizzard coloca en
    -- la primera bolsa o en la mochila unificada.
    if name == "ContainerFrame1" or name == "ContainerFrameCombinedBags" then
        ModernField(_G.BagItemSearchBox)
        ModernButton(_G.BagItemAutoSortButton, M.ICONS.sort, 22)
        ModernMoney(_G.BackpackTokenFrame)
    end
end

---------------------------------------------------------------------------
-- Huecos libres en el botón de la mochila (como las flechas en el carcaj)
---------------------------------------------------------------------------
function B.FreeSlots()
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return nil end
    local total = 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local ok, free, family = pcall(C_Container.GetContainerNumFreeSlots, bag)
        free, family = ok and Readable(free), ok and Readable(family)
        -- Solo bolsas normales: carcaj, bolsas de hierbas... no cuentan.
        if type(free) == "number" and (family == 0 or family == nil) then total = total + free end
    end
    return total
end

function B.UpdateFreeSlots()
    local button = _G.MainMenuBarBackpackButton
    if type(button) ~= "table" or not button.CreateFontString then return end
    local d = skins.freeSlots
    if not d then
        d = { text = button:CreateFontString(nil, "OVERLAY") }
        d.text:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 3)
        skins.freeSlots = d
    end
    local on = B.db.freeSlots
    -- El contador propio de Blizzard (si lo tiene activado) se oculta para no
    -- pintar dos números en el mismo sitio.
    Hold(Child(button, "Count", "Count"), on)
    local free = on and B.FreeSlots()
    if free then
        d.text:SetFont(M.FONT, 13, "OUTLINE")
        d.text:SetText(free)
        if free == 0 then d.text:SetTextColor(1, 0.3, 0.3)
        elseif free <= 4 then d.text:SetTextColor(1, 0.8, 0.3)
        else d.text:SetTextColor(1, 1, 1) end
        d.text:Show()
    else
        d.text:Hide()
    end
end

function B.SkinFrame(frame)
    local db = B.db
    local d = skins[frame]
    if not d then
        d = { border = frame:CreateTexture(nil, "BACKGROUND", nil, -8), fill = frame:CreateTexture(nil, "BACKGROUND", nil, -7) }
        skins[frame] = d
    end
    local on = db.skin
    for _, region in ipairs(FrameArt(frame)) do Hold(region, on) end
    for _, region in ipairs(PortraitArt(frame)) do Hold(region, on and db.hidePortrait) end
    local px = M.PixelSize()
    d.border:ClearAllPoints()
    d.border:SetAllPoints(frame)
    d.border:SetColorTexture(0, 0, 0, 1)
    d.fill:ClearAllPoints()
    d.fill:SetPoint("TOPLEFT", px, -px)
    d.fill:SetPoint("BOTTOMRIGHT", -px, px)
    d.fill:SetColorTexture(0.06, 0.06, 0.07, (db.background or 85) / 100)
    d.border:SetShown(on)
    d.fill:SetShown(on)
    B.SkinChrome(frame)
    for _, button in ipairs(B.Buttons(frame)) do
        if on then B.SkinButton(button) else B.UnskinButton(button) end
    end
end

-- Repaso de las ventanas abiertas.
function B.Refresh()
    if not (B.active and B.db) then return end
    B.UpdateFreeSlots()
    for _, frame in ipairs(B.Frames()) do
        if not showHooked[frame] then
            showHooked[frame] = true
            -- Al abrirse, Blizzard reparte las casillas: se repasa un instante después.
            frame:HookScript("OnShow", function() C_Timer.After(0, B.Refresh) end)
        end
        if frame:IsShown() then B.SkinFrame(frame) end
    end
end

-- Mochila unificada o bolsas separadas: la opción de Blizzard (CVar).
function B.HasCombinedOption()
    return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar("combinedBags") ~= nil
end

function B.IsCombined()
    return B.HasCombinedOption() and C_CVar.GetCVar("combinedBags") == "1"
end

function B.SetCombined(on)
    if not B.HasCombinedOption() then return false end
    if InCombatLockdown() then
        ns.Print("no se puede cambiar el tipo de mochila en combate.")
        return false
    end
    C_CVar.SetCVar("combinedBags", on and "1" or "0")
    -- Si estaban abiertas, se reabren con el nuevo modo.
    if CloseAllBags and OpenAllBags then
        local wasOpen = false
        for _, frame in ipairs(B.Frames()) do if frame:IsShown() then wasOpen = true end end
        if wasOpen then CloseAllBags(); OpenAllBags() end
    end
    return true
end

function B.ApplyAll()
    B.Refresh()
end

function B:OnEnable()
    local pending = false
    local function Queue()
        if pending then return end
        pending = true
        C_Timer.After(0.05, function()
            pending = false
            B.Refresh()
        end)
    end
    for _, event in ipairs({ "BAG_UPDATE_DELAYED", "PLAYER_EQUIPMENT_CHANGED", "BAG_NEW_ITEMS_UPDATED",
                             "ITEM_LOCK_CHANGED", "PLAYER_LEVEL_UP", "QUEST_ACCEPTED", "QUEST_REMOVED",
                             "GET_ITEM_INFO_RECEIVED", "INVENTORY_SEARCH_UPDATE" }) do
        ns.On(event, function() if B.active then Queue() end end)
    end
    for _, event in ipairs({ "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED", "BANK_TAB_SETTINGS_UPDATED", "BANK_TABS_CHANGED" }) do
        pcall(ns.On, event, function() if B.active then Queue() end end)
    end
    -- Con el banco abierto, un repaso cada medio segundo (al cambiar de
    -- pestaña Blizzard reparte las casillas sin avisar).
    local clock = CreateFrame("Frame")
    local waited = 0
    clock:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + elapsed
        if waited < 0.5 then return end
        waited = 0
        if B.active and B.db.bank and BankFrame and BankFrame:IsShown() then B.Refresh() end
    end)
    B.Refresh()
end
