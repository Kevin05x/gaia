extends GutTest
## Bloque A de la historia: recursos, edificios de la base, Antena Científica, nodos de historia con
## decisiones y los 4 finales (content/economia.json y content/historia.json).

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

var economia: Economy
var historia: StoryData
var sim: Simulation


func _nueva(con_historia: bool = true) -> Simulation:
	return Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"),
		economia, historia if con_historia else null)


func before_each() -> void:
	economia = Economy.desde_archivo("res://content/economia.json")
	historia = StoryData.desde_archivo("res://content/historia.json")
	sim = _nueva()


func _operar(simulacion: Simulation = sim, diseno: Array[String] = DISENO) -> void:
	for id in diseno:
		assert_true(simulacion.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(simulacion.ejecutar("design_start")["ok"])
	assert_true(simulacion.ejecutar("landing_finished")["ok"])


## Elige la opción «opcion» del nodo pendiente (falla si no hay nodo o es otro).
func _decidir(nodo: String, opcion: int = 0) -> void:
	assert_eq(sim.estado.historia_nodo, nodo, "nodo esperado")
	var r := sim.ejecutar("decide", {"choice": opcion})
	assert_true(r["ok"], "decidir %s/%d: %s" % [nodo, opcion, r["reason"]])


## La radio no espera al jugador: comprueba que ya sonó y que la misión no está detenida.
func _radio(nodo: String) -> void:
	assert_eq(sim.estado.historia_radio, nodo, "radio esperada")
	assert_true(sim.estado.historia_nodo.is_empty(), "la radio no deja decisiones pendientes")


## Juega hasta que suene la radio de «nodo» (respeta el respiro entre eventos).
func _esperar_radio(nodo: String) -> void:
	for i in range(3000):
		if sim.estado.historia_radio == nodo:
			break
		sim.avanzar(0.2)
	_radio(nodo)


## Deja «nodo» como el siguiente de la historia, sin respiro (para probar un nodo concreto).
func _forzar(nodo: String) -> void:
	sim.estado.historia_espera = nodo
	sim.estado.historia_t_ultimo = -1000.0


## Pone una nave de fuga ya terminada (sin pasar por las obras).
func _poner_nave() -> void:
	sim.estado.edificios.append({"id": "nave_fuga-9", "type": "nave_fuga", "tile": Vector2i(-5, -5), "level": 4, "target_level": 4, "elapsed": 12.0, "seconds": 12.0, "active": true, "hp": 100.0, "produced": 0.0, "cd": 0.0})


func _avanzar(segundos: float, paso: float = 0.2) -> Array[String]:
	var eventos: Array[String] = []
	var t := 0.0
	while t < segundos:
		eventos.append_array(sim.avanzar(paso))
		t += paso
	return eventos


func _dar(recursos: Dictionary) -> void:
	for r in recursos:
		sim.estado.recursos[r] = int(recursos[r])


func _subir_antena() -> void:
	assert_true(sim.ejecutar("upgrade")["ok"])
	var nivel := sim.estado.nivel_antena
	for i in range(200):
		sim.avanzar(0.2)
		if sim.estado.nivel_antena > nivel:
			return
	fail_test("la antena no subió de nivel")


func test_los_datos_cargan_sin_errores() -> void:
	assert_eq(economia.errores.size(), 0, "economía: %s" % [economia.errores])
	assert_eq(historia.errores.size(), 0, "historia: %s" % [historia.errores])
	assert_eq(historia.intro.size(), 4, "cuatro pantallas de introducción")
	assert_eq(historia.finales.size(), 4, "cuatro finales")


func test_cada_nodo_tiene_una_opcion_que_no_depende_de_rocky() -> void:
	for id in historia.nodos:
		var libre := false
		for opcion in historia.nodos[id]["opciones"]:
			if not bool(opcion.get("requiere_companero", false)):
				libre = true
		assert_true(libre, "%s se puede decidir sin compañero" % id)


func test_todos_los_textos_estan_en_espanol_e_ingles() -> void:
	for pantalla in historia.intro:
		assert_true(pantalla.has("es") and pantalla.has("en"))
	for id in historia.nodos:
		var nodo: Dictionary = historia.nodos[id]
		for clave in ["acto", "titulo", "texto", "objetivo"]:
			assert_true(nodo[clave].has("es") and nodo[clave].has("en"), "%s.%s" % [id, clave])
		for opcion in nodo["opciones"]:
			for clave in ["texto", "detalle", "registro"]:
				assert_true(opcion[clave].has("es") and opcion[clave].has("en"), "%s opción %s" % [id, clave])
	for id in historia.finales:
		assert_true(historia.finales[id]["texto"].has("es") and historia.finales[id]["texto"].has("en"), id)


func test_empieza_con_recursos_iniciales_y_sin_antena() -> void:
	_operar()
	var datos := sim.snapshot()
	assert_eq(datos["resources"], {"rocas": 30, "olivino": 0, "hielo": 0, "xenolito": 0})
	assert_eq(datos["antenna_level"], 0)
	assert_eq(datos["resource_capacity"], 150)
	assert_eq(datos["buildings"].size(), 1, "solo el sitio de la antena")
	assert_eq(datos["base"]["antenna_tile"], Vector2i(-7, -9))


func test_el_primer_nodo_es_una_radio_y_la_mision_sigue() -> void:
	_operar()
	var datos := sim.snapshot()
	assert_true(datos["story"]["pending"].is_empty(), "la radio no detiene la misión")
	assert_eq(datos["story"]["radio"]["id"], "aterrizaje")
	assert_eq(datos["story"]["radio"]["n"], 1)
	assert_eq(datos["story"]["radio"]["dialogue"].size(), 3)
	var hora := sim.estado.hora
	sim.avanzar(1.0)
	assert_gt(sim.estado.hora, hora, "el tiempo corre mientras suena la radio")
	assert_eq(sim.snapshot()["story"]["objective"]["es"], historia.nodos["aterrizaje"]["objetivo"]["es"])


func test_una_decision_si_detiene_la_mision() -> void:
	_operar()
	_forzar("noche_aranas")
	sim.estado.hora = 22.0
	sim.estado.nivel_antena = 1
	sim.avanzar(0.2)
	var hora := sim.estado.hora
	assert_eq(sim.estado.historia_nodo, "noche_aranas")
	assert_eq(sim.snapshot()["story"]["pending"]["scene"], "corta")
	assert_eq(sim.avanzar(5.0).size(), 0)
	assert_eq(sim.estado.hora, hora, "el tiempo no corre con una decisión pendiente")


func test_la_radio_aplica_sus_efectos_y_respeta_el_respiro() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 30, "olivino": 20})
	_subir_antena()
	var datos := sim.estado.datos
	sim.avanzar(0.2)
	assert_eq(sim.estado.historia_radio, "aterrizaje", "aún hay respiro: la alerta no llega con la antena recién hecha")
	_esperar_radio("alerta_sismica")
	assert_eq(sim.estado.datos, datos + 10.0, "la radio de alerta suma 10 de datos")
	assert_eq(sim.estado.historia_radio_n, 2)
	assert_true(sim.estado.historia_nodo.is_empty())


