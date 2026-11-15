extends GutTest
## Tutorial del Sol 1: pasos por eventos y estado, pasos adelantados, saltar, fin por sol y validación del JSON.

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro",
	"radar", "dron", "meteo", "companero"]

var sim: Simulation
var tutorial: TutorialData


func before_each() -> void:
	tutorial = TutorialData.desde_archivo("res://content/tutorial.json")
	sim = Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"), StoryData.desde_archivo("res://content/historia.json"), null, tutorial)
	for id in DISENO:
		assert_true(sim.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_true(sim.ejecutar("landing_finished")["ok"])


func _paso() -> String:
	return str(sim.snapshot()["tutorial"].get("id", ""))


func test_el_archivo_es_valido_y_esta_en_los_dos_idiomas() -> void:
	assert_eq(tutorial.errores.size(), 0, ", ".join(tutorial.errores))
	assert_gt(tutorial.pasos.size(), 4)
	for paso in tutorial.pasos:
		assert_true(paso["texto"].has("es") and paso["texto"].has("en"), paso["id"])


## Deja el tutorial en el paso «mover» (el jugador ya leyó la bienvenida).
func _hasta_mover() -> void:
	assert_eq(_paso(), "bienvenida")
	assert_true(sim.ejecutar("tutorial_next")["ok"])
	assert_eq(_paso(), "mover")


func test_empieza_en_el_primer_paso_con_su_cartel() -> void:
	var t: Dictionary = sim.snapshot()["tutorial"]
	assert_true(t["active"])
	assert_eq(t["step"], 1)
	assert_eq(t["total"], tutorial.pasos.size())
	assert_eq(t["id"], "bienvenida")
	assert_true(t["manual"], "la bienvenida solo avanza con «Siguiente»")
	assert_true(t["waiting"], "y el reloj espera")
	_hasta_mover()
	var m: Dictionary = sim.snapshot()["tutorial"]
	assert_eq(m["highlight"], "mapa")
	assert_eq(m["allowed"], ["move", "stop"])


func test_cada_paso_avanza_cuando_se_cumple() -> void:
	_hasta_mover()
	sim.estado.tutorial_contadores = {}
	# Mover: lo cuenta el evento de fin de movimiento.
	assert_true(sim.ejecutar("move", {"tile": Vector2i(2, 0)})["ok"])
	for i in range(400):
		sim.avanzar(0.1)
		if _paso() != "mover":
			break
	assert_eq(_paso(), "analizar")
	sim.estado.tutorial_contadores["ACTION_DONE"] = 1
	sim.ejecutar("tutorial_next")  # acciones: lectura (el diseño tiene cámara, radar y dron)
	assert_eq(_paso(), "acciones")
	sim.ejecutar("tutorial_next")
	assert_eq(_paso(), "panel", "la carga se salta: el rover no lleva nada")


func test_los_pasos_que_el_jugador_adelanta_se_saltan_solos() -> void:
	_hasta_mover()
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	sim.estado.nivel_antena = 1
	sim.estado.edificios.append({"id": "panel_solar-9", "type": "panel_solar", "tile": Vector2i(-6, -6), "level": 1, "target_level": 1,
		"elapsed": 5.0, "seconds": 5.0, "active": true, "hp": 100.0, "produced": 0.0, "cd": 0.0})
	var eventos := sim.avanzar(0.1)
	assert_eq(_paso(), "acciones", "mover y analizar ya estaban hechos; «acciones» es de lectura")
	assert_true(eventos.has("TUTORIAL_STEP:mover"))
	sim.ejecutar("tutorial_next")
	eventos = sim.avanzar(0.1)
	assert_eq(_paso(), "transmitir", "carga se salta; panel y antena ya estaban hechos")
	assert_true(eventos.has("TUTORIAL_STEP:panel"))
	assert_true(eventos.has("TUTORIAL_STEP:antena"))


func test_el_ultimo_paso_es_de_lectura_y_el_tutorial_termina() -> void:
	_hasta_mover()
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	sim.estado.nivel_antena = 1
	sim.estado.enviados = 3.0
	sim.estado.edificios.append({"id": "panel_solar-9", "type": "panel_solar", "tile": Vector2i(-6, -6), "level": 1, "target_level": 1,
		"elapsed": 5.0, "seconds": 5.0, "active": true, "hp": 100.0, "produced": 0.0, "cd": 0.0})
	sim.avanzar(0.1)
	sim.ejecutar("tutorial_next")  # acciones (lectura)
	sim.avanzar(0.1)  # panel, antena y transmitir ya estaban hechos
	assert_eq(_paso(), "noche")
	assert_true(sim.snapshot()["tutorial"]["manual"])
	sim.ejecutar("tutorial_next")
	assert_false(sim.snapshot()["tutorial"]["active"], "«Siguiente» en el último cartel termina el tutorial")
	assert_false(sim.estado.tutorial_espera, "y el reloj vuelve a correr")


func test_saltar_cierra_el_tutorial() -> void:
	assert_true(sim.ejecutar("tutorial_skip")["ok"])
	assert_false(sim.snapshot()["tutorial"]["active"])
	sim.avanzar(0.2)
	assert_false(sim.snapshot()["tutorial"]["active"], "no vuelve")


func test_al_pasar_del_sol_limite_se_cierra_solo() -> void:
	sim.estado.sol = tutorial.hasta_sol + 1
	sim.avanzar(0.1)
	assert_false(sim.snapshot()["tutorial"]["active"])


func test_no_cuenta_nada_antes_de_operar_ni_en_pausa() -> void:
	_hasta_mover()
	sim.ejecutar("pause", {"paused": true})
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1}
	sim.avanzar(0.5)
	assert_eq(_paso(), "mover", "en pausa no avanza nada")


