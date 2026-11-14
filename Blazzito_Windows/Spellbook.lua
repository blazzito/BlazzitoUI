-- Blazzito_Windows: el libro de hechizos en un solo libro.
--
-- En Forever, el libro de Blizzard (PlayerSpellsFrame.SpellBookFrame) tiene
-- una pestaña por especialización y casi todo el pergamino vacío. Aquí todas
-- (general y cada especialización) van en el mismo libro, una sección tras
-- otra, separadas por un encabezado con su icono y una línea; las páginas se
-- pasan con las flechas o la rueda. La mascota tiene su propia página.
--
-- Cómo, sin romper nada: lanzar un hechizo desde un botón es una acción
-- protegida, así que los datos del libro de Blizzard no se tocan nunca (si
-- se tocaran, sus botones dejarían de lanzar). El libro unificado es nuestro:
-- botones seguros propios (SecureActionButtonTemplate, type = spell) encima
-- del pergamino de Blizzard, que se queda de fondo. El libro no depende de
-- las pestañas de Blizzard (se ocultan todas): tiene las suyas, Hechizos y
-- Mascota. En la de la mascota, clic izquierdo la lanza y clic derecho
-- activa o quita su lanzamiento automático (/petautocasttoggle).
--
-- Limitaciones del juego: los botones seguros solo se pueden colocar fuera de
-- combate. En combate el libro funciona (lanzar, arrastrar no), pero pasar de
-- página, buscar o cambiar a la mascota espera al final del combate.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win = ns.Windows
local M = ns.Media
local Child, Hold = Win.Child, Win.Hold
local Readable = M.Readable

local B = {}
Win.Spellbook = B

local function Opts() return Win.db.spellbook end
local function Combat() return InCombatLockdown and InCombatLockdown() end

-- Texto claro sobre el fondo oscuro de la ventana (sin pergamino).
local INK = { 0.92, 0.92, 0.94 }
local INK_SOFT = { 0.58, 0.60, 0.65 }
local function AccentOr(r, g, b)
    local ar, ag, ab = Win.Accent()
    if ar then return ar, ag, ab end
    return r, g, b
end

local ROW, HEADER, ICON = 46, 46, 34

---------------------------------------------------------------------------
-- Datos: secciones { name, icon, items = { {slot, spellID, kind, name, sub, icon, passive} } }
---------------------------------------------------------------------------
local function Bank() return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0 end
local function Kind(name) return Enum and Enum.SpellBookItemType and Enum.SpellBookItemType[name] end
local function CVarOn(name)
    if C_CVar and C_CVar.GetCVarBool then
        local ok, v = pcall(C_CVar.GetCVarBool, name)
        if ok then return v end
    end
    return GetCVarBool and GetCVarBool(name) or false
end

B.query = nil
B.mode = "book"

local function PetBank() return Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1 end

function B.PetCount()
    if not (C_SpellBook and C_SpellBook.HasPetSpells) then return 0 end
    local ok, n = pcall(C_SpellBook.HasPetSpells)
    n = ok and Readable(n)
    return type(n) == "number" and n or 0
end

-- Los hechizos de la mascota, como una sola sección con su nombre.
function B.ReadPet()
    local count = B.PetCount()
    if count == 0 then return {} end
    local bank = PetBank()
    local allRanks = CVarOn("ShowAllSpellRanks")
    local query = B.query and B.query:lower()
    local items = {}
    for slot = 1, count do
        local it = C_SpellBook.GetSpellBookItemInfo(slot, bank)
        local keep = it and type(it.name) == "string"
        if keep and not allRanks and C_SpellBook.IsSpellBookItemLowRank then
            local okLow, low = pcall(C_SpellBook.IsSpellBookItemLowRank, slot, bank)
            if okLow and low then keep = false end
        end
        if keep and query and query ~= "" then
            local sub = type(it.subName) == "string" and it.subName:lower() or ""
            keep = it.name:lower():find(query, 1, true) or sub:find(query, 1, true)
        end
        if keep then
            local allowed, enabled
            if C_SpellBook.GetSpellBookItemAutoCast then
                local okA, a, e = pcall(C_SpellBook.GetSpellBookItemAutoCast, slot, bank)
                if okA then allowed, enabled = Readable(a), Readable(e) end
            end
            items[#items + 1] = {
                slot = slot, bank = bank, pet = true, spellID = it.spellID, actionID = it.actionID,
                name = it.name, sub = it.subName, icon = it.iconID, passive = it.isPassive,
                autoAllowed = allowed and true or false, autoOn = enabled and true or false,
            }
        end
    end
    if #items == 0 then return {} end
    local name = UnitName and Readable(UnitName("pet"))
    return { { name = (type(name) == "string" and name ~= "") and name or "Mascota", icon = items[1].icon, items = items } }
end

