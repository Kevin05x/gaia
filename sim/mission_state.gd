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
var limite_min: Vector2i = Vector2i(-11, -11)  ## últimas casillas válidas del mapa
var limite_max: Vector2i = Vector2i(11, 11)

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
var sol_limite: int = 0  ## último sol en el que aún se puede cumplir la meta
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
var movimiento_en_curso: Dictionary = {}  ## {"path", "seconds_per_tile", "elapsed"}; vacío si no se mueve
var ocupado: bool = false
var accion_en_curso: Dictionary = {}  ## {"action", "target_id", "seconds", "elapsed"}; vacío si no hay ninguna
var dron_sol: int = 0  ## sol del último vuelo de dron
var dron_usos: int = 0  ## vuelos de dron hechos en ese sol
var companero_sol: int = 0  ## sol de la última ayuda de Rocky
var companero_usos: int = 0  ## ayudas de Rocky hechas en ese sol

## Base y economía (content/economia.json); vacíos cuando la misión no usa economía.
var recursos: Dictionary = {}  ## rocas, olivino, hielo, xenolito
var recursos_vistos: Array = []  ## recursos ya conseguidos alguna vez
var edificios: Array[Dictionary] = []  ## ver BuildSystem
var siguiente_edificio: int = 1

## Historia (content/historia.json)
var etica: float = 50.0  ## 0..100: alta = simbiosis, baja = explotación
var rocky_hp: float = 100.0  ## vida de Rocky (el compañero) en %
var historia_nodo: String = ""  ## nodo que espera decisión ("" si ninguno): la misión se detiene
var historia_espera: String = ""  ## próximo nodo, que se mostrará cuando se cumpla un disparador
var historia_ultimo: String = ""  ## último nodo mostrado (da el objetivo actual)
var historia_registro: Array = []  ## [{"node", "choice"}] decisiones tomadas
var historia_final: String = ""  ## final elegido en el clímax
var historia_rama: String = ""
var historia_radio: String = ""  ## último nodo de radio (no detiene la misión)
var historia_radio_n: int = 0  ## contador de nodos de radio: la vista muestra la tarjeta cuando cambia
var historia_t_ultimo: float = -1000.0  ## hora de juego absoluta en que se resolvió el último nodo
var envio_max: float = -1.0  ## tope de datos enviados (con historia, hasta el clímax); -1 = sin tope

## Tutorial del Sol 1 (content/tutorial.json)
var tutorial_activo: bool = false
var tutorial_paso: int = 0  ## índice del paso que se muestra
var tutorial_t: float = 0.0  ## segundos reales que lleva el paso actual en pantalla
var tutorial_contadores: Dictionary = {}  ## evento -> veces que ha ocurrido desde que empezó el tutorial

## Combate (content/combate.json). Todo son datos simples para poder guardarlos.
var rover_hp: float = 100.0  ## vida del rover en %; a 0 la misión fracasa
var enemigos: Array[Dictionary] = []  ## {"id", "type", "wave", "pos": Vector2, "dest": Vector2i, "hp", "cd", "atk"}
var siguiente_enemigo: int = 1
var siguiente_disparo: int = 1  ## número de serie de cada efecto de «disparos» (la vista lo usa para sonar una sola vez)
var oleadas_hechas: Array = []  ## ids de oleadas y de lluvias de meteoritos que ya empezaron
var amenaza: float = 0.0  ## la actividad de la base (taladro, antena) despierta a la fauna: añade arañas a la siguiente oleada
var impactos: Array[Dictionary] = []  ## meteoritos en camino: {"tile", "t": segundos para caer, "dano", "radio"}
var meteoritos_en_curso: Array[Dictionary] = []  ## lluvias que aún sueltan meteoritos: {"id", "restan", "t", "separacion_s", "dano", "radio", "aviso_s", "sol"}
var disparos: Array[Dictionary] = []  ## efectos recientes para la vista: {"from": Vector2i, "to": Vector2, "ttl", "kind", "n"}

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
	sol_limite = reglas.sol_limite
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
		"bounds": {"min": limite_min, "max": limite_max},
		"battery": {"wh": bateria_wh, "capacity": bateria_capacidad_wh, "generation_w": generacion_w, "load_w": carga_w},
		"design": {"power": energia, "comms": enlace, "instruments": instrumentos.duplicate(), "companion": companero},
		"data": datos,
		"memory_capacity": memoria_capacidad,
		"sent": enviados,
		"goal": meta,
		"sol_limit": sol_limite,
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
		"rover_hp": rover_hp,
		"targets": objetivos.duplicate(true),
		"obstacles": obstaculos.duplicate(),
	}
