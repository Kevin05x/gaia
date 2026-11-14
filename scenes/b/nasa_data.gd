extends RefCounted
## Datos reales de la misión Mars 2020 (Perseverance) que el juego usa como referencia: hechos con su fuente
## (content/nasa/mision_real.json) e imágenes de la NASA Image and Video Library con su crédito.
## Todo lo que muestra el juego como «dato real» sale de aquí; lo demás son valores de juego.

const RUTA := "res://content/nasa/mision_real.json"

static var _cache: Dictionary = {}


static func datos() -> Dictionary:
	if _cache.is_empty():
		var texto := FileAccess.get_file_as_string(RUTA)
		var json: Variant = JSON.parse_string(texto) if not texto.is_empty() else null
		_cache = json if json is Dictionary else {"datos": [], "imagenes": {}, "comparacion": {}}
	return _cache


static func en_ingles() -> bool:
	return TranslationServer.get_locale().begins_with("en")


## Texto de un dato real en el idioma actual (vacío si no existe).
static func dato(id: String) -> String:
	for d in datos().get("datos", []):
		if str(d.get("id", "")) == id:
			return str(d.get("en" if en_ingles() else "es", ""))
	return ""


## Fuente del dato real (nombre del documento oficial).
static func fuente(id: String) -> String:
	for d in datos().get("datos", []):
		if str(d.get("id", "")) == id:
			return str(d.get("fuente", ""))
	return ""


static func comparacion() -> Dictionary:
	return datos().get("comparacion", {})


static func imagen(id: String) -> Texture2D:
	var info: Dictionary = datos().get("imagenes", {}).get(id, {})
	var ruta := str(info.get("archivo", ""))
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D


## «Foto: NASA/JPL-Caltech/MSSS · PIA24542 · images.nasa.gov» (o «Ilustración» si lo es).
static func credito(id: String) -> String:
	var info: Dictionary = datos().get("imagenes", {}).get(id, {})
	if info.is_empty():
		return ""
	var tipo := ("Illustration" if en_ingles() else "Ilustración") if bool(info.get("ilustracion", false)) else ("Photo" if en_ingles() else "Foto")
	return "%s: %s · %s · images.nasa.gov" % [tipo, str(info.get("credito", "NASA")), str(info.get("nasa_id", ""))]


static func url_imagen(id: String) -> String:
	return str(datos().get("imagenes", {}).get(id, {}).get("url", ""))
