-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ["Menú radial"] = "Radial menu",
    ["Menú radial (mantener y soltar)"] = "Radial menu (hold and release)",
    ["Gestos"] = "Emotes",
    ["Monturas"] = "Mounts",
    ["Esc o la tecla para cerrar"] = "Esc or the key to close",
    ["Pulsa aquí para volver"] = "Click here to go back",

    -- Botones
    ["Menú del juego"] = "Game menu",
    ["Personaje"] = "Character",
    ["Libro de hechizos"] = "Spellbook",
    ["Talentos"] = "Talents",
    ["Profesiones"] = "Professions",
    ["Registro de misiones"] = "Quest log",
    ["Bolsas"] = "Bags",
    ["Mapa del mundo"] = "World map",
    ["Colección de monturas"] = "Mount collection",

    -- Gestos
    ["Bailar"] = "Dance",
    ["Sentarse"] = "Sit",
    ["Saludar"] = "Wave",
    ["Reverencia"] = "Bow",
    ["Reír"] = "Laugh",
    ["Animar"] = "Cheer",
    ["Aplaudir"] = "Applaud",
    ["Rugir"] = "Roar",
    ["De rodillas"] = "Kneel",
    ["Dormir"] = "Sleep",
    ["Gracias"] = "Thank",
    ["Hola"] = "Hello",
    ["Músculo"] = "Flex",
    ["Llorar"] = "Cry",
    ["Beso"] = "Kiss",
    ["Gallina"] = "Chicken",
    ["Firmes"] = "Salute",
    ["Señalar"] = "Point",

    -- Avisos
    ["las teclas se asignan fuera de combate."] = "keys can only be assigned out of combat.",
    ["las macros se crean y se cogen fuera de combate."] = "macros are created and picked up out of combat.",
    ["no se pudo crear la macro (¿no te quedan huecos de macros generales?)."] =
        "the macro could not be created (are your general macro slots full?).",

    -- Página de opciones
    ["Cómo se abre"] = "How it opens",
    ["Probar"] = "Try it",
    ["Tecla"] = "Key",
    ["sin asignar"] = "not set",
    ["Pulsa una tecla... (Esc cancela)"] = "Press a key... (Esc cancels)",
    ["Asignar tecla"] = "Set key",
    ["Quitar la tecla"] = "Clear the key",
    ["Coger para arrastrar a una barra"] = "Pick up to drag onto a bar",
    ["Mantén la tecla, lleva el ratón a un botón y suelta: se usa ese. Con un toque corto el anillo se queda abierto para elegir con el ratón; se cierra con la misma tecla, con Esc, pulsando el centro o pulsando fuera del anillo. Funciona también en combate."] =
        "Hold the key, move the mouse onto a button and release: that one is used. With a short tap the ring stays open so you can pick with the mouse; it closes with the same key, with Esc, by clicking the center or by clicking outside the ring. It also works in combat.",
    ["En la barra se pone la macro «BUI Radial»: al pulsarla el anillo se abre y eliges con el ratón. La tecla también se puede cambiar en Opciones > Atajos > AddOns > BlazzitoUI."] =
        "On the bar it goes as the «BUI Radial» macro: pressing it opens the ring and you pick with the mouse. The key can also be changed in Options > Keybindings > AddOns > BlazzitoUI.",
    ["Qué sale en el anillo"] = "What the ring shows",
    ["(no existe en este cliente)"] = "(not in this client)",
    ["Van en el sentido de las agujas del reloj empezando arriba. Monturas y Gestos abren un segundo anillo: el centro vuelve atrás."] =
        "They go clockwise starting at the top. Mounts and Emotes open a second ring: the center goes back.",
    ["Si tienes a alguien seleccionado, el gesto va dirigido a él."] = "If you have someone targeted, the emote is aimed at them.",
    ["Monturas en el anillo"] = "Mounts in the ring",
    ["Primero tus favoritas del diario de monturas y luego las demás por nombre. El primer botón abre la colección."] =
        "Your favorites from the mount journal first, then the rest by name. The first button opens the collection.",
    ["Aspecto"] = "Look",
    ["Tamaño (%)"] = "Size (%)",
    ["Separación del centro"] = "Distance from the center",
    ["Tamaño de los iconos"] = "Icon size",
    ["Opacidad del fondo (%)"] = "Background opacity (%)",
    ["Nombres bajo los iconos"] = "Names under the icons",
    ["Mover el anillo"] = "Move the ring",
    ["Vista previa: pasa el ratón por los botones"] = "Preview: hover the buttons",
    ["Atenuar los demás al elegir uno"] = "Dim the others while picking one",
    ["Icono del elegido en el centro"] = "Picked icon in the center",
    ["Anillo"] = "Ring",
    ["Órbita (línea por donde van los botones)"] = "Orbit (line the buttons sit on)",
    ["Indicador de dirección"] = "Direction indicator",
    ["Color del acento"] = "Accent color",
    ["El de tu clase"] = "Your class color",
    ["Personalizado"] = "Custom",
    ["El acento colorea el borde del botón elegido y el indicador de dirección: un arco en el borde del anillo que señala hacia dónde vas."] =
        "The accent colors the picked button's border and the direction indicator: an arc on the ring's edge pointing where you are going.",
})
