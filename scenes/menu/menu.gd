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
const VERSION := "v0.2"

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
	# Fondo quieto: el acercamiento lento de antes, con pocos cuadros por segundo en la web, se veía temblar.
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
	UI.place(col, "tl", 92, 226, 380, 440)
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
	_item(tr("M_MULTI"), _abrir_multijugador, col)
	_item(tr("M_HOWTO"), func() -> void: _tutorial(false), col)
	_item(tr("M_CONTROLS"), _abrir_controles, col)
	_item(tr("M_SETTINGS"), _abrir_ajustes, col)
	_item(tr("M_RECORDS"), _abrir_records, col)
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


## Destello diagonal que cruza el logotipo según «barrido» (−0,4 a 1,4); fuera de ese rango no hace nada.
const BRILLO_LOGO := """shader_type canvas_item;
uniform float barrido = -1.0;
void fragment() {
	vec4 c = COLOR;
	float d = (UV.x + UV.y * 0.35) - barrido;
	float banda = smoothstep(0.16, 0.0, abs(d));
	c.rgb += vec3(1.0, 0.86, 0.62) * banda * 0.55 * c.a;
	COLOR = c;
}
"""
static var _logo_visto := false


func _crear_logotipo() -> Control:
	if ResourceLoader.exists(LOGOTIPO):
		var imagen := TextureRect.new()
		imagen.texture = load(LOGOTIPO)
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		imagen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		UI.place(imagen, "tl", 70, 56, 580, 164)
		# Sin flotar (se veía genérico): el logotipo entra una vez con un fundido y un destello de luz que lo cruza,
		# y después cada tanto un brillo muy sutil recorre las letras. El destello lo mueve un tween, no cada cuadro.
		var sombreador := Shader.new()
		sombreador.code = BRILLO_LOGO
		var material_brillo := ShaderMaterial.new()
		material_brillo.shader = sombreador
		material_brillo.set_shader_parameter("barrido", -1.0)
		imagen.material = material_brillo
		imagen.pivot_offset = Vector2(110, 82)
		if not _logo_visto:
			_logo_visto = true
			imagen.modulate.a = 0.0
			imagen.scale = Vector2(0.97, 0.97)
			var entrada := imagen.create_tween().set_parallel(true)
			entrada.tween_property(imagen, "modulate:a", 1.0, 0.9).set_delay(0.15)
			entrada.tween_property(imagen, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			entrada.tween_property(material_brillo, "shader_parameter/barrido", 1.4, 1.3).from(-0.4).set_delay(0.5) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var repeticion := imagen.create_tween().set_loops()
		repeticion.tween_interval(9.0)
		repeticion.tween_property(material_brillo, "shader_parameter/barrido", 1.4, 1.6).from(-0.4) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	b.custom_minimum_size = Vector2(340, 43)
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
		var cuerpo := _abrir_panel(tr("M_NEW_CONFIRM_TITLE"), 560, 300)
		var texto := UI.label(cuerpo, tr("M_NEW_CONFIRM"), 17, Color(UI.CREAM, 0.88))
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var pie := cuerpo.get_parent().get_child(cuerpo.get_parent().get_child_count() - 1) as HBoxContainer
		var si := Button.new()
		si.text = tr("M_NEW_CONFIRM_YES")
		si.theme_type_variation = "PrimaryButton"
		si.custom_minimum_size = Vector2(190, 42)
		si.pressed.connect(func() -> void:
			_cerrar_panel()
			_configurar_mision())
		pie.add_child(si)
		var no := pie.get_child(0) as Button
		no.text = tr("M_NEW_CONFIRM_NO")
		no.theme_type_variation = ""
		return
	_configurar_mision()


## Antes de jugar: objetivo de la misión, dificultad y cuántas personas juegan (modo equipo, hasta 4).
func _configurar_mision() -> void:
	var cuerpo := _abrir_panel(tr("M_SETUP_TITLE"), 760, 680)
	_subtitulo(cuerpo, tr("M_SETUP_DEST"))
	var fila_dest := HBoxContainer.new()
	fila_dest.add_theme_constant_override("separation", 8)
	cuerpo.add_child(fila_dest)
	var objetivo := UI.label(cuerpo, "", 14, Color(UI.CREAM, 0.88))
	objetivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objetivo.custom_minimum_size.x = 680
	var destinos: Variant = JSON.parse_string(FileAccess.get_file_as_string(Destino.DATOS))
	var lista: Dictionary = destinos.get("destinos", {}) if destinos is Dictionary else {}
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var grupo_dest := ButtonGroup.new()
	for id in (destinos.get("orden", ["marte"]) if destinos is Dictionary else ["marte"]):
		var info: Dictionary = lista.get(id, {})
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo_dest
		b.text = str(info.get("nombre", {}).get(idioma, id))
		b.custom_minimum_size = Vector2(250, 40)
		b.button_pressed = Sesion.destino == id
		b.pressed.connect(func() -> void:
			Sesion.destino = str(id)
			objetivo.text = str(info.get("descripcion", {}).get(idioma, "")))
		fila_dest.add_child(b)
	objetivo.text = str(lista.get(Sesion.destino, {}).get("descripcion", {}).get(idioma, ""))
	_subtitulo(cuerpo, tr("M_SETUP_DIFF"))
	var fila_dif := HBoxContainer.new()
	fila_dif.add_theme_constant_override("separation", 8)
	cuerpo.add_child(fila_dif)
	var explicacion := UI.label(cuerpo, "", 13, Color(UI.CREAM, 0.7))
	explicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explicacion.custom_minimum_size.x = 640
	var grupo_dif := ButtonGroup.new()
	for id in ["exploracion", "estandar", "experta"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo_dif
		b.text = tr("DIFF_" + id.to_upper())
		b.custom_minimum_size = Vector2(200, 40)
		b.button_pressed = Sesion.dificultad == id
		b.pressed.connect(func() -> void:
			Sesion.dificultad = id
			explicacion.text = tr("DIFF_" + id.to_upper() + "_D"))
		fila_dif.add_child(b)
	explicacion.text = tr("DIFF_" + Sesion.dificultad.to_upper() + "_D")
	_selector_duracion_sol(cuerpo)
	_subtitulo(cuerpo, tr("M_SETUP_TEAM"))
	var fila_eq := HBoxContainer.new()
	fila_eq.add_theme_constant_override("separation", 8)
	cuerpo.add_child(fila_eq)
	var roles := UI.label(cuerpo, "", 13, Color(UI.CREAM, 0.7))
	roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roles.custom_minimum_size.x = 640
	var grupo_eq := ButtonGroup.new()
	for n in range(1, 5):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo_eq
		b.text = tr("M_SETUP_PLAYERS") % n if n > 1 else tr("M_SETUP_SOLO")
		b.custom_minimum_size = Vector2(150, 40)
		b.button_pressed = Sesion.jugadores == n
		b.pressed.connect(func() -> void:
			Sesion.jugadores = n
			roles.text = _texto_roles(n))
		fila_eq.add_child(b)
	roles.text = _texto_roles(Sesion.jugadores)
	var pie := cuerpo.get_parent().get_child(cuerpo.get_parent().get_child_count() - 1) as HBoxContainer
	var empezar := Button.new()
	empezar.text = tr("M_SETUP_START")
	empezar.theme_type_variation = "PrimaryButton"
	empezar.custom_minimum_size = Vector2(200, 42)
	empezar.pressed.connect(func() -> void:
		Sesion.votos = []
		_cerrar_panel()
		_empezar_nueva())
	pie.add_child(empezar)
	var volver := pie.get_child(0) as Button
	volver.theme_type_variation = ""
	empezar.grab_focus.call_deferred()


## Duración de cada sol (plan 3.1): 6, 8, 10 o 12 minutos reales.
func _selector_duracion_sol(cuerpo: Control) -> void:
	_subtitulo(cuerpo, tr("M_SETUP_SOL"))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	cuerpo.add_child(fila)
	var nota := UI.label(cuerpo, "", 13, Color(UI.CREAM, 0.7))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 640
	var grupo := ButtonGroup.new()
	for minutos in Sesion.DURACIONES_SOL:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo
		b.text = tr("M_SETUP_SOL_N") % minutos
		b.custom_minimum_size = Vector2(140, 40)
		b.button_pressed = Sesion.duracion_sol_min == minutos
		b.pressed.connect(func() -> void:
			Sesion.duracion_sol_min = minutos
			nota.text = texto_duracion_sol(minutos))
		fila.add_child(b)
	nota.text = texto_duracion_sol(Sesion.duracion_sol_min)


## «6 soles ≈ 72 min de partida…» con el sol límite de content/rules.json.
static func texto_duracion_sol(minutos: int) -> String:
	var soles := Rules.desde_archivo("res://content/rules.json").sol_limite
	return TranslationServer.translate("M_SETUP_SOL_D") % [soles, soles * minutos]


## «Persona 1: Dirección y Ciencia · Persona 2: ...» según cuántos juegan.
func _texto_roles(n: int) -> String:
	if n <= 1:
		return tr("M_SETUP_SOLO_D")
	var partes: Array[String] = []
	var reparto := Sesion.roles_por_jugador(n)
	for i in range(reparto.size()):
		var nombres: Array[String] = []
		for rol in reparto[i]:
			nombres.append(tr("ROLE_" + str(rol).to_upper()))
		partes.append(tr("GNG_PLAYER") % (i + 1) + ": " + " + ".join(nombres))
	return tr("M_SETUP_TEAM_D") + "\n" + "  ·  ".join(partes)


## Partida en red (scenes/net/): sala, jugadores y, al empezar el jefe, todos pasan a la carga a la vez.
func _abrir_multijugador() -> void:
	_cerrar_panel()
	var panel := preload("res://scenes/net/lobby_panel.gd").new()
	panel.build()
	panel.cerrado.connect(_cerrar_panel)
	panel.partida_lista.connect(func() -> void:
		_cerrar_panel()
		_ir_al_juego(false))
	_panel = panel
	add_child(panel)
	move_child(panel, get_child_count() - 2)


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
func _abrir_panel(titulo: String, ancho: float, alto: float) -> VBoxContainer:
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
	# Gráficos: ajuste predefinido y, en su panel, cada opción por separado.
	fila = _fila(cuerpo, tr("M_SET_GRAPHICS"))
	var mas := Button.new()
	mas.text = tr("M_SET_GRAPHICS_MORE") + "  ·  " + _nombre_graficos(Graficos.cargar())
	mas.custom_minimum_size = Vector2(250, 40)
	mas.pressed.connect(_abrir_graficos)
	fila.add_child(mas)
	# Tamaño de ventana (solo en escritorio)
	if not Texto.tamanos_disponibles().is_empty():
		var ventana := HFlowContainer.new()
		ventana.add_theme_constant_override("h_separation", 8)
		ventana.add_theme_constant_override("v_separation", 6)
		cuerpo.add_child(ventana)
		var etiqueta := UI.label(ventana, tr("M_SET_WINDOW"), 17, UI.CREAM)
		etiqueta.custom_minimum_size.x = 640
		Texto.botones_tamano(ventana, func() -> void: _abrir_ajustes())
		var aviso := UI.label(cuerpo, tr("M_SET_WINDOW_NOTE"), 13, Color(UI.CREAM, 0.6))
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Pantalla completa y tutorial
	_interruptor(cuerpo, tr("M_SET_FULLSCREEN"), Texto.en_pantalla_completa(), func(v: bool) -> void:
		Texto.poner_pantalla_completa(v)
		_abrir_ajustes.call_deferred())  # para que la fila de tamaños marque «Nativa» o el tamaño de ventana
	_interruptor(cuerpo, tr("M_SET_TUTORIAL"), bool(prefs["tutorial"]), func(v: bool) -> void:
		Texto.guardar("ui", "tutorial", v))


func _nombre_graficos(g: Dictionary) -> String:
	var preset := Graficos.preset_de(g)
	return tr("GFX_CUSTOM") if preset == "personalizada" else tr("GFX_" + preset.to_upper())


func _abrir_graficos() -> void:
	var cuerpo := _abrir_panel(tr("GRAPHICS"), 620, 600)
	var opciones := OpcionesGraficos.new(Graficos.cargar(), 17)
	cuerpo.add_child(opciones)
	opciones.cambiado.connect(func(g: Dictionary) -> void: Graficos.guardar(g))


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


## Récords del equipo: las mejores misiones guardadas en este equipo, con su código de diseño para comparar.
func _abrir_records() -> void:
	var Registro := preload("res://scenes/menu/registro.gd")
	var cuerpo := _abrir_panel(tr("M_RECORDS_TITLE"), 760, 560)
	var lista := Registro.leer()
	if lista.is_empty():
		var vacio := UI.label(cuerpo, tr("M_RECORDS_EMPTY"), 15, Color(UI.CREAM, 0.8))
		vacio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vacio.custom_minimum_size.x = 680
		return
	var tabla := GridContainer.new()
	tabla.columns = 6
	tabla.add_theme_constant_override("h_separation", 18)
	tabla.add_theme_constant_override("v_separation", 6)
	cuerpo.add_child(tabla)
	for titulo in ["#", tr("M_REC_SCORE"), tr("M_SETUP_DEST"), tr("M_SETUP_DIFF"), tr("M_SETUP_TEAM"), tr("M_REC_CODE")]:
		var c := UI.label(tabla, titulo, 12, UI.AMBER)
		UI.display(c, 700, 1)
	for i in range(mini(lista.size(), 10)):
		var r: Dictionary = lista[i]
		var destino := "Luna" if str(r.get("destination", "")) == "luna" else "Marte"
		if TranslationServer.get_locale().begins_with("en"):
			destino = "Moon" if destino == "Luna" else "Mars"
		for valor in [str(i + 1), str(int(r.get("score", 0))), destino, tr("DIFF_" + str(r.get("difficulty", "estandar")).to_upper()),
				str(int(r.get("players", 1))), str(r.get("code", ""))]:
			UI.label(tabla, valor, 14, UI.CREAM)
	var nota := UI.label(cuerpo, tr("M_RECORDS_NOTE"), 12, Color(UI.CREAM, 0.6))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 680
