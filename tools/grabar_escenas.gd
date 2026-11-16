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
var _tam := Vector2i.ZERO
var _vista: Node = null  ## la vista de la misión (para esconder el cursor de casilla en cada cuadro)
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
	if _res == DisplayServer.screen_get_size():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)  # pantalla completa: el cuadro sale entero y exacto
	else:
		DisplayServer.window_set_size(_res)
	root.content_scale_size = Vector2i(1280, 720)
	await _esperar(5)
	var toma := str(_args.get("toma", "marte_dia"))
	var carpeta := _salida + "/" + toma
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(carpeta) if carpeta.begins_with("res://") else carpeta)
	Graficos.guardar_fps(false)
	# Gráficos en Ultra y sin calidad automática (no baja sola aunque el equipo dibuje despacio: la toma va a paso fijo y sale suave).
	var graficos_antes := Graficos.cargar()
	var ultra := Graficos.de_preset("ultra")
	ultra["auto"] = false
	Graficos.guardar(ultra)
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
		"base":
			await _construir_base(carpeta)
		"monstruos":
			await _batalla(carpeta, "ola_2", 3, 21.0)
		"coloso":
			await _batalla(carpeta, "ola_coloso", 5, 11.0)
		"batalla_final":
			await _batalla(carpeta, "ola_final", 6, 9.0)
		"hud":
			await _con_interfaz(carpeta, "marte")
		"hud_luna":
			await _con_interfaz(carpeta, "luna")
		"menu_construir":
			await _con_interfaz(carpeta, "marte", true)
		_:
			push_error("toma desconocida: " + toma)
	Graficos.guardar(graficos_antes)  # los ajustes del jugador vuelven a como estaban
	print("TOMA %s lista: %d cuadros de %dx%d" % [toma, _n, _tam.x, _tam.y])
	quit()


## Guarda el cuadro actual (JPG de la secuencia) y, si toca, una foto PNG.
func _cuadro(carpeta: String, foto: String = "") -> void:
	if _vista != null and is_instance_valid(_vista):
		_vista.terrain.hide_cursor()
		if _vista.get("tarjeta_nasa") != null:
			_vista.tarjeta_nasa.visible = false  # la tarjeta de «Dato real» tapa la toma
	await RenderingServer.frame_post_draw
	var imagen := root.get_texture().get_image()
	_tam = imagen.get_size()
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


## Cierra la introducción de la historia (5 pantallas) y la tarjeta de la NASA que tapan el taller.
func _cerrar_historia(vista: Node) -> void:
	for i in range(24):
		if vista.story.is_open():
			vista.story.pulsar()
		if vista.objetivo.is_open():
			vista.objetivo.cerrar()
		await _esperar(6)
	_vista = vista


## Quita la interfaz y los avisos para que quede solo el mundo.
func _limpiar(vista: Node) -> void:
	_vista = vista
	if vista.terrain.get("cursor") != null:
		vista.terrain.cursor.mesh = null  # el cuadrado blanco del destino del rover no sale en las tomas
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
		sim.estado.hora = 19.9  # la primera oleada llega a las 20:00 (content/combate.json)
		sim.fijar_duracion_sol(30.0)  # la hora corre deprisa solo hasta que sale la oleada; luego el reloj se queda de noche
		juego._publicar()
	else:
		sim.estado.hora = 9.5
		juego._publicar()
	await _esperar(60)
	vista.rig.zoom_target = 17.0
	if noche and vista.actors.station != null:
		vista.rig.follow = vista.actors.station  # la cámara mira la base: ahí llegan las criaturas
		vista.rig.zoom_target = 13.0
	var cuadros := _seg * FPS
	var destinos := [Vector2i(5, 2), Vector2i(-3, 5), Vector2i(2, -5)]
	var origen: Vector2i = sim.estado.casilla_rover
	for i in range(cuadros):
		if not noche and i % (FPS * 8) == FPS:
			juego.port.submit("move", {"tile": origen + destinos[(i / (FPS * 8)) % destinos.size()]})
		if noche and i > FPS * 2:
			sim.estado.hora = 21.0  # sigue de noche toda la toma
		if noche and i == FPS * 3:
			var k := 0
			for e in sim.estado.enemigos:  # las criaturas de la oleada aparecen alrededor de la base
				e["pos"] = Vector2(sim.estado.casilla_estacion) + Vector2.from_angle(float(k) * TAU / maxf(sim.estado.enemigos.size(), 1.0)) * (6.0 + float(k % 2) * 2.0)
				k += 1
		vista.rig.yaw += deg_to_rad(0.35) if not noche else deg_to_rad(0.2)
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


