extends SceneTree
## Herramienta de desarrollo: fotografía el rover del juego (modelo oficial de la NASA) DE PERFIL, con fondo transparente, para la
## pantalla de carga de la web: el cuerpo sin ruedas, una rueda sola y dónde va cada rueda. tools/generar_shell_web.py los usa.
## Salida en assets/_blender/: rover_cuerpo.png, rover_rueda.png y rover_ruedas.json (centros de las ruedas en píxeles del cuerpo).
## Uso (necesita GPU):  godot --rendering-driver opengl3 -s tools/renderizar_rover.gd
const CARPETA := "res://assets/_blender/"
const ANCHO := 900
const ALTO := 520


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var vista := SubViewport.new()
	vista.size = Vector2i(ANCHO, ALTO)
	vista.transparent_bg = true
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vista)
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_CLEAR_COLOR
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("C79A7C")
	entorno.ambient_light_energy = 0.75
	entorno.tonemap_mode = Environment.TONE_MAPPER_REINHARDT
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.light_color = Color("FFE0BC")
	sol.light_energy = 1.2
	sol.rotation_degrees = Vector3(-35, -75, 0)
	vista.add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.light_color = Color("9AB4E0")
	relleno.light_energy = 0.3
	relleno.rotation_degrees = Vector3(-15, 100, 0)
	vista.add_child(relleno)
	var rover := RoverNasa.crear(0)
	if rover == null:
		push_error("no hay modelo del rover")
		quit(1)
		return
	vista.add_child(rover)
	var camara := Camera3D.new()
	camara.projection = Camera3D.PROJECTION_ORTHOGONAL
	vista.add_child(camara)
	var ruedas: Array[Node3D] = []
	for n in rover.find_children("Wheel*", "Node3D", true, false):
		ruedas.append(n as Node3D)
	var caja := _caja(rover)
	var centro := caja.get_center()
	camara.size = maxf(caja.size.y * 1.25, caja.size.z / (float(ANCHO) / ALTO) * 1.12)  # alto visible (m)
	camara.position = centro + Vector3(-20.0, 0.0, 0.0)  # desde -x: el frente del rover (-z) queda a la izquierda
	camara.look_at(centro, Vector3.UP)
	await _esperar()
	# Las ruedas de este lado (x < 0): su centro en pantalla.
	var cerca: Array = []
	for r in ruedas:
		var c := _caja(r).get_center()
		if c.x < centro.x:
			cerca.append({"nodo": r, "pos": camara.unproject_position(c)})
	cerca.sort_custom(func(a, b) -> bool: return a["pos"].x < b["pos"].x)
	# 1) el cuerpo, sin ruedas
	for r in ruedas:
		r.visible = false
	await _esperar()
	vista.get_texture().get_image().save_png(ProjectSettings.globalize_path(CARPETA + "rover_cuerpo.png"))
	# 2) una rueda sola (la de en medio de este lado)
	for r in ruedas:
		r.visible = false
	for h in rover.find_children("*", "VisualInstance3D", true, false):
		if not ruedas.any(func(r) -> bool: return r.is_ancestor_of(h) or r == h):
			(h as VisualInstance3D).visible = false
	var elegida: Node3D = cerca[cerca.size() / 2]["nodo"]
	elegida.visible = true
	for h in elegida.find_children("*", "VisualInstance3D", true, false):
		(h as VisualInstance3D).visible = true
	await _esperar()
	var pos_rueda: Vector2 = cerca[cerca.size() / 2]["pos"]
	var px_por_m := ALTO / camara.size
	var lado := int(0.525 * px_por_m * 1.2)
	var imagen := vista.get_texture().get_image()
	var recorte := Image.create(lado, lado, false, Image.FORMAT_RGBA8)
	recorte.blit_rect(imagen, Rect2i(int(pos_rueda.x) - lado / 2, int(pos_rueda.y) - lado / 2, lado, lado), Vector2i.ZERO)
	recorte.save_png(ProjectSettings.globalize_path(CARPETA + "rover_rueda.png"))
	var datos := {"ancho": ANCHO, "alto": ALTO, "lado_rueda": lado, "ruedas": []}
	for c in cerca:
		datos["ruedas"].append([c["pos"].x, c["pos"].y])
	var f := FileAccess.open(ProjectSettings.globalize_path(CARPETA + "rover_ruedas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(datos))
	f.close()
	print("ROVER ", datos)
	quit()


func _esperar() -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw


func _caja(raiz: Node3D) -> AABB:
	var caja := AABB()
	var primera := true
	for m in raiz.find_children("*", "VisualInstance3D", true, false):
		var vi := m as VisualInstance3D
		if not vi.visible:
			continue
		var b := vi.global_transform * vi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	if raiz is VisualInstance3D and primera:
		var vi := raiz as VisualInstance3D
		return vi.global_transform * vi.get_aabb()
	return caja
