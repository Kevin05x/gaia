# Entrega B y conexión con A

## Qué se entrega

`scenes/b/mission.tscn` es la escena de producción. No depende de autoloads, no calcula energía, victoria o rutas y no crea una simulación. Incluye terreno, actores, HUD, cámara, EDL, audio e informe. Tiene un hijo `Port` que es la única frontera con A.

`scenes/b/review.tscn` ejecuta la misma escena con `review_host.gd`, un proveedor de estados para revisión manual y automatizada. Está identificado en pantalla. F2 abre inyección de estados (diseños, tormenta, noche, modo seguro, informes). No debe confundirse con la simulación definitiva del equipo. El archivo principal del proyecto apunta temporalmente a esta revisión para que B se pueda ejecutar antes de recibir A. A cambia el arranque a su flujo/taller cuando lo conecte.

No se modifica `sim/`, `autoload/`, `content/`, CI ni el taller de A. B queda en una carpeta propia para reducir conflictos. La reparación de `project.godot` es la única configuración compartida necesaria para abrirlo.

## Conectar sin EventBus

```gdscript
var view = preload("res://scenes/b/mission.tscn").instantiate()
add_child(view)
var port = view.get_node("Port")
port.connected_backend = true
port.command_requested.connect(_on_presentation_command)
port.apply_snapshot(snapshot_completo_de_game_state)
```

Conecta tu proveedor antes de enviar el primer snapshot. A debe traducir estas intenciones a sus métodos de simulación. No conectes `review_host.gd` junto a A. Los botones solo solicitan; la vista espera estado confirmado.

| Orden | Payload |
| --- | --- |
| `select` | `{target_id: String}`; A recalcula disponibilidad según objetivo |
| `move` | `{tile: Vector2i}` |
| `approach` | `{target_id: String}`; A decide casilla adyacente y ruta |
| `act` | `{target_id: String, action: String}` |
| `transmit` | `{on: bool}` |
| `upgrade` | `{}` |
| `pause` | `{paused: bool}` |
| `landing_finished` | `{}`; A habilita fase operations y reloj |
| `redesign` | `{}`; A regresa al taller y limpia la misión |

Acciones: `panorama`, `spectrometer`, `drill`, `radar`, `drone`, `companion`. A debe aprobar esos identificadores o cambiar el mapeo. No se deduce la disponibilidad desde el aspecto del instrumento.

## Snapshot completo

Es un Dictionary de GDScript (Vector2i son coordenadas, no cadenas). Ejemplo mínimo representativo:

```gdscript
{
 "phase": "operations", # workshop / landing / operations / report
 "paused": false, "safe_mode": false, "safe_entries": 0,
 "sol": 1, "hour": 8.0,
 "rover_tile": Vector2i(0, 0), "station_tile": Vector2i(3, 3),
 "battery": {"wh": 900.0, "capacity": 1000.0, "generation_w": 110.0, "load_w": 15.0},
 "design": {"power": "solar", "comms": "relay",
   "instruments": ["panorama", "drill", "spectrometer", "meteo", "radar", "drone"], "companion": true},
 "data": 15.0, "memory_capacity": 60.0, "sent": 30.0, "goal": 100,
 "mineral": 3, "antenna_level": 2, "dust": 0.12,
 "storm": false, "storm_in": 2.0,
 "transmitting": false, "link_open": true, "comms_windows": [[8, 11], [17, 20]],
 "moving": false, "busy": false,
 "map_revision": 1,
 "targets": [{"id": "JZ-01", "tile": Vector2i(2,-2), "type": "rock", "revealed": true, "depleted": false}],
 "obstacles": [Vector2i(4,0)],
 "available_actions": {
  "approach": {"enabled": true, "reason": ""},
  "drill": {"enabled": false, "reason": "TOO_FAR"},
  "transmit": {"enabled": true, "reason": ""}
 }
}
```

Incluye en `available_actions` todas las acciones y `approach`, `transmit`, `upgrade`. Las ausentes quedan deshabilitadas para evitar inventar reglas. Las razones son claves traducibles en el catálogo de UI o el de A.

Tipos de objetivo: `rock`, `mineral`, `buried`. IDs únicos y estables. Cambia `map_revision` cuando cambien posiciones, tipos o conjunto de objetivos/obstáculos. Revelado y agotamiento se actualizan en snapshots sin reconstruir el mapa. `rover_tile` siempre es la última posición confirmada. Al cargar o teletransportar usa `teleport=true` en un solo snapshot para cancelar una ruta anterior.

Coordenadas: X horizontal de cuadrícula, Y de Vector2i corresponde a Z del mundo; 1 casilla = 2 metros; límites del mapa actual -35..35 (71×71 casillas; ver `MAPA_GRANDE.md`). El relieve de +/-18 cm es cosmético. A usa la misma cuadrícula y casillas bloqueadas. Si cambia el mapa/límite del producto, actualiza también minimapa y conversión visual.

`chapter_title_key` y `brief_key` opcionales seleccionan textos de capítulos; A registra sus traducciones. No hay historia obligatoria incrustada en las reglas de la vista.

## Rutas y acciones aceptadas

