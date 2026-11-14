extends RefCounted
## Récords de misiones y códigos de diseño para compartir y comparar.
## · Código de diseño: «GAIA-M-ABDGK» = destino (M Marte, L Luna) + una letra por pieza elegida (orden de parts.json).
##   Se copia desde el informe o el taller y se pega en el taller de otro equipo: mismo objetivo, diseños distintos.
## · Récords: las mejores misiones de este equipo (puntuación, destino, dificultad, equipo y código), en user://.

const ARCHIVO := "user://gaia_records.json"
const PIEZAS := "res://content/parts.json"
const LETRAS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const MAXIMO := 20

static var _ids: Array = []


## Ids de todas las piezas en el orden del archivo (estable entre partidas y equipos).
static func ids() -> Array:
	if _ids.is_empty():
		var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(PIEZAS))
		if datos is Dictionary:
			for categoria in ["chasis", "cohetes", "trayectoria", "energia", "comunicaciones", "extras"]:
				for p in datos.get(categoria, []):
					_ids.append(str(p["id"]))
	return _ids


static func codigo(seleccion: Dictionary, destino: String) -> String:
	var letras := ""
	var lista := ids()
	for categoria in seleccion:
		for id in seleccion[categoria]:
			var i := lista.find(str(id))
			if i >= 0 and i < LETRAS.length():
				letras += LETRAS[i]
	var orden := letras.split("")
	orden.sort()
	return "GAIA-%s-%s" % ["L" if destino == "luna" else "M", "".join(orden)]


## {"destino", "piezas": [ids]} o vacío si el código no es válido.
static func leer_codigo(texto: String) -> Dictionary:
	var partes := texto.strip_edges().to_upper().split("-")
	if partes.size() != 3 or partes[0] != "GAIA" or not (partes[1] in ["M", "L"]):
		return {}
	var piezas: Array = []
	for letra in partes[2]:
		var i := LETRAS.find(letra)
		if i < 0 or i >= ids().size():
			return {}
		piezas.append(ids()[i])
	return {"destino": "luna" if partes[1] == "L" else "marte", "piezas": piezas}


## Puntuación de una misión: ciencia enviada, estrellas, éxito y presupuesto ahorrado (premia la eficiencia).
static func puntuacion(informe: Dictionary, taller: Dictionary) -> int:
	var totales: Dictionary = taller.get("totals", {})
	var meta := maxf(float(informe.get("goal", 100)), 1.0)
	var ahorro := maxf(float(totales.get("budget_musd", 0)) - float(totales.get("cost_musd", 0)), 0.0)
	var puntos := 600.0 * minf(float(informe.get("sent", 0)) / meta, 1.0) + 150.0 * int(informe.get("stars", 0)) + ahorro
	if bool(informe.get("success", false)):
		puntos += 300.0
	return int(round(puntos))


static func leer() -> Array:
	if not FileAccess.file_exists(ARCHIVO):
		return []
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVO))
	return datos if datos is Array else []


## Guarda la misión y devuelve su puesto (1 = la mejor), o 0 si no entró entre las MAXIMO mejores.
static func guardar(entrada: Dictionary) -> int:
	var lista := leer()
	lista.append(entrada)
	lista.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	var puesto := lista.find(entrada) + 1
	lista = lista.slice(0, MAXIMO)
	var archivo := FileAccess.open(ARCHIVO, FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(JSON.stringify(lista))
	return puesto if puesto <= MAXIMO else 0