func test_las_metas_muestran_el_avance_del_objetivo() -> void:
	_operar()
	var metas: Array = sim.snapshot()["story"]["goals"]
	assert_eq(metas.size(), 2)
	assert_eq(metas[0]["kind"], "antena")
	assert_false(metas[0]["done"])
	assert_eq(metas[0]["cur"], 0.0)
	_dar({"rocas": 100, "olivino": 100})
	assert_true(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-8, -7)})["ok"])
	_avanzar(6.0)
	metas = sim.snapshot()["story"]["goals"]
	assert_true(metas[1]["done"], "el panel solar ya está construido")
	assert_false(metas[0]["done"])


func test_una_radio_mal_definida_se_detecta() -> void:
	var mala := StoryData.desde_texto(JSON.stringify({"inicio": "a", "nodos": {"a": {"modo": "radio",
		"disparadores": [{"inicio": true}], "opciones": [{"siguiente": "a"}, {"siguiente": "a"}]}}, "finales": {}}))
	assert_true(mala.errores.has("BAD_RADIO:a"), "errores: %s" % [mala.errores])


func test_sin_antena_no_se_transmite() -> void:
	_operar()
	_radio("aterrizaje")
	sim.estado.datos = 10.0
	sim.estado.enlace_abierto = true
	assert_eq(sim.ejecutar("transmit", {"on": true})["reason"], "NO_ANTENNA")


