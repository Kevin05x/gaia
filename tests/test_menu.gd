extends GutTest
## Menú principal, tutorial, pantalla de carga y textos de entrada: las pantallas se construyen, los textos existen en
## español e inglés y el menú de pausa permite volver al menú.

const Texto := preload("res://scenes/menu/menu_text.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const MenuScript := preload("res://scenes/menu/menu.gd")
const TutorialScript := preload("res://scenes/menu/tutorial.gd")
const LoadingScript := preload("res://scenes/menu/loading.gd")
const HudScript := preload("res://scenes/b/hud.gd")
const Musica := preload("res://scenes/menu/musica.gd")


func before_all() -> void:
	Texto.install()


func after_all() -> void:
	TranslationServer.set_locale("es")


func test_las_tablas_en_y_es_tienen_las_mismas_claves() -> void:
	var es: Dictionary = Texto.TABLES["es"]
	var en: Dictionary = Texto.TABLES["en"]
	for clave in es:
		assert_true(en.has(clave), "falta en inglés: %s" % clave)
		assert_ne(String(es[clave]), "", clave)
	for clave in en:
		assert_true(es.has(clave), "falta en español: %s" % clave)


func test_los_textos_del_tutorial_y_los_consejos_estan_completos() -> void:
	for idioma in ["es", "en"]:
		TranslationServer.set_locale(idioma)
		var vistos: Dictionary = {}
		for i in range(1, TutorialScript.PAGINAS + 1):
			for sufijo in ["TITLE", "BODY"]:
				var clave := "M_T%d_%s" % [i, sufijo]
				assert_ne(tr(clave), clave, "%s (%s)" % [clave, idioma])
				vistos[tr(clave)] = true
		assert_eq(vistos.size(), TutorialScript.PAGINAS * 2, "cada página tiene texto propio")
		for i in range(1, LoadingScript.CONSEJOS + 1):
			assert_ne(tr("M_TIP%d" % i), "M_TIP%d" % i)
	TranslationServer.set_locale("es")


func test_el_menu_se_construye_con_sus_opciones() -> void:
	var menu: Control = add_child_autofree(MenuScript.new())
	await get_tree().process_frame
	assert_gte(menu.items.size(), 5, "continuar, nueva, cómo jugar, controles, configuración, créditos")
	assert_eq(menu.continuar.disabled, not Sesion.hay_guardado(), "Continuar solo se activa con una partida guardada")
	assert_eq(menu.items[1].text, "NUEVA PARTIDA")


func test_los_paneles_del_menu_se_abren_y_se_cierran() -> void:
	var menu: Control = add_child_autofree(MenuScript.new())
	await get_tree().process_frame
	for abrir in [menu._abrir_controles, menu._abrir_ajustes, menu._abrir_creditos]:
		abrir.call()
		assert_not_null(menu._panel)
		menu._cerrar_panel()
		assert_null(menu._panel)
		await get_tree().process_frame


func test_el_tutorial_recorre_sus_paginas_y_avisa_al_terminar() -> void:
	var t: Control = TutorialScript.new()
	t.empezar_al_final = true
	add_child_autofree(t)
	await get_tree().process_frame
	var avisos: Array = []
	t.cerrado.connect(func(completo: bool) -> void: avisos.append(completo))
	for i in range(TutorialScript.PAGINAS - 1):
		t._ir(t.pagina + 1)
	assert_eq(t.pagina, TutorialScript.PAGINAS - 1)
	assert_eq(t._siguiente.text, tr("M_TUT_START"), "la última página invita a empezar")
	t._ir(t.pagina + 1)
	assert_eq(avisos, [true])


func test_omitir_el_tutorial_avisa_que_no_se_completo() -> void:
	var t: Control = TutorialScript.new()
	add_child_autofree(t)
	await get_tree().process_frame
	var avisos: Array = []
	t.cerrado.connect(func(completo: bool) -> void: avisos.append(completo))
	t._terminar(false)
	assert_eq(avisos, [false])


func test_preferencias_se_guardan_sin_borrar_las_demas() -> void:
	var copia := ""
	if FileAccess.file_exists(Texto.PREFERENCIAS):
		copia = FileAccess.get_file_as_string(Texto.PREFERENCIAS)
	var antes: Dictionary = Texto.preferencias()
	Texto.guardar("ui", "tutorial", not bool(antes["tutorial"]))
	var despues: Dictionary = Texto.preferencias()
	assert_eq(bool(despues["tutorial"]), not bool(antes["tutorial"]))
	assert_eq(despues["volume"], antes["volume"], "no cambia el volumen")
	assert_eq(despues["quality"], antes["quality"], "no cambia la calidad")
	if copia == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Texto.PREFERENCIAS))
	else:
		FileAccess.open(Texto.PREFERENCIAS, FileAccess.WRITE).store_string(copia)


func test_la_pausa_tiene_salir_al_menu() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	var avisos: Array = []
	hud.menu_requested.connect(func() -> void: avisos.append(true))
	var boton: Button = null
	for b in hud._menu.find_children("*", "Button", true, false):
		if (b as Button).text == tr("MENU_QUIT"):
			boton = b
	assert_not_null(boton, "el menú de pausa tiene «Salir al menú»")
	if boton != null:
		boton.pressed.emit()
		assert_eq(avisos.size(), 1)


func test_la_musica_suena_en_bucle_y_cambia_de_pista() -> void:
	Musica.reproducir(get_tree(), "menu", 0.1)
	assert_eq(Musica.actual, "menu")
	var jugador: AudioStreamPlayer = get_tree().root.get_node("MusicaGaia")
	assert_not_null(jugador.stream)
	assert_gt(jugador.stream.get_length(), 60.0, "la pista es larga")
	assert_true(jugador.stream.loop, "la pista se repite")
	Musica.reproducir(get_tree(), "menu", 0.1)
	assert_eq(get_tree().root.find_children("MusicaGaia*", "AudioStreamPlayer", false, false).size(), 1, "no se duplica la misma pista")
	Musica.reproducir(get_tree(), "juego", 0.1)
	assert_eq(Musica.actual, "juego")
	Musica.detener(0.1)
	assert_eq(Musica.actual, "")
	await get_tree().create_timer(0.3).timeout
