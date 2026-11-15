class_name TutorialSystem
extends RefCounted
## Tutorial del Sol 1 (content/tutorial.json): lleva la cuenta de los eventos que le interesan, da por hechos los
## pasos cuando se cumple su condición (también los que el jugador adelanta) y avisa a la vista del paso actual.
## Mientras dura, guía de verdad (plan 2.2 reforzado):
##  · cada paso dice qué órdenes de juego permite («permite»); el resto se rechaza con TUTORIAL_LOCKED;
##  · con «espera» el reloj de la misión está detenido hasta que el jugador hace algo permitido;
##  · «requiere_instrumento» y «requiere_carga» saltan el paso si el rover no tiene esa herramienta o esa carga.
## «Siguiente» y «Saltar» funcionan siempre.

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
	estado.tutorial_visto = -1
	estado.tutorial_espera = false
	if estado.tutorial_activo:
		estado.tutorial_espera = bool(_datos.pasos[0].get("espera", false))


## Antes de avanzar el reloj: deja listo el paso actual (salta los que no aplican y fija si el reloj espera).
func preparar(estado: MissionState) -> void:
	if estado.tutorial_activo and estado.tutorial_visto != estado.tutorial_paso:
		_entrar(estado)


## ¿Se acepta esta orden ahora? Solo las de juego se pueden bloquear.
func permite(estado: MissionState, orden: String) -> bool:
	if not estado.tutorial_activo or estado.fase != "operations" or not TutorialData.ORDENES_DE_JUEGO.has(orden):
		return true
	var paso := paso_actual(estado)
	if paso.is_empty() or not paso.has("permite"):
		return true
	return (paso["permite"] as Array).has(orden)


## Una orden permitida salió bien: el paso ya está en marcha y el reloj vuelve a correr.
func al_ordenar(estado: MissionState, orden: String) -> void:
	if estado.tutorial_activo and TutorialData.ORDENES_DE_JUEGO.has(orden):
		estado.tutorial_espera = false


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
		_entrar(estado)
	if estado.tutorial_paso >= _datos.pasos.size() or estado.sol > _datos.hasta_sol:
		_terminar(estado)
		salida.append(EVENTO_FIN)
	return salida


## El jugador cierra el tutorial.
func omitir(estado: MissionState) -> void:
	_terminar(estado)


## «Siguiente»: el jugador da por visto el paso actual sin cumplirlo. Tras el último, el tutorial termina.
func siguiente(estado: MissionState) -> void:
	if not estado.tutorial_activo:
		return
	estado.tutorial_paso += 1
	_entrar(estado)
	if estado.tutorial_paso >= _datos.pasos.size():
		_terminar(estado)


func paso_actual(estado: MissionState) -> Dictionary:
	if not estado.tutorial_activo or estado.tutorial_paso >= _datos.pasos.size():
		return {}
	return _datos.pasos[estado.tutorial_paso]


## Lo que la vista necesita: si hay un cartel, su contenido, qué se puede hacer y si el reloj espera.
func para_la_vista(estado: MissionState) -> Dictionary:
	var paso := paso_actual(estado)
	if paso.is_empty():
		return {"active": false}
	var permitidas: Array = paso.get("permite", TutorialData.ORDENES_DE_JUEGO)
	return {"active": true, "step": estado.tutorial_paso + 1, "total": _datos.pasos.size(), "id": str(paso["id"]),
		"text": paso["texto"], "highlight": str(paso.get("resalta", "")), "image": str(paso.get("captura", paso["id"])),
		"allowed": permitidas.duplicate(), "waiting": estado.tutorial_espera, "manual": paso["condicion"].has("manual"),
		"tools": estado.instrumentos.duplicate(), "companion": estado.companero}


func _terminar(estado: MissionState) -> void:
	estado.tutorial_activo = false
	estado.tutorial_espera = false


## Prepara el paso al que se acaba de llegar: salta los que no aplican a este rover y fija si el reloj espera.
func _entrar(estado: MissionState) -> void:
	estado.tutorial_t = 0.0
	while estado.tutorial_paso < _datos.pasos.size() and not _aplica(estado, _datos.pasos[estado.tutorial_paso]):
		estado.tutorial_paso += 1
	estado.tutorial_visto = estado.tutorial_paso
	estado.tutorial_espera = estado.tutorial_paso < _datos.pasos.size() and bool(_datos.pasos[estado.tutorial_paso].get("espera", false))


func _aplica(estado: MissionState, paso: Dictionary) -> bool:
	if paso.has("requiere_instrumento"):
		var tiene := false
		for id in paso["requiere_instrumento"]:
			if estado.instrumentos.has(str(id)) or (str(id) == "companion" and estado.companero):
				tiene = true
		if not tiene:
			return false
	if bool(paso.get("requiere_carga", false)):
		var total := 0
		for cantidad in estado.carga.values():
			total += int(cantidad)
		if total <= 0:
			return false
	return true


func _contar(estado: MissionState, clave: String) -> void:
	estado.tutorial_contadores[clave] = int(estado.tutorial_contadores.get(clave, 0)) + 1


func _cumple(estado: MissionState, condicion: Dictionary) -> bool:
	if condicion.has("manual"):
		return false
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
