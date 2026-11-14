-- Página "Grupo y banda" de la ventana de configuración de BlazzitoUI.
-- Pestañas Grupo / Banda; las tarjetas copian de uno a otro y revierten como
-- en los marcos de unidad. Arriba, los botones de vista previa.
local ns = BlazzitoUI
if not (ns and ns.Group and ns.UnitFrames and ns.UnitFrames.NewCardSession) then return end

local G, UF, M, W = ns.Group, ns.UnitFrames, ns.Media, ns.Widgets

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local SHAPES = {}
for i, key in ipairs(M.SHAPE_ORDER) do SHAPES[i] = { value = key, text = M.SHAPES[key].text } end
local HEALTH_COLORS = Choices({ { "class", "Clase" }, { "gradient", "Según la vida (verde a rojo)" }, { "custom", "Color personalizado" } })
local HEALTH_TEXT = Choices({ { "percent", "Porcentaje" }, { "value", "Valor" }, { "both", "Valor y porcentaje" }, { "none", "Ninguno" } })
local DISPEL_POS = Choices({ { "outside", "Al lado del marco" }, { "inside", "Dentro de la barra" } })
local MYBUFF_POS = Choices({ { "inside", "Dentro, arriba a la derecha" }, { "above", "Encima del marco" }, { "left", "A la izquierda del marco" } })
local SORTS = Choices({ { "group", "Por grupo" }, { "role", "Por rol (tanques, sanadores, daño)" }, { "class", "Por clase" }, { "name", "Por nombre" } })
local FILLS = Choices({ { "columns", "Por columnas (de arriba abajo)" }, { "rows", "Por filas (de izquierda a derecha)" } })

local CONTEXT = {
    units = function() return G.db.layouts end,
    style = function() return UF.db.style end,
    editing = function() return G.editing end,
    apply = function(kind) G.ApplyKind(kind) end,
    applyAll = function() G.ApplyAll() end,
    pair = { party = "raid", raid = "party" },
    label = function(kind) return G.KINDS[kind].label end,
}

