extends CanvasLayer
## Tutorial del Sol 1 en una ventana (plan de mejoras 2.2): anclada abajo a la izquierda y movible arrastrando su
## cabecera, con la captura real del paso (assets/tutorial/<destino>/<idioma>/<paso>.jpg, las saca
## tools/capturar_tutorial.gd), una flecha y un halo hacia lo que hay que pulsar, y los botones «Siguiente» y «Saltar».
## Se puede plegar. Mientras está desplegada, la radio de Houston espera (la vista lo consulta con is_expanded()).
## No bloquea el juego. Solo presenta: los pasos, cuándo se cumplen y el orden de saltar o pasar los decide la
## simulación (content/tutorial.json, TutorialSystem).
const UI := preload("res://scenes/b/ui_style.gd")
const Story := preload("res://scenes/b/story_panel.gd")
const ANCHO := 620.0
const IMAGEN := Vector2(320, 180)
const CAPTURAS := "res://assets/tutorial/%s/%s/%s.jpg"  ## destino, idioma, paso

signal command(command: String, payload: Dictionary)
signal step_changed  ## un paso se completó: la vista hace sonar un aviso

var root: Control
var target_for: Callable  ## «resalta» -> Control al que apunta el halo (lo asigna la vista; puede devolver null)
var shown_id := ""  ## paso que se ve ("" si no hay ventana)
var plegada := false
var _card: PanelContainer
var _title: Label
var _text: Label
var _imagen: TextureRect
var _cuerpo: HBoxContainer
var _plegar: Button
var _siguiente: Button
var _skip: Button
var _halo: Panel
var _flecha: Line2D
var _punta: Polygon2D
var _highlight := ""
var _imagen_id := ""
var _clock := 0.0
var _hidden := false  ## la vista lo oculta mientras hay una escena, la pausa, la tarjeta de objetivo o el informe
var _arrastrando := false


func _ready() -> void:
	layer = 7
	root = Control.new()
	root.name = "TutorialRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_halo = Panel.new()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contorno := UI.box(0.0, UI.RADIUS_PILL, 0.0, 0)
	contorno.bg_color = Color(UI.AMBER, 0.08)
	contorno.set_border_width_all(3)
	contorno.border_color = UI.AMBER
	_halo.add_theme_stylebox_override("panel", contorno)
	_halo.visible = false
	root.add_child(_halo)
	_flecha = Line2D.new()
	_flecha.width = 3.0
	_flecha.default_color = UI.AMBER
	_flecha.antialiased = true
	_flecha.visible = false
	root.add_child(_flecha)
	_punta = Polygon2D.new()
	_punta.color = UI.AMBER
	_punta.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-14, -7), Vector2(-14, 7)])
	_punta.visible = false
	root.add_child(_punta)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.add_theme_stylebox_override("panel", UI.box(0.92, UI.RADIUS_PANEL, 0.45, 1, 16, 12, UI.AMBER))
	UI.place(_card, "bl", 20, 112, ANCHO, 0)
	_card.visible = false
	root.add_child(_card)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 10)
	_card.add_child(caja)
	# Cabecera: título del paso (se arrastra desde aquí) y botón de plegar.
	var cabecera := HBoxContainer.new()
	cabecera.mouse_filter = Control.MOUSE_FILTER_STOP
	cabecera.mouse_default_cursor_shape = Control.CURSOR_MOVE
	cabecera.gui_input.connect(_al_arrastrar)
	caja.add_child(cabecera)
	_title = UI.label(cabecera, "", 12, UI.AMBER)
	UI.display(_title, 700, 2)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.mouse_filter = Control.MOUSE_FILTER_PASS
	_plegar = Button.new()
	_plegar.flat = true
	_plegar.focus_mode = Control.FOCUS_NONE
	_plegar.add_theme_font_size_override("font_size", 13)
	_plegar.pressed.connect(func() -> void: set_plegada(not plegada))
	cabecera.add_child(_plegar)
	# Cuerpo: captura real a la izquierda; texto y botones a la derecha.
	_cuerpo = HBoxContainer.new()
	_cuerpo.add_theme_constant_override("separation", 14)
	caja.add_child(_cuerpo)
	_imagen = TextureRect.new()
	_imagen.custom_minimum_size = IMAGEN
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cuerpo.add_child(_imagen)
	var derecha := VBoxContainer.new()
	derecha.add_theme_constant_override("separation", 8)
	derecha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuerpo.add_child(derecha)
	_text = UI.label(derecha, "", 15, UI.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(ANCHO - IMAGEN.x - 60.0, 0)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	botones.alignment = BoxContainer.ALIGNMENT_END
	derecha.add_child(botones)
	_skip = Button.new()
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 13)
	_skip.add_theme_color_override("font_color", Color(UI.CREAM, 0.7))
	_skip.add_theme_color_override("font_hover_color", UI.AMBER)
	_skip.pressed.connect(func() -> void: command.emit("tutorial_skip", {}))
	botones.add_child(_skip)
	_siguiente = Button.new()
	_siguiente.focus_mode = Control.FOCUS_NONE
	_siguiente.theme_type_variation = "PrimaryButton"
	_siguiente.pressed.connect(func() -> void: command.emit("tutorial_next", {}))
	botones.add_child(_siguiente)


