-- Blazzito_Macros: el catálogo de macros de cada clase.
--
-- Las macros se escriben con números de hechizo entre llaves, {1130}, y al
-- crearlas se cambian por el nombre del hechizo en el idioma del juego (las
-- macros solo entienden nombres, y sin rango lanzan siempre el más alto).
--   {9634|5487}    el primero de la lista que conozcas (aquí, la mejor forma de oso)
--   {8042r}        nombre con su rango: «Choque de tierra(Rango 1)»
--   {shields}      el nombre de los escudos en tu idioma, para [equipped:...]
--
-- Lo que no conoces todavía se quita solo:
--   - en /cast y /use, cada opción separada por «;» que lo use;
--   - en /castsequence, cada paso separado por «,»;
--   - cualquier otra línea entera.
-- req: los hechizos que hacen falta para que la macro esté disponible (si
-- no se indica, todos los de la macro). Las macros «dynamic» las escribe el
-- motor (Macros.lua) con lo que llevas encima o en las bolsas.
--
-- Las macros son conocimiento común de la comunidad de Classic; aquí están
-- escritas a mano y adaptadas a lo que entiende Forever.
local ns = BlazzitoUI
if not ns then return end

local C = {}
ns.MacroCatalog = C

-- Sobre quién: el que tienes bajo el ratón; si no, tu objetivo (o tú mismo).
local HELP = "[@mouseover,help,nodead][help,nodead][@player]"
local HARM = "[@mouseover,harm,nodead][]"

C.GROUPS = { "Ataque", "Control", "Interrupción", "Defensa", "Curación", "Apoyo", "Mascota", "Formas y posturas",
    "Armas", "Consumibles", "Utilidad" }

---------------------------------------------------------------------------
-- Para todas las clases
---------------------------------------------------------------------------
C.ALL = {
    { key = "trinkets", name = "Abalorios", group = "Utilidad", title = "Los dos abalorios",
      desc = "Usa a la vez los dos abalorios que llevas puestos (los que se pueden usar).",
      body = "#showtooltip\n/use 13\n/use 14", icon = 134400 },
    { key = "emergency", name = "Emergencia", group = "Consumibles", title = "Piedra de salud y poción",
      desc = "Usa tu mejor piedra de salud y tu mejor poción de vida de las bolsas. Se actualiza sola cuando cambian.",
      dynamic = "emergency" },
    { key = "food", name = "Comer", group = "Consumibles", title = "Comer y beber",
      desc = "Come y bebe a la vez lo mejor que tengas para tu nivel (lo conjurado primero). Se actualiza sola.",
      dynamic = "food" },
    { key = "manapot", name = "Maná", group = "Consumibles", title = "Poción de maná",
      desc = "Tu mejor poción de maná de las bolsas. Se actualiza sola.",
      dynamic = "manapot", mana = true },
}

