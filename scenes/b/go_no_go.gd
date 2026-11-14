extends Control
## Revisión «Go / No-Go» del equipo antes del lanzamiento (modo equipo, 2 a 4 personas en la misma pantalla).
## Como en las revisiones de vuelo reales, cada responsable mira su parte del diseño y vota GO o NO GO;
## la misión solo despega si todos dicen GO. Si alguien vota NO GO, el equipo vuelve al taller y negocia.
## Los criterios salen del snapshot del taller; la decisión final es de las personas, no del juego.

const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const INSTRUMENTOS_CIENTIFICOS: Array[String] = ["espectrometro", "taladro", "camara", "meteo", "radar", "dron"]

signal launch_confirmed
signal cancelled
## Modo red: este jugador votó (valor null = quitó su voto). Los votos de los demás llegan con aplicar_voto_remoto().
signal voto_cambiado(rol: String, valor: Variant)

var taller: Dictionary = {}
var jugadores := 2
var _votos: Dictionary = {}  ## rol -> true (GO) / false (NO GO)
var _lanzar: Button
var _aviso: Label
## Modo red: roles de ESTE jugador (solo vota los suyos) y si es quien puede lanzar. Vacío = todo el equipo en una pantalla.
var roles_propios: Array = []
var es_lider := true
var _botones: Dictionary = {}  ## rol -> [GO, NO GO]


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tapa := ColorRect.new()
	tapa.color = Color(0.03, 0.02, 0.02, 0.78)
	tapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tapa)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.97, 14, 0.35, 1, 28, 22, UI.AMBER))
	UI.place(caja, "c", 0, 0, 820, 0)
	add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	caja.add_child(col)
	var titulo := UI.label(col, tr("GNG_TITLE"), 26, UI.CREAM)
	UI.display(titulo, 700, 2)
	var intro := UI.label(col, tr("GNG_INTRO") % jugadores, 14, Color(UI.CREAM, 0.8))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 760
	var roles := Sesion.roles_por_jugador(jugadores)
	for i in range(roles.size()):
		for rol in roles[i]:
			col.add_child(_fila(str(rol), i + 1))
	_aviso = UI.label(col, "", 13, UI.WARN)
	_aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso.custom_minimum_size.x = 760
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_END
	pie.add_theme_constant_override("separation", 10)
	col.add_child(pie)
	var volver := Button.new()
	volver.text = tr("GNG_BACK")
	volver.custom_minimum_size = Vector2(200, 42)
	volver.pressed.connect(func() -> void: cancelled.emit())
	volver.disabled = not es_lider
	pie.add_child(volver)
	_lanzar = Button.new()
	_lanzar.theme_type_variation = "PrimaryButton"
	_lanzar.text = tr("GNG_LAUNCH")
	_lanzar.custom_minimum_size = Vector2(220, 42)
	_lanzar.pressed.connect(_confirmar)
	pie.add_child(_lanzar)
	_actualizar()


## Lo que revisa cada rol: {"ok": bool, "detalle": String}.
func criterio(rol: String) -> Dictionary:
	var t: Dictionary = taller.get("totals", {})
	var sel: Dictionary = taller.get("selection", {})
	match rol:
		"direccion":
			var gasto := float(t.get("cost_musd", 0))
			var tope := float(t.get("budget_musd", 700))
			return {"ok": gasto <= tope, "detalle": tr("GNG_DIR_D") % [int(gasto), int(tope), int(tope - gasto)]}
		"ingenieria":
			var masa := float(t.get("mass_kg", 0))
			var cap := float(t.get("capacity_kg", 0))
			var margen := 0 if cap <= 0.0 else int(round((cap - masa) / cap * 100.0))
			var detalle := tr("GNG_ENG_D") % [int(masa), int(cap), margen]
			var energia: Array = sel.get("energia", [])
			if energia.has("panel_solar") and not (sel.get("extras", []) as Array).has("bateria"):
				detalle += " " + tr("GNG_ENG_SOLAR")
			return {"ok": cap > 0.0 and masa <= cap, "detalle": detalle}
		"ciencia":
			var n := 0
			for id in sel.get("extras", []):
				if INSTRUMENTOS_CIENTIFICOS.has(str(id)):
					n += 1
			return {"ok": n >= 2, "detalle": tr("GNG_SCI_D") % n}
		"comunicaciones":
			var enlace: Array = sel.get("comunicaciones", [])
			if enlace.is_empty():
				return {"ok": false, "detalle": tr("GNG_COM_NONE")}
			return {"ok": true, "detalle": tr("GNG_COM_RELAY") if enlace.has("antena_rele") else tr("GNG_COM_DIRECT")}
	return {"ok": true, "detalle": ""}


