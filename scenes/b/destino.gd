class_name Destino
extends RefCounted
## Destino de la misión: «marte» (cráter Jezero, con historia) o «luna» (polo sur lunar).
## La simulación recibe sus datos de content/destinos.json; aquí vive lo que cambia en la vista: la paleta del
## mundo (el regolito lunar es gris, el marciano rojizo), los textos que nombran el lugar y algunos datos reales.

const DATOS := "res://content/destinos.json"
static var id := "marte"

static var _textos_originales: Dictionary = {}  ## idioma -> {clave: texto} para volver a Marte


static func es_luna() -> bool:
	return id == "luna"


static var _forward_plus := -1


## true con el renderer Forward+ (escritorio): ilumina en espacio lineal y admite efectos avanzados.
static func forward_plus() -> bool:
	if _forward_plus < 0:
		_forward_plus = 1 if RenderingServer.get_current_rendering_method() == "forward_plus" else 0
	return _forward_plus == 1


## Lee la configuración de un destino (archivos de datos y parámetros) de content/destinos.json.
static func config(destino: String = "") -> Dictionary:
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATOS))
	if not (datos is Dictionary):
		return {}
	return datos.get("destinos", {}).get(destino if not destino.is_empty() else id, {})


## Color del mundo según el destino. En la Luna, el mismo relieve con el gris del regolito: se conserva la
## luminosidad de cada tono (las sombras siguen siendo sombras) y se quita el óxido de hierro que tiñe Marte.
static func color(c: Color) -> Color:
	if not es_luna():
		return c
	if absf(c.r - c.g) < 0.004 and absf(c.g * 1.0304 - c.b) < 0.006:
		return c  # ya está en la paleta lunar (no se aplica dos veces)
	var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	var g := clampf(pow(lum, 1.08) * 0.97, 0.0, 1.0)
	return Color(g * 0.985, g * 0.985, g * 1.015, c.a)


static func colores(lista: PackedColorArray) -> PackedColorArray:
	if not es_luna():
		return lista
	var salida := PackedColorArray()
	salida.resize(lista.size())
	for i in range(lista.size()):
		salida[i] = color(lista[i])
	return salida


## Cambia los textos que nombran el lugar (sol → día, Jezero → polo sur...) en las traducciones ya cargadas.
## Las claves y textos lunares están en content/destinos.json › luna › textos.
static func aplicar_textos() -> void:
	var textos_luna: Dictionary = config("luna").get("textos", {})
	for idioma in ["es", "en"]:
		var t := TranslationServer.get_translation_object(idioma)
		if t == null:
			continue
		var cambios: Dictionary = textos_luna.get(idioma, {})
		if not _textos_originales.has(idioma):
			var copia := {}
			for clave in cambios:
				copia[clave] = t.get_message(clave)
			_textos_originales[idioma] = copia
		for clave in cambios:
			_poner(clave, str(cambios[clave]) if es_luna() else str(_textos_originales[idioma].get(clave, "")), idioma)


## Escribe el texto en todas las traducciones de ese idioma que ya tengan la clave (menú, juego y CSV).
static func _poner(clave: String, texto: String, idioma: String) -> void:
	if texto.is_empty():
		return
	for t in _traducciones(idioma):
		if t.get_message(clave) != "" or t == TranslationServer.get_translation_object(idioma):
			t.add_message(clave, texto)


static var _registradas: Array = []  ## traducciones creadas por el juego (las registra menu_text y mission_view)


static func registrar(t: Translation) -> void:
	if not _registradas.has(t):
		_registradas.append(t)


static func _traducciones(idioma: String) -> Array:
	var lista: Array = []
	for t in _registradas:
		if t != null and str(t.locale) == idioma:
			lista.append(t)
	var principal := TranslationServer.get_translation_object(idioma)
	if principal != null and not lista.has(principal):
		lista.append(principal)
	return lista
