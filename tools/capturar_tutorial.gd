extends SceneTree
## Herramienta de desarrollo (plan de mejoras 2.2 y 2.3): saca las capturas reales de cada paso del tutorial jugando
## de verdad: arranca la misión, hace lo que pide el paso (mover el rover, elegir una roca, abrir Construir…) y
## fotografía la parte de la pantalla que el paso señala. Guarda JPG de 640×360 en
## assets/tutorial/<destino>/<idioma>/<paso>.jpg, para Marte y la Luna en español e inglés. Para «Cómo jugar» saca
## además el hangar (taller.jpg) y la plataforma de lanzamiento (plataforma.jpg) de Marte en los dos idiomas.
## Uso (necesita GPU):  godot --rendering-driver opengl3 --path . -s tools/capturar_tutorial.gd [-- <carpeta>]
## Sin carpeta escribe en res://assets/tutorial/. Después: godot --headless --path . --import (y revisar git status).

const Sesion := preload("res://scenes/menu/game_session.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const ANCHO := 1280
const ALTO := 720
const SALIDA := Vector2i(640, 360)
const RECORTE := Vector2(800, 450)  ## zona de la pantalla alrededor de lo que señala el paso (16:9)

var _salida := "res://assets/tutorial/"


func _initialize() -> void:
	_correr.call_deferred()


func _esperar(n: int) -> void:
	for i in range(n):
		await process_frame


func _correr() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_salida = args[0] if args[0].ends_with("/") else args[0] + "/"
	DisplayServer.window_set_size(Vector2i(ANCHO, ALTO))
	var fps_antes := Graficos.mostrar_fps()
	var idioma_antes := str(Texto.preferencias()["language"])
	Graficos.guardar_fps(false)  # el contador de rendimiento no sale en las capturas
	for destino in ["marte", "luna"]:
		for idioma in ["es", "en"]:
			Texto.guardar("ui", "language", idioma)  # la vista toma el idioma de las preferencias al arrancar
			await _capturar(destino, idioma)
	Sesion.destino = "marte"
	Destino.id = "marte"
	Destino.aplicar_textos()
	for idioma in ["es", "en"]:
		await _capturar_taller(idioma)
	Graficos.guardar_fps(fps_antes)
	Texto.guardar("ui", "language", idioma_antes)
	quit()


func _capturar(destino: String, idioma: String) -> void:
	Sesion.destino = destino
	TranslationServer.set_locale(idioma)
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	juego.saltar_taller = true
	root.add_child(juego)
	await _esperar(5)
	TranslationServer.set_locale(idioma)
	Destino.aplicar_textos()
	for i in range(600):
		if juego.view.esta_listo():
			break
		await process_frame
	var vista: Node = juego.view
	# El aterrizaje lo termina la propia vista al acabar su animación (como en el juego).
	for i in range(3000):
		if juego.sim.estado.fase == "operations":
			break
		await process_frame
	if juego.sim.estado.fase != "operations":
		juego.port.submit("landing_finished")
	await _esperar(60)
	vista.tutorial.visible = false  # la propia ventana del tutorial no sale en sus capturas
	vista.story.radio_tapada = func() -> bool: return true
	if vista.objetivo.is_open():
		vista.objetivo.cerrar()
	if vista.story.is_open():
		vista.story.pulsar()
		vista.story.pulsar()
	await _esperar(20)
	var sim: Simulation = juego.sim
	var carpeta := "%s%s/%s/" % [_salida, destino, idioma]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta) if carpeta.begins_with("res://") else carpeta)

	# 1) Mover: una ruta desde el rover.
	juego.port.submit("move", {"tile": sim.estado.casilla_rover + Vector2i(4, 2)})
	await _esperar(25)
	_guardar(carpeta + "mover.jpg", _centro())

	# 2) Analizar: una roca elegida con sus acciones (con el rover ya parado).
	for i in range(1200):
		if not sim.estado.en_movimiento:
			break
		await process_frame
	await _esperar(10)
	var objetivo := _objetivo_cercano(sim)
	if not objetivo.is_empty():
		juego.port.submit("approach", {"target_id": objetivo})
		for i in range(1200):
			if not sim.estado.en_movimiento:
				break
			await process_frame
		await _esperar(10)
		vista.selected_target = objetivo
		vista.terrain.select(objetivo)
		vista.hud.set_target(objetivo)
		juego.port.submit("select", {"target_id": objetivo})
		vista.rig.center_on(vista.terrain.targets[objetivo].global_position)
	await _esperar(25)
	_guardar(carpeta + "analizar.jpg", _zona(vista.hud.highlight_nodes().get("objetivo")))
	vista.hud.close_actions()

	# 2b) Acciones: el menú emergente (tecla Tab) con las herramientas del rover.
	vista.hud._abrir_acciones(true)
	await _esperar(12)
	_guardar(carpeta + "acciones.jpg", _zona(vista.hud.highlight_nodes().get("acciones"), true))
	vista.hud._abrir_acciones(false)

	# 2c) Carga: la bodega con algo dentro y el marcador sobre el almacén.
	sim.estado.carga = {"rocas": 37}
	juego._publicar()
	await _esperar(20)
	_guardar(carpeta + "carga.jpg", _centro())
	sim.estado.carga = {}
	juego._publicar()

	# 3) Panel y 4) Antena: el menú Construir abierto (con «Construir antena» arriba).
	vista.base_hud.toggle_menu()
	await _esperar(15)
	_guardar(carpeta + "panel.jpg", _zona(vista.base_hud.build_button, true))
	_guardar(carpeta + "antena.jpg", _zona(vista.base_hud.build_button, true))
	vista.base_hud.toggle_menu()

	# 5) Transmitir: el enlace con la Tierra (solo existe con antena).
	sim.estado.nivel_antena = 1
	juego._publicar()
	await _esperar(20)
	_guardar(carpeta + "transmitir.jpg", _zona(vista.hud.highlight_nodes().get("enlace")))

	# 6) Noche: la base cuando cae el sol.
	sim.estado.hora = 19.2
	juego._publicar()
	await _esperar(40)
	_guardar(carpeta + "noche.jpg", _centro())

	juego.queue_free()
	await _esperar(10)


