extends CanvasLayer
## Taller de diseño de misión (diseño visual consolidado, sección «Taller»).
## Solo presenta el bloque "workshop" del snapshot que entrega la simulación y envía órdenes
## design_add / design_remove / design_validate / design_start. No calcula costos, masas ni validez.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")

signal command(command: String, payload: Dictionary)
signal options_requested

const ORDER: Array[String] = ["cohetes", "chasis", "energia", "comunicaciones", "extras"]
const CATEGORY_KEYS := {"cohetes": "CAT_COHETES", "chasis": "CAT_CHASIS", "energia": "CAT_ENERGIA",
	"comunicaciones": "CAT_COMUNICACIONES", "extras": "CAT_EXTRAS"}
const CARD_SIZE := Vector2(186, 118)

var root: Control
var snapshot: Dictionary = {}
var category := "cohetes"
var validated := false

var _signature := ""
var _category_buttons: Dictionary = {}
var _cards: HFlowContainer
var _summary_box: VBoxContainer
var _action: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_until := 0.0
var _turntable: Node3D
var _rover: Node3D
var _drone: Node3D
var _companion: Node3D
var _names: Dictionary = {}


func _ready() -> void:
	layer = 4
	visible = false
	build()


func build() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	_category_buttons.clear()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	_background()
	var marca := Button.new()
	marca.text = "A"
	marca.theme_type_variation = "IconButton"
	marca.focus_mode = Control.FOCUS_NONE
	marca.add_theme_font_size_override("font_size", 15)
	UI.place(marca, "tl", 20, 20, 34, 34)
	root.add_child(marca)
	var titulo := Label.new()
	titulo.text = tr("WS_TITLE")
	titulo.add_theme_font_size_override("font_size", UI.FONT_TITLE)
	var medio := UI.display_font(600)
	if medio != null:
		titulo.add_theme_font_override("font", medio)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.place(titulo, "tl", 64, 18, 470, 36)
	root.add_child(titulo)
	var opciones := Button.new()
	opciones.theme_type_variation = "IconButton"
	opciones.focus_mode = Control.FOCUS_NONE
	opciones.tooltip_text = tr("OPTIONS")
	var engranaje := Icon.make("gear", 14)
	engranaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	engranaje.offset_left = -7
	engranaje.offset_right = 7
	engranaje.offset_top = -7
	engranaje.offset_bottom = 7
	opciones.add_child(engranaje)
	UI.place(opciones, "tr", 20, 22, 30, 30)
	root.add_child(opciones)
	opciones.pressed.connect(func(): options_requested.emit())
	_build_categories()
	_build_preview()
	_build_options_strip()
	_build_summary()
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PILL, 0.35, 1, 18, 8))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_toast, "bc", 0, 18, 420, 38)
	_toast_label = UI.label(_toast, "", UI.FONT_SECONDARY)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	root.add_child(_toast)
	_signature = ""
	if not snapshot.is_empty():
		update_snapshot(snapshot)


func _background() -> void:
	var degradado := Gradient.new()
	degradado.set_color(0, Color("4A3226"))
	degradado.set_color(1, Color("22150E"))
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0.5, 0.0)
	textura.fill_to = Vector2(0.5, 1.0)
	textura.width = 8
	textura.height = 256
	var fondo := TextureRect.new()
	fondo.texture = textura
	fondo.stretch_mode = TextureRect.STRETCH_SCALE
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(fondo)


func _build_categories() -> void:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)
	UI.place(panel, "tl", 20, 96, 164, 320)
	root.add_child(panel)
	for id in ORDER:
		var b := Button.new()
		b.theme_type_variation = "RowButton"
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = tr(CATEGORY_KEYS[id])
		b.custom_minimum_size = Vector2(164, 48)
		b.add_theme_font_size_override("font_size", UI.FONT_TEXT)
		panel.add_child(b)
		b.pressed.connect(func(): _choose_category(id))
		_category_buttons[id] = b
	_category_buttons[category].button_pressed = true


func _choose_category(id: String) -> void:
	category = id
	for k in _category_buttons:
		_category_buttons[k].button_pressed = k == id
	_signature = ""
	if not snapshot.is_empty():
		update_snapshot(snapshot)


