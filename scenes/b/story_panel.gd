extends CanvasLayer
## Historia en pantalla, como escenas: imagen ilustrada arriba y el relato debajo, luego los diálogos de
## Houston, Rocky y Perseverance uno a uno, y al final la decisión con sus opciones. También muestra las
## pantallas de introducción al empezar una partida nueva. La misión queda detenida mientras la escena está
## abierta (lo decide la simulación); aquí solo se presenta y se emite «decide».
## Los textos llegan en {"es", "en"} y se eligen según el idioma activo. Las imágenes viven en assets/historia/.
const UI := preload("res://scenes/b/ui_style.gd")
const CARPETA_IMAGENES := "res://assets/historia/"
const ANCHO := 980.0
const RADIO_ANCHO := 560.0
const RADIO_SEGUNDOS_MIN := 4.5
const RADIO_SEGUNDOS_POR_LETRA := 0.055
const ESPERA_IMAGEN := 5.0  ## segundos que se ve la imagen sola antes de que aparezca el texto

signal command(command: String, payload: Dictionary)
signal intro_finished
signal escena_abierta  ## se abrió una escena a pantalla completa nueva (para el sonido)

var root: Control
var snapshot: Dictionary = {}
var shown_node := ""  ## nodo que se está mostrando ("" si ninguno)
var step := 0  ## 0 = relato, 1..n = diálogos, n+1 = decisión
var intro_pages: Array = []
var intro_index := -1  ## -1: sin introducción en pantalla
var _node: Dictionary = {}
var _capa: MarginContainer  ## capa de texto sobre la imagen
var _clave_base := ""  ## escena e imagen que ya están dibujadas
var _hay_imagen := false
var _firma_opciones := ""
var _al_terminar := Callable()  ## qué hacer al cerrar la escena final
var _texto_visible := true
var _espera_t := 0.0
var _t_desde_build := 1.0
## Tarjeta de radio: no detiene la misión ni bloquea el juego; las líneas pasan solas o con un clic.
var radio_root: Control
var radio_visto := -1  ## último «n» de radio ya mostrado (-1: aún no hemos visto ningún snapshot)
var radio_line := -1  ## línea que se ve en la tarjeta (-1: tarjeta cerrada)
var _radio: Dictionary = {}
var _radio_cola: Array = []  ## radios que llegaron mientras otra seguía abierta
var _radio_t := 0.0


static func text_of(valor: Variant) -> String:
	if valor is String:
		return valor
	if not (valor is Dictionary):
		return ""
	var idioma := TranslationServer.get_locale().substr(0, 2)
	return str(valor.get(idioma, valor.get("es", "")))


static func image_of(id: String) -> Texture2D:
	if id.is_empty():
		return null
	for extension in [".jpg", ".png"]:
		var ruta: String = CARPETA_IMAGENES + id + extension
		if ResourceLoader.exists(ruta):
			return load(ruta) as Texture2D
	return null


func _ready() -> void:
	layer = 8


func is_open() -> bool:
	return is_instance_valid(root) and root.visible


func radio_open() -> bool:
	return is_instance_valid(radio_root) and radio_root.visible and radio_line >= 0


## Muestra las pantallas de introducción; al terminar (o saltarlas) emite intro_finished.
func show_intro(paginas: Array) -> void:
	intro_pages = paginas
	if paginas.is_empty():
		intro_finished.emit()
		return
	intro_index = 0
	_build_intro()


## Final de la historia: una escena a pantalla completa (imagen, título y relato) antes del informe.
## «al_terminar» se llama cuando el jugador pulsa Continuar.
func show_ending(final: Dictionary, al_terminar: Callable) -> void:
	var pagina := {"es": text_of(final.get("text", {})), "title": text_of(final.get("title", {})),
		"image": str(final.get("image", "")), "final": true}
	_al_terminar = al_terminar
	intro_pages = [pagina]
	intro_index = 0
	_build_intro()


