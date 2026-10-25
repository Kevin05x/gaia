extends GutTest
## Bloque C: nidos, oleadas, monstruos, torretas, daño a la base, reparación de Rocky, meteoritos y fracaso por
## rover destruido (content/combate.json, content/economia.json y content/mapa.json).

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]
const MAPA_MINI := '{"limites": {"min": [-3, -3], "max": [3, 3]}, "inicio_rover": [0, 0], "estacion": [-2, -2], "obstaculos": %s, "objetivos": [], "nidos": %s}'

var economia: Economy
var combate: CombatData
var sim: Simulation


func before_each() -> void:
	economia = Economy.desde_archivo("res://content/economia.json")
	combate = CombatData.desde_archivo("res://content/combate.json")
	sim = _nueva()
	_operar()


func _nueva(con_combate: bool = true) -> Simulation:
	return Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"),
		economia, null, combate if con_combate else null)


func _operar(simulacion: Simulation = null) -> void:
	var s: Simulation = simulacion if simulacion != null else sim
	for id in DISENO:
		assert_true(s.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(s.ejecutar("design_start")["ok"])
	assert_true(s.ejecutar("landing_finished")["ok"])


## Pone un edificio ya construido (sin pasar por la obra).
func _edificio(tipo: String, casilla: Vector2i, nivel: int = 1) -> Dictionary:
	var edificio := {"id": "%s-t%d" % [tipo, sim.estado.edificios.size()], "type": tipo, "tile": casilla, "level": nivel,
		"target_level": nivel, "elapsed": 0.0, "seconds": 1.0, "active": true,
		"hp": float(economia.edificio(tipo).get("hp", 100)), "produced": 0.0, "cd": 0.0}
	sim.estado.edificios.append(edificio)
	sim._edificios.sincronizar_mapa(sim.estado)
	return edificio


func _monstruo(tipo: String, pos: Vector2, destino: Vector2i = Vector2i(-9, -9)) -> Dictionary:
	var enemigo := {"id": "e%d" % sim.estado.siguiente_enemigo, "type": tipo, "wave": "prueba", "pos": pos, "dest": destino,
		"hp": float(combate.enemigo(tipo)["hp"]), "cd": 0.0, "atk": 0.0}
	sim.estado.siguiente_enemigo += 1
	sim.estado.enemigos.append(enemigo)
	return enemigo


## Avanza solo el combate (sin gasto de energía de fondo ni reloj): «segundos» en pasos de 0.1 s.
func _combatir(segundos: float) -> Array[String]:
	var eventos: Array[String] = []
	for i in int(segundos / 0.1):
		eventos.append_array(sim._combate.avanzar(sim.estado, 0.1, 0.0, sim._energia))
	return eventos


## Avanza la simulación entera.
func _jugar(segundos: float, paso: float = 0.1) -> Array[String]:
	var eventos: Array[String] = []
	for i in int(segundos / paso):
		eventos.append_array(sim.avanzar(paso))
	return eventos


func _ir_a(sol: int, hora: float) -> void:
	sim.estado.sol = sol
	sim.estado.hora = hora


# --- Datos -----------------------------------------------------------------------------------------------------------

func test_los_datos_de_combate_cargan_sin_errores() -> void:
	assert_eq(combate.errores.size(), 0, str(combate.errores))
	for tipo in ["arana", "void_biter", "coloso"]:
		assert_true(combate.enemigos.has(tipo), tipo)
	assert_gt(combate.oleadas.size(), 3)
	assert_gt(combate.max_activos, 0)


func test_las_oleadas_quedan_ordenadas_por_momento() -> void:
	var ultimo := -1.0
	for oleada in combate.oleadas:
		var t := CombatData.momento(oleada["sol"], oleada["hora"])
		assert_gt(t, ultimo, oleada["id"])
		ultimo = t


func test_el_coloso_es_el_mas_fuerte_y_lento() -> void:
	assert_gt(combate.enemigo("coloso")["hp"], combate.enemigo("void_biter")["hp"])
	assert_lt(combate.enemigo("coloso")["velocidad"], combate.enemigo("arana")["velocidad"])


func test_datos_invalidos_dan_errores_con_codigo() -> void:
	assert_has(CombatData.desde_texto("no es json").errores, "INVALID_JSON")
	var sin_enemigos := CombatData.desde_texto('{"oleadas": []}')
	assert_has(sin_enemigos.errores, "MISSING_FIELD:enemigos")
	var mala := CombatData.desde_texto('{"enemigos": {"a": {"hp": 0, "velocidad": 1, "dano": 1, "alcance": 1, "cadencia_s": 1}}, "oleadas": []}')
	assert_has(mala.errores, "INVALID_FIELD:enemigos.a.hp")
	var ola_rara := CombatData.desde_texto('{"enemigos": {"a": {"hp": 1, "velocidad": 1, "dano": 1, "alcance": 1, "cadencia_s": 1}}, '
		+ '"oleadas": [{"id": "x", "sol": 2, "hora": 30, "grupos": []}]}')
	assert_has(ola_rara.errores, "INVALID_FIELD:oleadas.x.momento")
	var tipo_raro := CombatData.desde_texto('{"enemigos": {"a": {"hp": 1, "velocidad": 1, "dano": 1, "alcance": 1, "cadencia_s": 1}}, '
		+ '"oleadas": [{"id": "x", "sol": 2, "hora": 5, "grupos": [{"tipo": "b", "cantidad": 2}]}]}')
	assert_has(tipo_raro.errores, "INVALID_FIELD:oleadas.x.grupos")


func test_las_torretas_son_edificios_con_datos_de_disparo() -> void:
	assert_eq(economia.errores.size(), 0, str(economia.errores))
	for tipo in ["torreta", "torreta_2"]:
		var arma := economia.combate_de(tipo)
		assert_false(arma.is_empty(), tipo)
		assert_gt(float(arma["alcance"]), 0.0)
		assert_gt(float(arma["dano"]), 0.0)
	assert_gt(economia.combate_de("torreta_2")["dano"], economia.combate_de("torreta")["dano"])
	assert_true(economia.combate_de("panel_solar").is_empty())


func test_un_edificio_no_puede_pedir_otro_que_no_existe() -> void:
	var texto := FileAccess.get_file_as_string("res://content/economia.json").replace('"requiere": "hangar"', '"requiere": "fantasma"')
	assert_has(Economy.desde_texto(texto).errores, "UNKNOWN_BUILDING:torreta_2.requiere")


# --- Mapa y nidos ----------------------------------------------------------------------------------------------------

func test_el_mapa_trae_nidos_en_la_falla_y_el_nucleo() -> void:
	var mapa := MapData.desde_archivo("res://content/mapa.json")
	assert_eq(mapa.errores.size(), 0, str(mapa.errores))
	assert_eq(mapa.nidos.size(), 5)
	var zonas := {}
	for nido in mapa.nidos:
		zonas[nido["zone"]] = int(zonas.get(nido["zone"], 0)) + 1
		assert_eq(mapa.zona_de(nido["tile"]), nido["zone"], nido["id"])
		assert_true(mapa.es_nido(nido["tile"]))
		assert_true(mapa.bloqueada(nido["tile"]), "el rover no pisa los nidos")
		assert_gt(mapa.pasos_a_la_estacion(nido["tile"]), 0, "camino de los monstruos desde " + nido["id"])
	assert_eq(zonas.get("falla", 0), 2)
	assert_eq(zonas.get("nucleo", 0), 3)


func test_los_monstruos_siguen_un_camino_que_se_acerca_a_la_estacion() -> void:
	var mapa := MapData.desde_archivo("res://content/mapa.json")
	var casilla: Vector2i = mapa.nidos[0]["tile"]
	var pasos := mapa.pasos_a_la_estacion(casilla)
	var llegados := 0
	while casilla != mapa.estacion and llegados < 400:
		var siguiente := mapa.paso_hacia_la_estacion(casilla)
		assert_ne(siguiente, casilla, "sigue avanzando en " + str(casilla))
		assert_false(mapa.bloqueada_para_enemigos(siguiente), "no pisa rocas ni objetivos")
		assert_lt(mapa.pasos_a_la_estacion(siguiente), mapa.pasos_a_la_estacion(casilla))
		casilla = siguiente
		llegados += 1
		if siguiente == mapa.estacion:
			break
	assert_eq(llegados, pasos, "los pasos coinciden con la distancia calculada")


func test_la_diagonal_no_corta_esquinas() -> void:
	var texto := MAPA_MINI % ["[[0, 1], [1, 0]]", '[{"id": "n", "casilla": [3, 3]}]']
	var mapa := MapData.desde_texto(texto)
	assert_eq(mapa.errores.size(), 0, str(mapa.errores))
	# De (1,1) no se puede ir en diagonal a (0,0) porque (0,1) y (1,0) son rocas.
	assert_ne(mapa.paso_hacia_la_estacion(Vector2i(1, 1)), Vector2i(0, 0))


func test_un_nido_encerrado_o_mal_puesto_da_error() -> void:
	var encerrado := MapData.desde_texto(MAPA_MINI % ["[[2, 3], [3, 2], [2, 2]]", '[{"id": "n", "casilla": [3, 3]}]'])
	assert_has(encerrado.errores, "UNREACHABLE_NEST:n")
	var sobre_roca := MapData.desde_texto(MAPA_MINI % ["[[3, 3]]", '[{"id": "n", "casilla": [3, 3]}]'])
	assert_has(sobre_roca.errores, "TILE_OCCUPIED:3,3")
	var fuera := MapData.desde_texto(MAPA_MINI % ["[]", '[{"id": "n", "casilla": [9, 9]}]'])
	assert_has(fuera.errores, "OUT_OF_BOUNDS:nidos.n")
	var repetido := MapData.desde_texto(MAPA_MINI % ["[]", '[{"id": "n", "casilla": [3, 3]}, {"id": "n", "casilla": [3, 2]}]'])
	assert_has(repetido.errores, "DUPLICATE_NEST:n")


func test_el_snapshot_trae_nidos_y_combate() -> void:
	var snap := sim.snapshot()
	assert_eq(snap["nests"].size(), 5)
	assert_true(snap.has("combat"))
	assert_eq(snap["combat"]["enemies"].size(), 0)
	assert_eq(snap["combat"]["wave"]["id"], "ola_1")
	assert_eq(snap["rover_hp"], 100.0)
	assert_false(_nueva(false).snapshot().has("combat"), "sin datos de combate no hay monstruos")


# --- Edificios: vida, daño y reparación ------------------------------------------------------------------------------

func test_las_torretas_piden_el_hangar() -> void:
	sim.estado.recursos = {"rocas": 500, "olivino": 500, "hielo": 500, "xenolito": 500}
	var sin_hangar: Dictionary = sim.ejecutar("build", {"building": "torreta_2", "tile": Vector2i(-8, -9)})
	assert_false(sin_hangar["ok"])
	assert_eq(sin_hangar["reason"], "NEEDS_HANGAR")
	assert_true(sim.ejecutar("build", {"building": "torreta", "tile": Vector2i(-8, -9)})["ok"], "la torreta Nv1 no pide nada")
	_edificio("hangar", Vector2i(-12, -9))
	for i in 100:
		sim.avanzar(0.1)  # termina la obra
	assert_true(sim.ejecutar("build", {"building": "torreta_2", "tile": Vector2i(-8, -7)})["ok"])


func test_un_edificio_destruido_desaparece_y_libera_la_casilla() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	var eventos: Array[String] = sim._edificios.danar(sim.estado, panel["id"], 30.0)
	assert_eq(panel["hp"], 70.0)
	assert_eq(eventos.size(), 0)
	eventos = sim._edificios.danar(sim.estado, panel["id"], 100.0)
	assert_has(eventos, "BUILDING_DESTROYED:panel_solar:%s" % panel["id"])
	assert_eq(sim._edificios.edificio_por_id(sim.estado, panel["id"]), {})
	assert_false(sim._mapa.bloqueada(Vector2i(-8, -9)))


func test_la_antena_baja_un_nivel_en_vez_de_desaparecer() -> void:
	var antena: Dictionary = sim._edificios.edificio_por_id(sim.estado, "antena")
	antena["level"] = 2
	antena["target_level"] = 2
	antena["hp"] = 150.0
	sim.estado.nivel_antena = 2
	var eventos: Array[String] = sim._edificios.danar(sim.estado, "antena", 500.0)
	assert_has(eventos, "ANTENNA_DAMAGED:1")
	assert_eq(sim.estado.nivel_antena, 1)
	assert_eq(antena["hp"], economia.antena_hp, "al bajar de nivel recupera su vida")
	eventos = sim._edificios.danar(sim.estado, "antena", 500.0)
	assert_has(eventos, "ANTENNA_DAMAGED:0")
	assert_eq(sim.estado.nivel_antena, 0)
	assert_eq(antena["hp"], 0.0)
	assert_eq(sim._edificios.danar(sim.estado, "antena", 50.0).size(), 0, "sin niveles no hay nada que dañar")


func test_la_antena_nueva_nace_con_vida() -> void:
	sim.estado.recursos = {"rocas": 500, "olivino": 500, "hielo": 500, "xenolito": 500}
	assert_true(sim.ejecutar("upgrade")["ok"])
	for i in 200:
		sim.avanzar(0.1)
	assert_eq(sim.estado.nivel_antena, 1)
	assert_eq(sim._edificios.edificio_por_id(sim.estado, "antena")["hp"], economia.antena_hp)


func test_reparar_no_pasa_de_la_vida_maxima() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	panel["hp"] = 90.0
	assert_almost_eq(sim._edificios.reparar(sim.estado, panel["id"], 50.0), 10.0, 0.001)
	assert_eq(panel["hp"], 100.0)
	assert_eq(sim._edificios.reparar(sim.estado, panel["id"], 5.0), 0.0)


func test_el_snapshot_de_edificios_trae_vida() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	panel["hp"] = 55.0
	for entrada in sim.snapshot()["buildings"]:
		if entrada["id"] == panel["id"]:
			assert_eq(entrada["hp"], 55.0)
			assert_eq(entrada["hp_max"], 100.0)
			return
	fail_test("el panel no está en el snapshot")


# --- Oleadas ---------------------------------------------------------------------------------------------------------

func test_la_primera_oleada_sale_a_su_hora_de_los_nidos_de_la_falla() -> void:
	_ir_a(2, 19.0)
	var eventos := _jugar(2.0)
	assert_eq(sim.estado.enemigos.size(), 0, "todavía no es la hora")
	_ir_a(2, 19.99)
	eventos = _jugar(1.0)
	assert_has(eventos, "WAVE_STARTED:ola_1")
	assert_eq(sim.estado.enemigos.size(), 3)
	var mapa: MapData = sim._mapa
	for enemigo in sim.estado.enemigos:
		assert_eq(enemigo["type"], "arana")
		var casilla := Vector2i(Vector2(enemigo["pos"]).round())
		assert_eq(mapa.zona_de(casilla), "falla", "sale de un nido de la falla")
	assert_has(sim.estado.oleadas_hechas, "ola_1")


func test_una_oleada_no_se_repite() -> void:
	_ir_a(2, 19.99)
	_jugar(1.0)
	var antes: int = sim.estado.siguiente_enemigo
	_ir_a(2, 21.0)
	_jugar(1.0)
	assert_eq(sim.estado.siguiente_enemigo, antes)


func test_las_oleadas_mezclan_tipos_y_zonas() -> void:
	sim.estado.oleadas_hechas.append("ola_1")
	_ir_a(3, 20.99)
	_jugar(1.0)
	var tipos := {}
	for enemigo in sim.estado.enemigos:
		tipos[enemigo["type"]] = int(tipos.get(enemigo["type"], 0)) + 1
	assert_eq(tipos.get("arana", 0), 4)
	assert_eq(tipos.get("void_biter", 0), 1)


func test_la_oleada_del_coloso_trae_al_coloso() -> void:
	_ir_a(5, 10.99)
	_jugar(1.0)
	var colosos := 0
	for enemigo in sim.estado.enemigos:
		if enemigo["type"] == "coloso":
			colosos += 1
			assert_eq(enemigo["hp"], combate.enemigo("coloso")["hp"])
	assert_eq(colosos, 1)


func test_la_actividad_de_la_base_agrega_aranas() -> void:
	sim.estado.amenaza = 25.0  # por_extra = 10: dos arañas más
	assert_eq(sim._combate.extra_por_amenaza(sim.estado), 2)
	assert_eq(sim.snapshot()["combat"]["wave"]["count"], 5)
	_ir_a(2, 19.99)
	_jugar(1.0)
	assert_eq(sim.estado.enemigos.size(), 5)
	assert_lt(sim.estado.amenaza, 10.0, "la amenaza se gasta al lanzar la oleada")


func test_la_amenaza_tiene_tope_de_extras() -> void:
	sim.estado.amenaza = 100.0
	assert_eq(sim._combate.extra_por_amenaza(sim.estado), int(combate.amenaza["extra_max"]))


func test_taladrar_sube_la_amenaza_y_el_tiempo_la_baja() -> void:
	sim._combate.reaccionar(sim.estado, ["ACTION_DONE:drill:JZ-01"] as Array[String])
	assert_eq(sim.estado.amenaza, float(combate.amenaza["taladro"]))
	sim._combate.reaccionar(sim.estado, ["ACTION_DONE:spectrometer:JZ-01"] as Array[String])
	assert_eq(sim.estado.amenaza, float(combate.amenaza["taladro"]), "solo el taladro despierta a la fauna")
	var antes: float = sim.estado.amenaza
	sim._combate.avanzar(sim.estado, 0.1, 4.0, sim._energia)
	assert_lt(sim.estado.amenaza, antes)


func test_transmitir_con_antena_alta_sube_la_amenaza() -> void:
	sim.estado.transmitiendo = true
	sim.estado.nivel_antena = 3
	sim._combate.avanzar(sim.estado, 0.1, 1.0, sim._energia)
	var esperado := 3.0 * float(combate.amenaza["transmision_por_h_y_nivel"]) - float(combate.amenaza["decaimiento_por_h"])
	assert_almost_eq(sim.estado.amenaza, esperado, 0.001)


func test_no_salen_mas_monstruos_que_el_maximo_de_activos() -> void:
	combate.oleadas[0]["grupos"][0]["cantidad"] = 90
	_ir_a(2, 19.99)
	_jugar(1.0)
	assert_eq(sim.estado.enemigos.size(), combate.max_activos)


func test_el_aviso_de_oleada_llega_con_antelacion() -> void:
	_ir_a(2, 10.0)
	var ids: Array = []
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_does_not_have(ids, "WAVE_SOON")
	_ir_a(2, 18.0)
	ids.clear()
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "WAVE_SOON")
	_monstruo("arana", Vector2(10, 10))
	ids.clear()
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "ENEMIES_ACTIVE")


