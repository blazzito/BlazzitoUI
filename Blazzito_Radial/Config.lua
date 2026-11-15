-- Blazzito_Radial: página «Menú radial» en /bui.
local ns = BlazzitoUI
local R = ns and ns.Radial
if not (R and ns.Config and ns.Widgets) then return end

local W = ns.Widgets
local M = ns.Media
local T = W.T
local function Tr(s) return ns.Translate and ns.Translate(s) or s end

-- Fila «Tecla: X» que se pone al día sola.
local function KeyInfo(parent, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 26)
    local label = W.Text(f, 13, T.textSoft)
    label:SetPoint("LEFT")
    label:SetText(Tr("Tecla"))
    local value = W.Text(f, 13, T.text, false, "bold")
    value:SetPoint("RIGHT")
    value:SetJustifyH("RIGHT")
    function f:Refresh()
        if R.capturing then
            value:SetText(Tr("Pulsa una tecla... (Esc cancela)"))
            value:SetTextColor(unpack(W.COLORS.accent))
        else
            value:SetText(R.KeyText() or Tr("sin asignar"))
            value:SetTextColor(unpack(T.text))
        end
    end
    f:Refresh()
    return f
end

-- Escucha la próxima tecla (con sus modificadores) y la asigna.
local catcher
local function Capture(onDone)
    if not catcher then
        catcher = CreateFrame("Frame", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher:EnableKeyboard(true)
        if catcher.SetPropagateKeyboardInput then catcher:SetPropagateKeyboardInput(false) end
        catcher:Hide()
        catcher:SetScript("OnKeyDown", function(self, k)
            if k == "ESCAPE" then
                R.capturing = nil
                self:Hide()
                if self.done then self.done() end
                return
            end
            local name = R.KeyName(k)
            if not name then return end
            R.capturing = nil
            self:Hide()
            R.SetKey(name)
            if self.done then self.done() end
        end)
    end
    catcher.done = onDone
    R.capturing = true
    catcher:Show()
end
R.Capture = Capture

ns.Config.RegisterPage("radial", "Menú radial", 20, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = R.db
    local function set(key)
        return function(value) db[key] = value; R.Apply(); L:RefreshStates() end
    end
    local function get(key) return function() return db[key] end end

    -- Vista previa fija arriba: se ve cada cambio al momento. Al pasar el
    -- ratón se ve el indicador; Monturas y Gestos abren su página.
    local pin = L:Pinned(320)
    local preview = R.NewPreview(pin, 300)
    preview:SetPoint("CENTER", pin, "CENTER", 0, 0)
    local tip = W.Text(pin, 11, T.dim)
    tip:SetPoint("BOTTOMLEFT", pin, "BOTTOMLEFT", 22, 8)
    tip:SetText(Tr("Vista previa: pasa el ratón por los botones"))

    local card = L:Card("Cómo se abre")
    local try = W.Button(card.actions, nil, "Probar", function() R.Open() end, true)
    try:SetPoint("RIGHT")
    local info = KeyInfo(content, col)
    local assign
    assign = W.Button(content, col, "Asignar tecla", function()
        Capture(function() info:Refresh() end)
        info:Refresh()
    end)
    L:Row(info, assign)
    local drag = W.Button(content, col, "Coger para arrastrar a una barra", function() R.PickupMacro() end)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() R.PickupMacro() end)
    L:Row(W.Button(content, col, "Quitar la tecla", function() R.SetKey(nil); info:Refresh() end), drag)
    L:Note("Mantén la tecla, lleva el ratón a un botón y suelta: se usa ese. Con un toque corto el anillo se queda abierto para elegir con el ratón; se cierra con la misma tecla, con Esc, pulsando el centro o pulsando fuera del anillo. Funciona también en combate.")
    L:Note("En la barra se pone la macro «BUI Radial»: al pulsarla el anillo se abre y eliges con el ratón. La tecla también se puede cambiar en Opciones > Atajos > AddOns > BlazzitoUI.")
    L:EndCard()

    L:Card("Qué sale en el anillo")
    local pending
    for _, entry in ipairs(R.ROOT) do
        local available = R.Available(entry)
        local label = entry.title
        if not available then label = Tr(entry.title) .. " " .. Tr("(no existe en este cliente)") end
        local t = W.Toggle(content, col, label,
            function() return db.items[entry.key] end,
            function(v) db.items[entry.key] = v; R.Apply() end)
        local cond = function() return available end
        if pending then L:Row(pending.w, t, pending.cond, cond); pending = nil
        else pending = { w = t, cond = cond } end
    end
    if pending then L:Row(pending.w, nil, pending.cond) end
    L:Note("Van en el sentido de las agujas del reloj empezando arriba. Monturas y Gestos abren un segundo anillo: el centro vuelve atrás.")
    L:EndCard()

    L:Card("Gestos")
    pending = nil
    for _, entry in ipairs(R.EMOTES) do
        local t = W.Toggle(content, col, Tr(entry.title) .. "  |cff8a9099" .. entry.cmd .. "|r",
            function() return db.emotes[entry.key] end,
            function(v) db.emotes[entry.key] = v; R.Apply() end)
        if pending then L:Row(pending, t); pending = nil else pending = t end
    end
    if pending then L:Row(pending) end
    L:Note("Si tienes a alguien seleccionado, el gesto va dirigido a él.")
    L:EndCard()

    L:Card("Monturas")
    L:Row(W.Slider(content, col, "Monturas en el anillo", 4, 16, 1, get("maxMounts"), set("maxMounts")))
    L:Note("Primero tus favoritas del diario de monturas y luego las demás por nombre. El primer botón abre la colección.")
    L:EndCard()

    local shapes = {}
    for i, k in ipairs(M.BUTTON_SHAPE_ORDER) do shapes[i] = { value = k, text = M.BUTTON_SHAPES[k].text } end
    L:Card("Botones")
    L:Row(W.Dropdown(content, col, "Forma", shapes, get("shape"), set("shape")),
          W.Slider(content, col, "Grosor del borde", 1, 3, 1, get("border"), set("border")))
    L:Row(W.Slider(content, col, "Tamaño de los iconos", 36, 72, 2, get("iconSize"), set("iconSize")),
          W.Toggle(content, col, "Nombres bajo los iconos", get("labels"), set("labels")))
    L:Row(W.Toggle(content, col, "Atenuar los demás al elegir uno", get("dimOthers"), set("dimOthers")),
          W.Toggle(content, col, "Icono del elegido en el centro", get("centerIcon"), set("centerIcon")))
    L:EndCard()

    local function custom() return db.accentMode == "custom" end
    L:Card("Anillo")
    L:Row(W.Slider(content, col, "Tamaño (%)", 60, 150, 5, get("scale"), set("scale")),
          W.Slider(content, col, "Separación del centro", 90, 200, 5, get("radius"), set("radius")))
    L:Row(W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("backdrop"), set("backdrop")),
          W.Toggle(content, col, "Órbita (línea por donde van los botones)", get("orbit"), set("orbit")))
    L:Row(W.Toggle(content, col, "Indicador de dirección", get("pointer"), set("pointer")),
          W.Button(content, 160, "Mover el anillo", function() ns.Movers.Toggle() end))
    L:Row(W.Dropdown(content, col, "Color del acento", {
              { value = "class", text = "El de tu clase" },
              { value = "custom", text = "Personalizado" },
          }, get("accentMode"), set("accentMode")),
          W.Color(content, col, "Color personalizado", get("accent"), function(r, g, b)
              db.accent = { r, g, b }; R.Apply()
          end), nil, custom)
    L:Note("El acento colorea el borde del botón elegido y el indicador de dirección: un arco en el borde del anillo que señala hacia dónde vas.")
    L:EndCard()

    L:Refresh()
    return L
end)
