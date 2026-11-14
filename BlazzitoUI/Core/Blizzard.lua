-- Convivencia con la interfaz de Blizzard: ocultar sus marcos sin "taint"
-- y abrir el menú de unidad con clic derecho.
local _, ns = ...

---------------------------------------------------------------------------
-- Ocultar marcos de Blizzard
---------------------------------------------------------------------------
-- El marco pierde sus eventos y pasa a un padre oculto. Edit Mode y otros
-- sistemas pueden devolverlo a su sitio con SetParent; en ese caso se vuelve a
-- esconder en el siguiente fotograma, nunca dentro de la llamada de Blizzard,
-- porque hacerlo ahí contaminaría su ejecución segura.
local hiddenParent = CreateFrame("Frame", "BlazzitoUIHiddenParent", UIParent)
hiddenParent:Hide()

-- Con el estilo de mando (Pad.lua), algunos marcos de Blizzard tienen que
-- seguir "visibles" para su navegación: el objetivo (el botón Y abre su menú y
-- el menú se cierra si su dueño no se ve) y los de grupo (la cruceta los
-- recorre al elegir aliados). Esos van a un soporte mostrado con alfa 0.
local padHolder
local function PadHolder()
    if not padHolder then
        padHolder = CreateFrame("Frame", "BlazzitoUIPadHolder", UIParent)
        padHolder:SetAllPoints(UIParent)
        padHolder:SetAlpha(0)
        padHolder:EnableMouse(false)
    end
    return padHolder
end

local hooked, pending = {}, {}
local parkTo = setmetatable({}, { __mode = "k" })   -- marco -> su padre (si no es el oculto)

local function Destination(frame)
    return parkTo[frame] or hiddenParent
end

local function Park(frame)
    pending[frame] = nil
    if frame:GetParent() == Destination(frame) then return end
    if EditModeManagerFrame and EditModeManagerFrame:IsShown() then
        pending[frame] = true
        C_Timer.After(0.25, function() Park(frame) end)
    elseif InCombatLockdown() and frame:IsProtected() then
        ns.AfterCombat(frame, function() Park(frame) end)
    else
        frame:SetParent(Destination(frame))
    end
end

local CHILDREN = { "healthbar", "manabar", "spellbar", "totFrame", "HealthBar", "ManaBar" }

-- opts.padVisible: con el estilo de mando, el marco queda en el soporte
-- invisible con sus eventos (Blizzard lo sigue mostrando y ocultando).
-- opts.noMouse: además sin ratón (invisible no debe tapar clics).
function ns.HideBlizzardFrame(frame, opts)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame then return end
    local padVisible = opts and opts.padVisible and ns.Pad and ns.Pad.Session()
    if padVisible then
        parkTo[frame] = PadHolder()
        if opts.noMouse and not (InCombatLockdown() and frame:IsProtected()) then
            frame:EnableMouse(false)
            local tot = frame.totFrame
            if type(tot) == "table" and tot.EnableMouse then tot:EnableMouse(false) end
        end
    else
        frame:UnregisterAllEvents()
        for _, key in ipairs(CHILDREN) do
            local child = frame[key]
            if type(child) == "table" and child.UnregisterAllEvents then child:UnregisterAllEvents() end
        end
        if not (InCombatLockdown() and frame:IsProtected()) then frame:Hide() end
    end
    Park(frame)
    if not hooked[frame] then
        hooked[frame] = true
        hooksecurefunc(frame, "SetParent", function(self, parent)
            if parent ~= Destination(self) and not pending[self] then
                pending[self] = true
                C_Timer.After(0, function() Park(self) end)
            end
        end)
    end
end

-- Más suave que HideBlizzardFrame: el marco se queda en su sitio (lo gestiona
-- Edit Mode) pero sin eventos ya no se muestra. Para las barras de lanzamiento.
function ns.SilenceBlizzardFrame(frame)
    if type(frame) == "string" then frame = _G[frame] end
    if not frame then return end
    frame:UnregisterAllEvents()
    if not (InCombatLockdown() and frame:IsProtected()) then frame:Hide() end
end

---------------------------------------------------------------------------
-- Menú de clic derecho
---------------------------------------------------------------------------
-- En el motor 12.1 "togglemenu" puesto directamente en un botón de unidad no
-- abre el menú. Rodeo: un botón seguro invisible que sí lo abre, y el clic
-- derecho del marco lo pulsa con una macro "/click".
local proxyCount = 0

function ns.AttachUnitMenu(button)
    proxyCount = proxyCount + 1
    local name = "BlazzitoUIMenuProxy" .. proxyCount
    local proxy = CreateFrame("Button", name, button, "SecureActionButtonTemplate")
    proxy:SetAllPoints(button)
    proxy:EnableMouse(false)
    proxy:RegisterForClicks("AnyUp")
    proxy:SetAttribute("type", "togglemenu")
    for i = 1, 5 do proxy:SetAttribute("type" .. i, "togglemenu") end
    proxy:SetAttribute("useparent-unit", true)
    proxy:SetAttribute("useOnKeyDown", false)

    button:SetAttribute("*type2", "macro")
    button:SetAttribute("*macrotext2", "/click " .. name)
end
