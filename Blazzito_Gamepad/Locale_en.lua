-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- Gamepad.lua (el volcado de /bui mando hud se queda en español)
    ---------------------------------------------------------------------------
    ["piezas del HUD de mando de Blizzard (para darles estilo)"] = "pieces of Blizzard's gamepad HUD (to style them)",

    ---------------------------------------------------------------------------
    -- Chooser.lua (la pregunta al entrar)
    ---------------------------------------------------------------------------
    ["¿Cómo vas a jugar?"] = "How are you going to play?",
    ["ahora"] = "now",
    ["Barras, menús y navegación de Blizzard para jugar con el mando."] = "Blizzard's bars, menus and navigation for playing with a gamepad.",
    ["Teclado y ratón"] = "Keyboard and mouse",
    ["La interfaz de PC de siempre, con todo el estilo de BlazzitoUI."] = "The usual PC interface, with all of BlazzitoUI's style.",
    ["No volver a preguntar"] = "Don't ask again",
    ["Se cierra en %d s sin cambiar nada"] = "Closes in %d s without changing anything",
    ["espera a salir de combate para elegir."] = "wait until you leave combat to choose.",
    ["Hay un mando conectado: %s."] = "A gamepad is connected: %s.",
    ["No se detecta ningún mando conectado."] = "No connected gamepad detected.",
    ["pregunta si quieres la interfaz de mando o la de teclado y ratón"] = "asks whether you want the gamepad or the keyboard and mouse interface",

    ---------------------------------------------------------------------------
    -- Config.lua (página «Mando»)
    ---------------------------------------------------------------------------
    ["Estilo de interfaz: |cffffffff%s|r"] = "Interface style: |cffffffff%s|r",
    ["|cffffb84d(al entrar era %s: escribe /reload)|r"] = "|cffffb84d(it was %s at login: type /reload)|r",
    ["mando"] = "gamepad",
    ["teclado y ratón"] = "keyboard and mouse",
    ["Mando conectado: |cffffffff%s|r"] = "Connected gamepad: |cffffffff%s|r",
    ["ninguno"] = "none",
    ["Estado"] = "Status",
    ["Elegir mando o teclado y ratón"] = "Choose gamepad or keyboard and mouse",
    ["Ver diagnóstico en el chat"] = "Show diagnostics in chat",
    ["El estilo de mando cambia toda la interfaz de Blizzard: sus barras de mando, su barra de lanzamiento, la leyenda de botones y la navegación de las ventanas con la cruceta. Al elegir otro estilo se recarga la interfaz para que BlazzitoUI se adapte."] =
        "The gamepad style changes all of Blizzard's interface: its gamepad bars, its cast bar, the button legend and window navigation with the D-pad. Choosing another style reloads the interface so BlazzitoUI can adapt.",
    ["Al entrar al juego"] = "On login",
    ["Preguntar si hay un mando conectado"] = "Ask if a gamepad is connected",
    ["Con un mando conectado, al entrar te pregunta si quieres la interfaz de mando o la de teclado y ratón. Con el mando: A elige mando, B elige teclado y ratón. Si no respondes, se cierra sola a los 30 segundos sin cambiar nada."] =
        "With a gamepad connected, on login it asks whether you want the gamepad or the keyboard and mouse interface. On the gamepad: A picks gamepad, B picks keyboard and mouse. If you don't answer, it closes by itself after 30 seconds without changing anything.",
    ["Estilo del HUD de mando"] = "Gamepad HUD style",
    ["Botones de las barras de mando"] = "Gamepad bar buttons",
    ["Leyenda de botones"] = "Button legend",
    ["Borde de 1 px en lugar del aro dorado: negro normalmente y del color de tu clase en la barra activa (al mantener LT o RT) o en los botones marcados. La leyenda pasa a un panel oscuro con una línea de tu color arriba. Solo con el estilo de mando; apagarlo se aplica al recargar."] =
        "A 1 px border instead of the golden ring: black normally and in your class color on the active bar (while holding LT or RT) or on checked buttons. The legend becomes a dark panel with a line in your color on top. Gamepad style only; turning it off applies after reload.",
    ["Con el estilo de mando"] = "With the gamepad style",
    ["Estas piezas meten botones o ganchos dentro de ventanas que la cruceta recorre. Si la cruceta pulsa algo nuestro, Blizzard bloquea el mando hasta recargar. Por eso se apartan con el estilo de mando. Enciéndelas solo si juegas con teclado y ratón aunque tengas el estilo de mando puesto. Se aplica al recargar."] =
        "These pieces put buttons or hooks inside windows the D-pad browses. If the D-pad presses something of ours, Blizzard blocks the gamepad until you reload. That's why they step aside with the gamepad style. Turn them on only if you play with keyboard and mouse while the gamepad style is set. Applies after reload.",
    ["Siempre, con el estilo de mando: el marco de objetivo de Blizzard sigue existiendo invisible, porque el botón Y abre su menú. Los marcos de grupo de Blizzard también quedan invisibles, porque la cruceta los recorre al elegir aliados."] =
        "Always, with the gamepad style: Blizzard's target frame still exists, invisible, because the Y button opens its menu. Blizzard's party frames also stay invisible, because the D-pad goes through them when choosing allies.",
})