function B.Read()
    local sections = {}
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then return sections end
    local bank = Bank()
    local allRanks = CVarOn("ShowAllSpellRanks")
    local hidePassives = CVarOn("spellBookHidePassives")
    local query = B.query and B.query:lower()
    local ok, count = pcall(C_SpellBook.GetNumSpellBookSkillLines)
    count = ok and Readable(count) or 0
    for i = 1, count do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
        local off = line and Readable(line.offSpecID)
        if line and not line.shouldHide and not line.isGuild and not (off and off ~= 0) and line.itemIndexOffset then
            local items = {}
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + (line.numSpellBookItems or 0) do
                local it = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                local kind = it and it.itemType
                local keep = it and (kind == Kind("Spell") or kind == Kind("FutureSpell") or kind == Kind("Flyout"))
                if keep and kind == Kind("Spell") and not allRanks and C_SpellBook.IsSpellBookItemLowRank then
                    local okLow, low = pcall(C_SpellBook.IsSpellBookItemLowRank, slot, bank)
                    if okLow and low then keep = false end
                end
                if keep and hidePassives and it.isPassive then keep = false end
                if keep and query and query ~= "" then
                    local name = type(it.name) == "string" and it.name:lower() or ""
                    local sub = type(it.subName) == "string" and it.subName:lower() or ""
                    keep = name:find(query, 1, true) or sub:find(query, 1, true)
                end
                if keep then
                    items[#items + 1] = {
                        slot = slot, spellID = it.spellID, actionID = it.actionID, kind = kind,
                        name = it.name, sub = it.subName, icon = it.iconID, passive = it.isPassive,
                        future = kind == Kind("FutureSpell"), flyout = kind == Kind("Flyout"),
                    }
                end
            end
            if #items > 0 then sections[#sections + 1] = { name = line.name, icon = line.iconID, items = items } end
        end
    end
    return sections
end

---------------------------------------------------------------------------
-- Maquetación: secciones repartidas por páginas (dos por pliego)
---------------------------------------------------------------------------
-- Devuelve las colocaciones { page, x, y, header = sección | item = hechizo }
-- y el número de páginas.
function B.Flow(sections, width, height, perSpread)
    local pageW = width / perSpread
    local padX, top, bottom = 46, 34, 70
    local colW = math.floor((pageW - padX * 2 - 16) / 2)
    local usable = height - top - bottom
    local placed, page, y = {}, 1, 0
    local function NewPage() page, y = page + 1, 0 end
    for _, section in ipairs(sections) do
        -- Un encabezado nunca se queda solo al pie de la página.
        if y > 0 and y + HEADER + ROW > usable then NewPage() end
        placed[#placed + 1] = { page = page, x = padX, y = top + y, w = pageW - padX * 2, header = section }
        y = y + HEADER
        for i, item in ipairs(section.items) do
            local col = (i - 1) % 2
            if col == 0 then
                if y + ROW > usable then NewPage() end
            end
            placed[#placed + 1] = { page = page, x = padX + col * (colW + 16), y = top + y, w = colW, item = item }
            if col == 1 or i == #section.items then y = y + ROW end
        end
        y = y + 10
    end
    return placed, page, colW
end

---------------------------------------------------------------------------
-- Piezas: encabezados (nuestros, sin protección) y hechizos (botones seguros)
---------------------------------------------------------------------------
local headers, buttons = {}, {}

local function Header(book, i)
    local h = headers[i]
    if h then return h end
    h = Win.Own(CreateFrame("Frame", nil, book))
    h:SetHeight(HEADER - 8)
    h.icon = h:CreateTexture(nil, "ARTWORK")
    h.icon:SetSize(24, 24)
    h.icon:SetPoint("LEFT", 0, 2)
    h.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    h.edge = h:CreateTexture(nil, "BACKGROUND")
    h.edge:SetPoint("TOPLEFT", h.icon, -1, 1)
    h.edge:SetPoint("BOTTOMRIGHT", h.icon, 1, -1)
    h.edge:SetColorTexture(0, 0, 0, 1)
    h.text = h:CreateFontString(nil, "ARTWORK")
    h.text:SetFont(M.FONT, 17, "")
    h.text:SetTextColor(INK[1], INK[2], INK[3])
    h.text:SetPoint("LEFT", h.icon, "RIGHT", 10, 0)
    h.line = h:CreateTexture(nil, "ARTWORK")
    h.line:SetHeight(1)
    h.line:SetPoint("LEFT", h.text, "RIGHT", 12, -1)
    h.line:SetPoint("RIGHT", h, "RIGHT", 0, -1)
    local ar, ag, ab = AccentOr(0.6, 0.6, 0.65)
    h.line:SetColorTexture(ar, ag, ab, 0.45)
    h.under = h:CreateTexture(nil, "ARTWORK")
    h.under:SetHeight(2)
    h.under:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, 2)
    h.under:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, 2)
    h.under:SetColorTexture(ar, ag, ab, 0.08)
    headers[i] = h
    return h
