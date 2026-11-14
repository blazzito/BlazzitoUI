-- Basura junto al botín: con las bolsas llenas, al abrir un botín aparece
-- pegado a su derecha un panel con tu basura (objetos grises), lo que te
-- daría un vendedor por cada montón y una X para destruirlo. Destruyes uno y
-- ya puedes recoger lo que querías.
--
-- Todo es nuestro y cuelga de UIParent: solo se ancla al LootFrame de
-- Blizzard, sin tocarlo. Destruir un objeto (DeleteCursorItem) necesita un
-- clic real: se hace dentro del propio clic de la X, comprobando antes que la
-- casilla sigue teniendo ese mismo objeto gris.
local ns = BlazzitoUI
if not (ns and ns.Bags) then return end

local B, M, W = ns.Bags, ns.Media, ns.Widgets
local T = W.T
local Readable = M.Readable

local MAX_ROWS = 8
local ROW_H, ICON, PAD = 34, 26, 8
local MIN_W, MAX_W = 210, 340
local GRAY = { 0.62, 0.62, 0.62 }

local panel, rows = nil, {}
local lootOpen, bagsFull = false, false
B.lootJunkRows = rows

local function Info(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    return ok and type(info) == "table" and info or nil
end

local function Price(info)
    local link = Readable(info.hyperlink)
    if type(link) ~= "string" then return 0 end
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not getInfo then return 0 end
    local ok, price = pcall(function() return select(11, getInfo(link)) end)
    price = ok and Readable(price) or 0
    local count = Readable(info.stackCount) or 1
    return (type(price) == "number" and price or 0) * count
end

local function Name(info)
    local link = Readable(info.hyperlink)
    if type(link) == "string" then
        local name = link:match("%[(.-)%]")
        if name then return name end
        local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
        local ok, n = pcall(function() return (getInfo(link)) end)
        if ok and type(n) == "string" then return n end
        return link
    end
    return "?"
end

local function Money(copper)
    if not copper or copper <= 0 then return "—" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    return copper .. " c"
end

-- Tu basura, la más barata primero (la que menos duele tirar).
function B.LootJunkList()
    local list = {}
    if not (C_Container and C_Container.GetContainerNumSlots) then return list end
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = Readable(C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local info = Info(bag, slot)
            if B.IsJunk(info) and not info.isLocked then
                list[#list + 1] = {
                    bag = bag, slot = slot, link = Readable(info.hyperlink), itemID = Readable(info.itemID),
                    icon = Readable(info.iconFileID), count = Readable(info.stackCount) or 1,
                    name = Name(info), price = Price(info),
                }
            end
        end
    end
    table.sort(list, function(a, b)
        if a.price ~= b.price then return a.price < b.price end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return list
end

-- Destruye la basura de esa casilla si sigue siendo la misma. Solo desde un clic.
function B.DeleteJunk(item)
    if not item or (GetCursorInfo and GetCursorInfo()) then return false end
    local info = Info(item.bag, item.slot)
    if not (B.IsJunk(info) and not info.isLocked and Readable(info.hyperlink) == item.link) then return false end
    C_Container.PickupContainerItem(item.bag, item.slot)
    local kind, id = GetCursorInfo()
    if kind == "item" and (item.itemID == nil or id == item.itemID) then
        DeleteCursorItem()
        return true
    end
    if ClearCursor then ClearCursor() end
    return false
end

---------------------------------------------------------------------------
-- Panel
---------------------------------------------------------------------------
local function RowTooltip(row)
    local item = row.item
    if not (item and GameTooltip) then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    if GameTooltip.SetBagItem then GameTooltip:SetBagItem(item.bag, item.slot) end
    GameTooltip:AddLine(ns.Translate("Pulsa la X para destruirlo y hacer sitio."), T.dim[1], T.dim[2], T.dim[3], true)
    GameTooltip:Show()
end

local function Row(i)
    local row = rows[i]
    if row then return row end
    row = CreateFrame("Button", nil, panel)
    row:SetHeight(ROW_H)
    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(T.rowHover[1], T.rowHover[2], T.rowHover[3], 1)
    row.hover:Hide()
    row.line = W.Line(row, T.rowLine)
    row.line:SetPoint("TOPLEFT"); row.line:SetPoint("TOPRIGHT")
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(ICON, ICON)
    row.icon:SetPoint("LEFT", PAD, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.count = M.Font(row, 10, "RIGHT")
    row.count:SetFont(M.FONT, 10, "OUTLINE")
    row.count:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, 0)
    row.name = W.Text(row, 12, GRAY, false, "medium")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.price = W.Text(row, 11, T.textSoft, false)
    row.price:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)

    local del = CreateFrame("Button", nil, row)
    del:SetSize(22, 22)
    del:SetPoint("RIGHT", -PAD, 0)
    W.Panel(del, T.radius, T.field, T.btnBorder, 0)
    del.x = del:CreateTexture(nil, "ARTWORK")
    del.x:SetSize(11, 11)
    del.x:SetPoint("CENTER")
    del.x:SetTexture(M.ICONS.close)
    del.x:SetVertexColor(T.muted[1], T.muted[2], T.muted[3])
    del:SetScript("OnEnter", function(self)
        self.panel.border:SetColor({ 0.85, 0.3, 0.3, 1 })
        self.x:SetVertexColor(1, 0.4, 0.4)
        RowTooltip(row)
    end)
    del:SetScript("OnLeave", function(self)
        self.panel.border:SetColor(T.btnBorder)
        self.x:SetVertexColor(T.muted[1], T.muted[2], T.muted[3])
        if GameTooltip then GameTooltip:Hide() end
    end)
    del:SetScript("OnClick", function()
        if B.DeleteJunk(row.item) then
            if GameTooltip then GameTooltip:Hide() end
            row.item = nil
            row:Hide()
        end
    end)
    row.delete = del

    row:SetScript("OnEnter", function(self) self.hover:Show(); RowTooltip(self) end)
    row:SetScript("OnLeave", function(self) self.hover:Hide(); if GameTooltip then GameTooltip:Hide() end end)
    rows[i] = row
    return row
end

local function Build()
    if panel then return panel end
    panel = CreateFrame("Frame", "BlazzitoUILootJunk", UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    W.Panel(panel, T.radius, T.bg, T.line)
    panel.title = W.Text(panel, 13, T.text, false, "head")
    panel.title:SetPoint("TOPLEFT", PAD + 2, -9)
    panel.title:SetText(W.Upper(ns.Translate("Basura")))
    panel.total = W.Text(panel, 11, T.muted, false, "medium")
    panel.total:SetPoint("TOPRIGHT", -PAD - 2, -10)
    panel.accent = W.Line(panel, W.COLORS.accent)
    panel.accent:SetPoint("TOPLEFT", 1, -1); panel.accent:SetPoint("TOPRIGHT", -1, -1)
    panel.more = W.Text(panel, 11, T.dim, false)
    panel.more:SetPoint("BOTTOMLEFT", PAD + 2, 8)
    panel:Hide()
    B.lootJunkPanel = panel
    return panel
end

local function Anchor()
    panel:ClearAllPoints()
    local loot = _G.LootFrame
    if loot and loot.IsShown and loot:IsShown() then
        panel:SetPoint("TOPLEFT", loot, "TOPRIGHT", 6, 0)
    else
        panel:SetPoint("LEFT", UIParent, "CENTER", 120, 80)
    end
end

function B.HideLootJunk()
    if panel then panel:Hide() end
end

function B.UpdateLootJunk()
    local db = B.db
    if not (lootOpen and B.active and db and db.lootJunk) then return B.HideLootJunk() end
    if not bagsFull then
        local free = B.FreeSlots and B.FreeSlots()
        if free == 0 then bagsFull = true end
    end
    if db.lootJunkFullOnly and not bagsFull then return B.HideLootJunk() end
    local list = B.LootJunkList()
    if #list == 0 then return B.HideLootJunk() end

    Build()
    local total, widest = 0, 0
    for _, item in ipairs(list) do total = total + item.price end
    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local item, row = list[i], Row(i)
        row.item = item
        row.icon:SetTexture(item.icon or 134400)
        row.count:SetText(item.count > 1 and item.count or "")
        row.name:SetText(item.name)
        row.price:SetText(Money(item.price))
        widest = math.max(widest, row.name:GetStringWidth() or 0, row.price:GetStringWidth() or 0)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -32 - (i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -32 - (i - 1) * ROW_H)
        row:Show()
    end
    for i = shown + 1, #rows do rows[i].item = nil; rows[i]:Hide() end
    panel.total:SetText(Money(total))
    local extra = #list - shown
    panel.more:SetText(extra > 0 and ns.LF("y %d más", extra) or "")
    local width = PAD + ICON + 8 + math.ceil(widest) + 8 + 22 + PAD + 2
    local header = math.ceil(panel.title:GetStringWidth() + panel.total:GetStringWidth() + 3 * PAD + 12)
    width = math.min(MAX_W, math.max(MIN_W, width, header))
    panel:SetSize(width, 32 + shown * ROW_H + (extra > 0 and 24 or 6))
    Anchor()
    panel:Show()
end

---------------------------------------------------------------------------
-- «Recoger todo»: botón propio bajo la ventana de botín (LootSlot no es
-- protegido). Con mando no hace falta: Blizzard ya pone el suyo.
---------------------------------------------------------------------------
local lootAll

function B.LootAll()
    local count = Readable(GetNumLootItems and GetNumLootItems()) or 0
    for slot = count, 1, -1 do LootSlot(slot) end
end

function B.UpdateLootAll()
    local db = B.db
    local loot = _G.LootFrame
    local want = lootOpen and B.active and db and db.lootAll and loot and loot.IsShown and loot:IsShown()
        and (Readable(GetNumLootItems and GetNumLootItems()) or 0) > 0
    if not want then
        if lootAll then lootAll:Hide() end
        return
    end
    if not lootAll then
        lootAll = W.Button(UIParent, 160, "Recoger todo", function() B.LootAll() end, true, 26)
        lootAll:SetFrameStrata("HIGH")
        B.lootAllButton = lootAll
    end
    if W.RefreshAccent then W.RefreshAccent() end
    lootAll:Refresh()
    local width = Readable(loot:GetWidth())
    lootAll:SetWidth(type(width) == "number" and width > 60 and width or 160)
    lootAll:ClearAllPoints()
    lootAll:SetPoint("TOP", loot, "BOTTOM", 0, -4)
    lootAll:Show()
end

local function Queue()
    C_Timer.After(0, function()
        B.UpdateLootJunk()
        B.UpdateLootAll()
    end)
end

ns.On("LOOT_OPENED", function()
    lootOpen, bagsFull = true, false
    Queue()
end)
ns.On("LOOT_SLOT_CLEARED", function() if lootOpen then Queue() end end)
ns.On("LOOT_CLOSED", function()
    lootOpen, bagsFull = false, false
    B.HideLootJunk()
    if lootAll then lootAll:Hide() end
end)
-- «El inventario está lleno» al intentar recoger: aparece aunque quede algún hueco especial.
local FULL_ERRORS = { ERR_INV_FULL = true, ERR_BAG_FULL = true }
local lastError

local function IsFullError(errorType, message)
    -- Por el nombre interno del error (no depende del idioma)...
    errorType = Readable(errorType)
    if type(errorType) == "number" and GetGameMessageInfo then
        local ok, name = pcall(GetGameMessageInfo, errorType)
        name = ok and Readable(name)
        if type(name) == "string" and FULL_ERRORS[name] then return true end
    end
    -- ...o por el texto.
    for _, text in ipairs({ Readable(message), errorType }) do
        if type(text) == "string" and (text == ERR_INV_FULL or text == ERR_BAG_FULL) then return true end
    end
    return false
end

ns.On("UI_ERROR_MESSAGE", function(_, errorType, message)
    if not lootOpen then return end
    lastError = tostring(Readable(message) or Readable(errorType) or "?")
    if IsFullError(errorType, message) then
        bagsFull = true
        Queue()
    end
end)
ns.On("BAG_UPDATE_DELAYED", function() if lootOpen then Queue() end end)

-- /bui basura: qué ve el panel (por qué sale o no sale).
function B.DiagnoseLootJunk()
    local db = B.db or {}
    local list = B.LootJunkList()
    local total = 0
    for _, item in ipairs(list) do total = total + item.price end
    ns.Print(string.format("basura junto al botín: opción %s, solo con bolsas llenas %s, módulo %s.",
        db.lootJunk and "sí" or "no", db.lootJunkFullOnly and "sí" or "no",
        B.active and "activo" or (B.padResting and "en reposo (mando)" or "apagado")))
    ns.Print(string.format("huecos libres: %s · basura: %d %s (%s) · botín abierto: %s · bolsas llenas: %s.",
        tostring(B.FreeSlots and B.FreeSlots()), #list, #list == 1 and "montón" or "montones", Money(total),
        lootOpen and "sí" or "no", bagsFull and "sí" or "no"))
    for i = 1, math.min(#list, 5) do
        ns.Print(string.format("  %s x%d — %s", list[i].name, list[i].count, Money(list[i].price)))
    end
    if lastError then ns.Print("último error al recoger: " .. lastError) end
    -- Qué devuelve el juego de cada objeto: calidades y grises descartados.
    local byQuality, grays, items = {}, {}, 0
    for bag = 0, (NUM_BAG_SLOTS or 4) do
        local slots = Readable(C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
        for slot = 1, slots do
            local info = Info(bag, slot)
            if info then
                items = items + 1
                local q = info.quality
                local key = M.IsSecret(q) and "secreta" or tostring(q)
                byQuality[key] = (byQuality[key] or 0) + 1
                if q == 0 and #grays < 4 then
                    grays[#grays + 1] = string.format("  gris: %s · sin valor=%s · bloqueado=%s · precio=%s",
                        Name(info), tostring(info.hasNoValue), tostring(info.isLocked), Money(Price(info)))
                end
            end
        end
    end
    local parts = {}
    for key, n in pairs(byQuality) do parts[#parts + 1] = key .. "=" .. n end
    table.sort(parts)
    ns.Print(string.format("objetos en las bolsas: %d · por calidad (0 gris, 1 blanco, 2 verde…): %s",
        items, #parts > 0 and table.concat(parts, ", ") or "ninguno"))
    for _, line in ipairs(grays) do ns.Print(line) end
end
ns.RegisterCommand("basura", function() B.DiagnoseLootJunk() end, "diagnóstico del panel de basura junto al botín")
