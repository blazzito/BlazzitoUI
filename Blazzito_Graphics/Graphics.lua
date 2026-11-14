-- Blazzito_Graphics: presets de gráficos de un clic y copia de seguridad de
-- los ajustes del jugador.
--
-- Cómo se aplica un preset (el orden importa: los ajustes "padre" de
-- Blizzard, como graphicsViewDistance, reescriben sus ajustes "hijo", como
-- farclip, al cambiar):
--   1. los hijos que tocan los presets vuelven a su valor por defecto, para
--      que no quede nada de un preset anterior (ni de otro addon);
--   2. la calidad general (graphicsQuality);
--   3. cada padre, comprobando que el juego admite ese nivel en este equipo
--      (si no, se baja al siguiente admitido). Si ya tiene ese valor, se le da
--      un toque (otro valor y vuelta) para que Blizzard rehaga sus hijos;
--   4. los hijos propios del preset;
--   5. un segundo después se repasan los hijos por si un padre los cambió
--      más tarde.
--
-- No se tocan nunca: la iluminación secundaria (graphicsLightMode,
-- giQuality; en Forever da problemas en algunos equipos), la densidad de
-- hechizos (afecta a lo que ves en combate), la resolución ni la ventana.
local ns = BlazzitoUI
if not ns then return end

local G = ns.NewModule("Graphics", "Gráficos", { sameEverywhere = true })
ns.Graphics = G

---------------------------------------------------------------------------
-- Acceso a los ajustes (CVars)
---------------------------------------------------------------------------
local function Get(name)
    local fn = (C_CVar and C_CVar.GetCVar) or GetCVar
    if not fn then return nil end
    local ok, value = pcall(fn, name)
    if ok then return value end
end
G.Get = Get

local function Default(name)
    local fn = (C_CVar and C_CVar.GetCVarDefault) or GetCVarDefault
    if not fn then return nil end
    local ok, value = pcall(fn, name)
    if ok then return value end
end

local function Set(name, value)
    local fn = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not fn then return false end
    local ok, result = pcall(fn, name, tostring(value))
    return ok and result ~= false
end
G.Set = Set

local function Same(a, b)
    local x, y = tonumber(a), tonumber(b)
    if x and y then return math.abs(x - y) < 0.001 end
    return tostring(a) == tostring(b)
end

---------------------------------------------------------------------------
-- Qué se toca
---------------------------------------------------------------------------
-- Ajustes padre del menú de gráficos de Blizzard, con su rango.
G.PARENTS = {
    { "graphicsTextureResolution", 0, 2 },
    { "graphicsViewDistance", 0, 9 },
    { "graphicsEnvironmentDetail", 0, 9 },
    { "graphicsGroundClutter", 0, 9 },
    { "graphicsShadowQuality", 0, 5 },
    { "graphicsLiquidDetail", 0, 3 },
    { "graphicsParticleDensity", 0, 5 },
    { "graphicsSSAO", 0, 4 },
    { "graphicsDepthEffects", 0, 3 },
    { "graphicsComputeEffects", 0, 4 },
    { "graphicsOutlineMode", 0, 2 },
    -- Proyecciones en el suelo: las áreas de daño y de hechizos. Siempre a 1.
    { "graphicsProjectedTextures", 0, 1 },
}
-- Cambiar la resolución de texturas recarga todas las texturas: sin toque.
local NO_NUDGE = { graphicsTextureResolution = true, graphicsProjectedTextures = true }

-- Ajustes hijo que algún preset fija a mano (distancias, hierba, sombras...).
G.CHILDREN = {
    "farclip", "horizonStart", "terrainLodDist",
    "groundEffectDensity", "groundEffectDist", "groundEffectFade",
    "lodObjectFadeScale", "lodObjectCullSize", "entityLodDist",
    "shadowTextureSize", "shadowSoft", "shadowNumCascades", "shadowBlendCascades",
    "SSAO", "sunShafts", "weatherDensity",
    "textureFilteringMode", "ResampleAlwaysSharpen",
}

