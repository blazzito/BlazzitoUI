-- Blazzito_Setup: copia los ajustes del JUEGO de tu main a tus otros personajes
-- (lo que antes hacía el addon Blazz_Setup). Copia: barras de acción activas,
-- mouseover cast y otras opciones de interfaz (CVars), el diseño activo de Edit
-- Mode y la lista de addons activos. No copia atajos de teclado ni macros.
-- La configuración de BlazzitoUI va aparte (perfiles, en la misma página).
--
-- Sus datos son de toda la cuenta, no de un perfil: BlazzitoUIDB.setup =
--   { chars = { [clave] = registro }, applied = { [clave] = main copiado },
--     addonSync = { [clave] = firma }, main = clave | "AUTO", autoApply, copy = {...} }
-- Al entrar por primera vez con Blazz_Setup activo se traen sus datos
-- (BlazzSetupDB) y ese addon se desactiva.
local ADDON_NAME = ...
local ns = BlazzitoUI

local S = ns.NewModule("Setup", "Ajustes del juego", {})
ns.Setup = S

-- Opciones del juego (CVars) que se copian del main. Las que no existan en el
-- cliente se ignoran.
S.CVARS = {
    -- Lanzamiento de hechizos / barras
    "enableMouseoverCast", "autoSelfCast", "lockActionBars", "alwaysShowActionBars",
    "countdownForCooldowns", "ActionButtonUseKeyDown",
    -- Misiones / interacción
    "showQuestLevel", "autoQuestWatch", "instantQuestText", "autoLootDefault",
    "interactOnLeftClick", "autoDismountFlying", "autoClearAFK", "showTutorials",
    -- Marcos de unidad / texto
    "showTargetOfTarget", "statusText", "statusTextDisplay", "showTargetCastbar",
    -- Placas de nombre y nombres
    "nameplateShowEnemies", "nameplateShowFriends", "nameplateShowAll",
    "UnitNameOwn", "UnitNameNPC", "UnitNameEnemyPlayerName", "UnitNameFriendlyPlayerName",
    -- Combate / chat
    "enableFloatingCombatText", "floatingCombatTextCombatDamage", "floatingCombatTextCombatHealing",
    "chatBubbles", "chatBubblesParty",
    -- Cámara
    "cameraDistanceMaxZoomFactor",
    -- Resaltarse a uno mismo
    "findYourselfMode", "findYourselfAnywhere",
}

local OLD_ADDON = "Blazz_Setup"
-- Nunca se desactivan al sincronizar (sin ellos no hay quien sincronice).
local KEEP = { [ADDON_NAME] = true, BlazzitoUI = true }

local function GetCV(name) return ((C_CVar and C_CVar.GetCVar) or GetCVar)(name) end
local function SetCV(name, value) return ((C_CVar and C_CVar.SetCVar) or SetCVar)(name, value) end

local APPLY_DELAY = 1      -- segundos tras entrar antes de aplicar
local LAYOUT_POLL = 0.25   -- cada cuánto se revisa si Edit Mode ya cargó
local LAYOUT_TIMEOUT = 60  -- segundos máximos esperando a Edit Mode

local db               -- BlazzitoUIDB.setup
local pendingApply     -- main a aplicar al salir de combate
local applying         -- esperando a que Edit Mode termine de cargar

-- Aviso al chat (traducido): Print("texto") o Print("texto con %s", valor).
local function Print(msg, ...)
    local text = select("#", ...) > 0 and ns.LF(msg, ...) or ns.Translate(msg)
    ns.Print(ns.Translate("ajustes del juego: ") .. text)
end
local Tr, LF = ns.Translate, ns.LF

local function Me() return ns.charKey end

local function PlayerIdentity()
    local getName = UnitNameUnmodified or UnitName
    local name, surname = getName("player")
    if surname == "" then surname = nil end
    return name, surname
end

local function FullName(rec)
    if not rec then return "?" end
    local name = rec.name or "?"
    return rec.surname and (name .. " " .. rec.surname) or name
end

function S.ColoredName(rec)
    if not rec then return "?" end
    local c = RAID_CLASS_COLORS and rec.class and RAID_CLASS_COLORS[rec.class]
    if c then
        return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, FullName(rec))
    end
    return FullName(rec)
end
local ColoredName = S.ColoredName

