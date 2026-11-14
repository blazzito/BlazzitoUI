-- Perfiles: copiar la configuración de otro de tus personajes, exportarla
-- entera como JSON e importarla pegando ese JSON. Todo cambio de perfil se
-- aplica recargando la interfaz (los módulos leen su configuración al cargar).
-- La estructura de BlazzitoUIDB está explicada en Core.lua (OpenDatabase).
local ADDON_NAME, ns = ...

local M = ns.Media
local W = ns.Widgets
local P = {}
ns.Profiles = P

local FORMAT = 1

---------------------------------------------------------------------------
-- JSON (propio, sin librerías). Las tablas con claves 1..n son listas; las
-- demás, objetos con las claves ordenadas. Las claves numéricas sueltas se
-- escriben como texto y al leer vuelven a ser números.
---------------------------------------------------------------------------
local JSON = {}
P.JSON = JSON

local ESCAPES = { ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }

local function EncodeString(s)
    return '"' .. s:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or string.format("\\u%04x", c:byte())
    end) .. '"'
end

local function IsList(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    for i = 1, n do
        if t[i] == nil then return false end
    end
    return true, n
end

local function Encode(value, out, seen)
    local kind = type(value)
    if kind == "table" then
        if seen[value] then error("tabla repetida (ciclo)") end
        seen[value] = true
        local list, n = IsList(value)
        if list and n > 0 then
            out[#out + 1] = "["
            for i = 1, n do
                if i > 1 then out[#out + 1] = "," end
                Encode(value[i], out, seen)
            end
            out[#out + 1] = "]"
        else
            local keys = {}
            for k, v in pairs(value) do
                local kt, vt = type(k), type(v)
                if (kt == "string" or kt == "number") and vt ~= "function" and vt ~= "userdata" and vt ~= "thread" then
                    keys[#keys + 1] = k
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            out[#out + 1] = "{"
            for i, k in ipairs(keys) do
                if i > 1 then out[#out + 1] = "," end
                out[#out + 1] = EncodeString(tostring(k))
                out[#out + 1] = ":"
                Encode(value[k], out, seen)
            end
            out[#out + 1] = "}"
        end
        seen[value] = nil
    elseif kind == "string" then
        out[#out + 1] = EncodeString(value)
    elseif kind == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            out[#out + 1] = "0"
        elseif value == math.floor(value) and math.abs(value) < 1e15 then
            out[#out + 1] = string.format("%d", value)
        else
            out[#out + 1] = string.format("%.14g", value)
        end
    elseif kind == "boolean" then
        out[#out + 1] = value and "true" or "false"
    else
        out[#out + 1] = "null"
    end
end

function JSON.Encode(value)
    local out = {}
    Encode(value, out, {})
    return table.concat(out)
end

local function Utf8(code)
    if code < 0x80 then return string.char(code) end
    if code < 0x800 then return string.char(0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40) end
    return string.char(0xE0 + math.floor(code / 0x1000), 0x80 + math.floor(code / 0x40) % 0x40, 0x80 + code % 0x40)
end

function JSON.Decode(text)
    local pos = 1
    local function Fail(msg) error(string.format("%s (carácter %d)", msg, pos), 0) end
    local function Skip()
        pos = text:find("[^ \t\r\n]", pos) or (#text + 1)
    end
    local Value

    local function String()
        pos = pos + 1   -- comilla
        local parts = {}
        while true do
            local c = text:sub(pos, pos)
            if c == "" then Fail("texto sin cerrar") end
            if c == '"' then pos = pos + 1; break end
            if c == "\\" then
                local e = text:sub(pos + 1, pos + 1)
                if e == "u" then
                    local hex = text:sub(pos + 2, pos + 5)
                    if not hex:match("^%x%x%x%x$") then Fail("\\u mal escrito") end
                    parts[#parts + 1] = Utf8(tonumber(hex, 16))
                    pos = pos + 6
                else
                    local map = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }
                    if not map[e] then Fail("escape desconocido") end
                    parts[#parts + 1] = map[e]
                    pos = pos + 2
                end
            else
                local stop = text:find('["\\]', pos) or (#text + 1)
                parts[#parts + 1] = text:sub(pos, stop - 1)
                pos = stop
            end
        end
        return table.concat(parts)
    end

    function Value()
        Skip()
        local c = text:sub(pos, pos)
        if c == "{" then
            pos = pos + 1
            local obj = {}
            Skip()
            if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
            while true do
                Skip()
                if text:sub(pos, pos) ~= '"' then Fail("se esperaba una clave") end
                local key = String()
                Skip()
                if text:sub(pos, pos) ~= ":" then Fail("se esperaban dos puntos") end
                pos = pos + 1
                local v = Value()
                if key:match("^%-?%d+$") then key = tonumber(key) end
                obj[key] = v
                Skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "}" then return obj end
                if d ~= "," then pos = pos - 1; Fail("se esperaba , o }") end
            end
        elseif c == "[" then
            pos = pos + 1
            local list, n = {}, 0
            Skip()
            if text:sub(pos, pos) == "]" then pos = pos + 1; return list end
            while true do
                n = n + 1   -- índice propio: un null deja su hueco
                list[n] = Value()
                Skip()
                local d = text:sub(pos, pos)
                pos = pos + 1
                if d == "]" then return list end
                if d ~= "," then pos = pos - 1; Fail("se esperaba , o ]") end
            end
        elseif c == '"' then
            return String()
        elseif text:sub(pos, pos + 3) == "true" then
            pos = pos + 4; return true
        elseif text:sub(pos, pos + 4) == "false" then
            pos = pos + 5; return false
        elseif text:sub(pos, pos + 3) == "null" then
            pos = pos + 4; return nil
        else
            local num = text:match("^-?%d+%.?%d*[eE]?[-+]?%d*", pos)
            if not num or num == "" or num == "-" then Fail("valor no válido") end
            pos = pos + #num
            local n = tonumber(num)
            if not n then Fail("número no válido") end
            return n
        end
    end

    local result = Value()
    Skip()
    if pos <= #text then Fail("sobra texto al final") end
    return result
end

---------------------------------------------------------------------------
-- Operaciones (todas acaban recargando)
---------------------------------------------------------------------------
local function Reload()
    if ReloadUI then ReloadUI() end
end

function P.Others()
    local list = {}
    for key in pairs(ns.root.profiles) do
        if key ~= ns.charKey then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

function P.Colored(key)
    local info = ns.root.chars[key]
    local color = info and info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
    local text = key
    if color then
        text = string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, key)
    end
    if info and info.level then text = text .. " |cff999999(nivel " .. info.level .. ")|r" end
    return text
end

function P.CopyFrom(key)
    local source = ns.root.profiles[key]
    if type(source) ~= "table" or key == ns.charKey then return false end
    ns.root.profiles[ns.charKey] = ns.DeepCopy(source)
    Reload()
    return true
end

function P.Delete(key)
    if key == ns.charKey or not ns.root.profiles[key] then return false end
    ns.root.profiles[key] = nil
    ns.root.chars[key] = nil
    if ns.root.last == key then ns.root.last = ns.charKey end
    return true
end

function P.Reset()
    ns.root.profiles[ns.charKey] = {}
    Reload()
end

function P.Export()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return JSON.Encode({
        addon = "BlazzitoUI",
        format = FORMAT,
        version = getMetadata and getMetadata(ADDON_NAME, "Version") or nil,
        character = ns.charKey,
        date = date and date("%Y-%m-%d %H:%M") or nil,
        profile = ns.db,
    })
end

-- Comprueba el texto sin aplicar nada. Devuelve los datos o nil y el motivo.
function P.Parse(text)
    text = (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return nil, "No hay nada pegado." end
    local ok, data = pcall(JSON.Decode, text)
    if not ok then return nil, "El texto no es un JSON válido: " .. tostring(data) end
    if type(data) ~= "table" or data.addon ~= "BlazzitoUI" or type(data.profile) ~= "table" then
        return nil, "Ese JSON no es una exportación de BlazzitoUI."
    end
    if type(data.profile.modules) ~= "table" then
        return nil, "La exportación no trae la configuración de los módulos."
    end
    return data
end

function P.Import(data)
    ns.root.profiles[ns.charKey] = data.profile
    Reload()
end

---------------------------------------------------------------------------
-- Confirmaciones
---------------------------------------------------------------------------
StaticPopupDialogs["BLAZZITOUI_PROFILE_CONFIRM"] = {
    text = "%s",
    button1 = "Aceptar",
    button2 = "Cancelar",
    OnAccept = function(_, action) if action then action() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Confirm(text, action)
    StaticPopup_Show("BLAZZITOUI_PROFILE_CONFIRM", text, nil, action)
end

---------------------------------------------------------------------------
-- Ventana con el texto para exportar o importar
---------------------------------------------------------------------------
local box

local function TextWindow()
    if box then return box end
    local win = CreateFrame("Frame", "BlazzitoUIProfileText", UIParent)
    win:SetSize(640, 440)
    win:SetPoint("CENTER")
    win:SetFrameStrata("DIALOG")
    win:SetToplevel(true)
    win:SetClampedToScreen(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    M.SetBackdrop(win, { 0.07, 0.07, 0.08, 0.98 })
    table.insert(UISpecialFrames, "BlazzitoUIProfileText")

    local a = M.COLORS.accent
    win.title = W.Text(win, 15, a)
    win.title:SetPoint("TOPLEFT", 16, -14)
    win.hint = W.Text(win, 11, W.COLORS.muted)
    win.hint:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -6)
    local close = W.IconButton(win, M.ICONS.close, function() return "Cerrar" end, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -10)

    local scroll = CreateFrame("ScrollFrame", nil, win)
    scroll:SetPoint("TOPLEFT", 16, -60)
    scroll:SetPoint("BOTTOMRIGHT", -34, 52)
    local bg = win:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", scroll, -6, 6)
    bg:SetPoint("BOTTOMRIGHT", scroll, 6, -6)
    bg:SetColorTexture(0.04, 0.04, 0.05, 1)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFont(M.FONT, 11, "")
    edit:SetWidth(580)
    edit:SetMaxLetters(0)
    edit:SetScript("OnEscapePressed", function() win:Hide() end)
    edit:SetScript("OnTextChanged", function(self, user)
        -- Exportar: solo lectura (se puede seleccionar y copiar, no cambiar).
        if user and win.readOnly and self:GetText() ~= win.readOnly then
            self:SetText(win.readOnly)
            self:HighlightText()
        end
        win.status:SetText("")
    end)
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * 60)))
    end)
    -- Clic en cualquier parte del recuadro: el cursor va al texto.
    scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
    W.ScrollBar(scroll, 10)

    win.status = W.Text(win, 12, { 1, 0.45, 0.4 }, true)
    win.status:SetPoint("BOTTOMLEFT", 16, 18)
    win.status:SetPoint("RIGHT", win, "RIGHT", -280, 0)
    win.status:SetJustifyH("LEFT")

    win.action = W.Button(win, 130, "", function() if win.onAction then win.onAction() end end, true, 28)
    win.action:SetPoint("BOTTOMRIGHT", -16, 14)
    win.select = W.Button(win, 120, "Seleccionar todo", function()
        edit:SetFocus()
        edit:HighlightText()
    end, false, 28)
    win.select:SetPoint("RIGHT", win.action, "LEFT", -8, 0)

    win.edit = edit
    win:Hide()
    box = win
    return win
end

function P.ShowExport()
    local win = TextWindow()
    local text = P.Export()
    win.title:SetText("Exportar configuración")
    win.hint:SetText("Todo BlazzitoUI de " .. ns.charKey .. ". Pulsa Ctrl+C para copiarlo (ya está seleccionado).")
    win.readOnly = text
    win.edit:SetText(text)
    win.status:SetText("")
    win.action.text:SetText("Listo")
    win.onAction = function() win:Hide() end
    win:Show()
    win.edit:SetFocus()
    win.edit:HighlightText()
end

function P.ShowImport()
    local win = TextWindow()
    win.title:SetText("Importar configuración")
    win.hint:SetText("Pega aquí (Ctrl+V) un JSON exportado de BlazzitoUI y pulsa Importar. Reemplaza la configuración de " .. ns.charKey .. ".")
    win.readOnly = nil
    win.edit:SetText("")
    win.status:SetText("")
    win.action.text:SetText("Importar")
    win.onAction = function()
        local data, err = P.Parse(win.edit:GetText())
        if not data then
            win.status:SetText(err)
            return
        end
        local from = type(data.character) == "string" and (" (de " .. data.character .. ")") or ""
        win:Hide()
        Confirm("BlazzitoUI: ¿reemplazar toda la configuración de " .. ns.charKey .. " por la importada" .. from
            .. "?\nLa interfaz se recargará.", function() P.Import(data) end)
    end
    win:Show()
    win.edit:SetFocus()
end

---------------------------------------------------------------------------
-- Página "Perfiles"
---------------------------------------------------------------------------
-- Tarjetas de otros módulos (p. ej. Blazzito_Setup): build(L, content, col)
-- y, si devuelve una función, se llama en cada Refresh de la página.
P.cards = {}
function P.AddCard(build)
    P.cards[#P.cards + 1] = build
end

-- Un botón a la altura de los desplegables (que llevan su etiqueta encima).
local function ButtonCell(parent, width, label, onClick, accent)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(width, 46)
    local button = W.Button(cell, width, label, onClick, accent)
    button:SetPoint("BOTTOMLEFT")
    cell.button = button
    function cell:SetActive(active) button:SetActive(active) end
    return cell
end

ns.Config.RegisterPage("profiles", "Perfiles", 90, function(content, width)
    local L = W.Layout(content, width)
    local col = L.innerColumn

    -- Las listas de personajes se rellenan de nuevo en cada Refresh.
    local copyChoices, deleteChoices = {}, {}
    local copySource, deleteTarget
    local function Fill(list, current)
        wipe(list)
        local found
        for i, key in ipairs(P.Others()) do
            list[i] = { value = key, text = P.Colored(key) }
            if key == current then found = true end
        end
        if not found then current = list[1] and list[1].value end
        return current
    end
    local function hasOthers() return #P.Others() > 0 end

    local function WhoText()
        local text = "Estás usando el perfil de " .. P.Colored(ns.charKey) .. "."
        if ns.profileCreatedFrom then
            text = text .. " Se creó copiando el de " .. P.Colored(ns.profileCreatedFrom) .. "."
        end
        return text
    end
    L:Card("Este personaje")
    local who = L:Note(WhoText())
    L:Note("Cada personaje tiene su propia configuración de BlazzitoUI. Un personaje nuevo empieza con la del último que entró al juego; después ya es independiente.")
    L:EndCard()

    L:Card("Copiar de otro personaje")
    local function Help(dd)
        dd.placeholder, dd.emptyText = "Elige un personaje", "No hay otros personajes"
        return dd
    end
    L:Row(Help(W.Dropdown(content, col, "Copiar la configuración de", copyChoices,
              function() copySource = Fill(copyChoices, copySource); return copySource end,
              function(value) copySource = value end)),
          ButtonCell(content, col, "Copiar a este personaje", function()
              if not copySource then return end
              Confirm("BlazzitoUI: ¿copiar toda la configuración de " .. copySource .. " a " .. ns.charKey
                  .. "?\nLa de este personaje se pierde y la interfaz se recargará.", function() P.CopyFrom(copySource) end)
          end, true),
          hasOthers, hasOthers)
    L:Note("Solo aparecen los personajes que ya entraron al juego con BlazzitoUI.")
    L:Row(Help(W.Dropdown(content, col, "Borrar el perfil de", deleteChoices,
              function() deleteTarget = Fill(deleteChoices, deleteTarget); return deleteTarget end,
              function(value) deleteTarget = value end)),
          ButtonCell(content, col, "Borrar perfil", function()
              if not deleteTarget then return end
              Confirm("BlazzitoUI: ¿borrar el perfil de " .. deleteTarget .. "?\n(Si ese personaje vuelve a entrar, empezará con la configuración del último que entró.)",
                  function()
                      P.Delete(deleteTarget)
                      deleteTarget = nil
                      L:Refresh()
                  end)
          end),
          hasOthers, hasOthers)
    L:EndCard()

    L:Card("Exportar e importar")
    L:Note("Exportar genera un JSON con absolutamente toda la configuración de BlazzitoUI (todos los módulos y las posiciones de los marcos). Guárdalo donde quieras o pásaselo a otra persona; al importarlo se pone todo tal cual.")
    L:Row(ButtonCell(content, col, "Exportar (JSON)", P.ShowExport),
          ButtonCell(content, col, "Importar (JSON)", P.ShowImport))
    L:EndCard()

    L:Card("Empezar de cero")
    L:Row(ButtonCell(content, col, "Restablecer este personaje", function()
        Confirm("BlazzitoUI: ¿devolver toda la configuración de " .. ns.charKey .. " a los valores por defecto?\nLa interfaz se recargará.", P.Reset)
    end))
    L:EndCard()

    local refreshers = {}
    for _, build in ipairs(P.cards) do
        local ok, fn = pcall(build, L, content, col)
        if ok and type(fn) == "function" then refreshers[#refreshers + 1] = fn end
        if not ok then geterrorhandler()(fn) end
    end

    -- Los textos de las tarjetas se actualizan con la página.
    local refresh = L.Refresh
    function L:Refresh()
        who:SetText(WhoText())
        for _, fn in ipairs(refreshers) do pcall(fn) end
        refresh(self)
    end
    return L
end)
