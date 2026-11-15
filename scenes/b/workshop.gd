extends CanvasLayer
## Taller de diseño de misión: «Hangar de ensamblaje».
## Solo presenta el bloque "workshop" del snapshot que entrega la simulación y envía órdenes
## design_add / design_remove / design_validate / design_start. No calcula costos, masas ni validez.
##
## Composición (concepto A): el rover sobre su plataforma ocupa toda la pantalla dentro de un hangar con ventana a Marte;
## encima, los pasos de categoría, el consejo de ingeniería, el catálogo en carrusel y la «Ficha de misión» a la derecha.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")
const RoverNasa := preload("res://scenes/b/rover_nasa.gd")

signal command(command: String, payload: Dictionary)
signal options_requested

## El cohete NO se elige aquí: se elige antes, en la plataforma de lanzamiento de la Tierra
## (scenes/b/launch_pad.gd). El hangar solo monta lo que va dentro del cohete ya elegido.
const ORDER: Array[String] = ["trayectoria", "chasis", "energia", "comunicaciones", "extras"]
const CATEGORY_KEYS := {"cohetes": "CAT_COHETES", "trayectoria": "CAT_TRAYECTORIA", "chasis": "CAT_CHASIS", "energia": "CAT_ENERGIA",
	"comunicaciones": "CAT_COMUNICACIONES", "extras": "CAT_EXTRAS"}
const CATEGORY_ICONS := {"cohetes": "rocket", "trayectoria": "goal", "chasis": "chassis", "energia": "bolt", "comunicaciones": "antenna", "extras": "flask"}
## Icono de cada pieza (las que no aparecen usan el de su categoría).
const PART_ICONS := {"cohete_ligero": "rocket", "cohete_medio": "rocket", "cohete_pesado": "rocket",
	"cohete_super": "rocket", "chasis_base": "chassis", "panel_solar": "solar",
	"mmrtg": "atom", "antena_directa": "antenna", "antena_rele": "link", "espectrometro": "spectrometer", "taladro": "drill",
	"camara": "camera", "meteo": "meteo", "radar": "radar", "bateria": "battery", "dron": "drone", "companero": "companion"}
## Nodo del rover sobre el que se marca cada pieza elegida.
const PART_NODES := {"panel_solar": "solar", "mmrtg": "rtg", "taladro": "drill", "radar": "radar", "espectrometro": "spectrometer",
	"meteo": "meteo", "camara": "head", "antena_directa": "HighGain", "antena_rele": "HighGain"}
## Catálogo en barra lateral: una fila por pieza, para que la lista se lea de un vistazo.
const SIDEBAR_ANCHO := 312.0
const CARD_SIZE := Vector2(0, 68)
const CARD_GAP := 8.0
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
var consejo_panel: Control  ## el cuadro «Consejo de ingeniería» (en red se oculta para dejar sitio al panel de rol)
var snapshot: Dictionary = {}
var category := "trayectoria"
var validated := false
var _basicas_puestas := false  ## ya se pidieron las herramientas básicas de este cohete