func update_snapshot(s: Dictionary) -> void:
	snapshot = s
	_update_radio(s)
	if intro_index >= 0:
		return
	var pendiente: Dictionary = s.get("story", {}).get("pending", {})
	if s.get("phase", "") != "operations" or pendiente.is_empty():
		if not shown_node.is_empty():
			_close()
		return
	var id := str(pendiente.get("id", ""))
	if id != shown_node:
		shown_node = id
		_node = pendiente
		step = 0
		_build_scene()
	elif step >= _dialogue_count() + 1:
		_node = pendiente
		var firma := JSON.stringify(pendiente.get("choices", []))
		if firma != _firma_opciones:
			_build_scene()  # la disponibilidad de las opciones cambió


## Vuelve a dibujar lo abierto (cambio de idioma).
func rebuild() -> void:
	if radio_open():
		_build_radio()
	if intro_index >= 0:
		_build_intro()
	elif not shown_node.is_empty():
		_build_scene()


func _dialogue_count() -> int:
	return Array(_node.get("dialogue", [])).size()


func _close() -> void:
	shown_node = ""
	_node = {}
	step = 0
	_clear_root()


func _clear_root() -> void:
	_clave_base = ""
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root = null


## Las escenas ocupan toda la pantalla (la interfaz del juego queda tapada): la imagen se ve sola unos segundos
## y luego aparece el texto abajo. Un clic o cualquier tecla adelanta lo que toque; la decisión pide elegir.
## La imagen y el fondo se conservan mientras sigue la misma escena; solo se rehace la capa de texto.
func _base(_alto_max: float, _aparecer: bool, espera: bool = false) -> VBoxContainer:
	var escena_id := "intro" if intro_index >= 0 else shown_node
	var imagen_id := ""
	if intro_index >= 0:
		var pagina: Variant = intro_pages[intro_index]
		imagen_id = str(pagina.get("image", "")) if pagina is Dictionary else ""
	else:
		imagen_id = str(_node.get("image", ""))
	var clave := "%s|%s" % [escena_id, imagen_id]
	var nueva := not is_instance_valid(root) or clave != _clave_base
	if nueva:
		_crear_fondo(imagen_id)
		_clave_base = clave
	else:
		for hijo in _capa.get_children():
			_capa.remove_child(hijo)
			hijo.queue_free()
	_t_desde_build = 0.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	_capa.add_child(col)
	_texto_visible = true
	_capa.modulate.a = 1.0
	if nueva and espera and _hay_imagen:
		_texto_visible = false
		_espera_t = 0.0
		_capa.modulate.a = 0.0
	return col


func _crear_fondo(imagen_id: String) -> void:
	_clear_root()
	root = Control.new()
	root.name = "StoryRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.clip_contents = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.015, 0.015, 1.0)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	fondo.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pulsar())
	root.add_child(fondo)
	var textura := image_of(imagen_id)
	_hay_imagen = textura != null
	if textura != null:
		var imagen := TextureRect.new()
		imagen.texture = textura
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		imagen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(imagen)
		imagen.resized.connect(func() -> void: imagen.pivot_offset = imagen.size / 2.0)
		imagen.modulate.a = 0.0
		var anim := create_tween().set_parallel(true)
		anim.tween_property(imagen, "modulate:a", 1.0, 0.6)
		imagen.scale = Vector2.ONE
		anim.tween_property(imagen, "scale", Vector2(1.07, 1.07), 16.0).set_trans(Tween.TRANS_SINE)
	# Sombra de abajo hacia arriba para que el texto se lea sobre cualquier imagen.
	var degradado := Gradient.new()
	degradado.set_color(0, Color(0.02, 0.015, 0.015, 0.0))
	degradado.set_color(1, Color(0.02, 0.015, 0.015, 0.92))
	degradado.add_point(0.35, Color(0.02, 0.015, 0.015, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = degradado
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var sombra := TextureRect.new()
	sombra.texture = tex
	sombra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sombra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sombra)
	_capa = MarginContainer.new()
	_capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capa.add_theme_constant_override("margin_bottom", 44)
	_capa.add_theme_constant_override("margin_top", 30)
	root.add_child(_capa)
	escena_abierta.emit()
	root.resized.connect(_ajustar_margenes)
	_ajustar_margenes.call_deferred()


## El texto no se estira en pantallas anchas: columna centrada de hasta ANCHO.
func _ajustar_margenes() -> void:
	if not is_instance_valid(root) or not is_instance_valid(_capa):
		return
	var lado := maxf(40.0, (root.size.x - ANCHO) / 2.0)
	_capa.add_theme_constant_override("margin_left", int(lado))
	_capa.add_theme_constant_override("margin_right", int(lado))


func _mostrar_texto() -> void:
	if _texto_visible:
		return
	_texto_visible = true
	if is_instance_valid(_capa):
		create_tween().tween_property(_capa, "modulate:a", 1.0, 0.5)


## Un clic o una tecla: si el texto aún no salió, lo muestra; si ya está, pasa a lo siguiente.
func pulsar() -> void:
	if _t_desde_build < 0.25:
		return
	if not _texto_visible:
		_mostrar_texto()
		_t_desde_build = 0.0
		return
	if intro_index >= 0:
		_siguiente_intro()
	elif not shown_node.is_empty():
		advance()


func _input(e: InputEvent) -> void:
	if not is_open():
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]:
			return
		var en_decision := intro_index < 0 and step >= _dialogue_count() + 1
		if en_decision and (e.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]):
			return  # el botón enfocado se encarga
		get_viewport().set_input_as_handled()
		if not en_decision or not _texto_visible:
			pulsar()