```gdscript
# Una ruta aceptada, SIN incluir la casilla de salida:
port.present_path([Vector2i(1,0), Vector2i(2,0)], 0.65)
# El tiempo de cada tramo lo entrega A; puede reenviar rutas por tramo para arena.
port.present_action({"target_id": "JZ-01", "action": "drill", "seconds": 4.0})
port.reject("LOW_ENERGY")
port.cancel_presentation() # si una acción/ruta se cancela
```

Envía snapshot inmediatamente después de cada cambio. Al terminar una ruta, confirma la posición; al terminar una acción, entrega datos/energía/disponibilidad. Al pausar, los relojes visuales se detienen; A también pausa su simulación. El modo seguro cancela animaciones y bloquea entrada. Para cargar una partida, instancia vista nueva y entrega snapshot completo; no dependas solo de señales de cambios incrementales.

## Informe

Primero envía phase=`report` y después:

```gdscript
port.present_report({
 "success": true, "stars": 3, "sent": 100, "goal": 100, "sol": 4,
 "causes": ["CAUSE_SUCCESS", "CAUSE_SOLAR"],
 "photo": nasa_texture, # Texture2D o null: hay respaldo original
 "photo_credit": "Crédito comprobado de la imagen concreta",
 "photo_url": "https://pagina-de-la-fuente"
})
```

B no calcula estrellas ni causas en la escena de informe. Causas también pueden ser `{key, values}` para textos con parámetros. Las fotos, descarga/cache/datasets y sus metadatos los entrega NasaApi de A. B muestra foto/crédito/fuente y conserva una ilustración si no hay imagen.

## Adaptador opcional al contrato del documento

`event_bus_adapter.gd` escucha las señales originales y convierte las órdenes. Se usa así:

```gdscript
var adapter = preload("res://scenes/b/event_bus_adapter.gd").new()
add_child(adapter)
adapter.bind(port, EventBus, snapshot_inicial_completo)
```

Escucha `sol_advanced`, `battery_changed`, `data_changed`, `storm_changed`, `storm_warned`, `safe_mode`, `rover_path`, `action_started`, `target_revealed`, `mission_ended`. Se desconecta al salir.

El documento original no definía disponibilidad, posición confirmada, minerales, nivel de antena, pausa, selección ni aproximación. Para una conexión completa A debe añadir `snapshot_changed(snapshot: Dictionary)` y las órdenes `cmd_select_target`, `cmd_approach_target`, `cmd_pause`, `cmd_redesign`, `cmd_landing_finished`; se conservan los cuatro comandos originales. Todo cambio del EventBus se revisa por A y B. Si una señal no existe, el adaptador rechaza la orden en vez de fingir éxito. También puede conectarse directamente el Port, evitando ampliar el autoload.

## Recursos y arte

Modelos finales originales low-poly en `assets/models/*.tscn`, también GLB para Blender. No son mallas NASA ni réplicas científicamente exactas. `art.gd` conserva su fuente reproducible; `tools/bake_assets.gd` reconstruye TSCN/GLB/preview. La escena de producción carga los modelos guardados, por lo que las mejoras artísticas se editan en sus TSCN. Si rebakeas, reemplaza las ediciones manuales: guarda copia o modifica primero la fuente.

Rover: seis ruedas con pivote, mast/cámaras, brazo articulado, taladro, paneles, RTG, espectrómetro, radar y meteo. Dron: dos rotores y patas; compañero original Nódulo; estación: tres antenas excluyentes. Los modelos NASA específicos del plan F0 no se incluyen ni se atribuyen falsamente; A/B pueden sustituir el visual conservando pivotes.

## Límites de la entrega compartida

B entrega las vistas y su frontera de integración. No certifica la simulación ausente de A, el uso efectivo de datasets NASA, el calendario/conformidad del concurso, aprobación de arte del grupo, video de una misión final ni publicación. Al integrar A, ambos deben jugar una misión completa y revisar balance, créditos de fotos y datos y rendimiento en la laptop más débil.

## Editar textos

La fuente es `i18n/strings_ui.csv`. Ejecutar `python scenes/b/tools/sync_i18n.py` tras editarla y confirmar también el `catalog.gd` generado. El catálogo embebido evita depender de archivos de traducción generados durante la primera importación, que causaron los errores anteriores. Las dos lenguas deben conservar los mismos parámetros de formato.

## Contrato v2 (diseño nuevo, 23 oct 2026)

Propuesta de A para el diseño visual consolidado (`GAIA_DISENO_VISUAL_CONSOLIDADO.md`). **Solo añade**: las claves y órdenes de arriba siguen igual. Kevin autorizó modificar el trabajo de B donde el diseño lo pida; los puntos marcados como *por decidir* los resuelven A y B juntos.

Cambio de cámara fuera del contrato: la vista actual usa cámara ortográfica (`camera.size`); el diseño objetivo es perspectiva elevada. Afecta a la selección por clic y a la proyección de marcadores (`Camera3D.unproject_position`), y es trabajo de B.

### Fases

`phase` admite ahora `"workshop"` además de `landing`, `operations` y `report`. En `workshop` el snapshot incluye la clave `workshop` (más abajo).

### Campos nuevos del snapshot de operaciones

