extends GutTest
## Pruebas del taller dentro de Simulation (y de MissionDesign.a_configuracion) con los datos reales.

var balance: Balance
var reglas: Rules
var mapa: MapData
var catalogo: Catalog
var sim: Simulation


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	mapa = MapData.desde_archivo("res://content/mapa.json")
	catalogo = Catalog.desde_archivo("res://content/parts.json")
	sim = Simulation.new(balance, reglas, mapa, catalogo)


func _agregar(ids: Array[String]) -> void:
	for id in ids:
		var resultado := sim.ejecutar("design_add", {"part_id": id})
		assert_true(resultado["ok"], "no se pudo agregar %s: %s" % [id, resultado["reason"]])


func _taller() -> Dictionary:
	return sim.snapshot()["workshop"]


func _pieza(id: String) -> Dictionary:
	for categoria in _taller()["categories"]:
		for pieza in categoria["parts"]:
			if pieza["id"] == id:
				return pieza
	return {}


func test_el_taller_muestra_las_piezas_por_categoria() -> void:
	var categorias: Array = _taller()["categories"]
	var ids: Array[String] = []
	for categoria in categorias:
		ids.append(categoria["id"])
	assert_eq(ids, Catalog.CATEGORIAS)
	var ligero := _pieza("cohete_ligero")
	assert_eq(ligero["name_key"], "PIEZA_COHETE_LIGERO")
	assert_eq(float(ligero["capacity_kg"]), 600.0)
	assert_null(ligero["mass_kg"])
	assert_eq(float(ligero["cost_musd"]), 150.0)
	assert_false(ligero["pending"])
	assert_true(ligero["available"])
	assert_eq(float(_pieza("panel_solar")["power_w"]), 140.0, "toma potencia_max_w si no hay potencia_w")
	assert_eq(float(_pieza("mmrtg")["power_w"]), 110.0)
	var radar := _pieza("radar")
	assert_true(radar["pending"])
	assert_null(radar["mass_kg"])
	assert_null(radar["cost_musd"])
	assert_null(radar["power_w"])


func test_el_taller_solo_existe_en_la_fase_taller() -> void:
	assert_true(sim.snapshot().has("workshop"))
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_false(sim.snapshot().has("workshop"))


func test_empieza_sin_piezas_y_no_es_valido() -> void:
	var taller := _taller()
	for categoria in Catalog.CATEGORIAS:
		assert_eq(taller["selection"][categoria], [])
	assert_false(taller["valid"])
	for requerida in ["chasis", "cohetes", "energia", "comunicaciones"]:
		assert_has(taller["validation"], "BELOW_MIN:%s" % requerida)
	assert_eq(float(taller["totals"]["budget_musd"]), 700.0)
	assert_eq(sim.ejecutar("design_validate")["reason"], "INVALID_DESIGN")
	assert_eq(sim.ejecutar("design_start")["reason"], "INVALID_DESIGN")
	assert_eq(sim.snapshot()["phase"], "workshop")


func test_agregar_y_quitar_actualiza_totales() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	var taller := _taller()
	assert_eq(taller["selection"]["cohetes"], ["cohete_ligero"])
	assert_eq(float(taller["totals"]["mass_kg"]), 525.0)
	assert_eq(float(taller["totals"]["cost_musd"]), 380.0)
	assert_eq(float(taller["totals"]["capacity_kg"]), 600.0)
	assert_eq(float(taller["totals"]["power_w"]), 140.0)
	assert_true(taller["valid"])
	assert_eq(taller["validation"].size(), 0)
	assert_true(sim.ejecutar("design_remove", {"part_id": "antena_rele"})["ok"])
	assert_false(_taller()["valid"])
	assert_has(_taller()["validation"], "BELOW_MIN:comunicaciones")
	assert_eq(float(_taller()["totals"]["cost_musd"]), 350.0)


func test_categoria_completa_y_piezas_desconocidas() -> void:
	_agregar(["cohete_ligero"])
	assert_eq(sim.ejecutar("design_add", {"part_id": "cohete_pesado"})["reason"], "CATEGORY_FULL")
	assert_false(_pieza("cohete_pesado")["available"])
	assert_eq(_pieza("cohete_pesado")["reason"], "CATEGORY_FULL")
	assert_eq(_taller()["selection"]["cohetes"], ["cohete_ligero"])
	assert_eq(sim.ejecutar("design_add", {"part_id": "motor_warp"})["reason"], "UNKNOWN_PART")
	assert_eq(sim.ejecutar("design_remove", {"part_id": "motor_warp"})["reason"], "UNKNOWN_PART")
	assert_eq(sim.ejecutar("design_remove", {"part_id": "cohete_pesado"})["reason"], "UNKNOWN_PART", "no estaba elegida")
	sim.ejecutar("design_remove", {"part_id": "cohete_ligero"})
	assert_true(_pieza("cohete_pesado")["available"])


func test_las_piezas_pendientes_avisan_y_cuentan_cero() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "radar"])
	var taller := _taller()
	assert_has(taller["notices"], "PENDING_DATA:radar")
	assert_true(taller["valid"], "una pieza pendiente no bloquea")
	assert_eq(float(taller["totals"]["mass_kg"]), 525.0)


