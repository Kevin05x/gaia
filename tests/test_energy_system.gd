extends GutTest
## Pruebas de EnergySystem con los datos reales de balance.json y rules.json.

var balance: Balance
var reglas: Rules
var estado: MissionState


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	estado = MissionState.new(balance, reglas)
	estado.polvo = 0.0


func _solar() -> EnergySystem:
	return EnergySystem.new(balance, 140.0)


func _rtg() -> EnergySystem:
	estado.energia = "rtg"
	return EnergySystem.new(balance, 110.0)


func test_es_noche() -> void:
	var energia := _solar()
	assert_true(energia.es_noche(5.9))
	assert_false(energia.es_noche(6.0))
	assert_false(energia.es_noche(17.9))
	assert_true(energia.es_noche(18.0))
	assert_true(energia.es_noche(23.0))


func test_generacion_solar_sigue_la_curva_del_sol() -> void:
	var energia := _solar()
	estado.hora = 12.0
	assert_almost_eq(energia.generacion_w(estado), 140.0, 0.01)
	estado.hora = 9.0
	assert_almost_eq(energia.generacion_w(estado), 140.0 * sin(PI * 0.25), 0.01)
	for hora in [0.0, 3.0, 6.0, 18.0, 22.0]:
		estado.hora = hora
		assert_almost_eq(energia.generacion_w(estado), 0.0, 0.01, "hora %s" % hora)


func test_polvo_y_tormenta_reducen_la_generacion_solar() -> void:
	var energia := _solar()
	estado.hora = 12.0
	estado.polvo = 0.25
	assert_almost_eq(energia.generacion_w(estado), 140.0 * 0.75, 0.01)
	estado.polvo = 0.0
	estado.tormenta = true
	assert_almost_eq(energia.generacion_w(estado), 140.0 * balance.numero("energia.factor_solar_tormenta"), 0.01)


func test_rtg_es_constante_de_dia_y_de_noche() -> void:
	var energia := _rtg()
	for hora in [3.0, 12.0, 22.0]:
		estado.hora = hora
		estado.tormenta = hora == 12.0
		assert_almost_eq(energia.generacion_w(estado), 110.0, 0.01)


func test_carga_base_y_calefaccion_nocturna() -> void:
	var base := balance.numero("energia.consumo_base_w")
	var energia := _solar()
	estado.hora = 12.0
	assert_almost_eq(energia.carga_w(estado), base, 0.01)
	estado.hora = 22.0
	assert_almost_eq(energia.carga_w(estado), base + balance.numero("energia.calefaccion_nocturna_w.solar"), 0.01)
	var energia_rtg := _rtg()
	assert_almost_eq(energia_rtg.carga_w(estado), base + balance.numero("energia.calefaccion_nocturna_w.rtg"), 0.01)


func test_avanzar_integra_la_bateria() -> void:
	var energia := _solar()
	estado.hora = 12.0
	estado.bateria_wh = 500.0
	var eventos := energia.avanzar(estado, 0.1)
	assert_eq(eventos.size(), 0)
	assert_almost_eq(estado.generacion_w, 140.0, 0.01)
	assert_almost_eq(estado.carga_w, balance.numero("energia.consumo_base_w"), 0.01)
	assert_almost_eq(estado.bateria_wh, 500.0 + (140.0 - estado.carga_w) * 0.1, 0.01)


func test_bateria_se_limita_a_su_capacidad_y_a_cero() -> void:
	var energia := _solar()
	estado.hora = 12.0
	estado.bateria_wh = estado.bateria_capacidad_wh - 1.0
	energia.avanzar(estado, 5.0)
	assert_eq(estado.bateria_wh, estado.bateria_capacidad_wh)
	estado.hora = 22.0
	estado.bateria_wh = 1.0
	energia.avanzar(estado, 5.0)
	assert_eq(estado.bateria_wh, 0.0)


func test_horas_cero_o_negativas_no_cambian_nada() -> void:
	var energia := _solar()
	estado.bateria_wh = 300.0
	assert_eq(energia.avanzar(estado, 0.0).size(), 0)
	assert_eq(energia.avanzar(estado, -1.0).size(), 0)
	assert_eq(estado.bateria_wh, 300.0)


func test_bateria_vacia_entra_en_modo_seguro() -> void:
	var energia := _solar()
	estado.hora = 22.0
	estado.bateria_wh = 1.0
	var eventos := energia.avanzar(estado, 1.0)
	assert_eq(eventos, [EnergySystem.EVENTO_ENTRA_MODO_SEGURO])
	assert_true(estado.modo_seguro)
	assert_eq(estado.entradas_modo_seguro, 1)


func test_no_vuelve_a_entrar_mientras_sigue_en_modo_seguro() -> void:
	var energia := _solar()
	estado.hora = 22.0
	estado.bateria_wh = 1.0
	energia.avanzar(estado, 1.0)
	var eventos := energia.avanzar(estado, 1.0)
	assert_eq(eventos.size(), 0)
	assert_eq(estado.entradas_modo_seguro, 1)


func test_segunda_entrada_en_modo_seguro_hace_fallar_la_mision() -> void:
	var energia := _solar()
	estado.hora = 22.0
	estado.entradas_modo_seguro = int(balance.numero("energia.modos_seguros_para_fallar")) - 1
	estado.bateria_wh = 1.0
	var eventos := energia.avanzar(estado, 1.0)
	assert_eq(eventos, [EnergySystem.EVENTO_ENTRA_MODO_SEGURO, EnergySystem.EVENTO_MISION_FALLA])


func test_sale_del_modo_seguro_al_recuperar_el_umbral() -> void:
	var energia := _solar()
	var umbral := estado.bateria_capacidad_wh * balance.numero("energia.umbral_salida_modo_seguro")
	estado.hora = 12.0
	estado.modo_seguro = true
	estado.bateria_wh = umbral - 100.0
	assert_eq(energia.avanzar(estado, 0.01).size(), 0)
	assert_true(estado.modo_seguro)
	estado.bateria_wh = umbral
	var eventos := energia.avanzar(estado, 0.01)
	assert_eq(eventos, [EnergySystem.EVENTO_SALE_MODO_SEGURO])
	assert_false(estado.modo_seguro)


func test_consumir() -> void:
	var energia := _solar()
	estado.bateria_wh = 100.0
	assert_true(energia.consumir(estado, 40.0))
	assert_eq(estado.bateria_wh, 60.0)
	assert_false(energia.consumir(estado, 61.0))
	assert_eq(estado.bateria_wh, 60.0)
	assert_true(energia.consumir(estado, 60.0))
	assert_eq(estado.bateria_wh, 0.0)
	assert_false(energia.consumir(estado, -5.0))
