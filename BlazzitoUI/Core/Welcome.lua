-- Mensaje de bienvenida en el chat al entrar al juego (no en cada /reload):
--  * la primera vez que se usa BlazzitoUI: bienvenida y cómo abrir las opciones;
--  * tras actualizar: la versión nueva;
--  * el resto: un saludo corto con la versión y una frase que va cambiando.
-- La última versión vista es de toda la cuenta (BlazzitoUIDB.seenVersion); el
-- interruptor, de cada perfil (ns.db.welcome). Página Inicio > Bienvenida.
local ADDON_NAME, ns = ...
local Tr, LF = ns.Translate, ns.LF

local ICON = "|TInterface\\AddOns\\BlazzitoUI\\icon:16:16:0:0|t"
local DELAY = 3   -- segundos tras entrar: después de los mensajes de otros addons

-- Frases del saludo de cada día (se elige una al azar).
local TAGLINES = {
    "¡Buena caza!",
    "¡Que el botín te acompañe!",
    "Tu interfaz está lista. ¡A por ellos!",
    "¡Que caigan muchos épicos hoy!",
    "Recuerda vaciar las bolsas antes de la mazmorra.",
    "¡Hoy es un buen día para subir de nivel!",
    "¡Que no te falte el maná!",
    "El zorro te saluda.",
}

function ns.Version()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata(ADDON_NAME, "Version") or "?"
end

function ns.WelcomeEnabled()
    return not (ns.db and ns.db.welcome == false)
end

-- Texto del mensaje (sin pintar): "first", "updated" o "daily".
function ns.WelcomeText(kind, version, tagline)
    local name = "|cff4fc3f7BlazzitoUI|r"
    local ver = "|cffc9cdd3" .. tostring(version) .. "|r"
    local cmd = "|cffffffff/bui|r"
    if kind == "first" then
        return ICON .. " " .. LF("¡Gracias por elegir %s! Estás en la versión %s. Escribe %s para dejarlo a tu gusto.", name, ver, cmd)
    elseif kind == "updated" then
        return ICON .. " " .. LF("%s se actualizó a la versión %s. ¡Gracias por seguir con nosotros!", name, ver)
    end
    return ICON .. " " .. LF("%s %s · %s", name, ver, Tr(tagline or TAGLINES[1]))
end

function ns.ShowWelcome()
    local root = ns.root
    if not root then return end
    local version = ns.Version()
    local seen = root.seenVersion
    root.seenVersion = version
    if not ns.WelcomeEnabled() then return end
    local kind = (seen == nil and "first") or (seen ~= version and "updated") or "daily"
    local tagline = TAGLINES[math.random(#TAGLINES)]
    print(ns.WelcomeText(kind, version, tagline))
end

ns.On("PLAYER_ENTERING_WORLD", function(_, isInitialLogin)
    if not isInitialLogin then return end
    if C_Timer then C_Timer.After(DELAY, ns.ShowWelcome) else ns.ShowWelcome() end
end)

-- Interruptor en la página Inicio.
if ns.Config and ns.Config.AddGeneralCard then
    ns.Config.AddGeneralCard(function(L, content)
        local W = ns.Widgets
        L:Card("Bienvenida")
        L:Row(W.Toggle(content, L.innerColumn, "Mensaje de bienvenida al entrar", function() return ns.WelcomeEnabled() end,
            function(value) ns.db.welcome = value and true or false end),
            W.Button(content, 180, "Ver el mensaje", function()
                print(ns.WelcomeText("daily", ns.Version(), TAGLINES[math.random(#TAGLINES)]))
            end))
        L:Note("Un saludo corto en el chat al entrar al juego (no al recargar), con tu versión de BlazzitoUI. Tras una actualización te avisa de la versión nueva.")
        L:EndCard()
    end)
end
