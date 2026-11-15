extends GutTest
## Plan de mejoras del 15 nov, bloque 2: que se entienda el juego (docs/PLAN_MEJORAS.md).

const WorkshopScript := preload("res://scenes/b/workshop.gd")
const LaunchPadScript := preload("res://scenes/b/launch_pad.gd")

var _destino_antes := ""


func before_all() -> void:
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


func before_each() -> void:
	_destino_antes = Destino.id


func after_each() -> void:
	Destino.id = _destino_antes


## Simulación del destino con el catálogo adaptado, como la arma MissionRunner.
func _sim(destino: String) -> Simulation:
	Destino.id = destino
	var cfg := Destino.config(destino)
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, destino, float(cfg.get("factor_capacidad_cohete", 1.0)))
	return Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]),
		MapData.desde_archivo(cfg["mapa"]), catalogo, Economy.desde_archivo(cfg["economia"]))


## Hangar conectado a la simulación igual que en el juego: cada orden se ejecuta y vuelve un snapshot.
func _hangar(sim: Simulation) -> CanvasLayer:
	var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
	hangar.command.connect(func(orden: String, carga: Dictionary) -> void:
		sim.ejecutar(orden, carga)
		hangar.update_snapshot(sim.snapshot()))
	return hangar


func _elegidas(sim: Simulation) -> Array:
	var ids: Array = []
	var seleccion: Dictionary = sim.snapshot()["workshop"]["selection"]
	for cat in seleccion:
		ids.append_array(seleccion[cat])
	ids.sort()
	return ids


# --- 2.4 Diseño recomendado ------------------------------------------------------------------------------------------

func test_2_4_marte_entra_al_hangar_con_el_diseno_recomendado() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	_hangar(sim).update_snapshot(sim.snapshot())
	var esperado := ["antena_rele", "camara", "chasis_base", "cohete_medio", "espectrometro", "panel_solar", "taladro",
		"trayectoria_rapida"]
	assert_eq(_elegidas(sim), esperado, "cohete medio, trayectoria rápida, chasis base, panel, relé y tres instrumentos")
	assert_true(sim.snapshot()["workshop"]["valid"], "y el diseño es válido")


func test_2_4_la_luna_recomienda_mmrtg() -> void:
	var sim := _sim("luna")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	_hangar(sim).update_snapshot(sim.snapshot())
	var elegidas := _elegidas(sim)
	assert_has(elegidas, "mmrtg", "en la Luna, energía que no depende del Sol")
	assert_does_not_have(elegidas, "panel_solar")
	assert_has(elegidas, "trayectoria_directa_luna")
	assert_true(sim.snapshot()["workshop"]["valid"], "y el diseño es válido")


func test_2_4_el_boton_vuelve_a_poner_el_diseno_recomendado() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	var recomendado := _elegidas(sim)
	sim.ejecutar("design_remove", {"part_id": "espectrometro"})
	sim.ejecutar("design_add", {"part_id": "dron"})
	sim.ejecutar("design_remove", {"part_id": "trayectoria_rapida"})
	sim.ejecutar("design_add", {"part_id": "trayectoria_hohmann"})
	hangar.update_snapshot(sim.snapshot())
	assert_ne(_elegidas(sim), recomendado, "el jugador lo cambió")
	assert_not_null(hangar._recomendado, "hay botón «Diseño recomendado»")
	hangar._recomendado.pressed.emit()
	assert_eq(_elegidas(sim), recomendado, "el botón lo restaura")


func test_2_4_la_plataforma_llega_con_el_cohete_medio_marcado() -> void:
	var sim := _sim("marte")
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	assert_eq(plataforma.elegido, "cohete_medio", "basta con abordar")
	plataforma._on_card("cohete_ligero", 600.0, 39.0)
	assert_eq(plataforma.elegido, "cohete_ligero", "y se puede elegir otro")
	plataforma._signature = ""
	plataforma.update_snapshot(sim.snapshot())
	assert_eq(plataforma.elegido, "cohete_ligero", "la marca recomendada no pisa la elección del jugador")


# --- 2.5 Aviso si falta un instrumento clave, con confirmación al despegar (sin bloquear) ----------------------------

func _textos_del_resumen(hangar: CanvasLayer) -> String:
	var textos := ""
	for etiqueta in hangar._summary_box.find_children("*", "Label", true, false):
		textos += (etiqueta as Label).text + "\n"
	return textos


func test_2_5_sin_taladro_se_avisa_en_rojo_y_no_bloquea() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	sim.ejecutar("design_remove", {"part_id": "taladro"})
	var taller: Dictionary = sim.snapshot()["workshop"]
	assert_has(taller["notices"], "MISSING_KEY:taladro", "la simulación avisa")
	assert_true(taller["valid"], "pero no bloquea")
	hangar.update_snapshot(sim.snapshot())
	assert_string_contains(_textos_del_resumen(hangar), "Sin taladro no podrás tomar muestras")


