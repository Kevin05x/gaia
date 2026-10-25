class_name StoryData
extends RefCounted
## Historia de la misión cargada desde content/historia.json: pantallas de introducción, nodos (acto,
## textos, objetivo, disparadores y opciones con efectos) y los finales. Los textos vienen en español e
## inglés ({"es", "en"}). Simulación pura: sin nodos. Errores como códigos "CODIGO:detalle".

const CONDICIONES: Array[String] = ["inicio", "antena_min", "noche", "tormenta", "sol_min", "enviados_pct_min"]
const METAS: Array[String] = ["antena", "edificio", "recurso", "enviados_pct", "sol", "bateria_pct", "rocky_hp"]
const MODOS: Array[String] = ["decision", "radio"]
const ESCENAS: Array[String] = ["completa", "corta"]
const EFECTOS: Array[String] = ["bateria_pct", "datos", "etica", "rocky_hp", "recursos", "completa_transmision"]

var inicio: String = ""
var etica_inicial: float = 50.0
var intro: Array = []
var nodos: Dictionary = {}
var finales: Dictionary = {}
var personajes: Dictionary = {}  ## quien -> {"nombre": {"es", "en"}, "color": "RRGGBB"}
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> StoryData:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacia := StoryData.new()
		vacia.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacia
	return desde_texto(texto)


static func desde_texto(texto: String) -> StoryData:
	var historia := StoryData.new()
	historia._cargar(texto)
	return historia


func nodo(id: String) -> Dictionary:
	return nodos.get(id, {})


func final(id: String) -> Dictionary:
	return finales.get(id, {})


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	inicio = str(datos.get("inicio", ""))
	etica_inicial = float(datos.get("etica_inicial", 50.0))
	var lista_intro: Variant = datos.get("intro", [])
	intro = lista_intro if lista_intro is Array else []
	var lista_nodos: Variant = datos.get("nodos", {})
	nodos = lista_nodos if lista_nodos is Dictionary else {}
	var lista_finales: Variant = datos.get("finales", {})
	finales = lista_finales if lista_finales is Dictionary else {}
	var lista_personajes: Variant = datos.get("personajes", {})
	personajes = lista_personajes if lista_personajes is Dictionary else {}
	if not nodos.has(inicio):
		errores.append("MISSING_NODE:%s" % inicio)
	for id in nodos:
		_validar_nodo(str(id), nodos[id])


func _validar_nodo(id: String, def: Variant) -> void:
	if not (def is Dictionary):
		errores.append("INVALID_NODE:%s" % id)
		return
	var disparadores: Variant = def.get("disparadores", [])
	if not (disparadores is Array) or disparadores.is_empty():
		errores.append("MISSING_TRIGGER:%s" % id)
	else:
		for disparador in disparadores:
			if not (disparador is Dictionary):
				errores.append("INVALID_TRIGGER:%s" % id)
				continue
			for condicion in disparador:
				if not CONDICIONES.has(str(condicion)):
					errores.append("UNKNOWN_CONDITION:%s:%s" % [id, condicion])
	for linea in def.get("dialogos", []):
		if not (linea is Dictionary) or not personajes.has(str(linea.get("quien", ""))):
			errores.append("UNKNOWN_SPEAKER:%s" % id)
	if not MODOS.has(str(def.get("modo", "decision"))):
		errores.append("UNKNOWN_MODE:%s" % id)
	if not ESCENAS.has(str(def.get("escena", "completa"))):
		errores.append("UNKNOWN_SCENE:%s" % id)
	if float(def.get("espera_h", 0.0)) < 0.0:
		errores.append("BAD_WAIT:%s" % id)
	for meta in def.get("metas", []):
		if not (meta is Dictionary) or not METAS.has(str(meta.get("tipo", ""))) or not meta.has("min"):
			errores.append("UNKNOWN_GOAL:%s" % id)
	var opciones: Variant = def.get("opciones", [])
	if not (opciones is Array) or opciones.is_empty():
		errores.append("MISSING_OPTIONS:%s" % id)
		return
	if str(def.get("modo", "decision")) == "radio":
		# La radio no espera al jugador: elige sola su única opción, que no puede terminar la partida ni exigir a Rocky.
		var unica: Variant = opciones[0]
		if opciones.size() != 1 or not (unica is Dictionary) or unica.has("final") or unica.has("termina") \
				or unica.has("requiere_companero"):
			errores.append("BAD_RADIO:%s" % id)
	for opcion in opciones:
		if not (opcion is Dictionary):
			errores.append("INVALID_OPTION:%s" % id)
			continue
		var siguiente := str(opcion.get("siguiente", ""))
		if not siguiente.is_empty() and not nodos.has(siguiente):
			errores.append("MISSING_NODE:%s" % siguiente)
		var final_id := str(opcion.get("final", ""))
		if not final_id.is_empty() and not finales.has(final_id):
			errores.append("MISSING_ENDING:%s" % final_id)
		if siguiente.is_empty() and final_id.is_empty():
			errores.append("DEAD_END:%s" % id)
		var efectos: Variant = opcion.get("efectos", {})
		if efectos is Dictionary:
			for efecto in efectos:
				if not EFECTOS.has(str(efecto)):
					errores.append("UNKNOWN_EFFECT:%s:%s" % [id, efecto])
