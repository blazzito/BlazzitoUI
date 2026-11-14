-- English. Clave = el texto en español tal cual aparece en el código.
-- Lo que sale en combate va corto.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- Display.lua: zonas, fuentes y mensajes de ejemplo
    ---------------------------------------------------------------------------
    ["Texto entrante"] = "Incoming text",
    ["Texto saliente"] = "Outgoing text",
    ["Avisos"] = "Notifications",
    ["De combate (la del juego)"] = "Combat (the game's)",
    ["De BlazzitoUI"] = "BlazzitoUI's",
    ["Esquiva"] = "Dodge",
    ["+Aspecto del halcón"] = "+Aspect of the Hawk",
    ["¡Fuego a discreción!"] = "Rapid Fire!",

    ---------------------------------------------------------------------------
    -- Sources.lua: textos en combate
    -- (la salida de /bui sct es diagnóstico: en español)
    ---------------------------------------------------------------------------
    ["¡%s!"] = "%s!",
    ["¡Vida baja!"] = "Low health!",
    ["¡Maná bajo!"] = "Low mana!",
    ["Cuerpo a cuerpo"] = "Melee",
    ["Disparo automático"] = "Auto Shot",
    ["Fallo"] = "Miss",
    ["¡Golpe de gracia! %s"] = "Killing blow! %s",
    ["diagnóstico del texto de combate:"] = "combat text diagnostics:",
    ["diagnóstico del texto de combate"] = "combat text diagnostics",
    ["ráfaga de prueba del texto de combate"] = "test burst of combat text",

    ---------------------------------------------------------------------------
    -- Flair.lua: críticos, resumen, golpe de gracia, exceso
    ---------------------------------------------------------------------------
    ["¡Crítico ×%d!"] = "Crit ×%d!",
    ["¡Crítico!"] = "Crit!",
    ["Combate: %s de daño · %s por segundo"] = "Fight: %s damage · %s per second",
    ["Mayor golpe: %s"] = "Biggest hit: %s",
    ["Combate: %d golpe en %d s"] = "Fight: %d hit in %d s",
    ["Combate: %d golpes en %d s"] = "Fight: %d hits in %d s",
    ["+%s de exceso"] = "+%s overkill",

    -- Cooldowns.lua
    ["Listo: %s"] = "Ready: %s",

    ---------------------------------------------------------------------------
    -- Config.lua: página Texto de combate
    ---------------------------------------------------------------------------
    ["Contorno"] = "Outline",
    ["Contorno grueso"] = "Thick outline",
    ["Sin contorno"] = "No outline",
    ["Arco (parábola)"] = "Arc (parabola)",
    ["Recto"] = "Straight",
    ["En ángulo"] = "Angled",
    ["Estático"] = "Static",
    ["Hacia abajo"] = "Downward",
    ["Hacia arriba"] = "Upward",
    ["Hacia la izquierda"] = "To the left",
    ["Hacia la derecha"] = "To the right",
    ["Lo que recibes"] = "What you take",
    ["Daño recibido"] = "Damage taken",
    ["Curas recibidas"] = "Heals received",
    ["Esquivas, paradas, bloqueos, fallos"] = "Dodges, parries, blocks, misses",
    ["Recursos ganados (maná, ira...)"] = "Resources gained (mana, rage...)",
    ["Lo que haces"] = "What you do",
    ["Tu daño"] = "Your damage",
    ["Tus curas a otros"] = "Your heals on others",
    ["Tus fallos (esquiva, parada...)"] = "Your misses (dodge, parry...)",
    ["Daño de tu mascota"] = "Your pet's damage",
    ["Entrar / salir de combate"] = "Entering / leaving combat",
    ["Enfriamientos listos"] = "Cooldowns ready",
    ["Beneficios ganados / perdidos"] = "Buffs gained / lost",
    ["Perjuicios recibidos / quitados"] = "Debuffs gained / removed",
    ["Procs (habilidades activadas)"] = "Procs (activated abilities)",
    ["Vida o maná bajos"] = "Low health or mana",
    ["Golpes de gracia"] = "Killing blows",
    ["Reputación"] = "Reputation",
    ["Honor"] = "Honor",
    ["Botín"] = "Loot",
    ["Dinero"] = "Money",
    ["Fuente"] = "Font",
    ["Crítico"] = "Critical",
    ["Las cuatro primeras van incluidas (gruesas y muy legibles; licencias libres). Recomendadas: Russo One (deportiva, la más llamativa) y Changa (redonda y muy negra). Detrás salen las que comparten otros addons que tengas instalados. Al elegir una salen golpes de ejemplo en pantalla."] =
        "The first four are included (bold and very readable; free licenses). Recommended: Russo One (sporty, the most striking) and Changa (round and very heavy). After them come the ones shared by other addons you have installed. Picking one shows sample hits on screen.",
    ["Más llamativo"] = "More striking",
    ["Los golpes grandes salen más grandes"] = "Big hits show bigger",
    ["Estallido detrás de los críticos"] = "Burst behind crits",
    ["Temblor al aparecer un crítico"] = "Shake when a crit appears",
    ["\"¡Crítico!\" encima del número"] = "\"Crit!\" above the number",
    ["Rachas de críticos (¡Crítico ×3!)"] = "Crit streaks (Crit ×3!)",
    ["Resumen al salir de combate"] = "Summary when leaving combat",
    ["Golpe de gracia con calavera"] = "Killing blow with a skull",
    ["Daño en el tiempo: tics pequeños y el total al acabar"] = "Damage over time: small ticks, total at the end",
    ["Exceso de daño al matar"] = "Overkill damage",
    ["Ocultar tus golpes menores que (0 = todos)"] = "Hide your hits below (0 = show all)",
    ["Ocultarlos solo en grupo o banda"] = "Hide them only in party or raid",
    ["El tamaño se compara con la media de tus últimos golpes: el normal sale igual y uno cuatro veces mayor, un 60 % más grande. El resumen sale en los avisos al acabar cada combate: daño total, daño por segundo y tu mayor golpe con su hechizo. El daño en el tiempo agrupado y el exceso de daño necesitan el registro de combate (/bui sct dice si llega); con el respaldo no se sabe qué tic es de qué."] =
        "Size is compared to the average of your recent hits: a normal one stays the same and one four times bigger shows 60 % larger. The summary appears in the notifications after each fight: total damage, damage per second and your biggest hit with its spell. Grouped damage over time and overkill need the combat log (/bui sct tells you if it arrives); with the fallback there's no telling which tick belongs to what.",
    ["Probar en pantalla"] = "Test on screen",
    ["Abreviar números (12,3 mil)"] = "Abbreviate numbers (12.3k)",
    ["Iconos de los hechizos"] = "Spell icons",
    ["Espada, flecha y huella en los ataques básicos"] = "Sword, arrow and paw on basic attacks",
    ["Colores por escuela de magia"] = "Colors by magic school",
    ["Ocultar el texto de Blizzard sobre ti"] = "Hide Blizzard's text over you",
    ["Mover zonas"] = "Move zones",
    ["Ráfaga de prueba"] = "Test burst",
    ["Los números que pone Blizzard sobre los enemigos se quitan en Opciones > Combate > Texto de combate flotante. Escribe /bui sct para ver qué fuentes de datos funcionan en tu cliente."] =
        "Blizzard's numbers over enemies are turned off in Options > Combat > Floating Combat Text. Type /bui sct to see which data sources work in your client.",
    ["Agrupar golpes"] = "Merge hits",
    ["Agrupar lo que haces"] = "Merge what you do",
    ["Agrupar lo que recibes"] = "Merge what you take",
    ["Ventana para agrupar (s)"] = "Merge window (s)",
    ["Los golpes seguidos del mismo hechizo (o del cuerpo a cuerpo, o de tu mascota) dentro de la ventana salen como uno solo: \"4.312 ×3\". Si alguno fue crítico, el total sale como crítico. Los números secretos (contenido restringido) no se pueden sumar y salen uno a uno."] =
        "Consecutive hits from the same spell (or melee, or your pet) within the window show as one: \"4,312 ×3\". If any was a crit, the total shows as a crit. Secret numbers (restricted content) can't be added up and show one by one.",
    ["Avisos de enfriamiento"] = "Cooldown alerts",
    ["Avisar cuando un hechizo esté listo"] = "Alert when a spell is ready",
    ["Solo enfriamientos de al menos (s)"] = "Only cooldowns of at least (s)",
    ["Sale \"Listo: <hechizo>\" con su icono en la zona de avisos."] = "Shows \"Ready: <spell>\" with its icon in the notifications zone.",
    ["Activar esta zona"] = "Enable this zone",
    ["Animación"] = "Animation",
    ["Dirección"] = "Direction",
    ["Curva"] = "Curve",
    ["Recorrido (alto)"] = "Travel (height)",
    ["Curvatura (ancho)"] = "Curvature (width)",
    ["Duración (s)"] = "Duration (s)",
    ["Críticos con golpe en el centro"] = "Crits pop in the center",
    ["Tamaño de los críticos (x)"] = "Crit size (x)",
    ["Mostrar: %s"] = "Show: %s",
})
