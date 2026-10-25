class_name TutorialData
extends RefCounted
## Tutorial del Sol 1 cargado desde content/tutorial.json: una lista de pasos con su texto ({"es", "en"}), la parte de
## la pantalla que señalan y la condición que los da por hechos. Simulación pura: sin nodos. Errores como códigos
## "CODIGO:detalle".

const TIPOS: Array[String] = ["edificio", "antena", "enviados"]
const RESALTES: Array[String] = ["", "mapa", "acciones", "construir", "enlace"]

var hasta_sol: int = 2  ## el tutorial se cierra solo al pasar de este sol
var pasos: Array[Dictionary] = []
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> TutorialData:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacio := TutorialData.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> TutorialData:
	var datos := TutorialData.new()
	datos._cargar(texto)
	return datos


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var raiz: Dictionary = json.data
	hasta_sol = int(raiz.get("hasta_sol", 2))
	if hasta_sol < 1:
		errores.append("INVALID_FIELD:hasta_sol")
	var lista: Variant = raiz.get("pasos", [])
	if not (lista is Array) or lista.is_empty():
		errores.append("MISSING_FIELD:pasos")
		return
	var vistos := {}
	for paso in lista:
		if not (paso is Dictionary):
			errores.append("INVALID_STEP")
			continue
		var id := str(paso.get("id", ""))
		if id.is_empty() or vistos.has(id):
			errores.append("DUPLICATE_STEP:%s" % id)
		vistos[id] = true
		var texto_paso: Variant = paso.get("texto", {})
		if not (texto_paso is Dictionary) or not texto_paso.has("es") or not texto_paso.has("en"):
			errores.append("MISSING_TEXT:%s" % id)
		if not RESALTES.has(str(paso.get("resalta", ""))):
			errores.append("UNKNOWN_HIGHLIGHT:%s" % id)
		_validar_condicion(id, paso.get("condicion", null))
		pasos.append(paso)


func _validar_condicion(id: String, condicion: Variant) -> void:
	if not (condicion is Dictionary):
		errores.append("MISSING_CONDITION:%s" % id)
		return
	if condicion.has("leer_s"):
		if float(condicion["leer_s"]) <= 0.0:
			errores.append("INVALID_CONDITION:%s" % id)
	elif condicion.has("evento"):
		if str(condicion["evento"]).is_empty() or int(condicion.get("min", 0)) < 1:
			errores.append("INVALID_CONDITION:%s" % id)
	elif condicion.has("tipo"):
		if not TIPOS.has(str(condicion["tipo"])) or float(condicion.get("min", 0)) <= 0.0:
			errores.append("INVALID_CONDITION:%s" % id)
		if str(condicion["tipo"]) == "edificio" and str(condicion.get("id", "")).is_empty():
			errores.append("INVALID_CONDITION:%s" % id)
	else:
		errores.append("INVALID_CONDITION:%s" % id)
