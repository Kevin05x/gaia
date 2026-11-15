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
			if not paso.has("captura") and str(paso["id"]) == "bienvenida":
				continue  # paso de lectura: sin foto, solo texto
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


# --- 2.6 Cada opción de un imprevisto dice qué implica ----------------------------------------------------------------

const ImprevistoPanelScript := preload("res://scenes/b/imprevisto_panel.gd")


func test_2_6_el_efecto_de_desviarse_en_lenguaje_de_juego() -> void:
	var texto := ImprevistoPanelScript.efecto_previsto({"energia_wh": -90, "datos": 10, "desvio_casillas": 5}, 15.0, 0.0)
	assert_eq(texto, "-90 Wh (unas 6 h de consumo actual) · +10 datos en memoria · el rover se desvía unas 5 casillas")


func test_2_6_todas_las_opciones_de_los_9_imprevistos_explican_su_efecto() -> void:
	for destino in ["marte", "luna"]:
		var sistema := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", destino)
		for id in sistema.imprevistos:
			var e := _sim("marte").estado
			e.imprevisto = {"id": id}
			var vista := sistema.para_la_vista(e)
			assert_eq((vista["effects"] as Array).size(), (vista["options"] as Array).size(), id)
			for efectos in vista["effects"]:
				var texto := ImprevistoPanelScript.efecto_previsto(efectos, 20.0, 30.0)
				assert_false(texto.is_empty() or texto.contains("UNEXP_"), "%s: %s" % [id, texto])


func test_2_6_la_ventana_muestra_el_efecto_debajo_de_cada_opcion() -> void:
	var panel: CanvasLayer = add_child_autofree(ImprevistoPanelScript.new())
	var sistema := ImprevistosSystem.desde_archivo("res://content/imprevistos.json", "marte")
	var e := _sim("marte").estado
	e.imprevisto = {"id": "conjuncion_solar"}
	panel.update_snapshot({"unexpected": sistema.para_la_vista(e), "data": 30.0, "battery": {"load_w": 30.0}})
	var efectos: Array = panel.find_children("Efecto*", "Label", true, false)
	assert_eq(efectos.size(), 2, "un efecto por opción")
	assert_string_contains((efectos[0] as Label).text, "enlace cerrado 8 h")
	assert_string_contains((efectos[1] as Label).text, "se pierde el 33 % de los datos a bordo (unos 10)")


# --- 2.7 Cada decisión de la historia dice qué cambiará ------------------------------------------------------------------

const StoryPanelScript := preload("res://scenes/b/story_panel.gd")
## Opciones que hoy no cambian nada visible (lista para Tony en docs/PLAN_MEJORAS.md, 2.7): dejar algo para después.
const SIN_HUELLA := ["falla_sismografo:0", "estacion_auxiliar:2"]


func test_2_7_cada_opcion_de_una_decision_dice_que_cambiara() -> void:
	var datos := StoryData.desde_archivo("res://content/historia.json")
	var sistema := StorySystem.new(datos, null)
	var e := _sim("marte").estado
	var revisadas := 0
	for id in datos.nodos:
		var opciones: Array = datos.nodos[id].get("opciones", [])
		if opciones.size() < 2:
			continue  # no es una decisión: solo «continuar»
		for i in range(opciones.size()):
			var texto := StoryPanelScript.resumen_cambios(sistema.cambios(e, opciones[i]))
			revisadas += 1
			if SIN_HUELLA.has("%s:%d" % [id, i]):
				assert_eq(texto, "", "%s:%d sigue sin huella (está en la lista para Tony)" % [id, i])
			else:
				assert_false(texto.is_empty(), "%s:%d dice qué cambia" % [id, i])
				assert_false(texto.contains("STORY_CH") or texto.contains("RES_"), texto)
	assert_gt(revisadas, 10)


