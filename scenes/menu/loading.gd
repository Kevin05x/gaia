extends Control
## Pantalla de carga: imagen fija de Marte en alta resolución, un consejo y una barra de progreso mientras se carga la
## escena del juego en segundo plano. Se queda al menos un instante para que se lea el consejo.
const UI := preload("res://scenes/b/ui_style.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const IMAGEN := "res://assets/menu/pantalla_carga.jpg"
const LOGOTIPO := "res://assets/menu/gaia_logo.png"
const TIEMPO_MINIMO := 2.2
const CONSEJOS := 6

var barra: ColorRect
var etiqueta: Label
var consejo: Label
var velo: ColorRect
var progreso := 0.0
var _t := 0.0
var _consejo_t := 0.0
var _listo := false
var _ancho_barra := 0.0


func _ready() -> void:
	Texto.install()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var base := ColorRect.new()
	base.color = Color("120a08")
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	var foto := TextureRect.new()
	if ResourceLoader.exists(IMAGEN):
		foto.texture = load(IMAGEN)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	foto.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(foto)
	# Banda inferior oscura para el consejo y la barra.
	var banda := ColorRect.new()
	banda.color = Color(0.04, 0.025, 0.02, 0.88)
	banda.anchor_top = 0.87
	banda.anchor_right = 1.0
	banda.anchor_bottom = 1.0
	add_child(banda)
	if ResourceLoader.exists(LOGOTIPO):
		var logo := TextureRect.new()
		logo.texture = load(LOGOTIPO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		UI.place(logo, "tl", 44, 30, 300, 85)
		add_child(logo)
	etiqueta = UI.label(self, tr("M_LOADING"), 14, Color(UI.AMBER, 0.95))
	UI.display(etiqueta, 700, 4)
	UI.place(etiqueta, "bl", 60, 28, 300, 20)
	consejo = UI.label(self, "", 17, Color(UI.CREAM, 0.9))
	consejo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consejo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	consejo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.place(consejo, "br", 60, 30, 640, 52)
	# Barra de progreso fina que cruza la banda.
	var pista := ColorRect.new()
	pista.color = Color(UI.CREAM, 0.12)
	UI.place(pista, "bl", 60, 14, 1160, 3)
	pista.anchor_right = 1.0
	pista.offset_left = 60
	pista.offset_right = -60
	add_child(pista)
	barra = ColorRect.new()
	barra.color = UI.AMBER
	barra.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	barra.anchor_right = 0.0
	barra.offset_right = 0
	pista.add_child(barra)
	pista.resized.connect(func() -> void: _ancho_barra = pista.size.x)
	_ancho_barra = 1160.0
	_nuevo_consejo()
	velo = ColorRect.new()
	velo.color = Color.BLACK
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	create_tween().tween_property(velo, "color:a", 0.0, 0.4)
	ResourceLoader.load_threaded_request(Sesion.ESCENA_JUEGO)


func _nuevo_consejo() -> void:
	consejo.text = "%s   %s" % [tr("M_TIP"), tr("M_TIP%d" % (1 + randi() % CONSEJOS))]


func _process(delta: float) -> void:
	_t += delta
	_consejo_t += delta
	if _consejo_t > 4.0:
		_consejo_t = 0.0
		_nuevo_consejo()
	var avance: Array = []
	var estado := ResourceLoader.load_threaded_get_status(Sesion.ESCENA_JUEGO, avance)
	var real: float = float(avance[0]) if not avance.is_empty() else 0.0
	var objetivo := minf(real, _t / TIEMPO_MINIMO)
	progreso = move_toward(progreso, objetivo, delta * 0.9)
	barra.anchor_right = 0.0
	barra.offset_right = _ancho_barra * progreso
	etiqueta.text = "%s  %d%%" % [tr("M_LOADING"), roundi(progreso * 100.0)]
	if estado == ResourceLoader.THREAD_LOAD_LOADED and _t >= TIEMPO_MINIMO and not _listo:
		progreso = 1.0
		_listo = true
		_cambiar()
	elif estado == ResourceLoader.THREAD_LOAD_FAILED and not _listo:
		_listo = true
		get_tree().change_scene_to_file(Sesion.ESCENA_JUEGO)


func _cambiar() -> void:
	# La imagen de carga se queda a la vista («Preparando… 100 %») mientras el juego se construye; así el paso no deja
	# una pantalla vacía. Se dibujan un par de fotogramas antes del trabajo pesado y el juego se monta sin cortar a negro.
	etiqueta.text = "%s  100%%" % tr("M_LOADING")
	barra.offset_right = _ancho_barra
	set_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var escena = ResourceLoader.load_threaded_get(Sesion.ESCENA_JUEGO)
	if not (escena is PackedScene):
		get_tree().change_scene_to_file(Sesion.ESCENA_JUEGO)
		return
	var juego: Node = (escena as PackedScene).instantiate()
	var arbol := get_tree()
	arbol.root.add_child(juego)
	await arbol.process_frame
	await arbol.process_frame
	# Con el juego ya dibujándose, la carga se desvanece y desaparece.
	var capa := CanvasLayer.new()
	capa.layer = 100
	arbol.root.add_child(capa)
	reparent(capa)
	arbol.current_scene = juego
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(capa.queue_free)
