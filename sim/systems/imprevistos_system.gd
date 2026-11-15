class_name ImprevistosSystem
extends RefCounted
## Imprevistos de misión (content/imprevistos.json): situaciones inesperadas basadas en hechos reales de misiones de la
## NASA (conjunción solar, rueda atrapada, fallo de memoria, partículas solares...). Cada partida programa unos pocos,
## con una semilla fija, en momentos distintos de la misión; cuando llega uno, el tiempo se detiene hasta que el
## equipo elige una opción, y la opción aplica sus consecuencias. Simulación pura: sin nodos.

const EVENTO := "UNEXPECTED_EVENT"  ## UNEXPECTED_EVENT:<id>
const EVENTO_RESUELTO := "UNEXPECTED_RESOLVED"  ## UNEXPECTED_RESOLVED:<id>:<opción>
const HORAS_POR_SOL := 24.0

var imprevistos: Dictionary = {}  ## id -> datos
var por_partida := 3
var ventana_soles := Vector2(1.6, 5.4)
var separacion_h := 14.0
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String, destino: String) -> ImprevistosSystem:
	var sistema := ImprevistosSystem.new()
	var texto := FileAccess.get_file_as_string(ruta)
	var datos: Variant = JSON.parse_string(texto) if not texto.is_empty() else null
	if not (datos is Dictionary):
		sistema.errores.append("INVALID_JSON:%s" % ruta)
		return sistema
	sistema.cargar(datos, destino)
	return sistema


func cargar(datos: Dictionary, destino: String) -> void:
	por_partida = int(datos.get("por_partida", 3))
	var v: Array = datos.get("ventana_soles", [1.6, 5.4])
	ventana_soles = Vector2(float(v[0]), float(v[1]))
	separacion_h = float(datos.get("separacion_min_h", 14))
	for item in datos.get("imprevistos", []):
		if not (item is Dictionary) or not item.has("id") or (item.get("opciones", []) as Array).size() < 2:
			errores.append("INVALID_EVENT")
			continue
		if (item.get("destinos", []) as Array).has(destino):
			imprevistos[str(item["id"])] = item


## Hora absoluta de la misión (horas desde el inicio del sol 1).
static func t_abs(estado: MissionState) -> float:
	return (estado.sol - 1) * HORAS_POR_SOL + estado.hora


## Elige qué imprevistos habrá y cuándo (horas absolutas), con la semilla de la partida. Se llama al aterrizar.
func programar(estado: MissionState, semilla: int) -> void:
	estado.imprevistos_programa = []
	if imprevistos.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	var ids: Array = imprevistos.keys()
	ids.sort()
	for i in range(ids.size() - 1, 0, -1):  # barajar con la semilla
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var cuantos := mini(por_partida, ids.size())
	var inicio := (ventana_soles.x - 1.0) * HORAS_POR_SOL
	var fin := (ventana_soles.y - 1.0) * HORAS_POR_SOL
	var tramo := (fin - inicio) / maxf(cuantos, 1)
	for k in range(cuantos):
		var t := inicio + tramo * k + rng.randf_range(0.0, maxf(tramo - separacion_h, 1.0))
		estado.imprevistos_programa.append({"id": ids[k], "t": snappedf(t, 0.01)})