func _build_preview() -> void:
	var marco := Control.new()
	UI.place(marco, "tl", 200, 96, 604, 284)
	root.add_child(marco)
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marco.add_child(contenedor)
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_2X
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	contenedor.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("5A3F30")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("D9B79B")
	entorno.ambient_light_energy = 0.7
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42, -35, 0)
	luz.light_color = Color("FFE0BC")
	luz.light_energy = 1.0
	vista.add_child(luz)
	var camara := Camera3D.new()
	camara.fov = 36
	vista.add_child(camara)
	camara.position = Vector3(5.4, 3.0, 6.6)
	camara.look_at(Vector3(0, 0.9, 0))
	_turntable = Node3D.new()
	vista.add_child(_turntable)
	var W := preload("res://scenes/b/world_art.gd")
	var suelo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 3.6
	disco.bottom_radius = 3.8
	disco.height = 0.12
	disco.radial_segments = 20
	suelo.mesh = disco
	suelo.material_override = W.flat_material(Color("8A5A44"), false)
	suelo.position.y = -0.06
	vista.add_child(suelo)
	_rover = load("res://scenes/b/assets/models/rover.tscn").instantiate()
	_turntable.add_child(_rover)
	_drone = load("res://scenes/b/assets/models/drone.tscn").instantiate()
	_turntable.add_child(_drone)
	_drone.position = Vector3(-2.0, 1.4, 1.2)
	_companion = load("res://scenes/b/assets/models/companion.tscn").instantiate()
	_turntable.add_child(_companion)
	_companion.position = Vector3(2.0, 0, 1.4)
	var borde := Panel.new()
	borde.mouse_filter = Control.MOUSE_FILTER_IGNORE
	borde.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var estilo := UI.box(0.0, UI.RADIUS_PANEL, 0.25, 1, 0, 0)
	estilo.draw_center = false
	borde.add_theme_stylebox_override("panel", estilo)
	marco.add_child(borde)
	var nota := UI.label(marco, tr("WS_PREVIEW_NOTE"), 13, Color(UI.CREAM, 0.7))
	nota.position = Vector2(14, 258)
	nota.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_options_strip() -> void:
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UI.place(desplazable, "tl", 200, 396, 604, 264)
	root.add_child(desplazable)
	_cards = HFlowContainer.new()
	_cards.add_theme_constant_override("h_separation", 10)
	_cards.add_theme_constant_override("v_separation", 10)
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(_cards)


func _build_summary() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PANEL, 0.25, 1, 20, 18))
	UI.place(panel, "tr", 20, 96, 440, 564)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var titulo := UI.label(col, tr("WS_SUMMARY"), UI.FONT_PANEL_TITLE)
	var medio := UI.display_font(600)
	if medio != null:
		titulo.add_theme_font_override("font", medio)
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 10)
	_summary_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_summary_box)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(fila)
	_action = Button.new()
	_action.theme_type_variation = "PrimaryButton"
	_action.custom_minimum_size = Vector2(180, 44)
	_action.text = tr("WS_VALIDATE")
	fila.add_child(_action)
	_action.pressed.connect(_on_action)


# ---------------------------------------------------------------- estado

func update_snapshot(s: Dictionary) -> void:
	snapshot = s
	var taller: Dictionary = s.get("workshop", {})
	var en_taller := str(s.get("phase", "")) == "workshop" and not taller.is_empty()
	visible = en_taller
	if not en_taller or not is_instance_valid(root):
		return
	_names.clear()
	for cat in taller.get("categories", []):
		for part in cat.get("parts", []):
			_names[str(part["id"])] = str(part.get("name_key", ""))
	var firma := "%s|%s|%s|%s|%s" % [category, str(taller.get("selection")), str(taller.get("totals")), str(taller.get("validation")), TranslationServer.get_locale()]
	if firma == _signature:
		return
	if not _signature.is_empty() and firma.split("|")[1] != _signature.split("|")[1]:
		validated = false
	_signature = firma
	_rebuild_cards(taller)
	_rebuild_summary(taller)
	_update_preview(taller.get("selection", {}))
	_action.text = tr("WS_START") if validated and taller.get("valid", false) else tr("WS_VALIDATE")


func _selected_ids(taller: Dictionary) -> Array:
	var ids: Array = []
	for cat in taller.get("selection", {}):
		ids.append_array(taller["selection"][cat])
	return ids


