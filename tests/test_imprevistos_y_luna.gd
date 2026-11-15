extends GutTest
## Imprevistos de misión (content/imprevistos.json) y destino Luna (content/destinos.json): carga, programación con
## semilla, tiempo detenido, consecuencias de cada opción, bloqueos de enlace y movimiento, y una misión lunar completa
## que se juega sin historia ni combate.

const DISENO_MARTE: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]
const DISENO_LUNA: Array[String] = ["cohete_ligero", "chasis_base", "mmrtg", "antena_rele", "camara", "espectrometro", "taladro", "radar", "bateria"]


func _sim_marte() -> Simulation:
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	return Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), catalogo, Economy.desde_archivo("res://content/economia.json"))


func _sim_luna() -> Simulation:
	var cfg := Destino.config("luna")
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "luna", float(cfg["factor_capacidad_cohete"]))
	return Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]), MapData.desde_archivo(cfg["mapa"]),
		catalogo, Economy.desde_archivo(cfg["economia"]), null, null, TutorialData.desde_archivo(cfg["tutorial"]),
		HitosData.desde_archivo(cfg["hitos"]))


func _operar(sim: Simulation, diseno: Array[String]) -> void:
	for id in diseno:
		assert_true(sim.ejecutar("design_add", {"part_id": id})["ok"], "pieza %s" % id)
	assert_true(sim.ejecutar("design_start")["ok"], "el diseño es válido")
	sim.ejecutar("landing_finished")
	sim.ejecutar("tutorial_skip")  # el tutorial detiene el reloj; estas pruebas miden la misión


func test_cada_destino_tiene_sus_imprevistos() -> void:
	var marte := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte")
	var luna := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "luna")
	assert_eq(marte.errores.size(), 0)
	assert_true(marte.imprevistos.has("conjuncion_solar"))
	assert_false(marte.imprevistos.has("particulas_solares"))
	assert_true(luna.imprevistos.has("particulas_solares"))
	assert_false(luna.imprevistos.has("conjuncion_solar"), "en la Luna no hay conjunción solar con la Tierra")
	assert_gte(marte.imprevistos.size(), 3)
	assert_gte(luna.imprevistos.size(), 3)


func test_la_misma_semilla_programa_lo_mismo() -> void:
	var sistema := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte")
	var a := _sim_marte()
	var b := _sim_marte()
	sistema.programar(a.estado, 42)
	sistema.programar(b.estado, 42)
	assert_eq(a.estado.imprevistos_programa, b.estado.imprevistos_programa)
	assert_eq(a.estado.imprevistos_programa.size(), 3)
	var anterior := -1.0
	for p in a.estado.imprevistos_programa:
		assert_gt(float(p["t"]), anterior, "en orden")
		assert_gte(float(p["t"]), 0.6 * 24.0, "no antes del sol 1,6")
		anterior = float(p["t"])


