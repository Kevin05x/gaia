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


func test_empieza_en_el_primer_paso_con_su_cartel() -> void:
	var t: Dictionary = sim.snapshot()["tutorial"]
	assert_true(t["active"])
	assert_eq(t["step"], 1)
	assert_eq(t["total"], tutorial.pasos.size())
	assert_eq(t["id"], "mover")
	assert_eq(t["highlight"], "mapa")


func test_cada_paso_avanza_cuando_se_cumple() -> void:
	sim.avanzar(0.1)
	assert_eq(_paso(), "mover")
	sim.estado.tutorial_contadores = {}
	# Mover: lo cuenta el evento de fin de movimiento.
	assert_true(sim.ejecutar("move", {"tile": Vector2i(2, 0)})["ok"])
	for i in range(400):
		sim.avanzar(0.1)
		if _paso() != "mover":
			break
	assert_eq(_paso(), "analizar")
	sim.estado.tutorial_contadores["ACTION_DONE"] = 1
	sim.avanzar(0.1)
	assert_eq(_paso(), "panel")


func test_los_pasos_que_el_jugador_adelanta_se_saltan_solos() -> void:
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	sim.estado.nivel_antena = 1
	sim.estado.edificios.append({"id": "panel_solar-9", "type": "panel_solar", "tile": Vector2i(-6, -6), "level": 1, "target_level": 1,
		"elapsed": 5.0, "seconds": 5.0, "active": true, "hp": 100.0, "produced": 0.0, "cd": 0.0})
	var eventos := sim.avanzar(0.1)
	assert_eq(_paso(), "transmitir", "mover, analizar, panel y antena ya estaban hechos")
	assert_true(eventos.has("TUTORIAL_STEP:panel"))
	assert_true(eventos.has("TUTORIAL_STEP:antena"))


func test_el_ultimo_paso_es_de_lectura_y_el_tutorial_termina() -> void:
	sim.estado.tutorial_contadores = {"MOVE_DONE": 1, "ACTION_DONE": 1}
	sim.estado.nivel_antena = 1
	sim.estado.enviados = 3.0
	sim.estado.edificios.append({"id": "panel_solar-9", "type": "panel_solar", "tile": Vector2i(-6, -6), "level": 1, "target_level": 1,
		"elapsed": 5.0, "seconds": 5.0, "active": true, "hp": 100.0, "produced": 0.0, "cd": 0.0})
	sim.avanzar(0.1)
	assert_eq(_paso(), "noche")
	var fin := false
	for i in range(200):
		if sim.avanzar(0.2).has("TUTORIAL_DONE"):
			fin = true
			break
	assert_true(fin, "tras leer el último cartel termina")
	assert_false(sim.snapshot()["tutorial"]["active"])


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
