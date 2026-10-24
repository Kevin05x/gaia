extends CanvasLayer
## Taller de diseño de misión: «Hangar de ensamblaje».
## Solo presenta el bloque "workshop" del snapshot que entrega la simulación y envía órdenes
## design_add / design_remove / design_validate / design_start. No calcula costos, masas ni validez.
##
## Composición (concepto A): el rover sobre su plataforma ocupa toda la pantalla dentro de un hangar con ventana a Marte;
## encima, los pasos de categoría, el consejo de ingeniería, el catálogo en carrusel y la «Ficha de misión» a la derecha.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")

signal command(command: String, payload: Dictionary)
signal options_requested

const ORDER: Array[String] = ["cohetes", "chasis", "energia", "comunicaciones", "extras"]
const CATEGORY_KEYS := {"cohetes": "CAT_COHETES", "chasis": "CAT_CHASIS", "energia": "CAT_ENERGIA",
	"comunicaciones": "CAT_COMUNICACIONES", "extras": "CAT_EXTRAS"}
const CATEGORY_ICONS := {"cohetes": "rocket", "chasis": "chassis", "energia": "bolt", "comunicaciones": "antenna", "extras": "flask"}
## Icono de cada pieza (las que no aparecen usan el de su categoría).
const PART_ICONS := {"cohete_ligero": "rocket", "cohete_pesado": "rocket", "chasis_base": "chassis", "panel_solar": "solar",
	"mmrtg": "atom", "antena_directa": "antenna", "antena_rele": "link", "espectrometro": "spectrometer", "taladro": "drill",
	"camara": "camera", "meteo": "meteo", "radar": "radar", "bateria": "battery", "dron": "drone", "companero": "companion"}
## Nodo del rover sobre el que se marca cada pieza elegida.
const PART_NODES := {"panel_solar": "solar", "mmrtg": "rtg", "taladro": "drill", "radar": "radar", "espectrometro": "spectrometer",
	"meteo": "meteo", "camara": "head", "antena_directa": "HighGain", "antena_rele": "HighGain"}
const CARD_SIZE := Vector2(117, 144)
const CARD_GAP := 12.0
const FICHA_ANCHO := 336.0
const MARGEN := 20.0
## Paleta del taller: naranja de hangar sobre marrones muy oscuros.
const ORANGE := Color("F7A021")
const ORANGE_SOFT := Color("F7A021", 0.55)
const PANEL_BG := Color("120A06", 0.9)
const PANEL_EDGE := Color("B8742A", 0.45)
const CARD_BG := Color("1A100A", 0.92)
const TEXT_DIM := Color("D8C3AC", 0.62)

var root: Control
var snapshot: Dictionary = {}
var category := "cohetes"
var validated := false

var _signature := ""
var _category_buttons: Dictionary = {}
var _step_names: Dictionary = {}
var _step_checks: Dictionary = {}
var _step_labels: Dictionary = {}
var _cards: HBoxContainer
var _strip: ScrollContainer
var _arrow_left: Button
var _arrow_right: Button
var _dots: HBoxContainer
var _summary_box: VBoxContainer
var _action: Button
var _hint: Label
var _tip_text: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_until := 0.0
var _turntable: Node3D
var _camera: Camera3D
var _rover: Node3D
var _drone: Node3D
var _companion: Node3D
var _hotspot_layer: Control
var _hotspots: Dictionary = {}
var _clock := 0.0
var _names: Dictionary = {}


## Medidor circular (presupuesto): pista tenue y arco naranja.
class Ring extends Control:
	var value := 0.0
	var over := false

	func _draw() -> void:
		var centro := size / 2.0
		var radio := minf(size.x, size.y) / 2.0 - 9.0
		draw_arc(centro, radio, 0.0, TAU, 72, Color("5A4330", 0.55), 13.0, true)
		if value > 0.0:
			var tono: Color = UI.CORAL if over else Color("F7A021")
			draw_arc(centro, radio, -PI / 2.0, -PI / 2.0 + TAU * clampf(value, 0.0, 1.0), 72, tono, 13.0, true)


## Línea de puntos que une un paso con el siguiente.
class DotLine extends Control:
	func _draw() -> void:
		var n := 5
		for i in range(n):
			var x := size.x * (i + 0.5) / float(n)
			draw_circle(Vector2(x, size.y / 2.0), 2.0 if i % 2 == 0 else 1.5, Color("F7A021", 0.75 if i % 2 == 0 else 0.4))


## Silueta tenue de relieve y rover, decoración del consejo de ingeniería.
class Sketch extends Control:
	func _draw() -> void:
		var c := Color("D8C3AC", 0.32)
		var base := size.y * 0.78
		var cresta := PackedVector2Array([Vector2(0, base), Vector2(size.x * 0.12, base - 8), Vector2(size.x * 0.22, base - 3),
			Vector2(size.x * 0.36, base - 15), Vector2(size.x * 0.5, base - 6), Vector2(size.x * 0.66, base - 12), Vector2(size.x * 0.82, base - 4), Vector2(size.x, base - 9)])
		draw_polyline(cresta, c, 1.0, true)
		var x0 := size.x * 0.3
		var y0 := base - 2.0
		draw_rect(Rect2(x0, y0 - 14, 34, 8), Color(c, 0.0), false, 1.0)
		draw_polyline(PackedVector2Array([Vector2(x0, y0 - 6), Vector2(x0, y0 - 14), Vector2(x0 + 34, y0 - 14), Vector2(x0 + 34, y0 - 6), Vector2(x0, y0 - 6)]), c, 1.0, true)
		draw_line(Vector2(x0 + 26, y0 - 14), Vector2(x0 + 26, y0 - 24), c, 1.0, true)
		draw_rect(Rect2(x0 + 22, y0 - 28, 8, 4), Color(c, 0.0), false, 1.0)
		for i in range(3):
			var cx := x0 + 5.0 + i * 12.0
			var pts := PackedVector2Array()
			for k in range(13):
				pts.append(Vector2(cx, y0 - 2.0) + Vector2.from_angle(k * TAU / 12.0) * 3.5)
			draw_polyline(pts, c, 1.0, true)


