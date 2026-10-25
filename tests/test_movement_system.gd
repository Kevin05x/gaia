extends GutTest
## Pruebas de MovementSystem con el mapa y los datos reales.

var balance: Balance
var reglas: Rules
var mapa: MapData
var estado: MissionState
var energia: EnergySystem
var movimiento: MovementSystem
var instrumentos: Array[String] = ["spectrometer", "drill"]


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	mapa = MapData.desde_archivo("res://content/mapa.json")
	estado = MissionState.new(balance, reglas)
	estado.configurar_diseno("solar", "relay", instrumentos, false)
	mapa.aplicar_a(estado)
	estado.fase = "operations"
	energia = EnergySystem.new(balance, 140.0)
	movimiento = MovementSystem.new(balance, energia, mapa)


func _costo_casilla() -> float:
	return balance.numero("movimiento.costo_wh_por_casilla")


func _tramo() -> float:
	return balance.numero("movimiento.segundos_por_casilla")


func test_mover_descuenta_toda_la_ruta_y_deja_al_rover_en_marcha() -> void:
	var resultado := movimiento.iniciar_mover(estado, Vector2i(3, 0))
	assert_true(resultado["ok"])
	assert_eq(resultado["path"].size(), 3)
	assert_eq(resultado["seconds_per_tile"], _tramo())
	assert_almost_eq(estado.bateria_wh, 1000.0 - 3 * _costo_casilla(), 0.001)
	assert_true(estado.en_movimiento)
	assert_eq(estado.casilla_rover, Vector2i(0, 0), "la posición se confirma al llegar")


func test_la_posicion_se_confirma_al_terminar_la_ruta() -> void:
	movimiento.iniciar_mover(estado, Vector2i(3, 0))
	assert_eq(movimiento.avanzar(estado, 2 * _tramo()).size(), 0)
	assert_true(estado.en_movimiento)
	assert_eq(estado.casilla_rover, Vector2i(0, 0))
	var eventos := movimiento.avanzar(estado, _tramo())
	assert_eq(eventos, [MovementSystem.EVENTO_MOVIMIENTO_TERMINADO])
	assert_false(estado.en_movimiento)
	assert_eq(estado.casilla_rover, Vector2i(3, 0))
	assert_true(estado.movimiento_en_curso.is_empty())


func test_motivos_por_estado_de_la_mision() -> void:
	var destino := Vector2i(1, 0)
	estado.fase = "landing"
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "LANDING")
	estado.fase = "report"
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "MISSION_END")
	estado.fase = "operations"
	estado.pausado = true
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "PAUSED")
	estado.pausado = false
	estado.modo_seguro = true
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "SAFE")
	estado.modo_seguro = false
	estado.ocupado = true
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "BUSY")
	estado.ocupado = false
	estado.en_movimiento = true
	assert_eq(movimiento.disponibilidad_mover(estado, destino)["reason"], "MOVING")
	estado.en_movimiento = false
	assert_true(movimiento.disponibilidad_mover(estado, destino)["enabled"])


func test_destino_fuera_del_mapa() -> void:
	var resultado := movimiento.iniciar_mover(estado, Vector2i(36, 0))
	assert_false(resultado["ok"])
	assert_eq(resultado["reason"], "OUT_OF_BOUNDS")
	assert_false(estado.en_movimiento)


func test_destinos_bloqueados_no_tienen_ruta() -> void:
	for casilla in [Vector2i(4, 0), mapa.estacion, Vector2i(2, -2)]:
		var resultado := movimiento.iniciar_mover(estado, casilla)
		assert_false(resultado["ok"], "se aceptó ir a %s" % [casilla])
		assert_eq(resultado["reason"], "NO_PATH")
	assert_eq(estado.bateria_wh, 1000.0)


func test_energia_insuficiente_rechaza_sin_gastar() -> void:
	var justo := 3 * _costo_casilla()
	estado.bateria_wh = justo - 1.0
	var resultado := movimiento.iniciar_mover(estado, Vector2i(3, 0))
	assert_false(resultado["ok"])
	assert_eq(resultado["reason"], "LOW_ENERGY")
	assert_eq(estado.bateria_wh, justo - 1.0)
	assert_false(estado.en_movimiento)
	estado.bateria_wh = justo
	assert_true(movimiento.iniciar_mover(estado, Vector2i(3, 0))["ok"], "justo alcanza")


func test_ir_a_la_casilla_actual_no_hace_nada() -> void:
	var resultado := movimiento.iniciar_mover(estado, estado.casilla_rover)
	assert_true(resultado["ok"])
	assert_eq(resultado["path"].size(), 0)
	assert_false(estado.en_movimiento)
	assert_eq(estado.bateria_wh, 1000.0)


func test_no_avanza_en_pausa() -> void:
	movimiento.iniciar_mover(estado, Vector2i(1, 0))
	estado.pausado = true
	assert_eq(movimiento.avanzar(estado, 10.0).size(), 0)
	assert_true(estado.en_movimiento)
	estado.pausado = false
	assert_eq(movimiento.avanzar(estado, 10.0), [MovementSystem.EVENTO_MOVIMIENTO_TERMINADO])


