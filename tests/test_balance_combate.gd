extends GutTest
## Curva de dificultad del combate con los datos reales: sin torretas la primera oleada hunde la base,
## con una torreta se sobrevive salvo al coloso, y con dos torretas se aguantan todas las oleadas.

var economia: Economy
var combate: CombatData


func before_each() -> void:
	economia = Economy.desde_archivo("res://content/economia.json")
	combate = CombatData.desde_archivo("res://content/combate.json")


## Lanza solo la oleada indicada contra N torretas de nivel 1 y devuelve el estado al terminar.
func _defender(ola_id: String, torretas: int) -> MissionState:
	var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"), economia,
		StoryData.desde_archivo("res://content/historia.json"), combate, null)
	for id in ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	var e := sim.estado
	e.historia_nodo = ""
	e.historia_espera = "zz"
	e.historia_t_ultimo = 1e9
	var ola := {}
	for o in combate.oleadas:
		e.oleadas_hechas.append(o["id"])
		if o["id"] == ola_id:
			ola = o
	e.sol = int(ola["sol"])
	e.hora = float(ola["hora"])
	e.casilla_rover = e.casilla_estacion + Vector2i(1, 1)
	# Base típica: dos paneles, un domo y un hangar alrededor de la estación.
	var fijos := [["panel_solar", Vector2i(-3, 0)], ["panel_solar", Vector2i(-3, 1)], ["domo", Vector2i(0, -3)], ["hangar", Vector2i(-2, -3)]]
	for i in fijos.size():
		e.edificios.append({"id": "%s-f%d" % [fijos[i][0], i], "type": fijos[i][0], "tile": e.casilla_estacion + fijos[i][1], "level": 1,
			"target_level": 1, "elapsed": 0.0, "seconds": 1.0, "active": true, "hp": float(economia.edificio(fijos[i][0]).get("hp", 100)),
			"produced": 0.0, "cd": 0.0})
	var sitios := [Vector2i(3, 1), Vector2i(2, 3), Vector2i(3, -1), Vector2i(1, 3)]
	for i in torretas:
		e.edificios.append({"id": "torreta-%d" % i, "type": "torreta", "tile": e.casilla_estacion + sitios[i], "level": 1,
			"target_level": 1, "elapsed": 0.0, "seconds": 1.0, "active": true, "hp": 120.0, "produced": 0.0, "cd": 0.0})
	sim._edificios.sincronizar_mapa(e)
	e.bateria_wh = e.bateria_capacidad_wh * 0.8
	sim._combate._lanzar(e, ola)
	var t := 0.0
	while t < 150.0 and not e.enemigos.is_empty() and e.fase == "operations":
		sim.avanzar(0.1)
		t += 0.1
	return e


func test_sin_torretas_la_primera_oleada_hunde_la_base() -> void:
	var e := _defender("ola_1", 0)
	assert_ne(e.fase, "operations")


func test_una_torreta_aguanta_las_primeras_oleadas_pero_no_el_coloso() -> void:
	for id in ["ola_1", "ola_2", "ola_3"]:
		var e := _defender(id, 1)
		assert_eq(e.fase, "operations", "una torreta debe aguantar %s" % id)
		assert_true(e.enemigos.is_empty())
	assert_ne(_defender("ola_coloso", 1).fase, "operations")


func test_dos_torretas_aguantan_todas_las_oleadas() -> void:
	for o in combate.oleadas:
		var e := _defender(o["id"], 2)
		assert_eq(e.fase, "operations", "dos torretas deben aguantar %s" % o["id"])
		assert_true(e.enemigos.is_empty(), "%s debe quedar eliminada" % o["id"])
