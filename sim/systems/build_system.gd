class_name BuildSystem
extends RefCounted
## Edificios de la base y la Antena Científica: dónde se puede construir, costo, construcción con el paso del
## tiempo (una obra a la vez), encendido y apagado, energía que generan o consumen y producción del extractor.
## Los números salen de economia.json; sin nodos ni reloj propio.
## Cada edificio en MissionState.edificios: {"id", "type", "tile", "level", "target_level", "elapsed", "seconds",
## "active", "hp", "produced"}. "level" es el nivel ya construido (0 mientras se levanta el primero).

const EVENTO_OBRA_TERMINADA := "BUILD_DONE"  ## BUILD_DONE:<tipo>:<id>
const EVENTO_NIVEL_ANTENA := "ANTENNA_LEVEL"  ## ANTENNA_LEVEL:<nivel>
const ANTENA := "antena"

var _economia: Economy
var _recursos: ResourceSystem
var _mapa: MapData


func _init(economia: Economy, recursos: ResourceSystem, mapa: MapData) -> void:
	_economia = economia
	_recursos = recursos
	_mapa = mapa


## Base vacía: solo el sitio de la antena, al nivel inicial.
func iniciar(estado: MissionState) -> void:
	estado.edificios.clear()
	estado.siguiente_edificio = 1
	estado.nivel_antena = _economia.antena_nivel_inicial
	estado.edificios.append({"id": ANTENA, "type": ANTENA, "tile": casilla_antena(estado), "level": estado.nivel_antena,
		"target_level": estado.nivel_antena, "elapsed": 0.0, "seconds": 0.0, "active": true, "hp": 0.0, "produced": 0.0})
	sincronizar_mapa(estado)


func casilla_antena(estado: MissionState) -> Vector2i:
	return estado.casilla_estacion + _economia.antena_casilla_relativa


## Las casillas con edificios (y obras) bloquean el paso del rover.
func sincronizar_mapa(estado: MissionState) -> void:
	_mapa.bloqueos_extra.clear()
	for edificio in estado.edificios:
		_mapa.bloqueos_extra[edificio["tile"]] = true


func en_zona_base(estado: MissionState, casilla: Vector2i) -> bool:
	var d := casilla - estado.casilla_estacion
	return maxi(absi(d.x), absi(d.y)) <= _economia.zona_base_radio and _mapa.dentro_de_limites(casilla)


func hay_obra(estado: MissionState) -> bool:
	for edificio in estado.edificios:
		if int(edificio["target_level"]) > int(edificio["level"]):
			return true
	return false


func cantidad(estado: MissionState, tipo: String) -> int:
	var total := 0
	for edificio in estado.edificios:
		if edificio["type"] == tipo:
			total += 1
	return total


func listo(estado: MissionState, tipo: String) -> bool:
	for edificio in estado.edificios:
		if edificio["type"] == tipo and int(edificio["level"]) >= 1:
			return true
	return false


## {"enabled", "reason"} para construir «tipo». Sin «casilla» solo mira fase, recursos, máximos y obras.
func disponibilidad(estado: MissionState, tipo: String, casilla: Variant = null) -> Dictionary:
	var motivo := _motivo(estado, tipo, casilla)
	return {"enabled": motivo.is_empty(), "reason": motivo}


## Empieza una obra. {"ok", "reason", "id"}.
func construir(estado: MissionState, tipo: String, casilla: Vector2i) -> Dictionary:
	var motivo := _motivo(estado, tipo, casilla)
	if not motivo.is_empty():
		return {"ok": false, "reason": motivo, "id": ""}
	var def := _economia.edificio(tipo)
	_recursos.pagar(estado, def["costo"])
	var id := "%s-%d" % [tipo, estado.siguiente_edificio]
	estado.siguiente_edificio += 1
	estado.edificios.append({"id": id, "type": tipo, "tile": casilla, "level": 0, "target_level": 1, "elapsed": 0.0,
		"seconds": float(def["tiempo_s"]), "active": true, "hp": float(def.get("hp", 100)), "produced": 0.0})
	sincronizar_mapa(estado)
	return {"ok": true, "reason": "", "id": id}