func _ready() -> void:
	layer = 4
	visible = false
	build()


func build() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	_category_buttons.clear()
	_step_names.clear()
	_step_checks.clear()
	_step_labels.clear()
	_hotspots.clear()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	_build_preview()
	_vignette()
	_build_header()
	_build_stepper()
	_build_tip()
	_build_catalog()
	_build_summary()
	_build_options()
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


## Coloca un control con márgenes respecto de los cuatro bordes de la pantalla.
func _frame(c: Control, izquierda: float, arriba: float, derecha: float, abajo: float) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = izquierda
	c.offset_top = arriba
	c.offset_right = -derecha
	c.offset_bottom = -abajo


## Degradado lineal como textura (para velos oscuros en los bordes).
func _fade(desde: Vector2, hasta: Vector2, alfa_inicio: float, alfa_fin: float) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color("080403", alfa_inicio))
	g.set_color(1, Color("080403", alfa_fin))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = desde
	t.fill_to = hasta
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Velos que oscurecen los bordes: la mirada se queda en el rover y los paneles se leen bien.
func _vignette() -> void:
	var izquierda := _fade(Vector2(0, 0.5), Vector2(1, 0.5), 0.78, 0.0)
	_frame(izquierda, 0, 0, 1280.0 - 330.0, 0)
	izquierda.anchor_right = 0.0
	izquierda.offset_right = 330
	root.add_child(izquierda)
	var abajo := _fade(Vector2(0.5, 1), Vector2(0.5, 0), 0.88, 0.0)
	abajo.anchor_top = 1.0
	abajo.offset_top = -270
	abajo.offset_left = 0
	abajo.anchor_right = 1.0
	root.add_child(abajo)
	var arriba := _fade(Vector2(0.5, 0), Vector2(0.5, 1), 0.7, 0.0)
	arriba.anchor_right = 1.0
	arriba.anchor_bottom = 0.0
	arriba.offset_bottom = 110
	root.add_child(arriba)
	var derecha := _fade(Vector2(1, 0.5), Vector2(0, 0.5), 0.8, 0.0)
	derecha.anchor_left = 1.0
	derecha.anchor_right = 1.0
	derecha.anchor_bottom = 1.0
	derecha.offset_left = -430
	root.add_child(derecha)


func _build_header() -> void:
	var emblema := PanelContainer.new()
	emblema.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var caja := UI.box(0.0, 20, 0.9, 2, 0, 0, ORANGE)
	caja.draw_center = false
	emblema.add_theme_stylebox_override("panel", caja)
	UI.place(emblema, "tl", 24, 22, 42, 42)
	root.add_child(emblema)
	var icono := Icon.make("rocket", 22, ORANGE)
	icono.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	icono.offset_left = -11
	icono.offset_right = 11
	icono.offset_top = -11
	icono.offset_bottom = 11
	emblema.add_child(icono)
	var titulo := Label.new()
	titulo.text = tr("WS_TITLE").to_upper()
	titulo.add_theme_font_size_override("font_size", 22)
	var fuerte := UI.display_font(700)
	if fuerte != null:
		titulo.add_theme_font_override("font", fuerte)
	titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(titulo, "tl", 76, 20, 360, 28)
	root.add_child(titulo)
	var sub := UI.label(root, tr("WS_SUBTITLE"), 11, Color(ORANGE, 0.9))
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(sub, "tl", 76, 50, 330, 16)
	var centro := Label.new()
	centro.text = tr("WS_HANGAR").to_upper()
	centro.add_theme_font_size_override("font_size", 19)
	if fuerte != null:
		centro.add_theme_font_override("font", fuerte)
	centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame(centro, 170, 26, FICHA_ANCHO + MARGEN * 2.0 + 10.0, 0)
	centro.anchor_bottom = 0.0
	centro.offset_bottom = 54
	root.add_child(centro)


## Se crea al final para quedar por encima de todo lo demás.
func _build_options() -> void:
	var opciones := Button.new()
	opciones.focus_mode = Control.FOCUS_NONE
	opciones.tooltip_text = tr("OPTIONS")
	opciones.text = "      " + tr("WS_HELP").to_upper()
	opciones.add_theme_font_size_override("font_size", 11)
	opciones.add_theme_color_override("font_color", TEXT_DIM)
	opciones.add_theme_color_override("font_hover_color", ORANGE)
	opciones.add_theme_stylebox_override("normal", UI.button_box(Color("120A06", 0.85), Color(ORANGE, 0.35), 1, 14, 12, 4, 0))
	opciones.add_theme_stylebox_override("hover", UI.button_box(Color("2A170B", 0.95), Color(ORANGE, 0.9), 1, 14, 12, 4, 0))
	opciones.add_theme_stylebox_override("pressed", UI.button_box(Color("0A0604", 0.95), Color(ORANGE, 1.0), 1, 14, 12, 4, 0))
	var engranaje := Icon.make("gear", 14, TEXT_DIM)
	engranaje.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	engranaje.offset_left = 11
	engranaje.offset_right = 25
	engranaje.offset_top = -7
	engranaje.offset_bottom = 7
	opciones.add_child(engranaje)
	UI.place(opciones, "bl", 24, 10, 96, 28)
	root.add_child(opciones)
	opciones.pressed.connect(func(): options_requested.emit())


