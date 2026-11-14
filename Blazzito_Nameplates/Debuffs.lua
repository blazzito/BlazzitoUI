-- Tus debuffs sobre la placa (Picadura de serpiente, Marca del cazador...).
--
-- Las auras de un enemigo en combate son secretas: el addon no puede leerlas.
-- Por eso se usa el contenedor de auras del cliente (AuraContainer, el mismo
-- motor que Blazzito_Auras), que las pinta sin que veamos los datos. Si el
-- cliente no lo tiene, se leen con C_UnitAuras (cuando se dejan) y se pintan
-- iconos propios; esos mismos iconos sirven para la vista previa.
local ns = BlazzitoUI
if not (ns and ns.Nameplates) then return end

local NP, M = ns.Nameplates, ns.Media
local Readable = M.Readable
local FILTER = "HARMFUL|PLAYER"
local SAMPLES = {
    { icon = "Interface\\Icons\\Ability_Hunter_Quickshot", duration = 15, stacks = 0 },
    { icon = "Interface\\Icons\\Ability_Hunter_SniperShot", duration = 120, stacks = 0 },
    { icon = "Interface\\Icons\\Ability_Rogue_DualWeild", duration = 12, stacks = 3 },
}

---------------------------------------------------------------------------
-- ¿Hay motor de auras en este cliente?
---------------------------------------------------------------------------
function NP.AuraEngine()
    if NP.engine ~= nil then return NP.engine end
    pcall(function()
        if C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded("Blizzard_AuraContainer") then
            C_AddOns.LoadAddOn("Blizzard_AuraContainer")
        end
    end)
    local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
    NP.engine = (ok and probe and probe.AddAuraGroup and probe.SetUnit) and true or false
    if ok and probe then probe:Hide() end
    return NP.engine
end

local function CallFirst(obj, names, ...)
    for _, name in ipairs(names) do
        if obj[name] then return pcall(obj[name], obj, ...) end
    end
end

local function Size()
    local size = NP.db.auraSize
    return size, math.floor(size * 0.8 + 0.5)   -- un poco más anchos que altos
end

-- Contador del tiempo: el del propio enfriamiento (sabe pintar duraciones
-- secretas), con una letra pequeña nuestra. OmniCC se aparta
-- (noCooldownCount, en nuestro marco) para que no ponga números gigantes.
local COUNT_FONT = "BlazzitoUINameplateCount"
local function CountFont()
    if not CreateFont then return nil end
    local font = _G[COUNT_FONT] or CreateFont(COUNT_FONT)
    local _, height = Size()
    font:SetFont(M.FONT, math.max(7, math.floor(height * 0.55)), "OUTLINE")
    return COUNT_FONT
end

local function SetupCooldown(cd)
    cd:SetDrawEdge(false)
    cd:SetReverse(true)
    cd.noCooldownCount = true
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    local font = CountFont()
    if font and cd.SetCountdownFont then pcall(cd.SetCountdownFont, cd, font) end
end

---------------------------------------------------------------------------
-- Fila e iconos propios
---------------------------------------------------------------------------
function NP.BuildDebuffs(p)
    local row = CreateFrame("Frame", nil, p)
    row:SetSize(1, 1)
    row.cells = {}
    return row
end

local function Cell(row, i)
    local cell = row.cells[i]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, row)
    cell.border = cell:CreateTexture(nil, "BACKGROUND")
    cell.border:SetAllPoints()
    cell.border:SetColorTexture(0, 0, 0, 1)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetPoint("TOPLEFT", 1, -1)
    cell.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    cell.cooldown = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
    cell.cooldown:SetAllPoints(cell.icon)
    SetupCooldown(cell.cooldown)
    local carrier = CreateFrame("Frame", nil, cell)
    carrier:SetAllPoints()
    carrier:SetFrameLevel(cell.cooldown:GetFrameLevel() + 2)
    cell.stack = NP.Font(carrier, 8, "RIGHT")
    cell.stack:SetPoint("BOTTOMRIGHT", 1, 0)
    cell:Hide()
    row.cells[i] = cell
    return cell
end

local function HideCells(row, from)
    for i = from, #row.cells do row.cells[i]:Hide() end
end

function NP.LayoutDebuffs(p)
    local row, db = p.debuffs, NP.db
    local width, height = Size()
    -- Por encima del nombre, con aire (el nombre ocupa ~letra + 5).
    local y = db.showName and (db.fontSize + 8) or 4
    row:ClearAllPoints()
    row:SetPoint("BOTTOMLEFT", p.block, "TOPLEFT", 0, y)
    row:SetSize(db.width, height)
    CountFont()
    for i, cell in ipairs(row.cells) do
        cell:SetSize(width, height)
        cell:ClearAllPoints()
        cell:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * (width + 2), 0)
        -- Recorte del icono a la proporción de la celda.
        local cut = (1 - height / width) / 2 * 0.84
        cell.icon:SetTexCoord(0.08, 0.92, 0.08 + cut, 0.92 - cut)
        cell.stack:SetFont(M.FONT, math.max(7, math.floor(height * 0.55)), "OUTLINE")
    end
    row:SetShown(db.auras)
    if row.container then row.container:SetSize(db.width, height) end
    -- El contenedor del motor se rehace si cambia el tamaño o el máximo.
    if row.container and row.signature ~= (width .. ":" .. height .. ":" .. db.auraMax) then
        NP.DetachDebuffs(p)
        row.container:Hide()
        row.container = nil
        if p.unit and not p.preview then NP.AttachDebuffs(p, p.unit) end
    end
end