var _signature := ""
var _category_buttons: Dictionary = {}
var _step_names: Dictionary = {}
var _step_checks: Dictionary = {}
var _step_labels: Dictionary = {}
var _cards: VBoxContainer
var _strip: ScrollContainer
var _summary_box: VBoxContainer
var _action: Button
var _hint: Label
var _tip_text: Label
var _cambiar_cohete: Button
var _fila_opciones: HBoxContainer  ## «Opciones» y «Código», bajo el catálogo
var _recomendado: Button  ## «Diseño recomendado», sobre el catálogo
var _confirmacion: PanelContainer  ## «¿Despegar sin todo?» cuando falta un instrumento clave
var _toast: PanelContainer
var _toast_label: Label
var _toast_until := 0.0
var _turntable: Node3D
var _camera: Camera3D
var _fondo_material: StandardMaterial3D  ## paisaje que se ve por el portón del hangar (cambia con el destino)
var _rover: Node3D
var _drone: Node3D
var _companion: Node3D
var _hotspot_layer: Control
var _hotspots: Dictionary = {}
var _clock := 0.0
var _camera_home := Vector3(6.8, 2.9, -7.8)
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
	_frame(centro, SIDEBAR_ANCHO + MARGEN * 2.0, 26, FICHA_ANCHO + MARGEN * 2.0 + 10.0, 0)
	centro.anchor_bottom = 0.0
	centro.offset_bottom = 54
	root.add_child(centro)
	# Volver a la plataforma de la Tierra: quita el cohete y la elección se vuelve a mostrar.
	_cambiar_cohete = Button.new()
	_cambiar_cohete.focus_mode = Control.FOCUS_NONE
	_cambiar_cohete.text = tr("WS_CHANGE_ROCKET")
	_cambiar_cohete.add_theme_font_size_override("font_size", UI.FONT_MIN)
	_cambiar_cohete.pressed.connect(_on_cambiar_cohete)
	UI.place(_cambiar_cohete, "tl", 76, 70, 196, 32)
	root.add_child(_cambiar_cohete)
	# Diseño recomendado para este destino (content/parts.json › recomendada): lo vuelve a poner si se cambió.
	_recomendado = Button.new()
	_recomendado.focus_mode = Control.FOCUS_NONE
	_recomendado.text = tr("WS_RECOMMENDED")
	_recomendado.tooltip_text = tr("WS_RECOMMENDED_TIP")
	_recomendado.add_theme_font_size_override("font_size", UI.FONT_MIN)
	_recomendado.pressed.connect(func() -> void: poner_recomendado(snapshot.get("workshop", {})))
	UI.place(_recomendado, "tl", MARGEN, 112, SIDEBAR_ANCHO, 32)
	root.add_child(_recomendado)


## Se crea al final para quedar por encima de todo lo demás. «Opciones» y «Código» van en una fila
## anclada abajo a la izquierda, del ancho del catálogo y con separación fija: así no se montan uno
## sobre otro aunque el texto (o el idioma) sea más largo.
func _build_options() -> void:
	_fila_opciones = HBoxContainer.new()
	_fila_opciones.add_theme_constant_override("separation", 8)
	UI.place(_fila_opciones, "bl", MARGEN, 10, SIDEBAR_ANCHO, 28)
	root.add_child(_fila_opciones)
	var opciones := Button.new()
	opciones.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opciones.focus_mode = Control.FOCUS_NONE
	opciones.tooltip_text = tr("OPTIONS")
	opciones.text = "      " + tr("WS_HELP").to_upper()
	opciones.add_theme_font_size_override("font_size", 13)
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
	_fila_opciones.add_child(opciones)
	opciones.pressed.connect(func(): options_requested.emit())
	var codigo := Button.new()
	codigo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	codigo.focus_mode = Control.FOCUS_NONE
	codigo.text = tr("WS_CODE").to_upper()
	codigo.tooltip_text = tr("WS_CODE_TIP")
	codigo.add_theme_font_size_override("font_size", 13)
	codigo.add_theme_color_override("font_color", TEXT_DIM)
	codigo.add_theme_color_override("font_hover_color", ORANGE)
	codigo.add_theme_stylebox_override("normal", UI.button_box(Color("120A06", 0.85), Color(ORANGE, 0.35), 1, 14, 12, 4, 0))
	codigo.add_theme_stylebox_override("hover", UI.button_box(Color("2A170B", 0.95), Color(ORANGE, 0.9), 1, 14, 12, 4, 0))
	_fila_opciones.add_child(codigo)
	codigo.pressed.connect(_abrir_codigo)


