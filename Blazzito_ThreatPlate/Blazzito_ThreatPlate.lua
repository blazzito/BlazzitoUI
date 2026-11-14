-- Blazzito_ThreatPlate: módulo "Aggro en placas" de BlazzitoUI (antes el
-- addon Blazz_ThreatPlate). Tu % de aggro en una pequeña insignia.
--
-- Una sola insignia, con un solo juego de ajustes (diseño, forma, letra,
-- 0% en combate), que usan:
--  * las placas de Blazzito_Nameplates, dentro de la placa (TP.NewBadge);
--  * las placas de Blizzard, encima de su barra, si este módulo está activo
--    (cuando apagas nuestras placas o el juego no deja tocarlas).
-- Diseños: "blazzito" (fondo oscuro con la forma de las placas, de ángulo
-- fijo, y borde del color del aggro) y "classic" (borde dorado, el % del
-- color del aggro). Sus opciones están en la página "Placas de nombre".
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret

local TP = ns.NewModule("ThreatPlate", "Aggro en placas", {
    style = "blazzito",     -- blazzito | classic
    shape = "slant",
    fontSize = 9,
    offsetX = 0,            -- desplazamiento desde su sitio (0, 0 = el de siempre)
    offsetY = 0,
    showZero = true,        -- "0%" si el enemigo está en combate pero no tienes aggro
})
ns.ThreatPlate = TP

local UPDATE_RATE = 0.25    -- segundos entre actualizaciones de respaldo
local GOLD = { 1.00, 0.82, 0.00 }
local NEUTRAL = { 0.45, 0.47, 0.52 }

local badges = {}   -- [placa de Blizzard] = insignia
local active = {}   -- [unidad] = placa

---------------------------------------------------------------------------
-- La insignia (compartida con Blazzito_Nameplates)
---------------------------------------------------------------------------
-- place(badge): la coloca quien la crea (se llama en cada repintado).
function TP.NewBadge(owner, place)
    local badge = CreateFrame("Frame", nil, owner)
    badge.place = place
    -- Rectángulo (clásico, o si no hay motor de formas).
    badge.edge = badge:CreateTexture(nil, "BACKGROUND", nil, -2)
    badge.edge:SetAllPoints()
    badge.edge:SetColorTexture(1, 1, 1, 1)
    badge.fill = badge:CreateTexture(nil, "BACKGROUND", nil, -1)
    local carrier = CreateFrame("Frame", nil, badge)
    carrier:SetAllPoints()
    badge.carrier = carrier
    badge.text = carrier:CreateFontString(nil, "OVERLAY")
    badge.text:SetShadowColor(0, 0, 0, 1)
    badge.text:SetShadowOffset(1, -1)
    badge.text:SetPoint("CENTER", 0, 0)
    badge:Hide()
    TP.StyleBadge(badge)
    return badge
end

-- Tamaño, forma y letra según los ajustes. Ancho fijo para "100%": la
-- insignia nunca cambia de tamaño.
function TP.StyleBadge(badge)
    local db = TP.db
    local size = db.fontSize
    local width, height = math.ceil(size * 2.6) + 10, size + 7
    badge:SetSize(width, height)
    if badge.place then badge.place(badge) end
    badge.text:SetFont(M.FONT, size, "OUTLINE")
    local px = M.PixelSize()
    local Shape = ns.Nameplates and ns.Nameplates.Shape
    local shaped = db.style ~= "classic" and Shape ~= nil
    if shaped then
        if not badge.block then
            badge.block = Shape.NewBlock(badge)
            badge.block:SetPoint("CENTER")
            badge.block.bar:SetMinMaxValues(0, 1)
            badge.block.bar:SetValue(1)
        end
        Shape.Layout(badge.block, { width = width, height = height, edge = px, outline = 2 * px, shape = db.shape })
        local bg = M.COLORS.background
        M.ColorBar(badge.block.bar, bg[1], bg[2], bg[3])
        badge.block:Show()
        badge.carrier:SetFrameLevel(badge.block.bar:GetFrameLevel() + 3)
    elseif badge.block then
        badge.block:Hide()
    end
    badge.edge:SetShown(not shaped)
    badge.fill:SetShown(not shaped)
    badge.fill:ClearAllPoints()
    badge.fill:SetPoint("TOPLEFT", px, -px)
    badge.fill:SetPoint("BOTTOMRIGHT", -px, px)
    local bg = M.COLORS.background
    badge.fill:SetColorTexture(bg[1], bg[2], bg[3], 0.95)
    TP.SetBadgeStatus(badge, badge.status)
