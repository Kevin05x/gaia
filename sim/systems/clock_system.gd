class_name ClockSystem
extends RefCounted
## Reloj y clima de la misión: hora y sol, día y noche, tormenta y ventanas del enlace.
## El tiempo solo corre en la fase "operations" y sin pausa. El modo seguro NO lo detiene
## (la batería solo se recarga con el paso del tiempo).
## No tiene reloj propio: la simulación le entrega los segundos reales transcurridos.

const EVENTO_SOL_NUEVO := "SOL_ADVANCED"
const EVENTO_TORMENTA_INICIA := "STORM_STARTED"
const EVENTO_TORMENTA_TERMINA := "STORM_ENDED"
const EVENTO_ENLACE_ABRE := "LINK_OPENED"
const EVENTO_ENLACE_CIERRA := "LINK_CLOSED"
const EVENTO_ANOCHECE := "NIGHT_STARTED"
const EVENTO_AMANECE := "DAY_STARTED"
const HORAS_POR_SOL := 24.0

var _balance: Balance
var _soles_tormenta: Array[int]


func _init(balance: Balance, reglas: Rules) -> void:
	_balance = balance
	_soles_tormenta = reglas.soles_de_evento("tormenta_polvo")
	_soles_tormenta.sort()


## Horas de juego que equivalen a los segundos reales indicados.
func horas_de_juego(delta_s: float) -> float:
	var duracion := _balance.numero("tiempo.duracion_sol_s")
	if duracion <= 0.0 or delta_s <= 0.0:
		return 0.0
	return delta_s * HORAS_POR_SOL / duracion


func es_noche(hora: float) -> bool:
	return hora < _balance.numero("tiempo.amanecer") or hora >= _balance.numero("tiempo.atardecer")


## Avanza el reloj los segundos reales indicados y devuelve los eventos ocurridos (códigos EVENTO_*).
func avanzar(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	if estado.fase != "operations" or estado.pausado:
		return eventos
	var horas := horas_de_juego(delta_s)
	if horas <= 0.0:
		return eventos
	actualizar(estado)
	var antes := _foto(estado)
	estado.hora += horas
	while estado.hora >= HORAS_POR_SOL:
		estado.hora -= HORAS_POR_SOL
		estado.sol += 1
		eventos.append(EVENTO_SOL_NUEVO)
	actualizar(estado)
	var despues := _foto(estado)
	if despues["noche"] != antes["noche"]:
		eventos.append(EVENTO_ANOCHECE if despues["noche"] else EVENTO_AMANECE)
	if despues["tormenta"] != antes["tormenta"]:
		eventos.append(EVENTO_TORMENTA_INICIA if despues["tormenta"] else EVENTO_TORMENTA_TERMINA)
	if despues["enlace"] != antes["enlace"]:
		eventos.append(EVENTO_ENLACE_ABRE if despues["enlace"] else EVENTO_ENLACE_CIERRA)
	return eventos


## Recalcula lo que depende de la hora y el sol, sin avanzar el tiempo.
func actualizar(estado: MissionState) -> void:
	estado.es_noche = es_noche(estado.hora)
	estado.tormenta = _soles_tormenta.has(estado.sol)
	estado.tormenta_en = _soles_hasta_tormenta(estado)
	estado.enlace_abierto = _esta_abierta(estado.ventanas_enlace, estado.hora)
	estado.proximo_cambio_enlace = _proximo_cambio(estado)


func _foto(estado: MissionState) -> Dictionary:
	return {"noche": estado.es_noche, "tormenta": estado.tormenta, "enlace": estado.enlace_abierto}


## Soles que faltan para el comienzo de la próxima tormenta; 0 si está activa o no queda ninguna.
func _soles_hasta_tormenta(estado: MissionState) -> float:
	if estado.tormenta:
		return 0.0
	for sol_tormenta in _soles_tormenta:
		if sol_tormenta > estado.sol:
			return sol_tormenta - estado.sol - estado.hora / HORAS_POR_SOL
	return 0.0


func _esta_abierta(ventanas: Array, hora: float) -> bool:
	for ventana in ventanas:
		if hora >= float(ventana[0]) and hora < float(ventana[1]):
			return true
	return false


func _proximo_cambio(estado: MissionState) -> Dictionary:
	var ventanas := estado.ventanas_enlace
	if ventanas.is_empty():
		return {"opens": true, "hour": 0.0, "sol": estado.sol}
	if estado.enlace_abierto:
		for ventana in ventanas:
			if estado.hora >= float(ventana[0]) and estado.hora < float(ventana[1]):
				return {"opens": false, "hour": float(ventana[1]), "sol": estado.sol}
	var siguiente := -1.0
	var primera := float(ventanas[0][0])
	for ventana in ventanas:
		var inicio := float(ventana[0])
		primera = minf(primera, inicio)
		if inicio > estado.hora and (siguiente < 0.0 or inicio < siguiente):
			siguiente = inicio
	if siguiente >= 0.0:
		return {"opens": true, "hour": siguiente, "sol": estado.sol}
	return {"opens": true, "hour": primera, "sol": estado.sol + 1}