```gdscript
{
 "is_night": false,                 # hora fuera de [amanecer, atardecer) de balance.json
 "dust": 0.12,                      # 0..1; incluye la tormenta. A lo sube y baja de forma continua
 "link_next": {"opens": true, "hour": 17.0, "sol": 1},   # próximo cambio del enlace; opens=false: próximo cierre
 "bounds": {"min": Vector2i(-35, -35), "max": Vector2i(35, 35)},   # últimas casillas válidas (mapa grande)
 "zones": [{"id": "orilla", "center": Vector2i(-12, -12)}],   # zonas del mapa (el centro más cercano manda)
 "rover_zone": "orilla",   # zona donde está el rover
 "warnings": [
   {"id": "LOW_BATTERY", "severity": "warning", "key": "WARN_LOW_BATTERY", "values": [18]}
 ],
 "targets": [{"id": "JZ-01", "tile": Vector2i(2, -2), "type": "rock", "revealed": true, "depleted": false,
   "actions": [{"id": "spectrometer", "enabled": true, "reason": ""}, {"id": "drill", "enabled": false, "reason": "TOO_FAR"}],
   "primary": "spectrometer"}]
}
```

- **`warnings`**: ordenados por prioridad (críticos primero). `severity` es `"warning"` o `"critical"`. Ids previstos: `SAFE_MODE` (crítico), `LOW_BATTERY`, `STORM_ACTIVE`, `STORM_SOON`, `LINK_OPENING_SOON`, `MEMORY_ALMOST_FULL`. `values` son los argumentos del formato del texto (`texto % values`, igual que las causas del informe). Los umbrales viven en `content/balance.json` (sección `avisos`, valores provisionales), no en la vista. Los textos `WARN_*` ya están en `strings_ui.csv`.
- **`targets[].actions`**: solo en objetivos **revelados**; ordenadas, con la principal en `primary`. La vista no decide qué acción es pertinente ni cuál es la principal. Los objetivos sin revelar siguen llegando con `revealed: false` y la vista **nunca** los señala (ni marcador ni flecha de borde).
- **Acciones por tipo de objetivo (propuesta)**: `rock` → principal `spectrometer`, luego `drill`; `mineral` → principal `drill`, luego `spectrometer`; `buried` (ya revelado) → solo `drill`. `panorama`, `radar`, `drone`, `companion`, `upgrade` y `transmit` no dependen del objetivo y siguen en `available_actions`.
- **`bounds`**: la cuadrícula visible y la previsualización de ruta terminan en la última casilla válida.

### Motivos de rechazo

Se conservan los de v1: `LANDING`, `MISSION_END`, `PAUSED`, `SAFE`, `MOVING`, `BUSY`, `NO_TARGET`, `NO_INSTRUMENT`, `LOW_ENERGY`, `TOO_FAR`, `DEPLETED`, `MEMORY_FULL`, `WEATHER`, `NIGHT`, `FLIGHT_USED`, `MAX_LEVEL`, `NO_MINERAL`, `NO_LINK`, `NO_DATA`. Nuevos: **`OUT_OF_BOUNDS`** («Fuera del área operativa») y **`NO_PATH`** («Casilla bloqueada o sin ruta»). `move` a una casilla fuera de `bounds` se responde con `port.reject("OUT_OF_BOUNDS")`; a un obstáculo, la estación, un objetivo o una casilla sin ruta, con `port.reject("NO_PATH")`. Ambos textos ya están en `strings_ui.csv`. También: **`ALREADY_NEAR`** (`approach` cuando el rover ya está junto al objetivo) y **`WRONG_PHASE`** (orden fuera de su fase).

### Taller (`phase == "workshop"`)

Órdenes nuevas, además de las de v1:

| Orden | Payload |
| --- | --- |
| `design_add` | `{part_id: String}` |
| `design_remove` | `{part_id: String}` |
| `design_validate` | `{}` |
| `design_start` | `{}`; solo se acepta tras una validación correcta; A pasa a `landing` |

```gdscript
snapshot["workshop"] = {
 "categories": [{"id": "cohetes", "parts": [
   {"id": "cohete_ligero", "name_key": "PIEZA_COHETE_LIGERO", "capacity_kg": 600, "mass_kg": null,
    "cost_musd": 150, "power_w": null, "pending": false, "available": true, "reason": ""}]}],
 "selection": {"cohetes": ["cohete_ligero"], "chasis": [], "energia": [], "comunicaciones": [], "extras": []},
 "totals": {"mass_kg": 0.0, "cost_musd": 150.0, "capacity_kg": 600.0, "power_w": 0.0, "budget_musd": 700.0},
 "validation": ["BELOW_MIN:energia", "OVER_MASS"],
 "notices": ["PENDING_DATA:radar"],
 "valid": false
}
```

Reglas del taller (A): `design_add` rechaza con `CATEGORY_FULL` si la categoría ya tiene su máximo (quitar primero con `design_remove`) y con `UNKNOWN_PART` si el id no existe; `design_remove` rechaza con `UNKNOWN_PART` si la pieza no estaba elegida; `design_validate` y `design_start` rechazan con `INVALID_DESIGN` (los detalles están en `workshop.validation`). `parts[].available` y `reason` dicen si esa pieza se puede agregar ahora. `redesign` devuelve al taller desde cualquier otra fase, limpia la misión y **conserva las piezas elegidas**. Los textos de cada pieza (`PIEZA_*`) ya están en `strings_ui.csv`; los nombres de categoría los pone la vista.

