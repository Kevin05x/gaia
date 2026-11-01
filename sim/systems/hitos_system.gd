class_name HitosSystem
extends RefCounted
## Ciencia por etapas. Comprueba los hitos de HitosData con contadores del estado (rocas analizadas, minerales, hielo,
## muestras, zonas visitadas, nivel de antena, paneles y oleadas superadas) y, al cumplirse uno, suma sus datos a la
## memoria. Si la memoria está llena, lo que no cabe espera en «datos_pendientes» y entra en cuanto se transmite.

const EVENTO_HITO := "MILESTONE"  ## MILESTONE:<id>

var _datos: HitosData


func _init(datos: HitosData) -> void:
	_datos = datos


## Contadores actuales para las condiciones.
func contadores(estado: MissionState) -> Dictionary:
	var c := {"rocas_analizadas": 0, "minerales": 0, "enterrados": 0, "muestras": 0, "zonas": estado.zonas_visitadas.size(),
		"antena": estado.nivel_antena, "paneles": 0, "oleadas": estado.oleadas_derrotadas}
	for objetivo in estado.objetivos:
		var hechas: Array = objetivo.get("done", [])
		if hechas.is_empty():
			continue
		match str(objetivo["type"]):
			"rock":
				if hechas.has("spectrometer"):
					c["rocas_analizadas"] += 1
			"mineral":
				c["minerales"] += 1
			"buried":
				c["enterrados"] += 1
		if hechas.has("drill"):
			c["muestras"] += 1
	for edificio in estado.edificios:
		if edificio["type"] == "panel_solar" and int(edificio["level"]) >= 1:
			c["paneles"] += 1
	return c


## Cumple los hitos nuevos y vacía lo pendiente en la memoria. Devuelve los eventos MILESTONE:<id>.
func avanzar(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	_vaciar_pendientes(estado)
	var c := contadores(estado)
	for hito in _datos.hitos:
		if estado.hitos_hechos.has(hito["id"]):
			continue
		var cumple := true
		for clave in hito["condicion"]:
			if int(c.get(clave, 0)) < int(hito["condicion"][clave]):
				cumple = false
				break
		if cumple:
			estado.hitos_hechos.append(hito["id"])
			estado.datos_pendientes += float(hito["datos"])
			eventos.append("%s:%s" % [EVENTO_HITO, hito["id"]])
	if not eventos.is_empty():
		_vaciar_pendientes(estado)
	return eventos


func _vaciar_pendientes(estado: MissionState) -> void:
	if estado.datos_pendientes <= 0.0:
		return
	var hueco := maxf(estado.memoria_capacidad - estado.datos, 0.0)
	var entra := minf(hueco, estado.datos_pendientes)
	estado.datos += entra
	estado.datos_pendientes -= entra


## Para la vista: [{"id", "objective", "name", "data", "done", "progress": [actual, meta]}] y los objetivos.
func para_la_vista(estado: MissionState) -> Dictionary:
	var c := contadores(estado)
	var lista: Array[Dictionary] = []
	for hito in _datos.hitos:
		var actual := 0
		var meta := 0
		for clave in hito["condicion"]:
			actual += mini(int(c.get(clave, 0)), int(hito["condicion"][clave]))
			meta += int(hito["condicion"][clave])
		lista.append({"id": hito["id"], "objective": hito["objetivo"], "name": hito["nombre"], "data": hito["datos"],
			"done": estado.hitos_hechos.has(hito["id"]), "progress": [actual, meta]})
	return {"objectives": _datos.objetivos, "milestones": lista, "pending": estado.datos_pendientes}
