extends GutTest
## Animación de obra (de abajo hacia arriba, con andamio y tiempo restante) y explosiones con restos.

const Buildings := preload("res://scenes/b/buildings.gd")
const Explosion := preload("res://scenes/b/explosion_fx.gd")
const Art := preload("res://scenes/b/art.gd")


func _edificio(id: String, tipo: String, nivel: int, obra: bool, progreso: float = 0.5, restante: float = 6.0) -> Dictionary:
	return {"id": id, "type": tipo, "tile": Vector2i(2, 2), "level": nivel, "building": obra, "progress": progreso,
		"remaining_s": restante, "active": true, "hp": 100.0, "hp_max": 100.0}


func test_formato_del_tiempo_restante() -> void:
	assert_eq(BuildFx.formato_tiempo(0.2), "1 s")
	assert_eq(BuildFx.formato_tiempo(12.0), "12 s")
	assert_eq(BuildFx.formato_tiempo(65.0), "1:05")
	assert_eq(BuildFx.formato_tiempo(-3.0), "0 s")


func test_el_edificio_en_obra_usa_el_material_de_revelado_y_mide_su_altura() -> void:
	var modelo := Node3D.new()
	add_child_autofree(modelo)
	Art.box(modelo, Vector3(1, 2, 1), Vector3(0, 1, 0), Color("B7A796"))
	var info := BuildFx.preparar(modelo)
	assert_eq((info["mats"] as Array).size(), 1)
	assert_almost_eq(float(info["alto"]), 2.0, 0.01)
	var malla := modelo.get_child(0) as MeshInstance3D
	assert_true(malla.material_override is ShaderMaterial)
	BuildFx.revelar(info, 0.0, 1.0)
	assert_eq(float((info["mats"][0] as ShaderMaterial).get_shader_parameter("reveal_h")), 1.0)


func test_medir_sin_convertir_no_cambia_los_materiales() -> void:
	var modelo := Node3D.new()
	add_child_autofree(modelo)
	Art.box(modelo, Vector3(1, 2, 1), Vector3(0, 1, 0), Color("B7A796"))
	var info := BuildFx.preparar(modelo, false)
	assert_true((info["mats"] as Array).is_empty())
	assert_false((modelo.get_child(0) as MeshInstance3D).material_override is ShaderMaterial)
	assert_almost_eq(float(info["alto"]), 2.0, 0.01)


func test_la_obra_muestra_andamio_tiempo_y_barra_y_al_terminar_lo_quita() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	vista.update_state({"buildings": [_edificio("domo-1", "domo", 0, true, 0.5, 6.0)]})
	var nodo := vista.get_node("domo-1") as Node3D
	var texto := nodo.get_node("ObraTiempo") as Label3D
	assert_true(texto.visible)
	assert_eq(texto.text, "6 s")
	assert_not_null(nodo.find_child("Andamio", true, false))
	vista.update_state({"buildings": [_edificio("domo-1", "domo", 1, false)]})
	await get_tree().process_frame
	assert_false((vista.get_node("domo-1/ObraTiempo") as Label3D).visible)
	assert_null(vista.get_node("domo-1").find_child("Andamio", true, false), "el andamio se retira")


func test_se_avisa_cuando_empieza_y_termina_una_obra() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	watch_signals(vista)
	vista.update_state({"buildings": [_edificio("torreta-1", "torreta", 0, true, 0.0, 6.0)]})
	assert_signal_emitted(vista, "building_started")
	vista.update_state({"buildings": [_edificio("torreta-1", "torreta", 1, false)]})
	assert_signal_emitted(vista, "building_done")
	assert_signal_not_emitted(vista, "building_lost")


func test_al_destruirse_un_edificio_se_avisa_con_su_tipo() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	vista.update_state({"buildings": [_edificio("torreta-1", "torreta", 1, false)]})
	watch_signals(vista)
	vista.update_state({"buildings": []})
	assert_signal_emitted(vista, "building_lost")
	assert_eq(get_signal_parameters(vista, "building_lost", 0)[1], "torreta")


func test_la_nave_avisa_cuando_pierde_un_modulo() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 3, false)]})
	watch_signals(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 2, false)]})
	assert_signal_emitted(vista, "module_lost")
	assert_signal_not_emitted(vista, "building_done")


func test_la_nave_avisa_si_pierde_el_modulo_que_estaba_en_obra() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 2, true, 0.4)]})
	watch_signals(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 2, false)]})
	assert_signal_emitted(vista, "module_lost")
	assert_signal_not_emitted(vista, "building_done")


func test_terminar_un_modulo_de_la_nave_es_una_obra_terminada() -> void:
	var vista := Buildings.new()
	add_child_autofree(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 1, true, 0.9)]})
	watch_signals(vista)
	vista.update_state({"buildings": [_edificio("nave_fuga-1", "nave_fuga", 2, false)]})
	assert_signal_emitted(vista, "building_done")
	assert_signal_not_emitted(vista, "module_lost")


func test_la_explosion_lanza_restos_y_se_apaga_sola() -> void:
	var fx := Explosion.new()
	add_child_autofree(fx)
	assert_eq(fx.activos(), 0)
	fx.explotar(Vector3(0, 1, 0), 1.0, 10)
	assert_gt(fx.activos(), 10, "restos, bola de fuego, humo y anillo")
	var visibles := 0
	for r in fx._restos:
		if r["node"].visible:
			visibles += 1
	assert_eq(visibles, 10)
	for i in range(60):
		fx._process(0.1)
	assert_eq(fx.activos(), 0, "todo termina por sí solo")
	assert_false(fx.is_processing())


func test_los_restos_caen_y_no_atraviesan_el_suelo() -> void:
	var fx := Explosion.new()
	fx.ground = func(_x: float, _z: float) -> float: return 0.5
	add_child_autofree(fx)
	fx.explotar(Vector3(0, 1, 0), 1.0, 6)
	for i in range(14):
		fx._process(0.1)
	for r in fx._restos:
		if not r["libre"]:
			assert_gte((r["node"] as Node3D).position.y, 0.5, "no queda bajo tierra")


func test_la_simulacion_informa_cuanto_falta_de_cada_obra() -> void:
	var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"), StoryData.desde_archivo("res://content/historia.json"),
		CombatData.desde_archivo("res://content/combate.json"), null)
	sim.estado.edificios.append({"id": "torreta-1", "type": "torreta", "tile": Vector2i(1, 1), "level": 0, "target_level": 1,
		"elapsed": 2.0, "seconds": 6.0, "active": true, "hp": 120.0, "produced": 0.0, "cd": 0.0})
	assert_almost_eq(float(_vista(sim, "torreta-1")["remaining_s"]), 4.0, 0.001)
	sim.estado.edificios[sim.estado.edificios.size() - 1]["level"] = 1
	assert_eq(float(_vista(sim, "torreta-1")["remaining_s"]), 0.0)


func _vista(sim: Simulation, id: String) -> Dictionary:
	for e in sim._edificios.para_la_vista(sim.estado):
		if e["id"] == id:
			return e
	return {}
