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
var _economia: Economy  ## null: misión sin base ni recursos (pruebas antiguas)
var _datos_historia: StoryData  ## null: misión sin historia
var _datos_combate: CombatData  ## null: misión sin monstruos (necesita también economía)
var _datos_tutorial: TutorialData  ## null: sin tutorial
var _recursos: ResourceSystem
var _edificios: BuildSystem
var _historia: StorySystem
var _combate: CombatSystem
var _tutorial: TutorialSystem
var _seleccion: String = ""
var _potencia_nominal_w: float = 0.0  ## del panel o RTG elegido; hace falta para reconstruir los sistemas al cargar
var _revision_mapa: int = 0  ## sube en cada reiniciar(): la vista reconstruye el mapa


## «economia», «historia» y «combate» son opcionales: sin ellas la misión es la de exploración y ciencia de siempre.
## El combate (monstruos y torretas) necesita la economía, porque las torretas son edificios.
func _init(balance: Balance, reglas: Rules, mapa: MapData, catalogo: Catalog, economia: Economy = null,
		historia: StoryData = null, combate: CombatData = null, tutorial: TutorialData = null) -> void:
	_balance = balance
	_reglas = reglas
	_mapa = mapa
	_catalogo = catalogo
	_economia = economia
	_datos_historia = historia
	_datos_combate = combate
	_datos_tutorial = tutorial
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
	_mapa.bloqueos_extra.clear()
	_construir_sistemas(0.0)
	if _recursos != null:
		_recursos.iniciar(estado)
	if _edificios != null:
		_edificios.iniciar(estado)
	if _historia != null:
		_historia.iniciar(estado)
	if _tutorial != null:
		_tutorial.iniciar(estado)
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
			var casilla: Vector2i = carga.get("tile", Vector2i.ZERO)
			return _con_redireccion(func() -> Dictionary: return _mover(casilla))
		"approach":
			var objetivo_id := str(carga.get("target_id", _seleccion))
			return _con_redireccion(func() -> Dictionary: return _acercar(objetivo_id))
		"stop":
			return _detener()
		"act":
			return _actuar(str(carga.get("action", "")), str(carga.get("target_id", _seleccion)))
		"transmit":
			return _resultado_simple(_comunicaciones.transmitir(estado, bool(carga.get("on", false))))
		"upgrade":
			if _edificios != null:
				return _resultado_simple(_edificios.mejorar_antena(estado))
			return _resultado_simple(_ciencia.mejorar_antena(estado))
		"build":
			if _edificios == null:
				return {"ok": false, "reason": "UNKNOWN_COMMAND"}
			return _resultado_simple(_edificios.construir(estado, str(carga.get("building", "")), carga.get("tile", Vector2i(9999, 9999))))
		"build_module":
			if _edificios == null:
				return {"ok": false, "reason": "UNKNOWN_COMMAND"}
			return _resultado_simple(_edificios.construir_modulo(estado, str(carga.get("id", ""))))
		"toggle_building":
			if _edificios == null:
				return {"ok": false, "reason": "UNKNOWN_COMMAND"}
			return _resultado_simple(_edificios.alternar(estado, str(carga.get("id", "")), bool(carga.get("on", true))))
		"decide":
			if _historia == null:
				return {"ok": false, "reason": "UNKNOWN_COMMAND"}
			var decision := _historia.decidir(estado, int(carga.get("choice", -1)))
			if decision["ok"] and decision["ends"]:
				estado.historia_final = StorySystem.FINAL_DERROTA
			if decision["ok"]:
				_fijar_tope_envio()  # un clímax decidido sube el tope de envío al instante
			return _resultado_simple(decision)
		"tutorial_skip":
			if _tutorial == null:
				return {"ok": false, "reason": "UNKNOWN_COMMAND"}
			_tutorial.omitir(estado)
			return {"ok": true, "reason": ""}
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
	if _historia != null and _historia.esperando_decision(estado):
		return eventos  # la misión espera la decisión del jugador
	var horas := _reloj.horas_de_juego(delta_s)
	_fijar_tope_envio()
	eventos.append_array(_energia.avanzar(estado, horas))
	var eventos_reloj := _reloj.avanzar(estado, delta_s)
	eventos.append_array(eventos_reloj)
	for evento in eventos_reloj:
		if evento == ClockSystem.EVENTO_SOL_NUEVO:
			eventos.append_array(_ciencia.al_nuevo_sol(estado))
	var habia_accion := not estado.accion_en_curso.is_empty()
	var eventos_ciencia := _ciencia.avanzar(estado, delta_s)
	eventos.append_array(eventos_ciencia)
	if _combate != null:
		_combate.reaccionar(estado, eventos_ciencia)
	if habia_accion and estado.accion_en_curso.is_empty() and not _hay_evento(eventos_ciencia, ScienceSystem.EVENTO_ACCION_TERMINADA):
		eventos.append(EVENTO_ACCION_CANCELADA)
	eventos.append_array(_movimiento.avanzar(estado, delta_s))
	eventos.append_array(_comunicaciones.avanzar(estado, delta_s))
	if _edificios != null:
		eventos.append_array(_edificios.avanzar(estado, delta_s, horas))
	if _combate != null:
		eventos.append_array(_combate.avanzar(estado, delta_s, horas, _energia))
	if _tutorial != null:
		eventos.append_array(_tutorial.avanzar(estado, delta_s, eventos))
	informe = _resultado.evaluar(estado, eventos)
	if not informe.is_empty():
		_completar_informe()
		eventos.append(EVENTO_MISION_TERMINADA)
	elif _historia != null:
		eventos.append_array(_historia.comprobar(estado))
	return eventos


