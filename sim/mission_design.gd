class_name MissionDesign
extends RefCounted
## Diseño de misión del taller: piezas elegidas y sus totales.
## Simulación pura: sin nodos. Todo número sale de Catalog y Rules (datos), nunca del código.
## validar() devuelve códigos (no textos) para que la interfaz los traduzca con tr().

## Categorías que suman masa a la nave. El cohete no suma: su "capacidad_kg" es el tope.
const CATEGORIAS_CON_MASA: Array[String] = ["chasis", "energia", "comunicaciones", "extras"]

## De piezas del taller a diseño de misión (vocabulario de la vista; ver INTEGRACION_A.md).
const ENERGIA_POR_PIEZA: Dictionary = {"panel_solar": "solar", "mmrtg": "rtg"}
const ENLACE_POR_PIEZA: Dictionary = {"antena_rele": "relay", "antena_directa": "direct"}
const INSTRUMENTO_POR_PIEZA: Dictionary = {"camara": "panorama", "espectrometro": "spectrometer", "taladro": "drill",
	"radar": "radar", "dron": "drone", "meteo": "meteo"}
const PIEZA_COMPANERO := "companero"

var seleccion: Dictionary = {}  ## categoria -> Array de ids elegidos

var _catalogo: Catalog
var _reglas: Rules


func _init(catalogo: Catalog, reglas: Rules) -> void:
	_catalogo = catalogo
	_reglas = reglas
	for categoria in Catalog.CATEGORIAS:
		seleccion[categoria] = []


## Devuelve false si el id no existe en el catálogo.
func agregar(id: String) -> bool:
	if not _catalogo.tiene(id):
		return false
	var categoria: String = _catalogo.obtener(id)["categoria"]
	seleccion[categoria].append(id)
	return true


## Quita una unidad de la pieza. Devuelve false si no estaba elegida.
func quitar(id: String) -> bool:
	if not _catalogo.tiene(id):
		return false
	var categoria: String = _catalogo.obtener(id)["categoria"]
	var lista: Array = seleccion[categoria]
	var posicion := lista.find(id)
	if posicion == -1:
		return false
	lista.remove_at(posicion)
	return true


func cantidad(categoria: String) -> int:
	return (seleccion.get(categoria, []) as Array).size()


func masa_total_kg() -> float:
	return _suma("masa_kg", CATEGORIAS_CON_MASA)


func costo_total_musd() -> float:
	return _suma("costo_musd", Catalog.CATEGORIAS)


## Lo que puede subir el cohete elegido (0 si no hay cohete).
func capacidad_kg() -> float:
	return _suma("capacidad_kg", ["cohetes"])


## Potencia nominal de las fuentes elegidas: "potencia_w" o, si no existe, "potencia_max_w".
## Todavía no considera el sol, la tormenta de polvo ni el consumo (sistema de energía, más adelante).
func potencia_nominal_w() -> float:
	var total := 0.0
	for id in seleccion["energia"]:
		var pieza := _catalogo.obtener(id)
		total += _valor(pieza, "potencia_w") if pieza.has("potencia_w") else _valor(pieza, "potencia_max_w")
	return total


## Errores que impiden lanzar la misión: BELOW_MIN:<cat>, ABOVE_MAX:<cat>, OVER_MASS, OVER_BUDGET.
func validar() -> PackedStringArray:
	var errores := PackedStringArray()
	for categoria in Catalog.CATEGORIAS:
		var elegidas := cantidad(categoria)
		if elegidas < _reglas.limite_min(categoria):
			errores.append("BELOW_MIN:%s" % categoria)
		var maximo := _reglas.limite_max(categoria)
		if maximo >= 0 and elegidas > maximo:
			errores.append("ABOVE_MAX:%s" % categoria)
	if cantidad("cohetes") > 0 and masa_total_kg() > capacidad_kg():
		errores.append("OVER_MASS")
	if costo_total_musd() > _reglas.presupuesto_musd:
		errores.append("OVER_BUDGET")
	return errores


## Avisos que no bloquean: PENDING_DATA:<id> por cada pieza elegida con datos pendientes.
func avisos() -> PackedStringArray:
	var resultado := PackedStringArray()
	for categoria in seleccion:
		for id in seleccion[categoria]:
			if id in _catalogo.pendientes:
				resultado.append("PENDING_DATA:%s" % id)
	return resultado


func es_valido() -> bool:
	return validar().is_empty()


## Lo que la simulación necesita saber del diseño elegido: {"energia", "enlace", "instrumentos",
## "companero", "potencia_nominal_w"}. "energia" o "enlace" quedan vacíos si la pieza no se reconoce.
func a_configuracion() -> Dictionary:
	var energia := ""
	for id in seleccion["energia"]:
		energia = ENERGIA_POR_PIEZA.get(id, "")
	var enlace := ""
	for id in seleccion["comunicaciones"]:
		enlace = ENLACE_POR_PIEZA.get(id, "")
	var instrumentos: Array[String] = []
	var companero := false
	for id in seleccion["extras"]:
		if id == PIEZA_COMPANERO:
			companero = true
		elif INSTRUMENTO_POR_PIEZA.has(id) and not instrumentos.has(INSTRUMENTO_POR_PIEZA[id]):
			instrumentos.append(INSTRUMENTO_POR_PIEZA[id])
	return {"energia": energia, "enlace": enlace, "instrumentos": instrumentos, "companero": companero,
		"potencia_nominal_w": potencia_nominal_w()}


func _suma(campo: String, categorias: Array) -> float:
	var total := 0.0
	for categoria in categorias:
		for id in seleccion[categoria]:
			total += _valor(_catalogo.obtener(id), campo)
	return total


## Un valor null (dato pendiente) o ausente cuenta como 0.
static func _valor(pieza: Dictionary, campo: String) -> float:
	var valor: Variant = pieza.get(campo)
	return float(valor) if (valor is float or valor is int) else 0.0