Los ids de categoría y pieza son ids de datos (`content/parts.json`), no textos de interfaz. `null` significa dato aún no definido y la tarjeta muestra «Pendiente». `validation` y `notices` usan los códigos de `MissionDesign` (`BELOW_MIN:cat`, `ABOVE_MAX:cat`, `OVER_MASS`, `OVER_BUDGET`, `PENDING_DATA:id`). La vista no calcula totales ni valida.

### De piezas del taller a diseño de misión

| Pieza (`parts.json`) | `design` del snapshot |
| --- | --- |
| `panel_solar` / `mmrtg` | `power`: `"solar"` / `"rtg"` |
| `antena_rele` / `antena_directa` | `comms`: `"relay"` / `"direct"` |
| `camara` | instrumento `panorama` |
| `espectrometro`, `taladro`, `radar`, `dron` | `spectrometer`, `drill`, `radar`, `drone` |
| `meteo` | `meteo` |
| `bateria` | efecto sobre la capacidad: pendiente de datos |
| `companero` | `companion: true` |

El compañero es la pieza `companero` (decidido), con masa, costo y potencia pendientes.

### Informe

`present_report` no cambia de forma. Propuesta de reglas (calculadas por A): **3 estrellas**, una por cada criterio cumplido: (1) `sent >= goal`; (2) `safe_entries == 0`; (3) misión terminada con al menos un sol de margen (`sol < límite de soles`). El límite se lee así: la misión termina al acabar el sol 6; si pasa a sol 7 sin la meta, fracasa. Fracasa también con la segunda entrada en modo seguro. Las causas usan claves `CAUSE_*`; A reutiliza las del catálogo de B y añade las que falten. La foto sale de una lista corta verificada incluida en el juego (título, crédito, enlace), elegida según el resultado; la descarga en vivo es opcional y, si falla, B muestra su ilustración de respaldo.

### Aterrizaje

Sin datos nuevos. El texto «Descenso en curso» es fijo. `landing_finished` no cambia.

### Luz

La luz depende de `hour` (amanecer 06:00, atardecer 18:00) y de `dust` (0..1). La simulación sigue siendo la única que decide la producción de energía; la luz es solo apariencia.

### Por decidir (A y B)

- Valores finales de los umbrales de los avisos (hoy provisionales).

### Decidido (Kevin, 23 oct 2026)

- Mapa fijo en `content/mapa.json` (límites, inicio del rover, estación, obstáculos y objetivos). `MapData` lo valida y lo vuelca en el estado.
- La estación está lejos, en un extremo (casilla (-9, -9)), es solo referencia visual y bloquea el paso. El enlace y la antena funcionan desde cualquier lugar.
- Los objetivos también bloquean el paso: el rover se acerca a una casilla contigua.
- Movimiento: ruta más corta en 4 direcciones; toda la energía de la ruta se descuenta al aceptar la orden y, si no alcanza, se rechaza con `LOW_ENERGY`.

## Rediseño visual implementado (rama `a/rediseno-visual`)

Estado de la vista frente al contrato v2. Todo lo de arriba se cumple; esto es lo que cambió o se decidió al implementarlo.

- **Snapshot**: se añadió `sol_limit` (soles de la misión, hoy 6; sale de `MissionState.sol_limite`). El HUD lo usa en «Sol 3 / 6» y la barra del sol.
- **Arranque**: `MissionRunner` ahora empieza en el **taller** (`phase == "workshop"`). `saltar_taller = true` mantiene el atajo anterior (diseño inicial completo, directo al aterrizaje) y es lo que usan las pruebas de `test_mission_runner.gd`.
- **Acciones globales** (panorama, radar, dron, compañero, transmitir, mejorar antena): barra inferior central con un botón por instrumento instalado (`available_actions` + `design`). Las acciones de un objetivo (`targets[].actions`) salen en su panel, con `primary` resaltada. Un botón deshabilitado muestra el `reason` traducido (la clave del motivo, p. ej. `TOO_FAR`); la vista no decide nada.
- **Taller** (`scenes/b/workshop.gd`): solo presenta `snapshot["workshop"]` y emite `design_add/remove/validate/start`. Cambiar la pieza de una categoría de una sola pieza emite `design_remove` y luego `design_add` (dos órdenes seguidas del mismo gesto). Antes de iniciar exige una validación correcta.
- **Cámara**: perspectiva elevada que sigue al rover (`camera.gd`); ya no hay `camera.size`. La selección por clic usa rayos y los marcadores 2D proyectan con `unproject_position` (`target_markers.gd`).
- **Luz** (`sky_light.gd`): tabla por hora con mezcla por `dust`; la energía de juego no depende de ella.
- **Mundo** (`terrain.gd`, `world_art.gd`, `tracks.gd`): suelo continuo facetado, cuenca y montañas lejanas, huellas del rover. Todo procedural, sin texturas externas.
- **Textos nuevos**: están en `strings_ui.csv`; después de editarlos se ejecuta `python3 scenes/b/tools/sync_i18n.py` para regenerar `catalog.gd`.
- **Fuentes**: `UI.font()` usa Inter y Space Grotesk si están en `res://assets/fonts/`; si no, usa la fuente por defecto de Godot. Descargarlas requiere decidirlo (licencia SIL OFL).
- **Pruebas**: `tests/test_ui_rediseno.gd` cubre cielo, relieve, minimapa, taller y HUD; `scenes/b/tests/integration.gd` sigue pasando.