func test_2_7_la_rama_y_los_finales_se_anuncian() -> void:
	var datos := StoryData.desde_archivo("res://content/historia.json")
	var sistema := StorySystem.new(datos, null)
	var e := _sim("marte").estado
	var cientifica := StoryPanelScript.resumen_cambios(sistema.cambios(e, datos.nodos["noche_aranas"]["opciones"][0]))
	assert_string_contains(cientifica, "la historia sigue por la rama científica")
	assert_string_contains(cientifica, "+15 de Hielo")
	var silencio := StoryPanelScript.resumen_cambios(sistema.cambios(e, datos.nodos["climax_destructivo"]["opciones"][2]))
	assert_string_contains(silencio, "lleva al final «Final 4 · Silencio orbital»")
	assert_string_contains(silencio, "termina la misión")


# --- 2.8 «Nueva partida» → Marte: salen la introducción y las escenas de Tony ----------------------------------------

func test_2_8_la_introduccion_las_escenas_y_los_finales_tienen_imagen() -> void:
	var datos := StoryData.desde_archivo("res://content/historia.json")
	var sistema := StorySystem.new(datos, null)
	var paginas: Array = sistema.intro()
	assert_gt(paginas.size(), 0, "hay introducción («de qué trata el juego»)")
	for pagina in paginas:
		assert_not_null(StoryPanelScript.image_of(str(pagina.get("image", ""))), "intro: %s" % pagina.get("image", ""))
	for id in datos.nodos:
		var imagen := str(datos.nodos[id].get("imagen", ""))
		if not imagen.is_empty():
			assert_not_null(StoryPanelScript.image_of(imagen), "escena %s: %s" % [id, imagen])
	for id in datos.finales:
		var imagen := str(datos.finales[id].get("imagen", "final_" + str(id)))
		assert_not_null(StoryPanelScript.image_of(imagen), "final %s" % id)


func test_2_8_las_escenas_de_tony_tienen_voz() -> void:
	var datos := StoryData.desde_archivo("res://content/historia.json")
	var con_voz := {"es": 0, "en": 0}
	var lineas := 0
	for id in datos.nodos:
		var dialogos: Array = datos.nodos[id].get("dialogos", [])
		for i in range(dialogos.size()):
			lineas += 1
			for idioma in ["es", "en"]:
				var frase := str(dialogos[i].get("texto", {}).get(idioma, ""))
				var linea := {"speaker": str(dialogos[i].get("quien", ""))}
				if StoryPanelScript._toma_dialogo(id, i, linea, frase) != null:
					con_voz[idioma] += 1
	gut.p("Voces de la historia: %d líneas · con voz ES %d · EN %d" % [lineas, con_voz["es"], con_voz["en"]])
	assert_gt(con_voz["es"], 0, "las voces de Tony están conectadas")


func test_2_8_nueva_partida_a_marte_abre_la_introduccion() -> void:
	var Sesion := preload("res://scenes/menu/game_session.gd")
	var destino_antes: String = Sesion.destino
	Sesion.destino = "marte"
	Sesion.cargar_al_iniciar = false
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	add_child_autofree(juego)
	await get_tree().process_frame
	assert_eq(juego.view.story.intro_index, 0, "la introducción sale al empezar")
	assert_true(juego.sim.intro_historia().size() > 0)
	Sesion.destino = destino_antes


func test_2_8_tras_aterrizar_llega_la_primera_escena() -> void:
	var cfg := Destino.config("marte")
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	var sim := Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]),
		MapData.desde_archivo(cfg["mapa"]), catalogo, Economy.desde_archivo(cfg["economia"]),
		StoryData.desde_archivo("res://content/historia.json"))
	for id in ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	sim.avanzar(0.1)
	var historia: Dictionary = sim.snapshot().get("story", {})
	# «aterrizaje» es de modo radio: Houston habla en la tarjeta de radio, sin detener el juego.
	assert_eq(str(historia.get("radio", {}).get("id", "")), "aterrizaje", "la radio del aterrizaje de Tony")
	assert_gt((historia["radio"]["dialogue"] as Array).size(), 0)


# --- 3.2 Más batería (Marte y Luna) y la batería extra suma de verdad ---------------------------------------------------

