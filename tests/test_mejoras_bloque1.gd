extends GutTest
## Plan de mejoras del 15 nov, bloque 1: errores que se ven en la primera partida (docs/PLAN_MEJORAS.md).


func before_all() -> void:
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


# --- 1.1 La cuadrícula no aparece sola al mover el rover -------------------------------------------------------------

func _vista_lista() -> Node:
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	add_child_autofree(juego)
	await get_tree().process_frame
	var vista: Node = juego.view
	for i in range(400):
		if vista.esta_listo():
			break
		await get_tree().process_frame
	return vista


func test_1_1_mover_el_rover_no_enciende_la_cuadricula() -> void:
	var vista: Node = await _vista_lista()
	assert_false(vista.terrain.grid_manual)
	vista.port.path_received.emit([Vector2i(1, 0), Vector2i(2, 0)], 1.0)
	for i in range(3):
		await get_tree().process_frame
	assert_false(vista.terrain.grid.visible, "con la cuadrícula apagada, una ruta no la muestra")
	vista.terrain.toggle_grid()
	await get_tree().process_frame
	assert_true(vista.terrain.grid.visible, "el botón (o la tecla) sí la muestra")
	vista.terrain.toggle_grid()
	await get_tree().process_frame
	assert_false(vista.terrain.grid.visible)


func test_1_1_la_cuadricula_se_ve_mientras_se_coloca_una_obra() -> void:
	var vista: Node = await _vista_lista()
	vista.terrain.grid_obra = true
	await get_tree().process_frame
	assert_true(vista.terrain.grid.visible, "en el modo construir se ve la cuadrícula")
	vista.cancel_placement()
	await get_tree().process_frame
	assert_false(vista.terrain.grid_obra, "al salir del modo construir se apaga")
	assert_false(vista.terrain.grid.visible)


# --- 1.2 Al abordar, el rover sube por la rampa en vez de atravesarla ------------------------------------------------

const LaunchPadScript := preload("res://scenes/b/launch_pad.gd")


func _plataforma(id: String, capacidad: float, alto: float) -> CanvasLayer:
	var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"))
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	plataforma._on_card(id, capacidad, alto)
	return plataforma


## Extremos de la cara de arriba de la rampa, en coordenadas del panorama: [pie, cima].
func _extremos_de_la_rampa(plataforma: CanvasLayer) -> Array:
	var rampa: MeshInstance3D = plataforma._rampa
	var caja := rampa.mesh as BoxMesh
	var t: Transform3D = plataforma._mesa.transform * rampa.transform
	var pie := t * Vector3(0.0, caja.size.y * 0.5, caja.size.z * 0.5)
	var cima := t * Vector3(0.0, caja.size.y * 0.5, -caja.size.z * 0.5)
	return [pie, cima]


func test_1_2_la_rampa_va_del_suelo_a_la_cubierta() -> void:
	for caso in [["cohete_ligero", 600.0, 39.0], ["cohete_super", 1800.0, 110.6]]:
		var plataforma := _plataforma(str(caso[0]), float(caso[1]), float(caso[2]))
		var extremos := _extremos_de_la_rampa(plataforma)
		assert_almost_eq(extremos[0].y, 0.0, 0.02, "%s: la rampa llega al suelo" % caso[0])
		assert_almost_eq(extremos[1].y, plataforma._mesa_alto, 0.02, "%s: y a la altura de la cubierta" % caso[0])
		assert_almost_eq(plataforma._puerta.position.y, plataforma._mesa_alto, 0.01,
			"%s: la escotilla está en la cubierta, al final de la rampa" % caso[0])


