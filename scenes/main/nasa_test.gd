extends Node3D
## Prueba temporal de la fase 0: llamada a images-api.nasa.gov desde el build web.
## Se descarta cuando exista el HUD real (los textos de depuración no usan tr()).

const URL := "https://images-api.nasa.gov/search?q=mars%20perseverance&media_type=image&page_size=1"

var _label: Label
var _t0 := 0


func _ready() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.text = "NASA: consultando..."
	capa.add_child(_label)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	_t0 = Time.get_ticks_msec()
	var err := http.request(URL)
	if err != OK:
		_label.text = "NASA: no se pudo iniciar la petición (error %d)" % err


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var ms := Time.get_ticks_msec() - _t0
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_label.text = "NASA: fallo (result %d, HTTP %d, %d ms)" % [result, code, ms]
		return

	var datos: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (datos is Dictionary) or not datos.has("collection"):
		_label.text = "NASA: respuesta inesperada (%d ms)" % ms
		return

	var items: Array = datos["collection"].get("items", [])
	if items.is_empty():
		_label.text = "NASA: sin resultados (%d ms)" % ms
		return

	var titulo: String = items[0]["data"][0].get("title", "(sin título)")
	_label.text = "NASA OK (%d ms)\n%s" % [ms, titulo]
