class_name Simulation
extends RefCounted
## Une todos los sistemas de la misión (reloj, energía, ciencia, movimiento, comunicaciones y
## resultado), atiende las órdenes de la vista y entrega el snapshot completo de INTEGRACION_A.md.
## Simulación pura: sin nodos. Quien la mueve (MissionRunner) le da los segundos reales de cada
## cuadro con avanzar() y traduce lo que devuelve a llamadas al Port de la vista.

const EVENTO_MISION_TERMINADA := "MISSION_ENDED"
const EVENTO_ACCION_CANCELADA := "ACTION_CANCELLED"
## Acciones que la vista conoce (INTEGRACION_A.md). "upgrade", "transmit" y "approach" van aparte.
const ACCIONES_VISTA: Array[String] = ["panorama", "spectrometer", "drill", "radar", "drone", "companion"]

var estado: MissionState
var informe: Dictionary = {}  ## vacío mientras la misión sigue; al terminar, forma de present_report

var _balance: Balance
var _reglas: Rules
var _mapa: MapData
var _catalogo: Catalog
var _diseno: MissionDesign  ## piezas elegidas en el taller; sobrevive a reiniciar()
var _reloj: ClockSystem
var _energia: EnergySystem
var _ciencia: ScienceSystem
var _comunicaciones: CommsSystem
var _movimiento: MovementSystem
var _resultado: OutcomeSystem
var _seleccion: String = ""
var _potencia_nominal_w: float = 0.0  ## del panel o RTG elegido; hace falta para reconstruir los sistemas al cargar
var _revision_mapa: int = 0  ## sube en cada reiniciar(): la vista reconstruye el mapa


func _init(balance: Balance, reglas: Rules, mapa: MapData, catalogo: Catalog) -> void:
	_balance = balance
	_reglas = reglas
	_mapa = mapa
	_catalogo = catalogo
	_diseno = MissionDesign.new(catalogo, reglas)
	reiniciar()


## Vuelve al taller con una misión limpia (mapa y objetivos como al principio). Conserva las piezas
## elegidas para poder ajustarlas al rediseñar.
func reiniciar() -> void:
	estado = MissionState.new(_balance, _reglas)
	_mapa.aplicar_a(estado)
	_revision_mapa += 1
	estado.revision_mapa = _revision_mapa
	estado.fase = "workshop"
	informe = {}
	_seleccion = ""
	_potencia_nominal_w = 0.0
	_construir_sistemas(0.0)
	_reloj.actualizar(estado)


## Fija el diseño elegido en el taller. "potencia_nominal_w" es la potencia del panel o del RTG.
## Solo se acepta en el taller; devuelve false (sin cambiar nada) si no, o si el diseño no existe.
func configurar_diseno(energia: String, enlace: String, instrumentos: Array[String], companero: bool, potencia_nominal_w: float) -> bool:
	if estado.fase != "workshop":
		return false
	if not estado.configurar_diseno(energia, enlace, instrumentos, companero):
		return false
	_potencia_nominal_w = potencia_nominal_w
	_construir_sistemas(potencia_nominal_w)
	_reloj.actualizar(estado)
	return true


## Pasa del taller al aterrizaje. false si no se estaba en el taller.
func iniciar_aterrizaje() -> bool:
	if estado.fase != "workshop":
		return false
	estado.fase = "landing"
	return true


## Atiende una orden de la vista. Devuelve {"ok", "reason"} y, según la orden:
## "path" y "seconds_per_tile" (move, approach) o "action" (act) para que la vista los presente.
func ejecutar(orden: String, carga: Dictionary = {}) -> Dictionary:
	match orden:
		"select":
			return _seleccionar(str(carga.get("target_id", "")))
		"move":
			return _mover(carga.get("tile", Vector2i.ZERO))
		"approach":
			return _acercar(str(carga.get("target_id", _seleccion)))
		"act":
			return _actuar(str(carga.get("action", "")), str(carga.get("target_id", _seleccion)))
		"transmit":
			return _resultado_simple(_comunicaciones.transmitir(estado, bool(carga.get("on", false))))
		"upgrade":
			return _resultado_simple(_ciencia.mejorar_antena(estado))
		"pause":
			return _pausar(bool(carga.get("paused", false)))
		"landing_finished":
			return _terminar_aterrizaje()
		"redesign":
			return _redisenar()
		"design_add", "design_remove", "design_validate", "design_start":
			return _orden_de_taller(orden, str(carga.get("part_id", "")))
		_:
			return {"ok": false, "reason": "UNKNOWN_COMMAND"}


