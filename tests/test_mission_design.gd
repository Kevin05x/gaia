extends GutTest
## Pruebas del diseño de misión con datos de prueba propios:
## cambiar las cifras de content/*.json el 28 no debe romper estas pruebas.

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

const REGLAS := """
{
  "version": 1,
  "presupuesto_musd": 200,
  "victoria": { "datos_requeridos": 10, "sol_limite": 3 },
  "eventos": [],
  "limites_piezas": {
	"chasis": { "min": 1, "max": 1 },
	"cohetes": { "min": 1, "max": 1 },
	"energia": { "min": 1, "max": 2 },
	"comunicaciones": { "min": 1, "max": 1 },
	"extras": { "min": 0 }
  }
}
"""

var _diseno: MissionDesign


func before_each() -> void:
	_diseno = MissionDesign.new(Catalog.desde_texto(PARTES), Rules.desde_texto(REGLAS))


func _armar(ids: Array) -> void:
	for id in ids:
		assert_true(_diseno.agregar(id), "no se pudo agregar %s" % id)


func test_diseno_valido_y_totales() -> void:
	_armar(["chasis_x", "cohete_s", "solar", "antena"])
	assert_true(_diseno.es_valido(), "errores: %s" % [_diseno.validar()])
	assert_eq(_diseno.masa_total_kg(), 130.0)
	assert_eq(_diseno.costo_total_musd(), 125.0)
	assert_eq(_diseno.capacidad_kg(), 150.0)
	assert_eq(_diseno.potencia_nominal_w(), 100.0)


func test_potencia_usa_potencia_w_o_potencia_max_w() -> void:
	_armar(["solar", "rtg"])
	assert_eq(_diseno.potencia_nominal_w(), 180.0)


func test_sobrepeso() -> void:
	_armar(["chasis_x", "cohete_s", "solar", "rtg", "antena"])
	var errores := Array(_diseno.validar())
	assert_has(errores, "OVER_MASS")
	assert_does_not_have(errores, "OVER_BUDGET")


func test_sobrepresupuesto() -> void:
	_armar(["chasis_x", "cohete_m", "solar", "rtg", "antena"])
	var errores := Array(_diseno.validar())
	assert_has(errores, "OVER_BUDGET")
	assert_does_not_have(errores, "OVER_MASS")


func test_faltan_piezas_obligatorias() -> void:
	var errores := Array(_diseno.validar())
	assert_has(errores, "BELOW_MIN:chasis")
	assert_has(errores, "BELOW_MIN:cohetes")
	assert_has(errores, "BELOW_MIN:energia")
	assert_has(errores, "BELOW_MIN:comunicaciones")
	assert_does_not_have(errores, "BELOW_MIN:extras")


func test_demasiadas_piezas() -> void:
	_armar(["chasis_x", "chasis_x", "cohete_s", "solar", "antena"])
	assert_has(Array(_diseno.validar()), "ABOVE_MAX:chasis")


func test_sin_cohete_no_se_evalua_la_masa() -> void:
	_armar(["chasis_x", "solar", "antena"])
	assert_does_not_have(Array(_diseno.validar()), "OVER_MASS")


func test_agregar_id_desconocido() -> void:
	assert_false(_diseno.agregar("no_existe"))
	assert_eq(_diseno.cantidad("chasis"), 0)


func test_quitar() -> void:
	_armar(["chasis_x", "solar"])
	assert_true(_diseno.quitar("solar"))
	assert_eq(_diseno.cantidad("energia"), 0)
	assert_false(_diseno.quitar("solar"), "ya no estaba elegida")
	assert_false(_diseno.quitar("no_existe"))


func test_pieza_pendiente_avisa_y_cuenta_cero() -> void:
	_armar(["chasis_x", "cam"])
	assert_eq(_diseno.masa_total_kg(), 100.0)
	assert_has(Array(_diseno.avisos()), "PENDING_DATA:cam")
	assert_eq(_diseno.avisos().size(), 1)