# ---------------------------------------------------------------- pasos de categoría

func _build_stepper() -> void:
	var zona := Control.new()
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame(zona, 170, 62, FICHA_ANCHO + MARGEN * 2.0 + 10.0, 0)
	zona.anchor_bottom = 0.0
	zona.offset_bottom = 170
	root.add_child(zona)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	zona.add_child(centro)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)
	centro.add_child(fila)
	for i in range(ORDER.size()):
		var id: String = ORDER[i]
		if i > 0:
			var puntos := DotLine.new()
			puntos.custom_minimum_size = Vector2(36, 66)
			puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fila.add_child(puntos)
		var paso := VBoxContainer.new()
		paso.add_theme_constant_override("separation", 6)
		paso.custom_minimum_size = Vector2(112, 0)
		fila.add_child(paso)
		var boton := Button.new()
		boton.focus_mode = Control.FOCUS_ALL
		boton.custom_minimum_size = Vector2(66, 66)
		boton.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		boton.tooltip_text = tr(CATEGORY_KEYS[id])
		paso.add_child(boton)
		var icono := Icon.make(CATEGORY_ICONS[id], 28)
		icono.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		icono.offset_left = -14
		icono.offset_right = 14
		icono.offset_top = -14
		icono.offset_bottom = 14
		boton.add_child(icono)
		_step_labels[id] = icono
		var fondo_marca := Panel.new()
		fondo_marca.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fondo_marca.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		fondo_marca.offset_left = -17
		fondo_marca.offset_right = 3
		fondo_marca.offset_top = -3
		fondo_marca.offset_bottom = 17
		var estilo := UI.box(1.0, 10, 0.0, 0, 0, 0)
		estilo.bg_color = ORANGE
		fondo_marca.add_theme_stylebox_override("panel", estilo)
		fondo_marca.visible = false
		boton.add_child(fondo_marca)
		var marca := Icon.make("check", 14, Color("1A0E06"))
		marca.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		marca.offset_left = -14
		marca.offset_right = 0
		marca.offset_top = 0
		marca.offset_bottom = 14
		boton.add_child(marca)
		marca.visible = false
		_step_checks[id] = [fondo_marca, marca]
		var nombre := UI.label(paso, tr(CATEGORY_KEYS[id]).to_upper(), 14, Color("F3E6D4"))
		UI.display(nombre, 700, 0)
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_step_names[id] = nombre
		boton.pressed.connect(func(): _choose_category(id))
		_category_buttons[id] = boton
	_style_steps()


func _style_steps() -> void:
	for id in _category_buttons:
		var boton: Button = _category_buttons[id]
		var activo: bool = id == category
		var relleno := Color("2A170B", 0.9) if activo else Color("140C07", 0.85)
		var borde := ORANGE if activo else Color("C9935A", 0.5)
		var normal := UI.button_box(relleno, borde, 3 if activo else 2, 33, 0, 0, 14 if activo else 0)
		if activo:
			normal.shadow_color = Color(ORANGE, 0.55)
			normal.shadow_offset = Vector2.ZERO
		boton.add_theme_stylebox_override("normal", normal)
		boton.add_theme_stylebox_override("hover", UI.button_box(Color("34200F", 0.95), Color(ORANGE, 0.95), 3 if activo else 2, 33, 0, 0, 10))
		boton.add_theme_stylebox_override("pressed", UI.button_box(Color("0C0704", 0.95), ORANGE, 3, 33, 0, 0, 0))
		boton.add_theme_stylebox_override("focus", UI.button_box(Color(0, 0, 0, 0), Color("FFF5E4", 0.9), 2, 33, 0, 0, 0))
		(_step_labels[id] as Control).set("color", ORANGE if activo else Color("F3E6D4"))
		(_step_names[id] as Label).add_theme_color_override("font_color", ORANGE if activo else Color("F3E6D4"))


func _choose_category(id: String) -> void:
	category = id
	_style_steps()
	_signature = ""
	_refresh_tip()
	if not snapshot.is_empty():
		update_snapshot(snapshot)


# ---------------------------------------------------------------- hangar 3D

func _material(color: Color, emision := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	return m


func _add_mesh(padre: Node, malla: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = malla
	n.material_override = mat
	n.position = pos
	n.rotation = rot
	padre.add_child(n)
	return n


func _build_preview() -> void:
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(contenedor)
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_2X
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	contenedor.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("0A0604")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("A9693A")
	entorno.ambient_light_energy = 0.55
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	entorno.fog_enabled = true
	entorno.fog_light_color = Color("2B160B")
	entorno.fog_density = 0.018
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-38, 40, 0)
	luz.light_color = Color("FFC890")
	luz.light_energy = 0.9
	vista.add_child(luz)
	var foco := OmniLight3D.new()  # luz cálida cenital sobre la plataforma
	foco.position = Vector3(0, 4.6, 0)
	foco.light_color = Color("FFA64D")
	foco.light_energy = 1.6
	foco.omni_range = 11.0
	vista.add_child(foco)
	var borde_luz := OmniLight3D.new()  # reflejo naranja del suelo
	borde_luz.position = Vector3(0, 0.3, 0)
	borde_luz.light_color = Color("F7A021")
	borde_luz.light_energy = 0.9
	borde_luz.omni_range = 5.5
	vista.add_child(borde_luz)
	_build_hangar(vista)
	_camera = Camera3D.new()
	_camera.fov = 36
	vista.add_child(_camera)
	_camera.position = Vector3(6.8, 2.9, -7.8)
	_camera.look_at(Vector3(0, 0.72, 0))
	_camera.h_offset = 1.3
	_turntable = Node3D.new()
	vista.add_child(_turntable)
	_rover = load("res://scenes/b/assets/models/rover.tscn").instantiate()
	_turntable.add_child(_rover)
	_drone = load("res://scenes/b/assets/models/drone.tscn").instantiate()
	_turntable.add_child(_drone)
	_drone.position = Vector3(-1.9, 1.5, 1.4)
	_companion = load("res://scenes/b/assets/models/companion.tscn").instantiate()
	_turntable.add_child(_companion)
	_companion.position = Vector3(-2.3, 0, -0.9)
	_hotspot_layer = Control.new()
	_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_hotspot_layer)


