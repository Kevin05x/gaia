class_name MissionState
extends RefCounted
## Estado vivo de la misión: solo datos, sin reglas de juego (esas viven en los sistemas de sim/).
## a_snapshot() entrega el formato de scenes/b/docs/INTEGRACION_A.md, salvo "available_actions",
## que añade la simulación porque depende de las reglas.

const ENERGIAS: Array[String] = ["solar", "rtg"]
## Vocabulario de la vista de B -> clave del enlace en balance.json.
const ENLACES: Dictionary = {"relay": "rele", "direct": "directa"}

var fase: String = "landing"  ## landing / operations / report
var pausado: bool = false
var modo_seguro: bool = false
var entradas_modo_seguro: int = 0
var sol: int = 1
var hora: float = 8.0
var casilla_rover: Vector2i = Vector2i.ZERO
var casilla_estacion: Vector2i = Vector2i.ZERO

var bateria_wh: float = 0.0
var bateria_capacidad_wh: float = 0.0
var generacion_w: float = 0.0
var carga_w: float = 0.0

var energia: String = "solar"
var enlace: String = "relay"
var instrumentos: Array[String] = []
var companero: bool = false

var datos: float = 0.0  ## guardados en memoria, sin enviar
var memoria_capacidad: float = 0.0
var enviados: float = 0.0
var meta: int = 0
var minerales: int = 0
var nivel_antena: int = 1
var polvo: float = 0.0

var tormenta: bool = false
var tormenta_en: float = 0.0  ## soles que faltan para la tormenta
var transmitiendo: bool = false
var enlace_abierto: bool = false
var es_noche: bool = false
var proximo_cambio_enlace: Dictionary = {"opens": true, "hour": 0.0, "sol": 1}  ## opens=false: próximo cierre
var ventanas_enlace: Array = []
var en_movimiento: bool = false
var ocupado: bool = false

var revision_mapa: int = 1
var objetivos: Array[Dictionary] = []
var obstaculos: Array[Vector2i] = []

var _balance: Balance


func _init(balance: Balance, reglas: Rules) -> void:
	_balance = balance
	hora = balance.numero("tiempo.hora_inicio")
	bateria_capacidad_wh = balance.numero("energia.capacidad_base_wh")
	bateria_wh = bateria_capacidad_wh
	carga_w = balance.numero("energia.consumo_base_w")
	memoria_capacidad = balance.numero("ciencia.memoria_capacidad")
	polvo = balance.numero("energia.polvo_inicial")
	meta = reglas.datos_requeridos
	configurar_diseno(energia, enlace, instrumentos, companero)


## Fija lo que depende del diseño. Devuelve false (sin cambiar nada) si la energía o el enlace no existen.
func configurar_diseno(nueva_energia: String, nuevo_enlace: String, nuevos_instrumentos: Array[String], con_companero: bool) -> bool:
	if not ENERGIAS.has(nueva_energia) or not ENLACES.has(nuevo_enlace):
		return false
	energia = nueva_energia
	enlace = nuevo_enlace
	instrumentos = nuevos_instrumentos.duplicate()
	companero = con_companero
	ventanas_enlace = _balance.ventanas(ENLACES[nuevo_enlace])
	return true


func a_snapshot() -> Dictionary:
	return {
		"phase": fase,
		"paused": pausado,
		"safe_mode": modo_seguro,
		"safe_entries": entradas_modo_seguro,
		"sol": sol,
		"hour": hora,
		"is_night": es_noche,
		"rover_tile": casilla_rover,
		"station_tile": casilla_estacion,
		"battery": {"wh": bateria_wh, "capacity": bateria_capacidad_wh, "generation_w": generacion_w, "load_w": carga_w},
		"design": {"power": energia, "comms": enlace, "instruments": instrumentos.duplicate(), "companion": companero},
		"data": datos,
		"memory_capacity": memoria_capacidad,
		"sent": enviados,
		"goal": meta,
		"mineral": minerales,
		"antenna_level": nivel_antena,
		"dust": maxf(polvo, 1.0 if tormenta else 0.0),  ## nivel visual 0..1: la tormenta cuenta como polvo máximo
		"storm": tormenta,
		"storm_in": tormenta_en,
		"transmitting": transmitiendo,
		"link_open": enlace_abierto,
		"link_next": proximo_cambio_enlace.duplicate(),
		"comms_windows": ventanas_enlace.duplicate(true),
		"moving": en_movimiento,
		"busy": ocupado,
		"map_revision": revision_mapa,
		"targets": objetivos.duplicate(true),
		"obstacles": obstaculos.duplicate(),
	}