## Avanza la misión los segundos reales indicados. Devuelve los eventos ocurridos (códigos de cada
## sistema, más ACTION_CANCELLED y MISSION_ENDED). Si la misión terminó, "informe" ya está lleno.
func avanzar(delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	if estado.fase != "operations" or estado.pausado or delta_s <= 0.0:
		return eventos
	eventos.append_array(_energia.avanzar(estado, _reloj.horas_de_juego(delta_s)))
	var eventos_reloj := _reloj.avanzar(estado, delta_s)
	eventos.append_array(eventos_reloj)
	for evento in eventos_reloj:
		if evento == ClockSystem.EVENTO_SOL_NUEVO:
			eventos.append_array(_ciencia.al_nuevo_sol(estado))
	var habia_accion := not estado.accion_en_curso.is_empty()
	var eventos_ciencia := _ciencia.avanzar(estado, delta_s)
	eventos.append_array(eventos_ciencia)
	if habia_accion and estado.accion_en_curso.is_empty() and not _hay_evento(eventos_ciencia, ScienceSystem.EVENTO_ACCION_TERMINADA):
		eventos.append(EVENTO_ACCION_CANCELADA)
	eventos.append_array(_movimiento.avanzar(estado, delta_s))
	eventos.append_array(_comunicaciones.avanzar(estado, delta_s))
	informe = _resultado.evaluar(estado, eventos)
	if not informe.is_empty():
		eventos.append(EVENTO_MISION_TERMINADA)
	return eventos


## Snapshot completo para la vista: el del estado más objetivos con sus acciones, avisos y
## disponibilidad de cada acción.
func snapshot() -> Dictionary:
	var datos := estado.a_snapshot()
	datos["targets"] = _objetivos_para_la_vista()
	datos["warnings"] = _avisos()
	datos["available_actions"] = _acciones_disponibles()
	if estado.fase == "workshop":
		datos["workshop"] = _taller()
	return datos


## Partida guardada: todo el estado vivo más las piezas elegidas y la potencia nominal. Solo datos simples, para
## escribirlos con var_to_str. La vista se reconstruye sola desde el snapshot al cargar.
func guardar() -> Dictionary:
	var campos := {}
	for propiedad in estado.get_property_list():
		if (int(propiedad["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var nombre: String = propiedad["name"]
		if nombre.begins_with("_"):
			continue
		var valor = estado.get(nombre)
		campos[nombre] = valor.duplicate(true) if (valor is Array or valor is Dictionary) else valor
	return {"version": 1, "estado": campos, "diseno": _diseno.seleccion.duplicate(true),
		"potencia_nominal_w": _potencia_nominal_w}


## Restaura una partida de guardar(). Solo se aceptan partidas en operaciones. Devuelve false, sin tocar
## nada, si los datos no sirven. Lo que pasaba en el instante (movimiento, acción, transmisión) no se restaura.
func cargar(datos: Dictionary) -> bool:
	if int(datos.get("version", 0)) != 1 or not datos.has("estado") or not datos.has("diseno"):
		return false
	var campos: Dictionary = datos["estado"]
	if str(campos.get("fase", "")) != "operations":
		return false
	reiniciar()
	var diseno: Dictionary = datos["diseno"]
	for categoria in Catalog.CATEGORIAS:
		_diseno.seleccion[categoria] = Array(diseno.get(categoria, []))
	for nombre in campos:
		var actual = estado.get(nombre)
		var valor = campos[nombre]
		if actual is Array:
			actual.assign(valor)
		elif actual != null:
			estado.set(nombre, valor)
	estado.revision_mapa = _revision_mapa
	estado.pausado = false
	estado.en_movimiento = false
	estado.movimiento_en_curso = {}
	estado.ocupado = false
	estado.accion_en_curso = {}
	estado.transmitiendo = false
	_potencia_nominal_w = float(datos.get("potencia_nominal_w", 0.0))
	_construir_sistemas(_potencia_nominal_w)
	_reloj.actualizar(estado)
	return true


func objetivo_seleccionado() -> String:
	return _seleccion


func _construir_sistemas(potencia_nominal_w: float) -> void:
	_reloj = ClockSystem.new(_balance, _reglas)
	_energia = EnergySystem.new(_balance, potencia_nominal_w)
	_ciencia = ScienceSystem.new(_balance, _energia)
	_comunicaciones = CommsSystem.new(_balance)
	_movimiento = MovementSystem.new(_balance, _energia, _mapa)
	_resultado = OutcomeSystem.new(_reglas)


func _seleccionar(objetivo_id: String) -> Dictionary:
	if objetivo_id.is_empty():
		_seleccion = ""
		return {"ok": true, "reason": ""}
	for objetivo in estado.objetivos:
		if objetivo["id"] == objetivo_id and objetivo["revealed"]:
			_seleccion = objetivo_id
			return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "NO_TARGET"}


func _mover(casilla: Vector2i) -> Dictionary:
	return _resultado_movimiento(_movimiento.iniciar_mover(estado, casilla))


func _acercar(objetivo_id: String) -> Dictionary:
	var resultado := _movimiento.iniciar_acercar(estado, objetivo_id)
	if resultado["ok"]:
		if resultado["path"].is_empty():
			return {"ok": false, "reason": "ALREADY_NEAR"}
		_seleccion = objetivo_id
	return _resultado_movimiento(resultado)


func _actuar(accion: String, objetivo_id: String) -> Dictionary:
	var resultado := _ciencia.iniciar(estado, accion, objetivo_id)
	if not resultado["ok"]:
		return resultado
	var en_curso := estado.accion_en_curso
	return {"ok": true, "reason": "", "action": {"target_id": en_curso["target_id"], "action": en_curso["action"], "seconds": en_curso["seconds"]}}


func _pausar(pausa: bool) -> Dictionary:
	if estado.fase != "operations":
		return {"ok": false, "reason": "WRONG_PHASE"}
	estado.pausado = pausa
	return {"ok": true, "reason": ""}


func _terminar_aterrizaje() -> Dictionary:
	if estado.fase != "landing":
		return {"ok": false, "reason": "WRONG_PHASE"}
	estado.fase = "operations"
	_reloj.actualizar(estado)
	return {"ok": true, "reason": ""}


func _redisenar() -> Dictionary:
	if estado.fase == "workshop":
		return {"ok": false, "reason": "WRONG_PHASE"}
	reiniciar()
	return {"ok": true, "reason": ""}


func _orden_de_taller(orden: String, pieza_id: String) -> Dictionary:
	if estado.fase != "workshop":
		return {"ok": false, "reason": "WRONG_PHASE"}
	match orden:
		"design_add":
			var disponible := _disponibilidad_pieza(pieza_id)
			if disponible["enabled"]:
				_diseno.agregar(pieza_id)
			return {"ok": disponible["enabled"], "reason": disponible["reason"]}
		"design_remove":
			return {"ok": true, "reason": ""} if _diseno.quitar(pieza_id) else {"ok": false, "reason": "UNKNOWN_PART"}
		"design_validate":
			return {"ok": true, "reason": ""} if _diseno.es_valido() else {"ok": false, "reason": "INVALID_DESIGN"}
		_:
			return _comenzar_mision()


## Valida el diseño, lo traduce a la configuración de la misión y pasa al aterrizaje.
func _comenzar_mision() -> Dictionary:
	if not _diseno.es_valido():
		return {"ok": false, "reason": "INVALID_DESIGN"}
	var configuracion := _diseno.a_configuracion()
	if not configurar_diseno(configuracion["energia"], configuracion["enlace"], configuracion["instrumentos"],
			configuracion["companero"], configuracion["potencia_nominal_w"]):
		return {"ok": false, "reason": "INVALID_DESIGN"}
	iniciar_aterrizaje()
	return {"ok": true, "reason": ""}


## {"enabled", "reason"}: una pieza se puede agregar si existe y su categoría no está completa.
func _disponibilidad_pieza(pieza_id: String) -> Dictionary:
	if not _catalogo.tiene(pieza_id):
		return {"enabled": false, "reason": "UNKNOWN_PART"}
	var categoria: String = _catalogo.obtener(pieza_id)["categoria"]
	var maximo := _reglas.limite_max(categoria)
	if maximo >= 0 and _diseno.cantidad(categoria) >= maximo:
		return {"enabled": false, "reason": "CATEGORY_FULL"}
	return {"enabled": true, "reason": ""}


## Todo lo que el taller muestra, ya calculado: piezas por categoría, elegidas, totales y validación.
func _taller() -> Dictionary:
	var categorias: Array[Dictionary] = []
	for categoria in Catalog.CATEGORIAS:
		var piezas: Array[Dictionary] = []
		for id in _catalogo.ids_de(categoria):
			var pieza := _catalogo.obtener(id)
			var disponible := _disponibilidad_pieza(id)
			piezas.append({"id": id, "name_key": pieza["nombre_clave"], "capacity_kg": pieza.get("capacidad_kg"),
				"mass_kg": pieza.get("masa_kg"), "cost_musd": pieza.get("costo_musd"),
				"power_w": pieza.get("potencia_w", pieza.get("potencia_max_w")),
				"pending": pieza.get("pendiente", false) == true,
				"available": disponible["enabled"], "reason": disponible["reason"]})
		categorias.append({"id": categoria, "parts": piezas})
	var validacion := _diseno.validar()
	return {"categories": categorias, "selection": _diseno.seleccion.duplicate(true),
		"totals": {"mass_kg": _diseno.masa_total_kg(), "cost_musd": _diseno.costo_total_musd(),
			"capacity_kg": _diseno.capacidad_kg(), "power_w": _diseno.potencia_nominal_w(),
			"budget_musd": _reglas.presupuesto_musd},
		"validation": Array(validacion), "notices": Array(_diseno.avisos()), "valid": validacion.is_empty()}


func _resultado_simple(resultado: Dictionary) -> Dictionary:
	return {"ok": resultado["ok"], "reason": resultado["reason"]}


func _resultado_movimiento(resultado: Dictionary) -> Dictionary:
	if not resultado["ok"]:
		return {"ok": false, "reason": resultado["reason"]}
	return {"ok": true, "reason": "", "path": resultado["path"], "seconds_per_tile": resultado["seconds_per_tile"]}


## Objetivos con la forma del contrato; solo los revelados traen acciones y la principal.
func _objetivos_para_la_vista() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for objetivo in estado.objetivos:
		var entrada := {"id": objetivo["id"], "tile": objetivo["tile"], "type": objetivo["type"],
			"revealed": objetivo["revealed"], "depleted": objetivo["depleted"]}
		if objetivo["revealed"]:
			entrada["actions"] = _ciencia.acciones_de_objetivo(estado, objetivo["id"])
			entrada["primary"] = _ciencia.accion_principal(estado, objetivo["id"])
		lista.append(entrada)
	return lista


func _acciones_disponibles() -> Dictionary:
	var acciones := {}
	for accion in ACCIONES_VISTA:
		var objetivo := _seleccion if ScienceSystem.ACCIONES_CON_OBJETIVO.has(accion) else ""
		acciones[accion] = _ciencia.disponibilidad(estado, accion, objetivo)
	var acercar := _movimiento.disponibilidad_acercar(estado, _seleccion)
	if acercar["enabled"] and acercar["path"].is_empty():
		acciones["approach"] = {"enabled": false, "reason": "ALREADY_NEAR"}
	else:
		acciones["approach"] = {"enabled": acercar["enabled"], "reason": acercar["reason"]}
	acciones["transmit"] = _comunicaciones.disponibilidad(estado)
	acciones["upgrade"] = _ciencia.disponibilidad(estado, "upgrade")
	return acciones


## Avisos ordenados por prioridad: los críticos primero. Solo durante las operaciones.
func _avisos() -> Array[Dictionary]:
	var avisos: Array[Dictionary] = []
	if estado.fase != "operations":
		return avisos
	if estado.modo_seguro:
		avisos.append(_aviso("SAFE_MODE", "critical", []))
	var porcentaje_bateria := _porcentaje(estado.bateria_wh, estado.bateria_capacidad_wh)
	if not estado.modo_seguro and porcentaje_bateria <= _balance.numero("avisos.bateria_baja_pct"):
		avisos.append(_aviso("LOW_BATTERY", "warning", [porcentaje_bateria]))
	if estado.tormenta:
		avisos.append(_aviso("STORM_ACTIVE", "warning", []))
	elif estado.tormenta_en > 0.0 and estado.tormenta_en <= _balance.numero("avisos.tormenta_pronto_soles"):
		avisos.append(_aviso("STORM_SOON", "warning", [estado.tormenta_en]))
	var porcentaje_memoria := _porcentaje(estado.datos, estado.memoria_capacidad)
	if porcentaje_memoria >= _balance.numero("avisos.memoria_casi_llena_pct"):
		avisos.append(_aviso("MEMORY_ALMOST_FULL", "warning", [porcentaje_memoria]))
	if not estado.enlace_abierto and estado.proximo_cambio_enlace["opens"]:
		var horas := (int(estado.proximo_cambio_enlace["sol"]) - estado.sol) * ClockSystem.HORAS_POR_SOL + float(estado.proximo_cambio_enlace["hour"]) - estado.hora
		if horas > 0.0 and horas <= _balance.numero("avisos.enlace_pronto_h"):
			avisos.append(_aviso("LINK_OPENING_SOON", "warning", [horas]))
	return avisos


## "values" son los argumentos del formato del texto (como en las causas del informe): text % values.
func _aviso(id: String, severidad: String, valores: Array) -> Dictionary:
	return {"id": id, "severity": severidad, "key": "WARN_%s" % id, "values": valores}


func _porcentaje(valor: float, total: float) -> int:
	return int(roundf(valor / total * 100.0)) if total > 0.0 else 0


func _hay_evento(eventos: Array[String], prefijo: String) -> bool:
	for evento in eventos:
		if evento.begins_with(prefijo):
			return true
	return false