# --- Monstruos --------------------------------------------------------------------------------------------------------

func test_los_monstruos_caminan_hacia_la_base_y_no_atraviesan_rocas() -> void:
	var mapa: MapData = sim._mapa
	var nido: Dictionary = mapa.nidos[0]
	var enemigo := _monstruo("arana", Vector2(nido["tile"]), nido["tile"])
	var inicio := Vector2(enemigo["pos"])
	var distancia := inicio.distance_to(Vector2(mapa.estacion))
	_combatir(10.0)
	assert_lt(Vector2(enemigo["pos"]).distance_to(Vector2(mapa.estacion)), distancia - 8.0, "10 s a 1,3 casillas por segundo")
	_combatir(120.0)
	assert_lt(Vector2(enemigo["pos"]).distance_to(Vector2(mapa.estacion)), combate.enemigo("arana")["alcance"] + 0.1, "llega a la estación")


func test_ningun_nido_deja_a_un_monstruo_atascado() -> void:
	var mapa: MapData = sim._mapa
	for nido in mapa.nidos:
		var enemigo := _monstruo("arana", Vector2(nido["tile"]), nido["tile"])
		enemigo["cd"] = 9999.0  # no ataca: solo mide el camino
		for i in 4000:
			sim._combate.avanzar(sim.estado, 0.1, 0.0, sim._energia)
			if Vector2(enemigo["pos"]).distance_to(Vector2(mapa.estacion)) <= 1.3:
				break
		assert_lte(Vector2(enemigo["pos"]).distance_to(Vector2(mapa.estacion)), 1.31, "llega desde " + nido["id"])
		sim.estado.enemigos.clear()


