class_name Balance
extends RefCounted
## Cifras de juego cargadas desde content/balance.json: tiempo, energía, movimiento,
## acciones, ciencia y comunicaciones. Simulación pura: sin nodos.
## La potencia de paneles y MMRTG NO está aquí: sale de parts.json.
## Los errores se guardan como códigos "CODIGO:detalle".

## Rutas (separadas por punto) que deben existir y ser numéricas.
const RUTAS_NUMERICAS: Array[String] = [
	"tiempo.duracion_sol_s",
	"tiempo.hora_inicio",
	"tiempo.amanecer",
	"tiempo.atardecer",
	"energia.capacidad_base_wh",
	"energia.consumo_base_w",
	"energia.calefaccion_nocturna_w.solar",
	"energia.calefaccion_nocturna_w.rtg",
	"energia.factor_solar_tormenta",
	"energia.polvo_inicial",
	"energia.umbral_salida_modo_seguro",
	"energia.modos_seguros_para_fallar",
	"movimiento.costo_wh_por_casilla",
	"movimiento.segundos_por_casilla",
	"ciencia.memoria_capacidad",
	"ciencia.rendimiento.spectrometer",
	"ciencia.rendimiento.drill",
	"ciencia.rendimiento.drill_enterrado",
	"ciencia.meteo_por_sol",
	"ciencia.minerales_por_mineral",
	"ciencia.minerales_companero",
	"ciencia.minerales_mejora_antena",
	"ciencia.nivel_antena_max",
	"comunicaciones.rele.unidades_por_s",
	"comunicaciones.rele.costo_wh_por_unidad",
	"comunicaciones.directa.unidades_por_s",
	"comunicaciones.directa.costo_wh_por_unidad",
]

## Acciones con costo y duración obligatorios (ids del contrato con la interfaz).
const ACCIONES: Array[String] = ["panorama", "spectrometer", "drill", "radar", "drone", "companion"]

## Tipos de enlace con ventanas de comunicación obligatorias.
const ENLACES: Array[String] = ["rele", "directa"]

var datos: Dictionary = {}
var errores: PackedStringArray = PackedStringArray()


static func desde_archivo(ruta: String) -> Balance:
	var texto := FileAccess.get_file_as_string(ruta)
	if texto.is_empty():
		var vacio := Balance.new()
		vacio.errores.append("FILE_UNREADABLE:%s" % ruta)
		return vacio
	return desde_texto(texto)


static func desde_texto(texto: String) -> Balance:
	var balance := Balance.new()
	balance._cargar(texto)
	return balance


func existe(ruta: String) -> bool:
	return _buscar(ruta) != null


## Valor numérico de una ruta con puntos ("energia.consumo_base_w"). 0.0 si no existe.
func numero(ruta: String) -> float:
	var valor: Variant = _buscar(ruta)
	return float(valor) if (valor is float or valor is int) else 0.0


## Datos de una acción ({"costo_wh", "duracion_s", ...}). Vacío si no existe.
func accion(id: String) -> Dictionary:
	var valor: Variant = _buscar("acciones.%s" % id)
	return valor if valor is Dictionary else {}


## Ventanas de comunicación [[inicio, fin], ...] en horas del sol. Vacío si no existe.
func ventanas(enlace: String) -> Array:
	var valor: Variant = _buscar("comunicaciones.%s.ventanas" % enlace)
	return valor if valor is Array else []


func _cargar(texto: String) -> void:
	var json := JSON.new()
	if json.parse(texto) != OK or not (json.data is Dictionary):
		errores.append("INVALID_JSON")
		return
	datos = json.data

	var rutas: Array[String] = RUTAS_NUMERICAS.duplicate()
	for id in ACCIONES:
		rutas.append("acciones.%s.costo_wh" % id)
		rutas.append("acciones.%s.duracion_s" % id)
	for ruta in rutas:
		var valor: Variant = _buscar(ruta)
		if not (valor is float or valor is int):
			errores.append("MISSING_FIELD:%s" % ruta)

	for enlace in ENLACES:
		if not _ventanas_validas(_buscar("comunicaciones.%s.ventanas" % enlace)):
			errores.append("INVALID_FIELD:comunicaciones.%s.ventanas" % enlace)


func _buscar(ruta: String) -> Variant:
	var actual: Variant = datos
	for parte in ruta.split("."):
		if not (actual is Dictionary) or not actual.has(parte):
			return null
		actual = actual[parte]
	return actual


## Una lista no vacía de pares [inicio, fin] numéricos con inicio < fin.
func _ventanas_validas(valor: Variant) -> bool:
	if not (valor is Array) or valor.is_empty():
		return false
	for par in valor:
		if not (par is Array) or par.size() != 2:
			return false
		if not ((par[0] is float or par[0] is int) and (par[1] is float or par[1] is int)):
			return false
		if par[0] >= par[1]:
			return false
	return true
