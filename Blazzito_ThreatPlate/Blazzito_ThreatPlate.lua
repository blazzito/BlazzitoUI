-- Blazzito_ThreatPlate: módulo "Aggro en placas" de BlazzitoUI (antes el
-- addon Blazz_ThreatPlate). Muestra tu % de aggro como una pequeña insignia
-- en la placa de cada enemigo.
-- Dos diseños: "blazzito" (fondo oscuro con la forma elegida y borde del color
-- del aggro) y "classic" (el de siempre: borde dorado redondeado).
-- Es un addon aparte que cuelga de BlazzitoUI en la lista de addons; usa su
-- núcleo a través de la variable global BlazzitoUI.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local Readable, IsSecret = M.Readable, M.IsSecret

local TP = ns.NewModule("ThreatPlate", "Aggro en placas", {
    style = "blazzito",     -- blazzito | classic
    shape = "slant",
    fontSize = 9,
    offsetX = 0,
    offsetY = -6,
    showZero = true,        -- "0%" si el enemigo está en combate pero no tienes aggro
})
ns.ThreatPlate = TP

local UPDATE_RATE = 0.25    -- segundos entre actualizaciones de respaldo
local CLASSIC = {
    bg = { 0.05, 0.04, 0.02, 0.9 },
    border = { 1.00, 0.82, 0.00, 1.0 },
    borderSize = 7, padX = 8, padY = 6,
}
local MODERN = { padX = 14, padY = 6 }

local badges = {}   -- [placa o vista previa] = insignia
local active = {}   -- [unidad] = placa

local function Padding()
    if TP.db.style == "classic" then return CLASSIC.padX, CLASSIC.padY end
    return MODERN.padX, MODERN.padY
end

---------------------------------------------------------------------------
-- Aspecto
---------------------------------------------------------------------------
local function ClassicFallback(badge)
    if badge.cBorder then return end
    badge.cBorder = badge:CreateTexture(nil, "BACKGROUND", nil, -1)
    badge.cBorder:SetAllPoints()
    badge.cBorder:SetColorTexture(unpack(CLASSIC.border))
    badge.cBg = badge:CreateTexture(nil, "BACKGROUND", nil, 0)
    badge.cBg:SetPoint("TOPLEFT", 1, -1)
    badge.cBg:SetPoint("BOTTOMRIGHT", -1, 1)
    badge.cBg:SetColorTexture(unpack(CLASSIC.bg))
end

local function Modern(badge)
    if badge.mBorder then return end
    badge.mBorder = badge:CreateTexture(nil, "BACKGROUND", nil, -2)
    badge.mBorder:SetAllPoints()
    badge.mBg = badge:CreateTexture(nil, "BACKGROUND", nil, -1)
    badge.mBg:SetPoint("TOPLEFT", 1, -1)
    badge.mBg:SetPoint("BOTTOMRIGHT", -1, 1)
end

-- Aplica el diseño, el tamaño de letra y la posición actuales.
local function Paint(badge)
    local db = TP.db
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", badge.anchorTo, "CENTER", db.offsetX, db.offsetY)
    badge.text:SetFont(M.FONT, db.fontSize, "OUTLINE")
    local padX, padY = Padding()
    badge:SetHeight(db.fontSize + padY)

    local classic = db.style == "classic"
    if classic then
        if badge.SetBackdrop then
            badge:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = CLASSIC.borderSize,
                insets = { left = 2, right = 2, top = 2, bottom = 2 },
            })
            badge:SetBackdropColor(unpack(CLASSIC.bg))
            badge:SetBackdropBorderColor(unpack(CLASSIC.border))
        else
            ClassicFallback(badge)
        end
    else
        if badge.SetBackdrop then badge:SetBackdrop(nil) end
        Modern(badge)
        local shape = M.ShapeTexture(db.shape, false)
        badge.mBorder:SetTexture(shape)
        badge.mBg:SetTexture(shape)
        local bg = M.COLORS.background
        badge.mBg:SetVertexColor(bg[1], bg[2], bg[3], 0.95)
    end
    if badge.cBorder then
        badge.cBorder:SetShown(classic)
        badge.cBg:SetShown(classic)
    end
    if badge.mBorder then
        badge.mBorder:SetShown(not classic)
        badge.mBg:SetShown(not classic)
    end