const LaunchPad := preload("res://scenes/b/launch_pad.gd")
const COHETES := [["cohete_ligero", 600.0, 39.0], ["cohete_medio", 900.0, 48.8], ["cohete_pesado", 1200.0, 58.3], ["cohete_super", 1800.0, 110.6]]


## Graba «seg» segundos seguidos (y una foto al principio de cada tramo si se pide).
func _grabar(carpeta: String, seg: float, foto: String = "") -> void:
	var n := int(seg * FPS)
	for i in range(n):
		await _cuadro(carpeta, foto if i == n / 2 else "")


func _taller(carpeta: String, hasta_despegue: bool) -> void:
	var juego: Node = await _nuevo_juego("marte", false)
	for i in range(900):
		if juego.view.esta_listo():
			break
		await process_frame
	await _esperar(30)
	await _cerrar_historia(juego.view)
	var pad = juego.view.launch_pad
	if not hasta_despegue:
		# Los cuatro lanzadores, uno tras otro, montándose a su escala real en la plataforma.
		for caso in COHETES:
			pad.elegido = ""
			pad._t_eleccion = -1.0
			pad._on_card(str(caso[0]), float(caso[1]), float(caso[2]))
			await _grabar(carpeta, pad._duracion_montaje() + 1.5, str(caso[0]))
		return
	# El lanzamiento completo: Saturno V, abordaje, diseño en el hangar y despegue.
	pad._on_card("cohete_super", 1800.0, 110.6)
	await _grabar(carpeta, pad._duracion_montaje() + 1.0, "montaje")
	pad._on_confirmar()
	await _grabar(carpeta, LaunchPad.DURACION_ABORDAJE + 1.0, "abordaje")
	var port = juego.port
	# Al confirmar el cohete el taller propone el diseño recomendado; con el Saturno V (400 M$) se pasa de 700: se quitan piezas hasta que cabe.
	for id in ["taladro", "camara", "espectrometro"]:
		port.submit("design_remove", {"part_id": id})
		await _grabar(carpeta, 0.8)
	await _grabar(carpeta, 1.5, "hangar")
	port.submit("design_validate")
	await _grabar(carpeta, 0.6)
	port.submit("design_start")
	var limite := 40 * FPS
	for i in range(limite):
		if juego.sim.estado.fase != "workshop" and i > FPS * 4:
			break
		await _cuadro(carpeta, "despegue" if i == FPS * 8 else "")
	await _grabar(carpeta, 30.0, "ascenso")  # el despegue y la subida del cohete


