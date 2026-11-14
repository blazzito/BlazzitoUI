-- Blazzito_Macros: marca en las barras de acción.
--
-- Los botones de tus barras que llevan una macro de «Macros de clase» (las
-- «BUI …») tienen una barrita del color de tu clase abajo; con la opción, las
-- demás macros también (en gris claro, para distinguirlas).
--
-- Sin tocar los botones de Blizzard: solo una textura nuestra encima, guardada
-- en una tabla débil (nunca un campo en su botón). Leer qué acción tiene cada
-- casilla no está protegido, así que también se actualiza en combate.
local ns = BlazzitoUI
local Mac = ns and ns.Macros
if not Mac then return end

local Readable = ns.Media.Readable

Mac.BAR_PREFIXES = { "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton",
    "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button" }
local OTHER = { 0.80, 0.82, 0.86 }

local marks = setmetatable({}, { __mode = "k" })
Mac.marks = marks

local function Mark(button)
    local m = marks[button]
    if m then return m end
    m = button:CreateTexture(nil, "OVERLAY", nil, 7)
    m:SetHeight(2)
    m:Hide()
    marks[button] = m
    return m
end

-- Barrita centrada abajo, la mitad del ancho: cabe en todas las formas de
-- botón (también en el círculo y el hexágono).
local function Place(button, m)
    local w = Readable(button:GetWidth()) or 36
    m:ClearAllPoints()
    m:SetWidth(math.max(6, math.floor(w * 0.45)))
    m:SetPoint("BOTTOM", button, "BOTTOM", 0, math.max(3, math.floor(w * 0.09)))
end

local function ActionOf(button)
    local action = Readable(rawget(button, "action"))
    if type(action) ~= "number" and button.GetAttribute then
        local ok, a = pcall(button.GetAttribute, button, "action")
        action = ok and Readable(a)
    end
    return type(action) == "number" and action or nil
end

-- El nombre de la macro de una casilla. Ojo: si la macro lanza un hechizo u
-- objeto, GetActionInfo devuelve el número de ESE hechizo (subtipo "spell" o
-- "item"), no el de la macro; el nombre se lee entonces de GetActionText.
function Mac.SlotMacroName(action)
    if not (action and GetActionInfo) then return nil end
    local ok, kind, id, subType = pcall(GetActionInfo, action)
    kind, id, subType = ok and Readable(kind), ok and Readable(id), ok and Readable(subType)
    if kind ~= "macro" then return nil end
    if GetActionText then
        local okT, text = pcall(GetActionText, action)
        text = okT and Readable(text)
        if type(text) == "string" and text ~= "" then return text end
    end
    if GetMacroInfo and id and (subType == nil or subType == "" or subType == "macro") then
        local okN, n = pcall(GetMacroInfo, id)
        n = okN and Readable(n)
        if type(n) == "string" then return n end
    end
    return ""   -- es una macro, pero sin nombre legible
end

-- "ours" (una macro BUI), "other" (otra macro) o nil.
function Mac.ButtonMacro(button)
    local name = Mac.SlotMacroName(ActionOf(button))
    if not name then return nil end
    if name:sub(1, #Mac.PREFIX) == Mac.PREFIX then return "ours" end
    return "other"
end

function Mac.MarkBars()
    if not Mac.db then return end
    local on = Mac.active and Mac.db.markBars
    local a = ns.Widgets.COLORS.accent
    for _, prefix in ipairs(Mac.BAR_PREFIXES) do
        for i = 1, 12 do
            local button = _G[prefix .. i]
            if button and button.CreateTexture then
                local what = on and Mac.ButtonMacro(button)
                if what == "other" and not Mac.db.markAll then what = nil end
                if what then
                    local m = Mark(button)
                    Place(button, m)
                    local c = what == "ours" and a or OTHER
                    m:SetColorTexture(c[1], c[2], c[3], what == "ours" and 1 or 0.7)
                    m:Show()
                elseif marks[button] then
                    marks[button]:Hide()
                end
            end
        end
    end
end

-- Varias casillas cambian a la vez (cambio de página, de forma...): una sola pasada.
local pending = false
function Mac.ScheduleMarks()
    if pending then return end
    pending = true
    local function Run()
        pending = false
        Mac.MarkBars()
    end
    if C_Timer and C_Timer.After then C_Timer.After(0.1, Run) else Run() end
end

for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_MACROS",
    "UPDATE_SHAPESHIFT_FORM", "PLAYER_ENTERING_WORLD", "UPDATE_VEHICLE_ACTIONBAR" }) do
    pcall(ns.On, event, function() Mac.ScheduleMarks() end)
end
