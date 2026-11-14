-- Página "Marcos de unidad" de la ventana de configuración.
-- Las pestañas eligen qué marco se edita; los cambios se aplican al momento.
-- Cada sección es una tarjeta: al cambiar algo en ella aparecen dos iconos.
-- Copiar lleva los ajustes de esa tarjeta al marco pareja (Jugador <-> Objetivo,
-- Mascota <-> Obj. del objetivo); Revertir, durante 10 segundos, deshace el
-- cambio y la copia.
local _, ns = ...

local UF = ns.UnitFrames
local W = ns.Widgets

UF.editing = "player"

local REVERT_SECONDS = 10
-- El foco copia al objetivo y su objetivo al del objetivo (tamaños parecidos).
local PAIR = { player = "target", target = "player", pet = "targettarget", targettarget = "pet",
    focus = "target", focustarget = "targettarget" }

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local SHAPES = {}
for i, key in ipairs(ns.Media.SHAPE_ORDER) do
    SHAPES[i] = { value = key, text = ns.Media.SHAPES[key].text }
end
local PORTRAITS = Choices({ { "none", "Ninguno" }, { "2d", "2D" }, { "3d", "3D" }, { "3dbar", "3D dentro de la barra" }, { "class", "Icono de clase" } })
UF.PORTRAIT_CHOICES = PORTRAITS
local HEALTH_COLORS = Choices({
    { "class", "Clase (criaturas por reacción)" },
    { "gradient", "Según la vida (verde a rojo)" },
    { "custom", "Color personalizado" },
})
local HEALTH_TEXT = Choices({
    { "percent", "Porcentaje" }, { "value", "Valor" }, { "both", "Valor y porcentaje" }, { "none", "Ninguno" },
})
local POWER_COLORS = Choices({
    { "type", "Según el recurso (maná, ira, energía...)" },
    { "class", "Clase (criaturas por reacción)" },
    { "custom", "Color personalizado" },
})

local COMBO_POSITIONS = Choices({
    { "above", "Encima de las barras" }, { "below", "Debajo de las barras" }, { "edge", "Montados en el borde de arriba" },
})
local COMBO_ALIGN = Choices({
    { "spread", "Repartidos a lo ancho" }, { "left", "Izquierda" }, { "center", "Centro" }, { "right", "Derecha" },
})
local COMBO_COLORS = Choices({
    { "gradient", "Degradado (amarillo a naranja)" }, { "class", "Color de clase" }, { "custom", "Color personalizado" },
})

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end

-- Las barras de lanzamiento de Jugador y Mascota sustituyen a las de Blizzard:
-- si cambian, hace falta recargar.
local function CastbarsState()
    local state = ""
    for _, unit in ipairs(UF.UNITS) do
        if UF.INFO[unit].castbarBlizzard then state = state .. tostring(UF.db.units[unit].castbar) end
    end
    return state
end

---------------------------------------------------------------------------
-- Sesión de una tarjeta: guarda cómo estaba todo antes del primer cambio
---------------------------------------------------------------------------
local sessions = {}

-- ctx dice qué ajustes edita la tarjeta (los marcos de unidad por defecto;
-- otros módulos, como Blazzito_Auras, pasan el suyo):
--   units() tabla por unidad · style() ajustes comunes · editing() unidad editada
--   apply(unit) / applyAll() · reloadState() cadena que, si cambia, pide recargar
local UF_CONTEXT = {
    units = function() return UF.db.units end,
    style = function() return UF.db.style end,
    editing = function() return UF.editing end,
    apply = function(unit) UF.ApplyUnit(unit) end,
    applyAll = function() UF.ApplyAll() end,
    reloadState = CastbarsState,
}

