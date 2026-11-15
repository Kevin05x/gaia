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
const RUTA_ECONOMIA := "res://content/economia.json"
const RUTA_HISTORIA := "res://content/historia.json"
const RUTA_COMBATE := "res://content/combate.json"
const RUTA_TUTORIAL := "res://content/tutorial.json"
const RUTA_HITOS := "res://content/hitos.json"
const RUTA_IMPREVISTOS := "res://content/imprevistos.json"
const ImprevistoPanel := preload("res://scenes/b/imprevisto_panel.gd")
const ESCENA_VISTA := "res://scenes/b/mission.tscn"
const Sesion := preload("res://scenes/menu/game_session.gd")
const Musica := preload("res://scenes/menu/musica.gd")

## Segundos entre snapshots cuando no pasa nada que los obligue a salir antes (batería, hora...).
const PERIODO_SNAPSHOT_S := 0.15
## Con monstruos o meteoritos se publica a 30 por segundo (la vista suaviza el movimiento entre uno y otro):
## antes era cada cuadro, y en la web armar y copiar el snapshot 60 veces por segundo se notaba.
const PERIODO_COMBATE_S := 1.0 / 30.0
## Un cuadro muy largo (pestaña oculta, tirón) no adelanta la misión más que esto.
const DELTA_MAXIMO_S := 0.25

## Diseño con el que se juega mientras no exista la pantalla del taller.
const DISENO_INICIAL: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

@export var crear_vista: bool = true  ## false en las pruebas: se usa el "port" que se le asigne
@export var saltar_taller: bool = false  ## true: empieza directo con DISENO_INICIAL, sin pasar por el taller (pruebas y atajos)
## true: este es el anfitrión de una partida en red (scenes/net/red.gd). Lleva la simulación sin dibujar nada: las órdenes
## llegan de los jugadores por el "port" que se le asigne (RedPort) y lo que pasa se reparte a todos. No guarda partida.
var modo_red: bool = false
var _aviso_datos := false  ## ya se explicó cómo se envían los datos a la Tierra

var sim: Simulation
var port: Node
var view: Node
var errores: PackedStringArray = PackedStringArray()

var _desde_ultimo_snapshot: float = 0.0
var _desde_ultimo_guardado: float = 0.0
const PERIODO_AUTOGUARDADO_S := 30.0  ## autoguardado ligero durante las operaciones (además del de cada sol)