ns.Config.RegisterPage("group", "Grupo y banda", 12, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local function cfg() return G.db.layouts[G.editing] end
    local function get(key) return function() return cfg()[key] end end
    local function Session(title, keys)
        return UF.NewCardSession(L:Card(title), keys, nil, L, CONTEXT)
    end

    L:Card("Vista previa")
    L:Row(W.Button(content, 200, "Vista previa de grupo", function() G.TogglePreview("party") end, true),
          W.Button(content, 200, "Vista previa de banda", function() G.TogglePreview("raid") end))
    L:Row(W.Toggle(content, col, "Ocultar los marcos de Blizzard (recarga)", function() return G.db.hideBlizzard end,
              function(v) G.db.hideBlizzard = v; ns.AskReload() end))
    L:Note("La vista previa muestra miembros de ejemplo con roles, perjuicios disipables, aggro y alguno fuera de rango. Púlsala otra vez para quitarla.")
    L:EndCard()

    L:Full(W.Tabs(content, { { value = "party", text = "Grupo" }, { value = "raid", text = "Banda" } },
        function() return G.editing end,
        function(kind)
            G.editing = kind
            L:Refresh()
        end))

    local s = Session("Tamaño y disposición", { "width", "height", "fontSize", "fontColor", "spacing", "showPlayer" })
    L:Row(W.Slider(content, col, "Ancho", 50, 300, 2, get("width"), s.Set("width")),
          W.Slider(content, col, "Alto", 14, 80, 1, get("height"), s.Set("height")))
    L:Row(W.Slider(content, col, "Tamaño de letra", 7, 18, 1, get("fontSize"), s.Set("fontSize")),
          W.Color(content, col, "Color de la letra", get("fontColor"), s.SetColor("fontColor")))
    L:Row(W.Slider(content, col, "Separación", 0, 20, 1, get("spacing"), s.Set("spacing")),
          W.Toggle(content, col, "Incluirte a ti en el grupo", get("showPlayer"), function(v)
              s.Set("showPlayer")(v)
              ns.AskReload()
          end),
          nil, function() return G.editing == "party" end)
    L:EndCard()

    local function isRaid() return G.editing == "raid" end
    local function freeGrid() return isRaid() and not (cfg().sortBy == "group" and cfg().groupColumns) end
    s = Session("Organización de la banda", { "sortBy", "groupColumns", "columns", "fillBy", "maxGroups" })
    L:Row(W.Dropdown(content, col, "Orden", SORTS, get("sortBy"), s.Set("sortBy")),
          W.Toggle(content, col, "Cada grupo en su propia columna", get("groupColumns"), s.Set("groupColumns")),
          isRaid, function() return isRaid() and cfg().sortBy == "group" end)
    L:Row(W.Slider(content, col, "Columnas", 1, 10, 1, get("columns"), s.Set("columns")),
          W.Dropdown(content, col, "Cómo se llena", FILLS, get("fillBy"), s.Set("fillBy")),
          freeGrid, freeGrid)
    L:Row(W.Slider(content, col, "Mostrar los grupos del 1 al", 1, 8, 1, get("maxGroups"), s.Set("maxGroups")),
          nil, isRaid)
    L:Note("Solo para la pestaña Banda. Se reorganiza al salir de combate. Con \"Mostrar los grupos del 1 al 5\" solo ves a los 25 primeros (útil en bandas de 25 con suplentes).")
    L:EndCard()

    s = Session("Forma y estilo", { "shape", "flipH", "flipV", "reverseFill" })
    L:Row(W.Dropdown(content, col, "Forma", SHAPES, get("shape"), s.Set("shape")),
          W.Toggle(content, col, "Rellenar de derecha a izquierda", get("reverseFill"), s.Set("reverseFill")))
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), s.Set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), s.Set("flipV")))
    L:EndCard()

    s = Session("Vida y recurso", { "healthColor", "customColor", "healthText", "healPrediction", "absorbs", "power" })
    L:Row(W.Dropdown(content, col, "Color de la vida", HEALTH_COLORS, get("healthColor"), s.Set("healthColor")),
          W.Dropdown(content, col, "Texto de vida", HEALTH_TEXT, get("healthText"), s.Set("healthText")))
    L:Row(W.Color(content, col, "Color personalizado", get("customColor"), s.SetColor("customColor")),
          W.Slider(content, col, "Alto del recurso (0 = sin barra)", 0, 12, 1, get("power"), s.Set("power")),
          function() return cfg().healthColor == "custom" end)
    L:Row(W.Toggle(content, col, "Predicción de curación", get("healPrediction"), s.Set("healPrediction")),
          W.Toggle(content, col, "Absorciones (escudos)", get("absorbs"), s.Set("absorbs")))
    L:EndCard()

    local function is3D() return cfg().portrait == "3d" or cfg().portrait == "3dbar" end
    s = Session("Retrato", { "portrait", "portraitZoom", "portraitOffset", "portraitFacing", "portraitInvert", "portraitShift", "portraitBarAlpha" })
    L:Row(W.Dropdown(content, col, "Retrato", UF.PORTRAIT_CHOICES, get("portrait"), s.Set("portrait")),
          W.Slider(content, col, "Opacidad dentro de la barra (%)", 15, 100, 5, get("portraitBarAlpha"), s.Set("portraitBarAlpha")),
          nil, function() return cfg().portrait == "3dbar" end)
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
          nil, is3D)
    L:EndCard()

    local function hasCast() return cfg().castbar end
    s = Session("Barra de lanzamiento", { "castbar", "castHeight", "castColor", "castIcon" })
    L:Row(W.Toggle(content, col, "Mostrar barra de lanzamiento", get("castbar"), s.Set("castbar")),
          W.Color(content, col, "Color", get("castColor"), s.SetColor("castColor")),
          nil, hasCast)
    L:Row(W.Slider(content, col, "Alto", 4, 20, 1, get("castHeight"), s.Set("castHeight")),
          W.Toggle(content, col, "Icono del hechizo", get("castIcon"), s.Set("castIcon")),
          hasCast, hasCast)
    L:EndCard()

    local function hasDispels() return cfg().dispels end
    s = Session("Perjuicios disipables", { "dispels", "dispelMax", "dispelSize", "dispelPos", "dispelGlow" })
    L:Row(W.Toggle(content, col, "Mostrar los que puedes disipar", get("dispels"), s.Set("dispels")),
          W.Toggle(content, col, "El marco brilla del color del tipo", get("dispelGlow"), s.Set("dispelGlow")))
    L:Row(W.Slider(content, col, "Cuántos como máximo", 1, 5, 1, get("dispelMax"), s.Set("dispelMax")),
          W.Slider(content, col, "Tamaño", 10, 32, 1, get("dispelSize"), s.Set("dispelSize")),
          hasDispels, hasDispels)
    L:Row(W.Dropdown(content, col, "Dónde", DISPEL_POS, get("dispelPos"), s.Set("dispelPos")), nil, hasDispels)
    L:Note("Solo salen los perjuicios que tu clase puede quitar, con el borde del color de su tipo (magia, maldición, enfermedad, veneno).")
    L:EndCard()

    local function hasBuffs() return cfg().myBuffs end
    s = Session("Tus beneficios", { "myBuffs", "myBuffMissing", "myBuffMax", "myBuffSize", "myBuffPos" })
    L:Row(W.Toggle(content, col, "Mostrar los beneficios que tú le pones", get("myBuffs"), s.Set("myBuffs")),
          W.Toggle(content, col, "Marcar en gris los que le faltan", get("myBuffMissing"), s.Set("myBuffMissing")),
          nil, hasBuffs)
    L:Row(W.Slider(content, col, "Cuántos como máximo", 1, 6, 1, get("myBuffMax"), s.Set("myBuffMax")),
          W.Slider(content, col, "Tamaño", 8, 28, 1, get("myBuffSize"), s.Set("myBuffSize")),
          hasBuffs, hasBuffs)
    L:Row(W.Dropdown(content, col, "Dónde", MYBUFF_POS, get("myBuffPos"), s.Set("myBuffPos")), nil, hasBuffs)
    L:Note("Iconos de tus beneficios sobre cada miembro, en el mismo orden en todos. \"Le falta\" se calcula con tus beneficios largos (sin duración o de 2 minutos o más) que lleva algún otro miembro: si alguien sale en gris con borde rojo, no lleva el tuyo (o está demasiado lejos para el aura).")
    L:EndCard()

    s = Session("Indicadores", { "roleIcon", "leaderIcon", "aggroBorder", "targetBorder", "rangeFade", "rangeAlpha" })
    L:Row(W.Toggle(content, col, "Icono de rol (tanque, sanador, daño)", get("roleIcon"), s.Set("roleIcon")),
          W.Toggle(content, col, "Corona del líder", get("leaderIcon"), s.Set("leaderIcon")))
    L:Row(W.Toggle(content, col, "Borde rojo si tiene aggro", get("aggroBorder"), s.Set("aggroBorder")),
          W.Toggle(content, col, "Borde de acento en tu objetivo", get("targetBorder"), s.Set("targetBorder")))
    L:Row(W.Toggle(content, col, "Atenuar si está fuera de rango", get("rangeFade"), s.Set("rangeFade")),
          W.Slider(content, col, "Opacidad fuera de rango (%)", 10, 90, 5, get("rangeAlpha"), s.Set("rangeAlpha")),
          nil, function() return cfg().rangeFade end)
    L:EndCard()
    return L
end)