local function NewSession(card, keys, styleKeys, layout, ctx)
    ctx = ctx or UF_CONTEXT
    local function ReloadState() return ctx.reloadState and ctx.reloadState() or "" end
    local session = { keys = keys, styleKeys = styleKeys or {} }
    sessions[#sessions + 1] = session

    local actions = card.actions
    local revert, copy

    function session.End()
        session.snapshot = nil
        actions:Hide()
    end

    local function Restart()
        session.remaining = REVERT_SECONDS
        revert.progress:SetWidth(22)
        actions:Show()
    end

    -- Se llama ANTES de aplicar cada cambio de la tarjeta.
    function session.Touch()
        if not session.snapshot then
            local snap = { units = {}, style = {} }
            -- Todas las entradas del contexto (unidades, o Grupo / Banda...).
            for unit, values in pairs(ctx.units()) do
                snap.units[unit] = {}
                for _, key in ipairs(keys) do snap.units[unit][key] = Copy(values[key]) end
            end
            for _, key in ipairs(session.styleKeys) do snap.style[key] = Copy(ctx.style()[key]) end
            session.snapshot = snap
            session.castbars = ReloadState()
        end
        session.copied = nil
        copy:SetTint(nil)
        Restart()
    end

    local function PairLabel()
        if ctx.copyAll then return ctx.copyAllLabel or "todos" end
        local pair = (ctx.pair or PAIR)[ctx.editing()]
        return ctx.label and ctx.label(pair) or UF.INFO[pair].label
    end
    copy = W.IconButton(actions, ns.Media.ICONS.copy, function()
        if session.copied then return "Copiado a " .. PairLabel() end
        return "Copiar a " .. PairLabel()
    end, function()
        local units, editing = ctx.units(), ctx.editing()
        local source = units[editing]
        local before = ReloadState()
        if ctx.copyAll then
            -- Copiar a todas las entradas del contexto que tengan esas opciones
            -- (ctx.copyAll(key) decide cuáles; p. ej. solo barras de botones).
            for targetKey, target in pairs(units) do
                if targetKey ~= editing and ctx.copyAll(targetKey, editing) then
                    for _, key in ipairs(keys) do
                        if source[key] ~= nil and target[key] ~= nil then target[key] = Copy(source[key]) end
                    end
                end
            end
            ctx.applyAll()
        else
            local pairKey = (ctx.pair or PAIR)[editing]
            local target = units[pairKey]
            for _, key in ipairs(keys) do target[key] = Copy(source[key]) end
            ctx.apply(pairKey)
        end
        if ReloadState() ~= before then ns.AskReload() end
        session.copied = true
        copy:SetTint(W.COLORS.accent)
        Restart()
    end)
    revert = W.IconButton(actions, ns.Media.ICONS.revert, function()
        return string.format("Revertir (%d s)", math.ceil(session.remaining or 0))
    end, function()
        local snap = session.snapshot
        if not snap then return end
        for unit, values in pairs(snap.units) do
            for key, value in pairs(values) do ctx.units()[unit][key] = Copy(value) end
        end
        for key, value in pairs(snap.style) do ctx.style()[key] = Copy(value) end
        local changedCastbars = ReloadState() ~= session.castbars
        session.End()
        ctx.applyAll()
        layout:Refresh()
        if changedCastbars then ns.AskReload() end
    end)
    revert:SetPoint("RIGHT")
    copy:SetPoint("RIGHT", revert, "LEFT", -6, 0)
    -- Línea bajo el icono de revertir que se acorta con la cuenta atrás.
    revert.progress = revert:CreateTexture(nil, "OVERLAY")
    revert.progress:SetPoint("BOTTOMLEFT", 1, 1)
    revert.progress:SetHeight(2)
    local a = W.COLORS.accent
    revert.progress:SetColorTexture(a[1], a[2], a[3], 1)

    -- Cuenta atrás: al llegar a 0 el cambio queda fijo.
    actions:SetScript("OnUpdate", function(_, elapsed)
        session.remaining = session.remaining - elapsed
        if session.remaining <= 0 then
            session.End()
            if revert.hovered then GameTooltip:Hide() end
        else
            revert.progress:SetWidth(math.max(1, 22 * session.remaining / REVERT_SECONDS))
            revert:UpdateTooltip()
        end
    end)
    actions:Hide()

    -- Envoltorios para los controles de la tarjeta.
    function session.Set(key)
        return function(value)
            session.Touch()
            ctx.units()[ctx.editing()][key] = value
            ctx.apply(ctx.editing())
            layout:RefreshStates()
        end
    end
    function session.SetColor(key)
        return function(r, g, b)
            session.Touch()
            ctx.units()[ctx.editing()][key] = { r, g, b }
            ctx.apply(ctx.editing())
        end
    end
    function session.SetStyle(key)
        return function(value)
            session.Touch()
            ctx.style()[key] = value
            ctx.applyAll()
            layout:RefreshStates()
        end
    end
    function session.SetStyleColor(key)
        return function(r, g, b)
            session.Touch()
            ctx.style()[key] = { r, g, b }
            ctx.applyAll()
        end
    end
    return session
end

-- Para otros módulos: misma tarjeta con copiar (a la pareja) y revertir.
UF.NewCardSession = NewSession
UF.PAIR = PAIR

local function EndAllSessions()
    for _, session in ipairs(sessions) do session.End() end
end

---------------------------------------------------------------------------
-- Página
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Vista previa en vivo: el marco que se edita, dibujado con el mismo motor
-- (UF.Build / UF.ApplyLayout) y tus datos, en un panel fijo a la derecha.
-- Es un marco normal (no seguro) sin unidad propia (buiUnit = nil): los
-- ganchos de auras y grupo lo ignoran.
---------------------------------------------------------------------------
local PREVIEW_W, STAGE_H = 268, 168

local function BuildLivePreview(host)
    local T = W.T
    local panel = CreateFrame("Frame", nil, host)
    panel:SetSize(PREVIEW_W, STAGE_H + 82)
    W.Panel(panel, T.radius, { 0.039, 0.043, 0.047, 1 }, T.line)
    local title = W.SectionTitle(panel, "Vista previa")
    title:SetPoint("TOPLEFT", 10, -9)
    local live = W.Text(panel, 11, T.min)
    live:SetPoint("TOPRIGHT", -10, -10)
    live:SetText("en vivo")
    local line = W.Line(panel, T.line)
    line:SetPoint("TOPLEFT", 1, -28)
    line:SetPoint("TOPRIGHT", -1, -28)

    local stage = CreateFrame("Frame", nil, panel)
    stage:SetPoint("TOPLEFT", 1, -29)
    stage:SetPoint("TOPRIGHT", -1, -29)
    stage:SetHeight(STAGE_H)
    panel.stage = stage

    local note = W.Text(panel, 11, T.dim, true)
    note:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 9, -8)
    note:SetPoint("RIGHT", -10, 0)
    note:SetSpacing(2)
    note:SetText("Con tus datos. Para ver los marcos en su sitio, usa «Vista previa» en la cabecera.")

    local frame = CreateFrame("Frame", nil, stage)
    frame.previewUnit = "player"
    frame.cfg = UF.db.units[UF.editing]
    frame.info = UF.INFO[UF.editing]
    -- Se construye con todas las piezas (también los puntos de combo); lo que
    -- el marco editado no use queda oculto por su configuración.
    UF.Build(frame, { combo = true })
    panel.frame = frame

    function panel:Refresh()
        local unit = UF.editing
        frame.cfg, frame.info = UF.db.units[unit], UF.INFO[unit]
        UF.ApplyLayout(frame)
        UF.UpdateAll(frame)
        local cfg = frame.cfg
        -- Cabe entero (con puntos de combo y barra de lanzamiento) en el escenario.
        local w = frame:GetWidth()
        local h = cfg.height + 30 + (cfg.castbar and (cfg.castHeight + 6) or 0)
        local scale = math.min(1, (PREVIEW_W - 28) / w, (STAGE_H - 24) / h)
        frame:SetScale(scale)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", stage, "CENTER", 0, (cfg.castbar and (cfg.castHeight / 2) or 0) / scale)
    end
    return panel
