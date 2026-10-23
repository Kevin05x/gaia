class_name CommsSystem
extends RefCounted
## Transmisión de los datos guardados a la Tierra. Solo fluye con el enlace abierto; el ritmo y el
## costo en energía dependen del tipo de enlace y del nivel de antena (balance.json).

const EVENTO_TRANSMISION_TERMINADA := "TRANSMISSION_ENDED"

var _balance: Balance


func _init(balance: Balance) -> void:
	_balance = balance


## {"enabled": bool, "reason": String}. Encender exige enlace y datos; apagar siempre se puede.
func disponibilidad(estado: MissionState) -> Dictionary:
	var motivo := _motivo(estado)
	return {"enabled": motivo.is_empty(), "reason": motivo}


## Enciende o apaga la transmisión. {"ok": bool, "reason": String}.
func transmitir(estado: MissionState, activar: bool) -> Dictionary:
	if activar:
		var motivo := _motivo(estado)
		if not motivo.is_empty():
			return {"ok": false, "reason": motivo}
	estado.transmitiendo = activar
	return {"ok": true, "reason": ""}


## Envía datos durante los segundos reales indicados. Devuelve los eventos ocurridos.
func avanzar(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	if not estado.transmitiendo or estado.fase != "operations" or estado.pausado or delta_s <= 0.0:
		return eventos
	if estado.modo_seguro:
		estado.transmitiendo = false
		eventos.append(EVENTO_TRANSMISION_TERMINADA)
		return eventos
	if not estado.enlace_abierto:
		return eventos
	var clave: String = MissionState.ENLACES[estado.enlace]
	var unidades_por_s := _balance.numero("comunicaciones.%s.unidades_por_s" % clave)
	var costo_por_unidad := _balance.numero("comunicaciones.%s.costo_wh_por_unidad" % clave)
	var cantidad := minf(estado.datos, delta_s * unidades_por_s * estado.nivel_antena)
	if costo_por_unidad > 0.0:
		cantidad = minf(cantidad, estado.bateria_wh / costo_por_unidad)
	estado.datos = maxf(0.0, estado.datos - cantidad)
	estado.enviados += cantidad
	estado.bateria_wh = maxf(0.0, estado.bateria_wh - cantidad * costo_por_unidad)
	if estado.datos <= 0.0:
		estado.transmitiendo = false
		eventos.append(EVENTO_TRANSMISION_TERMINADA)
	return eventos


func _motivo(estado: MissionState) -> String:
	if estado.fase != "operations":
		return "MISSION_END" if estado.fase == "report" else "LANDING"
	if estado.pausado:
		return "PAUSED"
	if estado.modo_seguro:
		return "SAFE"
	if not estado.transmitiendo:
		if not estado.enlace_abierto:
			return "NO_LINK"
		if estado.datos <= 0.0:
			return "NO_DATA"
	return ""