func test_el_modo_seguro_cancela_y_deja_al_rover_en_la_ultima_casilla_alcanzada() -> void:
	movimiento.iniciar_mover(estado, Vector2i(3, 0))
	movimiento.avanzar(estado, 1.5 * _tramo())
	estado.modo_seguro = true
	var eventos := movimiento.avanzar(estado, 0.1)
	assert_eq(eventos, [MovementSystem.EVENTO_MOVIMIENTO_CANCELADO])
	assert_false(estado.en_movimiento)
	assert_eq(estado.casilla_rover, Vector2i(1, 0))
	assert_true(estado.movimiento_en_curso.is_empty())


func test_cancelar_antes_de_completar_una_casilla_deja_al_rover_donde_estaba() -> void:
	movimiento.iniciar_mover(estado, Vector2i(3, 0))
	movimiento.avanzar(estado, 0.5 * _tramo())
	movimiento.cancelar(estado)
	assert_eq(estado.casilla_rover, Vector2i(0, 0))
	assert_false(estado.en_movimiento)


func test_acercar_termina_en_una_casilla_contigua_al_objetivo() -> void:
	var resultado := movimiento.iniciar_acercar(estado, "JZ-01")
	assert_true(resultado["ok"])
	var ruta: Array = resultado["path"]
	var llegada: Vector2i = ruta[ruta.size() - 1]
	assert_eq(maxi(absi(llegada.x - 2), absi(llegada.y + 2)), 1, "llega a %s" % [llegada])
	assert_false(mapa.bloqueada(llegada))
	assert_eq(ruta.size(), 2, "la contigua más cercana a (2,-2) es (1,-1): 2 pasos en 4 direcciones")
	movimiento.avanzar(estado, 100.0)
	assert_eq(estado.casilla_rover, llegada)


func test_despues_de_acercar_la_ciencia_deja_de_decir_demasiado_lejos() -> void:
	var ciencia := ScienceSystem.new(balance, energia)
	estado.hora = 12.0
	assert_eq(ciencia.disponibilidad(estado, "spectrometer", "JZ-01")["reason"], "TOO_FAR")
	movimiento.iniciar_acercar(estado, "JZ-01")
	assert_eq(ciencia.disponibilidad(estado, "spectrometer", "JZ-01")["reason"], "MOVING")
	movimiento.avanzar(estado, 100.0)
	assert_true(ciencia.disponibilidad(estado, "spectrometer", "JZ-01")["enabled"])


func test_acercar_si_ya_esta_cerca_no_gasta_nada() -> void:
	estado.casilla_rover = Vector2i(1, -1)
	var resultado := movimiento.iniciar_acercar(estado, "JZ-01")
	assert_true(resultado["ok"])
	assert_eq(resultado["path"].size(), 0)
	assert_eq(estado.bateria_wh, 1000.0)
	assert_false(estado.en_movimiento)


func test_acercar_objetivo_inexistente_o_sin_revelar() -> void:
	assert_eq(movimiento.iniciar_acercar(estado, "NO-EXISTE")["reason"], "NO_TARGET")
	assert_eq(movimiento.iniciar_acercar(estado, "JZ-05")["reason"], "NO_TARGET", "enterrado sin revelar")


func test_acercar_con_energia_insuficiente() -> void:
	estado.bateria_wh = 20.0
	var resultado := movimiento.iniciar_acercar(estado, "JZ-03")
	assert_eq(resultado["reason"], "LOW_ENERGY")
	assert_eq(estado.bateria_wh, 20.0)


func test_acercar_objetivo_encerrado() -> void:
	var datos := {"limites": {"min": [-2, -2], "max": [2, 2]}, "inicio_rover": [0, 0], "estacion": [2, 2],
		"obstaculos": [[-1, -2], [-2, -1], [-1, -1]],
		"objetivos": [{"id": "T1", "casilla": [-2, -2], "tipo": "rock", "revelado": true}]}
	var pequeno := MapData.desde_texto(JSON.stringify(datos))
	assert_eq(pequeno.errores.size(), 1, "el mapa es inválido a propósito: %s" % [pequeno.errores])
	pequeno.errores.clear()
	pequeno.aplicar_a(estado)
	estado.fase = "operations"
	var sistema := MovementSystem.new(balance, energia, pequeno)
	assert_eq(sistema.iniciar_acercar(estado, "T1")["reason"], "NO_PATH")


func test_al_terminar_la_mision_se_corta_el_movimiento() -> void:
	movimiento.iniciar_mover(estado, Vector2i(3, 0))
	estado.enviados = estado.meta
	var informe := OutcomeSystem.new(reglas).evaluar(estado)
	assert_false(informe.is_empty())
	assert_true(estado.movimiento_en_curso.is_empty())
	assert_false(estado.en_movimiento)
	assert_eq(movimiento.avanzar(estado, 10.0).size(), 0)
