extends GutTest
## Barrera de la base (ronda G): muros y compuertas que el jugador traza alrededor de la base. Los monstruos rodean la
## barrera si hay un hueco o golpean el muro que les cierra el paso; el rover solo cruza por las compuertas; el escudo
## se recarga solo y los muros se imprimen en paralelo sin ocupar a la cuadrilla de obras.

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

var sim: Simulation


func before_each() -> void:
	sim = Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"), StoryData.desde_archivo("res://content/historia.json"),
		CombatData.desde_archivo("res://content/combate.json"))
	for id in DISENO:
		sim.ejecutar("design_add", {"part_id": id})
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_true(sim.ejecutar("landing_finished")["ok"])
	for r in ["rocas", "olivino", "hielo"]:
		sim.estado.recursos[r] = 250
	sim.estado.enemigos.clear()


func _avanzar(segundos: float) -> void:
	var t := 0.0
	while t < segundos:
		sim.avanzar(0.2)
		t += 0.2


## Casillas libres (sin obstáculo, dentro del mapa) del anillo a distancia «d» de la estación.
func _anillo(d: int) -> Array[Vector2i]:
	var c := sim.estado.casilla_estacion
	var lista: Array[Vector2i] = []
	for x in range(-d, d + 1):
		for y in range(-d, d + 1):
			var t := c + Vector2i(x, y)
			if maxi(absi(x), absi(y)) == d and not sim._mapa.bloqueada(t) and sim._mapa.dentro_de_limites(t):
				lista.append(t)
	return lista


## Levanta muros ya terminados en esas casillas (sin pasar por la obra).
func _poner_muros(casillas: Array[Vector2i], tipo: String = "barrera") -> void:
	for t in casillas:
		var id := "%s-%d" % [tipo, sim.estado.siguiente_edificio]
		sim.estado.siguiente_edificio += 1
		sim.estado.edificios.append({"id": id, "type": tipo, "tile": t, "level": 1, "target_level": 1, "elapsed": 2.0,
			"seconds": 2.0, "active": true, "hp": 320.0, "produced": 0.0, "cd": 0.0})
	sim._edificios.sincronizar_mapa(sim.estado)


func test_los_muros_llegan_mas_lejos_que_los_edificios() -> void:
	var lejos := _anillo(7)
	assert_false(lejos.is_empty())
	assert_eq(sim.ejecutar("build", {"building": "panel_solar", "tile": lejos[0]})["reason"], "OUT_OF_BASE")
	assert_true(sim.ejecutar("build", {"building": "barrera", "tile": lejos[0]})["ok"])
	var fuera := _anillo(8)
	if not fuera.is_empty():
		assert_eq(sim.ejecutar("build", {"building": "barrera", "tile": fuera[0]})["reason"], "OUT_OF_BASE")


func test_los_muros_se_imprimen_en_paralelo_sin_ocupar_la_obra() -> void:
	var casillas := _anillo(6)
	assert_true(sim.ejecutar("build", {"building": "barrera", "tile": casillas[0]})["ok"])
	assert_true(sim.ejecutar("build", {"building": "barrera", "tile": casillas[1]})["ok"], "otro muro a la vez")
	var cerca := _anillo(2)
	assert_true(sim.ejecutar("build", {"building": "panel_solar", "tile": cerca[0]})["ok"], "los muros no ocupan la obra")
	assert_eq(sim.ejecutar("build", {"building": "panel_solar", "tile": cerca[1]})["reason"], "BUILD_BUSY")
	assert_true(sim.ejecutar("build", {"building": "barrera", "tile": casillas[2]})["ok"], "un panel en obra no frena los muros")
	_avanzar(3.0)
	var listos := 0
	for e in sim.estado.edificios:
		if e["type"] == "barrera" and int(e["level"]) >= 1:
			listos += 1
	assert_eq(listos, 3)


func test_el_rover_cruza_la_compuerta_pero_no_el_muro() -> void:
	var casillas := _anillo(5)
	_poner_muros([casillas[0]])
	_poner_muros([casillas[1]], "compuerta")
	assert_true(sim._mapa.bloqueada(casillas[0]), "el muro bloquea al rover")
	assert_false(sim._mapa.bloqueada(casillas[1]), "la compuerta deja pasar al rover")
	assert_true(sim._mapa.muros.has(casillas[0]) and sim._mapa.muros.has(casillas[1]), "los dos frenan a los monstruos")


func test_los_monstruos_rodean_la_barrera_si_tiene_un_hueco() -> void:
	var desde := _anillo(6)[0]
	var libre := sim._mapa.pasos_a_la_estacion(desde)
	var anillo := _anillo(3)
	_poner_muros(anillo)
	var cerrada := sim._mapa.pasos_a_la_estacion(desde)
	assert_gte(cerrada, libre + MapData.COSTO_MURO, "cerrada: hay que romper un muro")
	# Abrimos un hueco: el camino lo rodea sin pagar el coste del muro.
	var hueco: Vector2i = anillo[anillo.size() / 2]
	for e in sim.estado.edificios.duplicate():
		if e["tile"] == hueco:
			sim.estado.edificios.erase(e)
	sim._edificios.sincronizar_mapa(sim.estado)
	var con_hueco := sim._mapa.pasos_a_la_estacion(desde)
	assert_lt(con_hueco, cerrada, "con hueco es más barato rodear que romper")


func test_un_monstruo_golpea_el_muro_que_le_cierra_el_paso_y_lo_rompe() -> void:
	sim.estado.companero = false  # sin Rocky reparando los muros desde dentro
	_poner_muros(_anillo(3))
	var fuera := _anillo(5)[0]
	sim.estado.enemigos.append({"id": "e900", "type": "arana", "wave": "prueba", "pos": Vector2(fuera), "dest": fuera,
		"hp": 9999.0, "cd": 0.0, "atk": 0.0})
	for e in sim.estado.edificios:
		if e["type"] == "barrera":
			e["hp"] = 12.0
	var muros_antes := sim._mapa.muros.size()
	_avanzar(20.0)
	var dentro := Vector2(sim.estado.casilla_estacion).distance_to(sim.estado.enemigos[0]["pos"]) if not sim.estado.enemigos.is_empty() else 0.0
	assert_lt(sim._mapa.muros.size(), muros_antes, "rompió al menos un muro")
	assert_lt(dentro, 3.5, "y entró por el hueco")


func test_el_escudo_del_muro_se_recarga_solo() -> void:
	sim.estado.companero = false  # sin Rocky reparando: solo cuenta el escudo
	_poner_muros([_anillo(4)[0]])
	var muro: Dictionary = sim.estado.edificios.back()
	muro["hp"] = 100.0
	_avanzar(10.0)
	assert_gte(float(muro["hp"]), 127.0, "3 PV por segundo")
	var antes := float(muro["hp"])
	sim._edificios.danar(sim.estado, muro["id"], 20.0)
	_avanzar(3.0)
	assert_lte(float(muro["hp"]), antes - 20.0 + 6.0, "tras un golpe el escudo espera antes de recargarse")
	_avanzar(200.0)
	assert_eq(float(muro["hp"]), 320.0, "sin pasar de su vida máxima")


func test_la_ficha_de_los_muros_trae_su_escudo_y_su_zona() -> void:
	for o in sim.snapshot()["build_options"]:
		if o["id"] in ["barrera", "compuerta"]:
			assert_eq(int(o["zone_extra"]), 2)
			assert_true(o["wall"])
			assert_eq(float(o["info"]["shield_hp_s"]), 3.0)
