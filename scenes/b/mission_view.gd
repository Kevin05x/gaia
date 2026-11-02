extends Node3D
## Punto de entrada de la vista para A: instanciar mission.tscn y usar su nodo Port.
## Monta el mundo (terreno, actores, cámara que sigue al rover, luz por hora), el HUD y el informe,
## y traduce clics y teclas en órdenes. No contiene reglas de juego.
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
signal menu_requested  ## el jugador pidió volver al menú principal
const Art := preload("res://scenes/b/art.gd")
const SkyLight := preload("res://scenes/b/sky_light.gd")
const W := preload("res://scenes/b/world_art.gd")

var port: Node
var terrain: Node3D
var actors: Node3D
var rig: Node3D
var hud: CanvasLayer
var report_view: CanvasLayer
var explosions: Node3D
var audio: Node
var sun: DirectionalLight3D
var environment: Environment
var lighting: Node
var tracks: MeshInstance3D
var _tracks_seeded := false
var workshop: CanvasLayer
var story: CanvasLayer  ## introducción y ventana de decisión de la historia
var tutorial: CanvasLayer  ## cartel del tutorial del Sol 1
var base_hud: CanvasLayer  ## recursos, ética, Rocky y menú de construcción
var buildings: Node3D  ## edificios de la base
var muros: MurosView  ## barrera de la base (muros y compuertas terminados)
var textos: TextosFlotantes  ## «+3 Olivino» al recoger o descargar
var sombras: SombrasContacto  ## manchas de contacto bajo estación, edificios, muros, Rocky y el dron
var motas: PolvoAmbiente  ## polvo flotando cerca de la cámara (opción gráfica)
var _antes: Dictionary = {}  ## recursos y bodega del snapshot anterior (para los textos flotantes)
var _puestos: Dictionary = {}  ## casillas donde ya se pidió un muro en este modo de colocación (hasta que llegue el snapshot)
var combat: Node3D  ## nidos, monstruos, rayos y meteoritos
var placing := ""  ## edificio que se está colocando ("" si ninguno)
var state: Dictionary = {}
var inspection := false
var language := "es"
var volume := 0.65
var muted := false
var quality := true
var landing_in_progress := false
var selected_target := ""
var map_signature := ""
var _blocked_cache: Dictionary = {}
var _blocked_cache_revision := ""
var _hover_tile := Vector2i(999, 999)
var warmup: Node3D  ## precalentado de sombreadores al empezar
var cortina: CanvasLayer  ## cortina oscura mientras dura el precalentado
var _listo := false
var calidad: Node  ## resolución 3D automática según lo que aguante el equipo
var graficos: Dictionary = Graficos.de_preset(Graficos.defecto())  ## configuración gráfica elegida (Opciones)
var ciencia: CanvasLayer  ## panel de objetivos científicos (hitos)
signal listo  ## terreno construido y sombreadores precalentados: la pantalla de carga ya puede irse
static var translations_registered := false


