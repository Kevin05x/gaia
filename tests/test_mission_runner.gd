extends GutTest
## Pruebas de MissionRunner sin la vista 3D: se le asigna un Port y se mira lo que emite.

const PortScript := preload("res://scenes/b/port.gd")

var runner: MissionRunner
var port: Node
var snapshots: Array[Dictionary] = []
var rutas: Array[Dictionary] = []
var acciones: Array[Dictionary] = []
var rechazos: Array[String] = []
var informes: Array[Dictionary] = []
var cancelaciones: Array[int] = []


func before_each() -> void:
	snapshots.clear()
	rutas.clear()
	acciones.clear()
	rechazos.clear()
	informes.clear()
	cancelaciones.clear()
	port = autofree(PortScript.new())
	port.snapshot_received.connect(func(datos: Dictionary) -> void: snapshots.append(datos))
	port.path_received.connect(func(casillas: Array, segundos: float) -> void: rutas.append({"tiles": casillas, "seconds": segundos}))
	port.action_received.connect(func(accion: Dictionary) -> void: acciones.append(accion))
	port.rejected.connect(func(clave: String) -> void: rechazos.append(clave))
	port.report_received.connect(func(informe: Dictionary) -> void: informes.append(informe))
	port.cancel_received.connect(func() -> void: cancelaciones.append(1))
	runner = MissionRunner.new()
	runner.crear_vista = false
	runner.saltar_taller = true  # estas pruebas operan directo; el taller se prueba en test_taller y test_ui_rediseno
	runner.port = port
	add_child_autofree(runner)


func _ultimo() -> Dictionary:
	return snapshots[snapshots.size() - 1]


func _operar() -> void:
	port.submit("landing_finished")
	assert_eq(_ultimo()["phase"], "operations")
	_resolver_historia()


## La historia detiene la misión en cada nodo hasta que se decide: estas pruebas eligen siempre la primera opción.
func _resolver_historia() -> void:
	for i in range(10):
		if _ultimo().get("story", {}).get("pending", {}).is_empty():
			return
		port.submit("decide", {"choice": 0})


func test_los_datos_cargan_sin_errores() -> void:
	assert_eq(runner.errores.size(), 0, "errores: %s" % [runner.errores])
	assert_true(port.connected_backend)


func test_empieza_en_el_aterrizaje_con_el_diseno_inicial() -> void:
	assert_gt(snapshots.size(), 0, "publica un snapshot al empezar")
	var datos := _ultimo()
	assert_eq(datos["phase"], "landing")
	assert_eq(datos["targets"].size(), 39)
	assert_eq(datos["design"]["power"], "solar")
	assert_has(datos["design"]["instruments"], "panorama")
	assert_true(datos["design"]["companion"])


func test_el_tiempo_no_corre_hasta_terminar_el_aterrizaje() -> void:
	var hora: float = _ultimo()["hour"]
	runner._process(0.2)
	runner._process(0.2)
	assert_eq(_ultimo()["hour"], hora)
	_operar()
	runner._process(0.2)
	runner._process(0.2)
	assert_gt(_ultimo()["hour"], hora)


func test_mover_presenta_la_ruta_y_confirma_la_posicion_al_llegar() -> void:
	_operar()
	port.submit("move", {"tile": Vector2i(3, 0)})
	assert_eq(rutas.size(), 1)
	assert_eq(rutas[0]["tiles"].size(), 3)
	assert_eq(rutas[0]["seconds"], 0.65)
	assert_true(_ultimo()["moving"])
	assert_eq(_ultimo()["rover_tile"], Vector2i(0, 0))
	for i in 8:
		runner._process(0.25)
	assert_false(_ultimo()["moving"])
	assert_eq(_ultimo()["rover_tile"], Vector2i(3, 0))


func test_rechaza_con_el_motivo_y_no_presenta_nada() -> void:
	_operar()
	port.submit("move", {"tile": Vector2i(4, 0)})
	assert_eq(rechazos, ["NO_PATH"])
	assert_eq(rutas.size(), 0)
	port.submit("act", {"target_id": "JZ-01", "action": "drill"})
	assert_eq(rechazos, ["NO_PATH", "TOO_FAR"])
	assert_eq(acciones.size(), 0)


