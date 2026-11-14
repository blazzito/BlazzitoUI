-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- Auras.lua: auras de ejemplo (vista previa) y avisos
    -- (la salida de /bui auras y /bui auras motor es diagnóstico: en español)
    ---------------------------------------------------------------------------
    ["Palabra de poder: entereza"] = "Power Word: Fortitude",
    ["Marca de lo salvaje"] = "Mark of the Wild",
    ["Bendición de poderío"] = "Blessing of Might",
    ["Escudo de relámpagos"] = "Lightning Shield",
    ["Palabra de las Sombras: dolor"] = "Shadow Word: Pain",
    ["Veneno mortal"] = "Deadly Poison",
    ["Maldición de agonía"] = "Curse of Agony",
    ["|cffff6666auras: %s|r (más datos con /bui auras)"] = "|cffff6666auras: %s|r (more details with /bui auras)",
    ["auras: el módulo de marcos de unidad está desactivado; las auras van sobre esos marcos."] =
        "auras: the unit frames module is disabled; auras are shown on those frames.",
    ["diagnóstico del módulo de auras"] = "auras module diagnostics",
    ["prueba el motor de auras en el centro de la pantalla"] = "tests the aura engine in the middle of the screen",

    ---------------------------------------------------------------------------
    -- Config.lua: página Auras
    ---------------------------------------------------------------------------
    ["Iconos (con cargas y tiempo)"] = "Icons (with stacks and time)",
    ["Barras (icono, nombre y tiempo)"] = "Bars (icon, name and time)",
    ["Encima del marco"] = "Above the frame",
    ["Debajo del marco"] = "Below the frame",
    ["Rombo"] = "Diamond",
    ["Estrella"] = "Star",
    ["Brillo alrededor"] = "Glow around",
    ["Ninguna"] = "None",
    ["Mostrar auras en este marco"] = "Show auras on this frame",
    ["Intercambiar mitades"] = "Swap halves",
    ["Cómo se ven"] = "Display as",
    ["El ancho del marco se parte en dos: beneficios en una mitad y perjuicios en la otra (por defecto, beneficios a la izquierda). Cada mitad crece desde su borde exterior."] =
        "The frame's width is split in two: buffs in one half and debuffs in the other (buffs on the left by default). Each half grows from its outer edge.",
    ["Tamaño de los iconos"] = "Icon size",
    ["Alto de las barras"] = "Bar height",
    ["Máximo por mitad"] = "Max per half",
    ["Espaciado"] = "Spacing",
    ["Filtros"] = "Filters",
    ["Solo mis beneficios"] = "Only my buffs",
    ["Solo mis perjuicios"] = "Only my debuffs",
    ["\"Solo mis perjuicios\" en el Objetivo deja ver solo lo que tú le has puesto (útil para DoTs)."] =
        "\"Only my debuffs\" on the Target shows only what you applied (useful for DoTs).",
    ["Disipables"] = "Dispellable",
    ["Marca en lo que puedes disipar"] = "Mark on what you can dispel",
    ["Color de la marca"] = "Mark color",
    ["Borde del color del tipo (magia, maldición...)"] = "Border in the type's color (magic, curse...)",
    ["Los perjuicios que tu clase puede quitar van primero y llevan la marca."] = "Debuffs your class can remove come first and carry the mark.",
    ["Mostrar tiempo restante (modo barras)"] = "Show time left (bars mode)",
    ["Mostrar cargas"] = "Show stacks",
    ["En modo iconos el tiempo lo muestra el contador dentro del icono (OmniCC o el de Blizzard)."] =
        "In icons mode the time is shown by the counter inside the icon (OmniCC or Blizzard's).",
    ["Beneficios junto al minimapa"] = "Buffs next to the minimap",
    ["Estilo de BlazzitoUI"] = "BlazzitoUI style",
    ["Forma de los iconos"] = "Icon shape",
    ["Grosor del borde"] = "Border size",
    ["Tamaño de la letra"] = "Font size",
    ["Son los beneficios y perjuicios de Blizzard de arriba a la derecha (y la flechita que los pliega): siguen funcionando igual, solo cambia su aspecto. Los perjuicios mantienen el color de su tipo en el borde. En combate no se pueden tocar: lo nuevo se viste al salir."] =
        "These are Blizzard's buffs and debuffs at the top right (and the small arrow that collapses them): they work the same, only their look changes. Debuffs keep their type's color on the border. They can't be touched in combat: new ones get styled when combat ends.",
    ["Avanzado"] = "Advanced",
    ["Respaldo con iconos del motor (experimental)"] = "Fallback with engine icons (experimental)",
    ["Las auras \"secretas\" (enemigos en combate) siempre las pinta el motor del juego: es la única forma de verlas. Esta opción solo añade el motor cuando la lectura falla por otro motivo."] =
        "\"Secret\" auras (enemies in combat) are always drawn by the game engine: it's the only way to see them. This option only adds the engine when reading fails for some other reason.",
})
