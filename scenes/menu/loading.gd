extends Control
## Pantalla de carga: imagen fija de Marte, un consejo y una barra de progreso. En la web no hay hilos: todo lo pesado
## corre en el hilo principal y, si se hace de golpe, el navegador ofrece «Esperar / Salir». Por eso la carga va en
## pasos, uno por cuadro: primero los recursos (escenas, modelos, sonidos), luego se monta el juego y por último se
## espera a que el terreno (construido por pasos) y el precalentado de sombreadores terminen. La pantalla se queda
## hasta entonces: el jugador nunca ve el juego a medio montar.
const UI := preload("res://scenes/b/ui_style.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const IMAGEN := "res://assets/menu/pantalla_carga.jpg"
const LOGOTIPO := "res://assets/menu/gaia_logo.png"
const TIEMPO_MINIMO := 2.2
const CONSEJOS := 6
const SIN_AVANCE_MAX_S := 45.0  ## si la preparación no avanza en este rato, se entra igual (no se queda colgada)
const ESPERA_MAXIMA_S := 240.0  ## tope absoluto, por si avanza tan lento que nunca acaba
## Lo que se carga antes de montar el juego, un recurso por cuadro (así ningún cuadro tarda demasiado).
const RECURSOS := ["res://scenes/b/ui_style.gd", "res://scenes/b/terrain.gd", "res://scenes/b/actors.gd",
	"res://scenes/b/hud.gd", "res://scenes/b/workshop.gd", "res://scenes/b/base_hud.gd", "res://scenes/b/story_panel.gd",
	"res://scenes/b/buildings.gd", "res://scenes/b/combat_view.gd", "res://scenes/b/audio.gd",
	"res://scenes/b/assets/models/rover.tscn", "res://scenes/b/assets/models/station.tscn",
	"res://scenes/b/assets/models/drone.tscn", "res://scenes/b/assets/models/companion.tscn",
	"res://scenes/b/mission.tscn", "res://scenes/a/mission_runner.gd", "res://scenes/a/game.tscn"]
const MODELOS := ["anthena_juego", "cristal5_brillo", "hielo_2", "hielo_3", "foco", "hangar_cuadrado", "hangar_roundA",
	"taladro", "torreta_doble", "torreta_simple"]
const Equipo := preload("res://scenes/b/modelos_equipo.gd")

static var reservas: Array = []  ## recursos ya cargados: se quedan en memoria para que el juego no los vuelva a leer

var barra: ColorRect
var etiqueta: Label
var consejo: Label
var velo: ColorRect
var progreso := 0.0
var _t := 0.0
var _consejo_t := 0.0
var _ancho_barra := 0.0
var _objetivo := 0.0


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
	_cargar.call_deferred()


func _nuevo_consejo() -> void:
	consejo.text = "%s   %s" % [tr("M_TIP"), tr("M_TIP%d" % (1 + randi() % CONSEJOS))]


func _process(delta: float) -> void:
	_t += delta
	_consejo_t += delta
	if _consejo_t > 4.0:
		_consejo_t = 0.0
		_nuevo_consejo()
	progreso = move_toward(progreso, _objetivo, delta * 1.2)
	barra.anchor_right = 0.0
	barra.offset_right = _ancho_barra * progreso
	etiqueta.text = "%s  %d%%" % [tr("M_LOADING"), roundi(progreso * 100.0)]


func _fijar(valor: float) -> void:
	_objetivo = clampf(valor, _objetivo, 1.0)


## Carga por pasos (ver la cabecera). Cada «await» deja dibujar un cuadro: el navegador sigue respondiendo.
func _cargar() -> void:
	var arbol := get_tree()
	await arbol.process_frame
	var total := RECURSOS.size() + MODELOS.size()
	var hechos := 0
	for ruta in RECURSOS:
		if ResourceLoader.exists(ruta):
			reservas.append(load(ruta))
		hechos += 1
		_fijar(0.6 * hechos / total)
		await arbol.process_frame
	for nombre in MODELOS:
		Equipo.precargar([nombre])
		hechos += 1
		_fijar(0.6 * hechos / total)
		await arbol.process_frame
	while _t < TIEMPO_MINIMO * 0.5:
		await arbol.process_frame
	var escena = load(Sesion.ESCENA_JUEGO)
	if not (escena is PackedScene):
		arbol.change_scene_to_file(Sesion.ESCENA_JUEGO)
		return
	_fijar(0.65)
	await arbol.process_frame
	var juego: Node = (escena as PackedScene).instantiate()
	arbol.root.add_child(juego)
	_fijar(0.72)
	# El juego se prepara por pasos detrás de esta pantalla (terreno y sombreadores).
	var vista = juego.get("view")
	# Equipos lentos tardan más en compilar sombreadores: se espera mientras haya avance, no un tiempo fijo. Antes, a los
	# 40 s la carga se iba aunque el precalentado siguiera y quedaba una cortina marrón sin barra («no entra»).
	var inicio := _t
	var ultimo_avance := _t
	var avance_antes := -1.0
	while vista != null and is_instance_valid(vista) and vista.has_method("esta_listo") and not vista.esta_listo():
		var avance := float(vista.preparacion())
		if avance > avance_antes + 0.001:
			avance_antes = avance
			ultimo_avance = _t
		if _t - ultimo_avance > SIN_AVANCE_MAX_S or _t - inicio > ESPERA_MAXIMA_S:
			push_warning("Carga: sin avance (%.2f); se entra igual" % avance)
			if vista.has_method("forzar_listo"):
				vista.forzar_listo()
			break
		_fijar(0.72 + 0.26 * avance)
		await arbol.process_frame
	_fijar(1.0)
	while progreso < 0.999 or _t < TIEMPO_MINIMO:
		await arbol.process_frame
	await arbol.process_frame
	# Con el juego ya dibujándose detrás, la carga se desvanece y desaparece.
	var capa := CanvasLayer.new()
	capa.layer = 100
	arbol.root.add_child(capa)
	reparent(capa)
	arbol.current_scene = juego
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(capa.queue_free)
