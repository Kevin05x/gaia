class_name Economy
extends RefCounted
## Recursos y edificios de la base cargados desde content/economia.json: recursos iniciales, lo que da cada
## acción al recolectar, capacidad de almacén, zona de la base, niveles de la Antena Científica y edificios
## (costo, vida, tiempo de construcción y energía). Simulación pura: sin nodos.
## Los errores se guardan como códigos "CODIGO:detalle".

var recursos: Array[String] = []
var recursos_iniciales: Dictionary = {}
var capacidad_base: int = 0
var recoleccion: Dictionary = {}  ## acción -> {tipo de objetivo -> {recurso: cantidad}} o {recurso: cantidad}
var zona_base_radio: int = 0
var antena_nivel_inicial: int = 0
var antena_casilla_relativa: Vector2i = Vector2i.ZERO
var antena_niveles: Array = []  ## [{"costo", "tiempo_s", "consume_w", "requiere"?}]
var edificios: Dictionary = {}  ## id -> definición
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> Economy:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacia := Economy.new()
		vacia.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacia
	return desde_texto(texto)


static func desde_texto(texto: String) -> Economy:
	var economia := Economy.new()
	economia._cargar(texto)
	return economia


func tiene_edificio(id: String) -> bool:
	return edificios.has(id)


func edificio(id: String) -> Dictionary:
	return edificios.get(id, {})


func ids_edificios() -> Array[String]:
	var ids: Array[String] = []
	for id in edificios:
		ids.append(id)
	return ids


func nivel_antena_max() -> int:
	return antena_niveles.size()


## Datos del nivel «nivel» de la antena (1 = primero). Vacío si no existe.
func nivel_antena(nivel: int) -> Dictionary:
	if nivel < 1 or nivel > antena_niveles.size():
		return {}
	return antena_niveles[nivel - 1]


## Recursos que da una acción terminada sobre un objetivo de ese tipo ({} si no da nada).
func recoleccion_de(accion: String, tipo: String) -> Dictionary:
	var datos: Variant = recoleccion.get(accion, {})
	if not (datos is Dictionary):
		return {}
	if datos.has(tipo) and datos[tipo] is Dictionary:
		return datos[tipo]
	for clave in datos:
		if not (datos[clave] is Dictionary):
			return datos  # la acción da lo mismo sin importar el objetivo (por ejemplo, el compañero)
	return {}


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	for r in datos.get("recursos", []):
		recursos.append(str(r))
	if recursos.is_empty():
		errores.append("MISSING_FIELD:recursos")
	var iniciales: Variant = datos.get("recursos_iniciales", {})
	if iniciales is Dictionary:
		for r in recursos:
			recursos_iniciales[r] = int(iniciales.get(r, 0))
	capacidad_base = int(datos.get("capacidad_base", 0))
	if capacidad_base <= 0:
		errores.append("INVALID_FIELD:capacidad_base")
	var rec: Variant = datos.get("recoleccion", {})
	recoleccion = rec if rec is Dictionary else {}
	zona_base_radio = int(datos.get("zona_base_radio", 0))
	if zona_base_radio <= 0:
		errores.append("INVALID_FIELD:zona_base_radio")
	var antena: Variant = datos.get("antena", {})
	if antena is Dictionary:
		antena_nivel_inicial = int(antena.get("nivel_inicial", 0))
		var rel: Variant = antena.get("casilla_relativa", [0, 0])
		if rel is Array and rel.size() == 2:
			antena_casilla_relativa = Vector2i(int(rel[0]), int(rel[1]))
		for nivel in antena.get("niveles", []):
			if nivel is Dictionary and nivel.get("costo") is Dictionary:
				antena_niveles.append(nivel)
			else:
				errores.append("INVALID_FIELD:antena.niveles")
	if antena_niveles.is_empty():
		errores.append("MISSING_FIELD:antena.niveles")
	var lista: Variant = datos.get("edificios", {})
	if lista is Dictionary:
		for id in lista:
			var def: Variant = lista[id]
			if not (def is Dictionary) or not (def.get("costo") is Dictionary) or float(def.get("tiempo_s", 0)) <= 0.0:
				errores.append("INVALID_FIELD:edificios.%s" % id)
				continue
			edificios[str(id)] = def
	for id in edificios:
		for recurso in edificios[id]["costo"]:
			if not recursos.has(str(recurso)):
				errores.append("UNKNOWN_RESOURCE:%s" % recurso)