## Compartir y comparar diseños: copia el código de este diseño o pega el de otro equipo.
func _abrir_codigo() -> void:
	var Registro := preload("res://scenes/menu/registro.gd")
	var taller: Dictionary = snapshot.get("workshop", {})
	var capa := Control.new()
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(capa)
	var tapa := ColorRect.new()
	tapa.color = Color(0.03, 0.02, 0.02, 0.7)
	tapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	capa.add_child(tapa)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.97, 14, 0.35, 1, 26, 20, UI.AMBER))
	UI.place(caja, "c", 0, 0, 560, 0)
	capa.add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	caja.add_child(col)
	var titulo := UI.label(col, tr("WS_CODE_TITLE"), 22, UI.CREAM)
	UI.display(titulo, 700, 1)
	var texto := UI.label(col, tr("WS_CODE_TEXT"), 13, Color(UI.CREAM, 0.8))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 500
	var mio := Registro.codigo(taller.get("selection", {}), Destino.id)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	col.add_child(fila)
	var propio := UI.label(fila, tr("DESIGN_CODE") % mio, 15, UI.AMBER)
	propio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var copiar := Button.new()
	copiar.text = tr("COPY")
	copiar.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(mio)
		copiar.text = tr("COPIED"))
	fila.add_child(copiar)
	var entrada := LineEdit.new()
	entrada.placeholder_text = "GAIA-M-..."
	entrada.custom_minimum_size = Vector2(500, 40)
	col.add_child(entrada)
	var aviso := UI.label(col, "", 12, UI.WARN)
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_theme_constant_override("separation", 8)
	col.add_child(pie)
	var cerrar := Button.new()
	cerrar.text = tr("GNG_BACK")
	cerrar.pressed.connect(func() -> void: capa.queue_free())
	pie.add_child(cerrar)
	var aplicar := Button.new()
	aplicar.theme_type_variation = "PrimaryButton"
	aplicar.text = tr("WS_CODE_APPLY")
	pie.add_child(aplicar)
	aplicar.pressed.connect(func() -> void:
		var leido := Registro.leer_codigo(entrada.text)
		if leido.is_empty():
			aviso.text = tr("WS_CODE_BAD")
			return
		if str(leido["destino"]) != Destino.id:
			aviso.text = tr("WS_CODE_OTHER")
			return
		validated = false
		for categoria in taller.get("selection", {}):
			for id in (taller["selection"][categoria] as Array).duplicate():
				command.emit("design_remove", {"part_id": id})
		for id in leido["piezas"]:
			command.emit("design_add", {"part_id": id})
		capa.queue_free())
	entrada.grab_focus.call_deferred()


# ---------------------------------------------------------------- pasos de categoría

func _build_stepper() -> void:
	var zona := Control.new()
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame(zona, SIDEBAR_ANCHO + MARGEN * 2.0, 62, FICHA_ANCHO + MARGEN * 2.0 + 10.0, 0)
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
			puntos.custom_minimum_size = Vector2(16, 66)
			puntos.mouse_filter = Control.MOUSE_FILTER_IGNORE
			fila.add_child(puntos)
		var paso := VBoxContainer.new()
		paso.add_theme_constant_override("separation", 6)
		paso.custom_minimum_size = Vector2(88, 0)
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
		var nombre := UI.label(paso, tr(CATEGORY_KEYS[id]).to_upper(), 13, Color("F3E6D4"))
		UI.display(nombre, 700, 0)
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # COMUNICACIONES cabe en dos líneas
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


## Quita el cohete elegido. Al quedarse la categoría vacía, la plataforma de la Tierra vuelve a
## tomar el relevo (ver mission_view.gd) y se puede elegir otro.
func _on_cambiar_cohete() -> void:
	validated = false
	for id in (snapshot.get("workshop", {}).get("selection", {}).get("cohetes", []) as Array).duplicate():
		command.emit("design_remove", {"part_id": str(id)})


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
	entorno.fog_density = 0.01
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
	_rover = RoverNasa.crear()  # el Perseverance real de la NASA a escala 1:1 (o el rover de bloques si falta el modelo)
	if _rover == null:
		_rover = load("res://scenes/b/assets/models/rover.tscn").instantiate()
	_turntable.add_child(_rover)
	_drone = Node3D.new()  # Ingenuity real, 1:1 (0,5 m de alto): junto al rover se ve pequeño, como es
	_turntable.add_child(_drone)
	if ResourceLoader.exists("res://assets/nasa/modelos/ingenuity.glb"):
		_drone.add_child((load("res://assets/nasa/modelos/ingenuity.glb") as PackedScene).instantiate())
	else:
		_drone.add_child(load("res://scenes/b/assets/models/drone.tscn").instantiate())
		_drone.scale = Vector3.ONE * 0.45
	_drone.position = Vector3(-2.6, 1.0, 1.6)
	_companion = load("res://scenes/b/assets/models/companion.tscn").instantiate()
	_turntable.add_child(_companion)
	_companion.scale = Vector3.ONE * 0.8
	_companion.position = Vector3(-3.2, 0, -1.2)
	_hotspot_layer = Control.new()
	_hotspot_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotspot_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_hotspot_layer)