func set_hidden(valor: bool) -> void:
	_hidden = valor
	_aplicar_visibilidad()


func is_showing() -> bool:
	return is_instance_valid(_card) and _card.visible


## Desplegada y a la vista: entonces la radio de Houston espera para no taparse con ella.
func is_expanded() -> bool:
	return is_showing() and not plegada


func set_plegada(valor: bool) -> void:
	plegada = valor
	if is_instance_valid(_cuerpo):
		_cuerpo.visible = not plegada
		_plegar.text = tr("TUTORIAL_EXPAND") if plegada else tr("TUTORIAL_FOLD")
		_card.reset_size()


func update_snapshot(s: Dictionary) -> void:
	var t: Dictionary = s.get("tutorial", {})
	var activo: bool = t.get("active", false) and s.get("phase", "") == "operations"
	if not activo:
		shown_id = ""
		_highlight = ""
		_aplicar_visibilidad()
		return
	var id := str(t.get("id", ""))
	if id != shown_id:
		var primero := shown_id.is_empty()
		shown_id = id
		if not primero:
			step_changed.emit()
		_flash()
	_title.text = tr("TUTORIAL_TITLE") % [int(t.get("step", 1)), int(t.get("total", 1))]
	_text.text = Story.text_of(t.get("text", {}))
	_skip.text = tr("TUTORIAL_SKIP")
	_siguiente.text = tr("TUTORIAL_NEXT")
	_plegar.text = tr("TUTORIAL_EXPAND") if plegada else tr("TUTORIAL_FOLD")
	_highlight = str(t.get("highlight", ""))
	_poner_imagen(str(t.get("image", id)))
	_aplicar_visibilidad()


## Captura real del paso en el idioma del jugador (o en español si falta); sin captura, solo texto.
static func ruta_captura(paso: String, destino: String, idioma: String) -> String:
	for lengua in [idioma, "es"]:
		var ruta := CAPTURAS % [destino, lengua, paso]
		if ResourceLoader.exists(ruta):
			return ruta
	return ""


func _poner_imagen(paso: String) -> void:
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var clave := "%s|%s|%s" % [Destino.id, idioma, paso]
	if clave == _imagen_id:
		return
	_imagen_id = clave
	var ruta := ruta_captura(paso, Destino.id, idioma)
	_imagen.texture = load(ruta) if not ruta.is_empty() else null
	_imagen.visible = _imagen.texture != null


func _aplicar_visibilidad() -> void:
	if not is_instance_valid(_card):
		return
	var ver := not shown_id.is_empty() and not _hidden
	_card.visible = ver
	if not ver:
		_halo.visible = false
		_flecha.visible = false
		_punta.visible = false


## Destello al cambiar de paso: la ventana entra desde transparente.
func _flash() -> void:
	if not is_instance_valid(_card):
		return
	_card.modulate = Color(1.5, 1.4, 1.1, 0.0)
	var tween := create_tween()
	tween.tween_property(_card, "modulate", Color.WHITE, 0.45)


## Arrastrar la cabecera mueve la ventana (sin salirse de la pantalla).
func _al_arrastrar(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = e.pressed
	elif e is InputEventMouseMotion and _arrastrando:
		var limite := root.size - _card.size
		_card.position = (_card.position + e.relative).clamp(Vector2.ZERO, limite.max(Vector2.ZERO))


func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_halo):
		return
	var destino: Control = target_for.call(_highlight) if target_for.is_valid() and not _highlight.is_empty() else null
	if not _card.visible or destino == null or not is_instance_valid(destino) or not destino.is_visible_in_tree():
		_halo.visible = false
		_flecha.visible = false
		_punta.visible = false
		return
	var caja := destino.get_global_rect().grow(6.0)
	var pulso := 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 4.0))
	_halo.visible = true
	_halo.position = caja.position
	_halo.size = caja.size
	_halo.modulate.a = pulso
	# Flecha desde el borde de la ventana hasta el borde de lo que hay que pulsar.
	var ventana := _card.get_global_rect()
	var hacia := caja.get_center()
	var desde := Vector2(clampf(hacia.x, ventana.position.x + 24.0, ventana.end.x - 24.0),
		clampf(hacia.y, ventana.position.y, ventana.end.y))
	if ventana.has_point(hacia) or caja.intersects(ventana):
		_flecha.visible = false
		_punta.visible = false
		return
	var punta := _borde(caja, desde)
	_flecha.points = PackedVector2Array([desde, punta])
	_flecha.visible = true
	_flecha.modulate.a = pulso
	_punta.visible = true
	_punta.position = punta
	_punta.rotation = (punta - desde).angle()
	_punta.modulate.a = pulso


## Punto del borde de «caja» en la línea que va de su centro hacia «desde».
static func _borde(caja: Rect2, desde: Vector2) -> Vector2:
	var centro := caja.get_center()
	var dir := desde - centro
	if dir.length() < 0.01:
		return centro
	var tx: float = (caja.size.x * 0.5) / absf(dir.x) if absf(dir.x) > 0.001 else INF
	var ty: float = (caja.size.y * 0.5) / absf(dir.y) if absf(dir.y) > 0.001 else INF
	return centro + dir * minf(minf(tx, ty), 1.0)