## Interior del hangar: muro curvo con costillas, ventana a Marte y plataforma con anillos luminosos.
func _build_hangar(vista: Node) -> void:
	var pared_mat := _material(Color("2A1A12"))
	pared_mat.cull_mode = BaseMaterial3D.CULL_FRONT  # se ve por dentro
	var muro := CylinderMesh.new()
	muro.top_radius = 10.5
	muro.bottom_radius = 10.5
	muro.height = 7.0
	muro.radial_segments = 40
	muro.rings = 1
	_add_mesh(vista, muro, pared_mat, Vector3(0, 3.4, 0))
	var techo := CylinderMesh.new()
	techo.top_radius = 10.5
	techo.bottom_radius = 10.5
	techo.height = 0.2
	techo.radial_segments = 40
	_add_mesh(vista, techo, _material(Color("120A06")), Vector3(0, 7.0, 0))
	var suelo := CylinderMesh.new()
	suelo.top_radius = 10.5
	suelo.bottom_radius = 10.5
	suelo.height = 0.2
	suelo.radial_segments = 40
	_add_mesh(vista, suelo, _material(Color("1A100B")), Vector3(0, -0.45, 0))
	# Costillas del muro.
	var costilla := BoxMesh.new()
	costilla.size = Vector3(0.55, 7.0, 0.7)
	var costilla_mat := _material(Color("4A3023"))
	for i in range(20):
		var a := i * TAU / 20.0
		_add_mesh(vista, costilla, costilla_mat, Vector3(cos(a), 0, sin(a)) * 10.1 + Vector3(0, 3.4, 0), Vector3(0, -a + PI / 2.0, 0))
	# Bandas de luz cálida a lo largo del muro.
	for y in [1.2, 5.6]:
		var banda := TorusMesh.new()
		banda.inner_radius = 10.0
		banda.outer_radius = 10.06
		banda.rings = 48
		banda.ring_segments = 4
		_add_mesh(vista, banda, _material(Color("F7A021"), 0.6), Vector3(0, y, 0)).scale = Vector3(1, 0.5, 1)
	# Ventana a Marte (hacia el fondo, a la derecha del rover).
	var adelante := Vector3(4.7, 0, -5.4).normalized() * -1.0
	var derecha := Vector3(-adelante.z, 0, adelante.x)
	var dir := (adelante * cos(deg_to_rad(28.0)) + derecha * sin(deg_to_rad(28.0))).normalized()
	var centro := dir * 9.7 + Vector3(0, 2.6, 0)
	var ventana := Node3D.new()
	ventana.position = centro
	vista.add_child(ventana)
	ventana.look_at_from_position(centro, Vector3(0, 2.6, 0), Vector3.UP)
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(7.2, 3.8)
	var foto_mat := StandardMaterial3D.new()
	foto_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foto_mat.albedo_texture = load("res://assets/menu/menu_fondo.jpg")
	foto_mat.albedo_color = Color(1.0, 0.92, 0.86)
	foto_mat.uv1_scale = Vector3(0.42, 0.5, 1)
	foto_mat.uv1_offset = Vector3(0.52, 0.34, 0)
	_add_mesh(ventana, cuadro, foto_mat, Vector3(0, 0, -0.12), Vector3(0, PI, 0))
	var marco_mat := _material(Color("6B4126"), 0.25)
	for lado in [[Vector3(0, 2.05, -0.1), Vector3(7.8, 0.3, 0.4)], [Vector3(0, -2.05, -0.1), Vector3(7.8, 0.3, 0.4)],
			[Vector3(-3.75, 0, -0.1), Vector3(0.3, 4.4, 0.4)], [Vector3(3.75, 0, -0.1), Vector3(0.3, 4.4, 0.4)]]:
		var caja := BoxMesh.new()
		caja.size = lado[1]
		_add_mesh(ventana, caja, marco_mat, lado[0])
	# Plataforma circular con anillos luminosos.
	var plataforma := CylinderMesh.new()
	plataforma.top_radius = 3.9
	plataforma.bottom_radius = 4.2
	plataforma.height = 0.4
	plataforma.radial_segments = 48
	_add_mesh(vista, plataforma, _material(Color("3A2A21")), Vector3(0, -0.2, 0))
	var escalon := CylinderMesh.new()
	escalon.top_radius = 3.4
	escalon.bottom_radius = 3.5
	escalon.height = 0.06
	escalon.radial_segments = 48
	_add_mesh(vista, escalon, _material(Color("4A372B")), Vector3(0, 0.02, 0))
	for r in [3.6, 3.0, 2.2]:
		var anillo := TorusMesh.new()
		anillo.inner_radius = r - 0.035
		anillo.outer_radius = r + 0.035
		anillo.rings = 56
		anillo.ring_segments = 5
		var n := _add_mesh(vista, anillo, _material(Color("F7A021"), 0.9 if r > 3.5 else 0.5), Vector3(0, 0.07, 0))
		n.scale = Vector3(1, 0.25, 1)


# ---------------------------------------------------------------- consejo de ingeniería