func _parrafo(padre: Control, texto: String, tam: int, color: Color) -> Label:
	var l := UI.label(padre, texto, tam, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = ANCHO
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


func _cabecera(cuerpo: Control) -> void:
	var acto := UI.label(cuerpo, text_of(_node.get("act", {})).to_upper(), 13, UI.AMBER)
	UI.display(acto, 700, 3)
	var titulo := UI.label(cuerpo, text_of(_node.get("title", {})), 32, UI.CREAM)
	UI.display(titulo, 700, 0)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.custom_minimum_size.x = ANCHO


func _build_scene() -> void:
	var n := _dialogue_count()
	if str(_node.get("scene", "completa")) == "corta":
		_build_quick()
		return
	var en_decision := step >= n + 1
	var cuerpo := _base(0.0, false, step == 0)
	_cabecera(cuerpo)
	if step == 0:
		_parrafo(cuerpo, text_of(_node.get("text", {})), 21, Color(UI.CREAM, 0.95))
		var rocky := text_of(_node.get("rocky", {}))
		if not rocky.is_empty():
			_parrafo(cuerpo, rocky, 17, Color(UI.TEAL, 0.95))
		_advance_row(cuerpo, n)
	elif not en_decision:
		var linea: Dictionary = _node["dialogue"][step - 1]
		var quien := UI.label(cuerpo, text_of(linea.get("name", {})), 14, Color(str(linea.get("color", "FFF5E4"))))
		UI.display(quien, 700, 3)
		_parrafo(cuerpo, "«" + text_of(linea.get("text", {})) + "»", 23, UI.CREAM)
		_advance_row(cuerpo, n)
	else:
		_choices(cuerpo)


## Escena corta: una sola pantalla con la imagen, el relato, las voces en radio y las opciones.
func _build_quick() -> void:
	step = _dialogue_count() + 1
	var cuerpo := _base(0.0, true, false)
	_cabecera(cuerpo)
	_parrafo(cuerpo, text_of(_node.get("text", {})), 19, Color(UI.CREAM, 0.95))
	for linea in _node.get("dialogue", []):
		var fila := RichTextLabel.new()
		fila.bbcode_enabled = true
		fila.fit_content = true
		fila.scroll_active = false
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.custom_minimum_size.x = ANCHO
		fila.add_theme_font_size_override("normal_font_size", 16)
		fila.add_theme_font_size_override("bold_font_size", 16)
		fila.add_theme_color_override("default_color", Color(UI.CREAM, 0.95))
		fila.text = "[b][color=#%s]%s[/color][/b]  «%s»" % [str(linea.get("color", "FFF5E4")),
			text_of(linea.get("name", {})), text_of(linea.get("text", {}))]
		cuerpo.add_child(fila)
	_choices(cuerpo)


## Pie de las escenas: «Ir a la decisión» y «Continuar» (un clic en cualquier parte o cualquier tecla también avanzan).
func _advance_row(cuerpo: Control, n: int) -> void:
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	pie.custom_minimum_size.x = ANCHO
	cuerpo.add_child(pie)
	var paso := UI.label(pie, "%d / %d" % [step + 1, n + 2], 12, Color(UI.CREAM, 0.55))
	paso.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var saltar := Button.new()
	saltar.text = tr("STORY_SKIP")
	saltar.custom_minimum_size = Vector2(150, 40)
	saltar.focus_mode = Control.FOCUS_NONE
	saltar.pressed.connect(func() -> void:
		step = n + 1
		_build_scene())
	pie.add_child(saltar)
	var seguir := Button.new()
	seguir.theme_type_variation = "PrimaryButton"
	seguir.text = tr("STORY_NEXT")
	seguir.custom_minimum_size = Vector2(170, 40)
	seguir.focus_mode = Control.FOCUS_NONE
	seguir.pressed.connect(advance)
	pie.add_child(seguir)


func advance() -> void:
	if shown_node.is_empty() or step >= _dialogue_count() + 1:
		return
	step += 1
	_build_scene()


func _choices(cuerpo: Control) -> void:
	var opciones: Array = _node.get("choices", [])
	_firma_opciones = JSON.stringify(opciones)
	UI.label(cuerpo, tr("STORY_CHOOSE") if opciones.size() > 1 else tr("STORY_CONTINUE"), 12, Color(UI.CREAM, 0.7))
	var primero: Button = null
	for i in range(opciones.size()):
		var op: Dictionary = opciones[i]
		var b := Button.new()
		b.theme_type_variation = "RowButton"
		b.custom_minimum_size = Vector2(ANCHO, 0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var detalle := text_of(op.get("detail", {}))
		var habilitada := bool(op.get("enabled", true))
		if not habilitada:
			detalle += "\n— " + tr(str(op.get("reason", "")))
		b.text = text_of(op.get("text", {})) + ("\n" + detalle if not detalle.is_empty() else "")
		b.disabled = not habilitada
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_elegir.bind(i))
		cuerpo.add_child(b)
		if primero == null and habilitada:
			primero = b
	if primero != null:
		primero.grab_focus.call_deferred()


func _elegir(indice: int) -> void:
	_firma_opciones = ""
	command.emit("decide", {"choice": indice})


func _build_intro() -> void:
	var cuerpo := _base(0.0, false, true)
	var pagina: Variant = intro_pages[intro_index]
	var es_final: bool = pagina is Dictionary and bool(pagina.get("final", false))
	if es_final:
		var titulo := UI.label(cuerpo, str(pagina.get("title", "")), 34, UI.CREAM)
		UI.display(titulo, 700, 0)
		titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titulo.custom_minimum_size.x = ANCHO
	else:
		var paso := UI.label(cuerpo, "GAIA  ·  %d / %d" % [intro_index + 1, intro_pages.size()], 13, UI.AMBER)
		UI.display(paso, 700, 3)
	_parrafo(cuerpo, text_of(pagina), 23, Color(UI.CREAM, 0.97))
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_theme_constant_override("separation", 10)
	pie.custom_minimum_size.x = ANCHO
	cuerpo.add_child(pie)
	if not es_final:
		var saltar := Button.new()
		saltar.text = tr("INTRO_SKIP")
		saltar.custom_minimum_size = Vector2(130, 42)
		saltar.focus_mode = Control.FOCUS_NONE
		saltar.pressed.connect(_terminar_intro)
		pie.add_child(saltar)
	var siguiente := Button.new()
	siguiente.theme_type_variation = "PrimaryButton"
	var ultima := intro_index >= intro_pages.size() - 1
	siguiente.text = (tr("STORY_NEXT") if es_final else tr("INTRO_START")) if ultima else tr("INTRO_NEXT")
	siguiente.custom_minimum_size = Vector2(180, 42)
	siguiente.focus_mode = Control.FOCUS_NONE
	siguiente.pressed.connect(_siguiente_intro)
	pie.add_child(siguiente)


func _siguiente_intro() -> void:
	if intro_index < 0:
		return
	if intro_index >= intro_pages.size() - 1:
		_terminar_intro()
	else:
		intro_index += 1
		_build_intro()


func _terminar_intro() -> void:
	intro_index = -1
	_close()
	var cb := _al_terminar
	_al_terminar = Callable()
	if cb.is_valid():
		cb.call()
		return
	intro_finished.emit()
	update_snapshot(snapshot)


## ---------- Radio (Houston, Rocky y Perseverance hablan mientras se sigue jugando) ----------

func _update_radio(s: Dictionary) -> void:
	var radio: Dictionary = s.get("story", {}).get("radio", {})
	var n := int(radio.get("n", 0))
	if radio_visto < 0:
		radio_visto = n  # partida cargada o primer snapshot: lo anterior ya sonó
		return
	if s.get("phase", "") != "operations":
		return
	if n > radio_visto:
		radio_visto = n
		_radio_cola.append(radio)  # se muestra cuando no haya una escena abierta (ver _process)


func _next_radio() -> void:
	if _radio_cola.is_empty():
		_close_radio()
		return
	_radio = _radio_cola.pop_front()
	radio_line = 0
	_build_radio()


## Pasa a la siguiente línea de la radio; al terminar cierra la tarjeta (o sigue con la cola).
func advance_radio() -> void:
	if radio_line < 0:
		return
	radio_line += 1
	if radio_line >= Array(_radio.get("dialogue", [])).size():
		_next_radio()
	else:
		_build_radio()


func _close_radio() -> void:
	radio_line = -1
	_radio = {}
	if is_instance_valid(radio_root):
		remove_child(radio_root)
		radio_root.queue_free()
	radio_root = null


func _build_radio() -> void:
	if is_instance_valid(radio_root):
		remove_child(radio_root)
		radio_root.queue_free()
	radio_root = Control.new()
	radio_root.name = "RadioRoot"
	radio_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radio_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_root.theme = UI.theme()
	add_child(radio_root)
	var dialogo: Array = _radio.get("dialogue", [])
	if dialogo.is_empty() or radio_line >= dialogo.size():
		return
	var linea: Dictionary = dialogo[radio_line]
	var tarjeta := PanelContainer.new()
	tarjeta.add_theme_stylebox_override("panel", UI.box(0.92, UI.RADIUS_PANEL, 0.3, 1, 10, 10, Color(str(linea.get("color", "FFF5E4")))))
	tarjeta.mouse_filter = Control.MOUSE_FILTER_STOP
	tarjeta.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UI.place(tarjeta, "bl", 20, 118, RADIO_ANCHO, 120)
	radio_root.add_child(tarjeta)
	tarjeta.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			advance_radio())
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tarjeta.add_child(fila)
	var textura := image_of(str(_radio.get("image", "")))
	if textura != null:
		var imagen := TextureRect.new()
		imagen.texture = textura
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		imagen.custom_minimum_size = Vector2(152, 96)
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(imagen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(col)
	var quien := UI.label(col, text_of(linea.get("name", {})), 12, Color(str(linea.get("color", "FFF5E4"))))
	UI.display(quien, 700, 3)
	var texto := UI.label(col, "«" + text_of(linea.get("text", {})) + "»", 15, UI.CREAM)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = RADIO_ANCHO - 200.0
	var pie := UI.label(col, "%s  ·  %d / %d" % [tr("RADIO_TAP"), radio_line + 1, dialogo.size()], 11, Color(UI.CREAM, 0.5))
	pie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radio_t = maxf(RADIO_SEGUNDOS_MIN, text_of(linea.get("text", {})).length() * RADIO_SEGUNDOS_POR_LETRA)
	radio_root.modulate.a = 0.0
	create_tween().tween_property(radio_root, "modulate:a", 1.0, 0.25)


func _process(delta: float) -> void:
	var escena := is_open() or intro_index >= 0
	if escena:
		_t_desde_build += delta
		if not _texto_visible:
			_espera_t += delta
			if _espera_t >= ESPERA_IMAGEN:
				_mostrar_texto()
	if is_instance_valid(radio_root):
		radio_root.visible = not escena  # la radio se esconde mientras haya una escena abierta
	if escena or bool(snapshot.get("paused", false)):
		return
	if radio_line < 0:
		if not _radio_cola.is_empty():
			_next_radio()
		return
	_radio_t -= delta
	if _radio_t <= 0.0:
		advance_radio()