func _ready() -> void:
	var editor_preview := get_node_or_null("EditorPreview")
	if editor_preview != null:
		remove_child(editor_preview)
		editor_preview.queue_free()
	setup_locale()
	port = get_node("Port")
	terrain = preload("res://scenes/b/terrain.gd").new()
	terrain.name = "Terrain"
	terrain.lazy = true  # el mundo se construye con el tamaño del mapa, una sola vez
	terrain.por_pasos = true  # y repartido en varios cuadros, detrás de la pantalla de carga
	add_child(terrain)
	actors = preload("res://scenes/b/actors.gd").new()
	actors.name = "Actors"
	add_child(actors)
	actors.dust_ground = terrain.height_at
	tracks = preload("res://scenes/b/tracks.gd").new()
	tracks.name = "Tracks"
	tracks.ground = terrain.height_at
	add_child(tracks)
	rig = preload("res://scenes/b/camera.gd").new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.follow = actors.rover
	rig.center_on(actors.rover.global_position)
	var world := WorldEnvironment.new()
	environment = Environment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = quality
	add_child(sun)
	lighting = SkyLight.new()
	lighting.name = "Lighting"
	add_child(lighting)
	lighting.quality = quality
	lighting.setup(environment, sun)
	hud = preload("res://scenes/b/hud.gd").new()
	hud.name = "HUD"
	add_child(hud)
	hud.inspection = inspection
	hud.command.connect(_command)
	hud.locale_changed.connect(change_locale)
	hud.menu_requested.connect(func() -> void: menu_requested.emit())
	hud.preferences_changed.connect(set_preferences)
	audio = preload("res://scenes/b/audio.gd").new()
	add_child(audio)
	audio.set_volume(volume, muted)
	hud.volume = volume
	hud.muted = muted
	hud.quality = quality
	hud.graficos = graficos
	hud.graficos_changed.connect(aplicar_graficos)
	hud.build()
	workshop = preload("res://scenes/b/workshop.gd").new()
	workshop.name = "Workshop"
	add_child(workshop)
	workshop.command.connect(_command)
	workshop.options_requested.connect(func(): hud.open_options())
	report_view = preload("res://scenes/b/report.gd").new()
	report_view.name = "Report"
	add_child(report_view)
	report_view.redesign_requested.connect(func(): port.submit("redesign"))
	buildings = preload("res://scenes/b/buildings.gd").new()
	buildings.name = "Buildings"
	buildings.ground = terrain.height_at
	add_child(buildings)
	combat = preload("res://scenes/b/combat_view.gd").new()
	combat.ground = terrain.height_at
	combat.buildings = buildings
	add_child(combat)
	explosions = preload("res://scenes/b/explosion_fx.gd").new()
	explosions.name = "Explosions"
	explosions.ground = terrain.height_at
	add_child(explosions)
	explosions.exploto.connect(func(pos: Vector3, tamano: float) -> void: rig.sacudir(pos, 0.07 * tamano))
	sombras = SombrasContacto.new()
	sombras.name = "SombrasContacto"
	sombras.ground = terrain.height_at
	add_child(sombras)
	sombras.seguir(actors.companion, 0.85, 0.65)
	sombras.seguir(actors.drone, 0.7, 0.6, 4.0)
	motas = PolvoAmbiente.new()
	motas.name = "PolvoAmbiente"
	motas.objetivo = rig.camera
	add_child(motas)
	textos = TextosFlotantes.new()
	textos.name = "Textos"
	add_child(textos)
	muros = MurosView.new()
	muros.name = "Muros"
	muros.ground = terrain.height_at
	add_child(muros)
	buildings.building_lost.connect(func(pos: Vector3, tipo: String) -> void:
		var grande := tipo in ["hangar", "extractor_hielo", "domo", "torreta_2"]
		explosions.explotar(pos, 1.6 if grande else 1.1, 14 if grande else 10)
		if is_instance_valid(audio):
			audio.sfx("explosion", 0.08))
	buildings.module_lost.connect(func(pos: Vector3) -> void:
		explosions.explotar(pos, 2.4, 18)
		if is_instance_valid(audio):
			audio.sfx("explosion", 0.0))
	buildings.building_started.connect(func(pos: Vector3) -> void:
		explosions.polvo(pos, 0.7)
		if is_instance_valid(audio):
			audio.sfx("obra_inicio", 0.05))
	buildings.building_done.connect(func(pos: Vector3, tipo: String) -> void:
		explosions.polvo(pos, 1.3 if tipo == "hangar" or tipo == "domo" else 1.0)
		if is_instance_valid(audio):
			audio.sfx("obra_fin", 0.0))
	terrain.target_depleted.connect(func(pos: Vector3) -> void:
		explosions.polvo(pos, 0.9))
	base_hud = preload("res://scenes/b/base_hud.gd").new()
	base_hud.name = "BaseHud"
	add_child(base_hud)
	base_hud.command.connect(_command)
	base_hud.placement_requested.connect(start_placement)
	ciencia = preload("res://scenes/b/hud_ciencia.gd").new()
	ciencia.name = "Ciencia"
	add_child(ciencia)
	hud.abrir_ciencia = ciencia.toggle
	story = preload("res://scenes/b/story_panel.gd").new()
	story.name = "Story"
	add_child(story)
	story.command.connect(_command)
	tutorial = preload("res://scenes/b/tutorial_panel.gd").new()
	tutorial.name = "Tutorial"
	add_child(tutorial)
	tutorial.command.connect(_command)
	tutorial.step_changed.connect(func() -> void: audio.ping())
	story.escena_abierta.connect(func() -> void: audio.sfx("escena", 0.0))
	story.radio_tapada = func() -> bool: return base_hud.menu.visible or base_hud.ficha_abierta()
	hud.metas_tapadas = func() -> bool: return base_hud.menu.visible
	base_hud.menu_cambiado.connect(func(_abierto: bool) -> void:
		if not state.is_empty():
			hud.update_snapshot(state))
	tutorial.target_for = func(clave: String) -> Control:  # se consulta cada cuadro: el HUD puede reconstruirse
		return base_hud.build_button if clave == "construir" else hud.highlight_nodes().get(clave, null)
	port.snapshot_received.connect(apply_snapshot)
	port.report_received.connect(_report)
	port.path_received.connect(func(tiles: Array, seconds: float):
		actors.follow_path(tiles, seconds)
		terrain.show_route(tiles)
		terrain.flash_grid())
	port.action_received.connect(func(action: Dictionary):
		for t in port.snapshot.get("targets", []):
			if str(t.get("id", "")) == str(action.get("target_id", "")) and t.has("tile"):
				action["tile"] = t["tile"]
		actors.start_action(action)
		hud.start_action(action)
		audio.start_action(action))
	port.cancel_received.connect(actors.cancel_actions)
	port.cancel_received.connect(audio.cancel)
	port.cancel_received.connect(terrain.clear_route)
	port.rejected.connect(func(key: String):
		hud.show_notice(key)
		workshop.show_notice(key))
	actors.landing_finished.connect(func():
		landing_in_progress = false
		port.submit("landing_finished"))
	set_preferences(volume, muted, quality, false)
	if not port.snapshot.is_empty():
		apply_snapshot(port.snapshot)
	else:
		hud.show_notice("WAIT")
	_precalentar()
	calidad = preload("res://scenes/b/calidad_dinamica.gd").new()
	calidad.name = "CalidadDinamica"
	calidad.medir = func() -> bool:
		return _listo and not blocked() and DisplayServer.window_is_focused()
	calidad.al_recortar = _recortar
	add_child(calidad)
	aplicar_graficos(graficos, false)
	if warmup != null and warmup.activo():
		calidad.modo_carga(true)


