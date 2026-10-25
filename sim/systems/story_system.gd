class_name StorySystem
extends RefCounted
## Historia de la misión (content/historia.json): muestra cada nodo cuando se cumple alguno de sus disparadores,
## detiene la misión hasta que el jugador decide y aplica los efectos de la opción elegida (batería, datos,
## ética, vida de Rocky y recursos). Al final elige uno de los 4 finales. Sin nodos ni reloj propio.

const EVENTO_NODO := "STORY_NODE"  ## STORY_NODE:<nodo>, cuando un nodo espera decisión
const EVENTO_DECISION := "STORY_DECISION"  ## STORY_DECISION:<nodo>:<opción>
const EVENTO_RADIO := "STORY_RADIO"  ## STORY_RADIO:<nodo>, nodo de radio: se aplica solo y la misión sigue
const FINAL_DERROTA := "silencio"
const FINAL_BUENO := "simbiosis"
const FINAL_DESTRUCTIVO := "explotacion"

var _datos: StoryData
var _recursos: ResourceSystem  ## puede ser null (sin economía, los efectos de recursos se ignoran)


func _init(datos: StoryData, recursos: ResourceSystem) -> void:
	_datos = datos
	_recursos = recursos


func iniciar(estado: MissionState) -> void:
	estado.etica = _datos.etica_inicial
	estado.rocky_hp = 100.0
	estado.historia_nodo = ""
	estado.historia_espera = _datos.inicio
	estado.historia_ultimo = ""
	estado.historia_registro = []
	estado.historia_final = ""
	estado.historia_rama = ""
	estado.historia_radio = ""
	estado.historia_radio_n = 0
	estado.historia_t_ultimo = -1000.0


