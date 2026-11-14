extends SceneTree
## Jugador automático para probar la red sin pantallas: entra en una sala, vota el Go/No-Go de su rol y da órdenes según
## su rol, y al final imprime «RES nombre clave=valor». Lo usa tools/probar_red.sh con un servidor y cuatro bots.
##   godot --headless --path . -s tools/bot_red.gd -- --dir=127.0.0.1:9191 --nombre=Ana --jefe --esperar=4
##   (con --anfitrion crea la sala y juega en vez de unirse a una)
const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro",
	"taladro", "radar", "dron", "meteo", "companero"]

var nombre := "bot"
var snaps := 0
var fase := ""
var ultimo: Dictionary = {}
var rutas := 0
var rechazos: Array[String] = []
var votos: Dictionary = {}
var report := false
var revision_abierta := false
var res := {}
var red: Node  ## el autoload Red (en un script de SceneTree no se puede nombrar directamente)


func _arg(clave: String, defecto: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--%s=" % clave):
			return str(a).get_slice("=", 1)
		if str(a) == "--%s" % clave:
			return "1"
	return defecto


func _initialize() -> void:
	nombre = _arg("nombre", "bot")
	red = root.get_node("Red")
	red.evento.connect(_al_evento)
	red.partida_empieza.connect(func() -> void: red.avisar_listo())
	red.conexion_fallida.connect(func(m: String) -> void:
		print("RES %s error=%s" % [nombre, m])
		quit(2))
	red.desconectado.connect(func(m: String) -> void:
		print("RES %s desconectado=%s" % [nombre, m])
		quit(3))
	_correr.call_deferred()


func _esperar(cond: Callable, limite_s: float) -> bool:
	var t := 0.0
	while not cond.call():
		await create_timer(0.05).timeout
		t += 0.05
		if t > limite_s:
			return false
	return true


func _al_evento(tipo: String, datos: Variant) -> void:
	match tipo:
		"snapshot":
			snaps += 1
			ultimo = datos
			fase = str(datos.get("phase", ""))
		"path":
			rutas += 1
		"reject":
			rechazos.append(str(datos))
		"report":
			report = true
		"revision":
			revision_abierta = bool(datos["abrir"])
			if revision_abierta:
				for rol in red.mis_roles():
					red.enviar_orden("net_vote", {"rol": rol, "go": true})
		"voto":
			votos[str(datos["rol"])] = datos["go"]


func _correr() -> void:
	await process_frame  # hasta entonces el autoload no está en el árbol y no tiene red
	var err: int
	if _arg("anfitrion") == "1":
		err = red.crear_sala(nombre, int(_arg("puerto", "9191")))  # el anfitrión también juega (partida en la misma red Wi-Fi)
	else:
		err = red.unirse(_arg("dir", "127.0.0.1:9191"), nombre)
	if err != OK:
		print("RES %s error=unirse:%s" % [nombre, error_string(err)])
		quit(2)
		return
	await _esperar(func() -> bool: return red.sala.numero(red.mi_id) > 0, 8.0)
	res["entro"] = red.sala.numero(red.mi_id) > 0
	if _arg("jefe") == "1":
		await _esperar(func() -> bool: return red.sala.cuantos() >= int(_arg("esperar", "2")), 15.0)
		red.configurar(_arg("destino", "marte"), "estandar")
		await create_timer(0.3).timeout
		red.empezar()
	if _arg("tarde") == "1":  # entra con la misión en marcha: solo comprueba que le llega el estado actual
		res["tarde_recibio"] = await _esperar(func() -> bool: return fase != "", 25.0)
		res["roles"] = ",".join(red.mis_roles())
		await _terminar()
		return
	var llego := await _esperar(func() -> bool: return fase == "workshop", 25.0)
	res["taller"] = llego
	res["roles"] = ",".join(red.mis_roles())
	if not llego:
		await _terminar()
		return
	await create_timer(0.5).timeout
	if red.mis_roles().has("direccion"):
		for id in DISENO:
			red.enviar_orden("design_add", {"part_id": id})
		await create_timer(0.8).timeout
		red.enviar_orden("design_validate", {})
		await create_timer(0.4).timeout
		red.enviar_orden("net_review_open", {})
		var todos := await _esperar(func() -> bool: return votos.size() >= 4, 10.0)
		res["votos"] = votos.size()
		if todos:
			red.enviar_orden("design_start", {})
	res["aterrizaje"] = await _esperar(func() -> bool: return fase == "landing", 15.0)
	red.enviar_orden("landing_finished", {})  # todos lo mandan: el primero gana y a los demás no se les avisa
	res["operaciones"] = await _esperar(func() -> bool: return fase == "operations", 15.0)
	await create_timer(0.5).timeout
	await _probar_rol()
	await create_timer(2.0).timeout
	await _terminar()


func _probar_rol() -> void:
	var roles: Array = red.mis_roles()
	var casilla: Vector2i = ultimo.get("rover_tile", Vector2i.ZERO)
	if roles.has("direccion"):
		red.enviar_orden("move", {"tile": casilla + Vector2i(2, 0)})
		res["mover_ok"] = await _esperar(func() -> bool: return rutas > 0, 5.0)
	elif roles.has("ciencia"):
		red.enviar_orden("move", {"tile": casilla + Vector2i(2, 0)})
		res["mover_negado"] = await _esperar(func() -> bool: return rechazos.has("NET_NOT_YOUR_ROLE"), 5.0)
	elif roles.has("ingenieria"):
		red.enviar_orden("transmit", {"on": true})
		res["transmitir_negado"] = await _esperar(func() -> bool: return rechazos.has("NET_NOT_YOUR_ROLE"), 5.0)
	elif roles.has("comunicaciones"):
		red.enviar_orden("transmit", {"on": true})
		await create_timer(1.5).timeout
		res["transmitir_ok"] = not rechazos.has("NET_NOT_YOUR_ROLE")
	# Todos ven el movimiento del rover que dio Dirección.
	await create_timer(1.0).timeout
	res["vio_ruta"] = rutas > 0


func _terminar() -> void:
	res["snapshots"] = snaps
	res["fase"] = fase
	res["rechazos"] = ",".join(rechazos)
	var partes: Array[String] = []
	for k in res:
		partes.append("%s=%s" % [k, str(res[k])])
	print("RES %s %s" % [nombre, " ".join(partes)])
	await create_timer(float(_arg("demora", "0"))).timeout  # el anfitrión se queda un rato para que los demás terminen
	red.salir()
	quit(0)
