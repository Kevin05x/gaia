extends GutTest
## Un rover por jugador en una partida en red, sin abrir sockets: el anfitrión de la prueba es el jugador 1 y el jugador 2
## "habla" llamando a las mismas funciones que usa el servidor cuando le llega una orden.
const Sala := preload("res://scenes/net/sala.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")

var recibido: Dictionary = {}  ## tipo -> último dato que le llegó al jugador 1


func before_each() -> void:
	recibido.clear()
	Red.salir()
	Sesion.destino = "marte"
	Sesion.dificultad = "estandar"
	Red.modo = Red.Modo.ANFITRION
	Red.mi_id = 1
	Red.sala = Sala.new()
	assert_true(Red.sala.anadir(1, "Uno"))
	assert_true(Red.sala.anadir(2, "Dos"))
	assert_true(Red.sala.empezar(1))
	Red._crear_autoridad()
	Red.evento.connect(_al_evento)
	Red._listos[1] = true
	Red._listos[2] = true
	var sim: Simulation = Red.autoridad.sim
	for id in ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]:
		assert_true(sim.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_true(sim.ejecutar("landing_finished")["ok"])
	sim.ejecutar("tutorial_skip")  # el tutorial y la historia detienen el reloj; aquí se prueba el movimiento
	sim.estado.historia_nodo = ""
	sim.estado.imprevisto = {}


func after_each() -> void:
	if Red.evento.is_connected(_al_evento):
		Red.evento.disconnect(_al_evento)
	Red._terminar_partida()
	Red.salir()


func _al_evento(tipo: String, datos: Variant) -> void:
	recibido[tipo] = datos


func test_cada_jugador_tiene_su_rover_al_empezar() -> void:
	var sim: Simulation = Red.autoridad.sim
	assert_eq(sim.estado.ids_de_rovers().size(), 2)
	assert_eq(sim.estado.rover_lider, 1)
	assert_ne(sim.snapshot_de(1)["rover_tile"], sim.snapshot_de(2)["rover_tile"])


func test_las_ordenes_de_cada_jugador_mueven_su_propio_rover() -> void:
	var sim: Simulation = Red.autoridad.sim
	var casilla_1 := sim.snapshot_de(1)["rover_tile"] as Vector2i
	var casilla_2 := sim.snapshot_de(2)["rover_tile"] as Vector2i
	Red._procesar_orden(2, "move", {"tile": casilla_2 + Vector2i(3, 0)})
	for i in range(200):
		sim.avanzar(0.25)
	assert_eq(sim.snapshot_de(1)["rover_tile"], casilla_1, "el rover del jugador 1 no se movió")
	assert_eq(sim.snapshot_de(2)["rover_tile"], casilla_2 + Vector2i(3, 0), "el del jugador 2 llegó")
	assert_eq(sim.estado.rover_actual, 1, "tras cada orden vuelve el rover del líder")


func test_cada_jugador_recibe_el_snapshot_con_su_rover() -> void:
	var s1: Dictionary = Red._snapshot_para(1, Red.autoridad.sim.snapshot())
	var s2: Dictionary = Red._snapshot_para(2, Red.autoridad.sim.snapshot())
	assert_eq(s1["rover_id"], 1)
	assert_eq(s2["rover_id"], 2)
	assert_eq((s2["rovers"] as Array).size(), 2, "ve a los dos rovers")


func test_si_un_jugador_se_va_su_rover_se_va_con_el() -> void:
	var sim: Simulation = Red.autoridad.sim
	Red._al_desconectar_par(2)
	assert_eq(sim.estado.ids_de_rovers(), [1])


func test_quien_entra_con_la_mision_en_marcha_llega_con_su_rover() -> void:
	var sim: Simulation = Red.autoridad.sim
	assert_true(Red.sala.anadir(3, "Tres"))
	sim.jugador_entra(3)
	assert_eq(sim.estado.ids_de_rovers().size(), 3)
	var casillas := {}
	for id in [1, 2, 3]:
		casillas[sim.snapshot_de(id)["rover_tile"]] = true
	assert_eq(casillas.size(), 3, "cada rover en su casilla")


func test_la_vista_dibuja_los_rovers_de_los_demas_y_no_el_propio() -> void:
	var actores: Node3D = add_child_autofree(preload("res://scenes/b/actors.gd").new())
	var sim: Simulation = Red.autoridad.sim
	var s: Dictionary = sim.snapshot_de(1)
	actores.apply_others(s)
	assert_eq(actores._otros_rovers.size(), 1, "solo el del jugador 2")
	assert_true(actores._otros_rovers.has(2))
	# Si el otro se va, su rover desaparece de la vista.
	Red._al_desconectar_par(2)
	actores.apply_others(Red.autoridad.sim.snapshot_de(1))
	assert_eq(actores._otros_rovers.size(), 0)
