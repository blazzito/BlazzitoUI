-- Temporizadores de golpe (mano derecha, mano izquierda y a distancia) con el
-- estilo de BlazzitoUI. WoW Forever trae los suyos (Blizzard_SwingTimer) y la
-- API debajo; aquí se usan los mismos datos del juego y se dibujan en barras
-- propias con forma, borde, colores, texto y aviso de fuera de rango:
--   PLAYER_SWING(duración, tipo)                 -- un evento por golpe
--   PLAYER_SWING_RANGE_UPDATE(tipo, aRango, compruebaRango)
--   C_SwingTimer.EnableRangeCheck(tipo, true)    -- pedir los avisos de rango
--   Enum.PlayerSwingType.MainHand | OffHand | Ranged
-- El temporizador de Blizzard, si se encuentra, se oculta (alfa 0) para no
-- tener dos (opción en la configuración).
local ns = BlazzitoUI
if not (ns and ns.ActionBars) then return end

local AB, M = ns.ActionBars, ns.Media
local IsSecret, Readable = M.IsSecret, M.Readable

local S = {}
AB.Swing = S
local TYPES = Enum and Enum.PlayerSwingType or {}
S.available = C_SwingTimer ~= nil

local ROWS = {
    swing_mh     = { type = TYPES.MainHand or 0, frame = "BlazzitoUISwingMainHand", tag = "Derecha", pos = { "CENTER", "CENTER", 0, -150 } },
    swing_oh     = { type = TYPES.OffHand or 1,  frame = "BlazzitoUISwingOffHand",  tag = "Izquierda", pos = { "CENTER", "CENTER", 0, -168 } },
    swing_ranged = { type = TYPES.Ranged or 2,   frame = "BlazzitoUISwingRanged",   tag = "Distancia", pos = { "CENTER", "CENTER", 0, -186 } },
}
S.ROWS = ROWS
local BY_TYPE = {}
for key, row in pairs(ROWS) do row.key = key; BY_TYPE[row.type] = row end

local function Cfg(key) return AB.db.bars[key] end

---------------------------------------------------------------------------
-- Barras
---------------------------------------------------------------------------
local function Build(row)
    local f = CreateFrame("Frame", row.frame, UIParent)
    f:SetFrameStrata("MEDIUM")
    f:Hide()
    f.border = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    f.bar = M.StatusBar(f)
    f.bar:SetAllPoints()
    f.bar.bg:SetDrawLayer("BACKGROUND", -7)
    f.mask = f:CreateMaskTexture()
    f.mask:SetAllPoints(f.bar)
    f.lead = f:CreateMaskTexture()
    local fill = f.bar:GetStatusBarTexture()
    fill:AddMaskTexture(f.mask)
    fill:AddMaskTexture(f.lead)
    f.bar.bg:AddMaskTexture(f.mask)
    f.spark = f.bar:CreateTexture(nil, "OVERLAY")
    f.spark:SetColorTexture(1, 1, 1, 0.9)
    f.spark:SetBlendMode("ADD")
    f.spark:SetWidth(2)
    f.spark:SetPoint("TOP", fill, "TOPRIGHT", 0, 0)
    f.spark:SetPoint("BOTTOM", fill, "BOTTOMRIGHT", 0, 0)
    f.text = f.bar:CreateFontString(nil, "OVERLAY")
    f.label = f.bar:CreateFontString(nil, "OVERLAY")
    f.row = row
    row.f = f
    f:SetScript("OnUpdate", function(self) S.Tick(self.row) end)
    return f
end

local WEAPON_SLOT = { swing_mh = 16, swing_oh = 17, swing_ranged = 18 }
local WEAPON_CLASS = 2   -- Enum.ItemClass.Weapon

local function IsWeapon(itemID)
    if not (C_Item and C_Item.GetItemInfoInstant) then return true end
    local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, itemID)
    if not ok or classID == nil then return true end   -- sin datos aún: se da por buena
    return classID == WEAPON_CLASS
end

-- ¿Hay arma para esa mano? Se mira lo que llevas equipado: la velocidad de
-- ataque del juego (UnitAttackSpeed) puede llegar "secreta" en este cliente y
-- entonces todas las barras parecían sin arma. Mano derecha siempre (sin arma
-- se pega con los puños); izquierda solo con un arma (no escudo ni objeto de
-- mano); distancia con arco, fusil, ballesta, arrojadiza o varita (no reliquias).
function S.HasWeapon(row)
    if row.running and not row.sample then return true end   -- si golpea, la hay
    if row.key == "swing_mh" then return true end
    local slot = WEAPON_SLOT[row.key]
    local itemID = slot and GetInventoryItemID and GetInventoryItemID("player", slot)
    if itemID and not IsSecret(itemID) then return IsWeapon(itemID) end
    if itemID == nil and GetInventoryItemID then return false end
    -- Último recurso: la velocidad de ataque, si se puede leer.
    if row.key == "swing_ranged" then
        local speed = UnitRangedDamage and Readable((UnitRangedDamage("player")))
        return type(speed) == "number" and speed > 0
    end
    local _, off = UnitAttackSpeed("player")
    off = Readable(off)
    return type(off) == "number" and off > 0
