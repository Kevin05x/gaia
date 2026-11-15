extends GutTest
## Varios rovers en una misma misión (multijugador en red, plan 12): cada jugador lleva el suyo; la batería, los datos y la base
## son del equipo. Con un solo rover todo funciona como siempre (lo demuestran las demás pruebas).

const DISENO: Array[String] = ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]
var sim: Simulation


func before_each() -> void:
	sim = Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"))
	for id in DISENO:
		assert_true(sim.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_true(sim.ejecutar("landing_finished")["ok"])


func _dos_rovers() -> void:
	sim.agregar_rover(11)
	sim.agregar_rover(22)


func test_el_primero_es_el_lider_y_cada_uno_empieza_en_su_casilla() -> void:
	var inicio := sim.estado.casilla_rover
	_dos_rovers()
	assert_eq(sim.estado.ids_de_rovers().size(), 2)
	assert_eq(sim.estado.rover_lider, 11)
	assert_eq(sim.estado.rover_actual, 11)
	assert_eq(sim.estado.casilla_rover, inicio, "el líder se queda donde estaba")
	var otra := sim.snapshot_de(22)["rover_tile"] as Vector2i
	assert_ne(otra, inicio, "el segundo no empieza encima del primero")
	assert_eq(sim.estado.rover_actual, 11, "mirar el snapshot de otro no cambia el rover cargado")


func test_una_orden_mueve_solo_el_rover_de_quien_la_da() -> void:
	_dos_rovers()
	var inicio_1 := sim.estado.casilla_rover
	var inicio_2 := sim.snapshot_de(22)["rover_tile"] as Vector2i
	var meta := inicio_2 + Vector2i(3, 0)
	var r := sim.ejecutar("move", {"tile": meta, "_rover": 22})
	assert_true(r["ok"], str(r))
	for i in range(200):
		sim.avanzar(0.25)
	assert_eq(sim.snapshot_de(11)["rover_tile"], inicio_1, "el rover 11 no se movió")
	assert_eq(sim.snapshot_de(22)["rover_tile"], meta, "el rover 22 llegó")


func test_dos_rovers_se_mueven_a_la_vez_y_la_bateria_es_de_todos() -> void:
	_dos_rovers()
	var bateria := sim.estado.bateria_wh
	var a := (sim.snapshot_de(11)["rover_tile"] as Vector2i) + Vector2i(0, 3)
	var b := (sim.snapshot_de(22)["rover_tile"] as Vector2i) + Vector2i(3, 0)
	assert_true(sim.ejecutar("move", {"tile": a, "_rover": 11})["ok"])
	assert_true(sim.ejecutar("move", {"tile": b, "_rover": 22})["ok"])
	var minima := bateria
	for i in range(240):
		sim.avanzar(0.25)
		minima = minf(minima, sim.estado.bateria_wh)  # el panel solar la vuelve a llenar de día: se mira el punto más bajo
	assert_eq(sim.snapshot_de(11)["rover_tile"], a)
	assert_eq(sim.snapshot_de(22)["rover_tile"], b)
	assert_lt(minima, bateria, "los dos gastaron de la misma batería")


func test_cada_rover_lleva_su_bodega() -> void:
	_dos_rovers()
	sim.usar_rover(22)
	sim.estado.carga = {"rocas": 12}
	sim.usar_rover(11)
	assert_eq(sim.estado.carga, {}, "el rover 11 va vacío")
	assert_eq(sim.snapshot_de(22)["cargo"]["total"], 12)
	assert_eq(sim.snapshot_de(11)["cargo"]["total"], 0)


func test_el_snapshot_de_un_jugador_trae_su_rover_y_la_lista_de_todos() -> void:
	_dos_rovers()
	var s := sim.snapshot_de(22)
	assert_eq(s["rover_id"], 22)
	assert_eq((s["rovers"] as Array).size(), 2)
	var ids: Array = []
	for r in s["rovers"]:
		ids.append(r["id"])
	assert_true(ids.has(11) and ids.has(22))


func test_el_objetivo_seleccionado_es_de_cada_rover() -> void:
	_dos_rovers()
	var s := sim.snapshot()
	var objetivo := ""
	for t in s["targets"]:
		objetivo = str(t["id"])
		break
	assert_ne(objetivo, "")
	sim.ejecutar("select", {"target_id": objetivo, "_rover": 22})
	sim.usar_rover(22)
	var elegido_22: String = str(sim.objetivo_seleccionado())
	sim.usar_rover(11)
	assert_eq(elegido_22, objetivo)
	assert_eq(sim.objetivo_seleccionado(), "", "el rover 11 no tiene nada seleccionado")


func test_si_el_lider_se_va_manda_el_siguiente_y_siempre_queda_uno() -> void:
	_dos_rovers()
	sim.quitar_rover(11)
	assert_eq(sim.estado.ids_de_rovers(), [22])
	assert_eq(sim.estado.rover_lider, 22)
	sim.quitar_rover(22)
	assert_eq(sim.estado.ids_de_rovers().size(), 1, "nunca se queda sin rover")


func test_una_misma_orden_con_y_sin_rover_da_lo_mismo_con_un_solo_rover() -> void:
	# Un solo rover: «_rover» se ignora y la orden funciona como siempre.
	var meta := sim.estado.casilla_rover + Vector2i(2, 0)
	assert_true(sim.ejecutar("move", {"tile": meta, "_rover": 99})["ok"])
	for i in range(100):
		sim.avanzar(0.25)
	assert_eq(sim.estado.casilla_rover, meta)


func test_guardar_y_cargar_con_varios_rovers_no_falla() -> void:
	_dos_rovers()
	var datos := sim.guardar()
	assert_true(datos["estado"].has("rovers"))
	assert_true(sim.cargar(datos))
