-- Mando: convivencia con el estilo de interfaz «Gamepad» de WoW Forever.
--
-- Con ese estilo (Opciones > Juego > Gamepad) Blizzard cambia la interfaz:
-- barras de mando propias, leyenda, pies de ventana y un sistema de
-- navegación (SmartNavigation) que recorre las ventanas con la cruceta y
-- pulsa con :Click() cualquier botón que encuentre dentro. Si ese botón es
-- nuestro, nuestro código corre dentro de su navegación segura y la
-- contamina: Blizzard bloquea después SetPreferredGamepadInteractTarget() y el
-- mando se queda sin responder hasta /reload.
--
-- Por eso, con el estilo mando:
--  * Los módulos marcados con module.padStandDown (Ventanas, Bolsas) no se
--    activan salvo que el usuario lo pida en la página Mando (ns.db.pad.keep).
--  * El objetivo de Blizzard (dueño del menú del botón Y) y los marcos de
--    grupo (los recorre la cruceta al elegir aliados) no se esconden: quedan
--    visibles a alfa 0 (Blizzard.lua).
--  * Los avisos van también al chat: la cruceta no llega a nuestras ventanas.
--
-- La decisión se toma una vez por sesión, al entrar (Pad.Session); si el
-- jugador cambia de estilo después, se le pide /reload.
local _, ns = ...

local Pad = {}
ns.Pad = Pad

Pad.DEFAULTS = {
    keep = { Windows = false, Bags = false, GameMenu = false },
}

-- Qué se puede volver a encender con el estilo mando (página Mando).
Pad.KEEP_INFO = {
    { key = "Windows", label = "Todas las ventanas con nuestro estilo",
      desc = "Personaje, talentos, libro de hechizos y mapa: añadimos botones dentro de ellas, y la cruceta podría pulsarlos. Las ventanas sencillas (botín y tiradas, comerciante, entrenadores, correo, profesiones, subastas) siguen con nuestro estilo aunque esto esté apagado: solo llevan texturas." },
    { key = "Bags", label = "Bolsas con nuestro estilo",
      desc = "Bolsas y banco. Con mando se recorren con la cruceta, y nuestros botones y ganchos quedarían dentro." },
    { key = "GameMenu", label = "Botón BlazzitoUI en el menú Esc",
      desc = "Con mando, el menú Esc se recorre con la cruceta y nuestro botón lo cerraría desde nuestro código." },
}

---------------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------------
local function GamepadStyle()
    local api = C_InputInterfaceStyle
    local types = Enum and Enum.InputDeviceInterfaceType
    if not (api and api.GetCurrentStyle and types and types.Gamepad ~= nil) then return false end
    local ok, style = pcall(api.GetCurrentStyle)
    return ok and style == types.Gamepad or false
end

-- ¿Está puesto ahora mismo el estilo mando?
function Pad.On()
    return GamepadStyle()
end

-- El estilo con el que empezó la sesión: lo que deciden los módulos. Antes de
-- entrar al juego se lee pero no se guarda (el estilo se asienta al entrar).
function Pad.Session()
    if Pad.session ~= nil then return Pad.session end
    local on = GamepadStyle()
    if ns.loggedIn then Pad.session = on end
    return on
end

-- ¿Puede `key` (un módulo o pieza de Pad.KEEP_INFO) funcionar como siempre?
-- Sin estilo mando, sí; con él, solo si el usuario lo ha vuelto a encender.
function Pad.Keep(key)
    if not Pad.Session() then return true end
    local db = ns.db and ns.db.pad
    return db ~= nil and db.keep[key] == true
end

-- ¿El módulo está apartado por el mando? (encendido, pero sin activar)
function Pad.Resting(module)
    return module ~= nil and module.padResting == true
end

---------------------------------------------------------------------------
-- Cambio de estilo durante la sesión
---------------------------------------------------------------------------
local watchers = {}

-- fn(enMando) cada vez que cambia el estilo (un fotograma después del evento).
function Pad.Watch(key, fn)
    watchers[key] = fn
end

local asked = false
local function Changed()
    local on = GamepadStyle()
    for _, fn in pairs(watchers) do
        local ok, err = pcall(fn, on)
        if not ok then geterrorhandler()(err) end
    end
    if not ns.loggedIn or Pad.session == nil or on == Pad.session or asked then return end
    asked = true
    ns.Print(on and "has activado el estilo de mando. Escribe |cffffffff/reload|r para que BlazzitoUI se adapte (ventanas y bolsas se apartan para no bloquear el mando)."
                 or "has vuelto a teclado y ratón. Escribe |cffffffff/reload|r para recuperar todo el estilo de BlazzitoUI.")
    -- De vuelta a teclado y ratón, además la ventana de recarga (con mando, solo el chat).
    if not on then StaticPopup_Show("BLAZZITOUI_RELOAD") end
