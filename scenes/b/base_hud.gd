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
var _rover: Label
var _rover_chip: PanelContainer
var _menu_box: VBoxContainer
var _menu_signature := ""
var _filas: Dictionary = {}  ## tipo -> controles de su fila en el menú
var _interruptores: Dictionary = {}  ## id -> CheckButton de encendido
var _modulos: Dictionary = {}  ## id -> controles del siguiente módulo
var _ficha: PanelContainer  ## ficha informativa del edificio (se crea al abrirla)
static var _fotos: Dictionary = {}  ## tipo -> Texture2D (o null)


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
	_ficha = null
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
	_rover_chip = _chip(_bar, Icon.make("chassis", 13, UI.AMBER))
	_rover = _rover_chip.get_meta("text")
	_rover_chip.tooltip_text = tr("ROVER_HP_TIP")
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
	if not menu.visible:
		cerrar_ficha()
	if menu.visible:
		_menu_signature = ""
		_fill_menu()


func close_menu() -> void:
	if is_instance_valid(menu):
		menu.visible = false
	cerrar_ficha()


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
		cerrar_ficha()
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
	var con_combate := s.has("combat")
	_rover_chip.visible = con_combate
	if con_combate:
		var vida_rover := roundi(float(s.get("rover_hp", 100.0)))
		_rover.text = "%d%%" % vida_rover
		_rover.add_theme_color_override("font_color", UI.CORAL if vida_rover <= 40 else UI.CREAM)
	var bloqueado := bool(s.get("paused", false)) or bool(s.get("safe_mode", false))
	build_button.disabled = bloqueado
	if menu.visible:
		_fill_menu()


## Rendimiento: la lista solo se rehace si cambia su forma (qué edificios hay, el idioma); si solo cambian recursos,
## avances o motivos, se actualizan los textos de cada fila. Antes se rehacía entera en cada extracción.
func _fill_menu() -> void:
	var opciones: Array = snapshot.get("build_options", [])
	var edificios: Array = snapshot.get("buildings", [])
	var forma: Array = [TranslationServer.get_locale()]
	for op in opciones:
		forma.append(str(op.get("id", "")))
	for e in edificios:
		forma.append([str(e.get("id", "")), str(e.get("type", "")), int(e.get("level", 0)) >= 1, int(e.get("modules", 0)),
			e.get("next_module", {}).is_empty()])
	var firma := var_to_str(forma)
	if firma != _menu_signature:
		_menu_signature = firma
		_rehacer_menu(opciones, edificios)
	for op in opciones:
		var id := str(op.get("id", ""))
		if _filas.has(id):
			_fijar_fila(_filas[id], op)
	for e in edificios:
		var id := str(e.get("id", ""))
		if _interruptores.has(id):
			(_interruptores[id] as CheckButton).set_pressed_no_signal(bool(e.get("active", true)))
		if _modulos.has(id):
			_fijar_modulo(_modulos[id], e)
	if is_instance_valid(_ficha) and _ficha.visible:
		var tipo := str(_ficha.get_meta("tipo", ""))
		for op in opciones:
			if str(op.get("id", "")) == tipo:
				_llenar_ficha(op)


