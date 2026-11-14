extends Control
## Panel del taller en una partida en red: dice qué rol tienes, qué categorías del taller te tocan y cuánto lleva gastado
## cada área. El presupuesto y la masa son un solo total para todo el equipo; lo que se reparte es quién elige qué
## (ver Permisos.AREAS). Es solo vista: el anfitrión es quien rechaza las piezas de otra área.
const Permisos := preload("res://scenes/net/permisos.gd")
const UI := preload("res://scenes/b/ui_style.gd")
const NARANJA := Color("F5A623")
const CREMA := Color("F3E6D4")

var taller_vista: Node  ## scenes/b/workshop.gd
var _caja: VBoxContainer
var _primera := true
var _guia: Control
var _taller_actual: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if taller_vista != null and taller_vista.get("consejo_panel") != null:
		(taller_vista.consejo_panel as Control).visible = false
	var panel := PanelContainer.new()
	var estilo := UI.box(0.0, 14, 0.5, 1, 14, 12, NARANJA)
	estilo.bg_color = Color("120A06", 0.82)
	panel.add_theme_stylebox_override("panel", estilo)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(panel, "tl", 24, 168, 290, 0)
	add_child(panel)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 5)
	panel.add_child(_caja)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actualizar(taller_vista.snapshot.get("workshop", {}) if taller_vista != null else {})


## Cuánto lleva gastado cada rol: suma del costo de las piezas elegidas en las categorías de su área.
static func gasto_por_rol(taller: Dictionary) -> Dictionary:
	var costo := {}
	for cat in taller.get("categories", []):
		for pieza in cat.get("parts", []):
			costo[str(pieza.get("id", ""))] = float(pieza.get("cost_musd", 0.0) if pieza.get("cost_musd") != null else 0.0)
	var gasto := {}
	for rol in Permisos.AREAS:
		gasto[rol] = 0.0
	var seleccion: Dictionary = taller.get("selection", {})
	for categoria in seleccion:
		var rol := Permisos.rol_de_categoria(str(categoria))
		if rol.is_empty():
			continue
		for id in seleccion[categoria]:
			gasto[rol] += float(costo.get(str(id), 0.0))
	return gasto


func actualizar(taller: Dictionary) -> void:
	if _caja == null:
		return
	for hijo in _caja.get_children():
		_caja.remove_child(hijo)
		hijo.queue_free()
	var mis_roles: Array = Red.mis_roles()
	var mis_nombres: Array[String] = []
	for rol in mis_roles:
		mis_nombres.append(tr("NET_R_" + str(rol).to_upper()))
	UI.label(_caja, tr("NET_YOUR_ROLE"), UI.FONT_MIN, Color(NARANJA, 0.9))
	var titulo := UI.label(_caja, " · ".join(mis_nombres), UI.FONT_TEXT, CREMA)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var areas: Array[String] = []
	for categoria in Permisos.categorias_de(mis_roles):
		areas.append(tr(taller_vista.CATEGORY_KEYS[categoria]))
	var te_toca := UI.label(_caja, tr("NET_YOUR_AREAS") % ", ".join(areas), UI.FONT_MIN, NARANJA)
	te_toca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caja.add_child(HSeparator.new())
	var gasto := gasto_por_rol(taller)
	for rol in ["direccion", "ingenieria", "comunicaciones", "ciencia"]:
		var id: int = Red.sala.quien_tiene(rol)
		if id == 0:
			continue
		var mio: bool = mis_roles.has(rol)
		var fila := HBoxContainer.new()
		_caja.add_child(fila)
		var quien: String = tr("NET_WS_ME") if id == Red.mi_id else str(Red.sala.nombres.get(id, ""))
		var etiqueta := UI.label(fila, "%s · %s" % [tr("NET_R_" + rol.to_upper()), quien], UI.FONT_MIN, NARANJA if mio else Color(CREMA, 0.75))
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.clip_text = true
		var cifra := UI.label(fila, "%d M$" % int(round(gasto.get(rol, 0.0))), UI.FONT_MIN, NARANJA if mio else Color(CREMA, 0.75))
		cifra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pie := UI.label(_caja, tr("NET_SHARED_BUDGET"), UI.FONT_MIN, Color(CREMA, 0.6))
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var abrir := Button.new()
	abrir.text = tr("NET_G_OPEN")
	abrir.focus_mode = Control.FOCUS_NONE
	abrir.add_theme_font_size_override("font_size", UI.FONT_MIN)
	abrir.pressed.connect(mostrar_guia)
	_caja.add_child(abrir)
	_taller_actual = taller
	if is_instance_valid(_guia):
		_pintar_guia()
	_atenuar_ajenas(mis_roles)
	if _primera and not taller.is_empty():
		_primera = false
		mostrar_guia()
		var propias := Permisos.categorias_de(mis_roles)
		if not propias.is_empty() and not propias.has(taller_vista.category):
			taller_vista._choose_category(propias[0])