func test_1_2_el_rover_sube_por_la_rampa_sin_atravesarla() -> void:
	var plataforma := _plataforma("cohete_super", 1800.0, 110.6)
	var extremos := _extremos_de_la_rampa(plataforma)
	var pie: Vector3 = extremos[0]
	var cima: Vector3 = extremos[1]
	var en_la_rampa := 0
	var subio_inclinado := false
	for i in range(101):
		plataforma._abordar(i / 100.0)
		var rover: Node3D = plataforma._rover
		if not rover.visible:
			continue
		var z := rover.position.z
		if z < pie.z and z > cima.z:
			en_la_rampa += 1
			var suelo := lerpf(pie.y, cima.y, (pie.z - z) / (pie.z - cima.z))
			assert_gt(rover.position.y, suelo - 0.45, "a %.2f el rover no se hunde en la rampa" % (i / 100.0))
			if rover.rotation.x > 0.2:
				subio_inclinado = true
		elif z >= pie.z + 1.3:  # con las dos ruedas (delante y detrás) antes del pie de la rampa
			assert_almost_eq(rover.position.y, 0.0, 0.01, "delante de la rampa va por el suelo")
	assert_gt(en_la_rampa, 3, "el recorrido pasa por la rampa")
	assert_true(subio_inclinado, "y la sube con el morro hacia arriba")
	plataforma._abordar(0.0)
	assert_almost_eq(plataforma._rover.position.y, 0.0, 0.01, "al salir del todo vuelve al suelo")
	assert_almost_eq(plataforma._rover.rotation.x, 0.0, 0.01, "y derecho")


# --- 1.3 «Opciones» y «Código» no se montan uno sobre otro -----------------------------------------------------------

const WorkshopScript := preload("res://scenes/b/workshop.gd")


func test_1_3_opciones_y_codigo_van_en_fila_sin_montarse() -> void:
	for idioma in ["es", "en"]:
		TranslationServer.set_locale(idioma)
		var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
			Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo("res://content/mapa.json"),
			Catalog.desde_archivo("res://content/parts.json"))
		sim.ejecutar("design_add", {"part_id": "cohete_medio"})
		var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
		hangar.update_snapshot(sim.snapshot())
		await get_tree().process_frame
		await get_tree().process_frame
		var fila: HBoxContainer = hangar._fila_opciones
		assert_eq(fila.get_child_count(), 2, "Opciones y Código en la misma fila")
		var opciones := fila.get_child(0) as Button
		var codigo := fila.get_child(1) as Button
		var a := opciones.get_global_rect()
		var b := codigo.get_global_rect()
		assert_false(a.intersects(b), "%s: no se montan" % idioma)
		assert_gte(b.position.x - a.end.x, 6.0, "%s: con separación entre los dos" % idioma)
		for boton in [opciones, codigo]:
			assert_gte(boton.size.x + 0.5, boton.get_combined_minimum_size().x, "%s: el texto cabe en su botón" % idioma)
		assert_almost_eq(a.position.x, WorkshopScript.MARGEN, 0.5, "%s: alineada con el catálogo" % idioma)
		assert_lte(b.end.x, WorkshopScript.MARGEN + WorkshopScript.SIDEBAR_ANCHO + 0.5, "%s: del ancho del catálogo" % idioma)
		hangar.free()
	TranslationServer.set_locale("es")


# --- 1.4 Tamaño de ventana y pantalla completa: se guardan en un solo sitio y se respetan ---------------------------

const Texto := preload("res://scenes/menu/menu_text.gd")


func _con_preferencias_aparte(prueba: Callable) -> void:
	var habia := FileAccess.file_exists(Texto.PREFERENCIAS)
	var copia := FileAccess.get_file_as_bytes(Texto.PREFERENCIAS) if habia else PackedByteArray()
	prueba.call()
	if habia:
		FileAccess.open(Texto.PREFERENCIAS, FileAccess.WRITE).store_buffer(copia)
	elif FileAccess.file_exists(Texto.PREFERENCIAS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Texto.PREFERENCIAS))


func test_1_4_ventana_y_pantalla_completa_se_guardan_por_separado() -> void:
	_con_preferencias_aparte(func() -> void:
		Texto.guardar("audio", "volume", 0.3)
		Texto.poner_tamano_ventana(Vector2i(1920, 1080))
		var p := Texto.preferencias()
		assert_eq(p["window_size"], Vector2i(1920, 1080), "el tamaño elegido queda guardado")
		assert_false(p["fullscreen"], "elegir un tamaño de ventana sale de pantalla completa")
		Texto.poner_pantalla_completa(true)
		p = Texto.preferencias()
		assert_true(p["fullscreen"], "la pantalla completa también se guarda (antes se perdía al cerrar)")
		assert_eq(p["window_size"], Vector2i(1920, 1080), "y no borra el tamaño de ventana")
		assert_true(Texto.en_pantalla_completa())
		Texto.poner_pantalla_completa(false)
		p = Texto.preferencias()
		assert_false(p["fullscreen"])
		assert_eq(p["window_size"], Vector2i(1920, 1080), "al salir vuelve al último tamaño elegido")
		assert_almost_eq(float(p["volume"]), 0.3, 0.001, "sin tocar las demás preferencias"))


