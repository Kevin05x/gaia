class_name TutorialSystem
extends RefCounted
## Tutorial del Sol 1 (content/tutorial.json): lleva la cuenta de los eventos que le interesan, da por hechos los
## pasos cuando se cumple su condición (también los que el jugador adelanta) y avisa a la vista del paso actual. No
## bloquea nada: es solo guía. El jugador puede saltarlo en cualquier momento.

const EVENTO_PASO := "TUTORIAL_STEP"  ## TUTORIAL_STEP:<id>, cuando se completa un paso
const EVENTO_FIN := "TUTORIAL_DONE"  ## cuando se completa el último o se cierra por el sol

var _datos: TutorialData
var _edificios: BuildSystem  ## puede ser null


func _init(datos: TutorialData, edificios: BuildSystem) -> void:
	_datos = datos
	_edificios = edificios


func iniciar(estado: MissionState) -> void:
	estado.tutorial_activo = not _datos.pasos.is_empty()
	estado.tutorial_paso = 0
	estado.tutorial_t = 0.0
	estado.tutorial_contadores = {}


## Cuenta los eventos de este paso de la simulación y avanza todos los pasos que ya estén cumplidos.
func avanzar(estado: MissionState, delta_s: float, eventos: Array[String]) -> Array[String]:
	var salida: Array[String] = []
	if not estado.tutorial_activo or estado.fase != "operations":
		return salida
	for evento in eventos:
		var partes := evento.split(":")
		_contar(estado, partes[0])
		if partes.size() > 1:
			_contar(estado, "%s:%s" % [partes[0], partes[1]])
	estado.tutorial_t += delta_s
	while estado.tutorial_paso < _datos.pasos.size() and _cumple(estado, _datos.pasos[estado.tutorial_paso]["condicion"]):
		salida.append("%s:%s" % [EVENTO_PASO, _datos.pasos[estado.tutorial_paso]["id"]])
		estado.tutorial_paso += 1
		estado.tutorial_t = 0.0
	if estado.tutorial_paso >= _datos.pasos.size() or estado.sol > _datos.hasta_sol:
		estado.tutorial_activo = false
		salida.append(EVENTO_FIN)
	return salida


## El jugador cierra el tutorial.
func omitir(estado: MissionState) -> void:
	estado.tutorial_activo = false


func paso_actual(estado: MissionState) -> Dictionary:
	if not estado.tutorial_activo or estado.tutorial_paso >= _datos.pasos.size():
		return {}
	return _datos.pasos[estado.tutorial_paso]


## Lo que la vista necesita: si hay un cartel y su contenido.
func para_la_vista(estado: MissionState) -> Dictionary:
	var paso := paso_actual(estado)
	if paso.is_empty():
		return {"active": false}
	return {"active": true, "step": estado.tutorial_paso + 1, "total": _datos.pasos.size(), "id": str(paso["id"]),
		"text": paso["texto"], "highlight": str(paso.get("resalta", ""))}


func _contar(estado: MissionState, clave: String) -> void:
	estado.tutorial_contadores[clave] = int(estado.tutorial_contadores.get(clave, 0)) + 1


func _cumple(estado: MissionState, condicion: Dictionary) -> bool:
	if condicion.has("leer_s"):
		return estado.tutorial_t >= float(condicion["leer_s"])
	if condicion.has("evento"):
		return int(estado.tutorial_contadores.get(str(condicion["evento"]), 0)) >= int(condicion.get("min", 1))
	var minimo := float(condicion.get("min", 1))
	match str(condicion.get("tipo", "")):
		"edificio":
			var total := 0.0
			for edificio in estado.edificios:
				if str(edificio["type"]) == str(condicion.get("id", "")) and int(edificio["level"]) >= 1:
					total += 1.0
			return total >= minimo
		"antena":
			return float(estado.nivel_antena) >= minimo
		"enviados":
			return estado.enviados >= minimo
	return false
