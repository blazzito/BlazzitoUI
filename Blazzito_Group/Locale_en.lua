-- English. Clave = el texto en español tal cual aparece en el código.
if not BlazzitoUI or not BlazzitoUI.AddLocale then return end
BlazzitoUI.AddLocale("en", {
    -- Marcos y avisos
    ["Grupo"] = "Party",
    ["Banda"] = "Raid",
    ["grupo: el módulo de marcos de unidad está desactivado; los marcos de grupo lo necesitan."] =
        "party: the unit frames module is disabled; party frames need it.",
    ["diagnóstico de los marcos de grupo"] = "party frames diagnostics",

    -- Página de opciones
    ["Clase"] = "Class",
    ["Al lado del marco"] = "Next to the frame",
    ["Dentro de la barra"] = "Inside the bar",
    ["Dentro, arriba a la derecha"] = "Inside, top right",
    ["Encima del marco"] = "Above the frame",
    ["A la izquierda del marco"] = "Left of the frame",
    ["Por grupo"] = "By group",
    ["Por rol (tanques, sanadores, daño)"] = "By role (tanks, healers, damage)",
    ["Por clase"] = "By class",
    ["Por nombre"] = "By name",
    ["Por columnas (de arriba abajo)"] = "By columns (top to bottom)",
    ["Por filas (de izquierda a derecha)"] = "By rows (left to right)",
    ["Vista previa de grupo"] = "Party preview",
    ["Vista previa de banda"] = "Raid preview",
    ["Ocultar los marcos de Blizzard (recarga)"] = "Hide Blizzard's frames (reloads)",
    ["La vista previa muestra miembros de ejemplo con roles, perjuicios disipables, aggro y alguno fuera de rango. Púlsala otra vez para quitarla."] =
        "The preview shows sample members with roles, dispellable debuffs, aggro and some out of range. Press it again to remove it.",
    ["Tamaño y disposición"] = "Size and layout",
    ["Incluirte a ti en el grupo"] = "Include yourself in the party",
    ["Organización de la banda"] = "Raid layout",
    ["Orden"] = "Sort",
    ["Cada grupo en su propia columna"] = "Each group in its own column",
    ["Columnas"] = "Columns",
    ["Cómo se llena"] = "Fill order",
    ["Mostrar los grupos del 1 al"] = "Show groups 1 to",
    ["Solo para la pestaña Banda. Se reorganiza al salir de combate. Con \"Mostrar los grupos del 1 al 5\" solo ves a los 25 primeros (útil en bandas de 25 con suplentes)."] =
        "Raid tab only. It rearranges when combat ends. With \"Show groups 1 to 5\" you only see the first 25 (handy in 25-player raids with substitutes).",
    ["Vida y recurso"] = "Health and resource",
    ["Alto del recurso (0 = sin barra)"] = "Resource height (0 = no bar)",
    ["Icono del hechizo"] = "Spell icon",
    ["Perjuicios disipables"] = "Dispellable debuffs",
    ["Mostrar los que puedes disipar"] = "Show the ones you can dispel",
    ["El marco brilla del color del tipo"] = "Frame glows in the debuff type's color",
    ["Cuántos como máximo"] = "Maximum shown",
    ["Dónde"] = "Where",
    ["Solo salen los perjuicios que tu clase puede quitar, con el borde del color de su tipo (magia, maldición, enfermedad, veneno)."] =
        "Only debuffs your class can remove are shown, with a border in their type's color (magic, curse, disease, poison).",
    ["Tus beneficios"] = "Your buffs",
    ["Mostrar los beneficios que tú le pones"] = "Show the buffs you cast on them",
    ["Marcar en gris los que le faltan"] = "Mark missing ones in grey",
    ["Iconos de tus beneficios sobre cada miembro, en el mismo orden en todos. \"Le falta\" se calcula con tus beneficios largos (sin duración o de 2 minutos o más) que lleva algún otro miembro: si alguien sale en gris con borde rojo, no lleva el tuyo (o está demasiado lejos para el aura)."] =
        "Icons of your buffs on each member, in the same order on everyone. \"Missing\" is based on your long buffs (no duration or 2 minutes or more) that some other member has: if someone shows a grey icon with a red border, they don't have yours (or are too far away for the aura).",
    ["Indicadores"] = "Indicators",
    ["Icono de rol (tanque, sanador, daño)"] = "Role icon (tank, healer, damage)",
    ["Corona del líder"] = "Leader crown",
    ["Borde rojo si tiene aggro"] = "Red border when they have aggro",
    ["Borde de acento en tu objetivo"] = "Accent border on your target",
    ["Atenuar si está fuera de rango"] = "Fade when out of range",
    ["Opacidad fuera de rango (%)"] = "Out-of-range opacity (%)",
})
