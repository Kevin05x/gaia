extends SceneTree
## Herramienta de desarrollo: graba tomas largas y fotos del juego, en la resolución que se pida, para montar el video de la entrega
## (motion graphics, tráiler). Juega de verdad: la misión real, sin interfaz, con la cámara girando alrededor.
## Cada toma sale como secuencia de imágenes JPG numeradas (frame_00001.jpg…) a 30 cuadros por segundo, más fotos PNG sueltas.
## El juego corre con un paso de tiempo fijo (--fixed-fps 30): la toma sale suave aunque el equipo dibuje despacio.
## Uso (necesita GPU), desde la carpeta del proyecto:
##   godot --rendering-driver opengl3 --path . --fixed-fps 30 -s tools/grabar_escenas.gd -- --toma=<nombre> --salida=<carpeta> [--res=3840x2160] [--seg=30]
## Tomas: marte_dia, marte_noche, luna_dia, aterrizaje, plataforma, despegue, hangar
const Sesion := preload("res://scenes/menu/game_session.gd")
const FPS := 30

var _args := {}
var _salida := ""
var _res := Vector2i(1920, 1080)
var _seg := 30
var _n := 0
var _quedan_fotos: Array[int] = []  ## cuadros en los que además se guarda una foto PNG


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--"):
			_args[s.get_slice("=", 0).trim_prefix("--")] = s.get_slice("=", 1) if s.contains("=") else "1"
	_salida = str(_args.get("salida", "user://tomas")).rstrip("/")
	var r := str(_args.get("res", "1920x1080")).split("x")
	_res = Vector2i(int(r[0]), int(r[1]))
	_seg = int(_args.get("seg", 30))
	_correr.call_deferred()


func _esperar(n: int) -> void:
	for i in range(n):
		await process_frame


func _correr() -> void:
	DisplayServer.window_set_size(_res)
	root.content_scale_size = Vector2i(1280, 720)
	var toma := str(_args.get("toma", "marte_dia"))
	var carpeta := _salida + "/" + toma
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta) if carpeta.begins_with("res://") else carpeta)
	Graficos.guardar_fps(false)
	match toma:
		"marte_dia":
			await _superficie("marte", carpeta, false)
		"marte_noche":
			await _superficie("marte", carpeta, true)
		"luna_dia":
			await _superficie("luna", carpeta, false)
		"aterrizaje":
			await _aterrizaje(carpeta)
		"plataforma":
			await _taller(carpeta, false)
		"despegue":
			await _taller(carpeta, true)
		"hangar":
			await _hangar(carpeta)
		_:
			push_error("toma desconocida: " + toma)
	print("TOMA %s lista: %d cuadros, %dx%d" % [toma, _n, root.get_texture().get_width(), root.get_texture().get_height()])
	quit()


## Guarda el cuadro actual (JPG de la secuencia) y, si toca, una foto PNG.
func _cuadro(carpeta: String, foto: String = "") -> void:
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	_n += 1
	var base := ProjectSettings.globalize_path(carpeta) if carpeta.begins_with("res://") else carpeta
	imagen.save_jpg("%s/frame_%05d.jpg" % [base, _n], 0.93)
	if not foto.is_empty():
		imagen.save_png("%s/foto_%s.png" % [base, foto])


func _listo_y_en(juego: Node, fase: String) -> void:
	for i in range(900):
		if juego.view.esta_listo():
			break
		await process_frame
	for i in range(4000):
		if juego.sim.estado.fase == fase:
			break
		await process_frame


## Quita la interfaz y los avisos para que quede solo el mundo.
func _limpiar(vista: Node) -> void:
	vista.hud.visible = false
	vista.tutorial.visible = false
	vista.story.radio_tapada = func() -> bool: return true
	if vista.objetivo.is_open():
		vista.objetivo.cerrar()
	if vista.story.is_open():
		vista.story.pulsar()
		vista.story.pulsar()
	if vista.get("base_hud") != null:
		vista.base_hud.visible = false


