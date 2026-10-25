extends CanvasLayer
## HUD de operaciones según el diseño visual consolidado: deja libre el centro y solo presenta el snapshot.
## No decide reglas: habilitaciones, motivos, acciones pertinentes y avisos llegan de la simulación.
## Interfaz pública (mission_view, review_host y pruebas): señales command / locale_changed / preferences_changed,
## build(), update_snapshot(), set_target(), show_notice(), start_action(), show_help(), set_hover_hint(),
## y las variables buttons, settings, review_panel, pause_button, snapshot, inspection, volume, muted, quality.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")
const MiniMap := preload("res://scenes/b/minimap.gd")
const GaiaLogo := preload("res://scenes/menu/gaia_logo.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const Markers := preload("res://scenes/b/target_markers.gd")
const StoryPanel := preload("res://scenes/b/story_panel.gd")
const BaseHud := preload("res://scenes/b/base_hud.gd")
const LOGOTIPO := "res://assets/menu/gaia_logo.png"  ## logotipo del menú (si falta, se usa el 3D por código)

signal command(command: String, payload: Dictionary)
signal locale_changed(locale: String)
signal preferences_changed(volume: float, muted: bool, quality: bool)
signal menu_requested  ## «Salir al menú» del menú de pausa

## Filas de la lista del objetivo que siempre existen (las pruebas de B leen buttons.drill).
const TARGET_ACTIONS: Array[String] = ["approach", "spectrometer", "drill"]
## Acciones sin objetivo: fila inferior central, solo las instaladas.
const GLOBAL_ACTIONS: Array[String] = ["panorama", "radar", "drone", "companion", "upgrade"]
const HOTKEYS := {KEY_C: "panorama", KEY_V: "radar", KEY_X: "companion", KEY_T: "transmit"}
const HOTKEY_TEXT := {"panorama": "C", "radar": "V", "companion": "X", "transmit": "T"}
const LABEL_SIZE := Vector2(176, 34)
const ROW_HEIGHT := 40.0

var root: Control
var snapshot: Dictionary = {}
var buttons: Dictionary = {}
var settings: Control
var review_panel: Control
var help_view: Control
var pause_button: Button
var inspection := false
var volume := 0.65
var muted := false
var quality := true
var target_id := ""

var _ops: Array[Control] = []
var _title: Label
var _objective: Label
var _goals: VBoxContainer  ## metas del objetivo con su avance (historia)
var _goals_sig := ""
var _map: Control
var _mark: Control
var _energy_icon: Control
var _energy_text: Label
var _energy_pill: Button
var _science_text: Label
var _science_pill: Button
var _warn_slot: PanelContainer
var _warn_text: Label
var _warn_more: Button
var _warn_list: PanelContainer
var _warn_list_box: VBoxContainer
var _crit_slot: PanelContainer
var _crit_text: Label
var _toast: PanelContainer
var _toast_text: Label
var _toast_until := 0.0
var _toast_key := ""
var _clock_pill: PanelContainer
var _clock_icon: Control
var _clock_text: Label
var _comms: PanelContainer
var _comms_icon: Control
var _comms_title: Label
var _comms_row: HBoxContainer
var _comms_detail: Label
var _comms_hover := false
var _comms_expanded := false
var _comms_wants := false
var _comms_tween: Tween
var _actions_row: HBoxContainer
var _progress: ProgressBar
var _active_seconds := 0.0
var _active_total := 0.0
var _info: PanelContainer
var _info_values: Dictionary = {}
var _summary: PanelContainer
var _summary_labels: Dictionary = {}
var _summary_bar: ProgressBar
var _summary_button: Button
var _markers: Control
var _label_box: HBoxContainer
var _primary: Button
var _arrow: Button
var _open_actions := false
var _primary_action := ""
var _target_shown := false
var _list: PanelContainer
var _list_box: VBoxContainer
var _rows: Dictionary = {}
var _landing_text: PanelContainer
var _dim: ColorRect
var _menu: PanelContainer
var _menu_resume: Button
var _hover_hint: PanelContainer
var _hover_label: Label
var _debug: Label
var _was_night := false
var _night_known := false
var _pending_help := false
var _tweens: Array[Tween] = []
var _free_options := false  ## opciones abiertas fuera de la pausa (taller)


## Partes del HUD a las que apunta el halo del tutorial.
func highlight_nodes() -> Dictionary:
	return {"acciones": _actions_row, "enlace": _comms}


func _ready() -> void:
	layer = 5
	build()


# ---------------------------------------------------------------- construcción

func build() -> void:
	var reabrir_opciones := is_instance_valid(settings) and settings.visible
	for tw in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
	if _comms_tween != null and _comms_tween.is_valid():
		_comms_tween.kill()
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	buttons.clear()
	_ops.clear()
	_rows.clear()
	_info_values.clear()
	_summary_labels.clear()
	_comms_expanded = false
	_night_known = false
	_titulo_de_aterrizaje = -1
	_tono_energia = Color(0, 0, 0, 0)
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_markers = Markers.new()
	_markers.name = "TargetMarkers"
	root.add_child(_markers)
	_markers.project = _project
	_build_top_left()
	_build_top_right()
	_build_bottom()
	_build_slots()
	_build_target_ui()
	_build_info()
	_build_summary()
	_build_landing()
	_build_hover_hint()
	_build_pause()
	_build_review()
	if reabrir_opciones:
		_open_sub(settings)
	if not snapshot.is_empty():
		update_snapshot(snapshot)


func _build_top_left() -> void:
	_summary_button = Button.new()
	_summary_button.text = "A"
	_summary_button.theme_type_variation = "IconButton"
	_summary_button.focus_mode = Control.FOCUS_NONE
	_summary_button.tooltip_text = tr("OPEN_SUMMARY")
	_summary_button.add_theme_font_size_override("font_size", 15)
	UI.place(_summary_button, "tl", 20, 20, 34, 34)
	root.add_child(_summary_button)
	_summary_button.pressed.connect(func(): _toggle_panel(_summary))
	# Logotipo 3D (letras extruidas y emblema), renderizado una sola vez en su propio SubViewport.
	if ResourceLoader.exists(LOGOTIPO):
		var imagen := TextureRect.new()
		imagen.texture = load(LOGOTIPO)
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		imagen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		imagen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mark = imagen
	else:
		_mark = GaiaLogo.new()
	_mark.name = "GaiaLogo"
	UI.place(_mark, "tl", 58, 8, 168, 48)
	root.add_child(_mark)
	_title = Label.new()
	_title.text = "GAIA"
	_title.add_theme_font_override("font", UI.display_font(700, 5))
	_title.add_theme_font_size_override("font_size", UI.FONT_TITLE)
	_title.add_theme_color_override("font_shadow_color", Color(UI.SURFACE, 0.75))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 2)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.place(_title, "tl", 64, 18, 330, 30)
	root.add_child(_title)
	_objective = UI.label(root, tr("OBJECTIVE_SHORT"), UI.FONT_OBJECTIVE, Color(UI.CREAM, 0.9))
	_objective.clip_text = true
	UI.place(_objective, "tl", 64, 54, 330, 20)
	_ops.append(_objective)
	_goals = VBoxContainer.new()
	_goals.add_theme_constant_override("separation", 3)
	_goals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_goals, "tl", 64, 258, 250, 90)
	root.add_child(_goals)
	_goals_sig = ""
	_ops.append(_goals)
	_map = MiniMap.new()
	_map.name = "MiniMap"
	root.add_child(_map)
	UI.place(_map, "tl", 64, 82, 168, 168)
	_map.tile_chosen.connect(func(tile: Vector2i): emit_command("move", {"tile": tile}))
	_ops.append(_map)
	var cuadricula := _icon_button("grid", tr("GRID"), func(): emit_command("grid"), 36, 16)
	root.add_child(cuadricula)
	UI.place(cuadricula, "tl", 240, 82, 36, 36)
	_ops.append(cuadricula)


