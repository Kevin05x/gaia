class_name BuildSystem
extends RefCounted
## Edificios de la base y la Antena Científica: dónde se puede construir, costo, construcción con el paso del
## tiempo (una obra a la vez), encendido y apagado, energía que generan o consumen y producción del extractor.
## Los números salen de economia.json; sin nodos ni reloj propio.
## Cada edificio en MissionState.edificios: {"id", "type", "tile", "level", "target_level", "elapsed", "seconds",
## "active", "hp", "produced", "cd"}. "level" es el nivel ya construido (0 mientras se levanta el primero).
## "hp" es la vida actual; "cd" los segundos que faltan para el próximo disparo (solo torretas).

const EVENTO_OBRA_TERMINADA := "BUILD_DONE"  ## BUILD_DONE:<tipo>:<id>
const EVENTO_MODULO := "MODULE_DONE"  ## MODULE_DONE:<tipo>:<n>, cuando termina un módulo de un edificio por partes
const EVENTO_NIVEL_ANTENA := "ANTENNA_LEVEL"  ## ANTENNA_LEVEL:<nivel>
const EVENTO_EDIFICIO_DESTRUIDO := "BUILDING_DESTROYED"  ## BUILDING_DESTROYED:<tipo>:<id>
const EVENTO_MODULO_PERDIDO := "MODULE_LOST"  ## MODULE_LOST:<tipo>:<módulos que quedan>, un ataque destruyó un módulo
const EVENTO_ANTENA_DANADA := "ANTENNA_DAMAGED"  ## ANTENNA_DAMAGED:<nivel que queda>
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
		"target_level": estado.nivel_antena, "elapsed": 0.0, "seconds": 0.0, "active": true,
		"hp": _economia.antena_hp if estado.nivel_antena >= 1 else 0.0, "produced": 0.0, "cd": 0.0})
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
		"seconds": float(def["tiempo_s"]), "active": true, "hp": _vida_inicial(def), "produced": 0.0, "cd": 0.0})
	sincronizar_mapa(estado)
	return {"ok": true, "reason": "", "id": id}


## En un edificio por módulos la vida es la del módulo que recibe los golpes («hp_modulo»): al llegar a 0 se pierde ese módulo.
func _vida_inicial(def: Dictionary) -> float:
	return float(def.get("hp_modulo", def.get("hp", 100)))


## Módulos de un edificio construido por partes (la nave de fuga). El nivel del edificio es el número de módulos listos.
func modulos_totales(tipo: String) -> int:
	return _economia.modulos_de(tipo).size()


## Siguiente módulo de un edificio ({} si no tiene módulos, aún está en obra o ya está completo), con su disponibilidad.
func siguiente_modulo(estado: MissionState, edificio: Dictionary) -> Dictionary:
	var modulos := _economia.modulos_de(str(edificio["type"]))
	var nivel := int(edificio["level"])
	if modulos.is_empty() or nivel < 1 or nivel >= modulos.size() or int(edificio["target_level"]) > nivel:
		return {}
	var modulo: Dictionary = modulos[nivel]
	var motivo := _motivo_modulo(estado, edificio)
	return {"n": nivel + 1, "name_key": str(modulo["nombre_clave"]), "cost": modulo["costo"].duplicate(),
		"seconds": float(modulo["tiempo_s"]), "enabled": motivo.is_empty(), "reason": motivo}


## Empieza el siguiente módulo del edificio «id». {"ok", "reason"}.
func construir_modulo(estado: MissionState, id: String) -> Dictionary:
	var edificio := edificio_por_id(estado, id)
	if edificio.is_empty():
		return {"ok": false, "reason": "UNKNOWN_BUILDING"}
	var motivo := _motivo_modulo(estado, edificio)
	if not motivo.is_empty():
		return {"ok": false, "reason": motivo}
	var modulo: Dictionary = _economia.modulos_de(str(edificio["type"]))[int(edificio["level"])]
	_recursos.pagar(estado, modulo["costo"])
	edificio["target_level"] = int(edificio["level"]) + 1
	edificio["elapsed"] = 0.0
	edificio["seconds"] = float(modulo["tiempo_s"])
	return {"ok": true, "reason": ""}


