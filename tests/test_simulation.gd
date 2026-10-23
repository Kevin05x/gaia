extends GutTest
## Pruebas de Simulation con los datos reales: órdenes, snapshot, avisos y fin de misión.

var balance: Balance
var reglas: Rules
var mapa: MapData
var sim: Simulation
var todos: Array[String] = ["panorama", "spectrometer", "drill", "radar", "drone", "meteo"]


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	mapa = MapData.desde_archivo("res://content/mapa.json")
	sim = Simulation.new(balance, reglas, mapa)


## Deja la simulación lista para operar (taller -> aterrizaje -> operaciones).
func _operar(energia: String = "solar", instrumentos: Array[String] = []) -> void:
	var lista: Array[String] = instrumentos if not instrumentos.is_empty() else todos
	assert_true(sim.configurar_diseno(energia, "relay", lista, true, 140.0))
	assert_true(sim.iniciar_aterrizaje())
	assert_true(sim.ejecutar("landing_finished")["ok"])


func _tramo() -> float:
	return balance.numero("movimiento.segundos_por_casilla")


func _objetivo(id: String) -> Dictionary:
	for objetivo in sim.snapshot()["targets"]:
		if objetivo["id"] == id:
			return objetivo
	return {}


func test_empieza_en_el_taller_con_el_mapa_cargado() -> void:
	var datos := sim.snapshot()
	assert_eq(datos["phase"], "workshop")
	assert_eq(datos["targets"].size(), 9)
	assert_eq(datos["bounds"], {"min": Vector2i(-11, -11), "max": Vector2i(11, 11)})
	assert_eq(datos["warnings"].size(), 0)


func test_el_diseno_solo_se_fija_en_el_taller() -> void:
	assert_false(sim.configurar_diseno("nuclear", "relay", todos, false, 110.0), "energía inexistente")
	_operar()
	assert_false(sim.configurar_diseno("rtg", "direct", todos, false, 110.0))
	assert_false(sim.iniciar_aterrizaje())


func test_fases_y_ordenes_fuera_de_operaciones() -> void:
	assert_true(sim.configurar_diseno("solar", "relay", todos, true, 140.0))
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(1, 0)})["reason"], "LANDING")
	assert_eq(sim.ejecutar("pause", {"paused": true})["reason"], "WRONG_PHASE")
	assert_eq(sim.ejecutar("landing_finished")["reason"], "WRONG_PHASE")
	sim.iniciar_aterrizaje()
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(1, 0)})["reason"], "LANDING")
	assert_eq(sim.avanzar(10.0).size(), 0, "el tiempo no corre durante el aterrizaje")
	assert_true(sim.ejecutar("landing_finished")["ok"])
	assert_eq(sim.snapshot()["phase"], "operations")
	assert_eq(sim.ejecutar("volar")["reason"], "UNKNOWN_COMMAND")


func test_snapshot_trae_las_claves_del_contrato_y_las_nuevas() -> void:
	_operar()
	var datos := sim.snapshot()
	for clave in ["phase", "paused", "safe_mode", "sol", "hour", "rover_tile", "station_tile", "battery", "design",
			"data", "memory_capacity", "sent", "goal", "mineral", "antenna_level", "dust", "storm", "storm_in",
			"transmitting", "link_open", "comms_windows", "moving", "busy", "map_revision", "targets", "obstacles",
			"is_night", "link_next", "bounds", "warnings", "available_actions"]:
		assert_true(datos.has(clave), "falta %s" % clave)
	for accion in ["panorama", "spectrometer", "drill", "radar", "drone", "companion", "approach", "transmit", "upgrade"]:
		assert_true(datos["available_actions"].has(accion), "falta available_actions.%s" % accion)
		assert_true(datos["available_actions"][accion].has("reason"))


func test_objetivos_revelados_traen_acciones_y_los_ocultos_no() -> void:
	_operar()
	var roca := _objetivo("JZ-01")
	assert_eq(roca["primary"], "spectrometer")
	assert_eq(roca["actions"].size(), 2)
	assert_eq(roca["actions"][0]["reason"], "TOO_FAR")
	var enterrado := _objetivo("JZ-05")
	assert_false(enterrado["revealed"])
	assert_false(enterrado.has("actions"))
	assert_false(enterrado.has("primary"))
	assert_false(enterrado.has("done"), "el objetivo sale con la forma del contrato")


