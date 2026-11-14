extends RefCounted
## Partida guardada y paso entre menú y juego. La simulación entrega y recibe el diccionario (Simulation.guardar /
## cargar); aquí solo se escribe y se lee del disco (en la web, user:// vive en el almacenamiento del navegador).
const RUTA := "user://gaia_partida.dat"
static var ruta := RUTA  ## archivo de la partida (las pruebas usan otro para no tocar la del jugador)
const ESCENA_MENU := "res://scenes/menu/menu.tscn"
const ESCENA_CARGA := "res://scenes/menu/loading.tscn"
const ESCENA_JUEGO := "res://scenes/a/game.tscn"
const ESCENA_CLIENTE_RED := "res://scenes/net/cliente.tscn"

## true cuando el menú pidió «Continuar»: MissionRunner restaura la partida al arrancar y baja el indicador.
static var cargar_al_iniciar := false
## Configuración de la misión elegida en el menú (Nueva partida): dificultad y modo equipo (1 a 4 personas).
static var dificultad := "estandar"
static var destino := "marte"  ## «marte» o «luna» (content/destinos.json)
static var jugadores := 1
## true en una partida en red: la vista habla con el anfitrión por scenes/net/red.gd y no hay partida guardada ni «Continuar».
static var en_red := false
## Votos del último «Go / No-Go» del equipo en el taller: [{"rol", "jugador", "go"}].
static var votos: Array = []


static func hay_guardado() -> bool:
	return FileAccess.file_exists(ruta) and not resumen().is_empty()


static func guardar(sim: Simulation) -> bool:
	var datos := sim.guardar()
	datos["sesion"] = {"dificultad": dificultad, "jugadores": jugadores, "votos": votos.duplicate(true), "destino": destino}
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(var_to_str(datos))
	return true


static func leer() -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var archivo := FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}
	var datos = str_to_var(archivo.get_as_text())
	return datos if datos is Dictionary else {}


static func borrar() -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))


## {"sol", "hora", "enviados", "meta"} de la partida guardada; vacío si no hay una válida.
static func resumen() -> Dictionary:
	var datos := leer()
	if int(datos.get("version", 0)) != 1:
		return {}
	var estado: Dictionary = datos.get("estado", {})
	if str(estado.get("fase", "")) != "operations":
		return {}
	return {"sol": int(estado.get("sol", 1)), "hora": float(estado.get("hora", 8.0)),
		"enviados": int(float(estado.get("enviados", 0.0))), "meta": int(estado.get("meta", 100))}


## Abre la pantalla de carga y de ahí el juego. "continuar" restaura la partida guardada.
static func empezar(arbol: SceneTree, continuar: bool) -> void:
	cargar_al_iniciar = continuar
	arbol.change_scene_to_file(ESCENA_CARGA if ResourceLoader.exists(ESCENA_CARGA) else escena_juego())


## Recupera la dificultad y el equipo de la partida guardada (si los tiene).
static func restaurar_configuracion() -> void:
	var sesion: Dictionary = leer().get("sesion", {})
	dificultad = str(sesion.get("dificultad", dificultad))
	destino = str(sesion.get("destino", "marte"))
	jugadores = clampi(int(sesion.get("jugadores", jugadores)), 1, 4)
	votos = Array(sesion.get("votos", votos))


## {"presupuesto_musd", "factor_enemigos", "nombre_clave"} de una dificultad (de content/rules.json).
static func datos_dificultad(id: String) -> Dictionary:
	var reglas: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules.json"))
	if not (reglas is Dictionary):
		return {}
	return reglas.get("dificultades", {}).get(id, {})


## Roles de cada jugador según cuántos son: [["direccion", ...], ...] (de content/rules.json).
static func roles_por_jugador(cuantos: int) -> Array:
	var reglas: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules.json"))
	if not (reglas is Dictionary):
		return [["direccion", "ingenieria", "ciencia", "comunicaciones"]]
	return reglas.get("roles_equipo", {}).get(str(clampi(cuantos, 1, 4)), [["direccion", "ingenieria", "ciencia", "comunicaciones"]])


## La escena de juego: la de siempre, o el cliente de red si se juega con otros dispositivos.
static func escena_juego() -> String:
	return ESCENA_CLIENTE_RED if en_red else ESCENA_JUEGO


static func volver_al_menu(arbol: SceneTree) -> void:
	arbol.paused = false
	en_red = false
	arbol.change_scene_to_file(ESCENA_MENU)
