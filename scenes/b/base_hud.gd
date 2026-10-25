extends CanvasLayer
## Base en el HUD: recursos (rocas, olivino, hielo y xenolito con su capacidad), ética y vida de Rocky arriba a la
## derecha, y el botón «Construir» con su menú: edificios con costo, energía, tiempo y motivo si no se puede, más la
## lista de edificios terminados para encenderlos o apagarlos. Elegir un edificio pide a la vista que entre en modo
## de colocación (signal placement_requested). No decide reglas: todo llega en el snapshot.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")

signal command(command: String, payload: Dictionary)
signal placement_requested(building: String)

const RECURSOS: Array[String] = ["rocas", "olivino", "hielo", "xenolito"]
const COLORES := {"rocas": Color("C9A27E"), "olivino": Color("8DB06A"), "hielo": Color("A8DCEB"), "xenolito": Color("B98AE0")}

var root: Control
var snapshot: Dictionary = {}
var menu: PanelContainer
var build_button: Button
var _bar: HBoxContainer
var _chips: Dictionary = {}
var _ethics: Label
var _rocky: Label
var _rocky_chip: PanelContainer
var _menu_box: VBoxContainer
var _menu_signature := ""


func _ready() -> void:
	layer = 6
	build()


static func cost_text(costo: Dictionary) -> String:
	var partes: Array[String] = []
	for r in RECURSOS:
		if costo.has(r) and int(costo[r]) > 0:
			partes.append("%d %s" % [int(costo[r]), TranslationServer.translate("RES_" + r.to_upper()).to_lower()])
	return ", ".join(partes)


func build() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	_chips.clear()
	_menu_signature = ""
	root = Control.new()
	root.name = "BaseRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	_bar = HBoxContainer.new()
	_bar.alignment = BoxContainer.ALIGNMENT_END
	_bar.add_theme_constant_override("separation", 6)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_bar, "tr", 20, 60, 560, 28)
	root.add_child(_bar)
	for r in RECURSOS:
		var chip := _chip(_bar, Icon.make("ore", 12, COLORES[r]))
		_chips[r] = chip
	var etica_chip := _chip(_bar, Icon.make("scale", 13, UI.CREAM))
	_ethics = etica_chip.get_meta("text")
	etica_chip.tooltip_text = tr("ETHICS_TIP")
	_rocky_chip = _chip(_bar, Icon.make("heart", 13, UI.TEAL))
	_rocky = _rocky_chip.get_meta("text")
	_rocky_chip.tooltip_text = tr("ROCKY_TIP")
	build_button = Button.new()
	build_button.theme_type_variation = "PillButton"
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.text = tr("BUILD") + "  [B]"
	build_button.icon = null
	build_button.custom_minimum_size = Vector2(0, 36)
	build_button.add_theme_font_size_override("font_size", 14)
	UI.place(build_button, "bl", 20, 64, 150, 36)
	root.add_child(build_button)
	build_button.pressed.connect(toggle_menu)
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", UI.box(0.88, UI.RADIUS_PANEL, 0.3, 1, 16, 14))
	UI.place(menu, "bl", 20, 110, 420, 360)
	menu.visible = false
	root.add_child(menu)
	var desplazable := ScrollContainer.new()
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(desplazable)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 6)
	_menu_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(_menu_box)
	if not snapshot.is_empty():
		update_snapshot(snapshot)


func _chip(padre: Control, icono: Control) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_NORMAL, UI.RADIUS_PILL, 0.2, 1, 10, 3))
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	padre.add_child(chip)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(fila)
	fila.add_child(icono)
	var texto := UI.label(fila, "0", 13, UI.CREAM)
	texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.set_meta("text", texto)
	return chip


func toggle_menu() -> void:
	menu.visible = not menu.visible and _usable()
	if menu.visible:
		_menu_signature = ""
		_fill_menu()


func close_menu() -> void:
	if is_instance_valid(menu):
		menu.visible = false


func _usable() -> bool:
	return snapshot.has("resources") and snapshot.get("phase", "") == "operations"


