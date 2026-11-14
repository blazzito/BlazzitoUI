-- Blazzito_Group: marcos de grupo y de banda.
-- Cada miembro es un marco del motor de marcos de unidad de BlazzitoUI (forma,
-- vida, recurso, lanzamiento, curación entrante, escudo, retrato...) con
-- extras de grupo: icono de rol, líder, perjuicios que puedes disipar (y el
-- marco brillando de su color), atenuado fuera de rango, borde de aggro y de
-- tu objetivo.
--
-- Los contenedores son seguros y se muestran solos según el grupo: el de grupo
-- con un grupo pequeño y el de banda en banda. En banda, cada subgrupo es una
-- columna (se reordena fuera de combate).
local ns = BlazzitoUI
if not ns then return end
local UF = ns.UnitFrames
if not (UF and UF.Spawn and UF.UnitDefaults) then return end

local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret

local function LayoutDefaults(overrides)
    local d = UF.UnitDefaults({
        width = 140, height = 36, power = 4, shape = "rect",
        healthText = "percent", showLevel = false, fontSize = 11,
        castbar = true, castHeight = 6, castIcon = false,
    })
    -- Extras de grupo
    d.roleIcon, d.leaderIcon = true, true
    d.dispels, d.dispelMax, d.dispelSize, d.dispelPos, d.dispelGlow = true, 3, 18, "outside", true
    d.myBuffs, d.myBuffMissing, d.myBuffMax, d.myBuffSize, d.myBuffPos = true, true, 4, 16, "inside"
    d.rangeFade, d.rangeAlpha = true, 40
    d.aggroBorder, d.targetBorder = true, true
    d.spacing = 4
    -- Organización (la usa la banda; el grupo la ignora)
    d.sortBy, d.groupColumns, d.columns, d.fillBy, d.maxGroups = "group", true, 8, "columns", 8
    for key, value in pairs(overrides) do d[key] = value end
    return d
end

local G = ns.NewModule("Group", "Grupo y banda", {
    hideBlizzard = true,
    layouts = {
        party = LayoutDefaults({ showPlayer = true }),
        raid = LayoutDefaults({ width = 84, height = 34, power = 3, healthText = "none", fontSize = 10,
                                castbar = false, dispelMax = 2, dispelSize = 14, dispelPos = "inside", spacing = 3,
                                myBuffMax = 3, myBuffSize = 12,
                                -- Organización: orden, columnas, cómo se llena y cuántos grupos se ven.
                                sortBy = "group", groupColumns = true, columns = 8, fillBy = "columns", maxGroups = 8 }),
    },
    positions = {},
})
ns.Group = G

G.KINDS = {
    party = { label = "Grupo", pos = { "TOPLEFT", "CENTER", -560, 200 },
              driver = "[group:raid] hide; [group:party] show; hide" },
    raid = { label = "Banda", pos = { "TOPLEFT", "CENTER", -560, -60 },
             driver = "[group:raid] show; hide" },
}
G.containers = {}
G.frames = { party = {}, raid = {} }
G.editing = "party"

local DEBUFF_COLORS = {
    Magic = { 0.20, 0.60, 1.00 }, Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 }, Poison = { 0.00, 0.60, 0.00 },
}
local CLASS_DISPELS = {
    PRIEST = { Magic = true, Disease = true }, PALADIN = { Magic = true, Poison = true, Disease = true },
    DRUID = { Curse = true, Poison = true }, SHAMAN = { Poison = true, Disease = true }, MAGE = { Curse = true },
}
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }

local function Cfg(frame) return G.db.layouts[frame.groupKind] end

---------------------------------------------------------------------------
-- Extras de cada miembro
---------------------------------------------------------------------------
local function Edge(parent, layer)
    local t = parent:CreateTexture(nil, layer or "OVERLAY", nil, 6)
    t:SetColorTexture(1, 1, 1, 1)
    return t
end