---------------------------------------------------------------------------
-- Edit Mode
---------------------------------------------------------------------------
local function GetActiveLayoutName()
    if not (EditModeManagerFrame and EditModeManagerFrame.GetActiveLayoutInfo) then return nil end
    local ok, info = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
    if ok and type(info) == "table" then return info.layoutName end
end

-- true si terminó (aplicado o ya activo); false si Edit Mode aún no está listo.
local function TryApplyLayout(name)
    if not (C_EditMode and C_EditMode.SetActiveLayout) then return true end
    if not (EditModeManagerFrame and EditModeManagerFrame.layoutInfo) then return false end
    local ok, layouts = pcall(EditModeManagerFrame.GetLayouts, EditModeManagerFrame)
    if not ok or type(layouts) ~= "table" or #layouts == 0 then return false end
    if GetActiveLayoutName() == name then return true end
    for index, layout in ipairs(layouts) do
        if layout.layoutName == name then
            pcall(C_EditMode.SetActiveLayout, index)
            return true
        end
    end
    Print("no encontré el diseño de Edit Mode '%s' (puede ser un diseño solo del main).", tostring(name))
    return true
end

local function WaitForLayout(name, onDone)
    local started = GetTime()
    local ticker
    local function attempt()
        local done = not InCombatLockdown() and TryApplyLayout(name)
        if done or GetTime() - started >= LAYOUT_TIMEOUT then
            if ticker then ticker:Cancel() end
            onDone(done)
            return true
        end
    end
    if not attempt() then
        ticker = C_Timer.NewTicker(LAYOUT_POLL, attempt)
    end
end

---------------------------------------------------------------------------
-- Addons activos
---------------------------------------------------------------------------
-- { [nombre] = activo } para este personaje. Quedan fuera los seguros de
-- Blizzard y los que no se deben desactivar nunca (KEEP).
local function ReadAddonStates()
    if not (C_AddOns and C_AddOns.GetNumAddOns) then return nil end
    local char = UnitName("player")
    local states = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, _, _, _, _, security = C_AddOns.GetAddOnInfo(i)
        if name and not KEEP[name] and security ~= "SECURE" then
            states[name] = (C_AddOns.GetAddOnEnableState(name, char) or 0) > 0
        end
    end
    return states
end

