-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    ---------------------------------------------------------------------------
    -- Graphics.lua: presets (nombre y descripción)
    ---------------------------------------------------------------------------
    ["Más FPS"] = "More FPS",
    ["Lo justo para jugar fluido: sin sombras ni efectos, poca distancia."] = "Just enough to play smoothly: no shadows or effects, short view distance.",
    ["Competitivo"] = "Competitive",
    ["Para bandas y JcJ: mundo al mínimo, pero texturas, partículas y áreas del suelo en alto y la imagen nítida."] = "For raids and PvP: world detail at minimum, but textures, particles and ground effects high and a sharp image.",
    ["Baja"] = "Low",
    ["Sombras básicas y algo más de distancia."] = "Basic shadows and a bit more view distance.",
    ["Media"] = "Medium",
    ["Texturas altas, sombras medias y efectos ligeros."] = "High textures, medium shadows and light effects.",
    ["Alta"] = "High",
    ["Se ve muy bien en casi cualquier sitio."] = "Looks great almost anywhere.",
    ["Alta + FPS"] = "High + FPS",
    ["Alta con más distancia y hierba, pero quitando los efectos caros que casi no se notan."] = "High with more view distance and grass, minus the costly effects you barely notice.",
    ["Máxima + FPS"] = "Ultra + FPS",
    ["Todo al máximo menos la oclusión ambiental y la niebla volumétrica: casi igual de bonito y mucho más fluido."] = "Everything maxed except ambient occlusion and volumetric fog: almost as pretty and much smoother.",
    ["Máxima calidad"] = "Ultra quality",
    ["Todo a tope y más allá del menú: horizonte lejano, hierba densa y todos los efectos. Para equipos potentes."] = "Everything maxed and beyond the menu: far horizon, dense grass and every effect. For powerful PCs.",

    ---------------------------------------------------------------------------
    -- Graphics.lua: avisos en el chat y qué limita los FPS
    ---------------------------------------------------------------------------
    ["los gráficos se cambian al salir de combate."] = "graphics will change when you leave combat.",
    ["gráficos devueltos a como los tenías antes."] = "graphics restored to how you had them before.",
    ["gráficos devueltos a tu copia guardada."] = "graphics restored from your saved backup.",
    ["gráficos: |cff4fc3f7%s|r aplicado."] = "graphics: |cff4fc3f7%s|r applied.",
    ["%d ajuste bajado porque tu equipo no admite el nivel más alto."] = "%d setting lowered because your PC doesn't support the highest level.",
    ["%d ajustes bajados porque tu equipo no admite el nivel más alto."] = "%d settings lowered because your PC doesn't support the highest level.",
    ["la sincronización vertical (no pasa de los Hz de tu monitor)"] = "vertical sync (it won't go above your monitor's Hz)",
    ["el límite de FPS del juego (%s)"] = "the game's FPS limit (%s)",
    ["los FPS objetivo (%s)"] = "the target FPS (%s)",
    ["Limitan tus FPS: %s."] = "Limiting your FPS: %s.",
    ["El juego no limita tus FPS. Si se quedan clavados en 60, los frena tu monitor (60 Hz), el panel de tu gráfica (NVIDIA o AMD, con sincronización vertical o límite forzados) o Windows en modo ventana."] =
        "The game isn't limiting your FPS. If they're stuck at 60, it's your monitor (60 Hz), your graphics card panel (NVIDIA or AMD, with forced vsync or a frame cap) or Windows in windowed mode.",
    ["muestra tus ajustes de gráficos actuales"] = "shows your current graphics settings",

    ---------------------------------------------------------------------------
    -- Config.lua (página «Gráficos»)
    ---------------------------------------------------------------------------
    ["Presets"] = "Presets",
    ["Un clic y listo; el preset marcado es el que coincide con tus ajustes ahora mismo (si cambias algo en el menú de Blizzard, deja de estar marcado). Si tu equipo no admite algún nivel, se usa el más alto que sí admite. Lo que mejor rinde es quitar la oclusión ambiental y la niebla volumétrica: por eso los presets «+ FPS» se ven casi igual y van mucho más fluidos. No se tocan la iluminación secundaria (en Forever da problemas en algunos equipos) ni la densidad de hechizos."] =
        "One click and done; the highlighted preset is the one that matches your settings right now (if you change something in Blizzard's menu, it's no longer highlighted). If your PC doesn't support a level, the highest supported one is used. The biggest gain comes from turning off ambient occlusion and volumetric fog: that's why the \"+ FPS\" presets look almost the same and run much smoother. Secondary lighting (it causes problems on some PCs in Forever) and spell density are never touched.",
    ["Copia de seguridad"] = "Backup",
    ["Guardar mis ajustes actuales"] = "Save my current settings",
    ["gráficos guardados en tu copia."] = "graphics saved to your backup.",
    ["Volver a mi copia"] = "Restore my backup",
    ["Volver a como estaba antes"] = "Restore how it was before",
    ["Copia de antes: sin guardar"] = "Previous backup: not saved",
    ["Copia de antes: |cffffffff%s|r     Mi copia: |cffffffff%s|r"] = "Previous backup: |cffffffff%s|r     My backup: |cffffffff%s|r",
    ["sin guardar"] = "not saved",
    ["guardada"] = "saved",
    ["%d/%m a las %H:%M"] = "%d/%m at %H:%M",
    ["«Como estaba antes» se guarda sola la primera vez que aplicas un preset y no se borra nunca: es tu red de seguridad. «Mi copia» la guardas tú cuando quieras (por ejemplo, después de afinar algo a mano)."] =
        "\"How it was before\" is saved automatically the first time you apply a preset and is never deleted: it's your safety net. \"My backup\" is saved by you whenever you like (for example, after fine-tuning something by hand).",
    ["Rendimiento"] = "Performance",
    ["Mismos gráficos en bandas y mazmorras"] = "Same graphics in raids and dungeons",
    ["Escala de renderizado (%)"] = "Render scale (%)",
    ["Límite de FPS (0 = sin límite)"] = "FPS limit (0 = no limit)",
    ["Límite de FPS en segundo plano (0 = sin límite)"] = "Background FPS limit (0 = no limit)",
    ["Con «Mismos gráficos» apagado, en bandas, mazmorras y campos de batalla el juego usa su propio juego de ajustes (el de la pestaña de bandas del menú de Blizzard) y los presets no se notan allí. Bajar la escala de renderizado un poco (90-95 %) da bastantes FPS casi sin notarse. El límite en segundo plano ahorra gráfica cuando tienes el juego minimizado o detrás de otra ventana. /bui graficos muestra en el chat todos tus valores actuales."] =
        "With \"Same graphics\" off, in raids, dungeons and battlegrounds the game uses its own set of settings (the raid tab in Blizzard's menu) and the presets have no effect there. Lowering the render scale a little (90-95 %) gives a good FPS boost that's barely noticeable. The background limit spares your graphics card when the game is minimized or behind another window. /bui graficos prints all your current values in chat.",
})
