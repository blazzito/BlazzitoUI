-- BlazzitoUI: interfaz modular y ligera.
-- El núcleo carga la base de datos, registra los módulos y les da utilidades
-- comunes. Cada módulo vive en Modules/<Nombre>/ y se activa por separado.
local ADDON_NAME, ns = ...
_G.BlazzitoUI = ns

ns.modules = {}
ns.moduleOrder = {}

-- Mensaje al chat. Con huecos se traduce: ns.Print("%d objetos", n).
function ns.Print(msg, ...)
    if select("#", ...) > 0 then msg = ns.LF(msg, ...) else msg = ns.Translate(msg) end
    print("|cff4fc3f7BlazzitoUI|r: " .. tostring(msg))
end

-- Ventanas emergentes: se definen en español al cargar y se traducen al mostrarlas.
function ns.ShowPopup(name, ...)
    local dialog = StaticPopupDialogs[name]
    if dialog then
        dialog.source = dialog.source or { text = dialog.text, button1 = dialog.button1, button2 = dialog.button2 }
        for key, value in pairs(dialog.source) do dialog[key] = ns.Translate(value) end
    end
    return StaticPopup_Show(name, ...)
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            MergeDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end
ns.MergeDefaults = MergeDefaults

-- Un error en un módulo no debe impedir que carguen los demás.
local function SafeCall(fn, ...)
    local args, count = { ... }, select("#", ...)
    return xpcall(function() return fn(unpack(args, 1, count)) end, geterrorhandler())
end

-- Prepara la configuración de un módulo y llama a su OnInitialize.
local function InitModule(module)
    ns.db.modules[module.name] = ns.db.modules[module.name] or {}
    MergeDefaults(ns.db.modules[module.name], module.defaults)
    module.db = ns.db.modules[module.name]
    if module.OnInitialize then SafeCall(module.OnInitialize, module) end
end

local function EnableModule(module)
    -- Con el estilo de mando, los módulos que meten botones en ventanas que
    -- recorre la cruceta se apartan (Pad.lua), salvo que el usuario los pida.
    if module.db.enabled and module.padStandDown and ns.Pad and not ns.Pad.Keep(module.name) then
        module.padResting = true
        -- El módulo puede dejar en marcha lo que sí es seguro con mando.
        if module.OnPadRest then SafeCall(module.OnPadRest, module) end
        return
    end
    if module.db.enabled and module.OnEnable then
        module.active = true
        SafeCall(module.OnEnable, module)
    end
end