## Paisaje del portón según el destino. Marte: la ilustración de la pantalla de carga (IA, ver ARTE_Y_LICENCIAS.md).
## Luna: foto real de la NASA desde Orion (horizonte gris y la Tierra en el cielo; fuente en docs/DATOS_NASA.md).
const FONDO_MARTE := "res://assets/menu/pantalla_carga.jpg"
const FONDO_LUNA := "res://assets/nasa/luna_tierra.jpg"


## Interior del hangar: muro curvo con costillas, portón abierto al destino y plataforma con anillos luminosos.
func _build_hangar(vista: Node) -> void:
	var luna := Destino.es_luna()
	var pared_mat := _material(Color("2A1A12"))
	pared_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible por dentro
	# Dirección del portón (hacia el fondo, a la derecha del rover) y hueco que deja en el muro.
	var adelante := Vector3(6.8, 0, -7.8).normalized() * -1.0
	var derecha := Vector3(-adelante.z, 0, adelante.x)
	var dir := (adelante * cos(deg_to_rad(16.0)) + derecha * sin(deg_to_rad(16.0))).normalized()
	var ang_hueco := atan2(dir.z, dir.x)
	var medio_hueco := 0.37
	_arco(vista, 15.0, -0.4, 10.0, pared_mat, ang_hueco, medio_hueco)
	var techo := CylinderMesh.new()
	techo.top_radius = 15.0
	techo.bottom_radius = 15.0
	techo.height = 0.2
	techo.radial_segments = 40
	_add_mesh(vista, techo, _material(Color("120A06")), Vector3(0, 10.0, 0))
	var suelo := CylinderMesh.new()
	suelo.top_radius = 15.0
	suelo.bottom_radius = 15.0
	suelo.height = 0.2
	suelo.radial_segments = 40
	_add_mesh(vista, suelo, _material(Color("1A100B")), Vector3(0, -0.45, 0))
	# Costillas del muro.
	var costilla := BoxMesh.new()
	costilla.size = Vector3(0.5, 10.0, 0.8)
	var costilla_mat := _material(Color("4A3023"))
	for i in range(18):
		var a := i * TAU / 18.0
		if absf(angle_difference(a, ang_hueco)) < medio_hueco + 0.12:
			continue
		_add_mesh(vista, costilla, costilla_mat, Vector3(cos(a), 0, sin(a)) * 14.5 + Vector3(0, 4.9, 0), Vector3(0, -a + PI / 2.0, 0))
	# Bandas de luz cálida a lo largo del muro (interrumpidas en el portón).
	var luz_mat := _material(Color("F7A021"), 0.7)
	luz_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for y in [1.7, 8.0]:
		_arco(vista, 14.85, y, y + 0.1, luz_mat, ang_hueco, medio_hueco)
	# Portón del hangar abierto al paisaje del destino (hacia el fondo, a la derecha del rover). Es una abertura con
	# profundidad: túnel de salida, suelo que continúa afuera, el paisaje lejos y hojas del portón recogidas.
	var centro := dir * 15.0
	var porton := Node3D.new()
	vista.add_child(porton)
	porton.look_at_from_position(centro, Vector3(0, 0, 0), Vector3.UP)  # -Z mira al centro del hangar; +Z es «afuera»
	var metal := _material(Color("5B4535"))
	var oscuro := _material(Color("1A100B"))
	var interior := _material(Color("2A1B13"))
	var ancho := 8.4
	var alto := 5.4
	var fondo_z := 3.6  # profundidad del túnel de salida
	# Paisaje lejano (más grande y alejado: la cámara se mueve un poco y se nota la profundidad).
	var cuadro := QuadMesh.new()
	cuadro.size = Vector2(46, 25.9)
	var foto_mat := StandardMaterial3D.new()
	foto_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foto_mat.albedo_texture = load(FONDO_LUNA if luna else FONDO_MARTE)
	if luna:
		# Foto de 3:2 en un cuadro de 16:9: todo el ancho, sin deformar, con la Tierra a la vista.
		foto_mat.uv1_scale = Vector3(1.0, 0.845, 1)
		foto_mat.uv1_offset = Vector3(0.0, 0.08, 0)
	else:
		foto_mat.albedo_color = Color(1.0, 0.88, 0.8)
		foto_mat.uv1_scale = Vector3(0.9, 0.86, 1)
		foto_mat.uv1_offset = Vector3(0.05, 0.02, 0)
	_fondo_material = foto_mat
	# En la Luna el cuadro baja para que el horizonte y la Tierra queden dentro del hueco del portón.
	_add_mesh(porton, cuadro, foto_mat, Vector3(0, 4.0 if luna else 8.0, 26.0), Vector3(0, PI, 0))
	# Suelo exterior que enlaza con el del hangar (gris de regolito en la Luna).
	var terreno := BoxMesh.new()
	terreno.size = Vector3(60, 0.2, 40)
	var terreno_mat := _material(Destino.color(Color("6B3A25")))
	_add_mesh(porton, terreno, terreno_mat, Vector3(0, -0.1, 20.0))
	# Túnel de salida: paredes, techo y suelo con vetas de luz.
	var pared := BoxMesh.new()
	pared.size = Vector3(0.5, alto, fondo_z)
	for lado in [-1.0, 1.0]:
		_add_mesh(porton, pared, interior, Vector3(lado * (ancho / 2.0 + 0.1), alto / 2.0, fondo_z / 2.0 - 0.2))
	var techo_t := BoxMesh.new()
	techo_t.size = Vector3(ancho + 1.2, 0.5, fondo_z)
	_add_mesh(porton, techo_t, interior, Vector3(0, alto + 0.1, fondo_z / 2.0 - 0.2))
	var suelo_t := BoxMesh.new()
	suelo_t.size = Vector3(ancho, 0.12, fondo_z + 1.0)
	_add_mesh(porton, suelo_t, _material(Color("3B2A20")), Vector3(0, -0.04, fondo_z / 2.0))
	# Marco del portón (cara interior del hangar).
	var dintel := BoxMesh.new()
	dintel.size = Vector3(ancho + 2.2, 1.0, 1.1)
	_add_mesh(porton, dintel, metal, Vector3(0, alto + 0.45, -0.15))
	for lado in [-1.0, 1.0]:
		var poste := BoxMesh.new()
		poste.size = Vector3(1.0, alto + 1.0, 1.1)
		_add_mesh(porton, poste, metal, Vector3(lado * (ancho / 2.0 + 0.6), (alto + 1.0) / 2.0 - 0.05, -0.15))
	# Franjas de aviso (naranja y negro) en el dintel.
	var franja := BoxMesh.new()
	franja.size = Vector3(0.9, 0.3, 0.12)
	for i in range(11):
		_add_mesh(porton, franja, _material(Color("F7A021"), 0.6) if i % 2 == 0 else oscuro, Vector3(-4.8 + i * 0.96, alto + 0.55, -0.74))
	# Hojas del portón recogidas contra los postes, con nervaduras.
	for lado in [-1.0, 1.0]:
		var hoja := BoxMesh.new()
		hoja.size = Vector3(1.6, alto, 0.4)
		_add_mesh(porton, hoja, metal, Vector3(lado * (ancho / 2.0 - 0.7), alto / 2.0, -0.45))
		for k in range(5):
			var nervio := BoxMesh.new()
			nervio.size = Vector3(1.6, 0.1, 0.1)
			_add_mesh(porton, nervio, oscuro, Vector3(lado * (ancho / 2.0 - 0.7), 0.8 + k * 1.0, -0.72))
	# Luces de aviso y reflejo cálido que sale por la abertura hacia el suelo del hangar.
	var luz_aviso := SphereMesh.new()
	luz_aviso.radius = 0.22
	luz_aviso.height = 0.44
	for lado in [-1.0, 1.0]:
		_add_mesh(porton, luz_aviso, _material(Color("FF8A1F"), 2.4), Vector3(lado * (ancho / 2.0 + 0.6), alto + 1.2, -0.75))
	var sol := OmniLight3D.new()
	sol.light_color = Color("DCE6F5") if luna else Color("FFB070")  # luz del Sol sin atmósfera en la Luna
	sol.light_energy = 1.8
	sol.omni_range = 9.0
	sol.position = Vector3(0, 2.4, -1.5)
	porton.add_child(sol)
	var derrame := QuadMesh.new()
	derrame.size = Vector2(ancho * 0.9, 6.0)
	var derrame_mat := StandardMaterial3D.new()
	derrame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	derrame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	derrame_mat.albedo_color = Color(1.0, 0.6, 0.25, 0.22)
	derrame_mat.no_depth_test = false
	_add_mesh(porton, derrame, derrame_mat, Vector3(0, 0.03, -3.4), Vector3(-PI / 2.0, 0, 0))
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
	# A la derecha de la barra lateral: antes estaba arriba a la izquierda, donde ahora va el catálogo.
	UI.place(consejo, "bl", SIDEBAR_ANCHO + MARGEN * 2.0, 24, 236, 196)
	root.add_child(consejo)
	consejo_panel = consejo
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
	_tip_text.custom_minimum_size = Vector2(164, 0)
	_tip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dibujo := Sketch.new()
	dibujo.custom_minimum_size = Vector2(164, 44)
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
	zona.anchor_top = 0.0
	zona.anchor_bottom = 1.0
	zona.anchor_left = 0.0
	zona.anchor_right = 0.0
	zona.offset_left = MARGEN
	zona.offset_right = MARGEN + SIDEBAR_ANCHO
	zona.offset_top = 152  # debajo de «Diseño recomendado»
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
	_strip.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.offset_left = 10
	_strip.offset_right = -10
	_strip.offset_top = 30
	_strip.offset_bottom = -12
	zona.add_child(_strip)
	_cards = VBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(CARD_GAP))
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.add_child(_cards)



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
	_equipar_basicas(taller)
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


