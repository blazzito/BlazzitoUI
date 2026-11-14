-- Blazzito_Auras: beneficios y perjuicios sobre los marcos de BlazzitoUI.
-- El ancho de las barras se parte en dos mitades: una para beneficios y otra
-- para perjuicios. Cada mitad se ve como iconos o como barras.
--
-- Dos formas de dibujar:
--  * Motor (modo iconos): contenedores de auras del cliente (AuraContainer).
--    El cliente decide qué mostrar y lo pinta, aunque las auras sean secretas;
--    nuestro código solo crea las piezas de cada botón una vez.
--  * Lua (modo barras, vista previa y respaldo): leemos las auras y pintamos
--    icono, nombre, tiempo y barra. Si el cliente no deja leerlas (contenido
--    restringido), ese marco vuelve a los iconos del motor.
local ns = BlazzitoUI
if not ns then return end
local UF = ns.UnitFrames
if not UF then return end

local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret

local MEDIA = "Interface\\AddOns\\Blazzito_Auras\\Media\\"
local HALF_GAP = 4

local function UnitDefaults(overrides)
    local d = {
        enabled = true,
        mode = "icons",            -- icons | bars
        position = "above",        -- above | below
        swap = false,              -- perjuicios a la izquierda
        size = 22, spacing = 2, maxPerSide = 8, barHeight = 16,
        onlyMyBuffs = false, onlyMyDebuffs = false,
        showTime = true, showStacks = true,
        dispelMark = "diamond",    -- diamond | star | glow | none
        dispelColor = { 0.25, 0.60, 1.00 },
        typeBorder = true,         -- borde del color del tipo de perjuicio
    }
    for key, value in pairs(overrides) do d[key] = value end
    return d
end

local A = ns.NewModule("Auras", "Auras", {
    -- Respaldo con los iconos del contenedor del motor cuando no se pueden leer
    -- las auras. En algunos clientes ese contenedor se coloca mal: apagado por defecto.
    style = { engineFallback = false },
    -- Beneficios y perjuicios de Blizzard junto al minimapa.
    buffFrame = { skin = true, shape = "square", border = 1, fontSize = 11 },
    units = {
        player = UnitDefaults({}),
        target = UnitDefaults({ onlyMyDebuffs = false }),
        targettarget = UnitDefaults({ enabled = false, size = 16, maxPerSide = 4 }),
        pet = UnitDefaults({ enabled = false, size = 16, maxPerSide = 4 }),
        focus = UnitDefaults({ size = 18, maxPerSide = 6 }),
        focustarget = UnitDefaults({ enabled = false, size = 16, maxPerSide = 4 }),
    },
})
ns.Auras = A
A.displays = {}
A.editing = "player"

---------------------------------------------------------------------------
-- Datos
---------------------------------------------------------------------------
local DEBUFF_COLORS = {
    Magic = { 0.20, 0.60, 1.00 }, Curse = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 }, Poison = { 0.00, 0.60, 0.00 },
}
local DEBUFF_DEFAULT = { 0.80, 0.15, 0.15 }
local BUFF_BAR = { 0.30, 0.65, 0.35 }

-- Respaldo si el cliente no sabe filtrar "lo que yo puedo disipar".
local CLASS_DISPELS = {
    PRIEST = { Magic = true, Disease = true }, PALADIN = { Magic = true, Poison = true, Disease = true },
    DRUID = { Curse = true, Poison = true }, SHAMAN = { Poison = true, Disease = true }, MAGE = { Curse = true },
}
local DISPELLABLE_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"

local function Filter(kind, onlyMine)
    local base = kind == "buffs" and "HELPFUL" or "HARMFUL"
    return onlyMine and (base .. "|PLAYER") or base
end

local function GetAura(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    end
    local name, icon, count, dispelName, duration, expirationTime = UnitAura(unit, index, filter)
    if not name then return nil end
    return { name = name, icon = icon, applications = count, dispelName = dispelName,
             duration = duration, expirationTime = expirationTime }
end

-- ¿Lo puede disipar el jugador? Primero pregunta al cliente (el mismo filtro
-- que usa Blizzard); si no responde, mira la tabla de clases.
local function IsDispellable(unit, aura)
    if C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID and not IsSecret(aura.auraInstanceID)
        and aura.auraInstanceID ~= nil then
        local ok, filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, aura.auraInstanceID, DISPELLABLE_FILTER)
        if ok and not IsSecret(filteredOut) and filteredOut ~= nil then
            return filteredOut == false
        end
    end
    local _, class = UnitClass("player")
    local dispelName = Readable(aura.dispelName)
    return (dispelName and CLASS_DISPELS[class] and CLASS_DISPELS[class][dispelName]) and true or false
end

-- Lista de auras de una mitad, con las disipables primero. nil si el cliente
-- no deja leerlas ahora (se usarán los iconos del motor).
-- Campos que se usan. Se copian a una tabla propia: la que devuelve el
-- cliente puede venir protegida (enemigos en combate) y no se toca.
local AURA_FIELDS = { "name", "icon", "applications", "dispelName", "duration", "expirationTime",
                      "auraInstanceID", "spellId", "sourceUnit", "isStealable" }

local function Copy(aura)
    local copy = {}
    for _, key in ipairs(AURA_FIELDS) do
        local ok, value = pcall(function() return aura[key] end)
        if ok then copy[key] = value end
    end
    return copy
end

A.readErrors = {}