func update_snapshot(s: Dictionary) -> void:
	snapshot = s
	if not is_instance_valid(root):
		return
	var visible_base := _usable()
	_bar.visible = visible_base
	build_button.visible = visible_base
	if not visible_base:
		menu.visible = false
		return
	var recursos: Dictionary = s.get("resources", {})
	var tope := int(s.get("resource_capacity", 0))
	for r in RECURSOS:
		var chip: PanelContainer = _chips[r]
		var cantidad := int(recursos.get(r, 0))
		var texto: Label = chip.get_meta("text")
		texto.text = str(cantidad)
		texto.add_theme_color_override("font_color", UI.AMBER if cantidad >= tope else UI.CREAM)
		chip.tooltip_text = "%s  %d / %d" % [tr("RES_" + r.to_upper()), cantidad, tope]
	var historia: Dictionary = s.get("story", {})
	_ethics.get_parent().get_parent().visible = not historia.is_empty()
	_ethics.text = str(roundi(float(historia.get("ethics", 50.0))))
	var con_rocky := bool(s.get("design", {}).get("companion", false)) and not historia.is_empty()
	_rocky_chip.visible = con_rocky
	var vida := roundi(float(historia.get("rocky_hp", 100.0)))
	_rocky.text = "%d%%" % vida
	_rocky.add_theme_color_override("font_color", UI.CORAL if vida <= 30 else UI.CREAM)
	var bloqueado := bool(s.get("paused", false)) or bool(s.get("safe_mode", false))
	build_button.disabled = bloqueado
	if menu.visible:
		_fill_menu()


func _fill_menu() -> void:
	var opciones: Array = snapshot.get("build_options", [])
	var edificios: Array = snapshot.get("buildings", [])
	var firma := var_to_str([opciones, edificios, snapshot.get("resources", {}), TranslationServer.get_locale()])
	if firma == _menu_signature:
		return
	_menu_signature = firma
	for hijo in _menu_box.get_children():
		_menu_box.remove_child(hijo)
		hijo.queue_free()
	var titulo := UI.label(_menu_box, tr("BUILD_TITLE"), UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(titulo, 700, 2)
	UI.label(_menu_box, tr("BUILD_HINT"), 12, Color(UI.CREAM, 0.7)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for op in opciones:
		var b := Button.new()
		b.theme_type_variation = "RowButton"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(380, 0)
		b.add_theme_font_size_override("font_size", 14)
		var potencia := float(op.get("power_w", 0.0))
		var energia := ("+%d W" % roundi(potencia)) if potencia > 0.0 else ("−%d W" % roundi(-potencia) if potencia < 0.0 else "0 W")
		var maximo := int(op.get("max", -1))
		var cuenta := "  ·  %d/%d" % [int(op.get("count", 0)), maximo] if maximo >= 0 else ""
		var linea2 := "%s  ·  %s  ·  %d s%s" % [cost_text(op.get("cost", {})), energia, roundi(float(op.get("seconds", 0))), cuenta]
		var habilitado := bool(op.get("enabled", false))
		if not habilitado:
			linea2 += "\n— " + tr(str(op.get("reason", "")))
		b.text = tr(str(op.get("name_key", ""))) + "\n" + linea2
		b.disabled = not habilitado
		var tipo := str(op.get("id", ""))
		b.pressed.connect(func() -> void:
			menu.visible = false
			placement_requested.emit(tipo))
		_menu_box.add_child(b)
	var hechos: Array = []
	for e in edificios:
		if str(e.get("type", "")) != "antena" and int(e.get("level", 0)) >= 1:
			hechos.append(e)
	if hechos.is_empty():
		return
	_menu_box.add_child(HSeparator.new())
	UI.label(_menu_box, tr("BUILT_LIST"), 12, UI.AMBER)
	for e in hechos:
		var interruptor := CheckButton.new()
		interruptor.text = tr("BLD_" + _clave(str(e["type"])))
		interruptor.button_pressed = bool(e.get("active", true))
		interruptor.focus_mode = Control.FOCUS_NONE
		var id := str(e["id"])
		interruptor.toggled.connect(func(on: bool) -> void: command.emit("toggle_building", {"id": id, "on": on}))
		_menu_box.add_child(interruptor)


## Tipo de edificio -> sufijo de su clave de texto (BLD_SOLAR...).
static func _clave(tipo: String) -> String:
	return {"panel_solar": "SOLAR", "luz": "LIGHT", "domo": "DOME", "extractor_hielo": "EXTRACTOR", "hangar": "HANGAR",
		"antena": "ANTENNA"}.get(tipo, tipo.to_upper())


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_B and _usable():
		if not bool(snapshot.get("paused", false)) and snapshot.get("story", {}).get("pending", {}).is_empty():
			toggle_menu()
			get_viewport().set_input_as_handled()