end

---------------------------------------------------------------------------
-- Al pasar el ratón: el hechizo parpadea en tus barras (como en el libro de
-- Blizzard). Sin llamar a sus funciones globales de barras (contaminarían las
-- barras de acción): se buscan los botones con ese hechizo y se enciende su
-- propio brillo de "hechizo resaltado", o uno nuestro si no lo tienen.
---------------------------------------------------------------------------
local BARS = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local lit = {}
local ownGlow = setmetatable({}, { __mode = "k" })

local function SpellName(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok then return Readable(name) end
    end
    return nil
end

local function ActionSpell(button)
    local action = Readable(rawget(button, "action"))
    if type(action) ~= "number" and button.GetAttribute then action = Readable(button:GetAttribute("action")) end
    if type(action) ~= "number" or not GetActionInfo then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, action)
    kind, id, subType = ok and Readable(kind), ok and Readable(id), ok and Readable(subType)
    if kind == "spell" then return id end
    -- Macro que lanza un hechizo: Forever ya da el número del hechizo.
    if kind == "macro" and subType == "spell" then return id end
    if kind == "macro" and GetMacroSpell then
        local okM, spell = pcall(GetMacroSpell, id)
        return okM and Readable(spell) or nil
    end
    return nil
end

local function Glow(button, on)
    local tex, anim = rawget(button, "SpellHighlightTexture"), rawget(button, "SpellHighlightAnim")
    if tex and anim and tex.Show then
        if on then tex:Show(); anim:Play() else anim:Stop(); tex:Hide() end
        return
    end
    local g = ownGlow[button]
    if not g then
        if not on then return end
        g = button:CreateTexture(nil, "OVERLAY", nil, 7)
        g:SetAllPoints()
        g:SetTexture("Interface\\Buttons\\WHITE8X8")
        g.anim = g:CreateAnimationGroup()
        g.anim:SetLooping("BOUNCE")
        local a = g.anim:CreateAnimation("Alpha")
        a:SetFromAlpha(0.1)
        a:SetToAlpha(0.55)
        a:SetDuration(0.5)
        ownGlow[button] = g
    end
    if on then
        local r, gr, b = Win.Accent()
        g:SetVertexColor(r or 1, gr or 0.82, b or 0)
        g:Show(); g.anim:Play()
    else
        g.anim:Stop(); g:Hide()
    end
end

function B.HighlightBars(item)
    for button in pairs(lit) do Glow(button, false) end
    wipe(lit)
    if not (item and item.spellID) or item.passive or item.future then return end
    local name = SpellName(item.spellID) or item.name
    for _, prefix in ipairs(BARS) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and button.IsVisible and button:IsVisible() then
                local id = ActionSpell(button)
                if id and (id == item.spellID or (name and SpellName(id) == name)) then
                    lit[button] = true
                    Glow(button, true)
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- ¿Está en tus barras? Se recorren las casillas de acción y se anotan sus
-- hechizos (también los de las macros y los de dentro de los grupos de
-- hechizos) por id y por nombre: así cuenta tener otro rango del mismo
-- hechizo. Se rehace al cambiar las barras.
---------------------------------------------------------------------------
local onBars, onBarsStale = nil, true
local MAX_ACTION = 180

local function BarSets()
    if onBars and not onBarsStale then return onBars end
    local ids, names, flyouts = {}, {}, {}
    if GetActionInfo then
        for slot = 1, MAX_ACTION do
            local ok, kind, id, subType = pcall(GetActionInfo, slot)
            kind, id, subType = ok and Readable(kind), ok and Readable(id), ok and Readable(subType)
            if kind == "macro" and subType == "spell" then
                -- Macro que lanza un hechizo: Forever ya da el número del hechizo.
                kind = "spell"
            elseif kind == "macro" and GetMacroSpell then
                local okM, spell = pcall(GetMacroSpell, id)
                kind, id = "spell", okM and Readable(spell) or nil
            end
            if kind == "spell" and id then
                ids[id] = true
                local name = SpellName(id)
                if name then names[name] = true end
            elseif kind == "flyout" and id then
                flyouts[id] = true
                -- Los hechizos de dentro del grupo (aspectos, rastreos,
                -- herramientas de mascota...) también están a mano.
                if GetFlyoutInfo and GetFlyoutSlotInfo then
                    local okF, _, _, count = pcall(GetFlyoutInfo, id)
                    for i = 1, (okF and Readable(count)) or 0 do
                        local okS, spellID, override, _, spellName = pcall(GetFlyoutSlotInfo, id, i)
                        if okS then
                            for _, sid in ipairs({ Readable(spellID), Readable(override) }) do
                                if type(sid) == "number" and sid > 0 then
                                    ids[sid] = true
                                    local name = SpellName(sid)
                                    if name then names[name] = true end
                                end
                            end
                            spellName = Readable(spellName)
                            if type(spellName) == "string" and spellName ~= "" then names[spellName] = true end
                        end
                    end
                end
            end
        end
    end
    onBars, onBarsStale = { ids = ids, names = names, flyouts = flyouts }, false
    return onBars