---------------------------------------------------------------------------
-- Cazador
---------------------------------------------------------------------------
C.HUNTER = {
    { key = "hun_mark", name = "Marca", group = "Ataque", title = "Marca del cazador al ratón",
      desc = "Marca al enemigo que tienes bajo el ratón sin cambiar de objetivo; si no hay ninguno, a tu objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {1130}" },
    { key = "hun_auto", name = "Automático", group = "Ataque", title = "Disparo automático sin apagarlo",
      desc = "Empieza el disparo automático. Pulsarla otra vez no lo apaga (el error clásico de los cazadores).",
      body = "#showtooltip\n/cast !{75}" },
    { key = "hun_arcane", name = "Arcano", group = "Ataque", title = "Disparo arcano + automático",
      desc = "Dispara Arcano y deja el automático en marcha: puedes pulsarla todo el combate.",
      body = "#showtooltip {3044}\n/cast !{75}\n/cast {3044}" },
    { key = "hun_sting", name = "Picadura", group = "Ataque", title = "Picaduras al ratón",
      desc = "Picadura de serpiente al enemigo bajo el ratón. Mayús: picadura de víbora (quita maná).",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,harm,nodead][mod:shift] {3034}; " .. HARM .. " {1978}",
      req = { 1978 } },
    { key = "hun_melee", name = "Cuerpo", group = "Ataque", title = "Cuerpo a cuerpo",
      desc = "Golpe de raptor con ataque automático; Mayús: Mordedura de mangosta (tras esquivar). Para cuando te alcanzan.",
      body = "#showtooltip\n/startattack\n/cast [mod:shift] {1495}; {2973}", req = { 2973 } },
    { key = "hun_volley", name = "Descarga", group = "Ataque", title = "Descarga donde apunta el ratón",
      desc = "Lanza Descarga directamente bajo el cursor, sin el círculo de colocar.",
      body = "#showtooltip\n/cast [@cursor] {1510}" },
    { key = "hun_concuss", name = "Conmoción", group = "Control", title = "Disparo de conmoción al ratón",
      desc = "Ralentiza al enemigo bajo el ratón o a tu objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {5116}" },
    { key = "hun_scatter", name = "Dispersor", group = "Control", title = "Disparo de dispersión al ratón",
      desc = "Desorienta al enemigo bajo el ratón: lo clásico antes de poner una trampa congelante.",
      body = "#showtooltip\n/cast " .. HARM .. " {19503}" },
    { key = "hun_tranq", name = "Tranquilo", group = "Interrupción", title = "Disparo tranquilizante al foco",
      desc = "Quita el frenesí a tu foco; si no tienes foco, al ratón o a tu objetivo.",
      body = "#showtooltip\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] {19801}" },
    { key = "hun_fd", name = "Fingir", group = "Defensa", title = "Fingir muerte limpio",
      desc = "Deja de atacar, llama a la mascota y finge tu muerte: así no te «despiertas» con un disparo automático.",
      body = "#showtooltip\n/stopattack\n/petfollow\n/cast {5384}" },
    { key = "hun_trap", name = "Trampa", group = "Defensa", title = "Trampas con modificadores",
      desc = "Trampa congelante. Mayús: trampa de escarcha. Ctrl: trampa explosiva.",
      body = "#showtooltip\n/cast [mod:shift] {13809}; [mod:ctrl] {13813}; {1499}", req = { 1499 } },
    { key = "hun_disengage", name = "Retirada", group = "Defensa", title = "Separación + mascota",
      desc = "Separación para quitarte el aggro y manda a la mascota a atacar a tu objetivo.",
      body = "#showtooltip\n/petattack\n/cast {781}" },
    { key = "hun_petatk", name = "Atacar", group = "Mascota", title = "Ataque de la mascota",
      desc = "La mascota ataca al enemigo bajo el ratón o a tu objetivo. Mayús: vuelve contigo.",
      body = "/petfollow [mod:shift]\n/stopmacro [mod:shift]\n/petattack [@mouseover,harm,nodead][]",
      req = { 883 }, icon = 883 },
    { key = "hun_pet", name = "Mascota", group = "Mascota", title = "Llamar, revivir o aliviar",
      desc = "Sin mascota la llama; muerta (o con Mayús) la revive; viva la cura con Aliviar mascota.",
      body = "#showtooltip\n/cast [@pet,dead][mod:shift] {982}; [nopet] {883}; {136}", req = { 883 } },
    { key = "hun_feed", name = "Alimentar", group = "Mascota", title = "Alimentar mascota (última comida)",
      desc = "Alimenta a tu mascota con la última comida que le diste. Si se te acaba, usa otra que ya haya comido. Dale de comer una vez a mano y la recuerda.",
      dynamic = "feed", req = { 6991 } },
    { key = "hun_burst", name = "Furia", group = "Mascota", title = "Cólera de las bestias + abalorios",
      desc = "Manda a la mascota, usa tus abalorios y lanza Cólera de las bestias.",
      body = "#showtooltip {19574}\n/petattack\n/use 13\n/use 14\n/cast {19574}" },
    { key = "hun_intim", name = "Intimidar", group = "Mascota", title = "Intimidación + ataque",
      desc = "La mascota ataca y aturde a tu objetivo.",
      body = "#showtooltip\n/petattack\n/cast {19577}" },
    { key = "hun_aspect", name = "Aspectos", group = "Formas y posturas", title = "Aspectos con modificadores",
      desc = "Aspecto del halcón. Mayús: guepardo. Ctrl: manada. Alt: mono.",
      body = "#showtooltip\n/cast [mod:shift] !{5118}; [mod:ctrl] !{13159}; [mod:alt] !{13163}; !{13165}",
      req = { 13165 } },
}

