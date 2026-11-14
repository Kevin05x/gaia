extends Node
## Partida en red para 2 a 4 personas, cada una en su dispositivo y todas a la vez en la misma misión.
## Un solo anfitrión lleva la simulación (sim/), igual que en una partida normal; los jugadores le mandan órdenes y reciben lo
## que pasa. La vista no sabe si juega sola o en red: habla con su Port, y aquí se conecta ese Port con la red.
##
##   · Anfitrión (escritorio): crea la sala y también juega. Los demás entran con su dirección IP (misma red Wi-Fi).
##   · Servidor (godot --headless … -- --servidor): lleva la simulación sin jugar; los cuatro jugadores son clientes, también
##     desde el navegador (hace falta una dirección wss:// con certificado: Render, Fly, un túnel de Cloudflare…).
##   · Cliente: escritorio o navegador. Un navegador no puede abrir una sala, solo entrar en una.
## Todo viaja por WebSocket (un solo camino de código para las tres cosas). Qué puede hacer cada jugador lo decide el
## anfitrión según su rol (scenes/net/permisos.gd); lo que mande un cliente no se da por bueno.
const Sala := preload("res://scenes/net/sala.gd")
const Permisos := preload("res://scenes/net/permisos.gd")
const RedPort := preload("res://scenes/net/red_port.gd")
const MissionRunnerScript := preload("res://scenes/a/mission_runner.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")

const PROTOCOLO := 1  ## si dos versiones del juego no hablan igual, la sala rechaza al que no coincide
const PUERTO := 9080
const BUFFER := 4 * 1024 * 1024  ## un snapshot con enemigos y edificios pasa de los 64 KB por defecto
const PERIODO_SNAPSHOT_S := 0.1  ## máximo 10 snapshots por segundo a cada jugador (el movimiento va en rutas, no aquí)
const ESPERA_HOLA_S := 6.0
enum Modo { NINGUNO, ANFITRION, SERVIDOR, CLIENTE }

signal sala_cambiada
signal conectado  ## un cliente entró en la sala
signal conexion_fallida(motivo: String)  ## clave de texto
signal desconectado(motivo: String)  ## clave de texto
signal partida_empieza
signal evento(tipo: String, datos: Variant)  ## lo que el anfitrión manda a la vista: snapshot, path, action, ui, voto...

var modo := Modo.NINGUNO
var sala = Sala.new()
var mi_id := 0
var autoridad: Node = null  ## MissionRunner del anfitrión (solo existe en el anfitrión)
var _port: Node
var _listos: Dictionary = {}  ## ids de los jugadores cuya vista ya está montada
var _pendiente: Dictionary = {}
var _hay_pendiente := false
var _desde_envio := 0.0
var _votos: Dictionary = {}
var _nombre := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_al_conectar_par)
	multiplayer.peer_disconnected.connect(_al_desconectar_par)
	multiplayer.connected_to_server.connect(_al_conectar_servidor)
	multiplayer.connection_failed.connect(func() -> void: _caer("NET_ERR_CONNECT", true))
	multiplayer.server_disconnected.connect(func() -> void: _caer("NET_ERR_LOST", false))
	var args := OS.get_cmdline_user_args()
	if args.has("--servidor"):
		var puerto := PUERTO
		var entorno := OS.get_environment("PORT")  # Render, Fly y similares dicen aquí en qué puerto escuchar
		if entorno.is_valid_int():
			puerto = int(entorno)
		for a in args:
			if str(a).begins_with("--puerto="):
				puerto = int(str(a).get_slice("=", 1))
		var err := crear_sala("", puerto, false)
		print("GAIA servidor: puerto %d -> %s" % [puerto, error_string(err)])
		if err != OK:
			get_tree().quit(1)


func _process(delta: float) -> void:
	_desde_envio += delta
	if _hay_pendiente and _desde_envio >= PERIODO_SNAPSHOT_S:
		_enviar_snapshot_pendiente()


# ---------------------------------------------------------------------------------------------- estado

func activo() -> bool:
	return modo != Modo.NINGUNO


func es_autoridad() -> bool:
	return modo == Modo.ANFITRION or modo == Modo.SERVIDOR


func soy_jefe() -> bool:
	return sala.es_jefe(mi_id)


func mis_roles() -> Array:
	return sala.roles_de(mi_id)


