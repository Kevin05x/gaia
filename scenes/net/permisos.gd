extends RefCounted
## Quién puede dar cada orden en una partida en red. Cada jugador tiene uno o varios roles (los mismos del «Go / No-Go»:
## dirección, ingeniería, ciencia y comunicaciones) y solo puede dar las órdenes de sus roles; así los cuatro juegan a la vez
## sin pisarse. Con un solo jugador (o un solo equipo en la misma pantalla) tiene los cuatro roles y puede hacerlo todo.
## La comprobación la hace siempre el anfitrión: lo que diga el cliente no se da por bueno.

## Órdenes que cualquiera puede dar.
const LIBRES: Array[String] = ["select", "stop", "landing_finished", "tutorial_skip"]

## Órdenes de cada rol (además de las libres).
const POR_ROL := {
	"direccion": ["move", "approach", "unload", "pause", "decide", "event_choice", "redesign",
		"design_add", "design_remove", "design_validate", "design_start"],
	"ingenieria": ["build", "build_module", "toggle_building", "design_add", "design_remove", "design_validate"],
	"ciencia": ["approach", "unload", "act"],
	"comunicaciones": ["transmit", "upgrade"],
}

## Razón con la que se rechaza una orden de un rol que no la tiene (es la clave de texto de la interfaz).
const RAZON := "NET_NOT_YOUR_ROLE"


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
