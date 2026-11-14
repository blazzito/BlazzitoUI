-- Página "Minimapa" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.Minimap) then return end

local MM, M, W = ns.Minimap, ns.Media, ns.Widgets

ns.Config.RegisterPage("minimap", "Minimapa", 17, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = MM.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            MM.Apply()
            L:RefreshStates()
        end
    end
    local shapes = {}
    for i, key in ipairs(M.BUTTON_SHAPE_ORDER) do shapes[i] = { value = key, text = M.BUTTON_SHAPES[key].text } end

    L:Card("Tamaño y forma")
    L:Row(W.Slider(content, col, "Tamaño", 120, 450, 5, get("size"), set("size")),
          W.Dropdown(content, col, "Forma", shapes, get("shape"), set("shape")))
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), set("flipV")))
    L:Row(W.Slider(content, col, "Grosor del borde (0 = sin borde)", 0, 6, 1, get("border"), set("border")),
          W.Color(content, col, "Color del borde", get("borderColor"), function(r, g, b) db.borderColor = { r, g, b }; MM.Apply() end),
          nil, function() return (db.border or 0) > 0 end)
    L:Row(W.Toggle(content, col, "Zoom con la rueda del ratón", get("wheelZoom"), set("wheelZoom")),
          W.Button(content, 160, "Mover el minimapa", function() ns.Movers.Toggle() end, true))
    L:Note("Se mueve y se cambia de tamaño también con el modo mover (arriba a la derecha de esta ventana): arrastra la esquina para hacerlo más grande.")
    L:EndCard()

    local function hasCompass() return db.compass end
    L:Card("Puntos cardinales")
    L:Row(W.Toggle(content, col, "Mostrar N, S, E y O", get("compass"), set("compass")),
          W.Slider(content, col, "Tamaño de las letras", 9, 22, 1, get("compassSize"), set("compassSize")),
          nil, hasCompass)
    L:Row(W.Slider(content, col, "Opacidad (%)", 30, 100, 5, get("compassAlpha"), set("compassAlpha")), nil, hasCompass)
    L:Note("El norte va en el color de BlazzitoUI. Si en las opciones de Blizzard tienes el minimapa girando, no se muestran (dejarían de señalar bien).")
    L:EndCard()

    local function hasClock() return db.clock end
    L:Card("Información")
    L:Row(W.Toggle(content, col, "Zona (en la barra de abajo)", get("zone"), set("zone")),
          W.Toggle(content, col, "Coordenadas", get("coords"), set("coords")))
    L:Row(W.Toggle(content, col, "Hora", get("clock"), set("clock")),
          W.Toggle(content, col, "Formato de 24 horas", get("clock24"), set("clock24")),
          nil, hasClock)
    L:Row(W.Toggle(content, col, "Hora de tu ordenador (si no, la del reino)", get("localTime"), set("localTime")),
          W.Toggle(content, col, "Botón de calendario", get("calendar"), set("calendar")),
          hasClock)
    L:Row(W.Slider(content, col, "Tamaño de la letra", 9, 18, 1, get("fontSize"), set("fontSize")))
    L:Note("Pulsa la zona para abrir el mapa del mundo y la hora para el reloj de Blizzard (alarmas, cronómetro). El calendario lleva un punto cuando tienes invitaciones.")
    L:EndCard()

    local function hasPaw() return db.petPaw end
    L:Card("Mascota")
    L:Row(W.Toggle(content, col, "Huella en la posición de tu mascota", get("petPaw"), set("petPaw")),
          W.Slider(content, col, "Tamaño de la huella", 10, 32, 1, get("pawSize"), set("pawSize")),
          nil, hasPaw)
    L:Row(W.Toggle(content, col, "Color según su felicidad (verde, amarillo, rojo)", get("pawHappiness"), set("pawHappiness")), nil, hasPaw)
    L:Note("Una huella grande y con borde en lugar del puntito del juego. Si la mascota se aleja más allá del borde del minimapa, la huella se queda en el borde señalando hacia dónde está. Gris si está muerta. /bui minimapa dice si el juego da su posición.")
    L:EndCard()

    L:Card("Botones de los addons")
    L:Row(W.Toggle(content, col, "Recogerlos en un solo botón (recarga para soltarlos)", get("collectButtons"), function(v)
              db.collectButtons = v
              if v then MM.Apply() else ns.AskReload() end
          end),
          W.Slider(content, col, "Botones por fila", 2, 10, 1, get("buttonsPerRow"), set("buttonsPerRow")),
          nil, function() return db.collectButtons end)
    L:Row(W.Toggle(content, col, "Mostrar también el compartimento de addons de Blizzard", get("showCompartment"), set("showCompartment")))
    L:Note("Los iconos que los addons ponen alrededor del minimapa quedan dentro del botón de la rejilla (bajo el calendario). Púlsalo para desplegarlos y otra vez para recogerlos.")
    L:EndCard()
    return L
end)