end

-- true / false; nil si no aplica (pasivas, futuras, la mascota).
function B.OnBars(item)
    if not item or item.passive or item.future or item.pet then return nil end
    local sets = BarSets()
    if item.flyout then return sets.flyouts[item.actionID] and true or false end
    if item.spellID and sets.ids[item.spellID] then return true end
    local name = SpellName(item.spellID) or item.name
    return (name and sets.names[name]) and true or false
end

function B.BarsChanged() onBarsStale = true end

local function Tooltip(self)
    local d = Win.Parts(self)
    if not d.item then return end
    B.HighlightBars(d.item)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local ok = GameTooltip.SetSpellBookItem and pcall(GameTooltip.SetSpellBookItem, GameTooltip, d.item.slot, d.item.bank or Bank())
    if not ok and d.item.spellID then pcall(GameTooltip.SetSpellByID, GameTooltip, d.item.spellID) end
    if Opts().markUnbound and B.OnBars(d.item) == false then
        local r, g, b = Win.Accent()
        GameTooltip:AddLine("No está en tus barras", r or 1, g or 0.82, b or 0)
    end
    GameTooltip:Show()
end

local function Drag(self)
    local d = Win.Parts(self)
    if not d.item or d.item.passive or d.item.future or Combat() then return end
    if C_SpellBook and C_SpellBook.PickupSpellBookItem then
        pcall(C_SpellBook.PickupSpellBookItem, d.item.slot, d.item.bank or Bank())
    elseif d.item.spellID and C_Spell and C_Spell.PickupSpell then
        pcall(C_Spell.PickupSpell, d.item.spellID)
    end
end

local function SpellButton(book, i)
    local b = buttons[i]
    if b then return b end
    b = Win.Own(CreateFrame("Button", nil, book, "SecureActionButtonTemplate"))
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHeight(ICON + 6)
    local d = Win.Parts(b)
    d.icon = b:CreateTexture(nil, "ARTWORK")
    d.icon:SetSize(ICON, ICON)
    d.icon:SetPoint("LEFT", 2, 0)
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.edge = b:CreateTexture(nil, "BACKGROUND")
    d.edge:SetPoint("TOPLEFT", d.icon, -2, 2)
    d.edge:SetPoint("BOTTOMRIGHT", d.icon, 2, -2)
    d.hover = b:CreateTexture(nil, "HIGHLIGHT")
    d.hover:SetAllPoints(d.icon)
    d.hover:SetColorTexture(1, 1, 1, 0.15)
    -- Marca suave de "no está en tus barras": fondo tenue en la fila y un punto en el icono.
    d.unbound = b:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.unbound:SetPoint("TOPLEFT", -4, 2)
    d.unbound:SetPoint("BOTTOMRIGHT", 2, -2)
    d.unbound:Hide()
    d.dot = b:CreateTexture(nil, "OVERLAY", nil, 7)
    d.dot:SetSize(6, 6)
    d.dot:SetPoint("CENTER", d.icon, "TOPRIGHT", -2, -2)
    d.dot:Hide()
    d.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    d.cd:SetAllPoints(d.icon)
    d.name = b:CreateFontString(nil, "ARTWORK")
    d.name:SetFont(M.FONT, 13, "")
    d.name:SetJustifyH("LEFT")
    d.name:SetPoint("LEFT", d.icon, "RIGHT", 10, 7)
    d.name:SetPoint("RIGHT", b, "RIGHT", -2, 7)
    d.sub = b:CreateFontString(nil, "ARTWORK")
    d.sub:SetFont(M.FONT, 11, "")
    d.sub:SetJustifyH("LEFT")
    d.sub:SetPoint("TOPLEFT", d.name, "BOTTOMLEFT", 0, -2)
    d.sub:SetPoint("RIGHT", b, "RIGHT", -2, 0)
    b:SetScript("OnEnter", Tooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide(); B.HighlightBars(nil) end)
    b:SetScript("OnDragStart", Drag)
    -- Mayús + clic: enlace en el chat en vez de lanzarlo (como en el libro de Blizzard).
    b:SetAttribute("shift-type1", "none")
    b:HookScript("OnClick", function(self)
        local item = Win.Parts(self).item
        if not (item and item.spellID and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
        local link = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(item.spellID)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)
    buttons[i] = b
    return b
end

-- Pinta un hechizo (sin protección: también vale en combate).
local function Paint(b, item)
    local d = Win.Parts(b)
    d.item = item
    d.icon:SetTexture(item.icon)
    local dim = item.future
    d.icon:SetDesaturated(dim and true or false)
    d.icon:SetAlpha(dim and 0.55 or 1)
    local r, g, bl = Win.Accent()
    if item.passive or not r then d.edge:SetColorTexture(0.30, 0.30, 0.33, 1)
    else d.edge:SetColorTexture(r * 0.7, g * 0.7, bl * 0.7, 1) end
    d.name:SetText(item.name or "")
    d.name:SetTextColor(INK[1], INK[2], INK[3], dim and 0.6 or 1)
    local sub = item.sub
    if item.passive then sub = (sub and sub ~= "" and (sub .. " · ") or "") .. "Pasiva" end
    if item.flyout and (not sub or sub == "") then sub = "Grupo de hechizos" end
    if item.autoAllowed then
        sub = (sub and sub ~= "" and (sub .. " · ") or "") .. (item.autoOn and "Automático" or "Manual (clic derecho: automático)")
        if item.autoOn and r then d.edge:SetColorTexture(r, g, bl, 1) end
    end
    d.sub:SetText(sub or "")
    d.sub:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3], dim and 0.6 or 1)
    B.PaintUnbound(b)
