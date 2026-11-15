extends SceneTree
## Herramienta de desarrollo: fotografía la plataforma de la Tierra y el hangar para revisar la
## composición sin abrir el juego. No forma parte de la partida.
## Uso (necesita GPU):  godot --rendering-driver opengl3 -s tools/capturar_taller.gd -- <carpeta>

const LaunchPad := preload("res://scenes/b/launch_pad.gd")

const ANCHO := 1280
const ALTO := 720


func _initialize() -> void:
	_correr.call_deferred()


func _correr() -> void:
	var salida := "user://"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		salida = args[0]
	if not salida.ends_with("/"):
		salida += "/"

	DisplayServer.window_set_size(Vector2i(ANCHO, ALTO))
	root.content_scale_size = Vector2i(ANCHO, ALTO)

	# Traducciones, igual que MissionView.setup_locale().
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")

	var sim := Simulation.new(
		Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"))

	# 1) Plataforma de la Tierra, sin cohete elegido.
	var plataforma: CanvasLayer = LaunchPad.new()
	root.add_child(plataforma)
	plataforma.update_snapshot(sim.snapshot())
	await _esperar(45)
	_guardar(salida + "1_plataforma.png")

	# 2) La misma, con un cohete marcado (se monta en el horizonte).
	# Un retrato por lanzador: comprueba la escala real de cada modelo y su animación de armado.
	var manifiesto := [["cohete_ligero", 600.0, 39.0], ["cohete_medio", 900.0, 48.8],
		["cohete_pesado", 1200.0, 58.3], ["cohete_super", 1800.0, 110.6]]
	# Las fases no se esperan contando cuadros: aquí los cuadros vuelan y el reloj de la pantalla va
	# en segundos de verdad, así que una espera de 500 cuadros pillaba el cohete a medio montar y la
	# captura de «listo» mentía. Se retrasa el instante de la elección y se deja asentar unos cuadros.
	for caso in manifiesto:
		plataforma.elegido = ""
		plataforma._t_eleccion = -1.0
		plataforma._on_card(str(caso[0]), float(caso[1]), float(caso[2]))
		await _avanzar(plataforma, plataforma._duracion_montaje() * 0.45)
		_guardar(salida + "2_%s_montando.png" % caso[0])
		await _avanzar(plataforma, plataforma._duracion_montaje() * 0.6 + 2.0)
		_guardar(salida + "2b_%s_listo.png" % caso[0])

	# 3) El abordaje: el rover rueda hasta la escotilla y entra en su cohete.
	plataforma.elegido = ""
	plataforma._t_eleccion = -1.0
	plataforma._on_card("cohete_medio", 900.0, 48.8)
	await _avanzar(plataforma, plataforma._duracion_montaje() + 2.0)
	plataforma._on_confirmar()
	await _avanzar(plataforma, LaunchPad.DURACION_ABORDAJE * 0.45)
	_guardar(salida + "3_abordando.png")
	await _avanzar(plataforma, LaunchPad.DURACION_ABORDAJE * 0.48)
	_guardar(salida + "3b_en_la_escotilla.png")

	# 3c) La vuelta: desde el hangar se pulsa «‹ Cambiar de cohete» y el rover sale del cohete.
	plataforma._fin_abordaje()
	plataforma._empezar_salida()
	await _avanzar(plataforma, LaunchPad.DURACION_ABORDAJE * 0.5)
	_guardar(salida + "3c_saliendo.png")

	# 3d) El despegue: se aparta el techo del edificio y el cohete sale por el hueco.
	plataforma._t_salida = -1.0
	plataforma.elegido = "cohete_medio"
	plataforma.despegar({})
	await _avanzar(plataforma, LaunchPad.DURACION_DESPEGUE * 0.42)
	_guardar(salida + "3d_techo_abriendo.png")
	await _avanzar(plataforma, LaunchPad.DURACION_DESPEGUE * 0.42)
	_guardar(salida + "3e_despegando.png")
	plataforma.visible = false

	# 4) El hangar con la barra lateral de instrumentos.
	for id in ["cohete_pesado", "chasis_base", "panel_solar", "antena_rele", "camara"]:
		sim.ejecutar("design_add", {"part_id": id})
	var hangar: CanvasLayer = preload("res://scenes/b/workshop.gd").new()
	root.add_child(hangar)
	hangar.category = "extras"
	hangar.update_snapshot(sim.snapshot())
	await _esperar(45)
	_guardar(salida + "4_hangar_sidebar.png")

	quit()


## Adelanta el reloj de la plataforma los segundos pedidos y deja pasar unos cuadros para que se
## dibuje. No se cuenta por cuadros porque aquí vuelan: esperar 500 cuadros pillaba el cohete a
## medio montar y la captura de «listo» mentía.
func _avanzar(plataforma: CanvasLayer, segundos: float) -> void:
	await _esperar(2)
	plataforma._t += segundos
	await _esperar(4)


func _esperar(cuadros: int) -> void:
	for i in range(cuadros):
		await process_frame


func _guardar(ruta: String) -> void:
	var imagen := root.get_texture().get_image()
	var error := imagen.save_png(ruta)
	print("%s -> %s" % [ruta, "ok" if error == OK else "ERROR %d" % error])