### Segundo pase: realismo del mundo (23 oct 2026)

Tras comparar con el mockup (render casi fotorrealista), se acercó el aspecto sin salir de la geometría simple:

- **Terreno**: suelo continuo con normales suaves, dunas de gran escala y color por vértice; el facetado se reserva para rocas. Lomas lejanas con normales suaves, más bajas y con bruma. Un lago pálido en la cuenca, delante de la vista inicial, y un pasillo despejado de mesetas hacia él.
- **Rocas** (`world_art.gd`): nuevas familias `pebble` (piedritas), `boulder` (peñasco con capas sedimentarias por franjas de tono) y `mesa_mesh()` (mesetas estratificadas). Los objetivos «roca» son ahora peñascos, no pilas de láminas. Decorado en MultiMesh: ~800 piedritas, ~200 fragmentos, bloques, peñascos y ~50 mesetas.
- **Color y luz**: paleta más apagada y terrosa; tonemap Reinhard con exposición 0.85 y energía solar 0.7; cielo y bruma grisáceos. Parámetros en `sky_light.gd` (`tonemap`, `exposure`, `energy_scale`).
- **Selección**: contorno brillante con pulso de 1600 ms (casco invertido) en lugar de solo el anillo.
- **Huellas** iniciales que llegan al punto de aterrizaje (`tracks.seed_curve`).
- **Cámara**: zoom por defecto 18 m (antes 25) y mínimo 9 m; el rover ocupa un tamaño parecido al del mockup.
- **HUD**: píldoras con nombre («Energía 82 %», «Ciencia 34/100»); «Sol 2 · 10:32» sin píldora, con sombra; la fila de acciones es más compacta y ya no choca con la píldora de comunicación.
- **Modelos**: rover más claro, ruedas más grandes y techo oscuro; estación con módulos en caja. Se volvieron a generar `rover.tscn` y `station.tscn` con `tools/bake_assets.gd` (los `.glb` no se tocaron porque el repositorio los guarda con Git LFS).
- **Rendimiento** (medido en el motor con la partida completa, 1280×720, render por software): el rover tenía ~85 mallas sueltas; `Art.merged()` y `Art.optimize_*()` las fusionan al cargar (las piezas que se animan o se ocultan quedan aparte). Llamadas de dibujo 393 → 207 (de ellas ~109 son del HUD en 2D) y ~54 000 primitivas incluyendo sombras. Falta medir en la laptop más débil y en la exportación web.

### Pendiente de la vista

- Foto de la NASA en el informe: el informe ya acepta `photo`, `photo_credit` y `photo_url`; falta que A los entregue desde una lista corta verificada (título, crédito, enlace).
- Medir rendimiento en la exportación web (objetivo: ≤ 60 000 triángulos y ≤ 120 llamadas de dibujo) y, si hace falta, ajustar `ENERGY_SCALE` del sol.
- Declarar el uso de arte generado por IA en `ARTE_Y_LICENCIAS.md` si se incorpora (las fuentes ya están declaradas).

### Tercer pase: piedras facetadas, sombras y calidad (23 oct 2026)

- `world_art.gd`: las rocas (`pebble`, `fragment`, `block`, `boulder`, `outcrop`) se generan por intersección de planos (`STONE_PRESETS`, `stone_mesh`): caras planas de arista viva, 3 variantes por familia.
- `terrain.gd`: cada familia de decoración se reparte en 3 variantes (un MultiMesh por variante); las rocas grandes cercanas proyectan sombra solo en calidad alta (`apply_quality()`); obstáculos con colores más cercanos al suelo.
- `sky_light.gd`: sombra `SHADOW_ORTHOGONAL` (1 pasada) y corrección de color (contraste 1.1, saturación 0.96) solo en calidad alta.
- `mission_view.gd`: `set_preferences` aplica `W.quality`, `W.apply_quality()` y `terrain.apply_quality()`: la opción «calidad alta» controla texturas, sombras de rocas y corrección de color.
- Presupuesto medido en calidad alta: ≈69k primitivas y 245 llamadas de dibujo (HUD ≈109). Sin sombras de rocas ≈61k.

### Cuarto pase: modelos, lago y botones (23 oct 2026)

- `art.gd`: `bevel_mesh`/`rbox` (cajas con chaflán por intersección de planos), `dish_mesh` (parábola de revolución) y `panel` (panel solar con marco y celdas). Rover: casco biselado, 4 paneles solares en el techo, mástil con cabeza de cámaras, antena de alta ganancia, RTG horizontal con aletas, ruedas de 12 grampas con llanta. Estación: módulos biselados, torre de celosía con baliza, tanques y antenas parabólicas. `merged()` acepta mallas propias. Los nombres de nodo animados (`Wheel0..5`, `arm`, `head`, `solar`, `rtg`, `drill`, `radar`, `spectrometer`, `meteo`, `AntennaLevel1..3`) se conservan. `rover.tscn`/`station.tscn` re-horneados con `tools/bake_assets.gd` (los `.glb` no se tocan).
- `terrain.gd`: lago más grande, en malla polar con color por vértice (bancos de arena, orilla húmeda, vetas) y material brillante (`W.water_material()`); con calidad alta el cielo se refleja (`reflected_light_source = SKY` en `sky_light.gd`).
- `ui_style.gd`: botones con relleno cálido, sombra suave, borde ámbar al pasar el cursor y anillo de foco ámbar; variantes `PrimaryButton` / `PrimaryPill` (relleno ámbar) para Validar/Iniciar, Reanudar, Transmitir y Rediseñar; interruptores sin marco resaltado.
- `hud.gd`: `_layout_actions()` coloca la fila de acciones sin pisar el panel de comunicación (más ancho: 336 px) ni el reloj; paneles de menú/opciones al 95 % de opacidad.
- `workshop.gd`: las piezas se reparten en una cuadrícula que baja de línea (antes una tira horizontal cortaba tarjetas), vista previa más baja, tarjetas con borde ámbar al elegirse.

