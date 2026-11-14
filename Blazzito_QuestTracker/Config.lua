-- Página "Misiones" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.QuestTracker) then return end

local QT, W = ns.QuestTracker, ns.Widgets

ns.Config.RegisterPage("questtracker", "Misiones", 19, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = QT.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            QT.ApplyAll()
            L:RefreshStates()
        end
    end

    L:Card("Misión destacada")
    L:Row(W.Toggle(content, col, "Casilla para destacar cada misión", get("checkboxes"), set("checkboxes")),
          W.Toggle(content, col, "Destacar en el mapa también la marca aquí", get("followMap"), set("followMap")))
    L:Row(W.Toggle(content, col, "Distancia junto al nombre, p. ej. (125m)", get("distance"), set("distance")))
    L:Note("La casilla delante de cada misión de Questie la destaca: se resalta en el mapa y el juego te guía hacia ella. Marcada en azul = destacada; borde verde = misión completada. Con la segunda opción, destacar una misión desde el mapa de Blizzard también la marca en el rastreador. Son opciones de Questie: BlazzitoUI solo las activa.")
    L:EndCard()

    L:Card("Tamaño y posición")
    L:Row(W.Slider(content, col, "Ancho (0 = automático)", 0, 700, 10, function() return (QT.GetSize()) end,
              function(v) QT.SetSize(v ~= 0 and math.max(150, v) or 0, nil) end),
          W.Slider(content, col, "Alto (0 = automático)", 0, 1000, 10, function() return select(2, QT.GetSize()) end,
              function(v) QT.SetSize(nil, v ~= 0 and math.max(80, v) or 0) end))
    L:Row(W.Toggle(content, col, "Franja de color en la destacada (azul) y en las completadas (verde)", get("rowHighlight"), set("rowHighlight")),
          W.Button(content, 160, "Mover el rastreador", function() ns.Movers.Toggle() end, true))
    L:Note("El tamaño y la posición se guardan en Questie (como si lo hicieras con su tirador), así que Questie los respeta. En el modo mover se arrastra y se cambia de tamaño desde la esquina.")
    L:EndCard()

    L:Card("Otras secciones")
    L:Row(W.Toggle(content, col, "Mismo estilo que Questie en las secciones de otros addons", get("matchSections"), function(v)
        db.matchSections = v
        if v then QT.ApplyAll() else ns.AskReload() end
    end))
    L:Note("Secciones como \"Componentes de profesión\" de SkillUp Forever, que se colocan bajo la lista de Questie, toman su letra, tamaños y sangrías, y pierden la cabecera dorada con línea. Para quitarlo hay que recargar. /bui misiones muestra qué secciones encuentra.")
    L:EndCard()
    return L
end)
