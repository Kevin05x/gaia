class_name Rules
extends RefCounted
## Reglas de misión cargadas desde content/rules.json: presupuesto, victoria,
## eventos por sol y límites de piezas. Simulación pura: sin nodos.
## Los errores se guardan como códigos "CODIGO:detalle".

var presupuesto_musd: float = 0.0
var datos_requeridos: int = 0
var sol_limite: int = 0
var eventos: Array = []
var limites: Dictionary = {}  ## categoria -> {"min": int, "max": int}; sin "max" = sin límite
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> Rules:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacias := Rules.new()
		vacias.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacias
	return desde_texto(texto)


static func desde_texto(texto: String) -> Rules:
	var reglas := Rules.new()
	reglas._cargar(texto)
	return reglas


func limite_min(categoria: String) -> int:
	return int(limites.get(categoria, {}).get("min", 0))


## Devuelve -1 cuando la categoría no tiene máximo.
func limite_max(categoria: String) -> int:
	return int(limites.get(categoria, {}).get("max", -1))


func soles_de_evento(tipo: String) -> Array[int]:
	var soles: Array[int] = []
	for evento in eventos:
		if evento is Dictionary and evento.get("tipo") == tipo:
			for sol in evento.get("soles", []):
				soles.append(int(sol))
	return soles


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	presupuesto_musd = _numero(datos, "presupuesto_musd", "presupuesto_musd")

	var victoria: Variant = datos.get("victoria")
	if victoria is Dictionary:
		datos_requeridos = int(_numero(victoria, "datos_requeridos", "victoria.datos_requeridos"))
		sol_limite = int(_numero(victoria, "sol_limite", "victoria.sol_limite"))
	else:
		errores.append("MISSING_FIELD:victoria")

	var lista_eventos: Variant = datos.get("eventos", [])
	if lista_eventos is Array:
		eventos = lista_eventos
	else:
		errores.append("INVALID_FIELD:eventos")

	var lista_limites: Variant = datos.get("limites_piezas", {})
	if lista_limites is Dictionary:
		limites = lista_limites
	else:
		errores.append("INVALID_FIELD:limites_piezas")


func _numero(fuente: Dictionary, clave: String, etiqueta: String) -> float:
	var valor: Variant = fuente.get(clave)
	if valor is float or valor is int:
		return float(valor)
	errores.append("MISSING_FIELD:%s" % etiqueta)
	return 0.0
