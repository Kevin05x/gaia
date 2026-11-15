extends RefCounted
## Quién puede dar cada orden en una partida en red. Cada jugador tiene uno o varios roles (los mismos del «Go / No-Go»:
## dirección, ingeniería, ciencia y comunicaciones) y solo puede dar las órdenes de sus roles; así los cuatro juegan a la vez
## sin pisarse. Con un solo jugador (o un solo equipo en la misma pantalla) tiene los cuatro roles y puede hacerlo todo.
## La comprobación la hace siempre el anfitrión: lo que diga el cliente no se da por bueno.

## Órdenes que cualquiera puede dar. El taller es de todo el equipo: cada rol aporta su parte del diseño (instrumentos, antena,
## chasis…); lanzar, en cambio, lo decide Dirección tras el Go / No-Go.
const LIBRES: Array[String] = ["select", "stop", "landing_finished", "tutorial_skip", "design_add", "design_remove", "design_validate"]

## Órdenes de cada rol (además de las libres).
const POR_ROL := {
	"direccion": ["move", "approach", "unload", "pause", "decide", "event_choice", "redesign", "design_start"],
	"ingenieria": ["build", "build_module", "toggle_building"],
	"ciencia": ["approach", "unload", "act", "inspect_story_site"],
	"comunicaciones": ["transmit", "upgrade"],
}

## Razón con la que se rechaza una orden de un rol que no la tiene (es la clave de texto de la interfaz).
const RAZON := "NET_NOT_YOUR_ROLE"


## La razón más precisa: si la orden es de un solo rol, dice cuál («Eso le toca a Dirección»).
static func razon_para(orden: String) -> String:
	var duenos := roles_de_orden(orden)
	return "NET_ONLY_" + duenos[0].to_upper() if duenos.size() == 1 else RAZON


static func permite(roles: Array, orden: String) -> bool:
	if LIBRES.has(orden):
		return true
	for rol in roles:
		if POR_ROL.get(str(rol), []).has(orden):
			return true
	return false


## Roles que pueden dar una orden (para decir «eso lo hace Ciencia» en el aviso).
static func roles_de_orden(orden: String) -> Array[String]:
	var lista: Array[String] = []
	for rol in POR_ROL:
		if POR_ROL[rol].has(orden):
			lista.append(rol)
	return lista


## Áreas del taller. El presupuesto y la masa son uno solo para todo el equipo (como en una misión real), pero cada rol
## elige las piezas de su área: así nadie compra el cohete mientras otro piensa en la antena.
const AREAS := {
	"direccion": ["cohetes", "trayectoria"],
	"ingenieria": ["chasis", "energia"],
	"comunicaciones": ["comunicaciones"],
	"ciencia": ["extras"],
}

const RUTA_PIEZAS := "res://content/parts.json"
static var _categorias_por_pieza: Dictionary = {}


## Rol dueño de una categoría del taller («chasis» → ingenieria). Vacío si ninguna.
static func rol_de_categoria(categoria: String) -> String:
	for rol in AREAS:
		if AREAS[rol].has(categoria):
			return rol
	return ""


## Categorías que le tocan a un conjunto de roles, en el orden del taller.
static func categorias_de(roles: Array) -> Array[String]:
	var lista: Array[String] = []
	for categoria in ["cohetes", "trayectoria", "chasis", "energia", "comunicaciones", "extras"]:
		if roles.has(rol_de_categoria(categoria)):
			lista.append(categoria)
	return lista


## Categoría de una pieza según el catálogo (vacío si no existe; entonces la simulación la rechaza ella sola).
static func categoria_de_pieza(pieza_id: String) -> String:
	if _categorias_por_pieza.is_empty():
		var datos = JSON.parse_string(FileAccess.get_file_as_string(RUTA_PIEZAS))
		if datos is Dictionary:
			for categoria in AREAS.values().reduce(func(a, b): return a + b, []):
				for pieza in datos.get(categoria, []):
					_categorias_por_pieza[str(pieza.get("id", ""))] = categoria
	return str(_categorias_por_pieza.get(pieza_id, ""))


## ¿Puede alguien con estos roles añadir o quitar esta pieza? Las piezas desconocidas pasan (las rechaza la simulación).
static func permite_pieza(roles: Array, pieza_id: String) -> bool:
	var categoria := categoria_de_pieza(pieza_id)
	return categoria.is_empty() or roles.has(rol_de_categoria(categoria))


## Razón de rechazo para una pieza de otra área («Esa pieza es del área de Ingeniería»).
static func razon_de_pieza(pieza_id: String) -> String:
	var rol := rol_de_categoria(categoria_de_pieza(pieza_id))
	return "NET_AREA_" + rol.to_upper() if not rol.is_empty() else RAZON