func _fila(rol: String, jugador: int) -> Control:
	var c := criterio(rol)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	fila.add_child(Icon.make("check_circle" if c["ok"] else "warning", 22, UI.TEAL if c["ok"] else UI.WARN))
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("separation", 0)
	fila.add_child(textos)
	var nombre := UI.label(textos, "%s · %s" % [tr("ROLE_" + rol.to_upper()), tr("GNG_PLAYER") % jugador], 15, UI.CREAM)
	UI.display(nombre, 700, 0)
	var detalle := UI.label(textos, str(c["detalle"]), 12, Color(UI.CREAM, 0.75))
	detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detalle.custom_minimum_size.x = 470
	var mio := roles_propios.is_empty() or roles_propios.has(rol)
	var go := Button.new()
	go.text = "GO"
	go.toggle_mode = true
	go.custom_minimum_size = Vector2(76, 38)
	var no := Button.new()
	no.text = "NO GO"
	no.toggle_mode = true
	no.custom_minimum_size = Vector2(90, 38)
	go.toggled.connect(func(on: bool) -> void:
		if on:
			no.set_pressed_no_signal(false)
			_votos[rol] = true
		else:
			_votos.erase(rol)
		voto_cambiado.emit(rol, _votos.get(rol, null))
		_actualizar())
	no.toggled.connect(func(on: bool) -> void:
		if on:
			go.set_pressed_no_signal(false)
			_votos[rol] = false
		else:
			_votos.erase(rol)
		voto_cambiado.emit(rol, _votos.get(rol, null))
		_actualizar())
	go.disabled = not mio
	no.disabled = not mio
	_botones[rol] = [go, no]
	fila.add_child(go)
	fila.add_child(no)
	return fila


## Modo red: el voto de otro jugador (null = lo quitó).
func aplicar_voto_remoto(rol: String, valor: Variant) -> void:
	if valor == null:
		_votos.erase(rol)
	else:
		_votos[rol] = bool(valor)
	if _botones.has(rol):
		_botones[rol][0].set_pressed_no_signal(valor != null and bool(valor))
		_botones[rol][1].set_pressed_no_signal(valor != null and not bool(valor))
		_pintar_voto(rol)
	_actualizar()


## El voto de otro jugador se ve con el color del botón (los botones de roles ajenos están desactivados y no se «hunden»).
func _pintar_voto(rol: String) -> void:
	var par: Array = _botones[rol]
	par[0].add_theme_color_override("font_disabled_color", UI.AMBER if par[0].button_pressed else Color(UI.CREAM, 0.35))
	par[1].add_theme_color_override("font_disabled_color", UI.WARN if par[1].button_pressed else Color(UI.CREAM, 0.35))


func _roles() -> Array:
	var lista: Array = []
	for grupo in Sesion.roles_por_jugador(jugadores):
		lista.append_array(grupo)
	return lista


func _actualizar() -> void:
	if _lanzar == null:
		return
	var todos := _roles()
	var faltan := 0
	var en_contra: Array[String] = []
	for rol in todos:
		if not _votos.has(rol):
			faltan += 1
		elif not _votos[rol]:
			en_contra.append(tr("ROLE_" + str(rol).to_upper()))
	_lanzar.disabled = faltan > 0 or not en_contra.is_empty() or not es_lider
	if not en_contra.is_empty():
		_aviso.text = tr("GNG_NOGO") % ", ".join(en_contra)
	elif faltan > 0:
		_aviso.text = tr("GNG_WAITING") % faltan
	else:
		_aviso.text = tr("GNG_ALL_GO") + ("" if es_lider else " " + tr("NET_WAIT_DIRECTION"))


func _confirmar() -> void:
	var votos: Array = []
	var roles := Sesion.roles_por_jugador(jugadores)
	for i in range(roles.size()):
		for rol in roles[i]:
			votos.append({"rol": rol, "jugador": i + 1, "go": bool(_votos.get(rol, false)), "ok": bool(criterio(rol)["ok"])})
	Sesion.votos = votos
	launch_confirmed.emit()
