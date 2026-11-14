extends GutTest
## Luces nocturnas de la base: se encienden de noche, se apagan de día y no pasan de un máximo (la web tiene pocas luces).

const Buildings := preload("res://scenes/b/buildings.gd")


func _base(edificios: Array) -> Node3D:
	var base := Buildings.new()
	base.ground = func(_x: float, _z: float) -> float: return 0.0
	add_child_autofree(base)
	base.update_state({"buildings": edificios})
	return base


func _edificio(id: String, tipo: String, tile: Vector2i, listo := true) -> Dictionary:
	return {"id": id, "type": tipo, "tile": tile, "level": 1, "building": not listo, "progress": 1.0 if listo else 0.3}


func _luces(base: Node3D) -> Array[OmniLight3D]:
	var lista: Array[OmniLight3D] = []
	for id in base._nodos:
		var modelo: Node3D = base._nodos[id]["model"]
		var luz := modelo.get_node_or_null("LuzNoche") as OmniLight3D
		if luz != null:
			lista.append(luz)
	return lista


func test_un_edificio_terminado_con_luz_la_tiene_apagada_de_dia() -> void:
	var base := _base([_edificio("h1", "hangar", Vector2i(1, 1))])
	var luces := _luces(base)
	assert_eq(luces.size(), 1)
	assert_false(luces[0].visible)


func test_de_noche_se_enciende_y_de_dia_se_apaga() -> void:
	var base := _base([_edificio("l1", "luz", Vector2i(1, 1))])
	base.set_night(1.0)
	var luz := _luces(base)[0]
	assert_true(luz.visible)
	assert_gt(luz.light_energy, 0.0)
	base.set_night(0.0)
	assert_false(luz.visible)


func test_una_obra_en_curso_no_tiene_luz() -> void:
	var base := _base([_edificio("h1", "hangar", Vector2i(1, 1), false)])
	assert_eq(_luces(base).size(), 0)


func test_un_panel_solar_no_tiene_luz() -> void:
	var base := _base([_edificio("p1", "panel_solar", Vector2i(1, 1))])
	assert_eq(_luces(base).size(), 0)


func test_no_se_encienden_mas_luces_que_el_maximo() -> void:
	var lista: Array = []
	for i in range(Buildings.MAX_LUCES + 4):
		lista.append(_edificio("l%d" % i, "luz", Vector2i(i * 2, 0)))
	var base := _base(lista)
	base.set_night(1.0)
	var encendidas := _luces(base).filter(func(l: OmniLight3D) -> bool: return l.visible).size()
	assert_eq(encendidas, Buildings.MAX_LUCES)