func test_el_tiempo_corre_y_la_energia_cambia() -> void:
	_operar()
	sim.estado.bateria_wh = 500.0
	var antes := sim.snapshot()
	sim.avanzar(30.0)
	var despues := sim.snapshot()
	assert_gt(despues["hour"], antes["hour"])
	assert_ne(despues["battery"]["wh"], antes["battery"]["wh"])
	assert_gt(despues["battery"]["generation_w"], 0.0, "de día el panel genera")


func test_la_pausa_detiene_todo() -> void:
	_operar()
	assert_true(sim.ejecutar("pause", {"paused": true})["ok"])
	var antes := sim.snapshot()
	assert_eq(sim.avanzar(60.0).size(), 0)
	assert_eq(sim.snapshot()["hour"], antes["hour"])
	assert_eq(sim.snapshot()["battery"]["wh"], antes["battery"]["wh"])
	assert_true(sim.snapshot()["paused"])
	sim.ejecutar("pause", {"paused": false})
	sim.avanzar(1.0)
	assert_gt(sim.snapshot()["hour"], antes["hour"])


func test_mover_entrega_la_ruta_y_confirma_la_posicion_al_llegar() -> void:
	_operar()
	var resultado := sim.ejecutar("move", {"tile": Vector2i(3, 0)})
	assert_true(resultado["ok"])
	assert_eq(resultado["path"].size(), 3)
	assert_eq(resultado["seconds_per_tile"], _tramo())
	assert_true(sim.snapshot()["moving"])
	assert_eq(sim.snapshot()["rover_tile"], Vector2i(0, 0))
	var eventos := sim.avanzar(3 * _tramo() + 0.01)
	assert_has(eventos, MovementSystem.EVENTO_MOVIMIENTO_TERMINADO)
	assert_false(sim.snapshot()["moving"])
	assert_eq(sim.snapshot()["rover_tile"], Vector2i(3, 0))


func test_mover_rechazos() -> void:
	_operar()
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(40, 0)})["reason"], "OUT_OF_BOUNDS")
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(4, 0)})["reason"], "NO_PATH")


func test_seleccionar_y_la_disponibilidad_de_las_acciones() -> void:
	_operar()
	assert_eq(sim.snapshot()["available_actions"]["spectrometer"]["reason"], "NO_TARGET")
	assert_eq(sim.snapshot()["available_actions"]["approach"]["reason"], "NO_TARGET")
	assert_eq(sim.ejecutar("select", {"target_id": "JZ-05"})["reason"], "NO_TARGET", "enterrado sin revelar")
	assert_eq(sim.ejecutar("select", {"target_id": "NO-EXISTE"})["reason"], "NO_TARGET")
	assert_true(sim.ejecutar("select", {"target_id": "JZ-01"})["ok"])
	assert_eq(sim.objetivo_seleccionado(), "JZ-01")
	var acciones: Dictionary = sim.snapshot()["available_actions"]
	assert_eq(acciones["spectrometer"]["reason"], "TOO_FAR")
	assert_true(acciones["approach"]["enabled"])
	assert_true(sim.ejecutar("select", {"target_id": ""})["ok"])
	assert_eq(sim.objetivo_seleccionado(), "")


func test_acercar_actuar_y_analizar_un_objetivo() -> void:
	_operar()
	var acercar := sim.ejecutar("approach", {"target_id": "JZ-01"})
	assert_true(acercar["ok"])
	assert_eq(sim.objetivo_seleccionado(), "JZ-01", "acercarse selecciona el objetivo")
	assert_eq(sim.ejecutar("act", {"target_id": "JZ-01", "action": "spectrometer"})["reason"], "MOVING")
	sim.avanzar(acercar["path"].size() * _tramo() + 0.01)
	assert_eq(sim.snapshot()["available_actions"]["approach"]["reason"], "ALREADY_NEAR")
	assert_eq(sim.ejecutar("approach", {"target_id": "JZ-01"})["reason"], "ALREADY_NEAR")
	var accion := sim.ejecutar("act", {"target_id": "JZ-01", "action": "spectrometer"})
	assert_true(accion["ok"])
	assert_eq(accion["action"]["action"], "spectrometer")
	assert_eq(accion["action"]["target_id"], "JZ-01")
	assert_eq(float(accion["action"]["seconds"]), float(balance.accion("spectrometer")["duracion_s"]))
	assert_true(sim.snapshot()["busy"])
	var eventos := sim.avanzar(float(accion["action"]["seconds"]) + 0.01)
	assert_has(eventos, "%s:spectrometer:JZ-01" % ScienceSystem.EVENTO_ACCION_TERMINADA)
	assert_false(sim.snapshot()["busy"])
	assert_almost_eq(float(sim.snapshot()["data"]), balance.numero("ciencia.rendimiento.spectrometer"), 0.01)


