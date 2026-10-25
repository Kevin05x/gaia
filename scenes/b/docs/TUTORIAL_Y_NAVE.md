# Tutorial del Sol 1 y nave de fuga (bloque D, 24 oct 2026)

## Tutorial del Sol 1
- Contenido en `content/tutorial.json`: lista de `pasos` (`id`, `texto` es/en, `resalta`, `condicion`) y `hasta_sol`.
- `sim/tutorial_data.gd` carga y valida (`INVALID_JSON`, `MISSING_FIELD:pasos`, `DUPLICATE_STEP`, `MISSING_TEXT`, `UNKNOWN_HIGHLIGHT`, `MISSING_CONDITION`, `INVALID_CONDITION`).
- `sim/systems/tutorial_system.gd`: cuenta los eventos de la simulación (`MOVE_DONE`, `ACTION_DONE[:acción]`, etc.) en `estado.tutorial_contadores` y da por hechos los pasos cuando se cumple su condición. Los pasos que el jugador adelanta se saltan solos.
- Condiciones: `{"evento": "MOVE_DONE", "min": 1}`, `{"tipo": "edificio|antena|enviados", "id"?, "min": n}` y `{"leer_s": s}` (paso de lectura). El tutorial termina al acabar los pasos, al saltarlo (`tutorial_skip`) o al pasar de `hasta_sol`.
- Vista: `scenes/b/tutorial_panel.gd` (tarjeta arriba a la derecha con «Saltar tutorial» y un halo que pulsa sobre el botón señalado: Construir, barra de acciones o enlace). Se oculta con una escena, la pausa o los ajustes; no bloquea el juego. Un paso completado hace sonar el aviso.
- Pasos actuales: mover el rover → hacer un análisis → panel solar → antena Nv. 1 → transmitir → aviso de fauna y torretas.
- El estado (`tutorial_*`) viaja en la partida guardada.

## Nave de fuga (última misión)
- Edificio `nave_fuga` en `content/economia.json`, **construido por 4 módulos** (campo `modulos`; cada módulo es un nivel del edificio): 1 Plataforma y motores (rocas 50, olivino 30, 14 s), 2 Tanque y propulsores (rocas 60, olivino 30, hielo 30, 18 s), 3 Cápsula de tripulación (rocas 30, olivino 20, hielo 15, xenolito 20, 16 s), 4 Torre de escape (rocas 10, olivino 10, hielo 15, xenolito 20, 12 s). `requiere` hangar, `requiere_antena` 3 y `requiere_final` (solo aparece en el menú después de decidir el clímax). `construir` levanta el módulo 1; el resto se pide desde el menú con «Construir siguiente módulo» (orden `build_module {id}`). 400 de vida; máximo 1. Costos y tiempos provisionales, todo ajustable en datos.
- `content/historia.json`: `"nave": "nave_fuga"` y el nodo de radio `nave_fuga` (condición nueva `final_decidido`), al que llevan las opciones de ambos clímax (salvo «Silencio orbital», que termina la partida). Opción con `"cierra": true` = fin de la cadena de nodos.
- `OutcomeSystem.requiere_nave`: con historia, ganar exige datos al 100 %, clímax decidido **y** la nave con todos sus módulos (`requiere_nave_nivel` = número de módulos). El informe añade `CAUSE_SHIP`. Incluso el sacrificio de Rocky (que completa la transmisión al instante) necesita la nave.
- La obra se juega con las oleadas en marcha: hay que defender la base mientras se construye.
- Modelo por código (`scenes/b/escape_ship.gd`), inspirado en el SLS/Orion de la NASA: plataforma con motores, tanque central naranja con dos propulsores blancos, cápsula de tripulación con panel solar y torre de escape; torre de lanzamiento con brazos. Cada módulo es una malla fundida aparte (`Cuerpo/Modulo1..4`); el módulo en obra crece según el avance y los anteriores ya están completos. Se sustituirá por el del equipo (ver «Qué necesitamos del equipo»). La radio de la nave usa la ilustración `assets/historia/nave_fuga.jpg` (captura del juego).