end

-- Vista previa: con la configuración de barras abierta, la opción de
-- mostrarlas todas o el modo mover, un golpe de ejemplo que se repite.
local function Previewing(row)
    if ns.Movers and ns.Movers.unlocked then return true end
    if AB.preview then return true end
    return AB.HighlightKey and AB.HighlightKey() ~= nil
end

function S.Apply(key)
    local row = ROWS[key]
    if not row then return end
    local f = row.f or Build(row)
    local cfg = Cfg(key)
    local w, h = cfg.width or 200, cfg.height or 12
    f:SetSize(w, h)
    local shape = cfg.skin and cfg.shape or "rect"
    local file = M.ShapeTexture(shape, cfg.flipH, cfg.flipV)
    local b = (cfg.border or 0) > 0 and PixelUtil and PixelUtil.GetNearestPixelSize(cfg.border, f:GetEffectiveScale(), cfg.border) or (cfg.border or 0)
    f.border:ClearAllPoints()
    f.border:SetPoint("TOPLEFT", -b, b)
    f.border:SetPoint("BOTTOMRIGHT", b, -b)
    f.border:SetTexture(file)
    local bc = cfg.borderColor or { 0, 0, 0 }
    f.border:SetVertexColor(bc[1], bc[2], bc[3], 1)
    f.border:SetShown(b > 0)
    f.mask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    -- Máscara de punta: el final del relleno con la misma forma.
    f.lead:ClearAllPoints()
    f.lead:SetSize(w, h)
    f.lead:SetPoint("RIGHT", f.bar:GetStatusBarTexture(), "RIGHT", 0, 0)
    f.lead:SetTexture((M.SHAPES[shape] or {}).file and file or M.TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local c = cfg.color or { 1, 1, 1 }
    f.bar:SetStatusBarColor(c[1], c[2], c[3])
    f.bar.bg:SetVertexColor(0.05, 0.05, 0.06, (cfg.background or 60) / 100)
    local inset = M.ShapeInset(shape, w)
    local size = math.max(8, math.floor(h * 0.8))
    f.text:SetFont(M.FONT, size, "OUTLINE")
    f.text:ClearAllPoints()
    f.text:SetPoint("RIGHT", f.bar, "RIGHT", -inset, 0)
    f.label:SetFont(M.FONT, size, "OUTLINE")
    f.label:ClearAllPoints()
    f.label:SetPoint("LEFT", f.bar, "LEFT", inset, 0)
    f.label:SetText(ns.Translate(row.tag))
    f.label:SetShown(cfg.label and true or false)
    if C_SwingTimer and C_SwingTimer.EnableRangeCheck then
        pcall(C_SwingTimer.EnableRangeCheck, row.type, cfg.rangeTint and true or false)
    end
    S.Update(row)
end

-- Colores según el rango: fuera de rango se apaga.
local function Paint(row)
    local f, cfg = row.f, Cfg(row.key)
    local c = cfg.color or { 1, 1, 1 }
    if cfg.rangeTint and row.outOfRange then
        f.bar:SetStatusBarColor(c[1] * 0.35, c[2] * 0.35, c[3] * 0.35)
        f.text:SetTextColor(1, 0.35, 0.35)
    else
        f.bar:SetStatusBarColor(c[1], c[2], c[3])
        f.text:SetTextColor(1, 1, 1)
    end
end

-- ¿Se muestra? Activada, con arma para esa mano y (si se oculta en reposo)
-- golpeando; en la vista previa siempre.
function S.Update(row)
    local f = row.f
    if not f then return end
    local cfg = Cfg(row.key)
    local preview = Previewing(row)
    -- "Ocultar fuera de combate" (clave hideIdle): fuera de combate no se ve;
    -- en combate siempre, golpees o no.
    local inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) or InCombatLockdown()
    if IsSecret(inCombat) then inCombat = true end
    local show = cfg.shown ~= false and (preview or (S.HasWeapon(row) and (inCombat or not cfg.hideIdle)))
    if preview and not row.running then
        row.start, row.duration, row.running, row.sample = GetTime(), 2.2, true, true
    end
    f:SetShown(show and true or false)
    Paint(row)
    S.Tick(row)
end

