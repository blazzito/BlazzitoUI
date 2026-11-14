-- Página "Chat" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.Chat) then return end

local CH, M, W = ns.Chat, ns.Media, ns.Widgets

ns.Config.RegisterPage("chat", "Chat", 16, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = CH.db
    local function get(key) return function() return db[key] end end
    local function set(key)
        return function(value)
            db[key] = value
            CH.ApplyAll()
            L:RefreshStates()
        end
    end
    local function skinned() return db.skin end

    L:Card("Aspecto")
    L:Row(W.Toggle(content, col, "Estilo de BlazzitoUI (sin el arte de Blizzard)", get("skin"), set("skin")),
          W.Slider(content, col, "Opacidad del fondo (%)", 0, 100, 5, get("background"), set("background")),
          nil, skinned)
    L:Row(W.Toggle(content, col, "Borde fino", get("border"), set("border")),
          W.Toggle(content, col, "Ocultar los botones del chat", get("hideButtons"), set("hideButtons")),
          skinned, skinned)
    L:Row(W.Toggle(content, col, "Letra con contorno", get("fontOutline"), set("fontOutline")))
    L:Note("Las ventanas, pestañas y canales siguen siendo los de WoW (clic derecho en una pestaña para sus opciones). El tamaño de letra se cambia en esas opciones de Blizzard. Al quitar el estilo conviene recargar.")
    L:EndCard()

    L:Card("Copiar")
    L:Row(W.Toggle(content, col, "Botón de copiar en los mensajes de jugadores", get("copyButtons"), set("copyButtons")),
          W.Toggle(content, col, "Botón de historial encima del chat", get("historyButton"), set("historyButton")))
    L:Row(W.Button(content, 200, "Abrir el historial", function() CH.OpenHistory() end, true))
    L:Note("WoW no deja a los addons escribir en tu portapapeles: al pulsar copiar se abre el mensaje ya seleccionado y basta con Ctrl+C. En el historial puedes seleccionar varios mensajes con el ratón (o todo con Ctrl+A). También con /bui chat.")
    L:EndCard()

    L:Card("Enlaces, comandos y emoticonos")
    L:Row(W.Toggle(content, col, "Direcciones web pulsables", get("links"), set("links")),
          W.Toggle(content, col, "Comandos pulsables (/algo)", get("commands"), set("commands")))
    L:Row(W.Toggle(content, col, "Emoticonos  :)  :(  ;)  :D  :P  :O  <3  :/", get("emotes"), set("emotes")),
          W.Slider(content, col, "Tamaño de los emoticonos (0 = como la letra)", 0, 32, 1, get("emoteSize"), set("emoteSize")),
          nil, function() return db.emotes end)
    L:Note("WoW no puede abrir el navegador: una dirección pulsada se muestra para copiarla, con aviso de que lleva fuera del juego. Los comandos de addons se ejecutan al momento; los de Blizzard se dejan escritos en el chat para que pulses Intro. Lo que escriben otros addons en el chat no pasa por aquí: sus comandos aparecen a la derecha del historial.")
    L:Note("En bandas, mazmorras y JcJ el chat puede llegar \"protegido\": esos mensajes se muestran tal cual, sin estos añadidos.")
    L:EndCard()
    return L
end)
