-- Página "Ventanas" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.Windows) then return end

local Win, W = ns.Windows, ns.Widgets

local ACCENTS = {
    { value = "class", text = "Color de tu clase" },
    { value = "blue", text = "Azul de BlazzitoUI" },
    { value = "none", text = "Sin acento" },
}
local POSITIONS = {
    { value = "BOTTOM", text = "Abajo en el centro" }, { value = "BOTTOMLEFT", text = "Abajo a la izquierda" },
    { value = "BOTTOMRIGHT", text = "Abajo a la derecha" }, { value = "TOP", text = "Arriba en el centro" },
}

local function OpenCharacter()
    if ToggleCharacter then ToggleCharacter("PaperDollFrame")
    elseif CharacterFrame then CharacterFrame:SetShown(not CharacterFrame:IsShown()) end
end

ns.Config.RegisterPage("windows", "Ventanas", 21, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = Win.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            Win.ApplyAll()
            L:RefreshStates()
        end
    end
    local o = db.character
    local function cget(key) return function() return o[key] end end
    local function cset(key)
        return function(value)
            o[key] = value
            Win.ApplyAll()
            L:RefreshStates()
        end
    end
    local function charOn() return o.enabled end

    L:Card("Todas las ventanas")
    L:Row(W.Dropdown(content, col, "Color de acento", ACCENTS, get("accent"), set("accent")),
          W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("background"), set("background")))
    L:Row(W.Toggle(content, col, "Barra superior oscura con línea de acento", get("topBar"), set("topBar")),
          W.Toggle(content, col, "Ocultar el retrato de la ventana", get("hidePortrait"), set("hidePortrait")))
    L:Row(W.Toggle(content, col, "Botón de cerrar moderno", get("modernClose"), set("modernClose")),
          W.Toggle(content, col, "Pestañas planas (la elegida, marcada con el acento)", get("tabs"), set("tabs")))
    L:Row(W.Toggle(content, col, "Barras de desplazamiento finas con el color de acento", get("scrollBars"), function(v)
              db.scrollBars = v
              if v then Win.ApplyAll() else ns.AskReload() end
          end),
          W.Toggle(content, col, "Menús desplegables con nuestro estilo", get("menus"), set("menus")))
    L:Note("Las ventanas siguen siendo las de Blizzard: se abren, se cierran y funcionan igual; solo cambia su aspecto. Para moverlas, BlizzMove sigue funcionando. Se irán añadiendo ventanas poco a poco. /bui ventanas muestra qué piezas encuentra en cada una.")
    L:EndCard()

    L:Card("Personaje")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI en la ventana de personaje", cget("enabled"), function(v)
              o.enabled = v
              Win.ApplyAll()
              L:RefreshStates()
          end),
          W.Button(content, 200, "Abrir la ventana de personaje", OpenCharacter, true))
    L:Row(W.Toggle(content, col, "Fondo del personaje con el color de acento", cget("modelBackground"), cset("modelBackground")),
          W.Toggle(content, col, "Nivel de objeto medio sobre el personaje", cget("averageLevel"), cset("averageLevel")),
          charOn, charOn)
    L:Row(W.Toggle(content, col, "Estadísticas con cabeceras de acento", cget("stats"), cset("stats")),
          W.Toggle(content, col, "Flecha moderna para plegar las estadísticas", cget("modernToggle"), cset("modernToggle")),
          charOn, charOn)
    L:Row(W.Toggle(content, col, "Emblema de tu clase detrás del personaje", cget("watermark"), cset("watermark")),
          W.Toggle(content, col, "Barras de reputación y habilidades planas", cget("bars"), cset("bars")),
          charOn, charOn)
    L:Row(W.Toggle(content, col, "Encantamiento y gemas junto a cada pieza", cget("slotText"), cset("slotText")),
          W.Toggle(content, col, "Quitar también el fondo clásico de las otras pestañas", cget("otherTabs"), function(v)
              o.otherTabs = v
              if v then Win.ApplyAll() else ns.AskReload() end
          end), charOn, charOn)
    L:Row(W.Toggle(content, col, "Pestañas con icono planas (laterales y de arriba)", cget("iconTabs"), function(v)
              o.iconTabs = v
              Win.ApplyAll()
          end), nil, charOn)
    L:Note("Sobre el personaje: nivel de objeto medio y durabilidad de todo el equipo. Junto a cada pieza, su encantamiento en verde y sus huecos de gema (con la gema puesta o el hueco vacío de su color). En las estadísticas los valores conservan sus colores de Blizzard: verde si están mejorados y rojo si están reducidos. En reputación y habilidades, barras planas y cabeceras con el color de acento.")
    L:EndCard()

    local p = db.pet
    local function pget(key) return function() return p[key] end end
    local function pset(key)
        return function(value)
            p[key] = value
            Win.ApplyAll()
            L:RefreshStates()
        end
    end
    local function petOn() return charOn() and p.enabled end
    L:Card("Mascota")
    L:Row(W.Toggle(content, col, "Panel de la mascota pegado bajo la ventana", pget("enabled"), pset("enabled")),
          W.Toggle(content, col, "Ocultar la vista \"Mascota\" de Blizzard", pget("hideTab"), pset("hideTab")),
          charOn, petOn)
    L:Row(W.Toggle(content, col, "Girar el modelo arrastrando con el ratón", pget("rotate"), pset("rotate")),
          W.Toggle(content, col, "Icono de felicidad de Blizzard junto al nombre", pget("moveHappiness"), pset("moveHappiness")),
          petOn, petOn)
    L:Note("Con una mascota invocada, debajo de la ventana de personaje aparece todo lo de su pestaña: modelo, nivel y familia, felicidad, lealtad, vida, foco, experiencia, atributos, armadura, ataque, resistencias, lo que come y los puntos de adiestramiento. La vista \"Mascota\" de Blizzard no se borra: solo deja de verse. Su icono de felicidad (con su descripción al pasar el ratón) se muda junto al nombre.")
    L:EndCard()

    local t = db.talents
    local function tget(key) return function() return t[key] end end
    local function tset(key)
        return function(value)
            t[key] = value
            Win.ApplyAll()
            L:RefreshStates()
        end
    end
    local function talOn() return t.enabled end
    L:Card("Talentos y libro de hechizos")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI en la ventana de talentos", tget("enabled"), function(v)
              t.enabled = v
              if v then Win.ApplyAll() else ns.AskReload() end
              L:RefreshStates()
          end),
          W.Button(content, 200, "Abrir la ventana de talentos", function()
              if PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then pcall(PlayerSpellsUtil.ToggleClassTalentFrame)
              elseif ToggleTalentFrame then pcall(ToggleTalentFrame) end
          end, true))
    L:Row(W.Toggle(content, col, "Rango de cada talento (2/5) en una pastilla", tget("ranks"), tset("ranks")),
          W.Toggle(content, col, "Halo de tu color en los talentos al máximo", tget("glow"), tset("glow")),
          talOn, talOn)
    L:Row(W.Toggle(content, col, "Reparto de puntos arriba (Puntería 0 / 2 / 0)", tget("summary"), tset("summary")),
          W.Slider(content, col, "Opacidad del arte de los árboles (%)", 0, 100, 5, tget("art"), tset("art")),
          talOn, talOn)
    local sbo = db.spellbook
    L:Row(W.Toggle(content, col, "Libro de hechizos unificado (todas las especializaciones juntas)", function() return sbo.enabled end, function(v)
              sbo.enabled = v
              Win.ApplyAll()
              L:RefreshStates()
          end),
          W.Toggle(content, col, "Abrir el libro siempre desplegado", function() return sbo.expand end, function(v)
              sbo.expand = v
              L:RefreshStates()
          end), talOn, function() return talOn() and sbo.enabled end)
    L:Row(W.Toggle(content, col, "Resaltar los hechizos que no tienes en tus barras", function() return sbo.markUnbound end, function(v)
              sbo.markUnbound = v
              Win.ApplyAll()
          end),
          W.Toggle(content, col, "Avisar si en tus barras hay un rango anterior", function() return sbo.markOldRank ~= false end, function(v)
              sbo.markOldRank = v
              Win.ApplyAll()
          end), function() return talOn() and sbo.enabled end, function() return talOn() and sbo.enabled end)
    L:Note("Rango anterior: si en tus barras está, por ejemplo, el Rango 2 de un hechizo y ya conoces el Rango 3, el libro lo marca en verde con una flecha. Arrastra el rango nuevo encima del viejo para mejorarlo.")
    L:Note("El libro unificado pone la parte general y cada especialización en el mismo libro, una sección tras otra con su encabezado. La mascota tiene su propia pestaña en el libro: clic izquierdo lanza su hechizo y clic derecho le pone o quita el lanzamiento automático. Respeta las opciones del libro de Blizzard (ocultar pasivas, mostrar todos los rangos) y su buscador. Al pasar el ratón por un hechizo, parpadea en tus barras; Mayús + clic lo enlaza en el chat. En combate se puede lanzar desde él, pero pasar de página o cambiar a la mascota espera al final del combate.")
    L:Note("Cada talento lleva un anillo del color de su estado: al máximo, tu color de clase (con halo); con puntos, tu color más suave; disponible, claro; bloqueado, oscuro. El arte de cada árbol se queda de fondo, más tenue, para que manden los iconos. Las pestañas, el buscador y «Aplicar cambios» pasan a ser planos. /bui ventanas muestra qué piezas encuentra en la ventana (ábrela antes).")
    L:EndCard()

    local wm = db.worldmap
    L:Card("Mapa del mundo y misiones")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI en el mapa y el registro de misiones", function() return wm.enabled end, function(v)
              wm.enabled = v
              if v then Win.ApplyAll() else ns.AskReload() end
              L:RefreshStates()
          end),
          W.Button(content, 200, "Abrir el mapa", function()
              if ToggleWorldMap then pcall(ToggleWorldMap) elseif _G.WorldMapFrame then _G.WorldMapFrame:SetShown(not _G.WorldMapFrame:IsShown()) end
          end, true))
    L:Row(W.Toggle(content, col, "Cabeceras de zona del registro con el color de acento", function() return wm.headers end, function(v)
              wm.headers = v
              Win.ApplyAll()
          end),
          W.Toggle(content, col, "Cada misión como una tarjeta (con sus objetivos)", function() return wm.cards end, function(v)
              wm.cards = v
              Win.ApplyAll()
          end), function() return wm.enabled end, function() return wm.enabled end)
    L:Note("Marco oscuro con la barra de acento, cerrar y plegar modernos, la barra de ruta (Kalimdor > Durotar...) sobre una franja oscura y el botón del panel lateral con flecha. La ruta (Mundo > zona) en tramos planos, y los botones del mapa (filtro, seguimiento) cuadrados. En el registro: cada misión en una tarjeta con sus objetivos, sus botones (seguir, completar) modernos, cabeceras de zona con el color de acento, buscador y contador planos y pestañas laterales cuadradas. El texto de cada misión conserva su pergamino (su letra es oscura). Los puntos del mapa, Questie y el rastreador no se tocan.")
    L:EndCard()

    local function other(key)
        return function() return db[key].enabled end, function(v)
            db[key].enabled = v
            if v then Win.ApplyAll() else ns.AskReload() end
        end
    end
    L:Card("Otras ventanas")
    local g1, s1 = other("trainer")
    local g2, s2 = other("loot")
    L:Row(W.Toggle(content, col, "Entrenadores (clase y bestias)", g1, s1), W.Toggle(content, col, "Botín y tiradas de grupo", g2, s2))
    local g3, s3 = other("merchant")
    local g4, s4 = other("mail")
    L:Row(W.Toggle(content, col, "Comerciante", g3, s3), W.Toggle(content, col, "Correo", g4, s4))
    local g5, s5 = other("professions")
    local g6, s6 = other("auction")
    L:Row(W.Toggle(content, col, "Profesiones", g5, s5), W.Toggle(content, col, "Casa de subastas", g6, s6))
    L:Note("Marco oscuro con la barra de acento y, dentro, botones, buscadores y casillas planos: el icono recortado con borde fino y el color de calidad de Blizzard. Lo que hace cada ventana no cambia. Si alguna pieza sigue con el estilo antiguo, abre la ventana y escribe /bui ventanas.")
    L:EndCard()

    local shapes = {}
    for i, key in ipairs(ns.Media.BUTTON_SHAPE_ORDER) do shapes[i] = { value = key, text = ns.Media.BUTTON_SHAPES[key].text } end
    L:Card("Casillas de equipo")
    L:Row(W.Dropdown(content, col, "Forma", shapes, cget("slotShape"), cset("slotShape")),
          W.Slider(content, col, "Grosor del borde", 0, 3, 1, cget("slotBorder"), cset("slotBorder")),
          charOn, charOn)
    L:Row(W.Toggle(content, col, "Voltear horizontal", cget("slotFlipH"), cset("slotFlipH")),
          W.Toggle(content, col, "Voltear vertical", cget("slotFlipV"), cset("slotFlipV")),
          charOn, charOn)
    L:Row(W.Toggle(content, col, "Borde del color de la calidad", cget("qualityBorder"), cset("qualityBorder")),
          W.Toggle(content, col, "Nivel de objeto en cada pieza", cget("itemLevel"), cset("itemLevel")),
          charOn, charOn)
    local function hasLevel() return charOn() and o.itemLevel end
    L:Row(W.Dropdown(content, col, "Posición del nivel", POSITIONS, cget("itemLevelPos"), cset("itemLevelPos")),
          W.Slider(content, col, "Tamaño del número", 8, 16, 1, cget("itemLevelSize"), cset("itemLevelSize")),
          hasLevel, hasLevel)
    L:Row(W.Toggle(content, col, "Número del color de la calidad", cget("itemLevelQuality"), cset("itemLevelQuality")),
          W.Toggle(content, col, "Avisar de la durabilidad baja", cget("durability"), cset("durability")),
          hasLevel, charOn)
    local function hasDura() return charOn() and o.durability end
    L:Row(W.Slider(content, col, "Avisar desde (%)", 10, 100, 5, cget("durabilityWarn"), cset("durabilityWarn")), nil, hasDura)
    L:Note("La durabilidad sale en la casilla cuando baja del porcentaje elegido: en amarillo, y en rojo a partir del 20 %. La camisa, el tabardo y la munición no llevan nivel de objeto.")
    L:EndCard()
    return L
end)