## Aplica la configuración gráfica (Opciones › Gráficos) a la luz, las sombras, los materiales, el decorado, el polvo
## y la calidad automática, y la guarda.
func aplicar_graficos(nuevo: Dictionary, guardar: bool = true) -> void:
	graficos = Graficos.normalizar(nuevo.duplicate())
	quality = bool(graficos["texturas"])
	lighting.post = bool(graficos["post"])
	lighting.quality = quality
	lighting.fijar_sombras(int(graficos["sombras"]))
	W.quality = quality
	W.sombras_decor = int(graficos["sombras"]) > 0
	W.apply_quality()
	terrain.factor_distancia = Graficos.FACTOR_DISTANCIA[int(graficos["distancia"])]
	terrain.apply_quality()
	actors.dust.amount = 130 if bool(graficos["polvo"]) else 36
	motas.emitting = bool(graficos["polvo"])
	motas.visible = bool(graficos["polvo"])
	if is_instance_valid(calidad):
		calidad.configurar(Graficos.msaa(graficos), float(graficos["resolucion"]), bool(graficos["auto"]),
			bool(graficos["post"]), int(graficos["sombras"]) > 0)
	if guardar:
		Graficos.guardar(graficos)


## Ajuste automático en un equipo muy justo: tras quitar suavizado y resolución, quita el brillo (1) y luego las
## sombras (2) solo en esta partida. 0 vuelve a lo elegido.
func _recortar(nivel: int) -> void:
	var post := bool(graficos["post"]) and nivel < 1
	var sombras := int(graficos["sombras"]) if nivel < 2 else 0
	if lighting.post != post or lighting.sombras != sombras:
		lighting.post = post
		lighting.fijar_sombras(sombras)


