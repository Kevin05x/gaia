extends CanvasLayer
## Cartel del tutorial del Sol 1: una tarjeta pequeña arriba a la derecha con el paso actual y un botón para saltarlo, y un
## halo que pulsa alrededor de la parte de la pantalla que señala el paso. No bloquea el juego. Solo presenta: los pasos,
## cuándo se cumplen y el orden de saltar los decide la simulación (content/tutorial.json, TutorialSystem).
const UI := preload("res://scenes/b/ui_style.gd")
const Story := preload("res://scenes/b/story_panel.gd")
const ANCHO := 310.0

signal command(command: String, payload: Dictionary)
signal step_changed  ## un paso se completó: la vista hace sonar un aviso

var root: Control
var target_for: Callable  ## «resalta» -> Control al que apunta el halo (lo asigna la vista; puede devolver null)
var shown_id := ""  ## paso que se ve ("" si no hay cartel)
var _card: PanelContainer
var _title: Label
var _text: Label
var _skip: Button
var _halo: Panel
var _highlight := ""
var _clock := 0.0
var _hidden := false  ## la vista lo oculta mientras hay una escena, la pausa o el informe


func _ready() -> void:
	layer = 7
	root = Control.new()
	root.name = "TutorialRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_halo = Panel.new()
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var contorno := UI.box(0.0, UI.RADIUS_PILL, 0.0, 0)
	contorno.bg_color = Color(UI.AMBER, 0.08)
	contorno.set_border_width_all(3)
	contorno.border_color = UI.AMBER
	_halo.add_theme_stylebox_override("panel", contorno)
	_halo.visible = false
	root.add_child(_halo)
	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.add_theme_stylebox_override("panel", UI.box(0.86, UI.RADIUS_PANEL, 0.4, 1, 14, 12, UI.AMBER))
	UI.place(_card, "tr", 20, 108, ANCHO, 80)
	_card.visible = false
	root.add_child(_card)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	_card.add_child(caja)
	_title = UI.label(caja, "", 12, UI.AMBER)
	UI.display(_title, 700, 2)
	_text = UI.label(caja, "", 14, UI.CREAM)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(ANCHO - 28.0, 0)
	_skip = Button.new()
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip.add_theme_font_size_override("font_size", 12)
	_skip.add_theme_color_override("font_color", Color(UI.CREAM, 0.7))
	_skip.add_theme_color_override("font_hover_color", UI.AMBER)
	_skip.pressed.connect(func() -> void: command.emit("tutorial_skip", {}))
	caja.add_child(_skip)


func set_hidden(valor: bool) -> void:
	_hidden = valor
	_aplicar_visibilidad()


func is_showing() -> bool:
	return is_instance_valid(_card) and _card.visible


func update_snapshot(s: Dictionary) -> void:
	var t: Dictionary = s.get("tutorial", {})
	var activo: bool = t.get("active", false) and s.get("phase", "") == "operations"
	if not activo:
		shown_id = ""
		_highlight = ""
		_aplicar_visibilidad()
		return
	var id := str(t.get("id", ""))
	if id != shown_id:
		var primero := shown_id.is_empty()
		shown_id = id
		if not primero:
			step_changed.emit()
		_flash()
	_title.text = tr("TUTORIAL_TITLE") % [int(t.get("step", 1)), int(t.get("total", 1))]
	_text.text = Story.text_of(t.get("text", {}))
	_skip.text = tr("TUTORIAL_SKIP")
	_highlight = str(t.get("highlight", ""))
	_aplicar_visibilidad()


func _aplicar_visibilidad() -> void:
	if not is_instance_valid(_card):
		return
	var ver := not shown_id.is_empty() and not _hidden
	_card.visible = ver
	if not ver:
		_halo.visible = false


## Destello al cambiar de paso: la tarjeta entra desde transparente.
func _flash() -> void:
	if not is_instance_valid(_card):
		return
	_card.modulate = Color(1.5, 1.4, 1.1, 0.0)
	var tween := create_tween()
	tween.tween_property(_card, "modulate", Color.WHITE, 0.45)


func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_halo):
		return
	var destino: Control = target_for.call(_highlight) if target_for.is_valid() and not _highlight.is_empty() else null
	if not _card.visible or destino == null or not is_instance_valid(destino) or not destino.is_visible_in_tree():
		_halo.visible = false
		return
	var caja := destino.get_global_rect().grow(6.0)
	_halo.visible = true
	_halo.position = caja.position
	_halo.size = caja.size
	_halo.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_clock * 4.0))