func _hangar(carpeta: String) -> void:
	var juego: Node = await _nuevo_juego("marte", false)
	for i in range(900):
		if juego.view.esta_listo():
			break
		await process_frame
	await _esperar(30)
	await _cerrar_historia(juego.view)
	var port = juego.port
	port.submit("design_add", {"part_id": "cohete_medio"})
	await _esperar(60)
	var piezas := ["trayectoria_hohmann", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro", "companero"]
	var cuadros := _seg * FPS
	for i in range(cuadros):
		if i % FPS == FPS / 2 and (i / FPS) < piezas.size():
			port.submit("design_add", {"part_id": piezas[i / FPS]})
		await _cuadro(carpeta, "%02d" % (i / (FPS * 5)) if i % (FPS * 5) == 0 else "")


## Una foto de la misión con la interfaz puesta (para la web del proyecto): el rover, el minimapa, la energía y los avisos.
func _con_interfaz(carpeta: String, destino: String, con_menu: bool = false) -> void:
	var juego: Node = await _nuevo_juego(destino, true)
	await _listo_y_en(juego, "landing")
	juego.port.submit("landing_finished")
	await _listo_y_en(juego, "operations")
	var vista: Node = juego.view
	await _esperar(40)
	vista.tutorial.visible = false
	vista.story.radio_tapada = func() -> bool: return true
	if vista.objetivo.is_open():
		vista.objetivo.cerrar()
	if vista.story.is_open():
		vista.story.pulsar()
		vista.story.pulsar()
	juego.sim.estado.hora = 10.0
	juego.sim.estado.bateria_wh = juego.sim.estado.bateria_capacidad_wh * 0.7  # batería a medias para ver cómo carga
	juego._publicar()
	await _esperar(300)  # que se apaguen los avisos pasajeros
	if con_menu:
		vista.base_hud.toggle_menu()  # el menú Construir (B), con «Construir antena» arriba
		await _esperar(30)
		await _cuadro(carpeta, "menu_construir")
		return
	await _cuadro(carpeta, "hud_" + destino)


## El rover construyendo la base de la estación pieza a pieza (con la antena y los muros con su puerta) y, al final, la base completa.
func _construir_base(carpeta: String) -> void:
	var juego: Node = await _nuevo_juego("marte", true)
	await _listo_y_en(juego, "landing")
	juego.port.submit("landing_finished")
	await _listo_y_en(juego, "operations")
	var vista: Node = juego.view
	var sim: Simulation = juego.sim
	await _esperar(40)
	_limpiar(vista)
	sim.fijar_duracion_sol(24.0)  # la obra dura horas de juego: así se ve entera en pocos segundos
	sim.estado.hora = 11.0
	sim.estado.recursos = {"rocas": 1500, "olivino": 600, "hielo": 300, "xenolito": 100}
	juego._publicar()
	await _esperar(30)
	var centro: Vector2i = sim.estado.casilla_estacion
	var sitios := [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4),
			Vector2i(3, 2), Vector2i(-3, -2)]
	# Primero la antena (nivel 1), luego el resto de la base; la antena sube de nivel cuando hay hangar.
	var trabajos: Array = [["upgrade", ""], ["build", "panel_solar"], ["build", "domo"], ["build", "luz"], ["build", "hangar"], ["upgrade", ""],
			["build", "extractor_hielo"], ["build", "panel_solar"], ["build", "torreta"], ["build", "luz"], ["upgrade", ""], ["build", "torreta"]]
	# Muro alrededor de la base (a 7 casillas, el límite de la zona de muros) con la puerta al sur y otra al este.
	var muros: Array[Vector2i] = []
	for d in range(-7, 8):
		for borde in [Vector2i(d, -7), Vector2i(d, 7), Vector2i(-7, d), Vector2i(7, d)]:
			if not muros.has(borde):
				muros.append(borde)
	var indice := 0
	var sitio := 0
	var muro := 0
	var fin_obras := -1
	var cuadros := _seg * FPS
	vista.rig.zoom_target = 15.0
	for i in range(cuadros):
		if indice < trabajos.size() and i % 15 == 0 and not sim._edificios.hay_obra(sim.estado):
			var trabajo: Array = trabajos[indice]
			var r: Dictionary
			if trabajo[0] == "upgrade":
				r = sim.ejecutar("upgrade", {})
			else:
				r = sim.ejecutar("build", {"building": trabajo[1], "tile": centro + sitios[sitio % sitios.size()]})
			if bool(r.get("ok", false)):
				indice += 1
				if trabajo[0] == "build":
					sitio += 1
			elif trabajo[0] == "build" and str(r.get("reason", "")) != "BUILD_BUSY":
				sitio += 1  # ese sitio no vale: se prueba otro
			elif trabajo[0] == "upgrade" and i > FPS * 90:
				indice += 1  # la antena no puede subir ahora: se sigue
		if i > FPS * 10 and i % 6 == 0 and muro < muros.size():  # los muros empiezan a los 10 s y se imprimen solos
			var casilla: Vector2i = centro + muros[muro]
			var tipo := "compuerta" if (muros[muro] == Vector2i(0, 7) or muros[muro] == Vector2i(7, 0)) else "barrera"
			sim.ejecutar("build", {"building": tipo, "tile": casilla})
			muro += 1
		if indice >= trabajos.size() and muro >= muros.size() and fin_obras < 0 and not sim._edificios.hay_obra(sim.estado) and not sim._edificios.hay_obra(sim.estado, true):
			fin_obras = i
		sim.estado.hora = 11.0  # siempre de día: la obra corre deprisa pero la luz no parpadea
		vista.rig.yaw += deg_to_rad(0.28)
		if fin_obras >= 0 and i == fin_obras + FPS * 3:
			vista.rig.follow = vista.actors.station  # terminada la obra: la base completa, desde más lejos
			vista.rig.zoom_target = 30.0
		await _cuadro(carpeta, "%02d" % (i / (FPS * 8)) if i % (FPS * 8) == 0 else "")
		if fin_obras >= 0 and i > fin_obras + FPS * 22:
			break