function S.Tick(row)
    local f = row.f
    if not (f and f:IsShown()) then return end
    local cfg = Cfg(row.key)
    if not row.running then
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(1)
        f.text:SetText("")
        f.spark:Hide()
        return
    end
    local elapsed = GetTime() - row.start
    if elapsed >= row.duration then
        if row.sample and Previewing(row) then
            row.start = GetTime()
            elapsed = 0
        else
            row.running, row.sample = false, nil
            S.Update(row)
            return
        end
    end
    f.bar:SetMinMaxValues(0, row.duration)
    f.bar:SetValue(elapsed)
    f.spark:Show()
    if cfg.timeText then f.text:SetFormattedText("%.1f", row.duration - elapsed) else f.text:SetText("") end
end

---------------------------------------------------------------------------
-- Eventos del juego
---------------------------------------------------------------------------
function S.OnSwing(duration, swingType)
    local row = BY_TYPE[swingType]
    if not row or not row.f then return end
    duration = Readable(duration)
    if type(duration) ~= "number" or duration <= 0 then return end
    row.start, row.duration, row.running, row.sample = GetTime(), duration, true, nil
    S.Update(row)
end

function S.OnRange(swingType, inRange, checks)
    local row = BY_TYPE[swingType]
    if not row then return end
    inRange, checks = Readable(inRange), Readable(checks)
    row.outOfRange = (checks and inRange == false) and true or false
    if row.f then Paint(row) end
end

function S.UpdateAll()
    for _, row in pairs(ROWS) do S.Update(row) end
end

