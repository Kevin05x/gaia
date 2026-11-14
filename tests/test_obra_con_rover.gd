extends GutTest
## Obra con rover (content/economia.json › obra_con_rover): al ordenar una obra el rover va hasta ella, la obra solo
## empieza cuando el rover llega a una casilla contigua y, al terminar, el rover vuelve a donde estaba. Los muros se
## imprimen solos.

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar"]

var sim: Simulation


func _nueva(economia: Economy) -> Simulation:
	var s := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"), economia)
	for id in DISENO:
		s.ejecutar("design_add", {"part_id": id})
	s.ejecutar("design_start")
	s.ejecutar("landing_finished")
	return s


func before_each() -> void:
	sim = _nueva(Economy.desde_archivo("res://content/economia.json").para_pruebas(true))
	for recurso in sim.estado.recursos:
		sim.estado.recursos[recurso] = 300  # almacén lleno: estas pruebas no miran los costos


## Primera casilla de la base donde se puede construir «tipo» a 3 casillas o más del rover.
func _casilla_lejos(tipo: String) -> Vector2i:
	var centro := sim.estado.casilla_estacion
	for dx in range(-5, 6):
		for dy in range(-5, 6):
			var c := centro + Vector2i(dx, dy)
			var d := c - sim.estado.casilla_rover
			if maxi(absi(d.x), absi(d.y)) >= 3 and sim._edificios.disponibilidad(sim.estado, tipo, c)["enabled"]:
				return c
	fail_test("no hay casilla libre para %s" % tipo)
	return Vector2i.ZERO


## Avanza «segundos» en pasos de 0,1 s y junta los eventos.
func _avanzar(segundos: float) -> Array[String]:
	var eventos: Array[String] = []
	var t := 0.0
	while t < segundos:
		eventos.append_array(sim.avanzar(0.1))
		t += 0.1
	return eventos


func _obra(id: String) -> Dictionary:
	for b in sim.snapshot()["buildings"]:
		if b["id"] == id:
			return b
	return {}


func test_la_obra_espera_al_rover_y_el_rover_vuelve_al_terminar() -> void:
	var inicio := sim.estado.casilla_rover
	var casilla := _casilla_lejos("panel_solar")
	var r := sim.ejecutar("build", {"building": "panel_solar", "tile": casilla})
	assert_true(r["ok"], str(r))
	assert_false((r["path"] as Array).is_empty(), "el rover sale hacia la obra")
	assert_gt(float(r["seconds_per_tile"]), 0.0)
	assert_true(sim.estado.en_movimiento)
	var obra := _obra("panel_solar-1")
	assert_true(obra["building"])
	assert_true(obra["waiting_rover"], "la obra espera al rover")
	sim.avanzar(0.3)
	assert_eq(float(_obra("panel_solar-1")["progress"]), 0.0, "sin el rover al lado la obra no avanza")
	var ida := (r["path"] as Array).size() * float(r["seconds_per_tile"])
	var eventos := _avanzar(ida + 0.3)
	assert_true(eventos.has("BUILD_STARTED:panel_solar:panel_solar-1"), "la obra empieza al llegar: %s" % [eventos])
	var d := casilla - sim.estado.casilla_rover
	assert_lte(maxi(absi(d.x), absi(d.y)), 1, "el rover queda junto a la obra")
	assert_false(_obra("panel_solar-1")["waiting_rover"])
	eventos = _avanzar(6.0)
	assert_true(eventos.has("BUILD_DONE:panel_solar:panel_solar-1"), "%s" % [eventos])
	assert_true(eventos.has("ROVER_AUTO_MOVE:vuelta"), "el rover se va de la obra: %s" % [eventos])
	var vuelta := sim.ruta_en_curso()
	assert_false((vuelta["path"] as Array).is_empty())
	assert_eq((vuelta["path"] as Array).back(), inicio, "vuelve a donde estaba")
	_avanzar((vuelta["path"] as Array).size() * float(vuelta["seconds_per_tile"]) + 0.3)
	assert_eq(sim.estado.casilla_rover, inicio)


