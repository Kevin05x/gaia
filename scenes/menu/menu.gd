extends Control
## Menú principal de GAIA: el paisaje de Jezero de fondo, el logotipo y una lista a la izquierda con Continuar,
## Nueva partida, Cómo jugar, Controles, Configuración y Créditos. Todo se construye por código.
const UI := preload("res://scenes/b/ui_style.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const Tutorial := preload("res://scenes/menu/tutorial.gd")
const Musica := preload("res://scenes/menu/musica.gd")
const Logo := preload("res://scenes/menu/gaia_logo.gd")
const FONDO := "res://assets/menu/menu_fondo.jpg"
const LOGOTIPO := "res://assets/menu/gaia_logo.png"
const VERSION := "v0.1"

var fondo: TextureRect
var velo: ColorRect
var items: Array[Button] = []
var continuar: Button
var _capa: Control
var _panel: Control
var _saliendo := false


func _ready() -> void:
	Texto.install()
	Musica.reproducir(get_tree(), "menu", 3.0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	_construir_fondo()
	_construir_interfaz()
	velo = ColorRect.new()
	velo.color = Color.BLACK
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)
	create_tween().tween_property(velo, "color:a", 0.0, 0.7)


func _construir_fondo() -> void:
	var base := ColorRect.new()
	base.color = Color("0b0810")
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)
	fondo = TextureRect.new()
	if ResourceLoader.exists(FONDO):
		fondo.texture = load(FONDO)
	fondo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fondo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)
	fondo.resized.connect(func() -> void: fondo.pivot_offset = Vector2(fondo.size.x * 0.82, fondo.size.y * 0.62))
	var deriva := create_tween().set_loops()
	deriva.tween_property(fondo, "scale", Vector2(1.045, 1.045), 26.0).from(Vector2.ONE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	deriva.tween_property(fondo, "scale", Vector2.ONE, 26.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Oscurece el lado izquierdo (donde va la lista) y el borde inferior.
	add_child(_degradado(Vector2(0, 0), Vector2(1, 0), [0.0, 0.7], [Color(0.03, 0.02, 0.05, 0.82), Color(0.03, 0.02, 0.05, 0.0)]))
	add_child(_degradado(Vector2(0, 1), Vector2(0, 0), [0.0, 0.3], [Color(0.03, 0.02, 0.05, 0.7), Color(0.03, 0.02, 0.05, 0.0)]))


func _degradado(desde: Vector2, hasta: Vector2, puntos: Array, colores: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(puntos)
	g.colors = PackedColorArray(colores)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = desde
	t.fill_to = hasta
	var r := TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _construir_interfaz() -> void:
	if _capa != null:
		_capa.queue_free()
	items.clear()
	_capa = Control.new()
	_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_capa)
	if _panel != null:
		move_child(_capa, _panel.get_index())
	_capa.add_child(_crear_logotipo())
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	UI.place(col, "tl", 92, 262, 380, 420)
	_capa.add_child(col)
	var guardado: Dictionary = Sesion.resumen()
	var bloque := VBoxContainer.new()
	bloque.add_theme_constant_override("separation", 0)
	col.add_child(bloque)
	continuar = _item(tr("M_CONTINUE"), _continuar, bloque)
	continuar.disabled = guardado.is_empty()
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 22)
	bloque.add_child(margen)
	var info := UI.label(margen, tr("M_NO_SAVE") if guardado.is_empty() else tr("M_SAVE_INFO") % [guardado["sol"], guardado["enviados"], guardado["meta"]],
		13, Color(UI.AMBER, 0.85 if not guardado.is_empty() else 0.4))
	info.add_theme_constant_override("line_spacing", 0)
	var sangria := Control.new()
	sangria.custom_minimum_size.y = 8
	bloque.add_child(sangria)
	_item(tr("M_NEW"), _nueva_partida, col)
	_item(tr("M_HOWTO"), func() -> void: _tutorial(false), col)
	_item(tr("M_CONTROLS"), _abrir_controles, col)
	_item(tr("M_SETTINGS"), _abrir_ajustes, col)
	_item(tr("M_CREDITS"), _abrir_creditos, col)
	if not OS.has_feature("web"):
		_item(tr("M_QUIT"), func() -> void: get_tree().quit(), col)
	var pie := UI.label(_capa, tr("M_FOOTER"), 12, Color(UI.CREAM, 0.5))
	UI.display(pie, 500, 1)
	UI.place(pie, "bl", 96, 26, 600, 18)
	var version := UI.label(_capa, VERSION, 12, Color(UI.CREAM, 0.5))
	UI.display(version, 500, 1)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.place(version, "br", 32, 26, 120, 18)
	var primero: Button = items[1] if continuar.disabled else items[0]
	primero.grab_focus.call_deferred()


func _crear_logotipo() -> Control:
	if ResourceLoader.exists(LOGOTIPO):
		var imagen := TextureRect.new()
		imagen.texture = load(LOGOTIPO)
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.place(imagen, "tl", 70, 56, 580, 164)
		var flota := imagen.create_tween().set_loops()
		flota.tween_property(imagen, "position:y", imagen.position.y + 5.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		flota.tween_property(imagen, "position:y", imagen.position.y, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return imagen
	var logo := Logo.new()
	logo.disposicion = "horizontal"
	logo.girar = true
	UI.place(logo, "tl", 80, 40, 560, 190)
	return logo


func _item(texto: String, accion: Callable, padre: Control) -> Button:
	var b := Button.new()
	b.text = texto
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(340, 46)
	b.add_theme_font_override("font", UI.display_font(650, 3))
	b.add_theme_font_size_override("font_size", 23)
	b.add_theme_color_override("font_color", Color(UI.CREAM, 0.8))
	b.add_theme_color_override("font_hover_color", UI.AMBER)
	b.add_theme_color_override("font_focus_color", UI.AMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(UI.CREAM, 0.28))
	var normal := _caja_item(0.0, 0.0)
	var resalte := _caja_item(0.13, 3.0)
	var pulsado := _caja_item(0.24, 3.0)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("hover", resalte)
	b.add_theme_stylebox_override("focus", resalte)
	b.add_theme_stylebox_override("pressed", pulsado)
	b.pressed.connect(accion)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	padre.add_child(b)
	items.append(b)
	return b


func _caja_item(relleno: float, borde: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.AMBER, relleno)
	s.border_color = UI.AMBER
	s.border_width_left = int(borde)
	s.content_margin_left = 22
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


# --- acciones -----------------------------------------------------------------------------------------------

func _continuar() -> void:
	_ir_al_juego(true)


func _nueva_partida() -> void:
	if Sesion.hay_guardado():
		var cuerpo := _abrir_panel(tr("M_NEW_CONFIRM_TITLE"), 560, 300, false)
		var texto := UI.label(cuerpo, tr("M_NEW_CONFIRM"), 17, Color(UI.CREAM, 0.88))
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var pie := cuerpo.get_parent().get_child(cuerpo.get_parent().get_child_count() - 1) as HBoxContainer
		var si := Button.new()
		si.text = tr("M_NEW_CONFIRM_YES")
		si.theme_type_variation = "PrimaryButton"
		si.custom_minimum_size = Vector2(190, 42)
		si.pressed.connect(func() -> void:
			_cerrar_panel()
			_empezar_nueva())
		pie.add_child(si)
		var no := pie.get_child(0) as Button
		no.text = tr("M_NEW_CONFIRM_NO")
		no.theme_type_variation = ""
		return
	_empezar_nueva()


func _empezar_nueva() -> void:
	if bool(Texto.preferencias()["tutorial"]):
		_tutorial(true)
	else:
		_ir_al_juego(false)


func _tutorial(antes_de_jugar: bool) -> void:
	var t := Tutorial.new()
	t.empezar_al_final = antes_de_jugar
	t.cerrado.connect(func(_completo: bool) -> void:
		if antes_de_jugar:
			Texto.guardar("ui", "tutorial", false)
			_ir_al_juego(false))
	add_child(t)
	move_child(t, get_child_count() - 2)


func _ir_al_juego(cargar: bool) -> void:
	if _saliendo:
		return
	_saliendo = true
	var tw := create_tween()
	tw.tween_property(velo, "color:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: Sesion.empezar(get_tree(), cargar))


# --- paneles ------------------------------------------------------------------------------------------------

## Abre un panel centrado con título, cuerpo y un pie con «Volver». Devuelve el cuerpo.
func _abrir_panel(titulo: String, ancho: float, alto: float, con_volver: bool = true) -> VBoxContainer:
	_cerrar_panel()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tapa := ColorRect.new()
	tapa.color = Color(0.03, 0.02, 0.04, 0.74)
	tapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	tapa.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_child(tapa)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.96, 14, 0.28, 1, 36, 28))
	UI.place(caja, "c", 0, 0, ancho, alto)
	_panel.add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	caja.add_child(col)
	var cabecera := UI.label(col, titulo.to_upper(), 26, UI.CREAM)
	UI.display(cabecera, 700, 3)
	var cuerpo := VBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 12)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cuerpo)
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_theme_constant_override("separation", 10)
	col.add_child(pie)
	var volver := Button.new()
	volver.text = tr("M_BACK")
	volver.theme_type_variation = "PrimaryButton"
	volver.custom_minimum_size = Vector2(150, 42)
	volver.pressed.connect(_cerrar_panel)
	pie.add_child(volver)
	add_child(_panel)
	move_child(_panel, get_child_count() - 2)
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.18)
	volver.grab_focus.call_deferred()
	return cuerpo