-- Crea un módulo. Su configuración queda en module.db; "enabled" vale true si no se indica.
-- Hooks opcionales: OnInitialize (al cargar) y OnEnable (al entrar, si está activo).
-- Los módulos pueden venir en addons aparte (Blazzito_*), que cargan después
-- del núcleo: esos se preparan en el ADDON_LOADED de su propio addon, cuando
-- ya cargaron todos sus archivos.
function ns.NewModule(name, title, defaults)
    defaults = defaults or {}
    if defaults.enabled == nil then defaults.enabled = true end
    local module = { name = name, title = title or name, defaults = defaults }
    ns.modules[name] = module
    ns.moduleOrder[#ns.moduleOrder + 1] = name
    if ns.db then module.pendingInit = true end
    return module
end

---------------------------------------------------------------------------
-- Eventos con varios oyentes
---------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local listeners = {}

function ns.On(event, fn)
    if not listeners[event] then
        listeners[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(listeners[event], fn)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    for _, fn in ipairs(listeners[event]) do fn(event, ...) end
end)

---------------------------------------------------------------------------
-- Tareas que no se pueden hacer en combate (mover o mostrar marcos seguros)
---------------------------------------------------------------------------
local combatQueue = {}

function ns.AfterCombat(key, fn)
    if not InCombatLockdown() then
        fn()
    else
        combatQueue[key] = fn
    end
end

ns.On("PLAYER_REGEN_ENABLED", function()
    for key, fn in pairs(combatQueue) do
        combatQueue[key] = nil
        SafeCall(fn)
    end
end)

---------------------------------------------------------------------------
-- Recarga
---------------------------------------------------------------------------
StaticPopupDialogs["BLAZZITOUI_RELOAD"] = {
    text = "BlazzitoUI: hay que recargar la interfaz para aplicar este cambio.",
    button1 = "Recargar",
    button2 = "Luego",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function ns.AskReload()
    -- Con el estilo de mando, una ventana de Blizzard abierta desde nuestro
    -- código entra en su navegación con la cruceta (y la contamina): solo chat.
    if ns.Pad and ns.Pad.On() then
        ns.Print("hay que recargar para aplicar este cambio: escribe |cffffffff/reload|r.")
        return
    end
    ns.ShowPopup("BLAZZITOUI_RELOAD")
end

---------------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Perfiles: cada personaje tiene su propia configuración.
--   BlazzitoUIDB = { version = 2, last = clave, profiles = { [clave] = { modules, movers } },
--                    chars = { [clave] = { class, level, seen } } }
-- La clave es "Nombre Apellido" (en Forever varios personajes comparten nombre
-- y reino). ns.db es el perfil de este personaje. La página Perfiles
-- (Profiles.lua) copia, exporta e importa perfiles.
---------------------------------------------------------------------------
local function DeepCopy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = DeepCopy(v) end
    return out
end
ns.DeepCopy = DeepCopy

function ns.CharacterKey()
    local getName = UnitNameUnmodified or UnitName
    local name, surname = getName("player")
    if surname == "" then surname = nil end
    name = name or "Personaje"
    if surname then return name .. " " .. surname end
    local realm = GetRealmName and GetRealmName()
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

local function OpenDatabase()
    local root = BlazzitoUIDB or {}
    local legacy
    if type(root.profiles) ~= "table" then
        -- Versión 1: una sola configuración en la raíz, compartida por todos.
        -- Pasa a ser el perfil de este personaje (y la base de los demás).
        if next(root) then legacy = root end
        root = { profiles = {}, chars = {} }
    end
    root.chars = root.chars or {}
    local key = ns.CharacterKey()
    if type(root.profiles[key]) ~= "table" then
        if legacy then
            root.profiles[key] = legacy
        elseif root.last and type(root.profiles[root.last]) == "table" then
            -- Personaje nuevo: empieza con la configuración del último que entró.
            root.profiles[key] = DeepCopy(root.profiles[root.last])
            ns.profileCreatedFrom = root.last
        else
            root.profiles[key] = {}
        end
    end
    root.version, root.last = 2, key
    BlazzitoUIDB = root
    ns.root, ns.charKey = root, key
    return root.profiles[key]
end

ns.On("ADDON_LOADED", function(_, name)
    if name ~= ADDON_NAME then return end
    ns.db = OpenDatabase()
    ns.ApplyLocale()
    ns.db.movers = ns.db.movers or {}
    MergeDefaults(ns.db.movers, ns.Movers.DEFAULTS)
    ns.db.modules = ns.db.modules or {}
    for _, key in ipairs(ns.moduleOrder) do InitModule(ns.modules[key]) end
    if ns.BuildOptions then ns.BuildOptions() end
end)

-- Los módulos de addons aparte se preparan en su propio ADDON_LOADED.
ns.On("ADDON_LOADED", function()
    for _, key in ipairs(ns.moduleOrder) do
        local module = ns.modules[key]
        if module.pendingInit and not module.db then
            module.pendingInit = nil
            InitModule(module)
            -- Cargado bajo demanda después de entrar al juego: se activa ya.
            if ns.loggedIn then EnableModule(module) end
        end
    end
end)

ns.On("PLAYER_LOGIN", function()
    ns.loggedIn = true
    -- Datos del personaje para la lista de perfiles (color de clase, nivel).
    local class = select(2, UnitClass("player"))
    ns.root.chars[ns.charKey] = { class = class, level = UnitLevel("player"), seen = time and time() or 0 }
    for _, key in ipairs(ns.moduleOrder) do
        local module = ns.modules[key]
        if module.db then EnableModule(module) end
    end
end)

---------------------------------------------------------------------------
-- Comandos: /bui  (alias /blazzitoui)
---------------------------------------------------------------------------
-- Los módulos pueden añadir sus propios subcomandos: /bui <nombre>.
ns.commands = {}
function ns.RegisterCommand(name, fn, help)
    ns.commands[name] = { fn = fn, help = help }
end

SLASH_BLAZZITOUI1 = "/bui"
SLASH_BLAZZITOUI2 = "/blazzitoui"
SlashCmdList["BLAZZITOUI"] = function(msg)
    local cmd = strlower(strtrim(msg or ""))
    -- Comando con argumento: "/bui ventanas personaje" -> ventanas("personaje").
    local first, rest = cmd:match("^(%S+)%s+(.+)$")
    if ns.commands[cmd] then
        ns.commands[cmd].fn()
    elseif first and ns.commands[first] then
        ns.commands[first].fn(rest)
    elseif cmd == "mover" or cmd == "move" then
        ns.Movers.Toggle()
    elseif cmd == "reset" then
        ns.Movers.ResetAll()
    elseif cmd == "help" or cmd == "?" then
        ns.Print("comandos:")
        print("  /bui          " .. ns.L["abre las opciones"])
        print("  /bui mover    " .. ns.L["desbloquea o bloquea los marcos para moverlos"])
        print("  /bui reset    " .. ns.L["devuelve los marcos a su posición inicial"])
        for name, command in pairs(ns.commands) do
            if command.help then print("  /bui " .. name .. "    " .. ns.Translate(command.help)) end
        end
    else
        ns.OpenOptions()
    end
end