### Compañero y dron (23 oct 2026)

- `art.gd`: el compañero es ahora un robot explorador con orugas, cabeza con cámaras, panel solar, pinza y antena (`Body` sigue siendo el casco); el dron es un helicóptero tipo Ingenuity con panel solar, patas con pies, cámara ventral y dos rotores coaxiales (`Rotor0`/`Rotor1` son nodos que giran con sus aspas y cubo).
- `merged()` ahora funde también los grupos marcados con el metadato `fusionable` (paneles solares), y `cylinder()` admite número de segmentos (barras finas con 6, ruedas con 8–16) para bajar triángulos. Rover ≈ 6 700 triángulos, estación ≈ 4 000, compañero ≈ 1 500, dron ≈ 800. Vista por defecto medida: ≈ 77 000 primitivas y 249 llamadas de dibujo (calidad alta, con sombras).
- Re-horneados `rover/station/drone/companion.tscn` con `tools/bake_assets.gd` (los `.glb` no se tocan).

### Paisaje: colinas y farallones (23 oct 2026)

- `terrain.gd`: malla exterior de colinas (`_build_outer`, celdas de 4 m hasta ±80) con crestas y ondulaciones (`_outer_height`), laderas con franjas de capa y color por altura. Deja bajo el pasillo hacia el lago (`_corridor_mask`) y el propio lago. `height_at` devuelve la altura de las colinas fuera de la malla detallada (empalma con ella en ±40) y el plano de la cuenca más allá de ±80; las rocas decorativas y los objetos se apoyan con esa altura.
- `_build_cliffs`: 16 grupos de farallones (lajas altas estratificadas, algo inclinadas) con bloques y peñascos caídos alrededor, en MultiMesh por variante; proyectan sombra en calidad alta (`apply_quality()`).
- `world_art.gd`: nuevo tipo de piedra `cliff` en `STONE_PRESETS`.
- Vista inicial medida: ≈ 85 000 primitivas y 262 llamadas de dibujo (calidad alta).

### Paisaje: contacto con el suelo (23 oct 2026)

- `terrain.gd`: `_build_decor` reúne las sombras de contacto de rocas, obstáculos y objetivos (`W.ao_blobs`, una sola llamada de dibujo con un MultiMesh de cuadrados con degradado) y reparte 2–4 guijarros caídos alrededor de las rocas grandes (`_build_halos`, 3 variantes). Los guijarros sueltos bajan de 800 a 360 para mantener el presupuesto de triángulos.
- `tracks.gd`: las huellas son marcas discontinuas (60 % de cada tramo) que se leen como la pisada de las grampas.
- Vista inicial medida: ≈ 87 000 primitivas y 266 llamadas de dibujo (calidad alta).

### Antena por niveles, mapa, título y tipografía (23 oct 2026)

- `art.gd` `antenna(n, level)`: cada nivel suma módulos y no solo tamaño. Nivel 1: plato pequeño, receptor y látigo. Nivel 2: plato mediano con horquilla y alimentador de trípode, plato de relé, armario amplificador con rejillas y luz verde, panel solar propio inclinado y baliza. Nivel 3: plato de espacio profundo sobre pedestal giratorio con aro naranja y alimentador de cuatro patas, dos relés, búnker de comunicaciones con puerta y franja naranja, radomo sobre torre, matriz de fase de 15 celdas, conductos y baliza roja. Los nodos `AntennaLevel1..3` siguen igual (se muestra uno a la vez). `station.tscn` re-horneado.
- Fuentes (`assets/fonts/`, licencia OFL, con sus `OFL-*.txt`): **Inter** para el texto y **Space Grotesk** para títulos y cifras, ambas variables. `ui_style.gd`: `text_font(peso)` y `display_font(peso, separación)` (FontVariation con el eje `wght`, constante `WGHT`); el tema usa Inter 450 y los botones Inter 560. Si faltan los archivos se usa la fuente de Godot.
- `gaia_mark.gd`: emblema de GAIA dibujado por código (planeta con órbita y luna). El título «GAIA» usa Space Grotesk 700 con separación de 5 px y sombra; el emblema se oculta junto al título en el taller.
- `hud.gd` `_fit_top_right()`: las píldoras de Energía y Ciencia miden su texto y se apilan desde el botón de pausa, así que no se desbordan ni se pisan en ningún idioma.
- `minimap.gd`: mapa de 168 px con terreno marrón, cuadrícula cada 5 casillas, rocas en relieve, objetivos revelados con aro, estación como casita, rover como flecha que apunta hacia donde se mueve, esquinas de marco y, al pasar el cursor, casilla resaltada con sus coordenadas. Mismo contrato (`state`, `point`, `tile_at`, `tile_chosen`).
- Pruebas nuevas en `tests/test_ui_rediseno.gd` (234 en total) y vista inicial medida: ≈ 89 000 primitivas y 315 llamadas de dibujo.

