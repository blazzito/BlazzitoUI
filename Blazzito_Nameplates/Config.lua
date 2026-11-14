-- Página "Placas de nombre" de la ventana de configuración de BlazzitoUI.
-- Arriba, una placa de ejemplo que muestra cada cambio al momento.
local ns = BlazzitoUI
if not (ns and ns.Nameplates) then return end

local NP, M, W = ns.Nameplates, ns.Media, ns.Widgets

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local COLOR_MODES = Choices({ { "reaction", "Reacción (hostil, neutral...) y clase" }, { "threat", "Aggro en combate (y reacción fuera)" } })
local HEALTH_TEXT = Choices({ { "percent", "Porcentaje" }, { "none", "Ninguno" } })

ns.Config.RegisterPage("nameplates", "Placas de nombre", 18, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = NP.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            NP.ApplyAll()
            L:RefreshStates()
        end
    end
    local function setColor(key)
        return function(r, g, b)
            db[key] = { r, g, b }
            NP.ApplyAll()
        end
    end

    local shapes = {}
    for i, key in ipairs(M.SHAPE_ORDER) do shapes[i] = { value = key, text = M.SHAPES[key].text } end

    -- Vista previa: una placa de ejemplo (objetivo, lanzando y a rango).
    local previewCard = L:Card("Vista previa")
    local host = CreateFrame("Frame", nil, previewCard)
    host:SetSize(L.width, 60)
    host.keepWidth = true
    L:Full(host)
    NP.preview = NP.Build(host)
    NP.preview:ClearAllPoints()
    NP.preview:SetPoint("CENTER", host, "CENTER", 0, 4)
    NP.PaintPreview(NP.preview)
    L:EndCard()

    L:Card("Tamaño")
    L:Row(W.Slider(content, col, "Ancho", 60, 250, 2, get("width"), set("width")),
          W.Slider(content, col, "Alto", 4, 30, 1, get("height"), set("height")))
    L:Row(W.Slider(content, col, "Tamaño de letra", 7, 16, 1, get("fontSize"), set("fontSize")),
          W.Color(content, col, "Color de la letra", get("fontColor"), setColor("fontColor")))
    L:EndCard()

    L:Card("Forma y estilo")
    L:Row(W.Dropdown(content, col, "Forma", shapes, get("shape"), set("shape")),
          W.Slider(content, col, "Grosor del borde (0 = sin borde)", 0, 4, 1, get("border"), set("border")))
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), set("flipV")))
    L:Row(W.Toggle(content, col, "Brillo en las barras", get("gloss"), set("gloss")))
    L:EndCard()

    L:Card("Vida y textos")
    L:Row(W.Dropdown(content, col, "Color de la vida", COLOR_MODES, get("colorMode"), set("colorMode")),
          W.Dropdown(content, col, "Texto de vida", HEALTH_TEXT, get("healthText"), set("healthText")))
    L:Row(W.Toggle(content, col, "Mostrar nombre", get("showName"), set("showName")))
    L:Note("Con \"Aggro en combate\", la barra toma el color de tu situación de aggro con ese enemigo (rojo si te ataca a ti).")
    L:EndCard()

    local function hasCast() return db.castbar end
    L:Card("Barra de lanzamiento")
    L:Row(W.Toggle(content, col, "Mostrar barra de lanzamiento", get("castbar"), set("castbar")),
          W.Color(content, col, "Color del lanzamiento", get("castColor"), setColor("castColor")),
          nil, hasCast)
    L:Row(W.Slider(content, col, "Alto", 6, 24, 1, get("castHeight"), set("castHeight")), nil, hasCast)
    L:EndCard()

    L:Card("Objetivo")
    L:Row(W.Toggle(content, col, "Resaltar tu objetivo", get("targetHighlight"), set("targetHighlight")),
          W.Slider(content, col, "Opacidad del resto (%)", 30, 100, 5, get("otherAlpha"), set("otherAlpha")))
    L:EndCard()

    local function hasRange() return db.range end
    L:Card("Rango")
    L:Row(W.Toggle(content, col, "Indicador de enemigo a rango", get("range"), set("range")),
          W.Toggle(content, col, "Que lata (brillo animado)", get("rangePulse"), set("rangePulse")),
          nil, hasRange)
    L:Row(W.Color(content, col, "Color del indicador", get("rangeColor"), setColor("rangeColor")),
          W.Slider(content, col, "Tamaño", 10, 28, 1, get("rangeSize"), set("rangeSize")),
          hasRange, hasRange)
    L:Note("Se comprueba con hechizos de tu clase. En el cazador, Disparo automático y Golpe de raptor: la zona muerta de 5 a 8 metros cuenta como fuera de rango. Va junto a la insignia de aggro cuando está visible.")
    L:EndCard()
    return L
end)