---------------------------------------------------------------------------
-- Guerrero
---------------------------------------------------------------------------
C.WARRIOR = {
    { key = "war_charge", name = "Cargar", group = "Ataque", title = "Cargar / Interceptar",
      desc = "Fuera de combate: postura de batalla y Cargar. En combate: postura rabiosa e Interceptar. Púlsala dos veces si tiene que cambiar de postura.",
      body = "#showtooltip\n/cast [nocombat,nostance:1] {2457}; [nocombat] {100}; [nostance:3] {2458}; {20252}",
      req = { 100 } },
    { key = "war_op", name = "Abrumar", group = "Ataque", title = "Abrumar (con postura)",
      desc = "Pasa a postura de batalla si hace falta y usa Abrumar.",
      body = "#showtooltip {7384}\n/startattack\n/cast [nostance:1] {2457}; {7384}" },
    { key = "war_hs", name = "Golpe", group = "Ataque", title = "Golpe heroico / Rajar",
      desc = "Golpe heroico sin cortar el ataque automático. Mayús: Rajar (varios enemigos).",
      body = "#showtooltip\n/startattack\n/cast [mod:shift] {845}; {78}", req = { 78 } },
    { key = "war_exec", name = "Ejecutar", group = "Ataque", title = "Ejecutar (con postura)",
      desc = "Ejecutar desde batalla o rabiosa: si estás en defensiva cambia a batalla primero.",
      body = "#showtooltip {5308}\n/startattack\n/cast [stance:2] {2457}; {5308}" },
    { key = "war_kick", name = "Cortar", group = "Interrupción", title = "Interrupción según postura",
      desc = "Rabiosa: Zurrar. Con escudo: Golpe con escudo. Sin nada de eso, cambia a postura rabiosa.",
      body = "#showtooltip\n/cast [stance:3] {6552}; [equipped:{shields}] {72}; {2458}", req = { 6552 } },
    { key = "war_taunt", name = "Provocar", group = "Defensa", title = "Provocar al ratón",
      desc = "Pasa a postura defensiva si hace falta y provoca al enemigo bajo el ratón o a tu objetivo.",
      body = "#showtooltip {355}\n/cast [nostance:2] {71}; " .. HARM .. " {355}" },
    { key = "war_block", name = "Bloquear", group = "Defensa", title = "Bloquear con escudo",
      desc = "Pasa a defensiva si hace falta y bloquea con el escudo.",
      body = "#showtooltip {2565}\n/cast [nostance:2] {71}; {2565}" },
    { key = "war_disarm", name = "Desarmar", group = "Control", title = "Desarmar (con postura)",
      desc = "Pasa a defensiva si hace falta y desarma a tu objetivo.",
      body = "#showtooltip {676}\n/cast [nostance:2] {71}; {676}" },
    { key = "war_berserk", name = "Rabia", group = "Defensa", title = "Rabia rabiosa (con postura)",
      desc = "Pasa a postura rabiosa si hace falta y usa Rabia rabiosa (contra miedo y aturdir).",
      body = "#showtooltip {18499}\n/cast [nostance:3] {2458}; {18499}" },
    { key = "war_stance", name = "Posturas", group = "Formas y posturas", title = "Posturas con modificadores",
      desc = "Batalla. Mayús: defensiva. Ctrl: rabiosa.",
      body = "#showtooltip\n/cast [mod:shift] {71}; [mod:ctrl] {2458}; {2457}", req = { 2457 } },
    { key = "weapon", name = "Armas", group = "Armas", title = "Dos manos / una mano",
      desc = "Cambia entre tu última arma de dos manos y tu última arma de una mano con lo que llevabas en la otra mano (escudo, arma, objeto o nada). Recuerda sola lo último que llevaste.",
      dynamic = "weapon" },
}