## Rendimiento (web): compila de antemano los sombreadores de edificios, monstruos y efectos, detrás de una cortina
## oscura que luego se desvanece. Sin esto, la primera obra o extracción congelaba la imagen un instante.
func _precalentar() -> void:
	warmup = preload("res://scenes/b/shader_warmup.gd").new()
	warmup.name = "ShaderWarmup"
	add_child(warmup)
	warmup.camara = rig.camera
	warmup.sol = sun
	cortina = CanvasLayer.new()
	cortina.name = "Cortina"
	cortina.layer = 120
	add_child(cortina)
	var negro := ColorRect.new()
	negro.color = Color(0.07, 0.04, 0.03, 1.0)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	negro.set_anchors_preset(Control.PRESET_FULL_RECT)
	cortina.add_child(negro)
	lighting.set_process(false)  # el cielo no debe cambiar las sombras mientras se precalienta
	warmup.terminado.connect(func() -> void:
		if is_instance_valid(calidad):
			calidad.modo_carga(false)
		lighting.set_process(true)
		lighting.apply(true)
		_comprobar_listo()
		var t := negro.create_tween()
		t.tween_property(negro, "modulate:a", 0.0, 0.35)
		t.tween_callback(cortina.queue_free))
	terrain.mundo_listo.connect(_comprobar_listo)
	var extra: Array = []
	extra.append_array(buildings.muestras_para_precalentar())
	extra.append_array(MurosView.muestras())
	extra.append_array(combat.muestras_para_precalentar())
	extra.append(terrain.muestra_contorno())
	warmup.empezar([actors, combat, explosions, terrain, buildings, tracks, textos], extra)


## Se descargó la bodega: sonido de confirmación (el almacén late en el HUD).
func al_descargar() -> void:
	audio.sfx("obra_fin", 0.1)


## Un hito científico se cumplió: cartel y sonido de enlace.
func celebrar_hito(id: String) -> void:
	if not state.is_empty():
		ciencia.update_snapshot(state)
	ciencia.celebrar(id)
	audio.sfx("hito", 0.0)


## Avance de la preparación (0..1) para la pantalla de carga: terreno por pasos y precalentado de sombreadores.
func preparacion() -> float:
	var a := 0.0 if terrain.construyendo() or not terrain._built else 0.5
	var b: float = warmup.avance() if warmup != null else 1.0
	return a + 0.5 * b


func esta_listo() -> bool:
	return _listo


## La pantalla de carga no vio avances en mucho rato: se termina el precalentado (si quedaba) para que el jugador entre
## igual. Lo que falte por compilar se compilará al aparecer (algún tirón suelto), pero nunca una pantalla marrón fija.
func forzar_listo() -> void:
	if warmup != null and warmup.activo():
		warmup.terminar()
	if is_instance_valid(calidad):
		calidad.modo_carga(false)


func _comprobar_listo() -> void:
	if _listo or warmup == null or warmup.activo() or terrain.construyendo() or not terrain._built:
		return
	_listo = true
	listo.emit()


func _exit_tree() -> void:
	Equipo.vaciar()


func setup_locale() -> void:
	if not translations_registered:
		var tables = preload("res://scenes/b/i18n/catalog.gd").TABLES
		for locale in tables:
			var translation := Translation.new()
			translation.locale = locale
			for key in tables[locale]:
				translation.add_message(key, tables[locale][key])
			TranslationServer.add_translation(translation)
		translations_registered = true
	var config := ConfigFile.new()
	if config.load("user://b_preferences.cfg") == OK:
		language = config.get_value("ui", "language", "es")
		volume = config.get_value("audio", "volume", 0.65)
		muted = config.get_value("audio", "muted", false)
		quality = config.get_value("visual", "quality", true)
	graficos = Graficos.cargar()
	quality = bool(graficos["texturas"])
	TranslationServer.set_locale(language)


func change_locale(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	hud.build()
	workshop.build()
	base_hud.build()
	story.rebuild()
	if not report_view.report.is_empty():
		report_view.rebuild()
	save_preferences()


func set_preferences(value: float, is_muted: bool, high_quality: bool, save: bool = true) -> void:
	volume = value
	muted = is_muted
	quality = high_quality
	audio.set_volume(volume, muted)
	if high_quality != bool(graficos["texturas"]):
		# Interruptor antiguo de calidad: Alta o Baja completa.
		aplicar_graficos(Graficos.de_preset("alta" if high_quality else "baja"), save)
	if save:
		save_preferences()


func save_preferences() -> void:
	var config := ConfigFile.new()
	config.load("user://b_preferences.cfg")  # conserva el resto de preferencias (tutorial, tamaño de ventana)
	config.set_value("ui", "language", language)
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "muted", muted)
	config.set_value("visual", "quality", quality)
	config.save("user://b_preferences.cfg")


