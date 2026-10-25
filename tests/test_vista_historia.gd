extends GutTest
## Vista del bloque A: ventana de decisión, introducción y panel de la base (recursos y menú de construcción).

const StoryPanel := preload("res://scenes/b/story_panel.gd")
const BaseHud := preload("res://scenes/b/base_hud.gd")

var ordenes: Array = []
var _idioma := ""


func before_all() -> void:
	# Mismas traducciones que registra MissionView.setup_locale(), sin crear la vista.
	_idioma = TranslationServer.get_locale()
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


func after_all() -> void:
	TranslationServer.set_locale(_idioma)


func _nodo() -> Dictionary:
	return {"id": "noche_aranas", "act": {"es": "Acto 1", "en": "Act 1"}, "title": {"es": "Noche", "en": "Night"},
		"text": {"es": "Texto", "en": "Text"}, "rocky": {"es": "Rocky", "en": "Rocky"},
		"choices": [{"text": {"es": "A", "en": "A"}, "detail": {"es": "a", "en": "a"}, "enabled": true, "reason": ""},
			{"text": {"es": "B", "en": "B"}, "detail": {"es": "b", "en": "b"}, "enabled": false, "reason": "NO_COMPANION"}]}


func test_la_ventana_de_decision_se_abre_y_se_cierra_con_el_snapshot() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	panel.command.connect(func(orden: String, carga: Dictionary) -> void: ordenes.append([orden, carga]))
	panel.update_snapshot({"phase": "operations", "story": {"pending": _nodo()}})
	assert_true(panel.is_open())
	assert_eq(panel.shown_node, "noche_aranas")
	assert_eq(panel.step, 0, "primero el relato")
	panel.advance()
	var botones := panel.root.find_children("*", "Button", true, false)
	assert_eq(botones.size(), 2)
	assert_true((botones[1] as Button).disabled, "la opción sin Rocky está deshabilitada")
	(botones[0] as Button).pressed.emit()
	assert_eq(ordenes, [["decide", {"choice": 0}]])
	panel.update_snapshot({"phase": "operations", "story": {"pending": {}}})
	assert_false(panel.is_open())


func test_la_introduccion_pasa_pagina_y_avisa_al_terminar() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	var terminada := [false]
	panel.intro_finished.connect(func() -> void: terminada[0] = true)
	panel.show_intro([{"es": "uno", "en": "one"}, {"es": "dos", "en": "two"}])
	assert_true(panel.is_open())
	panel.update_snapshot({"phase": "operations", "story": {"pending": _nodo()}})
	assert_eq(panel.shown_node, "", "la decisión espera a que termine la introducción")
	panel._terminar_intro()
	assert_true(terminada[0])
	assert_eq(panel.shown_node, "noche_aranas")


func test_textos_segun_el_idioma() -> void:
	var antes := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(StoryPanel.text_of({"es": "hola", "en": "hello"}), "hello")
	TranslationServer.set_locale("es")
	assert_eq(StoryPanel.text_of({"es": "hola", "en": "hello"}), "hola")
	TranslationServer.set_locale(antes)


func test_el_panel_de_base_muestra_recursos_y_el_menu() -> void:
	var base := BaseHud.new()
	add_child_autofree(base)
	var pedidos: Array = []
	base.placement_requested.connect(func(tipo: String) -> void: pedidos.append(tipo))
	base.update_snapshot({"phase": "operations", "resources": {"rocas": 30, "olivino": 4, "hielo": 0, "xenolito": 0},
		"resource_capacity": 150, "design": {"companion": true}, "story": {"ethics": 65.0, "rocky_hp": 80.0},
		"build_options": [{"id": "panel_solar", "name_key": "BLD_SOLAR", "cost": {"rocas": 20}, "power_w": 45.0, "seconds": 5.0,
			"count": 0, "max": 6, "enabled": true, "reason": ""},
			{"id": "hangar", "name_key": "BLD_HANGAR", "cost": {"rocas": 50, "olivino": 30}, "power_w": -5.0, "seconds": 12.0,
			"count": 0, "max": 1, "enabled": false, "reason": "NO_RESOURCES"}],
		"buildings": []})
	assert_true(base.build_button.visible)
	assert_eq((base._chips["rocas"].get_meta("text") as Label).text, "30")
	assert_eq(base._ethics.text, "65")
	base.toggle_menu()
	assert_true(base.menu.visible)
	var filas := base.menu.find_children("*", "Button", true, false)
	assert_eq(filas.size(), 2)
	assert_true((filas[1] as Button).disabled)
	(filas[0] as Button).pressed.emit()
	assert_eq(pedidos, ["panel_solar"])
	assert_false(base.menu.visible, "al elegir se cierra para colocar")


func test_sin_economia_el_panel_de_base_no_aparece() -> void:
	var base := BaseHud.new()
	add_child_autofree(base)
	base.update_snapshot({"phase": "operations"})
	assert_false(base.build_button.visible)