---------------------------------------------------------------------------
-- Paladín
---------------------------------------------------------------------------
C.PALADIN = {
    { key = "weapon", name = "Armas", group = "Armas", title = "Dos manos / una mano",
      desc = "Cambia entre tu última arma de dos manos y tu última arma de una mano con lo que llevabas en la otra mano (escudo, arma, objeto o nada). Recuerda sola lo último que llevaste.",
      dynamic = "weapon" },
    { key = "pal_judge", name = "Juicio", group = "Ataque", title = "Juicio con ataque",
      desc = "Juicio sin cortar el ataque automático. Mayús: vuelve a ponerte Sello de rectitud.",
      body = "#showtooltip\n/startattack\n/cast [mod:shift] {21084|20154}; {20271}", req = { 20271 } },
    { key = "pal_crusader", name = "Cruzado", group = "Ataque", title = "Sello del cruzado / Juicio",
      desc = "Primera pulsación: Sello del cruzado. Segunda: Juicio (deja el perjuicio del cruzado). Se reinicia al cambiar de objetivo.",
      body = "#showtooltip\n/startattack\n/castsequence reset=target {21082}, {20271}" },
    { key = "pal_hoj", name = "Martillo", group = "Control", title = "Martillo de justicia al ratón",
      desc = "Aturde al enemigo bajo el ratón o a tu objetivo (también sirve para cortar hechizos).",
      body = "#showtooltip\n/cast " .. HARM .. " {853}" },
    { key = "pal_holy", name = "Luz", group = "Curación", title = "Luz sagrada al ratón",
      desc = "Cura al aliado bajo el ratón, a tu objetivo si es aliado o a ti mismo.",
      body = "#showtooltip\n/cast " .. HELP .. " {635}" },
    { key = "pal_flash", name = "Destello", group = "Curación", title = "Destello de Luz al ratón",
      desc = "Cura rápida al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {19750}" },
    { key = "pal_cleanse", name = "Limpiar", group = "Curación", title = "Purgación al ratón",
      desc = "Quita venenos, enfermedades y magia del aliado bajo el ratón, de tu objetivo o de ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {4987}" },
    { key = "pal_loh", name = "Manos", group = "Curación", title = "Imposición de manos al ratón",
      desc = "Toda tu vida al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {633}" },
    { key = "pal_bless", name = "Bendición", group = "Apoyo", title = "Bendiciones con modificadores",
      desc = "Al ratón o a tu objetivo: Poderío. Mayús: Sabiduría. Ctrl: Reyes. Alt: Salvación.",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,help][mod:shift] {19742}; [mod:ctrl,@mouseover,help][mod:ctrl] {20217}; [mod:alt,@mouseover,help][mod:alt] {1038}; [@mouseover,help][] {19740}",
      req = { 19740 } },
    { key = "pal_bop", name = "Protección", group = "Defensa", title = "Bendición de protección al ratón",
      desc = "Protege al aliado bajo el ratón (ideal para el sanador o el mago con aggro).",
      body = "#showtooltip\n/cast " .. HELP .. " {1022}" },
    { key = "pal_freedom", name = "Libertad", group = "Defensa", title = "Bendición de libertad al ratón",
      desc = "Libera de raíces y ralentizaciones al aliado bajo el ratón o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {1044}" },
    { key = "pal_bubble", name = "Burbuja", group = "Defensa", title = "Escudo divino (y quitarlo)",
      desc = "Escudo divino; si ya lo tienes, pulsarla otra vez lo quita (con Mayús).",
      body = "#showtooltip {642}\n/cancelaura [mod:shift] {642}\n/stopmacro [mod:shift]\n/cast {642}" },
}

