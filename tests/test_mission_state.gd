extends GutTest
## Pruebas de MissionState con los datos reales de balance.json y rules.json.

var balance: Balance
var reglas: Rules


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")


func test_valores_iniciales_salen_de_los_datos() -> void:
	var estado := MissionState.new(balance, reglas)
	assert_eq(estado.fase, "landing")
	assert_eq(estado.sol, 1)
	assert_eq(estado.hora, balance.numero("tiempo.hora_inicio"))
	assert_eq(estado.bateria_wh, balance.numero("energia.capacidad_base_wh"))
	assert_eq(estado.bateria_wh, estado.bateria_capacidad_wh)
	assert_eq(estado.memoria_capacidad, balance.numero("ciencia.memoria_capacidad"))
	assert_eq(estado.polvo, balance.numero("energia.polvo_inicial"))
	assert_eq(estado.meta, reglas.datos_requeridos)
	assert_eq(estado.datos, 0.0)
	assert_eq(estado.enviados, 0.0)


func test_configurar_diseno_valido() -> void:
	var estado := MissionState.new(balance, reglas)
	var instrumentos: Array[String] = ["panorama", "drill"]
	assert_true(estado.configurar_diseno("rtg", "direct", instrumentos, true))
	assert_eq(estado.energia, "rtg")
	assert_eq(estado.enlace, "direct")
	assert_eq(estado.instrumentos, instrumentos)
	assert_true(estado.companero)
	assert_eq(estado.ventanas_enlace, balance.ventanas("directa"))


func test_configurar_diseno_invalido_no_cambia_nada() -> void:
	var estado := MissionState.new(balance, reglas)
	var antes := estado.a_snapshot()
	var instrumentos: Array[String] = ["drill"]
	assert_false(estado.configurar_diseno("nuclear", "relay", instrumentos, true))
	assert_false(estado.configurar_diseno("solar", "laser", instrumentos, true))
	assert_eq(estado.a_snapshot(), antes)


func test_snapshot_tiene_las_claves_del_contrato() -> void:
	var snapshot := MissionState.new(balance, reglas).a_snapshot()
	var claves := ["phase", "paused", "safe_mode", "safe_entries", "sol", "hour", "rover_tile",
		"station_tile", "battery", "design", "data", "memory_capacity", "sent", "goal", "mineral",
		"antenna_level", "dust", "storm", "storm_in", "transmitting", "link_open", "comms_windows",
		"moving", "busy", "map_revision", "targets", "obstacles"]
	for clave in claves:
		assert_true(snapshot.has(clave), "falta la clave %s" % clave)
	for clave in ["wh", "capacity", "generation_w", "load_w"]:
		assert_true(snapshot["battery"].has(clave), "falta battery.%s" % clave)
	for clave in ["power", "comms", "instruments", "companion"]:
		assert_true(snapshot["design"].has(clave), "falta design.%s" % clave)


func test_snapshot_es_una_copia() -> void:
	var estado := MissionState.new(balance, reglas)
	estado.objetivos.append({"id": "JZ-01", "tile": Vector2i(2, -2), "type": "rock", "revealed": true, "depleted": false})
	var snapshot := estado.a_snapshot()
	snapshot["targets"][0]["depleted"] = true
	snapshot["comms_windows"].clear()
	snapshot["design"]["instruments"].append("radar")
	assert_false(estado.objetivos[0]["depleted"])
	assert_gt(estado.ventanas_enlace.size(), 0)
	assert_eq(estado.instrumentos.size(), 0)


func test_snapshot_refleja_cambios_de_estado() -> void:
	var estado := MissionState.new(balance, reglas)
	estado.sol = 3
	estado.casilla_rover = Vector2i(2, -1)
	estado.bateria_wh = 420.0
	var snapshot := estado.a_snapshot()
	assert_eq(snapshot["sol"], 3)
	assert_eq(snapshot["rover_tile"], Vector2i(2, -1))
	assert_eq(snapshot["battery"]["wh"], 420.0)