-- "Auras cannot be accessed when secret while tainted": el juego no deja a
-- los addons leer esas auras; solo el contenedor del motor puede pintarlas.
function A.IsSecretError(err)
    return type(err) == "string" and err:find("secret", 1, true) ~= nil
end

local function Collect(unit, kind, cfg)
    local filter = Filter(kind, kind == "buffs" and cfg.onlyMyBuffs or kind == "debuffs" and cfg.onlyMyDebuffs)
    local list = {}
    -- Cada aura por separado: si una no se puede leer, las demás sí se pintan.
    local failures, lastError = 0, nil
    for i = 1, 40 do
        local ok, aura = pcall(GetAura, unit, i, filter)
        if not ok then
            failures, lastError = failures + 1, aura
            if failures >= 3 then break end
        elseif not aura then
            break
        else
            local copy = Copy(aura)
            copy.index, copy.filter = i, filter
            if kind == "debuffs" then
                local okD, dispellable = pcall(IsDispellable, unit, copy)
                copy.dispellable = okD and dispellable or false
            end
            list[#list + 1] = copy
        end
    end
    A.readErrors[unit .. ":" .. kind] = lastError
    if lastError and #list == 0 then
        -- Auras "secretas" (enemigos en combate): es lo esperado en este
        -- cliente y las pinta el motor. Cualquier otro fallo se avisa una vez.
        if not A.IsSecretError(lastError) and A.Report then
            A.Report(kind .. " de " .. unit .. " (lectura)", lastError)
        end
        return nil
    end
    if kind == "debuffs" then
        local dispel, rest = {}, {}
        for _, aura in ipairs(list) do
            table.insert(aura.dispellable and dispel or rest, aura)
        end
        for _, aura in ipairs(rest) do dispel[#dispel + 1] = aura end
        list = dispel
    end
    while #list > cfg.maxPerSide do table.remove(list) end
    return list
end

-- Auras de ejemplo para la vista previa (configuración abierta o modo mover).
local SAMPLES = {
    buffs = {
        { name = "Palabra de poder: entereza", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", duration = 1800 },
        { name = "Marca de lo salvaje", icon = "Interface\\Icons\\Spell_Nature_Regeneration", duration = 1800, applications = 0 },
        { name = "Bendición de poderío", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", duration = 300 },
        { name = "Escudo de relámpagos", icon = "Interface\\Icons\\Spell_Nature_LightningShield", duration = 600, applications = 3 },
    },
    debuffs = {
        { name = "Palabra de las Sombras: dolor", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", duration = 18, dispelName = "Magic", dispellable = true },
        { name = "Veneno mortal", icon = "Interface\\Icons\\Ability_Rogue_DualWeild", duration = 12, dispelName = "Poison", applications = 4 },
        { name = "Maldición de agonía", icon = "Interface\\Icons\\Spell_Shadow_CurseOfSargeras", duration = 24, dispelName = "Curse" },
    },
}

local function Samples(kind, cfg)
    local now, list = GetTime(), {}
    for i, sample in ipairs(SAMPLES[kind]) do
        if i > cfg.maxPerSide then break end
        local aura = {}
        for k, v in pairs(sample) do aura[k] = v end
        aura.expirationTime = now + aura.duration * (0.35 + 0.15 * i)
        aura.sample = true
        list[#list + 1] = aura
    end
    return list
end

---------------------------------------------------------------------------
-- Piezas comunes de un botón o celda
---------------------------------------------------------------------------
-- Marca de "lo puedes disipar": rombo o estrella en la esquina, o un marco
-- brillante de 2 px alrededor del icono.
local GLOW_EDGES = {
    { "TOPLEFT", -2, 2, "TOPRIGHT", 2, 2, "height" },
    { "BOTTOMLEFT", -2, -2, "BOTTOMRIGHT", 2, -2, "height" },
    { "TOPLEFT", -2, 2, "BOTTOMLEFT", -2, -2, "width" },
    { "TOPRIGHT", 2, 2, "BOTTOMRIGHT", 2, -2, "width" },
}

local function BuildMarker(parent, cfg, iconSize)
    local mark = cfg.dispelMark
    if mark == "none" then return nil end
    local c = cfg.dispelColor
    if mark == "glow" then
        local glow = {}
        for i, e in ipairs(GLOW_EDGES) do
            local edge = parent:CreateTexture(nil, "OVERLAY", nil, 6)
            edge:SetColorTexture(c[1], c[2], c[3], 0.95)
            edge:SetPoint(e[1], parent, e[1], e[2], e[3])
            edge:SetPoint(e[4], parent, e[4], e[5], e[6])
            if e[7] == "height" then edge:SetHeight(2) else edge:SetWidth(2) end
            glow[i] = edge
        end
        return glow
    end
    local size = math.max(8, math.floor(iconSize * 0.55))
    local tex = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetTexture(MEDIA .. (mark == "star" and "mark_star" or "mark_diamond"))
    tex:SetVertexColor(c[1], c[2], c[3], 1)
    tex:SetSize(size, size)
    tex:SetPoint("CENTER", parent, "TOPRIGHT", -2, -2)
    return { tex }
end

local function ShowMarker(marker, shown)
    if not marker then return end
    for _, piece in ipairs(marker) do piece:SetShown(shown) end
end

local function Font(parent, size, justify)
    local fs = M.Font(parent, size, justify)
    fs:SetFont(M.FONT, size, "OUTLINE")
    return fs
end

---------------------------------------------------------------------------
-- Motor: contenedor de auras del cliente (solo modo iconos)
---------------------------------------------------------------------------
function A.EngineAvailable()
    if A.engine ~= nil then return A.engine end
    pcall(function()
        if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end)
    local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    A.engine = (ok and probe and probe.AddAuraGroup and probe.SetUnit) and true or false
    if ok and probe then probe:Hide() end
    return A.engine
end

local function CallFirst(obj, names, ...)
    for _, name in ipairs(names) do
        if obj[name] then return pcall(obj[name], obj, ...) end
    end
end

-- Tras declarar un grupo: activarlo, fijar su tope de iconos y su
-- disposición. En este cliente los grupos pueden nacer apagados (EllesmereUI
-- los enciende siempre así, con SetAuraGroupEnabled + MaxFrameCount).
local function EnableGroup(container, key, cap, layout)
    if container.SetAuraGroupEnabled then pcall(container.SetAuraGroupEnabled, container, key, true) end
    if container.SetAuraGroupMaxFrameCount then pcall(container.SetAuraGroupMaxFrameCount, container, key, cap) end
    if layout and container.SetAuraGroupLayout then pcall(container.SetAuraGroupLayout, container, key, layout) end
end

-- Las piezas de cada botón solo se pueden crear aquí: el cliente llama a esta
-- función una vez por botón, y después (con auras secretas) ya no deja tocarlos.
local function EngineInitializer(cfg, kind, dispel)
    return function(button)
        -- Antes los fallos aquí se perdían en silencio (y el botón quedaba
        -- vacío): ahora se anotan para /bui auras.
        local ok, err = pcall(function()
            -- El motor solo coloca los botones: el tamaño lo pone el addon.
            -- Sin esto miden 0x0 y no se ve nada (aviso de EllesmereUI).
            button:SetSize(cfg.size, cfg.size)
            pcall(button.SetMouseClickEnabled, button, false)
            local border = button:CreateTexture(nil, "BACKGROUND")
            border:SetPoint("TOPLEFT", -1, 1)
            border:SetPoint("BOTTOMRIGHT", 1, -1)
            border:SetColorTexture(0, 0, 0, 1)
            local icon = button:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints()
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            cd:SetAllPoints()
            cd:SetDrawEdge(false)
            cd:SetHideCountdownNumbers(true)
            local carrier = CreateFrame("Frame", nil, button)
            carrier:SetAllPoints()
            carrier:SetFrameLevel(cd:GetFrameLevel() + 2)
            carrier:EnableMouse(false)
            local stack = Font(carrier, math.max(8, math.floor(cfg.size * 0.45)), "RIGHT")
            stack:SetPoint("BOTTOMRIGHT", 1, 0)
            local time = Font(carrier, math.max(8, math.floor(cfg.size * 0.42)), "CENTER")
            time:SetPoint("TOP", carrier, "BOTTOM", 0, -1)

            button:SetIcon(icon)
            button:SetDurationCooldown(cd)
            if cfg.showStacks then button:SetApplicationCount(stack, {}) else stack:Hide() end
            -- En iconos el tiempo lo pinta el contador del enfriamiento (OmniCC o
            -- el de Blizzard) dentro del icono: no se repite debajo.
            time:Hide()
            -- Borde del color del tipo (magia, maldición...), pintado por el cliente.
            if kind == "debuffs" and cfg.typeBorder and button.AddDispelTypeTexture
                and Enum and Enum.CustomAuraButtonDispelTypeTextureStyle then
                local typed = button:CreateTexture(nil, "BACKGROUND", nil, 1)
                typed:SetPoint("TOPLEFT", -1, 1)
                typed:SetPoint("BOTTOMRIGHT", 1, -1)
                pcall(button.AddDispelTypeTexture, button, typed, {
                    style = Enum.CustomAuraButtonDispelTypeTextureStyle.Border,
                    showWhenHarmful = true, showWhenHelpful = false,
                })
            end
            -- El grupo de disipables lleva su marca siempre (el cliente oculta el
            -- botón entero cuando no tiene aura).
            if dispel then ShowMarker(BuildMarker(carrier, cfg, cfg.size), true) end
        end)
        if not ok and A.Report then A.Report("botón del motor (" .. kind .. ")", err) end
    end
end

local function BuildEngineHalf(half, unit, kind, cfg, layout)
    local container = CreateFrame("AuraContainer", nil, half.area, "CustomAuraContainerTemplate")
    container:SetPoint(layout.corner, half.area, layout.corner)
    container:SetSize(1, 1)
    CallFirst(container, { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" }, layout.corner)
    local FD = AnchorUtil and AnchorUtil.FlowDirection
    if FD then
        CallFirst(container, { "SetFlowLayoutGrowthDirection", "SetAuraLayoutGrowthDirection" },
            layout.growLeft and FD.Left or FD.Right, layout.growUp and FD.Up or FD.Down)
    end
    CallFirst(container, { "SetFlowLayoutMaximumLineSize", "SetAuraLayoutRowWidth" }, layout.width)
    local groupLayout = {
        elementWidth = cfg.size, elementHeight = cfg.size,
        elementSpacing = cfg.spacing, lineSpacing = cfg.spacing,
        -- Sin groupSpacing: el motor ya deja elementSpacing tras cada icono y
        -- lo duplicaría (aviso de EllesmereUI, que usa este mismo motor).
    }
    local mine = (kind == "buffs" and cfg.onlyMyBuffs) or (kind == "debuffs" and cfg.onlyMyDebuffs)
    if kind == "buffs" then
        container:AddAuraGroup("buffs", Filter("buffs", mine), {
            maxFrameCount = cfg.maxPerSide, layout = groupLayout,
            initializeFrame = EngineInitializer(cfg, kind, false),
        })
        EnableGroup(container, "buffs", cfg.maxPerSide, groupLayout)
    else
        -- Primero lo que puedes disipar (con marca), luego el resto.
        local base = mine and "HARMFUL|PLAYER" or "HARMFUL"
        container:AddAuraGroup("dispel", base .. "|RAID_PLAYER_DISPELLABLE", {
            maxFrameCount = cfg.maxPerSide, layout = groupLayout,
            initializeFrame = EngineInitializer(cfg, kind, cfg.dispelMark ~= "none"),
        })
        container:AddAuraGroup("debuffs", base .. "|!RAID_PLAYER_DISPELLABLE", {
            maxFrameCount = cfg.maxPerSide, layout = groupLayout,
            initializeFrame = EngineInitializer(cfg, kind, false),
        })
        EnableGroup(container, "dispel", cfg.maxPerSide, groupLayout)
        EnableGroup(container, "debuffs", cfg.maxPerSide, groupLayout)
    end
    container:SetUnit(unit)
    container:UpdateAllAuras()
    return container
end

---------------------------------------------------------------------------
-- Lua: celdas que pintamos nosotros (barras, vista previa, respaldo)
---------------------------------------------------------------------------
local function OnCellEnter(cell)
    local aura = cell.aura
    if not aura or aura.sample then return end
    GameTooltip:SetOwner(cell, "ANCHOR_BOTTOMRIGHT")
    if not pcall(GameTooltip.SetUnitAura, GameTooltip, cell.unit, aura.index, aura.filter) then
        GameTooltip:SetText(aura.name)
    end
    GameTooltip:Show()
end

local function NewCell(half, mode, cfg)
    local cell = CreateFrame("Frame", nil, half.area)
    cell.mode = mode
    cell.iconBox = CreateFrame("Frame", nil, cell)
    cell.border = cell.iconBox:CreateTexture(nil, "BACKGROUND")
    cell.border:SetPoint("TOPLEFT", -1, 1)
    cell.border:SetPoint("BOTTOMRIGHT", 1, -1)
    cell.icon = cell.iconBox:CreateTexture(nil, "ARTWORK")
    cell.icon:SetAllPoints()
    cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cell.cooldown = CreateFrame("Cooldown", nil, cell.iconBox, "CooldownFrameTemplate")
    cell.cooldown:SetAllPoints()
    cell.cooldown:SetDrawEdge(false)
    cell.cooldown:SetHideCountdownNumbers(true)
    cell.carrier = CreateFrame("Frame", nil, cell.iconBox)
    cell.carrier:SetAllPoints()
    cell.carrier:SetFrameLevel(cell.cooldown:GetFrameLevel() + 2)
    cell.stack = Font(cell.carrier, 9, "RIGHT")
    cell.stack:SetPoint("BOTTOMRIGHT", 1, 0)
    cell.marker = BuildMarker(cell.carrier, cfg, mode == "bars" and cfg.barHeight or cfg.size)

    if mode == "bars" then
        cell.bar = M.StatusBar(cell)
        cell.bar:SetPoint("TOPLEFT", cell.iconBox, "TOPRIGHT", 2, 0)
        cell.bar:SetPoint("BOTTOMRIGHT")
        cell.name = Font(cell.bar, 10, "LEFT")
        cell.name:SetPoint("LEFT", 4, 0)
        cell.time = Font(cell.bar, 10, "RIGHT")
        cell.time:SetPoint("RIGHT", -4, 0)
        cell.name:SetPoint("RIGHT", cell.time, "LEFT", -4, 0)
    else
        cell.time = Font(cell, 9, "CENTER")
        cell.time:SetPoint("TOP", cell.iconBox, "BOTTOM", 0, -1)
    end
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", OnCellEnter)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cell
end

local function FormatTime(seconds)
    if seconds >= 3600 then return string.format("%dh", math.ceil(seconds / 3600)) end
    if seconds >= 90 then return string.format("%dm", math.ceil(seconds / 60)) end
    if seconds >= 10 then return string.format("%d", math.ceil(seconds)) end
    return string.format("%.1f", seconds)
end

-- Tiempo restante legible, o nil (permanente o secreto).
local function Remaining(aura)
    local duration, expiration = Readable(aura.duration), Readable(aura.expirationTime)
    if not (duration and expiration) or duration <= 0 then return nil end
    return math.max(0, expiration - GetTime()), duration
end

-- Duración secreta (enemigos en combate): el cliente da un "objeto de
-- duración" que el enfriamiento sabe dibujar sin que el addon vea el número.
local function SecretTimer(cell, aura, unit)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDuration and cell.cooldown.SetCooldownFromDurationObject) then return false end
    if aura.auraInstanceID == nil or not unit then return false end
    local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
    if not ok or not durationObject then return false end
    return pcall(cell.cooldown.SetCooldownFromDurationObject, cell.cooldown, durationObject) and true or false
end

local function PaintCell(cell, aura, kind, cfg, unit)
    cell.aura, cell.unit = aura, unit
    cell.icon:SetTexture(aura.icon)
    local color
    if kind == "debuffs" then
        color = DEBUFF_COLORS[Readable(aura.dispelName) or ""] or DEBUFF_DEFAULT
    else
        color = BUFF_BAR
    end
    if kind == "debuffs" and cfg.typeBorder then
        cell.border:SetColorTexture(color[1], color[2], color[3], 1)
    else
        cell.border:SetColorTexture(0, 0, 0, 1)
    end
    ShowMarker(cell.marker, kind == "debuffs" and aura.dispellable and true or false)

    local stacks = Readable(aura.applications)
    cell.stack:SetShown(cfg.showStacks and stacks ~= nil and stacks > 1)
    if stacks then cell.stack:SetText(stacks) end

    local remaining, duration = Remaining(aura)
    if cell.mode == "bars" then
        cell.name:SetText(aura.name)
        M.ColorBar(cell.bar, color[1], color[2], color[3])
        cell.bar:SetMinMaxValues(0, duration or 1)
        cell.bar:SetValue(remaining or 1)
    elseif remaining then
        cell.cooldown:SetCooldown(Readable(aura.expirationTime) - duration, duration)
    elseif not SecretTimer(cell, aura, unit) then
        cell.cooldown:Clear()
    end
    -- El tiempo en texto solo en barras; en iconos ya lo pinta el contador
    -- del enfriamiento (OmniCC o el de Blizzard) dentro del icono.
    local showTime = cell.mode == "bars" and cfg.showTime and remaining ~= nil
    cell.time:SetShown(showTime)
    if showTime then cell.time:SetText(FormatTime(remaining)) end
    cell:Show()
end

local function PlaceCells(half, mode, cfg, layout, count)
    for i = 1, count do
        local cell = half.cells[i]
        cell:ClearAllPoints()
        local x, y
        if mode == "bars" then
            cell:SetSize(layout.width, cfg.barHeight)
            cell.iconBox:ClearAllPoints()
            cell.iconBox:SetSize(cfg.barHeight, cfg.barHeight)
            cell.iconBox:SetPoint("LEFT")
            x, y = 0, (i - 1) * (cfg.barHeight + cfg.spacing)
        else
            local step = cfg.size + cfg.spacing
            local perRow = math.max(1, math.floor((layout.width + cfg.spacing) / step))
            local col, row = (i - 1) % perRow, math.floor((i - 1) / perRow)
            cell:SetSize(cfg.size, cfg.size)
            cell.iconBox:ClearAllPoints()
            cell.iconBox:SetAllPoints()
            x, y = col * step, row * (cfg.size + cfg.spacing)
        end
        cell:SetPoint(layout.corner, half.area, layout.corner,
            layout.growLeft and -x or x, layout.growUp and y or -y)
    end
end

---------------------------------------------------------------------------
-- Visualización por marco
---------------------------------------------------------------------------
local function Display(frame)
    local d = A.displays[frame.buiUnit]
    if d then return d end
    d = { frame = frame, unit = frame.buiUnit, halves = {} }
    d.holder = CreateFrame("Frame", nil, frame)
    d.holder:SetSize(1, 1)
    for _, kind in ipairs({ "buffs", "debuffs" }) do
        local half = { kind = kind, cells = {}, cellMode = nil }
        half.area = CreateFrame("Frame", nil, d.holder)
        half.area:SetSize(1, 1)
        d.halves[kind] = half
    end
    -- Tiempo restante de las celdas Lua.
    local elapsed = 0
    d.holder:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.1 then return end
        elapsed = 0
        A.Tick(d)
    end)
    A.displays[frame.buiUnit] = d
    return d
end

local function Cfg(d) return A.db.units[d.unit] end

-- Dónde va cada mitad, según el marco y la configuración.
local function HalfLayout(d, kind)
    local frame, cfg, ucfg = d.frame, Cfg(d), UF.Cfg(d.frame)
    local width = ucfg.width
    local halfWidth = math.floor((width - HALF_GAP) / 2)
    local left = (kind == "buffs") ~= (cfg.swap and true or false)
    local up = cfg.position ~= "below"
    -- Cada mitad crece desde su borde exterior.
    return {
        width = halfWidth,
        left = left,
        growLeft = not left,
        growUp = up,
        corner = (up and "BOTTOM" or "TOP") .. (left and "LEFT" or "RIGHT"),
    }
end

-- Firma de los ajustes que obligan a rehacer un contenedor del motor.
local function EngineSignature(cfg, kind)
    return table.concat({ cfg.size, cfg.spacing, cfg.maxPerSide, tostring(cfg.onlyMyBuffs), tostring(cfg.onlyMyDebuffs),
        tostring(cfg.showTime), tostring(cfg.showStacks), cfg.dispelMark, table.concat(cfg.dispelColor, ","),
        tostring(cfg.typeBorder), cfg.position, tostring(cfg.swap), kind }, ";")
end

function A.Layout(frame)
    -- Solo los marcos principales (los de grupo tienen sus propios disipables).
    if not A.active or not A.db.units[frame.buiUnit] then return end
    local d = Display(frame)
    local cfg, ucfg = Cfg(d), UF.Cfg(frame)
    d.holder:SetShown(cfg.enabled)
    if not cfg.enabled then return end

    local bars = frame.Bars
    d.holder:ClearAllPoints()
    if cfg.position == "below" then
        local castSpace = (ucfg.castbar and (ucfg.castHeight + 4) or 0) + (UF.ComboSpace and UF.ComboSpace(frame, "below") or 0)
        d.holder:SetPoint("TOPLEFT", bars, "BOTTOMLEFT", 0, -(4 + castSpace))
        d.holder:SetPoint("TOPRIGHT", bars, "BOTTOMRIGHT", 0, -(4 + castSpace))
    else
        local comboSpace = UF.ComboSpace and UF.ComboSpace(frame, "above") or ((frame.Combo and ucfg.combo) and 9 or 0)
        d.holder:SetPoint("BOTTOMLEFT", bars, "TOPLEFT", 0, 4 + comboSpace)
        d.holder:SetPoint("BOTTOMRIGHT", bars, "TOPRIGHT", 0, 4 + comboSpace)
    end

    for kind, half in pairs(d.halves) do
        local layout = HalfLayout(d, kind)
        half.layout = layout
        half.area:ClearAllPoints()
        half.area:SetSize(layout.width, 1)
        half.area:SetPoint(layout.corner, d.holder, layout.corner)
        -- Un cambio que afecta a cómo se crean los botones rehace el contenedor.
        local signature = EngineSignature(cfg, kind)
        if half.engine and half.signature ~= signature then
            half.engine:Hide()
            pcall(half.engine.SetUnit, half.engine, nil)
            half.engine = nil
        end
        half.signature = signature
    end
    A.Refresh(frame)
end

local function HideCells(half, from)
    for i = from, #half.cells do half.cells[i]:Hide() end
end

-- Pinta una mitad con celdas Lua. Devuelve false si no se pudieron leer las auras.
local function PaintLua(d, half, list, mode)
    local cfg = Cfg(d)
    local mark = table.concat({ cfg.dispelMark, table.concat(cfg.dispelColor, ","), cfg.size, cfg.barHeight }, ";")
    if half.cellMode ~= mode or half.cellMark ~= mark then
        -- Otro modo, otra marca u otro tamaño: celdas nuevas.
        for _, cell in ipairs(half.cells) do cell:Hide() end
        half.cells = {}
        half.cellMode = mode
        half.cellMark = mark
    end
    for i, aura in ipairs(list) do
        half.cells[i] = half.cells[i] or NewCell(half, mode, cfg)
        PaintCell(half.cells[i], aura, half.kind, cfg, d.unit)
    end
    PlaceCells(half, mode, cfg, half.layout, #list)
    HideCells(half, #list + 1)
end

---------------------------------------------------------------------------
-- Errores: se guardan para /bui auras y se avisan una vez por el chat (el
-- cliente oculta los errores de Lua por defecto, así que un fallo sería mudo).
---------------------------------------------------------------------------
A.errors = {}
local reported = {}

local function Report(where, err)
    local text = where .. ": " .. tostring(err)
    table.insert(A.errors, 1, text)
    while #A.errors > 5 do table.remove(A.errors) end
    if not reported[text] then
        reported[text] = true
        ns.Print("|cffff6666auras: " .. text .. "|r (más datos con /bui auras)")
    end
end
A.Report = Report

-- Iconos del motor para una mitad. Si el contenedor no se puede crear, la
-- mitad queda marcada y en adelante se pinta desde Lua.
local function RefreshEngineHalf(half, unit, kind, cfg)
    if not half.engine then
        local ok, result = pcall(BuildEngineHalf, half, unit, kind, cfg, half.layout)
        if not ok then
            half.engineFailed = true
            Report("contenedor de " .. kind, result)
            return false
        end
        half.engine = result
    else
        -- Se recoloca en cada repaso: tras recargar se quedaba donde estaba la
        -- zona al crearse (en medio de la pantalla) hasta el siguiente ajuste.
        local layout = half.layout
        if layout then
            half.engine:ClearAllPoints()
            half.engine:SetPoint(layout.corner, half.area, layout.corner)
        end
        half.engine:Show()
        if half.engineUnit ~= unit then pcall(half.engine.SetUnit, half.engine, unit) end
        pcall(half.engine.UpdateAllAuras, half.engine)
    end
    half.engineUnit = unit
    return true
end

-- Primero se leen y pintan las auras desde Lua (iconos o barras). Solo si el
-- cliente no deja leerlas (contenido restringido) se usan los iconos del motor.
local function RefreshHalf(d, half, unit, cfg, preview)
    local kind = half.kind
    local list
    if preview then
        list = Samples(kind, cfg)
    else
        list = Collect(unit, kind, cfg)
    end
    if list then
        half.readFailed = nil
        if half.engine then half.engine:Hide() end
        PaintLua(d, half, list, cfg.mode == "bars" and "bars" or "icons")
        return
    end
    -- No se pudieron leer (p. ej. justo al cargar): se reintenta en el próximo
    -- cambio de auras. Respaldo del motor solo si está activado.
    HideCells(half, 1)
    half.readFailed = true
    -- Auras secretas: siempre el motor (es la única forma de verlas). Otros
    -- fallos: solo si el respaldo está activado en Avanzado.
    local secret = A.IsSecretError(A.readErrors[unit .. ":" .. kind])
    if (secret or A.db.style.engineFallback) and A.EngineAvailable() and not half.engineFailed then
        RefreshEngineHalf(half, unit, kind, cfg)
    end
end

function A.Refresh(frame)
    if not A.active or not A.db.units[frame.buiUnit] then return end
    local d = A.displays[frame.buiUnit]
    if not d or not Cfg(d).enabled then return end
    local cfg = Cfg(d)
    local unit = UF.UnitOf(frame)
    local preview = frame.previewUnit ~= nil
    -- Cada mitad por separado: un fallo en una no deja sin pintar la otra.
    for kind, half in pairs(d.halves) do
        local ok, err = pcall(RefreshHalf, d, half, unit, cfg, preview)
        if not ok then Report(kind .. " de " .. frame.buiUnit, err) end
    end
end

---------------------------------------------------------------------------
-- /bui auras: lo que ve el addon, para encontrar por qué algo no aparece
---------------------------------------------------------------------------
local function Num(value)
    if IsSecret(value) then return "secreto" end
    return tostring(value)
end

local function ListAuras(unit, filter)
    local out = {}
    local ok, err = pcall(function()
        for i = 1, 40 do
            local aura = GetAura(unit, i, filter)
            if not aura then break end
            out[#out + 1] = string.format("%s (id %s, %ss)", IsSecret(aura.name) and "secreto" or tostring(aura.name),
                Num(aura.spellId), Num(aura.duration))
        end
    end)
    if not ok then return "no se pueden leer: " .. tostring(err) end
    return #out == 0 and "ninguna" or table.concat(out, ", ")
end

function A.Diagnose()
    ns.Print("diagnóstico de auras:")
    print("  módulo activo: " .. (A.active and "sí" or "no")
        .. " · contenedores del motor: " .. (A.EngineAvailable() and "sí" or "no"))
    print("  tus beneficios: " .. ListAuras("player", "HELPFUL"))
    print("  tus perjuicios: " .. ListAuras("player", "HARMFUL"))
    if UnitExists("target") then
        print("  perjuicios del objetivo: " .. ListAuras("target", "HARMFUL"))
        print("  los tuyos sobre el objetivo: " .. ListAuras("target", "HARMFUL|PLAYER"))
        for _, kind in ipairs({ "buffs", "debuffs" }) do
            local err = A.readErrors["target:" .. kind]
            if err then print("  error al leer " .. kind .. " del objetivo: " .. tostring(err)) end
        end
    else
        print("  (selecciona un objetivo con perjuicios para ver los suyos)")
    end
    for _, unit in ipairs({ "player", "target" }) do
      local okUnit, errUnit = pcall(function()
        local d, cfg = A.displays[unit], A.db.units[unit]
        if not d then
            print("  " .. unit .. ": sin marco (¿desactivado en Marcos de unidad?)")
        else
            local h = d.holder
            print(string.format("  %s: activado %s · modo %s · visible %s · posición %s,%s · ancho %s",
                unit, tostring(cfg.enabled), cfg.mode, tostring(h:IsVisible()),
                tostring(h:GetLeft() and math.floor(h:GetLeft())), tostring(h:GetBottom() and math.floor(h:GetBottom())),
                tostring(h:GetWidth() and math.floor(h:GetWidth()))))
            for kind, half in pairs(d.halves) do
                local shownCells = 0
                for _, cell in ipairs(half.cells) do if cell:IsShown() then shownCells = shownCells + 1 end end
                local line = string.format("    %s: celdas Lua %d", kind, shownCells)
                local engine = half.engine
                if engine then
                    -- El contenedor puede negarse a dar datos: cada consulta va protegida.
                    local function Ask(fn, ...)
                        local ok, value = pcall(fn, engine, ...)
                        if not ok then return "bloqueado" end
                        return Num(value)
                    end
                    local okKids, kids = pcall(function()
                        -- Si el juego oculta si un botón se ve (auras secretas), se dice:
                        -- antes contaba 0 y parecía que no había nada.
                        local total, shown, secret = 0, 0, 0
                        for _, child in ipairs({ engine:GetChildren() }) do
                            total = total + 1
                            local okShown, isShown = pcall(child.IsShown, child)
                            if not okShown or IsSecret(isShown) then secret = secret + 1
                            elseif isShown then shown = shown + 1 end
                        end
                        if secret > 0 then
                            return total .. " botones, cuáles se ven: secreto (lo decide el juego)"
                        end
                        return total .. " botones, " .. shown .. " mostrados"
                    end)
                    line = line .. string.format(" · motor: visible %s, tamaño %sx%s, %s",
                        Ask(engine.IsVisible), Ask(engine.GetWidth), Ask(engine.GetHeight),
                        okKids and kids or "botones bloqueados")
                else
                    line = line .. " · motor: no"
                end
                if half.engineFailed then line = line .. " · el motor falló" end
                print(line)
            end
        end
      end)
      if not okUnit then print("  " .. unit .. ": error en el diagnóstico: " .. tostring(errUnit)) end
    end
    if #A.errors > 0 then
        print("  errores:")
        for _, e in ipairs(A.errors) do print("    " .. e) end
    else
        print("  errores: ninguno")
    end
end

ns.RegisterCommand("auras", function() A.Diagnose() end, "diagnóstico del módulo de auras")

---------------------------------------------------------------------------
-- /bui auras motor: prueba aislada del contenedor del motor. Un contenedor
-- suelto en el centro de la pantalla (con un recuadro verde que marca dónde
-- está) con tus beneficios y los perjuicios de tu objetivo, iconos grandes,
-- durante 20 segundos. Sirve para saber si el motor dibuja en este cliente
-- (y entonces el fallo es de colocación en el marco) o no dibuja nada.
---------------------------------------------------------------------------
local probe
local function ProbeInitializer(button)
    local ok, err = pcall(function()
        button:SetSize(40, 40)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints()
        button:SetIcon(icon)
        button:SetDurationCooldown(cd)
    end)
    if not ok then print("  |cffff6666motor: error al montar un icono: " .. tostring(err) .. "|r") end
end

local function ProbeContainer(parent, unit, filter, point, y)
    local container = CreateFrame("AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    container:SetPoint(point, parent, "CENTER", 0, y)
    container:SetSize(1, 1)
    CallFirst(container, { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" }, point)
    CallFirst(container, { "SetFlowLayoutMaximumLineSize", "SetAuraLayoutRowWidth" }, 380)
    local layout = { elementWidth = 40, elementHeight = 40, elementSpacing = 6, lineSpacing = 6 }
    container:AddAuraGroup("probe", filter, {
        maxFrameCount = 8, layout = layout,
        initializeFrame = ProbeInitializer,
    })
    EnableGroup(container, "probe", 8, layout)
    container:SetUnit(unit)
    container:UpdateAllAuras()
    return container
end

function A.EngineProbe()
    if not A.EngineAvailable() then
        print("BlazzitoUI: el motor de auras no está disponible en este cliente.")
        return
    end
    if not probe then
        probe = CreateFrame("Frame", nil, UIParent)
        probe:SetSize(400, 150)
        probe:SetPoint("CENTER", 0, 120)
        probe:SetFrameStrata("HIGH")
        local bg = probe:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.1, 0.6, 0.2, 0.25)
        local label = probe:CreateFontString(nil, "OVERLAY")
        label:SetFont(M.FONT, 12, "OUTLINE")
        label:SetPoint("BOTTOM", probe, "TOP", 0, 4)
        label:SetText("Prueba del motor: arriba tus beneficios, abajo los perjuicios del objetivo")
        local ok, err = pcall(function()
            probe.buffs = ProbeContainer(probe, "player", "HELPFUL", "TOP", 70)
            probe.debuffs = ProbeContainer(probe, "target", "HARMFUL", "TOP", 0)
        end)
        if not ok then
            print("BlazzitoUI: |cffff6666el motor no pudo crear el contenedor: " .. tostring(err) .. "|r")
            return
        end
        probe.timer = 0
        probe:SetScript("OnUpdate", function(self, elapsed)
            self.timer = self.timer + elapsed
            if self.timer >= 20 then self:Hide() end
        end)
    end
    probe.timer = 0
    probe:Show()
    pcall(probe.buffs.UpdateAllAuras, probe.buffs)
    pcall(probe.debuffs.UpdateAllAuras, probe.debuffs)
    print("BlazzitoUI: prueba del motor en el centro de la pantalla (20 s). ¿Ves iconos dentro del recuadro verde?")
    local c = probe.buffs
    local has = {}
    for _, name in ipairs({ "SetAuraGroupEnabled", "SetAuraGroupMaxFrameCount", "SetAuraGroupLayout",
                            "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint", "SetAuraProcessingPolicy" }) do
        has[#has + 1] = name .. (c[name] and " sí" or " no")
    end
    local okKids, count = pcall(function() return select("#", c:GetChildren()) end)
    print("  motor: " .. table.concat(has, " · ") .. " · botones creados: " .. (okKids and tostring(count) or "secreto"))
end

ns.RegisterCommand("auras motor", function() A.EngineProbe() end, "prueba el motor de auras en el centro de la pantalla")

-- Cada 0,1 s: tiempos de las celdas Lua; las auras de ejemplo vuelven a empezar.
function A.Tick(d)
    local cfg = A.db.units[d.unit]
    for _, half in pairs(d.halves) do
        for _, cell in ipairs(half.cells) do
            local aura = cell.aura
            if cell:IsShown() and aura then
                local remaining, duration = Remaining(aura)
                if remaining and remaining <= 0 and aura.sample then
                    aura.expirationTime = GetTime() + aura.duration
                    remaining = aura.duration
                end
                if remaining then
                    if cfg.showTime and cell.mode == "bars" then cell.time:SetText(FormatTime(remaining)) end
                    if cell.mode == "bars" then cell.bar:SetValue(remaining) end
                end
            end
        end
    end
end

function A.ApplyUnit(unit)
    local frame = UF.frames[unit]
    if not frame then return end
    local ok, err = pcall(A.Layout, frame)
    if not ok then Report("colocación de " .. unit, err) end
end

function A.ApplyAll()
    for unit in pairs(UF.frames) do A.ApplyUnit(unit) end
end

---------------------------------------------------------------------------
-- Activación
---------------------------------------------------------------------------
-- Un error aquí no debe romper la colocación de los marcos de unidad.
local function SafeLayout(frame)
    local ok, err = pcall(A.Layout, frame)
    if not ok then Report("colocación de " .. tostring(frame.buiUnit), err) end
end

function A:OnEnable()
    if not UF.active then
        ns.Print("auras: el módulo de marcos de unidad está desactivado; las auras van sobre esos marcos.")
        return
    end
    for _, frame in pairs(UF.frames) do SafeLayout(frame) end

    table.insert(UF.hooks.layout, SafeLayout)
    table.insert(UF.hooks.update, function(frame, tick)
        -- El objetivo del objetivo se repinta cada 0,2 s: sus auras, una vez por segundo.
        if tick then
            frame.auraTick = (frame.auraTick or 0) + 1
            if frame.auraTick % 5 ~= 0 then return end
        end
        A.Refresh(frame)
    end)
    table.insert(UF.hooks.preview, function()
        for _, frame in pairs(UF.frames) do SafeLayout(frame) end
    end)

    local events = CreateFrame("Frame")
    -- Evento general y filtro propio: RegisterUnitEvent sobre el mismo frame
    -- reemplaza la unidad anterior, así que no sirve para varios marcos.
    events:RegisterEvent("UNIT_AURA")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function(_, event, unit)
        if event == "PLAYER_ENTERING_WORLD" then
            -- Tras cargar, las auras ya se pueden leer: se repintan todos.
            for _, frame in pairs(UF.frames) do SafeLayout(frame) end
            return
        end
        local frame = UF.frames[unit]
        if frame and frame:IsShown() and not frame.previewUnit and A.displays[unit] then
            A.Refresh(frame)
        end
    end)
end