## Menú, presentación y partida guardada (rama `a/menu-presentacion`)

Flujo: `intro.tscn` (escena principal) → `menu.tscn` → (tutorial la primera vez) → `loading.tscn` → `scenes/a/game.tscn`. `game.tscn` sigue pudiendo abrirse sola para pruebas.

- **Intro** (`scenes/menu/intro.gd`): logotipo de Canva con destello, subtítulo y crédito; cualquier tecla o clic la salta. En la web empieza con «Pulsa para comenzar» (el navegador exige un gesto para el audio).
- **Menú** (`menu.gd`): Continuar (activo solo con partida guardada; muestra sol y ciencia enviada), Nueva partida (pide confirmación si hay partida guardada), Cómo jugar, Controles, Configuración (idioma, volumen, silencio, gráficos altos/ligeros, pantalla completa, mostrar tutorial), Créditos y Salir (no en la web). Las preferencias se guardan en `user://b_preferences.cfg`, el mismo archivo que usa la misión.
- **Tutorial** (`tutorial.gd`): cinco páginas; se muestra antes de la primera partida y se puede volver a ver desde «Cómo jugar».
- **Carga** (`loading.gd`): imagen fija, consejos y barra de progreso mientras `ResourceLoader.load_threaded_request` carga el juego.
- **Pausa**: nuevo botón «Salir al menú». `hud.gd` emite `menu_requested`, `mission_view.gd` lo reenvía y `MissionRunner` abre el menú.
- **Textos**: `menu_text.gd` (tablas ES/EN del menú) y la clave `MENU_QUIT` en `strings_ui.csv`.
- **Guardado** (`game_session.gd` + `Simulation.guardar/cargar`): `user://gaia_partida.dat` (en la web vive en el almacenamiento del navegador). Se guarda al aterrizar y al comenzar cada sol; solo en la fase de operaciones. «Continuar» restaura la simulación y no los movimientos ni acciones en curso.
- **HUD**: el logotipo de `assets/menu/gaia_logo.png` sustituye al emblema 3D por código si el archivo existe.
- **Música** (`musica.gd`): el reproductor cuelga de la raíz y no se corta al cambiar de escena; `gaia_menu.ogg` suena en intro, menú y carga y `gaia_juego.ogg` en la misión, con fundido cruzado. Sigue el volumen y el silencio del bus principal.
- **Sonidos por acción** (`audio.gd`): el rover rodando, el taladro, el láser del espectrómetro, el radar, la panorámica, el dron (arranque de rotores y vuelo), el compañero y la estación meteorológica tienen sonido propio y suenan en bucle mientras dura la acción (la tabla `ACCIONES` los asocia con el id de la acción). Al abrirse la transmisión suena un barrido de subida y luego el chorro de datos. Los `.wav` importados no vienen en bucle, así que `audio.gd` los repite por código.
- **Animación de transmisión** (`transmission_fx.gd`, accesible como `actors.link`): mientras `transmitting` es verdadero, paquetes de datos viajan en arco del rover a la antena, de su punta sale un haz con paquetes que suben al cielo y ondas circulares se expanden hacia arriba; aparece y se apaga con fundido. Sigue la altura de la antena según su nivel (`actors.antenna_top`).
- Pruebas: `tests/test_guardado.gd` (5), `tests/test_menu.gd` (9) y `tests/test_sonido.gd` (6). Total: 254.

## Historia, recursos y base (bloque A, 24 oct 2026)

Con `content/economia.json` y `content/historia.json` (los carga `MissionRunner`), el snapshot trae además:

- `resources`: `{"rocas", "olivino", "hielo", "xenolito"}` y `resource_capacity` (sube con cada domo).
- `buildings`: `[{"id", "type", "tile", "level", "building", "progress", "active"}]`. La Antena Científica es `type: "antena"` en `base.antenna_tile` y empieza en nivel 0: sin ella no se transmite (`NO_ANTENNA`).
- `build_options`: `[{"id", "name_key", "cost", "power_w", "seconds", "count", "max", "enabled", "reason"}]`.
- `base`: `{"center", "radius", "antenna_tile", "antenna_max", "antenna_next_cost"}`.
- `story`: `{"pending", "objective", "ethics", "rocky_hp", "branch", "log"}`. `pending` es el nodo que espera decisión (la misión se detiene): `{"id", "act", "title", "text", "rocky", "choices": [{"text", "detail", "enabled", "reason"}]}`. Los textos son `{"es", "en"}`.

Órdenes nuevas: `build {"building", "tile"}`, `toggle_building {"id", "on"}`, `decide {"choice"}`; `upgrade` sube la antena un nivel (obra con tiempo y costo en recursos; el nivel 2 pide el hangar).

El informe trae `ending {"id", "title", "text"}`, `ethics`, `rocky_hp` y `story_log`. Con historia, llegar a la meta solo gana después de decidir el clímax; la derrota siempre es el final «silencio».

### Radio, metas y escenas (bloque A, ajuste del 24 oct 2026: «menos película, más juego»)

La historia ya no pausa el juego en cada evento. Cada nodo de `content/historia.json` tiene un `modo`:

- **`radio`** (aterrizaje, alerta sísmica y glaciares): no detiene la misión. Se aplica solo (su única opción) y el snapshot trae `story.radio = {"id", "n", "act", "title", "image", "dialogue"}`. La vista muestra una tarjeta no bloqueante abajo a la izquierda con la escena en miniatura y las voces; pasa sola o con clic, y espera si hay una escena o la pausa. `n` sube con cada radio nueva: la vista solo muestra la que tiene `n` mayor que la última vista (una partida cargada no repite la anterior). Evento `STORY_RADIO:<nodo>`.
- **`decision`** (noche de arañas, nidos y clímax): detiene la misión (`story.pending`). Con `escena: "corta"` (noche de arañas) la vista muestra una sola pantalla con imagen, relato, voces y opciones; con `completa`, imagen y relato, diálogos uno a uno y decisión.
- **`espera_h`**: horas de juego de respiro desde el nodo anterior antes de que este pueda salir (así se juega entre evento y evento).
- **`metas`**: `[{"tipo": "antena|edificio|recurso|enviados_pct|sol|bateria_pct|rocky_hp", "id"?, "min"}]`. El snapshot trae `story.goals = [{"kind", "id", "cur", "goal", "done"}]` (avance del objetivo actual) y el HUD lo muestra como lista bajo el minimapa. Son guía: lo que abre cada evento sigue siendo `disparadores`.

`StoryData` valida `modo`, `escena`, `espera_h`, `metas` y que una radio tenga una sola opción sin final ni requisito de Rocky (`BAD_RADIO`). Estado nuevo en `MissionState`: `historia_radio`, `historia_radio_n`, `historia_t_ultimo`.

Imágenes: las 16 escenas ilustradas (`assets/historia/<id>.jpg`, 1280×720) salen del storyboard de Canva aprobado.

## Combate (bloque C, 24 oct 2026)

Ver `COMBATE.md`. Cambios de contrato para A:

- `Simulation` recibe un séptimo argumento opcional: `Simulation.new(balance, reglas, mapa, catalogo, economia, historia, combate)`, con `combate = CombatData.new(...)` cargado de `content/combate.json`. `MissionRunner` ya lo carga (`RUTA_COMBATE`). Sin él no hay combate y el snapshot no trae `combat`.
- `Simulation.hay_combate_activo()`: el runner publica el snapshot cada cuadro mientras sea `true` (monstruos, rayos o meteoritos en movimiento).
- Snapshot nuevo:
  - `combat`: `{"enemies": [{"id","type","pos","hp","hp_max","size","attacking"}], "shots": [{"from","to","ttl","kind","n"}], "impacts": [{"tile","t","total","radius"}], "threat", "threat_extra", "wave": {…próxima oleada…}, "rover_hp"}`.
  - `nests`: `[{"id","casilla","zona"}]`.
  - `rover_hp` (0–100) en el nivel superior.
  - `buildings[*].hp` y `hp_max`.
- Avisos nuevos: `ENEMIES_ACTIVE`, `METEORS_INCOMING`, `ROVER_DAMAGED`, `WAVE_SOON` (textos `WARN_*` en `i18n/catalog.gd`).
- Eventos nuevos: `WAVE_STARTED:<id>`, `WAVE_CLEARED:<id>`, `ENEMY_KILLED:<tipo>`, `ROVER_HIT`, `METEOR_SHOWER:<id>`, `METEOR_IMPACT`, `BUILDING_DESTROYED`, `ANTENNA_DAMAGED`.
- Informe: nueva causa de derrota `CAUSE_ROVER_DESTROYED`.
- Nuevos edificios en `build_options`: `torreta` y `torreta_2` (la segunda pide hangar). Cada opción trae `range` (alcance en casillas; 0 si no dispara).

## Tutorial y nave de fuga (bloque D, 24 oct 2026)

Ver `TUTORIAL_Y_NAVE.md`. Cambios de contrato para A:

- `Simulation.new(..., combate, tutorial)`: octavo argumento opcional, `TutorialData` cargado de `content/tutorial.json` (`MissionRunner` ya lo carga, `RUTA_TUTORIAL`).
- Snapshot nuevo: `tutorial`: `{"active": false}` o `{"active": true, "step", "total", "id", "text": {"es","en"}, "highlight": ""|"mapa"|"acciones"|"construir"|"enlace"}`.
- Orden nueva: `tutorial_skip` (cierra el tutorial). Eventos: `TUTORIAL_STEP:<id>` y `TUTORIAL_DONE`.
- `build_options` ya no trae `nave_fuga` hasta decidir el clímax. Motivos nuevos: `NEEDS_FINAL`, `NEEDS_ANTENNA_3`.
- Con historia y `nave` en `historia.json`, la victoria exige además tener la nave de fuga completa (todos sus módulos); el informe añade la causa `CAUSE_SHIP`.
- Edificios por módulos (`modulos` en `economia.json`): `buildings[*]` trae `modules` (total, 0 si no es por módulos) y `next_module` (`{name_key, cost, seconds, enabled, reason}`, vacío si ya está completo); el nivel del edificio es el número de módulos terminados. Orden nueva: `build_module {id}`. Evento nuevo: `MODULE_DONE:<tipo>:<n>`. `meta.modulos` da el total para la meta «módulos». `construir` crea el módulo 1 con el costo y tiempo del primero.