## Snapshot completo para la vista: el del estado más objetivos con sus acciones, avisos y
## disponibilidad de cada acción.
func snapshot() -> Dictionary:
	var datos := estado.a_snapshot()
	datos["targets"] = _objetivos_para_la_vista()
	datos["warnings"] = _avisos()
	datos["available_actions"] = _acciones_disponibles()
	datos["zones"] = _mapa.zonas_para_la_vista()
	datos["rover_zone"] = _mapa.zona_de(estado.casilla_rover)
	if estado.fase == "workshop":
		datos["workshop"] = _taller()
	if _economia != null:
		datos["resources"] = estado.recursos.duplicate()
		datos["resource_capacity"] = _recursos.capacidad(estado)
		datos["buildings"] = _edificios.para_la_vista(estado)
		datos["build_options"] = _edificios.opciones(estado)
		datos["base"] = {"center": estado.casilla_estacion, "radius": _economia.zona_base_radio,
			"antenna_tile": _edificios.casilla_antena(estado), "antenna_max": _economia.nivel_antena_max(),
			"antenna_next_cost": _edificios.costo_siguiente_antena(estado)}
	if _historia != null:
		datos["story"] = _historia.para_la_vista(estado)
	if _tutorial != null:
		datos["tutorial"] = _tutorial.para_la_vista(estado)
	if _combate != null:
		datos["combat"] = _combate.para_la_vista(estado)
		datos["nests"] = _mapa.nidos_para_la_vista()
	return datos


## Pantallas de introducción de la historia (vacío si no hay historia).
func intro_historia() -> Array:
	return _historia.intro() if _historia != null else []


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
	if _edificios != null:
		_edificios.sincronizar_mapa(estado)
	_reloj.actualizar(estado)
	return true


## true mientras hay monstruos, rayos o meteoritos en pantalla: la vista necesita datos nuevos cada cuadro.
func hay_combate_activo() -> bool:
	return _combate != null and estado.fase == "operations" and (not estado.enemigos.is_empty() or not estado.disparos.is_empty()
		or not estado.impactos.is_empty())


func objetivo_seleccionado() -> String:
	return _seleccion


func _construir_sistemas(potencia_nominal_w: float) -> void:
	_reloj = ClockSystem.new(_balance, _reglas)
	_energia = EnergySystem.new(_balance, potencia_nominal_w)
	_ciencia = ScienceSystem.new(_balance, _energia)
	_comunicaciones = CommsSystem.new(_balance)
	_movimiento = MovementSystem.new(_balance, _energia, _mapa)
	_resultado = OutcomeSystem.new(_reglas)
	_recursos = null
	_edificios = null
	_historia = null
	_combate = null
	_tutorial = null
	if _economia != null:
		_recursos = ResourceSystem.new(_economia)
		_edificios = BuildSystem.new(_economia, _recursos, _mapa)
		_energia.edificios = _edificios
		_ciencia.recursos = _recursos
		if _datos_combate != null:
			_combate = CombatSystem.new(_datos_combate, _economia, _edificios, _mapa)
	if _datos_historia != null:
		_historia = StorySystem.new(_datos_historia, _recursos)
		_resultado.requiere_final = true
		if _economia != null and _economia.tiene_edificio(_datos_historia.nave):
			_resultado.requiere_nave = _datos_historia.nave
			_resultado.requiere_nave_nivel = maxi(_economia.modulos_de(_datos_historia.nave).size(), 1)
	if _datos_tutorial != null:
		_tutorial = TutorialSystem.new(_datos_tutorial, _edificios)


func _seleccionar(objetivo_id: String) -> Dictionary:
	if objetivo_id.is_empty():
		_seleccion = ""
		return {"ok": true, "reason": ""}
	for objetivo in estado.objetivos:
		if objetivo["id"] == objetivo_id and objetivo["revealed"]:
			_seleccion = objetivo_id
			return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "NO_TARGET"}