func test_la_arana_muerde_el_edificio_que_tiene_a_tiro() -> void:
	var panel := _edificio("panel_solar", Vector2i(-6, -9))
	_monstruo("arana", Vector2(-5.2, -9.0), Vector2i(-5, -9))
	_combatir(3.0)
	assert_lt(panel["hp"], 100.0)


func test_el_coloso_golpea_mas_fuerte_a_los_edificios() -> void:
	var panel := _edificio("panel_solar", Vector2i(-6, -9))
	sim.estado.companero = false  # sin Rocky que repare entre golpes
	_monstruo("coloso", Vector2(-4.5, -9.0), Vector2i(-5, -9))
	var eventos := _combatir(0.2)
	assert_eq(panel["hp"], 100.0 - 30.0 * 1.5, "30 de daño por 1,5")
	assert_eq(eventos.size(), 0)


func test_el_void_biter_drena_la_bateria() -> void:
	var panel := _edificio("panel_solar", Vector2i(-6, -9))
	_monstruo("void_biter", Vector2(-5.0, -9.0), Vector2i(-5, -9))
	var antes: float = sim.estado.bateria_wh
	_combatir(0.2)
	assert_almost_eq(sim.estado.bateria_wh, antes - 8.0, 0.001)
	assert_lt(panel["hp"], 100.0)