func test_taladrar_un_mineral_da_olivino() -> void:
	_operar()
	_radio("aterrizaje")
	sim.estado.casilla_rover = Vector2i(6, 1)  # junto a JZ-06 (mineral en 6,2)
	assert_true(sim.ejecutar("act", {"action": "drill", "target_id": "JZ-06"})["ok"])
	_avanzar(5.0)
	assert_eq(sim.estado.recursos["olivino"], 14)
	assert_eq(sim.estado.recursos["rocas"], 34)


func test_construir_un_panel_solar() -> void:
	_operar()
	_radio("aterrizaje")
	assert_eq(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(5, 5)})["reason"], "OUT_OF_BASE")
	assert_eq(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-9, -9)})["reason"], "TILE_BLOCKED", "la estación")
	assert_eq(sim.ejecutar("build", {"building": "hangar", "tile": Vector2i(-8, -7)})["reason"], "NO_RESOURCES")
	var carga_antes := sim.estado.carga_w
	assert_true(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-8, -7)})["ok"])
	assert_eq(sim.estado.recursos["rocas"], 10, "cuesta 20 rocas")
	assert_eq(sim.ejecutar("build", {"building": "domo", "tile": Vector2i(-7, -7)})["reason"], "BUILD_BUSY")
	var generacion_antes := sim.estado.generacion_w
	var eventos := _avanzar(6.0)
	assert_true(eventos.has("BUILD_DONE:panel_solar:panel_solar-1"), "eventos: %s" % [eventos])
	sim.avanzar(0.2)
	assert_gt(sim.estado.generacion_w, generacion_antes + 20.0, "el panel de la base genera de día")
	assert_eq(sim.estado.carga_w, carga_antes)
	assert_eq(sim.ejecutar("move", {"tile": Vector2i(-8, -7)})["reason"], "NO_PATH", "el rover no pisa el edificio")


func test_apagar_un_edificio_deja_de_consumir() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 100, "olivino": 100})
	assert_true(sim.ejecutar("build", {"building": "extractor_hielo", "tile": Vector2i(-8, -7)})["ok"])
	_avanzar(11.0)
	var id: String = sim.estado.edificios[1]["id"]
	sim.avanzar(0.2)
	var con := sim.estado.carga_w
	assert_true(sim.ejecutar("toggle_building", {"id": id, "on": false})["ok"])
	sim.avanzar(0.2)
	assert_almost_eq(sim.estado.carga_w, con - 20.0, 0.01)


func test_el_extractor_produce_hielo() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 100, "olivino": 100})
	assert_true(sim.ejecutar("build", {"building": "extractor_hielo", "tile": Vector2i(-8, -7)})["ok"])
	_avanzar(11.0)
	_avanzar(60.0)  # unas horas de juego
	assert_gt(sim.estado.recursos["hielo"], 0)


func test_la_antena_sube_de_nivel_y_dispara_la_alerta() -> void:
	_operar()
	_radio("aterrizaje")
	assert_eq(sim.ejecutar("upgrade")["reason"], "NO_RESOURCES")
	_dar({"rocas": 30, "olivino": 20})
	_subir_antena()
	assert_eq(sim.estado.nivel_antena, 1)
	assert_eq(sim.estado.recursos["rocas"], 0)
	_esperar_radio("alerta_sismica")
	_dar({"olivino": 100, "hielo": 100})
	assert_eq(sim.ejecutar("upgrade")["reason"], "NEEDS_HANGAR", "el nivel 2 necesita el hangar")


