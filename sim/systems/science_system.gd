class_name ScienceSystem
extends RefCounted
## Acciones del rover: espectrómetro, taladro, panorámica, radar, dron, compañero y mejora de antena.
## Decide si una acción está disponible (con su motivo), la inicia (gasta energía), la completa con el
## paso del tiempo y aplica sus efectos (datos, minerales, objetivos revelados o agotados).
## Los números salen de balance.json; no tiene nodos ni reloj propio.

const EVENTO_ACCION_TERMINADA := "ACTION_DONE"  ## ACTION_DONE:<acción>:<objetivo>
const EVENTO_OBJETIVO_REVELADO := "TARGET_REVEALED"  ## TARGET_REVEALED:<objetivo>
const EVENTO_OBJETIVO_AGOTADO := "TARGET_DEPLETED"  ## TARGET_DEPLETED:<objetivo>
const EVENTO_DATOS_METEO := "METEO_DATA"

## Acciones pertinentes por tipo de objetivo; la primera es la principal.
const ACCIONES_POR_TIPO: Dictionary = {
	"rock": ["spectrometer", "drill"],
	"mineral": ["drill", "spectrometer"],
	"buried": ["drill"],
}
const ACCIONES_CON_OBJETIVO: Array[String] = ["spectrometer", "drill"]

var _balance: Balance
var _energia: EnergySystem
var recursos: ResourceSystem = null  ## si hay economía: lo recolectado suma rocas, olivino, hielo o xenolito


func _init(balance: Balance, energia: EnergySystem) -> void:
	_balance = balance
	_energia = energia


## {"enabled": bool, "reason": String}. El motivo es un código ("TOO_FAR", "LOW_ENERGY"...) o "" si se puede.
func disponibilidad(estado: MissionState, accion: String, objetivo_id: String = "") -> Dictionary:
	var motivo := _motivo(estado, accion, objetivo_id)
	return {"enabled": motivo.is_empty(), "reason": motivo}