func _rehacer_menu(opciones: Array, edificios: Array) -> void:
	_filas.clear()
	_interruptores.clear()
	_modulos.clear()
	for hijo in _menu_box.get_children():
		_menu_box.remove_child(hijo)
		hijo.queue_free()
	var titulo := UI.label(_menu_box, tr("BUILD_TITLE"), UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(titulo, 700, 2)
	UI.label(_menu_box, tr("BUILD_HINT"), 12, Color(UI.CREAM, 0.7)).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for op in opciones:
		var tipo := str(op.get("id", ""))
		_filas[tipo] = _crear_fila(tipo)
	for e in edificios:
		if int(e.get("modules", 0)) > 0 and int(e.get("level", 0)) >= 1:
			_fill_modules(e)
	var hechos: Array = []
	for e in edificios:
		if str(e.get("type", "")) != "antena" and int(e.get("level", 0)) >= 1 and int(e.get("modules", 0)) == 0:
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
		_interruptores[id] = interruptor


## Fila del menú: foto del edificio, nombre, costo · energía · tiempo, motivo si no se puede y botón «i» de su ficha.
func _crear_fila(tipo: String) -> Dictionary:
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 66)
	b.pressed.connect(func() -> void:
		menu.visible = false
		cerrar_ficha()
		placement_requested.emit(tipo))
	_menu_box.add_child(b)
	var fila := HBoxContainer.new()
	fila.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fila.offset_left = 6
	fila.offset_right = -6
	fila.add_theme_constant_override("separation", 10)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(fila)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UI.box(0.35, UI.RADIUS_LABEL, 0.18, 1, 2, 2))
	marco.custom_minimum_size = Vector2(56, 56)
	marco.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(marco)
	var foto := TextureRect.new()
	foto.texture = foto_de(tipo)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	foto.custom_minimum_size = Vector2(52, 52)
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marco.add_child(foto)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.alignment = BoxContainer.ALIGNMENT_CENTER
	textos.add_theme_constant_override("separation", 1)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(textos)
	var nombre := UI.label(textos, tr("BLD_" + _clave(tipo)), 14, UI.CREAM)
	UI.display(nombre, 600)
	var linea := UI.label(textos, "", 12, Color(UI.CREAM, 0.78))
	var motivo := UI.label(textos, "", 11, UI.WARN)
	motivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var info := Button.new()
	info.flat = true
	info.focus_mode = Control.FOCUS_NONE
	info.tooltip_text = tr("INFO_TIP")
	info.custom_minimum_size = Vector2(30, 30)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_STOP
	var icono := Icon.make("info", 18, UI.AMBER)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	info.add_child(icono)
	info.pressed.connect(func() -> void: abrir_ficha(tipo))
	fila.add_child(info)
	return {"button": b, "photo": foto, "name": nombre, "line": linea, "reason": motivo, "info": info}


func _fijar_fila(f: Dictionary, op: Dictionary) -> void:
	var maximo := int(op.get("max", -1))
	var cuenta := "  ·  %d/%d" % [int(op.get("count", 0)), maximo] if maximo >= 0 else ""
	(f["line"] as Label).text = "%s  ·  %s  ·  %d s%s" % [_costo(op.get("cost", {})), _energia(float(op.get("power_w", 0.0))),
		roundi(float(op.get("seconds", 0))), cuenta]
	var habilitado := bool(op.get("enabled", false))
	var motivo: Label = f["reason"]
	motivo.text = "" if habilitado else tr(str(op.get("reason", "")))
	motivo.visible = not habilitado
	(f["button"] as Button).disabled = not habilitado
	(f["button"] as Button).custom_minimum_size.y = 66 if habilitado else 80
	(f["photo"] as TextureRect).modulate = Color.WHITE if habilitado else Color(1, 1, 1, 0.45)
	(f["name"] as Label).modulate = Color.WHITE if habilitado else Color(1, 1, 1, 0.6)


static func _energia(potencia: float) -> String:
	return ("+%d W" % roundi(potencia)) if potencia > 0.0 else ("−%d W" % roundi(-potencia) if potencia < 0.0 else "0 W")


func _costo(costo: Dictionary) -> String:
	var texto := cost_text(costo)
	return texto if not texto.is_empty() else tr("INFO_FREE")


## Foto del edificio (renderizada de su modelo con tools/renderizar_fichas.gd); null si falta.
static func foto_de(tipo: String) -> Texture2D:
	if not _fotos.has(tipo):
		var ruta := "res://assets/edificios/%s.png" % tipo
		_fotos[tipo] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _fotos[tipo]


# --- Ficha del edificio ---------------------------------------------------------------------------------------------

## Abre (o cambia) la ficha del edificio «tipo»: foto grande, descripción, datos y botón para construirlo.
func abrir_ficha(tipo: String) -> void:
	if not is_instance_valid(_ficha):
		_crear_ficha()
	_ficha.set_meta("tipo", tipo)
	for op in snapshot.get("build_options", []):
		if str(op.get("id", "")) == tipo:
			_llenar_ficha(op)
	_ficha.visible = true


func cerrar_ficha() -> void:
	if is_instance_valid(_ficha):
		_ficha.visible = false


func ficha_abierta() -> bool:
	return is_instance_valid(_ficha) and _ficha.visible


