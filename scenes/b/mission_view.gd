extends Node3D
## Punto de entrada de la vista para A: instanciar mission.tscn y usar su nodo Port.
## Monta el mundo (terreno, actores, cámara que sigue al rover, luz por hora), el HUD y el informe,
## y traduce clics y teclas en órdenes. No contiene reglas de juego.
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
var audio: Node
var sun: DirectionalLight3D
var environment: Environment
var lighting: Node
var tracks: MeshInstance3D
var _tracks_seeded := false
var workshop: CanvasLayer
var state: Dictionary = {}
var inspection := false
var language := "es"
var volume := 0.65
var muted := false
var quality := true
var landing_in_progress := false
var selected_target := ""
var map_signature := ""
var _hover_tile := Vector2i(999, 999)
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
	port.snapshot_received.connect(apply_snapshot)
	port.report_received.connect(_report)
	port.path_received.connect(func(tiles: Array, seconds: float):
		actors.follow_path(tiles, seconds)
		terrain.show_route(tiles)
		terrain.flash_grid())
	port.action_received.connect(func(action: Dictionary):
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
	TranslationServer.set_locale(language)


func change_locale(locale: String) -> void:
	language = locale
	TranslationServer.set_locale(locale)
	hud.build()
	workshop.build()
	if not report_view.report.is_empty():
		report_view.rebuild()
	save_preferences()


func set_preferences(value: float, is_muted: bool, high_quality: bool, save: bool = true) -> void:
	volume = value
	muted = is_muted
	quality = high_quality
	audio.set_volume(volume, muted)
	lighting.quality = quality
	lighting.apply()
	W.quality = quality
	W.apply_quality()
	terrain.apply_quality()
	actors.dust.amount = 130 if quality else 36
	if save:
		save_preferences()


func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "language", language)
	config.set_value("audio", "volume", volume)
	config.set_value("audio", "muted", muted)
	config.set_value("visual", "quality", quality)
	config.save("user://b_preferences.cfg")


func apply_snapshot(s: Dictionary) -> void:
	state = s.duplicate(true)
	var signature := str(s.get("map_revision", 0))
	if map_signature != signature:
		terrain.configure(s.get("targets", []), s.get("obstacles", []), s.get("bounds", {}))
		map_signature = signature
		tracks.clear()
	var en_taller: bool = s.get("phase", "") == "workshop"
	terrain.visible = not en_taller
	actors.visible = not en_taller
	tracks.visible = not en_taller
	workshop.update_snapshot(s)
	terrain.update_targets(s.get("targets", []))
	terrain.select(selected_target)
	actors.apply_state(s)
	hud.update_snapshot(s)
	lighting.set_state(float(s.get("hour", 8.0)), float(s.get("dust", 0.0)))
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
	return state.is_empty() or state.get("paused", false) or state.get("safe_mode", false) or state.get("phase", "") != "operations"


func _command(command: String, payload: Dictionary) -> void:
	audio.unlock()
	if command == "grid":
		terrain.toggle_grid()
		return
	if command == "act" or command == "approach":
		payload["target_id"] = selected_target
	port.submit(command, payload)


func _report(value: Dictionary) -> void:
	actors.cancel_actions()
	rig.enabled = false
	hud.visible = false
	terrain.hide_cursor()
	report_view.show_report(value)


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
	var libre: bool = dentro and not tile in _blocked_tiles() or dentro and target_at_tile(tile) != ""
	if dentro or Vector2(point.x, point.z).length() < 34.0:
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
		if t.get("revealed", false) and t.get("tile", Vector2i(9999, 9999)) == tile:
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
		lista.append(t["tile"])
	return lista


## Casilla libre más cercana a «tile» (y al rover si hay empate). Si «tile» ya está libre, la devuelve igual.
func nearest_free_tile(tile: Vector2i) -> Vector2i:
	var bloqueadas := _blocked_tiles()
	if not terrain.in_bounds(tile) or not tile in bloqueadas:
		return tile
	var origen := Vector2(actors.rover.position.x / 2.0, actors.rover.position.z / 2.0)
	var mejor := tile
	var mejor_d := INF
	for radio in range(1, 5):
		for dx in range(-radio, radio + 1):
			for dy in range(-radio, radio + 1):
				if maxi(absi(dx), absi(dy)) != radio:
					continue
				var c := tile + Vector2i(dx, dy)
				if not terrain.in_bounds(c) or c in bloqueadas:
					continue
				var d := Vector2(c).distance_to(origen)
				if d < mejor_d:
					mejor_d = d
					mejor = c
		if mejor_d < INF:
			return mejor
	return tile


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