## «Cómo jugar», páginas 2 y 3: la plataforma de lanzamiento con el cohete recomendado y el hangar con el diseño
## recomendado (Marte).
func _capturar_taller(idioma: String) -> void:
	TranslationServer.set_locale(idioma)
	var carpeta := "%smarte/%s/" % [_salida, idioma]
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo("res://content/mapa.json"), catalogo)
	var plataforma: CanvasLayer = preload("res://scenes/b/launch_pad.gd").new()
	root.add_child(plataforma)
	plataforma.update_snapshot(sim.snapshot())
	await _esperar(5)
	plataforma._t += plataforma._duracion_montaje() + 4.0  # el cohete ya montado
	await _esperar(60)
	_guardar(carpeta + "plataforma.jpg", _centro())
	plataforma.queue_free()
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar: CanvasLayer = preload("res://scenes/b/workshop.gd").new()
	root.add_child(hangar)
	hangar.command.connect(func(orden: String, carga: Dictionary) -> void:
		sim.ejecutar(orden, carga)
		hangar.update_snapshot(sim.snapshot()))
	hangar.update_snapshot(sim.snapshot())
	await _esperar(60)
	_guardar(carpeta + "taller.jpg", _centro())
	hangar.queue_free()
	await _esperar(5)


## Objetivo revelado más cerca del rover ("" si no hay).
func _objetivo_cercano(sim: Simulation) -> String:
	var mejor := ""
	var distancia := INF
	for t in sim.snapshot().get("targets", []):
		if t.get("revealed", false) and not t.get("depleted", false):
			var d := Vector2(t["tile"] - sim.estado.casilla_rover).length()
			if d < distancia:
				distancia = d
				mejor = str(t["id"])
	return mejor


func _centro() -> Rect2:
	return Rect2(Vector2(0, 0), Vector2(ANCHO, ALTO))


## Zona de 800×450 alrededor del control (sin salirse de la pantalla). «arriba»: el control queda abajo de la zona,
## para que se vea lo que se abre encima (el menú Construir).
func _zona(control: Control, arriba := false) -> Rect2:
	if control == null or not is_instance_valid(control):
		return _centro()
	var r := control.get_global_rect()
	var centro := r.get_center()
	if arriba:
		centro.y = r.end.y - RECORTE.y * 0.5 + 20.0
	var origen := (centro - RECORTE * 0.5).clamp(Vector2.ZERO, Vector2(ANCHO, ALTO) - RECORTE)
	return Rect2(origen, RECORTE)


func _guardar(ruta: String, zona: Rect2) -> void:
	var imagen := root.get_texture().get_image()
	var escala := Vector2(imagen.get_width(), imagen.get_height()) / Vector2(ANCHO, ALTO)
	var recorte := imagen.get_region(Rect2i(Vector2i(zona.position * escala), Vector2i(zona.size * escala)))
	recorte.resize(SALIDA.x, SALIDA.y, Image.INTERPOLATE_LANCZOS)
	var destino := ProjectSettings.globalize_path(ruta) if ruta.begins_with("res://") else ruta
	var error := recorte.save_jpg(destino, 0.85)
	print("%s -> %s" % [ruta, "ok" if error == OK else "ERROR %d" % error])