func _crear_ficha() -> void:
	_ficha = PanelContainer.new()
	_ficha.name = "Ficha"
	_ficha.add_theme_stylebox_override("panel", UI.box(0.92, UI.RADIUS_PANEL, 0.35, 1, 18, 16))
	UI.place(_ficha, "bl", 450, 110, 340, 470)
	_ficha.visible = false
	root.add_child(_ficha)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 8)
	_ficha.add_child(caja)
	var cabecera := HBoxContainer.new()
	caja.add_child(cabecera)
	var titulo := UI.label(cabecera, "", UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(titulo, 700, 1)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.set_meta("titulo", titulo)
	var cerrar := Button.new()
	cerrar.flat = true
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.custom_minimum_size = Vector2(28, 28)
	var x := Icon.make("close", 14, UI.CREAM)
	x.mouse_filter = Control.MOUSE_FILTER_IGNORE
	x.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	cerrar.add_child(x)
	cerrar.pressed.connect(cerrar_ficha)
	cabecera.add_child(cerrar)
	var escenario := PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.36, 0.22, 0.16, 0.55)
	fondo.set_corner_radius_all(UI.RADIUS_LABEL)
	fondo.border_color = Color(UI.AMBER, 0.25)
	fondo.set_border_width_all(1)
	escenario.add_theme_stylebox_override("panel", fondo)
	escenario.custom_minimum_size = Vector2(0, 170)
	caja.add_child(escenario)
	var foto := TextureRect.new()
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	foto.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	escenario.add_child(foto)
	_ficha.set_meta("foto", foto)
	var descripcion := UI.label(caja, "", 13, Color(UI.CREAM, 0.88))
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.set_meta("descripcion", descripcion)
	var datos := GridContainer.new()
	datos.columns = 2
	datos.add_theme_constant_override("h_separation", 12)
	datos.add_theme_constant_override("v_separation", 3)
	caja.add_child(datos)
	_ficha.set_meta("datos", datos)
	var motivo := UI.label(caja, "", 12, UI.WARN)
	motivo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ficha.set_meta("motivo", motivo)
	var construir := Button.new()
	construir.theme_type_variation = "PrimaryButton"
	construir.focus_mode = Control.FOCUS_NONE
	construir.custom_minimum_size = Vector2(0, 38)
	construir.text = tr("INFO_BUILD")
	construir.pressed.connect(func() -> void:
		var tipo := str(_ficha.get_meta("tipo", ""))
		cerrar_ficha()
		menu.visible = false
		placement_requested.emit(tipo))
	caja.add_child(construir)
	_ficha.set_meta("construir", construir)


func _llenar_ficha(op: Dictionary) -> void:
	var tipo := str(op.get("id", ""))
	var clave := _clave(tipo)
	(_ficha.get_meta("titulo") as Label).text = tr("BLD_" + clave)
	(_ficha.get_meta("foto") as TextureRect).texture = foto_de(tipo)
	(_ficha.get_meta("descripcion") as Label).text = tr("BLD_DESC_" + clave)
	var info: Dictionary = op.get("info", {})
	var filas: Array = []
	filas.append([tr("INFO_COST"), _costo(op.get("cost", {}))])
	filas.append([tr("INFO_POWER"), _energia(float(op.get("power_w", 0.0)))])
	filas.append([tr("INFO_TIME"), tr("INFO_SECONDS") % roundi(float(op.get("seconds", 0.0)))])
	filas.append([tr("INFO_HP"), str(roundi(float(info.get("hp", 0.0))))])
	if info.has("damage"):
		filas.append([tr("INFO_DAMAGE"), str(roundi(float(info["damage"])))])
		filas.append([tr("INFO_FIRE_RATE"), tr("INFO_FIRE_RATE_VALUE") % _decimal(float(info.get("fire_rate_s", 0.0)))])
		filas.append([tr("INFO_RANGE"), tr("INFO_RANGE_VALUE") % _decimal(float(info.get("range", 0.0)))])
	if int(info.get("capacity", 0)) > 0:
		filas.append([tr("INFO_CAPACITY"), tr("INFO_CAPACITY_VALUE") % int(info["capacity"])])
	var produce: Dictionary = info.get("produces_per_hour", {})
	for r in produce:
		filas.append([tr("INFO_PRODUCES"), tr("INFO_PER_HOUR") % ("%s %s" % [_decimal(float(produce[r])), tr("RES_" + str(r).to_upper()).to_lower()])])
	if int(info.get("modules", 0)) > 0:
		filas.append([tr("INFO_MODULES"), str(int(info["modules"]))])
		filas.append([tr("INFO_MODULE_HP"), str(roundi(float(info.get("hp_module", 0.0))))])
	var maximo := int(op.get("max", -1))
	if maximo >= 0:
		filas.append([tr("INFO_BUILT"), "%d / %d" % [int(op.get("count", 0)), maximo]])
	var requiere := str(info.get("requires", ""))
	if not requiere.is_empty():
		filas.append([tr("INFO_REQUIRES"), tr("BLD_" + _clave(requiere))])
	var datos: GridContainer = _ficha.get_meta("datos")
	for hijo in datos.get_children():
		datos.remove_child(hijo)
		hijo.queue_free()
	for f in filas:
		UI.label(datos, str(f[0]), 12, Color(UI.CREAM, 0.62))
		var valor := UI.label(datos, str(f[1]), 13, UI.CREAM)
		valor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var habilitado := bool(op.get("enabled", false))
	var motivo: Label = _ficha.get_meta("motivo")
	motivo.text = "" if habilitado else tr(str(op.get("reason", "")))
	motivo.visible = not habilitado
	var construir: Button = _ficha.get_meta("construir")
	construir.text = tr("INFO_BUILD")
	construir.disabled = not habilitado