func test_la_rama_militar_hiere_a_rocky_y_baja_la_etica() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 30, "olivino": 20})
	_subir_antena()
	_esperar_radio("alerta_sismica")
	for i in range(3000):
		sim.avanzar(0.2)
		if not sim.estado.historia_nodo.is_empty():
			break
	var rocas := int(sim.estado.recursos["rocas"])
	_decidir("noche_aranas", 1)
	assert_eq(sim.estado.etica, 35.0)
	assert_eq(sim.estado.rocky_hp, 80.0)
	assert_eq(int(sim.estado.recursos["rocas"]), rocas + 35)
	assert_eq(sim.estado.historia_espera, "glaciar_militar")
	assert_eq(sim.snapshot()["story"]["log"].size(), 3)


func test_llegar_a_100_no_gana_hasta_resolver_el_climax() -> void:
	_operar()
	_radio("aterrizaje")
	sim.estado.enviados = 100.0
	sim.avanzar(0.2)
	assert_true(sim.informe.is_empty(), "la historia sigue: falta el clímax")
	_forzar("climax_puro")
	sim.avanzar(0.2)
	_decidir("climax_puro", 0)
	sim.avanzar(0.2)
	assert_true(sim.informe.is_empty(), "falta la nave de fuga")
	_poner_nave()
	sim.avanzar(0.2)
	assert_true(sim.informe["success"])
	assert_eq(sim.informe["ending"]["id"], "simbiosis")


func test_el_sacrificio_de_rocky_completa_la_transmision() -> void:
	_operar()
	_radio("aterrizaje")
	_forzar("climax_puro")
	sim.estado.sol = 6
	sim.avanzar(0.2)
	_decidir("climax_puro", 1)
	sim.avanzar(0.2)
	assert_true(sim.informe.is_empty(), "también el sacrificio necesita la nave de fuga")
	_poner_nave()
	sim.avanzar(0.2)
	assert_true(sim.informe["success"])
	assert_eq(sim.informe["ending"]["id"], "sacrificio")
	assert_eq(sim.estado.rocky_hp, 0.0)


func test_mantener_las_torretas_termina_en_silencio_orbital() -> void:
	_operar()
	_radio("aterrizaje")
	_forzar("climax_destructivo")
	sim.estado.sol = 6
	sim.avanzar(0.2)
	_decidir("climax_destructivo", 2)
	sim.avanzar(0.2)
	assert_false(sim.informe["success"])
	assert_eq(sim.informe["ending"]["id"], "silencio")
	assert_has(sim.informe["causes"], "CAUSE_STORY_FAIL")


func test_sin_companero_no_se_puede_elegir_a_rocky() -> void:
	var diseno: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "taladro"]
	_operar(sim, diseno)
	_radio("aterrizaje")
	_forzar("nidos")
	sim.estado.sol = 4
	sim.avanzar(0.2)
	var opciones: Array = sim.snapshot()["story"]["pending"]["choices"]
	assert_false(opciones[0]["enabled"])
	assert_eq(opciones[0]["reason"], "NO_COMPANION")
	assert_eq(sim.ejecutar("decide", {"choice": 0})["reason"], "NO_COMPANION")
	assert_true(sim.ejecutar("decide", {"choice": 1})["ok"])


func test_guardar_y_cargar_conserva_la_base_y_la_historia() -> void:
	_operar()
	_radio("aterrizaje")
	assert_true(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-8, -7)})["ok"])
	_avanzar(6.0)
	var datos := sim.guardar()
	var otra := _nueva()
	assert_true(otra.cargar(str_to_var(var_to_str(datos))))
	assert_eq(otra.snapshot()["buildings"].size(), 2)
	assert_eq(otra.snapshot()["resources"], sim.snapshot()["resources"])
	assert_eq(otra.estado.historia_espera, "alerta_sismica")
	assert_eq(otra.ejecutar("move", {"tile": Vector2i(-8, -7)})["reason"], "NO_PATH", "el edificio sigue bloqueando")