## Acciones pertinentes del objetivo, ordenadas y con su disponibilidad. Vacío si no está revelado.
func acciones_de_objetivo(estado: MissionState, objetivo_id: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var objetivo := _objetivo(estado, objetivo_id)
	if objetivo.is_empty() or not objetivo["revealed"]:
		return lista
	var permitidas: Array = ACCIONES_POR_TIPO.get(objetivo["type"], [])
	for accion in permitidas:
		var id: String = accion
		var disp := disponibilidad(estado, id, objetivo_id)
		lista.append({"id": id, "enabled": disp["enabled"], "reason": disp["reason"]})
	return lista


## Primera acción pertinente aún no hecha; si ya están todas, la primera. "" si no hay objetivo revelado.
func accion_principal(estado: MissionState, objetivo_id: String) -> String:
	var lista := acciones_de_objetivo(estado, objetivo_id)
	if lista.is_empty():
		return ""
	var hechas: Array = _objetivo(estado, objetivo_id).get("done", [])
	for entrada in lista:
		if not hechas.has(entrada["id"]):
			return entrada["id"]
	return lista[0]["id"]


## Inicia una acción: comprueba, gasta la energía y la deja en curso. {"ok": bool, "reason": String}.
func iniciar(estado: MissionState, accion: String, objetivo_id: String = "") -> Dictionary:
	var disp := disponibilidad(estado, accion, objetivo_id)
	if not disp["enabled"]:
		return {"ok": false, "reason": disp["reason"]}
	var definicion := _balance.accion(accion)
	_energia.consumir(estado, float(definicion["costo_wh"]))
	estado.accion_en_curso = {"action": accion, "target_id": objetivo_id, "seconds": float(definicion["duracion_s"]), "elapsed": 0.0}
	estado.ocupado = true
	if accion == "drone":
		if estado.dron_sol != estado.sol:
			estado.dron_sol = estado.sol
			estado.dron_usos = 0
		estado.dron_usos += 1
	return {"ok": true, "reason": ""}


## Mejora instantánea de la antena a cambio de minerales. {"ok": bool, "reason": String}.
func mejorar_antena(estado: MissionState) -> Dictionary:
	var disp := disponibilidad(estado, "upgrade")
	if not disp["enabled"]:
		return {"ok": false, "reason": disp["reason"]}
	estado.minerales -= int(_balance.numero("ciencia.minerales_mejora_antena"))
	estado.nivel_antena += 1
	return {"ok": true, "reason": ""}


## Avanza la acción en curso los segundos reales indicados. Devuelve los eventos ocurridos.
func avanzar(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	if estado.accion_en_curso.is_empty() or estado.fase != "operations" or estado.pausado or delta_s <= 0.0:
		return eventos
	if estado.modo_seguro:
		cancelar(estado)
		return eventos
	estado.accion_en_curso["elapsed"] = float(estado.accion_en_curso["elapsed"]) + delta_s
	if float(estado.accion_en_curso["elapsed"]) >= float(estado.accion_en_curso["seconds"]):
		_completar(estado, eventos)
	return eventos


func cancelar(estado: MissionState) -> void:
	estado.accion_en_curso = {}
	estado.ocupado = false


## Datos de la estación meteorológica al empezar un sol nuevo (si el diseño la lleva).
func al_nuevo_sol(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	if estado.instrumentos.has("meteo"):
		estado.datos = minf(estado.memoria_capacidad, estado.datos + _balance.numero("ciencia.meteo_por_sol"))
		eventos.append(EVENTO_DATOS_METEO)
	return eventos


func _motivo(estado: MissionState, accion: String, objetivo_id: String) -> String:
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
	if accion == "upgrade":
		if estado.nivel_antena >= int(_balance.numero("ciencia.nivel_antena_max")):
			return "MAX_LEVEL"
		if estado.minerales < int(_balance.numero("ciencia.minerales_mejora_antena")):
			return "NO_MINERAL"
		return ""
	var definicion := _balance.accion(accion)
	if definicion.is_empty():
		return "UNKNOWN_ACTION"
	var objetivo := {}
	if ACCIONES_CON_OBJETIVO.has(accion):
		objetivo = _objetivo(estado, objetivo_id)
		if objetivo.is_empty() or not objetivo["revealed"]:
			return "NO_TARGET"
		var permitidas: Array = ACCIONES_POR_TIPO.get(objetivo["type"], [])
		if not permitidas.has(accion):
			return "NOT_APPLICABLE"
	if accion == "companion":
		if not estado.companero:
			return "NO_INSTRUMENT"
		if estado.rocky_hp <= 0.0:
			return "ROCKY_DOWN"
	elif not estado.instrumentos.has(accion):
		return "NO_INSTRUMENT"
	if estado.bateria_wh < float(definicion["costo_wh"]):
		return "LOW_ENERGY"
	if not objetivo.is_empty():
		var casilla: Vector2i = objetivo["tile"]
		if maxi(absi(estado.casilla_rover.x - casilla.x), absi(estado.casilla_rover.y - casilla.y)) > 1:
			return "TOO_FAR"
		var hechas: Array = objetivo.get("done", [])
		if hechas.has(accion):
			return "DEPLETED"
		if estado.datos + _rendimiento(accion, objetivo["type"]) > estado.memoria_capacidad:
			return "MEMORY_FULL"
	if accion == "drone":
		if estado.tormenta:
			return "WEATHER"
		if estado.es_noche:
			return "NIGHT"
		var usos_maximos := int(definicion.get("usos_por_sol", 0))
		if usos_maximos > 0 and estado.dron_sol == estado.sol and estado.dron_usos >= usos_maximos:
			return "FLIGHT_USED"
	return ""


func _objetivo(estado: MissionState, objetivo_id: String) -> Dictionary:
	for objetivo in estado.objetivos:
		if objetivo["id"] == objetivo_id:
			return objetivo
	return {}


func _rendimiento(accion: String, tipo: String) -> float:
	if accion == "drill" and tipo == "buried":
		return _balance.numero("ciencia.rendimiento.drill_enterrado")
	return _balance.numero("ciencia.rendimiento." + accion)


func _completar(estado: MissionState, eventos: Array[String]) -> void:
	var accion: String = estado.accion_en_curso["action"]
	var objetivo_id: String = estado.accion_en_curso["target_id"]
	estado.accion_en_curso = {}
	estado.ocupado = false
	match accion:
		"spectrometer", "drill":
			_analizar(estado, accion, objetivo_id, eventos)
		"panorama":
			_revelar(estado, ["rock", "mineral"], eventos)
		"radar":
			_revelar(estado, ["buried"], eventos)
		"drone":
			_revelar(estado, ["rock", "mineral", "buried"], eventos)
		"companion":
			estado.minerales += int(_balance.numero("ciencia.minerales_companero"))
			if recursos != null:
				eventos.append_array(recursos.recolectar(estado, "companion", ""))
	eventos.append("%s:%s:%s" % [EVENTO_ACCION_TERMINADA, accion, objetivo_id])


func _analizar(estado: MissionState, accion: String, objetivo_id: String, eventos: Array[String]) -> void:
	var objetivo := _objetivo(estado, objetivo_id)
	if objetivo.is_empty():
		return
	if not objetivo.has("done"):
		objetivo["done"] = []
	objetivo["done"].append(accion)
	estado.datos = minf(estado.memoria_capacidad, estado.datos + _rendimiento(accion, objetivo["type"]))
	if objetivo["type"] == "mineral":
		estado.minerales += int(_balance.numero("ciencia.minerales_por_mineral"))
	if recursos != null:
		eventos.append_array(recursos.recolectar(estado, accion, objetivo["type"]))
	var requeridas: Array = ACCIONES_POR_TIPO.get(objetivo["type"], [])
	var completo := true
	for requerida in requeridas:
		if not objetivo["done"].has(requerida):
			completo = false
	if completo and not objetivo["depleted"]:
		objetivo["depleted"] = true
		eventos.append("%s:%s" % [EVENTO_OBJETIVO_AGOTADO, objetivo_id])


func _revelar(estado: MissionState, tipos: Array, eventos: Array[String]) -> void:
	for objetivo in estado.objetivos:
		if tipos.has(objetivo["type"]) and not objetivo["revealed"]:
			objetivo["revealed"] = true
			eventos.append("%s:%s" % [EVENTO_OBJETIVO_REVELADO, objetivo["id"]])