func test_el_imprevisto_detiene_el_tiempo_y_la_decision_lo_reanuda() -> void:
	var sim := _sim_marte()
	sim.usar_imprevistos(ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte"), 7)
	_operar(sim, DISENO_MARTE)
	sim.avanzar(0.1)
	assert_true(sim.estado.imprevistos_programados)
	# Adelanta el primero para no esperar dos soles.
	sim.estado.imprevistos_programa[0]["t"] = ImprevistosSystem.t_abs(sim.estado) + 0.05
	var vistos: Array[String] = []
	for i in range(40):
		vistos.append_array(sim.avanzar(0.25))
		if not sim.estado.imprevisto.is_empty():
			break
	assert_false(sim.estado.imprevisto.is_empty(), "llegó el imprevisto")
	assert_true(sim.snapshot().has("unexpected"))
	assert_eq((sim.snapshot()["unexpected"]["options"] as Array).size(), 2)
	var hora := sim.estado.hora
	sim.avanzar(1.0)
	assert_eq(sim.estado.hora, hora, "el tiempo no corre mientras se decide")
	assert_false(sim.ejecutar("event_choice", {"choice": 5})["ok"], "opción inexistente")
	assert_true(sim.ejecutar("event_choice", {"choice": 0})["ok"])
	assert_true(sim.estado.imprevisto.is_empty())
	assert_eq(sim.estado.imprevistos_hechos.size(), 1)
	sim.avanzar(1.0)
	assert_ne(sim.estado.hora, hora, "el tiempo vuelve a correr")


func test_las_opciones_tienen_consecuencias() -> void:
	var sistema := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte")
	var sim := _sim_marte()
	_operar(sim, DISENO_MARTE)
	var e := sim.estado
	e.datos = 30.0
	e.imprevisto = {"id": "conjuncion_solar"}
	assert_true(sistema.decidir(e, 0)["ok"])
	assert_true(ImprevistosSystem.enlace_bloqueado(e), "esperar cierra el enlace")
	assert_eq(sim.ejecutar("transmit", {"on": true})["reason"], "LINK_BLOCKED_EVENT")
	e.imprevisto = {"id": "conjuncion_solar"}
	sistema.decidir(e, 1)
	assert_almost_eq(e.datos, 20.1, 0.01, "transmitir igual pierde un tercio de los datos")
	e.imprevisto = {"id": "arena_blanda"}
	var bateria := e.bateria_wh
	sistema.decidir(e, 0)
	assert_almost_eq(e.bateria_wh, maxf(bateria - 80.0, 0.0), 0.01)
	assert_true(ImprevistosSystem.movimiento_bloqueado(e))
	assert_eq(sim.ejecutar("move", {"tile": e.casilla_rover + Vector2i(2, 0)})["reason"], "MOVE_BLOCKED_EVENT")
	e.imprevisto = {"id": "arena_blanda"}
	sistema.decidir(e, 1)
	assert_almost_eq(e.rover_hp, 80.0, 0.01)


func test_la_luna_usa_sus_trayectorias_y_lleva_mas_carga() -> void:
	var sim := _sim_luna()
	var taller: Dictionary = sim.snapshot()["workshop"]
	var trayectorias: Array = []
	for cat in taller["categories"]:
		if cat["id"] == "trayectoria":
			for p in cat["parts"]:
				trayectorias.append(p["id"])
		if cat["id"] == "cohetes":
			for p in cat["parts"]:
				if p["id"] == "cohete_ligero":
					assert_eq(float(p["capacity_kg"]), 900.0, "a la Luna el cohete ligero lleva 1,5 veces más")
	assert_eq(trayectorias, ["trayectoria_directa_luna", "trayectoria_balistica_luna"])
	assert_eq(taller["selection"]["trayectoria"], ["trayectoria_directa_luna"])
	assert_eq(int(taller["totals"]["cruise_days"]), 3)


func test_una_mision_lunar_se_juega_sin_historia_ni_combate() -> void:
	var sim := _sim_luna()
	sim.usar_imprevistos(ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "luna"), 3)
	_operar(sim, DISENO_LUNA)
	assert_eq(sim.estado.fase, "operations")
	assert_false(sim.snapshot().has("combat"), "sin monstruos en la Luna")
	assert_false(sim.snapshot()["resources"].has("bionutrientes"))
	assert_false(sim.snapshot().has("story"), "sin historia en la Luna")
	# Un día y medio de misión, resolviendo los imprevistos que aparezcan.
	for i in range(int(1.5 * 300.0 / 0.25)):
		sim.avanzar(0.25)
		if not sim.estado.imprevisto.is_empty():
			assert_true(sim.ejecutar("event_choice", {"choice": 1})["ok"])
		if sim.estado.fase != "operations":
			break
	assert_false(is_nan(sim.estado.bateria_wh))
	assert_gte(sim.estado.sol, 2)
	# La noche lunar con RTG no agota la batería; la calefacción solar gasta más (balance_luna.json).
	assert_eq(int(Balance.desde_archivo("res://content/balance_luna.json").numero("energia.calefaccion_nocturna_w.solar")), 35)