func _motivo_modulo(estado: MissionState, edificio: Dictionary) -> String:
	var modulos := _economia.modulos_de(str(edificio["type"]))
	if modulos.is_empty():
		return "NO_MODULES"
	var comun := _motivo_comun(estado)
	if not comun.is_empty():
		return comun
	if int(edificio["level"]) < 1:
		return "BUILD_BUSY"
	if int(edificio["level"]) >= modulos.size():
		return "MAX_LEVEL"
	if not _recursos.alcanza(estado, modulos[int(edificio["level"])]["costo"]):
		return "NO_RESOURCES"
	return ""


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
					edificio["hp"] = _economia.antena_hp
					eventos.append("%s:%d" % [EVENTO_NIVEL_ANTENA, estado.nivel_antena])
				eventos.append("%s:%s:%s" % [EVENTO_OBRA_TERMINADA, edificio["type"], edificio["id"]])
				if modulos_totales(str(edificio["type"])) > 0:
					eventos.append("%s:%s:%d" % [EVENTO_MODULO, edificio["type"], int(edificio["level"])])
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
		var restante := 0.0
		if en_obra:
			progreso = clampf(float(edificio["elapsed"]) / maxf(float(edificio["seconds"]), 0.001), 0.0, 1.0)
			restante = maxf(float(edificio["seconds"]) - float(edificio["elapsed"]), 0.0)
		lista.append({"id": edificio["id"], "type": edificio["type"], "tile": edificio["tile"], "level": edificio["level"],
			"building": en_obra, "progress": progreso, "remaining_s": restante, "active": edificio["active"],
			"hp": float(edificio["hp"]), "hp_max": vida_maxima(edificio), "modules": modulos_totales(str(edificio["type"])),
			"next_module": siguiente_modulo(estado, edificio)})
	return lista


## Opciones del menú de construcción con su costo, energía, tiempo y disponibilidad.
func opciones(estado: MissionState) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for tipo in _economia.ids_edificios():
		var def := _economia.edificio(tipo)
		if bool(def.get("requiere_final", false)) and estado.historia_final.is_empty():
			continue  # la nave de fuga no aparece en el menú hasta decidir el clímax
		var disp := disponibilidad(estado, tipo)
		lista.append({"id": tipo, "name_key": def.get("nombre_clave", tipo), "cost": def["costo"].duplicate(),
			"power_w": float(def.get("genera_w_solar", def.get("genera_w", 0.0))) - float(def.get("consume_w", 0.0)),
			"seconds": float(def["tiempo_s"]), "count": cantidad(estado, tipo), "max": int(def.get("maximo", -1)),
			"enabled": disp["enabled"], "reason": disp["reason"], "range": float(def.get("combate", {}).get("alcance", 0.0)),
			"info": ficha(tipo)})
	return lista


## Datos de la ficha informativa del edificio (vida, daño, capacidad, producción y requisitos), para el menú.
func ficha(tipo: String) -> Dictionary:
	var def := _economia.edificio(tipo)
	var combate: Dictionary = def.get("combate", {})
	var datos := {"hp": float(def.get("hp", 100)), "requires": str(def.get("requiere", "")),
		"capacity": int(def.get("capacidad", 0)), "produces_per_hour": Dictionary(def.get("produce_por_hora", {})).duplicate()}
	if not combate.is_empty():
		datos["damage"] = float(combate.get("dano", 0.0))
		datos["fire_rate_s"] = float(combate.get("cadencia_s", 0.0))
		datos["range"] = float(combate.get("alcance", 0.0))
	if def.has("modulos"):
		datos["modules"] = (def["modulos"] as Array).size()
		datos["hp_module"] = float(def.get("hp_modulo", 0))
	return datos