local function Decorate(frame)
    if frame.Group then return frame.Group end
    local g = {}
    local layer = frame.TextLayer
    g.role = layer:CreateTexture(nil, "OVERLAY")
    g.leader = layer:CreateTexture(nil, "OVERLAY")
    g.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    -- Contorno de 2 px alrededor de las barras: disipable > aggro > objetivo.
    g.outline = CreateFrame("Frame", nil, frame.Bars)
    g.outline:SetFrameLevel(frame.TextLayer:GetFrameLevel() + 1)
    g.edges = { Edge(g.outline), Edge(g.outline), Edge(g.outline), Edge(g.outline) }
    g.outline:Hide()
    -- Iconos de perjuicios disipables
    g.dispels = CreateFrame("Frame", nil, frame)
    g.dispels:SetFrameLevel(frame.TextLayer:GetFrameLevel() + 2)
    g.cells = {}
    -- Tus beneficios sobre él (y los que le faltan)
    g.buffs = CreateFrame("Frame", nil, frame)
    g.buffs:SetFrameLevel(frame.TextLayer:GetFrameLevel() + 2)
    g.buffCells = {}
    frame.Group = g
    return g
end

local function NewCell(parent)
    local cell = CreateFrame("Frame", nil, parent)
    cell.border = cell:CreateTexture(nil, "BACKGROUND")
    cell.border:SetPoint("TOPLEFT", -1, 1)
    cell.border:SetPoint("BOTTOMRIGHT", 1, -1)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetAllPoints()
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.cooldown = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
    cell.cooldown:SetAllPoints()
    cell.cooldown:SetHideCountdownNumbers(true)
    cell.cooldown:SetDrawEdge(false)
    return cell
end

local function DispelCell(g, i)
    g.cells[i] = g.cells[i] or NewCell(g.dispels)
    return g.cells[i]
end

local function BuffCell(g, i)
    g.buffCells[i] = g.buffCells[i] or NewCell(g.buffs)
    return g.buffCells[i]
end

-- Coloca los extras según la configuración (tras cada ApplyLayout del marco).
local function LayoutExtras(frame)
    local cfg, g = Cfg(frame), Decorate(frame)
    local bars = frame.Bars
    g.role:SetSize(12, 12)
    g.role:ClearAllPoints()
    g.role:SetPoint("TOPLEFT", bars, "TOPLEFT", 2, -2)
    g.leader:SetSize(12, 12)
    g.leader:ClearAllPoints()
    g.leader:SetPoint("BOTTOMLEFT", bars, "TOPLEFT", 2, -5)

    local e = g.edges
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", bars, -2, 2); e[1]:SetPoint("TOPRIGHT", bars, 2, 2); e[1]:SetHeight(2)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", bars, -2, -2); e[2]:SetPoint("BOTTOMRIGHT", bars, 2, -2); e[2]:SetHeight(2)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", bars, -2, 2); e[3]:SetPoint("BOTTOMLEFT", bars, -2, -2); e[3]:SetWidth(2)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", bars, 2, 2); e[4]:SetPoint("BOTTOMRIGHT", bars, 2, -2); e[4]:SetWidth(2)

    local size = cfg.dispelSize
    g.dispels:ClearAllPoints()
    g.dispels:SetSize(size * cfg.dispelMax + 2 * (cfg.dispelMax - 1), size)
    if cfg.dispelPos == "inside" then
        g.dispels:SetPoint("BOTTOMRIGHT", bars, "BOTTOMRIGHT", -3, 3)
    else
        g.dispels:SetPoint("LEFT", bars, "RIGHT", 4, 0)
    end
    for i = 1, cfg.dispelMax do
        local cell = DispelCell(g, i)
        cell:ClearAllPoints()
        cell:SetSize(size, size)
        if cfg.dispelPos == "inside" then
            cell:SetPoint("RIGHT", g.dispels, "RIGHT", -(i - 1) * (size + 2), 0)
        else
            cell:SetPoint("LEFT", g.dispels, "LEFT", (i - 1) * (size + 2), 0)
        end
    end
    for i = cfg.dispelMax + 1, #g.cells do g.cells[i]:Hide() end

    -- Tus beneficios: crecen hacia la izquierda desde la esquina derecha.
    size = cfg.myBuffSize
    g.buffs:ClearAllPoints()
    g.buffs:SetSize(size * cfg.myBuffMax + 2 * (cfg.myBuffMax - 1), size)
    if cfg.myBuffPos == "above" then
        g.buffs:SetPoint("BOTTOMRIGHT", bars, "TOPRIGHT", 0, 3)
    elseif cfg.myBuffPos == "left" then
        g.buffs:SetPoint("RIGHT", bars, "LEFT", -4, 0)
    else
        g.buffs:SetPoint("TOPRIGHT", bars, "TOPRIGHT", -3, -3)
    end
    for i = 1, cfg.myBuffMax do
        local cell = BuffCell(g, i)
        cell:ClearAllPoints()
        cell:SetSize(size, size)
        cell:SetPoint("RIGHT", g.buffs, "RIGHT", -(i - 1) * (size + 2), 0)
    end
    for i = cfg.myBuffMax + 1, #g.buffCells do g.buffCells[i]:Hide() end