-- Todo lo que guarda una copia de seguridad.
local EXTRA = { "RAIDsettingsEnabled", "RenderScale", "useMaxFPS", "maxFPS", "useMaxFPSBk", "maxFPSBk" }
local function AllNames()
    local list = { "graphicsQuality" }
    for _, p in ipairs(G.PARENTS) do list[#list + 1] = p[1] end
    for _, name in ipairs(G.CHILDREN) do list[#list + 1] = name end
    for _, name in ipairs(EXTRA) do list[#list + 1] = name end
    return list
end
G.AllNames = AllNames

---------------------------------------------------------------------------
-- Presets
---------------------------------------------------------------------------
-- p: niveles de los padres, en el orden de G.PARENTS
--    (texturas, vista, entorno, hierba, sombras, agua, partículas, SSAO,
--     profundidad, cómputo, contornos, proyecciones en el suelo).
-- Las texturas van en alto en todos: gastan memoria de la gráfica pero casi
-- no cuestan FPS. Las partículas, al menos en 3, para no perder efectos de
-- hechizos importantes.
-- c: hijos fijados a mano después.
G.PRESETS = {
    {
        key = "fps", name = "Más FPS",
        desc = "Lo justo para jugar fluido: sin sombras ni efectos, poca distancia.",
        quality = 1, p = { 2, 2, 2, 1, 0, 0, 3, 0, 0, 0, 1, 1 },
        c = { textureFilteringMode = 2 },
    },
    {
        key = "competitive", name = "Competitivo",
        desc = "Para bandas y JcJ: mundo al mínimo, pero texturas, partículas y áreas del suelo en alto y la imagen nítida.",
        quality = 1, p = { 2, 0, 0, 0, 1, 0, 5, 0, 0, 0, 0, 1 },
        c = { textureFilteringMode = 4, ResampleAlwaysSharpen = 1 },
    },
    {
        key = "low", name = "Bajo",
        desc = "Sombras básicas y algo más de distancia.",
        quality = 3, p = { 2, 3, 3, 3, 1, 1, 3, 0, 0, 1, 1, 1 },
        c = { textureFilteringMode = 3 },
    },
    {
        key = "medium", name = "Medio",
        desc = "Texturas altas, sombras medias y efectos ligeros.",
        quality = 5, p = { 2, 5, 5, 5, 2, 2, 3, 1, 1, 2, 2, 1 },
        c = { textureFilteringMode = 4 },
    },
    {
        key = "high", name = "Alto",
        desc = "Se ve muy bien en casi cualquier sitio.",
        quality = 7, p = { 2, 7, 7, 7, 3, 2, 4, 2, 2, 3, 2, 1 },
        c = { textureFilteringMode = 5 },
    },
    {
        key = "highfps", name = "Alto + FPS",
        desc = "Alto con más distancia y hierba, pero quitando los efectos caros que casi no se notan.",
        quality = 8, p = { 2, 8, 8, 8, 3, 3, 4, 1, 2, 2, 2, 1 },
        c = {
            textureFilteringMode = 5, ResampleAlwaysSharpen = 1,
            groundEffectDensity = 128, groundEffectDist = 320, groundEffectFade = 200,
            terrainLodDist = 800, lodObjectFadeScale = 150, lodObjectCullSize = 12,
        },
    },
    {
        key = "maxfps", name = "Máxima + FPS",
        desc = "Todo al máximo menos la oclusión ambiental y la niebla volumétrica: casi igual de bonito y mucho más fluido.",
        quality = 9, p = { 2, 9, 9, 9, 5, 3, 4, 4, 3, 3, 2, 1 },
        c = {
            textureFilteringMode = 5, ResampleAlwaysSharpen = 1, SSAO = 1, farclip = 10000,
            groundEffectDensity = 192, groundEffectDist = 500, groundEffectFade = 370,
            terrainLodDist = 1000, lodObjectFadeScale = 200, lodObjectCullSize = 8, entityLodDist = 100,
            shadowTextureSize = 2048, shadowSoft = 1, shadowNumCascades = 4, shadowBlendCascades = 1, sunShafts = 2,
        },
    },
    {
        key = "max", name = "Máxima calidad",
        desc = "Todo a tope y más allá del menú: horizonte lejano, hierba densa y todos los efectos. Para equipos potentes.",
        quality = 10, p = { 2, 9, 9, 9, 5, 3, 5, 4, 3, 4, 2, 1 },
        c = {
            textureFilteringMode = 5, ResampleAlwaysSharpen = 1, farclip = 14000, horizonStart = 4000,
            groundEffectDensity = 256, groundEffectDist = 560, groundEffectFade = 420,
            terrainLodDist = 2600, lodObjectFadeScale = 200, lodObjectCullSize = 8, entityLodDist = 100,
            shadowTextureSize = 2048, shadowSoft = 1, shadowNumCascades = 4, shadowBlendCascades = 1,
            sunShafts = 2, weatherDensity = 3,
        },
    },
}
G.byKey = {}
for _, preset in ipairs(G.PRESETS) do G.byKey[preset.key] = preset end

---------------------------------------------------------------------------
-- Escritura
---------------------------------------------------------------------------
local PARENT = {}
for _, p in ipairs(G.PARENTS) do PARENT[p[1]] = p end

-- ¿Admite el juego ese nivel en este equipo? (el validador de Blizzard
-- devuelve 0 o true si sí). Sin validador o sin respuesta, se da por bueno.
local function Supported(name, value)
    if type(IsGraphicsSettingValueSupported) ~= "function" then return true end
    local ok, code = pcall(IsGraphicsSettingValueSupported, name, value, false)
    if not ok or code == nil or code == true or code == 0 then return true end
    return false
end
G.Supported = Supported

-- El nivel más alto admitido que no pase del pedido.
local function Best(name, value)
    local spec = PARENT[name]
    value = tonumber(value)
    if not (spec and value) then return value end
    value = math.max(spec[2], math.min(spec[3], value))
    while value > spec[2] and not Supported(name, value) do value = value - 1 end
    return value
end
G.Best = Best

local function SetParent(name, value)
    if not NO_NUDGE[name] and Same(Get(name), value) then
        local spec = PARENT[name]
        Set(name, value > spec[2] and value - 1 or value + 1)
    end
    return Set(name, value)
end

-- Escribe una lista ordenada { {nombre, valor}, ... }. Los que no existen en
-- este cliente se saltan. Devuelve cuántos se aplicaron, cuántos no existen
-- y cuántos se bajaron porque el equipo no admite el nivel pedido.
local function Write(list, exact)
    local done, missing, lowered = 0, 0, 0
    for _, item in ipairs(list) do
        local name, value = item[1], item[2]
        if Get(name) == nil then
            missing = missing + 1
        elseif PARENT[name] then
            local v = exact and tonumber(value) or Best(name, value)
            if v and not Same(v, value) then lowered = lowered + 1 end
            if v and SetParent(name, v) then done = done + 1 end
        elseif Set(name, value) then
            done = done + 1
        end
    end
    return done, missing, lowered
end

-- Repasa los hijos un momento después: algún padre puede reescribirlos tarde.
local function Recheck(children)
    if not (C_Timer and C_Timer.After) then return end
    C_Timer.After(1, function()
        for name, value in pairs(children) do
            if Get(name) ~= nil and not Same(Get(name), value) then Set(name, value) end
        end
        if G.OnChanged then G.OnChanged() end
    end)
end

local function Later(fn)
    if InCombatLockdown and InCombatLockdown() then
        ns.Print("los gráficos se cambian al salir de combate.")
        ns.AfterCombat("graphics", fn)
        return false
    end
    fn()
    return true
end

---------------------------------------------------------------------------
-- Copias de seguridad
---------------------------------------------------------------------------
-- db.backups.original: la primera vez que se aplica un preset (tus gráficos
-- tal y como los tenías antes de usar este módulo). Nunca se sobrescribe sola.
-- db.backups.mine: la que guardas tú con el botón.
function G.Snapshot(slot)
    local values = {}
    for _, name in ipairs(AllNames()) do values[name] = Get(name) end
    G.db.backups[slot] = { time = time and time() or 0, values = values }
    return G.db.backups[slot]
end

function G.HasBackup(slot)
    return G.db.backups[slot] ~= nil
end

function G.Restore(slot)
    local backup = G.db.backups[slot]
    if not backup then return false end
    return Later(function()
        local v = backup.values
        local list, children = {}, {}
        local function Add(name)
            if v[name] ~= nil then list[#list + 1] = { name, v[name] } end
        end
        Add("graphicsQuality")
        for _, p in ipairs(G.PARENTS) do Add(p[1]) end
        for _, name in ipairs(G.CHILDREN) do
            Add(name)
            if v[name] ~= nil then children[name] = v[name] end
        end
        for _, name in ipairs(EXTRA) do Add(name) end
        Write(list, true)
        Recheck(children)
        G.db.preset = nil
        ns.Print(slot == "original" and "gráficos devueltos a como los tenías antes." or "gráficos devueltos a tu copia guardada.")
        if G.OnChanged then G.OnChanged() end
    end)
end

---------------------------------------------------------------------------
-- Aplicar un preset
---------------------------------------------------------------------------
function G.Apply(key)
    local preset = G.byKey[key]
    if not preset then return false end
    return Later(function()
        if not G.db.backups.original then G.Snapshot("original") end
        -- 1. Hijos a su valor por defecto (nada de presets anteriores).
        local list = {}
        for _, name in ipairs(G.CHILDREN) do
            local d = Default(name)
            if d ~= nil then list[#list + 1] = { name, d } end
        end
        -- 2 y 3. Calidad general y padres.
        list[#list + 1] = { "graphicsQuality", preset.quality }
        for i, p in ipairs(G.PARENTS) do list[#list + 1] = { p[1], preset.p[i] } end
        -- 4. Hijos del preset.
        for _, name in ipairs(G.CHILDREN) do
            if preset.c[name] ~= nil then list[#list + 1] = { name, preset.c[name] } end
        end
        -- Mismos gráficos en bandas y mazmorras (si no, allí el juego usa
        -- su juego de ajustes aparte e ignora el preset).
        if G.db.sameEverywhere then list[#list + 1] = { "RAIDsettingsEnabled", 0 } end
        local _, _, lowered = Write(list)
        Recheck(preset.c)
        G.db.preset = key
        local msg = "gráficos: |cff4fc3f7" .. preset.name .. "|r aplicado."
        if lowered > 0 then
            msg = msg .. " " .. lowered .. (lowered == 1 and " ajuste bajado" or " ajustes bajados") .. " porque tu equipo no admite el nivel más alto."
        end
        ns.Print(msg)
        if G.OnChanged then G.OnChanged() end
    end)
end

-- El preset que coincide con tus ajustes actuales (o nil si los cambiaste).
function G.Current()
    for _, preset in ipairs(G.PRESETS) do
        local match = true
        for i, p in ipairs(G.PARENTS) do
            local now = Get(p[1])
            if now ~= nil and not Same(now, Best(p[1], preset.p[i])) then match = false; break end
        end
        if match then
            for name, value in pairs(preset.c) do
                local now = Get(name)
                if now ~= nil and not Same(now, value) then match = false; break end
            end
        end
        if match then return preset.key end
    end
end

---------------------------------------------------------------------------
-- Extras: escala de renderizado y límites de FPS
---------------------------------------------------------------------------
function G.GetRenderScale()
    return math.floor((tonumber(Get("RenderScale")) or 1) * 100 + 0.5)
end
function G.SetRenderScale(percent)
    Set("RenderScale", percent / 100)
end

-- 0 = sin límite.
function G.GetFPSCap(background)
    local use, cap = background and "useMaxFPSBk" or "useMaxFPS", background and "maxFPSBk" or "maxFPS"
    if Get(use) ~= "1" then return 0 end
    return tonumber(Get(cap)) or 0
end
function G.SetFPSCap(value, background)
    local use, cap = background and "useMaxFPSBk" or "useMaxFPS", background and "maxFPSBk" or "maxFPS"
    if value and value > 0 then
        Set(cap, value)
        Set(use, 1)
    else
        Set(use, 0)
    end
    if G.OnChanged then G.OnChanged() end
end

-- RAIDsettingsEnabled = 1: bandas, mazmorras y campos de batalla usan sus
-- propios ajustes (raidGraphics*); 0: los mismos que en el mundo.
function G.GetSameEverywhere()
    return Get("RAIDsettingsEnabled") == "0"
end
function G.SetSameEverywhere(on)
    G.db.sameEverywhere = on and true or false
    Set("RAIDsettingsEnabled", on and 0 or 1)
end

-- Qué está frenando los FPS, en una frase.
function G.Limiter()
    local found = {}
    if Get("vsync") == "1" then found[#found + 1] = "la sincronización vertical (no pasa de los Hz de tu monitor)" end
    if Get("useMaxFPS") == "1" then found[#found + 1] = "el límite de FPS del juego (" .. tostring(Get("maxFPS")) .. ")" end
    if Get("useTargetFPS") == "1" then found[#found + 1] = "los FPS objetivo (" .. tostring(Get("targetFPS")) .. ")" end
    if #found > 0 then return "Limitan tus FPS: " .. table.concat(found, ", ") .. "." end
    return "El juego no limita tus FPS. Si se quedan clavados en 60, los frena tu monitor (60 Hz), el panel de tu gráfica (NVIDIA o AMD, con sincronización vertical o límite forzados) o Windows en modo ventana."
end

---------------------------------------------------------------------------
-- Diagnóstico: /bui graficos
---------------------------------------------------------------------------
function G.Report()
    print("  " .. G.Limiter())
    print("  vsync=" .. tostring(Get("vsync")) .. "  useMaxFPS=" .. tostring(Get("useMaxFPS")) .. "  maxFPS=" .. tostring(Get("maxFPS")) ..
          "  useTargetFPS=" .. tostring(Get("useTargetFPS")) .. "  LowLatencyMode=" .. tostring(Get("LowLatencyMode")) ..
          "  gxMaximize=" .. tostring(Get("gxMaximize")) .. "  gxRefresh=" .. tostring(Get("gxRefresh")))
    local current = G.Current()
    ns.Print("gráficos actuales" .. (current and (" (preset " .. G.byKey[current].name .. ")") or " (personalizados)") .. ":")
    local line = {}
    for _, name in ipairs(AllNames()) do
        local v = Get(name)
        if v ~= nil then line[#line + 1] = name .. "=" .. tostring(v) end
        if #line == 4 then print("  " .. table.concat(line, "  ")); line = {} end
    end
    if #line > 0 then print("  " .. table.concat(line, "  ")) end
    local o, m = G.db.backups.original, G.db.backups.mine
    print("  copia de antes: " .. (o and date and date("%d/%m %H:%M", o.time) or "no") ..
          "   tu copia: " .. (m and date and date("%d/%m %H:%M", m.time) or "no"))
end

function G:OnInitialize()
    self.db.backups = self.db.backups or {}
    ns.RegisterCommand("graficos", G.Report, "muestra tus ajustes de gráficos actuales")
end