func test_las_piezas_se_pueden_repetir_en_extras() -> void:
	_agregar(["camara", "camara"])
	assert_eq(_taller()["selection"]["extras"], ["camara", "camara"])


func test_validar_acepta_un_diseno_completo() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	assert_true(sim.ejecutar("design_validate")["ok"])
	assert_eq(sim.snapshot()["phase"], "workshop", "validar no inicia la misión")


func test_iniciar_traduce_las_piezas_al_diseno_de_la_mision() -> void:
	_agregar(["cohete_pesado", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro", "companero", "bateria"])
	var resultado := sim.ejecutar("design_start")
	assert_true(resultado["ok"], "reason: %s" % resultado["reason"])
	var datos := sim.snapshot()
	assert_eq(datos["phase"], "landing")
	assert_eq(datos["design"]["power"], "solar")
	assert_eq(datos["design"]["comms"], "relay")
	assert_eq(datos["design"]["instruments"], ["panorama", "spectrometer", "drill"])
	assert_true(datos["design"]["companion"])
	sim.ejecutar("landing_finished")
	assert_eq(sim.snapshot()["available_actions"]["radar"]["reason"], "NO_INSTRUMENT")
	assert_true(sim.ejecutar("act", {"action": "panorama"})["ok"], "la cámara habilita la panorámica")


func test_un_rtg_genera_su_potencia_de_noche() -> void:
	_agregar(["cohete_ligero", "chasis_base", "mmrtg", "antena_directa"])
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_eq(sim.snapshot()["design"]["power"], "rtg")
	assert_eq(sim.snapshot()["design"]["comms"], "direct")
	assert_false(sim.snapshot()["design"]["companion"])
	sim.ejecutar("landing_finished")
	sim.estado.hora = 3.0
	sim.avanzar(0.1)
	assert_eq(float(sim.snapshot()["battery"]["generation_w"]), 110.0)


func test_el_panel_solar_usa_su_potencia_nominal() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	sim.estado.hora = 12.0
	sim.avanzar(0.1)
	assert_almost_eq(float(sim.snapshot()["battery"]["generation_w"]), 140.0 * (1.0 - balance.numero("energia.polvo_inicial")), 0.5)


func test_ordenes_de_taller_fuera_del_taller() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	sim.ejecutar("design_start")
	for orden in ["design_add", "design_remove", "design_validate", "design_start"]:
		assert_eq(sim.ejecutar(orden, {"part_id": "camara"})["reason"], "WRONG_PHASE", orden)
	assert_eq(sim.ejecutar("redesign")["ok"], true, "se puede rediseñar durante el aterrizaje")


func test_redisenar_vuelve_al_taller_conservando_las_piezas() -> void:
	_agregar(["cohete_ligero", "chasis_base", "panel_solar", "antena_rele"])
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	sim.ejecutar("move", {"tile": Vector2i(3, 0)})
	sim.avanzar(5.0)
	assert_true(sim.ejecutar("redesign")["ok"])
	var datos := sim.snapshot()
	assert_eq(datos["phase"], "workshop")
	assert_eq(datos["rover_tile"], Vector2i(0, 0))
	assert_eq(datos["battery"]["wh"], 1000.0)
	assert_eq(datos["workshop"]["selection"]["cohetes"], ["cohete_ligero"])
	assert_true(datos["workshop"]["valid"])
	assert_eq(sim.ejecutar("redesign")["reason"], "WRONG_PHASE", "ya está en el taller")
	sim.ejecutar("design_remove", {"part_id": "panel_solar"})
	sim.ejecutar("design_add", {"part_id": "mmrtg"})
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_eq(sim.snapshot()["design"]["power"], "rtg")


func test_a_configuracion_del_diseno() -> void:
	var diseno := MissionDesign.new(catalogo, reglas)
	for id in ["cohete_ligero", "chasis_base", "mmrtg", "antena_directa", "dron", "dron", "meteo", "companero"]:
		diseno.agregar(id)
	var configuracion := diseno.a_configuracion()
	assert_eq(configuracion["energia"], "rtg")
	assert_eq(configuracion["enlace"], "direct")
	assert_eq(configuracion["instrumentos"], ["drone", "meteo"], "sin repetidos")
	assert_true(configuracion["companero"])
	assert_eq(float(configuracion["potencia_nominal_w"]), 110.0)


func test_todos_los_nombres_de_pieza_tienen_texto_en_el_catalogo_de_la_interfaz() -> void:
	var texto := FileAccess.get_file_as_string("res://scenes/b/i18n/catalog.gd")
	for id in catalogo.piezas:
		var clave: String = catalogo.piezas[id]["nombre_clave"]
		assert_true(texto.contains("\"" + clave + "\""), "falta %s en catalog.gd" % clave)
	for clave in ["CATEGORY_FULL", "INVALID_DESIGN", "UNKNOWN_PART"]:
		assert_true(texto.contains("\"" + clave + "\""), "falta %s en catalog.gd" % clave)
