-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- Chat.lua: comandos, enlaces, copiar e historial
    ---------------------------------------------------------------------------
    ["ese comando ya no existe: %s"] = "that command no longer exists: %s",
    ["el comando %s falló: %s"] = "the command %s failed: %s",
    ["Ctrl+C para copiar · Esc para cerrar"] = "Ctrl+C to copy · Esc to close",
    ["Ojo: este enlace lleva fuera del juego. WoW no deja a los addons abrir el navegador; cópialo y pégalo en él solo si confías en quien lo envió."] =
        "Careful: this link leads outside the game. WoW doesn't let addons open the browser; copy it and paste it there only if you trust whoever sent it.",
    ["ese enlace ya es muy antiguo."] = "that link is too old.",
    ["Copiar mensaje"] = "Copy message",
    ["Enlace a un sitio externo"] = "Link to an external site",
    ["Historial del chat"] = "Chat history",
    ["Selecciona con el ratón y pulsa Ctrl+C (Ctrl+A para todo)"] = "Select with the mouse and press Ctrl+C (Ctrl+A for everything)",
    ["Comandos y enlaces"] = "Commands and links",
    ["No hay comandos ni direcciones en los últimos mensajes."] = "No commands or web addresses in the latest messages.",
    ["(No hay mensajes que se puedan copiar.)"] = "(There are no messages that can be copied.)",
    ["Ejecutar  %s"] = "Run  %s",
    ["Web  %s"] = "Web  %s",
    ["Historial del chat (copiar mensajes, comandos y enlaces)"] = "Chat history (copy messages, commands and links)",
    ["abre el historial del chat para copiar"] = "opens the chat history for copying",

    ---------------------------------------------------------------------------
    -- Config.lua: página Chat
    ---------------------------------------------------------------------------
    ["Aspecto"] = "Look",
    ["Estilo de BlazzitoUI (sin el arte de Blizzard)"] = "BlazzitoUI style (without Blizzard's art)",
    ["Opacidad del fondo (%)"] = "Background opacity (%)",
    ["Borde fino"] = "Thin border",
    ["Ocultar los botones del chat"] = "Hide the chat buttons",
    ["Letra con contorno"] = "Outlined text",
    ["Las ventanas, pestañas y canales siguen siendo los de WoW (clic derecho en una pestaña para sus opciones). El tamaño de letra se cambia en esas opciones de Blizzard. Al quitar el estilo conviene recargar."] =
        "Windows, tabs and channels are still WoW's own (right-click a tab for its options). The font size is changed in those Blizzard options. After turning the style off, a reload is recommended.",
    ["Copiar"] = "Copy",
    ["Botón de copiar en los mensajes de jugadores"] = "Copy button on player messages",
    ["Botón de historial encima del chat"] = "History button above the chat",
    ["Abrir el historial"] = "Open the history",
    ["WoW no deja a los addons escribir en tu portapapeles: al pulsar copiar se abre el mensaje ya seleccionado y basta con Ctrl+C. En el historial puedes seleccionar varios mensajes con el ratón (o todo con Ctrl+A). También con /bui chat."] =
        "WoW doesn't let addons write to your clipboard: pressing copy opens the message already selected, so just press Ctrl+C. In the history you can select several messages with the mouse (or everything with Ctrl+A). Also with /bui chat.",
    ["Enlaces, comandos y emoticonos"] = "Links, commands and emotes",
    ["Direcciones web pulsables"] = "Clickable web addresses",
    ["Comandos pulsables (/algo)"] = "Clickable commands (/something)",
    ["Emoticonos  :)  :(  ;)  :D  :P  :O  <3  :/"] = "Emotes  :)  :(  ;)  :D  :P  :O  <3  :/",
    ["Tamaño de los emoticonos (0 = como la letra)"] = "Emote size (0 = same as the text)",
    ["WoW no puede abrir el navegador: una dirección pulsada se muestra para copiarla, con aviso de que lleva fuera del juego. Los comandos de addons se ejecutan al momento; los de Blizzard se dejan escritos en el chat para que pulses Intro. Lo que escriben otros addons en el chat no pasa por aquí: sus comandos aparecen a la derecha del historial."] =
        "WoW can't open the browser: a clicked address is shown so you can copy it, with a warning that it leads outside the game. Addon commands run right away; Blizzard's are typed into the chat for you to press Enter. What other addons write to the chat doesn't go through here: their commands appear on the right of the history.",
    ["En bandas, mazmorras y JcJ el chat puede llegar \"protegido\": esos mensajes se muestran tal cual, sin estos añadidos."] =
        "In raids, dungeons and PvP the chat may arrive \"protected\": those messages are shown as they are, without these extras.",
})