func _cerrar_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	if is_inside_tree() and not items.is_empty():
		var primero: Button = items[1] if continuar.disabled else items[0]
		primero.grab_focus.call_deferred()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_ESCAPE and _panel != null:
		_cerrar_panel()
		get_viewport().set_input_as_handled()


func _subtitulo(cuerpo: Control, texto: String) -> void:
	var l := UI.label(cuerpo, texto.to_upper(), 12, Color(UI.AMBER, 0.9))
	UI.display(l, 700, 3)


func _abrir_controles() -> void:
	var cuerpo := _abrir_panel(tr("M_CONTROLS_TITLE"), 840, 560)
	var filas := [
		["M_CTRL_MOUSE", [["M_CTRL_CLICK", "M_CTRL_CLICK_D"], ["M_CTRL_GROUND", "M_CTRL_GROUND_D"], ["M_CTRL_WHEEL", "M_CTRL_WHEEL_D"]]],
		["M_CTRL_KEYS", [["M_CTRL_QE", "M_CTRL_QE_D"], ["M_CTRL_F", "M_CTRL_F_D"], ["M_CTRL_CVX", "M_CTRL_CVX_D"],
			["M_CTRL_T", "M_CTRL_T_D"], ["M_CTRL_ESC", "M_CTRL_ESC_D"], ["M_CTRL_F1", "M_CTRL_F1_D"]]],
	]
	for grupo in filas:
		_subtitulo(cuerpo, tr(grupo[0]))
		var rejilla := GridContainer.new()
		rejilla.columns = 2
		rejilla.add_theme_constant_override("h_separation", 24)
		rejilla.add_theme_constant_override("v_separation", 9)
		cuerpo.add_child(rejilla)
		for fila in grupo[1]:
			var tecla := UI.label(rejilla, tr(fila[0]), 17, UI.CREAM)
			UI.display(tecla, 650, 1)
			tecla.custom_minimum_size.x = 310
			UI.label(rejilla, tr(fila[1]), 16, Color(UI.CREAM, 0.72))


