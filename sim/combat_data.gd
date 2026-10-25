class_name CombatData
extends RefCounted
## Datos del combate cargados desde content/combate.json: tipos de monstruo, oleadas, cómo la actividad de la base
## despierta a la fauna (amenaza), reparación de Rocky y lluvias de meteoritos. Simulación pura: sin nodos.
## Las torretas no están aquí: son edificios de economia.json. Errores como códigos "CODIGO:detalle".

const CAMPOS_ENEMIGO: Array[String] = ["hp", "velocidad", "dano", "alcance", "cadencia_s"]

var max_activos: int = 20
var enemigos: Dictionary = {}  ## id -> definición
var oleadas: Array[Dictionary] = []  ## {"id", "sol", "hora", "grupos": [{"tipo", "cantidad", "zona"}]} ordenadas por momento
var amenaza: Dictionary = {}
var reparacion: Dictionary = {}
var meteoritos: Array[Dictionary] = []  ## {"id", "sol", "hora", "impactos", "dano", "radio", "aviso_s", "separacion_s"}
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> CombatData:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacio := CombatData.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> CombatData:
	var datos := CombatData.new()
	datos._cargar(texto)
	return datos


func enemigo(id: String) -> Dictionary:
	return enemigos.get(id, {})


func oleada(id: String) -> Dictionary:
	for entrada in oleadas:
		if entrada["id"] == id:
			return entrada
	return {}


## Momento absoluto en horas de juego desde el sol 1, hora 0.
static func momento(sol: int, hora: float) -> float:
	return float(sol - 1) * ClockSystem.HORAS_POR_SOL + hora


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	var datos: Dictionary = json.data
	max_activos = int(datos.get("max_activos", 20))
	if max_activos < 1:
		errores.append("INVALID_FIELD:max_activos")
	_leer_enemigos(datos.get("enemigos"))
	_leer_oleadas(datos.get("oleadas"))
	var valor_amenaza: Variant = datos.get("amenaza", {})
	amenaza = valor_amenaza if valor_amenaza is Dictionary else {}
	if not enemigos.has(str(amenaza.get("extra_tipo", ""))) and not amenaza.is_empty():
		errores.append("UNKNOWN_ENEMY:amenaza.extra_tipo")
	var valor_reparacion: Variant = datos.get("reparacion", {})
	reparacion = valor_reparacion if valor_reparacion is Dictionary else {}
	_leer_meteoritos(datos.get("meteoritos", []))


func _leer_enemigos(valor: Variant) -> void:
	if not (valor is Dictionary) or valor.is_empty():
		errores.append("MISSING_FIELD:enemigos")
		return
	for id in valor:
		var def: Variant = valor[id]
		if not (def is Dictionary):
			errores.append("INVALID_FIELD:enemigos.%s" % id)
			continue
		var bien := true
		for campo in CAMPOS_ENEMIGO:
			if float(def.get(campo, 0.0)) <= 0.0:
				errores.append("INVALID_FIELD:enemigos.%s.%s" % [id, campo])
				bien = false
		if bien:
			enemigos[str(id)] = def


func _leer_oleadas(valor: Variant) -> void:
	if not (valor is Array) or valor.is_empty():
		errores.append("MISSING_FIELD:oleadas")
		return
	var vistas := {}
	for entrada in valor:
		if not (entrada is Dictionary) or str(entrada.get("id", "")).is_empty():
			errores.append("INVALID_FIELD:oleadas")
			continue
		var id := str(entrada["id"])
		if vistas.has(id):
			errores.append("DUPLICATE_WAVE:%s" % id)
			continue
		vistas[id] = true
		var hora := float(entrada.get("hora", -1.0))
		if int(entrada.get("sol", 0)) < 1 or hora < 0.0 or hora >= ClockSystem.HORAS_POR_SOL:
			errores.append("INVALID_FIELD:oleadas.%s.momento" % id)
			continue
		var grupos: Array = []
		for grupo in entrada.get("grupos", []):
			if not (grupo is Dictionary) or not enemigos.has(str(grupo.get("tipo", ""))) or int(grupo.get("cantidad", 0)) < 1:
				errores.append("INVALID_FIELD:oleadas.%s.grupos" % id)
				continue
			grupos.append({"tipo": str(grupo["tipo"]), "cantidad": int(grupo["cantidad"]), "zona": str(grupo.get("zona", ""))})
		if grupos.is_empty():
			errores.append("MISSING_FIELD:oleadas.%s.grupos" % id)
			continue
		oleadas.append({"id": id, "sol": int(entrada["sol"]), "hora": hora, "grupos": grupos})
	oleadas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return momento(a["sol"], a["hora"]) < momento(b["sol"], b["hora"]))


func _leer_meteoritos(valor: Variant) -> void:
	if not (valor is Array):
		errores.append("INVALID_FIELD:meteoritos")
		return
	for entrada in valor:
		if not (entrada is Dictionary) or str(entrada.get("id", "")).is_empty() or int(entrada.get("sol", 0)) < 1 \
				or int(entrada.get("impactos", 0)) < 1 or float(entrada.get("dano", 0.0)) <= 0.0 or float(entrada.get("radio", 0.0)) <= 0.0:
			errores.append("INVALID_FIELD:meteoritos")
			continue
		meteoritos.append({"id": str(entrada["id"]), "sol": int(entrada["sol"]), "hora": float(entrada.get("hora", 12.0)),
			"impactos": int(entrada["impactos"]), "dano": float(entrada["dano"]), "radio": float(entrada["radio"]),
			"aviso_s": float(entrada.get("aviso_s", 5.0)), "separacion_s": float(entrada.get("separacion_s", 1.0))})
