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
