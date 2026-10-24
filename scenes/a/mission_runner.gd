class_name MissionRunner
extends Node
## Mueve la simulación cuadro a cuadro y la conecta con la vista de B a través de su Port.
## Carga los datos de content/, crea la Simulation, traduce las órdenes de la vista a Simulation.ejecutar()
## y devuelve lo que la vista debe presentar (rutas, acciones, rechazos, snapshot e informe).
## Contrato: scenes/b/docs/INTEGRACION_A.md.

const RUTA_BALANCE := "res://content/balance.json"
const RUTA_REGLAS := "res://content/rules.json"
const RUTA_MAPA := "res://content/mapa.json"
const RUTA_PIEZAS := "res://content/parts.json"
const ESCENA_VISTA := "res://scenes/b/mission.tscn"
const Sesion := preload("res://scenes/menu/game_session.gd")
const Musica := preload("res://scenes/menu/musica.gd")

## Segundos entre snapshots cuando no pasa nada que los obligue a salir antes (batería, hora...).
const PERIODO_SNAPSHOT_S := 0.15
## Un cuadro muy largo (pestaña oculta, tirón) no adelanta la misión más que esto.
const DELTA_MAXIMO_S := 0.25

## Diseño con el que se juega mientras no exista la pantalla del taller.
const DISENO_INICIAL: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

@export var crear_vista: bool = true  ## false en las pruebas: se usa el "port" que se le asigne
@export var saltar_taller: bool = false  ## true: empieza directo con DISENO_INICIAL, sin pasar por el taller (pruebas y atajos)

var sim: Simulation
var port: Node
var view: Node
var errores: PackedStringArray = PackedStringArray()

var _desde_ultimo_snapshot: float = 0.0


func _ready() -> void:
	_crear_simulacion()
	if not errores.is_empty():
		for error in errores:
			push_error("GAIA datos: %s" % error)
		set_process(false)
		return
	if crear_vista and view == null:
		view = load(ESCENA_VISTA).instantiate()
		add_child(view)
		view.menu_requested.connect(func() -> void: Sesion.volver_al_menu(get_tree()))
		Musica.reproducir(get_tree(), "juego", 4.0)
	if port == null and view != null:
		port = view.get_node("Port")
	if port == null:
		push_error("GAIA: no hay Port al que conectar la simulación")
		set_process(false)
		return
	port.connected_backend = true
	port.command_requested.connect(_al_recibir_orden)
	if saltar_taller:
		_empezar_con_diseno_inicial()
	if Sesion.cargar_al_iniciar:
		Sesion.cargar_al_iniciar = false
		if not sim.cargar(Sesion.leer()):
			push_warning("GAIA: la partida guardada no se pudo cargar; se empieza una nueva")
	_publicar()


func _process(delta: float) -> void:
	var eventos := sim.avanzar(minf(delta, DELTA_MAXIMO_S))
	var ya_publicado := false
	for evento in eventos:
		if evento == MovementSystem.EVENTO_MOVIMIENTO_CANCELADO or evento == Simulation.EVENTO_ACCION_CANCELADA \
				or evento == Simulation.EVENTO_MISION_TERMINADA:
			port.cancel_presentation()
		elif evento.begins_with(ScienceSystem.EVENTO_ACCION_TERMINADA):
			_aviso("ACTION_DONE")
		elif evento == ClockSystem.EVENTO_SOL_NUEVO and crear_vista:
			Sesion.guardar(sim)  # autoguardado al inicio de cada sol
	if eventos.has(Simulation.EVENTO_MISION_TERMINADA):
		_publicar()
		port.present_report(sim.informe.duplicate(true))
		return
	_desde_ultimo_snapshot += delta
	if not eventos.is_empty() or _desde_ultimo_snapshot >= PERIODO_SNAPSHOT_S:
		_publicar()


func _crear_simulacion() -> void:
	var balance := Balance.desde_archivo(RUTA_BALANCE)
	var reglas := Rules.desde_archivo(RUTA_REGLAS)
	var mapa := MapData.desde_archivo(RUTA_MAPA)
	var catalogo := Catalog.desde_archivo(RUTA_PIEZAS)
	for lista in [balance.errores, reglas.errores, mapa.errores, catalogo.errores]:
		errores.append_array(lista)
	if errores.is_empty():
		sim = Simulation.new(balance, reglas, mapa, catalogo)


## "agregar_piezas" es false al rediseñar: el taller conserva las piezas ya elegidas.
func _empezar_con_diseno_inicial(agregar_piezas: bool = true) -> void:
	if agregar_piezas:
		for id in DISENO_INICIAL:
			var resultado := sim.ejecutar("design_add", {"part_id": id})
			if not resultado["ok"]:
				push_error("GAIA: no se pudo agregar %s al diseño inicial (%s)" % [id, resultado["reason"]])
	var inicio := sim.ejecutar("design_start")
	if not inicio["ok"]:
		push_error("GAIA: el diseño inicial no es válido (%s)" % inicio["reason"])


func _al_recibir_orden(orden: String, carga: Dictionary) -> void:
	var resultado := sim.ejecutar(orden, carga)
	if not resultado["ok"]:
		port.reject(resultado["reason"])
		return
	match orden:
		"move", "approach":
			if not resultado["path"].is_empty():
				port.present_path(resultado["path"], resultado["seconds_per_tile"])
		"act":
			port.present_action(resultado["action"])
		"upgrade":
			if view != null:
				view.audio.ping()
		"landing_finished":
			_aviso("READY")
			if crear_vista:
				Sesion.guardar(sim)  # primer punto de guardado: recién aterrizado
		"redesign":
			port.cancel_presentation()
			_reiniciar_vista()
			if saltar_taller:
				_empezar_con_diseno_inicial(false)
	_publicar()


func _publicar() -> void:
	_desde_ultimo_snapshot = 0.0
	port.apply_snapshot(sim.snapshot())


func _aviso(clave: String) -> void:
	if view != null:
		view.hud.show_notice(clave)


## Deja la vista como recién creada (lo mismo que hace el host de revisión de B al reiniciar).
func _reiniciar_vista() -> void:
	if view == null:
		return
	view.actors.cancel_actions()
	view.actors.landed = false
	view.actors.landing_active = false
	view.report_view.clear()
	view.hud.visible = true
	view.selected_target = ""
	view.hud.set_target("")
