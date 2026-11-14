-- Página "Auras" de la ventana de configuración de BlazzitoUI.
-- Mismas tarjetas que los marcos de unidad: al cambiar algo aparecen copiar
-- (a la pareja: Jugador <-> Objetivo, Mascota <-> Obj. del objetivo) y revertir.
local ns = BlazzitoUI
if not (ns and ns.Auras and ns.UnitFrames and ns.UnitFrames.NewCardSession) then return end

local A, UF, W = ns.Auras, ns.UnitFrames, ns.Widgets

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local MODES = Choices({ { "icons", "Iconos (con cargas y tiempo)" }, { "bars", "Barras (icono, nombre y tiempo)" } })
local POSITIONS = Choices({ { "above", "Encima del marco" }, { "below", "Debajo del marco" } })
local MARKS = Choices({ { "diamond", "Rombo" }, { "star", "Estrella" }, { "glow", "Brillo alrededor" }, { "none", "Ninguna" } })

local CONTEXT = {
    units = function() return A.db.units end,
    style = function() return A.db.style end,
    editing = function() return A.editing end,
    apply = function(unit) A.ApplyUnit(unit) end,
    applyAll = function() A.ApplyAll() end,
}

ns.Config.RegisterPage("auras", "Auras", 15, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local function cfg() return A.db.units[A.editing] end
    local function get(key) return function() return cfg()[key] end end
    local function Session(title, keys)
        return UF.NewCardSession(L:Card(title), keys, nil, L, CONTEXT)
    end

    local tabs = {}
    for i, unit in ipairs(UF.UNITS) do tabs[i] = { value = unit, text = UF.INFO[unit].label } end
    L:Full(W.Tabs(content, tabs,
        function() return A.editing end,
        function(unit)
            A.editing = unit
            L:Refresh()
        end, L.width))

    local function shown() return cfg().enabled end
    local function isBars() return cfg().enabled and cfg().mode == "bars" end
    local function isIcons() return cfg().enabled and cfg().mode == "icons" end

    local s = Session("Auras", { "enabled", "mode", "position", "swap" })
    L:Row(W.Toggle(content, col, "Mostrar auras en este marco", get("enabled"), s.Set("enabled")),
          W.Toggle(content, col, "Intercambiar mitades", get("swap"), s.Set("swap")),
          nil, shown)
    L:Row(W.Dropdown(content, col, "Cómo se ven", MODES, get("mode"), s.Set("mode")),
          W.Dropdown(content, col, "Posición", POSITIONS, get("position"), s.Set("position")),
          shown, shown)
    L:Note("El ancho del marco se parte en dos: beneficios en una mitad y perjuicios en la otra (por defecto, beneficios a la izquierda). Cada mitad crece desde su borde exterior.")
    L:EndCard()

    s = Session("Tamaño", { "size", "spacing", "maxPerSide", "barHeight" })
    L:Row(W.Slider(content, col, "Tamaño de los iconos", 12, 40, 1, get("size"), s.Set("size")),
          W.Slider(content, col, "Alto de las barras", 10, 30, 1, get("barHeight"), s.Set("barHeight")),
          isIcons, isBars)
    L:Row(W.Slider(content, col, "Máximo por mitad", 1, 20, 1, get("maxPerSide"), s.Set("maxPerSide")),
          W.Slider(content, col, "Espaciado", 0, 8, 1, get("spacing"), s.Set("spacing")),
          shown, shown)
    L:EndCard()

    s = Session("Filtros", { "onlyMyBuffs", "onlyMyDebuffs" })
    L:Row(W.Toggle(content, col, "Solo mis beneficios", get("onlyMyBuffs"), s.Set("onlyMyBuffs")),
          W.Toggle(content, col, "Solo mis perjuicios", get("onlyMyDebuffs"), s.Set("onlyMyDebuffs")),
          shown, shown)
    L:Note("\"Solo mis perjuicios\" en el Objetivo deja ver solo lo que tú le has puesto (útil para DoTs).")
    L:EndCard()

    s = Session("Disipables", { "dispelMark", "dispelColor", "typeBorder" })
    L:Row(W.Dropdown(content, col, "Marca en lo que puedes disipar", MARKS, get("dispelMark"), s.Set("dispelMark")),
          W.Color(content, col, "Color de la marca", get("dispelColor"), s.SetColor("dispelColor")),
          shown, function() return shown() and cfg().dispelMark ~= "none" end)
    L:Row(W.Toggle(content, col, "Borde del color del tipo (magia, maldición...)", get("typeBorder"), s.Set("typeBorder")),
          nil, shown)
    L:Note("Los perjuicios que tu clase puede quitar van primero y llevan la marca.")
    L:EndCard()

    s = Session("Textos", { "showTime", "showStacks" })
    L:Row(W.Toggle(content, col, "Mostrar tiempo restante (modo barras)", get("showTime"), s.Set("showTime")),
          W.Toggle(content, col, "Mostrar cargas", get("showStacks"), s.Set("showStacks")),
          function() return shown() and cfg().mode == "bars" end, shown)
    L:Note("En modo iconos el tiempo lo muestra el contador dentro del icono (OmniCC o el de Blizzard).")
    L:EndCard()
    local bf = A.db.buffFrame
    local function setBF(key) return function(v) bf[key] = v; if A.BuffFrame then A.BuffFrame.ApplyAll() end; L:RefreshStates() end end
    local bfShapes = {}
    for i, key in ipairs(ns.Media.BUTTON_SHAPE_ORDER) do bfShapes[i] = { value = key, text = ns.Media.BUTTON_SHAPES[key].text } end
    local function bfOn() return bf.skin end
    L:Card("Beneficios junto al minimapa")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI", function() return bf.skin end, setBF("skin")),
          W.Dropdown(content, col, "Forma de los iconos", bfShapes, function() return bf.shape end, setBF("shape")),
          nil, bfOn)
    L:Row(W.Slider(content, col, "Grosor del borde", 0, 3, 1, function() return bf.border end, setBF("border")),
          W.Slider(content, col, "Tamaño de la letra", 8, 16, 1, function() return bf.fontSize end, setBF("fontSize")),
          bfOn, bfOn)
    L:Note("Son los beneficios y perjuicios de Blizzard de arriba a la derecha (y la flechita que los pliega): siguen funcionando igual, solo cambia su aspecto. Los perjuicios mantienen el color de su tipo en el borde. En combate no se pueden tocar: lo nuevo se viste al salir.")
    L:EndCard()

    L:Card("Avanzado")
    L:Row(W.Toggle(content, col, "Respaldo con iconos del motor (experimental)",
        function() return A.db.style.engineFallback end,
        function(v) A.db.style.engineFallback = v; A.ApplyAll() end))
    L:Note("Las auras \"secretas\" (enemigos en combate) siempre las pinta el motor del juego: es la única forma de verlas. Esta opción solo añade el motor cuando la lectura falla por otro motivo.")
    L:EndCard()
    return L
end)