func test_actuar_sin_instrumento_o_con_accion_desconocida() -> void:
	var sin_radar: Array[String] = ["panorama"]
	_operar("solar", sin_radar)
	assert_eq(sim.ejecutar("act", {"action": "radar"})["reason"], "NO_INSTRUMENT")
	assert_eq(sim.ejecutar("act", {"action": "teletransporte"})["reason"], "UNKNOWN_ACTION")
	assert_eq(sim.snapshot()["available_actions"]["radar"]["reason"], "NO_INSTRUMENT")


func test_la_panoramica_revela_objetivos() -> void:
	_operar()
	var accion := sim.ejecutar("act", {"action": "panorama"})
	assert_true(accion["ok"])
	var eventos := sim.avanzar(float(accion["action"]["seconds"]) + 0.01)
	assert_has(eventos, "%s:panorama:" % ScienceSystem.EVENTO_ACCION_TERMINADA)
	assert_true(_objetivo("JZ-09")["revealed"], "el mineral oculto sale a la vista")
	assert_false(_objetivo("JZ-05")["revealed"], "el enterrado sigue oculto")
	assert_true(_objetivo("JZ-09").has("actions"))


func test_transmitir_envia_datos_cuando_hay_enlace() -> void:
	_operar()
	sim.estado.datos = 30.0
	sim.estado.hora = 12.0
	sim.avanzar(0.01)
	assert_eq(sim.ejecutar("transmit", {"on": true})["reason"], "NO_LINK", "entre ventanas no hay enlace")
	sim.estado.hora = 9.0
	sim.avanzar(0.01)
	assert_true(sim.ejecutar("transmit", {"on": true})["ok"])
	assert_true(sim.snapshot()["transmitting"])
	sim.avanzar(2.0)
	assert_gt(float(sim.snapshot()["sent"]), 0.0)
	assert_lt(float(sim.snapshot()["data"]), 30.0)
	assert_true(sim.ejecutar("transmit", {"on": false})["ok"])
	assert_false(sim.snapshot()["transmitting"])


func test_mejorar_antena_pide_minerales() -> void:
	_operar()
	assert_eq(sim.ejecutar("upgrade")["reason"], "NO_MINERAL")
	assert_eq(sim.snapshot()["available_actions"]["upgrade"]["reason"], "NO_MINERAL")
	sim.estado.minerales = 3
	assert_true(sim.ejecutar("upgrade")["ok"])
	assert_eq(sim.snapshot()["antenna_level"], 2)
	assert_eq(sim.snapshot()["mineral"], 0)


func test_el_modo_seguro_cancela_la_accion_y_el_movimiento() -> void:
	_operar()
	sim.estado.hora = 3.0
	var accion := sim.ejecutar("act", {"action": "panorama"})
	assert_true(accion["ok"])
	sim.estado.bateria_wh = 0.0
	var eventos := sim.avanzar(0.5)
	assert_has(eventos, EnergySystem.EVENTO_ENTRA_MODO_SEGURO)
	assert_has(eventos, Simulation.EVENTO_ACCION_CANCELADA)
	assert_false(sim.snapshot()["busy"])
	assert_true(sim.snapshot()["safe_mode"])
	assert_eq(sim.snapshot()["warnings"][0]["id"], "SAFE_MODE")
	assert_eq(sim.snapshot()["warnings"][0]["severity"], "critical")
	assert_eq(sim.ejecutar("act", {"action": "panorama"})["reason"], "SAFE")