---------------------------------------------------------------------------
-- Pícaro
---------------------------------------------------------------------------
C.ROGUE = {
    { key = "rog_cheap", name = "Golpe bajo", group = "Ataque", title = "Sigilo > Golpe bajo",
      desc = "Fuera de combate entra en sigilo; en sigilo, Golpe bajo.",
      body = "#showtooltip {1833}\n/cast [nostealth,nocombat] {1784}; {1833}" },
    { key = "rog_ambush", name = "Emboscar", group = "Ataque", title = "Sigilo > Emboscada",
      desc = "Fuera de combate entra en sigilo; en sigilo, Emboscada (con daga).",
      body = "#showtooltip {8676}\n/cast [nostealth,nocombat] {1784}; {8676}" },
    { key = "rog_ss", name = "Siniestro", group = "Ataque", title = "Golpe siniestro con ataque",
      desc = "Golpe siniestro y deja el ataque automático en marcha.",
      body = "#showtooltip\n/startattack\n/cast {1752}" },
    { key = "rog_sap", name = "Porrazo", group = "Control", title = "Sigilo > Porrazo al ratón",
      desc = "Entra en sigilo si no lo estás y aporrea al enemigo bajo el ratón o a tu objetivo.",
      body = "#showtooltip {6770}\n/cast [nostealth] {1784}; " .. HARM .. " {6770}" },
    { key = "rog_blind", name = "Ceguera", group = "Control", title = "Ceguera al ratón",
      desc = "Ciega al enemigo bajo el ratón sin cambiar de objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {2094}" },
    { key = "rog_gouge", name = "Gubia", group = "Control", title = "Gubia sin ataque",
      desc = "Gubia y para el ataque automático para no despertarlo.",
      body = "#showtooltip\n/cast {1776}\n/stopattack" },
    { key = "rog_distract", name = "Distraer", group = "Control", title = "Distraer donde apunta el ratón",
      desc = "Distraer directamente bajo el cursor.",
      body = "#showtooltip\n/cast [@cursor] {1725}" },
    { key = "rog_kick", name = "Patada", group = "Interrupción", title = "Patada al ratón",
      desc = "Corta el hechizo del enemigo bajo el ratón o de tu objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {1766}" },
    { key = "rog_vanish", name = "Esfumarse", group = "Defensa", title = "Esfumarse limpio",
      desc = "Para el ataque automático y te esfumas (sin él volverías a salir del sigilo).",
      body = "#showtooltip\n/stopattack\n/cast {1856}" },
    { key = "rog_poison", name = "Venenos", group = "Consumibles", title = "Venenos en tus armas",
      desc = "Pon tu mejor veneno instantáneo en la mano principal. Mayús: el mejor mortal (o entorpecedor) en la otra mano. Se actualiza sola.",
      dynamic = "poison" },
}

---------------------------------------------------------------------------
-- Mago
---------------------------------------------------------------------------
C.MAGE = {
    { key = "mag_poly", name = "Polimorfia", group = "Control", title = "Polimorfia al ratón o al foco",
      desc = "Oveja al enemigo bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {118}" },
    { key = "mag_cs", name = "Contra", group = "Interrupción", title = "Contrahechizo al ratón",
      desc = "Corta al enemigo bajo el ratón o a tu objetivo, aunque estés lanzando algo.",
      body = "#showtooltip\n/stopcasting\n/cast " .. HARM .. " {2139}" },
    { key = "mag_blink", name = "Traslación", group = "Defensa", title = "Traslación al instante",
      desc = "Corta lo que estés lanzando y te trasladas.",
      body = "#showtooltip\n/stopcasting\n/cast {1953}" },
    { key = "mag_block", name = "Bloque", group = "Defensa", title = "Bloque de hielo (y quitarlo)",
      desc = "Bloque de hielo. Pulsarla otra vez dentro del bloque lo quita.",
      body = "#showtooltip {11958}\n/stopcasting\n/cancelaura {11958}\n/cast {11958}" },
    { key = "mag_nova", name = "Nova", group = "Control", title = "Nova de escarcha al instante",
      desc = "Corta lo que estés lanzando y congela a todos los que tienes cerca.",
      body = "#showtooltip\n/stopcasting\n/cast {122}" },
    { key = "mag_pom", name = "Presencia", group = "Ataque", title = "Presencia mental + Piroexplosión",
      desc = "Presencia mental y Piroexplosión al instante (sin Piroexplosión, Bola de Fuego).",
      body = "#showtooltip\n/cast {12043}\n/stopcasting\n/cast {11366|133}" },
    { key = "mag_ai", name = "Intelecto", group = "Apoyo", title = "Intelecto arcano al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti. Mayús: Luminosidad arcana (todo el grupo).",
      body = "#showtooltip\n/cast [mod:shift] {23028}; " .. HELP .. " {1459}", req = { 1459 } },
    { key = "mag_decurse", name = "Maldición", group = "Apoyo", title = "Deshacer maldición menor al ratón",
      desc = "Quita una maldición al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {475}" },
    { key = "mag_water", name = "Agua", group = "Consumibles", title = "Beber o conjurar",
      desc = "Bebe tu mejor agua conjurada; si no te queda, conjura más. Mayús: conjura siempre. Se actualiza sola.",
      dynamic = "water", req = { 5504 } },
    { key = "mag_gem", name = "Gema", group = "Consumibles", title = "Gema de maná: usar o crear",
      desc = "Usa tu mejor gema de maná; si no tienes ninguna, crea la mejor que sepas. Se actualiza sola.",
      dynamic = "gem", req = { 759 } },
}