func test_sin_economia_todo_funciona_como_antes() -> void:
	var antigua := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"))
	_operar(antigua)
	var datos := antigua.snapshot()
	assert_false(datos.has("resources"))
	assert_false(datos.has("story"))
	assert_eq(datos["antenna_level"], 1)
	assert_eq(antigua.ejecutar("build", {"building": "domo", "tile": Vector2i(-8, -7)})["reason"], "UNKNOWN_COMMAND")


func test_la_senal_se_detiene_en_85_hasta_el_climax() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 30, "olivino": 20})
	_subir_antena()
	_esperar_radio("alerta_sismica")
	sim.estado.datos = 40.0
	sim.estado.enviados = 80.0
	sim.estado.enlace_abierto = true
	sim.estado.hora = 9.0
	assert_true(sim.ejecutar("transmit", {"on": true})["ok"])
	_avanzar(5.0)
	assert_eq(sim.estado.enviados, 85.0, "no pasa del 85 %")
	assert_false(sim.estado.transmitiendo)
	assert_eq(sim.ejecutar("transmit", {"on": true})["reason"], "SIGNAL_CAPPED")


func test_decidido_el_climax_la_senal_llega_al_100_y_no_pasa() -> void:
	_operar()
	_radio("aterrizaje")
	_dar({"rocas": 30, "olivino": 20})
	_subir_antena()
	_esperar_radio("alerta_sismica")
	sim.estado.historia_final = StorySystem.FINAL_BUENO
	sim._fijar_tope_envio()
	sim.estado.datos = 40.0
	sim.estado.enviados = 90.0
	sim.estado.enlace_abierto = true
	sim.estado.hora = 9.0
	assert_true(sim.ejecutar("transmit", {"on": true})["ok"])
	_avanzar(5.0)
	assert_eq(sim.estado.enviados, float(sim.estado.meta), "se queda en la meta, sin pasar del 100 %")
	for aviso in sim.snapshot()["warnings"]:
		assert_ne(aviso["id"], "SIGNAL_CAPPED", "ya no es un tope por el clímax")



# --- Nave de fuga (bloque D) ------------------------------------------------------------------------------------------

func _opcion(id: String) -> Dictionary:
	for o in sim.snapshot()["build_options"]:
		if o["id"] == id:
			return o
	return {}


func test_la_nave_de_fuga_no_aparece_en_el_menu_hasta_decidir_el_climax() -> void:
	_operar()
	assert_true(_opcion("nave_fuga").is_empty())
	sim.estado.historia_final = "simbiosis"
	var o := _opcion("nave_fuga")
	assert_false(o.is_empty())
	assert_false(o["enabled"])
	assert_eq(o["reason"], "NEEDS_HANGAR")


func test_la_nave_pide_hangar_antena_nivel_3_y_materiales() -> void:
	_operar()
	sim.estado.historia_final = "simbiosis"
	sim.estado.edificios.append({"id": "hangar-9", "type": "hangar", "tile": Vector2i(-10, -10), "level": 1, "target_level": 1,
		"elapsed": 12.0, "seconds": 12.0, "active": true, "hp": 300.0, "produced": 0.0, "cd": 0.0})
	assert_eq(_opcion("nave_fuga")["reason"], "NEEDS_ANTENNA_3")
	sim.estado.nivel_antena = 3
	assert_eq(_opcion("nave_fuga")["reason"], "NO_RESOURCES")
	sim.estado.recursos = {"rocas": 150, "olivino": 80, "hielo": 60, "xenolito": 40}
	assert_true(_opcion("nave_fuga")["enabled"])
	var r := sim.ejecutar("build", {"building": "nave_fuga", "tile": Vector2i(-6, -6)})
	assert_true(r["ok"], r["reason"])
	assert_eq(sim.estado.recursos["rocas"], 100, "paga solo el primer módulo (rocas 50)")
	assert_eq(sim.estado.recursos["hielo"], 60, "el hielo se gasta desde el segundo módulo")
	assert_eq(_opcion("nave_fuga")["reason"], "BUILD_BUSY")