## El rover entra al hangar con las herramientas básicas ya puestas (taladro y cámara): abrir la
## lista en blanco dejaba al jugador sin saber por dónde empezar. Se piden una sola vez por cohete
## y solo si no hay ningún instrumento elegido, así que quitarlas es decisión del jugador y no se
## vuelven a poner solas; si faltan, la ficha de misión avisa (MISSING_BASIC, sin bloquear).
##
## Se hace aquí y no en la simulación a propósito: la simulación la usan las pruebas de balance con
## diseños fijados a mano, y meterles piezas por detrás les cambiaba las cuentas.
## Herramientas básicas que el jugador se ha quitado. Vacío mientras no haya cohete: sin cohete
## todavía no hay misión de la que avisar.
func basicas_que_faltan(taller: Dictionary) -> Array:
	var seleccion: Dictionary = taller.get("selection", {})
	if (seleccion.get("cohetes", []) as Array).is_empty():
		return []
	var faltan: Array = []
	for id in MissionDesign.HERRAMIENTAS_BASICAS:
		if not (seleccion.get("extras", []) as Array).has(str(id)):
			faltan.append(str(id))
	return faltan


## Al llegar con el cohete, el rover entra con el diseño recomendado ya armado (que incluye las herramientas
## básicas). Una sola vez por cohete y solo si no hay instrumentos elegidos.
func _equipar_basicas(taller: Dictionary) -> void:
	var seleccion: Dictionary = taller.get("selection", {})
	if (seleccion.get("cohetes", []) as Array).is_empty():
		_basicas_puestas = false  # sin cohete no hay misión; al elegir otro se vuelven a poner
		return
	if _basicas_puestas or not (seleccion.get("extras", []) as Array).is_empty():
		return
	_basicas_puestas = true
	poner_recomendado(taller)