local function PaintCell(cell, aura, unit)
    cell.icon:SetTexture(aura.icon)
    local stacks = Readable(aura.applications)
    cell.stack:SetShown(stacks ~= nil and stacks > 1)
    if stacks then cell.stack:SetText(stacks) end
    local duration, expiration = Readable(aura.duration), Readable(aura.expirationTime)
    if duration and expiration and duration > 0 then
        cell.cooldown:SetCooldown(expiration - duration, duration)
    elseif unit and aura.auraInstanceID ~= nil and C_UnitAuras and C_UnitAuras.GetAuraDuration
        and cell.cooldown.SetCooldownFromDurationObject then
        local ok, object = pcall(C_UnitAuras.GetAuraDuration, unit, aura.auraInstanceID)
        if not (ok and object and pcall(cell.cooldown.SetCooldownFromDurationObject, cell.cooldown, object)) then
            cell.cooldown:Clear()
        end
    else
        cell.cooldown:Clear()
    end
    cell:Show()
end

---------------------------------------------------------------------------
-- Motor del cliente
---------------------------------------------------------------------------
local function EngineButton(button)
    pcall(function()
        local width, height = Size()
        button:SetSize(width, height)
        if button.EnableMouse then button:EnableMouse(false) end
        local border = button:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", -1, 1)
        local cut = (1 - height / width) / 2 * 0.84
        icon:SetTexCoord(0.08, 0.92, 0.08 + cut, 0.92 - cut)
        local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        SetupCooldown(cd)
        local carrier = CreateFrame("Frame", nil, button)
        carrier:SetAllPoints()
        carrier:SetFrameLevel(cd:GetFrameLevel() + 2)
        local stack = NP.Font(carrier, math.max(7, math.floor(height * 0.55)), "RIGHT")
        stack:SetPoint("BOTTOMRIGHT", 1, 0)
        button:SetIcon(icon)
        button:SetDurationCooldown(cd)
        button:SetApplicationCount(stack, {})
    end)
end

local function NewContainer(p)
    local row, db = p.debuffs, NP.db
    local width, height = Size()
    -- Anclado arriba a la izquierda de su fila y creciendo hacia la derecha
    -- y hacia abajo: la primera línea ocupa justo la fila (en el juego,
    -- creciendo "hacia arriba" desde abajo tapaba el nombre).
    local container = CreateFrame("AuraContainer", nil, row, "CustomAuraContainerTemplate")
    container:SetPoint("TOPLEFT", row, "TOPLEFT")
    container:SetSize(db.width, height)
    CallFirst(container, { "SetFlowLayoutAnchorPoint", "SetAuraLayoutAnchorPoint" }, "TOPLEFT")
    local FD = AnchorUtil and AnchorUtil.FlowDirection
    if FD then
        CallFirst(container, { "SetFlowLayoutGrowthDirection", "SetAuraLayoutGrowthDirection" }, FD.Right, FD.Down)
    end
    CallFirst(container, { "SetFlowLayoutMaximumLineSize", "SetAuraLayoutRowWidth" }, db.width)
    local layout = { elementWidth = width, elementHeight = height, elementSpacing = 2, lineSpacing = 2 }
    container:AddAuraGroup("mine", FILTER, {
        maxFrameCount = db.auraMax, layout = layout, initializeFrame = EngineButton,
    })
    if container.SetAuraGroupEnabled then pcall(container.SetAuraGroupEnabled, container, "mine", true) end
    if container.SetAuraGroupMaxFrameCount then pcall(container.SetAuraGroupMaxFrameCount, container, "mine", db.auraMax) end
    if container.SetAuraGroupLayout then pcall(container.SetAuraGroupLayout, container, "mine", layout) end
    row.container = container
    row.signature = width .. ":" .. height .. ":" .. db.auraMax
    return container
end

function NP.AttachDebuffs(p, unit)
    local row = p.debuffs
    if not (NP.db.auras and NP.AuraEngine()) then return end
    local ok = pcall(function()
        local container = row.container or NewContainer(p)
        container:Show()
        container:SetUnit(unit)
        container:UpdateAllAuras()
    end)
    if not ok then NP.engine = false end
end

function NP.DetachDebuffs(p)
    local container = p.debuffs.container
    if not container then return end
    if not pcall(container.SetUnit, container, "none") then pcall(container.SetUnit, container, nil) end
    container:Hide()
end

---------------------------------------------------------------------------
-- Respaldo en Lua (sin motor)
---------------------------------------------------------------------------
function NP.UpdateDebuffs(p)
    local row, db = p.debuffs, NP.db
    if not db.auras then
        HideCells(row, 1)
        return
    end
    if NP.AuraEngine() then
        HideCells(row, 1)
        if not row.container then NP.AttachDebuffs(p, p.unit) end
        return
    end
    local shown = 0
    local ok = pcall(function()
        for i = 1, 40 do
            if shown >= db.auraMax then break end
            local aura = C_UnitAuras.GetAuraDataByIndex(p.unit, i, FILTER)
            if not aura then break end
            shown = shown + 1
            PaintCell(Cell(row, shown), aura, p.unit)
        end
    end)
    if not ok then shown = 0 end
    if shown > 0 then NP.LayoutDebuffs(p) end
    HideCells(row, shown + 1)
end

-- Vista previa: iconos de ejemplo con su tiempo corriendo.
function NP.PreviewDebuffs(p, show)
    local row, db = p.debuffs, NP.db
    local count = (show and db.auras) and math.min(#SAMPLES, db.auraMax) or 0
    local now = GetTime()
    for i = 1, count do
        local sample = SAMPLES[i]
        PaintCell(Cell(row, i), { icon = sample.icon, applications = sample.stacks,
                                  duration = sample.duration, expirationTime = now + sample.duration * 0.6 })
    end
    HideCells(row, count + 1)
    NP.LayoutDebuffs(p)
end