---------------------------------------------------------------------------
-- Sacerdote
---------------------------------------------------------------------------
C.PRIEST = {
    { key = "pri_shield", name = "Escudo", group = "Curación", title = "Escudo al ratón",
      desc = "Palabra de poder: escudo al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {17}" },
    { key = "pri_renew", name = "Renovar", group = "Curación", title = "Renovar al ratón",
      desc = "Renovar al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {139}" },
    { key = "pri_flash", name = "Destello", group = "Curación", title = "Sanación relámpago al ratón",
      desc = "Cura rápida al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {2061}" },
    { key = "pri_heal", name = "Sanar", group = "Curación", title = "Sanar / Sanación superior al ratón",
      desc = "Sanación superior (o Sanar, o Sanación inferior: la mejor que sepas) al aliado bajo el ratón.",
      body = "#showtooltip\n/cast " .. HELP .. " {2060|2054|2050}" },
    { key = "pri_focus", name = "Enfoque", group = "Curación", title = "Enfoque interno + Sanación superior",
      desc = "Enfoque interno (sin coste de maná) y Sanación superior al aliado bajo el ratón.",
      body = "#showtooltip {2060}\n/cast {14751}\n/cast " .. HELP .. " {2060}" },
    { key = "pri_dispel", name = "Disipar", group = "Curación", title = "Disipar magia al ratón",
      desc = "A un aliado le quita lo malo; a un enemigo, lo bueno. Bajo el ratón o tu objetivo.",
      body = "#showtooltip\n/cast [@mouseover,exists,nodead][] {527}" },
    { key = "pri_disease", name = "Enfermedad", group = "Curación", title = "Curar enfermedad al ratón",
      desc = "Abolir enfermedad (o Curar enfermedad) al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {552|528}" },
    { key = "pri_fort", name = "Entereza", group = "Apoyo", title = "Entereza al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti. Mayús: Rezo de entereza (todo el grupo).",
      body = "#showtooltip\n/cast [mod:shift] {21562}; " .. HELP .. " {1243}", req = { 1243 } },
    { key = "pri_swp", name = "Dolor", group = "Ataque", title = "Palabra de las Sombras: dolor al ratón",
      desc = "Pon el dolor en el enemigo bajo el ratón sin cambiar de objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {589}" },
    { key = "pri_scream", name = "Alarido", group = "Control", title = "Alarido psíquico al instante",
      desc = "Corta lo que estés lanzando y hace huir a los que tienes cerca.",
      body = "#showtooltip\n/stopcasting\n/cast {8122}" },
    { key = "pri_shackle", name = "Grilletes", group = "Control", title = "Encadenar no-muerto",
      desc = "Al no-muerto bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {9484}" },
    { key = "pri_fade", name = "Desvanecer", group = "Defensa", title = "Desvanecerse al instante",
      desc = "Corta lo que estés lanzando y te quita amenaza.",
      body = "#showtooltip\n/stopcasting\n/cast {586}" },
}