func test_1_4_se_ofrecen_tamanos_grandes_y_la_nativa() -> void:
	assert_true(Vector2i(2560, 1440) in Texto.TAMANOS_VENTANA, "hay 2560×1440")
	for idioma in ["es", "en"]:
		var plantilla: String = Texto.TABLES[idioma].get("M_SET_NATIVE", "")
		assert_eq(plantilla.count("%d"), 2, "%s: «Nativa» con su resolución" % idioma)
	var texto := Texto.texto_nativa(Vector2i(2560, 1440))
	assert_string_contains(texto, "2560×1440")


# --- 1.5 El texto de las escenas sale enseguida, con un fundido sobre la imagen ---------------------------------------

const StoryPanelScript := preload("res://scenes/b/story_panel.gd")


func test_1_5_el_texto_de_la_escena_sale_en_poco_mas_de_un_segundo() -> void:
	assert_almost_eq(StoryPanelScript.ESPERA_IMAGEN, 1.2, 0.001, "antes eran 5 s de imagen sola")
	var panel: CanvasLayer = StoryPanelScript.new()
	add_child_autofree(panel)
	panel.show_intro([{"es": "uno", "en": "one", "image": "aterrizaje"}])
	assert_false(panel._texto_visible, "primero la imagen")
	panel._process(1.3)
	assert_true(panel._texto_visible, "a los 1,2 s ya sale el texto")
	assert_lt(panel._capa.modulate.a, 1.0, "entra con un fundido, no de golpe")
	await get_tree().create_timer(0.7).timeout
	assert_almost_eq(panel._capa.modulate.a, 1.0, 0.01, "y el fundido termina")


# --- 1.6 El hangar muestra el paisaje del destino ---------------------------------------------------------------------

func test_1_6_el_hangar_muestra_el_paisaje_del_destino() -> void:
	var antes := Destino.id
	for caso in [["marte", WorkshopScript.FONDO_MARTE], ["luna", WorkshopScript.FONDO_LUNA]]:
		Destino.id = str(caso[0])
		var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
		var foto: Texture2D = hangar._fondo_material.albedo_texture
		assert_eq(foto.resource_path, caso[1], "%s: su propio paisaje por el portón" % caso[0])
		hangar.free()
	Destino.id = antes
	assert_ne(WorkshopScript.FONDO_LUNA, WorkshopScript.FONDO_MARTE)


# --- 1.7 Cada decisión de un imprevisto se ve: aviso con lo que cambió y, al desviarse, el rover sale al punto ---------

const ImprevistoPanelScript := preload("res://scenes/b/imprevisto_panel.gd")
const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]


func _sim_con_imprevistos(destino: String) -> Simulation:
	var cfg := Destino.config(destino)
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, destino, float(cfg.get("factor_capacidad_cohete", 1.0)))
	var sim := Simulation.new(Balance.desde_archivo(cfg.get("balance", "res://content/balance.json")),
		Rules.desde_archivo(cfg.get("reglas", "res://content/rules.json")),
		MapData.desde_archivo(cfg.get("mapa", "res://content/mapa.json")), catalogo,
		Economy.desde_archivo(cfg.get("economia", "res://content/economia.json")).para_pruebas())
	sim.usar_imprevistos(ImprevistosSystem.desde_archivo("res://content/imprevistos.json", destino), 7)
	for id in DISENO:
		sim.ejecutar("design_add", {"part_id": id})
	var diseno := ["mmrtg", "bateria", "radar"] if destino == "luna" else []
	for id in diseno:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	return sim


func test_1_7_cada_opcion_de_los_9_imprevistos_cuenta_lo_que_cambio() -> void:
	var vistos := {}
	for destino in ["marte", "luna"]:
		var sistema := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", destino)
		for id in sistema.imprevistos:
			for opcion in range((sistema.imprevistos[id]["opciones"] as Array).size()):
				var sim := _sim_con_imprevistos(destino)
				sim.estado.datos = 20.0
				sim.estado.imprevisto = {"id": id}
				var r := sim.ejecutar("event_choice", {"choice": opcion})
				assert_true(r["ok"], "%s/%d se puede elegir" % [id, opcion])
				assert_true(r.has("applied"), "%s/%d devuelve lo que cambió" % [id, opcion])
				var texto := ImprevistoPanelScript.resumen(r["applied"])
				assert_false(texto.is_empty(), "%s/%d tiene aviso" % [id, opcion])
				assert_false(texto.contains("UNEXP_"), "%s/%d: aviso traducido (%s)" % [id, opcion, texto])
				vistos[id] = true
	assert_eq(vistos.size(), 9, "se revisaron los 9 imprevistos")