end

-- status: situación de aggro legible (0..3) o nil (secreta: color neutro).
function TP.SetBadgeStatus(badge, status)
    badge.status = status
    local r, g, b
    if status then
        local ok, rr, gg, bb = pcall(GetThreatStatusColor, status)
        if ok and rr then r, g, b = rr, gg, bb end
    end
    if not r then r, g, b = NEUTRAL[1], NEUTRAL[2], NEUTRAL[3] end
    if TP.db.style == "classic" then
        -- Clásico: borde dorado y el % del color del aggro.
        badge.edge:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        badge.text:SetTextColor(r, g, b)
    else
        badge.text:SetTextColor(1, 1, 1)
        if badge.block and badge.block:IsShown() then
            badge.block.border:SetVertexColor(r, g, b, 1)
        else
            badge.edge:SetVertexColor(r, g, b, 1)
        end
    end
end

-- Escribe el % (puede venir secreto: se pinta tal cual, sin compararlo).
-- Devuelve false si no hay nada que mostrar.
function TP.SetBadgeValue(badge, unit, pct)
    if IsSecret(pct) then
        return pcall(badge.text.SetFormattedText, badge.text, "%d%%", pct) and true or false
    end
    if pct == nil then return false end
    if pct <= 0 and not (TP.db.showZero and Readable(UnitAffectingCombat(unit)) == true) then return false end
    badge.text:SetFormattedText("%d%%", pct)
    return true
end

---------------------------------------------------------------------------
-- Insignias sobre las placas de Blizzard
---------------------------------------------------------------------------
-- Sobre qué se coloca: la placa de Blazzito_Nameplates si la hay (y no lleva
-- ya el aggro dentro); si no, la barra de vida de la placa de Blizzard.
local function AnchorFor(plate)
    local own = ns.Nameplates and ns.Nameplates.AnchorFor and ns.Nameplates.AnchorFor(plate)
    if own then return own end
    local uf = plate.UnitFrame
    local bar = type(uf) == "table" and (uf.healthBar or (type(uf.HealthBarsContainer) == "table" and uf.HealthBarsContainer.healthBar))
    return type(bar) == "table" and bar or plate
end

-- En las de Blizzard su sitio es 6 px bajo el centro de la barra; Horizontal
-- y Vertical la mueven desde ahí (los mismos valores que en nuestras placas).
local BLIZZARD_Y = -6
local function PlaceOnPlate(badge)
    local db = TP.db
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", badge.anchorTo, "CENTER", db.offsetX, BLIZZARD_Y + db.offsetY)
end

-- Ajustes de antes: offsetY guardaba la posición absoluta (-6 era la de
-- siempre). "v" no va en los valores por defecto: el núcleo los rellena antes
-- de OnInitialize y la migración no llegaría a correr. Con 0 no se toca (es
-- el valor nuevo por defecto).
function TP:OnInitialize()
    local db = self.db
    if (db.v or 1) < 2 then
        if db.offsetY and db.offsetY ~= 0 then db.offsetY = db.offsetY - BLIZZARD_Y end
        db.v = 2
    end
end

local function BadgeFor(plate)
    local badge = badges[plate]
    if not badge then
        badge = TP.NewBadge(plate, PlaceOnPlate)
        badge:SetFrameStrata("HIGH")
        badges[plate] = badge
    end
    return badge
end