end

-- La marca de "no está en tus barras" (también vale en combate).
function B.PaintUnbound(b)
    local d = Win.Parts(b)
    if not d.unbound then return end
    local mark = Opts().markUnbound and B.OnBars(d.item) == false
    if mark then
        local r, g, bl = Win.Accent()
        r, g, bl = r or 1, g or 0.82, bl or 0
        d.unbound:SetColorTexture(r, g, bl, 0.09)
        d.dot:SetColorTexture(r, g, bl, 1)
    end
    d.unbound:SetShown(mark)
    d.dot:SetShown(mark)
end

local function Cooldown(b)
    local d = Win.Parts(b)
    local item = d.item
    if not (item and item.spellID) or item.passive or item.future then d.cd:Hide(); return end
    if C_Spell and C_Spell.GetSpellCooldownDuration and d.cd.SetCooldownFromDurationObject then
        local ok, dur = pcall(C_Spell.GetSpellCooldownDuration, item.spellID)
        if ok and dur then pcall(d.cd.SetCooldownFromDurationObject, d.cd, dur); return end
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, item.spellID)
        if ok and type(info) == "table" then pcall(d.cd.SetCooldown, d.cd, info.startTime, info.duration) end
    end
end

-- Lo que lanza (protegido: solo fuera de combate).
local function Aim(b, item)
    if item and not item.passive and not item.future then
        if item.pet then
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", item.name)
            if item.autoAllowed then
                b:SetAttribute("type2", "macro")
                b:SetAttribute("macrotext2", "/petautocasttoggle " .. item.name)
            else
                b:SetAttribute("type2", nil)
                b:SetAttribute("macrotext2", nil)
            end
        elseif item.flyout then
            b:SetAttribute("type", "flyout")
            b:SetAttribute("spell", item.actionID)
            b:SetAttribute("flyoutDirection", "RIGHT")
        else
            b:SetAttribute("type", "spell")
            b:SetAttribute("spell", item.spellID)
        end
        if not item.pet then
            b:SetAttribute("type2", nil)
            b:SetAttribute("macrotext2", nil)
        end
    else
        b:SetAttribute("type", nil)
        b:SetAttribute("spell", nil)
        b:SetAttribute("type2", nil)
        b:SetAttribute("macrotext2", nil)
    end
end

---------------------------------------------------------------------------
-- El libro
---------------------------------------------------------------------------
B.spread, B.spreads = 1, 1
local book, controls

local function SpellBook() return _G.PlayerSpellsFrame and Child(_G.PlayerSpellsFrame, "SpellBookFrame") end
local function Paged(sb) return sb and Child(sb, "PagedSpellsFrame") end

local function PerSpread(width) return width >= 640 and 2 or 1 end

-- El fondo: emblema de la clase (tenue, de tu color) y el lomo entre páginas.
function B.Backdrop(width, height, per)
    if not book then return end
    local class
    if UnitClass then class = select(2, UnitClass("player")) end
    local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
    local r, g, b = AccentOr(0.7, 0.7, 0.75)
    if coords and Opts().crest ~= false then
        book.crest:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
        local size = math.floor(math.min(width, height) * 0.62)
        book.crest:SetSize(size, size)
        book.crest:SetVertexColor(r, g, b, 0.07)
        book.crest:Show()
    else
        book.crest:Hide()
    end
    book.spine:SetColorTexture(r, g, b, 0.18)
    book.spine:SetShown(per == 2)
end