func apply_snapshot(s: Dictionary) -> void:
	state = s  # el Port ya entrega su propia copia: no hace falta otra copia profunda en cada snapshot
	var signature := str(s.get("map_revision", 0))
	if map_signature != signature:
		terrain.configure(s.get("targets", []), s.get("obstacles", []), s.get("bounds", {}), s.get("zones", []))
		map_signature = signature
		tracks.clear()
	var en_taller: bool = s.get("phase", "") == "workshop"
	terrain.visible = not en_taller
	actors.visible = not en_taller
	tracks.visible = not en_taller
	buildings.visible = not en_taller
	buildings.update_state(s)
	muros.visible = not en_taller
	muros.update_state(s)
	sombras.visible = not en_taller
	sombras.update_state(s, actors.station.global_position)
	_textos_de_recursos(s)
	if not _puestos.is_empty() and not placing.is_empty():
		_puestos.clear()  # el snapshot ya trae las obras pedidas (o la simulación las rechazó: la casilla vuelve a estar libre)
		start_placement(placing)
	combat.update_state(s)
	base_hud.update_snapshot(s)
	ciencia.update_snapshot(s)
	story.update_snapshot(s)
	tutorial.update_snapshot(s)
	tutorial.set_hidden(story.is_open() or bool(s.get("paused", false)) or hud.settings.visible)
	if not placing.is_empty() and (s.get("phase", "") != "operations" or story.is_open()):
		cancel_placement()
	workshop.update_snapshot(s)
	terrain.update_targets(s.get("targets", []))
	terrain.select(selected_target)
	actors.apply_state(s)
	hud.update_snapshot(s)
	lighting.set_state(float(s.get("hour", 8.0)), float(s.get("dust", 0.0)))
	motas.fijar_polvo(float(s.get("dust", 0.0)))
	rig.enabled = not blocked()
	if s.get("phase", "") == "landing" and not landing_in_progress and not actors.landed:
		landing_in_progress = true
		actors.start_landing()
		tracks.clear()
	var fase := str(s.get("phase", ""))
	if fase == "operations" and actors.landed and not _tracks_seeded:
		_tracks_seeded = true
		tracks.seed_curve(actors.rover.global_position)
	elif fase == "workshop" or fase == "landing":
		_tracks_seeded = false
	if s.get("phase", "") == "report":
		actors.cancel_actions()
	audio.update_state(s, not actors.route.is_empty())


func blocked() -> bool:
	return state.is_empty() or state.get("paused", false) or state.get("safe_mode", false) or state.get("phase", "") != "operations" \
		or (story != null and story.is_open())


## Modo de colocación: se marca la zona de la base y el siguiente clic en una casilla libre pide la obra.
func start_placement(tipo: String) -> void:
	if blocked() or not state.has("base"):
		return
	if placing != tipo:
		_puestos.clear()
	placing = tipo
	hud.close_actions()
	var base: Dictionary = state["base"]
	var centro: Vector2i = base.get("center", Vector2i.ZERO)
	var radio := _radio_de(tipo)
	var validas: Array = []
	var ocupadas: Array = []
	for x in range(centro.x - radio, centro.x + radio + 1):
		for y in range(centro.y - radio, centro.y + radio + 1):
			var t := Vector2i(x, y)
			if not terrain.in_bounds(t):
				continue
			if _placement_valid(t):
				validas.append(t)
			else:
				ocupadas.append(t)
	buildings.show_zone(validas, ocupadas)
	if _puestos.is_empty():
		hud.show_notice("PLACE_WALL_NOTICE" if MurosView.es_muro(tipo) else "PLACE_NOTICE")


func cancel_placement() -> void:
	placing = ""
	_puestos.clear()
	buildings.hide_zone()
	terrain.hide_cursor()
	hud.set_hover_hint("")


