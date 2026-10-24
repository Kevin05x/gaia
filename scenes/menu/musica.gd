extends RefCounted
## Música de fondo de GAIA. El reproductor cuelga de la raíz del árbol, así que no se corta al cambiar de escena:
## la pista del menú suena en la intro, el menú y la carga, y al entrar en la misión pasa por fundido al ambiente de juego.
## Las pistas son originales, sintetizadas por código (`tools/sintetizar_musica.py`).
const PISTAS := {
	"menu": "res://assets/audio/gaia_menu.ogg",
	"juego": "res://assets/audio/gaia_juego.ogg",
}
const NIVEL_DB := {"menu": -7.0, "juego": -15.0}

static var actual := ""
static var _jugador: AudioStreamPlayer


## Hace sonar la pista pedida (en bucle) con un fundido cruzado. No hace nada si ya está sonando o si falta el archivo.
static func reproducir(arbol: SceneTree, pista: String, fundido: float = 2.5) -> void:
	if arbol == null or pista == actual and is_instance_valid(_jugador):
		return
	var ruta: String = PISTAS.get(pista, "")
	if ruta == "" or not ResourceLoader.exists(ruta):
		return
	var flujo: AudioStream = load(ruta)
	if "loop" in flujo:
		flujo.set("loop", true)
	if is_instance_valid(_jugador):
		var saliente := _jugador
		var tw := saliente.create_tween()
		tw.tween_property(saliente, "volume_db", -60.0, fundido)
		tw.tween_callback(saliente.queue_free)
	var nuevo := AudioStreamPlayer.new()
	nuevo.name = "MusicaGaia"
	nuevo.stream = flujo
	nuevo.volume_db = -60.0
	_jugador = nuevo
	actual = pista
	# Diferido: se puede pedir desde _ready(), cuando la raíz aún está montando a sus hijos.
	_montar.call_deferred(arbol, nuevo, float(NIVEL_DB[pista]), fundido)


static func _montar(arbol: SceneTree, nuevo: AudioStreamPlayer, nivel: float, fundido: float) -> void:
	if not is_instance_valid(nuevo):
		return
	if nuevo != _jugador or arbol == null:
		nuevo.queue_free()
		return
	arbol.root.add_child(nuevo)
	nuevo.play()
	nuevo.create_tween().tween_property(nuevo, "volume_db", nivel, fundido)


static func detener(fundido: float = 1.5) -> void:
	if is_instance_valid(_jugador):
		var saliente := _jugador
		var tw := saliente.create_tween()
		tw.tween_property(saliente, "volume_db", -60.0, fundido)
		tw.tween_callback(saliente.queue_free)
	_jugador = null
	actual = ""