func test_un_monstruo_en_la_estacion_golpea_a_rocky_y_a_la_bateria() -> void:
	_monstruo("arana", Vector2(-8.0, -9.0), Vector2i(-9, -9))
	var antes: float = sim.estado.bateria_wh
	_combatir(0.2)
	assert_eq(sim.estado.rocky_hp, 98.0)
	assert_almost_eq(sim.estado.bateria_wh, antes - 4.0, 0.001)


func test_sin_companero_la_estacion_no_hiere_a_nadie_pero_cuesta_energia() -> void:
	var otro := _nueva()
	for id in DISENO.filter(func(p: String) -> bool: return p != "companero"):
		otro.ejecutar("design_add", {"part_id": id})
	assert_true(otro.ejecutar("design_start")["ok"])
	otro.ejecutar("landing_finished")
	otro.estado.enemigos.append({"id": "e1", "type": "arana", "wave": "prueba", "pos": Vector2(-8, -9), "dest": Vector2i(-9, -9),
		"hp": 24.0, "cd": 0.0, "atk": 0.0})
	var antes: float = otro.estado.bateria_wh
	otro._combate.avanzar(otro.estado, 0.1, 0.0, otro._energia)
	assert_eq(otro.estado.rocky_hp, 100.0)
	assert_lt(otro.estado.bateria_wh, antes)