func _ready() -> void:
	var Medidor := preload("res://scenes/a/medidor.gd")
	if crear_vista and Medidor.pedido():
		saltar_taller = Medidor.escena() != "plataforma"  # la misión con el diseño inicial; la plataforma, en el taller
		Sesion.cargar_al_iniciar = false
		add_child(Medidor.new())
	_crear_simulacion()
	if not errores.is_empty():
		for error in errores:
			push_error("GAIA datos: %s" % error)
		set_process(false)
		return
	if crear_vista and view == null:
		view = load(ESCENA_VISTA).instantiate()
		add_child(view)
		Destino.aplicar_textos()
		view.menu_requested.connect(func() -> void:
			guardar_partida()  # «Salir al menú» guarda: «Continuar» vuelve con todo lo juntado
			Sesion.volver_al_menu(get_tree()))
		Musica.reproducir(get_tree(), "juego", 4.0)
		if not Sesion.cargar_al_iniciar and not saltar_taller and view.get("story") != null and not sim.intro_historia().is_empty():
			view.story.show_intro(sim.intro_historia())
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
	for evento in eventos:
		if evento == MovementSystem.EVENTO_MOVIMIENTO_CANCELADO or evento == Simulation.EVENTO_ACCION_CANCELADA \
				or evento == Simulation.EVENTO_MISION_TERMINADA:
			port.cancel_presentation()
		elif evento.begins_with(ScienceSystem.EVENTO_ACCION_TERMINADA):
			_aviso("ACTION_DONE")
		elif evento == ClockSystem.EVENTO_SOL_NUEVO and crear_vista:
			guardar_partida()  # autoguardado al inicio de cada sol
		elif evento.begins_with(BuildSystem.EVENTO_NIVEL_ANTENA):
			_aviso("ANTENNA_UP")
		elif evento.begins_with(BuildSystem.EVENTO_OBRA_TERMINADA):
			_aviso("BUILD_DONE")
		elif evento.begins_with(CombatSystem.EVENTO_OLEADA + ":"):
			_aviso("NOTICE_WAVE")
		elif evento.begins_with(CombatSystem.EVENTO_OLEADA_DERROTADA):
			_aviso("NOTICE_WAVE_CLEARED")
		elif evento.begins_with(BuildSystem.EVENTO_EDIFICIO_DESTRUIDO):
			_aviso("NOTICE_BUILDING_LOST")
		elif evento.begins_with(BuildSystem.EVENTO_MODULO_PERDIDO):
			_aviso("NOTICE_MODULE_LOST")
		elif evento.begins_with(BuildSystem.EVENTO_ANTENA_DANADA):
			_aviso("NOTICE_ANTENNA_HIT")
		elif evento.begins_with(CombatSystem.EVENTO_METEORITOS):
			_aviso("NOTICE_METEORS")
		elif evento.begins_with(ScienceSystem.EVENTO_ACCION_TERMINADA + ":") and not _aviso_datos and sim.estado.datos > 0.0:
			_aviso_datos = true
			_aviso("DATA_FIRST")
		elif evento == ResourceSystem.EVENTO_PRIMERA_CARGA:
			_aviso("CARGO_FIRST")
		elif evento.begins_with(Simulation.EVENTO_DESCARGA + ":"):
			_aviso_descarga(int(evento.get_slice(":", 1)))
		elif evento.begins_with(Simulation.EVENTO_ROVER_AUTOMATICO + ":"):
			var ruta := sim.ruta_en_curso()
			if not ruta.is_empty():
				port.present_path(ruta["path"], ruta["seconds_per_tile"])
			_aviso("BUILD_ROVER_BACK" if evento.ends_with(":vuelta") else "BUILD_ROVER_GOING")
		elif evento.begins_with(Simulation.EVENTO_OBRA_SIN_ROVER + ":"):
			_aviso_obra_sin_rover(evento.get_slice(":", 1))
		elif evento.begins_with(HitosSystem.EVENTO_HITO + ":"):
			_ui("hito", [evento.get_slice(":", 1)])
	if eventos.has(Simulation.EVENTO_MISION_TERMINADA):
		if crear_vista:
			Sesion.borrar()  # misión terminada: ya no hay partida que continuar
		_publicar()
		var informe := sim.informe.duplicate(true)
		informe["difficulty"] = Sesion.dificultad
		informe["destination"] = Destino.id
		informe["events"] = sim.estado.imprevistos_hechos.duplicate(true)
		informe["team"] = {"players": Sesion.jugadores, "votes": Sesion.votos.duplicate(true)}
		port.present_report(informe)
		return
	_desde_ultimo_snapshot += delta
	if crear_vista:
		_desde_ultimo_guardado += delta
		if _desde_ultimo_guardado >= PERIODO_AUTOGUARDADO_S:
			guardar_partida()
	if not eventos.is_empty() or _desde_ultimo_snapshot >= PERIODO_SNAPSHOT_S \
			or (_desde_ultimo_snapshot >= PERIODO_COMBATE_S and sim.hay_combate_activo()):
		_publicar()


## Guarda la partida si está en operaciones (en el taller, el aterrizaje o el informe no hay nada que continuar).
func guardar_partida() -> bool:
	_desde_ultimo_guardado = 0.0
	if sim == null or sim.estado.fase != "operations":
		return false
	return Sesion.guardar(sim)


func _notification(que: int) -> void:
	# Cerrar la ventana o la pestaña, o dejarla en segundo plano, guarda antes: no se pierde lo juntado.
	if crear_vista and (que == NOTIFICATION_WM_CLOSE_REQUEST or que == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or que == NOTIFICATION_APPLICATION_PAUSED):
		guardar_partida()


