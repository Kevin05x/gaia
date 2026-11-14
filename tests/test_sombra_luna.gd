extends GutTest
## Energía de la Luna (polo sur): el Sol roza el horizonte (factor_solar_max) y las zonas de sombra permanente
## no dan energía solar. Marte no cambia. Datos reales de balance_luna.json y mapa_luna.json.

var balance_luna: Balance
var balance_marte: Balance
var reglas: Rules
var mapa: MapData
var estado: MissionState


func before_each() -> void:
	balance_luna = Balance.desde_archivo("res://content/balance_luna.json")
	balance_marte = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules_luna.json")
	mapa = MapData.desde_archivo("res://content/mapa_luna.json")
	estado = MissionState.new(balance_luna, reglas)
	estado.polvo = 0.0
	mapa.aplicar_a(estado)
	estado.hora = 12.0  # mediodía: curva del sol en su máximo


func test_los_datos_de_la_luna_cargan_sin_errores() -> void:
	assert_eq(balance_luna.errores.size(), 0)
	assert_eq(mapa.errores.size(), 0, str(mapa.errores))
	assert_eq(mapa.sombras.size(), 2)
	assert_eq(estado.sombras.size(), 2)


func test_balance_sabe_si_una_clave_opcional_existe() -> void:
	assert_true(balance_luna.tiene("energia.factor_solar_max"))
	assert_false(balance_marte.tiene("energia.factor_solar_max"))


func test_el_sol_bajo_de_la_luna_reduce_el_panel() -> void:
	var energia := EnergySystem.new(balance_luna, 140.0)
	estado.casilla_rover = Vector2i(0, 0)  # al sol
	assert_almost_eq(energia.generacion_w(estado), 140.0 * balance_luna.numero("energia.factor_solar_max"), 0.01)
	assert_lt(energia.generacion_w(estado), 140.0)


func test_en_sombra_permanente_el_panel_no_genera() -> void:
	var energia := EnergySystem.new(balance_luna, 140.0)
	estado.casilla_rover = Vector2i(-4, -6)  # centro de la sombra A
	assert_true(estado.en_sombra(estado.casilla_rover))
	assert_eq(energia.generacion_w(estado), 0.0)
	assert_eq(energia.factor_solar(estado), 0.0)


func test_al_salir_de_la_sombra_vuelve_a_generar() -> void:
	var energia := EnergySystem.new(balance_luna, 140.0)
	estado.casilla_rover = Vector2i(-4, -6)
	assert_eq(energia.generacion_w(estado), 0.0)
	estado.casilla_rover = Vector2i(0, 0)
	assert_gt(energia.generacion_w(estado), 0.0)


func test_el_rtg_no_depende_del_sol_ni_de_la_sombra() -> void:
	estado.energia = "rtg"
	var energia := EnergySystem.new(balance_luna, 110.0)
	estado.casilla_rover = Vector2i(0, 0)
	var al_sol := energia.generacion_w(estado)
	estado.casilla_rover = Vector2i(-4, -6)
	assert_eq(energia.generacion_w(estado), al_sol)
	assert_eq(al_sol, 110.0)


func test_marte_no_cambia() -> void:
	var reglas_marte := Rules.desde_archivo("res://content/rules.json")
	var estado_marte := MissionState.new(balance_marte, reglas_marte)
	estado_marte.polvo = 0.0
	estado_marte.hora = 12.0
	var energia := EnergySystem.new(balance_marte, 140.0)
	assert_eq(estado_marte.sombras.size(), 0)
	assert_almost_eq(energia.generacion_w(estado_marte), 140.0, 0.01)


func test_el_snapshot_avisa_de_la_sombra() -> void:
	estado.casilla_rover = Vector2i(-4, -6)
	assert_true(bool(estado.a_snapshot()["in_shadow"]))
	estado.casilla_rover = Vector2i(0, 0)
	assert_false(bool(estado.a_snapshot()["in_shadow"]))


func test_el_hielo_enterrado_esta_en_las_sombras() -> void:
	# NASA: el hielo está en regiones de sombra permanente. Al menos un objetivo enterrado debe estar en sombra.
	var en_sombra := 0
	for objetivo in mapa.objetivos:
		if objetivo["type"] == "buried" and estado.en_sombra(objetivo["tile"]):
			en_sombra += 1
	assert_gt(en_sombra, 0)


func test_la_estacion_y_el_inicio_estan_al_sol() -> void:
	assert_false(estado.en_sombra(mapa.estacion))
	assert_false(estado.en_sombra(mapa.inicio_rover))


func test_sombras_invalidas_se_rechazan() -> void:
	var texto := FileAccess.get_file_as_string("res://content/mapa_luna.json")
	var datos: Dictionary = JSON.parse_string(texto)
	datos["sombras"] = [{"id": "mala", "centro": [0, 0], "radio": -2}]
	var malo := MapData.desde_texto(JSON.stringify(datos))
	assert_gt(malo.errores.size(), 0)
