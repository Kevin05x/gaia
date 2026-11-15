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
## Herramientas con las que arranca cualquier misión: con qué cavar y con qué mirar. Van puestas de
## salida en cuanto hay cohete, porque empezar con el rover desnudo deja al jugador delante de una
## lista en blanco sin saber por dónde entrar. Se pueden quitar, pero entonces el taller avisa.
const HERRAMIENTAS_BASICAS: Array[String] = ["taladro", "camara"]
## Instrumentos sin los que se pierde una parte del juego (la antena ya es obligatoria). Si falta uno, el taller avisa
## en rojo y pide confirmación al despegar, pero no bloquea.
const INSTRUMENTOS_CLAVE: Array[String] = ["taladro", "espectrometro", "camara"]

var seleccion: Dictionary = {}  ## categoria -> Array de ids elegidos

var _catalogo: Catalog
var _reglas: Rules


func _init(catalogo: Catalog, reglas: Rules) -> void:
	_catalogo = catalogo
	_reglas = reglas
	for categoria in Catalog.CATEGORIAS:
		seleccion[categoria] = []
	elegir_trayectoria_por_defecto()


## La trayectoria siempre tiene un valor: si no hay ninguna elegida se usa la primera del catálogo
## (la transferencia de Hohmann), así los diseños antiguos y las pruebas siguen siendo válidos.
func elegir_trayectoria_por_defecto() -> void:
	if (seleccion.get("trayectoria", []) as Array).is_empty():
		var ids := _catalogo.ids_de("trayectoria")
		if not ids.is_empty():
			seleccion["trayectoria"] = [ids[0]]


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


## Lo que puede subir el cohete elegido (0 si no hay cohete), según la trayectoria: una transferencia rápida
## pide más energía al cohete, así que lleva menos masa a Marte (factor_capacidad < 1).
func capacidad_kg() -> float:
	return _suma("capacidad_kg", ["cohetes"]) * factor_trayectoria()


## Multiplicador de la capacidad del cohete por la trayectoria elegida (1 si no hay trayectoria).
func factor_trayectoria() -> float:
	var lista: Array = seleccion.get("trayectoria", [])
	if lista.is_empty():
		return 1.0
	var valor: Variant = _catalogo.obtener(lista[0]).get("factor_capacidad", 1.0)
	return float(valor) if (valor is float or valor is int) else 1.0


## Días de crucero de la Tierra a Marte con la trayectoria elegida (0 si no hay).
func dias_crucero() -> int:
	var lista: Array = seleccion.get("trayectoria", [])
	if lista.is_empty():
		return 0
	return int(_catalogo.obtener(lista[0]).get("dias_crucero", 0))


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


## Avisos que no bloquean: PENDING_DATA:<id> por cada pieza elegida con datos pendientes y, con cohete elegido,
## MISSING_KEY:<id> por cada instrumento clave que no lleva el rover.
func avisos() -> PackedStringArray:
	var resultado := PackedStringArray()
	for categoria in seleccion:
		for id in seleccion[categoria]:
			if id in _catalogo.pendientes:
				resultado.append("PENDING_DATA:%s" % id)
	if cantidad("cohetes") > 0:
		for id in INSTRUMENTOS_CLAVE:
			if _catalogo.tiene(id) and not (seleccion.get("extras", []) as Array).has(id):
				resultado.append("MISSING_KEY:%s" % id)
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