func _crear_simulacion() -> void:
	if crear_vista and Sesion.cargar_al_iniciar:
		Sesion.restaurar_configuracion()
	# Destino (Marte o Luna): cada uno trae sus propios datos (content/destinos.json). Sin vista (pruebas) es Marte.
	var destino := Sesion.destino if (crear_vista or modo_red) else "marte"
	var cfg := Destino.config(destino)
	if cfg.is_empty():
		destino = "marte"
		cfg = Destino.config("marte")
	aplicar_destino(destino)
	var balance := Balance.desde_archivo(str(cfg.get("balance", RUTA_BALANCE)))
	var reglas := Rules.desde_archivo(str(cfg.get("reglas", RUTA_REGLAS)))
	var mapa := MapData.desde_archivo(str(cfg.get("mapa", RUTA_MAPA)))
	var catalogo := Catalog.desde_archivo(RUTA_PIEZAS)
	adaptar_catalogo(catalogo, destino, float(cfg.get("factor_capacidad_cohete", 1.0)))
	var economia := Economy.desde_archivo(str(cfg.get("economia", RUTA_ECONOMIA)))
	var ruta_historia := str(cfg.get("historia", RUTA_HISTORIA))
	var ruta_combate := str(cfg.get("combate", RUTA_COMBATE))
	var historia: StoryData = StoryData.desde_archivo(ruta_historia) if not ruta_historia.is_empty() else null
	var combate: CombatData = CombatData.desde_archivo(ruta_combate) if not ruta_combate.is_empty() else null
	var tutorial := TutorialData.desde_archivo(str(cfg.get("tutorial", RUTA_TUTORIAL)))
	var hitos := HitosData.desde_archivo(str(cfg.get("hitos", RUTA_HITOS)))
	for lista in [balance.errores, reglas.errores, mapa.errores, catalogo.errores, economia.errores, tutorial.errores, hitos.errores]:
		errores.append_array(lista)
	for opcional in [historia, combate]:
		if opcional != null:
			errores.append_array(opcional.errores)
	aplicar_dificultad(reglas, combate, Sesion.dificultad)
	if errores.is_empty():
		# En red no hay tutorial: bloquea órdenes y detiene el reloj de todo el equipo, y cada jugador lleva su rover.
		sim = Simulation.new(balance, reglas, mapa, catalogo, economia, historia, combate, null if modo_red else tutorial, hitos)
		if (crear_vista or modo_red) and not preload("res://scenes/a/medidor.gd").pedido():  # pruebas y medición: el sol de balance.json
			sim.fijar_duracion_sol(Sesion.duracion_sol_min * 60.0)
		var imprevistos := ImprevistosSystem.desde_archivo(RUTA_IMPREVISTOS, destino)
		if (crear_vista or modo_red) and imprevistos.errores.is_empty() and not saltar_taller:  # pruebas y medición: sin sorpresas
			sim.usar_imprevistos(imprevistos, int(Time.get_unix_time_from_system()) % 100000)


## Fija el destino en curso. Lo usan el anfitrión (aquí) y la vista de cada jugador en red (scenes/net/cliente_juego.gd).
static func aplicar_destino(destino: String) -> void:
	if Destino.id != destino:
		var arte := preload("res://scenes/b/world_art.gd")
		arte._meshes.clear()  # las mallas y la textura de contacto guardadas llevan la paleta del otro destino
		arte._contact_texture = null
	Destino.id = destino


## Deja en el catálogo solo las trayectorias del destino y ajusta lo que lleva cada cohete hasta allí.
static func adaptar_catalogo(catalogo: Catalog, destino: String, factor_cohete: float) -> void:
	for id in catalogo.ids_de("trayectoria"):
		if str(catalogo.piezas[id].get("destino", "marte")) != destino:
			catalogo.piezas.erase(id)
	if not is_equal_approx(factor_cohete, 1.0):
		for id in catalogo.ids_de("cohetes"):
			catalogo.piezas[id]["capacidad_kg"] = float(catalogo.piezas[id]["capacidad_kg"]) * factor_cohete


## Dificultad: cambia el presupuesto y cuántos monstruos trae cada oleada (content/rules.json › dificultades).
static func aplicar_dificultad(reglas: Rules, combate: CombatData, id: String) -> void:
	var nivel := Sesion.datos_dificultad(id)
	if nivel.is_empty():
		return
	reglas.presupuesto_musd = float(nivel.get("presupuesto_musd", reglas.presupuesto_musd))
	var factor := float(nivel.get("factor_enemigos", 1.0))
	if combate != null and not is_equal_approx(factor, 1.0):
		for oleada in combate.oleadas:
			for grupo in oleada["grupos"]:
				grupo["cantidad"] = maxi(1, roundi(int(grupo["cantidad"]) * factor))


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
	elif saltar_taller:
		sim.ejecutar("tutorial_skip")  # las pruebas operan directo: el tutorial bloquearía órdenes y detendría el reloj