## Si el próximo nodo ya cumple un disparador, lo deja esperando decisión. Devuelve los eventos.
func comprobar(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	if estado.fase != "operations" or not estado.historia_nodo.is_empty() or estado.historia_espera.is_empty():
		return eventos
	var nodo := _datos.nodo(estado.historia_espera)
	if nodo.is_empty():
		estado.historia_espera = ""
		return eventos
	if _ahora(estado) - estado.historia_t_ultimo < float(nodo.get("espera_h", 0.0)):
		return eventos  # respiro entre eventos: se juega un rato antes del siguiente
	for disparador in nodo.get("disparadores", []):
		if _cumple(estado, disparador):
			var id := estado.historia_espera
			estado.historia_ultimo = id
			if str(nodo.get("modo", "decision")) == "radio":
				_resolver(estado, id, 0)
				estado.historia_radio = id
				estado.historia_radio_n += 1
				eventos.append("%s:%s" % [EVENTO_RADIO, id])
			else:
				estado.historia_nodo = id
				estado.historia_espera = ""
				eventos.append("%s:%s" % [EVENTO_NODO, id])
			break
	return eventos


func esperando_decision(estado: MissionState) -> bool:
	return not estado.historia_nodo.is_empty()


## {"enabled", "reason"} de cada opción del nodo que espera decisión.
func disponibilidad_opcion(estado: MissionState, opcion: Dictionary) -> Dictionary:
	var motivo := ""
	if bool(opcion.get("requiere_companero", false)):
		if not estado.companero:
			motivo = "NO_COMPANION"
		elif estado.rocky_hp <= 0.0:
			motivo = "ROCKY_DOWN"
	return {"enabled": motivo.is_empty(), "reason": motivo}


## Aplica la opción «indice» del nodo que espera decisión. {"ok", "reason", "ends": bool}.
func decidir(estado: MissionState, indice: int) -> Dictionary:
	if estado.historia_nodo.is_empty():
		return {"ok": false, "reason": "NO_DECISION", "ends": false}
	var opciones: Array = _datos.nodo(estado.historia_nodo).get("opciones", [])
	if indice < 0 or indice >= opciones.size():
		return {"ok": false, "reason": "UNKNOWN_CHOICE", "ends": false}
	var disp := disponibilidad_opcion(estado, opciones[indice])
	if not disp["enabled"]:
		return {"ok": false, "reason": disp["reason"], "ends": false}
	return _resolver(estado, estado.historia_nodo, indice)


## Aplica la opción «indice» del nodo «id»: efectos, registro, rama, final y siguiente nodo.
func _resolver(estado: MissionState, id: String, indice: int) -> Dictionary:
	var opcion: Dictionary = _datos.nodo(id).get("opciones", [])[indice]
	_aplicar(estado, opcion.get("efectos", {}))
	estado.historia_registro.append({"node": id, "choice": indice})
	if opcion.has("rama"):
		estado.historia_rama = str(opcion["rama"])
	if opcion.has("final"):
		estado.historia_final = str(opcion["final"])
	estado.historia_espera = str(opcion.get("siguiente", ""))
	estado.historia_nodo = ""
	estado.historia_t_ultimo = _ahora(estado)
	return {"ok": true, "reason": "", "ends": bool(opcion.get("termina", false))}


## Final de la partida: el elegido en el clímax si lo hubo; si no, según la ética y Rocky. Derrota = silencio.
func final_de(estado: MissionState, exito: bool) -> String:
	if not exito:
		return FINAL_DERROTA
	if not estado.historia_final.is_empty() and estado.historia_final != FINAL_DERROTA:
		return estado.historia_final
	return FINAL_BUENO if estado.etica >= 50.0 and estado.rocky_hp > 0.0 else FINAL_DESTRUCTIVO


## Lo que la vista necesita de la historia: nodo pendiente con sus opciones, objetivo, ética, Rocky y registro.
func para_la_vista(estado: MissionState) -> Dictionary:
	var pendiente := {}
	if not estado.historia_nodo.is_empty():
		var nodo := _datos.nodo(estado.historia_nodo)
		var opciones: Array[Dictionary] = []
		for opcion in nodo.get("opciones", []):
			var disp := disponibilidad_opcion(estado, opcion)
			opciones.append({"text": opcion.get("texto", {}), "detail": opcion.get("detalle", {}),
				"enabled": disp["enabled"], "reason": disp["reason"]})
		pendiente = {"id": estado.historia_nodo, "act": nodo.get("acto", {}), "title": nodo.get("titulo", {}),
			"image": str(nodo.get("imagen", "")), "text": nodo.get("texto", {}), "rocky": nodo.get("rocky", {}),
			"scene": str(nodo.get("escena", "completa")), "dialogue": _dialogos(nodo), "choices": opciones}
	var radio := {}
	if not estado.historia_radio.is_empty():
		var nodo_radio := _datos.nodo(estado.historia_radio)
		radio = {"id": estado.historia_radio, "n": estado.historia_radio_n, "act": nodo_radio.get("acto", {}),
			"title": nodo_radio.get("titulo", {}), "image": str(nodo_radio.get("imagen", "")),
			"dialogue": _dialogos(nodo_radio)}
	var objetivo := {}
	if not estado.historia_ultimo.is_empty():
		objetivo = _datos.nodo(estado.historia_ultimo).get("objetivo", {})
	var registro: Array[Dictionary] = []
	for entrada in estado.historia_registro:
		var opciones_nodo: Array = _datos.nodo(str(entrada["node"])).get("opciones", [])
		var i := int(entrada["choice"])
		if i >= 0 and i < opciones_nodo.size():
			registro.append(opciones_nodo[i].get("registro", {}))
	return {"pending": pendiente, "radio": radio, "objective": objetivo, "goals": metas(estado),
		"ethics": estado.etica, "rocky_hp": estado.rocky_hp, "branch": estado.historia_rama, "log": registro}


## Metas del objetivo actual con su avance: [{"kind", "id", "cur", "goal", "done"}]. Son guía para el jugador: no
## bloquean la historia (eso lo deciden los disparadores).
func metas(estado: MissionState) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	if estado.historia_ultimo.is_empty():
		return lista
	for meta in _datos.nodo(estado.historia_ultimo).get("metas", []):
		var tipo := str(meta.get("tipo", ""))
		var id := str(meta.get("id", ""))
		var meta_valor := float(meta.get("min", 0.0))
		var actual := 0.0
		match tipo:
			"antena":
				actual = float(estado.nivel_antena)
			"edificio":
				for edificio in estado.edificios:
					if str(edificio["type"]) == id and int(edificio["level"]) >= 1:
						actual += 1.0
			"recurso":
				actual = float(estado.recursos.get(id, 0))
			"enviados_pct":
				actual = estado.enviados * 100.0 / float(estado.meta) if estado.meta > 0 else 0.0
			"sol":
				actual = float(estado.sol)
			"bateria_pct":
				actual = estado.bateria_wh * 100.0 / estado.bateria_capacidad_wh if estado.bateria_capacidad_wh > 0.0 else 0.0
			"rocky_hp":
				actual = estado.rocky_hp
		lista.append({"kind": tipo, "id": id, "cur": minf(actual, meta_valor), "goal": meta_valor,
			"done": actual >= meta_valor})
	return lista


## Pantallas de introducción y finales (textos para la vista).
func intro() -> Array:
	var paginas: Array = []
	for pagina in _datos.intro:
		paginas.append({"image": str(pagina.get("imagen", "")), "es": pagina.get("es", ""), "en": pagina.get("en", "")})
	return paginas


func datos_final(id: String) -> Dictionary:
	return _datos.final(id)


func _dialogos(nodo: Dictionary) -> Array[Dictionary]:
	var dialogos: Array[Dictionary] = []
	for linea in nodo.get("dialogos", []):
		var personaje: Dictionary = _datos.personajes.get(str(linea.get("quien", "")), {})
		dialogos.append({"speaker": str(linea.get("quien", "")), "name": personaje.get("nombre", {}),
			"color": str(personaje.get("color", "FFF5E4")), "text": linea.get("texto", {})})
	return dialogos


## Horas de juego transcurridas desde el sol 1 (para los respiros entre eventos).
func _ahora(estado: MissionState) -> float:
	return float(estado.sol - 1) * 24.0 + estado.hora


func _cumple(estado: MissionState, disparador: Dictionary) -> bool:
	for condicion in disparador:
		var valor: Variant = disparador[condicion]
		match str(condicion):
			"inicio":
				pass
			"antena_min":
				if estado.nivel_antena < int(valor):
					return false
			"noche":
				if estado.es_noche != bool(valor):
					return false
			"tormenta":
				if estado.tormenta != bool(valor):
					return false
			"sol_min":
				if estado.sol < int(valor):
					return false
			"enviados_pct_min":
				if estado.meta <= 0 or estado.enviados * 100.0 / float(estado.meta) < float(valor):
					return false
			_:
				return false
	return true


func _aplicar(estado: MissionState, efectos: Dictionary) -> void:
	if efectos.has("bateria_pct"):
		var cambio := estado.bateria_capacidad_wh * float(efectos["bateria_pct"]) / 100.0
		estado.bateria_wh = clampf(estado.bateria_wh + cambio, 0.0, estado.bateria_capacidad_wh)
	if efectos.has("datos"):
		estado.datos = clampf(estado.datos + float(efectos["datos"]), 0.0, estado.memoria_capacidad)
	if efectos.has("etica"):
		estado.etica = clampf(estado.etica + float(efectos["etica"]), 0.0, 100.0)
	if efectos.has("rocky_hp") and estado.companero:
		estado.rocky_hp = clampf(estado.rocky_hp + float(efectos["rocky_hp"]), 0.0, 100.0)
	if efectos.has("recursos") and _recursos != null and efectos["recursos"] is Dictionary:
		_recursos.sumar(estado, efectos["recursos"])
	if bool(efectos.get("completa_transmision", false)):
		estado.enviados = maxf(estado.enviados, float(estado.meta))