## Detiene la marcha del rover (Esc). {"ok", "reason", "path": tramo que le queda por terminar, "seconds_per_tile"}.
func _detener() -> Dictionary:
	if not estado.en_movimiento or estado.movimiento_en_curso.is_empty():
		return {"ok": false, "reason": "NOT_MOVING"}
	var segundos := float(estado.movimiento_en_curso["seconds_per_tile"])
	var tramo := _movimiento.detener(estado)
	return {"ok": true, "reason": "", "path": tramo, "seconds_per_tile": segundos}


## Con el rover en marcha, una orden de ir a otro sitio reemplaza a la anterior: el rover termina el tramo que está
## recorriendo y sale desde esa casilla. Si la orden nueva no se puede cumplir, la marcha anterior sigue igual.
func _con_redireccion(iniciar: Callable) -> Dictionary:
	if not estado.en_movimiento or estado.movimiento_en_curso.is_empty() or estado.fase != "operations" or estado.pausado:
		return iniciar.call()
	var copia := {"mov": estado.movimiento_en_curso.duplicate(true), "casilla": estado.casilla_rover, "wh": estado.bateria_wh}
	var tramo := _movimiento.detener(estado)
	var resultado: Dictionary = iniciar.call()
	if not resultado["ok"]:
		estado.movimiento_en_curso = copia["mov"]
		estado.casilla_rover = copia["casilla"]
		estado.bateria_wh = copia["wh"]
		estado.en_movimiento = true
		return resultado
	resultado["redirected"] = true
	if not tramo.is_empty() and not Array(resultado.get("path", [])).is_empty():
		# La vista termina primero el tramo en curso y luego sigue el camino nuevo, sin cortar en diagonal.
		var camino: Array = tramo.duplicate()
		camino.append_array(resultado["path"])
		resultado["path"] = camino
	elif Array(resultado.get("path", [])).is_empty():
		# El destino nuevo es la casilla donde se detiene: solo falta terminar el tramo en curso.
		resultado["path"] = tramo
		if not resultado.has("seconds_per_tile") or float(resultado["seconds_per_tile"]) <= 0.0:
			resultado["seconds_per_tile"] = float(copia["mov"]["seconds_per_tile"])
	return resultado


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
	if _historia != null:
		_historia.comprobar(estado)
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
			var acciones := _ciencia.acciones_de_objetivo(estado, objetivo["id"])
			entrada["actions"] = acciones
			entrada["primary"] = _ciencia.principal_de(acciones, objetivo)
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
	acciones["upgrade"] = _ciencia.disponibilidad(estado, "upgrade") if _edificios == null else _edificios.disponibilidad_antena(estado)
	return acciones


## Con historia, la ciencia enviada se queda en el 85 % de la meta hasta decidir el clímax: el 100 llega al final.
const TOPE_ANTES_DEL_CLIMAX := 0.85


func _fijar_tope_envio() -> void:
	if _historia == null:
		estado.envio_max = -1.0
	elif estado.historia_final.is_empty():
		estado.envio_max = float(estado.meta) * TOPE_ANTES_DEL_CLIMAX
	else:
		estado.envio_max = float(estado.meta)  # decidido el clímax, la ciencia llega al 100 % y no pasa de ahí


## Con historia, el informe dice el final, la ética, la vida de Rocky y las decisiones tomadas.
func _completar_informe() -> void:
	if _historia == null:
		return
	var id := _historia.final_de(estado, bool(informe.get("success", false)))
	var final := _historia.datos_final(id)
	var vista := _historia.para_la_vista(estado)
	informe["ending"] = {"id": id, "title": final.get("titulo", {}), "text": final.get("texto", {}),
		"image": str(final.get("imagen", ""))}
	informe["ethics"] = estado.etica
	informe["rocky_hp"] = estado.rocky_hp
	informe["story_log"] = vista["log"]


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
	if estado.envio_max >= 0.0 and estado.enviados >= estado.envio_max and estado.historia_final.is_empty():
		avisos.append(_aviso("SIGNAL_CAPPED", "warning", []))
	if estado.tormenta:
		avisos.append(_aviso("STORM_ACTIVE", "warning", []))
	elif estado.tormenta_en > 0.0 and estado.tormenta_en <= _balance.numero("avisos.tormenta_pronto_soles"):
		avisos.append(_aviso("STORM_SOON", "warning", [estado.tormenta_en]))
	if _combate != null:
		for entrada in _combate.avisos(estado):
			avisos.append(_aviso(entrada[0], entrada[1], entrada[2]))
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
