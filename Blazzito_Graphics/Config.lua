-- Página "Gráficos" de la ventana de configuración de BlazzitoUI.
local ns = BlazzitoUI
if not (ns and ns.Graphics) then return end

local G, W, M = ns.Graphics, ns.Widgets, ns.Media
local ACCENT = W.COLORS.accent
local Tr, LF = ns.Translate, ns.LF

-- Una fila de preset: botón a la izquierda y su descripción a la derecha.
-- El preset que coincide con tus ajustes actuales queda marcado.
local function PresetRow(parent, width, preset)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width, 30)
    local button = W.Button(f, 150, preset.name, function() G.Apply(preset.key) end, false, 30)
    button:SetPoint("LEFT")
    local mark = button:CreateTexture(nil, "OVERLAY")
    mark:SetPoint("TOPLEFT", 1, -1)
    mark:SetPoint("BOTTOMLEFT", 1, 1)
    mark:SetWidth(3)
    mark:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    local fill = button:CreateTexture(nil, "BACKGROUND", nil, -6)
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.30)
    local desc = W.Text(f, 12, W.COLORS.muted, true)
    desc:SetPoint("LEFT", button, "RIGHT", 14, 0)
    desc:SetPoint("RIGHT")
    desc:SetJustifyH("LEFT")
    desc:SetText(Tr(preset.desc))
    f.button = button
    function f:Refresh()
        local on = G.Current() == preset.key
        mark:SetShown(on)
        fill:SetShown(on)
    end
    function f:SetActive(active)
        self:SetAlpha(active and 1 or 0.35)
        button:SetEnabled(active)
    end
    return f
end

-- Botón que se puede activar o no según una condición.
local function ActionButton(parent, width, label, onClick)
    return W.Button(parent, width, label, onClick)
end

local function When(slot)
    local backup = G.db.backups[slot]
    if not backup then return Tr("sin guardar") end
    return date and date(Tr("%d/%m a las %H:%M"), backup.time) or Tr("guardada")
end

ns.Config.RegisterPage("graphics", "Gráficos", 22, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn

    local card = L:Card("Presets")
    -- FPS en vivo junto al título, para comparar al probar presets.
    local fps = W.Text(card.actions, 13, ACCENT)
    fps:SetPoint("RIGHT")
    local elapsed = 0
    card:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.5 then return end
        elapsed = 0
        local rate = GetFramerate and GetFramerate()
        if rate then fps:SetText(string.format("%d FPS", rate + 0.5)) end
    end)
    for _, preset in ipairs(G.PRESETS) do
        L:Full(PresetRow(content, L.width, preset))
    end
    L:Note("Un clic y listo; el preset marcado es el que coincide con tus ajustes ahora mismo (si cambias algo en el menú de Blizzard, deja de estar marcado). Si tu equipo no admite algún nivel, se usa el más alto que sí admite. Lo que mejor rinde es quitar la oclusión ambiental y la niebla volumétrica: por eso los presets «+ FPS» se ven casi igual y van mucho más fluidos. No se tocan la iluminación secundaria (en Forever da problemas en algunos equipos) ni la densidad de hechizos.")
    L:EndCard()

    L:Card("Copia de seguridad")
    L:Row(ActionButton(content, col, "Guardar mis ajustes actuales", function()
              G.Snapshot("mine")
              ns.Print("gráficos guardados en tu copia.")
              L:Refresh()
          end),
          ActionButton(content, col, "Volver a mi copia", function() G.Restore("mine") end),
          nil, function() return G.HasBackup("mine") end)
    L:Row(ActionButton(content, col, "Volver a como estaba antes", function() G.Restore("original") end),
          nil, function() return G.HasBackup("original") end)
    local info = L:Note("Copia de antes: sin guardar")
    L:Note("«Como estaba antes» se guarda sola la primera vez que aplicas un preset y no se borra nunca: es tu red de seguridad. «Mi copia» la guardas tú cuando quieras (por ejemplo, después de afinar algo a mano).")
    L:EndCard()

    L:Card("Rendimiento")
    L:Row(W.Toggle(content, col, "Mismos gráficos en bandas y mazmorras", G.GetSameEverywhere, function(v)
              G.SetSameEverywhere(v)
              L:Refresh()
          end))
    L:Row(W.Slider(content, col, "Escala de renderizado (%)", 50, 100, 1, G.GetRenderScale, G.SetRenderScale),
          W.Slider(content, col, "Límite de FPS (0 = sin límite)", 0, 240, 5,
              function() return G.GetFPSCap(false) end, function(v) G.SetFPSCap(v, false) end))
    L:Row(W.Slider(content, col, "Límite de FPS en segundo plano (0 = sin límite)", 0, 120, 5,
              function() return G.GetFPSCap(true) end, function(v) G.SetFPSCap(v, true) end))
    L:Note("Con «Mismos gráficos» apagado, en bandas, mazmorras y campos de batalla el juego usa su propio juego de ajustes (el de la pestaña de bandas del menú de Blizzard) y los presets no se notan allí. Bajar la escala de renderizado un poco (90-95 %) da bastantes FPS casi sin notarse. El límite en segundo plano ahorra gráfica cuando tienes el juego minimizado o detrás de otra ventana. /bui graficos muestra en el chat todos tus valores actuales.")
    local limiter = L:Note(G.Limiter())
    L:EndCard()

    local refresh = L.Refresh
    function L:Refresh()
        limiter:SetText(G.Limiter())
        info:SetText(LF("Copia de antes: |cffffffff%s|r     Mi copia: |cffffffff%s|r", When("original"), When("mine")))
        refresh(self)
    end
    G.OnChanged = function()
        if content:IsVisible() then L:Refresh() end
    end
    return L
end)
