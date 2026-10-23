extends GutTest
## Pruebas del catálogo de piezas. La lógica usa datos de prueba propios;
## los datos reales solo se comprueban en lo que no cambia (sin errores, ids y claves únicos).

const PARTES := """
{
  "version": 1,
  "chasis": [ { "id": "chasis_x", "nombre_clave": "K1", "masa_kg": 100, "costo_musd": 50 } ],
  "cohetes": [
	{ "id": "cohete_s", "nombre_clave": "K2", "capacidad_kg": 150, "costo_musd": 60 },
	{ "id": "cohete_m", "nombre_clave": "K3", "capacidad_kg": 400, "costo_musd": 120 }
  ],
  "energia": [
	{ "id": "solar", "nombre_clave": "K4", "masa_kg": 20, "costo_musd": 10, "potencia_max_w": 100 },
	{ "id": "rtg", "nombre_clave": "K5", "masa_kg": 40, "costo_musd": 70, "potencia_w": 80 }
  ],
  "comunicaciones": [ { "id": "antena", "nombre_clave": "K6", "masa_kg": 10, "costo_musd": 5 } ],
  "extras": [
	{ "id": "cam", "nombre_clave": "K7", "masa_kg": null, "costo_musd": null, "potencia_w": null, "pendiente": true }
  ]
}
"""


func test_carga_sin_errores() -> void:
	var catalogo := Catalog.desde_texto(PARTES)
	assert_eq(catalogo.errores.size(), 0)
	assert_eq(catalogo.piezas.size(), 7)


func test_consulta_por_id_y_categoria() -> void:
	var catalogo := Catalog.desde_texto(PARTES)
	assert_true(catalogo.tiene("solar"))
	assert_false(catalogo.tiene("no_existe"))
	assert_eq(catalogo.obtener("solar")["categoria"], "energia")
	assert_eq(catalogo.ids_de("cohetes").size(), 2)
	assert_eq(catalogo.obtener("no_existe"), {})


func test_detecta_piezas_pendientes() -> void:
	var catalogo := Catalog.desde_texto(PARTES)
	assert_eq(catalogo.pendientes.size(), 1)
	assert_eq(catalogo.pendientes[0], "cam")


func test_detecta_id_duplicado() -> void:
	var texto := """
	{ "chasis": [
		{ "id": "a", "nombre_clave": "K", "masa_kg": 1, "costo_musd": 1 },
		{ "id": "a", "nombre_clave": "K", "masa_kg": 1, "costo_musd": 1 }
	] }
	"""
	var catalogo := Catalog.desde_texto(texto)
	assert_has(Array(catalogo.errores), "DUPLICATE_ID:a")


func test_detecta_campo_faltante() -> void:
	var texto := """
	{ "chasis": [ { "id": "a", "nombre_clave": "K", "costo_musd": 1 } ] }
	"""
	var catalogo := Catalog.desde_texto(texto)
	assert_has(Array(catalogo.errores), "MISSING_FIELD:a:masa_kg")


func test_pieza_pendiente_no_exige_campos() -> void:
	var texto := """
	{ "extras": [ { "id": "x", "nombre_clave": "K", "pendiente": true } ] }
	"""
	var catalogo := Catalog.desde_texto(texto)
	assert_eq(catalogo.errores.size(), 0)


func test_json_invalido() -> void:
	var catalogo := Catalog.desde_texto("esto no es json")
	assert_has(Array(catalogo.errores), "INVALID_JSON")


func test_archivo_inexistente() -> void:
	var catalogo := Catalog.desde_archivo("res://content/no_existe.json")
	assert_has(Array(catalogo.errores), "FILE_UNREADABLE:res://content/no_existe.json")


func test_datos_reales_son_consistentes() -> void:
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	assert_eq(catalogo.errores.size(), 0, "errores en parts.json: %s" % [catalogo.errores])
	assert_gt(catalogo.piezas.size(), 0)
	var claves := {}
	for id in catalogo.piezas:
		var clave: String = catalogo.piezas[id].get("nombre_clave", "")
		assert_false(claves.has(clave), "nombre_clave repetido: %s" % clave)
		claves[clave] = true