func test_costo_en_texto() -> void:
	assert_eq(BaseHud.cost_text({"rocas": 20, "olivino": 10}), "20 %s, 10 %s" % [tr("RES_ROCAS").to_lower(), tr("RES_OLIVINO").to_lower()])


func test_la_escena_pasa_por_el_relato_y_los_dialogos_antes_de_decidir() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	var nodo := _nodo()
	nodo["dialogue"] = [{"name": {"es": "ROCKY", "en": "ROCKY"}, "color": "9AD7C6", "text": {"es": "¡Bip!", "en": "Beep!"}},
		{"name": {"es": "HOUSTON", "en": "HOUSTON"}, "color": "F0C079", "text": {"es": "Recibido", "en": "Copy"}}]
	panel.update_snapshot({"phase": "operations", "story": {"pending": nodo}})
	assert_eq(panel.step, 0)
	panel.advance()
	assert_eq(panel.step, 1, "primer diálogo")
	var textos := panel.root.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_has(textos, "«¡Bip!»")
	panel.advance()
	panel.advance()
	assert_eq(panel.step, 3, "decisión")
	panel.advance()
	assert_eq(panel.step, 3, "en la decisión ya no avanza")
	panel.update_snapshot({"phase": "operations", "story": {"pending": nodo}})
	assert_eq(panel.step, 3, "un snapshot nuevo no reinicia la escena")



func _radio(n: int) -> Dictionary:
	return {"phase": "operations", "story": {"pending": {}, "radio": {"id": "aterrizaje", "n": n, "image": "aterrizaje",
		"dialogue": [{"name": {"es": "HOUSTON", "en": "HOUSTON"}, "color": "F0C079", "text": {"es": "Hola", "en": "Hi"}},
			{"name": {"es": "ROCKY", "en": "ROCKY"}, "color": "9AD7C6", "text": {"es": "¡Bip!", "en": "Beep!"}}]}}}


func test_la_radio_no_bloquea_el_juego_y_pasa_sus_lineas() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	panel.update_snapshot(_radio(0))
	panel._process(0.0)
	assert_false(panel.radio_open(), "sin radio nueva no hay tarjeta")
	panel.update_snapshot(_radio(1))
	panel._process(0.0)
	assert_true(panel.radio_open())
	assert_false(panel.is_open(), "la radio no bloquea el juego")
	var textos := panel.radio_root.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_has(textos, "«Hola»")
	panel.advance_radio()
	textos = panel.radio_root.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	assert_has(textos, "«¡Bip!»")
	panel.advance_radio()
	assert_false(panel.radio_open(), "al terminar la última línea se cierra")


func test_la_radio_pasa_sola_con_el_tiempo() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	panel.update_snapshot(_radio(0))
	panel.update_snapshot(_radio(1))
	panel._process(0.0)
	assert_eq(panel.radio_line, 0)
	panel._process(30.0)
	assert_eq(panel.radio_line, 1, "pasa a la segunda línea")
	panel._process(30.0)
	assert_false(panel.radio_open())


func test_una_partida_cargada_no_repite_la_radio_de_antes() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	panel.update_snapshot(_radio(3))
	panel._process(0.0)
	assert_false(panel.radio_open())


func test_la_radio_espera_a_que_cierre_la_escena() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	panel.update_snapshot(_radio(0))
	var nodo := _nodo()
	var datos := _radio(1)
	datos["story"]["pending"] = nodo
	panel.update_snapshot(datos)
	panel._process(0.0)
	assert_true(panel.is_open())
	assert_false(panel.radio_open(), "la escena va primero")
	panel.update_snapshot(_radio(1))
	panel._process(0.0)
	assert_true(panel.radio_open(), "al cerrarse la escena suena la radio")


func test_la_escena_corta_va_directo_a_la_decision() -> void:
	var panel := StoryPanel.new()
	add_child_autofree(panel)
	var nodo := _nodo()
	nodo["scene"] = "corta"
	nodo["dialogue"] = [{"name": {"es": "ROCKY", "en": "ROCKY"}, "color": "9AD7C6", "text": {"es": "¡Bip!", "en": "Beep!"}}]
	panel.update_snapshot({"phase": "operations", "story": {"pending": nodo}})
	assert_eq(panel.step, 2, "relato y diálogos se saltan")
	assert_eq(panel.root.find_children("*", "Button", true, false).size(), 2, "solo las opciones")


func test_texto_de_las_metas() -> void:
	var Hud := preload("res://scenes/b/hud.gd")
	assert_eq(Hud.goal_text({"kind": "antena", "goal": 2.0, "cur": 1.0}), tr("GOAL_ANTENNA") % 2)
	assert_eq(Hud.goal_text({"kind": "edificio", "id": "panel_solar", "goal": 1.0}), tr("GOAL_BUILD") % tr("BLD_SOLAR"))
	assert_eq(Hud.goal_text({"kind": "enviados_pct", "goal": 85.0, "cur": 40.0}), tr("GOAL_SENT") % 85 + ": 40 %")
