extends Control
## «Tu misión frente a la real»: se abre desde el informe final. Compara el diseño del jugador con Mars 2020
## (Perseverance) usando datos oficiales con fuente, explica los cuatro segmentos de una misión (recurso oficial
## del reto, NASA «Design and Develop Science Missions») y consulta en vivo la NASA Image and Video Library.
## Sin conexión, muestra las imágenes oficiales que vienen con el juego.

const UI := preload("res://scenes/b/ui_style.gd")
const NasaData := preload("res://scenes/b/nasa_data.gd")
const API := "https://images-api.nasa.gov/search?media_type=image&page_size=4&q="

signal closed

var report: Dictionary = {}
var taller: Dictionary = {}
var _archivo: VBoxContainer
var _http: HTTPRequest
var _foto: TextureRect
var _credito: Label


func build() -> void:
	for h in get_children():
		h.queue_free()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var fondo := Panel.new()
	fondo.add_theme_stylebox_override("panel", UI.box(1.0, UI.RADIUS_PANEL, 0.3, 1, 0, 0, UI.AMBER))
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var titulo := UI.label(self, tr("CMP_TITLE"), UI.FONT_TITLE, UI.CREAM)
	UI.display(titulo, 700, 0)
	titulo.position = Vector2(24, 18)
	var sub := UI.label(self, tr("CMP_SUBTITLE"), 12, Color(UI.CREAM, 0.65))
	sub.position = Vector2(24, 50)
	# Columna izquierda: foto real con su crédito y dos datos.
	_foto = TextureRect.new()
	_foto.position = Vector2(24, 78)
	_foto.size = Vector2(400, 250)
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_foto)
	_credito = UI.label(self, "", 10, Color(UI.CREAM, 0.6))
	_credito.position = Vector2(24, 332)
	_credito.size = Vector2(400, 34)
	_credito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mostrar_foto("selfie")
	_visor_3d()
	var segmentos := UI.label(self, tr("CMP_SEGMENTS"), UI.FONT_SECONDARY, UI.AMBER)
	segmentos.position = Vector2(24, 374)
	var lista := VBoxContainer.new()
	lista.position = Vector2(24, 398)
	lista.size = Vector2(400, 150)
	lista.add_theme_constant_override("separation", 4)
	add_child(lista)
	for linea in _segmentos():
		var l := UI.label(lista, linea, 12, Color(UI.CREAM, 0.88))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 400
	var fuente_seg := UI.label(self, tr("CMP_SEGMENTS_SRC"), 10, Color(UI.CREAM, 0.5))
	fuente_seg.position = Vector2(24, 548)
	# Columna derecha: tabla comparativa.
	var tabla := GridContainer.new()
	tabla.columns = 3
	tabla.position = Vector2(448, 80)
	tabla.size = Vector2(488, 270)
	tabla.add_theme_constant_override("h_separation", 14)
	tabla.add_theme_constant_override("v_separation", 7)
	add_child(tabla)
	for celda in ["", tr("CMP_YOU"), tr("CMP_REAL")]:
		var c := UI.label(tabla, celda, 13, UI.AMBER)
		UI.display(c, 700, 0)
	for fila in _filas():
		var a := UI.label(tabla, fila[0], 12, Color(UI.CREAM, 0.7))
		a.custom_minimum_size.x = 130
		var b := UI.label(tabla, fila[1], 13, UI.CREAM)
		b.custom_minimum_size.x = 150
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var c := UI.label(tabla, fila[2], 13, UI.TEAL)
		c.custom_minimum_size.x = 170
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var nota := UI.label(self, tr("CMP_SCALE_NOTE"), 10, Color(UI.CREAM, 0.55))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 488
	nota.position = Vector2(448, 358)
	nota.size = Vector2(488, 20)
	# Archivo NASA en vivo.
	var cab := UI.label(self, tr("CMP_ARCHIVE"), UI.FONT_SECONDARY, UI.AMBER)
	cab.position = Vector2(448, 424)
	_archivo = VBoxContainer.new()
	_archivo.position = Vector2(448, 448)
	_archivo.size = Vector2(488, 110)
	_archivo.add_theme_constant_override("separation", 2)
	add_child(_archivo)
	UI.label(_archivo, tr("CMP_ARCHIVE_LOADING"), 12, Color(UI.CREAM, 0.6))
	var volver := Button.new()
	volver.theme_type_variation = "PrimaryButton"
	volver.text = tr("CMP_BACK")
	volver.size = Vector2(180, 40)
	volver.position = Vector2(960 - 24 - 180, 592 - 20 - 40)
	add_child(volver)
	volver.pressed.connect(func() -> void: closed.emit())
	volver.grab_focus.call_deferred()
	_consultar_archivo()


