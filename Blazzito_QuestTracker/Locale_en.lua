-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- QuestTracker.lua
    ["estado del rastreador de misiones"] = "quest tracker status",

    -- Config.lua
    ["Misión destacada"] = "Focused quest",
    ["Casilla para destacar cada misión"] = "Checkbox to focus each quest",
    ["Destacar en el mapa también la marca aquí"] = "Focusing on the map also checks it here",
    ["Distancia junto al nombre, p. ej. (125m)"] = "Distance next to the name, e.g. (125m)",
    ["La casilla delante de cada misión de Questie la destaca: se resalta en el mapa y el juego te guía hacia ella. Marcada en azul = destacada; borde verde = misión completada. Con la segunda opción, destacar una misión desde el mapa de Blizzard también la marca en el rastreador. Son opciones de Questie: BlazzitoUI solo las activa."] =
        "The checkbox in front of each Questie quest focuses it: it's highlighted on the map and the game guides you to it. Blue = focused; green border = quest complete. With the second option, focusing a quest from Blizzard's map also checks it in the tracker. These are Questie options: BlazzitoUI just turns them on.",
    ["Tamaño y posición"] = "Size and position",
    ["Ancho (0 = automático)"] = "Width (0 = automatic)",
    ["Alto (0 = automático)"] = "Height (0 = automatic)",
    ["Franja de color en la destacada (azul) y en las completadas (verde)"] = "Color strip on the focused (blue) and completed (green) quests",
    ["Mover el rastreador"] = "Move the tracker",
    ["El tamaño y la posición se guardan en Questie (como si lo hicieras con su tirador), así que Questie los respeta. En el modo mover se arrastra y se cambia de tamaño desde la esquina."] =
        "Size and position are saved in Questie (as if you used its handle), so Questie keeps them. In move mode, drag it and resize it from the corner.",
    ["Otras secciones"] = "Other sections",
    ["Mismo estilo que Questie en las secciones de otros addons"] = "Questie's style on other addons' sections",
    ["Secciones como \"Componentes de profesión\" de SkillUp Forever, que se colocan bajo la lista de Questie, toman su letra, tamaños y sangrías, y pierden la cabecera dorada con línea. Para quitarlo hay que recargar. /bui misiones muestra qué secciones encuentra."] =
        "Sections such as SkillUp Forever's \"Profession components\", placed under Questie's list, take its font, sizes and indents, and lose the gold header with a line. Removing it needs a reload. /bui misiones shows which sections it finds.",
})