func test_el_rover_herido_pierde_vida_y_sin_vida_se_acaba_la_mision() -> void:
	sim.estado.casilla_rover = Vector2i(0, 0)
	_monstruo("coloso", Vector2(1.0, 0.0), Vector2i(0, 0))
	var eventos := _combatir(0.2)
	assert_has(eventos, "ROVER_HIT")
	assert_eq(sim.estado.rover_hp, 82.0, "18 de daño del coloso al rover")
	sim.estado.rover_hp = 5.0
	sim.estado.enemigos[0]["cd"] = 0.0
	_combatir(0.2)
	assert_eq(sim.estado.rover_hp, 0.0)
	var final := sim.avanzar(0.1)
	assert_has(final, "MISSION_ENDED")
	assert_false(sim.informe["success"])
	assert_has(sim.informe["causes"], "CAUSE_ROVER_DESTROYED")
	assert_eq(sim.estado.fase, "report")


# --- Torretas --------------------------------------------------------------------------------------------------------

func test_una_torreta_dispara_y_gasta_bateria() -> void:
	var torre := _edificio("torreta", Vector2i(-6, -9))
	var arana := _monstruo("arana", Vector2(-2.0, -9.0), Vector2i(-2, -9))
	var antes: float = sim.estado.bateria_wh
	_combatir(0.1)
	assert_eq(arana["hp"], 24.0 - 12.0)
	assert_almost_eq(sim.estado.bateria_wh, antes - 0.5, 0.001)
	assert_eq(sim.estado.disparos.size(), 1)
	assert_gt(torre["cd"], 0.0)