func _build_tip() -> void:
	var consejo := PanelContainer.new()
	consejo.add_theme_stylebox_override("panel", UI.box(0.0, 14, 0.9, 1, 14, 12, Color("B8742A")))
	var estilo := UI.box(0.0, 14, 0.4, 1, 14, 12, Color("B8742A"))
	estilo.bg_color = Color("120A06", 0.72)
	consejo.add_theme_stylebox_override("panel", estilo)
	consejo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(consejo, "tl", 24, 190, 172, 220)
	root.add_child(consejo)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	consejo.add_child(col)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 6)
	col.add_child(cab)
	cab.add_child(Icon.make("gear", 15, Color("F3E6D4")))
	var titulo := UI.label(cab, tr("WS_TIP_TITLE"), 12, Color("F3E6D4"))
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_text = UI.label(col, "", 11, TEXT_DIM)
	_tip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_text.custom_minimum_size = Vector2(140, 0)
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dibujo := Sketch.new()
	dibujo.custom_minimum_size = Vector2(140, 64)
	dibujo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dibujo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(dibujo)
	_refresh_tip()


func _refresh_tip() -> void:
	if is_instance_valid(_tip_text):
		_tip_text.text = tr("WS_TIP_" + category)


# ---------------------------------------------------------------- catálogo (carrusel)

func _build_catalog() -> void:
	var zona := Control.new()
	zona.anchor_top = 1.0
	zona.anchor_bottom = 1.0
	zona.anchor_left = 0.0
	zona.anchor_right = 1.0
	zona.offset_left = 24
	zona.offset_right = -(FICHA_ANCHO + MARGEN * 2.0 + 10.0)
	zona.offset_top = -244
	zona.offset_bottom = -52
	root.add_child(zona)
	var fondo := Panel.new()
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cuerpo := UI.box(0.0, 16, 0.25, 1, 0, 0, Color("B8742A"))
	cuerpo.bg_color = Color("0E0805", 0.62)
	fondo.add_theme_stylebox_override("panel", cuerpo)
	zona.add_child(fondo)
	var titulo := UI.label(zona, tr("WS_CATALOG").to_upper(), 11, Color("D8C3AC", 0.55))
	UI.display(titulo, 700, 2)
	titulo.anchor_right = 1.0
	titulo.offset_top = 8
	titulo.offset_bottom = 24
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip = ScrollContainer.new()
	_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.offset_left = 54
	_strip.offset_right = -54
	_strip.offset_top = 30
	_strip.offset_bottom = -22
	_strip.gui_input.connect(_on_strip_input)
	_strip.get_h_scroll_bar().value_changed.connect(func(_v: float): _update_dots())
	zona.add_child(_strip)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(CARD_GAP))
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_strip.add_child(_cards)
	_arrow_left = _arrow_button("‹", true)
	zona.add_child(_arrow_left)
	_arrow_right = _arrow_button("›", false)
	zona.add_child(_arrow_right)
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.anchor_left = 0.0
	_dots.anchor_right = 1.0
	_dots.anchor_top = 1.0
	_dots.anchor_bottom = 1.0
	_dots.offset_top = -18
	_dots.offset_bottom = -6
	zona.add_child(_dots)


