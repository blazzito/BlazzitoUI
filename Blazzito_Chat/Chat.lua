-- Blazzito_Chat: el chat de WoW con el estilo de BlazzitoUI. No se sustituye
-- nada: las ventanas, pestañas, canales y el cuadro de escribir siguen siendo
-- los de Blizzard.
--
-- Qué añade:
--  * Aspecto: fondo y borde propios, sin el arte de Blizzard (fondo, marco de
--    las pestañas y del cuadro de escribir) y, si quieres, sin los botones.
--  * Botón de copiar al final de cada mensaje y una ventana de historial para
--    seleccionar y copiar (Ctrl+C: WoW no deja a los addons escribir en el
--    portapapeles ni abrir el navegador).
--  * Enlaces: las direcciones web se pueden pulsar (se muestran para copiar,
--    con aviso de que llevan fuera del juego) y los comandos (/algo) se
--    ejecutan al pulsarlos.
--  * Emoticonos de siempre: :) :( ;) :D :P :O <3 :/
--
-- En WoW Forever reemplazar funciones del chat (AddMessage) "contamina" el
-- manejador seguro de mensajes. Por eso los mensajes se tocan solo con la API
-- oficial de filtros (ChatFrame_AddMessageEventFilter), y los mensajes
-- secretos (bandas, mazmorras, JcJ con el chat restringido) pasan intactos.
local ns = BlazzitoUI
if not ns then return end

local M = ns.Media
local IsSecret = M.IsSecret
local MEDIA = "Interface\\AddOns\\Blazzito_Chat\\Media\\"
local LINK = "addon:BlazzitoUI:"

local CH = ns.NewModule("Chat", "Chat", {
    skin = true, background = 45, border = true, hideButtons = false,
    fontOutline = false,
    copyButtons = true, historyButton = true,
    links = true, commands = true, emotes = true, emoteSize = 0,
})
ns.Chat = CH

---------------------------------------------------------------------------
-- Datos propios (nunca se escribe en los marcos de Blizzard)
---------------------------------------------------------------------------
local held = setmetatable({}, { __mode = "k" })
local hooked = setmetatable({}, { __mode = "k" })
local ours = setmetatable({}, { __mode = "k" })   -- marco de chat -> nuestras piezas
CH.ours = ours

local function Hold(region, hide)
    if type(region) ~= "table" or not region.SetAlpha then return end
    if hide then
        held[region] = true
        if not hooked[region] then
            hooked[region] = true
            hooksecurefunc(region, "SetAlpha", function(self, alpha)
                if held[self] and (IsSecret(alpha) or alpha ~= 0) then self:SetAlpha(0) end
            end)
        end
        region:SetAlpha(0)
    elseif held[region] then
        held[region] = nil
        region:SetAlpha(1)
    end
end