func test_sin_tutorial_la_orden_no_existe_y_el_snapshot_no_lo_trae() -> void:
	var s := Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"))
	assert_false(s.snapshot().has("tutorial"))
	assert_false(s.ejecutar("tutorial_skip")["ok"])


func test_el_estado_del_tutorial_se_guarda_y_se_carga() -> void:
	_hasta_mover()
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1}
	sim.avanzar(0.1)
	assert_eq(_paso(), "analizar")
	var guardado := sim.guardar()
	sim.ejecutar("tutorial_skip")
	assert_true(sim.cargar(guardado))
	assert_eq(_paso(), "analizar")


func test_validacion_del_archivo() -> void:
	var malo := TutorialData.desde_texto('{"pasos": [{"id": "a", "texto": {"es": "x"}, "condicion": {"tipo": "edificio", "min": 1}}, {"id": "a", "resalta": "luna", "condicion": {}}]}')
	for codigo in ["MISSING_TEXT:a", "INVALID_CONDITION:a", "DUPLICATE_STEP:a", "UNKNOWN_HIGHLIGHT:a"]:
		assert_true(malo.errores.has(codigo), codigo)
	assert_true(TutorialData.desde_texto("no es json").errores.has("INVALID_JSON"))
	assert_true(TutorialData.desde_texto("{}").errores.has("MISSING_FIELD:pasos"))


# --- Bloqueo del tutorial (15 nov) --------------------------------------------------------------------------------

func test_el_reloj_espera_a_que_el_jugador_actue_en_cada_paso() -> void:
	_hasta_mover()
	var hora := sim.estado.hora
	for i in range(50):
		sim.avanzar(1.0)
	assert_eq(sim.estado.hora, hora, "con el cartel esperando, el reloj no corre")
	assert_true(sim.ejecutar("move", {"tile": Vector2i(2, 0)})["ok"])
	assert_false(sim.estado.tutorial_espera, "al actuar, el reloj corre")
	for i in range(40):
		sim.avanzar(1.0)
	assert_gt(sim.estado.hora, hora)


func test_las_ordenes_que_el_paso_no_permite_se_rechazan() -> void:
	_hasta_mover()
	var r := sim.ejecutar("transmit", {"on": true})
	assert_false(r["ok"])
	assert_eq(r["reason"], "TUTORIAL_LOCKED")
	assert_eq(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-6, -6)})["reason"], "TUTORIAL_LOCKED")
	assert_eq(sim.ejecutar("upgrade")["reason"], "TUTORIAL_LOCKED")
	assert_true(sim.ejecutar("move", {"tile": Vector2i(2, 0)})["ok"], "lo que pide el paso sí")
	assert_true(sim.ejecutar("pause", {"paused": true})["ok"], "pausar siempre se puede")
	sim.ejecutar("pause", {"paused": false})


func test_saltar_el_tutorial_desbloquea_todo() -> void:
	_hasta_mover()
	sim.ejecutar("tutorial_skip")
	assert_ne(sim.ejecutar("transmit", {"on": true})["reason"], "TUTORIAL_LOCKED")
	assert_false(sim.estado.tutorial_espera)


func test_los_pasos_de_herramientas_dependen_de_lo_que_lleva_el_rover() -> void:
	# Sin cámara, radar, dron ni compañero no hay paso «acciones»; sin carga, tampoco «carga».
	var s := Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"), StoryData.desde_archivo("res://content/historia.json"), null, tutorial)
	for id in ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "espectrometro", "taladro"]:
		assert_true(s.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(s.ejecutar("design_start")["ok"])
	assert_true(s.ejecutar("landing_finished")["ok"])
	s.ejecutar("tutorial_next")  # bienvenida
	s.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	s.avanzar(0.1)
	assert_eq(str(s.snapshot()["tutorial"]["id"]), "panel", "sin herramientas extra ni carga, de «analizar» pasa a «panel»")
	assert_eq(s.snapshot()["tutorial"]["tools"], ["spectrometer", "drill"])


func test_el_paso_de_carga_sale_si_el_rover_lleva_algo() -> void:
	_hasta_mover()
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	sim.estado.carga = {"rocas": 12}
	sim.avanzar(0.1)
	sim.ejecutar("tutorial_next")  # acciones
	assert_eq(_paso(), "carga")
	assert_eq(sim.snapshot()["tutorial"]["highlight"], "carga")
	assert_true(sim.snapshot()["tutorial"]["allowed"].has("unload"))


func test_el_snapshot_trae_las_casillas_de_los_almacenes() -> void:
	sim.ejecutar("tutorial_skip")
	sim.estado.carga = {"rocas": 5}
	var cargo: Dictionary = sim.snapshot()["cargo"]
	assert_true(cargo.has("storages"))
	assert_true((cargo["storages"] as Array).has(sim.estado.casilla_estacion))


func test_los_dos_tutoriales_son_validos_y_empiezan_por_la_bienvenida() -> void:
	for ruta in ["res://content/tutorial.json", "res://content/tutorial_luna.json"]:
		var d := TutorialData.desde_archivo(ruta)
		assert_eq(d.errores.size(), 0, ", ".join(d.errores))
		assert_eq(str(d.pasos[0]["id"]), "bienvenida", ruta)
		for paso in d.pasos:
			for orden in paso.get("permite", []):
				assert_true(TutorialData.ORDENES_DE_JUEGO.has(orden), "%s: %s" % [paso["id"], orden])