## {"enabled", "reason"} para subir la antena al nivel siguiente.
func disponibilidad_antena(estado: MissionState) -> Dictionary:
	var motivo := _motivo_antena(estado)
	return {"enabled": motivo.is_empty(), "reason": motivo}


## Empieza a subir la antena un nivel. {"ok", "reason"}.
func mejorar_antena(estado: MissionState) -> Dictionary:
	var motivo := _motivo_antena(estado)
	if not motivo.is_empty():
		return {"ok": false, "reason": motivo}
	var nivel := _economia.nivel_antena(estado.nivel_antena + 1)
	_recursos.pagar(estado, nivel["costo"])
	var antena := _antena(estado)
	antena["target_level"] = estado.nivel_antena + 1
	antena["elapsed"] = 0.0
	antena["seconds"] = float(nivel.get("tiempo_s", 10))
	return {"ok": true, "reason": ""}


## Costo del siguiente nivel de la antena ({} si ya está al máximo).
func costo_siguiente_antena(estado: MissionState) -> Dictionary:
	return _economia.nivel_antena(estado.nivel_antena + 1).get("costo", {})


## Enciende o apaga un edificio terminado (apagado no consume ni produce). {"ok", "reason"}.
func alternar(estado: MissionState, id: String, encendido: bool) -> Dictionary:
	if estado.fase != "operations":
		return {"ok": false, "reason": "WRONG_PHASE"}
	for edificio in estado.edificios:
		if edificio["id"] == id and edificio["type"] != ANTENA:
			edificio["active"] = encendido
			return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "UNKNOWN_BUILDING"}


## Avanza las obras (segundos reales) y la producción (horas de juego). Devuelve los eventos.
func avanzar(estado: MissionState, delta_s: float, horas: float) -> Array[String]:
	var eventos: Array[String] = []
	if estado.modo_seguro:
		return eventos  # sin energía no se construye ni se produce
	for edificio in estado.edificios:
		if int(edificio["target_level"]) > int(edificio["level"]):
			edificio["elapsed"] = float(edificio["elapsed"]) + delta_s
			if float(edificio["elapsed"]) >= float(edificio["seconds"]):
				edificio["level"] = int(edificio["target_level"])
				edificio["elapsed"] = float(edificio["seconds"])
				if edificio["type"] == ANTENA:
					estado.nivel_antena = int(edificio["level"])
					eventos.append("%s:%d" % [EVENTO_NIVEL_ANTENA, estado.nivel_antena])
				eventos.append("%s:%s:%s" % [EVENTO_OBRA_TERMINADA, edificio["type"], edificio["id"]])
		elif int(edificio["level"]) >= 1 and edificio["active"] and horas > 0.0:
			var produce: Variant = _economia.edificio(edificio["type"]).get("produce_por_hora", {})
			if produce is Dictionary and not produce.is_empty():
				edificio["produced"] = float(edificio["produced"]) + horas
				var horas_enteras := floorf(float(edificio["produced"]))
				if horas_enteras >= 1.0:
					edificio["produced"] = float(edificio["produced"]) - horas_enteras
					var cantidades := {}
					for recurso in produce:
						cantidades[recurso] = int(roundf(float(produce[recurso]) * horas_enteras))
					eventos.append_array(_recursos.sumar(estado, cantidades))
	return eventos


## Potencia que generan los edificios listos y encendidos. «factor_solar» es 0..1 (0 de noche).
func generacion_w(estado: MissionState, factor_solar: float) -> float:
	var total := 0.0
	for edificio in estado.edificios:
		if int(edificio["level"]) < 1 or not edificio["active"]:
			continue
		var def := _economia.edificio(edificio["type"])
		total += float(def.get("genera_w_solar", 0.0)) * factor_solar + float(def.get("genera_w", 0.0))
	return total