func test_tras_el_climax_suena_la_radio_de_la_nave_y_el_objetivo_cambia() -> void:
	_operar()
	_radio("aterrizaje")
	_forzar("climax_puro")
	sim.estado.sol = 6
	sim.avanzar(0.2)
	_decidir("climax_puro", 0)
	for i in range(400):
		sim.avanzar(0.2)
		if sim.estado.historia_radio == "nave_fuga":
			break
	assert_eq(sim.estado.historia_radio, "nave_fuga")
	var historia_vista: Dictionary = sim.snapshot()["story"]
	assert_eq(historia_vista["goals"][0]["id"], "nave_fuga")
	assert_false(historia_vista["goals"][0]["done"])


func test_la_derrota_por_silencio_no_pide_nave() -> void:
	_operar()
	_radio("aterrizaje")
	_forzar("climax_destructivo")
	sim.estado.sol = 6
	sim.avanzar(0.2)
	_decidir("climax_destructivo", 2)
	sim.avanzar(0.2)
	assert_false(sim.informe["success"])


func test_el_informe_con_nave_incluye_su_causa() -> void:
	_operar()
	sim.estado.enviados = 100.0
	sim.estado.historia_final = "simbiosis"
	_poner_nave()
	sim.avanzar(0.2)
	assert_true(sim.informe["success"])
	assert_true(sim.informe["causes"].has("CAUSE_SHIP"))


func _nave_por_modulos() -> Dictionary:
	_operar()
	sim.estado.historia_final = "simbiosis"
	sim.estado.nivel_antena = 3
	sim.estado.edificios.append({"id": "hangar-9", "type": "hangar", "tile": Vector2i(-10, -10), "level": 1, "target_level": 1,
		"elapsed": 12.0, "seconds": 12.0, "active": true, "hp": 300.0, "produced": 0.0, "cd": 0.0})
	sim.estado.recursos = {"rocas": 150, "olivino": 90, "hielo": 60, "xenolito": 40}
	var r := sim.ejecutar("build", {"building": "nave_fuga", "tile": Vector2i(-6, -6)})
	assert_true(r["ok"], r["reason"])
	for edificio in sim.estado.edificios:
		if edificio["type"] == "nave_fuga":
			return edificio
	return {}


func _terminar_obra() -> void:
	for i in range(400):
		sim.avanzar(0.2)
		if not sim.estado.edificios.any(func(e: Dictionary) -> bool: return int(e["target_level"]) > int(e["level"])):
			break


func _vista_nave() -> Dictionary:
	for e in sim.snapshot()["buildings"]:
		if e["type"] == "nave_fuga":
			return e
	return {}


func test_la_nave_se_construye_por_cuatro_modulos_uno_tras_otro() -> void:
	var nave := _nave_por_modulos()
	assert_eq(_vista_nave()["modules"], 4)
	assert_true(_vista_nave()["next_module"].is_empty(), "mientras se hace el primero no hay siguiente")
	_terminar_obra()
	assert_eq(nave["level"], 1)
	var siguiente: Dictionary = _vista_nave()["next_module"]
	assert_eq(siguiente["n"], 2)
	assert_eq(siguiente["name_key"], "MOD_TANK")
	assert_true(siguiente["enabled"])
	for n in [2, 3, 4]:
		var r := sim.ejecutar("build_module", {"id": nave["id"]})
		assert_true(r["ok"], "módulo %d: %s" % [n, r["reason"]])
		assert_eq(sim.ejecutar("build_module", {"id": nave["id"]})["reason"], "BUILD_BUSY", "una obra a la vez")
		_terminar_obra()
		assert_eq(nave["level"], n)
	assert_true(_vista_nave()["next_module"].is_empty(), "no quedan módulos")
	assert_eq(sim.ejecutar("build_module", {"id": nave["id"]})["reason"], "MAX_LEVEL")
	assert_eq(sim.estado.recursos, {"rocas": 0, "olivino": 0, "hielo": 0, "xenolito": 0}, "los cuatro módulos cuestan en total lo previsto")


