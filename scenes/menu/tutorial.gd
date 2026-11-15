extends Control
## Tutorial de GAIA en cinco páginas: la misión, el taller, despegue y aterrizaje, explorar y transmitir.
## Se abre desde «Cómo jugar» (termina con «Cerrar») y antes de la primera partida (termina con «¡Empezar la misión!»).
## Cada página lleva una captura real del juego (las mismas del tutorial en ventana, assets/tutorial/marte/<idioma>/).
const UI := preload("res://scenes/b/ui_style.gd")
const TutorialVentana := preload("res://scenes/b/tutorial_panel.gd")
const PAGINAS := 5
const CAPTURAS: Array[String] = ["mover", "taller", "plataforma", "analizar", "transmitir"]  ## una por página
signal cerrado(completo: bool)

var empezar_al_final := false
var pagina := 0
var _numero: Label
var _imagen: TextureRect
var _titulo: Label
var _cuerpo: Label
var _puntos: HBoxContainer
var _anterior: Button
var _siguiente: Button
var _omitir: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UI.theme()
	var velo := ColorRect.new()
	velo.color = Color(0.03, 0.02, 0.04, 0.78)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(velo)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.96, 14, 0.28, 1, 40, 32))
	UI.place(caja, "c", 0, 0, 940, 470)
	add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	caja.add_child(col)
	var cabecera := UI.label(col, tr("M_TUT_TITLE").to_upper(), 13, Color(UI.AMBER, 0.9))
	UI.display(cabecera, 700, 4)
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 30)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cuerpo)
	_imagen = TextureRect.new()
	_imagen.custom_minimum_size = Vector2(416, 234)
	_imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_imagen.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cuerpo.add_child(_imagen)
	var texto := VBoxContainer.new()
	texto.add_theme_constant_override("separation", 10)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuerpo.add_child(texto)
	_numero = Label.new()
	_numero.add_theme_font_override("font", UI.display_font(700, 0))
	_numero.add_theme_font_size_override("font_size", 44)
	_numero.add_theme_color_override("font_color", Color(UI.AMBER, 0.85))
	texto.add_child(_numero)
	_titulo = UI.label(texto, "", 30, UI.CREAM)
	UI.display(_titulo, 700, 1)
	_cuerpo = UI.label(texto, "", 17, Color(UI.CREAM, 0.88))
	_cuerpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cuerpo.add_theme_constant_override("line_spacing", 5)
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	col.add_child(pie)
	_omitir = Button.new()
	_omitir.text = tr("M_TUT_SKIP")
	_omitir.flat = true
	_omitir.pressed.connect(func() -> void: _terminar(false))
	pie.add_child(_omitir)
	_puntos = HBoxContainer.new()
	_puntos.add_theme_constant_override("separation", 8)
	_puntos.alignment = BoxContainer.ALIGNMENT_CENTER
	_puntos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_puntos)
	for i in range(PAGINAS):
		var punto := ColorRect.new()
		punto.custom_minimum_size = Vector2(26, 4)
		punto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		punto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_puntos.add_child(punto)
	_anterior = Button.new()
	_anterior.text = tr("M_TUT_PREV")
	_anterior.custom_minimum_size = Vector2(120, 42)
	_anterior.pressed.connect(func() -> void: _ir(pagina - 1))
	pie.add_child(_anterior)
	_siguiente = Button.new()
	_siguiente.theme_type_variation = "PrimaryButton"
	_siguiente.custom_minimum_size = Vector2(170, 42)
	_siguiente.pressed.connect(func() -> void: _ir(pagina + 1))
	pie.add_child(_siguiente)
	_ir(0)
	_siguiente.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)


func _ir(nueva: int) -> void:
	if nueva >= PAGINAS:
		_terminar(true)
		return
	pagina = clampi(nueva, 0, PAGINAS - 1)
	_numero.text = "%02d" % (pagina + 1)
	_titulo.text = tr("M_T%d_TITLE" % (pagina + 1))
	_cuerpo.text = tr("M_T%d_BODY" % (pagina + 1))
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var ruta := TutorialVentana.ruta_captura(CAPTURAS[pagina], "marte", idioma)
	_imagen.texture = load(ruta) if not ruta.is_empty() else null
	_imagen.visible = _imagen.texture != null
	_anterior.visible = pagina > 0
	var ultima := pagina == PAGINAS - 1
	_siguiente.text = tr("M_TUT_START") if ultima and empezar_al_final else (tr("M_TUT_CLOSE") if ultima else tr("M_TUT_NEXT"))
	_omitir.visible = not ultima
	for i in range(_puntos.get_child_count()):
		(_puntos.get_child(i) as ColorRect).color = Color(UI.AMBER, 0.95) if i == pagina else Color(UI.CREAM, 0.25)


func _terminar(completo: bool) -> void:
	cerrado.emit(completo)
	queue_free()


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo:
		return
	var k := e as InputEventKey
	if k.keycode == KEY_ESCAPE:
		_terminar(false)
	elif k.keycode == KEY_RIGHT:
		_ir(pagina + 1)
	elif k.keycode == KEY_LEFT and pagina > 0:
		_ir(pagina - 1)
	else:
		return
	get_viewport().set_input_as_handled()
