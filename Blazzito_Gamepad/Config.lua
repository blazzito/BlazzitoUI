-- Página «Mando» de /bui.
local ns = BlazzitoUI
local GP = ns and ns.Gamepad
if not (GP and ns.Config and ns.Widgets) then return end

local Pad, W = ns.Pad, ns.Widgets

local function StatusText()
    local now, session = Pad.On(), Pad.Session()
    local devices = Pad.Devices()
    local text = "Estilo de interfaz: |cffffffff" .. (now and "Mando" or "Teclado y ratón") .. "|r"
    if now ~= session then
        text = text .. "   |cffffb84d(al entrar era " .. (session and "mando" or "teclado y ratón") .. ": escribe /reload)|r"
    end
    text = text .. "\nMando conectado: |cffffffff" .. (#devices > 0 and table.concat(devices, ", ") or "ninguno") .. "|r"
    return text
end

ns.Config.RegisterPage("gamepad", "Mando", 23, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn

    L:Card("Estado")
    local status = L:Note(StatusText())
    L:Row(W.Button(content, col, "Elegir mando o teclado y ratón", function() GP.ShowChooser(true) end, true),
          W.Button(content, col, "Ver diagnóstico en el chat", Pad.Diagnose))
    L:Note("El estilo de mando cambia toda la interfaz de Blizzard: sus barras de mando, su barra de lanzamiento, la leyenda de botones y la navegación de las ventanas con la cruceta. Al elegir otro estilo se recarga la interfaz para que BlazzitoUI se adapte.")
    L:EndCard()

    L:Card("Al entrar al juego")
    L:Row(W.Toggle(content, col, "Preguntar si hay un mando conectado",
        function() return GP.db.ask end,
        function(v) GP.db.ask = v and true or false end))
    L:Note("Con un mando conectado, al entrar te pregunta si quieres la interfaz de mando o la de teclado y ratón. Con el mando: A elige mando, B elige teclado y ratón. Si no respondes, se cierra sola a los 30 segundos sin cambiar nada.")
    L:EndCard()

    L:Card("Estilo del HUD de mando")
    L:Row(W.Toggle(content, col, "Botones de las barras de mando",
              function() return GP.db.skinButtons end,
              function(v) GP.db.skinButtons = v and true or false; if Pad.Session() then ns.AskReload() end end),
          W.Toggle(content, col, "Leyenda de botones",
              function() return GP.db.skinLegend end,
              function(v) GP.db.skinLegend = v and true or false; if Pad.Session() then ns.AskReload() end end))
    L:Note("Borde de 1 px en lugar del aro dorado: negro normalmente y del color de tu clase en la barra activa (al mantener LT o RT) o en los botones marcados. La leyenda pasa a un panel oscuro con una línea de tu color arriba. Solo con el estilo de mando; apagarlo se aplica al recargar.")
    L:EndCard()

    L:Card("Con el estilo de mando")
    L:Note("Estas piezas meten botones o ganchos dentro de ventanas que la cruceta recorre. Si la cruceta pulsa algo nuestro, Blizzard bloquea el mando hasta recargar. Por eso se apartan con el estilo de mando. Enciéndelas solo si juegas con teclado y ratón aunque tengas el estilo de mando puesto. Se aplica al recargar.")
    for _, info in ipairs(Pad.KEEP_INFO) do
        L:Row(W.Toggle(content, col, info.label,
            function() return ns.db.pad.keep[info.key] == true end,
            function(v)
                ns.db.pad.keep[info.key] = v and true or false
                if Pad.Session() then ns.AskReload() end
            end))
        L:Note(info.desc)
    end
    L:Note("Siempre, con el estilo de mando: el marco de objetivo de Blizzard sigue existiendo invisible, porque el botón Y abre su menú. Los marcos de grupo de Blizzard también quedan invisibles, porque la cruceta los recorre al elegir aliados.")
    L:EndCard()

    local refresh = L.Refresh
    function L:Refresh()
        status:SetText(StatusText())
        refresh(self)
    end
    Pad.Watch("page", function()
        if content:IsVisible() then L:Refresh() end
    end)
    return L
end)