static func _decimal(v: float) -> String:
	return str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v)


## Edificio por módulos (la nave de fuga): avance y botón del siguiente módulo con su costo.
func _fill_modules(e: Dictionary) -> void:
	_menu_box.add_child(HSeparator.new())
	var titulo := UI.label(_menu_box, "", 12, UI.AMBER)
	var completa := UI.label(_menu_box, tr("SHIP_COMPLETE"), 14, UI.TEAL)
	var b := Button.new()
	b.theme_type_variation = "RowButton"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(380, 0)
	b.add_theme_font_size_override("font_size", 14)
	var id := str(e["id"])
	b.pressed.connect(func() -> void:
		menu.visible = false
		command.emit("build_module", {"id": id}))
	_menu_box.add_child(b)
	_modulos[id] = {"title": titulo, "done": completa, "button": b}
	_fijar_modulo(_modulos[id], e)


func _fijar_modulo(m: Dictionary, e: Dictionary) -> void:
	var total := int(e.get("modules", 0))
	var hechos := int(e.get("level", 0))
	(m["title"] as Label).text = tr("SHIP_MODULES") % [hechos, total]
	var siguiente: Dictionary = e.get("next_module", {})
	var b: Button = m["button"]
	(m["done"] as Label).visible = siguiente.is_empty() and hechos >= total
	b.visible = not siguiente.is_empty()
	if siguiente.is_empty():
		return
	var linea2 := "%s  ·  %d s" % [cost_text(siguiente.get("cost", {})), roundi(float(siguiente.get("seconds", 0)))]
	var habilitado := bool(siguiente.get("enabled", false))
	if not habilitado:
		linea2 += "\n— " + tr(str(siguiente.get("reason", "")))
	b.text = tr(str(siguiente.get("name_key", ""))) + "\n" + linea2
	b.disabled = not habilitado


## Tipo de edificio -> sufijo de su clave de texto (BLD_SOLAR...).
static func _clave(tipo: String) -> String:
	return {"panel_solar": "SOLAR", "luz": "LIGHT", "domo": "DOME", "extractor_hielo": "EXTRACTOR", "hangar": "HANGAR",
		"antena": "ANTENNA", "torreta": "TURRET", "torreta_2": "TURRET2", "nave_fuga": "SHIP"}.get(tipo, tipo.to_upper())


## Esc cierra primero la ficha y luego el menú de construcción (antes que la pausa del HUD).
func _input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_ESCAPE):
		return
	if ficha_abierta():
		cerrar_ficha()
		get_viewport().set_input_as_handled()
	elif is_instance_valid(menu) and menu.visible:
		close_menu()
		get_viewport().set_input_as_handled()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_B and _usable():
		if not bool(snapshot.get("paused", false)) and snapshot.get("story", {}).get("pending", {}).is_empty():
			toggle_menu()
			get_viewport().set_input_as_handled()