func _empezar(destino: String, piezas: Array[String]) -> Simulation:
	var sim := _sim(destino)
	for id in piezas:
		sim.ejecutar("design_add", {"part_id": id})
	assert_true(sim.ejecutar("design_start")["ok"], "%s: diseño válido" % destino)
	return sim


func test_3_2_la_bateria_base_es_de_4000_wh_en_marte_y_en_la_luna() -> void:
	var marte := _empezar("marte", ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara"])
	assert_eq(marte.estado.bateria_capacidad_wh, 4000.0)
	assert_eq(marte.estado.bateria_wh, 4000.0, "sale llena")
	var luna := _empezar("luna", ["cohete_medio", "chasis_base", "mmrtg", "antena_rele", "camara"])
	assert_eq(luna.estado.bateria_capacidad_wh, 4000.0)


func test_3_2_la_bateria_extra_suma_2000_wh() -> void:
	var sim := _empezar("marte", ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "bateria"])
	assert_eq(sim.estado.bateria_capacidad_wh, 6000.0, "antes la pieza no sumaba nada")
	assert_eq(sim.estado.bateria_wh, 6000.0)


# --- 3.1 Duración del sol a elección (6 a 12 min) sin cambiar el balance ---------------------------------------------

func _sim_operando(duracion_s: float) -> Simulation:
	var cfg := Destino.config("marte")
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	var sim := Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]),
		MapData.desde_archivo(cfg["mapa"]), catalogo, Economy.desde_archivo(cfg["economia"]).para_pruebas())
	sim.fijar_duracion_sol(duracion_s)
	for id in ["cohete_medio", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	return sim


func _jugar_un_sol(sim: Simulation) -> void:
	var paso := sim.estado.duracion_sol_s / 2400.0
	for i in range(2400):
		sim.avanzar(paso)


func test_3_1_un_sol_dura_lo_elegido() -> void:
	for duracion in [360.0, 720.0]:
		var sim := _sim_operando(duracion)
		var hora := sim.estado.hora
		_jugar_un_sol(sim)
		assert_eq(sim.estado.sol, 2, "%d s: pasó un sol" % duracion)
		assert_almost_eq(sim.estado.hora, hora, 0.05, "%d s: a la misma hora" % duracion)


func test_3_1_un_dia_de_juego_da_lo_mismo_con_6_y_con_12_minutos() -> void:
	var resultados: Array[Dictionary] = []
	for duracion in [360.0, 720.0]:
		var sim := _sim_operando(duracion)
		sim.estado.recursos["rocas"] = 200
		sim.ejecutar("build", {"building": "panel_solar", "tile": sim.estado.casilla_estacion + Vector2i(3, 0)})
		sim.estado.datos = 40.0
		sim.estado.nivel_antena = 1
		sim.ejecutar("transmit", {"on": true})
		_jugar_un_sol(sim)
		var obras := sim.estado.edificios.map(func(b): return "%s:%d" % [b["type"], b["level"]])
		resultados.append({"bateria": sim.estado.bateria_wh, "enviados": sim.estado.enviados, "obras": str(obras)})
	gut.p("3.1 un día: %s" % [resultados])
	assert_gt(float(resultados[0]["enviados"]), 0.0, "hubo transmisión")
	assert_almost_eq(resultados[0]["bateria"], resultados[1]["bateria"], 1.0, "la batería es la misma")
	assert_almost_eq(resultados[0]["enviados"], resultados[1]["enviados"], 0.5, "se envían los mismos datos")
	assert_eq(resultados[0]["obras"], resultados[1]["obras"], "la obra avanza igual")


func test_3_1_la_partida_guardada_conserva_la_duracion() -> void:
	var sim := _sim_operando(600.0)
	var datos: Dictionary = str_to_var(var_to_str(sim.guardar()))
	var otra := _sim_operando(360.0)
	assert_true(otra.cargar(datos))
	assert_eq(otra.estado.duracion_sol_s, 600.0, "se carga con su duración")
	datos["estado"].erase("duracion_sol_s")
	assert_true(otra.cargar(datos))
	assert_eq(otra.estado.duracion_sol_s, 300.0, "una partida de antes vuelve al sol de siempre")


func test_3_1_el_menu_y_la_sala_ofrecen_la_duracion() -> void:
	var Sesion := preload("res://scenes/menu/game_session.gd")
	assert_eq(Sesion.DURACIONES_SOL, [6, 8, 10, 12])
	assert_eq(Sesion.duracion_sol_min, 12, "12 min por defecto")
	var Menu := preload("res://scenes/menu/menu.gd")
	assert_string_contains(Menu.texto_duracion_sol(12), "72 min")
	var Sala := preload("res://scenes/net/sala.gd")
	var sala = Sala.new()
	sala.anadir(1, "Ana")
	assert_true(sala.configurar(1, "marte", "estandar", 8))
	var copia = Sala.desde_dict(sala.a_dict())
	assert_eq(int(copia.config["duracion_sol_min"]), 8, "el jefe la fija y la ven todos")
	assert_true(sala.configurar(1, "luna", "experta"))
	assert_eq(int(sala.config["duracion_sol_min"]), 8, "cambiar destino no la pierde")


# --- 4.2 Menos ruido: acciones en un bloque con iconos y atajos, ocultas si no se pueden usar, FPS aparte -------------

const HudScript := preload("res://scenes/b/hud.gd")


func _hud_con(disponibles: Dictionary) -> CanvasLayer:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	var sim := _sim_operando(300.0)
	var s := sim.snapshot()
	s["available_actions"] = disponibles
	hud.update_snapshot(s)
	return hud


func test_4_2_las_acciones_van_en_un_bloque_con_icono_y_tecla() -> void:
	var hud := _hud_con({})
	assert_true(hud._actions_row is PanelContainer, "un solo bloque")
	for accion in HudScript.GLOBAL_ACTIONS:
		if accion == "upgrade":
			continue
		var b: Button = hud.buttons[accion]
		assert_eq(b.get_parent(), hud._actions_fila)
		assert_eq(b.get_child_count(), 1, "%s con icono" % accion)
		assert_true(HudScript.HOTKEY_TEXT.has(accion), "%s con atajo" % accion)


func test_4_2_se_ocultan_las_que_no_se_podran_usar_y_no_las_pasajeras() -> void:
	var hud := _hud_con({"panorama": {"enabled": true, "reason": ""}, "radar": {"enabled": false, "reason": "NO_INSTRUMENT"},
		"drone": {"enabled": false, "reason": "FLIGHT_USED"}, "companion": {"enabled": false, "reason": "MOVING"},
		"upgrade": {"enabled": false, "reason": "LOW_ENERGY"}})
	assert_true(hud.buttons["panorama"].visible)
	assert_false(hud.buttons["radar"].visible, "sin instrumento: fuera")
	assert_false(hud.buttons["drone"].visible, "el dron ya voló este sol: fuera")
	assert_true(hud.buttons["companion"].visible, "rover en marcha: visible y apagada, la barra no salta")
	assert_true(hud.buttons["companion"].disabled)
	assert_false(hud.buttons["upgrade"].visible, "«Construir antena» vive en el menú Construir (B), no en la barra")


func test_4_2_el_contador_de_fps_va_arriba_a_la_derecha() -> void:
	var hud := _hud_con({})
	assert_eq(hud._debug.anchor_left, 1.0, "anclado a la derecha, fuera del centro")
	assert_eq(hud._debug.anchor_top, 0.0)


# --- 6.2 Sombras: dos cascadas y menos distancia en Alta, cuatro en Ultra · 6.4 medir la plataforma -----------------

func test_6_2_cascadas_de_sombra_por_nivel() -> void:
	var cielo: Node = autofree(preload("res://scenes/b/sky_light.gd").new())
	var sol: DirectionalLight3D = autofree(DirectionalLight3D.new())
	cielo.setup(Environment.new(), sol)
	cielo.fijar_sombras(1)
	assert_eq(sol.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Media y Alta: dos cascadas")
	assert_eq(sol.directional_shadow_max_distance, 40.0, "y menos distancia")
	cielo.fijar_sombras(2)
	assert_eq(sol.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Ultra: cuatro")
	assert_eq(sol.directional_shadow_max_distance, 90.0)


func test_6_4_el_medidor_sabe_que_escena_mide() -> void:
	var Medidor := preload("res://scenes/a/medidor.gd")
	assert_eq(Medidor.escena(), "mision", "sin --escena se mide la misión")
	assert_true(FileAccess.get_file_as_string("res://tools/paquete_windows/Medir_rendimiento.bat").contains("--escena=plataforma"),
		"el .bat mide también la plataforma")


# --- 9 Voces de radio (Houston y el rover) en Marte y Luna, español e inglés ----------------------------------------

const VocesScript := preload("res://scenes/b/voces_radio.gd")


func _eventos_voces() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/voces.json"))["eventos"]


func test_9_1_cada_evento_tiene_tres_variantes_en_los_dos_idiomas() -> void:
	var eventos := _eventos_voces()
	for nombre in ["mover", "llegada", "bateria", "despegue_inicio", "despegue_fin", "aterrizaje_rover",
			"aterrizaje_houston", "noche", "ventana", "memoria", "tormenta"]:
		assert_true(eventos.has(nombre), nombre)
		for variante in eventos[nombre]["variantes"] + eventos[nombre].get("luna", []):
			assert_false(str(variante.get("es", "")).is_empty() or str(variante.get("en", "")).is_empty(), nombre)
		assert_eq((eventos[nombre]["variantes"] as Array).size(), 3, "%s: 3 variantes" % nombre)


func test_9_3_cada_frase_tiene_su_archivo_en_los_dos_idiomas_y_destinos() -> void:
	var eventos := _eventos_voces()
	var revisadas := 0
	for nombre in eventos:
		for destino in ["marte", "luna"]:
			for n in range(1, 4):
				for idioma in ["es", "en"]:
					var ruta := VocesScript.ruta(eventos, nombre, n, destino, idioma)
					if ruta.is_empty():
						continue  # el evento no va en ese destino (tormenta en la Luna, aterrizaje en Marte)
					revisadas += 1
					assert_true(ResourceLoader.exists(ruta), "%s %s %d %s: %s" % [nombre, destino, n, idioma, ruta])
	assert_gt(revisadas, 100)
	assert_eq(VocesScript.ruta(eventos, "tormenta", 1, "luna", "es"), "", "en la Luna no hay tormenta de polvo")
	assert_eq(VocesScript.ruta(eventos, "aterrizaje_rover", 1, "marte", "es"), "", "en Marte el aterrizaje es de Tony")


func test_9_3_pausa_minima_historia_y_opcion_de_apagarlas() -> void:
	var Texto := preload("res://scenes/menu/menu_text.gd")
	var habia := FileAccess.file_exists(Texto.PREFERENCIAS)
	var copia := FileAccess.get_file_as_bytes(Texto.PREFERENCIAS) if habia else PackedByteArray()
	Texto.guardar("audio", "radio_voices", true)
	var voces: Node = add_child_autofree(VocesScript.new())
	var historia := [false]
	voces.ocupada = func() -> bool: return historia[0]
	assert_true(voces.decir("mover"), "habla")
	assert_false(voces.decir("llegada"), "no dentro de la pausa mínima")
	assert_true(voces.decir("despegue_fin", "", true), "el despegue no espera la pausa")
	voces._jugador.stop()
	voces._t = 100.0
	historia[0] = true
	assert_false(voces.decir("noche"), "nunca encima de las voces de la historia")
	historia[0] = false
	Texto.guardar("audio", "radio_voices", false)
	assert_false(voces.decir("noche"), "apagadas en Configuración")
	Texto.guardar("audio", "radio_voices", true)
	assert_true(voces.decir("noche"))
	if habia:
		FileAccess.open(Texto.PREFERENCIAS, FileAccess.WRITE).store_buffer(copia)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Texto.PREFERENCIAS))
