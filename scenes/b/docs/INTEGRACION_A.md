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
 "phase": "operations", # landing / operations / report
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