func test_cada_modulo_pide_sus_materiales() -> void:
	var nave := _nave_por_modulos()
	_terminar_obra()
	sim.estado.recursos["hielo"] = 0
	assert_eq(sim.ejecutar("build_module", {"id": nave["id"]})["reason"], "NO_RESOURCES")
	assert_false(_vista_nave()["next_module"]["enabled"])


func test_no_se_gana_con_la_nave_a_medias() -> void:
	var nave := _nave_por_modulos()
	_terminar_obra()
	sim.estado.enviados = 100.0
	sim.avanzar(0.2)
	assert_true(sim.informe.is_empty(), "con 1 de 4 módulos no basta")
	nave["level"] = 4
	nave["target_level"] = 4
	sim.avanzar(0.2)
	assert_true(sim.informe["success"])


func test_la_meta_de_la_historia_cuenta_los_modulos() -> void:
	var nave := _nave_por_modulos()
	_terminar_obra()
	sim.estado.historia_ultimo = "nave_fuga"
	var metas: Array = sim.snapshot()["story"]["goals"]
	assert_eq(metas[0]["kind"], "modulos")
	assert_eq(metas[0]["cur"], 1.0)
	assert_eq(metas[0]["goal"], 4.0)
	assert_false(metas[0]["done"])


func test_el_evento_de_modulo_y_la_orden_en_otro_edificio() -> void:
	var nave := _nave_por_modulos()
	var eventos: Array[String] = []
	for i in range(400):
		eventos.append_array(sim.avanzar(0.2))
		if nave["level"] == 1:
			break
	assert_true(eventos.has("MODULE_DONE:nave_fuga:1"))
	assert_eq(sim.ejecutar("build_module", {"id": "hangar-9"})["reason"], "NO_MODULES")
	assert_eq(sim.ejecutar("build_module", {"id": "no-existe"})["reason"], "UNKNOWN_BUILDING")


func _nave_con_modulos(modulos: int) -> Dictionary:
	var nave := _nave_por_modulos()
	nave["level"] = modulos
	nave["target_level"] = modulos
	nave["hp"] = 100.0
	return nave


func test_un_golpe_fuerte_destruye_el_modulo_mas_alto_de_la_nave() -> void:
	var nave := _nave_con_modulos(3)
	var eventos: Array[String] = sim._edificios.danar(sim.estado, nave["id"], 30.0)
	assert_eq(int(nave["level"]), 3, "un golpe flojo no destruye nada")
	assert_eq(float(nave["hp"]), 70.0)
	assert_true(eventos.is_empty())
	eventos = sim._edificios.danar(sim.estado, nave["id"], 80.0)
	assert_eq(int(nave["level"]), 2, "pierde el módulo más alto")
	assert_eq(int(nave["target_level"]), 2)
	assert_eq(float(nave["hp"]), 100.0, "el módulo que queda vuelve a tener su vida")
	assert_true(eventos.has("MODULE_LOST:nave_fuga:2"))
	assert_true(sim.estado.edificios.has(nave))


func test_si_la_nave_pierde_todos_los_modulos_desaparece() -> void:
	var nave := _nave_con_modulos(1)
	var eventos: Array[String] = sim._edificios.danar(sim.estado, nave["id"], 500.0)
	assert_true(eventos.any(func(e: String) -> bool: return e.begins_with("BUILDING_DESTROYED:nave_fuga")))
	assert_false(sim.estado.edificios.has(nave))


func test_un_ataque_cancela_el_modulo_que_estaba_en_obra() -> void:
	var nave := _nave_con_modulos(2)
	sim.estado.recursos = {"rocas": 100, "olivino": 100, "hielo": 100, "xenolito": 100}
	assert_true(sim.ejecutar("build_module", {"id": nave["id"]})["ok"])
	assert_eq(int(nave["target_level"]), 3)
	sim._edificios.danar(sim.estado, nave["id"], 500.0)
	assert_eq(int(nave["level"]), 2, "los módulos terminados se conservan")
	assert_eq(int(nave["target_level"]), 2, "la obra en curso se pierde")