## Piezas recomendadas para el destino actual (sin el cohete, que se elige en la plataforma), por categoría.
static func recomendadas(taller: Dictionary, destino: String) -> Dictionary:
	var por_categoria := {}
	for cat in taller.get("categories", []):
		if str(cat.get("id", "")) == "cohetes":
			continue
		for pieza in cat.get("parts", []):
			if (pieza.get("recommended_for", []) as Array).has(destino):  # «no disponible» solo es categoría llena: se libera al quitar
				if not por_categoria.has(cat["id"]):
					por_categoria[cat["id"]] = []
				por_categoria[cat["id"]].append(str(pieza["id"]))
	return por_categoria


## Pone el diseño recomendado: en cada categoría con recomendación quita lo que no lo es y añade lo que falta
## (la trayectoria se cambia, no se añade). Sin recomendación en el destino, solo las herramientas básicas.
func poner_recomendado(taller: Dictionary) -> void:
	var por_categoria := recomendadas(taller, Destino.id)
	if por_categoria.is_empty():
		for id in MissionDesign.HERRAMIENTAS_BASICAS:
			command.emit("design_add", {"part_id": str(id)})
		return
	var seleccion: Dictionary = taller.get("selection", {})
	for cat in seleccion:
		if str(cat) == "cohetes":
			continue
		var quiere: Array = por_categoria.get(cat, [])
		for id in seleccion[cat]:
			if not quiere.has(str(id)):
				command.emit("design_remove", {"part_id": str(id)})
	for cat in por_categoria:
		for id in por_categoria[cat]:
			if not (seleccion.get(cat, []) as Array).has(id):
				command.emit("design_add", {"part_id": id})


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
	_strip.scroll_vertical = 0


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
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Fila: icono a la izquierda, nombre y datos a la derecha.
	var fila := HBoxContainer.new()
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_theme_constant_override("separation", 10)
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 10
	fila.offset_top = 6
	fila.offset_right = -10
	fila.offset_bottom = -6
	b.add_child(fila)
	var marco_icono := CenterContainer.new()
	marco_icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco_icono.custom_minimum_size = Vector2(38, 0)
	fila.add_child(marco_icono)
	marco_icono.add_child(Icon.make(PART_ICONS.get(str(part.get("id", "")), CATEGORY_ICONS[category]), 30, ORANGE if elegida else Color("D8C3AC", 0.8)))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_child(col)
	var nombre := UI.label(col, tr(str(part.get("name_key", ""))), UI.FONT_MIN, Color("F3E6D4") if puede or elegida else TEXT_DIM)
	nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 4)
	chips.add_theme_constant_override("v_separation", 3)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)
	if part.get("pending", false):
		chips.add_child(_chip(tr("WS_PENDING"), ORANGE))
	else:
		for par in [["cost_musd", "WS_COST"], ["mass_kg", "WS_MASS"], ["capacity_kg", "WS_CAPACITY"], ["power_w", "WS_POWER"],
				["cruise_days", "WS_DAYS"]]:
			var valor = part.get(par[0])
			if valor != null:
				chips.add_child(_chip(tr(par[1]) % int(valor), Color("F3E6D4", 0.9)))
		var factor = part.get("capacity_factor")
		if factor != null:
			chips.add_child(_chip(tr("WS_FACTOR") % int(round(float(factor) * 100.0)), Color("F3E6D4", 0.9)))
	var referencia := str(part.get("ref_key", ""))
	if not referencia.is_empty():
		b.tooltip_text = tr(referencia)
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
	var dias := int(totales.get("cruise_days", 0))
	if dias > 0 and capacidad > 0.0:
		var tray := UI.label(_summary_box, tr("WS_TRAJ_LINE") % [int(totales.get("rocket_capacity_kg", 0)),
			int(round(float(totales.get("capacity_factor", 1.0)) * 100.0)), dias], 11, TEXT_DIM)
		tray.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		elif str(codigo).begins_with("MISSING_KEY:"):  # instrumento clave: en rojo, con lo que se pierde
			_check_line(tr("WS_MISSING_KEY_" + str(codigo).get_slice(":", 1).to_upper()), "critical", UI.CORAL)
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
	for id in basicas_que_faltan(taller):
		if not MissionDesign.INSTRUMENTOS_CLAVE.has(id):  # los clave ya salen en rojo (MISSING_KEY)
			_check_line(tr("WS_MISSING_BASIC") % tr(str(_names.get(id, id))), "warning", ORANGE)
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
			return tr("WS_OVER_MASS_TRAJ")
		"OVER_BUDGET":
			return tr("WS_OVER_BUDGET")
		"PENDING_DATA":
			return tr("WS_PENDING_DATA") % tr(str(_names.get(partes[1], partes[1])))
	return codigo