func _arrow_button(texto: String, izquierda: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", Color("F3E6D4"))
	b.add_theme_stylebox_override("normal", UI.button_box(Color("1A100A", 0.9), Color("B8742A", 0.5), 1, 8, 0, 0, 0))
	b.add_theme_stylebox_override("hover", UI.button_box(Color("2E1A0C", 0.95), Color(ORANGE, 0.9), 1, 8, 0, 0, 0))
	b.add_theme_stylebox_override("pressed", UI.button_box(Color("0A0604", 0.95), ORANGE, 1, 8, 0, 0, 0))
	b.add_theme_stylebox_override("disabled", UI.button_box(Color("1A100A", 0.4), Color("B8742A", 0.15), 1, 8, 0, 0, 0))
	b.anchor_top = 0.5
	b.anchor_bottom = 0.5
	b.offset_top = -22
	b.offset_bottom = 28
	if izquierda:
		b.anchor_left = 0.0
		b.anchor_right = 0.0
		b.offset_left = 6
		b.offset_right = 42
	else:
		b.anchor_left = 1.0
		b.anchor_right = 1.0
		b.offset_left = -42
		b.offset_right = -6
	b.pressed.connect(func(): _scroll_strip(-1 if izquierda else 1))
	return b


func _scroll_strip(sentido: int) -> void:
	var paso := int((CARD_SIZE.x + CARD_GAP) * 3.0)
	var destino := clampi(_strip.scroll_horizontal + sentido * paso, 0, _max_scroll())
	create_tween().tween_property(_strip, "scroll_horizontal", destino, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _max_scroll() -> int:
	return maxi(0, int(_cards.get_combined_minimum_size().x - _strip.size.x))


func _on_strip_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN or e.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_strip.scroll_horizontal = clampi(_strip.scroll_horizontal + 120, 0, _max_scroll())
			_strip.accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP or e.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_strip.scroll_horizontal = clampi(_strip.scroll_horizontal - 120, 0, _max_scroll())
			_strip.accept_event()


func _update_arrows() -> void:
	if not is_instance_valid(_strip):
		return
	var cabe := _cards.get_combined_minimum_size().x <= _strip.size.x + 1.0
	_arrow_left.visible = not cabe
	_arrow_right.visible = not cabe
	if not cabe:
		_arrow_left.disabled = _strip.scroll_horizontal <= 0
		_arrow_right.disabled = _strip.scroll_horizontal >= _max_scroll() - 1
	_update_dots()


## Puntos de paginación: uno por «página» de tarjetas; el activo va en naranja.
func _update_dots() -> void:
	if not is_instance_valid(_dots):
		return
	var ancho := maxf(_strip.size.x, 1.0)
	var total := _cards.get_combined_minimum_size().x
	var paginas := maxi(1, int(ceil(total / ancho)))
	var actual := 0
	if paginas > 1 and _max_scroll() > 0:
		actual = clampi(int(round(float(_strip.scroll_horizontal) / float(_max_scroll()) * (paginas - 1))), 0, paginas - 1)
	if _dots.get_child_count() != paginas:
		for hijo in _dots.get_children():
			_dots.remove_child(hijo)
			hijo.queue_free()
		for i in range(paginas):
			var p := Panel.new()
			p.custom_minimum_size = Vector2(7, 7)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_dots.add_child(p)
	for i in range(_dots.get_child_count()):
		var punto := UI.box(1.0, 4, 0.0, 0, 0, 0)
		punto.bg_color = ORANGE if i == actual else Color("D8C3AC", 0.35)
		(_dots.get_child(i) as Panel).add_theme_stylebox_override("panel", punto)
	_dots.visible = paginas > 1


# ---------------------------------------------------------------- ficha de misión

func _build_summary() -> void:
	var panel := PanelContainer.new()
	var estilo := UI.box(0.0, 16, 0.4, 1, 20, 16, Color("B8742A"))
	estilo.bg_color = PANEL_BG
	panel.add_theme_stylebox_override("panel", estilo)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -(FICHA_ANCHO + MARGEN - 2.0)
	panel.offset_right = -(MARGEN - 2.0)
	panel.offset_top = MARGEN
	panel.offset_bottom = -MARGEN
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 10)
	cab.custom_minimum_size = Vector2(0, 32)
	col.add_child(cab)
	cab.add_child(Icon.make("info", 20, Color("F3E6D4")))
	var titulo := UI.label(cab, tr("WS_FICHA").to_upper(), 18)
	UI.display(titulo, 700, 0)
	var linea := ColorRect.new()
	linea.color = Color("B8742A", 0.3)
	linea.custom_minimum_size = Vector2(0, 1)
	col.add_child(linea)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.custom_minimum_size = Vector2(0, 120)
	col.add_child(desplazable)
	_summary_box = VBoxContainer.new()
	_summary_box.add_theme_constant_override("separation", 12)
	_summary_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desplazable.add_child(_summary_box)
	_action = Button.new()
	_action.theme_type_variation = "PrimaryButton"
	_action.custom_minimum_size = Vector2(0, 52)
	_action.text = tr("WS_VALIDATE").to_upper()
	_action.add_theme_font_size_override("font_size", 17)
	var fuerte := UI.display_font(700)
	if fuerte != null:
		_action.add_theme_font_override("font", fuerte)
	_action.add_theme_stylebox_override("normal", UI.button_box(Color("F7A021"), Color("FFD08A", 0.8), 1, 10, 12, 8, 6))
	_action.add_theme_stylebox_override("hover", UI.button_box(Color("FFB53F"), Color("FFE2B0", 0.9), 1, 10, 12, 8, 8))
	_action.add_theme_stylebox_override("pressed", UI.button_box(Color("D9860F"), Color("FFD08A", 0.9), 2, 10, 12, 8, 0))
	var cohete := Icon.make("rocket", 22, Color("2A1A10"))
	cohete.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	cohete.offset_left = 28
	cohete.offset_right = 50
	cohete.offset_top = -11
	cohete.offset_bottom = 11
	_action.add_child(cohete)
	col.add_child(_action)
	_action.pressed.connect(_on_action)
	_hint = UI.label(col, tr("WS_HINT"), 11, TEXT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


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
	_update_steps(taller.get("selection", {}))
	_update_preview(taller.get("selection", {}))
	var listo: bool = validated and taller.get("valid", false)
	_action.text = "      " + (tr("WS_START") if listo else tr("WS_VALIDATE")).to_upper()
	_hint.text = tr("WS_HINT_READY") if listo else tr("WS_HINT")
	call_deferred("_update_arrows")


func _selected_ids(taller: Dictionary) -> Array:
	var ids: Array = []
	for cat in taller.get("selection", {}):
		ids.append_array(taller["selection"][cat])
	return ids


func _update_steps(seleccion: Dictionary) -> void:
	for id in ORDER:
		var piezas: Array = seleccion.get(id, [])
		var tiene := not piezas.is_empty()
		for nodo in _step_checks[id]:
			nodo.visible = tiene
		var nombres: Array[String] = []
		for pid in piezas:
			nombres.append(tr(str(_names.get(pid, pid))))
		(_category_buttons[id] as Button).tooltip_text = tr(CATEGORY_KEYS[id]) + ("" if nombres.is_empty() else ": " + ", ".join(nombres))


func _rebuild_cards(taller: Dictionary) -> void:
	for hijo in _cards.get_children():
		_cards.remove_child(hijo)
		hijo.queue_free()
	var elegidas: Array = taller.get("selection", {}).get(category, [])
	for cat in taller.get("categories", []):
		if str(cat["id"]) != category:
			continue
		for part in cat["parts"]:
			_cards.add_child(_card(part, elegidas.has(part["id"])))
	_strip.scroll_horizontal = 0


func _card(part: Dictionary, elegida: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	var motivo := str(part.get("reason", ""))
	var puede := bool(part.get("available", true)) or motivo == "CATEGORY_FULL"
	b.disabled = not puede and not elegida
	var relleno := Color("2A170B", 0.96) if elegida else CARD_BG
	var borde := ORANGE if elegida else Color("B8742A", 0.4)
	var normal := UI.button_box(relleno, borde, 2 if elegida else 1, 12, 8, 8, 0)
	if elegida:
		normal.shadow_size = 10
		normal.shadow_offset = Vector2.ZERO
		normal.shadow_color = Color(ORANGE, 0.45)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", UI.button_box(Color("2E1A0C", 0.96), Color(ORANGE, 1.0 if elegida else 0.8), 2 if elegida else 1, 12, 8, 8, 0))
	b.add_theme_stylebox_override("pressed", UI.button_box(Color("0A0604", 0.96), ORANGE, 2, 12, 8, 8, 0))
	b.add_theme_stylebox_override("disabled", UI.button_box(Color("120A06", 0.6), Color("B8742A", 0.15), 1, 12, 8, 8, 0))
	b.clip_contents = false
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 6
	col.offset_top = 8
	col.offset_right = -6
	col.offset_bottom = -8
	b.add_child(col)
	var nombre := UI.label(col, tr(str(part.get("name_key", ""))), 12, Color("F3E6D4") if puede or elegida else TEXT_DIM)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nombre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nombre.custom_minimum_size = Vector2(0, 32)
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var centro := CenterContainer.new()
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(centro)
	var icono := Icon.make(PART_ICONS.get(str(part.get("id", "")), CATEGORY_ICONS[category]), 40, ORANGE if elegida else Color("D8C3AC", 0.8))
	centro.add_child(icono)
	var chips := HFlowContainer.new()
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 3)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)
	if part.get("pending", false):
		chips.add_child(_chip(tr("WS_PENDING"), ORANGE))
	else:
		for par in [["cost_musd", "WS_COST"], ["mass_kg", "WS_MASS"], ["capacity_kg", "WS_CAPACITY"], ["power_w", "WS_POWER"]]:
			var valor = part.get(par[0])
			if valor != null:
				chips.add_child(_chip(tr(par[1]) % int(valor), Color("F3E6D4", 0.9)))
	if not puede and not elegida and not motivo.is_empty():
		b.tooltip_text = tr(motivo)
	b.pressed.connect(_on_card.bind(part, elegida))
	return b


func _chip(texto: String, tono: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var estilo := UI.box(0.0, 8, 0.0, 0, 6, 1)
	estilo.bg_color = Color("3A2616", 0.9)
	chip.add_theme_stylebox_override("panel", estilo)
	var l := UI.label(chip, texto, 10, tono)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return chip


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
		_summary_box.remove_child(hijo)
		hijo.queue_free()
	var totales: Dictionary = taller.get("totals", {})
	var costo := float(totales.get("cost_musd", 0))
	var presupuesto := float(totales.get("budget_musd", 700))
	var masa := float(totales.get("mass_kg", 0))
	var capacidad := float(totales.get("capacity_kg", 0))
	var sobre_costo := costo > presupuesto
	var sobre_masa := capacidad > 0.0 and masa > capacidad
	# Presupuesto: anillo y leyenda.
	_section(tr("WS_BUDGET"), "coin")
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	_summary_box.add_child(fila)
	var anillo := Ring.new()
	anillo.custom_minimum_size = Vector2(132, 132)
	anillo.value = costo / maxf(presupuesto, 1.0)
	anillo.over = sobre_costo
	fila.add_child(anillo)
	var centro := VBoxContainer.new()
	centro.alignment = BoxContainer.ALIGNMENT_CENTER
	centro.add_theme_constant_override("separation", 0)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	anillo.add_child(centro)
	var cifra := UI.label(centro, str(int(costo)), 28, UI.CORAL if sobre_costo else Color("F3E6D4"))
	UI.display(cifra, 700, 0)
	cifra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var total := UI.label(centro, "/ %d" % int(presupuesto), 13, Color("F3E6D4", 0.85))
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var unidad := UI.label(centro, "M USD", 11, TEXT_DIM)
	unidad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var leyenda := VBoxContainer.new()
	leyenda.alignment = BoxContainer.ALIGNMENT_CENTER
	leyenda.add_theme_constant_override("separation", 12)
	leyenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(leyenda)
	_legend(leyenda, tr("WS_SPENT"), "%d M USD" % int(costo), UI.CORAL if sobre_costo else ORANGE)
	if sobre_costo:
		_legend(leyenda, tr("WS_OVER"), "%d M USD" % int(costo - presupuesto), UI.CORAL)
	else:
		_legend(leyenda, tr("WS_AVAILABLE"), "%d M USD" % int(presupuesto - costo), Color("8A7566"))
	# Masa.
	var cab_masa := HBoxContainer.new()
	cab_masa.add_theme_constant_override("separation", 8)
	_summary_box.add_child(cab_masa)
	cab_masa.add_child(Icon.make("weight", 16, Color("F3E6D4")))
	var etiqueta_masa := UI.label(cab_masa, tr("WS_MASS_TOTAL").to_upper(), 13, Color("F3E6D4"))
	UI.display(etiqueta_masa, 700, 0)
	etiqueta_masa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.label(cab_masa, "%d / %d kg" % [int(masa), int(capacidad)], 14, UI.CORAL if sobre_masa else Color("F3E6D4"))
	var barra := ProgressBar.new()
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 13)
	barra.max_value = maxf(capacidad, 1.0)
	barra.value = minf(masa, maxf(capacidad, 1.0))
	var relleno := UI.box(0.95, 5, 0.0, 0, 0, 0)
	relleno.bg_color = UI.CORAL if sobre_masa else ORANGE
	barra.add_theme_stylebox_override("fill", relleno)
	var fondo_barra := UI.box(0.5, 5, 0.0, 0, 0, 0)
	fondo_barra.bg_color = Color("3A2A20", 0.8)
	barra.add_theme_stylebox_override("background", fondo_barra)
	_summary_box.add_child(barra)
	var marcas := HBoxContainer.new()
	_summary_box.add_child(marcas)
	var m0 := UI.label(marcas, "0", 11, TEXT_DIM)
	m0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var m1 := UI.label(marcas, str(int(capacidad / 2.0)), 11, TEXT_DIM)
	m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var m2 := UI.label(marcas, str(int(capacidad)), 11, TEXT_DIM)
	m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Potencia.
	_section(tr("WS_POWER_LABEL"), "bolt")
	var valor_potencia := UI.label(_summary_box, tr("WS_POWER") % int(totales.get("power_w", 0)), 26, ORANGE)
	UI.display(valor_potencia, 700, 0)
	# Validación.
	_section(tr("WS_VALIDATION"), "list")
	var hay_cohete := not (taller.get("selection", {}).get("cohetes", []) as Array).is_empty()
	if hay_cohete and not sobre_costo:
		_check_line(tr("WS_OK_BUDGET"), "check_circle", UI.TEAL)
	if hay_cohete and not sobre_masa:
		_check_line(tr("WS_OK_MASS"), "check_circle", UI.TEAL)
	for codigo in taller.get("validation", []):
		_check_line(_message(str(codigo)), "critical", UI.CORAL)
	var pendientes: Array = []
	for codigo in taller.get("notices", []):
		if str(codigo).begins_with("PENDING_DATA:"):
			pendientes.append(str(codigo))
		else:
			_check_line(_message(str(codigo)), "warning", ORANGE)
	if pendientes.size() == 1:
		_check_line(_message(pendientes[0]), "warning", ORANGE)
	elif pendientes.size() > 1:
		var nombres: Array[String] = []
		for codigo in pendientes:
			nombres.append(tr(str(_names.get(str(codigo).split(":")[1], str(codigo).split(":")[1]))))
		var linea := _check_line(tr("WS_PENDING_MANY") % pendientes.size(), "warning", ORANGE)
		linea.tooltip_text = ", ".join(nombres)
	if taller.get("valid", false):
		_check_line(tr("WS_VALID_OK"), "check_circle", UI.TEAL)


func _section(titulo: String, icono: String) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_summary_box.add_child(fila)
	fila.add_child(Icon.make(icono, 16, Color("F3E6D4")))
	var l := UI.label(fila, titulo.to_upper(), 13, Color("F3E6D4"))
	UI.display(l, 700, 0)


func _legend(padre: Control, titulo: String, valor: String, tono: Color) -> void:
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 0)
	padre.add_child(caja)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	caja.add_child(fila)
	var punto := Panel.new()
	punto.custom_minimum_size = Vector2(10, 10)
	punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var estilo := UI.box(1.0, 5, 0.0, 0, 0, 0)
	estilo.bg_color = tono
	punto.add_theme_stylebox_override("panel", estilo)
	fila.add_child(punto)
	UI.label(fila, titulo, 14, Color("F3E6D4"))
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 18)
	caja.add_child(margen)
	UI.label(margen, valor, 13, TEXT_DIM)


