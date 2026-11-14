extends RefCounted
## Sala de una partida en red: quién entró, en qué orden, con qué roles y con qué configuración. Es lógica pura (sin sockets
## ni nodos) para poder probarla; scenes/net/red.gd la usa y la reparte entre los dispositivos.
## El primero en entrar es el jefe de la sala: elige destino y dificultad y da la orden de empezar. Los roles se reparten
## igual que en el equipo de una sola pantalla (content/rules.json › roles_equipo), según cuántas personas haya al empezar.
const Sesion := preload("res://scenes/menu/game_session.gd")

const MAXIMO := 4
const NOMBRE_MAXIMO := 16

var orden: Array[int] = []  ## ids de los jugadores en orden de llegada
var nombres: Dictionary = {}  ## id -> nombre
var config := {"destino": "marte", "dificultad": "estandar"}
var jugando := false
var _roles: Dictionary = {}  ## id -> roles, fijados al empezar (y reasignados si alguien se va)


## true si entró. Falla si la sala está llena o ese id ya está. Con la misión en marcha también se puede entrar: los roles se
## reparten de nuevo entre todos, según cuántos son ahora.
func anadir(id: int, nombre: String) -> bool:
	if orden.size() >= MAXIMO or orden.has(id):
		return false
	orden.append(id)
	nombres[id] = limpiar_nombre(nombre, orden.size())
	if jugando:
		_repartir_roles()
	return true


static func limpiar_nombre(nombre: String, posicion: int) -> String:
	var limpio := nombre.strip_edges().replace("\n", " ").left(NOMBRE_MAXIMO)
	return limpio if not limpio.is_empty() else "Jugador %d" % posicion


## Quita a un jugador. Si la partida ya empezó, sus roles pasan al jefe para que nadie se quede sin poder jugar su parte.
func quitar(id: int) -> void:
	var idx := orden.find(id)
	if idx < 0:
		return
	var heredados: Array = _roles.get(id, [])
	orden.remove_at(idx)
	nombres.erase(id)
	_roles.erase(id)
	if jugando and not orden.is_empty():
		var jefe_id := orden[0]
		var mios: Array = _roles.get(jefe_id, [])
		for rol in heredados:
			if not mios.has(rol):
				mios.append(rol)
		_roles[jefe_id] = mios


func cuantos() -> int:
	return orden.size()


func jefe() -> int:
	return orden[0] if not orden.is_empty() else 0


func es_jefe(id: int) -> bool:
	return not orden.is_empty() and orden[0] == id


## Número de jugador (1 a 4) o 0 si no está.
func numero(id: int) -> int:
	return orden.find(id) + 1


## Cambia la configuración; solo el jefe, y solo antes de empezar.
func configurar(id: int, destino: String, dificultad: String) -> bool:
	if jugando or not es_jefe(id):
		return false
	config = {"destino": destino, "dificultad": dificultad}
	return true


## El jefe empieza la partida: se fijan los roles según cuántos son. false si no es el jefe o ya empezó.
func empezar(id: int) -> bool:
	if jugando or not es_jefe(id) or orden.is_empty():
		return false
	jugando = true
	_repartir_roles()
	return true


func _repartir_roles() -> void:
	var reparto: Array = Sesion.roles_por_jugador(orden.size())
	_roles.clear()
	for i in range(orden.size()):
		_roles[orden[i]] = Array(reparto[i]).duplicate() if i < reparto.size() else []


## Roles de un jugador (vacío si no hay partida o no existe).
func roles_de(id: int) -> Array:
	return _roles.get(id, [])


## Quién tiene un rol (id del jugador, 0 si nadie).
func quien_tiene(rol: String) -> int:
	for id in orden:
		if _roles.get(id, []).has(rol):
			return id
	return 0


## Vuelve a la sala sin dueños de rol (al terminar la misión).
func reiniciar() -> void:
	jugando = false
	_roles.clear()


## Para mandarla por la red: todo son números, textos y listas.
func a_dict() -> Dictionary:
	var jugadores: Array = []
	for id in orden:
		jugadores.append({"id": id, "nombre": nombres.get(id, ""), "roles": roles_de(id)})
	return {"jugadores": jugadores, "config": config.duplicate(), "jugando": jugando, "jefe": jefe()}


## Reconstruye una sala a partir de lo que mandó el anfitrión (los clientes solo la leen).
static func desde_dict(datos: Dictionary) -> Object:
	var sala = load("res://scenes/net/sala.gd").new()
	for j in datos.get("jugadores", []):
		var id := int(j.get("id", 0))
		sala.orden.append(id)
		sala.nombres[id] = str(j.get("nombre", ""))
		sala._roles[id] = Array(j.get("roles", []))
	var cfg: Dictionary = datos.get("config", {})
	sala.config = {"destino": str(cfg.get("destino", "marte")), "dificultad": str(cfg.get("dificultad", "estandar"))}
	sala.jugando = bool(datos.get("jugando", false))
	return sala
