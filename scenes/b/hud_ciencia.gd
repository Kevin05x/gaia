class_name HudCiencia
extends CanvasLayer
## Panel «Objetivos científicos»: los hitos de la misión agrupados en los cuatro objetivos de Mars 2020, con su avance
## y los datos que da cada uno. Se abre desde la píldora de ciencia del HUD. Cuando se cumple un hito, muestra un
## cartel breve («Hito científico · +8 datos»). Componente aparte del HUD: solo presenta lo que trae el snapshot.
const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")

var root: Control
var panel: PanelContainer
var _lista: VBoxContainer
var _cabecera: Label
var _cartel: PanelContainer
var _cartel_titulo: Label
var _cartel_texto: Label
var _datos: Dictionary = {}
var _firma := ""


func _ready() -> void:
	layer = 7
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.theme()
	add_child(root)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(0.93, UI.RADIUS_PANEL, 0.3, 1, 18, 14))
	UI.place(panel, "tr", 20, 72, 380, 0)
	panel.visible = false
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var titulo := UI.label(col, tr("SCI_GOALS_TITLE"), UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(titulo, 700, 2)
	_cabecera = UI.label(col, "", 12, Color(UI.CREAM, 0.72))
	_cabecera.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 3)
	col.add_child(_lista)
	_cartel = PanelContainer.new()
	_cartel.add_theme_stylebox_override("panel", UI.box(0.92, UI.RADIUS_PANEL, 0.6, 2, 20, 12, UI.AMBER))
	_cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_cartel, "tc", 0, 150, 420, 0)
	_cartel.visible = false
	root.add_child(_cartel)
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override("separation", 2)
	_cartel.add_child(c2)
	_cartel_titulo = UI.label(c2, "", 12, UI.AMBER)
	UI.display(_cartel_titulo, 700, 3)
	_cartel_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartel_texto = UI.label(c2, "", 17, UI.CREAM)
	_cartel_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cartel_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_firma = ""
		_rellenar()


func cerrar() -> void:
	if is_instance_valid(panel):
		panel.visible = false


func update_snapshot(s: Dictionary) -> void:
	_datos = s.get("science_goals", {})
	if panel.visible:
		_rellenar()


## Cartel animado de un hito cumplido: aparece con un pequeño rebote, se queda 3 s y se desvanece.
func celebrar(id: String) -> void:
	for h in _datos.get("milestones", []):
		if str(h.get("id", "")) == id:
			_cartel_titulo.text = tr("SCI_MILESTONE")
			_cartel_texto.text = "%s   ·   +%d %s" % [texto_de(h.get("name", {})), roundi(float(h.get("data", 0))), tr("SCI_DATA")]
	_cartel.visible = true
	_cartel.pivot_offset = Vector2(210, 30)
	_cartel.modulate.a = 0.0
	_cartel.scale = Vector2(0.85, 0.85)
	var t := _cartel.create_tween()
	t.tween_property(_cartel, "modulate:a", 1.0, 0.18)
	t.parallel().tween_property(_cartel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(3.0)
	t.tween_property(_cartel, "modulate:a", 0.0, 0.5)
	t.tween_callback(func() -> void: _cartel.visible = false)
	_firma = ""
	if panel.visible:
		_rellenar()


static func texto_de(nombre: Variant) -> String:
	if nombre is Dictionary:
		var idioma := TranslationServer.get_locale().substr(0, 2)
		return str(nombre.get(idioma, nombre.get("es", "")))
	return str(nombre)


func _rellenar() -> void:
	var firma := var_to_str([_datos, TranslationServer.get_locale()])
	if firma == _firma:
		return
	_firma = firma
	for hijo in _lista.get_children():
		_lista.remove_child(hijo)
		hijo.queue_free()
	var hitos: Array = _datos.get("milestones", [])
	var hechos := 0
	var ganado := 0.0
	var total := 0.0
	for h in hitos:
		total += float(h.get("data", 0))
		if h.get("done", false):
			hechos += 1
			ganado += float(h.get("data", 0))
	_cabecera.text = tr("SCI_GOALS_HINT") % [hechos, hitos.size(), roundi(ganado), roundi(total)]
	if float(_datos.get("pending", 0.0)) > 0.0:
		_cabecera.text += "\n" + tr("SCI_PENDING") % roundi(float(_datos["pending"]))
	for objetivo in _datos.get("objectives", []):
		var titulo := UI.label(_lista, texto_de(objetivo.get("nombre", {})).to_upper(), 11, Color(UI.AMBER, 0.9))
		UI.display(titulo, 700, 3)
		for h in hitos:
			if str(h.get("objective", "")) != str(objetivo.get("id", "")):
				continue
			var fila := HBoxContainer.new()
			fila.add_theme_constant_override("separation", 8)
			_lista.add_child(fila)
			var hecho: bool = h.get("done", false)
			var icono := Icon.make("check_circle" if hecho else "goal", 14, UI.TEAL if hecho else Color(UI.CREAM, 0.5))
			fila.add_child(icono)
			var progreso: Array = h.get("progress", [0, 1])
			var texto := texto_de(h.get("name", {}))
			if not hecho and int(progreso[1]) > 1:
				texto += "  (%d/%d)" % [int(progreso[0]), int(progreso[1])]
			var nombre := UI.label(fila, texto, 13, Color(UI.CREAM, 1.0 if hecho else 0.8))
			nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			UI.label(fila, "+%d" % roundi(float(h.get("data", 0))), 13, UI.TEAL if hecho else Color(UI.AMBER, 0.85))