## Instrumentos clave que faltan en el diseño (avisos MISSING_KEY de la simulación).
static func clave_que_faltan(taller: Dictionary) -> Array[String]:
	var faltan: Array[String] = []
	for codigo in taller.get("notices", []):
		if str(codigo).begins_with("MISSING_KEY:"):
			faltan.append(str(codigo).get_slice(":", 1))
	return faltan


func _on_action() -> void:
	var taller: Dictionary = snapshot.get("workshop", {})
	if validated and taller.get("valid", false):
		var faltan := clave_que_faltan(taller)
		if faltan.is_empty():
			_despegar(taller)
		elif not is_instance_valid(_confirmacion):
			_pedir_confirmacion(faltan)
		return
	command.emit("design_validate", {})
	validated = bool(snapshot.get("workshop", {}).get("valid", false))
	_signature = ""
	update_snapshot(snapshot)


func _despegar(taller: Dictionary) -> void:
	var sesion := preload("res://scenes/menu/game_session.gd")
	var jugadores := int(sesion.jugadores)
	if jugadores > 1 and sesion.en_red:
		command.emit("net_review_open", {})  # en red, la revisión se abre en todos los dispositivos (scenes/net/cliente_juego.gd)
	elif jugadores > 1:
		_revision_de_equipo(taller, jugadores)
	else:
		command.emit("design_start", {})


