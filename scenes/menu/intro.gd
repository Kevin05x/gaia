extends Control
## Intro de GAIA: estrellas, el planeta con su órbita, las letras 3D que llegan y encajan con un destello y un pequeño
## «glitch», y el subtítulo. Cualquier tecla o clic la salta. En la web empieza con «Pulsa para comenzar», que además
## desbloquea el audio del navegador. Al terminar abre el menú principal.
const UI := preload("res://scenes/b/ui_style.gd")
const Logo := preload("res://scenes/menu/gaia_logo.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const Musica := preload("res://scenes/menu/musica.gd")
const LOGOTIPO := "res://assets/menu/gaia_logo.png"
const ESCENA_SIGUIENTE := "res://scenes/menu/menu.tscn"
const ESCENA_ALTERNA := "res://scenes/a/game.tscn"
signal terminada

var logo: Control
var subtitulo: Label
var credito: Label
var gate: Label
var estrellas: Control
var velo: ColorRect
var _empezo := false
var _salto := false
var _tween: Tween


func _ready() -> void:
	Texto.install()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var fondo := ColorRect.new()
	fondo.color = Color("0b0810")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	# Resplandor de horizonte marciano abajo.
	var degradado := Gradient.new()
	degradado.colors = PackedColorArray([Color(0.75, 0.35, 0.2, 0.0), Color(0.75, 0.35, 0.2, 0.32)])
	var textura := GradientTexture2D.new()
	textura.gradient = degradado
	textura.fill_from = Vector2(0, 0)
	textura.fill_to = Vector2(0, 1)
	var horizonte := TextureRect.new()
	horizonte.texture = textura
	horizonte.stretch_mode = TextureRect.STRETCH_SCALE
	horizonte.set_anchors_preset(Control.PRESET_FULL_RECT)
	horizonte.anchor_top = 0.55
	add_child(horizonte)
	estrellas = Stars2D.new()
	estrellas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(estrellas)
	if ResourceLoader.exists(LOGOTIPO):
		var imagen := TextureRect.new()
		imagen.texture = load(LOGOTIPO)
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo = imagen
	else:
		var logo3d := Logo.new()
		logo3d.disposicion = "horizontal"
		logo = logo3d
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.anchor_left = 0.14
	logo.anchor_right = 0.86
	logo.anchor_top = 0.2
	logo.anchor_bottom = 0.62
	logo.offset_left = 0
	logo.offset_right = 0
	logo.offset_top = 0
	logo.offset_bottom = 0
	logo.pivot_offset_ratio = Vector2(0.5, 0.5)
	add_child(logo)
	subtitulo = _etiqueta(tr("INTRO_SUBTITLE"), 22, 700, 10, Color(UI.AMBER, 0.95))
	subtitulo.anchor_top = 0.64
	subtitulo.anchor_bottom = 0.7
	credito = _etiqueta(tr("INTRO_CREDIT"), 14, 560, 3, Color(UI.CREAM, 0.6))
	credito.anchor_top = 0.92
	credito.anchor_bottom = 0.97
	gate = _etiqueta(tr("INTRO_CLICK"), 18, 600, 4, Color(UI.CREAM, 0.85))
	gate.anchor_top = 0.62
	gate.anchor_bottom = 0.7
	velo = ColorRect.new()
	velo.color = Color.BLACK
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	for c in [logo, subtitulo, credito]:
		c.modulate.a = 0.0
	if OS.has_feature("web"):
		gate.modulate.a = 0.0
		create_tween().tween_property(gate, "modulate:a", 1.0, 0.8)
		velo.color = Color(0, 0, 0, 0.0)
	else:
		gate.visible = false
		_empezar()


func _etiqueta(texto: String, tam: int, peso: int, tracking: int, color: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UI.display_font(peso, tracking))
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _unhandled_input(e: InputEvent) -> void:
	var pulsado: bool = (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed) \
		or (e is InputEventScreenTouch and e.pressed)
	if not pulsado:
		return
	get_viewport().set_input_as_handled()
	if not _empezo:
		_empezar()
	elif not _salto:
		_salir()


func _empezar() -> void:
	if _empezo:
		return
	_empezo = true
	Musica.reproducir(get_tree(), "menu", 4.0)
	if gate.visible:
		create_tween().tween_property(gate, "modulate:a", 0.0, 0.3)
	if logo.has_method("set_glitch"):
		logo.set_glitch(1.0)
	_tween = create_tween()
	_tween.tween_property(velo, "color:a", 0.0, 0.5).from(1.0)
	if logo.has_method("animar_entrada"):
		_tween.tween_property(logo, "modulate:a", 1.0, 0.05)
	_tween.tween_callback(_entrada_logo)
	_tween.tween_interval(2.5)
	_tween.tween_property(subtitulo, "modulate:a", 1.0, 0.8)
	_tween.parallel().tween_property(credito, "modulate:a", 1.0, 1.2)
	_tween.tween_interval(1.8)
	_tween.tween_callback(_salir)


## El logotipo entra con un destello cálido y un pequeño acercamiento; el 3D por código usa su propia animación.
func _entrada_logo() -> void:
	if logo.has_method("animar_entrada"):
		logo.animar_entrada()
		return
	logo.scale = Vector2(1.08, 1.08)
	logo.modulate = Color(2.6, 2.0, 1.4, 0.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(logo, "modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(logo, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _salir() -> void:
	if _salto:
		return
	_salto = true
	if _tween != null:
		_tween.kill()
	logo.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(velo, "color:a", 1.0, 0.45)
	tw.tween_callback(func() -> void:
		terminada.emit()
		var destino := ESCENA_SIGUIENTE if ResourceLoader.exists(ESCENA_SIGUIENTE) else ESCENA_ALTERNA
		if is_inside_tree():
			get_tree().change_scene_to_file(destino))


## Estrellas dibujadas en 2D (una sola pasada de dibujo) con un parpadeo lento.
class Stars2D extends Control:
	var _puntos: Array = []
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var azar := RandomNumberGenerator.new()
		azar.seed = 77
		for i in range(190):
			_puntos.append([azar.randf(), azar.randf() * 0.8, azar.randf_range(0.6, 2.0), azar.randf() * TAU])

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for p in _puntos:
			var brillo := 0.35 + 0.35 * sin(_t * 0.8 + p[3])
			draw_circle(Vector2(p[0] * size.x, p[1] * size.y), p[2], Color(1.0, 0.95, 0.85, brillo * (0.5 + p[2] / 4.0)))