## IPv4 de esta computadora en la red local (lo que los demás escriben para entrar).
static func direcciones_locales() -> PackedStringArray:
	var lista := PackedStringArray()
	for d in IP.get_local_addresses():
		var partes := str(d).split(".")
		if partes.size() != 4:
			continue
		var a := int(partes[0])
		var b := int(partes[1])
		if a == 10 or (a == 192 and b == 168) or (a == 172 and b >= 16 and b <= 31):
			lista.append(str(d))
	return lista


## «192.168.1.5», «192.168.1.5:9090» o «wss://mi-servidor.onrender.com» → la URL completa.
static func normalizar_direccion(texto: String) -> String:
	var d := texto.strip_edges()
	if d.is_empty():
		return ""
	if d.contains("://"):
		return d
	var host := d.get_slice(":", 0)
	var local := host == "localhost" or host.is_valid_ip_address()
	if local:
		return "ws://%s%s" % [d, "" if d.contains(":") else ":%d" % PUERTO]
	return "wss://" + d


# ----------------------------------------------------------------------------------------- crear y unirse

## Abre una sala. «como_jugador» false es el servidor dedicado (no juega).
func crear_sala(nombre: String, puerto: int = PUERTO, como_jugador: bool = true) -> Error:
	if OS.has_feature("web"):
		return ERR_UNAVAILABLE  # un navegador no puede escuchar conexiones
	salir()
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = BUFFER
	peer.outbound_buffer_size = BUFFER
	var err := peer.create_server(puerto)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	modo = Modo.ANFITRION if como_jugador else Modo.SERVIDOR
	sala = Sala.new()
	mi_id = 1
	_nombre = nombre
	if como_jugador:
		sala.anadir(1, nombre)
	sala_cambiada.emit()
	return OK


func unirse(direccion: String, nombre: String) -> Error:
	salir()
	var url := normalizar_direccion(direccion)
	if url.is_empty():
		return ERR_INVALID_PARAMETER
	var peer := WebSocketMultiplayerPeer.new()
	peer.inbound_buffer_size = BUFFER
	peer.outbound_buffer_size = BUFFER
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	modo = Modo.CLIENTE
	sala = Sala.new()
	_nombre = nombre
	return OK


## Cierra todo y deja la red como si no se hubiera usado.
func salir() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	_terminar_partida()
	modo = Modo.NINGUNO
	mi_id = 0
	sala = Sala.new()
	Sesion.en_red = false


func _caer(motivo: String, al_conectar: bool) -> void:
	var estaba_en_partida := Sesion.en_red
	salir()
	if al_conectar and not estaba_en_partida:
		conexion_fallida.emit(motivo)
	else:
		desconectado.emit(motivo)


func _al_conectar_par(id: int) -> void:
	if not es_autoridad():
		return
	# Quien se conecta y no se presenta en unos segundos no es nuestro cliente: se le echa.
	get_tree().create_timer(ESPERA_HOLA_S).timeout.connect(func() -> void:
		if es_autoridad() and not sala.orden.has(id) and multiplayer.get_peers().has(id):
			_expulsar(id))


func _al_conectar_servidor() -> void:
	mi_id = multiplayer.get_unique_id()
	_rpc_hola.rpc_id(1, _nombre, PROTOCOLO)


func _al_desconectar_par(id: int) -> void:
	if not es_autoridad():
		return
	_listos.erase(id)
	if not sala.orden.has(id):
		return
	sala.quitar(id)
	if sala.cuantos() == 0:  # el servidor dedicado se queda sin jugadores: vuelve a abrirse una sala nueva
		_terminar_partida()
		sala = Sala.new()
	_enviar_sala()


func _expulsar(id: int) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(id):
		multiplayer.multiplayer_peer.disconnect_peer(id)


func _rechazar(id: int, motivo: String) -> void:
	_rpc_rechazo.rpc_id(id, motivo)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: _expulsar(id))


# --------------------------------------------------------------------------------------------- la sala

func _enviar_sala() -> void:
	if multiplayer.multiplayer_peer != null:
		_rpc_sala.rpc(sala.a_dict())
	sala_cambiada.emit()


@rpc("any_peer", "reliable")
func _rpc_hola(nombre: String, protocolo: int) -> void:
	if not es_autoridad():
		return
	var id := multiplayer.get_remote_sender_id()
	if protocolo != PROTOCOLO:
		_rechazar(id, "NET_ERR_VERSION")
	elif sala.jugando:
		_rechazar(id, "NET_ERR_STARTED")
	elif not sala.anadir(id, nombre):
		_rechazar(id, "NET_ERR_FULL")
	else:
		_enviar_sala()