## Falta un instrumento clave: se avisa de lo que se pierde y se pide confirmación. No bloquea.
func _pedir_confirmacion(faltan: Array[String]) -> void:
	_confirmacion = PanelContainer.new()
	_confirmacion.add_theme_stylebox_override("panel", UI.box(0.96, 12, 0.5, 1, 24, 20))
	UI.place(_confirmacion, "c", 0, 0, 520, 0)
	root.add_child(_confirmacion)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_confirmacion.add_child(col)
	UI.label(col, tr("WS_MISSING_CONFIRM_TITLE"), 18, ORANGE)
	for id in faltan:
		var linea := UI.label(col, "• " + tr("WS_MISSING_KEY_" + id.to_upper()), UI.FONT_MIN + 1, Color("F3E6D4"))
		linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var nota := UI.label(col, tr("WS_MISSING_CONFIRM"), UI.FONT_MIN, TEXT_DIM)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 10)
	botones.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(botones)
	var volver := Button.new()
	volver.text = tr("WS_MISSING_BACK")
	volver.pressed.connect(_cerrar_confirmacion)
	botones.add_child(volver)
	var igual := Button.new()
	igual.text = tr("WS_LAUNCH_ANYWAY")
	igual.pressed.connect(func() -> void:
		_cerrar_confirmacion()
		_despegar(snapshot.get("workshop", {})))
	botones.add_child(igual)


func _cerrar_confirmacion() -> void:
	if is_instance_valid(_confirmacion):
		_confirmacion.queue_free()
	_confirmacion = null


## Modo equipo: antes de despegar, cada responsable vota GO / NO GO sobre su parte del diseño.
func _revision_de_equipo(taller: Dictionary, jugadores: int) -> void:
	var revision := preload("res://scenes/b/go_no_go.gd").new()
	revision.taller = taller
	revision.jugadores = jugadores
	root.add_child(revision)
	revision.build()
	revision.launch_confirmed.connect(func() -> void:
		revision.queue_free()
		command.emit("design_start", {}))
	revision.cancelled.connect(func() -> void:
		revision.queue_free()
		validated = false
		_signature = ""
		update_snapshot(snapshot))


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
	if is_instance_valid(_camera):
		_camera.position = _camera_home + _camera_home.cross(Vector3.UP).normalized() * sin(_clock * 0.3) * 0.55  # paralaje suave
		_camera.look_at(Vector3(0, 0.72, 0))
	_update_hotspots()
	if is_instance_valid(_toast) and _toast.visible and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_toast.visible = false


## Muro cilíndrico por tramos que deja un hueco (el portón). Se ve por ambas caras.
func _arco(padre: Node, radio: float, y0: float, y1: float, mat: Material, ang_hueco: float, medio_hueco: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	for i in range(n):
		var a0 := i * TAU / n
		var a1 := (i + 1) * TAU / n
		if absf(angle_difference((a0 + a1) / 2.0, ang_hueco)) < medio_hueco:
			continue
		var p00 := Vector3(cos(a0) * radio, y0, sin(a0) * radio)
		var p10 := Vector3(cos(a1) * radio, y0, sin(a1) * radio)
		var p01 := Vector3(cos(a0) * radio, y1, sin(a0) * radio)
		var p11 := Vector3(cos(a1) * radio, y1, sin(a1) * radio)
		for v in [p00, p10, p11, p00, p11, p01]:
			st.add_vertex(v)
	st.generate_normals()
	var malla := st.commit()
	var nodo := MeshInstance3D.new()
	nodo.mesh = malla
	nodo.material_override = mat
	padre.add_child(nodo)