func _rebuild_cards(taller: Dictionary) -> void:
	for hijo in _cards.get_children():
		hijo.queue_free()
	var elegidas: Array = taller.get("selection", {}).get(category, [])
	for cat in taller.get("categories", []):
		if str(cat["id"]) != category:
			continue
		for part in cat["parts"]:
			_cards.add_child(_card(part, elegidas.has(part["id"])))


func _card(part: Dictionary, elegida: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	var motivo := str(part.get("reason", ""))
	var puede := bool(part.get("available", true)) or motivo == "CATEGORY_FULL"
	b.disabled = not puede and not elegida
	var relleno := Color("5C4230", 0.95) if elegida else Color("4A3629", 0.82)
	b.add_theme_stylebox_override("normal", UI.button_box(relleno, Color(UI.AMBER, 1.0) if elegida else Color(UI.CREAM, 0.22), 2 if elegida else 1, UI.RADIUS_PANEL, 12, 10))
	b.add_theme_stylebox_override("hover", UI.button_box(Color("5E4433", 0.95), Color(UI.AMBER, 1.0 if elegida else 0.75), 2 if elegida else 1, UI.RADIUS_PANEL, 12, 10, 5))
	b.add_theme_stylebox_override("pressed", UI.button_box(Color("2B1D15", 0.95), Color(UI.AMBER, 1.0), 2, UI.RADIUS_PANEL, 12, 10, 0))
	b.add_theme_stylebox_override("disabled", UI.button_box(Color("3A2A20", 0.5), Color(UI.CREAM, 0.1), 1, UI.RADIUS_PANEL, 12, 10, 0))
	b.clip_contents = true
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 12
	col.offset_top = 10
	col.offset_right = -12
	col.offset_bottom = -8
	b.add_child(col)
	var nombre := UI.label(col, tr(str(part.get("name_key", ""))), UI.FONT_TEXT)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if part.get("pending", false):
		var pendiente := UI.label(col, tr("WS_PENDING"), UI.FONT_SECONDARY, UI.AMBER)
		pendiente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		for par in [["cost_musd", "WS_COST"], ["mass_kg", "WS_MASS"], ["capacity_kg", "WS_CAPACITY"], ["power_w", "WS_POWER"]]:
			var valor = part.get(par[0])
			if valor != null:
				var linea := UI.label(col, tr(par[1]) % int(valor), UI.FONT_SECONDARY, Color(UI.CREAM, 0.85))
				linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not puede and not elegida and not motivo.is_empty():
		var razon := UI.label(col, tr(motivo), 12, UI.AMBER)
		razon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		razon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(_on_card.bind(part, elegida))
	return b


func _on_card(part: Dictionary, elegida: bool) -> void:
	var taller: Dictionary = snapshot.get("workshop", {})
	validated = false
	if elegida:
		command.emit("design_remove", {"part_id": part["id"]})
		return
	if str(part.get("reason", "")) == "CATEGORY_FULL":
		# Categoría de una sola pieza: se cambia la actual por la elegida (dos órdenes del mismo gesto).
		for id in taller.get("selection", {}).get(category, []).duplicate():
			command.emit("design_remove", {"part_id": id})
	command.emit("design_add", {"part_id": part["id"]})


func _rebuild_summary(taller: Dictionary) -> void:
	for hijo in _summary_box.get_children():
		hijo.queue_free()
	var seleccion: Dictionary = taller.get("selection", {})
	var totales: Dictionary = taller.get("totals", {})
	_section(tr("WS_CONFIG"))
	for id in ORDER:
		var fila := HBoxContainer.new()
		_summary_box.add_child(fila)
		var nombre := UI.label(fila, tr(CATEGORY_KEYS[id]), UI.FONT_SECONDARY, Color(UI.CREAM, 0.75))
		nombre.custom_minimum_size.x = 120
		var piezas: Array = seleccion.get(id, [])
		var texto := tr("WS_NONE")
		if not piezas.is_empty():
			var nombres: Array[String] = []
			for pid in piezas:
				nombres.append(tr(str(_names.get(pid, pid))))
			texto = ", ".join(nombres)
		var valor := UI.label(fila, texto, 15, UI.CREAM if not piezas.is_empty() else Color(UI.CREAM, 0.5))
		valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		valor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var costo := float(totales.get("cost_musd", 0))
	var presupuesto := float(totales.get("budget_musd", 700))
	_meter(tr("WS_BUDGET"), "%d / %d M USD" % [costo, presupuesto], costo, presupuesto, costo > presupuesto)
	var masa := float(totales.get("mass_kg", 0))
	var capacidad := float(totales.get("capacity_kg", 0))
	_meter(tr("WS_MASS_LABEL"), "%d / %d kg" % [masa, capacidad], masa, maxf(capacidad, 1.0), capacidad > 0.0 and masa > capacidad)
	var potencia := UI.label(_summary_box, "%s: %s" % [tr("WS_POWER_LABEL"), tr("WS_POWER") % int(totales.get("power_w", 0))], 15)
	potencia.add_theme_color_override("font_color", UI.CREAM)
	var mensajes: Array = []
	for codigo in taller.get("validation", []):
		mensajes.append([_message(str(codigo)), true])
	for codigo in taller.get("notices", []):
		mensajes.append([_message(str(codigo)), false])
	_section("")
	for par in mensajes:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 8)
		_summary_box.add_child(fila)
		var tono: Color = UI.CORAL if par[1] else UI.AMBER
		fila.add_child(Icon.make("critical" if par[1] else "warning", 16, tono))
		var texto := UI.label(fila, par[0], UI.FONT_SECONDARY)
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if taller.get("valid", false):
		var ok := UI.label(_summary_box, tr("WS_VALID_OK"), UI.FONT_SECONDARY, UI.TEAL)
		ok.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _section(titulo: String) -> void:
	if titulo.is_empty():
		var hueco := Control.new()
		hueco.custom_minimum_size.y = 4
		_summary_box.add_child(hueco)
		return
	var l := UI.label(_summary_box, titulo, UI.FONT_TEXT, UI.AMBER)
	l.add_theme_font_size_override("font_size", UI.FONT_SECONDARY)


