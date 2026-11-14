-- Acciones rápidas: con Alt pulsado, el objeto bajo el ratón se marca si un
-- hechizo tuyo sirve para él (desencantar, forzar cerradura, prospectar,
-- moler) y Alt+clic lo lanza sobre ese objeto.
--
-- Lanzar un hechizo sobre un objeto es una acción protegida: la hace un
-- botón seguro nuestro (SecureActionButtonTemplate, tipo "spell" con
-- target-bag / target-slot) que se coloca encima de la casilla solo mientras
-- Alt está pulsado y fuera de combate. Sin Alt no tapa nada: los clics
-- normales siguen yendo a la casilla de Blizzard.
local ns = BlazzitoUI
if not (ns and ns.Bags) then return end

local B, M = ns.Bags, ns.Media
local IsSecret = M.IsSecret

local DISENCHANT, PICK_LOCK, PROSPECT, MILL = 13262, 1804, 31252, 51005

local function Knows(spellID)
    if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
    return IsSpellKnown and IsSpellKnown(spellID) or false
end

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(spellID) end
    return GetSpellInfo and GetSpellInfo(spellID) or tostring(spellID)
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(spellID) end
    return GetSpellTexture and GetSpellTexture(spellID)
end

-- ¿Aparece este texto en el tooltip del objeto? ("Cerrado", "Se puede prospectar"...)
local function TooltipHas(bag, slot, text)
    if type(text) ~= "string" or not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return false end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    for _, line in ipairs(data.lines) do
        local left = line.leftText
        if type(left) == "string" and not IsSecret(left) and left == text then return true end
    end
    return false
end

-- El hechizo que sirve para ese objeto, o nil.
function B.QuickSpell(bag, slot)
    if not (C_Container and C_Container.GetContainerItemInfo) then return nil end
    local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not ok or type(info) ~= "table" or info.isLocked then return nil end
    local quality = info.quality
    if IsSecret(quality) then return nil end
    local classID
    if C_Item and C_Item.GetItemInfoInstant and info.itemID then
        classID = select(6, C_Item.GetItemInfoInstant(info.itemID))
    end
    if Knows(DISENCHANT) and (classID == 2 or classID == 4) and type(quality) == "number" and quality >= 2 and quality <= 4 then
        return DISENCHANT
    end
    if Knows(PICK_LOCK) and TooltipHas(bag, slot, LOCKED) then return PICK_LOCK end
    local count = info.stackCount or 1
    if not IsSecret(count) and count >= 5 then
        if Knows(PROSPECT) and TooltipHas(bag, slot, ITEM_PROSPECTABLE) then return PROSPECT end
        if Knows(MILL) and TooltipHas(bag, slot, ITEM_MILLABLE) then return MILL end
    end
    return nil
end

---------------------------------------------------------------------------
-- El botón seguro que se pone encima de la casilla
---------------------------------------------------------------------------
local cast = CreateFrame("Button", "BlazzitoUIBagQuickCast", UIParent, "SecureActionButtonTemplate")
cast:SetFrameStrata("DIALOG")
cast:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
cast:SetAttribute("type", "spell")
cast:Hide()
B.quickCast = cast
do
    local a = M.COLORS.accent
    cast.edges = {}
    for i = 1, 4 do
        local edge = cast:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(a[1], a[2], a[3], 1)
        cast.edges[i] = edge
    end
    cast.edges[1]:SetPoint("TOPLEFT"); cast.edges[1]:SetPoint("TOPRIGHT"); cast.edges[1]:SetHeight(2)
    cast.edges[2]:SetPoint("BOTTOMLEFT"); cast.edges[2]:SetPoint("BOTTOMRIGHT"); cast.edges[2]:SetHeight(2)
    cast.edges[3]:SetPoint("TOPLEFT"); cast.edges[3]:SetPoint("BOTTOMLEFT"); cast.edges[3]:SetWidth(2)
    cast.edges[4]:SetPoint("TOPRIGHT"); cast.edges[4]:SetPoint("BOTTOMRIGHT"); cast.edges[4]:SetWidth(2)
    cast.fill = cast:CreateTexture(nil, "ARTWORK")
    cast.fill:SetAllPoints()
    cast.fill:SetColorTexture(a[1], a[2], a[3], 0.15)
    cast.spellIcon = cast:CreateTexture(nil, "OVERLAY", nil, 1)
    cast.spellIcon:SetSize(16, 16)
    cast.spellIcon:SetPoint("CENTER")
    cast.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

local hovered   -- casilla de Blizzard bajo el ratón

local function HideCast()
    if InCombatLockdown() then return end
    cast:Hide()
    cast.button = nil
end

-- Coloca el botón sobre la casilla si Alt está pulsado y hay un hechizo.
function B.UpdateQuickCast()
    if InCombatLockdown() then return end
    local button = hovered
    if not (B.active and B.db and B.db.quickActions and button and IsAltKeyDown and IsAltKeyDown()) then
        HideCast()
        return
    end
    local bag, slot = B.SlotOf(button)
    local spell = bag and B.QuickSpell(bag, slot)
    if not spell then
        HideCast()
        return
    end
    cast:ClearAllPoints()
    cast:SetAllPoints(button)
    cast:SetAttribute("spell", spell)
    cast:SetAttribute("target-bag", bag)
    cast:SetAttribute("target-slot", slot)
    cast.spellIcon:SetTexture(SpellIcon(spell))
    cast.button, cast.spell, cast.bag, cast.slot = button, spell, bag, slot
    cast:Show()
end

function B.OnItemEnter(button)
    hovered = button
    B.UpdateQuickCast()
end

function B.OnItemLeave(button)
    -- Al aparecer el botón encima, la casilla "pierde" el ratón: no cuenta.
    if cast:IsShown() and cast.button == button then return end
    if hovered == button then hovered = nil end
end

cast:SetScript("OnEnter", function(self)
    if not (self.bag and GameTooltip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetBagItem then GameTooltip:SetBagItem(self.bag, self.slot) end
    GameTooltip:AddLine(ns.LF("Alt+clic: %s", tostring(SpellName(self.spell))), 0.31, 0.76, 0.97)
    GameTooltip:Show()
end)
cast:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    hovered = nil
    HideCast()
end)
-- Tras lanzar, el objeto cambia (o desaparece): se vuelve a mirar.
cast:HookScript("PostClick", function()
    C_Timer.After(0.2, B.UpdateQuickCast)
end)

ns.On("MODIFIER_STATE_CHANGED", function() B.UpdateQuickCast() end)
-- Al entrar en combate se quita (luego no se podría mover ni ocultar).
ns.On("PLAYER_REGEN_DISABLED", function() cast:Hide(); cast.button = nil; hovered = nil end)
ns.On("BAG_UPDATE_DELAYED", function() if cast:IsShown() then B.UpdateQuickCast() end end)
