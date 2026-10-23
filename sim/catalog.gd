class_name Catalog
extends RefCounted
## Catálogo de piezas cargado desde content/parts.json.
## Simulación pura: sin nodos. Los errores se guardan como códigos "CODIGO:detalle".

const CATEGORIAS: Array[String] = ["chasis", "cohetes", "energia", "comunicaciones", "extras"]

## Campos numéricos obligatorios por categoría (las piezas con "pendiente": true se saltan).
const CAMPOS_REQUERIDOS := {
	"chasis": ["masa_kg", "costo_musd"],
	"cohetes": ["capacidad_kg", "costo_musd"],
	"energia": ["masa_kg", "costo_musd"],
	"comunicaciones": ["masa_kg", "costo_musd"],
	"extras": ["masa_kg", "costo_musd"],
}

var piezas: Dictionary = {}  ## id -> Dictionary de la pieza (con la clave añadida "categoria")
var errores: PackedStringArray = PackedStringArray()
var pendientes: PackedStringArray = PackedStringArray()  ## ids con datos aún por definir


static func desde_archivo(ruta: String) -> Catalog:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacio := Catalog.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> Catalog:
	var catalogo := Catalog.new()
	catalogo._cargar(texto)
	return catalogo


func tiene(id: String) -> bool:
	return piezas.has(id)


func obtener(id: String) -> Dictionary:
	return piezas.get(id, {})


func ids_de(categoria: String) -> PackedStringArray:
	var resultado := PackedStringArray()
	for id in piezas:
		if piezas[id]["categoria"] == categoria:
			resultado.append(id)
	return resultado


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	for categoria in CATEGORIAS:
		var lista: Variant = datos.get(categoria, [])
		if not (lista is Array):
			errores.append("INVALID_CATEGORY:%s" % categoria)
			continue
		for pieza in lista:
			_agregar_pieza(categoria, pieza)


func _agregar_pieza(categoria: String, pieza: Variant) -> void:
	if not (pieza is Dictionary) or not (pieza.get("id") is String):
		errores.append("INVALID_PART:%s" % categoria)
		return
	var id: String = pieza["id"]
	if piezas.has(id):
		errores.append("DUPLICATE_ID:%s" % id)
		return
	if not (pieza.get("nombre_clave") is String):
		errores.append("MISSING_NAME_KEY:%s" % id)
	var es_pendiente: bool = pieza.get("pendiente", false) == true
	if not es_pendiente:
		for campo in CAMPOS_REQUERIDOS[categoria]:
			var valor: Variant = pieza.get(campo)
			if not (valor is float or valor is int):
				errores.append("MISSING_FIELD:%s:%s" % [id, campo])
	var copia: Dictionary = (pieza as Dictionary).duplicate()
	copia["categoria"] = categoria
	piezas[id] = copia
	if es_pendiente:
		pendientes.append(id)
