extends Node
## Voces de radio del juego (plan de mejoras 9.3): Houston y el rover hablan cuando pasa algo que ya existe (ruta
## recibida, llegada, despegue, aterrizaje en la Luna, noche, enlace abierto, memoria llena, batería baja, tormenta).
## Guion en content/voces.json; grabaciones en assets/voces/ (tools/voces/generar_voces.py). Vive en la vista: solo
## escucha lo que ya llega (señales y fotos del estado), no toca la simulación.
## Reglas: una pausa mínima entre voces (pausa_min_s), nunca encima de las voces de la historia de Tony, sin repetir la
## misma variante dos veces seguidas y apagable con «Voces de radio» en Configuración.

const DATOS := "res://content/voces.json"
const CARPETA := "res://assets/voces/%s/%s_%d_%s.wav"  ## carpeta, evento, variante, sha12
const Texto := preload("res://scenes/menu/menu_text.gd")

var ocupada: Callable  ## true si suena una voz de la historia (o hay una escena abierta): entonces no se habla
var pausa_min_s := 20.0
var _eventos: Dictionary = {}
var _jugador: AudioStreamPlayer
var _t := 1000.0  ## segundos desde la última voz
var _ultima_variante: Dictionary = {}  ## evento -> variante dicha la última vez
var _cola: Array[AudioStream] = []  ## voces encadenadas (aterrizaje: rover y luego Houston)
var _foto: Dictionary = {}


func _ready() -> void:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	if datos is Dictionary:
		_eventos = datos.get("eventos", {})
		pausa_min_s = float(datos.get("pausa_min_s", 20.0))
	_jugador = AudioStreamPlayer.new()
	_jugador.volume_db = -4.0
	add_child(_jugador)
	_jugador.finished.connect(_siguiente)


static func activadas() -> bool:
	return bool(Texto.preferencias().get("radio_voices", true))


static func sha12(quien: String, texto: String) -> String:
	return (quien + "\n" + texto).sha256_text().left(12)


## Ruta del archivo de una variante (1, 2, 3…) de un evento, en un destino e idioma. "" si el evento no va en ese destino.
static func ruta(eventos: Dictionary, evento: String, n: int, destino: String, idioma: String) -> String:
	var ev: Dictionary = eventos.get(evento, {})
	if ev.is_empty() or not (ev.get("destinos", ["marte", "luna"]) as Array).has(destino):
		return ""
	var variantes: Array = ev.get(destino, ev["variantes"]) if ev.has("luna") else ev["variantes"]
	if n < 1 or n > variantes.size():
		return ""
	var carpeta := destino if ev.has("luna") else ("comun" if (ev.get("destinos", ["marte", "luna"]) as Array).size() > 1 else destino)
	return CARPETA % [carpeta, evento, n, sha12(str(ev["quien"]), str(variantes[n - 1].get(idioma, "")))]


## Habla del evento si se puede (pausa mínima, nada de la historia sonando, voces activadas). true si habló.
## «encadenar» añade otro evento justo detrás (sin esperar la pausa). «forzar» no espera la pausa mínima (secuencias
## cortas como el despegue), pero tampoco pisa la historia.
func decir(evento: String, encadenar: String = "", forzar := false) -> bool:
	if not activadas() or (_t < pausa_min_s and not forzar) or (_jugador.playing and not forzar) \
			or (ocupada.is_valid() and ocupada.call()):
		return false
	var stream := _elegir(evento)
	if stream == null:
		return false
	_cola.clear()
	if not encadenar.is_empty():
		var detras := _elegir(encadenar)
		if detras != null:
			_cola.append(detras)
	_jugador.stream = stream
	_jugador.play()
	_t = 0.0
	return true


func _elegir(evento: String) -> AudioStream:
	var ev: Dictionary = _eventos.get(evento, {})
	if ev.is_empty():
		return null
	var total: int = (ev.get(Destino.id, ev["variantes"]) if ev.has("luna") else ev["variantes"]).size()
	var opciones: Array[int] = []
	for n in range(1, total + 1):
		if n != int(_ultima_variante.get(evento, 0)) or total == 1:
			opciones.append(n)
	var n: int = opciones[randi() % opciones.size()]
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var archivo := ruta(_eventos, evento, n, Destino.id, idioma)
	if archivo.is_empty() or not ResourceLoader.exists(archivo):
		return null
	_ultima_variante[evento] = n
	return load(archivo) as AudioStream


func _siguiente() -> void:
	if not _cola.is_empty():
		_jugador.stream = _cola.pop_front()
		_jugador.play()
		_t = 0.0


func _process(delta: float) -> void:
	if not _jugador.playing:
		_t += delta
	if _jugador.playing and ocupada.is_valid() and ocupada.call():
		_jugador.stop()  # empezó una voz de la historia: la suya manda
		_cola.clear()


## Cambios de estado que merecen una voz: noche, enlace abierto, tormenta, llegada, memoria casi llena, batería baja.
func update_snapshot(s: Dictionary) -> void:
	var antes := _foto
	_foto = s
	if antes.is_empty() or str(s.get("phase", "")) != "operations" or bool(s.get("paused", false)):
		return
	if bool(s.get("storm", false)) and not bool(antes.get("storm", false)):
		decir("tormenta")
	elif bool(s.get("is_night", false)) and not bool(antes.get("is_night", false)):
		decir("noche")
	elif bool(s.get("link_open", false)) and not bool(antes.get("link_open", false)):
		decir("ventana")
	elif _aviso_nuevo(antes, s, "MEMORY_ALMOST_FULL"):
		decir("memoria")
	elif _aviso_nuevo(antes, s, "LOW_BATTERY"):
		decir("bateria")
	elif bool(antes.get("moving", false)) and not bool(s.get("moving", false)):
		decir("llegada")


static func _aviso_nuevo(antes: Dictionary, ahora: Dictionary, id: String) -> bool:
	return _hay(ahora, id) and not _hay(antes, id)


static func _hay(s: Dictionary, id: String) -> bool:
	for aviso in s.get("warnings", []):
		if str(aviso.get("id", "")) == id:
			return true
	return false
