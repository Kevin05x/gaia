extends GutTest
## Pruebas de CommsSystem con los datos reales de balance.json y rules.json.

var balance: Balance
var reglas: Rules
var estado: MissionState
var comunicaciones: CommsSystem
var sin_instrumentos: Array[String] = []


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	estado = MissionState.new(balance, reglas)
	estado.configurar_diseno("solar", "relay", sin_instrumentos, false)
	estado.fase = "operations"
	estado.enlace_abierto = true
	estado.datos = 20.0
	comunicaciones = CommsSystem.new(balance)


func test_encender_exige_enlace_y_datos() -> void:
	estado.enlace_abierto = false
	assert_eq(comunicaciones.transmitir(estado, true)["reason"], "NO_LINK")
	estado.enlace_abierto = true
	estado.datos = 0.0
	assert_eq(comunicaciones.transmitir(estado, true)["reason"], "NO_DATA")
	estado.datos = 5.0
	assert_true(comunicaciones.transmitir(estado, true)["ok"])
	assert_true(estado.transmitiendo)


func test_motivos_por_estado_de_la_mision() -> void:
	estado.fase = "landing"
	assert_eq(comunicaciones.disponibilidad(estado)["reason"], "LANDING")
	estado.fase = "report"
	assert_eq(comunicaciones.disponibilidad(estado)["reason"], "MISSION_END")
	estado.fase = "operations"
	estado.pausado = true
	assert_eq(comunicaciones.disponibilidad(estado)["reason"], "PAUSED")
	estado.pausado = false
	estado.modo_seguro = true
	assert_eq(comunicaciones.disponibilidad(estado)["reason"], "SAFE")


func test_apagar_siempre_se_puede_y_no_pide_enlace_si_ya_transmite() -> void:
	estado.transmitiendo = true
	estado.enlace_abierto = false
	assert_true(comunicaciones.disponibilidad(estado)["enabled"])
	assert_true(comunicaciones.transmitir(estado, false)["ok"])
	assert_false(estado.transmitiendo)


func test_el_rele_envia_unidades_y_gasta_energia() -> void:
	estado.transmitiendo = true
	var bateria := estado.bateria_wh
	var por_s := balance.numero("comunicaciones.rele.unidades_por_s")
	var costo := balance.numero("comunicaciones.rele.costo_wh_por_unidad")
	comunicaciones.avanzar(estado, 1.0)
	assert_almost_eq(estado.enviados, por_s, 0.001)
	assert_almost_eq(estado.datos, 20.0 - por_s, 0.001)
	assert_almost_eq(estado.bateria_wh, bateria - por_s * costo, 0.001)


func test_el_nivel_de_antena_multiplica_el_ritmo() -> void:
	estado.transmitiendo = true
	estado.nivel_antena = 2
	comunicaciones.avanzar(estado, 1.0)
	assert_almost_eq(estado.enviados, balance.numero("comunicaciones.rele.unidades_por_s") * 2.0, 0.001)


func test_la_antena_directa_es_mas_lenta_y_cara() -> void:
	estado.configurar_diseno("solar", "direct", sin_instrumentos, false)
	estado.transmitiendo = true
	var bateria := estado.bateria_wh
	var por_s := balance.numero("comunicaciones.directa.unidades_por_s")
	var costo := balance.numero("comunicaciones.directa.costo_wh_por_unidad")
	comunicaciones.avanzar(estado, 1.0)
	assert_almost_eq(estado.enviados, por_s, 0.001)
	assert_almost_eq(estado.bateria_wh, bateria - por_s * costo, 0.001)


func test_termina_cuando_se_acaban_los_datos() -> void:
	estado.transmitiendo = true
	estado.datos = 3.0
	var eventos := comunicaciones.avanzar(estado, 10.0)
	assert_almost_eq(estado.enviados, 3.0, 0.001)
	assert_eq(estado.datos, 0.0)
	assert_false(estado.transmitiendo)
	assert_eq(eventos, [CommsSystem.EVENTO_TRANSMISION_TERMINADA])


func test_se_limita_por_la_energia_disponible() -> void:
	estado.transmitiendo = true
	estado.bateria_wh = 4.0
	var costo := balance.numero("comunicaciones.rele.costo_wh_por_unidad")
	comunicaciones.avanzar(estado, 10.0)
	assert_almost_eq(estado.enviados, 4.0 / costo, 0.001)
	assert_almost_eq(estado.bateria_wh, 0.0, 0.001)
	assert_true(estado.transmitiendo)


func test_con_el_enlace_cerrado_no_fluye_pero_sigue_encendida() -> void:
	estado.transmitiendo = true
	estado.enlace_abierto = false
	assert_eq(comunicaciones.avanzar(estado, 5.0).size(), 0)
	assert_eq(estado.enviados, 0.0)
	assert_true(estado.transmitiendo)


func test_el_modo_seguro_corta_la_transmision() -> void:
	estado.transmitiendo = true
	estado.modo_seguro = true
	var eventos := comunicaciones.avanzar(estado, 1.0)
	assert_false(estado.transmitiendo)
	assert_eq(eventos, [CommsSystem.EVENTO_TRANSMISION_TERMINADA])
	assert_eq(estado.enviados, 0.0)


func test_sin_transmitir_o_en_pausa_no_cambia_nada() -> void:
	comunicaciones.avanzar(estado, 5.0)
	assert_eq(estado.enviados, 0.0)
	estado.transmitiendo = true
	estado.pausado = true
	comunicaciones.avanzar(estado, 5.0)
	assert_eq(estado.enviados, 0.0)
