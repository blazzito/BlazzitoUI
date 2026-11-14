-- Página "Texto de combate" de la ventana de configuración de BlazzitoUI.
-- Mientras está abierta, salen mensajes de ejemplo en las zonas para ver los
-- arcos al ajustarlos.
local ns = BlazzitoUI
if not (ns and ns.CombatText) then return end

local CT, W = ns.CombatText, ns.Widgets

local function Choices(list)
    local out = {}
    for i, pair in ipairs(list) do out[i] = { value = pair[1], text = pair[2] } end
    return out
end

local OUTLINES = Choices({ { "OUTLINE", "Contorno" }, { "THICKOUTLINE", "Contorno grueso" }, { "", "Sin contorno" } })
local STYLES = Choices({ { "parabola", "Arco (parábola)" }, { "straight", "Recto" }, { "angled", "En ángulo" }, { "static", "Estático" } })
local DIRECTIONS = Choices({ { "down", "Hacia abajo" }, { "up", "Hacia arriba" } })
local CURVES = Choices({ { "left", "Hacia la izquierda" }, { "right", "Hacia la derecha" } })

-- Qué se puede mostrar, agrupado como en el juego.
local GROUPS = {
    { "Lo que recibes", {
        { "incomingDamage", "Daño recibido" }, { "incomingHeal", "Curas recibidas" },
        { "incomingAvoid", "Esquivas, paradas, bloqueos, fallos" }, { "incomingPower", "Recursos ganados (maná, ira...)" },
    } },
    { "Lo que haces", {
        { "outgoingDamage", "Tu daño" }, { "outgoingHeal", "Tus curas a otros" },
        { "outgoingMiss", "Tus fallos (esquiva, parada...)" }, { "petDamage", "Daño de tu mascota" },
    } },
    { "Avisos", {
        { "combat", "Entrar / salir de combate" }, { "cooldowns", "Enfriamientos listos" },
        { "buffs", "Beneficios ganados / perdidos" },
        { "debuffs", "Perjuicios recibidos / quitados" }, { "procs", "Procs (habilidades activadas)" },
        { "lowHealth", "Vida o maná bajos" }, { "killingBlow", "Golpes de gracia" },
        { "reputation", "Reputación" }, { "honor", "Honor" },
        { "loot", "Botín" }, { "money", "Dinero" },
    } },
}

