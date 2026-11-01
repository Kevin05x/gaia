class_name ResourceSystem
extends RefCounted
## Recursos de la base (rocas, olivino, hielo y xenolito): recolección al terminar acciones, capacidad de
## almacén (más con cada domo listo) y pago de costos. Los números salen de economia.json; sin nodos.

const EVENTO_RECURSO_NUEVO := "RESOURCE_FIRST"  ## RESOURCE_FIRST:<recurso>, la primera vez que se consigue
const EVENTO_PRIMERA_CARGA := "CARGO_FIRST"  ## la primera vez que algo entra en la bodega del rover

var _economia: Economy


func _init(economia: Economy) -> void:
	_economia = economia


## Recursos al empezar la misión.
func iniciar(estado: MissionState) -> void:
	estado.recursos = {}
	for recurso in _economia.recursos:
		estado.recursos[recurso] = int(_economia.recursos_iniciales.get(recurso, 0))
	estado.recursos_vistos = []
	for recurso in estado.recursos:
		if int(estado.recursos[recurso]) > 0:
			estado.recursos_vistos.append(recurso)


## Capacidad de cada recurso: la base más lo que suman los domos ya construidos.
func capacidad(estado: MissionState) -> int:
	var total := _economia.capacidad_base
	for edificio in estado.edificios:
		if int(edificio["level"]) >= 1 and edificio["active"]:
			total += int(_economia.edificio(edificio["type"]).get("capacidad", 0))
	return total


func alcanza(estado: MissionState, costo: Dictionary) -> bool:
	for recurso in costo:
		if int(estado.recursos.get(recurso, 0)) < int(costo[recurso]):
			return false
	return true


## Descuenta un costo. false (sin cambiar nada) si no alcanza.
func pagar(estado: MissionState, costo: Dictionary) -> bool:
	if not alcanza(estado, costo):
		return false
	for recurso in costo:
		estado.recursos[recurso] = int(estado.recursos.get(recurso, 0)) - int(costo[recurso])
	return true


## Suma (o resta, con cantidades negativas) recursos sin pasar de la capacidad ni bajar de 0.
## Devuelve los eventos de recurso conseguido por primera vez.
func sumar(estado: MissionState, cantidades: Dictionary) -> Array[String]:
	var eventos: Array[String] = []
	var tope := capacidad(estado)
	for recurso in cantidades:
		if not estado.recursos.has(recurso):
			continue
		var antes := int(estado.recursos[recurso])
		var nuevo := clampi(antes + int(cantidades[recurso]), 0, maxi(tope, antes))
		estado.recursos[recurso] = nuevo
		if nuevo > antes and not estado.recursos_vistos.has(recurso):
			estado.recursos_vistos.append(recurso)
			eventos.append("%s:%s" % [EVENTO_RECURSO_NUEVO, recurso])
	return eventos


## Recursos al terminar una acción sobre un objetivo de ese tipo (o sin objetivo, como el compañero). Con bodega,
## van a la bodega del rover (lo que no cabe se pierde) y hay que descargarlos en la estación o en un domo.
func recolectar(estado: MissionState, accion: String, tipo: String) -> Array[String]:
	var cantidades := _economia.recoleccion_de(accion, tipo)
	if _economia.bodega_rover <= 0:
		return sumar(estado, cantidades)
	var eventos: Array[String] = []
	if not estado.bodega_avisada and not cantidades.is_empty():
		estado.bodega_avisada = true
		eventos.append(EVENTO_PRIMERA_CARGA)
	for recurso in cantidades:
		var hueco := maxi(_economia.bodega_rover - carga_total(estado), 0)
		var entra := mini(int(cantidades[recurso]), hueco)
		if entra > 0:
			estado.carga[recurso] = int(estado.carga.get(recurso, 0)) + entra
	return eventos


func usa_bodega() -> bool:
	return _economia.bodega_rover > 0


func capacidad_bodega() -> int:
	return _economia.bodega_rover


func carga_total(estado: MissionState) -> int:
	var total := 0
	for recurso in estado.carga:
		total += int(estado.carga[recurso])
	return total


func bodega_llena(estado: MissionState) -> bool:
	return usa_bodega() and carga_total(estado) >= _economia.bodega_rover


## Pasa la bodega a la base (sin superar la capacidad del almacén; lo que no cabe se queda en la bodega).
## Devuelve [unidades descargadas, eventos de recurso nuevo].
func descargar(estado: MissionState) -> Array:
	var movido := 0
	var cantidades := {}
	var tope := capacidad(estado)
	for recurso in estado.carga.keys():
		var hueco := maxi(tope - int(estado.recursos.get(recurso, 0)), 0)
		var pasa := mini(int(estado.carga[recurso]), hueco)
		if pasa > 0:
			cantidades[recurso] = pasa
			estado.carga[recurso] = int(estado.carga[recurso]) - pasa
			movido += pasa
		if int(estado.carga.get(recurso, 0)) <= 0:
			estado.carga.erase(recurso)
	return [movido, sumar(estado, cantidades)]
