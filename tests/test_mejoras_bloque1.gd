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
