extends GutTest
## Pruebas de ScienceSystem con los datos reales de balance.json y rules.json.

var balance: Balance
var reglas: Rules
var estado: MissionState
var energia: EnergySystem
var ciencia: ScienceSystem
var todos: Array[String] = ["panorama", "spectrometer", "drill", "radar", "drone", "meteo"]


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	estado = MissionState.new(balance, reglas)
	estado.configurar_diseno("solar", "relay", todos, true)
	estado.fase = "operations"
	estado.hora = 12.0
	ClockSystem.new(balance, reglas).actualizar(estado)
	energia = EnergySystem.new(balance, 140.0)
	ciencia = ScienceSystem.new(balance, energia)


func _agregar(id: String, casilla: Vector2i, tipo: String, revelado: bool = true) -> void:
	estado.objetivos.append({"id": id, "tile": casilla, "type": tipo, "revealed": revelado, "depleted": false, "done": []})


func _completar(accion: String, objetivo: String = "") -> Array[String]:
	var resultado := ciencia.iniciar(estado, accion, objetivo)
	assert_true(resultado["ok"], "no se pudo iniciar %s: %s" % [accion, resultado["reason"]])
	if not resultado["ok"]:
		return []
	return ciencia.avanzar(estado, float(estado.accion_en_curso["seconds"]))


func _motivo(accion: String, objetivo: String = "") -> String:
	return ciencia.disponibilidad(estado, accion, objetivo)["reason"]


func test_iniciar_gasta_energia_y_deja_la_accion_en_curso() -> void:
	var antes := estado.bateria_wh
	var resultado := ciencia.iniciar(estado, "panorama")
	assert_true(resultado["ok"])
	assert_almost_eq(estado.bateria_wh, antes - float(balance.accion("panorama")["costo_wh"]), 0.001)
	assert_true(estado.ocupado)
	assert_eq(estado.accion_en_curso["action"], "panorama")


func test_no_se_inicia_otra_accion_mientras_hay_una_en_curso() -> void:
	ciencia.iniciar(estado, "panorama")
	var antes := estado.bateria_wh
	var resultado := ciencia.iniciar(estado, "radar")
	assert_false(resultado["ok"])
	assert_eq(resultado["reason"], "BUSY")
	assert_eq(estado.bateria_wh, antes)


func test_motivos_por_estado_de_la_mision() -> void:
	estado.fase = "landing"
	assert_eq(_motivo("panorama"), "LANDING")
	estado.fase = "report"
	assert_eq(_motivo("panorama"), "MISSION_END")
	estado.fase = "operations"
	estado.pausado = true
	assert_eq(_motivo("panorama"), "PAUSED")
	estado.pausado = false
	estado.modo_seguro = true
	assert_eq(_motivo("panorama"), "SAFE")
	estado.modo_seguro = false
	estado.en_movimiento = true
	assert_eq(_motivo("panorama"), "MOVING")
	estado.en_movimiento = false
	estado.ocupado = true
	assert_eq(_motivo("panorama"), "BUSY")


func test_instrumentos_que_el_diseno_no_tiene() -> void:
	var pocos: Array[String] = ["panorama"]
	estado.configurar_diseno("solar", "relay", pocos, false)
	assert_eq(_motivo("radar"), "NO_INSTRUMENT")
	assert_eq(_motivo("companion"), "NO_INSTRUMENT")
	assert_eq(_motivo("panorama"), "")


func test_energia_insuficiente() -> void:
	var costo := float(balance.accion("panorama")["costo_wh"])
	estado.bateria_wh = costo - 1.0
	assert_eq(_motivo("panorama"), "LOW_ENERGY")
	estado.bateria_wh = costo
	assert_eq(_motivo("panorama"), "")


func test_accion_desconocida() -> void:
	assert_eq(_motivo("teletransporte"), "UNKNOWN_ACTION")


func test_objetivo_lejano_y_cercano() -> void:
	_agregar("R1", Vector2i(2, 0), "rock")
	assert_eq(_motivo("spectrometer", "R1"), "TOO_FAR")
	estado.casilla_rover = Vector2i(1, 1)
	assert_eq(_motivo("spectrometer", "R1"), "")


func test_objetivo_ausente_o_sin_revelar() -> void:
	_agregar("R1", Vector2i(1, 0), "rock", false)
	assert_eq(_motivo("spectrometer", ""), "NO_TARGET")
	assert_eq(_motivo("spectrometer", "R1"), "NO_TARGET")


func test_accion_no_aplicable_al_tipo_de_objetivo() -> void:
	_agregar("B1", Vector2i(1, 0), "buried")
	assert_eq(_motivo("spectrometer", "B1"), "NOT_APPLICABLE")
	assert_eq(_motivo("drill", "B1"), "")