func test_la_torreta_respeta_su_cadencia_y_alcance() -> void:
	_edificio("torreta", Vector2i(-6, -9))
	var lejos := _monstruo("arana", Vector2(10.0, -9.0), Vector2i(10, -9))
	lejos["cd"] = 9999.0
	_combatir(2.0)
	assert_eq(lejos["hp"], 24.0, "fuera de alcance")
	var cerca := _monstruo("coloso", Vector2(-1.0, -9.0), Vector2i(-1, -9))
	cerca["cd"] = 9999.0
	_combatir(2.0)  # cadencia 0,8 s: tres disparos
	assert_eq(cerca["hp"], 360.0 - 36.0)


func test_la_torreta_dos_pega_mas_fuerte_y_mas_lejos() -> void:
	_edificio("hangar", Vector2i(-12, -9))
	_edificio("torreta_2", Vector2i(-6, -9))
	var arana := _monstruo("arana", Vector2(1.5, -9.0), Vector2i(1, -9))  # a 7,5 casillas: solo la Nv2 llega
	arana["cd"] = 9999.0
	_combatir(0.1)
	assert_true(sim.estado.enemigos.is_empty() or arana["hp"] < 24.0, "la Nv2 la alcanza y la baja o la mata")


func test_una_torreta_apagada_o_en_modo_seguro_no_dispara() -> void:
	var torre := _edificio("torreta", Vector2i(-6, -9))
	var arana := _monstruo("arana", Vector2(-2.0, -9.0), Vector2i(-2, -9))
	arana["cd"] = 9999.0
	torre["active"] = false
	_combatir(1.0)
	assert_eq(arana["hp"], 24.0, "apagada")
	torre["active"] = true
	sim.estado.modo_seguro = true
	_combatir(1.0)
	assert_eq(arana["hp"], 24.0, "modo seguro")
	sim.estado.modo_seguro = false
	_combatir(0.1)
	assert_lt(arana["hp"], 24.0)


func test_sin_bateria_la_torreta_no_dispara() -> void:
	_edificio("torreta", Vector2i(-6, -9))
	var arana := _monstruo("arana", Vector2(-2.0, -9.0), Vector2i(-2, -9))
	arana["cd"] = 9999.0
	sim.estado.bateria_wh = 0.2
	_combatir(1.0)
	assert_eq(arana["hp"], 24.0)


func test_una_torreta_en_obra_no_dispara() -> void:
	var torre := _edificio("torreta", Vector2i(-6, -9), 0)
	torre["target_level"] = 1
	var arana := _monstruo("arana", Vector2(-2.0, -9.0), Vector2i(-2, -9))
	arana["cd"] = 9999.0
	_combatir(1.0)
	assert_eq(arana["hp"], 24.0)