func test_2_5_despegar_sin_un_instrumento_clave_pide_confirmacion() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	sim.ejecutar("design_remove", {"part_id": "espectrometro"})
	hangar.update_snapshot(sim.snapshot())
	var ordenes: Array[String] = []
	hangar.command.connect(func(orden: String, _c: Dictionary) -> void: ordenes.append(orden))
	hangar.validated = true
	hangar._on_action()
	assert_false(ordenes.has("design_start"), "no despega todavía")
	assert_true(is_instance_valid(hangar._confirmacion), "pregunta antes")
	var botones: Array = hangar._confirmacion.find_children("*", "Button", true, false)
	assert_eq(botones.size(), 2, "«Volver al taller» y «Despegar igual»")
	(botones[1] as Button).pressed.emit()
	assert_true(ordenes.has("design_start"), "«Despegar igual» despega")


func test_2_5_con_todos_los_instrumentos_despega_sin_preguntar() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	assert_eq(WorkshopScript.clave_que_faltan(sim.snapshot()["workshop"]), [])
	var ordenes: Array[String] = []
	hangar.command.connect(func(orden: String, _c: Dictionary) -> void: ordenes.append(orden))
	hangar.validated = true
	hangar._on_action()
	assert_true(ordenes.has("design_start"))
	assert_false(is_instance_valid(hangar._confirmacion))


# --- 2.1 Tarjeta de objetivo al empezar la misión ------------------------------------------------------------------------

const ObjetivoScript := preload("res://scenes/b/objetivo_panel.gd")


func _foto(extra: Dictionary = {}) -> Dictionary:
	var s := {"phase": "operations", "sol": 1, "sent": 0.0, "data": 0.0, "goal": 100, "sol_limit": 6}
	s.merge(extra, true)
	return s


func _texto_de(nodo: Node) -> String:
	var t := ""
	for l in nodo.find_children("*", "Label", true, false):
		t += (l as Label).text + "\n"
	return t


func test_2_1_la_tarjeta_sale_una_vez_con_la_meta_y_los_tres_pasos() -> void:
	var panel: CanvasLayer = add_child_autofree(ObjetivoScript.new())
	panel.update_snapshot({"phase": "landing", "sol": 1})
	assert_false(panel.is_open(), "no durante el aterrizaje")
	panel.update_snapshot(_foto())
	assert_true(panel.is_open(), "sale al empezar las operaciones")
	var texto := _texto_de(panel)
	assert_string_contains(texto, "Envía 100 datos de ciencia a la Tierra antes de que acabe el sol 6")
	for clave in ["OBJ_STEP1_T", "OBJ_STEP2_T", "OBJ_STEP3_T"]:
		assert_string_contains(texto, tr(clave))
	var boton: Button = panel.find_children("*", "Button", true, false)[0]
	assert_eq(boton.text, "Entendido")
	boton.pressed.emit()
	assert_false(panel.is_open())
	panel.update_snapshot(_foto())
	assert_false(panel.is_open(), "una sola vez")


func test_2_1_no_sale_al_continuar_una_partida_empezada() -> void:
	var panel: CanvasLayer = add_child_autofree(ObjetivoScript.new())
	panel.update_snapshot(_foto({"sent": 12.0}))
	assert_false(panel.is_open())
	panel.update_snapshot(_foto())
	assert_false(panel.is_open(), "ni después")


func test_2_1_espera_a_que_cierre_la_escena_o_el_imprevisto() -> void:
	var panel: CanvasLayer = add_child_autofree(ObjetivoScript.new())
	var ocupada := [true]
	panel.tapada = func() -> bool: return ocupada[0]
	panel.update_snapshot(_foto())
	assert_false(panel.is_open(), "espera")
	ocupada[0] = false
	panel.update_snapshot(_foto())
	assert_true(panel.is_open(), "y sale después")


func test_2_1_en_la_luna_habla_de_dias_y_de_la_energia_lunar() -> void:
	Destino.id = "luna"
	Destino.aplicar_textos()
	var panel: CanvasLayer = add_child_autofree(ObjetivoScript.new())
	panel.update_snapshot(_foto())
	var texto := _texto_de(panel)
	Destino.id = "marte"
	Destino.aplicar_textos()
	assert_string_contains(texto, "antes de que acabe el día 6")
	assert_string_contains(texto, "70 %")


