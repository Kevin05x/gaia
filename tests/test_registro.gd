extends GutTest
## Códigos de diseño (compartir y comparar) y puntuación de récords.

const Registro := preload("res://scenes/menu/registro.gd")


func test_el_codigo_ida_y_vuelta_conserva_las_piezas() -> void:
	var seleccion := {"cohetes": ["cohete_ligero"], "trayectoria": ["trayectoria_hohmann"], "chasis": ["chasis_base"],
		"energia": ["panel_solar"], "comunicaciones": ["antena_rele"], "extras": ["camara", "taladro"]}
	var codigo := Registro.codigo(seleccion, "marte")
	assert_true(codigo.begins_with("GAIA-M-"))
	var leido := Registro.leer_codigo(codigo.to_lower())
	assert_eq(leido["destino"], "marte")
	var esperado: Array = []
	for c in seleccion:
		esperado.append_array(seleccion[c])
	esperado.sort()
	var piezas: Array = leido["piezas"]
	piezas.sort()
	assert_eq(piezas, esperado)
	assert_true(Registro.codigo(seleccion, "luna").begins_with("GAIA-L-"))


func test_codigos_invalidos() -> void:
	assert_eq(Registro.leer_codigo("hola"), {})
	assert_eq(Registro.leer_codigo("GAIA-X-AB"), {})
	assert_eq(Registro.leer_codigo("GAIA-M-A9"), {})


func test_la_puntuacion_premia_ciencia_exito_y_ahorro() -> void:
	var taller := {"totals": {"budget_musd": 700, "cost_musd": 600}}
	var malo := Registro.puntuacion({"sent": 40, "goal": 100, "stars": 0, "success": false}, taller)
	var bueno := Registro.puntuacion({"sent": 100, "goal": 100, "stars": 3, "success": true}, taller)
	assert_eq(malo, 240 + 100)
	assert_eq(bueno, 600 + 450 + 300 + 100)