local function UpdateUnit(unit)
    local plate = active[unit]
    local badge = plate and badges[plate]
    if not badge then return end
    -- Apagada, o las placas de Blazzito_Nameplates ya llevan el aggro dentro.
    local NP = ns.Nameplates
    if not TP.active or (NP and NP.HandlesThreat and NP.HandlesThreat(plate)) then
        badge:Hide()
        return
    end
    local anchor = AnchorFor(plate)
    if badge.anchorTo ~= anchor then
        badge.anchorTo = anchor
        PlaceOnPlate(badge)
    end

    -- Si estas comprobaciones vienen como secretas, se asume "sí mostrar".
    local canAttack = Readable(UnitCanAttack("player", unit))
    local isDead = Readable(UnitIsDead(unit))
    if canAttack == false or isDead == true then
        badge:Hide()
        return
    end

    local _, status, scaledPct = UnitDetailedThreatSituation("player", unit)
    if not TP.SetBadgeValue(badge, unit, scaledPct) then
        badge:Hide()
        return
    end
    -- Sin situación (no secreta) cuenta como 0; secreta, color neutro.
    local readable = Readable(status)
    if readable == nil and not IsSecret(status) then readable = 0 end
    TP.SetBadgeStatus(badge, readable)
    badge:Show()
end

local function UpdateAll()
    for unit in pairs(active) do UpdateUnit(unit) end
end

-- Repinta todas las insignias (las de Blizzard; las de nuestras placas las
-- repinta Blazzito_Nameplates al aplicar sus ajustes).
function TP.RestyleAll()
    for _, badge in pairs(badges) do TP.StyleBadge(badge) end
    UpdateAll()
end

local function AddPlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
    local badge = BadgeFor(plate)
    badge.anchorTo = AnchorFor(plate)
    PlaceOnPlate(badge)
    active[unit] = plate
    UpdateUnit(unit)
end

---------------------------------------------------------------------------
-- Activación (también en vivo desde las opciones, sin recargar)
---------------------------------------------------------------------------
local function StandaloneLoaded()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded("Blazz_ThreatPlate") and true or false
end

local function Start()
    if TP.started then return end
    TP.started = true
    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            AddPlate(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            local plate = active[unit]
            if plate and badges[plate] then badges[plate]:Hide() end
            active[unit] = nil
        elseif event == "PLAYER_REGEN_ENABLED" then
            UpdateAll()
        elseif unit and active[unit] then
            UpdateUnit(unit)
        end
    end)

    -- Respaldo: refresco periódico por si algún evento de aggro no llega.
    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        if not TP.active then return end
        elapsed = elapsed + dt
        if elapsed >= UPDATE_RATE then
            elapsed = 0
            UpdateAll()
        end
    end)

    -- Placas que ya estaban en pantalla.
    if C_NamePlate.GetNamePlates then
        for _, base in ipairs(C_NamePlate.GetNamePlates()) do
            local unit = base.namePlateUnitToken or base.unitToken or (base.GetUnit and base:GetUnit())
            if unit then AddPlate(unit) end
        end
    end
end

function TP:OnEnable()
    -- El addon suelto haría lo mismo dos veces: mientras esté activo, este módulo espera.
    if StandaloneLoaded() then
        TP.blocked = true
        TP.active = false
        ns.Print("el addon Blazz_ThreatPlate sigue activo; desactívalo para usar el módulo \"Aggro en placas\".")
        return
    end
    Start()
end

-- Encender o apagar las insignias sobre las placas de Blizzard al momento.
function TP.SetEnabled(on)
    TP.db.enabled = on and true or false
    if TP.blocked then return end
    TP.active = TP.db.enabled
    if TP.active then Start() end
    UpdateAll()
end

-- /btp : diagnóstico sobre tu objetivo actual
SLASH_BLAZZITOUITHREAT1 = "/btp"
SlashCmdList["BLAZZITOUITHREAT"] = function()
    if not UnitExists("target") then
        ns.Print("selecciona un enemigo y vuelve a escribir /btp")
        return
    end
    local _, status, scaledPct = UnitDetailedThreatSituation("player", "target")
    local plate = C_NamePlate.GetNamePlateForUnit("target")
    ns.Print("diagnóstico de aggro:")
    print("  placa encontrada:", plate and "sí" or "no")
    print("  porcentaje secreto:", tostring(IsSecret(scaledPct)), " tipo:", type(scaledPct))
    print("  estado secreto:", tostring(IsSecret(status)), " tipo:", type(status))
    pcall(print, "  valor:", scaledPct)
end
