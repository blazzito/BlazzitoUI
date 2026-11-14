-- Página "Bolsas" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.Bags) then return end

local B, W = ns.Bags, ns.Widgets

local POSITIONS = {
    { value = "BOTTOMLEFT", text = "Abajo a la izquierda" }, { value = "BOTTOMRIGHT", text = "Abajo a la derecha" },
    { value = "TOPRIGHT", text = "Arriba a la derecha" }, { value = "BOTTOM", text = "Abajo en el centro" },
}

ns.Config.RegisterPage("bags", "Bolsas", 15, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = B.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            B.ApplyAll()
            L:RefreshStates()
        end
    end
    local function skinned() return db.skin end

    L:Card("Mochila")
    L:Row(W.Toggle(content, col, "Mochila unificada (todas las bolsas en una)", function() return B.IsCombined() end,
              function(v) B.SetCombined(v); L:Refresh() end),
          W.Button(content, 200, "Abrir las bolsas", function() if ToggleAllBags then ToggleAllBags() end end, true),
          function() return B.HasCombinedOption() end)
    L:Row(W.Toggle(content, col, "Huecos libres en el botón de la mochila", get("freeSlots"), set("freeSlots")))
    L:Note("Es la misma opción de WoW: unificada o una ventana por bolsa. Abrir, ordenar, buscar y usar objetos sigue siendo de Blizzard. El número de huecos libres cuenta las bolsas normales (no el carcaj ni las bolsas de oficio) y se pone amarillo con 4 o menos y rojo si está llena.")
    L:EndCard()

    L:Card("Ventana")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI", get("skin"), set("skin")),
          W.Toggle(content, col, "Ocultar el retrato de la ventana", get("hidePortrait"), set("hidePortrait")),
          nil, skinned)
    L:Row(W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("background"), set("background")),
          W.Toggle(content, col, "Botón de cerrar, buscador, ordenar y monedas modernos", get("modernChrome"), set("modernChrome")),
          skinned, skinned)
    L:EndCard()

    local shapes = {}
    for i, key in ipairs(ns.Media.BUTTON_SHAPE_ORDER) do shapes[i] = { value = key, text = ns.Media.BUTTON_SHAPES[key].text } end
    L:Card("Casillas")
    L:Row(W.Dropdown(content, col, "Forma", shapes, get("slotShape"), set("slotShape")),
          W.Color(content, col, "Color del fondo", get("slotColor"), function(r, g, b) db.slotColor = { r, g, b }; B.ApplyAll() end),
          skinned, skinned)
    L:Row(W.Toggle(content, col, "Voltear horizontal", get("slotFlipH"), set("slotFlipH")),
          W.Toggle(content, col, "Voltear vertical", get("slotFlipV"), set("slotFlipV")),
          skinned, skinned)
    L:Row(W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("slotBackground"), set("slotBackground")),
          W.Slider(content, col, "Grosor del borde", 0, 3, 1, get("border"), set("border")),
          skinned, skinned)
    L:Row(W.Toggle(content, col, "Borde del color de la calidad", get("qualityBorder"), set("qualityBorder")),
          W.Toggle(content, col, "Equipo que no puedes usar en rojo", get("unusableRed"), set("unusableRed")),
          skinned, skinned)
    L:EndCard()

    local function hasLevel() return skinned() and db.itemLevel end
    L:Card("Información de los objetos")
    L:Row(W.Toggle(content, col, "Nivel de objeto en el equipo", get("itemLevel"), set("itemLevel")),
          W.Dropdown(content, col, "Posición del nivel", POSITIONS, get("itemLevelPos"), set("itemLevelPos")),
          skinned, hasLevel)
    L:Row(W.Slider(content, col, "Tamaño del número", 8, 16, 1, get("itemLevelSize"), set("itemLevelSize")),
          W.Toggle(content, col, "Número del color de la calidad", get("itemLevelQuality"), set("itemLevelQuality")),
          hasLevel, hasLevel)
    L:Row(W.Toggle(content, col, "Flecha de mejora (verde) o peor (roja)", get("upgrade"), set("upgrade")),
          W.Toggle(content, col, "Brillo en los objetos nuevos", get("newGlow"), set("newGlow")),
          skinned, skinned)
    L:Note("La flecha compara el nivel del objeto con lo que llevas puesto en esa ranura (en anillos, abalorios y armas a una mano, con el peor de los dos). Solo es una guía: no mira estadísticas. Los objetos que tu clase no puede usar no llevan flecha. El brillo de un objeto nuevo se quita al pasarle el ratón por encima.")
    L:EndCard()

    L:Card("Extras")
    L:Row(W.Toggle(content, col, "Marcar la basura (moneda)", get("junkMark"), set("junkMark")),
          W.Toggle(content, col, "Vender la basura al abrir un vendedor", get("autoSellJunk"), set("autoSellJunk")))
    L:Row(W.Toggle(content, col, "Basura junto a la ventana de botín", get("lootJunk"), set("lootJunk")),
          W.Toggle(content, col, "Solo con las bolsas llenas", get("lootJunkFullOnly"), set("lootJunkFullOnly")),
          nil, function() return db.lootJunk end)
    L:Row(W.Toggle(content, col, "Botón «Recoger todo» bajo el botín", get("lootAll"), set("lootAll")))
    L:Row(W.Toggle(content, col, "Acciones rápidas con Alt+clic", get("quickActions"), set("quickActions")),
          W.Toggle(content, col, "Banco con el mismo estilo", get("bank"), set("bank")))
    L:Note("Basura: los objetos grises que se pueden vender. Al abrir un vendedor se venden uno a uno y te dice cuánto has ganado en el chat (puedes recomprarlos en la pestaña de recompra del vendedor).")
    L:Note("Basura junto al botín: al abrir un botín sin sitio en las bolsas (o cuando el juego avisa de que están llenas) aparece a su derecha tu basura, la más barata primero, con lo que te daría un vendedor. La X destruye ese montón al momento y ya puedes recoger lo que querías.")
    L:Note("Acciones rápidas: con Alt pulsado, el objeto bajo el ratón se marca si puedes desencantarlo, forzar su cerradura, prospectarlo o molerlo; Alt+clic lo hace. Solo fuera de combate.")
    L:EndCard()
    return L
end)