end

local function SetOutline(g, color)
    if not color then
        g.outline:Hide()
        return
    end
    for _, edge in ipairs(g.edges) do edge:SetVertexColor(color[1], color[2], color[3], 1) end
    g.outline:Show()
end

local function SetRole(g, role, show)
    local atlas = show and ROLE_ATLAS[role or ""]
    if not atlas then
        g.role:Hide()
        return
    end
    if not pcall(g.role.SetAtlas, g.role, atlas) then
        g.role:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
        if GetTexCoordsForRoleSmallCircle then g.role:SetTexCoord(GetTexCoordsForRoleSmallCircle(role)) end
    end
    g.role:Show()
end

---------------------------------------------------------------------------
-- Perjuicios disipables
---------------------------------------------------------------------------
local DISPELLABLE = "HARMFUL|RAID_PLAYER_DISPELLABLE"

local function ReadDispels(unit, max)
    local list = {}
    local ok = pcall(function()
        for i = 1, 40 do
            local aura
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                aura = C_UnitAuras.GetAuraDataByIndex(unit, i, DISPELLABLE)
            else
                local name, icon, _, dispelName, duration, expirationTime = UnitAura(unit, i, "HARMFUL")
                if name then aura = { icon = icon, dispelName = dispelName, duration = duration, expirationTime = expirationTime } end
            end
            if not aura then break end
            -- Respaldo sin el filtro del cliente: la tabla de tu clase.
            if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
                local _, class = UnitClass("player")
                local dn = Readable(aura.dispelName)
                if not (dn and CLASS_DISPELS[class] and CLASS_DISPELS[class][dn]) then aura = false end
            end
            if aura then
                list[#list + 1] = aura
                if #list >= max then break end
            end
        end
    end)
    return ok and list or nil
end

local function PaintDispels(frame, list)
    local cfg, g = Cfg(frame), frame.Group
    local first
    for i = 1, cfg.dispelMax do
        local cell, aura = DispelCell(g, i), list and list[i]
        if aura and cfg.dispels then
            local color = DEBUFF_COLORS[Readable(aura.dispelName) or ""] or { 0.8, 0.15, 0.15 }
            first = first or color
            cell.icon:SetTexture(aura.icon)
            cell.border:SetColorTexture(color[1], color[2], color[3], 1)
            local duration, expiration = Readable(aura.duration), Readable(aura.expirationTime)
            if duration and expiration and duration > 0 then
                cell.cooldown:SetCooldown(expiration - duration, duration)
            else
                cell.cooldown:Clear()
            end
            cell:Show()
        else
            cell:Hide()
        end
    end
    return first
end

---------------------------------------------------------------------------
-- Tus beneficios sobre cada miembro y los que le faltan
---------------------------------------------------------------------------
-- El filtro PLAYER lo aplica el cliente: no hace falta mirar el origen (que
-- puede ser secreto). Cada beneficio se identifica por su hechizo o su nombre;
-- si ambos son secretos se muestra igual, pero no cuenta para "le falta".
local MINE = "HELPFUL|PLAYER"
local LONG_BUFF = 120   -- segundos: lo más corto (curas, efectos) no se exige a nadie

local function BuffKey(aura)
    local id = Readable(aura.spellId)
    if id then return "id" .. tostring(id) end
    local name = Readable(aura.name)
    return name and ("n" .. name) or nil
end

local function ReadMyBuffs(unit)
    local list = {}
    local ok = pcall(function()
        for i = 1, 40 do
            local aura
            if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
                aura = C_UnitAuras.GetAuraDataByIndex(unit, i, MINE)
            else
                local name, icon, _, _, duration, expirationTime, _, _, _, spellId = UnitAura(unit, i, MINE)
                if name then aura = { name = name, icon = icon, duration = duration, expirationTime = expirationTime, spellId = spellId } end
            end
            if not aura then break end
            local duration = Readable(aura.duration)
            list[#list + 1] = { key = BuffKey(aura), icon = aura.icon, duration = aura.duration,
                                expirationTime = aura.expirationTime,
                                long = duration ~= nil and (duration == 0 or duration >= LONG_BUFF) }
        end
    end)
    return ok and list or nil
end

-- Referencia del grupo: tus beneficios largos que lleva algún otro miembro
-- (así un aspecto o algo solo tuyo no marca a nadie como "sin tu beneficio").
local function ReferenceSet(kind)
    local keys, icons = {}, {}
    for _, frame in ipairs(G.frames[kind]) do
        local g = frame.Group
        if g and g.myBuffs and not g.isMe and frame:IsShown() then
            for _, b in ipairs(g.myBuffs) do
                if b.key and b.long and not icons[b.key] then
                    keys[#keys + 1], icons[b.key] = b.key, b.icon
                end
            end
        end
    end
    table.sort(keys)
    return keys, icons
end

local function PaintMyBuffs(frame, ref, refIcons)
    local cfg, g = Cfg(frame), frame.Group
    local entries = {}
    if cfg.myBuffs and g.myBuffs then
        local have, inRef = {}, {}
        for _, b in ipairs(g.myBuffs) do if b.key then have[b.key] = b end end
        -- Primero los de la referencia, siempre en el mismo orden en todos.
        for _, key in ipairs(ref) do
            inRef[key] = true
            if have[key] then
                entries[#entries + 1] = have[key]
            elseif cfg.myBuffMissing then
                entries[#entries + 1] = { icon = refIcons[key], missing = true }
            end
        end
        -- Luego el resto (cortos o sin nombre legible); en ti, solo los de la referencia.
        if not g.isMe then
            for _, b in ipairs(g.myBuffs) do
                if not (b.key and inRef[b.key]) then entries[#entries + 1] = b end
            end
        end
    end
    for i = 1, cfg.myBuffMax do
        local cell, b = BuffCell(g, i), entries[i]
        if b then
            cell.icon:SetTexture(b.icon)
            cell.icon:SetDesaturated(b.missing and true or false)
            if b.missing then
                cell.border:SetColorTexture(0.85, 0.1, 0.1, 1)
                cell.icon:SetAlpha(0.45)
                cell.cooldown:Clear()
            else
                cell.border:SetColorTexture(0, 0, 0, 1)
                cell.icon:SetAlpha(1)
                local duration, expiration = Readable(b.duration), Readable(b.expirationTime)
                if duration and expiration and duration > 0 then
                    cell.cooldown:SetCooldown(expiration - duration, duration)
                else
                    cell.cooldown:Clear()
                end
            end
            cell:Show()
        else
            cell:Hide()
        end
    end
end

-- Repinta los beneficios de todos los miembros de un tipo (la referencia es común).
G.buffSignature = {}
function G.PaintBuffs(kind)
    local ref, icons = ReferenceSet(kind)
    G.buffSignature[kind] = table.concat(ref, ",")
    for _, frame in ipairs(G.frames[kind]) do
        if frame.Group and frame:IsShown() and not frame.previewUnit then PaintMyBuffs(frame, ref, icons) end
    end
end

---------------------------------------------------------------------------
-- Actualización de los extras
---------------------------------------------------------------------------
local SAMPLES = {
    { name = "Aldren", class = "WARRIOR", role = "TANK", hp = 82, leader = true },
    { name = "Brisa", class = "PRIEST", role = "HEALER", hp = 100, dispel = "Magic" },
    { name = "Corvo", class = "MAGE", role = "DAMAGER", hp = 46 },
    { name = "Dalia", class = "HUNTER", role = "DAMAGER", hp = 64, dispel = "Curse", aggro = true },
    { name = "Eryn", class = "ROGUE", role = "DAMAGER", hp = 23, outOfRange = true },
    { name = "Fausto", class = "PALADIN", role = "HEALER", hp = 91 },
    { name = "Gala", class = "DRUID", role = "DAMAGER", hp = 77, dispel = "Poison" },
    { name = "Hugo", class = "SHAMAN", role = "DAMAGER", hp = 55 },
    { name = "Iris", class = "WARLOCK", role = "DAMAGER", hp = 100 },
    { name = "Joel", class = "WARRIOR", role = "TANK", hp = 68 },
}
-- Tus beneficios de ejemplo: a Corvo le falta uno y a Eryn (lejos) los dos.
local SAMPLE_BUFFS = {
    { key = "s1", icon = "Interface\\Icons\\Ability_TrueShot", duration = 0, long = true },
    { key = "s2", icon = "Interface\\Icons\\Ability_Mount_WhiteTiger", duration = 0, long = true },
}
local SAMPLE_REF = { "s1", "s2" }
local SAMPLE_REF_ICONS = { s1 = SAMPLE_BUFFS[1].icon, s2 = SAMPLE_BUFFS[2].icon }
local SAMPLE_MISSING = { Corvo = { s2 = true }, Eryn = { s1 = true, s2 = true } }
local SAMPLE_ICONS = {
    Magic = "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    Curse = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras",
    Poison = "Interface\\Icons\\Ability_Rogue_DualWeild",
}

local function PaintSample(frame)
    local cfg, g, s = Cfg(frame), frame.Group, SAMPLES[(frame.sampleIndex - 1) % #SAMPLES + 1]
    frame.Name:SetText(s.name)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[s.class]
    if c and cfg.healthColor == "class" then M.ColorBar(frame.Health, c.r, c.g, c.b) end
    frame.Health:SetMinMaxValues(0, 100)
    frame.Health:SetValue(s.hp)
    frame.HealthText:SetFormattedText("%d%%", s.hp)
    SetRole(g, s.role, cfg.roleIcon)
    g.leader:SetShown(cfg.leaderIcon and s.leader or false)
    local list = s.dispel and { { icon = SAMPLE_ICONS[s.dispel], dispelName = s.dispel, duration = 0 } } or {}
    local dispelColor = PaintDispels(frame, list)
    local outline = (cfg.dispelGlow and dispelColor) or (cfg.aggroBorder and s.aggro and { 1, 0.1, 0.1 }) or nil
    SetOutline(g, outline)
    frame.wrapper:SetAlpha((cfg.rangeFade and s.outOfRange) and cfg.rangeAlpha / 100 or 1)
    g.isMe, g.myBuffs = false, {}
    for _, b in ipairs(SAMPLE_BUFFS) do
        if not (SAMPLE_MISSING[s.name] or {})[b.key] then g.myBuffs[#g.myBuffs + 1] = b end
    end
    PaintMyBuffs(frame, SAMPLE_REF, SAMPLE_REF_ICONS)
end

function G.UpdateExtras(frame)
    local cfg, g = Cfg(frame), Decorate(frame)
    if frame.previewUnit then
        PaintSample(frame)
        return
    end
    local unit = frame.buiUnit
    if not UnitExists(unit) then return end
    local role = UnitGroupRolesAssigned and Readable(UnitGroupRolesAssigned(unit))
    SetRole(g, role, cfg.roleIcon)
    g.leader:SetShown(cfg.leaderIcon and Readable(UnitIsGroupLeader(unit)) == true)

    local dispelColor = PaintDispels(frame, cfg.dispels and ReadDispels(unit, cfg.dispelMax) or nil)
    local outline
    if cfg.dispelGlow and dispelColor then
        outline = dispelColor
    elseif cfg.aggroBorder and (Readable(UnitThreatSituation(unit)) or 0) >= 2 then
        outline = { 1, 0.1, 0.1 }
    elseif cfg.targetBorder and Readable(UnitIsUnit(unit, "target")) then
        outline = M.COLORS.accent
    end
    SetOutline(g, outline)

    -- Tus beneficios: si no se pueden leer ahora, se queda lo último leído.
    g.isMe = Readable(UnitIsUnit(unit, "player")) == true
    if cfg.myBuffs then
        g.myBuffs = ReadMyBuffs(unit) or g.myBuffs
    else
        g.myBuffs = nil
    end
    local kind = frame.groupKind
    local ref, icons = ReferenceSet(kind)
    if G.buffSignature[kind] == table.concat(ref, ",") then
        PaintMyBuffs(frame, ref, icons)
    else
        G.PaintBuffs(kind)   -- cambió lo que lleva el grupo: repintar a todos
    end
end

-- Atenuado fuera de rango (los miembros de grupo sí se pueden comprobar).
function G.UpdateRange(frame)
    if frame.previewUnit then return end
    local cfg, unit = Cfg(frame), frame.buiUnit
    local alpha = 1
    if cfg.rangeFade and unit ~= "player" and UnitInRange then
        local inRange, checked = UnitInRange(unit)
        if Readable(checked) and Readable(inRange) == false then alpha = cfg.rangeAlpha / 100 end
    end
    frame.wrapper:SetAlpha(alpha)
end

---------------------------------------------------------------------------
-- Colocación dentro de los contenedores
---------------------------------------------------------------------------
local function MemberHeight(cfg)
    return cfg.height + (cfg.castbar and (cfg.castHeight + 4) or 0)
end

---------------------------------------------------------------------------
-- Banda: orden, columnas y grupos visibles
---------------------------------------------------------------------------
local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }

-- Quién hay en la banda (o en la vista previa) con lo necesario para ordenar.
local function RaidMembers(frames)
    local list = {}
    for i, frame in ipairs(frames) do
        local m
        if frame.previewUnit then
            local s = SAMPLES[(i - 1) % #SAMPLES + 1]
            m = { subgroup = math.floor((i - 1) / 5) + 1, name = s.name, class = s.class, role = s.role }
        elseif frame:GetAttribute("unit") or frame.excluded then
            local name, subgroup, classToken
            if GetRaidRosterInfo then
                local n, _, sg, _, _, ct = GetRaidRosterInfo(i)
                name, subgroup, classToken = Readable(n), Readable(sg), Readable(ct)
            end
            if UnitExists(frame.buiUnit) or name then
                m = { subgroup = subgroup or math.floor((i - 1) / 5) + 1, name = name or "", class = classToken or "",
                      role = (UnitGroupRolesAssigned and Readable(UnitGroupRolesAssigned(frame.buiUnit))) or "NONE" }
            end
        end
        if m then
            m.frame, m.index = frame, i
            list[#list + 1] = m
        end
    end
    return list
end

local SORTS = {
    group = function(a, b) if a.subgroup ~= b.subgroup then return a.subgroup < b.subgroup end return a.index < b.index end,
    role = function(a, b)
        local ra, rb = ROLE_ORDER[a.role] or 4, ROLE_ORDER[b.role] or 4
        if ra ~= rb then return ra < rb end
        return a.index < b.index
    end,
    class = function(a, b) if a.class ~= b.class then return a.class < b.class end return a.name < b.name end,
    name = function(a, b) if a.name ~= b.name then return a.name < b.name end return a.index < b.index end,
}

-- Saca o devuelve a un miembro (grupos que no se quieren ver). Fuera de combate.
local function Exclude(frame, out)
    if frame.previewUnit then
        frame:SetShown(not out)
        return
    end
    if out and not frame.excluded then
        frame.excluded = true
        frame:SetAttribute("unit", nil)
    elseif not out and frame.excluded then
        frame.excluded = nil
        frame:SetAttribute("unit", frame.buiUnit)
    end
end

function G.ArrangeRaid(cfg, container, frames, w, h)
    local members = RaidMembers(frames)
    local shown = {}
    for _, m in ipairs(members) do
        local out = m.subgroup > cfg.maxGroups
        Exclude(m.frame, out)
        if not out then shown[#shown + 1] = m end
    end
    table.sort(shown, SORTS[cfg.sortBy] or SORTS.group)

    local stepX, stepY = w + cfg.spacing, h + cfg.spacing
    local maxCol, maxRow = 0, 0
    local function Place(m, col, row)
        m.frame:ClearAllPoints()
        m.frame:SetPoint("TOPLEFT", container, "TOPLEFT", col * stepX, -row * stepY)
        maxCol, maxRow = math.max(maxCol, col), math.max(maxRow, row)
    end
    if cfg.sortBy == "group" and cfg.groupColumns then
        -- Cada grupo en su propia columna, en el orden de los grupos.
        local slots = {}
        for _, m in ipairs(shown) do
            slots[m.subgroup] = (slots[m.subgroup] or 0) + 1
            Place(m, m.subgroup - 1, slots[m.subgroup] - 1)
        end
    else
        local columns = math.max(1, cfg.columns)
        local perColumn = math.max(1, math.ceil(cfg.maxGroups * 5 / columns))
        for k, m in ipairs(shown) do
            if cfg.fillBy == "rows" then
                Place(m, (k - 1) % columns, math.floor((k - 1) / columns))
            else
                Place(m, math.floor((k - 1) / perColumn), (k - 1) % perColumn)
            end
        end
    end
    container:SetSize((maxCol + 1) * stepX - cfg.spacing, (maxRow + 1) * stepY - cfg.spacing)
end

function G.Arrange(kind)
    ns.AfterCombat("GroupArrange" .. kind, function()
        local cfg, container, frames = G.db.layouts[kind], G.containers[kind], G.frames[kind]
        if not container then return end
        local w, h = cfg.width, MemberHeight(cfg)
        if kind == "party" then
            local y = 0
            for _, frame in ipairs(frames) do
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
                y = y + h + cfg.spacing
            end
            container:SetSize(w + (cfg.dispelPos == "outside" and (cfg.dispelSize + 2) * cfg.dispelMax + 4 or 0), math.max(h, y - cfg.spacing))
        else
            G.ArrangeRaid(cfg, container, frames, w, h)
        end
    end)
end

function G.ApplyKind(kind)
    ns.AfterCombat("GroupApply" .. kind, function()
        for _, frame in ipairs(G.frames[kind]) do
            UF.ApplyLayout(frame)
            if frame:IsShown() then UF.UpdateAll(frame) end
        end
        G.Arrange(kind)
    end)
end

function G.ApplyAll()
    for kind in pairs(G.KINDS) do G.ApplyKind(kind) end
end

---------------------------------------------------------------------------
-- Vista previa: miembros de ejemplo (grupo: 5, banda: 20)
---------------------------------------------------------------------------
G.preview = {}

local function SetPreviewNow(kind, on)
    local container = G.containers[kind]
    if not container then return end
    G.preview[kind] = on or nil
    if on then
        UnregisterStateDriver(container, "visibility")
        container:Show()
    else
        RegisterStateDriver(container, "visibility", G.KINDS[kind].driver)
    end
    local count = kind == "party" and 5 or 20
    for i, frame in ipairs(G.frames[kind]) do
        if on then
            UnregisterUnitWatch(frame)
            if i <= count then
                frame.previewUnit = "player"
                frame.sampleIndex = i
                frame:Show()
                UF.UpdateAll(frame)
            else
                frame:Hide()
            end
        elseif frame.previewUnit or not frame:IsShown() then
            frame.previewUnit = nil
            RegisterUnitWatch(frame)
            if frame:IsShown() then UF.UpdateAll(frame) end
        end
    end
    G.Arrange(kind)
end

function G.SetPreview(kind, on)
    ns.AfterCombat("GroupPreview" .. kind, function() SetPreviewNow(kind, on) end)
end

function G.TogglePreview(kind)
    G.SetPreview(kind, not G.preview[kind])
end

function G.RefreshAll()
    for _, frames in pairs(G.frames) do
        for _, frame in ipairs(frames) do
            if frame:IsVisible() and not frame.previewUnit then UF.UpdateAll(frame) end
        end
    end
end

-- /bui grupo: estado de los contenedores y de cada miembro.
function G.Diagnose()
    ns.Print("diagnóstico de grupo:")
    print(("  en combate: %s · en grupo: %s · en banda: %s"):format(tostring(InCombatLockdown()),
        tostring(IsInGroup and IsInGroup()), tostring(IsInRaid and IsInRaid())))
    for kind, container in pairs(G.containers) do
        print(("  %s: mostrado=%s visible=%s vista previa=%s"):format(kind, tostring(container:IsShown()),
            tostring(container:IsVisible()), tostring(G.preview[kind] or false)))
        for i, frame in ipairs(G.frames[kind]) do
            if i <= 5 then
                local unit = frame.buiUnit
                print(("    %s: existe=%s mostrado=%s visible=%s alfa=%.2f"):format(unit, tostring(UnitExists(unit)),
                    tostring(frame:IsShown()), tostring(frame:IsVisible()), frame.wrapper:GetAlpha()))
            end
        end
    end
end
ns.RegisterCommand("grupo", function() G.Diagnose() end, "diagnóstico de los marcos de grupo")

---------------------------------------------------------------------------
-- Activación
---------------------------------------------------------------------------
local BLIZZARD = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer",
    "PartyMemberFrame1", "PartyMemberFrame2", "PartyMemberFrame3", "PartyMemberFrame4" }
-- Con el estilo de mando, la cruceta recorre los marcos de grupo de Blizzard
-- para elegir aliados: quedan invisibles pero vivos (ver Blizzard.lua).
local PAD_VISIBLE = { padVisible = true }

local function Units(kind)
    local units = {}
    if kind == "party" then
        if G.db.layouts.party.showPlayer then units[1] = "player" end
        for i = 1, 4 do units[#units + 1] = "party" .. i end
    else
        for i = 1, 40 do units[i] = "raid" .. i end
    end
    return units
end

function G:OnEnable()
    if not UF.active then
        ns.Print("grupo: el módulo de marcos de unidad está desactivado; los marcos de grupo lo necesitan.")
        return
    end
    for kind, info in pairs(G.KINDS) do
        local container = CreateFrame("Frame", "BlazzitoUI_" .. kind .. "Container", UIParent, "SecureHandlerStateTemplate")
        container:SetSize(10, 10)
        RegisterStateDriver(container, "visibility", info.driver)
        G.containers[kind] = container
        for i, unit in ipairs(Units(kind)) do
            local frame = UF.Spawn(unit, {
                cfg = G.db.layouts[kind], info = { label = info.label },
                parent = container, name = "BlazzitoUI_" .. kind .. i, keep = false,
            })
            frame.groupFrame, frame.groupKind = true, kind
            G.frames[kind][i] = frame
            LayoutExtras(frame)
        end
        ns.Movers.Register(container, "group_" .. kind, info.label, info.pos, G.db.positions, {
            onUnlock = function() G.SetPreview(kind, true) end,
            onLock = function() G.SetPreview(kind, false) end,
            -- Tamaño de cada miembro desde el modo mover.
            getSize = function() return G.db.layouts[kind].width, G.db.layouts[kind].height end,
            setSize = function(w, h)
                G.db.layouts[kind].width = math.max(50, math.min(300, w))
                G.db.layouts[kind].height = math.max(14, math.min(80, h))
                G.ApplyKind(kind)
            end,
        })
        G.Arrange(kind)
    end

    -- Extras: tras cada colocación y repintado de un miembro.
    table.insert(UF.hooks.layout, function(frame) if frame.groupFrame then LayoutExtras(frame) end end)
    table.insert(UF.hooks.update, function(frame) if frame.groupFrame then G.UpdateExtras(frame) end end)

    if G.db.hideBlizzard then
        for _, name in ipairs(BLIZZARD) do ns.HideBlizzardFrame(name, PAD_VISIBLE) end
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PARTY_LEADER_CHANGED",
                             "PLAYER_TARGET_CHANGED", "UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE" }) do
        pcall(events.RegisterEvent, events, event)
    end
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_REGEN_DISABLED" then
            -- Última ocasión antes del bloqueo: una vista previa abierta dejaría
            -- los contenedores sin su condición de grupo todo el combate.
            for kind in pairs(G.KINDS) do
                if G.preview[kind] then SetPreviewNow(kind, false) end
            end
            return
        end
        if event == "GROUP_ROSTER_UPDATE" then
            G.Arrange("raid")
            -- Los marcos de Blizzard pueden crearse al formar el grupo.
            if G.db.hideBlizzard then
                for _, name in ipairs(BLIZZARD) do ns.HideBlizzardFrame(name, PAD_VISIBLE) end
            end
            -- Los marcos seguros aparecen solos (también en combate), pero los
            -- datos del nuevo miembro pueden llegar un poco después: se repintan.
            C_Timer.After(0.5, G.RefreshAll)
        end
        for _, frames in pairs(G.frames) do
            for _, frame in ipairs(frames) do
                if frame:IsShown() and (unit == nil or frame.buiUnit == unit or event == "PLAYER_TARGET_CHANGED") then
                    G.UpdateExtras(frame)
                end
            end
        end
    end)

    -- Al entrar al mundo o recargar, los datos de los compañeros (clase,
    -- nombre) pueden llegar después de que el marco se pinte: dos repasos.
    ns.On("PLAYER_ENTERING_WORLD", function()
        C_Timer.After(0.5, function() G.RefreshAll() end)
        C_Timer.After(2, function() G.RefreshAll() end)
    end)

    -- Rango: 4 veces por segundo, solo miembros visibles.
    local elapsed = 0
    events:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.25 then return end
        elapsed = 0
        for _, frames in pairs(G.frames) do
            for _, frame in ipairs(frames) do
                if frame:IsShown() then G.UpdateRange(frame) end
            end
        end
    end)
end
