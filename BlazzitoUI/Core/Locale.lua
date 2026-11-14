-- Idioma de BlazzitoUI: español (el de origen) o inglés.
--
-- Los textos se escriben en español en el código y esa frase es la clave:
--   L("Mostrar este marco")        -> "Show this frame" en inglés
--   L["Mostrar este marco"]        -> lo mismo
-- Si falta una traducción, sale el español: nunca se rompe nada a medias.
--
-- La traducción se hace al MOSTRAR el texto, no al cargar el archivo: los
-- ajustes guardados (BlazzitoUIDB.locale) llegan después de cargar el código.
-- Por eso los controles de Widgets.lua traducen solos sus etiquetas, y los
-- textos guardados en tablas al cargar (títulos de módulos, opciones de
-- desplegables...) se escriben en español y se traducen donde se pintan.
--
-- Elección (BlazzitoUIDB.locale, de toda la cuenta): "auto" (el del juego:
-- español si el cliente está en español, si no inglés), "es" o "en".
local _, ns = ...

ns.LOCALES = {}            -- [código] = { ["texto en español"] = "traducción" }
ns.locale = "es"           -- idioma en uso ("es" o "en")

local function GameLocale()
    local game = GetLocale and GetLocale() or "esES"
    return (game == "esES" or game == "esMX") and "es" or "en"
end
ns.GameLocale = GameLocale

local issecretvalue = issecretvalue

-- Traducción de un texto (si no es texto, se devuelve tal cual). Un valor
-- secreto (motor 12.x) nunca se usa como clave: se devuelve sin tocarlo.
local function Translate(text)
    if type(text) ~= "string" or ns.locale == "es" then return text end
    if issecretvalue and issecretvalue(text) then return text end
    local tbl = ns.LOCALES[ns.locale]
    local out = tbl and tbl[text]
    return out or text
end
ns.Translate = Translate

ns.L = setmetatable({}, {
    __index = function(_, text) return Translate(text) end,
    __call = function(_, text) return Translate(text) end,
})

-- Textos con huecos: ns.LF("%d objetos", n) == string.format(L("%d objetos"), n).
function ns.LF(text, ...)
    return string.format(Translate(text), ...)
end

function ns.LocaleChoice()
    local root = ns.root or BlazzitoUIDB
    local choice = type(root) == "table" and root.locale or nil
    if choice ~= "es" and choice ~= "en" then choice = "auto" end
    return choice
end

-- Aplica la elección guardada (o una nueva). Cambiarla pide /reload.
function ns.ApplyLocale(choice)
    choice = choice or ns.LocaleChoice()
    if choice == "auto" then ns.locale = GameLocale() else ns.locale = choice end
    return ns.locale
end

function ns.SetLocaleChoice(choice)
    if choice ~= "es" and choice ~= "en" then choice = "auto" end
    if ns.root then ns.root.locale = choice end
    local before = ns.locale
    ns.ApplyLocale(choice)
    return ns.locale ~= before
end

-- Cada módulo trae sus traducciones en su propia carpeta (Locale_en.lua):
--   BlazzitoUI.AddLocale("en", { ["Bolsas"] = "Bags", ... })
function ns.AddLocale(code, entries)
    local tbl = ns.LOCALES[code]
    if not tbl then
        tbl = {}
        ns.LOCALES[code] = tbl
    end
    for es, text in pairs(entries) do tbl[es] = text end
end

-- Hasta leer los ajustes, el del juego.
ns.ApplyLocale("auto")