## «+N recurso» flotando: sobre el rover cuando llena la bodega y sobre la base cuando descarga en el almacén.
func _textos_de_recursos(s: Dictionary) -> void:
	var recursos: Dictionary = s.get("resources", {})
	var bodega: Dictionary = (s.get("cargo", {}) as Dictionary).get("items", {})
	var antes_r: Dictionary = _antes.get("r", {})
	var antes_b: Dictionary = _antes.get("b", {})
	var jugando: bool = s.get("phase", "") == "operations" and not _antes.is_empty() and visible
	_antes = {"r": recursos.duplicate(), "b": bodega.duplicate()}
	if not jugando:
		return
	var sobre_rover: Vector3 = actors.rover.global_position + Vector3(0, 2.0, 0)
	var en_base: Vector3 = actors.station.global_position + Vector3(0, 2.6, 0)
	for r in bodega:
		var mas := int(bodega[r]) - int(antes_b.get(r, 0))
		if mas > 0:
			textos.mostrar(sobre_rover, "+%d %s" % [mas, tr("RES_" + str(r).to_upper())], (base_hud.COLORES as Dictionary).get(r, Color.WHITE))
	for r in recursos:
		var mas := int(recursos[r]) - int(antes_r.get(r, 0))
		if mas > 0:
			# Sin bodega (partidas antiguas) el recurso entra directo: el texto sale del rover.
			textos.mostrar(en_base if s.has("cargo") else sobre_rover, "+%d %s" % [mas, tr("RES_" + str(r).to_upper())],
				(base_hud.COLORES as Dictionary).get(r, Color.WHITE))


## Radio (en casillas desde la estación) donde se puede colocar «tipo»: los muros pueden ir un poco más afuera.
func _radio_de(tipo: String) -> int:
	var radio := int((state.get("base", {}) as Dictionary).get("radius", 0))
	for o in state.get("build_options", []):
		if o.get("id", "") == tipo:
			return radio + int(o.get("zone_extra", 0))
	return radio


## Pide un muro en «casilla» sin salir del modo de colocación (se pueden trazar varios seguidos arrastrando).
func _poner_muro(casilla: Vector2i) -> void:
	if _puestos.has(casilla) or not _placement_valid(casilla):
		return
	_puestos[casilla] = true
	port.submit("build", {"building": placing, "tile": casilla})
	start_placement(placing)


## Alcance en casillas de un edificio de defensa (0 si no dispara).
func _alcance_de(tipo: String) -> float:
	for o in state.get("build_options", []):
		if o.get("id", "") == tipo:
			return float(o.get("range", 0.0))
	return 0.0


func _placement_valid(tile: Vector2i) -> bool:
	if not state.has("base") or not terrain.in_bounds(tile):
		return false
	var base: Dictionary = state["base"]
	var d: Vector2i = tile - base.get("center", Vector2i.ZERO)
	if maxi(absi(d.x), absi(d.y)) > _radio_de(placing):
		return false
	return not _blocked_set().has(tile) and not _puestos.has(tile) and tile != state.get("rover_tile", Vector2i(9999, 9999))


func _command(command: String, payload: Dictionary) -> void:
	audio.unlock()
	if command == "grid":
		terrain.toggle_grid()
		return
	if command == "act" or command == "approach":
		payload["target_id"] = selected_target
	port.submit(command, payload)


func _input(e: InputEvent) -> void:
	if not placing.is_empty() and e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE:
		cancel_placement()
		get_viewport().set_input_as_handled()


func _report(value: Dictionary) -> void:
	cancel_placement()
	base_hud.close_menu()
	actors.cancel_actions()
	rig.enabled = false
	hud.visible = false
	terrain.hide_cursor()
	var final: Dictionary = value.get("ending", {})
	if final.is_empty():
		report_view.show_report(value)
	else:
		story.show_ending(final, func() -> void: report_view.show_report(value))
		if is_instance_valid(audio):
			audio.sfx("final_ok" if bool(value.get("success", false)) else "final_mal", 0.0)


func _process(_delta: float) -> void:
	if is_instance_valid(audio) and not state.is_empty():
		audio.update_state(state, not actors.route.is_empty())
	if not actors.landing_active:
		tracks.track(actors.rover.global_position)
	if actors.route.is_empty():
		terrain.clear_route()
	_update_hover()


