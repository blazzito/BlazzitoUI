-- Los beneficios y perjuicios de Blizzard de arriba, junto al minimapa, con el
-- estilo de BlazzitoUI: icono recortado con la forma elegida, borde (del color
-- del tipo en los perjuicios), letra propia en tiempo y cargas, y la flechita
-- de plegar con nuestro icono. Siguen siendo los de Blizzard (clic derecho
-- para quitar un beneficio, tiempos, orden...): solo cambia el aspecto.
--
-- Cuidado con las auras secretas: en combate el juego puede negar cualquier
-- llamada a esos botones, así que todo va con pcall y el aspecto se aplica
-- fuera de combate (los botones nuevos se visten al salir).
local ns = BlazzitoUI
if not (ns and ns.Auras) then return end

local A, M = ns.Auras, ns.Media
local IsSecret = M.IsSecret

local BF = {}
A.BuffFrame = BF
local skins = setmetatable({}, { __mode = "k" })
local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
BF.skins = skins

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

-- Los botones de aura de Blizzard: los del contenedor moderno y, si existen,
-- los clásicos por nombre (BuffButtonN, DebuffButtonN, TempEnchantN).
function BF.Buttons()
    local list, seen = {}, {}
    local function Add(button)
        if type(button) == "table" and button.GetObjectType and not seen[button] then
            seen[button] = true
            list[#list + 1] = button
        end
    end
    for _, frame in ipairs({ _G.BuffFrame, _G.DebuffFrame }) do
        if type(frame) == "table" then
            local container = frame.AuraContainer or frame
            local ok, children = pcall(function() return { container:GetChildren() } end)
            if ok then
                for _, child in ipairs(children) do
                    if Child(child, "Icon") or Child(child, "icon") then Add(child) end
                end
            end
            if type(frame.auraFrames) == "table" then
                for _, button in ipairs(frame.auraFrames) do Add(button) end
            end
        end
    end
    for i = 1, 40 do Add(_G["BuffButton" .. i]) end
    for i = 1, 16 do Add(_G["DebuffButton" .. i]) end
    for i = 1, 3 do Add(_G["TempEnchant" .. i]) end
    return list
end

local function IconOf(button)
    return Child(button, "Icon", "Icon") or Child(button, "icon")
end

local function BorderOf(button)
    return Child(button, "DebuffBorder") or Child(button, "Border", "Border")
end

-- Color del borde de Blizzard (perjuicios: según el tipo), si se puede leer.
local function BlizzardBorderColor(button)
    local border = BorderOf(button)
    if not border or not border.GetVertexColor then return nil end
    local shown = border.IsShown and border:IsShown()
    if IsSecret(shown) or not shown then return nil end
    local ok, r, g, b = pcall(border.GetVertexColor, border)
    if not ok or IsSecret(r) or type(r) ~= "number" then return nil end
    return r, g, b
end

function BF.SkinButton(button)
    local cfg = A.db.buffFrame
    local icon = IconOf(button)
    if not icon then return end
    local d = skins[button]
    if not d then
        d = {}
        d.border = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.mask = button:CreateMaskTexture()
        d.icon = icon
        skins[button] = d
    end
    local on = cfg.skin
    local file = M.ButtonShape(cfg.shape)
    local px = M.PixelSize()
    local b = (cfg.border or 1) * px
    -- El borde rodea al icono (debajo va el tiempo, que no se toca de sitio).
    d.border:ClearAllPoints()
    d.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -b, b)
    d.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", b, -b)
    d.border:SetTexture(file)
    d.border:SetShown(on and b > 0)
    d.mask:ClearAllPoints()
    d.mask:SetAllPoints(icon)
    d.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if on and not d.masked then
        local okCount, count = pcall(icon.GetNumMaskTextures, icon)
        if okCount and type(count) == "number" and not IsSecret(count) then
            for i = count, 1, -1 do
                local okMask, mask = pcall(icon.GetMaskTexture, icon, i)
                if okMask and mask then pcall(icon.RemoveMaskTexture, icon, mask) end
            end
        end
        pcall(icon.SetTexCoord, icon, 0.08, 0.92, 0.08, 0.92)
        icon:AddMaskTexture(d.mask)
        d.masked = true
    elseif not on and d.masked then
        icon:RemoveMaskTexture(d.mask)
        pcall(icon.SetTexCoord, icon, 0, 1, 0, 1)
        d.masked = false
    end
    Hold(BorderOf(button), on)
    Hold(Child(button, "TempEnchantBorder"), on)
    -- Letra de BlazzitoUI en tiempo y cargas.
    for _, key in ipairs({ "Duration", "Count", "count", "duration" }) do
        local text = Child(button, key, key)
        if text and text.SetFont then
            if on then
                if not d[key] then d[key] = { text:GetFont() } end
                pcall(text.SetFont, text, M.FONT, cfg.fontSize or 11, "OUTLINE")
            elseif d[key] and d[key][1] then
                pcall(text.SetFont, text, unpack(d[key]))
            end
        end
    end
    d.active = on
    BF.Color(button)
