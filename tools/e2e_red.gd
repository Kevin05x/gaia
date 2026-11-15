extends Node
## Prueba de extremo a extremo del multijugador (desarrollo): un cliente de verdad contra un servidor de verdad.
## Uso: godot --headless --path . res://tools/e2e_red.tscn -- --dir=ws://127.0.0.1:9099 --nombre=Ana [--jefe] [--n=2] [--dx=3 --dy=0]
##        [--tarde] [--esperar=3]
##   --n=K       cuántos jugadores empiezan la partida (el jefe espera a que estén todos)
##   --tarde     entra con la misión ya en marcha (no diseña ni lanza)
##   --esperar=K tras mover su rover, espera a ver K rovers (para ver llegar a quien entra tarde)
## Imprime líneas «E2E …»; termina con «E2E_OK» (código 0) o «E2E_FALLO …» (código 1). Lo lanza tools/e2e_red.sh.
const Permisos := preload("res://scenes/net/permisos.gd")
const PIEZAS := {"cohetes": "cohete_medio", "trayectoria": "trayectoria_directa_luna", "chasis": "chasis_base", "energia": "mmrtg",
	"comunicaciones": "antena_rele"}
const EXTRAS: Array[String] = ["camara", "espectrometro", "taladro"]

var _snap: Dictionary = {}
var _rechazos: Array[String] = []
var _empezo := false
var _args: Dictionary = {}
var _vistos: Dictionary = {}  ## id del otro -> última casilla vista (si el otro se va, el servidor quita su rover)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := str(a)
		if s.begins_with("--"):
			_args[s.get_slice("=", 0).trim_prefix("--")] = s.get_slice("=", 1) if s.contains("=") else "1"
	Red.evento.connect(_al_evento)
	Red.partida_empieza.connect(func() -> void:
		_empezo = true
		Red.avisar_listo())
	_correr.call_deferred()


func _al_evento(tipo: String, datos: Variant) -> void:
	if tipo == "snapshot":
		_snap = datos
		for r in _snap.get("rovers", []):
			if int(r["id"]) != Red.mi_id:
				_vistos[int(r["id"])] = r["tile"]
	elif tipo == "reject":
		_rechazos.append(str(datos))


func _fallo(motivo: String) -> void:
	print("E2E_FALLO %s" % motivo)
	get_tree().quit(1)


func _esperar(condicion: Callable, segundos: float, que: String) -> bool:
	var t := 0.0
	while t < segundos:
		if condicion.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_fallo("tiempo agotado esperando: " + que)
	return false


func _esperar_sin_fallo(condicion: Callable, segundos: float) -> bool:
	var t := 0.0
	while t < segundos:
		if condicion.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	return false


func _n() -> int:
	return int(_args.get("n", 2))