## Cursor de destino y motivo cuando se señala fuera del área o una casilla bloqueada.
func _update_hover() -> void:
	if blocked() or hud.settings.visible or hud.review_panel.visible or not is_instance_valid(rig.camera):
		terrain.hide_cursor()
		hud.set_hover_hint("")
		return
	var mouse := get_viewport().get_mouse_position()
	if not placing.is_empty():
		var punto = ground_point(mouse)
		if punto == null or hud.root.get_viewport().gui_get_hovered_control() != null:
			terrain.hide_cursor()
			return
		var casilla := Vector2i(roundi(punto.x / 2.0), roundi(punto.z / 2.0))
		var valida := _placement_valid(casilla)
		terrain.show_cursor(casilla, valida)
		terrain.show_range(casilla, _alcance_de(placing) if valida else 0.0)
		# Muros: con el botón pulsado se traza la barrera casilla a casilla, como una línea.
		if valida and MurosView.es_muro(placing) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_poner_muro(casilla)
		hud.set_hover_hint(tr("PLACE_HINT") % tr("BLD_" + base_hud._clave(placing)) if valida else tr("TILE_BLOCKED"), mouse)
		return
	if hud.root.get_viewport().gui_get_hovered_control() != null or not pick_target(mouse).is_empty():
		terrain.hide_cursor()
		hud.set_hover_hint("")
		return
	var point = ground_point(mouse)
	if point == null:
		terrain.hide_cursor()
		hud.set_hover_hint("")
		return
	var tile := Vector2i(roundi(point.x / 2.0), roundi(point.z / 2.0))
	var dentro: bool = terrain.in_bounds(tile)
	var libre: bool = dentro and not _blocked_set().has(tile) or dentro and target_at_tile(tile) != ""
	if dentro or Vector2(point.x, point.z).length() < 34.0 + terrain.extra_size():
		terrain.show_cursor(tile, libre)
	else:
		terrain.hide_cursor()
	if not dentro:
		hud.set_hover_hint(tr("OUT_OF_BOUNDS"), mouse)
	elif not libre:
		hud.set_hover_hint(tr("HOVER_BLOCKED"), mouse)
	else:
		hud.set_hover_hint("")


## Punto del suelo bajo una posición de pantalla (plano y luego una corrección con la altura real).
func ground_point(screen: Vector2) -> Variant:
	var camera: Camera3D = rig.camera
	var origen := camera.project_ray_origin(screen)
	var direccion := camera.project_ray_normal(screen)
	var point = Plane(Vector3.UP, 0).intersects_ray(origen, direccion)
	if point == null:
		return null
	for i in range(2):
		var h: float = terrain.height_at(point.x, point.z)
		var corregido = Plane(Vector3.UP, h).intersects_ray(origen, direccion)
		if corregido == null:
			break
		point = corregido
	return point


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		audio.unlock()
	if e is InputEventKey and e.pressed and not e.echo:
		audio.unlock()
		if e.physical_keycode == KEY_F:
			rig.center_on(actors.rover.position)
	if blocked() or hud.settings.visible or hud.review_panel.visible:
		return
	if not placing.is_empty():
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_LEFT:
				var punto = ground_point(e.position)
				if punto != null:
					var casilla := Vector2i(roundi(punto.x / 2.0), roundi(punto.z / 2.0))
					if MurosView.es_muro(placing):
						if _placement_valid(casilla):
							_poner_muro(casilla)
						else:
							hud.show_notice("TILE_BLOCKED")
					elif _placement_valid(casilla):
						port.submit("build", {"building": placing, "tile": casilla})
						cancel_placement()
					else:
						hud.show_notice("TILE_BLOCKED")
			elif e.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var target := pick_target(e.position)
		if not target.is_empty():
			selected_target = target
			terrain.select(target)
			hud.set_target(target)
			port.submit("select", {"target_id": target})
			return
		var point = ground_point(e.position)
		if point == null:
			return
		var tile := Vector2i(roundi(point.x / 2.0), roundi(point.z / 2.0))
		# Un clic en la casilla de un objetivo revelado lo selecciona y lleva al rover a la casilla libre más cercana.
		var en_casilla := target_at_tile(tile)
		if not en_casilla.is_empty():
			selected_target = en_casilla
			terrain.select(en_casilla)
			hud.set_target(en_casilla)
			port.submit("select", {"target_id": en_casilla})
			port.submit("approach", {"target_id": en_casilla})
			return
		hud.close_actions()
		port.submit("move", {"tile": nearest_free_tile(tile)})