func _build_top_right() -> void:
	pause_button = _icon_button("pause", tr("PAUSE"), _toggle_pause, 30, 13)
	root.add_child(pause_button)
	UI.place(pause_button, "tr", 20, 22, 30, 30)
	_science_pill = _pill_button("science", 150, 30)
	UI.place(_science_pill, "tr", 60, 22, 150, 30)
	_science_text = _science_pill.get_meta("text")
	_science_pill.tooltip_text = tr("SENT")
	_science_pill.pressed.connect(func(): _toggle_panel(_info))
	_ops.append(_science_pill)
	_energy_pill = _pill_button("battery", 140, 30)
	UI.place(_energy_pill, "tr", 220, 22, 140, 30)
	_energy_text = _energy_pill.get_meta("text")
	_energy_icon = _energy_pill.get_meta("icon")
	_energy_pill.tooltip_text = tr("ENERGY")
	_energy_pill.pressed.connect(func(): _toggle_panel(_info))
	_ops.append(_energy_pill)


## Las píldoras de energía y ciencia crecen con su texto y se apilan desde el botón de pausa: nunca se desbordan ni se pisan.
func _fit_top_right() -> void:
	var derecha := 20.0 + 30.0 + 10.0
	for par in [[_science_pill, _science_text], [_energy_pill, _energy_text]]:
		var pildora: Button = par[0]
		var texto: Label = par[1]
		var fuente := texto.get_theme_font("font")
		var ancho := fuente.get_string_size(texto.text, HORIZONTAL_ALIGNMENT_LEFT, -1, texto.get_theme_font_size("font_size")).x
		var w := maxf(104.0, 16.0 + 7.0 + ancho + 32.0)
		pildora.custom_minimum_size.x = w
		UI.place(pildora, "tr", derecha, 22, w, 30)
		derecha += w + 10.0


func _build_slots() -> void:
	_warn_slot = _slot("warning", UI.WARN)
	UI.place(_warn_slot, "tc", -70, 20, 340, 48)
	_warn_text = _warn_slot.get_meta("text")
	_warn_more = Button.new()
	_warn_more.theme_type_variation = "PillButton"
	_warn_more.focus_mode = Control.FOCUS_NONE
	_warn_more.custom_minimum_size = Vector2(44, 30)
	_warn_more.add_theme_font_size_override("font_size", UI.FONT_SECONDARY)
	_warn_more.visible = false
	_warn_slot.get_meta("row").add_child(_warn_more)
	_warn_more.pressed.connect(func(): _toggle_panel(_warn_list))
	_crit_slot = _slot("critical", UI.CORAL)
	UI.place(_crit_slot, "tc", -70, 76, 340, 48)
	_crit_text = _crit_slot.get_meta("text")
	_warn_list = PanelContainer.new()
	_warn_list.add_theme_stylebox_override("panel", UI.box(0.8, UI.RADIUS_PANEL, 0.3, 1, 14, 10, UI.WARN))
	UI.place(_warn_list, "tc", -70, 132, 340, 0)
	_warn_list_box = VBoxContainer.new()
	_warn_list_box.add_theme_constant_override("separation", 8)
	_warn_list.add_child(_warn_list_box)
	_warn_list.visible = false
	root.add_child(_warn_list)
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PILL, 0.35, 1, 18, 8))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_toast, "bc", 0, 128, 360, 0)
	_toast_text = UI.label(_toast, "", UI.FONT_SECONDARY)
	_toast_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_text.custom_minimum_size.x = 324
	_toast.visible = false
	root.add_child(_toast)


func _build_bottom() -> void:
	_clock_pill = PanelContainer.new()
	var sin_fondo := StyleBoxEmpty.new()
	sin_fondo.content_margin_left = 2.0
	sin_fondo.content_margin_right = 2.0
	_clock_pill.add_theme_stylebox_override("panel", sin_fondo)
	UI.place(_clock_pill, "bl", 20, 20, 200, 38)
	root.add_child(_clock_pill)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_clock_pill.add_child(fila)
	_clock_icon = Icon.make("sun", 16)
	fila.add_child(_clock_icon)
	_clock_text = UI.label(fila, "", UI.FONT_TEXT)
	_clock_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_text.add_theme_color_override("font_shadow_color", Color(UI.SURFACE, 0.8))
	_clock_text.add_theme_constant_override("shadow_offset_x", 0)
	_clock_text.add_theme_constant_override("shadow_offset_y", 1)
	_clock_text.add_theme_color_override("font_outline_color", Color(UI.SURFACE, 0.55))
	_clock_text.add_theme_constant_override("outline_size", 4)
	_ops.append(_clock_pill)
	# Comunicación: píldora que se expande con enlace, transmisión, apertura próxima, hover o foco.
	_comms = PanelContainer.new()
	_comms.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_NORMAL, UI.RADIUS_PILL, 0.25, 1, 14, 6))
	_comms.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.place(_comms, "br", 20, 20, 166, 32)
	_comms.custom_minimum_size = Vector2(166, 32)
	root.add_child(_comms)
	_comms.mouse_entered.connect(func(): _comms_hover = true)
	_comms.mouse_exited.connect(func(): _comms_hover = _comms.get_global_rect().has_point(_comms.get_global_mouse_position()))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_comms.add_child(col)
	var arriba := HBoxContainer.new()
	arriba.add_theme_constant_override("separation", 6)
	arriba.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(arriba)
	_comms_icon = Icon.make("link", 16, UI.TEAL)
	arriba.add_child(_comms_icon)
	_comms_title = UI.label(arriba, "", 15)
	_comms_title.clip_text = true
	_comms_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comms_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_comms_row = HBoxContainer.new()
	_comms_row.add_theme_constant_override("separation", 8)
	_comms_row.visible = false
	col.add_child(_comms_row)
	_comms_detail = UI.label(_comms_row, "", 13, Color(UI.CREAM, 0.85))
	_comms_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_comms_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_comms_detail.clip_text = true
	_comms_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_comms_detail.custom_minimum_size.x = 140
	_comms_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	var transmitir := Button.new()
	transmitir.theme_type_variation = "PrimaryPill"
	transmitir.focus_mode = Control.FOCUS_NONE
	transmitir.custom_minimum_size = Vector2(108, 36)
	transmitir.add_theme_font_size_override("font_size", 15)
	transmitir.text = tr("TRANSMIT_SHORT")
	_comms_row.add_child(transmitir)
	transmitir.pressed.connect(func(): emit_command("transmit", {"on": not snapshot.get("transmitting", false)}))
	buttons["transmit"] = transmitir
	_ops.append(_comms)
	# Acciones sin objetivo (decisión de A: fila discreta abajo al centro, solo instrumentos instalados).
	_actions_row = HBoxContainer.new()
	_actions_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_actions_row.add_theme_constant_override("separation", 6)
	UI.place(_actions_row, "bl", 190, 20, 660, 36)
	root.add_child(_actions_row)
	for accion in GLOBAL_ACTIONS:
		var b := Button.new()
		b.theme_type_variation = "PillButton"
		b.focus_mode = Control.FOCUS_NONE
		b.text = tr(accion.to_upper())
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_font_size_override("font_size", 13)
		_actions_row.add_child(b)
		if accion == "upgrade":
			b.pressed.connect(func(): emit_command("upgrade"))
		else:
			b.pressed.connect(_act.bind(accion))
		buttons[accion] = b
	_ops.append(_actions_row)
	_progress = ProgressBar.new()
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_progress, "bc", 0, 68, 220, 6)
	_progress.visible = false
	root.add_child(_progress)
	_debug = UI.label(root, "", 12, Color(UI.CREAM, 0.8))
	UI.place(_debug, "bl", 20, 66, 420, 18)
	_debug.visible = inspection