## Potencia que consumen los edificios listos y encendidos (la antena según su nivel).
func carga_w(estado: MissionState) -> float:
	var total := 0.0
	for edificio in estado.edificios:
		if int(edificio["level"]) < 1 or not edificio["active"]:
			continue
		if edificio["type"] == ANTENA:
			total += float(_economia.nivel_antena(int(edificio["level"])).get("consume_w", 0.0))
		else:
			total += float(_economia.edificio(edificio["type"]).get("consume_w", 0.0))
	return total


## Edificios para la vista.
func para_la_vista(estado: MissionState) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for edificio in estado.edificios:
		var en_obra := int(edificio["target_level"]) > int(edificio["level"])
		var progreso := 1.0
		if en_obra:
			progreso = clampf(float(edificio["elapsed"]) / maxf(float(edificio["seconds"]), 0.001), 0.0, 1.0)
		lista.append({"id": edificio["id"], "type": edificio["type"], "tile": edificio["tile"], "level": edificio["level"],
			"building": en_obra, "progress": progreso, "active": edificio["active"]})
	return lista


## Opciones del menú de construcción con su costo, energía, tiempo y disponibilidad.
func opciones(estado: MissionState) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for tipo in _economia.ids_edificios():
		var def := _economia.edificio(tipo)
		var disp := disponibilidad(estado, tipo)
		lista.append({"id": tipo, "name_key": def.get("nombre_clave", tipo), "cost": def["costo"].duplicate(),
			"power_w": float(def.get("genera_w_solar", def.get("genera_w", 0.0))) - float(def.get("consume_w", 0.0)),
			"seconds": float(def["tiempo_s"]), "count": cantidad(estado, tipo), "max": int(def.get("maximo", -1)),
			"enabled": disp["enabled"], "reason": disp["reason"]})
	return lista


func _antena(estado: MissionState) -> Dictionary:
	for edificio in estado.edificios:
		if edificio["type"] == ANTENA:
			return edificio
	return {}


func _motivo_comun(estado: MissionState) -> String:
	if estado.fase != "operations":
		return "MISSION_END" if estado.fase == "report" else "LANDING"
	if estado.pausado:
		return "PAUSED"
	if estado.modo_seguro:
		return "SAFE"
	if hay_obra(estado):
		return "BUILD_BUSY"
	return ""


func _motivo(estado: MissionState, tipo: String, casilla: Variant) -> String:
	if not _economia.tiene_edificio(tipo):
		return "UNKNOWN_BUILDING"
	var comun := _motivo_comun(estado)
	if not comun.is_empty():
		return comun
	var def := _economia.edificio(tipo)
	var maximo := int(def.get("maximo", -1))
	if maximo >= 0 and cantidad(estado, tipo) >= maximo:
		return "MAX_BUILT"
	if not _recursos.alcanza(estado, def["costo"]):
		return "NO_RESOURCES"
	if casilla == null:
		return ""
	var c: Vector2i = casilla
	if not en_zona_base(estado, c):
		return "OUT_OF_BASE"
	if _mapa.bloqueada(c) or c == estado.casilla_rover:
		return "TILE_BLOCKED"
	if estado.en_movimiento and Array(estado.movimiento_en_curso.get("path", [])).has(c):
		return "TILE_BLOCKED"
	return ""


func _motivo_antena(estado: MissionState) -> String:
	var comun := _motivo_comun(estado)
	if not comun.is_empty():
		return comun
	if estado.nivel_antena >= _economia.nivel_antena_max():
		return "MAX_LEVEL"
	var nivel := _economia.nivel_antena(estado.nivel_antena + 1)
	var requiere := str(nivel.get("requiere", ""))
	if not requiere.is_empty() and not listo(estado, requiere):
		return "NEEDS_" + requiere.to_upper()
	if not _recursos.alcanza(estado, nivel["costo"]):
		return "NO_RESOURCES"
	return ""
