extends GutTest
## Configuración gráfica (Opciones › Gráficos): ajustes predefinidos, «Personalizada», guardado y calidad automática
## que solo baja desde lo elegido.

var _copia: PackedByteArray = PackedByteArray()
var _habia := false


func before_each() -> void:
	_habia = FileAccess.file_exists(Graficos.ARCHIVO)
	if _habia:
		_copia = FileAccess.get_file_as_bytes(Graficos.ARCHIVO)


func after_each() -> void:
	if _habia:
		var f := FileAccess.open(Graficos.ARCHIVO, FileAccess.WRITE)
		f.store_buffer(_copia)
	elif FileAccess.file_exists(Graficos.ARCHIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Graficos.ARCHIVO))


func test_cada_preset_se_reconoce_y_ultra_es_lo_mas_alto() -> void:
	for nombre in Graficos.ORDEN:
		assert_eq(Graficos.preset_de(Graficos.de_preset(nombre)), nombre)
	var baja := Graficos.de_preset("baja")
	var ultra := Graficos.de_preset("ultra")
	assert_eq(baja["sombras"], 0)
	assert_false(baja["post"])
	assert_eq(ultra["sombras"], 2)
	assert_eq(ultra["aa"], 2)
	assert_eq(Graficos.de_preset("nada")["preset"], Graficos.DEFECTO, "un nombre desconocido vuelve al de por defecto")


func test_cambiar_una_opcion_la_vuelve_personalizada() -> void:
	var g := Graficos.de_preset("alta")
	g["polvo"] = false
	assert_eq(Graficos.preset_de(g), "personalizada")


func test_se_guarda_y_se_carga() -> void:
	var g := Graficos.de_preset("media")
	g["resolucion"] = 0.85
	Graficos.guardar(g)
	var leido := Graficos.cargar()
	assert_almost_eq(float(leido["resolucion"]), 0.85, 0.001)
	assert_eq(leido["preset"], "personalizada")
	assert_eq(int(leido["sombras"]), 1)


func test_valores_fuera_de_rango_se_acotan() -> void:
	var g := Graficos.normalizar({"sombras": 9, "aa": -2, "resolucion": 0.2, "post": 1, "texturas": 0, "polvo": true,
		"distancia": 7, "auto": false})
	assert_eq(g["sombras"], 2)
	assert_eq(g["aa"], 0)
	assert_eq(g["resolucion"], 0.7)
	assert_eq(g["distancia"], 2)
	assert_true(g["post"] is bool)


func test_la_calidad_automatica_solo_baja_desde_lo_elegido() -> void:
	var calidad: Node = preload("res://scenes/b/calidad_dinamica.gd").new()
	add_child_autofree(calidad)
	calidad.set_process(false)
	calidad.configurar(Viewport.MSAA_4X, 0.9, true)
	assert_eq(calidad.escala(), 0.9, "empieza en lo elegido, no más alto")
	calidad.medir = func() -> bool: return true
	for i in range(400):
		calidad._process(0.04)
	assert_gte(calidad.escala(), 0.8)
	assert_lte(calidad.escala(), 0.9)
	calidad.configurar(Viewport.MSAA_DISABLED, 1.0, false)
	for i in range(400):
		calidad._process(0.04)
	assert_eq(calidad.nivel(), 0, "sin ajuste automático no cambia nada")


func test_el_panel_de_opciones_emite_la_configuracion() -> void:
	var panel := OpcionesGraficos.new(Graficos.de_preset("alta"))
	add_child_autofree(panel)
	var recibido: Array = []
	panel.cambiado.connect(func(g: Dictionary) -> void: recibido.append(g))
	panel._elegir_preset("ultra")
	assert_eq(recibido.size(), 1)
	assert_eq(recibido[0]["preset"], "ultra")
	panel._cambiar("polvo", false)
	assert_eq(recibido[1]["preset"], "personalizada")


func test_el_ajuste_automatico_quita_el_brillo_y_las_sombras_al_final() -> void:
	var calidad: Node = preload("res://scenes/b/calidad_dinamica.gd").new()
	add_child_autofree(calidad)
	calidad.set_process(false)
	var recortes: Array = []
	calidad.al_recortar = func(n: int) -> void: recortes.append(n)
	calidad.configurar(Viewport.MSAA_2X, 1.0, true, true, true)
	calidad.medir = func() -> bool: return true
	for i in range(1000):
		calidad._process(0.04)
	assert_eq(recortes.back(), 2, "en el último escalón ya no hay brillo ni sombras")
	assert_true(recortes.has(1), "antes quitó solo el brillo")
	assert_gte(calidad.escala(), 0.8)


func test_mostrar_fps_se_guarda_aparte_y_no_cambia_el_ajuste() -> void:
	assert_false(Graficos.mostrar_fps())
	var g := Graficos.de_preset("media")
	Graficos.guardar(g)
	Graficos.guardar_fps(true)
	assert_true(Graficos.mostrar_fps())
	assert_eq(Graficos.preset_de(Graficos.cargar()), "media")
	Graficos.guardar(g)  # guardar los ajustes no apaga el contador
	assert_true(Graficos.mostrar_fps())
	Graficos.guardar_fps(false)
	assert_false(Graficos.mostrar_fps())


func test_panel_de_opciones_tiene_la_casilla_fps() -> void:
	var panel := OpcionesGraficos.new(Graficos.de_preset("alta"), 14)
	add_child_autofree(panel)
	assert_not_null(panel.casilla_fps())
	watch_signals(panel)
	panel.casilla_fps().button_pressed = true
	assert_signal_emitted_with_parameters(panel, "fps_cambiado", [true])
	assert_true(Graficos.mostrar_fps())