end

-- Borde negro, o del color del tipo si Blizzard pinta el suyo (perjuicios).
function BF.Color(button)
    local d = skins[button]
    if not (d and d.active) then return end
    -- Casilla sin aura (sin icono): sin borde. Antes se veían recuadros vacíos.
    local okTex, texture = pcall(d.icon.GetTexture, d.icon)
    local empty = okTex and not IsSecret(texture) and (texture == nil or texture == "" or texture == 0)
    local okShown, shown = pcall(button.IsShown, button)
    if empty or (okShown and not IsSecret(shown) and not shown) then
        d.border:Hide()
        return
    end
    d.border:SetShown(A.db.buffFrame.skin and (A.db.buffFrame.border or 1) > 0)
    local r, g, b = BlizzardBorderColor(button)
    -- Blizzard pinta algunos bordes con la textura ya coloreada (su color de
    -- vértice es blanco): entonces el rojo de perjuicio, nunca blanco.
    if r and r > 0.9 and g > 0.9 and b > 0.9 then r, g, b = 0.8, 0.1, 0.1 end
    if r then d.border:SetVertexColor(r, g, b, 1) else d.border:SetVertexColor(0, 0, 0, 1) end
end

---------------------------------------------------------------------------
-- La flechita de plegar / desplegar
---------------------------------------------------------------------------
local function CollapseButton()
    local frame = _G.BuffFrame
    return frame and (Child(frame, "CollapseAndExpandButton") or Child(frame, "CollapseButton"))
end

function BF.SkinCollapse()
    local button = CollapseButton()
    if not button then return end
    local on = A.db.buffFrame.skin
    local d = skins[button]
    if not d then
        d = {}
        d.bg = button:CreateTexture(nil, "BACKGROUND", nil, -8)
        d.bg:SetPoint("CENTER")
        d.arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        d.arrow:SetPoint("CENTER")
        d.arrow:SetTexture(M.ICONS.chevron)
        d.hover = button:CreateTexture(nil, "HIGHLIGHT", nil, 7)
        d.hover:SetAllPoints(d.bg)
        d.hover:SetColorTexture(1, 1, 1, 0.1)
        skins[button] = d
        button:HookScript("OnClick", function() C_Timer.After(0, BF.UpdateCollapse) end)
    end
    for _, region in pairs({
        button.GetNormalTexture and button:GetNormalTexture(), button.GetPushedTexture and button:GetPushedTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(), button.GetCheckedTexture and button:GetCheckedTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
    }) do Hold(region, on) end
    for _, region in ipairs({ button:GetRegions() }) do
        if region ~= d.bg and region ~= d.arrow and region ~= d.hover and region.GetObjectType
           and region:GetObjectType() == "Texture" then Hold(region, on) end
    end
    d.bg:SetSize(16, 22)
    d.bg:SetColorTexture(0.08, 0.08, 0.09, 0.9)
    d.arrow:SetSize(14, 14)
    local a = M.COLORS.accent
    d.arrow:SetVertexColor(a[1], a[2], a[3])
    d.bg:SetShown(on)
    d.arrow:SetShown(on)
    d.hover:SetShown(on)
    BF.UpdateCollapse()
end

-- Plegado: la flecha mira hacia fuera (para desplegar); desplegado, hacia dentro.
function BF.UpdateCollapse()
    local button = CollapseButton()
    local d = button and skins[button]
    if not d then return end
    local collapsed = button.GetChecked and button:GetChecked()
    if IsSecret(collapsed) then return end
    d.arrow:SetRotation(collapsed and math.pi or 0)
end

---------------------------------------------------------------------------
function BF.ApplyAll()
    if not (A.db and A.db.buffFrame) then return end
    if InCombatLockdown() then
        ns.AfterCombat("AurasBuffFrame", BF.ApplyAll)
        return
    end
    for _, button in ipairs(BF.Buttons()) do pcall(BF.SkinButton, button) end
    pcall(BF.SkinCollapse)
end

-- Cada medio segundo fuera de combate: botones nuevos y color de los bordes.
local clock = CreateFrame("Frame")
local waited = 0
clock:SetScript("OnUpdate", function(_, elapsed)
    waited = waited + elapsed
    if waited < 0.5 then return end
    waited = 0
    if not (A.active and A.db and A.db.buffFrame and A.db.buffFrame.skin) or InCombatLockdown() then return end
    for _, button in ipairs(BF.Buttons()) do
        if not skins[button] then pcall(BF.SkinButton, button) else pcall(BF.Color, button) end
    end
    BF.UpdateCollapse()
end)

local baseEnable = A.OnEnable
function A:OnEnable()
    if baseEnable then baseEnable(self) end
    BF.ApplyAll()
end