func _build_target_ui() -> void:
	_label_box = HBoxContainer.new()
	_label_box.add_theme_constant_override("separation", 1)
	_label_box.visible = false
	root.add_child(_label_box)
	_label_box.size = LABEL_SIZE
	_primary = Button.new()
	_primary.theme_type_variation = "LabelLeft"
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.custom_minimum_size = Vector2(LABEL_SIZE.x - 35, LABEL_SIZE.y)
	_primary.clip_text = true
	_primary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label_box.add_child(_primary)
	_primary.pressed.connect(func(): _run_action(_primary_action))
	_arrow = Button.new()
	_arrow.theme_type_variation = "LabelRight"
	_arrow.focus_mode = Control.FOCUS_NONE
	_arrow.custom_minimum_size = Vector2(34, LABEL_SIZE.y)
	_arrow.tooltip_text = tr("MORE_ACTIONS")
	_label_box.add_child(_arrow)
	var flecha := Icon.make("chevron_down", 14)
	_center(flecha, 14)
	_arrow.add_child(flecha)
	_arrow.pressed.connect(func(): _toggle_panel(_list); _place_target_ui())
	_list = PanelContainer.new()
	_list.add_theme_stylebox_override("panel", UI.box(0.85, UI.RADIUS_LABEL, 0.3, 1, 8, 8))
	_list.visible = false
	root.add_child(_list)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 4)
	_list.add_child(_list_box)
	for accion in TARGET_ACTIONS:
		_row(accion)


func _row(accion: String) -> Button:
	if _rows.has(accion):
		return _rows[accion]
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(224, ROW_HEIGHT)
	b.text = tr("APPROACH") if accion == "approach" else tr(accion.to_upper())
	_list_box.add_child(b)
	var motivo := UI.label(b, "", 12, UI.AMBER)
	motivo.position = Vector2(12, 21)
	motivo.size = Vector2(204, 16)
	motivo.clip_text = true
	motivo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("reason", motivo)
	b.pressed.connect(func(): _list.visible = false; _run_action(accion))
	_rows[accion] = b
	buttons[accion] = b
	return b


func _build_info() -> void:
	_info = PanelContainer.new()
	UI.place(_info, "tr", 20, 72, 300, 0)
	_info.visible = false
	root.add_child(_info)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_info.add_child(col)
	_panel_title(col, tr("INFO_TITLE"))
	var tabla := GridContainer.new()
	tabla.columns = 2
	tabla.add_theme_constant_override("h_separation", 12)
	tabla.add_theme_constant_override("v_separation", 6)
	col.add_child(tabla)
	for clave in ["INFO_STORED", "INFO_BATTERY", "INFO_GENERATION", "INFO_LOAD", "INFO_POWER", "INFO_MINERALS",
			"INFO_ANTENNA", "INFO_LINK", "INFO_DUST", "INFO_STORM"]:
		var nombre := UI.label(tabla, tr(clave), UI.FONT_SECONDARY, Color(UI.CREAM, 0.75))
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var valor := UI.label(tabla, "—", 15)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_info_values[clave] = valor


func _build_summary() -> void:
	_summary = PanelContainer.new()
	UI.place(_summary, "tl", 20, 64, 360, 0)
	_summary.visible = false
	root.add_child(_summary)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_summary.add_child(col)
	_summary_labels["title"] = _panel_title(col, tr("SUMMARY_TITLE"))
	_summary_labels["mission"] = UI.label(col, tr("MISSION"), UI.FONT_SECONDARY, UI.AMBER)
	var brief := UI.label(col, tr("BRIEF"), UI.FONT_SECONDARY, Color(UI.CREAM, 0.9))
	brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	brief.custom_minimum_size.x = 328
	_summary_labels["brief"] = brief
	_summary_labels["goal"] = UI.label(col, "", UI.FONT_TEXT)
	_summary_bar = ProgressBar.new()
	_summary_bar.show_percentage = false
	_summary_bar.custom_minimum_size = Vector2(0, 6)
	col.add_child(_summary_bar)
	_summary_labels["progress"] = UI.label(col, "", UI.FONT_SECONDARY)
	_summary_labels["deadline"] = UI.label(col, "", UI.FONT_SECONDARY)
	var guardada := UI.label(col, tr("SUMMARY_STORED"), 13, Color(UI.CREAM, 0.75))
	guardada.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guardada.custom_minimum_size.x = 328
	_summary_labels["safe"] = UI.label(col, "", 13, Color(UI.CREAM, 0.85))
	_summary_labels["early"] = UI.label(col, "", 13, Color(UI.CREAM, 0.85))


func _build_landing() -> void:
	_landing_text = PanelContainer.new()
	_landing_text.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PILL, 0.25, 1, 22, 8))
	_landing_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_landing_text, "bc", 0, 24, 280, 40)
	var texto := UI.label(_landing_text, tr("LANDING_FIXED"), UI.FONT_TEXT)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_landing_text.visible = false
	root.add_child(_landing_text)


func _build_hover_hint() -> void:
	_hover_hint = PanelContainer.new()
	_hover_hint.add_theme_stylebox_override("panel", UI.box(0.8, UI.RADIUS_LABEL, 0.4, 1, 10, 4, UI.CORAL))
	_hover_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_hint.visible = false
	root.add_child(_hover_hint)
	_hover_label = UI.label(_hover_hint, "", 13)