## Una oleada de criaturas contra la base ya construida (con torretas y muros): se prepara la defensa sin dibujar y se graba el ataque.
func _batalla(carpeta: String, ola: String, sol: int, hora: float) -> void:
	var juego: Node = await _nuevo_juego("marte", true)
	await _listo_y_en(juego, "landing")
	juego.port.submit("landing_finished")
	await _listo_y_en(juego, "operations")
	var vista: Node = juego.view
	var sim: Simulation = juego.sim
	await _esperar(40)
	_limpiar(vista)
	sim.fijar_duracion_sol(8.0)
	sim.estado.hora = 11.0
	sim.estado.recursos = {"rocas": 2500, "olivino": 900, "hielo": 400, "xenolito": 100}
	sim.estado.bateria_wh = sim.estado.bateria_capacidad_wh
	for id in ["ola_1", "ola_2", "ola_3", "ola_coloso", "ola_final"]:
		sim.estado.oleadas_hechas.append(id)  # ninguna sale mientras se prepara la defensa
	juego._publicar()
	var centro: Vector2i = sim.estado.casilla_estacion
	var sitios := [Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(4, 4), Vector2i(-4, 4), Vector2i(4, -4), Vector2i(-4, -4), Vector2i(3, 2), Vector2i(-3, -2), Vector2i(2, 4), Vector2i(-2, -4)]
	var trabajos: Array = ["hangar", "luz", "panel_solar", "torreta", "torreta", "torreta_2", "luz", "domo"]
	var muros: Array[Vector2i] = []
	for d in range(-7, 8):
		for borde in [Vector2i(d, -7), Vector2i(d, 7), Vector2i(-7, d), Vector2i(7, d)]:
			if not muros.has(borde):
				muros.append(borde)
	root.disable_3d = true  # la defensa se prepara sin dibujar: es mucho más rápido
	var indice := 0
	var sitio := 0
	var muro := 0
	for i in range(30 * 150):
		sim.estado.hora = 11.0
		sim.estado.bateria_wh = sim.estado.bateria_capacidad_wh
		if indice < trabajos.size() and i % 8 == 0 and not sim._edificios.hay_obra(sim.estado):
			var r := sim.ejecutar("build", {"building": trabajos[indice], "tile": centro + sitios[sitio % sitios.size()]})
			if bool(r.get("ok", false)):
				indice += 1
				sitio += 1
			elif str(r.get("reason", "")) != "BUILD_BUSY":
				sitio += 1
		if i % 3 == 0 and muro < muros.size():
			var tipo := "compuerta" if (muros[muro] == Vector2i(0, 7) or muros[muro] == Vector2i(7, 0)) else "barrera"
			sim.ejecutar("build", {"building": tipo, "tile": centro + muros[muro]})
			muro += 1
		await process_frame
		if indice >= trabajos.size() and muro >= muros.size() and not sim._edificios.hay_obra(sim.estado) and not sim._edificios.hay_obra(sim.estado, true):
			break
	await _esperar(60)
	root.disable_3d = false
	# Llega la oleada: se le quita a la lista de las ya hechas y se pone el reloj justo antes.
	sim.estado.oleadas_hechas.erase(ola)
	sim.estado.sol = sol
	sim.estado.hora = hora - 0.05
	sim.fijar_duracion_sol(30.0)
	vista.rig.follow = vista.actors.station
	vista.rig.zoom_target = 36.0  # lejos: el ataque ocurre contra los muros, a unos 30-40 m de la estación
	var noche := hora >= 19.0 or hora < 5.0
	var cuadros := _seg * FPS
	for i in range(cuadros):
		if i > FPS:
			sim.estado.hora = hora + (1.2 if noche else 0.4)  # el reloj se queda quieto: de día o de noche según la oleada
			sim.estado.bateria_wh = sim.estado.bateria_capacidad_wh
		if i == FPS * 2:
			var k := 0
			for e in sim.estado.enemigos:  # las criaturas salen de más cerca para que el ataque llegue pronto
				e["pos"] = Vector2(sim.estado.casilla_estacion) + Vector2.from_angle(float(k) * TAU / maxf(sim.estado.enemigos.size(), 1.0) + 0.4) * (15.0 + float(k % 3) * 1.5)
				e["hp"] = float(e["hp"]) * 10.0  # aguantan más: así se ve la batalla y no mueren de un tiro
				k += 1
		vista.rig.yaw += deg_to_rad(0.22)
		await _cuadro(carpeta, "%02d" % (i / (FPS * 6)) if i % (FPS * 6) == 0 else "")