end

local function CreateBadge(owner, anchorTo)
    local badge = CreateFrame("Frame", nil, owner, BackdropTemplateMixin and "BackdropTemplate" or nil)
    badge:SetFrameStrata("HIGH")
    badge.anchorTo = anchorTo
    badge.text = badge:CreateFontString(nil, "OVERLAY")
    badge.text:SetShadowColor(0, 0, 0, 1)
    badge.text:SetShadowOffset(1, -1)
    badge.text:SetPoint("CENTER", 0, 0)
    Paint(badge)
    badge:Hide()
    badges[owner] = badge
    return badge
end

-- Clásico: el texto lleva el color del aggro. BlazzitoUI: texto blanco y el
-- borde con el color del aggro.
local function SetColor(badge, status)
    local ok, r, g, b = pcall(GetThreatStatusColor, status)
    if not ok then r, g, b = 1, 1, 1 end
    if TP.db.style == "classic" then
        badge.text:SetTextColor(r, g, b)
    else
        badge.text:SetTextColor(1, 1, 1)
        if badge.mBorder then badge.mBorder:SetVertexColor(r, g, b, 1) end
    end
end

local function SetWidth(badge)
    local padX, padY = Padding()
    local ok = pcall(function()
        badge:SetWidth(math.max(badge.text:GetStringWidth() + padX, TP.db.fontSize + padY))
    end)
    if not ok then badge:SetWidth(TP.db.fontSize * 3 + padX) end
end

---------------------------------------------------------------------------
-- Lectura del aggro (los valores pueden venir secretos)
---------------------------------------------------------------------------
-- Sobre qué se coloca la insignia: la placa de Blazzito_Nameplates si la hay;
-- si no, la barra de vida de la placa de Blizzard.
local function AnchorFor(plate)
    local own = ns.Nameplates and ns.Nameplates.AnchorFor and ns.Nameplates.AnchorFor(plate)
    return own or (plate.UnitFrame and plate.UnitFrame.healthBar) or plate
end

-- Para Blazzito_Nameplates (pone el indicador de rango al lado).
function TP.BadgeFor(plate)
    return badges[plate]
end

local function UpdateUnit(unit)
    local plate = active[unit]
    local badge = plate and badges[plate]
    if not badge then return end
    local anchor = AnchorFor(plate)
    if badge.anchorTo ~= anchor then
        badge.anchorTo = anchor
        Paint(badge)
    end

    -- Si estas comprobaciones vienen como secretas, se asume "sí mostrar".
    local canAttack = Readable(UnitCanAttack("player", unit))
    local isDead = Readable(UnitIsDead(unit))
    if canAttack == false or isDead == true then
        badge:Hide()
        return
    end

    local _, status, scaledPct = UnitDetailedThreatSituation("player", unit)

    -- nil real = no estás en la tabla de aggro de este enemigo.
    if not IsSecret(scaledPct) and scaledPct == nil then
        badge:Hide()
        return
    end

    local pct = Readable(scaledPct)
    if pct then
        if pct <= 0 and not (TP.db.showZero and Readable(UnitAffectingCombat(unit))) then
            badge:Hide()
            return
        end
        badge.text:SetFormattedText("%d%%", pct)
    else
        -- Valor secreto: solo se puede mostrar tal cual.
        local ok = pcall(badge.text.SetFormattedText, badge.text, "%d%%", scaledPct)
        if not ok then ok = pcall(badge.text.SetText, badge.text, scaledPct) end
        if not ok then
            badge:Hide()
            return
        end
    end

    if not IsSecret(status) and status == nil then status = 0 end
    SetColor(badge, status)
    SetWidth(badge)
    badge:Show()
