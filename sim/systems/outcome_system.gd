class_name OutcomeSystem
extends RefCounted
## Final de la misión: éxito, fracaso, estrellas y causas del informe.
## Éxito: los datos enviados llegan a la meta. Fracaso: segunda entrada en modo seguro, o pasar del
## último sol (la misión termina al acabar el sol límite) sin haber llegado a la meta.
## Estrellas (solo con éxito): 1 por la meta, +1 sin modo seguro, +1 con al menos un sol de margen.

const CAUSA_EXITO := "CAUSE_SUCCESS"
const CAUSA_PLAZO := "CAUSE_FAIL"
const CAUSA_FALLO_MODO_SEGURO := "CAUSE_SAFE_FAIL"
const CAUSA_MODO_SEGURO := "CAUSE_SAFE"
const CAUSA_HISTORIA := "CAUSE_STORY_FAIL"
const CAUSA_ROVER_DESTRUIDO := "CAUSE_ROVER_DESTROYED"
const CAUSA_SOLAR := "CAUSE_SOLAR"
const CAUSA_RTG := "CAUSE_RTG"
const CAUSA_RELE := "CAUSE_RELAY"
const CAUSA_DIRECTA := "CAUSE_DIRECT"

var _sol_limite: int
var requiere_final: bool = false  ## con historia: llegar a la meta solo gana tras decidir el clímax


func _init(reglas: Rules) -> void:
	_sol_limite = reglas.sol_limite


## Evalúa si la misión terminó. Devuelve {} si sigue. Si terminó, deja la fase en "report", detiene
## lo que estuviera en marcha y devuelve el informe con la forma de present_report.
## "eventos" son los de los sistemas en este paso (para detectar el fallo por modo seguro).
func evaluar(estado: MissionState, eventos: Array[String] = []) -> Dictionary:
	if estado.fase != "operations":
		return {}
	if estado.historia_final == StorySystem.FINAL_DERROTA:
		return _terminar(estado, false, CAUSA_HISTORIA)
	if estado.enviados >= estado.meta and (not requiere_final or not estado.historia_final.is_empty()):
		return _terminar(estado, true, CAUSA_EXITO)
	if estado.rover_hp <= 0.0:
		return _terminar(estado, false, CAUSA_ROVER_DESTRUIDO)
	if eventos.has(EnergySystem.EVENTO_MISION_FALLA):
		return _terminar(estado, false, CAUSA_FALLO_MODO_SEGURO)
	if estado.sol > _sol_limite:
		return _terminar(estado, false, CAUSA_PLAZO)
	return {}


func estrellas(estado: MissionState, exito: bool) -> int:
	if not exito:
		return 0
	var total := 1
	if estado.entradas_modo_seguro == 0:
		total += 1
	if estado.sol < _sol_limite:
		total += 1
	return total


func _terminar(estado: MissionState, exito: bool, causa_principal: String) -> Dictionary:
	var estrellas_ganadas := estrellas(estado, exito)
	estado.fase = "report"
	estado.transmitiendo = false
	estado.accion_en_curso = {}
	estado.ocupado = false
	estado.en_movimiento = false
	estado.movimiento_en_curso = {}
	var causas: Array[String] = [causa_principal]
	causas.append(CAUSA_SOLAR if estado.energia == "solar" else CAUSA_RTG)
	causas.append(CAUSA_RELE if estado.enlace == "relay" else CAUSA_DIRECTA)
	if estado.entradas_modo_seguro > 0 and causa_principal != CAUSA_FALLO_MODO_SEGURO:
		causas.append(CAUSA_MODO_SEGURO)
	return {
		"success": exito,
		"stars": estrellas_ganadas,
		"sent": int(estado.enviados),
		"goal": estado.meta,
		"sol": mini(estado.sol, _sol_limite),
		"causes": causas,
	}