local function AddonSignature(states)
    local parts = {}
    for name, enabled in pairs(states) do
        parts[#parts + 1] = name .. (enabled and "=1" or "=0")
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

-- Deja los addons de este personaje como en el main (los que el main no conoce
-- no se tocan). Devuelve cuántos cambiaron; hace falta recargar.
local function SyncAddons(src)
    local wanted = src.settings.addons
    local current = ReadAddonStates()
    if not (wanted and current) then return 0 end

    local char = UnitName("player")
    local enabled, disabled = {}, {}
    for name, isEnabled in pairs(current) do
        local want = wanted[name]
        if want == true and not isEnabled then
            C_AddOns.EnableAddOn(name, char)
            enabled[#enabled + 1] = name
        elseif want == false and isEnabled then
            C_AddOns.DisableAddOn(name, char)
            disabled[#disabled + 1] = name
        end
    end

    local changed = #enabled + #disabled
    if changed > 0 then
        C_AddOns.SaveAddOns()
        local after = ReadAddonStates()
        for name, want in pairs(wanted) do
            if after[name] ~= nil and after[name] ~= want then
                -- Sin firma guardada: se reintenta en el próximo inicio de sesión.
                Print("no pude cambiar el addon '%s'; usa la lista de addons del juego.", name)
                return 0
            end
        end
        table.sort(enabled)
        table.sort(disabled)
        if #disabled > 0 then Print("addons desactivados como en el main: %s", table.concat(disabled, ", ")) end
        if #enabled > 0 then Print("addons activados como en el main: %s", table.concat(enabled, ", ")) end
    end
    db.addonSync[Me()] = AddonSignature(wanted)
    return changed
end

---------------------------------------------------------------------------
-- Guardar / aplicar
---------------------------------------------------------------------------
local function PackBars()
    if not GetActionBarToggles then return nil end
    local vals = { GetActionBarToggles() }
    local t = { n = select("#", GetActionBarToggles()) }
    for i = 1, t.n do t[i] = vals[i] and true or false end
    return t
end

local function Snapshot()
    local s = { cvars = {} }
    for _, name in ipairs(S.CVARS) do
        local ok, v = pcall(GetCV, name)
        if ok and v ~= nil then s.cvars[name] = v end
    end
    local ok, bars = pcall(GetCV, "enableMultiActionBars")
    if ok then s.barsCVar = bars end
    s.bars = PackBars()
    s.editMode = GetActiveLayoutName()
    s.addons = ReadAddonStates()
    return s
end

function S.UpdateRecord(saveSettings)
    local key = Me()
    local rec = db.chars[key] or {}
    rec.name, rec.surname = PlayerIdentity()
    rec.realm = GetRealmName and GetRealmName() or rec.realm
    rec.className, rec.class = UnitClass("player")
    if UnitRace then rec.raceName, rec.raceFile = UnitRace("player") end
    rec.level = UnitLevel("player")
    rec.updated = time and time() or 0
    if saveSettings then rec.settings = Snapshot() end
    db.chars[key] = rec
end

-- El main: el fijado a mano o, en automático, el de nivel más alto con datos.
function S.MainKey()
    if db.main ~= "AUTO" and db.chars[db.main] and db.chars[db.main].settings then
        return db.main
    end
    local best, bestRec
    for key, rec in pairs(db.chars) do
        if rec.settings then
            local lvl, bestLvl = rec.level or 0, bestRec and bestRec.level or -1
            if lvl > bestLvl or (lvl == bestLvl and (rec.updated or 0) > (bestRec.updated or 0)) then
                best, bestRec = key, rec
            end
        end
    end
    return best
end

StaticPopupDialogs["BLAZZITOUI_SETUP_RELOAD"] = {
    text = "BlazzitoUI: se aplicaron los ajustes del juego de %s.\n\n¿Recargar la interfaz para que todo se vea bien?",
    button1 = "Recargar",
    button2 = "Luego",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function FinishApply(sourceKey, layoutApplied)
    applying = false
    if layoutApplied then
        local src = db.chars[sourceKey]
        db.applied[Me()] = sourceKey
        Print("ajustes de %s aplicados.", ColoredName(src))
        ns.ShowPopup("BLAZZITOUI_SETUP_RELOAD", ColoredName(src))
    else
        -- No se marca como aplicado: se reintenta en el próximo inicio de sesión.
        Print("Edit Mode no terminó de cargar; lo reintentaré al volver a entrar (o pulsa «Aplicar ahora» en Perfiles).")
    end
    if ns.Config.RefreshCurrent then ns.Config.RefreshCurrent() end
end

function S.Apply(sourceKey)
    if applying then return end
    local src = sourceKey and db.chars[sourceKey]
    local s = src and src.settings
    if not s then
        Print("no hay ajustes guardados del main. Entra una vez con tu main (o usa «Usar este personaje como main» en él).")
        return
    end
    if sourceKey == Me() then
        Print("este personaje ya es el main, no hay nada que copiar.")
        return
    end
    if InCombatLockdown() then
        pendingApply = sourceKey
        Print("estás en combate; los aplicaré al salir.")
        return
    end

    if db.copy.cvars then
        for name, v in pairs(s.cvars) do pcall(SetCV, name, v) end
    end
    if db.copy.bars then
        if s.barsCVar then pcall(SetCV, "enableMultiActionBars", s.barsCVar) end
        if s.bars and SetActionBarToggles then
            pcall(SetActionBarToggles, unpack(s.bars, 1, s.bars.n))
        end
        if MultiActionBar_Update then pcall(MultiActionBar_Update) end
    end
    if db.copy.addons then
        SyncAddons(src)
    end
    if db.copy.editmode and s.editMode then
        applying = true
        WaitForLayout(s.editMode, function(done) FinishApply(sourceKey, done) end)
    else
        FinishApply(sourceKey, true)
    end
end

local function AutoApply()
    if not db.autoApply then return end
    local me = Me()
    local mainKey = S.MainKey()
    if not mainKey or mainKey == me then return end
    -- Ya recibió los ajustes de este mismo main: no se vuelven a pisar. En
    -- automático solo se copia a personajes de menor nivel que el main.
    local tooHigh = db.main == "AUTO" and (db.chars[me].level or 0) >= (db.chars[mainKey].level or 0)
    if db.applied[me] ~= mainKey and not tooHigh then
        S.Apply(mainKey)
        return
    end
    -- Los addons se sincronizan solo cuando el main cambia su lista: así se
    -- respetan los cambios hechos aquí y no hay recargas en bucle.
    local src = db.chars[mainKey]
    local wanted = src.settings.addons
    if db.copy.addons and wanted and db.addonSync[me] ~= AddonSignature(wanted) then
        if SyncAddons(src) > 0 then
            ns.ShowPopup("BLAZZITOUI_SETUP_RELOAD", ColoredName(src))
        end
    end
end

function S.SetMain()
    S.UpdateRecord(true)
    db.main = Me()
    Print("%s es ahora tu main. Sus ajustes se copiarán a los demás personajes.", ColoredName(db.chars[db.main]))
end

function S.SetAuto()
    db.main = "AUTO"
    local key = S.MainKey()
    if key then
        Print("modo automático: el main será tu personaje de nivel más alto (ahora: %s).", ColoredName(db.chars[key]))
    else
        Print("modo automático: el main será tu personaje de nivel más alto.")
    end
end

---------------------------------------------------------------------------
-- Datos y paso desde Blazz_Setup
---------------------------------------------------------------------------
local function OpenData()
    local root = ns.root
    root.setup = root.setup or {}
    db = root.setup
    S.data = db
    db.chars = db.chars or {}
    db.applied = db.applied or {}
    db.addonSync = db.addonSync or {}
    db.main = db.main or "AUTO"
    if db.autoApply == nil then db.autoApply = true end
    db.copy = db.copy or {}
    for _, k in ipairs({ "bars", "cvars", "editmode", "addons" }) do
        if db.copy[k] == nil then db.copy[k] = true end
    end
end

-- Datos de Blazz_Setup (BlazzSetupDB: este addon declara la misma variable y
-- su archivo de guardado se copió del viejo). Se traen una vez y la variable
-- se vacía. Si Blazz_Setup sigue instalado y activo, se desactiva para toda la
-- cuenta. Devuelve true si estaba cargado en esta sesión.
local function AdoptOldAddon()
    local old = BlazzSetupDB
    if type(old) == "table" and not db.imported then
        for _, k in ipairs({ "chars", "applied", "addonSync" }) do
            if type(old[k]) == "table" then
                for key, value in pairs(old[k]) do
                    if db[k][key] == nil then db[k][key] = value end
                end
            end
        end
        if old.main then db.main = old.main end
        if old.autoApply ~= nil then db.autoApply = old.autoApply end
        if type(old.copy) == "table" then
            for k, v in pairs(old.copy) do db.copy[k] = v end
        end
        db.imported = true
        Print("traje tus personajes y tu main de Blazz_Setup.")
    end
    BlazzSetupDB = nil
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
    if not (isLoaded and isLoaded(OLD_ADDON)) then return false end
    if C_AddOns.DisableAddOn then
        C_AddOns.DisableAddOn(OLD_ADDON)   -- sin personaje: para toda la cuenta
        if C_AddOns.SaveAddOns then C_AddOns.SaveAddOns() end
    end
    Print("Blazz_Setup ahora es parte de BlazzitoUI (página Perfiles). Traje sus datos y lo desactivé; recarga para terminar.")
    ns.AskReload()
    return true
end

---------------------------------------------------------------------------
-- Ciclo de vida
---------------------------------------------------------------------------
function S:OnInitialize()
    OpenData()
end

function S:OnEnable()
    local oldActive = AdoptOldAddon()
    S.UpdateRecord(false)

    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_LEVEL_UP")
    events:RegisterEvent("PLAYER_LOGOUT")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    events:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_LEVEL_UP" then
            S.UpdateRecord(false)
            db.chars[Me()].level = arg1 or UnitLevel("player")
        elseif event == "PLAYER_LOGOUT" then
            -- Guarda los ajustes de este personaje (también al recargar).
            S.UpdateRecord(true)
        elseif event == "PLAYER_REGEN_ENABLED" and pendingApply then
            local key = pendingApply
            pendingApply = nil
            S.Apply(key)
        end
    end)
    -- Con Blazz_Setup aún cargado, él ya aplicó en esta sesión.
    if not oldActive and C_Timer then C_Timer.After(APPLY_DELAY, AutoApply) end

    -- /blazz y /bsetup siguen funcionando: abren la página Perfiles.
    SLASH_BLAZZSETUP1 = "/blazz"
    SLASH_BLAZZSETUP2 = "/bsetup"
    SlashCmdList["BLAZZSETUP"] = function(msg)
        local cmd = strlower(strtrim(msg or ""))
        if cmd == "set" then
            S.SetMain()
        elseif cmd == "auto" then
            S.SetAuto()
        elseif cmd == "apply" then
            S.Apply(S.MainKey())
        elseif cmd == "save" then
            S.UpdateRecord(true)
            Print("ajustes de este personaje guardados.")
        else
            ns.Config.Open("profiles")
        end
    end
end

---------------------------------------------------------------------------
-- Tarjeta en la página Perfiles
---------------------------------------------------------------------------
local function CharacterLines()
    local keys = {}
    for key in pairs(db.chars) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b)
        local la, lb = db.chars[a].level or 0, db.chars[b].level or 0
        if la ~= lb then return la > lb end
        return a < b
    end)
    local mainKey, lines = S.MainKey(), {}
    for _, key in ipairs(keys) do
        local rec = db.chars[key]
        local tags = {}
        if key == mainKey then tags[#tags + 1] = "|cffffd100[main]|r" end
        if key == Me() then tags[#tags + 1] = "|cff33ff99" .. Tr("[actual]") .. "|r" end
        if not rec.settings then tags[#tags + 1] = "|cff888888" .. Tr("(sin ajustes guardados)") .. "|r" end
        local source = db.chars[db.applied[key] or ""]
        if source then tags[#tags + 1] = "|cff888888" .. LF("copiado de %s", FullName(source)) .. "|r" end
        lines[#lines + 1] = ColoredName(rec) .. " |cff999999" .. LF("(nivel %s)", rec.level or "?") .. "|r  " .. table.concat(tags, " ")
    end
    return #lines > 0 and table.concat(lines, "\n") or Tr("(ninguno todavía)")
end

local function MainText()
    local mainKey = S.MainKey()
    local rec = mainKey and db.chars[mainKey]
    local mode = "|cff888888" .. Tr(db.main == "AUTO" and "(automático: el de nivel más alto)" or "(fijado a mano)") .. "|r"
    if rec then
        return "Main: " .. ColoredName(rec) .. " |cff999999" .. LF("(nivel %s)", rec.level or "?") .. "|r  " .. mode
    end
    return "Main: |cffff5555" .. Tr("ninguno todavía") .. "|r  " .. mode
end

if ns.Profiles and ns.Profiles.AddCard then
    ns.Profiles.AddCard(function(L, content, col)
        local W = ns.Widgets
        if not db then return end
        local function copyGet(key) return function() return db.copy[key] end end
        local function copySet(key) return function(value) db.copy[key] = value end end

        L:Card("Ajustes del juego (de tu main)")
        L:Note("Copia de tu main a tus otros personajes las opciones del juego que no son de BlazzitoUI: barras de acción activas, mouseover y otras opciones de interfaz, el diseño de Edit Mode y los addons activos. No copia atajos de teclado ni macros.")
        local main = L:Note(MainText())
        L:Row(W.Button(content, col, "Usar este personaje como main", function()
                  S.SetMain()
                  L:Refresh()
              end),
              W.Button(content, col, "Automático (nivel más alto)", function()
                  S.SetAuto()
                  L:Refresh()
              end))
        L:Row(W.Toggle(content, col, "Aplicar al entrar con otro personaje",
                  function() return db.autoApply end, function(value) db.autoApply = value end))
        L:Row(W.Toggle(content, col, "Barras de acción activas", copyGet("bars"), copySet("bars")),
              W.Toggle(content, col, "Mouseover y opciones de interfaz", copyGet("cvars"), copySet("cvars")))
        L:Row(W.Toggle(content, col, "Diseño de Edit Mode", copyGet("editmode"), copySet("editmode")),
              W.Toggle(content, col, "Addons activos", copyGet("addons"), copySet("addons")))
        L:Row(W.Button(content, col, "Aplicar ahora los del main", function() S.Apply(S.MainKey()) end, true),
              W.Button(content, col, "Guardar los de este personaje", function()
                  S.UpdateRecord(true)
                  Print("ajustes de este personaje guardados.")
                  L:Refresh()
              end))
        L:Note("Los ajustes de cada personaje se guardan solos al salir o recargar. Los addons se vuelven a sincronizar cuando el main cambia su lista.")
        local list = L:Note(CharacterLines())
        L:EndCard()

        return function()
            main:SetText(MainText())
            list:SetText(CharacterLines())
        end
    end)
end