## Vida máxima de un edificio (la antena tiene la suya).
func vida_maxima(edificio: Dictionary) -> float:
	if edificio["type"] == ANTENA:
		return _economia.antena_hp
	var def := _economia.edificio(edificio["type"])
	return float(def.get("hp_modulo", def.get("hp", 100)))


## Edificio por id ({} si no existe).
func edificio_por_id(estado: MissionState, id: String) -> Dictionary:
	for edificio in estado.edificios:
		if edificio["id"] == id:
			return edificio
	return {}


## Edificio con vida (la antena sin ningún nivel todavía no cuenta: es solo el sitio).
func es_objetivo(edificio: Dictionary) -> bool:
	return edificio["type"] != ANTENA or int(edificio["level"]) >= 1


## Quita «dano» de vida a un edificio. Al llegar a 0 un edificio se destruye (se quita del mapa) y la antena baja
## un nivel. Devuelve los eventos.
func danar(estado: MissionState, id: String, dano: float) -> Array[String]:
	var eventos: Array[String] = []
	var edificio := edificio_por_id(estado, id)
	if edificio.is_empty() or dano <= 0.0 or not es_objetivo(edificio):
		return eventos
	edificio["hp"] = maxf(float(edificio["hp"]) - dano, 0.0)
	if float(edificio["hp"]) > 0.0:
		return eventos
	if edificio["type"] == ANTENA:
		var nivel := maxi(int(edificio["level"]) - 1, 0)
		edificio["level"] = nivel
		edificio["target_level"] = nivel
		edificio["elapsed"] = 0.0
		edificio["hp"] = _economia.antena_hp if nivel >= 1 else 0.0
		estado.nivel_antena = nivel
		eventos.append("%s:%d" % [EVENTO_ANTENA_DANADA, nivel])
	elif modulos_totales(str(edificio["type"])) > 0:
		# Edificio por módulos (la nave): el golpe destruye el módulo más alto, o el que estaba en obra.
		if int(edificio["target_level"]) > int(edificio["level"]):
			edificio["target_level"] = int(edificio["level"])
		else:
			edificio["level"] = int(edificio["level"]) - 1
			edificio["target_level"] = int(edificio["level"])
		edificio["elapsed"] = 0.0
		if int(edificio["level"]) < 1:
			estado.edificios.erase(edificio)
			sincronizar_mapa(estado)
			eventos.append("%s:%s:%s" % [EVENTO_EDIFICIO_DESTRUIDO, edificio["type"], id])
		else:
			edificio["hp"] = vida_maxima(edificio)
			eventos.append("%s:%s:%d" % [EVENTO_MODULO_PERDIDO, edificio["type"], int(edificio["level"])])
	else:
		estado.edificios.erase(edificio)
		sincronizar_mapa(estado)
		eventos.append("%s:%s:%s" % [EVENTO_EDIFICIO_DESTRUIDO, edificio["type"], id])
	return eventos


## Suma vida a un edificio sin pasar de su máximo. Devuelve cuánta vida puso.
func reparar(estado: MissionState, id: String, vida: float) -> float:
	var edificio := edificio_por_id(estado, id)
	if edificio.is_empty() or vida <= 0.0 or not es_objetivo(edificio):
		return 0.0
	var antes := float(edificio["hp"])
	edificio["hp"] = minf(antes + vida, vida_maxima(edificio))
	return float(edificio["hp"]) - antes


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
	if bool(def.get("requiere_final", false)) and estado.historia_final.is_empty():
		return "NEEDS_FINAL"
	var requiere := str(def.get("requiere", ""))
	if not requiere.is_empty() and not listo(estado, requiere):
		return "NEEDS_" + requiere.to_upper()
	if estado.nivel_antena < int(def.get("requiere_antena", 0)):
		return "NEEDS_ANTENNA_%d" % int(def["requiere_antena"])
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
