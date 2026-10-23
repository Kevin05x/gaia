extends GutTest
## Pruebas de OutcomeSystem con los datos reales: meta de 100 y límite de 6 soles.

var balance: Balance
var reglas: Rules
var estado: MissionState
var resultado: OutcomeSystem
var sin_instrumentos: Array[String] = []
var sin_eventos: Array[String] = []


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")
	estado = MissionState.new(balance, reglas)
	estado.configurar_diseno("solar", "relay", sin_instrumentos, false)
	estado.fase = "operations"
	resultado = OutcomeSystem.new(reglas)


func test_la_mision_continua_si_no_hay_meta_ni_fallo() -> void:
	estado.enviados = 50.0
	assert_true(resultado.evaluar(estado).is_empty())
	assert_eq(estado.fase, "operations")


func test_no_evalua_fuera_de_operaciones() -> void:
	estado.enviados = 100.0
	estado.fase = "landing"
	assert_true(resultado.evaluar(estado).is_empty())
	estado.fase = "report"
	assert_true(resultado.evaluar(estado).is_empty())


func test_exito_al_llegar_a_la_meta_y_detiene_todo() -> void:
	estado.enviados = float(estado.meta)
	estado.transmitiendo = true
	estado.ocupado = true
	estado.en_movimiento = true
	estado.accion_en_curso = {"action": "drill"}
	var informe := resultado.evaluar(estado)
	assert_true(informe["success"])
	assert_eq(informe["sent"], estado.meta)
	assert_eq(informe["goal"], estado.meta)
	assert_eq(estado.fase, "report")
	assert_false(estado.transmitiendo)
	assert_false(estado.ocupado)
	assert_false(estado.en_movimiento)
	assert_true(estado.accion_en_curso.is_empty())


func test_lo_enviado_se_informa_como_entero() -> void:
	estado.enviados = 123.9
	assert_eq(resultado.evaluar(estado)["sent"], 123)


func test_el_exito_tiene_prioridad_sobre_el_plazo() -> void:
	estado.enviados = float(estado.meta)
	estado.sol = reglas.sol_limite + 1
	assert_true(resultado.evaluar(estado)["success"])


func test_fracasa_por_modo_seguro_repetido() -> void:
	var eventos: Array[String] = [EnergySystem.EVENTO_MISION_FALLA]
	estado.entradas_modo_seguro = 2
	var informe := resultado.evaluar(estado, eventos)
	assert_false(informe["success"])
	assert_eq(informe["stars"], 0)
	assert_eq(informe["causes"][0], OutcomeSystem.CAUSA_FALLO_MODO_SEGURO)
	assert_false(informe["causes"].has(OutcomeSystem.CAUSA_MODO_SEGURO))
	assert_eq(estado.fase, "report")


func test_fracasa_al_pasar_del_ultimo_sol_y_no_antes() -> void:
	estado.sol = reglas.sol_limite
	estado.hora = 23.9
	assert_true(resultado.evaluar(estado).is_empty())
	estado.sol = reglas.sol_limite + 1
	var informe := resultado.evaluar(estado)
	assert_false(informe["success"])
	assert_eq(informe["stars"], 0)
	assert_eq(informe["causes"][0], OutcomeSystem.CAUSA_PLAZO)
	assert_eq(informe["sol"], reglas.sol_limite)


func test_estrellas() -> void:
	# [entradas en modo seguro, sol al terminar, estrellas esperadas]
	var casos := [[0, 3, 3], [1, 3, 2], [0, 5, 3], [0, 6, 2], [1, 6, 1]]
	for caso in casos:
		estado.fase = "operations"
		estado.entradas_modo_seguro = caso[0]
		estado.sol = caso[1]
		estado.enviados = float(estado.meta)
		assert_eq(resultado.evaluar(estado)["stars"], caso[2], "caso %s" % [caso])


func test_causas_segun_el_diseno() -> void:
	estado.enviados = float(estado.meta)
	assert_eq(resultado.evaluar(estado)["causes"], [OutcomeSystem.CAUSA_EXITO, OutcomeSystem.CAUSA_SOLAR, OutcomeSystem.CAUSA_RELE])
	estado.fase = "operations"
	estado.configurar_diseno("rtg", "direct", sin_instrumentos, false)
	estado.entradas_modo_seguro = 1
	assert_eq(resultado.evaluar(estado)["causes"], [OutcomeSystem.CAUSA_EXITO, OutcomeSystem.CAUSA_RTG, OutcomeSystem.CAUSA_DIRECTA, OutcomeSystem.CAUSA_MODO_SEGURO])


func test_todas_las_causas_tienen_texto_en_el_catalogo_de_la_interfaz() -> void:
	var csv := FileAccess.get_file_as_string("res://scenes/b/i18n/strings_ui.csv")
	var claves := [OutcomeSystem.CAUSA_EXITO, OutcomeSystem.CAUSA_PLAZO, OutcomeSystem.CAUSA_FALLO_MODO_SEGURO,
		OutcomeSystem.CAUSA_MODO_SEGURO, OutcomeSystem.CAUSA_SOLAR, OutcomeSystem.CAUSA_RTG,
		OutcomeSystem.CAUSA_RELE, OutcomeSystem.CAUSA_DIRECTA]
	for clave in claves:
		assert_true(csv.contains("\n" + clave + ","), "falta %s en strings_ui.csv" % clave)
	var catalogo := FileAccess.get_file_as_string("res://scenes/b/i18n/catalog.gd")
	for clave in claves:
		assert_true(catalogo.contains("\"" + clave + "\""), "falta %s en catalog.gd" % clave)
