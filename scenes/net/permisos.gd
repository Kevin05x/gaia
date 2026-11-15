extends RefCounted
## Quién puede dar cada orden en una partida en red. Cada jugador tiene uno o varios roles (los mismos del «Go / No-Go»:
## dirección, ingeniería, ciencia y comunicaciones) y solo puede dar las órdenes de sus roles; así los cuatro juegan a la vez
## sin pisarse. Con un solo jugador (o un solo equipo en la misma pantalla) tiene los cuatro roles y puede hacerlo todo.
## La comprobación la hace siempre el anfitrión: lo que diga el cliente no se da por bueno.

## Órdenes que cualquiera puede dar. El taller es de todo el equipo: cada rol aporta su parte del diseño (instrumentos, antena,
## chasis…); lanzar, en cambio, lo decide Dirección tras el Go / No-Go.
const LIBRES: Array[String] = ["select", "stop", "landing_finished", "tutorial_skip", "tutorial_next", "design_add", "design_remove", "design_validate"]

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


## Presupuesto propio de cada rol (plan 12, pedido de Kevin el 15 nov): el rover y la masa siguen siendo uno solo, pero cada rol tiene su
## parte del presupuesto total y no puede pasarse de ella. Las partes salen de content/rules*.json › presupuesto_por_rol (valores de
## juego, sumados dan el presupuesto estándar) y se escalan al presupuesto de la dificultad. Solo con más de un jugador en la sala.
static func topes_por_rol(presupuesto_total: float) -> Dictionary:
	var config := Destino.config(Destino.id)
	var datos = JSON.parse_string(FileAccess.get_file_as_string(str(config.get("reglas", "res://content/rules.json"))))
	var partes: Dictionary = datos.get("presupuesto_por_rol", {}) if datos is Dictionary else {}
	var suma := 0.0
	for rol in partes:
		suma += float(partes[rol])
	var topes := {}
	if suma <= 0.0:
		return topes
	for rol in partes:
		topes[str(rol)] = float(partes[rol]) * presupuesto_total / suma
	return topes


## Cuánto lleva gastado cada rol: el costo de las piezas elegidas en las categorías de su área.
static func gasto_por_rol(taller: Dictionary) -> Dictionary:
	var costo := {}
	for cat in taller.get("categories", []):
		for pieza in cat.get("parts", []):
			var valor = pieza.get("cost_musd")
			costo[str(pieza.get("id", ""))] = float(valor) if valor != null else 0.0
	var gasto := {}
	for rol in AREAS:
		gasto[rol] = 0.0
	var seleccion: Dictionary = taller.get("selection", {})
	for categoria in seleccion:
		var rol := rol_de_categoria(str(categoria))
		if rol.is_empty():
			continue
		for id in seleccion[categoria]:
			gasto[rol] += float(costo.get(str(id), 0.0))
	return gasto


## M$ que le quedan a un rol para esta pieza; negativo si no cabe. null si no hay reparto (sala de uno, o sin datos).
static func resto_de_rol(rol: String, costo_pieza: float, taller: Dictionary) -> Variant:
	var total := float(taller.get("totals", {}).get("budget_musd", 0.0))
	var topes := topes_por_rol(total)
	if not topes.has(rol):
		return null
	return float(topes[rol]) - float(gasto_por_rol(taller).get(rol, 0.0)) - costo_pieza


## ¿Puede alguien con estos roles añadir o quitar esta pieza? Las piezas desconocidas pasan (las rechaza la simulación).
static func permite_pieza(roles: Array, pieza_id: String) -> bool:
	var categoria := categoria_de_pieza(pieza_id)
	return categoria.is_empty() or roles.has(rol_de_categoria(categoria))


## Razón de rechazo cuando la pieza no cabe en la parte del presupuesto de su rol.
const RAZON_PRESUPUESTO := "NET_ROLE_BUDGET"


## Razón de rechazo para una pieza de otra área («Esa pieza es del área de Ingeniería»).
static func razon_de_pieza(pieza_id: String) -> String:
	var rol := rol_de_categoria(categoria_de_pieza(pieza_id))
	return "NET_AREA_" + rol.to_upper() if not rol.is_empty() else RAZON