func _nuevo_juego(destino: String, saltar: bool) -> Node:
	Sesion.destino = destino
	Destino.id = destino
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	juego.saltar_taller = saltar
	root.add_child(juego)
	await _esperar(5)
	Destino.aplicar_textos()
	return juego


func _superficie(destino: String, carpeta: String, noche: bool) -> void:
	var juego: Node = await _nuevo_juego(destino, true)
	await _listo_y_en(juego, "landing")
	juego.port.submit("landing_finished")
	await _listo_y_en(juego, "operations")
	var vista: Node = juego.view
	var sim: Simulation = juego.sim
	await _esperar(40)
	_limpiar(vista)
	if noche:
		sim.estado.sol = 2
		sim.estado.hora = 19.7  # la primera oleada llega a las 20:00 (content/combate.json)
		sim.fijar_duracion_sol(45.0)  # un sol de 45 s: la oleada llega enseguida y la noche se ve entera
		juego._publicar()
	else:
		sim.estado.hora = 9.5
		juego._publicar()
	await _esperar(60)
	vista.rig.zoom_target = 17.0
	if noche and vista.actors.station != null:
		vista.rig.follow = vista.actors.station  # la cámara mira la base: ahí llegan las criaturas
		vista.rig.zoom_target = 24.0
	var cuadros := _seg * FPS
	var destinos := [Vector2i(5, 2), Vector2i(-3, 5), Vector2i(2, -5)]
	var origen: Vector2i = sim.estado.casilla_rover
	for i in range(cuadros):
		if not noche and i % (FPS * 8) == FPS:
			juego.port.submit("move", {"tile": origen + destinos[(i / (FPS * 8)) % destinos.size()]})
		vista.rig.yaw += deg_to_rad(0.35) if not noche else deg_to_rad(0.22)
		if i == cuadros / 2:
			vista.rig.zoom_target = 13.0 if not noche else 22.0
		await _cuadro(carpeta, "%02d" % (i / (FPS * 6)) if i % (FPS * 6) == 0 else "")


func _aterrizaje(carpeta: String) -> void:
	var juego: Node = await _nuevo_juego("marte", true)
	await _listo_y_en(juego, "landing")
	_limpiar(juego.view)
	var cuadros := _seg * FPS
	for i in range(cuadros):
		if juego.sim.estado.fase != "landing":
			break
		await _cuadro(carpeta, "%02d" % (i / (FPS * 5)) if i % (FPS * 5) == 0 else "")


func _taller(carpeta: String, hasta_despegue: bool) -> void:
	var juego: Node = await _nuevo_juego("marte", false)
	for i in range(900):
		if juego.view.esta_listo():
			break
		await process_frame
	await _esperar(30)
	var port = juego.port
	for id in ["cohete_super", "trayectoria_hohmann", "chasis_base", "mmrtg", "antena_rele", "espectrometro", "taladro", "camara"]:
		port.submit("design_add", {"part_id": id})
	var cuadros := _seg * FPS
	var lanzado := false
	for i in range(cuadros):
		if hasta_despegue and not lanzado and i == FPS * 12:
			port.submit("design_validate")
			port.submit("design_start")
			lanzado = true
		await _cuadro(carpeta, "%02d" % (i / (FPS * 5)) if i % (FPS * 5) == 0 else "")


func _hangar(carpeta: String) -> void:
	var juego: Node = await _nuevo_juego("marte", false)
	for i in range(900):
		if juego.view.esta_listo():
			break
		await process_frame
	await _esperar(30)
	var port = juego.port
	port.submit("design_add", {"part_id": "cohete_medio"})
	await _esperar(60)
	var piezas := ["trayectoria_hohmann", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro", "radar", "dron", "companero"]
	var cuadros := _seg * FPS
	for i in range(cuadros):
		if i % FPS == FPS / 2 and (i / FPS) < piezas.size():
			port.submit("design_add", {"part_id": piezas[i / FPS]})
		await _cuadro(carpeta, "%02d" % (i / (FPS * 5)) if i % (FPS * 5) == 0 else "")