end

ns.Config.RegisterPage("unitframes", "Marcos de unidad", 10, function(content, width)
    -- Ajustes a la izquierda; la vista previa ocupa la columna derecha.
    local L = W.Layout(content, width - PREVIEW_W - 22)
    local col = L.innerColumn

    local preview = BuildLivePreview(content:GetParent())
    preview:SetPoint("TOPRIGHT", content:GetParent(), "TOPRIGHT", -14, -14)
    UF.livePreview = preview
    -- Se repinta con cada cambio: tras cada ajuste (RefreshStates), al cambiar
    -- de pestaña (Refresh) y cuando se aplica el marco real (colores incluidos).
    local refreshStates = L.RefreshStates
    function L:RefreshStates()
        refreshStates(self)
        preview:Refresh()
    end
    table.insert(UF.hooks.layout, function(frame)
        if frame ~= preview.frame and frame.buiUnit == UF.editing and preview:IsVisible() then preview:Refresh() end
    end)

    local function cfg() return UF.db.units[UF.editing] end
    local function get(key) return function() return cfg()[key] end end

    local tabs = {}
    for i, unit in ipairs(UF.UNITS) do tabs[i] = { value = unit, text = UF.INFO[unit].label } end
    L:Full(W.Tabs(content, tabs,
        function() return UF.editing end,
        function(unit)
            -- Copiar y revertir se refieren al marco que se estaba editando.
            EndAllSessions()
            UF.editing = unit
            L:Refresh()
        end, L.width))

    L:Card("Marco")
    L:Row(W.Toggle(content, col, "Mostrar este marco (recarga)", get("enabled"), function(value)
        cfg().enabled = value
        ns.AskReload()
    end))
    L:EndCard()

    local s = NewSession(L:Card("Tamaño"), { "width", "height", "fontSize", "fontColor" }, nil, L)
    L:Row(W.Slider(content, col, "Ancho", 80, 400, 2, get("width"), s.Set("width")),
          W.Slider(content, col, "Alto", 14, 80, 1, get("height"), s.Set("height")))
    L:Row(W.Slider(content, col, "Tamaño de letra", 8, 20, 1, get("fontSize"), s.Set("fontSize")),
          W.Color(content, col, "Color de la letra", get("fontColor"), s.SetColor("fontColor")))
    L:EndCard()

    s = NewSession(L:Card("Forma y estilo"), { "shape", "flipH", "flipV", "reverseFill" }, { "gloss", "background", "border", "smooth" }, L)
    L:Row(W.Dropdown(content, col, "Forma de las barras", SHAPES, get("shape"), s.Set("shape")),
          W.Toggle(content, col, "Rellenar de derecha a izquierda", get("reverseFill"), s.Set("reverseFill")))
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), s.Set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), s.Set("flipV")))
    L:Row(W.Toggle(content, col, "Brillo en las barras (todos)",
              function() return UF.db.style.gloss end, s.SetStyle("gloss")),
          W.Color(content, col, "Fondo de las barras (todos)",
              function() return UF.db.style.background end, s.SetStyleColor("background")))
    L:Row(W.Slider(content, col, "Grosor del borde (todos, 0 = sin borde)", 0, 4, 1,
              function() return UF.db.style.border end, s.SetStyle("border")),
          W.Toggle(content, col, "Relleno suave (todos)",
              function() return UF.db.style.smooth end, s.SetStyle("smooth")))
    L:EndCard()

    s = NewSession(L:Card("Barra de vida"),
        { "healthColor", "customColor", "healthText", "healPrediction", "absorbs", "absorbColor" }, nil, L)
    L:Row(W.Dropdown(content, col, "Color de la vida", HEALTH_COLORS, get("healthColor"), s.Set("healthColor")),
          W.Dropdown(content, col, "Texto de vida", HEALTH_TEXT, get("healthText"), s.Set("healthText")))
    L:Row(W.Color(content, col, "Color personalizado", get("customColor"), s.SetColor("customColor")),
          nil, function() return cfg().healthColor == "custom" end)
    L:Row(W.Toggle(content, col, "Predicción de curación", get("healPrediction"), s.Set("healPrediction")),
          W.Toggle(content, col, "Absorciones (escudos)", get("absorbs"), s.Set("absorbs")))
    L:Row(W.Color(content, col, "Color del escudo", get("absorbColor"), s.SetColor("absorbColor")),
          nil, function() return cfg().absorbs end)
    L:Note("La curación entrante se ve como un tramo translúcido justo después de la vida actual. El escudo es una franja clara en la parte de arriba de la barra: su largo es el tamaño del escudo respecto a la vida máxima.")
    L:EndCard()

    local function hasPower() return cfg().power > 0 end
    s = NewSession(L:Card("Barra de recurso"), { "power", "powerColor", "powerCustomColor", "powerText" }, nil, L)
    L:Row(W.Slider(content, col, "Alto (0 = sin barra)", 0, 20, 1, get("power"), s.Set("power")),
          W.Dropdown(content, col, "Color", POWER_COLORS, get("powerColor"), s.Set("powerColor")),
          nil, hasPower)
    L:Row(W.Color(content, col, "Color personalizado", get("powerCustomColor"), s.SetColor("powerCustomColor")),
          W.Dropdown(content, col, "Texto del recurso", HEALTH_TEXT, get("powerText"), s.Set("powerText")),
          function() return hasPower() and cfg().powerColor == "custom" end,
          function() return cfg().power >= 6 end)
    L:Note("El texto del recurso necesita una barra de al menos 6 de alto.")
    L:EndCard()

    local function hasPortrait() return cfg().portrait ~= "none" and cfg().portrait ~= "3dbar" end
    local function is3D() return cfg().portrait == "3d" or cfg().portrait == "3dbar" end
    local function inBar() return cfg().portrait == "3dbar" end
    s = NewSession(L:Card("Retrato"), { "portrait", "portraitSize", "portraitZoom", "portraitOffset", "portraitFacing", "portraitInvert", "portraitShift", "portraitBarAlpha" }, nil, L)
    L:Row(W.Dropdown(content, col, "Retrato", PORTRAITS, get("portrait"), s.Set("portrait")),
          W.Slider(content, col, "Tamaño (% del alto)", 60, 200, 5, get("portraitSize"), s.Set("portraitSize")),
          nil, hasPortrait)
    L:Row(W.Slider(content, col, "Zoom del modelo 3D (%)", 50, 250, 5, get("portraitZoom"), s.Set("portraitZoom")),
          W.Slider(content, col, "Altura del encuadre 3D", -50, 50, 1, get("portraitOffset"), s.Set("portraitOffset")),
          is3D, is3D)
    L:Row(W.Toggle(content, col, "Invertir (efecto espejo)", get("portraitInvert"), function(v)
              s.Set("portraitInvert")(v)
              -- El 3D además se gira para mirar al otro lado (se puede afinar).
              local f = cfg().portraitFacing or 0
              if v and f == 0 then s.Set("portraitFacing")(-90) elseif not v and f == -90 then s.Set("portraitFacing")(0) end
              -- Dentro de la barra, la imagen pasa a la mitad derecha.
              if cfg().portrait == "3dbar" then
                  local sh = cfg().portraitShift or 0
                  if v and sh == 0 then s.Set("portraitShift")(50) elseif not v and sh == 50 then s.Set("portraitShift")(0) end
              end
          end),
          W.Slider(content, col, "Posición horizontal del 3D", -100, 100, 5, get("portraitShift"), s.Set("portraitShift")),
          function() return cfg().portrait ~= "none" end, function() return cfg().portrait == "3d" or cfg().portrait == "3dbar" end)
    L:Row(W.Slider(content, col, "Giro del modelo 3D (grados)", -90, 90, 5, get("portraitFacing"), s.Set("portraitFacing")),
          W.Slider(content, col, "Opacidad dentro de la barra (%)", 15, 100, 5, get("portraitBarAlpha"), s.Set("portraitBarAlpha")),
          is3D, inBar)
    L:Note("El retrato 3D va sin recuadro ni fondo: solo el modelo, encuadrado en hombros y cabeza. \"Dentro de la barra\" lo pone sobre la vida, semitransparente, detrás de los textos.")
    L:EndCard()

    s = NewSession(L:Card("Textos"), { "showName", "showLevel" }, nil, L)
    L:Row(W.Toggle(content, col, "Mostrar nombre", get("showName"), s.Set("showName")),
          W.Toggle(content, col, "Mostrar nivel", get("showLevel"), s.Set("showLevel")))
    L:EndCard()

    local castShapes = { { value = "inherit", text = "Igual que el marco" } }
    for _, choice in ipairs(SHAPES) do castShapes[#castShapes + 1] = choice end
    local function hasCast() return cfg().castbar end
    s = NewSession(L:Card("Barra de lanzamiento"),
        { "castbar", "castColor", "castShape", "castHeight", "castWidth", "castIcon", "castFlipH", "castFlipV" }, nil, L)
    local setCastbar = s.Set("castbar")
    L:Row(W.Toggle(content, col, "Mostrar barra de lanzamiento", get("castbar"), function(value)
              setCastbar(value)
              -- En Jugador o Mascota sustituye a la barra de Blizzard: pide recargar.
              if UF.INFO[UF.editing].castbarBlizzard then ns.AskReload() end
          end),
          W.Color(content, col, "Color del lanzamiento", get("castColor"), s.SetColor("castColor")),
          nil, hasCast)
    L:Row(W.Dropdown(content, col, "Forma", castShapes, get("castShape"), s.Set("castShape")),
          W.Slider(content, col, "Alto", 10, 40, 1, get("castHeight"), s.Set("castHeight")),
          hasCast, hasCast)
    L:Row(W.Toggle(content, col, "Invertir horizontal", get("castFlipH"), s.Set("castFlipH")),
          W.Toggle(content, col, "Invertir vertical", get("castFlipV"), s.Set("castFlipV")),
          hasCast, hasCast)
    L:Row(W.Slider(content, col, "Ancho (0 = igual que el marco)", 0, 400, 2, get("castWidth"), s.Set("castWidth")),
          W.Toggle(content, col, "Mostrar icono del hechizo", get("castIcon"), s.Set("castIcon")),
          hasCast, hasCast)
    L:Note("Por defecto sigue la orientación del marco; invertir la cambia solo en esta barra. En Jugador y Mascota sustituye a la barra de Blizzard (recarga).")
    L:EndCard()

    -- Puntos de combo (solo Jugador y Objetivo).
    local function canCombo() return UF.INFO[UF.editing].combo and true or false end
    local function comboOn() return canCombo() and cfg().combo end
    local function comboStyle() return UF.ComboStyle(cfg()) end
    local comboStyles = {}
    for i, key in ipairs(UF.COMBO_STYLE_ORDER) do
        comboStyles[i] = { value = key, text = UF.COMBO_STYLES[key].text }
    end
    s = NewSession(L:Card("Puntos de combo"), {
        "combo", "comboStyleRogue", "comboStyleDruid", "comboPosition", "comboAlign", "comboSize",
        "comboBarHeight", "comboSpacing", "comboOffset", "comboColor", "comboCustomColor", "comboFull",
        "comboFullColor", "comboEmpty", "comboAlways", "comboPop",
    }, nil, L)
    L:Row(W.Toggle(content, col, "Puntos de combo", get("combo"), s.Set("combo")),
          W.Dropdown(content, col, "Posición", COMBO_POSITIONS, get("comboPosition"), s.Set("comboPosition")),
          canCombo, comboOn)
    L:Row(W.Dropdown(content, col, "Diseño para pícaro", comboStyles, get("comboStyleRogue"), s.Set("comboStyleRogue")),
          W.Dropdown(content, col, "Diseño para druida", comboStyles, get("comboStyleDruid"), s.Set("comboStyleDruid")),
          comboOn, comboOn)
    L:Row(W.Dropdown(content, col, "Alineación", COMBO_ALIGN, get("comboAlign"), s.Set("comboAlign")),
          W.Slider(content, col, "Separación", 0, 16, 1, get("comboSpacing"), s.Set("comboSpacing")),
          comboOn, function() return comboOn() and comboStyle() ~= "number" end)
    L:Row(W.Slider(content, col, "Tamaño (iconos y número)", 8, 36, 1, get("comboSize"), s.Set("comboSize")),
          W.Slider(content, col, "Grosor de los segmentos", 2, 16, 1, get("comboBarHeight"), s.Set("comboBarHeight")),
          function() return comboOn() and (comboStyle() ~= "bars" or cfg().comboAlign ~= "spread") end,
          function() return comboOn() and comboStyle() == "bars" end)
    L:Row(W.Slider(content, col, "Distancia a las barras", 0, 24, 1, get("comboOffset"), s.Set("comboOffset")),
          W.Dropdown(content, col, "Color", COMBO_COLORS, get("comboColor"), s.Set("comboColor")),
          function() return comboOn() and cfg().comboPosition ~= "edge" end, comboOn)
    L:Row(W.Color(content, col, "Color personalizado", get("comboCustomColor"), s.SetColor("comboCustomColor")),
          W.Toggle(content, col, "Color de remate con 5 puntos", get("comboFull"), s.Set("comboFull")),
          function() return comboOn() and cfg().comboColor == "custom" end, comboOn)
    L:Row(W.Color(content, col, "Color de remate", get("comboFullColor"), s.SetColor("comboFullColor")),
          W.Toggle(content, col, "Mostrar los huecos vacíos", get("comboEmpty"), s.Set("comboEmpty")),
          function() return comboOn() and cfg().comboFull end,
          function() return comboOn() and comboStyle() ~= "number" end)
    L:Row(W.Toggle(content, col, "Huecos vacíos al elegir enemigo", get("comboAlways"), s.Set("comboAlways")),
          W.Toggle(content, col, "Animación al ganar un punto", get("comboPop"), s.Set("comboPop")),
          comboOn, function() return comboOn() and comboStyle() ~= "number" end)
    L:Note("El diseño se elige por la clase del personaje: los druidas usan el suyo y el resto (pícaros) el otro. "
        .. "\"Huecos vacíos al elegir enemigo\": los 5 huecos apagados se ven en cuanto seleccionas un enemigo, aunque aún no tengas puntos; si no, aparecen con el primer punto. "
        .. "Con la configuración abierta los puntos suben solos de 1 a 5 para ver cómo quedan. "
        .. "\"Rellenar de derecha a izquierda\" (en Forma y estilo) también invierte el orden de los puntos.")
    L:EndCard()

    s = NewSession(L:Card("Extras"), { "fade" }, nil, L)
    L:Row(W.Toggle(content, col, "Atenuar fuera de combate", get("fade"), s.Set("fade")))
    L:EndCard()

    return L
end)