func _meter(titulo: String, valor: String, actual: float, maximo: float, excedido: bool) -> void:
	var fila := HBoxContainer.new()
	_summary_box.add_child(fila)
	var nombre := UI.label(fila, titulo, UI.FONT_SECONDARY, Color(UI.CREAM, 0.75))
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(fila, valor, 15, UI.CORAL if excedido else UI.CREAM)
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 6)
	barra.max_value = maximo
	barra.value = minf(actual, maximo)
	if excedido:
		var relleno := UI.box(0.95, 4, 0.0, 0, 0, 0)
		relleno.bg_color = UI.CORAL
		barra.add_theme_stylebox_override("fill", relleno)
	_summary_box.add_child(barra)


func _message(codigo: String) -> String:
	var partes := codigo.split(":")
	match partes[0]:
		"BELOW_MIN":
			return tr("WS_BELOW_MIN") % tr(CATEGORY_KEYS.get(partes[1], partes[1]))
		"ABOVE_MAX":
			return tr("WS_ABOVE_MAX") % tr(CATEGORY_KEYS.get(partes[1], partes[1]))
		"OVER_MASS":
			return tr("WS_OVER_MASS")
		"OVER_BUDGET":
			return tr("WS_OVER_BUDGET")
		"PENDING_DATA":
			return tr("WS_PENDING_DATA") % tr(str(_names.get(partes[1], partes[1])))
	return codigo


func _on_action() -> void:
	var taller: Dictionary = snapshot.get("workshop", {})
	if validated and taller.get("valid", false):
		command.emit("design_start", {})
		return
	command.emit("design_validate", {})
	validated = bool(snapshot.get("workshop", {}).get("valid", false))
	_signature = ""
	update_snapshot(snapshot)


func _update_preview(seleccion: Dictionary) -> void:
	var ids: Array = []
	for cat in seleccion:
		ids.append_array(seleccion[cat])
	var partes := {"solar": "panel_solar", "rtg": "mmrtg", "drill": "taladro", "radar": "radar", "spectrometer": "espectrometro", "meteo": "meteo"}
	for clave in partes:
		var nodo := _rover.find_child(clave, true, false)
		if nodo != null:
			nodo.visible = ids.has(partes[clave])
	_drone.visible = ids.has("dron")
	_companion.visible = ids.has("companero")


func show_notice(key: String) -> void:
	if not is_instance_valid(_toast_label):
		return
	_toast_label.text = tr(key)
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.5
	_toast.visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	if is_instance_valid(_turntable):
		_turntable.rotate_y(delta * 0.35)
	if is_instance_valid(_toast) and _toast.visible and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_toast.visible = false