func test_memoria_llena() -> void:
	_agregar("R1", Vector2i(1, 0), "rock")
	estado.datos = estado.memoria_capacidad - balance.numero("ciencia.rendimiento.spectrometer") + 1.0
	assert_eq(_motivo("spectrometer", "R1"), "MEMORY_FULL")
	estado.datos = estado.memoria_capacidad - balance.numero("ciencia.rendimiento.spectrometer")
	assert_eq(_motivo("spectrometer", "R1"), "")


func test_dron_clima_noche_y_un_vuelo_por_sol() -> void:
	estado.tormenta = true
	assert_eq(_motivo("drone"), "WEATHER")
	estado.tormenta = false
	estado.es_noche = true
	assert_eq(_motivo("drone"), "NIGHT")
	estado.es_noche = false
	_completar("drone")
	assert_eq(_motivo("drone"), "FLIGHT_USED")
	estado.sol += 1
	assert_eq(_motivo("drone"), "")


func test_espectrometro_suma_datos_y_marca_el_objetivo() -> void:
	_agregar("R1", Vector2i(1, 0), "rock")
	var eventos := _completar("spectrometer", "R1")
	assert_eq(estado.datos, balance.numero("ciencia.rendimiento.spectrometer"))
	assert_eq(estado.objetivos[0]["done"], ["spectrometer"])
	assert_false(estado.objetivos[0]["depleted"])
	assert_false(estado.ocupado)
	assert_true(estado.accion_en_curso.is_empty())
	assert_true(eventos.has("ACTION_DONE:spectrometer:R1"))


func test_la_roca_se_agota_con_las_dos_acciones() -> void:
	_agregar("R1", Vector2i(1, 0), "rock")
	_completar("spectrometer", "R1")
	var eventos := _completar("drill", "R1")
	assert_true(estado.objetivos[0]["depleted"])
	assert_true(eventos.has("TARGET_DEPLETED:R1"))
	assert_eq(_motivo("spectrometer", "R1"), "DEPLETED")


func test_el_enterrado_rinde_mas_y_se_agota_con_el_taladro() -> void:
	_agregar("B1", Vector2i(0, 1), "buried")
	var eventos := _completar("drill", "B1")
	assert_eq(estado.datos, balance.numero("ciencia.rendimiento.drill_enterrado"))
	assert_true(estado.objetivos[0]["depleted"])
	assert_true(eventos.has("TARGET_DEPLETED:B1"))


func test_el_mineral_da_minerales() -> void:
	_agregar("M1", Vector2i(1, 0), "mineral")
	_completar("drill", "M1")
	assert_eq(estado.minerales, 1)
	assert_eq(estado.datos, balance.numero("ciencia.rendimiento.drill"))
	_completar("spectrometer", "M1")
	assert_eq(estado.minerales, 2)
	assert_true(estado.objetivos[0]["depleted"])


func test_panoramica_revela_rocas_y_minerales_pero_no_enterrados() -> void:
	_agregar("R2", Vector2i(5, 5), "rock", false)
	_agregar("M2", Vector2i(-5, 5), "mineral", false)
	_agregar("B2", Vector2i(5, -5), "buried", false)
	var eventos := _completar("panorama")
	assert_true(estado.objetivos[0]["revealed"])
	assert_true(estado.objetivos[1]["revealed"])
	assert_false(estado.objetivos[2]["revealed"])
	assert_true(eventos.has("TARGET_REVEALED:R2"))
	assert_true(eventos.has("TARGET_REVEALED:M2"))


func test_radar_revela_solo_enterrados() -> void:
	_agregar("R2", Vector2i(5, 5), "rock", false)
	_agregar("B2", Vector2i(5, -5), "buried", false)
	_completar("radar")
	assert_false(estado.objetivos[0]["revealed"])
	assert_true(estado.objetivos[1]["revealed"])


func test_dron_revela_todo() -> void:
	_agregar("R2", Vector2i(5, 5), "rock", false)
	_agregar("B2", Vector2i(5, -5), "buried", false)
	_completar("drone")
	assert_true(estado.objetivos[0]["revealed"])
	assert_true(estado.objetivos[1]["revealed"])


func test_companero_aporta_minerales() -> void:
	_completar("companion")
	assert_eq(estado.minerales, int(balance.numero("ciencia.minerales_companero")))


func test_mejorar_antena() -> void:
	var coste := int(balance.numero("ciencia.minerales_mejora_antena"))
	assert_eq(ciencia.mejorar_antena(estado)["reason"], "NO_MINERAL")
	estado.minerales = coste
	assert_true(ciencia.mejorar_antena(estado)["ok"])
	assert_eq(estado.nivel_antena, 2)
	assert_eq(estado.minerales, 0)
	estado.minerales = coste
	estado.nivel_antena = int(balance.numero("ciencia.nivel_antena_max"))
	assert_eq(ciencia.mejorar_antena(estado)["reason"], "MAX_LEVEL")