@rpc("authority", "reliable")
func _rpc_rechazo(motivo: String) -> void:
	_caer(motivo, true)


@rpc("authority", "reliable")
func _rpc_sala(datos: Dictionary) -> void:
	var primera: bool = mi_id != 0 and sala.numero(mi_id) == 0
	sala = Sala.desde_dict(datos)
	if primera and sala.numero(mi_id) > 0:
		conectado.emit()
	sala_cambiada.emit()


## Interfaz → anfitrión: el jefe cambia destino o dificultad.
func configurar(destino: String, dificultad: String) -> void:
	if es_autoridad():
		if sala.configurar(mi_id, destino, dificultad):
			_enviar_sala()
	else:
		_rpc_config.rpc_id(1, destino, dificultad)


@rpc("any_peer", "reliable")
func _rpc_config(destino: String, dificultad: String) -> void:
	if es_autoridad() and sala.configurar(multiplayer.get_remote_sender_id(), destino, dificultad):
		_enviar_sala()


# ------------------------------------------------------------------------------------- empezar la partida

func empezar() -> void:
	if es_autoridad():
		_empezar(mi_id)
	else:
		_rpc_empezar.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_empezar() -> void:
	if es_autoridad():
		_empezar(multiplayer.get_remote_sender_id())


func _empezar(id: int) -> void:
	var destino := str(sala.config.get("destino", "marte"))
	if Destino.config(destino).is_empty() or not sala.empezar(id):
		return
	Sesion.destino = destino
	Sesion.dificultad = str(sala.config.get("dificultad", "estandar"))
	Sesion.jugadores = sala.cuantos()
	Sesion.votos = []
	Sesion.cargar_al_iniciar = false
	Sesion.en_red = true
	_crear_autoridad()
	_enviar_sala()
	if multiplayer.multiplayer_peer != null:
		_rpc_partida.rpc(sala.a_dict())
	if modo == Modo.ANFITRION:
		_preparar_cliente(sala.a_dict())
		partida_empieza.emit()


@rpc("authority", "reliable")
func _rpc_partida(datos: Dictionary) -> void:
	sala = Sala.desde_dict(datos)
	_preparar_cliente(datos)
	partida_empieza.emit()


func _preparar_cliente(datos: Dictionary) -> void:
	var cfg: Dictionary = datos.get("config", {})
	Sesion.destino = str(cfg.get("destino", "marte"))
	Sesion.dificultad = str(cfg.get("dificultad", "estandar"))
	Sesion.jugadores = maxi(1, (datos.get("jugadores", []) as Array).size())
	Sesion.votos = []
	Sesion.cargar_al_iniciar = false
	Sesion.en_red = true


func _crear_autoridad() -> void:
	_terminar_partida()
	var runner: Node = MissionRunnerScript.new()
	runner.name = "Autoridad"
	runner.crear_vista = false
	runner.modo_red = true
	_port = RedPort.new()
	_port.name = "RedPort"
	runner.port = _port
	runner.add_child(_port)
	autoridad = runner
	add_child(runner)
	_votos.clear()
	_listos.clear()


func _terminar_partida() -> void:
	if autoridad != null and is_instance_valid(autoridad):
		autoridad.queue_free()
	autoridad = null
	_port = null
	_listos.clear()
	_votos.clear()
	_hay_pendiente = false


# ---------------------------------------------------------------------- del anfitrión a los jugadores

## La vista de un jugador ya está montada: desde ahora recibe lo que pasa, empezando por cómo está todo.
func avisar_listo() -> void:
	if es_autoridad():
		_cliente_listo(mi_id)
	else:
		_rpc_listo.rpc_id(1)


@rpc("any_peer", "reliable")
func _rpc_listo() -> void:
	if es_autoridad() and sala.orden.has(multiplayer.get_remote_sender_id()):
		_cliente_listo(multiplayer.get_remote_sender_id())


func _cliente_listo(id: int) -> void:
	if autoridad == null or _port == null:
		return
	_listos[id] = true
	var sim = autoridad.get("sim")
	if sim == null:
		return
	if not _port.snapshot.is_empty():
		enviar_a(id, "snapshot", _port.snapshot)
	if sim.estado.fase == "workshop" and not sim.intro_historia().is_empty():
		enviar_a(id, "ui", {"m": "intro", "a": [sim.intro_historia()]})


