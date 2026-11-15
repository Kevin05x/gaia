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
var _abierto := false  ## el panel está desplegado (por defecto solo una línea, para no tapar el catálogo)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if taller_vista != null and taller_vista.get("consejo_panel") != null:
		(taller_vista.consejo_panel as Control).visible = false
	var panel := PanelContainer.new()
	var estilo := UI.box(0.0, 14, 0.5, 1, 14, 12, NARANJA)
	estilo.bg_color = Color("120A06", 0.82)
	panel.add_theme_stylebox_override("panel", estilo)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Abajo, a la derecha del catálogo y bajo el rover: ya no tapa las piezas. Plegado es una sola tarjeta baja; al desplegarlo crece hacia arriba.
	UI.place(panel, "bl", 352, 16, 310, 0)
	add_child(panel)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 5)
	panel.add_child(_caja)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if taller_vista != null:
		taller_vista.bloqueo = _bloqueo
	actualizar(taller_vista.snapshot.get("workshop", {}) if taller_vista != null else {})


## Cuánto lleva gastado cada rol (ver Permisos.gasto_por_rol).
static func gasto_por_rol(taller: Dictionary) -> Dictionary:
	return Permisos.gasto_por_rol(taller)


## Más de un jugador: cada rol tiene su parte del presupuesto y las piezas de otros roles se ven bloqueadas.
func _hay_reparto() -> bool:
	return Red.sala != null and Red.sala.orden.size() > 1


## Aviso con el que se bloquea una pieza en el catálogo (vacío = libre): es de otro rol, o no cabe en la parte de tu rol.
func _bloqueo(categoria: String, pieza: Dictionary, elegida: bool) -> String:
	if not _hay_reparto():
		return ""
	var rol := Permisos.rol_de_categoria(categoria)
	if rol.is_empty():
		return ""
	if not Red.mis_roles().has(rol):
		var id: int = Red.sala.quien_tiene(rol)
		var quien: String = tr("NET_WS_ME") if id == Red.mi_id else str(Red.sala.nombres.get(id, ""))
		return tr("NET_LOCKED_BY") % [tr("NET_R_" + rol.to_upper()), quien]
	if elegida:
		return ""
	var valor = pieza.get("cost_musd")
	var resto = Permisos.resto_de_rol(rol, float(valor) if valor != null else 0.0, _taller_actual)
	if resto != null and float(resto) < 0.0:
		return tr("NET_NO_BUDGET") % int(maxf(0.0, float(resto) + (float(valor) if valor != null else 0.0)))
	return ""


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
	_taller_actual = taller
	var gasto := Permisos.gasto_por_rol(taller)
	var topes := Permisos.topes_por_rol(float(taller.get("totals", {}).get("budget_musd", 0.0))) if _hay_reparto() else {}
	var cabecera := HBoxContainer.new()
	_caja.add_child(cabecera)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cabecera.add_child(textos)
	UI.label(textos, tr("NET_YOUR_ROLE"), UI.FONT_MIN, Color(NARANJA, 0.9))
	var titulo := UI.label(textos, " · ".join(mis_nombres), UI.FONT_TEXT, CREMA)
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not topes.is_empty():
		var mio := 0.0
		var tope_mio := 0.0
		for rol in mis_roles:
			mio += float(gasto.get(rol, 0.0))
			tope_mio += float(topes.get(rol, 0.0))
		var resto := tope_mio - mio
		UI.label(textos, tr("NET_MY_BUDGET") % [int(round(mio)), int(round(tope_mio))], UI.FONT_MIN, UI.CORAL if resto < 0.0 else NARANJA)
	var plegar := Button.new()
	plegar.text = tr("NET_PANEL_HIDE") if _abierto else tr("NET_PANEL_SHOW")
	plegar.focus_mode = Control.FOCUS_NONE
	plegar.add_theme_font_size_override("font_size", UI.FONT_MIN)
	plegar.pressed.connect(func() -> void:
		_abierto = not _abierto
		actualizar(_taller_actual))
	plegar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cabecera.add_child(plegar)
	if _abierto:
		var areas: Array[String] = []
		for categoria in Permisos.categorias_de(mis_roles):
			areas.append(tr(taller_vista.CATEGORY_KEYS[categoria]))
		var te_toca := UI.label(_caja, tr("NET_YOUR_AREAS") % ", ".join(areas), UI.FONT_MIN, NARANJA)
		te_toca.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_caja.add_child(HSeparator.new())
		for rol in ["direccion", "ingenieria", "comunicaciones", "ciencia"]:
			var id: int = Red.sala.quien_tiene(rol)
			if id == 0:
				continue
			var mio_rol: bool = mis_roles.has(rol)
			var fila := HBoxContainer.new()
			_caja.add_child(fila)
			var quien: String = tr("NET_WS_ME") if id == Red.mi_id else str(Red.sala.nombres.get(id, ""))
			var etiqueta := UI.label(fila, "%s · %s" % [tr("NET_R_" + rol.to_upper()), quien], UI.FONT_MIN, NARANJA if mio_rol else Color(CREMA, 0.75))
			etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			etiqueta.clip_text = true
			var texto_cifra := "%d / %d M$" % [int(round(gasto.get(rol, 0.0))), int(round(topes[rol]))] if topes.has(rol) else "%d M$" % int(round(gasto.get(rol, 0.0)))
			var cifra := UI.label(fila, texto_cifra, UI.FONT_MIN, NARANJA if mio_rol else Color(CREMA, 0.75))
			cifra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var pie := UI.label(_caja, tr("NET_SHARED_BUDGET"), UI.FONT_MIN, Color(CREMA, 0.6))
		pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var abrir := Button.new()
		abrir.text = tr("NET_G_OPEN")
		abrir.focus_mode = Control.FOCUS_NONE
		abrir.add_theme_font_size_override("font_size", UI.FONT_MIN)
		abrir.pressed.connect(mostrar_guia)
		_caja.add_child(abrir)
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