func _build_pause() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(UI.SURFACE, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	root.add_child(_dim)
	_menu = PanelContainer.new()
	_menu.add_theme_stylebox_override("panel", UI.box(0.95, UI.RADIUS_PANEL, 0.25, 1, 24, 24))
	UI.place(_menu, "c", 0, 0, 420, 466)
	_menu.visible = false
	root.add_child(_menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_menu.add_child(col)
	var cabecera := HBoxContainer.new()
	col.add_child(cabecera)
	var titulo := _panel_title(cabecera, tr("PAUSE_TITLE"))
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cerrar := _icon_button("close", tr("CLOSE"), _toggle_pause, 36, 14)
	cerrar.focus_mode = Control.FOCUS_ALL
	cabecera.add_child(cerrar)
	var hueco := Control.new()
	hueco.custom_minimum_size.y = 18
	col.add_child(hueco)
	_menu_resume = _menu_button(col, tr("MENU_RESUME"), _toggle_pause)
	_menu_resume.theme_type_variation = "PrimaryButton"
	_menu_button(col, tr("OPTIONS"), func(): _open_sub(settings))
	_menu_button(col, tr("HELP"), func(): _open_sub(help_view))
	_menu_button(col, tr("MENU_QUIT"), func(): menu_requested.emit())
	var nota := UI.label(col, tr("CONTROLS"), 12, Color(UI.CREAM, 0.7))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 372
	# Subvista de opciones.
	settings = _subview(tr("OPTIONS"))
	var cuerpo: VBoxContainer = settings.get_meta("body")
	var idioma := HBoxContainer.new()
	idioma.add_theme_constant_override("separation", 8)
	cuerpo.add_child(idioma)
	var etiqueta := UI.label(idioma, tr("LANGUAGE"), UI.FONT_TEXT)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for codigo in ["es", "en"]:
		var b := Button.new()
		b.text = codigo.to_upper()
		b.custom_minimum_size = Vector2(64, 40)
		b.toggle_mode = true
		b.button_pressed = TranslationServer.get_locale().begins_with(codigo)
		idioma.add_child(b)
		b.pressed.connect(func(): locale_changed.emit(codigo))
	UI.label(cuerpo, tr("VOLUME"), UI.FONT_SECONDARY)
	var deslizador := HSlider.new()
	deslizador.min_value = 0
	deslizador.max_value = 1
	deslizador.step = 0.01
	deslizador.value = volume
	deslizador.custom_minimum_size.y = 24
	cuerpo.add_child(deslizador)
	var sonido := CheckButton.new()
	sonido.text = tr("SOUND")
	sonido.button_pressed = not muted
	cuerpo.add_child(sonido)
	var calidad := CheckButton.new()
	calidad.text = tr("QUALITY")
	calidad.button_pressed = quality
	cuerpo.add_child(calidad)
	var completa := CheckButton.new()
	completa.text = tr("FULLSCREEN")
	completa.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	cuerpo.add_child(completa)
	deslizador.value_changed.connect(func(valor: float): volume = valor; preferences_changed.emit(volume, muted, quality))
	sonido.toggled.connect(func(on: bool): muted = not on; preferences_changed.emit(volume, muted, quality))
	calidad.toggled.connect(func(on: bool): quality = on; preferences_changed.emit(volume, muted, quality))
	completa.toggled.connect(func(on: bool): DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	if not Texto.tamanos_disponibles().is_empty():
		UI.label(cuerpo, tr("WINDOW_SIZE"), UI.FONT_SECONDARY)
		var ventana := HFlowContainer.new()
		ventana.add_theme_constant_override("h_separation", 8)
		ventana.add_theme_constant_override("v_separation", 6)
		cuerpo.add_child(ventana)
		Texto.botones_tamano(ventana, func(): completa.set_pressed_no_signal(false))
	UI.label(cuerpo, tr("SAVED_SETTINGS"), 12, Color(UI.CREAM, 0.7))
	# Subvista de ayuda.
	help_view = _subview(tr("HELP_TITLE"))
	var ayuda: VBoxContainer = help_view.get_meta("body")
	for clave in ["HELP_TEXT", "CONTROLS"]:
		var texto := UI.label(ayuda, tr(clave), UI.FONT_TEXT if clave == "HELP_TEXT" else UI.FONT_SECONDARY)
		texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		texto.custom_minimum_size.x = 440


func _subview(titulo: String) -> PanelContainer:
	var vista := PanelContainer.new()
	vista.add_theme_stylebox_override("panel", UI.box(0.95, UI.RADIUS_PANEL, 0.25, 1, 24, 24))
	UI.place(vista, "c", 0, 0, 520, 460)
	vista.visible = false
	root.add_child(vista)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	vista.add_child(col)
	_panel_title(col, titulo)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazable.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desplazable)
	var cuerpo := VBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 12)
	cuerpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(cuerpo)
	var volver := _menu_button(col, tr("BACK"), _close_sub)
	volver.custom_minimum_size = Vector2(0, 44)
	vista.set_meta("body", cuerpo)
	vista.set_meta("back", volver)
	return vista


func _build_review() -> void:
	review_panel = PanelContainer.new()
	UI.place(review_panel, "c", 0, 0, 520, 470)
	root.add_child(review_panel)
	var col := VBoxContainer.new()
	review_panel.add_child(col)
	_panel_title(col, tr("REVIEW_TITLE"))
	var nota := UI.label(col, tr("REVIEW_NOTE"), 13)
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for escenario in ["solar", "rtg", "storm", "night", "safe", "win", "lose", "reset"]:
		UI.button(col, tr("R_" + escenario.to_upper()), func(): emit_command("review", {"scenario": escenario}))
	UI.button(col, tr("CLOSE"), func(): review_panel.hide())
	review_panel.hide()


# ---------------------------------------------------------------- piezas reutilizables

func _icon_button(tipo: String, ayuda: String, accion: Callable, lado: float, icono: float) -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = ayuda
	b.custom_minimum_size = Vector2(lado, lado)
	var i := Icon.make(tipo, icono)
	_center(i, icono)
	b.add_child(i)
	b.set_meta("icon", i)
	b.pressed.connect(accion)
	return b


func _pill_button(tipo: String, w: float, h: float) -> Button:
	var b := Button.new()
	b.theme_type_variation = "PillButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, h)
	root.add_child(b)
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	fila.add_theme_constant_override("separation", 7)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(fila)
	var i := Icon.make(tipo, 16)
	fila.add_child(i)
	var texto := UI.label(fila, "—", UI.FONT_FIGURE)
	UI.display(texto, 600)
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("icon", i)
	b.set_meta("text", texto)
	return b


func _slot(tipo: String, tono: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PANEL, 0.9, 1, 14, 6, tono))
	p.visible = false
	p.set_meta("on", false)
	root.add_child(p)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	p.add_child(fila)
	fila.add_child(Icon.make(tipo, 20, tono))
	var texto := UI.label(fila, "", UI.FONT_TEXT)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	texto.clip_text = true
	texto.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	p.set_meta("text", texto)
	p.set_meta("row", fila)
	return p


