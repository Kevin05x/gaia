class_name EnergySystem
extends RefCounted
## Energía de la misión: generación, consumo continuo, batería y modo seguro.
## No tiene nodos ni reloj propio: la simulación le dice cuántas horas de juego pasaron.
## Las cifras salen de balance.json; la potencia nominal sale del diseño (MissionDesign.potencia_nominal_w).

const EVENTO_ENTRA_MODO_SEGURO := "SAFE_MODE_ENTERED"
const EVENTO_SALE_MODO_SEGURO := "SAFE_MODE_EXITED"
const EVENTO_MISION_FALLA := "MISSION_FAILED_SAFE_MODE"

var _balance: Balance
var _potencia_nominal_w: float


func _init(balance: Balance, potencia_nominal_w: float) -> void:
	_balance = balance
	_potencia_nominal_w = potencia_nominal_w


func es_noche(hora: float) -> bool:
	return hora < _balance.numero("tiempo.amanecer") or hora >= _balance.numero("tiempo.atardecer")


## Solar: potencia nominal por la curva del sol, el polvo y la tormenta. RTG: constante.
func generacion_w(estado: MissionState) -> float:
	if estado.energia == "rtg":
		return _potencia_nominal_w
	var amanecer := _balance.numero("tiempo.amanecer")
	var atardecer := _balance.numero("tiempo.atardecer")
	if estado.hora < amanecer or estado.hora >= atardecer:
		return 0.0
	var curva := sin(PI * (estado.hora - amanecer) / (atardecer - amanecer))
	var factor_tormenta := _balance.numero("energia.factor_solar_tormenta") if estado.tormenta else 1.0
	return _potencia_nominal_w * curva * (1.0 - estado.polvo) * factor_tormenta


## Consumo continuo: base más calefacción de noche (según el tipo de energía).
func carga_w(estado: MissionState) -> float:
	var carga := _balance.numero("energia.consumo_base_w")
	if es_noche(estado.hora):
		carga += _balance.numero("energia.calefaccion_nocturna_w." + estado.energia)
	return carga


## Avanza la batería las horas de juego indicadas. Devuelve los eventos ocurridos (códigos EVENTO_*).
func avanzar(estado: MissionState, horas: float) -> Array[String]:
	var eventos: Array[String] = []
	if horas <= 0.0:
		return eventos
	estado.generacion_w = generacion_w(estado)
	estado.carga_w = carga_w(estado)
	var energia := estado.bateria_wh + (estado.generacion_w - estado.carga_w) * horas
	estado.bateria_wh = clampf(energia, 0.0, estado.bateria_capacidad_wh)
	if estado.bateria_wh <= 0.0 and not estado.modo_seguro:
		estado.modo_seguro = true
		estado.entradas_modo_seguro += 1
		eventos.append(EVENTO_ENTRA_MODO_SEGURO)
		if estado.entradas_modo_seguro >= int(_balance.numero("energia.modos_seguros_para_fallar")):
			eventos.append(EVENTO_MISION_FALLA)
	elif estado.modo_seguro and estado.bateria_wh >= estado.bateria_capacidad_wh * _balance.numero("energia.umbral_salida_modo_seguro"):
		estado.modo_seguro = false
		eventos.append(EVENTO_SALE_MODO_SEGURO)
	return eventos


func puede_consumir(estado: MissionState, wh: float) -> bool:
	return wh >= 0.0 and estado.bateria_wh >= wh


## Descuenta un gasto puntual (moverse, actuar, transmitir). Devuelve false sin cambiar nada si no alcanza.
## El modo seguro por batería vacía lo detecta el siguiente avanzar().
func consumir(estado: MissionState, wh: float) -> bool:
	if not puede_consumir(estado, wh):
		return false
	estado.bateria_wh -= wh
	return true
