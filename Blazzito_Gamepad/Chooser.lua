-- La pregunta al entrar: «¿mando o teclado y ratón?».
--
-- Solo al entrar al juego (no en cada /reload), si hay un mando conectado y
-- el jugador no ha dicho «no volver a preguntar».
--
-- Cambiar de estilo es poner el CVar InputDeviceInterfaceStyle (lo mismo que
-- hace la casilla de Blizzard en Opciones > Juego > Gamepad). Ese cambio
-- dispara al momento (evento síncrono) la puesta en marcha de toda la
-- interfaz de mando de Blizzard: si lo hiciera nuestro código, esa puesta en
-- marcha quedaría contaminada. Por eso las dos opciones son botones seguros
-- con una macro («/console …» y «/reload»): al pulsarlos, lo ejecuta el juego
-- como si lo escribiera el jugador. Tras recargar, BlazzitoUI ya arranca con
-- el estilo nuevo (Pad.Session).
--
-- Con el mando: A elige mando, B elige teclado y ratón (atajos solo mientras
-- la ventana está abierta). Si nada responde, se cierra sola sin cambiar nada.
local ns = BlazzitoUI
local GP = ns and ns.Gamepad
if not GP then return end

local Pad, W = ns.Pad, ns.Widgets
local T = W.T
local ACCENT = W.COLORS.accent
local Tr, LF = ns.Translate, ns.LF

local TIMEOUT = 30
local GAMEPAD, MKB = 1, 0   -- Enum.InputDeviceInterfaceType
local KEY_GAMEPAD = _G.GAMEPAD_FACE_BOTTOM or "PAD1"   -- A / ✕
local KEY_MKB = _G.GAMEPAD_FACE_RIGHT or "PAD2"        -- B / ◯

local chooser

local function StyleValue(gamepad)
    local types = Enum and Enum.InputDeviceInterfaceType
    if gamepad then return types and types.Gamepad or GAMEPAD end
    return types and types.Mkb or MKB
end

-- Icono del botón del mando (el de Blizzard: cambia solo entre Xbox y
-- PlayStation); si la plantilla no existe, la letra.
local function Glyph(parent, key, letter)
    local ok, icon = pcall(CreateFrame, "Frame", nil, parent, "InputIconTextureFrameTemplate")
    if ok and icon and icon.SetInputKey and pcall(icon.SetInputKey, icon, key) then
        icon:SetSize(24, 24)
        return icon
    end
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(24, 24)
    W.Panel(f, T.radius, T.field, T.ctrlBorder)
    local text = W.Text(f, 13, T.text, false, "medium")
    text:SetPoint("CENTER")
    text:SetText(letter)
    return f
end

-- Una opción: botón seguro con su macro (puesta al abrir, fuera de combate).
local function Option(parent, name, gamepad, title, desc, key, letter)
    local b = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    b:SetSize(204, 92)
    b:RegisterForClicks("AnyUp", "AnyDown")
    local panel = W.Panel(b, T.radius, T.surface, T.ctrlBorder)
    b.glyph = Glyph(b, key, letter)
    b.glyph:SetPoint("TOPLEFT", 12, -12)
    b.title = W.Text(b, 15, T.text, false, "medium")
    b.title:SetPoint("LEFT", b.glyph, "RIGHT", 8, 0)
    b.title:SetText(Tr(title))
    b.now = W.Text(b, 10, ACCENT, false, "medium")
    b.now:SetPoint("TOPRIGHT", -10, -14)
    b.now:SetText(W.Upper(Tr("ahora")))
    b.desc = W.Text(b, 12, T.dim, true)
    b.desc:SetPoint("TOPLEFT", 12, -44)
    b.desc:SetPoint("RIGHT", -12, 0)
    b.desc:SetJustifyH("LEFT")
    b.desc:SetText(Tr(desc))
    b.gamepad = gamepad
    b.bindName = name

    local hot = false
    function b:Paint()
        local current = Pad.On() == self.gamepad
        self.now:SetShown(current)
        panel.border:SetColor((hot or current) and ACCENT or T.ctrlBorder)
    end
    b:HookScript("OnEnter", function(self) hot = true; self:Paint() end)
    b:HookScript("OnLeave", function(self) hot = false; self:Paint() end)
    -- Tras la macro (o si ya era el estilo elegido), se cierra.
    b:HookScript("PostClick", function() if chooser then chooser:Close() end end)
    return b
end

