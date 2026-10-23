extends GutTest
## Pruebas de las reglas de misión. La lógica usa datos de prueba propios;
## los datos reales solo se comprueban en lo que no cambia.

const REGLAS := """
{
  "version": 1,
  "presupuesto_musd": 200,
  "victoria": { "datos_requeridos": 10, "sol_limite": 3 },
  "eventos": [ { "tipo": "tormenta_polvo", "soles": [2, 3] } ],
  "limites_piezas": {
	"chasis": { "min": 1, "max": 1 },
	"energia": { "min": 1, "max": 2 },
	"extras": { "min": 0 }
  }
}
"""


func test_carga_valores() -> void:
	var reglas := Rules.desde_texto(REGLAS)
	assert_eq(reglas.errores.size(), 0)
	assert_eq(reglas.presupuesto_musd, 200.0)
	assert_eq(reglas.datos_requeridos, 10)
	assert_eq(reglas.sol_limite, 3)


func test_limites_por_categoria() -> void:
	var reglas := Rules.desde_texto(REGLAS)
	assert_eq(reglas.limite_min("chasis"), 1)
	assert_eq(reglas.limite_max("energia"), 2)
	assert_eq(reglas.limite_max("extras"), -1, "sin max = sin límite")
	assert_eq(reglas.limite_min("categoria_inexistente"), 0)
	assert_eq(reglas.limite_max("categoria_inexistente"), -1)


func test_soles_de_evento() -> void:
	var reglas := Rules.desde_texto(REGLAS)
	var soles := reglas.soles_de_evento("tormenta_polvo")
	assert_eq(soles.size(), 2)
	assert_eq(soles[0], 2)
	assert_eq(soles[1], 3)
	assert_eq(reglas.soles_de_evento("otro_evento").size(), 0)


func test_campos_faltantes() -> void:
	var reglas := Rules.desde_texto("{}")
	assert_has(Array(reglas.errores), "MISSING_FIELD:presupuesto_musd")
	assert_has(Array(reglas.errores), "MISSING_FIELD:victoria")


func test_json_invalido() -> void:
	var reglas := Rules.desde_texto("no es json")
	assert_has(Array(reglas.errores), "INVALID_JSON")


func test_datos_reales_son_consistentes() -> void:
	var reglas := Rules.desde_archivo("res://content/rules.json")
	assert_eq(reglas.errores.size(), 0, "errores en rules.json: %s" % [reglas.errores])
	assert_gt(reglas.presupuesto_musd, 0.0)
	assert_gt(reglas.datos_requeridos, 0)
	assert_gt(reglas.sol_limite, 0)
