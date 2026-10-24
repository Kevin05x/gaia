extends GutTest
## Partida guardada: la simulación entrega su estado, se escribe como texto y otra simulación lo restaura igual.

const Sesion := preload("res://scenes/menu/game_session.gd")
const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

var sim: Simulation


func _nueva() -> Simulation:
	return Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"))


func before_each() -> void:
	sim = _nueva()


func _operar(simulacion: Simulation) -> void:
	for id in DISENO:
		assert_true(simulacion.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(simulacion.ejecutar("design_start")["ok"])
	assert_true(simulacion.ejecutar("landing_finished")["ok"])


func test_guardar_y_cargar_deja_la_misma_mision() -> void:
	_operar(sim)
	sim.ejecutar("move", {"tile": Vector2i(2, 1)})
	for i in range(900):
		sim.avanzar(0.2)
	var antes := sim.snapshot()
	var datos := sim.guardar()
	var otra := _nueva()
	assert_true(otra.cargar(str_to_var(var_to_str(datos))), "se carga lo que se escribió como texto")
	var despues := otra.snapshot()
	for clave in ["phase", "sol", "hour", "rover_tile", "station_tile", "data", "sent", "mineral", "antenna_level", "design", "bounds"]:
		assert_eq(despues[clave], antes[clave], clave)
	assert_almost_eq(float(despues["battery"]["wh"]), float(antes["battery"]["wh"]), 0.001)
	assert_eq(despues["targets"].size(), antes["targets"].size())
	assert_eq(despues["obstacles"], antes["obstacles"])


func test_la_partida_cargada_sigue_jugandose() -> void:
	_operar(sim)
	for i in range(300):
		sim.avanzar(0.2)
	var otra := _nueva()
	assert_true(otra.cargar(sim.guardar()))
	var hora := float(otra.snapshot()["hour"])
	for i in range(100):
		otra.avanzar(0.2)
	assert_gt(float(otra.snapshot()["hour"]), hora, "el reloj avanza después de cargar")
	assert_true(otra.ejecutar("move", {"tile": Vector2i(1, 0)})["ok"], "se aceptan órdenes")
	assert_eq(otra.snapshot()["design"]["instruments"], sim.snapshot()["design"]["instruments"])


func test_no_se_restauran_movimientos_ni_acciones_en_curso() -> void:
	_operar(sim)
	sim.ejecutar("move", {"tile": Vector2i(3, 3)})
	sim.avanzar(0.3)
	var otra := _nueva()
	assert_true(otra.cargar(sim.guardar()))
	var s := otra.snapshot()
	assert_false(s["moving"])
	assert_false(s["busy"])
	assert_false(s["paused"])


func test_datos_invalidos_no_se_cargan_ni_cambian_la_simulacion() -> void:
	_operar(sim)
	var antes: int = int(sim.snapshot()["sol"])
	assert_false(sim.cargar({}))
	assert_false(sim.cargar({"version": 2, "estado": {}, "diseno": {}}))
	assert_false(sim.cargar({"version": 1, "estado": {"fase": "workshop"}, "diseno": {}}), "solo partidas en operaciones")
	assert_eq(sim.snapshot()["sol"], antes)
	assert_eq(sim.snapshot()["phase"], "operations")


func test_sesion_escribe_lee_y_resume_la_partida() -> void:
	_operar(sim)
	Sesion.borrar()
	assert_false(Sesion.hay_guardado())
	assert_true(Sesion.guardar(sim))
	assert_true(Sesion.hay_guardado())
	var resumen := Sesion.resumen()
	assert_eq(resumen["sol"], 1)
	assert_eq(resumen["meta"], 100)
	var otra := _nueva()
	assert_true(otra.cargar(Sesion.leer()))
	Sesion.borrar()
	assert_false(Sesion.hay_guardado())
