class_name MapData
extends RefCounted
## Mapa fijo de la misión (content/mapa.json): límites, inicio del rover, estación, obstáculos y
## objetivos. Valida el archivo, calcula rutas casilla a casilla (4 direcciones) y vuelca el mapa
## en MissionState. El rover no puede pisar obstáculos, la estación ni los objetivos.

const TIPOS: Array[String] = ["rock", "mineral", "buried"]
const VECINOS := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]

var limite_min: Vector2i = Vector2i(-11, -11)
var limite_max: Vector2i = Vector2i(11, 11)
var inicio_rover: Vector2i = Vector2i.ZERO
var estacion: Vector2i = Vector2i.ZERO
var obstaculos: Array[Vector2i] = []
var objetivos: Array[Dictionary] = []  ## {"id", "tile", "type", "revealed"}
var bloqueos_extra: Dictionary = {}  ## casillas ocupadas durante la partida (edificios); las fija BuildSystem
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(archivo: String) -> MapData:
	var texto := FileAccess.get_file_as_string(archivo)
	if texto.is_empty():
		var vacio := MapData.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % archivo)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> MapData:
	var mapa := MapData.new()
	mapa._cargar(texto)
	return mapa


func dentro_de_limites(casilla: Vector2i) -> bool:
	return casilla.x >= limite_min.x and casilla.x <= limite_max.x and casilla.y >= limite_min.y and casilla.y <= limite_max.y


## Casillas donde el rover no puede estar: fuera del mapa, obstáculos, estación y objetivos.
func bloqueada(casilla: Vector2i) -> bool:
	if not dentro_de_limites(casilla) or casilla == estacion or obstaculos.has(casilla) or bloqueos_extra.has(casilla):
		return true
	for objetivo in objetivos:
		if objetivo["tile"] == casilla:
			return true
	return false


## Ruta más corta (4 direcciones) sin incluir la casilla de salida. Vacía si no hay ruta,
## si el destino está bloqueado o si destino y salida coinciden.
func ruta(desde: Vector2i, hasta: Vector2i) -> Array[Vector2i]:
	var camino: Array[Vector2i] = []
	if desde == hasta or bloqueada(hasta) or not dentro_de_limites(desde):
		return camino
	var previo := {desde: desde}
	var cola: Array[Vector2i] = [desde]
	var indice := 0
	while indice < cola.size():
		var actual := cola[indice]
		indice += 1
		if actual == hasta:
			break
		for vecino in VECINOS:
			var siguiente: Vector2i = actual + vecino
			if previo.has(siguiente) or bloqueada(siguiente):
				continue
			previo[siguiente] = actual
			cola.append(siguiente)
	if not previo.has(hasta):
		return camino
	var paso := hasta
	while paso != desde:
		camino.push_front(paso)
		paso = previo[paso]
	return camino


## Vuelca el mapa en el estado de la misión (copias; los objetivos empiezan sin acciones hechas).
func aplicar_a(estado: MissionState) -> void:
	estado.limite_min = limite_min
	estado.limite_max = limite_max
	estado.casilla_rover = inicio_rover
	estado.casilla_estacion = estacion
	estado.obstaculos.clear()
	for casilla in obstaculos:
		estado.obstaculos.append(casilla)
	estado.objetivos.clear()
	for objetivo in objetivos:
		estado.objetivos.append({"id": objetivo["id"], "tile": objetivo["tile"], "type": objetivo["type"],
			"revealed": objetivo["revealed"], "depleted": false, "done": []})
	estado.revision_mapa += 1


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	for campo in ["limites", "inicio_rover", "estacion", "obstaculos", "objetivos"]:
		if not datos.has(campo):
			errores.append("MISSING_FIELD:%s" % campo)
	if not errores.is_empty():
		return
	if not _leer_limites(datos["limites"]):
		return
	var inicio: Variant = _leer_casilla(datos["inicio_rover"], "inicio_rover")
	if inicio != null:
		inicio_rover = inicio
	var puesto: Variant = _leer_casilla(datos["estacion"], "estacion")
	if puesto != null:
		estacion = puesto
	if datos["obstaculos"] is Array:
		var indice := 0
		for valor in datos["obstaculos"]:
			var casilla: Variant = _leer_casilla(valor, "obstaculos[%d]" % indice)
			if casilla != null:
				obstaculos.append(casilla)
			indice += 1
	else:
		errores.append("INVALID_FIELD:obstaculos")
	if datos["objetivos"] is Array:
		_leer_objetivos(datos["objetivos"])
	else:
		errores.append("INVALID_FIELD:objetivos")
	if errores.is_empty():
		_comprobar_ocupacion()
	if errores.is_empty():
		_comprobar_alcanzables()