-- Redibuja el pliego actual: coloca y apunta los botones. Fuera de combate.
function B.Render()
    if not book then return end
    if Combat() then ns.AfterCombat("bui-spellbook", B.Render); return end
    local width, height = book:GetWidth(), book:GetHeight()
    width, height = Readable(width) or 0, Readable(height) or 0
    if width < 100 or height < 100 then return end
    local per = PerSpread(width)
    if B.mode == "pet" and B.PetCount() == 0 then B.mode = "book" end
    local sections = B.mode == "pet" and B.ReadPet() or B.Read()
    local placed, pages = B.Flow(sections, width, height, per)
    B.spreads = math.max(1, math.ceil(pages / per))
    B.spread = math.max(1, math.min(B.spread, B.spreads))
    local first = (B.spread - 1) * per + 1
    local pageW = width / per
    local hi, bi = 0, 0
    for _, p in ipairs(placed) do
        if p.page >= first and p.page < first + per then
            local x = (p.page - first) * pageW + p.x
            if p.header then
                hi = hi + 1
                local h = Header(book, hi)
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", book, "TOPLEFT", x, -p.y)
                h:SetWidth(p.w)
                h.icon:SetTexture(p.header.icon)
                h.text:SetText(p.header.name or "")
                h:Show()
            else
                bi = bi + 1
                local b = SpellButton(book, bi)
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT", book, "TOPLEFT", x, -p.y)
                b:SetWidth(p.w)
                Paint(b, p.item)
                Aim(b, p.item)
                b:Show()
                Cooldown(b)
            end
        end
    end
    for i = hi + 1, #headers do headers[i]:Hide() end
    for i = bi + 1, #buttons do
        Aim(buttons[i], nil)
        Win.Parts(buttons[i]).item = nil
        buttons[i]:Hide()
    end
    if controls then
        controls.text:SetText(string.format("Página %d/%d", B.spread, B.spreads))
        controls.prev:SetEnabled(B.spread > 1)
        controls.next:SetEnabled(B.spread < B.spreads)
        controls.prev:SetAlpha(B.spread > 1 and 1 or 0.35)
        controls.next:SetAlpha(B.spread < B.spreads and 1 or 0.35)
    end
    if book.empty then book.empty:SetShown(bi == 0) end
    B.Backdrop(width, height, per)
    if B.PaintTabs then B.PaintTabs() end
end

function B.Turn(step)
    if Combat() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("Las páginas se pasan fuera de combate.", 1, 0.3, 0.3) end
        return
    end
    local to = math.max(1, math.min(B.spreads, B.spread + step))
    if to ~= B.spread then
        B.spread = to
        B.Render()
    end
end

local function Arrow(parent, angle)
    local b = Win.Own(CreateFrame("Button", nil, parent))
    b:SetSize(26, 26)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.14, 0.95)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(12, 12)
    icon:SetPoint("CENTER")
    icon:SetTexture(M.ICONS.chevron)
    icon:SetVertexColor(0.85, 0.85, 0.9)
    if icon.SetRotation then icon:SetRotation(angle) end
    local hover = b:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.12)
    return b
end

local function Build(sb, paged)
    book = Win.Own(CreateFrame("Frame", nil, sb))
    B.book = book
    book:SetAllPoints(paged)
    book:SetFrameLevel((paged:GetFrameLevel() or 1) + 30)
    book:EnableMouse(true)          -- tapa el libro de Blizzard que queda debajo
    book:EnableMouseWheel(true)
    book:SetScript("OnMouseWheel", function(_, delta) B.Turn(delta > 0 and -1 or 1) end)
    book:SetScript("OnSizeChanged", function() B.Render() end)
    -- Fondo limpio: el emblema de tu clase muy tenue y una línea fina entre las dos páginas.
    book.crest = book:CreateTexture(nil, "BACKGROUND", nil, 1)
    book.crest:SetPoint("CENTER")
    book.crest:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
    book.crest:SetDesaturated(true)
    book.spine = book:CreateTexture(nil, "BACKGROUND", nil, 2)
    book.spine:SetWidth(1)
    book.spine:SetPoint("TOP", book, "TOP", 0, -30)
    book.spine:SetPoint("BOTTOM", book, "BOTTOM", 0, 30)
    book.empty = book:CreateFontString(nil, "ARTWORK")
    book.empty:SetFont(M.FONT, 14, "")
    book.empty:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])
    book.empty:SetPoint("CENTER")
    book.empty:SetText("Ningún hechizo coincide con la búsqueda.")
    book.empty:Hide()
    controls = Win.Own(CreateFrame("Frame", nil, book))
    controls:SetSize(220, 30)
    controls:SetPoint("BOTTOMRIGHT", book, "BOTTOMRIGHT", -46, 30)
    controls.next = Arrow(controls, 0)
    controls.next:SetPoint("RIGHT")
    controls.prev = Arrow(controls, math.pi)
    controls.prev:SetPoint("RIGHT", controls.next, "LEFT", -8, 0)
    controls.text = controls:CreateFontString(nil, "ARTWORK")
    controls.text:SetFont(M.FONT, 14, "")
    controls.text:SetTextColor(INK[1], INK[2], INK[3])
    controls.text:SetPoint("RIGHT", controls.prev, "LEFT", -10, 0)
    controls.prev:SetScript("OnClick", function() B.Turn(-1) end)
    controls.next:SetScript("OnClick", function() B.Turn(1) end)
