-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Avisos y /btp (las líneas de detalle del diagnóstico se quedan en español)
    ["el addon Blazz_ThreatPlate sigue activo; desactívalo para usar el módulo \"Aggro en placas\"."] =
        "the Blazz_ThreatPlate addon is still enabled; disable it to use the \"Threat on nameplates\" module.",
    ["selecciona un enemigo y vuelve a escribir /btp"] = "target an enemy and type /btp again",
    ["diagnóstico de aggro:"] = "threat diagnostics:",

    -- Página de configuración
    ["Diseño"] = "Design",
    ["BlazzitoUI (forma y borde del color del aggro)"] = "BlazzitoUI (shape, border in the threat color)",
    ["Clásico (borde dorado)"] = "Classic (gold border)",
    ["|cffff9933El addon Blazz_ThreatPlate sigue activo: desactívalo en la lista de addons para que este módulo funcione.|r"] =
        "|cffff9933The Blazz_ThreatPlate addon is still enabled: disable it in the addon list so this module can work.|r",
    ["Texto"] = "Text",
    ["Mostrar 0% en combate"] = "Show 0% in combat",
    ["Posición en la placa"] = "Position on the nameplate",
    ["Horizontal"] = "Horizontal",
    ["Vertical"] = "Vertical",
})