func test_avisos_de_bateria_memoria_y_tormenta() -> void:
	_operar()
	assert_eq(sim.snapshot()["warnings"].size(), 0)
	sim.estado.bateria_wh = 150.0
	sim.estado.datos = 55.0
	var ids: Array[String] = []
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "LOW_BATTERY")
	assert_has(ids, "MEMORY_ALMOST_FULL")
	var bateria: Dictionary = sim.snapshot()["warnings"][0]
	assert_eq(bateria["key"], "WARN_LOW_BATTERY")
	assert_eq(bateria["values"], [15])
	sim.estado.sol = 3
	sim.avanzar(0.01)
	ids.clear()
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "STORM_ACTIVE")


func test_aviso_de_tormenta_cercana_y_de_enlace() -> void:
	_operar()
	sim.estado.sol = 2
	sim.estado.hora = 17.5
	sim.estado.bateria_wh = 900.0
	sim.avanzar(0.01)
	var ids: Array[String] = []
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "STORM_SOON", "faltan menos de 1 sol para la tormenta del sol 3")
	sim.estado.sol = 1
	sim.estado.hora = 7.5
	sim.avanzar(0.01)
	ids.clear()
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "LINK_OPENING_SOON", "el relé abre a las 08:00")
	assert_does_not_have(ids, "STORM_SOON")


func test_los_textos_de_avisos_y_nuevos_motivos_estan_en_el_catalogo() -> void:
	var catalogo := FileAccess.get_file_as_string("res://scenes/b/i18n/catalog.gd")
	for clave in ["WARN_SAFE_MODE", "WARN_LOW_BATTERY", "WARN_STORM_ACTIVE", "WARN_STORM_SOON",
			"WARN_MEMORY_ALMOST_FULL", "WARN_LINK_OPENING_SOON", "ALREADY_NEAR", "WRONG_PHASE", "NO_PATH", "OUT_OF_BOUNDS"]:
		assert_true(catalogo.contains("\"" + clave + "\""), "falta %s en catalog.gd" % clave)


func test_exito_al_enviar_la_meta() -> void:
	_operar()
	sim.estado.enviados = sim.estado.meta - 1.0
	sim.estado.datos = 20.0
	sim.estado.hora = 9.0
	sim.avanzar(0.01)
	assert_true(sim.ejecutar("transmit", {"on": true})["ok"])
	var eventos := sim.avanzar(3.0)
	assert_has(eventos, Simulation.EVENTO_MISION_TERMINADA)
	assert_true(sim.informe["success"])
	assert_eq(sim.snapshot()["phase"], "report")
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(1, 0)})["reason"], "MISSION_END")
	assert_eq(sim.avanzar(10.0).size(), 0, "terminada la misión no avanza nada")


func test_fracaso_al_acabar_el_ultimo_sol() -> void:
	_operar()
	sim.estado.sol = 6
	sim.estado.hora = 23.99
	sim.estado.bateria_wh = 1000.0
	var eventos := sim.avanzar(1.0)
	assert_has(eventos, Simulation.EVENTO_MISION_TERMINADA)
	assert_false(sim.informe["success"])
	assert_eq(sim.informe["stars"], 0)
	assert_has(sim.informe["causes"], OutcomeSystem.CAUSA_PLAZO)


func test_reiniciar_vuelve_al_taller_con_la_mision_limpia() -> void:
	_operar()
	sim.ejecutar("move", {"tile": Vector2i(3, 0)})
	sim.avanzar(5.0)
	sim.estado.enviados = 200.0
	sim.avanzar(0.1)
	assert_false(sim.informe.is_empty())
	sim.reiniciar()
	assert_true(sim.informe.is_empty())
	var datos := sim.snapshot()
	assert_eq(datos["phase"], "workshop")
	assert_eq(datos["rover_tile"], Vector2i(0, 0))
	assert_eq(datos["sent"], 0.0)
	assert_eq(datos["sol"], 1)
	assert_eq(datos["battery"]["wh"], 1000.0)
	assert_eq(sim.objetivo_seleccionado(), "")
	assert_true(sim.configurar_diseno("rtg", "direct", todos, false, 110.0))
