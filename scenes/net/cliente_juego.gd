extends Node
## La partida vista desde un dispositivo en una partida en red: monta la misma vista de siempre (scenes/b/mission.tscn) y
## la conecta con el anfitrión a través de Red en vez de con un MissionRunner. Las órdenes del jugador salen hacia el
## anfitrión y lo que pasa (snapshots, rutas, avisos, votos) entra por Red.evento y se le entrega al Port de la vista.
## Igual que MissionRunner en una partida normal, esta escena tiene una propiedad «view» (la pantalla de carga la espera).
const Sesion := preload("res://scenes/menu/game_session.gd")
const Musica := preload("res://scenes/menu/musica.gd")
const Permisos := preload("res://scenes/net/permisos.gd")
const GoNoGo := preload("res://scenes/b/go_no_go.gd")
const RolTaller := preload("res://scenes/net/rol_taller.gd")

var view: Node
var port: Node
var _revision: Control
var _rol_taller: Control
var _cayendo := false


func _ready() -> void:
	MissionRunner.aplicar_destino(Sesion.destino)
	view = load("res://scenes/b/mission.tscn").instantiate()
	add_child(view)
	Destino.aplicar_textos()
	port = view.get_node("Port")
	port.connected_backend = true
	port.command_requested.connect(Red.enviar_orden)
	view.menu_requested.connect(_salir)
	Musica.reproducir(get_tree(), "juego", 4.0)
	Red.evento.connect(_al_evento)
	Red.desconectado.connect(_al_caer)
	# También con una sola persona: la guía le explica que tiene los cuatro roles.
	_rol_taller = RolTaller.new()
	_rol_taller.taller_vista = view.workshop
	view.workshop.root.add_child(_rol_taller)
	Red.sala_cambiada.connect(_al_cambiar_sala)
	Red.avisar_listo()


## Entró o salió alguien: los roles se repartieron de nuevo.
func _al_cambiar_sala() -> void:
	if is_instance_valid(_rol_taller):
		_rol_taller.actualizar(port.snapshot.get("workshop", {}))


func _exit_tree() -> void:
	if Red.sala_cambiada.is_connected(_al_cambiar_sala):
		Red.sala_cambiada.disconnect(_al_cambiar_sala)
	if Red.evento.is_connected(_al_evento):
		Red.evento.disconnect(_al_evento)
	if Red.desconectado.is_connected(_al_caer):
		Red.desconectado.disconnect(_al_caer)


func _al_evento(tipo: String, datos: Variant) -> void:
	match tipo:
		"snapshot":
			port.apply_snapshot(datos)
			if is_instance_valid(_rol_taller):
				_rol_taller.actualizar(port.snapshot.get("workshop", {}))
			# El diseño dejó de estar abierto (despegó o se rediseñó): la revisión ya no tiene sentido.
			if str(datos.get("phase", datos.get("fase", "workshop"))) != "workshop":
				_cerrar_revision()
		"path":
			port.present_path(datos["tiles"], float(datos["spt"]))
		"action":
			port.present_action(datos)
		"cancel":
			port.cancel_presentation()
		"reject":
			port.reject(str(datos))
		"report":
			port.present_report(datos)
		"ui":
			MissionRunner.ui_en_vista(view, str(datos["m"]), datos["a"])
		"revision":
			if bool(datos["abrir"]):
				_abrir_revision()
			else:
				_cerrar_revision()
		"voto":
			if is_instance_valid(_revision):
				_revision.aplicar_voto_remoto(str(datos["rol"]), datos["go"])


## «Go / No-Go» entre dispositivos: cada persona vota los roles que le tocan y lanza quien lleva Dirección.
func _abrir_revision() -> void:
	_cerrar_revision()
	var roles := Red.mis_roles()
	_revision = GoNoGo.new()
	_revision.taller = port.snapshot.get("workshop", {})
	_revision.jugadores = Sesion.jugadores
	_revision.roles_propios = roles
	_revision.es_lider = Permisos.permite(roles, "design_start")
	view.workshop.root.add_child(_revision)
	_revision.build()
	_revision.voto_cambiado.connect(func(rol: String, valor: Variant) -> void:
		port.submit("net_vote", {"rol": rol} if valor == null else {"rol": rol, "go": valor}))
	_revision.launch_confirmed.connect(func() -> void:
		_cerrar_revision()
		port.submit("design_start", {}))
	_revision.cancelled.connect(func() -> void: port.submit("net_review_close", {}))


func _cerrar_revision() -> void:
	if is_instance_valid(_revision):
		_revision.queue_free()
	_revision = null


func _al_caer(motivo: String) -> void:
	if _cayendo:
		return
	_cayendo = true
	# El anfitrión se fue o se cortó la conexión: se dice y se vuelve al menú.
	if is_instance_valid(view) and view.get("hud") != null:
		view.hud.show_notice(motivo)
	get_tree().create_timer(2.5).timeout.connect(func() -> void: Sesion.volver_al_menu(get_tree()))


func _salir() -> void:
	_cayendo = true
	Red.salir()
	Sesion.volver_al_menu(get_tree())
