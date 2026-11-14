-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Bags.lua
    ["basura vendida: %d objeto por %s."] = "junk sold: %d item for %s.",
    ["basura vendida: %d objetos por %s."] = "junk sold: %d items for %s.",
    ["no se puede cambiar el tipo de mochila en combate."] = "the backpack type can't be changed in combat.",

    -- LootJunk.lua
    ["Pulsa la X para destruirlo y hacer sitio."] = "Press the X to destroy it and make room.",
    ["Basura"] = "Junk",
    ["y %d más"] = "and %d more",
    ["Recoger todo"] = "Loot all",
    ["diagnóstico del panel de basura junto al botín"] = "diagnostics for the junk panel next to the loot window",

    -- QuickActions.lua
    ["Alt+clic: %s"] = "Alt+click: %s",

    -- Config.lua
    ["Abajo a la izquierda"] = "Bottom left",
    ["Abajo a la derecha"] = "Bottom right",
    ["Arriba a la derecha"] = "Top right",
    ["Abajo en el centro"] = "Bottom center",
    ["Mochila"] = "Backpack",
    ["Mochila unificada (todas las bolsas en una)"] = "Combined backpack (all bags in one)",
    ["Abrir las bolsas"] = "Open the bags",
    ["Huecos libres en el botón de la mochila"] = "Free slots on the backpack button",
    ["Es la misma opción de WoW: unificada o una ventana por bolsa. Abrir, ordenar, buscar y usar objetos sigue siendo de Blizzard. El número de huecos libres cuenta las bolsas normales (no el carcaj ni las bolsas de oficio) y se pone amarillo con 4 o menos y rojo si está llena."] =
        "It's the same WoW option: combined or one window per bag. Opening, sorting, searching and using items is still Blizzard's. The free slot count includes regular bags (not the quiver or profession bags) and turns yellow at 4 or fewer and red when full.",
    ["Ventana"] = "Window",
    ["Estilo de BlazzitoUI"] = "BlazzitoUI style",
    ["Ocultar el retrato de la ventana"] = "Hide the window portrait",
    ["Opacidad del fondo (%)"] = "Background opacity (%)",
    ["Botón de cerrar, buscador, ordenar y monedas modernos"] = "Modern close button, search, sort and currencies",
    ["Casillas"] = "Slots",
    ["Color del fondo"] = "Background color",
    ["Grosor del borde"] = "Border size",
    ["Borde del color de la calidad"] = "Quality-colored border",
    ["Equipo que no puedes usar en rojo"] = "Gear you can't use in red",
    ["Información de los objetos"] = "Item info",
    ["Nivel de objeto en el equipo"] = "Item level on gear",
    ["Posición del nivel"] = "Level position",
    ["Tamaño del número"] = "Number size",
    ["Número del color de la calidad"] = "Quality-colored number",
    ["Flecha de mejora (verde) o peor (roja)"] = "Upgrade (green) or downgrade (red) arrow",
    ["Brillo en los objetos nuevos"] = "Glow on new items",
    ["La flecha compara el nivel del objeto con lo que llevas puesto en esa ranura (en anillos, abalorios y armas a una mano, con el peor de los dos). Solo es una guía: no mira estadísticas. Los objetos que tu clase no puede usar no llevan flecha. El brillo de un objeto nuevo se quita al pasarle el ratón por encima."] =
        "The arrow compares the item level with what you wear in that slot (for rings, trinkets and one-hand weapons, with the worse of the two). It's only a guide: it ignores stats. Items your class can't use get no arrow. A new item's glow goes away when you mouse over it.",
    ["Marcar la basura (moneda)"] = "Mark junk (coin)",
    ["Basura junto a la ventana de botín"] = "Junk next to the loot window",
    ["Solo con las bolsas llenas"] = "Only when bags are full",
    ["Botón «Recoger todo» bajo el botín"] = "«Loot all» button under the loot window",
    ["Acciones rápidas con Alt+clic"] = "Quick actions with Alt+click",
    ["Banco con el mismo estilo"] = "Bank in the same style",
    ["Basura: los objetos grises que se pueden vender. Al abrir un vendedor se venden uno a uno y te dice cuánto has ganado en el chat (puedes recomprarlos en la pestaña de recompra del vendedor)."] =
        "Junk: grey items that can be sold. When you open a vendor they are sold one by one and chat tells you how much you made (you can buy them back on the vendor's buyback tab).",
    ["Basura junto al botín: al abrir un botín sin sitio en las bolsas (o cuando el juego avisa de que están llenas) aparece a su derecha tu basura, la más barata primero, con lo que te daría un vendedor. La X destruye ese montón al momento y ya puedes recoger lo que querías."] =
        "Junk next to loot: when you open loot with no room in your bags (or the game says they are full), your junk appears on its right, cheapest first, with what a vendor would pay. The X destroys that stack at once so you can pick up what you wanted.",
    ["Acciones rápidas: con Alt pulsado, el objeto bajo el ratón se marca si puedes desencantarlo, forzar su cerradura, prospectarlo o molerlo; Alt+clic lo hace. Solo fuera de combate."] =
        "Quick actions: while holding Alt, the item under the mouse is highlighted if you can disenchant, pick, prospect or mill it; Alt+click does it. Out of combat only.",
})