func _al_recibir_orden(orden: String, carga: Dictionary) -> void:
	var resultado := sim.ejecutar(orden, carga)
	if not resultado["ok"]:
		port.reject(resultado["reason"])
		return
	match orden:
		"unload":
			if not resultado["path"].is_empty():
				port.present_path(resultado["path"], resultado["seconds_per_tile"])
				_aviso("CARGO_GOING")
			for evento in resultado.get("events", []):
				if str(evento).begins_with(Simulation.EVENTO_DESCARGA + ":"):
					_aviso_descarga(int(str(evento).get_slice(":", 1)))
		"move", "approach", "stop":
			# Con «stop» o una orden nueva en plena marcha, el camino empieza por el tramo que el rover está terminando.
			if not resultado["path"].is_empty():
				port.present_path(resultado["path"], resultado["seconds_per_tile"])
			elif orden == "stop":
				port.cancel_presentation()
			if orden == "stop":
				_aviso("MOVE_STOPPED")
		"act":
			port.present_action(resultado["action"])
		"event_choice":
			# Lo que cambió la decisión se cuenta en un aviso; con desvío, el rover sale hacia el punto marcado.
			if not Array(resultado.get("path", [])).is_empty():
				port.present_path(resultado["path"], resultado["seconds_per_tile"])
			_ui("aviso_imprevisto", [resultado.get("applied", {})])
		"upgrade", "build", "build_module":
			_ui("ping")
			# Obra con rover: el rover sale hacia la obra (o irá en cuanto acabe lo que hace).
			if not Array(resultado.get("path", [])).is_empty():
				port.present_path(resultado["path"], resultado["seconds_per_tile"])
				_aviso("BUILD_ROVER_GOING")
			elif resultado.has("rover_reason") and not str(resultado["rover_reason"]) in ["BUSY", "MOVING", "PAUSED"]:
				_aviso_obra_sin_rover(str(resultado["rover_reason"]))
		"decide":
			_ui("ping")
		"landing_finished":
			_aviso("READY")
			if crear_vista:
				guardar_partida()  # primer punto de guardado: recién aterrizado
		"redesign":
			port.cancel_presentation()
			_ui("reiniciar")
			if saltar_taller:
				_empezar_con_diseno_inicial(false)
	_publicar()


func _publicar() -> void:
	_desde_ultimo_snapshot = 0.0
	port.apply_snapshot(sim.snapshot())


func _aviso_descarga(unidades: int) -> void:
	_ui("aviso_descarga", [unidades])


func _aviso_obra_sin_rover(motivo: String) -> void:
	_ui("aviso_obra_sin_rover", [motivo])


func _aviso(clave: String) -> void:
	_ui("aviso", [clave])


## Lo que la simulación le pide a la pantalla (avisos, hitos, sonido). Con vista propia se hace aquí mismo; en una partida
## en red el anfitrión no dibuja nada y se lo manda a cada jugador (RedPort.ui), cuya vista lo ejecuta con ui_en_vista.
func _ui(metodo: String, args: Array = []) -> void:
	if view != null:
		ui_en_vista(view, metodo, args)
	elif port != null and port.has_method("ui"):
		port.ui(metodo, args)


static func ui_en_vista(vista: Node, metodo: String, args: Array) -> void:
	if vista == null or not is_instance_valid(vista):
		return
	match metodo:
		"aviso":
			vista.hud.show_notice(str(args[0]))
		"aviso_obra_sin_rover":
			vista.hud.show_notice(TranslationServer.translate("BUILD_ROVER_BLOCKED") % TranslationServer.translate(str(args[0])))
		"aviso_descarga":
			vista.hud.show_notice(TranslationServer.translate("CARGO_UNLOADED") % int(args[0]))
			vista.al_descargar()
		"aviso_imprevisto":
			var aplicado: Dictionary = args[0]
			vista.hud.show_notice("UNEXP_RESULT", [ImprevistoPanel.resumen(aplicado)], 8.0)
			if aplicado.has("detour_tile"):
				vista.terrain.marcar_hallazgo(aplicado["detour_tile"])
		"hito":
			vista.celebrar_hito(str(args[0]))
		"ping":
			vista.audio.ping()
		"reiniciar":
			reiniciar_vista(vista)
		"intro":
			if vista.get("story") != null:
				vista.story.show_intro(args[0])


## Deja la vista como recién creada (lo mismo que hace el host de revisión de B al reiniciar).
func _reiniciar_vista() -> void:
	if view == null:
		return
	reiniciar_vista(view)


static func reiniciar_vista(view: Node) -> void:
	view.actors.cancel_actions()
	view.actors.landed = false
	view.actors.landing_active = false
	view.report_view.clear()
	view.hud.visible = true
	view.selected_target = ""
	view.hud.set_target("")