func test_matar_al_ultimo_de_la_oleada_la_da_por_derrotada() -> void:
	_edificio("torreta", Vector2i(-6, -9))
	var a := _monstruo("arana", Vector2(-2.0, -9.0), Vector2i(-2, -9))
	var b := _monstruo("arana", Vector2(-2.0, -8.0), Vector2i(-2, -8))
	a["cd"] = 9999.0
	b["cd"] = 9999.0
	var eventos := _combatir(6.0)
	assert_true(sim.estado.enemigos.is_empty())
	assert_eq(eventos.count("ENEMY_KILLED:arana"), 2)
	assert_eq(eventos.count("WAVE_CLEARED:prueba"), 1)


func test_dos_torretas_paran_la_primera_oleada_y_sin_ellas_la_base_sufre() -> void:
	# Con defensa.
	_edificio("torreta", Vector2i(-5, -9))
	_edificio("torreta", Vector2i(-5, -8))
	var panel := _edificio("panel_solar", Vector2i(-6, -10))
	_ir_a(2, 19.99)
	_jugar(90.0)
	assert_true(sim.estado.enemigos.is_empty(), "la oleada cayó")
	assert_eq(panel["hp"], 100.0, "sin daño")
	assert_eq(sim.estado.rocky_hp, 100.0)
	assert_eq(sim.estado.fase, "operations")
	# Sin defensa, la misma oleada llega a la estación.
	sim = _nueva()
	_operar()
	_ir_a(2, 19.99)
	_jugar(90.0)
	assert_eq(sim.estado.enemigos.size(), 3)
	assert_lt(sim.estado.rocky_hp, 100.0, "las arañas llegaron a Rocky")


# --- Rocky repara -----------------------------------------------------------------------------------------------------

func test_rocky_repara_el_edificio_mas_danado_y_gasta_bateria() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	var luz := _edificio("luz", Vector2i(-8, -7))
	panel["hp"] = 40.0
	luz["hp"] = 70.0
	var antes: float = sim.estado.bateria_wh
	_combatir(5.0)
	assert_almost_eq(panel["hp"], 55.0, 0.01, "3 de vida por segundo")
	assert_eq(luz["hp"], 70.0, "solo repara uno a la vez: el más dañado")
	assert_almost_eq(sim.estado.bateria_wh, antes - 15.0 * 0.2, 0.01)


func test_rocky_se_esconde_si_hay_monstruos_cerca_de_la_estacion() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	panel["hp"] = 40.0
	var arana := _monstruo("arana", Vector2(-6.0, -9.0), Vector2i(-6, -9))
	arana["cd"] = 9999.0
	_combatir(2.0)
	assert_eq(panel["hp"], 40.0)


func test_sin_companero_nadie_repara() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	panel["hp"] = 40.0
	sim.estado.companero = false
	_combatir(2.0)
	assert_eq(panel["hp"], 40.0)
	sim.estado.companero = true
	sim.estado.rocky_hp = 0.0
	_combatir(2.0)
	assert_eq(panel["hp"], 40.0, "Rocky caído no repara")


func test_rocky_repara_al_rover_solo_dentro_de_la_base() -> void:
	sim.estado.rover_hp = 50.0
	sim.estado.casilla_rover = Vector2i(10, 10)
	_combatir(2.0)
	assert_eq(sim.estado.rover_hp, 50.0, "fuera de la base no hay reparación")
	sim.estado.casilla_rover = Vector2i(-8, -9)
	_combatir(2.0)
	assert_almost_eq(sim.estado.rover_hp, 53.0, 0.01, "1,5 por segundo")


func test_sin_bateria_rocky_no_repara() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	panel["hp"] = 40.0
	sim.estado.bateria_wh = 0.0
	_combatir(2.0)
	assert_eq(panel["hp"], 40.0)


# --- Meteoritos -------------------------------------------------------------------------------------------------------

func test_la_lluvia_de_meteoritos_avisa_y_cae_en_la_base() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	_ir_a(4, 13.99)
	var eventos := _jugar(0.5)
	assert_has(eventos, "METEOR_SHOWER:meteoritos_1")
	assert_gt(sim.estado.impactos.size(), 0, "hay meteoritos en camino")
	assert_eq(sim.snapshot()["combat"]["impacts"].size(), sim.estado.impactos.size())
	var ids: Array = []
	for aviso in sim.snapshot()["warnings"]:
		ids.append(aviso["id"])
	assert_has(ids, "METEORS_INCOMING")
	var cuantos := 0
	for i in 400:
		for evento in sim.avanzar(0.1):
			if evento == "METEOR_IMPACT":
				cuantos += 1
	assert_eq(cuantos, 5)
	assert_true(sim.estado.impactos.is_empty())
	assert_true(sim.estado.meteoritos_en_curso.is_empty())
	assert_true(panel["hp"] <= 100.0)


