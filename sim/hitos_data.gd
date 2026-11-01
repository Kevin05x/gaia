class_name HitosData
extends RefCounted
## Hitos científicos (content/hitos.json): la ciencia avanza por etapas de la misión. Cada hito pertenece a uno de
## los cuatro objetivos de Mars 2020 y da un tramo de datos cuando se cumple su condición (todas sus claves).
## Simulación pura: sin nodos. Errores como códigos "CODIGO:detalle".

## Contadores que puede usar una condición (los calcula HitosSystem a partir del estado).
const CONDICIONES: Array[String] = ["rocas_analizadas", "minerales", "enterrados", "muestras", "zonas", "antena", "paneles", "oleadas"]

var objetivos: Array[Dictionary] = []  ## {"id", "nombre": {"es", "en"}}
var hitos: Array[Dictionary] = []  ## {"id", "objetivo", "datos", "condicion": {clave: mínimo}, "nombre": {"es", "en"}}
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> HitosData:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacio := HitosData.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> HitosData:
	var datos := HitosData.new()
	datos._cargar(texto)
	return datos


## Suma de los datos de todos los hitos.
func total() -> float:
	var suma := 0.0
	for h in hitos:
		suma += float(h["datos"])
	return suma


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var raiz: Dictionary = json.data
	var ids_objetivo := {}
	for o in raiz.get("objetivos", []):
		if not (o is Dictionary) or not o.has("id") or not (o.get("nombre") is Dictionary):
			errores.append("INVALID_FIELD:objetivos")
			continue
		objetivos.append({"id": str(o["id"]), "nombre": o["nombre"]})
		ids_objetivo[str(o["id"])] = true
	var vistos := {}
	for h in raiz.get("hitos", []):
		if not (h is Dictionary):
			errores.append("INVALID_FIELD:hitos")
			continue
		var id := str(h.get("id", ""))
		if id.is_empty() or vistos.has(id):
			errores.append("INVALID_ID:%s" % id)
			continue
		vistos[id] = true
		if not ids_objetivo.has(str(h.get("objetivo", ""))):
			errores.append("UNKNOWN_OBJECTIVE:%s" % id)
		var condicion: Variant = h.get("condicion", {})
		if not (condicion is Dictionary) or (condicion as Dictionary).is_empty():
			errores.append("INVALID_CONDITION:%s" % id)
			continue
		for clave in condicion:
			if not CONDICIONES.has(str(clave)):
				errores.append("UNKNOWN_CONDITION:%s.%s" % [id, clave])
		if float(h.get("datos", 0)) <= 0.0:
			errores.append("INVALID_DATA:%s" % id)
		hitos.append({"id": id, "objetivo": str(h.get("objetivo", "")), "datos": float(h.get("datos", 0)),
			"condicion": condicion, "nombre": h.get("nombre", {})})
