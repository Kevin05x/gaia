class_name ResourceSystem
extends RefCounted
## Recursos de la base (rocas, olivino, hielo y xenolito): recolección al terminar acciones, capacidad de
## almacén (más con cada domo listo) y pago de costos. Los números salen de economia.json; sin nodos.

const EVENTO_RECURSO_NUEVO := "RESOURCE_FIRST"  ## RESOURCE_FIRST:<recurso>, la primera vez que se consigue

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


## Recursos al terminar una acción sobre un objetivo de ese tipo (o sin objetivo, como el compañero).
func recolectar(estado: MissionState, accion: String, tipo: String) -> Array[String]:
	return sumar(estado, _economia.recoleccion_de(accion, tipo))