func test_estacion_meteorologica_aporta_datos_cada_sol() -> void:
	var eventos := ciencia.al_nuevo_sol(estado)
	assert_eq(estado.datos, balance.numero("ciencia.meteo_por_sol"))
	assert_eq(eventos, [ScienceSystem.EVENTO_DATOS_METEO])
	estado.datos = estado.memoria_capacidad - 1.0
	ciencia.al_nuevo_sol(estado)
	assert_eq(estado.datos, estado.memoria_capacidad)
	var pocos: Array[String] = ["panorama"]
	estado.configurar_diseno("solar", "relay", pocos, false)
	estado.datos = 0.0
	assert_eq(ciencia.al_nuevo_sol(estado).size(), 0)
	assert_eq(estado.datos, 0.0)


func test_la_accion_no_avanza_en_pausa_y_se_cancela_en_modo_seguro() -> void:
	ciencia.iniciar(estado, "panorama")
	estado.pausado = true
	assert_eq(ciencia.avanzar(estado, 100.0).size(), 0)
	assert_false(estado.accion_en_curso.is_empty())
	estado.pausado = false
	estado.modo_seguro = true
	assert_eq(ciencia.avanzar(estado, 1.0).size(), 0)
	assert_true(estado.accion_en_curso.is_empty())
	assert_false(estado.ocupado)


func test_acciones_pertinentes_y_principal_por_objetivo() -> void:
	_agregar("R1", Vector2i(1, 0), "rock")
	_agregar("M1", Vector2i(0, 1), "mineral")
	_agregar("B1", Vector2i(-1, 0), "buried")
	_agregar("R9", Vector2i(5, 5), "rock", false)
	assert_eq(_ids("R1"), ["spectrometer", "drill"])
	assert_eq(ciencia.accion_principal(estado, "R1"), "spectrometer")
	assert_eq(_ids("M1"), ["drill", "spectrometer"])
	assert_eq(ciencia.accion_principal(estado, "M1"), "drill")
	assert_eq(_ids("B1"), ["drill"])
	assert_eq(_ids("R9"), [])
	assert_eq(ciencia.accion_principal(estado, "R9"), "")
	_completar("spectrometer", "R1")
	assert_eq(ciencia.accion_principal(estado, "R1"), "drill")


func _ids(objetivo: String) -> Array:
	var ids: Array = []
	for entrada in ciencia.acciones_de_objetivo(estado, objetivo):
		ids.append(entrada["id"])
	return ids


func test_el_indice_de_objetivos_sigue_bien_si_cambia_la_lista() -> void:
	_agregar("A", Vector2i(1, 1), "rock")
	_agregar("B", Vector2i(2, 2), "mineral")
	assert_eq(ciencia.acciones_de_objetivo(estado, "B").size() > 0, true)
	assert_eq(ciencia.accion_principal(estado, "A"), ciencia.principal_de(ciencia.acciones_de_objetivo(estado, "A"), estado.objetivos[0]))
	# la lista cambia de orden y de contenido (por ejemplo, al cargar una partida): el índice no puede devolver otro objetivo
	estado.objetivos.reverse()
	assert_eq(ciencia.acciones_de_objetivo(estado, "A").size() > 0, true, "A sigue encontrándose")
	estado.objetivos.clear()
	assert_eq(ciencia.acciones_de_objetivo(estado, "A").size(), 0, "sin objetivos no hay acciones")
	_agregar("C", Vector2i(3, 3), "rock")
	assert_eq(ciencia.acciones_de_objetivo(estado, "A").size(), 0)
	assert_gt(ciencia.acciones_de_objetivo(estado, "C").size(), 0)


func test_companero_tiene_tope_por_sol() -> void:
	var maximo := int(balance.numero("acciones.companion.usos_por_sol"))
	assert_gt(maximo, 0)
	estado.bateria_wh = estado.bateria_capacidad_wh
	for i in maximo:
		_completar("companion")
	assert_eq(_motivo("companion"), "HELP_USED")
	assert_false(ciencia.iniciar(estado, "companion")["ok"])
	# Al día siguiente vuelve a estar disponible.
	estado.sol += 1
	assert_eq(_motivo("companion"), "")


func test_memoria_llena_no_frena_recursos_si_ya_no_se_puede_enviar() -> void:
	_agregar("R9", Vector2i(0, 0), "rock")
	estado.casilla_rover = Vector2i(0, 0)
	estado.bateria_wh = estado.bateria_capacidad_wh
	estado.datos = float(estado.memoria_capacidad)
	assert_eq(_motivo("spectrometer", "R9"), "MEMORY_FULL")
	estado.envio_max = 10.0
	estado.enviados = 10.0
	assert_eq(_motivo("spectrometer", "R9"), "")