func test_una_accion_se_presenta_y_revela_objetivos_al_terminar() -> void:
	_operar()
	port.submit("act", {"action": "panorama"})
	assert_eq(acciones.size(), 1)
	assert_eq(acciones[0]["action"], "panorama")
	assert_true(_ultimo()["busy"])
	for i in 12:
		runner._process(0.25)
	assert_false(_ultimo()["busy"])
	var revelado := false
	for objetivo in _ultimo()["targets"]:
		if objetivo["id"] == "JZ-09":
			revelado = objetivo["revealed"]
	assert_true(revelado, "la panorámica revela el mineral oculto")


func test_la_pausa_congela_la_mision() -> void:
	_operar()
	port.submit("pause", {"paused": true})
	assert_true(_ultimo()["paused"])
	var hora: float = _ultimo()["hour"]
	for i in 4:
		runner._process(0.25)
	assert_eq(_ultimo()["hour"], hora)
	port.submit("pause", {"paused": false})
	runner._process(0.25)
	assert_gt(_ultimo()["hour"], hora)


func test_un_cuadro_muy_largo_no_adelanta_la_mision() -> void:
	_operar()
	var hora: float = _ultimo()["hour"]
	runner._process(30.0)
	assert_lt(_ultimo()["hour"] - hora, 0.05)


func test_publica_snapshots_periodicos() -> void:
	_operar()
	var antes := snapshots.size()
	runner._process(0.05)
	runner._process(0.05)
	assert_eq(snapshots.size(), antes, "todavía no toca")
	runner._process(0.06)
	assert_eq(snapshots.size(), antes + 1)


func test_el_modo_seguro_cancela_lo_que_se_presentaba() -> void:
	_operar()
	runner.sim.estado.hora = 3.0
	port.submit("act", {"action": "panorama"})
	runner.sim.estado.bateria_wh = 0.0
	var antes := cancelaciones.size()
	runner._process(0.25)
	assert_gt(cancelaciones.size(), antes)
	assert_true(_ultimo()["safe_mode"])
	assert_false(_ultimo()["busy"])


func test_al_ganar_publica_la_fase_informe_y_despues_el_informe() -> void:
	_operar()
	runner.sim.estado.enviados = runner.sim.estado.meta
	runner.sim.estado.historia_final = "simbiosis"  # con historia, la victoria llega tras el clímax
	runner.sim.estado.edificios.append({"id": "nave_fuga-9", "type": "nave_fuga", "tile": Vector2i(-5, -5), "level": 4, "target_level": 4, "elapsed": 12.0, "seconds": 12.0, "active": true, "hp": 400.0, "produced": 0.0, "cd": 0.0})  # y tras construir la nave de fuga
	runner._process(0.1)
	assert_eq(_ultimo()["phase"], "report")
	assert_eq(informes.size(), 1)
	assert_true(informes[0]["success"])
	assert_eq(informes[0]["causes"][0], "CAUSE_SUCCESS")
	assert_gt(informes[0]["stars"], 0)
	var informes_antes := informes.size()
	runner._process(0.25)
	assert_eq(informes.size(), informes_antes, "el informe sale una sola vez")


func test_redisenar_vuelve_a_empezar_con_el_mapa_limpio() -> void:
	_operar()
	port.submit("move", {"tile": Vector2i(3, 0)})
	var revision: int = _ultimo()["map_revision"]
	runner.sim.estado.enviados = runner.sim.estado.meta
	runner.sim.estado.historia_final = "simbiosis"  # con historia, la victoria llega tras el clímax
	runner.sim.estado.edificios.append({"id": "nave_fuga-9", "type": "nave_fuga", "tile": Vector2i(-5, -5), "level": 4, "target_level": 4, "elapsed": 12.0, "seconds": 12.0, "active": true, "hp": 400.0, "produced": 0.0, "cd": 0.0})  # y tras construir la nave de fuga
	runner._process(0.1)
	assert_eq(_ultimo()["phase"], "report")
	port.submit("redesign")
	var datos := _ultimo()
	assert_eq(datos["phase"], "landing")
	assert_eq(datos["rover_tile"], Vector2i(0, 0))
	assert_eq(datos["sent"], 0.0)
	assert_gt(datos["map_revision"], revision, "la vista reconstruye el mapa")
	assert_true(runner.sim.informe.is_empty())
	_operar()
	runner._process(0.25)
	assert_eq(informes.size(), 1, "no hay un segundo informe")
