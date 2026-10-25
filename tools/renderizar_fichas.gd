extends SceneTree
## Herramienta de desarrollo: fotografía cada edificio (los mismos modelos del juego) y guarda su imagen para las
## fichas del menú de construcción en assets/edificios/<tipo>.png (fondo transparente, 3/4 desde arriba).
## Uso (necesita GPU o xvfb):  godot --rendering-driver opengl3 -s tools/renderizar_fichas.gd
const TIPOS := ["panel_solar", "luz", "domo", "extractor_hielo", "hangar", "torreta", "torreta_2", "antena", "nave_fuga"]
const LADO := 384
const SALIDA := "res://assets/edificios/"


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(LADO, LADO)
	vista.transparent_bg = true
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("BE8F74")
	entorno.ambient_light_energy = 0.55
	entorno.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	entorno.tonemap_exposure = 0.95
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("FFE0BC")
	sol.light_energy = 1.05
	sol.rotation_degrees = Vector3(-42, -35, 0)
	vista.add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.light_color = Color("9AB4E0")
	relleno.light_energy = 0.25
	relleno.rotation_degrees = Vector3(-20, 150, 0)
	vista.add_child(relleno)
	var camara := Camera3D.new()
	camara.fov = 30.0
	vista.add_child(camara)
	var edificios: Node3D = load("res://scenes/b/buildings.gd").new()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SALIDA))
	for tipo in TIPOS:
		var modelo := Node3D.new()
		vista.add_child(modelo)
		var nivel := 4 if tipo == "nave_fuga" else (3 if tipo == "antena" else 1)
		edificios._modelo(modelo, tipo, nivel, false, nivel)
		var caja := _caja(modelo)
		var centro := caja.get_center()
		var radio := caja.size.length() * 0.5
		var distancia := radio / sin(deg_to_rad(camara.fov * 0.5)) * 1.02
		var direccion := (Vector3(0.75, 0.42, -0.5) if tipo == "panel_solar" else Vector3(0.62, 0.52, 0.82)).normalized()
		camara.position = centro + direccion * distancia
		camara.look_at(centro, Vector3.UP)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var imagen := vista.get_texture().get_image()
		imagen.save_png(SALIDA + tipo + ".png")
		print("FICHA ", tipo, " ", imagen.get_size())
		modelo.queue_free()
		await process_frame
	edificios.free()
	quit()


func _caja(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for m in raiz.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		var b := vi.global_transform * vi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	return caja