ns.Config.RegisterPage("combattext", "Texto de combate", 19, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn
    local db = CT.db
    local function apply()
        for key in pairs(CT.frames) do CT.LayoutArea(key) end
        CT.ApplyBlizzard()
        L:RefreshStates()
    end

    -- Fuente: cada casilla enseña un ejemplo escrito con ella; un clic la elige.
    L:Card("Fuente")
    local tiles = {}
    local function Tile(font)
        local path = CT.FontPath(font.key)
        local tile = CreateFrame("Button", nil, content)
        tile:SetSize(col, 58)
        -- La elegida: borde de 1 px y nombre en el color del acento (la clase).
        local T = W.T
        local panel = W.Panel(tile, T.radius, T.bg, T.line)
        local hover = tile:CreateTexture(nil, "HIGHLIGHT")
        hover:SetPoint("TOPLEFT", 1, -1)
        hover:SetPoint("BOTTOMRIGHT", -1, 1)
        hover:SetColorTexture(1, 1, 1, 0.04)
        local sample = tile:CreateFontString(nil, "OVERLAY")
        local okFont, loaded = pcall(sample.SetFont, sample, path, 24, "OUTLINE")
        if not okFont or loaded == false then return nil end
        sample:SetPoint("LEFT", 14, 4)
        -- Sin «¡»: algunas fuentes compartidas no tienen ese signo.
        sample:SetText("|cffffd2301.234|r  |cffff8020" .. ns.Translate("Crítico") .. "|r")
        local name = W.Text(tile, 11, W.COLORS.muted)
        name:SetPoint("BOTTOMLEFT", 14, 6)
        name:SetText(ns.Translate(font.text))
        tile:SetScript("OnClick", function()
            db.font = font.key
            for _, t in ipairs(tiles) do t:Refresh() end
            CT.Burst()
        end)
        function tile:Refresh()
            local chosen = db.font == font.key
            local a = W.COLORS.accent
            panel.border:SetColor(chosen and a or T.line)
            name:SetTextColor(unpack(chosen and a or W.COLORS.muted))
        end
        function tile:SetActive(active) self:SetAlpha(active and 1 or 0.35); self:SetEnabled(active) end
        tiles[#tiles + 1] = tile
        return tile
    end
    local fonts = {}
    for _, f in ipairs(CT.FONT_LIST) do fonts[#fonts + 1] = f end
    for _, f in ipairs(CT.SharedFonts()) do fonts[#fonts + 1] = f end
    local pending
    for _, f in ipairs(fonts) do
        local tile = Tile(f)
        if tile then
            if pending then L:Row(pending, tile); pending = nil else pending = tile end
        end
    end
    if pending then L:Row(pending) end
    L:Note("Las cuatro primeras van incluidas (gruesas y muy legibles; licencias libres). Recomendadas: Russo One (deportiva, la más llamativa) y Changa (redonda y muy negra). Detrás salen las que comparten otros addons que tengas instalados. Al elegir una salen golpes de ejemplo en pantalla.")
    L:EndCard()

    local fl = db.flair
    local function fget(key) return function() return fl[key] end end
    local function fset(key) return function(v) fl[key] = v; L:RefreshStates() end end
    L:Card("Más llamativo")
    L:Row(W.Toggle(content, col, "Los golpes grandes salen más grandes", fget("sizeByHit"), fset("sizeByHit")),
          W.Toggle(content, col, "Estallido detrás de los críticos", fget("critBurst"), fset("critBurst")))
    L:Row(W.Toggle(content, col, "Temblor al aparecer un crítico", fget("critShake"), fset("critShake")),
          W.Toggle(content, col, "\"¡Crítico!\" encima del número", fget("critLabel"), fset("critLabel")))
    L:Row(W.Toggle(content, col, "Rachas de críticos (¡Crítico ×3!)", fget("streak"), fset("streak")),
          W.Toggle(content, col, "Resumen al salir de combate", fget("summary"), fset("summary")),
          function() return fl.critLabel end)
    L:Row(W.Toggle(content, col, "Golpe de gracia con calavera", fget("killSkull"), fset("killSkull")),
          W.Toggle(content, col, "Daño en el tiempo: tics pequeños y el total al acabar", fget("dotSummary"), fset("dotSummary")))
    L:Row(W.Toggle(content, col, "Exceso de daño al matar", fget("overkill"), fset("overkill")))
    L:Row(W.Slider(content, col, "Ocultar tus golpes menores que (0 = todos)", 0, 500, 10, fget("minHit"), fset("minHit")),
          W.Toggle(content, col, "Ocultarlos solo en grupo o banda", fget("minHitGroupOnly"), fset("minHitGroupOnly")),
          nil, function() return (fl.minHit or 0) > 0 end)
    L:Note("El tamaño se compara con la media de tus últimos golpes: el normal sale igual y uno cuatro veces mayor, un 60 % más grande. El resumen sale en los avisos al acabar cada combate: daño total, daño por segundo y tu mayor golpe con su hechizo. El daño en el tiempo agrupado y el exceso de daño necesitan el registro de combate (/bui sct dice si llega); con el respaldo no se sabe qué tic es de qué.")
    L:EndCard()

    L:Card("General")
    L:Row(W.Dropdown(content, col, "Contorno", OUTLINES, function() return db.outline end, function(v) db.outline = v end),
          W.Button(content, 200, "Probar en pantalla", function() CT.Burst() end, true))
    L:Row(W.Toggle(content, col, "Abreviar números (12,3 mil)", function() return db.abbreviate end, function(v) db.abbreviate = v end),
          W.Toggle(content, col, "Iconos de los hechizos", function() return db.icons end, function(v) db.icons = v end))
    L:Row(W.Toggle(content, col, "Espada, flecha y huella en los ataques básicos", function() return db.glyphs end, function(v) db.glyphs = v end))
    L:Row(W.Toggle(content, col, "Colores por escuela de magia", function() return db.schoolColors end, function(v) db.schoolColors = v end),
          W.Toggle(content, col, "Ocultar el texto de Blizzard sobre ti", function() return db.hideBlizzardSelf end, function(v)
              db.hideBlizzardSelf = v
              apply()
          end))
    L:Row(W.Button(content, 160, "Mover zonas", function() ns.Movers.Toggle() end),
          W.Button(content, 180, "Ráfaga de prueba", function() CT.Burst() end))
    L:Note("Los números que pone Blizzard sobre los enemigos se quitan en Opciones > Combate > Texto de combate flotante. Escribe /bui sct para ver qué fuentes de datos funcionan en tu cliente.")
    L:EndCard()

    L:Card("Agrupar golpes")
    L:Row(W.Toggle(content, col, "Agrupar lo que haces", function() return db.merge.outgoing end, function(v) db.merge.outgoing = v end),
          W.Toggle(content, col, "Agrupar lo que recibes", function() return db.merge.incoming end, function(v) db.merge.incoming = v end))
    L:Row(W.Slider(content, col, "Ventana para agrupar (s)", 0.1, 1.5, 0.1, function() return db.merge.window end,
              function(v) db.merge.window = v end))
    L:Note("Los golpes seguidos del mismo hechizo (o del cuerpo a cuerpo, o de tu mascota) dentro de la ventana salen como uno solo: \"4.312 ×3\". Si alguno fue crítico, el total sale como crítico. Los números secretos (contenido restringido) no se pueden sumar y salen uno a uno.")
    L:EndCard()

    L:Card("Avisos de enfriamiento")
    L:Row(W.Toggle(content, col, "Avisar cuando un hechizo esté listo", function() return db.categories.cooldowns.on end,
              function(v) db.categories.cooldowns.on = v; L:RefreshStates() end),
          W.Slider(content, col, "Solo enfriamientos de al menos (s)", 2, 120, 1, function() return db.cooldownMin end,
              function(v) db.cooldownMin = v end),
          nil, function() return db.categories.cooldowns.on end)
    L:Note("Sale \"Listo: <hechizo>\" con su icono en la zona de avisos.")
    L:EndCard()

    for _, info in ipairs(CT.AREAS) do
        local a = db.areas[info.key]
        local function get(key) return function() return a[key] end end
        local function set(key) return function(v) a[key] = v; apply() end end
        local function on() return a.enabled end
        local function moving() return a.enabled and a.style ~= "static" end
        local function curved() return a.enabled and (a.style == "parabola" or a.style == "angled") end
        L:Card(info.label)
        L:Row(W.Toggle(content, col, "Activar esta zona", get("enabled"), set("enabled")),
              W.Dropdown(content, col, "Animación", STYLES, get("style"), set("style")),
              nil, on)
        L:Row(W.Dropdown(content, col, "Dirección", DIRECTIONS, get("direction"), set("direction")),
              W.Dropdown(content, col, "Curva", CURVES, get("curve"), set("curve")),
              on, curved)
        L:Row(W.Slider(content, col, "Recorrido (alto)", 60, 500, 10, get("height"), set("height")),
              W.Slider(content, col, "Curvatura (ancho)", 0, 250, 5, get("width"), set("width")),
              moving, curved)
        L:Row(W.Slider(content, col, "Tamaño de letra", 10, 40, 1, get("fontSize"), set("fontSize")),
              W.Slider(content, col, "Duración (s)", 1, 6, 0.5, get("duration"), set("duration")),
              on, on)
        L:Row(W.Toggle(content, col, "Críticos con golpe en el centro", get("pow"), set("pow")),
              W.Slider(content, col, "Tamaño de los críticos (x)", 1, 2.5, 0.1, get("critScale"), set("critScale")),
              on, on)
        L:EndCard()
    end

    for _, group in ipairs(GROUPS) do
        L:Card(ns.LF("Mostrar: %s", ns.Translate(group[1])))
        for _, item in ipairs(group[2]) do
            local cat = db.categories[item[1]]
            L:Row(W.Toggle(content, col, item[2], function() return cat.on end, function(v) cat.on = v; L:RefreshStates() end),
                  W.Color(content, col, "Color", function() return cat.color end, function(r, g, b) cat.color = { r, g, b } end),
                  nil, function() return cat.on end)
        end
        L:EndCard()
    end
    return L
end)