func test_un_meteorito_daña_edificios_y_rover_dentro_de_su_radio() -> void:
	var panel := _edificio("panel_solar", Vector2i(-8, -9))
	var lejos := _edificio("luz", Vector2i(-8, -3))
	sim.estado.companero = false
	sim.estado.casilla_rover = Vector2i(-8, -8)
	sim.estado.impactos.append({"tile": Vector2i(-8, -9), "t": 0.05, "dano": 60.0, "radio": 1.5})
	var eventos := _combatir(0.2)
	assert_has(eventos, "METEOR_IMPACT")
	assert_has(eventos, "ROVER_HIT")
	assert_eq(panel["hp"], 40.0)
	assert_eq(lejos["hp"], 80.0)
	assert_eq(sim.estado.rover_hp, 75.0)


func test_los_meteoritos_caen_siempre_en_los_mismos_sitios() -> void:
	var otro := _nueva()
	_operar(otro)
	for s in [sim, otro]:
		s.estado.sol = 4
		s.estado.hora = 13.99
	var a := _jugar(20.0)
	var b: Array[String] = []
	for i in 200:
		b.append_array(otro.avanzar(0.1))
	assert_eq(a, b)
	assert_eq(sim.estado.edificios, otro.estado.edificios)


# --- Guardado y rendimiento ------------------------------------------------------------------------------------------

func test_guardar_y_cargar_conserva_monstruos_y_amenaza() -> void:
	_ir_a(2, 19.99)
	_jugar(12.0)
	sim.estado.amenaza = 7.0
	sim.estado.rover_hp = 64.0
	var antes: Array = sim.estado.enemigos.duplicate(true)
	assert_gt(antes.size(), 0)
	var datos: Dictionary = str_to_var(var_to_str(sim.guardar()))
	var otra := _nueva()
	assert_true(otra.cargar(datos))
	assert_eq(otra.estado.enemigos.size(), antes.size())
	assert_eq(otra.estado.enemigos[0]["pos"], antes[0]["pos"])
	assert_eq(otra.estado.enemigos[0]["dest"], antes[0]["dest"])
	assert_eq(otra.estado.amenaza, 7.0)
	assert_eq(otra.estado.rover_hp, 64.0)
	assert_eq(otra.estado.oleadas_hechas, sim.estado.oleadas_hechas)
	otra.avanzar(0.5)  # sigue andando


func test_dos_partidas_iguales_dan_los_mismos_monstruos() -> void:
	var otro := _nueva()
	_operar(otro)
	for s in [sim, otro]:
		s.estado.sol = 3
		s.estado.hora = 20.99
	_jugar(30.0)
	for i in 300:
		otro.avanzar(0.1)
	assert_eq(sim.estado.enemigos, otro.estado.enemigos)


func test_el_combate_a_tope_es_barato() -> void:
	for i in 6:
		_edificio("torreta", Vector2i(-5, -12 + i * 2))
	for i in combate.max_activos:
		var enemigo := _monstruo("arana", Vector2(-3.0, -11.0 + float(i)), Vector2i(-3, -11 + i))
		enemigo["hp"] = 9999.0
	var t0 := Time.get_ticks_usec()
	for i in 200:
		sim._combate.avanzar(sim.estado, 0.05, 0.0, sim._energia)
	var por_paso_ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 200.0
	assert_lt(por_paso_ms, 3.0, "20 monstruos y 6 torretas: %.3f ms por paso" % por_paso_ms)
	var t1 := Time.get_ticks_usec()
	for i in 50:
		sim.snapshot()
	var snapshot_ms := float(Time.get_ticks_usec() - t1) / 1000.0 / 50.0
	assert_lt(snapshot_ms, 5.0, "snapshot con combate: %.3f ms" % snapshot_ms)


func test_cada_efecto_de_la_vista_lleva_un_numero_de_serie_distinto() -> void:
	var antes: int = sim.estado.siguiente_disparo
	sim.estado.edificios.clear()
	sim._combate._efecto(sim.estado, Vector2i(1, 1), Vector2(2, 2), 0.2, "shot")
	sim._combate._efecto(sim.estado, Vector2i(1, 1), Vector2(2, 2), 0.2, "shot")
	assert_eq(sim.estado.disparos[0]["n"], antes)
	assert_eq(sim.estado.disparos[1]["n"], antes + 1)


func test_las_opciones_de_construccion_traen_el_alcance_de_las_torretas() -> void:
	var opciones: Array = sim.snapshot()["build_options"]
	var alcances := {}
	for o in opciones:
		alcances[o["id"]] = o["range"]
	assert_eq(alcances["torreta"], 6.0)
	assert_eq(alcances["torreta_2"], 8.0)
	assert_eq(alcances["panel_solar"], 0.0)
