-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- ActionBars.lua: nombres de las barras (pestañas, marcos móviles, brillo)
    ---------------------------------------------------------------------------
    ["Barra 1 (principal)"] = "Bar 1 (main)",
    ["Barra 2"] = "Bar 2",
    ["Barra 3"] = "Bar 3",
    ["Barra 4 (derecha)"] = "Bar 4 (right)",
    ["Barra 5 (derecha 2)"] = "Bar 5 (right 2)",
    ["Barra 6"] = "Bar 6",
    ["Barra 7"] = "Bar 7",
    ["Barra 8"] = "Bar 8",
    ["Posturas y formas"] = "Stances and forms",
    ["Posturas"] = "Stances",
    ["Menú (microbotones)"] = "Menu (micro buttons)",
    ["Menú"] = "Menu",
    ["Experiencia y reputación"] = "Experience and reputation",
    ["Experiencia"] = "Experience",
    ["Golpe: mano derecha"] = "Swing: main hand",
    ["Mano der."] = "Main hand",
    ["Golpe: mano izquierda"] = "Swing: off hand",
    ["Mano izq."] = "Off hand",
    ["Golpe: a distancia"] = "Swing: ranged",
    ["Distancia"] = "Ranged",
    ["no se pueden activar ni quitar barras en combate."] = "bars can't be turned on or off in combat.",

    -- Visibilidad
    ["Siempre"] = "Always",
    ["Ocultar en combate"] = "Hide in combat",
    ["Solo en combate"] = "Only in combat",
    ["Al pasar el ratón"] = "On mouseover",
    ["En combate o al pasar el ratón"] = "In combat or on mouseover",

    ---------------------------------------------------------------------------
    -- Swing.lua (la salida de /bui swing es diagnóstico: en español)
    ---------------------------------------------------------------------------
    ["temporizador de golpe:"] = "swing timer:",
    ["estado de los temporizadores de golpe"] = "status of the swing timers",

    ---------------------------------------------------------------------------
    -- Config.lua: página Barras de acción
    ---------------------------------------------------------------------------
    ["todas las barras del mismo tipo"] = "all bars of the same type",
    ["General"] = "General",
    ["Ocultar el arte de la barra 1 (grifos y marco)"] = "Hide bar 1's art (gryphons and frame)",
    ["Mostrar todas mientras configuras"] = "Show all while configuring",
    ["Mostrarlas al arrastrar un hechizo u objeto"] = "Show them while dragging a spell or item",
    ["Duración del fundido (s)"] = "Fade duration (s)",
    ["Las barras siguen siendo las de WoW: su posición y tamaño se cambian en el Modo edición de Blizzard (Esc > Modo edición). Aquí cambian su aspecto y cuándo se ven. La barra de la pestaña elegida brilla en pantalla."] =
        "The bars are still WoW's own: their position and size are changed in Blizzard's Edit Mode (Esc > Edit Mode). Here you change their look and when they show. The bar of the selected tab glows on screen.",
    ["Barra"] = "Bar",
    ["Barra activada"] = "Bar enabled",
    ["Quitar el fondo de Blizzard"] = "Remove Blizzard's background",
    ["Barras 2 a 8: es la misma casilla que Opciones > Barras de acción de Blizzard (fuera de combate). La barra 1, mascota, posturas, bolsas, menú y experiencia no se pueden quitar en WoW: al desactivarlas se vuelven invisibles."] =
        "Bars 2 to 8: it's the same checkbox as Blizzard's Options > Action Bars (out of combat). Bar 1, pet, stances, bags, menu and experience can't be removed in WoW: disabling them makes them invisible.",
    ["Aplicar el estilo de BlazzitoUI"] = "Apply the BlazzitoUI style",
    ["Grosor del borde (0 = sin borde)"] = "Border size (0 = no border)",
    ["Color del borde"] = "Border color",
    ["Opacidad del fondo (%)"] = "Background opacity (%)",
    ["Voltear solo cambia las formas que no son simétricas (inclinada y ala). Desactivar el estilo devuelve la barra a como la pinta Blizzard."] =
        "Flipping only affects shapes that aren't symmetrical (slanted and wing). Turning the style off returns the bar to how Blizzard draws it.",
    ["Visibilidad"] = "Visibility",
    ["Cuándo se ve"] = "When it shows",
    ["Opacidad cuando está oculta (%)"] = "Opacity when hidden (%)",
    ["Oculta = transparente: la barra sigue en su sitio y sus atajos de teclado funcionan. En el Modo edición se ven todas."] =
        "Hidden = transparent: the bar stays in place and its keybinds still work. In Edit Mode they all show.",
    ["Botones"] = "Buttons",
    ["Mostrar la tecla asignada"] = "Show the keybind",
    ["Mostrar el nombre de la macro"] = "Show the macro name",
    ["Mostrar cargas y cantidades"] = "Show charges and counts",
    ["Brillo al pasar el ratón"] = "Glow on mouseover",
    ["Temporizador de golpe"] = "Swing timer",
    ["Color de la barra"] = "Bar color",
    ["Tiempo restante"] = "Time left",
    ["Nombre de la mano (Derecha / Izquierda / Distancia)"] = "Hand name (Right / Left / Ranged)",
    ["Ocultar fuera de combate"] = "Hide out of combat",
    ["Apagarse fuera de rango"] = "Dim when out of range",
    ["Ocultar el temporizador de Blizzard"] = "Hide Blizzard's swing timer",
    ["Los datos son los del temporizador de golpe del juego (WoW Forever): cada golpe de tu mano derecha, izquierda o ataque a distancia (disparo automático, varita) reinicia su barra. La mano izquierda solo aparece con dos armas y la de distancia con arco, fusil, arma arrojadiza o varita. Se colocan con el modo mover (arriba a la derecha) y /bui swing muestra su estado."] =
        "The data comes from the game's swing timer (WoW Forever): each swing of your main hand, off hand or ranged attack (Auto Shot, wand) restarts its bar. The off hand only shows with two weapons, and ranged with a bow, gun, thrown weapon or wand. Place them with move mode (top right) and /bui swing shows their status.",
    ["Fijar la página de la barra 1 (sin Mayús + rueda)"] = "Lock bar 1's page (no Shift + mouse wheel)",
    ["Con la página fijada, Mayús + rueda del ratón (y las teclas de página siguiente y anterior) ya no cambian la barra 1 a las páginas 2, 3, 4... Tus atajos no se tocan: al quitarla vuelven a funcionar como antes."] =
        "With the page locked, Shift + mouse wheel (and the next and previous page keys) no longer switch bar 1 to pages 2, 3, 4... Your keybindings are not changed: turn it off and they work as before.",
})