## Si llegó la hora de un imprevisto, lo deja pendiente (la misión se detiene). Devuelve los eventos.
func avanzar(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	if not estado.imprevisto.is_empty() or estado.imprevistos_programa.is_empty():
		return eventos
	var ahora := t_abs(estado)
	var siguiente: Dictionary = estado.imprevistos_programa[0]
	if ahora >= float(siguiente["t"]) and not estado.en_movimiento and estado.accion_en_curso.is_empty():
		estado.imprevistos_programa.pop_front()
		if imprevistos.has(str(siguiente["id"])):
			estado.imprevisto = {"id": str(siguiente["id"])}
			eventos.append("%s:%s" % [EVENTO, siguiente["id"]])
	return eventos


func esperando(estado: MissionState) -> bool:
	return not estado.imprevisto.is_empty()


## Aplica la opción elegida. {"ok", "reason", "event", "applied"}. «applied» es lo que de verdad cambió (para que la
## vista lo cuente): energia_wh, datos (lo que entró o salió de la memoria), datos_perdidos (lo que no cupo porque la
## memoria estaba llena), rover_hp, bloquear_enlace_h, bloquear_movimiento_h, recursos y desvio_casillas.
func decidir(estado: MissionState, opcion: int) -> Dictionary:
	if estado.imprevisto.is_empty():
		return {"ok": false, "reason": "NO_EVENT"}
	var id := str(estado.imprevisto["id"])
	var opciones: Array = imprevistos.get(id, {}).get("opciones", [])
	if opcion < 0 or opcion >= opciones.size():
		return {"ok": false, "reason": "INVALID_CHOICE"}
	var efectos: Dictionary = opciones[opcion].get("efectos", {})
	var ahora := t_abs(estado)
	var aplicado := {}
	if efectos.has("energia_wh"):
		var antes := estado.bateria_wh
		estado.bateria_wh = clampf(estado.bateria_wh + float(efectos["energia_wh"]), 0.0, estado.bateria_capacidad_wh)
		aplicado["energia_wh"] = estado.bateria_wh - antes
	if efectos.has("datos") or efectos.has("datos_pct"):
		var antes := estado.datos
		if efectos.has("datos"):
			var pedidos := float(efectos["datos"])
			estado.datos = clampf(estado.datos + pedidos, 0.0, estado.memoria_capacidad)
			if pedidos > 0.0 and pedidos - (estado.datos - antes) >= 0.5:
				aplicado["datos_perdidos"] = pedidos - (estado.datos - antes)  # no cupieron: memoria llena
		if efectos.has("datos_pct"):
			estado.datos = maxf(estado.datos * (1.0 + float(efectos["datos_pct"])), 0.0)
		aplicado["datos"] = estado.datos - antes
	if efectos.has("rover_hp"):
		var antes := estado.rover_hp
		estado.rover_hp = clampf(estado.rover_hp + float(efectos["rover_hp"]), 1.0, 100.0)
		aplicado["rover_hp"] = estado.rover_hp - antes
	if efectos.has("bloquear_enlace_h"):
		estado.enlace_bloqueado_hasta = maxf(estado.enlace_bloqueado_hasta, ahora + float(efectos["bloquear_enlace_h"]))
		estado.transmitiendo = false
		aplicado["bloquear_enlace_h"] = float(efectos["bloquear_enlace_h"])
	if efectos.has("bloquear_movimiento_h"):
		estado.movimiento_bloqueado_hasta = maxf(estado.movimiento_bloqueado_hasta, ahora + float(efectos["bloquear_movimiento_h"]))
		aplicado["bloquear_movimiento_h"] = float(efectos["bloquear_movimiento_h"])
	for recurso in efectos.get("recursos", {}):
		estado.recursos[recurso] = int(estado.recursos.get(recurso, 0)) + int(efectos["recursos"][recurso])
		aplicado["recursos"] = efectos["recursos"].duplicate()
	if efectos.has("desvio_casillas"):
		aplicado["desvio_casillas"] = int(efectos["desvio_casillas"])  # lo hace Simulation: necesita mapa y movimiento
	estado.imprevistos_hechos.append({"id": id, "choice": opcion})
	estado.imprevisto = {}
	return {"ok": true, "reason": "", "event": "%s:%s:%d" % [EVENTO_RESUELTO, id, opcion], "applied": aplicado}


## Lo que la vista necesita para mostrar el imprevisto pendiente (vacío si no hay).
func para_la_vista(estado: MissionState) -> Dictionary:
	if estado.imprevisto.is_empty():
		return {}
	var datos: Dictionary = imprevistos.get(str(estado.imprevisto["id"]), {})
	var opciones: Array = []
	var efectos: Array = []
	for o in datos.get("opciones", []):
		opciones.append(o.get("texto", {}))
		efectos.append((o.get("efectos", {}) as Dictionary).duplicate(true))
	return {"id": estado.imprevisto["id"], "title": datos.get("titulo", {}), "text": datos.get("texto", {}),
		"real": datos.get("real", {}), "source": datos.get("fuente", ""), "options": opciones, "effects": efectos}


static func enlace_bloqueado(estado: MissionState) -> bool:
	return estado.enlace_bloqueado_hasta > t_abs(estado)


static func movimiento_bloqueado(estado: MissionState) -> bool:
	return estado.movimiento_bloqueado_hasta > t_abs(estado)