func _mostrar_foto(id: String) -> void:
	_foto.texture = NasaData.imagen(id)
	_credito.text = NasaData.credito(id)
	if is_instance_valid(_visor):
		_visor.visible = false
		_foto.visible = true


var _visor: Control
var _credito_modelo := ""


## Modelo 3D oficial de la NASA en lugar de la foto (solo en el escritorio: en la web no se incluyen los modelos
## para que la descarga sea liviana). Botones para cambiar entre modelo y foto.
func _visor_3d() -> void:
	var info: Dictionary = NasaData.datos().get("modelos_3d", {})
	var archivos: Array = info.get("archivos", [])
	if archivos.is_empty() or not ResourceLoader.exists(str(archivos[0])):
		return
	_visor = preload("res://scenes/b/visor_3d.gd").new()
	_visor.archivos = archivos
	_visor.tamanos = info.get("tamanos", [])
	_visor.position = _foto.position
	_visor.size = _foto.size
	add_child(_visor)
	_credito_modelo = str(info.get("credito", ""))
	_foto.visible = false
	_credito.text = _credito_modelo + " · " + tr("CMP_DRAG")
	var fila := HBoxContainer.new()
	fila.position = Vector2(24 + 400 - 190, 82)
	fila.add_theme_constant_override("separation", 4)
	add_child(fila)
	for par in [["CMP_VIEW_MODEL", true], ["CMP_VIEW_PHOTO", false]]:
		var b := Button.new()
		b.text = tr(par[0])
		b.custom_minimum_size = Vector2(90, 26)
		b.add_theme_font_size_override("font_size", 13)
		var modelo: bool = par[1]
		b.pressed.connect(func() -> void:
			_visor.visible = modelo
			_foto.visible = not modelo
			_credito.text = (_credito_modelo + " · " + tr("CMP_DRAG")) if modelo else NasaData.credito("selfie"))
		fila.add_child(b)


func _filas() -> Array:
	var real: Dictionary = NasaData.comparacion()
	var totales: Dictionary = taller.get("totals", {})
	var extras: Array = _cientificos()
	return [
		[tr("CMP_ROCKET"), "%s · %s" % [_nombre("cohetes"), _nombre("trayectoria")], str(real.get("cohete", ""))],
		[tr("CMP_CRUISE"), tr("WS_DAYS") % int(totales.get("cruise_days", 0)), tr("WS_DAYS") % int(real.get("crucero_dias", 0))],
		[tr("CMP_MASS"), "%d kg" % int(totales.get("mass_kg", 0)), _o(real, "masa_kg", "%d kg")],
		[tr("CMP_POWER"), "%s · %d W" % [_nombre("energia"), int(totales.get("power_w", 0))], _o(real, "potencia_w", "MMRTG · %d W")],
		[tr("CMP_INSTRUMENTS"), str(extras.size()), _o(real, "instrumentos", "%d")],
		[tr("CMP_COMMS"), _nombre("comunicaciones"), tr("CMP_COMMS_REAL")],
		[tr("CMP_COST"), "%d M USD" % int(totales.get("cost_musd", 0)), _o(real, "costo_musd", "≈ %d M USD")],
		[tr("CMP_DURATION"), tr("CMP_SOLS") % int(report.get("sol", 1)), tr("WS_DAYS") % int(real.get("mision_dias", 0))],
	]