func _correr() -> void:
	var nombre := str(_args.get("nombre", "Jugador"))
	var err := Red.unirse(str(_args.get("dir", "ws://127.0.0.1:9099")), nombre)
	if err != OK:
		return _fallo("no se pudo abrir la conexión: %d" % err)
	if not await _esperar(func() -> bool: return Red.mi_id != 0 and Red.sala.numero(Red.mi_id) > 0, 10.0, "entrar en la sala"):
		return
	print("E2E %s dentro de la sala, id %d, jugador %d" % [nombre, Red.mi_id, Red.sala.numero(Red.mi_id)])
	var tarde := _args.has("tarde")
	if _args.has("jefe"):
		if not await _esperar(func() -> bool: return Red.sala.cuantos() >= _n(), 30.0, "que entren los jugadores"):
			return
		Red.configurar(str(_args.get("destino", "luna")), "estandar", 6)
		await get_tree().create_timer(0.5).timeout
		Red.empezar()
	var fase_inicial := "operations" if tarde else "workshop"
	if not await _esperar(func() -> bool: return _empezo and str(_snap.get("phase", "")) == fase_inicial, 90.0, "que empiece la partida (%s)" % fase_inicial):
		return
	var roles := Red.mis_roles()
	print("E2E %s roles: %s" % [nombre, ",".join(roles)])
	if not tarde:
		if not await _taller(nombre, roles):
			return
	# --- Operaciones: cada jugador, su rover -----------------------------------------------------------------------------
	if not await _esperar(func() -> bool: return str(_snap.get("phase", "")) == "operations", 20.0, "estar en operaciones"):
		return
	var esperados := int(_args.get("esperar", _n()))
	if not await _esperar(func() -> bool: return (_snap.get("rovers", []) as Array).size() >= mini(esperados, _n() + (1 if tarde else 0)), 30.0, "ver los rovers del equipo"):
		return
	var propio: int = int(_snap.get("rover_id", 0))
	if propio != Red.mi_id:
		return _fallo("el snapshot trae el rover %d y yo soy %d" % [propio, Red.mi_id])
	var inicio: Vector2i = _snap["rover_tile"]
	var preferida := inicio + Vector2i(int(_args.get("dx", 3)), int(_args.get("dy", 0)))
	var meta := preferida
	var llegado := false
	# Si la casilla pedida no sirve (bloqueada, fuera de mapa…), la sala dice por qué y se prueba otra.
	for desplazamiento in [Vector2i.ZERO, Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(2, 2), Vector2i(-2, -2)]:
		meta = preferida + desplazamiento
		_rechazos.clear()
		Red.enviar_orden("move", {"tile": meta})
		await get_tree().create_timer(1.0).timeout
		if not _rechazos.is_empty():
			print("E2E %s: la sala no deja ir a %s (%s)" % [nombre, str(meta), _rechazos[0]])
			continue
		if await _esperar_sin_fallo(func() -> bool: return Vector2i(_snap.get("rover_tile", Vector2i.ZERO)) == meta, 45.0):
			llegado = true
			break
	if not llegado:
		return _fallo("no pude llegar a ninguna casilla")
	print("E2E %s llegó a %s" % [nombre, str(meta)])
	# Lo que no es de mi rol se rechaza.
	_rechazos.clear()
	var ajena := "transmit" if not roles.has("comunicaciones") else ("build" if not roles.has("ingenieria") else "act")
	Red.enviar_orden(ajena, {"on": true, "building": "panel_solar", "tile": Vector2i(0, 0), "action": "drill"})
	if not await _esperar(func() -> bool: return _rechazos.size() > 0, 5.0, "respuesta a una orden de otro rol"):
		return
	print("E2E %s orden %s: %s" % [nombre, ajena, _rechazos[0]])
	if esperados > _n():
		if not await _esperar(func() -> bool: return _vistos.size() >= esperados - 1, 90.0, "ver llegar a quien entra tarde"):
			return
	await get_tree().create_timer(float(_args.get("final", 6.0))).timeout
	var lista: Array[String] = []
	for id in _vistos:
		lista.append("%d,%d" % [_vistos[id].x, _vistos[id].y])
	lista.sort()
	print("E2E %s FINAL mi=%d,%d vistos=%s" % [nombre, meta.x, meta.y, "|".join(lista)])
	print("E2E_OK")
	get_tree().quit(0)


## Taller: una pieza de otro rol se rechaza, el tope de presupuesto del rol se respeta, y cada uno completa lo suyo.
func _taller(nombre: String, roles: Array) -> bool:
	var ajeno := "cohete_pesado" if not roles.has("direccion") else "mmrtg"
	_rechazos.clear()
	Red.enviar_orden("design_add", {"part_id": ajeno})
	if not await _esperar(func() -> bool: return _rechazos.size() > 0, 5.0, "rechazo de una pieza de otro rol"):
		return false
	print("E2E %s pieza ajena %s rechazada: %s" % [nombre, ajeno, _rechazos[0]])
	if not _rechazos[0].begins_with("NET_AREA_"):
		_fallo("el rechazo de la pieza ajena no fue por el área: " + _rechazos[0])
		return false
	if roles.has("direccion"):
		_rechazos.clear()
		Red.enviar_orden("design_add", {"part_id": "cohete_super"})
		if not await _esperar(func() -> bool: return _rechazos.size() > 0, 5.0, "rechazo por presupuesto"):
			return false
		print("E2E %s cohete_super rechazado: %s" % [nombre, _rechazos[0]])
		if _rechazos[0] != "NET_ROLE_BUDGET":
			_fallo("el cohete_super debía rechazarse por presupuesto del rol: " + _rechazos[0])
			return false
	for categoria in Permisos.categorias_de(roles):
		if categoria == "extras":
			for id in EXTRAS:
				Red.enviar_orden("design_add", {"part_id": id})
				await get_tree().create_timer(0.3).timeout
		else:
			Red.enviar_orden("design_add", {"part_id": PIEZAS[categoria]})
			await get_tree().create_timer(0.3).timeout
	if not await _esperar(func() -> bool: return _diseno_completo(), 20.0, "que el diseño quede completo"):
		return false
	print("E2E %s diseño completo" % nombre)
	Red.enviar_orden("design_validate", {})
	if roles.has("direccion"):
		await get_tree().create_timer(1.0).timeout
		Red.enviar_orden("design_start", {})
	if not await _esperar(func() -> bool: return str(_snap.get("phase", "")) in ["landing", "operations"], 25.0, "salir del taller"):
		return false
	await get_tree().create_timer(1.0).timeout
	Red.enviar_orden("landing_finished", {})
	return true


func _diseno_completo() -> bool:
	var sel: Dictionary = _snap.get("workshop", {}).get("selection", {})
	for categoria in PIEZAS:
		if (sel.get(categoria, []) as Array).is_empty():
			return false
	return (sel.get("extras", []) as Array).size() >= EXTRAS.size()