func _menu_button(parent: Node, texto: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(372, 44)
	b.focus_mode = Control.FOCUS_ALL
	parent.add_child(b)
	b.pressed.connect(accion)
	return b


func _panel_title(parent: Node, texto: String) -> Label:
	var l := UI.label(parent, texto, UI.FONT_PANEL_TITLE)
	var medio := UI.display_font(600)
	if medio != null:
		l.add_theme_font_override("font", medio)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _center(c: Control, lado: float) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -lado / 2.0
	c.offset_right = lado / 2.0
	c.offset_top = -lado / 2.0
	c.offset_bottom = lado / 2.0


func _fade(c: Control, on: bool) -> void:
	if not is_instance_valid(c) or bool(c.get_meta("on", false)) == on:
		return
	c.set_meta("on", on)
	var tw := create_tween()
	_tweens.append(tw)
	if on:
		c.visible = true
		c.modulate.a = 0.0
		tw.tween_property(c, "modulate:a", 1.0, 0.22)
	else:
		tw.tween_property(c, "modulate:a", 0.0, 0.16)
		tw.tween_callback(func(): if is_instance_valid(c) and not bool(c.get_meta("on", false)): c.visible = false)


# ---------------------------------------------------------------- órdenes

func emit_command(key: String, payload: Dictionary = {}) -> void:
	command.emit(key, payload)


func _act(action: String) -> void:
	emit_command("act", {"target_id": target_id, "action": action})


func _run_action(accion: String) -> void:
	if accion.is_empty():
		return
	if accion == "approach":
		emit_command("approach", {"target_id": target_id})
	else:
		_act(accion)


func _toggle_pause() -> void:
	if pause_button.disabled:
		return
	emit_command("pause", {"paused": not snapshot.get("paused", false)})


func _toggle_panel(p: Control) -> void:
	var abrir := not p.visible
	for otro in [_info, _summary, _warn_list, _list]:
		if otro != p:
			otro.visible = false
	p.visible = abrir


func close_actions() -> void:
	_open_actions = false
	_list.visible = false


func _close_popups() -> bool:
	var algo := false
	for p in [_info, _summary, _warn_list, _list]:
		if p.visible:
			p.visible = false
			algo = true
	return algo


func _open_sub(vista: Control) -> void:
	_menu.visible = false
	settings.visible = vista == settings
	help_view.visible = vista == help_view
	var volver: Button = vista.get_meta("back")
	volver.grab_focus.call_deferred()


## Abre las opciones sin pausar la misión (el taller reutiliza esta superficie).
func open_options() -> void:
	_free_options = true
	_dim.visible = true
	_open_sub(settings)


func _close_sub() -> void:
	_free_options = false
	settings.visible = false
	help_view.visible = false
	_menu.visible = snapshot.get("paused", false)
	_dim.visible = _menu.visible
	if _menu.visible:
		_menu_resume.grab_focus.call_deferred()


# ---------------------------------------------------------------- estado

func set_target(id: String) -> void:
	target_id = id
	# Al elegir un objetivo se despliegan todas sus acciones (taladro incluido), sin esconderlas tras la flecha.
	_open_actions = not id.is_empty()
	_list.visible = false
	if not snapshot.is_empty():
		update_snapshot(snapshot)


var _titulo_de_aterrizaje := -1  ## -1 aún sin poner, 0 título del juego, 1 título del aterrizaje
var _tono_energia := Color(0, 0, 0, 0)


func update_snapshot(s: Dictionary) -> void:
	snapshot = s
	if not is_instance_valid(root):
		return
	if _toast_key == "WAIT":
		_toast_key = ""
		_toast_until = 0.0
	var fase := str(s.get("phase", ""))
	var en_operacion := fase == "operations"
	var pausa := bool(s.get("paused", false))
	var seguro := bool(s.get("safe_mode", false))
	for c in _ops:
		c.visible = en_operacion
	_landing_text.visible = fase == "landing"
	# Los cambios de tema de un control rehacen su diseño: solo se tocan cuando cambia la fase de aterrizaje.
	var titulo_aterrizaje := fase == "landing"
	if titulo_aterrizaje:
		_title.text = tr("LANDING_TITLE")
	else:
		_title.text = "GAIA"
	if int(titulo_aterrizaje) != _titulo_de_aterrizaje:
		_titulo_de_aterrizaje = int(titulo_aterrizaje)
		if titulo_aterrizaje:
			_title.add_theme_font_override("font", UI.display_font(600, 0))
			_title.add_theme_font_size_override("font_size", 20)
		else:
			_title.add_theme_font_override("font", UI.display_font(700, 5))
			_title.add_theme_font_size_override("font_size", UI.FONT_TITLE)
	var objetivo: Dictionary = s.get("story", {}).get("objective", {})
	_objective.text = StoryPanel.text_of(objetivo) if not objetivo.is_empty() else tr("OBJECTIVE_SHORT")
	_fill_goals(s.get("story", {}).get("goals", []))
	var en_taller := fase == "workshop"
	_title.visible = fase == "landing"
	_mark.visible = not en_taller and fase != "landing"
	_summary_button.visible = not en_taller
	pause_button.visible = not en_taller
	_markers.visible = en_operacion
	pause_button.disabled = not en_operacion
	pause_button.get_meta("icon").kind = "play" if pausa else "pause"
	pause_button.tooltip_text = tr("RESUME") if pausa else tr("PAUSE")
	# Energía y ciencia (crema en reposo; ámbar con alerta si la batería está baja; coral en modo seguro).
	var bateria: Dictionary = s.get("battery", {})
	var capacidad := maxf(1.0, float(bateria.get("capacity", 1.0)))
	var porcentaje := roundi(float(bateria.get("wh", 0.0)) / capacidad * 100.0)
	var baja := _has_warning(s, "LOW_BATTERY") if s.has("warnings") else porcentaje <= 20
	var tono := UI.CORAL if seguro else (UI.AMBER if baja else UI.CREAM)
	_energy_text.text = tr("ENERGY_PILL") % porcentaje
	if tono != _tono_energia:
		_tono_energia = tono
		_energy_text.add_theme_color_override("font_color", tono)
	_energy_icon.level = porcentaje / 100.0
	_energy_icon.alert = baja or seguro
	_energy_icon.color = tono
	_science_text.text = tr("SCIENCE_PILL") % [int(s.get("sent", 0)), int(s.get("goal", 100))]
	_fit_top_right()
	# Sol y hora; la noche se anuncia una vez y luego queda con la luna.
	var hora := float(s.get("hour", 8.0))
	var noche := bool(s.get("is_night", hora < 6.0 or hora >= 18.0))
	var texto_hora := tr("SOL_SHORT") % [int(s.get("sol", 1)), int(hora), int(fmod(hora, 1.0) * 60.0)]
	_clock_text.text = texto_hora + ("  ·  " + tr("NIGHT_LABEL") if noche else "")
	_clock_icon.kind = "moon" if noche else "sun"
	if _night_known and noche and not _was_night and en_operacion:
		show_notice("NIGHT_NOTICE")
	_was_night = noche
	_night_known = true
	_update_warnings(s, en_operacion)
	_update_comms(s)
	var bloqueado := pausa or seguro or not en_operacion
	var disponibles: Dictionary = s.get("available_actions", {})
	for accion in GLOBAL_ACTIONS:
		var b: Button = buttons[accion]
		var d: Dictionary = disponibles.get(accion, {"enabled": false, "reason": "WAIT"})
		var motivo := str(d.get("reason", ""))
		b.visible = accion == "upgrade" or motivo != "NO_INSTRUMENT"
		b.disabled = bloqueado or not bool(d.get("enabled", false))
		b.tooltip_text = tr(motivo) if b.disabled and not motivo.is_empty() else _hotkey_hint(accion)
		if accion == "upgrade" and s.has("base"):
			var nivel := int(s.get("antenna_level", 0))
			var base: Dictionary = s["base"]
			if nivel >= int(base.get("antenna_max", 3)):
				b.text = tr("ANTENNA_MAX")
			else:
				b.text = tr("BUILD_ANTENNA") if nivel == 0 else tr("UPGRADE_ANTENNA") % (nivel + 1)
			var costo := BaseHud.cost_text(base.get("antenna_next_cost", {}))
			if not costo.is_empty():
				b.tooltip_text = (b.tooltip_text + "\n" if not b.tooltip_text.is_empty() else "") + tr("COST_LABEL") + ": " + costo
	var dt: Dictionary = disponibles.get("transmit", {"enabled": false, "reason": "WAIT"})
	buttons.transmit.disabled = bloqueado or not bool(dt.get("enabled", false))
	buttons.transmit.text = tr("STOP_SHORT") if s.get("transmitting", false) else tr("TRANSMIT_SHORT")
	buttons.transmit.tooltip_text = tr(str(dt.get("reason", ""))) if buttons.transmit.disabled else _hotkey_hint("transmit")
	_refresh_target(s, bloqueado)
	_update_info(s)
	_update_summary(s)
	_map.state = s
	_map.queue_redraw()
	_markers.targets = s.get("targets", [])
	_markers.selected = target_id
	# Pausa: atenuación y menú; la entrada del rover no atraviesa la pausa.
	var menu_abierto := pausa and en_operacion
	_dim.visible = menu_abierto or _free_options
	if _free_options and not menu_abierto:
		return
	if not menu_abierto:
		settings.visible = false
		help_view.visible = false
		_menu.visible = false
	elif not settings.visible and not help_view.visible:
		if not _menu.visible:
			_menu.visible = true
			_menu_resume.grab_focus.call_deferred()
		if _pending_help:
			_pending_help = false
			_open_sub(help_view)
	if not pausa:
		_pending_help = false


func _hotkey_hint(accion: String) -> String:
	return "%s  [%s]" % [tr(accion.to_upper()) if accion != "transmit" else tr("TRANSMIT_SHORT"), HOTKEY_TEXT[accion]] if HOTKEY_TEXT.has(accion) else ""


func _has_warning(s: Dictionary, id: String) -> bool:
	for aviso in s.get("warnings", []):
		if str(aviso.get("id", "")) == id:
			return true
	return false


func _warning_list(s: Dictionary) -> Array:
	if s.has("warnings"):
		return s["warnings"]
	# Proveedor de revisión de B (sin avisos): solo los estados evidentes.
	var lista := []
	if s.get("safe_mode", false):
		lista.append({"id": "SAFE_MODE", "severity": "critical", "key": "WARN_SAFE_MODE", "values": []})
	if s.get("storm", false):
		lista.append({"id": "STORM_ACTIVE", "severity": "warning", "key": "WARN_STORM_ACTIVE", "values": []})
	return lista


func _format(aviso: Dictionary) -> String:
	var valores = aviso.get("values", [])
	if str(aviso.get("key", "")) == "WARN_STORM_SOON" and valores is Array and not valores.is_empty():
		var horas := float(valores[0]) * 24.0
		if horas < 24.0:  # menos de un sol: se dice en horas, no «0.1 soles»
			return tr("WARN_STORM_SOON_H") % maxi(1, ceili(horas))
	var texto := tr(str(aviso.get("key", "")))
	if valores is Array and not valores.is_empty():
		texto = texto % valores
	return _decimal(texto)


## En español los decimales llevan coma.
func _decimal(texto: String) -> String:
	if not TranslationServer.get_locale().begins_with("es"):
		return texto
	var er := RegEx.new()
	er.compile("(\\d)\\.(\\d)")
	return er.sub(texto, "$1,$2", true)


func _update_warnings(s: Dictionary, en_operacion: bool) -> void:
	var criticos := []
	var avisos := []
	if en_operacion:
		for aviso in _warning_list(s):
			if str(aviso.get("severity", "")) == "critical":
				criticos.append(aviso)
			else:
				avisos.append(aviso)
	if criticos.is_empty():
		_fade(_crit_slot, false)
	else:
		_crit_text.text = _format(criticos[0])
		_fade(_crit_slot, true)
	if avisos.is_empty():
		_fade(_warn_slot, false)
		_warn_list.visible = false
	else:
		_warn_text.text = _format(avisos[0])
		_warn_more.visible = avisos.size() > 1
		_warn_more.text = tr("MORE_WARNINGS") % (avisos.size() - 1)
		_fade(_warn_slot, true)
		for hijo in _warn_list_box.get_children():
			hijo.queue_free()
		for aviso in avisos:
			var linea := UI.label(_warn_list_box, _format(aviso), UI.FONT_SECONDARY)
			linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			linea.custom_minimum_size.x = 360
		if avisos.size() < 2:
			_warn_list.visible = false


func _time_text(s: Dictionary, sol: int, hora: float) -> String:
	if sol == int(s.get("sol", 1)):
		return tr("COMMS_TIME") % [int(hora), int(fmod(hora, 1.0) * 60.0)]
	return tr("COMMS_TIME_SOL") % [sol, int(hora), int(fmod(hora, 1.0) * 60.0)]


func _update_comms(s: Dictionary) -> void:
	var diseno: Dictionary = s.get("design", {})
	var tipo := tr("COMMS_DIRECT") if str(diseno.get("comms", "relay")) == "direct" else tr("COMMS_RELAY")
	var abierto := bool(s.get("link_open", false))
	var siguiente := ""
	var corto := ""
	var proximo: Dictionary = s.get("link_next", {})
	if not proximo.is_empty():
		var hora_cambio := float(proximo.get("hour", 0.0))
		var cuando := _time_text(s, int(proximo.get("sol", s.get("sol", 1))), hora_cambio)
		var verbo := tr("COMMS_OPENS") if proximo.get("opens", true) else tr("COMMS_CLOSES")
		siguiente = verbo % cuando
		corto = verbo % (tr("COMMS_TIME") % [int(hora_cambio), int(fmod(hora_cambio, 1.0) * 60.0)])
	_comms_icon.visible = abierto
	var estado := tr("COMMS_OPEN_NOW") if abierto else corto
	_comms_title.text = tipo + ("  ·  " + estado if not estado.is_empty() else "")
	var disp: Dictionary = s.get("available_actions", {}).get("transmit", {})
	var motivo := str(disp.get("reason", ""))
	if abierto and not bool(disp.get("enabled", true)) and not motivo.is_empty():
		_comms_detail.text = tr(motivo)
		_comms_detail.tooltip_text = tr(motivo)
		_comms_detail.add_theme_color_override("font_color", UI.AMBER)
	else:
		_comms_detail.text = siguiente if abierto else tr(motivo) if not motivo.is_empty() else siguiente
		_comms_detail.add_theme_color_override("font_color", Color(UI.CREAM, 0.85))
	_comms_wants = abierto or bool(s.get("transmitting", false)) or _has_warning(s, "LINK_OPENING_SOON")


func _set_comms_expanded(on: bool) -> void:
	_comms_expanded = on
	if _comms_tween != null and _comms_tween.is_valid():
		_comms_tween.kill()
	_comms_tween = create_tween()
	if on:
		_comms_tween.tween_property(_comms, "custom_minimum_size", Vector2(336, 72), 0.18)
		_comms_tween.tween_callback(func(): _comms_row.visible = _comms_expanded)
	else:
		_comms_row.visible = false
		_comms_tween.tween_property(_comms, "custom_minimum_size", Vector2(166, 32), 0.18)
		_comms_tween.tween_callback(func(): _comms.size = _comms.get_combined_minimum_size(); _comms.reset_size())


func _target() -> Dictionary:
	if target_id.is_empty():
		return {}
	for t in snapshot.get("targets", []):
		if str(t.get("id", "")) == target_id:
			return t
	return {}


func _refresh_target(s: Dictionary, bloqueado: bool) -> void:
	var t := _target()
	var disponibles: Dictionary = s.get("available_actions", {})
	var acercar: Dictionary = disponibles.get("approach", {"enabled": false, "reason": "NO_TARGET"})
	var acciones: Array = []
	if not t.is_empty() and t.get("revealed", false):
		if t.has("actions"):
			acciones = t["actions"]
		else:
			for id in ["spectrometer", "drill"]:
				var d: Dictionary = disponibles.get(id, {"enabled": false, "reason": "WAIT"})
				acciones.append({"id": id, "enabled": d.get("enabled", false), "reason": d.get("reason", "")})
	var visibles := {}
	var lejos := false
	for entrada in acciones:
		var id := str(entrada.get("id", ""))
		var fila := _row(id)
		var motivo := str(entrada.get("reason", ""))
		_set_row(fila, bloqueado or not bool(entrada.get("enabled", false)), motivo)
		visibles[id] = true
		if motivo == "TOO_FAR":
			lejos = true
	var motivo_acercar := str(acercar.get("reason", ""))
	_set_row(_rows["approach"], bloqueado or t.is_empty() or not bool(acercar.get("enabled", false)), motivo_acercar)
	if not t.is_empty() and (bool(acercar.get("enabled", false)) or lejos) and motivo_acercar != "ALREADY_NEAR":
		visibles["approach"] = true
	for id in _rows:
		_rows[id].visible = visibles.has(id)
		if t.is_empty():
			_rows[id].disabled = true
			_rows[id].tooltip_text = tr("NO_TARGET")
	# Acción principal: la que indica la simulación; si el rover está lejos, «Acercar».
	_target_shown = not t.is_empty() and t.get("revealed", false) and str(s.get("phase", "")) == "operations"
	if not _target_shown:
		_label_box.visible = false
		_list.visible = false
		_markers.label_rect = Rect2()
		return
	var principal := str(t.get("primary", ""))
	if principal.is_empty() and not acciones.is_empty():
		principal = str(acciones[0].get("id", ""))
	if lejos or principal.is_empty():
		principal = "approach"
	_primary_action = principal
	if _open_actions:
		_open_actions = false
		for otro in [_info, _summary, _warn_list]:
			otro.visible = false
		_list.visible = true
	var fila_principal: Button = _rows.get(principal, _rows["approach"])
	_primary.text = tr("ACT_APPROACH") if principal == "approach" else tr(principal.to_upper())
	_primary.disabled = fila_principal.disabled
	_primary.tooltip_text = fila_principal.tooltip_text


func _set_row(fila: Button, deshabilitada: bool, motivo: String) -> void:
	fila.disabled = deshabilitada
	var etiqueta: Label = fila.get_meta("reason")
	var mostrar := deshabilitada and not motivo.is_empty()
	etiqueta.text = tr(motivo) if mostrar else ""
	etiqueta.visible = mostrar
	fila.theme_type_variation = "RowButtonReason" if mostrar else "RowButton"
	fila.tooltip_text = tr(motivo) if mostrar else ""


func _update_info(s: Dictionary) -> void:
	var bateria: Dictionary = s.get("battery", {})
	var diseno: Dictionary = s.get("design", {})
	_info_values["INFO_STORED"].text = "%d / %d" % [int(s.get("data", 0)), int(s.get("memory_capacity", 60))]
	_info_values["INFO_BATTERY"].text = "%d / %d Wh" % [int(bateria.get("wh", 0)), int(bateria.get("capacity", 0))]
	_info_values["INFO_GENERATION"].text = "%d W" % int(bateria.get("generation_w", 0))
	_info_values["INFO_LOAD"].text = "%d W" % int(bateria.get("load_w", 0))
	_info_values["INFO_POWER"].text = tr("POWER_RTG") if str(diseno.get("power", "solar")) == "rtg" else tr("POWER_SOLAR")
	_info_values["INFO_MINERALS"].text = str(int(s.get("mineral", 0)))
	_info_values["INFO_ANTENNA"].text = tr("LEVEL_FMT") % int(s.get("antenna_level", 1))
	var tipo := tr("COMMS_DIRECT") if str(diseno.get("comms", "relay")) == "direct" else tr("COMMS_RELAY")
	_info_values["INFO_LINK"].text = tipo + " · " + (tr("COMMS_OPEN_NOW") if s.get("link_open", false) else "—")
	_info_values["INFO_DUST"].text = "%d %%" % int(float(s.get("dust", 0.0)) * 100.0)
	var tormenta := tr("STORM_NONE")
	if s.get("storm", false):
		tormenta = tr("STORM_ACTIVE_SHORT")
	elif float(s.get("storm_in", -1.0)) > 0.0:
		tormenta = _decimal(tr("STORM_IN") % float(s.get("storm_in", 0.0)))
	_info_values["INFO_STORM"].text = tormenta


func _update_summary(s: Dictionary) -> void:
	var meta := int(s.get("goal", 100))
	var enviado := int(s.get("sent", 0))
	var limite := int(s.get("sol_limit", 6))
	_summary_labels["mission"].text = tr(str(s.get("chapter_title_key", "MISSION")))
	_summary_labels["brief"].text = tr(str(s.get("brief_key", "BRIEF")))
	_summary_labels["goal"].text = tr("SUMMARY_GOAL") % meta
	_summary_bar.max_value = maxf(1.0, meta)
	_summary_bar.value = enviado
	_summary_labels["progress"].text = tr("SUMMARY_PROGRESS") % [enviado, meta]
	_summary_labels["deadline"].text = tr("SUMMARY_DEADLINE") % [limite, int(s.get("sol", 1))]
	_summary_labels["safe"].text = ("✓  " if int(s.get("safe_entries", 0)) == 0 else "✗  ") + tr("NO_SAFE")
	_summary_labels["early"].text = ("✓  " if int(s.get("sol", 1)) < limite else "·  ") + tr("EARLY")


# ---------------------------------------------------------------- avisos breves, acciones, ayuda

func show_notice(key: String) -> void:
	if not is_instance_valid(_toast_text):
		return
	_toast_key = key
	_toast_text.text = tr(key)
	_toast_until = Time.get_ticks_msec() / 1000.0 + 3.5
	_fade(_toast, true)


func start_action(a: Dictionary) -> void:
	_active_seconds = 0.0
	_active_total = maxf(0.1, float(a.get("seconds", 1.0)))
	if is_instance_valid(_progress):
		_progress.visible = true
		_progress.value = 0


func show_help() -> void:
	if snapshot.get("paused", false):
		_open_sub(help_view)
	elif not pause_button.disabled:
		_pending_help = true
		emit_command("pause", {"paused": true})
	else:
		show_notice("HELP_TEXT")


## Pista junto al cursor (destino fuera del área o bloqueado). Texto vacío la oculta.
func set_hover_hint(texto: String, pos: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(_hover_hint):
		return
	_hover_hint.visible = not texto.is_empty()
	if _hover_hint.visible:
		_hover_label.text = texto
		_hover_hint.reset_size()
		var pantalla := root.size
		_hover_hint.position = Vector2(minf(pos.x + 16, pantalla.x - _hover_hint.size.x - 8), minf(pos.y + 14, pantalla.y - _hover_hint.size.y - 8))


func _project(id: String) -> Dictionary:
	var vista := get_parent()
	if vista != null and vista.has_method("project_target"):
		return vista.project_target(id)
	return {}


## Coloca la etiqueta contextual cerca del objetivo, fuera de las zonas reservadas del HUD, y la lista hacia el espacio libre.
func _place_target_ui() -> void:
	if not _target_shown:
		return
	var datos := _project(target_id)
	var pantalla := root.size
	var dentro: bool = not datos.is_empty() and not datos.get("behind", false) \
		and Rect2(Vector2.ZERO, pantalla).grow(-30).has_point(datos.get("pos", Vector2.ZERO))
	_label_box.visible = dentro
	if not dentro:
		_list.visible = false
		_markers.label_rect = Rect2()
		return
	var p: Vector2 = datos["pos"]
	var pos := p + Vector2(26, -62)
	if pos.x + LABEL_SIZE.x > pantalla.x - 20:
		pos.x = p.x - 26 - LABEL_SIZE.x
	pos.x = clampf(pos.x, 20, pantalla.x - 20 - LABEL_SIZE.x)
	pos.y = clampf(pos.y, 132, pantalla.y - 120 - LABEL_SIZE.y)
	_label_box.position = pos
	_label_box.size = LABEL_SIZE
	_markers.label_rect = Rect2(pos, LABEL_SIZE)
	if _list.visible:
		_list.reset_size()
		var alto := minf(_list.get_combined_minimum_size().y, 320.0)
		var lpos := Vector2(pos.x, pos.y + LABEL_SIZE.y + 6)
		if lpos.y + alto > pantalla.y - 70:
			lpos.y = pos.y - 6 - alto
		lpos.x = clampf(lpos.x, 20, pantalla.x - 20 - 240)
		_list.position = lpos


func _process(delta: float) -> void:
	if not is_instance_valid(root):
		return
	if _toast.visible and Time.get_ticks_msec() / 1000.0 > _toast_until:
		_fade(_toast, false)
	if _progress.visible:
		if not snapshot.get("paused", false):
			_active_seconds += delta
		_progress.value = clampf(_active_seconds / maxf(0.1, _active_total) * 100.0, 0, 100)
		if _active_seconds >= _active_total + 0.2:
			_progress.visible = false
	_place_target_ui()
	_layout_actions()
	var querer := _comms_wants or _comms_hover
	if querer != _comms_expanded and _comms.visible:
		_set_comms_expanded(querer)
	if _debug.visible:
		_debug.text = "%s%d FPS · %d draw · %.1fk tris" % [tr("INSPECTION") + " · " if inspection else "", Engine.get_frames_per_second(),
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000.0]
	var vista := get_parent()
	if vista != null and vista.get("rig") != null and vista.has_method("blocked"):
		vista.rig.enabled = not vista.blocked() and not settings.visible and not review_panel.visible


## Fila de acciones: centrada abajo, pero nunca bajo el panel de comunicación ni sobre el reloj.
func _layout_actions() -> void:
	if not is_instance_valid(_actions_row) or not _actions_row.visible:
		return
	var ancho_vista := root.size.x
	var ancho := maxf(_actions_row.get_combined_minimum_size().x, 1.0)
	var comms_izq := ancho_vista - 20.0 - (_comms.size.x if _comms.visible else 0.0)
	var izq := ancho_vista * 0.5 - ancho * 0.5
	izq = minf(izq, comms_izq - 16.0 - ancho)
	izq = maxf(izq, 180.0)
	_actions_row.offset_left = izq
	_actions_row.offset_right = izq + ancho


func _input(e: InputEvent) -> void:
	# Un clic fuera de un panel a demanda lo cierra (y no atraviesa al mundo).
	if not (e is InputEventMouseButton and e.pressed) or not is_instance_valid(root):
		return
	var cerrado := false
	for par in [[_info, [_energy_pill, _science_pill]], [_summary, [_summary_button]], [_warn_list, [_warn_more]], [_list, [_arrow]]]:
		var panel: Control = par[0]
		if not panel.visible or panel.get_global_rect().has_point(e.position):
			continue
		var en_boton := false
		for b in par[1]:
			if b.visible and b.get_global_rect().has_point(e.position):
				en_boton = true
		if not en_boton:
			panel.visible = false
			cerrado = true
	if cerrado and _label_box.visible and _label_box.get_global_rect().has_point(e.position):
		cerrado = false
	if cerrado:
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var tecla: int = e.physical_keycode
	if tecla == KEY_ESCAPE:
		if settings.visible or help_view.visible:
			_close_sub()
		elif review_panel.visible:
			review_panel.hide()
		elif _close_popups():
			pass
		elif bool(snapshot.get("moving", false)) and str(snapshot.get("phase", "")) == "operations" and not bool(snapshot.get("paused", false)):
			command.emit("stop", {})  # Esc con el rover en marcha: se detiene en la casilla que está pisando
		elif not pause_button.disabled:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif tecla == KEY_F2 and inspection:
		review_panel.visible = not review_panel.visible
		get_viewport().set_input_as_handled()
	elif tecla == KEY_F3 or tecla == KEY_P:  # P: alternativa para teclados donde F3 exige Fn o lo captura el editor/navegador
		_debug.visible = not _debug.visible
		get_viewport().set_input_as_handled()
	elif tecla == KEY_F1 or tecla == KEY_H:
		show_help()
		get_viewport().set_input_as_handled()
	elif HOTKEYS.has(tecla) and not settings.visible and not review_panel.visible and not snapshot.get("paused", false):
		var b: Button = buttons.get(HOTKEYS[tecla])
		if b != null and not b.disabled:
			b.pressed.emit()
		get_viewport().set_input_as_handled()


## Metas del objetivo: círculo vacío o con visto, texto y avance. Solo guía: lo que abre cada evento lo decide la historia.
func _fill_goals(metas: Array) -> void:
	var firma := var_to_str([metas, TranslationServer.get_locale()])
	if firma == _goals_sig:
		return
	_goals_sig = firma
	for hijo in _goals.get_children():
		_goals.remove_child(hijo)
		hijo.queue_free()
	if metas.is_empty():
		return
	var titulo := UI.label(_goals, tr("GOALS_TITLE"), 11, Color(UI.AMBER, 0.85))
	UI.display(titulo, 700, 3)
	for meta in metas:
		var hecha := bool(meta.get("done", false))
		var tono := UI.TEAL if hecha else Color(UI.CREAM, 0.9)
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 6)
		fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_goals.add_child(fila)
		fila.add_child(Icon.make("check" if hecha else "goal", 13, tono))
		var texto := UI.label(fila, goal_text(meta), 13, tono)
		texto.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Texto de una meta (kind, id, cur, goal): «Antena Nv. 2», «Rocas: 12 / 30», «Batería al 70 %: 45 %»...
static func goal_text(meta: Dictionary) -> String:
	var meta_valor := roundi(float(meta.get("goal", 0)))
	var actual := roundi(float(meta.get("cur", 0)))
	var id := str(meta.get("id", ""))
	match str(meta.get("kind", "")):
		"antena":
			return TranslationServer.translate("GOAL_ANTENNA") % meta_valor
		"edificio":
			return TranslationServer.translate("GOAL_BUILD") % TranslationServer.translate("BLD_" + BaseHud._clave(id))
		"recurso":
			return "%s: %d / %d" % [TranslationServer.translate("RES_" + id.to_upper()), actual, meta_valor]
		"enviados_pct":
			return TranslationServer.translate("GOAL_SENT") % meta_valor + ": %d %%" % actual
		"sol":
			return TranslationServer.translate("GOAL_SOL") % meta_valor
		"bateria_pct":
			return TranslationServer.translate("GOAL_BATTERY") % meta_valor + ": %d %%" % actual
		"rocky_hp":
			return TranslationServer.translate("GOAL_ROCKY") % meta_valor + ": %d %%" % actual
		"modulos":
			return TranslationServer.translate("GOAL_MODULES") % [TranslationServer.translate("BLD_" + BaseHud._clave(id)), actual, meta_valor]
	return ""
