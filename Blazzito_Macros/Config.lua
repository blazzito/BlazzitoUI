-- Blazzito_Macros: página «Macros de clase» en /bui.
local ns = BlazzitoUI
local Mac = ns and ns.Macros
if not (Mac and ns.Config and ns.Widgets) then return end

local W = ns.Widgets

ns.Config.RegisterPage("macros", "Macros de clase", 26, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = Mac.db

    local card = L:Card("Macros de clase")
    local open = W.Button(card.actions, nil, "Abrir macros", function() Mac.Open() end, true)
    open:SetPoint("RIGHT")
    L:Note("Las macros esenciales de tu clase en una ventana junto al libro de hechizos. Aparecen al aprender la habilidad; arrástralas a tus barras. Se crean como macros de personaje con el nombre «BUI …», y solo las que arrastras.")
    L:Row(W.Toggle(content, col, "Botón junto al libro de hechizos",
              function() return db.button end,
              function(v) db.button = v; Mac.ApplyButton() end),
          W.Toggle(content, col, "Actualizar mis macros solas",
              function() return db.autoUpdate end,
              function(v) db.autoUpdate = v; if v then Mac.Schedule() end end))
    L:Row(W.Toggle(content, col, "Marcar mis macros en las barras",
              function() return db.markBars end,
              function(v) db.markBars = v; Mac.MarkBars(); L:RefreshStates() end),
          W.Toggle(content, col, "Marcar también mis otras macros",
              function() return db.markAll end,
              function(v) db.markAll = v; Mac.MarkBars() end),
          nil, function() return db.markBars end)
    L:Note("La marca es una barrita abajo del botón: del color de tu clase en las macros de esta ventana y gris claro en tus otras macros. En la ventana, la misma barrita bajo el icono indica que ya la creaste.")
    L:Note("Al actualizarse solas cambian a la última arma que llevaste, a la comida que come tu mascota, a tus mejores pociones... y añaden los hechizos que vas aprendiendo. Fuera de combate, y nunca si editaste la macro a mano en /macro. «/bui macros ver» escribe en el chat el texto de cada una.")
    L:EndCard()

    -- Modificadores: si Mayús + R ya es otro atajo tuyo, la macro de R no puede usar Mayús.
    L:Card("Modificadores")
    L:Note("Algunas macros hacen otra cosa con Mayús, Ctrl o Alt pulsados. Si esa combinación ya es un atajo tuyo (por ejemplo Mayús + R), cámbiala aquí por otra tecla o quítala. Las macros del juego solo entienden Mayús, Ctrl y Alt: un botón del ratón no puede hacer de modificador.")
    local function Choices()
        return {
            { value = "shift", text = "Mayús" },
            { value = "ctrl", text = "Ctrl" },
            { value = "alt", text = "Alt" },
            { value = "none", text = "Ninguno (quitar esa opción)" },
        }
    end
    db.mods = db.mods or {}
    local function Mod(role, label)
        return W.Dropdown(content, col, label, Choices(),
            function() return db.mods[role] or role end,
            function(v)
                db.mods[role] = v
                Mac.RefreshAll()
            end)
    end
    L:Row(Mod("shift", "Donde las macros usan Mayús, usar"), Mod("ctrl", "Donde usan Ctrl, usar"))
    L:Row(Mod("alt", "Donde usan Alt, usar"))
    L:Note("Tus macros ya creadas se reescriben al momento (fuera de combate). Si eliges la misma tecla para dos, la primera opción de la macro gana.")
    L:EndCard()
    return L
end)