func _abrir_ajustes() -> void:
	var cuerpo := _abrir_panel(tr("M_SETTINGS"), 700, 520)
	var prefs: Dictionary = Texto.preferencias()
	# Idioma
	var fila := _fila(cuerpo, tr("M_SET_LANGUAGE"))
	var grupo := ButtonGroup.new()
	for codigo in ["es", "en"]:
		var b := Button.new()
		b.text = codigo.to_upper()
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(70, 40)
		b.button_pressed = TranslationServer.get_locale().begins_with(codigo)
		b.pressed.connect(func() -> void:
			if not TranslationServer.get_locale().begins_with(codigo):
				TranslationServer.set_locale(codigo)
				Texto.guardar("ui", "language", codigo)
				_construir_interfaz()
				_abrir_ajustes())
		fila.add_child(b)
	# Volumen
	fila = _fila(cuerpo, tr("M_SET_VOLUME"))
	var deslizador := HSlider.new()
	deslizador.min_value = 0.0
	deslizador.max_value = 1.0
	deslizador.step = 0.01
	deslizador.value = float(prefs["volume"])
	deslizador.custom_minimum_size = Vector2(220, 24)
	deslizador.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fila.add_child(deslizador)
	var cifra := UI.label(fila, "%d%%" % roundi(deslizador.value * 100.0), 15, Color(UI.CREAM, 0.8))
	cifra.custom_minimum_size.x = 46
	deslizador.value_changed.connect(func(v: float) -> void:
		cifra.text = "%d%%" % roundi(v * 100.0)
		Texto.guardar("audio", "volume", v)
		Texto.aplicar_audio())
	# Silencio
	_interruptor(cuerpo, tr("M_SET_MUTE"), bool(prefs["muted"]), func(v: bool) -> void:
		Texto.guardar("audio", "muted", v)
		Texto.aplicar_audio())
	# Gráficos
	fila = _fila(cuerpo, tr("M_SET_GRAPHICS"))
	var calidad := ButtonGroup.new()
	for alta in [true, false]:
		var b := Button.new()
		b.text = tr("M_SET_GRAPHICS_HIGH") if alta else tr("M_SET_GRAPHICS_LOW")
		b.toggle_mode = true
		b.button_group = calidad
		b.custom_minimum_size = Vector2(110, 40)
		b.button_pressed = bool(prefs["quality"]) == alta
		b.pressed.connect(func() -> void: Texto.guardar("visual", "quality", alta))
		fila.add_child(b)
	var nota := UI.label(cuerpo, tr("M_SET_GRAPHICS_NOTE"), 13, Color(UI.CREAM, 0.6))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Pantalla completa y tutorial
	_interruptor(cuerpo, tr("M_SET_FULLSCREEN"), DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, func(v: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED))
	_interruptor(cuerpo, tr("M_SET_TUTORIAL"), bool(prefs["tutorial"]), func(v: bool) -> void:
		Texto.guardar("ui", "tutorial", v))


func _fila(padre: Control, titulo: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	padre.add_child(fila)
	var etiqueta := UI.label(fila, titulo, 17, UI.CREAM)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return fila


func _interruptor(padre: Control, titulo: String, valor: bool, al_cambiar: Callable) -> void:
	var fila := _fila(padre, titulo)
	var c := CheckButton.new()
	c.button_pressed = valor
	c.toggled.connect(al_cambiar)
	fila.add_child(c)


func _abrir_creditos() -> void:
	var cuerpo := _abrir_panel(tr("M_CREDITS_TITLE"), 760, 520)
	for par in [["M_CREDITS_TEAM", "M_CREDITS_ROLES"], ["M_CREDITS_DATA", "M_CREDITS_DATA_D"], ["M_CREDITS_ART", "M_CREDITS_ART_D"],
			["M_CREDITS_MUSIC", "M_CREDITS_MUSIC_D"]]:
		_subtitulo(cuerpo, tr(par[0]))
		var t := UI.label(cuerpo, tr(par[1]), 16, Color(UI.CREAM, 0.85))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var motor := UI.label(cuerpo, tr("M_CREDITS_ENGINE"), 14, Color(UI.CREAM, 0.55))
	motor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
