extends Node
## «Port» del anfitrión de una partida en red: hace el papel que en una partida normal hace la vista (mismos métodos que
## scenes/b/port.gd), pero en vez de dibujar reparte lo que pasa a todos los jugadores a través de Red.
## MissionRunner no sabe la diferencia: le da órdenes por command_requested y le entrega snapshots, rutas y avisos.
signal command_requested(command: String, payload: Dictionary)

var snapshot: Dictionary = {}  ## el último, para dárselo a quien entre con la partida ya empezada
var connected_backend := false
var emisor := 0  ## id del jugador cuya orden se está ejecutando (los rechazos solo le llegan a él)
var orden_actual := ""


func apply_snapshot(value: Dictionary) -> void:
	snapshot = value
	Red.repartir_snapshot(value)


func present_report(value: Dictionary) -> void:
	Red.repartir("report", value)


## Con un rover por jugador, la animación de lo que hace cada rover es solo de su dueño (los demás ven su posición en el snapshot).
func _a_su_dueno(tipo: String, datos: Variant) -> void:
	if emisor != 0:
		Red.enviar_a(emisor, tipo, datos)
	else:
		Red.repartir(tipo, datos)


func present_action(value: Dictionary) -> void:
	_a_su_dueno("action", value)


func present_path(tiles: Array, seconds_per_tile: float = 0.65) -> void:
	_a_su_dueno("path", {"tiles": tiles, "spt": seconds_per_tile})


func cancel_presentation() -> void:
	_a_su_dueno("cancel", null)


func reject(reason_key: String) -> void:
	# Cuando varios jugadores terminan el aterrizaje a la vez, el primero gana y a los demás no se les avisa de nada.
	if orden_actual == "landing_finished" or emisor == 0:
		return
	Red.enviar_a(emisor, "reject", reason_key)


## Avisos, hitos y sonidos que MissionRunner pide a la pantalla (ver MissionRunner._ui).
func ui(metodo: String, args: Array = []) -> void:
	Red.repartir("ui", {"m": metodo, "a": args})
