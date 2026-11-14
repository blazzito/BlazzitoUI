-- Página "Barras de acción" de la ventana de configuración de BlazzitoUI.
-- Se elige la barra arriba y las tarjetas editan esa barra; "copiar" lleva
-- la tarjeta a todas las barras del mismo tipo y "revertir" deshace 10 s.
local ns = BlazzitoUI
if not (ns and ns.ActionBars and ns.UnitFrames and ns.UnitFrames.NewCardSession) then return end

local AB, UF, M, W = ns.ActionBars, ns.UnitFrames, ns.Media, ns.Widgets

local CONTEXT = {
    units = function() return AB.db.bars end,
    style = function() return AB.db.style end,
    editing = function() return AB.editing end,
    apply = function(key) AB.ApplyBar(key) end,
    applyAll = function() AB.ApplyAll() end,
    copyAll = function(target, source) return AB.BAR_BY_KEY[target].kind == AB.BAR_BY_KEY[source].kind end,
    copyAllLabel = "todas las barras del mismo tipo",
}

local function Kind() return AB.BAR_BY_KEY[AB.editing].kind end

-- Las formas cambian según la barra: cuadradas para botones y menú,
-- alargadas para la de experiencia. La lista se rellena en su sitio.
local shapeChoices = {}
local function FillShapes()
    for i = #shapeChoices, 1, -1 do shapeChoices[i] = nil end
    if Kind() == "status" or Kind() == "swing" then
        for _, key in ipairs(M.SHAPE_ORDER) do shapeChoices[#shapeChoices + 1] = { value = key, text = M.SHAPES[key].text } end
    else
        for _, key in ipairs(AB.BUTTON_SHAPE_ORDER) do
            shapeChoices[#shapeChoices + 1] = { value = key, text = AB.BUTTON_SHAPES[key].text }
        end
    end
end

ns.Config.RegisterPage("actionbars", "Barras de acción", 14, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local function cfg() return AB.db.bars[AB.editing] end
    local function get(key) return function() return cfg()[key] end end
    local function Session(title, keys)
        return UF.NewCardSession(L:Card(title), keys, nil, L, CONTEXT)
    end
    FillShapes()

    L:Card("General")
    L:Row(W.Toggle(content, col, "Ocultar el arte de la barra 1 (grifos y marco)", function() return AB.db.style.hideArt end,
              function(v) AB.db.style.hideArt = v; AB.ApplyAll() end),
          W.Toggle(content, col, "Mostrar todas mientras configuras", function() return AB.preview end, function(v)
              AB.SetPreview(v)
          end))
    L:Row(W.Toggle(content, col, "Mostrarlas al arrastrar un hechizo u objeto", function() return AB.db.style.showWhileDragging end,
              function(v) AB.db.style.showWhileDragging = v end),
          W.Slider(content, col, "Duración del fundido (s)", 0, 1, 0.05, function() return AB.db.style.fadeTime end,
              function(v) AB.db.style.fadeTime = v end))
    L:Note("Las barras siguen siendo las de WoW: su posición y tamaño se cambian en el Modo edición de Blizzard (Esc > Modo edición). Aquí cambian su aspecto y cuándo se ven. La barra de la pestaña elegida brilla en pantalla.")
    L:EndCard()

    -- Una pestaña por barra; las desactivadas salen atenuadas.
    local tabs = {}
    for i, bar in ipairs(AB.BARS) do
        local key = bar.key
        tabs[i] = { value = key, text = bar.tab or bar.label, dim = function() return not AB.IsBarEnabled(key) end }
    end
    L:Full(W.Tabs(content, tabs, function() return AB.editing end, function(key)
        AB.editing = key
        FillShapes()
        L:Refresh()
    end, L.width))

    local function bar() return AB.BAR_BY_KEY[AB.editing] end
    local function enabled() return AB.IsBarEnabled(AB.editing) end
    local barCard = L:Card("Barra")
    L:Row(W.Toggle(content, col, "Barra activada", enabled, function(v)
              AB.SetBarEnabled(AB.editing, v)
              L:Refresh()
          end),
          W.Toggle(content, col, "Quitar el fondo de Blizzard", get("hideArt"), function(v)
              cfg().hideArt = v
              AB.ApplyBar(AB.editing)
          end),
          nil, function() return bar().art and enabled() end)
    L:Note("Barras 2 a 8: es la misma casilla que Opciones > Barras de acción de Blizzard (fuera de combate). La barra 1, mascota, posturas, bolsas, menú y experiencia no se pueden quitar en WoW: al desactivarlas se vuelven invisibles.")
    L:EndCard()
    -- El título de la tarjeta dice qué barra se edita.
    local refreshTitle = { Refresh = function() barCard.title:SetText(W.Upper(ns.Translate(bar().label))) end }
    L.widgets[#L.widgets + 1] = refreshTitle
    refreshTitle.Refresh()

    local function isSkinned() return cfg().skin end
    local s = Session("Forma y estilo", { "skin", "shape", "flipH", "flipV", "border", "borderColor", "background" })
    L:Row(W.Toggle(content, col, "Aplicar el estilo de BlazzitoUI", get("skin"), s.Set("skin")),
          W.Dropdown(content, col, "Forma", shapeChoices, get("shape"), s.Set("shape")),
          nil, isSkinned)
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), s.Set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), s.Set("flipV")),
          isSkinned, isSkinned)
    L:Row(W.Slider(content, col, "Grosor del borde (0 = sin borde)", 0, 4, 1, get("border"), s.Set("border")),
          W.Color(content, col, "Color del borde", get("borderColor"), s.SetColor("borderColor")),
          isSkinned, function() return isSkinned() and (cfg().border or 0) > 0 end)
    L:Row(W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("background"), s.Set("background")), nil, isSkinned)
    L:Note("Voltear solo cambia las formas que no son simétricas (inclinada y ala). Desactivar el estilo devuelve la barra a como la pinta Blizzard.")
    L:EndCard()

    local function hides() return cfg().visibility ~= "always" end
    s = Session("Visibilidad", { "visibility", "hiddenAlpha" })
    L:Row(W.Dropdown(content, col, "Cuándo se ve", AB.VISIBILITY, get("visibility"), s.Set("visibility")),
          W.Slider(content, col, "Opacidad cuando está oculta (%)", 0, 100, 5, get("hiddenAlpha"), s.Set("hiddenAlpha")),
          nil, hides)
    L:Note("Oculta = transparente: la barra sigue en su sitio y sus atajos de teclado funcionan. En el Modo edición se ven todas.")
    L:EndCard()

    local function isButtons() return Kind() == "buttons" and isSkinned() end
    s = Session("Botones", { "hotkey", "macroName", "count", "hoverGlow" })
    L:Row(W.Toggle(content, col, "Mostrar la tecla asignada", get("hotkey"), s.Set("hotkey")),
          W.Toggle(content, col, "Mostrar el nombre de la macro", get("macroName"), s.Set("macroName")),
          isButtons, isButtons)
    L:Row(W.Toggle(content, col, "Mostrar cargas y cantidades", get("count"), s.Set("count")),
          W.Toggle(content, col, "Brillo al pasar el ratón", get("hoverGlow"), s.Set("hoverGlow")),
          isButtons, isButtons)
    L:EndCard()

    local function isSwing() return Kind() == "swing" end
    s = Session("Temporizador de golpe", { "width", "height", "color", "timeText", "label", "hideIdle", "rangeTint" })
    L:Row(W.Slider(content, col, "Ancho", 60, 500, 2, get("width"), s.Set("width")),
          W.Slider(content, col, "Alto", 4, 40, 1, get("height"), s.Set("height")),
          isSwing, isSwing)
    L:Row(W.Color(content, col, "Color de la barra", get("color"), s.SetColor("color")),
          W.Toggle(content, col, "Tiempo restante", get("timeText"), s.Set("timeText")),
          isSwing, isSwing)
    L:Row(W.Toggle(content, col, "Nombre de la mano (Derecha / Izquierda / Distancia)", get("label"), s.Set("label")),
          W.Toggle(content, col, "Ocultar fuera de combate", get("hideIdle"), s.Set("hideIdle")),
          isSwing, isSwing)
    L:Row(W.Toggle(content, col, "Apagarse fuera de rango", get("rangeTint"), s.Set("rangeTint")),
          W.Toggle(content, col, "Ocultar el temporizador de Blizzard", function() return AB.db.style.hideBlizzardSwing end,
              function(v) AB.db.style.hideBlizzardSwing = v; if AB.Swing then AB.Swing.ApplyBlizzard() end end),
          isSwing, isSwing)
    L:Note("Los datos son los del temporizador de golpe del juego (WoW Forever): cada golpe de tu mano derecha, izquierda o ataque a distancia (disparo automático, varita) reinicia su barra. La mano izquierda solo aparece con dos armas y la de distancia con arco, fusil, arma arrojadiza o varita. Se colocan con el modo mover (arriba a la derecha) y /bui swing muestra su estado.")
    L:EndCard()
    return L
end)

-- Al cerrar la ventana se quita la vista previa.
if ns.Config.OnOpenChanged then
    ns.Config.OnOpenChanged(function(open)
        if not open then AB.SetPreview(false) end
    end)
end