local function Build()
    local f = CreateFrame("Frame", "BlazzitoUIPadChooser", UIParent)
    f:SetSize(468, 224)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:Hide()
    W.Panel(f, T.radius, T.bg, T.line)
    local top = W.Line(f, ACCENT)
    top:SetPoint("TOPLEFT", 1, -1)
    top:SetPoint("TOPRIGHT", -1, -1)

    local title = W.SectionTitle(f, "¿Cómo vas a jugar?", 13)
    title:SetPoint("TOPLEFT", 20, -18)
    f.sub = W.Text(f, 12, T.dim)
    f.sub:SetPoint("TOPLEFT", 20, -38)
    f.sub:SetPoint("RIGHT", -48, 0)
    f.sub:SetJustifyH("LEFT")

    local close = CreateFrame("Button", "BlazzitoUIPadChooserClose", f)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -12, -12)
    local x = close:CreateTexture(nil, "ARTWORK")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetTexture(ns.Media.ICONS.close)
    x:SetVertexColor(unpack(T.min))
    close:SetScript("OnClick", function() f:Close() end)
    close:SetScript("OnEnter", function() x:SetVertexColor(unpack(T.text)) end)
    close:SetScript("OnLeave", function() x:SetVertexColor(unpack(T.min)) end)

    f.pad = Option(f, "BlazzitoUIPadChoiceGamepad", true, "Mando",
        "Barras, menús y navegación de Blizzard para jugar con el mando.", KEY_GAMEPAD, "A")
    f.pad:SetPoint("TOPLEFT", 20, -66)
    f.mkb = Option(f, "BlazzitoUIPadChoiceMkb", false, "Teclado y ratón",
        "La interfaz de PC de siempre, con todo el estilo de BlazzitoUI.", KEY_MKB, "B")
    f.mkb:SetPoint("TOPRIGHT", -20, -66)

    f.never = W.Toggle(f, 210, "No volver a preguntar",
        function() return not GP.db.ask end,
        function(v) GP.db.ask = not v end)
    f.never:SetPoint("BOTTOMLEFT", 20, 16)
    f.timer = W.Text(f, 11, T.min)
    f.timer:SetPoint("BOTTOMRIGHT", -20, 22)

    -- Cuenta atrás: si el mando no llega a la ventana, no se queda ahí.
    f:SetScript("OnUpdate", function(self, elapsed)
        self.left = (self.left or TIMEOUT) - elapsed
        if self.left <= 0 then self:Close() return end
        self.timer:SetText(LF("Se cierra en %d s sin cambiar nada", math.ceil(self.left)))
    end)

    -- Cada opción: macro si cambia el estilo; si ya es el actual, solo cierra.
    function f:Arm()
        for _, b in ipairs({ self.pad, self.mkb }) do
            if Pad.On() == b.gamepad then
                b:SetAttribute("type", nil)
                b:SetAttribute("macrotext", nil)
            else
                b:SetAttribute("type", "macro")
                b:SetAttribute("macrotext", "/console InputDeviceInterfaceStyle " .. StyleValue(b.gamepad) .. "\n/reload")
            end
            b:Paint()
        end
        -- A y B del mando (y Escape) solo mientras está abierta.
        ClearOverrideBindings(self)
        SetOverrideBindingClick(self, true, KEY_GAMEPAD, self.pad.bindName, "LeftButton")
        SetOverrideBindingClick(self, true, KEY_MKB, self.mkb.bindName, "LeftButton")
        SetOverrideBindingClick(self, true, "ESCAPE", "BlazzitoUIPadChooserClose", "LeftButton")
    end

    function f:Close()
        if InCombatLockdown() then return end
        ClearOverrideBindings(self)
        self:Hide()
    end
    f:SetScript("OnHide", function(self)
        if not InCombatLockdown() then ClearOverrideBindings(self) end
    end)
    return f
end

-- Abre la pregunta (también a mano: /bui mando elegir). force: aunque no haya mando.
function GP.ShowChooser(force)
    if InCombatLockdown() then
        if force then ns.Print("espera a salir de combate para elegir.") end
        return false
    end
    local devices = Pad.Devices()
    if #devices == 0 and not force then return false end
    chooser = chooser or Build()
    chooser.sub:SetText(#devices > 0 and LF("Hay un mando conectado: %s.", devices[1])
        or Tr("No se detecta ningún mando conectado."))
    chooser.left = TIMEOUT
    chooser.never:Refresh()
    chooser:Arm()
    chooser:Show()
    return true
end

function GP.CloseChooser()
    if chooser and chooser:IsShown() then chooser:Close() end
end

function GP.SetupChooser()
    ns.RegisterCommand("mando elegir", function() GP.ShowChooser(true) end, "pregunta si quieres la interfaz de mando o la de teclado y ratón")
    ns.On("PLAYER_ENTERING_WORLD", function(_, isInitialLogin)
        if not (isInitialLogin and GP.active and GP.db.ask) then return end
        -- Un instante después de entrar: el mando ya está detectado y la pantalla quieta.
        C_Timer.After(2, function() GP.ShowChooser(false) end)
    end)
end