func _leer_limites(valor: Variant) -> bool:
	if not (valor is Dictionary):
		errores.append("INVALID_FIELD:limites")
		return false
	var minimo: Variant = _leer_casilla(valor.get("min"), "limites.min")
	var maximo: Variant = _leer_casilla(valor.get("max"), "limites.max")
	if minimo == null or maximo == null:
		return false
	if minimo.x > maximo.x or minimo.y > maximo.y:
		errores.append("INVALID_FIELD:limites")
		return false
	limite_min = minimo
	limite_max = maximo
	return true


func _leer_objetivos(lista: Array) -> void:
	var vistos := {}
	var indice := 0
	for entrada in lista:
		var etiqueta := "objetivos[%d]" % indice
		indice += 1
		if not (entrada is Dictionary):
			errores.append("INVALID_FIELD:%s" % etiqueta)
			continue
		var id := str(entrada.get("id", ""))
		if id.is_empty():
			errores.append("MISSING_FIELD:%s.id" % etiqueta)
			continue
		if vistos.has(id):
			errores.append("DUPLICATE_TARGET:%s" % id)
			continue
		vistos[id] = true
		var tipo := str(entrada.get("tipo", ""))
		if not TIPOS.has(tipo):
			errores.append("INVALID_TARGET_TYPE:%s" % id)
			continue
		if not (entrada.get("revelado") is bool):
			errores.append("MISSING_FIELD:objetivos.%s.revelado" % id)
			continue
		var casilla: Variant = _leer_casilla(entrada.get("casilla"), "objetivos.%s" % id)
		if casilla == null:
			continue
		objetivos.append({"id": id, "tile": casilla, "type": tipo, "revealed": entrada["revelado"]})


## [x, y] con enteros -> Vector2i. null (y error INVALID_TILE) si no tiene esa forma.
func _leer_casilla(valor: Variant, etiqueta: String) -> Variant:
	if valor is Array and valor.size() == 2:
		var x: Variant = valor[0]
		var y: Variant = valor[1]
		if (x is int or x is float) and (y is int or y is float) and float(x) == floorf(float(x)) and float(y) == floorf(float(y)):
			return Vector2i(int(x), int(y))
	errores.append("INVALID_TILE:%s" % etiqueta)
	return null


func _comprobar_ocupacion() -> void:
	var elementos: Array = [["inicio_rover", inicio_rover], ["estacion", estacion]]
	for i in obstaculos.size():
		elementos.append(["obstaculos[%d]" % i, obstaculos[i]])
	for objetivo in objetivos:
		elementos.append(["objetivos.%s" % objetivo["id"], objetivo["tile"]])
	var ocupadas := {}
	for elemento in elementos:
		var casilla: Vector2i = elemento[1]
		if not dentro_de_limites(casilla):
			errores.append("OUT_OF_BOUNDS:%s" % elemento[0])
		elif ocupadas.has(casilla):
			errores.append("TILE_OCCUPIED:%d,%d" % [casilla.x, casilla.y])
		else:
			ocupadas[casilla] = elemento[0]


## Cada objetivo debe tener alguna casilla contigua a la que el rover pueda llegar desde el inicio.
func _comprobar_alcanzables() -> void:
	for objetivo in objetivos:
		var alcanzable := false
		var casilla_objetivo: Vector2i = objetivo["tile"]
		for desplazamiento in VECINOS:
			var vecino: Vector2i = casilla_objetivo + desplazamiento
			if bloqueada(vecino):
				continue
			if vecino == inicio_rover or not ruta(inicio_rover, vecino).is_empty():
				alcanzable = true
				break
		if not alcanzable:
			errores.append("UNREACHABLE_TARGET:%s" % objetivo["id"])
