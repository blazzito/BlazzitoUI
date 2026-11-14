-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Avisos en el chat
    ["ajustes del juego: "] = "game settings: ",
    ["no encontré el diseño de Edit Mode '%s' (puede ser un diseño solo del main)."] = "couldn't find the Edit Mode layout '%s' (it may only exist on your main).",
    ["no pude cambiar el addon '%s'; usa la lista de addons del juego."] = "couldn't change the addon '%s'; use the game's addon list.",
    ["addons desactivados como en el main: %s"] = "addons disabled to match your main: %s",
    ["addons activados como en el main: %s"] = "addons enabled to match your main: %s",
    ["ajustes de %s aplicados."] = "%s's settings applied.",
    ["Edit Mode no terminó de cargar; lo reintentaré al volver a entrar (o pulsa «Aplicar ahora» en Perfiles)."] =
        "Edit Mode didn't finish loading; I'll try again next time you log in (or press \"Apply now\" in Profiles).",
    ["no hay ajustes guardados del main. Entra una vez con tu main (o usa «Usar este personaje como main» en él)."] =
        "no saved settings from your main. Log in once with your main (or use \"Use this character as main\" on it).",
    ["este personaje ya es el main, no hay nada que copiar."] = "this character is already the main, nothing to copy.",
    ["estás en combate; los aplicaré al salir."] = "you're in combat; I'll apply them when it ends.",
    ["%s es ahora tu main. Sus ajustes se copiarán a los demás personajes."] = "%s is now your main. Its settings will be copied to your other characters.",
    ["modo automático: el main será tu personaje de nivel más alto (ahora: %s)."] = "automatic mode: your main will be your highest-level character (now: %s).",
    ["modo automático: el main será tu personaje de nivel más alto."] = "automatic mode: your main will be your highest-level character.",
    ["traje tus personajes y tu main de Blazz_Setup."] = "imported your characters and your main from Blazz_Setup.",
    ["Blazz_Setup ahora es parte de BlazzitoUI (página Perfiles). Traje sus datos y lo desactivé; recarga para terminar."] =
        "Blazz_Setup is now part of BlazzitoUI (Profiles page). I imported its data and disabled it; reload to finish.",
    ["ajustes de este personaje guardados."] = "this character's settings saved.",

    -- Ventana de recarga
    ["BlazzitoUI: se aplicaron los ajustes del juego de %s.\n\n¿Recargar la interfaz para que todo se vea bien?"] =
        "BlazzitoUI: %s's game settings were applied.\n\nReload the interface so everything looks right?",

    -- Tarjeta en Perfiles
    ["[actual]"] = "[current]",
    ["(sin ajustes guardados)"] = "(no saved settings)",
    ["(ninguno todavía)"] = "(none yet)",
    ["(automático: el de nivel más alto)"] = "(automatic: the highest level)",
    ["(fijado a mano)"] = "(set by hand)",
    ["ninguno todavía"] = "none yet",
    ["Ajustes del juego (de tu main)"] = "Game settings (from your main)",
    ["Copia de tu main a tus otros personajes las opciones del juego que no son de BlazzitoUI: barras de acción activas, mouseover y otras opciones de interfaz, el diseño de Edit Mode y los addons activos. No copia atajos de teclado ni macros."] =
        "Copies the game options that aren't part of BlazzitoUI from your main to your other characters: enabled action bars, mouseover and other interface options, the Edit Mode layout and enabled addons. Keybindings and macros are not copied.",
    ["Usar este personaje como main"] = "Use this character as main",
    ["Automático (nivel más alto)"] = "Automatic (highest level)",
    ["Aplicar al entrar con otro personaje"] = "Apply when logging in on another character",
    ["Barras de acción activas"] = "Enabled action bars",
    ["Mouseover y opciones de interfaz"] = "Mouseover and interface options",
    ["Diseño de Edit Mode"] = "Edit Mode layout",
    ["Addons activos"] = "Enabled addons",
    ["Aplicar ahora los del main"] = "Apply your main's now",
    ["Guardar los de este personaje"] = "Save this character's",
    ["Los ajustes de cada personaje se guardan solos al salir o recargar. Los addons se vuelven a sincronizar cuando el main cambia su lista."] =
        "Each character's settings are saved automatically when you log out or reload. Addons are synced again when your main changes its list.",
})
