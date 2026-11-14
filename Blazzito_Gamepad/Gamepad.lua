-- Blazzito_Gamepad: el módulo «Mando».
--
-- La convivencia con el estilo de mando de Blizzard (qué se aparta, qué
-- marcos se quedan invisibles) vive en el núcleo (BlazzitoUI/Core/Pad.lua),
-- porque afecta a módulos que cargan antes que este. Aquí va lo propio del
-- mando: la pregunta al entrar (Chooser.lua), la página de opciones
-- (Config.lua) y el diagnóstico del HUD de mando (para vestirlo después).
local ns = BlazzitoUI
if not (ns and ns.Pad) then return end

local Pad = ns.Pad
local GP = ns.NewModule("Gamepad", "Mando", {
    ask = true,   -- al entrar con un mando conectado, preguntar mando o teclado y ratón
    skinButtons = true,   -- nuestro estilo en los botones de las barras de mando (Skin.lua)
    skinLegend = true,    -- y en la leyenda de botones
})
ns.Gamepad = GP

---------------------------------------------------------------------------
-- Diagnóstico del HUD de mando: /bui mando hud
-- Lista las piezas de Blizzard que se podrían vestir (barras de mando, menú
-- radial, leyenda), con sus claves, tipo y atlas, para ver qué existe de
-- verdad en este cliente antes de tocar nada.
---------------------------------------------------------------------------
local HUD_ROOTS = { "GamepadMainActionBarFrame", "GamepadPersistentInputLegend", "GamepadRadial", "GamepadHudMode" }
local MAX_LINES = 45

local function KeyOf(parent, child)
    if type(parent) ~= "table" then return nil end
    local ok, key = pcall(function()
        for k, v in pairs(parent) do
            if v == child and type(k) == "string" then return k end
        end
    end)
    return ok and key or nil
end

local function Describe(region, parent)
    local name = region.GetName and region:GetName()
    local key = KeyOf(parent, region)
    local kind = region.GetObjectType and region:GetObjectType() or "?"
    local label = (key and ("." .. key)) or (type(name) == "string" and name) or "(sin clave)"
    local extra = ""
    if region.GetAtlas then
        local atlas = region:GetAtlas()
        if type(atlas) == "string" and atlas ~= "" then extra = " " .. atlas end
    end
    if region.IsShown and not region:IsShown() then extra = extra .. " oculto" end
    return label .. " [" .. kind .. "]" .. extra
end

local function Dump(frame, depth, prefix, lines)
    if #lines >= MAX_LINES then return end
    lines[#lines + 1] = prefix .. Describe(frame, frame.GetParent and frame:GetParent())
    if depth <= 0 then return end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if #lines >= MAX_LINES then return end
            if region.GetAtlas then
                local atlas = region:GetAtlas()
                if type(atlas) == "string" and atlas ~= "" then
                    lines[#lines + 1] = prefix .. "  " .. Describe(region, frame)
                end
            end
        end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do Dump(child, depth - 1, prefix .. "  ", lines) end
    end
end

-- Un botón de muestra de las barras de mando (el de inspeccionar, Y).
local function SampleButton()
    local bar = _G.GamepadMainActionBarFrame
    local ok, button = pcall(function() return bar.PageUnit.actionBars.topBar.Right.ActionButton2 end)
    return ok and button or nil
end

function GP.DiagnoseHud()
    ns.Print("piezas del HUD de mando (estilo " .. (Pad.On() and "mando" or "teclado y ratón") .. "):")
    for _, name in ipairs(HUD_ROOTS) do
        local frame = _G[name]
        if not frame then
            print("  " .. name .. ": no existe")
        else
            local lines = {}
            Dump(frame, name == "GamepadMainActionBarFrame" and 3 or 2, "  ", lines)
            for _, line in ipairs(lines) do print(line) end
        end
    end
    if GP.Skin then
        local n, l = GP.Skin.Count()
        print(string.format("  con nuestro estilo: %d botones, %d fondos de la leyenda%s", n, l,
            GP.Skin.running and "" or " (solo con el estilo de mando al entrar)"))
    end
    local sample = SampleButton()
    if sample then
        print("  botón de muestra (Y):")
        local lines = {}
        Dump(sample, 1, "    ", lines)
        for _, line in ipairs(lines) do print(line) end
    else
        print("  botón de muestra (Y): no encontrado")
    end
end

function GP:OnEnable()
    ns.RegisterCommand("mando hud", GP.DiagnoseHud, "piezas del HUD de mando de Blizzard (para darles estilo)")
    if GP.SetupChooser then GP.SetupChooser() end
    if GP.Skin then GP.Skin.Start() end
end