func _check_line(texto: String, icono: String, tono: Color) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	_summary_box.add_child(fila)
	var marca := Icon.make(icono, 18, tono)
	marca.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	fila.add_child(marca)
	var l := UI.label(fila, texto, 13, Color("F3E6D4", 0.95))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return fila


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
	_sync_hotspots(ids)


## Un punto naranja luminoso por cada pieza elegida que tenga un lugar visible en el rover (o el dron y el compañero).
func _sync_hotspots(ids: Array) -> void:
	var querido: Array[String] = []
	for id in ids:
		if PART_NODES.has(id) or id == "dron" or id == "companero":
			querido.append(str(id))
	for id in _hotspots.keys():
		if not querido.has(id):
			_hotspots[id].queue_free()
			_hotspots.erase(id)
	for id in querido:
		if _hotspots.has(id):
			continue
		var punto := Panel.new()
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		punto.custom_minimum_size = Vector2(22, 22)
		punto.size = Vector2(22, 22)
		punto.pivot_offset = Vector2(11, 11)
		var estilo := UI.box(1.0, 11, 0.85, 3, 0, 0, Color("FFD9A0"))
		estilo.bg_color = ORANGE
		estilo.shadow_size = 14
		estilo.shadow_offset = Vector2.ZERO
		estilo.shadow_color = Color(ORANGE, 0.6)
		punto.add_theme_stylebox_override("panel", estilo)
		_hotspot_layer.add_child(punto)
		_hotspots[id] = punto


