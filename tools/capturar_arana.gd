extends SceneTree
## Herramienta de desarrollo: fotografía las criaturas del combate (araña, Void Biter, Coloso) para revisar su diseño.
## Uso (necesita GPU):  godot --rendering-driver opengl3 -s tools/capturar_arana.gd -- <carpeta>
const Combate := preload("res://scenes/b/combat_view.gd")


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var salida := "user://"
	for a in OS.get_cmdline_user_args():
		salida = a
	if not salida.ends_with("/"):
		salida += "/"
	var vista := SubViewport.new()
	vista.size = Vector2i(900, 560)
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("1b2433")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("5a6c8f")
	entorno.ambient_light_energy = 1.1
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var luna := DirectionalLight3D.new()
	luna.light_color = Color("c7d4ff")
	luna.light_energy = 1.6
	luna.rotation_degrees = Vector3(-40, -30, 0)
	vista.add_child(luna)
	var combate: Node3D = Combate.new()
	var camara := Camera3D.new()
	camara.fov = 35.0
	vista.add_child(camara)
	var n := 0
	for tipo in ["arana", "void_biter", "coloso"]:
		var modelo: Node3D = combate._plantilla(tipo).duplicate()
		vista.add_child(modelo)
		var escala := 0.45 if tipo == "coloso" else 1.0
		camara.position = Vector3(2.4, 1.9, -3.2) * (3.2 if tipo == "coloso" else 1.0) * escala + Vector3(0, 0.3, 0)
		camara.look_at(Vector3(0, 0.5 * (3.0 if tipo == "coloso" else 1.0), 0), Vector3.UP)
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		vista.get_texture().get_image().save_png(ProjectSettings.globalize_path(salida + "criatura_%s.png" % tipo))
		print("CRIATURA ", tipo)
		modelo.queue_free()
		await process_frame
		n += 1
	quit()
