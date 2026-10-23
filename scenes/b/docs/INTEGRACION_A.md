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

Coordenadas: X horizontal de cuadrícula, Y de Vector2i corresponde a Z del mundo; 1 casilla = 2 metros; límites visuales -11..11. El relieve de +/-18 cm es cosmético. A usa la misma cuadrícula y casillas bloqueadas. Si cambia el mapa/límite del producto, actualiza también minimapa y conversión visual.

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
 "bounds": {"min": Vector2i(-11, -11), "max": Vector2i(11, 11)},   # últimas casillas válidas
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