## A un jugador. El anfitrión que también juega recibe lo suyo directamente, sin pasar por la red.
func enviar_a(id: int, tipo: String, datos: Variant) -> void:
	if id == mi_id and modo == Modo.ANFITRION:
		evento.emit(tipo, datos)
	elif multiplayer.multiplayer_peer != null and multiplayer.get_peers().has(id):
		_rpc_evento.rpc_id(id, tipo, datos)


## A todos los jugadores que ya tienen la vista montada.
func repartir(tipo: String, datos: Variant) -> void:
	if tipo == "snapshot":
		return
	for id in _listos.keys():
		enviar_a(int(id), tipo, datos)


## Los snapshots se juntan: sale como mucho uno cada PERIODO_SNAPSHOT_S, siempre el más reciente.
func repartir_snapshot(datos: Dictionary) -> void:
	_pendiente = datos
	_hay_pendiente = true
	if _desde_envio >= PERIODO_SNAPSHOT_S:
		_enviar_snapshot_pendiente()


func _enviar_snapshot_pendiente() -> void:
	_hay_pendiente = false
	_desde_envio = 0.0
	for id in _listos.keys():
		enviar_a(int(id), "snapshot", _pendiente)


@rpc("authority", "reliable")
func _rpc_evento(tipo: String, datos: Variant) -> void:
	evento.emit(tipo, datos)


# ---------------------------------------------------------------------- de los jugadores al anfitrión

## La vista de este jugador da una orden. El anfitrión comprueba que le toca.
func enviar_orden(orden: String, carga: Dictionary = {}) -> void:
	if es_autoridad():
		_procesar_orden(mi_id, orden, carga)
	elif multiplayer.multiplayer_peer != null:
		_rpc_orden.rpc_id(1, orden, carga)


@rpc("any_peer", "reliable")
func _rpc_orden(orden: String, carga: Dictionary) -> void:
	if es_autoridad():
		_procesar_orden(multiplayer.get_remote_sender_id(), orden, carga)


func _procesar_orden(id: int, orden: String, carga: Dictionary) -> void:
	if autoridad == null or _port == null or not sala.jugando or not sala.orden.has(id):
		return
	var limpia = sanear(carga)
	if limpia == null:
		return
	var roles: Array = sala.roles_de(id)
	if orden.begins_with("net_"):
		_orden_de_equipo(id, roles, orden, limpia)
		return
	if not Permisos.permite(roles, orden):
		enviar_a(id, "reject", Permisos.RAZON)
		return
	_port.emisor = id
	_port.orden_actual = orden
	_port.command_requested.emit(orden, limpia)
	_port.emisor = 0
	_port.orden_actual = ""


## Revisión Go / No-Go entre dispositivos: Dirección la abre y la cierra; cada uno vota lo suyo.
func _orden_de_equipo(id: int, roles: Array, orden: String, carga: Dictionary) -> void:
	match orden:
		"net_review_open", "net_review_close":
			if not Permisos.permite(roles, "design_start"):
				enviar_a(id, "reject", Permisos.RAZON)
				return
			_votos.clear()
			repartir("revision", {"abrir": orden == "net_review_open"})
		"net_vote":
			var rol := str(carga.get("rol", ""))
			if not roles.has(rol):
				return
			if carga.has("go"):
				_votos[rol] = bool(carga["go"])
			else:
				_votos.erase(rol)
			_votos_a_sesion()
			repartir("voto", {"rol": rol, "go": _votos.get(rol, null)})


func _votos_a_sesion() -> void:
	var lista: Array = []
	for rol in _votos:
		lista.append({"rol": rol, "jugador": sala.numero(sala.quien_tiene(rol)), "go": bool(_votos[rol]), "ok": true})
	Sesion.votos = lista


## Deja pasar solo datos simples: un cliente que mande otra cosa no debe poder romper la simulación del anfitrión.
## Devuelve null si algo no es de fiar.
static func sanear(carga: Dictionary) -> Variant:
	if carga.size() > 8:
		return null
	var limpia := {}
	for clave in carga:
		if not (clave is String) or str(clave).length() > 32:
			return null
		var valor: Variant = carga[clave]
		match typeof(valor):
			TYPE_STRING:
				if str(valor).length() > 64:
					return null
			TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
				pass
			TYPE_VECTOR2I:
				var v: Vector2i = valor
				if absi(v.x) > 10000 or absi(v.y) > 10000:
					return null
			_:
				return null
		limpia[clave] = valor
	if limpia.has("tile") and typeof(limpia["tile"]) != TYPE_VECTOR2I:
		return null
	return limpia
