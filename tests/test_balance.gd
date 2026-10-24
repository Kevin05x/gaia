extends GutTest
## Pruebas de Balance. La lógica parte de una copia del balance real con un campo
## roto a propósito, así que no depende de las cifras concretas.

const RUTA := "res://content/balance.json"


func _base() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RUTA))


func _cargar(datos: Dictionary) -> Balance:
	return Balance.desde_texto(JSON.stringify(datos))


func test_datos_reales_sin_errores() -> void:
	var balance := Balance.desde_archivo(RUTA)
	assert_eq(balance.errores.size(), 0, "errores en balance.json: %s" % [balance.errores])


func test_numero_existente_e_inexistente() -> void:
	var balance := Balance.desde_archivo(RUTA)
	assert_gt(balance.numero("tiempo.duracion_sol_s"), 0.0)
	assert_gt(balance.numero("energia.calefaccion_nocturna_w.solar"), 0.0)
	assert_eq(balance.numero("no.existe"), 0.0)
	assert_eq(balance.numero("acciones"), 0.0, "una ruta que no es número da 0")


func test_existe() -> void:
	var balance := Balance.desde_archivo(RUTA)
	assert_true(balance.existe("energia.consumo_base_w"))
	assert_false(balance.existe("energia.no_existe"))


func test_accion() -> void:
	var balance := Balance.desde_archivo(RUTA)
	var taladro := balance.accion("drill")
	assert_true(taladro.has("costo_wh"))
	assert_true(taladro.has("duracion_s"))
	assert_eq(balance.accion("no_existe"), {})


func test_ventanas_validas_en_datos_reales() -> void:
	var balance := Balance.desde_archivo(RUTA)
	for enlace in Balance.ENLACES:
		assert_gt(balance.ventanas(enlace).size(), 0, "sin ventanas: %s" % enlace)
	assert_eq(balance.ventanas("no_existe"), [])


func test_campo_numerico_faltante() -> void:
	var datos := _base()
	datos["energia"].erase("capacidad_base_wh")
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "MISSING_FIELD:energia.capacidad_base_wh")


func test_campo_anidado_faltante() -> void:
	var datos := _base()
	datos["energia"]["calefaccion_nocturna_w"].erase("rtg")
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "MISSING_FIELD:energia.calefaccion_nocturna_w.rtg")


func test_accion_incompleta() -> void:
	var datos := _base()
	datos["acciones"]["drill"].erase("costo_wh")
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "MISSING_FIELD:acciones.drill.costo_wh")


func test_accion_ausente() -> void:
	var datos := _base()
	datos["acciones"].erase("radar")
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "MISSING_FIELD:acciones.radar.costo_wh")
	assert_has(Array(balance.errores), "MISSING_FIELD:acciones.radar.duracion_s")


func test_ventanas_invalidas() -> void:
	var datos := _base()
	datos["comunicaciones"]["rele"]["ventanas"] = [[11, 8]]
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "INVALID_FIELD:comunicaciones.rele.ventanas")


func test_ventanas_vacias() -> void:
	var datos := _base()
	datos["comunicaciones"]["directa"]["ventanas"] = []
	var balance := _cargar(datos)
	assert_has(Array(balance.errores), "INVALID_FIELD:comunicaciones.directa.ventanas")


func test_json_invalido() -> void:
	var balance := Balance.desde_texto("no es json")
	assert_has(Array(balance.errores), "INVALID_JSON")


func test_archivo_inexistente() -> void:
	var balance := Balance.desde_archivo("res://content/no_existe.json")
	assert_has(Array(balance.errores), "FILE_UNREADABLE:res://content/no_existe.json")
