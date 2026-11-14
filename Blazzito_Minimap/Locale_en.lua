-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Minimap.lua
    ["O"] = "W",   -- letra del oeste en la brújula
    ["Calendario"] = "Calendar",
    ["Calendario (%d invitaciones)"] = "Calendar (pending invites: %d)",
    ["Botones de addons (%d)"] = "Addon buttons (%d)",
    ["lista lo que hay alrededor del minimapa"] = "lists what is around the minimap",

    -- Config.lua
    ["Tamaño y forma"] = "Size and shape",
    ["Grosor del borde (0 = sin borde)"] = "Border size (0 = no border)",
    ["Color del borde"] = "Border color",
    ["Zoom con la rueda del ratón"] = "Zoom with the mouse wheel",
    ["Mover el minimapa"] = "Move the minimap",
    ["Se mueve y se cambia de tamaño también con el modo mover (arriba a la derecha de esta ventana): arrastra la esquina para hacerlo más grande."] =
        "You can also move and resize it with move mode (top right of this window): drag the corner to make it bigger.",
    ["Puntos cardinales"] = "Compass points",
    ["Mostrar N, S, E y O"] = "Show N, S, E and W",
    ["Tamaño de las letras"] = "Letter size",
    ["Opacidad (%)"] = "Opacity (%)",
    ["El norte va en el color de BlazzitoUI. Si en las opciones de Blizzard tienes el minimapa girando, no se muestran (dejarían de señalar bien)."] =
        "North uses the BlazzitoUI color. If the minimap rotates in Blizzard's options, they are hidden (they would point the wrong way).",
    ["Información"] = "Info",
    ["Zona (en la barra de abajo)"] = "Zone (in the bottom bar)",
    ["Coordenadas"] = "Coordinates",
    ["Hora"] = "Clock",
    ["Formato de 24 horas"] = "24-hour format",
    ["Hora de tu ordenador (si no, la del reino)"] = "Your computer's time (otherwise the realm's)",
    ["Botón de calendario"] = "Calendar button",
    ["Tamaño de la letra"] = "Font size",
    ["Pulsa la zona para abrir el mapa del mundo y la hora para el reloj de Blizzard (alarmas, cronómetro). El calendario lleva un punto cuando tienes invitaciones."] =
        "Click the zone to open the world map and the clock for Blizzard's clock (alarms, stopwatch). The calendar shows a dot when you have invites.",
    ["Huella en la posición de tu mascota"] = "Paw print at your pet's position",
    ["Tamaño de la huella"] = "Paw print size",
    ["Color según su felicidad (verde, amarillo, rojo)"] = "Color by happiness (green, yellow, red)",
    ["Una huella grande y con borde en lugar del puntito del juego. Si la mascota se aleja más allá del borde del minimapa, la huella se queda en el borde señalando hacia dónde está. Gris si está muerta. /bui minimapa dice si el juego da su posición."] =
        "A big outlined paw print instead of the game's tiny dot. If your pet goes past the edge of the minimap, the print stays on the edge pointing toward it. Grey if it's dead. /bui minimapa tells you whether the game gives its position.",
    ["Botones de los addons"] = "Addon buttons",
    ["Recogerlos en un solo botón (recarga para soltarlos)"] = "Gather them in one button (reload to release them)",
    ["Botones por fila"] = "Buttons per row",
    ["Mostrar también el compartimento de addons de Blizzard"] = "Also show Blizzard's addon compartment",
    ["Los iconos que los addons ponen alrededor del minimapa quedan dentro del botón de la rejilla (bajo el calendario). Púlsalo para desplegarlos y otra vez para recogerlos."] =
        "The icons addons put around the minimap go inside the grid button (under the calendar). Click it to open them and again to put them away.",
})