end

do
    local EVENT = "INPUT_DEVICE_INTERFACE_TRANSITION"
    local known = not (C_EventUtils and C_EventUtils.IsEventValid) or C_EventUtils.IsEventValid(EVENT)
    if known then
        local frame = CreateFrame("Frame")
        -- Un nombre de evento que el cliente no conoce da error al registrarlo.
        if pcall(frame.RegisterEvent, frame, EVENT) then
            frame:SetScript("OnEvent", function() C_Timer.After(0, Changed) end)
        end
    end
end
Pad.Changed = Changed

ns.On("ADDON_LOADED", function(_, name)
    if name ~= "BlazzitoUI" or not ns.db then return end
    ns.db.pad = ns.db.pad or {}
    ns.MergeDefaults(ns.db.pad, Pad.DEFAULTS)
end)

ns.On("PLAYER_LOGIN", function()
    Pad.Session()
end)

---------------------------------------------------------------------------
-- Diagnóstico: /bui mando
---------------------------------------------------------------------------
local function Yes(v) return v and "|cff7fdc7fsí|r" or "|cffff7f7fno|r" end

local function FrameState(name)
    local frame = _G[name]
    if not frame then return "no existe" end
    local parent = frame:GetParent()
    local pname = parent and parent.GetName and parent:GetName() or "?"
    return string.format("padre %s, mostrado %s, visible %s", tostring(pname),
        Yes(frame:IsShown()), Yes(frame:IsVisible()))
end

function Pad.Devices()
    local list = {}
    if not (C_GamePad and C_GamePad.GetAllDeviceIDs) then return list end
    local ok, ids = pcall(C_GamePad.GetAllDeviceIDs)
    if not ok or type(ids) ~= "table" then return list end
    for _, id in ipairs(ids) do
        local name
        if C_GamePad.GetDeviceMappedState then
            local okState, state = pcall(C_GamePad.GetDeviceMappedState, id)
            name = okState and type(state) == "table" and state.name or nil
        end
        list[#list + 1] = name or ("mando " .. tostring(id))
    end
    return list
end

function Pad.Diagnose()
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    ns.Print("mando:")
    print(string.format("  estilo ahora: %s · al entrar: %s · CVar InputDeviceInterfaceStyle=%s · GamePadEnable=%s",
        Pad.On() and "mando" or "teclado y ratón", Pad.Session() and "mando" or "teclado y ratón",
        tostring(get and get("InputDeviceInterfaceStyle")), tostring(get and get("GamePadEnable"))))
    local devices = Pad.Devices()
    local using = IsUsingGamepad and IsUsingGamepad()
    print("  mandos: " .. (#devices > 0 and table.concat(devices, ", ") or "ninguno") ..
        " · usando el mando ahora: " .. Yes(using))
    print(string.format("  Blizzard: SmartNavigation %s · GamepadMode %s · GroupTargeting %s",
        Yes(_G.SmartNavigation ~= nil), Yes(_G.GamepadMode ~= nil), Yes(_G.GroupTargeting ~= nil)))
    local manager = _G.GamepadMode and _G.GamepadMode.FrameControlsManager
    if manager and manager.GetActiveFrame then
        local ok, active = pcall(manager.GetActiveFrame, manager)
        local name = ok and active and active.GetName and active:GetName()
        print("  ventana enfocada por la cruceta: " .. tostring(name or (ok and active and "(sin nombre)") or "ninguna"))
    end
    for _, info in ipairs(Pad.KEEP_INFO) do
        local module = ns.modules[info.key]
        local state
        if module then
            state = module.active and "activo" or (module.padResting and "apartado por el mando")
                or (module.db and module.db.enabled == false and "apagado") or "sin cargar"
        else
            state = Pad.Keep(info.key) and "activo" or "apartado por el mando"
        end
        print("  " .. info.label .. ": " .. state)
    end
    for _, name in ipairs({ "TargetFrame", "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer" }) do
        print("  " .. name .. ": " .. FrameState(name))
    end
end

ns.RegisterCommand("mando", Pad.Diagnose, "estado del mando y qué hace BlazzitoUI con él")