end

local function UpdateAll()
    for unit in pairs(active) do UpdateUnit(unit) end
end

function TP.RestyleAll()
    for _, badge in pairs(badges) do Paint(badge) end
    UpdateAll()
    if TP.preview then
        SetColor(TP.preview, 2)
        SetWidth(TP.preview)
    end
end

---------------------------------------------------------------------------
-- Activación
---------------------------------------------------------------------------
local function StandaloneLoaded()
    local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return isLoaded and isLoaded("Blazz_ThreatPlate") and true or false
end

function TP:OnEnable()
    -- El addon suelto haría lo mismo dos veces: mientras esté activo, este módulo espera.
    if StandaloneLoaded() then
        TP.blocked = true
        ns.Print("el addon Blazz_ThreatPlate sigue activo; desactívalo para usar el módulo \"Aggro en placas\".")
        return
    end

    local f = CreateFrame("Frame")
    f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    f:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
    f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(_, event, unit)
        if event == "NAME_PLATE_UNIT_ADDED" then
            local plate = C_NamePlate.GetNamePlateForUnit(unit)
            if not plate or (plate.IsForbidden and plate:IsForbidden()) then return end
            if not badges[plate] then
                CreateBadge(plate, AnchorFor(plate))
            end
            active[unit] = plate
            UpdateUnit(unit)
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
        elapsed = elapsed + dt
        if elapsed >= UPDATE_RATE then
            elapsed = 0
            UpdateAll()
        end
    end)

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
end

---------------------------------------------------------------------------
-- Página de configuración
---------------------------------------------------------------------------
local W = ns.Widgets

ns.Config.RegisterPage("threatplate", "Aggro en placas", 20, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = TP.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            TP.RestyleAll()
            L:RefreshStates()
        end
    end

    local shapes = {}
    for i, key in ipairs(M.SHAPE_ORDER) do shapes[i] = { value = key, text = M.SHAPES[key].text } end

    local design = L:Card("Diseño")
    -- Vista previa: una insignia de ejemplo con 75% en color de aggro alto.
    local sample = CreateFrame("Frame", nil, design)
    sample:SetSize(60, 24)
    sample:SetPoint("TOPRIGHT", -24, -46)
    TP.preview = CreateBadge(sample, sample)
    TP.preview:SetFrameStrata(design:GetFrameStrata())
    TP.preview.text:SetText("75%")
    SetColor(TP.preview, 2)
    SetWidth(TP.preview)
    TP.preview:Show()

    L:Row(W.Dropdown(content, col, "Diseño", {
              { value = "blazzito", text = "BlazzitoUI (forma y borde del color del aggro)" },
              { value = "classic", text = "Clásico (borde dorado)" },
          }, get("style"), set("style")))
    L:Row(W.Dropdown(content, col, "Forma", shapes, get("shape"), set("shape")),
          nil, function() return db.style == "blazzito" end)
    if TP.blocked then
        L:Note("|cffff9933El addon Blazz_ThreatPlate sigue activo: desactívalo en la lista de addons para que este módulo funcione.|r")
    end
    L:EndCard()

    L:Card("Texto")
    L:Row(W.Slider(content, col, "Tamaño de letra", 7, 16, 1, get("fontSize"), set("fontSize")),
          W.Toggle(content, col, "Mostrar 0% en combate", get("showZero"), set("showZero")))
    L:EndCard()

    L:Card("Posición en la placa")
    L:Row(W.Slider(content, col, "Horizontal", -60, 60, 1, get("offsetX"), set("offsetX")),
          W.Slider(content, col, "Vertical", -40, 40, 1, get("offsetY"), set("offsetY")))
    L:EndCard()
    return L
end)