---------------------------------------------------------------------------
-- Brujo
---------------------------------------------------------------------------
C.WARLOCK = {
    { key = "wlk_fear", name = "Miedo", group = "Control", title = "Miedo al ratón o al foco",
      desc = "Al enemigo bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {5782}" },
    { key = "wlk_banish", name = "Desterrar", group = "Control", title = "Desterrar al ratón o al foco",
      desc = "Al demonio o elemental bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {710}" },
    { key = "wlk_coil", name = "Espiral", group = "Control", title = "Espiral de la muerte al instante",
      desc = "Corta lo que estés lanzando y lanza Espiral de la muerte.",
      body = "#showtooltip\n/stopcasting\n/cast " .. HARM .. " {6789}" },
    { key = "wlk_dots", name = "Dots", group = "Ataque", title = "Corrupción / Agonía al ratón",
      desc = "Corrupción al enemigo bajo el ratón. Mayús: Maldición de agonía. Para repartir dots sin cambiar de objetivo.",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,harm,nodead][mod:shift] {980}; " .. HARM .. " {172}",
      req = { 172 } },
    { key = "wlk_curse", name = "Maldición", group = "Ataque", title = "Maldiciones de banda",
      desc = "Maldición de los elementos. Mayús: de las Sombras. Ctrl: de temeridad. Alt: de lenguas.",
      body = "#showtooltip\n/cast [mod:shift] {17862}; [mod:ctrl] {704}; [mod:alt] {1714}; {1490}", req = { 704 } },
    { key = "wlk_petatk", name = "Atacar", group = "Mascota", title = "Ataque del demonio",
      desc = "Tu demonio ataca al enemigo bajo el ratón o a tu objetivo. Mayús: vuelve contigo.",
      body = "/petfollow [mod:shift]\n/stopmacro [mod:shift]\n/petattack [@mouseover,harm,nodead][]",
      req = { 688 }, icon = 688 },
    { key = "wlk_lock", name = "Bloqueo", group = "Interrupción", title = "Bloqueo de hechizo del manáfago",
      desc = "Tu manáfago corta al enemigo bajo el ratón o a tu objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {19244}" },
    { key = "wlk_seduce", name = "Seducir", group = "Control", title = "Seducción de la súcubo",
      desc = "Tu súcubo seduce al enemigo bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {6358}" },
    { key = "wlk_hs", name = "Piedra", group = "Consumibles", title = "Piedra de salud: usar o crear",
      desc = "Usa tu mejor piedra de salud; si no tienes, crea la mejor que sepas. Se actualiza sola.",
      dynamic = "healthstone", req = { 6201 } },
}

---------------------------------------------------------------------------
-- Druida
---------------------------------------------------------------------------
C.DRUID = {
    { key = "dru_shift", name = "Felino", group = "Formas y posturas", title = "Forma felina (cambio de forma)",
      desc = "Sale y vuelve a entrar en forma felina en una pulsación: te quita raíces y ralentizaciones y te devuelve energía.",
      body = "#showtooltip {768}\n/cancelaura {768}\n/cast {768}" },
    { key = "dru_bear", name = "Oso", group = "Formas y posturas", title = "Forma de oso (la mejor)",
      desc = "Forma de oso temible si la conoces; si no, forma de oso. No te saca de la forma si ya estás.",
      body = "#showtooltip\n/cast !{9634|5487}" },
    { key = "dru_prowl", name = "Abalanzar", group = "Ataque", title = "Acechar > Abalanzarse",
      desc = "Fuera de combate te pone en acecho (en forma felina); acechando, Abalanzarse (o Devastar con Mayús).",
      body = "#showtooltip\n/cast [nostealth,nocombat] {5215}; [mod:shift] {6785}; {9005}", req = { 5215 } },
    { key = "dru_ff", name = "Fuego", group = "Ataque", title = "Fuego feérico (en forma o no)",
      desc = "En forma de oso o felina: Fuego feérico (feral). Si no, el normal. Al ratón o a tu objetivo.",
      body = "#showtooltip\n/cast [nostance:0,@mouseover,harm,nodead][nostance:0] {16857}; " .. HARM .. " {770}",
      req = { 770 } },
    { key = "dru_roots", name = "Raíces", group = "Control", title = "Raíces enredadoras al ratón",
      desc = "Al enemigo bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {339}" },
    { key = "dru_hibernate", name = "Hibernar", group = "Control", title = "Hibernar al ratón o al foco",
      desc = "A la bestia o dragón bajo el ratón o a tu objetivo. Mayús: a tu foco.",
      body = "#showtooltip\n/cast [mod:shift,@focus,harm,nodead][@mouseover,harm,nodead][] {2637}" },
    { key = "dru_growl", name = "Gruñido", group = "Defensa", title = "Gruñido al ratón",
      desc = "Provoca al enemigo bajo el ratón o a tu objetivo (en forma de oso).",
      body = "#showtooltip\n/cast " .. HARM .. " {6795}" },
    { key = "dru_rejuv", name = "Rejuvenecer", group = "Curación", title = "Rejuvenecimiento al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {774}" },
    { key = "dru_regrowth", name = "Recrecer", group = "Curación", title = "Recrecimiento al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {8936}" },
    { key = "dru_ht", name = "Toque", group = "Curación", title = "Toque de sanación al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti. Si tienes Presteza de la naturaleza lista, la usa antes (Mayús).",
      body = "#showtooltip {5185}\n/cast [mod:shift] {17116}\n/cast " .. HELP .. " {5185}", req = { 5185 } },
    { key = "dru_innervate", name = "Estimular", group = "Apoyo", title = "Estimular al ratón",
      desc = "Al sanador bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {29166}" },
    { key = "dru_rebirth", name = "Renacer", group = "Apoyo", title = "Renacer al ratón",
      desc = "Resucita en combate al aliado muerto bajo el ratón o a tu objetivo.",
      body = "#showtooltip\n/cast [@mouseover,help,dead][] {20484}" },
    { key = "dru_motw", name = "Marca", group = "Apoyo", title = "Marca de lo Salvaje al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti. Mayús: Don de lo Salvaje. Ctrl: Espinas.",
      body = "#showtooltip\n/cast [mod:shift] {21849}; [mod:ctrl,@mouseover,help,nodead][mod:ctrl] {467}; " .. HELP .. " {1126}",
      req = { 1126 } },
    { key = "dru_cleanse", name = "Limpiar", group = "Curación", title = "Quitar maldición / veneno al ratón",
      desc = "Quitar maldición al aliado bajo el ratón. Mayús: Suprimir veneno (o Curar veneno).",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] {2893|8946};" .. HELP .. " {2782}",
      req = { 2782 } },
}

