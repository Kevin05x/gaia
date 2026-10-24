extends GutTest
## Pruebas de ClockSystem con los datos reales: sol de 300 s (12,5 s por hora de juego),
## tormenta en el sol 3 y ventanas del relé de 8–11 h y 17–20 h.

var balance: Balance
var reglas: Rules
var estado: MissionState
var reloj: ClockSystem
var sin_instrumentos: Array[String] = []


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	estado = MissionState.new(balance, reglas)
	estado.configurar_diseno("solar", "relay", sin_instrumentos, false)
	estado.fase = "operations"
	reloj = ClockSystem.new(balance, reglas)


func test_horas_de_juego() -> void:
	assert_almost_eq(reloj.horas_de_juego(300.0), 24.0, 0.001)
	assert_almost_eq(reloj.horas_de_juego(12.5), 1.0, 0.001)
	assert_eq(reloj.horas_de_juego(0.0), 0.0)
	assert_eq(reloj.horas_de_juego(-3.0), 0.0)


func test_es_noche() -> void:
	assert_true(reloj.es_noche(5.9))
	assert_false(reloj.es_noche(6.0))
	assert_false(reloj.es_noche(17.9))
	assert_true(reloj.es_noche(18.0))


func test_el_tiempo_no_corre_fuera_de_operaciones_ni_en_pausa() -> void:
	estado.fase = "landing"
	assert_eq(reloj.avanzar(estado, 12.5).size(), 0)
	assert_eq(estado.hora, 8.0)
	estado.fase = "operations"
	estado.pausado = true
	assert_eq(reloj.avanzar(estado, 12.5).size(), 0)
	assert_eq(estado.hora, 8.0)
	estado.pausado = false
	estado.fase = "report"
	reloj.avanzar(estado, 12.5)
	assert_eq(estado.hora, 8.0)


func test_el_modo_seguro_no_detiene_el_reloj() -> void:
	estado.modo_seguro = true
	reloj.avanzar(estado, 12.5)
	assert_almost_eq(estado.hora, 9.0, 0.001)


func test_avanza_la_hora() -> void:
	reloj.avanzar(estado, 12.5)
	assert_almost_eq(estado.hora, 9.0, 0.001)
	assert_eq(estado.sol, 1)


func test_cambia_de_sol() -> void:
	estado.hora = 23.5
	var eventos := reloj.avanzar(estado, 12.5)
	assert_eq(estado.sol, 2)
	assert_almost_eq(estado.hora, 0.5, 0.001)
	assert_true(eventos.has(ClockSystem.EVENTO_SOL_NUEVO))


func test_sin_eventos_falsos_en_el_primer_avance() -> void:
	assert_eq(reloj.avanzar(estado, 1.0).size(), 0)


func test_tormenta_en_el_sol_3() -> void:
	estado.sol = 2
	estado.hora = 23.9
	var eventos := reloj.avanzar(estado, 3.0)
	assert_eq(estado.sol, 3)
	assert_true(estado.tormenta)
	assert_true(eventos.has(ClockSystem.EVENTO_TORMENTA_INICIA))
	estado.hora = 23.9
	eventos = reloj.avanzar(estado, 3.0)
	assert_eq(estado.sol, 4)
	assert_false(estado.tormenta)
	assert_true(eventos.has(ClockSystem.EVENTO_TORMENTA_TERMINA))


func test_soles_hasta_la_tormenta() -> void:
	reloj.actualizar(estado)
	assert_almost_eq(estado.tormenta_en, 3.0 - 1.0 - 8.0 / 24.0, 0.001)
	estado.sol = 3
	reloj.actualizar(estado)
	assert_eq(estado.tormenta_en, 0.0)
	estado.sol = 4
	reloj.actualizar(estado)
	assert_eq(estado.tormenta_en, 0.0)


func test_ventanas_del_rele() -> void:
	for caso in [[7.99, false], [8.0, true], [10.99, true], [11.0, false], [16.9, false], [17.5, true], [20.0, false]]:
		estado.hora = caso[0]
		reloj.actualizar(estado)
		assert_eq(estado.enlace_abierto, caso[1], "hora %s" % caso[0])


func test_ventana_de_la_antena_directa() -> void:
	estado.configurar_diseno("solar", "direct", sin_instrumentos, false)
	for caso in [[5.9, false], [6.0, true], [12.0, true], [17.9, true], [18.0, false]]:
		estado.hora = caso[0]
		reloj.actualizar(estado)
		assert_eq(estado.enlace_abierto, caso[1], "hora %s" % caso[0])


func test_proximo_cambio_del_enlace() -> void:
	estado.hora = 9.0
	reloj.actualizar(estado)
	assert_eq(estado.proximo_cambio_enlace, {"opens": false, "hour": 11.0, "sol": 1})
	estado.hora = 12.0
	reloj.actualizar(estado)
	assert_eq(estado.proximo_cambio_enlace, {"opens": true, "hour": 17.0, "sol": 1})
	estado.hora = 21.0
	reloj.actualizar(estado)
	assert_eq(estado.proximo_cambio_enlace, {"opens": true, "hour": 8.0, "sol": 2})
	estado.hora = 5.0
	reloj.actualizar(estado)
	assert_eq(estado.proximo_cambio_enlace, {"opens": true, "hour": 8.0, "sol": 1})


func test_eventos_de_enlace_y_de_noche() -> void:
	estado.hora = 7.9
	assert_true(reloj.avanzar(estado, 2.5).has(ClockSystem.EVENTO_ENLACE_ABRE))
	estado.hora = 10.9
	assert_true(reloj.avanzar(estado, 2.5).has(ClockSystem.EVENTO_ENLACE_CIERRA))
	estado.hora = 17.9
	assert_true(reloj.avanzar(estado, 2.5).has(ClockSystem.EVENTO_ANOCHECE))
	estado.hora = 5.9
	assert_true(reloj.avanzar(estado, 2.5).has(ClockSystem.EVENTO_AMANECE))
