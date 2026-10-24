extends RefCounted
## Partida guardada y paso entre menú y juego. La simulación entrega y recibe el diccionario (Simulation.guardar /
## cargar); aquí solo se escribe y se lee del disco (en la web, user:// vive en el almacenamiento del navegador).
const RUTA := "user://gaia_partida.dat"
const ESCENA_MENU := "res://scenes/menu/menu.tscn"
const ESCENA_CARGA := "res://scenes/menu/loading.tscn"
const ESCENA_JUEGO := "res://scenes/a/game.tscn"

## true cuando el menú pidió «Continuar»: MissionRunner restaura la partida al arrancar y baja el indicador.
static var cargar_al_iniciar := false


static func hay_guardado() -> bool:
	return FileAccess.file_exists(RUTA) and not resumen().is_empty()


static func guardar(sim: Simulation) -> bool:
	var datos := sim.guardar()
	var archivo := FileAccess.open(RUTA, FileAccess.WRITE)
	if archivo == null:
		return false
	archivo.store_string(var_to_str(datos))
	return true


static func leer() -> Dictionary:
	if not FileAccess.file_exists(RUTA):
		return {}
	var archivo := FileAccess.open(RUTA, FileAccess.READ)
	if archivo == null:
		return {}
	var datos = str_to_var(archivo.get_as_text())
	return datos if datos is Dictionary else {}


static func borrar() -> void:
	if FileAccess.file_exists(RUTA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUTA))


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
	arbol.change_scene_to_file(ESCENA_CARGA if ResourceLoader.exists(ESCENA_CARGA) else ESCENA_JUEGO)


static func volver_al_menu(arbol: SceneTree) -> void:
	arbol.paused = false
	arbol.change_scene_to_file(ESCENA_MENU)