---------------------------------------------------------------------------
-- Chamán
---------------------------------------------------------------------------
C.SHAMAN = {
    { key = "weapon", name = "Armas", group = "Armas", title = "Dos manos / una mano",
      desc = "Cambia entre tu última arma de dos manos y tu última arma de una mano con lo que llevabas en la otra mano (escudo, arma, objeto o nada). Recuerda sola lo último que llevaste.",
      dynamic = "weapon" },
    { key = "sha_kick", name = "Cortar", group = "Interrupción", title = "Choque de tierra (rango 1) al ratón",
      desc = "El rango 1 corta igual y casi no gasta maná: la interrupción clásica del chamán.",
      body = "#showtooltip {8042}\n/cast " .. HARM .. " {8042r}" },
    { key = "sha_shock", name = "Choque", group = "Ataque", title = "Choques con modificadores",
      desc = "Choque de tierra al ratón o a tu objetivo. Mayús: de llamas. Ctrl: de escarcha.",
      body = "#showtooltip\n/cast [mod:shift] {8050}; [mod:ctrl] {8056}; " .. HARM .. " {8042}", req = { 8042 } },
    { key = "sha_purge", name = "Purgar", group = "Ataque", title = "Purgar al ratón",
      desc = "Quita un beneficio del enemigo bajo el ratón o de tu objetivo.",
      body = "#showtooltip\n/cast " .. HARM .. " {370}" },
    { key = "sha_totems", name = "Tótems", group = "Apoyo", title = "Tus tótems uno tras otro",
      desc = "Fuerza de la tierra, Abrasador, Fuente de maná y Viento furioso pulsando la misma tecla. Se reinicia al salir de combate o a los 2 minutos.",
      body = "#showtooltip\n/castsequence reset=combat/120 {8075}, {3599}, {5675}, {8512}", req = { 8075 } },
    { key = "sha_hw", name = "Ola", group = "Curación", title = "Ola de sanación al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti. Mayús: Ola de sanación inferior.",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] {8004}; " .. HELP .. " {331}",
      req = { 331 } },
    { key = "sha_chain", name = "Cadena", group = "Curación", title = "Sanación en cadena al ratón",
      desc = "Al aliado bajo el ratón, a tu objetivo o a ti.",
      body = "#showtooltip\n/cast " .. HELP .. " {1064}" },
    { key = "sha_ns", name = "Presteza", group = "Curación", title = "Presteza de la naturaleza + Ola",
      desc = "Presteza de la naturaleza y Ola de sanación al instante al aliado bajo el ratón.",
      body = "#showtooltip {331}\n/cast {16188}\n/cast " .. HELP .. " {331}" },
    { key = "sha_cure", name = "Curar", group = "Curación", title = "Curar veneno / enfermedad al ratón",
      desc = "Curar veneno al aliado bajo el ratón. Mayús: Curar enfermedad.",
      body = "#showtooltip\n/cast [mod:shift,@mouseover,help,nodead][mod:shift] {2870}; " .. HELP .. " {526}",
      req = { 526 } },
}
