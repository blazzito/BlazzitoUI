-- Página "Placas de nombre" de la ventana /bui. Arriba, fijas (no se van al
-- bajar por la página), tres placas de ejemplo que muestran cada cambio al
-- momento: tu objetivo, otro enemigo fuera de alcance y casi muerto, y un
-- aliado.
local ns = BlazzitoUI
if not (ns and ns.Nameplates and ns.Nameplates.Shape) then return end

local NP, M, W = ns.Nameplates, ns.Media, ns.Widgets
local Shape = NP.Shape

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local COLOR_MODES = Choices({ { "reaction", "Reacción (hostil, neutral...) y clase" }, { "threat", "Aggro en combate (y reacción fuera)" } })
local HEALTH_TEXT = Choices({ { "percent", "Porcentaje" }, { "value", "Vida" }, { "both", "Vida y porcentaje" }, { "none", "Ninguno" } })

ns.Config.RegisterPage("nameplates", "Placas de nombre", 18, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = NP.db
    local function refresh()
        NP.ApplyAll()
        L:RefreshStates()
    end
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            refresh()
        end
    end
    local function setColor(key)
        return function(r, g, b)
            db[key] = { r, g, b }
            NP.ApplyAll()
        end
    end

    local shapes = {}
    for i, key in ipairs(Shape.ORDER) do shapes[i] = { value = key, text = Shape.INFO[key].text } end

    -- Vista previa fijada arriba: siempre a la vista mientras cambias ajustes.
    local pin = L:Pinned(200)
    local title = W.SectionTitle(pin, "Vista previa")
    title:SetPoint("TOPLEFT", L.x, -12)
    local line = W.Line(pin, W.T.sectionLine)
    line:SetPoint("BOTTOMLEFT", L.x, 0)
    line:SetPoint("BOTTOMRIGHT", -L.x, 0)
    NP.previews = {}
    local LABELS = { target = "Tu objetivo", friend = "Aliado" }
    NP.previewSpace = L.width / 2
    for i, variant in ipairs({ "target", "friend" }) do
        local x = (i == 1 and -1 or 1) * L.width / 4
        local label = W.Text(pin, 11, W.T.dim)
        label:SetPoint("BOTTOM", pin, "BOTTOM", x, 8)
        label:SetText(ns.Translate(LABELS[variant]))
        local p = NP.Build(pin, true)
        -- Un poco por debajo del centro: encima van nombre y debuffs.
        p.previewX, p.previewY = x, -6
        NP.previews[variant] = p
        NP.PaintPreview(p, variant)
    end

    L:Card("Tamaño")
    L:Row(W.Slider(content, col, "Ancho", 60, 260, 2, get("width"), set("width")),
          W.Slider(content, col, "Alto", 4, 30, 1, get("height"), set("height")))
    L:Row(W.Slider(content, col, "Escala", 0.6, 1.6, 0.1, get("scale"), set("scale")),
          W.Slider(content, col, "Subir o bajar", -40, 40, 1, get("offsetY"), set("offsetY")))
    L:Row(W.Slider(content, col, "Tamaño de letra", 7, 16, 1, get("fontSize"), set("fontSize")),
          W.Color(content, col, "Color de la letra", get("fontColor"), setColor("fontColor")))
    L:Note("Las placas tienen siempre el mismo tamaño, cerca o lejos: así el borde de 1 píxel se ve nítido.")
    L:EndCard()

    local function canFlip() return Shape.INFO[db.shape] and Shape.INFO[db.shape].flips end
    L:Card("Forma")
    L:Row(W.Dropdown(content, col, "Forma", shapes, get("shape"), set("shape")),
          W.Slider(content, col, "Grosor del borde (0 = sin borde)", 0, 3, 1, get("border"), set("border")))
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("flipH"), set("flipH")),
          W.Toggle(content, col, "Voltear vertical", get("flipV"), set("flipV")), canFlip, canFlip)
    L:Row(W.Toggle(content, col, "Brillo en las barras", get("gloss"), set("gloss")))
    L:Note("Las formas mantienen su ángulo con cualquier ancho: los extremos no se estiran.")
    L:EndCard()

    L:Card("Vida y textos")
    L:Row(W.Dropdown(content, col, "Color de la vida", COLOR_MODES, get("colorMode"), set("colorMode")),
          W.Dropdown(content, col, "Texto de vida", HEALTH_TEXT, get("healthText"), set("healthText")))
    L:Row(W.Toggle(content, col, "Mostrar nombre", get("showName"), set("showName")),
          W.Toggle(content, col, "Mostrar nivel (+ élite, ?? jefe, rombo si es raro)", get("showLevel"), set("showLevel")))
    local function hasExecute() return db.execute > 0 end
    L:Row(W.Slider(content, col, "Umbral de remate (%) · 0 = no", 0, 50, 5, get("execute"), set("execute")),
          W.Color(content, col, "Color de remate", get("executeColor"), setColor("executeColor")),
          nil, hasExecute)
    L:Note("Por debajo del umbral la barra cambia al color de remate, aunque la vida llegue secreta en combate.")
    L:EndCard()

    local function hasRange() return db.range end
    L:Card("Objetivo y alcance")
    L:Row(W.Toggle(content, col, "Resaltar tu objetivo", get("targetHighlight"), set("targetHighlight")),
          W.Slider(content, col, "Opacidad del resto (%)", 30, 100, 5, get("otherAlpha"), set("otherAlpha")))
    L:Row(W.Toggle(content, col, "Atenuar los enemigos fuera de alcance", get("range"), set("range")),
          W.Slider(content, col, "Opacidad fuera de alcance (%)", 15, 90, 5, get("rangeAlpha"), set("rangeAlpha")),
          nil, hasRange)
    L:Note("El alcance se comprueba con hechizos de tu clase. En el cazador, Disparo automático y Golpe de raptor: la zona muerta de 5 a 8 metros cuenta como fuera de alcance.")
    L:Row(W.Toggle(content, col, "Área de clic del tamaño de la placa", get("clickArea"), set("clickArea")))
    L:Note("Para seleccionar un enemigo vale con hacer clic en su barra o en su nombre. Se aplica fuera de combate; el juego usa la misma medida para todas las placas.")
    L:EndCard()

    L:Card("Aliados")
    L:Row(W.Toggle(content, col, "Placas aliadas: solo el nombre", get("friendly"), set("friendly")))
    L:Note("Aliados y neutrales que no se pueden atacar: solo su nombre, del color de su clase (jugadores) o de su reacción. Se ven si tienes activadas las placas aliadas del juego. En mazmorras y bandas el juego no deja tocarlas.")
    L:EndCard()

    -- Aggro: una sola insignia (la del módulo «Aggro en placas»,
    -- Blazzito_ThreatPlate) para estas placas y las de Blizzard; todos sus
    -- ajustes aquí, y cada cambio se ve en la vista previa de arriba.
    local function hasThreat() return db.threat end
    L:Card("Aggro")
    L:Row(W.Toggle(content, col, "Mostrar tu % de aggro a la derecha", get("threat"), set("threat")),
          W.Toggle(content, col, "Teñir el borde con el color del aggro", get("threatBorder"), set("threatBorder")),
          nil, hasThreat)
    local TP = ns.ThreatPlate
    if TP and TP.db and TP.NewBadge then
        local tdb = TP.db
        local function tget(key) return function() return tdb[key] end end
        local function tset(key)
            return function(value)
                tdb[key] = value
                refresh()
            end
        end
        L:Row(W.Dropdown(content, col, "Diseño de la insignia", {
                  { value = "blazzito", text = "BlazzitoUI (forma y borde del color del aggro)" },
                  { value = "classic", text = "Clásico (borde dorado)" },
              }, tget("style"), tset("style")),
              W.Dropdown(content, col, "Forma de la insignia", shapes, tget("shape"), tset("shape")),
              hasThreat, function() return hasThreat() and tdb.style ~= "classic" end)
        L:Row(W.Slider(content, col, "Tamaño de letra de la insignia", 7, 16, 1, tget("fontSize"), tset("fontSize")),
              W.Toggle(content, col, "Mostrar 0% en combate", tget("showZero"), tset("showZero")),
              hasThreat, hasThreat)

        -- Sobre las placas que no son de BlazzitoUI.
        L:Row(W.Toggle(content, col, "La misma insignia en las placas de Blizzard", tget("enabled"), function(value)
            TP.SetEnabled(value)
            refresh()
        end))
        L:Row(W.Slider(content, col, "Horizontal de la insignia", -150, 150, 1, tget("offsetX"), tset("offsetX")),
              W.Slider(content, col, "Vertical de la insignia", -40, 40, 1, tget("offsetY"), tset("offsetY")),
              hasThreat, hasThreat)
        L:Note("La insignia va en el centro de la barra; Horizontal y Vertical la mueven desde ahí (se ve en tu objetivo, arriba). Lo mismo en las placas de Blizzard, las que no son de BlazzitoUI (si apagas estas placas, o donde el juego no deja tocarlas). Sobre estas placas nunca se repite.")
        if TP.blocked then
            L:Note("|cffff9933El addon Blazz_ThreatPlate sigue activo: desactívalo en la lista de addons para que este módulo funcione.|r")
        end
    end
    L:EndCard()

    local function hasCast() return db.castbar end
    L:Card("Barra de lanzamiento")
    L:Row(W.Toggle(content, col, "Mostrar barra de lanzamiento", get("castbar"), set("castbar")),
          W.Color(content, col, "Color del lanzamiento", get("castColor"), setColor("castColor")),
          nil, hasCast)
    L:Row(W.Slider(content, col, "Alto", 6, 24, 1, get("castHeight"), set("castHeight")),
          W.Toggle(content, col, "Mostrar a quién va dirigido", get("castTarget"), set("castTarget")),
          hasCast, hasCast)
    L:Row(W.Toggle(content, col, "Borde rojo si te lo lanzan a ti", get("castWarn"), set("castWarn")), nil, hasCast)
    L:Note("Un escudo sobre el icono indica que no se puede interrumpir (barra gris). Si lo interrumpen, la barra se queda un momento en rojo.")
    L:EndCard()

    local function hasAuras() return db.auras end
    L:Card("Tus debuffs")
    L:Row(W.Toggle(content, col, "Mostrar tus debuffs sobre la placa", get("auras"), set("auras")),
          W.Slider(content, col, "Tamaño", 12, 30, 1, get("auraSize"), set("auraSize")),
          nil, hasAuras)
    L:Row(W.Slider(content, col, "Máximo de iconos", 1, 8, 1, get("auraMax"), set("auraMax")), nil, hasAuras)
    L:EndCard()

    L:Card("Marcas")
    L:Row(W.Toggle(content, col, "Marcar los enemigos de tus misiones", get("quest"), set("quest")),
          W.Toggle(content, col, "Marcar a quién ataca tu mascota", get("petTarget"), set("petTarget")))
    L:Note("Misión: un «!» amarillo a la izquierda del nombre. Los enemigos que hay que matar se reconocen por tu registro de misiones; los que sueltan objetos de misión se aprenden la primera vez que saqueas uno de esos objetos (se recuerda para toda la cuenta). La bolsita junto a la placa es de Questie (se quita en sus opciones, pestaña de placas). Mascota: una huella a la derecha del nombre.")
    L:EndCard()
    return L
end)