func test_si_el_jugador_mueve_el_rover_ya_no_vuelve_solo() -> void:
	var casilla := _casilla_lejos("panel_solar")
	var r := sim.ejecutar("build", {"building": "panel_solar", "tile": casilla})
	_avanzar((r["path"] as Array).size() * float(r["seconds_per_tile"]) + 0.3)
	assert_false(_obra("panel_solar-1")["waiting_rover"])
	var aqui := sim.estado.casilla_rover
	sim.ejecutar("stop")  # una orden del jugador (aunque esté quieto) le quita la vuelta automática
	assert_true(sim.ejecutar("move", {"tile": aqui + Vector2i(0, 1) if aqui + Vector2i(0, 1) != casilla else aqui + Vector2i(0, -1)})["ok"])
	var eventos := _avanzar(7.0)
	assert_true(eventos.has("BUILD_DONE:panel_solar:panel_solar-1"), "una obra empezada sigue aunque el rover se vaya")
	assert_false(eventos.has("ROVER_AUTO_MOVE:vuelta"))


func test_con_el_rover_al_lado_la_obra_empieza_sin_moverse() -> void:
	# El rover se deja dentro de la base, en una casilla libre con otra libre al lado.
	var junto := Vector2i.ZERO
	var encontrada := false
	for c in [sim.estado.casilla_estacion + Vector2i(3, 3), sim.estado.casilla_estacion + Vector2i(-3, 3), sim.estado.casilla_estacion + Vector2i(3, -3)]:
		if encontrada or sim._mapa.bloqueada(c):
			continue
		sim.estado.casilla_rover = c
		for d in MovementSystem.CONTIGUAS:
			if sim._edificios.disponibilidad(sim.estado, "panel_solar", c + d)["enabled"]:
				junto = c + d
				encontrada = true
				break
	assert_true(encontrada, "hay una casilla libre junto al rover")
	var r := sim.ejecutar("build", {"building": "panel_solar", "tile": junto})
	assert_true(r["ok"])
	assert_true((r["path"] as Array).is_empty(), "ya está al lado")
	var eventos := sim.avanzar(0.1)
	assert_true(eventos.has("BUILD_STARTED:panel_solar:panel_solar-1"), "%s" % [eventos])
	assert_false(eventos.has("ROVER_AUTO_MOVE:vuelta"))


func test_los_muros_no_esperan_al_rover() -> void:
	var casilla := _casilla_lejos("barrera")
	var r := sim.ejecutar("build", {"building": "barrera", "tile": casilla})
	assert_true(r["ok"], str(r))
	assert_true((r["path"] as Array).is_empty(), "el rover no se mueve por un muro")
	assert_false(sim.estado.en_movimiento)
	var id := "barrera-1"
	assert_false(_obra(id)["waiting_rover"])
	sim.avanzar(0.5)
	assert_gt(float(_obra(id)["progress"]), 0.0)


func test_si_el_rover_esta_ocupado_va_a_la_obra_al_quedar_libre() -> void:
	sim.estado.ocupado = true  # por ejemplo, taladrando
	var casilla := _casilla_lejos("panel_solar")
	var r := sim.ejecutar("build", {"building": "panel_solar", "tile": casilla})
	assert_true(r["ok"])
	assert_eq(str(r.get("rover_reason", "")), "BUSY")
	assert_false(sim.estado.en_movimiento)
	sim.estado.ocupado = false
	var eventos := sim.avanzar(0.1)
	assert_true(eventos.has("ROVER_AUTO_MOVE:a_obra"), "%s" % [eventos])
	assert_true(sim.estado.en_movimiento)


func test_la_antena_tambien_espera_al_rover() -> void:
	var tile: Vector2i = _obra("antena")["tile"]
	var d := tile - sim.estado.casilla_rover
	var lejos := maxi(absi(d.x), absi(d.y)) > 1
	var r := sim.ejecutar("upgrade")
	assert_true(r["ok"], str(r))
	assert_eq(not (r["path"] as Array).is_empty(), lejos, "el rover sale solo si no está junto a la antena")
	if lejos:
		assert_true(_obra("antena")["waiting_rover"])
	_avanzar((r["path"] as Array).size() * float(r["seconds_per_tile"]) + 0.3)
	assert_false(_obra("antena")["waiting_rover"], "con el rover al lado la mejora empieza")
