class_name MovementSystem
extends RefCounted
## Movimiento del rover. Al aceptar la orden se calcula la ruta más corta (4 direcciones, sin pisar
## obstáculos, estación ni objetivos) y se descuenta TODA su energía; si no alcanza, se rechaza con
## LOW_ENERGY. La posición del rover se confirma al terminar la ruta (o al cancelarla, en la última
## casilla alcanzada). Los números salen de balance.json; no tiene nodos ni reloj propio.

const EVENTO_MOVIMIENTO_TERMINADO := "MOVE_DONE"
const EVENTO_MOVIMIENTO_CANCELADO := "MOVE_CANCELLED"

## Casillas desde las que se puede actuar sobre un objetivo (a una casilla, contando diagonales).
const CONTIGUAS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
]

var _balance: Balance
var _energia: EnergySystem
var _mapa: MapData


func _init(balance: Balance, energia: EnergySystem, mapa: MapData) -> void:
	_balance = balance
	_energia = energia
	_mapa = mapa


## {"enabled": bool, "reason": String, "path": Array[Vector2i], "cost_wh": float}. Sin ruta si no se puede.
func disponibilidad_mover(estado: MissionState, destino: Vector2i) -> Dictionary:
	return _plan_mover(estado, destino)


## Igual que disponibilidad_mover, pero hacia una casilla contigua al objetivo. Si el rover ya está
## a una casilla del objetivo, la ruta sale vacía y la orden está permitida (no hay nada que mover).
func disponibilidad_acercar(estado: MissionState, objetivo_id: String) -> Dictionary:
	return _plan_acercar(estado, objetivo_id)


## Acepta la orden: descuenta la energía de toda la ruta y deja al rover en marcha.
## {"ok": bool, "reason": String, "path": Array[Vector2i], "seconds_per_tile": float}.
func iniciar_mover(estado: MissionState, destino: Vector2i) -> Dictionary:
	return _iniciar(estado, _plan_mover(estado, destino))


func iniciar_acercar(estado: MissionState, objetivo_id: String) -> Dictionary:
	return _iniciar(estado, _plan_acercar(estado, objetivo_id))


## Avanza el movimiento los segundos reales indicados. Devuelve los eventos ocurridos.
func avanzar(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	if estado.movimiento_en_curso.is_empty() or estado.fase != "operations" or estado.pausado or delta_s <= 0.0:
		return eventos
	if estado.modo_seguro:
		cancelar(estado)
		eventos.append(EVENTO_MOVIMIENTO_CANCELADO)
		return eventos
	estado.movimiento_en_curso["elapsed"] = float(estado.movimiento_en_curso["elapsed"]) + delta_s
	var ruta: Array = estado.movimiento_en_curso["path"]
	var total := ruta.size() * float(estado.movimiento_en_curso["seconds_per_tile"])
	if float(estado.movimiento_en_curso["elapsed"]) >= total:
		estado.casilla_rover = ruta[ruta.size() - 1]
		estado.movimiento_en_curso = {}
		estado.en_movimiento = false
		eventos.append(EVENTO_MOVIMIENTO_TERMINADO)
	return eventos


## Detiene el movimiento: el rover queda en la última casilla que alcanzó a completar.
func cancelar(estado: MissionState) -> void:
	if not estado.movimiento_en_curso.is_empty():
		var ruta: Array = estado.movimiento_en_curso["path"]
		var segundos: float = float(estado.movimiento_en_curso["seconds_per_tile"])
		var hechas := mini(int(floorf(float(estado.movimiento_en_curso["elapsed"]) / segundos)), ruta.size())
		if hechas > 0:
			estado.casilla_rover = ruta[hechas - 1]
	estado.movimiento_en_curso = {}
	estado.en_movimiento = false


func _iniciar(estado: MissionState, plan: Dictionary) -> Dictionary:
	var ruta: Array[Vector2i] = plan["path"]
	if not plan["enabled"]:
		return {"ok": false, "reason": plan["reason"], "path": ruta, "seconds_per_tile": 0.0}
	var segundos := _segundos_por_casilla()
	if not ruta.is_empty():
		_energia.consumir(estado, float(plan["cost_wh"]))
		estado.movimiento_en_curso = {"path": ruta, "seconds_per_tile": segundos, "elapsed": 0.0}
		estado.en_movimiento = true
	return {"ok": true, "reason": "", "path": ruta, "seconds_per_tile": segundos}


func _plan_mover(estado: MissionState, destino: Vector2i) -> Dictionary:
	var motivo := _motivo_general(estado)
	if motivo.is_empty() and not _mapa.dentro_de_limites(destino):
		motivo = "OUT_OF_BOUNDS"
	if not motivo.is_empty():
		return _plan(motivo, [])
	if destino == estado.casilla_rover:
		return _plan("", [], 0.0)
	return _con_energia(estado, _mapa.ruta(estado.casilla_rover, destino))


func _plan_acercar(estado: MissionState, objetivo_id: String) -> Dictionary:
	var motivo := _motivo_general(estado)
	if not motivo.is_empty():
		return _plan(motivo, [])
	var objetivo := {}
	for candidato in estado.objetivos:
		if candidato["id"] == objetivo_id:
			objetivo = candidato
	if objetivo.is_empty() or not objetivo["revealed"]:
		return _plan("NO_TARGET", [])
	var casilla_objetivo: Vector2i = objetivo["tile"]
	var distancia := maxi(absi(estado.casilla_rover.x - casilla_objetivo.x), absi(estado.casilla_rover.y - casilla_objetivo.y))
	if distancia <= 1:
		return _plan("", [], 0.0)
	var mejor: Array[Vector2i] = []
	for desplazamiento in CONTIGUAS:
		var ruta := _mapa.ruta(estado.casilla_rover, casilla_objetivo + desplazamiento)
		if not ruta.is_empty() and (mejor.is_empty() or ruta.size() < mejor.size()):
			mejor = ruta
	return _con_energia(estado, mejor)


func _con_energia(estado: MissionState, ruta: Array[Vector2i]) -> Dictionary:
	if ruta.is_empty():
		return _plan("NO_PATH", ruta)
	var costo := ruta.size() * float(_balance.numero("movimiento.costo_wh_por_casilla"))
	if not _energia.puede_consumir(estado, costo):
		return _plan("LOW_ENERGY", ruta, costo)
	return _plan("", ruta, costo)


func _plan(motivo: String, ruta: Array[Vector2i], costo: float = 0.0) -> Dictionary:
	return {"enabled": motivo.is_empty(), "reason": motivo, "path": ruta, "cost_wh": costo}


func _motivo_general(estado: MissionState) -> String:
	if estado.fase != "operations":
		return "MISSION_END" if estado.fase == "report" else "LANDING"
	if estado.pausado:
		return "PAUSED"
	if estado.modo_seguro:
		return "SAFE"
	if estado.en_movimiento:
		return "MOVING"
	if estado.ocupado:
		return "BUSY"
	return ""


func _segundos_por_casilla() -> float:
	return float(_balance.numero("movimiento.segundos_por_casilla"))
