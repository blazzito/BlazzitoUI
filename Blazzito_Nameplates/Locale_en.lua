-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Nameplates.lua: placa de ejemplo
    ["Ogro salvaje"] = "Wild Ogre",
    ["Bola de fuego"] = "Fireball",

    -- Config.lua: página Placas de nombre
    ["Reacción (hostil, neutral...) y clase"] = "Reaction (hostile, neutral...) and class",
    ["Aggro en combate (y reacción fuera)"] = "Threat in combat (reaction outside)",
    ["Grosor del borde (0 = sin borde)"] = "Border size (0 = no border)",
    ["Brillo en las barras"] = "Bar shine",
    ["Vida y textos"] = "Health and texts",
    ["Con \"Aggro en combate\", la barra toma el color de tu situación de aggro con ese enemigo (rojo si te ataca a ti)."] =
        "With \"Threat in combat\", the bar takes the color of your threat status with that enemy (red if it's attacking you).",
    ["Resaltar tu objetivo"] = "Highlight your target",
    ["Opacidad del resto (%)"] = "Opacity of the others (%)",
    ["Rango"] = "Range",
    ["Indicador de enemigo a rango"] = "In-range enemy indicator",
    ["Que lata (brillo animado)"] = "Pulse (animated glow)",
    ["Color del indicador"] = "Indicator color",
    ["Se comprueba con hechizos de tu clase. En el cazador, Disparo automático y Golpe de raptor: la zona muerta de 5 a 8 metros cuenta como fuera de rango. Va junto a la insignia de aggro cuando está visible."] =
        "Checked with your class's spells. For hunters, Auto Shot and Raptor Strike: the 5 to 8 yard dead zone counts as out of range. It sits next to the threat badge when that is visible.",
})