func test_1_7_desviarse_manda_al_rover_al_punto_y_suma_10_datos() -> void:
	var sim := _sim_con_imprevistos("marte")
	var e := sim.estado
	e.datos = 0.0
	e.bateria_wh = e.bateria_capacidad_wh
	var bateria := e.bateria_wh
	var salida := e.casilla_rover
	e.imprevisto = {"id": "oportunidad"}
	var r := sim.ejecutar("event_choice", {"choice": 0})
	assert_true(r["ok"])
	var aplicado: Dictionary = r["applied"]
	assert_true(aplicado.has("detour_tile"), "hay un punto marcado")
	var punto: Vector2i = aplicado["detour_tile"]
	var distancia := maxi(absi(punto.x - salida.x), absi(punto.y - salida.y))
	assert_between(distancia, 3, 7, "a unas 5 casillas del rover")
	assert_false(Array(r["path"]).is_empty(), "con ruta para que la vista mueva al rover")
	assert_eq(Array(r["path"]).back(), punto, "la ruta acaba en el punto marcado")
	assert_true(e.en_movimiento, "el rover sale hacia el punto")
	assert_almost_eq(e.datos, 10.0, 0.01, "+10 datos en memoria al decidir")
	assert_almost_eq(bateria - e.bateria_wh, 90.0, 0.01, "los 90 Wh incluyen el viaje")
	assert_almost_eq(float(aplicado["energia_wh"]), -90.0, 0.01)
	var texto := ImprevistoPanelScript.resumen(aplicado)
	assert_string_contains(texto, "+10 datos en memoria")
	assert_string_contains(texto, "punto marcado")


func test_1_7_con_la_memoria_llena_el_aviso_cuenta_lo_perdido() -> void:
	var sim := _sim_con_imprevistos("marte")
	var e := sim.estado
	e.datos = e.memoria_capacidad - 4.0
	e.imprevisto = {"id": "oportunidad"}
	var r := sim.ejecutar("event_choice", {"choice": 0})
	var aplicado: Dictionary = r["applied"]
	assert_almost_eq(float(aplicado["datos"]), 4.0, 0.01, "solo caben 4")
	assert_almost_eq(float(aplicado["datos_perdidos"]), 6.0, 0.01, "y se pierden 6")
	assert_string_contains(ImprevistoPanelScript.resumen(aplicado), "6 datos perdidos: memoria llena")


func test_1_7_la_baliza_del_desvio_se_quita_al_llegar() -> void:
	var terreno: Node3D = load("res://scenes/b/terrain.gd").new()
	add_child_autofree(terreno)
	terreno.marcar_hallazgo(Vector2i(4, 2))
	assert_true(is_instance_valid(terreno.hallazgo))
	assert_eq(terreno.hallazgo_casilla, Vector2i(4, 2))
	terreno.quitar_hallazgo()
	assert_null(terreno.hallazgo)


func test_1_7_el_runner_presenta_la_ruta_del_desvio() -> void:
	var port: Node = autofree(preload("res://scenes/b/port.gd").new())
	var rutas: Array = []
	port.path_received.connect(func(casillas: Array, _s: float) -> void: rutas.append(casillas))
	var runner := MissionRunner.new()
	runner.crear_vista = false
	runner.saltar_taller = true
	runner.port = port
	add_child_autofree(runner)
	port.submit("landing_finished")
	runner.sim.usar_imprevistos(ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte"), 7)
	runner.sim.estado.bateria_wh = runner.sim.estado.bateria_capacidad_wh
	runner.sim.estado.imprevisto = {"id": "oportunidad"}
	port.submit("event_choice", {"choice": 0})
	assert_eq(rutas.size(), 1, "la vista recibe la ruta del desvío y mueve al rover")
	assert_true(runner.sim.estado.imprevisto.is_empty(), "la decisión quedó tomada")