---------------------------------------------------------------------------
-- El temporizador de Blizzard: se buscan sus marcos (globales de Blizzard
-- con "Swing" en el nombre) y se dejan a alfa 0 mientras la opción esté.
---------------------------------------------------------------------------
-- Dos vías: (1) cualquier marco que escuche PLAYER_SWING y no sea nuestro (el
-- de Blizzard tiene que escucharlo para funcionar; no hace falta saber su
-- nombre) y (2) globales de Blizzard con "Swing" en el nombre.
local OURS = {}
function S.FindBlizzard()
    local found, seen = {}, {}
    -- Nunca la pantalla entera ni un marco del que cuelguen nuestras barras.
    local protected = { [UIParent] = true }
    if WorldFrame then protected[WorldFrame] = true end
    for _, row in pairs(ROWS) do
        local parent = row.f and row.f:GetParent()
        while parent do
            protected[parent] = true
            parent = parent.GetParent and parent:GetParent()
        end
    end
    local function Add(frame, label)
        if type(frame) == "table" and not seen[frame] and not OURS[frame] and not protected[frame] then
            seen[frame] = true
            found[#found + 1] = { frame = frame, name = label }
        end
    end
    if EnumerateFrames then
        local frame = EnumerateFrames()
        local guard = 0
        while frame and guard < 200000 do
            guard = guard + 1
            -- En algunos marcos (botones de aura del motor) estas respuestas son
            -- valores secretos: no se pueden comparar, y un marco así no es el
            -- temporizador de Blizzard.
            local okF, forbidden = pcall(frame.IsForbidden, frame)
            if okF and not IsSecret(forbidden) and not forbidden then
                local ok, registered = pcall(frame.IsEventRegistered, frame, "PLAYER_SWING")
                if ok and Readable(registered) == true then
                    local okN, name = pcall(frame.GetDebugName or frame.GetName, frame)
                    Add(frame, okN and Readable(name) or "(sin nombre)")
                end
            end
            frame = EnumerateFrames(frame)
        end
    end
    for name, value in pairs(_G) do
        if type(name) == "string" and name:find("Swing", 1, true) and not name:find("^Blazzito") and not name:find("^ERB_")
           and type(value) == "table" and type(value.GetObjectType) == "function" then
            local ok, kind = pcall(value.GetObjectType, value)
            local blizzard = issecurevariable and issecurevariable(_G, name)
            if ok and blizzard and (kind == "Frame" or kind == "StatusBar") then Add(value, name) end
        end
    end
    return found
end

function S.ApplyBlizzard()
    local hide = AB.db.style.hideBlizzardSwing and S.available
    -- Los nuestros nunca cuentan (también escuchan PLAYER_SWING).
    OURS[S.events] = true
    for _, row in pairs(ROWS) do if row.f then OURS[row.f] = true end end
    S.blizzard = S.FindBlizzard()
    for _, item in ipairs(S.blizzard) do AB.Hold(item.frame, hide) end
end

---------------------------------------------------------------------------
-- Arranque: se engancha al de las barras de acción
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
S.events = events
events:SetScript("OnEvent", function(_, event, ...)
    if not AB.active then return end
    if event == "PLAYER_SWING" then
        S.OnSwing(...)
    elseif event == "PLAYER_SWING_RANGE_UPDATE" then
        S.OnRange(...)
    elseif event == "ADDON_LOADED" then
        if ... == "Blizzard_SwingTimer" then C_Timer.After(0, S.ApplyBlizzard) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- El de Blizzard puede crearse tarde: se busca otra vez al entrar.
        C_Timer.After(1, S.ApplyBlizzard)
        S.UpdateAll()
    else
        S.UpdateAll()
    end
end)

-- Cuatro veces por segundo: entrar o salir de la vista previa (abrir la
-- configuración, el modo mover...) sin esperar a un golpe.
local clock = CreateFrame("Frame")
local waited = 0
clock:SetScript("OnUpdate", function(_, elapsed)
    waited = waited + elapsed
    if waited < 0.25 then return end
    waited = 0
    if AB.active and AB.db then
        for _, row in pairs(ROWS) do
            local preview = Previewing(row)
            if preview ~= row.wasPreview or (row.sample and not preview) then
                row.wasPreview = preview
                if not preview and row.sample then row.running, row.sample = false, nil end
                S.Update(row)
            end
        end
    end
end)

local baseEnable = AB.OnEnable
function AB:OnEnable()
    if baseEnable then baseEnable(self) end
    for key, row in pairs(ROWS) do
        local f = row.f or Build(row)
        ns.Movers.Register(f, key, AB.BAR_BY_KEY[key].label, row.pos, AB.db.positions, {
            onUnlock = function() S.Update(row) end,
            onLock = function() S.Update(row) end,
            getSize = function() local cfg = Cfg(key); return cfg.width, cfg.height end,
            setSize = function(w, h)
                local cfg = Cfg(key)
                cfg.width = math.max(60, math.min(500, w))
                cfg.height = math.max(4, math.min(40, h))
                S.Apply(key)
            end,
        })
        S.Apply(key)
    end
    -- Eventos que pueden no existir fuera de Forever: cada uno con pcall.
    -- Antes "ocultar en reposo" venía activado y parecía que algo las ocultaba:
    -- ahora viene apagado (una sola vez se apaga en las configuraciones viejas).
    if not AB.db.style.swingIdleReset then
        AB.db.style.swingIdleReset = true
        for key in pairs(ROWS) do AB.db.bars[key].hideIdle = false; S.Apply(key) end
    end
    for _, event in ipairs({ "PLAYER_SWING", "PLAYER_SWING_RANGE_UPDATE", "UNIT_INVENTORY_CHANGED",
                             "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
                             "PLAYER_EQUIPMENT_CHANGED", "UNIT_ATTACK_SPEED", "PLAYER_ENTERING_WORLD", "ADDON_LOADED" }) do
        pcall(events.RegisterEvent, events, event)
    end
    S.ApplyBlizzard()
    ns.RegisterCommand("swing", function()
        ns.Print("temporizador de golpe:")
        print("  API del juego: " .. (S.available and "sí" or "no (este cliente no la tiene)"))
        for _, key in ipairs({ "swing_mh", "swing_oh", "swing_ranged" }) do
            local row = ROWS[key]
            print(string.format("  %s: arma %s · golpeando %s · fuera de rango %s · activada %s · ocultar fuera de combate %s",
                AB.BAR_BY_KEY[key].label, tostring(S.HasWeapon(row)), tostring(row.running or false),
                tostring(row.outOfRange or false), tostring(Cfg(key).shown ~= false), tostring(Cfg(key).hideIdle and true or false)))
            local f = row.f
            if f then
                local ok, line = pcall(function()
                    local x, y = f:GetCenter()
                    local parent = f:GetParent()
                    return string.format("    marco: mostrado %s · se ve %s · alfa %.2f (real %.2f) · centro %s,%s · %dx%d · capa %s · padre %s",
                        tostring(f:IsShown()), tostring(f:IsVisible()), f:GetAlpha(), f:GetEffectiveAlpha(),
                        tostring(x and math.floor(x)), tostring(y and math.floor(y)), math.floor(f:GetWidth() or 0),
                        math.floor(f:GetHeight() or 0), f:GetFrameStrata(), parent and (parent:GetName() or "?") or "ninguno")
                end)
                print(ok and line or ("    marco: " .. tostring(line)))
            end
        end
        S.ApplyBlizzard()
        local names = {}
        for _, item in ipairs(S.blizzard or {}) do names[#names + 1] = tostring(item.name) end
        print("  marcos de Blizzard encontrados (ocultos): " .. (#names > 0 and table.concat(names, ", ") or "ninguno"))
    end, "estado de los temporizadores de golpe")
end