## Instrumentos científicos elegidos (sin la batería ni el compañero), comparables con los 7 de Perseverance.
func _cientificos() -> Array:
	var lista: Array = []
	for id in taller.get("selection", {}).get("extras", []):
		if not ["bateria", "companero"].has(str(id)):
			lista.append(id)
	return lista


## Valor real con formato, o «—» si no aplica a ese destino (por ejemplo, la masa de un rover en Apolo 11).
func _o(real: Dictionary, clave: String, formato: String) -> String:
	var v := int(real.get(clave, 0))
	return "—" if v <= 0 else formato % v


func _segmentos() -> Array:
	var extras: Array = _cientificos()
	return [
		tr("CMP_SEG_LAUNCH") % [_nombre("cohetes"), int(taller.get("totals", {}).get("cruise_days", 0))],
		tr("CMP_SEG_SPACE") % [extras.size(), _nombre("energia")],
		tr("CMP_SEG_GROUND") % _nombre("comunicaciones"),
		tr("CMP_SEG_USER") % [int(report.get("sent", 0)), int(report.get("goal", 100))],
	]


func _nombre(categoria: String) -> String:
	var elegidas: Array = taller.get("selection", {}).get(categoria, [])
	if elegidas.is_empty():
		return "—"
	for cat in taller.get("categories", []):
		for parte in cat.get("parts", []):
			if str(parte.get("id", "")) == str(elegidas[0]):
				return tr(str(parte.get("name_key", "")))
	return str(elegidas[0])


## Consulta la NASA Image and Video Library (la API permite CORS, así que también funciona en la web).
func _consultar_archivo() -> void:
	var consultas: Array = NasaData.datos().get("archivo_en_vivo", {}).get("consultas", ["jezero crater"])
	var consulta := str(consultas[randi() % consultas.size()])
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_al_recibir)
	if _http.request(API + consulta.uri_encode()) != OK:
		_sin_conexion()


func _al_recibir(resultado: int, codigo: int, _cabeceras: PackedStringArray, cuerpo: PackedByteArray) -> void:
	for h in _archivo.get_children():
		h.queue_free()
	if resultado != HTTPRequest.RESULT_SUCCESS or codigo != 200:
		_sin_conexion()
		return
	var datos: Variant = JSON.parse_string(cuerpo.get_string_from_utf8())
	if not (datos is Dictionary):
		_sin_conexion()
		return
	var elementos: Array = datos.get("collection", {}).get("items", [])
	if elementos.is_empty():
		_sin_conexion()
		return
	UI.label(_archivo, tr("CMP_ARCHIVE_LIVE"), 10, Color(UI.TEAL, 0.9))
	for item in elementos.slice(0, 4):
		var meta: Dictionary = (item.get("data", [{}]) as Array)[0]
		var id := str(meta.get("nasa_id", ""))
		var enlace := LinkButton.new()
		enlace.text = "%s · %s" % [str(meta.get("title", id)).left(60), str(meta.get("date_created", "")).left(10)]
		enlace.add_theme_font_size_override("font_size", 13)
		enlace.add_theme_color_override("font_color", UI.CREAM)
		_archivo.add_child(enlace)
		enlace.pressed.connect(func() -> void: OS.shell_open("https://images.nasa.gov/details/" + id.uri_encode()))


## Sin internet: las imágenes oficiales que trae el juego, que también se pueden ver en grande.
func _sin_conexion() -> void:
	for h in _archivo.get_children():
		h.queue_free()
	UI.label(_archivo, tr("CMP_ARCHIVE_OFFLINE"), 10, Color(UI.WARN, 0.9))
	var vistos: Array = []
	for id in ["selfie", "muestras", "jezero", "lago", "lanzamiento"]:
		var archivo := str(NasaData.datos().get("imagenes", {}).get(id, {}).get("archivo", id))
		if archivo in vistos or vistos.size() >= 4:
			continue  # la Luna reutiliza fotos en varias claves: cada foto una sola vez
		vistos.append(archivo)
		var b := LinkButton.new()
		b.text = str(NasaData.datos().get("imagenes", {}).get(id, {}).get("titulo", id))
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", UI.CREAM)
		_archivo.add_child(b)
		b.pressed.connect(_mostrar_foto.bind(id))