## Objetivo revelado cuya casilla es «tile» ("" si no hay).
func target_at_tile(tile: Vector2i) -> String:
	for t in state.get("targets", []):
		if t.get("revealed", false) and not t.get("depleted", false) and t.get("tile", Vector2i(9999, 9999)) == tile:
			return str(t["id"])
	return ""


## Casillas que el simulador no deja pisar: obstáculos, la estación y todos los objetivos.
func _blocked_tiles() -> Array[Vector2i]:
	var lista: Array[Vector2i] = []
	for o in state.get("obstacles", []):
		lista.append(o)
	if state.has("station_tile"):
		lista.append(state["station_tile"])
	for t in state.get("targets", []):
		if not t.get("depleted", false):
			lista.append(t["tile"])
	for b in state.get("buildings", []):
		lista.append(b["tile"])
	for n in state.get("nests", []):
		lista.append(n["tile"])
	return lista


## Lo mismo que _blocked_tiles() como diccionario (búsqueda directa), recalculado solo cuando cambia el mapa.
func _blocked_set() -> Dictionary:
	# Se rehace si cambia el mapa, un edificio o un objetivo agotado (que libera su casilla).
	var agotados := 0
	for t in state.get("targets", []):
		if t.get("depleted", false):
			agotados += 1
	var firma := "%s|%d|%d" % [map_signature, (state.get("buildings", []) as Array).size(), agotados]
	if _blocked_cache_revision != firma or _blocked_cache.is_empty():
		_blocked_cache.clear()
		for t in _blocked_tiles():
			_blocked_cache[t] = true
		_blocked_cache_revision = firma
	return _blocked_cache


## Casilla libre más cercana a «tile» (y al rover si hay empate). Si «tile» ya está libre, la devuelve igual.
func nearest_free_tile(tile: Vector2i) -> Vector2i:
	var bloqueadas := _blocked_set()
	var origen: Vector2i = state.get("rover_tile", Vector2i.ZERO)
	# Casillas a las que el rover sí puede llegar (relleno en 4 direcciones, como la ruta del simulador).
	var alcanzables := {origen: true}
	var cola: Array[Vector2i] = [origen]
	var i := 0
	while i < cola.size():
		var actual := cola[i]
		i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var sig: Vector2i = actual + d
			if alcanzables.has(sig) or not terrain.in_bounds(sig) or bloqueadas.has(sig):
				continue
			alcanzables[sig] = true
			cola.append(sig)
	if alcanzables.has(tile):
		return tile
	var mejor := tile
	var mejor_d := INF
	for c in alcanzables:
		var dist := Vector2(c).distance_to(Vector2(tile)) + Vector2(c).distance_to(Vector2(origen)) * 0.001
		if dist < mejor_d:
			mejor_d = dist
			mejor = c
	return mejor


## Posición en pantalla del objetivo (para el HUD): {"pos": Vector2, "behind": bool}; {} si no existe.
func project_target(id: String) -> Dictionary:
	if not terrain.targets.has(id) or rig == null or rig.camera == null:
		return {}
	var camera: Camera3D = rig.camera
	var world: Vector3 = terrain.targets[id].global_position + Vector3(0, 1.4, 0)
	if camera.is_position_behind(world):
		var local := camera.global_transform.affine_inverse() * world
		var size := get_viewport().get_visible_rect().size
		return {"pos": size / 2.0 + Vector2(local.x, absf(local.y) + 1.0).normalized() * size.length(), "behind": true}
	return {"pos": camera.unproject_position(world), "behind": false}


## Objetivo revelado más cercano al clic en pantalla (zona de 44×44 px), aunque lo tape una roca.
func pick_target(screen: Vector2) -> String:
	var best := ""
	var best_distance := 40.0
	for id in terrain.targets:
		if not terrain.targets[id].visible:
			continue
		var data := project_target(id)
		if data.is_empty() or data["behind"]:
			continue
		var d: float = screen.distance_to(data["pos"])
		if d < best_distance:
			best = id
			best_distance = d
	return best