local function Textures(frame)
    local list = {}
    if type(frame) ~= "table" or not frame.GetRegions then return list end
    for _, region in ipairs({ frame:GetRegions() }) do
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then
            list[#list + 1] = region
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Enlaces y portapapeles: un almacén circular de lo que se puede pulsar
---------------------------------------------------------------------------
local STORE_SIZE = 400
local store, nextId = {}, 0
CH.store = store

local function Remember(kind, value)
    nextId = nextId + 1
    store[nextId] = { kind = kind, value = value }
    store[nextId - STORE_SIZE] = nil
    return nextId
end

local function Link(kind, value, display)
    return "|H" .. LINK .. kind .. ":" .. Remember(kind, value) .. "|h" .. display .. "|h"
end

---------------------------------------------------------------------------
-- Emoticonos
---------------------------------------------------------------------------
local EMOTES = {
    [":)"] = "smile", [":-)"] = "smile", ["=)"] = "smile",
    [":("] = "sad", [":-("] = "sad", ["=("] = "sad",
    [";)"] = "wink", [";-)"] = "wink",
    [":D"] = "grin", [":-D"] = "grin", ["xD"] = "grin", ["XD"] = "grin",
    [":P"] = "tongue", [":p"] = "tongue", [":-P"] = "tongue", [":-p"] = "tongue",
    [":O"] = "surprised", [":o"] = "surprised", [":-O"] = "surprised",
    ["<3"] = "heart",
    [":/"] = "meh", [":-/"] = "meh",
}
-- Para copiar: cada dibujo vuelve a su texto.
local EMOTE_TEXT = { smile = ":)", sad = ":(", wink = ";)", grin = ":D", tongue = ":P", surprised = ":O", heart = "<3", meh = ":/" }
CH.EMOTES = EMOTES

local function EmoteIcon(name)
    local size = CH.db.emoteSize or 0
    return "|T" .. MEDIA .. "emote_" .. name .. ":" .. size .. ":" .. size .. "|t"
end

---------------------------------------------------------------------------
-- Comandos de barra (/algo): solo se enlazan los que existen
---------------------------------------------------------------------------
local SECURE = "secure"
local slashIndex, indexTime = nil, -100

local function BuildIndex()
    slashIndex = {}
    for key in pairs(SlashCmdList or {}) do
        for i = 1, 40 do
            local text = _G["SLASH_" .. key .. i]
            if type(text) ~= "string" then break end
            slashIndex[text:lower()] = key
        end
    end
    for key in pairs(SecureCmdList or {}) do
        for i = 1, 40 do
            local text = _G["SLASH_" .. key .. i]
            if type(text) ~= "string" then break end
            slashIndex[text:lower()] = SECURE
        end
    end
    indexTime = GetTime()
end

-- Devuelve la clave de SlashCmdList, "secure" o nil si no existe.
function CH.FindCommand(command)
    command = command:lower()
    if not slashIndex then BuildIndex() end
    if slashIndex[command] == nil and GetTime() - indexTime > 5 then BuildIndex() end
    return slashIndex[command]
end

local function OpenChat(text)
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    if open then open(text) end
end

-- Los comandos de los addons se ejecutan directamente. Los de Blizzard
-- (pueden usar funciones protegidas que un addon no puede llamar) se dejan
-- escritos en el chat: basta con pulsar Intro.
function CH.RunCommand(command)
    local key = CH.FindCommand(command)
    if not key then
        ns.Print("ese comando ya no existe: " .. command)
        return false
    end
    local blizzard = key == SECURE
    if not blizzard and issecurevariable then blizzard = issecurevariable(SlashCmdList, key) end
    if blizzard then
        OpenChat(command .. " ")
        return "chat"
    end
    local editBox = DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox
    local ok, err = pcall(SlashCmdList[key], "", editBox)
    if not ok then ns.Print("el comando " .. command .. " falló: " .. tostring(err)) end
    return ok
end

---------------------------------------------------------------------------
-- Transformación de un mensaje (solo texto legible, nunca secretos)
---------------------------------------------------------------------------
local function Word(token)
    local db = CH.db
    if db.emotes and EMOTES[token] then return EmoteIcon(EMOTES[token]) end
    if db.links then
        local url, tail = token:match("^(%a[%w+.-]*://[^%s|]-)([%.,;:!%?%)]*)$")
        if not url then url, tail = token:match("^(www%.[%w%-]+%.[%w%-%./]+[^%s|]-)([%.,;:!%?%)]*)$") end
        if url and #url > 7 then
            return "|cff4fc3f7" .. Link("url", url, url) .. "|r" .. tail
        end
    end
    if db.commands then
        local head, command, tail = token:match("^([%(\"']*)(/%a[%w_]*)([%.,;:!%?%)\"']*)$")
        if command and CH.FindCommand(command) then
            return head .. "|cff4fc3f7" .. Link("cmd", command, command) .. "|r" .. tail
        end
    end
    return nil
end

local function Plain(text)
    if text == "" then return text end
    return (text:gsub("%S+", Word))
end

-- Separa los enlaces de Blizzard (objetos, hechizos...) para no tocarlos.
function CH.Transform(msg)
    local out, pos = {}, 1
    while true do
        local s, e = msg:find("|H.-|h.-|h", pos)
        if not s then
            out[#out + 1] = Plain(msg:sub(pos))
            break
        end
        out[#out + 1] = Plain(msg:sub(pos, s - 1))
        out[#out + 1] = msg:sub(s, e)
        pos = e + 1
    end
    return table.concat(out)
end

-- Texto limpio para copiar: sin colores, enlaces ni texturas (los
-- emoticonos vuelven a ser :) y compañía).
function CH.Strip(text)
    text = text:gsub("|T[^|]-emote_(%a+)[^|]-|t", function(name) return EMOTE_TEXT[name] or "" end)
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", "")
    text = text:gsub("|A.-|a", "")
    text = text:gsub("|K.-|k", "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|n", "\n")
    text = text:gsub("||", "|")
    return text
end

local COPY_ICON = "|T" .. M.ICONS.copy .. ":0:0:0:0:32:32:0:32:0:32:140:140:150|t"

---------------------------------------------------------------------------
-- Filtro de mensajes (API oficial). Se llama una vez por cada ventana que
-- muestra el mensaje: con el lineID se reutiliza el mismo resultado.
---------------------------------------------------------------------------
local EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER", "CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM",
}
CH.EVENTS = EVENTS

local cache = {}       -- lineID -> mensaje ya transformado
local cacheOrder = {}

local function Sender(name)
    if type(name) ~= "string" or name == "" then return nil end
    if Ambiguate then return Ambiguate(name, "none") end
    return name
end

function CH.Filter(_, event, msg, sender, ...)
    if not CH.active or not CH.db then return false end
    if type(msg) ~= "string" or IsSecret(msg) or IsSecret(sender) then return false end
    local lineID = select(9, ...)
    if IsSecret(lineID) then lineID = nil end
    if lineID and cache[lineID] then return false, cache[lineID], sender, ... end

    local ok, result = pcall(CH.Transform, msg)
    if not ok then return false end
    -- Copiar en línea solo en mensajes de jugadores (los del sistema, como
    -- "tu agilidad ha aumentado", se copian desde el historial).
    local who = Sender(sender)
    if CH.db.copyButtons and who and event ~= "CHAT_MSG_SYSTEM" then
        local plain = CH.Strip(msg)
        local stamp = date and date("%H:%M") or ""
        local copy = "[" .. stamp .. "] " .. (who and (who .. ": ") or "") .. plain
        result = result .. " " .. Link("copy", copy, COPY_ICON)
    end
    if result == msg then return false end
    if lineID then
        cache[lineID] = result
        cacheOrder[#cacheOrder + 1] = lineID
        if #cacheOrder > 60 then cache[table.remove(cacheOrder, 1)] = nil end
    end
    return false, result, sender, ...
end

---------------------------------------------------------------------------
-- Líneas que no pasan por los filtros (lo que escriben los addons con print
-- o AddMessage): poco después de mostrarse se reescribe la línea guardada en
-- la ventana para que sus comandos y enlaces se puedan pulsar. Es lo mismo
-- que hace EllesmereUI en este cliente: se cambia el texto guardado, sin
-- reemplazar ni enganchar funciones del chat, y Blizzard sigue gestionando
-- los clics. Las líneas secretas no se tocan.
---------------------------------------------------------------------------
local seen = setmetatable({}, { __mode = "k" })   -- entradas ya revisadas
local SCAN_MAX = 30

function CH.RewriteNew(frame)
    local buffer = frame.historyBuffer
    if not (buffer and buffer.GetEntryAtIndex) then return 0 end
    local changed = 0
    for i = 1, SCAN_MAX do
        local ok, entry = pcall(buffer.GetEntryAtIndex, buffer, i)
        if not ok or type(entry) ~= "table" or seen[entry] then break end
        seen[entry] = true
        local msg = entry.message
        if type(msg) == "string" and not IsSecret(msg) and not msg:find(LINK, 1, true) and not msg:find("|K", 1, true) then
            -- Sin botón de copiar: en línea solo lo llevan los mensajes de
            -- jugadores. Esto es del sistema o de addons: se copia desde el historial.
            local okT, result = pcall(CH.Transform, msg)
            if okT and result ~= msg then
                entry.message = result
                changed = changed + 1
            end
        end
    end
    if changed > 0 then
        local refresh = frame.MarkDisplayDirty or frame.RefreshDisplay
        if refresh then pcall(refresh, frame) end
    end
    return changed
end

---------------------------------------------------------------------------
-- Ventanitas: copiar (Ctrl+C) y aviso de enlace externo
---------------------------------------------------------------------------
local popup
local function Popup()
    if popup then return popup end
    popup = CreateFrame("Frame", "BlazzitoUIChatCopy", UIParent)
    popup:SetSize(460, 96)
    popup:SetFrameStrata("DIALOG")
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:SetPoint("CENTER", 0, 120)
    M.SetBackdrop(popup, { 0.07, 0.07, 0.08, 0.98 })
    table.insert(UISpecialFrames, "BlazzitoUIChatCopy")
    popup.title = M.Font(popup, 13)
    popup.title:SetPoint("TOPLEFT", 14, -12)
    popup.warning = M.Font(popup, 11)
    popup.warning:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -6)
    popup.warning:SetPoint("RIGHT", -14, 0)
    popup.warning:SetWordWrap(true)
    popup.warning:SetTextColor(1, 0.75, 0.3)
    local box = CreateFrame("EditBox", nil, popup)
    box:SetHeight(24)
    box:SetPoint("BOTTOMLEFT", 14, 30)
    box:SetPoint("BOTTOMRIGHT", -14, 30)
    box:SetFont(M.FONT, 12, "")
    box:SetAutoFocus(false)
    local field = box:CreateTexture(nil, "BACKGROUND")
    field:SetPoint("TOPLEFT", -4, 2)
    field:SetPoint("BOTTOMRIGHT", 4, -2)
    field:SetColorTexture(0.12, 0.12, 0.14, 1)
    -- El texto no se puede cambiar: si se toca, vuelve a estar entero y
    -- seleccionado para copiar.
    box:SetScript("OnTextChanged", function(self, user)
        if user and popup.value then self:SetText(popup.value); self:HighlightText() end
    end)
    box:SetScript("OnEscapePressed", function() popup:Hide() end)
    box:SetScript("OnEnterPressed", function() popup:Hide() end)
    box:SetScript("OnKeyUp", function(_, key)
        -- Tras Ctrl+C se cierra solo.
        if key == "C" and IsControlKeyDown and IsControlKeyDown() then
            C_Timer.After(0, function() popup:Hide() end)
        end
    end)
    popup.box = box
    popup.hint = M.Font(popup, 11)
    popup.hint:SetPoint("BOTTOMLEFT", 14, 10)
    popup.hint:SetTextColor(0.6, 0.6, 0.65)
    popup.hint:SetText("Ctrl+C para copiar · Esc para cerrar")
    return popup
end

function CH.ShowCopy(title, value, warning)
    local p = Popup()
    p.value = value
    p.title:SetText(title)
    p.warning:SetText(warning or "")
    p.warning:SetShown(warning ~= nil)
    p:SetHeight(warning and 118 or 86)
    p.box:SetText(value)
    p:Show()
    p.box:SetFocus()
    p.box:HighlightText()
    p.box:SetCursorPosition(0)
    p.box:HighlightText()
end

local URL_WARNING = "Ojo: este enlace lleva fuera del juego. WoW no deja a los addons abrir el navegador; cópialo y pégalo en él solo si confías en quien lo envió."

function CH.OnLink(link)
    if type(link) ~= "string" or IsSecret(link) then return end
    local kind, id = link:match("^addon:BlazzitoUI:(%a+):(%d+)")
    local entry = id and store[tonumber(id)]
    if not entry then
        if kind then ns.Print("ese enlace ya es muy antiguo.") end
        return
    end
    if kind == "copy" then
        CH.ShowCopy("Copiar mensaje", entry.value)
    elseif kind == "url" then
        CH.ShowCopy("Enlace a un sitio externo", entry.value, URL_WARNING)
    elseif kind == "cmd" then
        CH.RunCommand(entry.value)
    end
end

---------------------------------------------------------------------------
-- Historial: los últimos mensajes de la ventana elegida, para seleccionar y
-- copiar, y a la derecha los comandos y enlaces que aparecen en ellos (así
-- también se pueden pulsar los que escriben otros addons, que no pasan por
-- los filtros).
---------------------------------------------------------------------------
local function SelectedFrame()
    if GENERAL_CHAT_DOCK and FCFDock_GetSelectedWindow then
        local ok, frame = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
        if ok and frame then return frame end
    end
    return SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME or ChatFrame1
end
CH.SelectedFrame = SelectedFrame

function CH.ReadLines(frame, limit)
    local lines = {}
    if not (frame and frame.GetNumMessages) then return lines end
    local ok, count = pcall(frame.GetNumMessages, frame)
    if not ok or IsSecret(count) or type(count) ~= "number" then return lines end
    for i = math.max(1, count - (limit or 300) + 1), count do
        local okLine, text = pcall(frame.GetMessageInfo, frame, i)
        if okLine and type(text) == "string" and not IsSecret(text) then
            local okStrip, plain = pcall(CH.Strip, text)
            if okStrip then lines[#lines + 1] = plain end
        end
    end
    return lines
end

-- Comandos existentes y direcciones web que aparecen en las líneas (los más
-- recientes primero, sin repetir).
function CH.FindExtras(lines, max)
    local found, seen = {}, {}
    for i = #lines, 1, -1 do
        for token in lines[i]:gmatch("%S+") do
            local command = token:match("^[%(\"']*(/%a[%w_]*)[%.,;:!%?%)\"']*$")
            local url = token:match("^(%a[%w+.-]*://[^%s]-)[%.,;:!%?%)]*$") or token:match("^(www%.[%w%-]+%.[^%s]-)[%.,;:!%?%)]*$")
            if command and not seen[command:lower()] and CH.FindCommand(command) then
                seen[command:lower()] = true
                found[#found + 1] = { kind = "cmd", value = command }
            elseif url and not seen[url] then
                seen[url] = true
                found[#found + 1] = { kind = "url", value = url }
            end
            if #found >= max then return found end
        end
    end
    return found
end

local history
local EXTRA_ROWS = 12

local function HistoryWindow()
    if history then return history end
    local W = ns.Widgets
    history = CreateFrame("Frame", "BlazzitoUIChatHistory", UIParent)
    history:SetSize(760, 440)
    history:SetPoint("CENTER")
    history:SetFrameStrata("DIALOG")
    history:SetToplevel(true)
    history:EnableMouse(true)
    history:SetMovable(true)
    history:SetClampedToScreen(true)
    history:RegisterForDrag("LeftButton")
    history:SetScript("OnDragStart", history.StartMoving)
    history:SetScript("OnDragStop", history.StopMovingOrSizing)
    M.SetBackdrop(history, { 0.07, 0.07, 0.08, 0.98 })
    table.insert(UISpecialFrames, "BlazzitoUIChatHistory")

    local title = M.Font(history, 14)
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("Historial del chat")
    local a = M.COLORS.accent
    title:SetTextColor(a[1], a[2], a[3])
    local hint = M.Font(history, 11)
    hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
    hint:SetTextColor(0.6, 0.6, 0.65)
    hint:SetText("Selecciona con el ratón y pulsa Ctrl+C (Ctrl+A para todo)")
    local close = W.IconButton(history, M.ICONS.close, function() return "Cerrar" end, function() history:Hide() end)
    close:SetPoint("TOPRIGHT", -10, -8)

    -- Texto (solo lectura) a la izquierda.
    local scroll = CreateFrame("ScrollFrame", nil, history)
    scroll:SetPoint("TOPLEFT", 16, -44)
    scroll:SetPoint("BOTTOMRIGHT", -232, 16)
    local bg = history:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetPoint("TOPLEFT", scroll, -6, 6)
    bg:SetPoint("BOTTOMRIGHT", scroll, 6, -6)
    bg:SetColorTexture(0.04, 0.04, 0.05, 1)
    local box = CreateFrame("EditBox", nil, scroll)
    box:SetMultiLine(true)
    box:SetAutoFocus(false)
    box:SetFont(M.FONT, 12, "")
    box:SetWidth(500)
    box:SetScript("OnEscapePressed", function() history:Hide() end)
    box:SetScript("OnTextChanged", function(self, user)
        if user and history.text then self:SetText(history.text) end
    end)
    scroll:SetScrollChild(box)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        local value = (self:GetVerticalScroll() or 0) - delta * 60
        self:SetVerticalScroll(math.max(0, math.min(max, value)))
    end)
    history.scroll, history.box = scroll, box
    if W.ScrollBar then W.ScrollBar(scroll, 8) end

    -- Comandos y enlaces encontrados, a la derecha.
    local side = M.Font(history, 12)
    side:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 22, 0)
    side:SetText("Comandos y enlaces")
    side:SetTextColor(0.85, 0.85, 0.9)
    history.empty = M.Font(history, 11)
    history.empty:SetPoint("TOPLEFT", side, "BOTTOMLEFT", 0, -10)
    history.empty:SetWidth(196)
    history.empty:SetWordWrap(true)
    history.empty:SetTextColor(0.6, 0.6, 0.65)
    history.empty:SetText("No hay comandos ni direcciones en los últimos mensajes.")
    history.rows = {}
    for i = 1, EXTRA_ROWS do
        local row = W.Button(history, 196, "", function(self)
            local item = self.item
            if not item then return end
            if item.kind == "cmd" then
                if CH.RunCommand(item.value) == "chat" then history:Hide() end
            else
                CH.ShowCopy("Enlace a un sitio externo", item.value, URL_WARNING)
            end
        end, nil, 24)
        row:SetPoint("TOPLEFT", side, "BOTTOMLEFT", 0, -10 - (i - 1) * 28)
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetPoint("RIGHT", -8, 0)
        row.text:SetJustifyH("LEFT")
        history.rows[i] = row
    end
    return history
end

function CH.OpenHistory(frame)
    local h = HistoryWindow()
    local lines = CH.ReadLines(frame or SelectedFrame(), 300)
    local text = #lines > 0 and table.concat(lines, "\n") or "(No hay mensajes que se puedan copiar.)"
    h.text = text
    h.box:SetText(text)
    local extras = CH.FindExtras(lines, EXTRA_ROWS)
    for i, row in ipairs(h.rows) do
        local item = extras[i]
        row.item = item
        if item then
            row.text:SetText(item.kind == "cmd" and ("Ejecutar  " .. item.value) or ("Web  " .. item.value))
            row:Show()
        else
            row:Hide()
        end
    end
    h.empty:SetShown(#extras == 0)
    h:Show()
    -- Al final (lo más reciente) tras colocarse el texto.
    C_Timer.After(0, function()
        h.scroll:SetVerticalScroll(h.scroll:GetVerticalScrollRange() or 0)
    end)
end

---------------------------------------------------------------------------
-- Aspecto de las ventanas de chat
---------------------------------------------------------------------------
local CHAT_TEXTURES = { "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
                        "LeftTexture", "RightTexture", "BottomTexture", "TopTexture" }
local SIDE_BUTTONS = { "ChatFrameMenuButton", "ChatFrameChannelButton", "QuickJoinToastButton",
                       "ChatFrameToggleVoiceDeafenButton", "ChatFrameToggleVoiceMuteButton", "TextToSpeechButtonFrame" }

local function ChatFrames()
    local list = {}
    for i = 1, 20 do
        local frame = _G["ChatFrame" .. i]
        if type(frame) == "table" and frame.GetName then list[#list + 1] = frame end
    end
    return list
end
CH.ChatFrames = ChatFrames

local function Parts(frame)
    local d = ours[frame]
    if d then return d end
    d = {}
    -- Marcos propios con padre UIParent, anclados al de Blizzard.
    d.back = CreateFrame("Frame", nil, UIParent)
    d.back:SetFrameStrata("BACKGROUND")
    d.back:EnableMouse(false)
    d.border = d.back:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.border:SetAllPoints()
    d.fill = d.back:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.edit = CreateFrame("Frame", nil, UIParent)
    d.edit:SetFrameStrata("BACKGROUND")
    d.edit:EnableMouse(false)
    d.editBorder = d.edit:CreateTexture(nil, "BACKGROUND", nil, -8)
    d.editBorder:SetAllPoints()
    d.editFill = d.edit:CreateTexture(nil, "BACKGROUND", nil, -7)
    d.tabLine = CreateFrame("Frame", nil, UIParent)
    d.tabLine:SetFrameStrata("MEDIUM")
    d.tabLine.bar = d.tabLine:CreateTexture(nil, "OVERLAY")
    d.tabLine.bar:SetAllPoints()
    local a = M.COLORS.accent
    d.tabLine.bar:SetColorTexture(a[1], a[2], a[3], 1)
    ours[frame] = d
    return d
end

local function Paint(d, border, fill, alpha, showBorder)
    local px = M.PixelSize()
    border:SetColorTexture(0, 0, 0, showBorder and math.min(1, alpha + 0.35) or 0)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", px, -px)
    fill:SetPoint("BOTTOMRIGHT", -px, px)
    fill:SetColorTexture(0.06, 0.06, 0.07, alpha)
end

local function TabOf(frame) return _G[frame:GetName() .. "Tab"] end
local function EditOf(frame) return frame.editBox or _G[frame:GetName() .. "EditBox"] end

function CH.SkinFrame(frame)
    local db = CH.db
    local name = frame:GetName()
    local d = Parts(frame)
    local on = db.skin
    for _, key in ipairs(CHAT_TEXTURES) do Hold(_G[name .. key], on) end
    for _, region in ipairs(Textures(frame)) do
        if region:GetDrawLayer() == "BACKGROUND" then Hold(region, on) end
    end
    local tab = TabOf(frame)
    if tab then
        local glow = tab.glow or _G[name .. "TabGlow"]
        for _, region in ipairs(Textures(tab)) do
            if region ~= glow and region ~= tab.conversationIcon then Hold(region, on) end
        end
    end
    local edit = EditOf(frame)
    if edit then
        for _, region in ipairs(Textures(edit)) do Hold(region, on) end
    end
    Hold(frame.buttonFrame or _G[name .. "ButtonFrame"], on and db.hideButtons)

    d.back:ClearAllPoints()
    d.back:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
    d.back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)
    Paint(d, d.border, d.fill, (db.background or 45) / 100, db.border)
    if edit then
        d.edit:ClearAllPoints()
        d.edit:SetPoint("TOPLEFT", edit, "TOPLEFT", 2, -3)
        d.edit:SetPoint("BOTTOMRIGHT", edit, "BOTTOMRIGHT", -2, 3)
        Paint(d, d.editBorder, d.editFill, math.max(0.75, (db.background or 45) / 100), true)
    end
    if tab then
        d.tabLine:ClearAllPoints()
        d.tabLine:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 8, 2)
        d.tabLine:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, 2)
        d.tabLine:SetHeight(2)
    end
    d.skinned = on
    CH.ApplyFont(frame)
end

function CH.ApplyFont(frame)
    if not frame.GetFont then return end
    local font, size, flags = frame:GetFont()
    if not font or IsSecret(size) then return end
    local want = CH.db.fontOutline and "OUTLINE" or ""
    if (flags or "") ~= want then frame:SetFont(font, size, want) end
end

-- Botón del historial, encima de la ventana de chat elegida.
local historyButton
local function HistoryButton()
    if historyButton then return historyButton end
    historyButton = ns.Widgets.IconButton(UIParent, MEDIA .. "icon_history", function()
        return "Historial del chat (copiar mensajes, comandos y enlaces)"
    end, function() CH.OpenHistory() end)
    historyButton:SetFrameStrata("MEDIUM")
    historyButton:SetSize(20, 20)
    historyButton.icon:SetSize(14, 14)
    historyButton.icon:SetVertexColor(1, 1, 1)
    historyButton:SetAlpha(0.6)
    historyButton:HookScript("OnEnter", function(self) self:SetAlpha(1) end)
    historyButton:HookScript("OnLeave", function(self) self:SetAlpha(0.6) end)
    return historyButton
end

-- Cada poco se sincroniza lo nuestro con lo que Blizzard muestra.
function CH.Sync()
    if not (CH.active and CH.db) then return end
    local db = CH.db
    local selected = SelectedFrame()
    for _, frame in ipairs(ChatFrames()) do
        if db.commands or db.links or db.emotes then CH.RewriteNew(frame) end
        local d = ours[frame]
        if d then
            local visible = d.skinned and frame:IsVisible()
            d.back:SetShown(visible and true or false)
            local edit = EditOf(frame)
            d.edit:SetShown((d.skinned and edit and edit:IsVisible()) and true or false)
            local tab = TabOf(frame)
            d.tabLine:SetShown((d.skinned and tab and tab:IsVisible() and frame == selected) and true or false)
            if visible then CH.ApplyFont(frame) end
        end
    end
    local button = HistoryButton()
    if db.historyButton and selected and selected:IsVisible() then
        if button.anchor ~= selected then
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", selected, "TOPRIGHT", 2, 4)
            button.anchor = selected
        end
        button:Show()
    else
        button:Hide()
    end
    -- Botones sueltos del chat (menú, canales, voz...).
    for _, key in ipairs(SIDE_BUTTONS) do Hold(_G[key], db.skin and db.hideButtons) end
end

function CH.ApplyAll()
    if not CH.db then return end
    for _, frame in ipairs(ChatFrames()) do CH.SkinFrame(frame) end
    CH.Sync()
end

---------------------------------------------------------------------------
-- Arranque
---------------------------------------------------------------------------
function CH:OnEnable()
    if ChatFrame_AddMessageEventFilter then
        for _, event in ipairs(EVENTS) do ChatFrame_AddMessageEventFilter(event, CH.Filter) end
    end
    if hooksecurefunc and SetItemRef then
        hooksecurefunc("SetItemRef", function(link) CH.OnLink(link) end)
    end
    local clock = CreateFrame("Frame")
    local elapsedTotal = 0
    clock:SetScript("OnUpdate", function(_, elapsed)
        elapsedTotal = elapsedTotal + elapsed
        if elapsedTotal >= 0.2 then
            elapsedTotal = 0
            CH.Sync()
        end
    end)
    CH.clock = clock
    -- Las ventanas de susurro se crean al vuelo: se visten al aparecer.
    ns.On("PLAYER_ENTERING_WORLD", function() C_Timer.After(0.5, CH.ApplyAll) end)
    ns.On("UPDATE_CHAT_WINDOWS", function() C_Timer.After(0.1, CH.ApplyAll) end)
    ns.On("CHAT_MSG_WHISPER", function() C_Timer.After(0.1, CH.ApplyAll) end)
    ns.On("CHAT_MSG_BN_WHISPER", function() C_Timer.After(0.1, CH.ApplyAll) end)
    ns.RegisterCommand("chat", function() CH.OpenHistory() end, "abre el historial del chat para copiar")
    CH.ApplyAll()
end
