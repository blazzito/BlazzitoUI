-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Plate.lua: placa y vista previa
    ["Ogro salvaje"] = "Wild Ogre",
    ["Bola de fuego"] = "Fireball",
    ["Tú"] = "You",
    ["Interrumpido"] = "Interrupted",

    -- Driver.lua
    ["Diagnóstico de las placas de nombre"] = "Nameplate diagnostics",

    -- Config.lua: página Placas de nombre
    ["Reacción (hostil, neutral...) y clase"] = "Reaction (hostile, neutral...) and class",
    ["Aggro en combate (y reacción fuera)"] = "Threat in combat (reaction outside)",
    ["Vida"] = "Health",
    ["Vida y porcentaje"] = "Health and percent",
    ["Tu objetivo"] = "Your target",
    ["Aliado"] = "Friendly",
    ["Guardia de la ciudad"] = "City Guard",
    ["Escala"] = "Scale",
    ["Subir o bajar"] = "Move up or down",
    ["Las placas tienen siempre el mismo tamaño, cerca o lejos: así el borde de 1 píxel se ve nítido."] =
        "Nameplates always keep the same size, near or far, so the 1-pixel border stays crisp.",
    ["Grosor del borde (0 = sin borde)"] = "Border size (0 = no border)",
    ["Brillo en las barras"] = "Bar shine",
    ["Las formas mantienen su ángulo con cualquier ancho: los extremos no se estiran."] =
        "Shapes keep their angle at any width: the ends are never stretched.",
    ["Vida y textos"] = "Health and texts",
    ["Mostrar nivel (+ élite, ?? jefe, rombo si es raro)"] = "Show level (+ elite, ?? boss, diamond if rare)",
    ["Objetivo y alcance"] = "Target and range",
    ["Resaltar tu objetivo"] = "Highlight your target",
    ["Opacidad del resto (%)"] = "Opacity of the others (%)",
    ["Atenuar los enemigos fuera de alcance"] = "Fade enemies out of range",
    ["Opacidad fuera de alcance (%)"] = "Out-of-range opacity (%)",
    ["El alcance se comprueba con hechizos de tu clase. En el cazador, Disparo automático y Golpe de raptor: la zona muerta de 5 a 8 metros cuenta como fuera de alcance."] =
        "Range is checked with your class's spells. For hunters, Auto Shot and Raptor Strike: the 5 to 8 yard dead zone counts as out of range.",
    ["Aggro"] = "Threat",
    ["Mostrar tu % de aggro a la derecha"] = "Show your threat % on the right",
    ["Teñir el borde con el color del aggro"] = "Tint the border with the threat color",
    ["Con esto activado, la insignia del módulo «Aggro en placas» no se dibuja sobre estas placas (sería lo mismo dos veces)."] =
        "With this on, the «Threat on nameplates» badge is not drawn on these nameplates (it would show the same thing twice).",
    ["Mostrar a quién va dirigido"] = "Show who it's aimed at",
    ["Borde rojo si te lo lanzan a ti"] = "Red border if it's cast at you",
    ["Un escudo sobre el icono indica que no se puede interrumpir (barra gris). Si lo interrumpen, la barra se queda un momento en rojo."] =
        "A shield over the icon means it can't be interrupted (gray bar). When it's interrupted, the bar stays red for a moment.",
    ["Tus debuffs"] = "Your debuffs",
    ["Mostrar tus debuffs sobre la placa"] = "Show your debuffs above the nameplate",
    ["Máximo de iconos"] = "Maximum icons",
    ["Marcas"] = "Markers",
    ["Marcar los enemigos de tus misiones"] = "Mark enemies from your quests",
    ["Marcar a quién ataca tu mascota"] = "Mark what your pet is attacking",
    ["Misión: un «!» amarillo a la izquierda del nombre. Los enemigos que hay que matar se reconocen por tu registro de misiones; los que sueltan objetos de misión se aprenden la primera vez que saqueas uno de esos objetos (se recuerda para toda la cuenta). La bolsita junto a la placa es de Questie (se quita en sus opciones, pestaña de placas). Mascota: una huella a la derecha del nombre."] =
        "Quest: a yellow «!» left of the name. Enemies you must kill are recognized from your quest log; those that drop quest items are learned the first time you loot one of those items (remembered account-wide). The little bag next to the nameplate is Questie's (turn it off in its options, nameplates tab). Pet: a paw print right of the name.",
    ["Umbral de remate (%) · 0 = no"] = "Execute threshold (%) · 0 = off",
    ["Por debajo del umbral la barra cambia al color de remate, aunque la vida llegue secreta en combate."] =
        "Below the threshold the bar switches to the execute color, even when health is secret in combat.",
    ["Área de clic del tamaño de la placa"] = "Click area the size of the nameplate",
    ["Para seleccionar un enemigo vale con hacer clic en su barra o en su nombre. Se aplica fuera de combate; el juego usa la misma medida para todas las placas."] =
        "Click an enemy's bar or name to target it. Applied out of combat; the game uses the same size for every nameplate.",
    ["Aliados"] = "Friendlies",
    ["Placas aliadas: solo el nombre"] = "Friendly nameplates: name only",
    ["Aliados y neutrales que no se pueden atacar: solo su nombre, del color de su clase (jugadores) o de su reacción. Se ven si tienes activadas las placas aliadas del juego. En mazmorras y bandas el juego no deja tocarlas."] =
        "Friendly and neutral units you can't attack: just their name, in their class color (players) or reaction color. They show if the game's friendly nameplates are on. In dungeons and raids the game doesn't let addons touch them.",
    ["Diseño de la insignia"] = "Badge design",
    ["Forma de la insignia"] = "Badge shape",
    ["Tamaño de letra de la insignia"] = "Badge font size",
    ["La misma insignia en las placas de Blizzard"] = "Same badge on Blizzard nameplates",
    ["Horizontal de la insignia"] = "Badge horizontal",
    ["Vertical de la insignia"] = "Badge vertical",
    ["La insignia va en el centro de la barra; Horizontal y Vertical la mueven desde ahí (se ve en tu objetivo, arriba). Lo mismo en las placas de Blizzard, las que no son de BlazzitoUI (si apagas estas placas, o donde el juego no deja tocarlas). Sobre estas placas nunca se repite."] =
        "The badge sits in the center of the bar; Horizontal and Vertical move it from there (see your target, above). The same on Blizzard nameplates, the ones that aren't BlazzitoUI's (if you turn these off, or where the game doesn't let addons touch them). It never repeats on these nameplates.",
})