func test_2_1_la_mision_muestra_la_tarjeta_tras_el_aterrizaje() -> void:
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	juego.saltar_taller = true
	add_child_autofree(juego)
	await get_tree().process_frame
	assert_false(juego.view.objetivo.is_open(), "durante el aterrizaje no")
	juego.port.submit("landing_finished")
	for i in range(5):
		await get_tree().process_frame
	if juego.view.story.is_open():
		juego.view.story.pulsar()
		juego.view.story.pulsar()
		juego.port.submit("pause", {"paused": false})
	for i in range(5):
		await get_tree().process_frame
	juego.view.apply_snapshot(juego.sim.snapshot())
	assert_true(juego.view.objetivo.is_open() or juego.view.story.is_open(), "la tarjeta sale (o espera a la escena)")


# --- 2.2 Tutorial en ventana con capturas reales, «Siguiente» y «Saltar» ---------------------------------------------

const TutorialPanelScript := preload("res://scenes/b/tutorial_panel.gd")


func test_2_2_hay_captura_de_cada_paso_en_los_dos_destinos_e_idiomas() -> void:
	for destino in ["marte", "luna"]:
		var datos := TutorialData.desde_archivo(Destino.config(destino)["tutorial"])
		for paso in datos.pasos:
			for idioma in ["es", "en"]:
				var ruta := TutorialPanelScript.ruta_captura(str(paso.get("captura", paso["id"])), destino, idioma)
				assert_true(ruta.contains("/%s/%s/" % [destino, idioma]), "%s/%s/%s tiene captura" % [destino, idioma, paso["id"]])


func test_2_2_siguiente_pasa_de_paso_sin_cumplirlo() -> void:
	var cfg := Destino.config("marte")
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	var sim := Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]),
		MapData.desde_archivo(cfg["mapa"]), catalogo, Economy.desde_archivo(cfg["economia"]), null, null,
		TutorialData.desde_archivo(cfg["tutorial"]))
	for id in ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	var t: Dictionary = sim.snapshot()["tutorial"]
	assert_true(t["active"])
	assert_eq(int(t["step"]), 1)
	assert_true(sim.ejecutar("tutorial_next")["ok"])
	t = sim.snapshot()["tutorial"]
	assert_eq(int(t["step"]), 2, "«Siguiente» da el paso por visto")
	for i in range(int(t["total"])):
		sim.ejecutar("tutorial_next")
	assert_false(sim.snapshot()["tutorial"]["active"], "tras el último, termina")


func test_2_2_la_ventana_muestra_captura_y_botones_y_se_pliega() -> void:
	var panel: CanvasLayer = add_child_autofree(TutorialPanelScript.new())
	var ordenes: Array[String] = []
	panel.command.connect(func(o: String, _c: Dictionary) -> void: ordenes.append(o))
	panel.update_snapshot({"phase": "operations", "tutorial": {"active": true, "step": 1, "total": 6, "id": "mover",
		"text": {"es": "Haz clic en el suelo.", "en": "Click the ground."}, "highlight": "mapa", "image": "mover"}})
	assert_true(panel.is_showing())
	assert_true(panel.is_expanded(), "desplegada: la radio espera")
	assert_not_null(panel._imagen.texture, "con la captura real del paso")
	assert_eq(panel._siguiente.text, "Siguiente")
	panel._siguiente.pressed.emit()
	panel._skip.pressed.emit()
	assert_eq(ordenes, ["tutorial_next", "tutorial_skip"])
	panel.set_plegada(true)
	assert_false(panel.is_expanded(), "plegada: la radio puede hablar")
	assert_true(panel.is_showing())
	assert_false(panel._cuerpo.visible)


func test_2_4_el_hangar_dibuja_el_diseno_recomendado_y_no_la_foto_vieja() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	assert_eq(hangar.snapshot["workshop"]["selection"], sim.snapshot()["workshop"]["selection"],
		"lo que se ve es el diseño ya armado")


# --- 2.3 «Cómo jugar» con capturas reales en sus 5 páginas -------------------------------------------------------------

func test_2_3_cada_pagina_de_como_jugar_tiene_su_captura() -> void:
	var MenuTutorial := preload("res://scenes/menu/tutorial.gd")
	assert_eq(MenuTutorial.CAPTURAS.size(), MenuTutorial.PAGINAS)
	for idioma in ["es", "en"]:
		TranslationServer.set_locale(idioma)
		var t: Control = MenuTutorial.new()
		add_child_autofree(t)
		for pagina in range(MenuTutorial.PAGINAS):
			t._ir(pagina)
			assert_not_null(t._imagen.texture, "%s, página %d con captura" % [idioma, pagina + 1])
			assert_string_contains(t._imagen.texture.resource_path, "/%s/" % idioma, "en su idioma")
	TranslationServer.set_locale("es")