func _part_point(id: String) -> Variant:
	var nodo: Node = null
	if id == "dron":
		nodo = _drone
	elif id == "companero":
		nodo = _companion
	else:
		nodo = _rover.find_child(str(PART_NODES[id]), true, false)
	if nodo is Node3D and (nodo as Node3D).is_inside_tree():
		return (nodo as Node3D).global_position + Vector3(0, 0.12, 0)
	return null


func _update_hotspots() -> void:
	if not is_instance_valid(_camera) or _hotspots.is_empty():
		return
	var pulso := 1.0 + 0.16 * sin(_clock * 4.0)
	for id in _hotspots:
		var punto: Panel = _hotspots[id]
		var mundo = _part_point(id)
		if mundo == null or _camera.is_position_behind(mundo):
			punto.visible = false
			continue
		punto.visible = true
		punto.position = _camera.unproject_position(mundo) - punto.size / 2.0
		punto.scale = Vector2(pulso, pulso)


func show_notice(key: String) -> void:
	if not is_instance_valid(_toast_label):
		return
	_toast_label.text = tr(key)
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.5
	_toast.visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	if is_instance_valid(_turntable):
		_turntable.rotation.y = sin(_clock * 0.45) * 0.55  # vaivén suave: se ven ambos lados sin perder el mejor ángulo
	_update_hotspots()
	if is_instance_valid(_toast) and _toast.visible and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_toast.visible = false