end

---------------------------------------------------------------------------
-- Pestañas: las de Blizzard fuera (todas); las nuestras, Hechizos y Mascota
---------------------------------------------------------------------------
local tabs = {}

-- Las pestañas de Blizzard (para ocultarlas), de izquierda a derecha.
function B.BlizzardTabs(sb)
    local system = Child(sb, "CategoryTabSystem")
    local list = {}
    local found = system and rawget(system, "tabs")
    if type(found) == "table" then
        for _, tab in pairs(found) do if type(tab) == "table" and tab.CreateTexture then list[#list + 1] = tab end end
    elseif system then
        for _, child in ipairs(Win.Children(system)) do
            if child.GetObjectType and child:GetObjectType() == "Button" then list[#list + 1] = child end
        end
    end
    table.sort(list, function(a, b)
        local ax, bx = Readable(a:GetLeft()), Readable(b:GetLeft())
        if type(ax) ~= "number" or type(bx) ~= "number" then return false end
        return ax < bx
    end)
    return list
end

function B.PaintTabs()
    local r, g, b = Win.Accent()
    if not r then r, g, b = 1, 0.82, 0 end
    local hasPet = B.PetCount() > 0
    for key, tab in pairs(tabs) do
        local on = B.mode == key
        tab.ring:SetColorTexture(r, g, b, on and 1 or 0)
        tab.icon:SetDesaturated(not on)
        if key == "pet" then tab:SetShown(hasPet and book and book:IsShown() or false) end
    end
end

function B.SetMode(mode)
    if mode == B.mode then return end
    if Combat() then
        if UIErrorsFrame then UIErrorsFrame:AddMessage("Se cambia de página al salir de combate.", 1, 0.3, 0.3) end
        ns.AfterCombat("bui-spellbook-mode", function() B.SetMode(mode) end)
        return
    end
    B.mode = mode
    B.spread = 1
    B.Render()
end

local function Tab(parent, key, icon, title, text)
    local tab = Win.Own(CreateFrame("Button", nil, parent))
    tab:SetSize(36, 36)
    tab.ring = tab:CreateTexture(nil, "BACKGROUND", nil, -7)
    tab.ring:SetPoint("TOPLEFT", -2, 2)
    tab.ring:SetPoint("BOTTOMRIGHT", 2, -2)
    local edge = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
    edge:SetAllPoints()
    edge:SetColorTexture(0, 0, 0, 1)
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetPoint("TOPLEFT", 1, -1)
    tab.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    tab.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tab.icon:SetTexture(icon)
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(tab.icon)
    hover:SetColorTexture(1, 1, 1, 0.12)
    tab:SetScript("OnClick", function() B.SetMode(key) end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(text, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tabs[key] = tab
    return tab
end

-- Encima del libro, arriba a la izquierda (donde estaban las de Blizzard).
local function MakeTabs(sb, first)
    local strip = Win.Own(CreateFrame("Frame", nil, sb))
    strip:SetSize(90, 36)
    strip:SetFrameLevel((book:GetFrameLevel() or 1) + 10)
    if first then strip:SetPoint("LEFT", first, "LEFT", 0, 0)
    else strip:SetPoint("TOPLEFT", sb, "TOPLEFT", 90, -14) end
    B.tabStrip = strip
    local spells = Tab(strip, "book", "Interface\\Icons\\INV_Misc_Book_09", "Hechizos", "Todas tus especializaciones en un solo libro.")
    spells:SetPoint("LEFT")
    local pet = Tab(strip, "pet", "Interface\\Icons\\Ability_Hunter_BeastCall", "Mascota",
        "Los hechizos de tu mascota. Clic derecho en uno: lanzamiento automático sí/no.")
    pet:SetPoint("LEFT", spells, "RIGHT", 12, 0)
end

---------------------------------------------------------------------------
-- Desplegado: Blizzard recuerda si plegaste el libro en el ajuste
-- spellBookMinimize. Con la opción, se devuelve a 0 al cerrar la ventana y
-- al abrirla otra vez sale desplegado. (Pulsar su botón de desplegar desde un
-- addon contaminaría la colocación de ventanas: por eso solo el ajuste.)
---------------------------------------------------------------------------
local MINIMIZE = "spellBookMinimize"
function B.Unfold()
    if not (Opts().enabled and Opts().expand) then return end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if get and set and get(MINIMIZE) == "1" then pcall(set, MINIMIZE, "0") end
end
local hookedHide = setmetatable({}, { __mode = "k" })

-- El arte de libro de Blizzard (pergamino, lomo, esquinas, barra de arriba): fuera.
local BOOK_ART = { "BookBGLeft", "BookBGRight", "BookBGHalved", "TopBar", "BookCornerFlipbook", "Bookmark", "BookmarkBackground" }
function B.BookArt(sb, on)
    Win.Strip(sb, on)
    for _, key in ipairs(BOOK_ART) do
        local part = Child(sb, key)
        if part then
            if Win.IsTexture(part) then Hold(part, on) else Hold(part, on); Win.Strip(part, on) end
        end
    end
end

-- Plegar/desplegar: un botón moderno con dos iconos propios (libro abierto / una página).
function B.MaxMin(frame, on)
    local mm = frame and (Child(frame, "MaximizeMinimizeButton") or Child(frame, "MaxMinButtonFrame"))
    if not mm then return end
    Win.Strip(mm, on)
    Win.ModernButton(Child(mm, "MaximizeButton"), M.ICONS.maximize, 20, on)
    Win.ModernButton(Child(mm, "MinimizeButton"), M.ICONS.minimize, 20, on)
end

local hookedSearch = setmetatable({}, { __mode = "k" })

local function Search(sb)
    for _, owner in ipairs({ sb, _G.PlayerSpellsFrame }) do
        local box = Child(owner, "SearchBox")
        if box and box.GetText then return box end
    end
end

---------------------------------------------------------------------------
-- Aplicar (desde el paquete de talentos: es la misma ventana)
---------------------------------------------------------------------------
function B.Apply(frame, on)
    local sb = SpellBook()
    local paged = Paged(sb)
    if not (sb and paged) then return end
    on = on and Opts().enabled
    if not on and not book then
        B.BookArt(sb, false)
        B.MaxMin(frame, false)
    end
    if Combat() then
        ns.AfterCombat("bui-spellbook-apply", function() B.Apply(frame, Win.PackOn(Win.Talents.pack)) end)
        return
    end
    B.BookArt(sb, on)
    B.MaxMin(frame, on)
    if on and not book then Build(sb, paged) end
    if frame and not hookedHide[frame] then
        hookedHide[frame] = true
        frame:HookScript("OnHide", B.Unfold)
    end
    B.Unfold()
    if not book then return end

    local blizz = B.BlizzardTabs(sb)
    if on and not B.tabStrip then MakeTabs(sb, blizz[1]) end
    for _, tab in ipairs(blizz) do
        Hold(tab, on)
        tab:EnableMouse(not on)
    end
    if B.tabStrip then B.tabStrip:SetShown(on) end
    local box = Search(sb)
    if box and not hookedSearch[box] then
        hookedSearch[box] = true
        box:HookScript("OnTextChanged", function(self)
            local text = Readable(self:GetText())
            B.query = (type(text) == "string" and text ~= "") and text or nil
            B.spread = 1
            if book and book:IsShown() then B.Render() end
        end)
    end
    if on then
        book:Show()
        Hold(paged, true)
        B.Render()
    else
        -- Sin unificar: el libro de Blizzard tal cual (el modo elegido se recuerda).
        book:Hide()
        Hold(paged, false)
    end
end

-- Al cambiar los hechizos o las opciones del libro, se redibuja.
local pending = false
local function Changed()
    if pending or not book then return end
    pending = true
    C_Timer.After(0.2, function()
        pending = false
        if book:IsVisible() then B.Render() end
    end)
end
-- Al cambiar las barras, solo se repintan las marcas (no hace falta recolocar nada).
local function BarsChanged()
    B.BarsChanged()
    if not (book and book:IsVisible()) then return end
    for _, b in ipairs(buttons) do if b:IsShown() then B.PaintUnbound(b) end end
end
for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "UPDATE_MACROS", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR" }) do
    pcall(ns.On, event, BarsChanged)
end
for _, event in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "CVAR_UPDATE", "PET_BAR_UPDATE", "UNIT_PET", "PET_UI_UPDATE" }) do
    pcall(ns.On, event, Changed)
end
pcall(ns.On, "SPELL_UPDATE_COOLDOWN", function()
    if not (book and book:IsVisible()) then return end
    for _, b in ipairs(buttons) do if b:IsShown() then Cooldown(b) end end
end)

function B.Diagnose()
    local sb = SpellBook()
    local sections = B.Read()
    local n = 0
    for _, sec in ipairs(sections) do n = n + #sec.items end
    print(string.format("  libro: %s, páginas %s, pestañas de Blizzard ocultas %d, secciones %d, hechizos %d, mascota %d, pliego %d/%d, viendo %s",
        sb and "sí" or "no", Paged(sb) and "sí" or "no", #B.BlizzardTabs(sb or {}), #sections, n, B.PetCount(),
        B.spread, B.spreads, B.mode == "pet" and "mascota" or "hechizos"))
    for _, sec in ipairs(sections) do print("    " .. tostring(sec.name) .. ": " .. #sec.items) end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local w = B.book and Readable(B.book:GetWidth())
    print(string.format("    plegado: ajuste %s=%s, ancho del libro %s (dos páginas desde 640)",
        MINIMIZE, tostring(get and get(MINIMIZE)), tostring(w and math.floor(w))))
end