## Las categorías de otro rol se ven apagadas: se pueden mirar, pero no comprar.
func _atenuar_ajenas(mis_roles: Array) -> void:
	for id in taller_vista._category_buttons:
		var mia: bool = mis_roles.has(Permisos.rol_de_categoria(str(id)))
		(taller_vista._category_buttons[id] as Control).modulate = Color(1, 1, 1, 1.0 if mia else 0.5)


# ---------------------------------------------------------------- guía

## Una pequeña explicación al entrar al taller: cómo se reparte el trabajo y qué le toca a cada quien. Se puede reabrir.
func mostrar_guia() -> void:
	if not is_instance_valid(_guia):
		_guia = Control.new()
		_guia.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_guia.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_guia)
	_pintar_guia()


func cerrar_guia() -> void:
	if is_instance_valid(_guia):
		_guia.queue_free()
	_guia = null


func _pintar_guia() -> void:
	for hijo in _guia.get_children():
		_guia.remove_child(hijo)
		hijo.queue_free()
	var velo := ColorRect.new()
	velo.color = Color("080403", 0.72)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guia.add_child(velo)
	var tarjeta := PanelContainer.new()
	var estilo := UI.box(0.0, 16, 0.6, 1, 26, 20, NARANJA)
	estilo.bg_color = Color("120A06", 0.96)
	tarjeta.add_theme_stylebox_override("panel", estilo)
	UI.place(tarjeta, "c", 0, 0, 640, 0)
	_guia.add_child(tarjeta)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	tarjeta.add_child(col)
	var titulo := UI.label(col, tr("NET_G_TITLE").to_upper(), UI.FONT_PANEL_TITLE, NARANJA)
	UI.display(titulo, 700, 0)
	var presupuesto := int(taller_vista.snapshot.get("workshop", {}).get("totals", {}).get("budget_musd", 0))
	_texto(col, tr("NET_G_INTRO") % presupuesto, UI.FONT_TEXT, CREMA)
	var solo: bool = Red.sala.orden.size() <= 1
	if solo:
		_texto(col, tr("NET_G_SOLO"), UI.FONT_SECONDARY, NARANJA)
	col.add_child(HSeparator.new())
	for id in Red.sala.orden:
		var roles: Array = Red.sala.roles_de(id)
		var quien: String = tr("NET_WS_ME") if id == Red.mi_id else str(Red.sala.nombres.get(id, ""))
		var nombres: Array[String] = []
		for rol in roles:
			nombres.append(tr("ROLE_" + str(rol).to_upper()))
		var areas: Array[String] = []
		for categoria in Permisos.categorias_de(roles):
			areas.append(tr(taller_vista.CATEGORY_KEYS[categoria]))
		var mio: bool = id == Red.mi_id
		_texto(col, "%s: %s" % [quien, " · ".join(nombres)], UI.FONT_TEXT, NARANJA if mio else CREMA)
		_texto(col, tr("NET_YOUR_AREAS") % ", ".join(areas), UI.FONT_MIN, Color(CREMA, 0.85))
		for rol in roles:
			_texto(col, "• " + tr("NET_G_" + str(rol).to_upper()), UI.FONT_MIN, Color(CREMA, 0.7))
	col.add_child(HSeparator.new())
	_texto(col, tr("NET_G_STEPS"), UI.FONT_MIN, CREMA)
	var ok := Button.new()
	ok.text = tr("NET_G_OK").to_upper()
	ok.custom_minimum_size = Vector2(0, 40)
	ok.pressed.connect(cerrar_guia)
	col.add_child(ok)


func _texto(padre: Node, texto: String, tamano: int, color: Color) -> Label:
	var etiqueta := UI.label(padre, texto, tamano, color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return etiqueta
