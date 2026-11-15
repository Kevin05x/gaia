extends Control
## Panel «Multijugador» del menú: crear una sala o entrar en una, y la sala de espera (jugadores, roles, destino y
## dificultad). Cuando el jefe empieza, avisa al menú con «partida_lista» y el menú lleva a todos a la pantalla de carga.
const UI := preload("res://scenes/b/ui_style.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")
const Texto := preload("res://scenes/menu/menu_text.gd")
const RolesVentana := preload("res://scenes/net/roles_ventana.gd")
## Servidor de GAIA en internet (VPS de Full Galácticos). Es lo que se propone por defecto: nadie tiene que saber la dirección.
const SERVIDOR_GAIA := "sala.gaianasa.tech"

signal cerrado
signal partida_lista

static var nombre_guardado := ""
static var direccion_guardada := ""

var _cuerpo: VBoxContainer
var _mensaje: Label
var _nombre: LineEdit
var _direccion: LineEdit
var _conectando := false


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var tapa := ColorRect.new()
	tapa.color = Color(0.03, 0.02, 0.04, 0.8)
	tapa.set_anchors_preset(Control.PRESET_FULL_RECT)
	tapa.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tapa)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.97, 14, 0.28, 1, 34, 26))
	UI.place(caja, "c", 0, 0, 800, 0)
	add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	caja.add_child(col)
	UI.display(UI.label(col, tr("NET_TITLE").to_upper(), 26, UI.CREAM), 700, 3)
	_cuerpo = VBoxContainer.new()
	_cuerpo.add_theme_constant_override("separation", 10)
	col.add_child(_cuerpo)
	_mensaje = UI.label(col, "", 14, UI.WARN)
	_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje.custom_minimum_size.x = 720
	Red.sala_cambiada.connect(_refrescar)
	Red.conexion_fallida.connect(_al_fallar)
	Red.desconectado.connect(_al_fallar)
	Red.partida_empieza.connect(func() -> void: partida_lista.emit())
	_refrescar()


func _exit_tree() -> void:
	# Si se cierra el panel sin empezar (Esc), no se deja una sala abierta a medias.
	if Red.activo() and not Sesion.en_red:
		Red.salir()
	for senal in [Red.sala_cambiada, Red.conexion_fallida, Red.desconectado]:
		for conexion in senal.get_connections():
			if conexion["callable"].get_object() == self:
				senal.disconnect(conexion["callable"])


func _al_fallar(motivo: String) -> void:
	_conectando = false
	_mensaje.text = tr(motivo)
	_refrescar()


func _subtitulo(texto: String) -> void:
	UI.display(UI.label(_cuerpo, texto.to_upper(), 12, Color(UI.AMBER, 0.9)), 700, 3)


func _boton(texto: String, accion: Callable, principal: bool = false, ancho: float = 200) -> Button:
	var b := Button.new()
	b.text = texto
	if principal:
		b.theme_type_variation = "PrimaryButton"
	b.custom_minimum_size = Vector2(ancho, 42)
	b.pressed.connect(accion)
	return b


func _refrescar() -> void:
	if not is_instance_valid(_cuerpo):
		return
	for hijo in _cuerpo.get_children():
		hijo.queue_free()
	if Red.activo() and Red.sala.numero(Red.mi_id) > 0:
		_vista_sala()
	elif _conectando:
		UI.label(_cuerpo, tr("NET_CONNECTING"), 16, UI.CREAM)
	else:
		_vista_inicio()


# ---------------------------------------------------------------------------------------- crear o unirse

func _vista_inicio() -> void:
	var nota := UI.label(_cuerpo, tr("NET_NOTE"), 13, Color(UI.CREAM, 0.75))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 720
	_subtitulo(tr("NET_NAME"))
	_nombre = LineEdit.new()
	_nombre.text = nombre_guardado
	_nombre.placeholder_text = tr("NET_NAME_DEFAULT")
	_nombre.max_length = 16
	_nombre.custom_minimum_size = Vector2(320, 40)
	_cuerpo.add_child(_nombre)
	_subtitulo(tr("NET_HOST"))
	var web := OS.has_feature("web")
	if web:
		var aviso := UI.label(_cuerpo, tr("NET_WEB_NO_HOST"), 13, Color(UI.CREAM, 0.75))
		aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		aviso.custom_minimum_size.x = 720
	else:
		var crear := _boton(tr("NET_HOST"), _crear_sala, true)
		_cuerpo.add_child(crear)
		crear.grab_focus.call_deferred()
	_subtitulo(tr("NET_JOIN"))
	_direccion = LineEdit.new()
	if direccion_guardada.is_empty():
		direccion_guardada = str(Texto.preferencias().get("net_direccion", ""))  # la última sala a la que se entró
	_direccion.text = direccion_guardada if not direccion_guardada.is_empty() else SERVIDOR_GAIA
	_direccion.placeholder_text = tr("NET_ADDR_HINT")
	_direccion.custom_minimum_size = Vector2(560, 40)
	_direccion.text_submitted.connect(func(_t: String) -> void: _unirse())
	_cuerpo.add_child(_direccion)
	_cuerpo.add_child(_boton(tr("NET_CONNECT"), _unirse, web))
	_cuerpo.add_child(_boton(tr("NET_OFFICIAL") % SERVIDOR_GAIA, func() -> void:
		_direccion.text = SERVIDOR_GAIA
		_unirse(), false, 360))
	_cuerpo.add_child(_boton(tr("NET_RW_BUTTON"), func() -> void: RolesVentana.abrir(self), false, 260))
	_cuerpo.add_child(_boton(tr("NET_BACK"), func() -> void: cerrado.emit(), false, 150))


func _nombre_elegido() -> String:
	nombre_guardado = _nombre.text.strip_edges() if is_instance_valid(_nombre) else nombre_guardado
	return nombre_guardado  # vacío: la sala le pone «Jugador N»


func _crear_sala() -> void:
	_mensaje.text = ""
	var err := Red.crear_sala(_nombre_elegido())
	if err != OK:
		_mensaje.text = tr("NET_ERR_PORT") if not OS.has_feature("web") else tr("NET_ERR_WEB")


func _unirse() -> void:
	_mensaje.text = ""
	direccion_guardada = _direccion.text.strip_edges()
	var err := Red.unirse(direccion_guardada, _nombre_elegido())
	if err != OK:
		_mensaje.text = tr("NET_ERR_CONNECT")
		return
	Texto.guardar("net", "direccion", direccion_guardada)
	_conectando = true
	_refrescar()


# ------------------------------------------------------------------------------------------- la sala

func _vista_sala() -> void:
	var sala = Red.sala
	var jefe: bool = Red.soy_jefe()
	if Red.modo == Red.Modo.ANFITRION:
		_subtitulo(tr("NET_SHARE"))
		var ips := Red.direcciones_locales()
		var texto := "   ·   ".join(ips) if not ips.is_empty() else "—"
		UI.label(_cuerpo, "%s   (:%d)" % [texto, Red.PUERTO], 18, UI.CREAM)
	_cuerpo.add_child(_boton(tr("NET_RW_BUTTON"), func() -> void: RolesVentana.abrir(self), false, 260))
	_subtitulo(tr("NET_PLAYERS") % sala.cuantos())
	for i in range(sala.cuantos()):
		var id: int = sala.orden[i]
		var linea := "%d.  %s" % [i + 1, sala.nombres.get(id, "")]
		if id == Red.mi_id:
			linea += "  (%s)" % tr("NET_YOU")
		if i == 0:
			linea += "  ·  %s" % tr("NET_LEADER")
		UI.label(_cuerpo, linea, 17, UI.CREAM)
	var roles := UI.label(_cuerpo, _texto_roles(sala), 13, Color(UI.CREAM, 0.7))
	roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roles.custom_minimum_size.x = 720
	_selector_destino(sala, jefe)
	_selector_dificultad(sala, jefe)
	_selector_duracion_sol(sala, jefe)
	if jefe:
		UI.label(_cuerpo, tr("NET_START_HINT"), 13, Color(UI.AMBER, 0.9))
	var pie := HBoxContainer.new()
	pie.add_theme_constant_override("separation", 10)
	_cuerpo.add_child(pie)
	pie.add_child(_boton(tr("NET_LEAVE"), func() -> void:
		Red.salir()
		cerrado.emit(), false, 200))
	if jefe:
		var empezar := _boton(tr("NET_START"), func() -> void: Red.empezar(), true, 240)
		pie.add_child(empezar)
		empezar.grab_focus.call_deferred()
	else:
		UI.label(pie, tr("NET_WAITING"), 14, Color(UI.AMBER, 0.9))


func _texto_roles(sala) -> String:
	var reparto: Array = Sesion.roles_por_jugador(sala.cuantos())
	var partes: Array[String] = []
	for i in range(mini(reparto.size(), sala.cuantos())):
		var nombres: Array[String] = []
		for rol in reparto[i]:
			nombres.append(tr("ROLE_" + str(rol).to_upper()))
		partes.append("%s: %s" % [sala.nombres.get(sala.orden[i], ""), " + ".join(nombres)])
	return tr("NET_ROLES") % "  ·  ".join(partes) + "\n" + tr("NET_ROLES_AT_START")


func _selector_destino(sala, jefe: bool) -> void:
	_subtitulo(tr("M_SETUP_DEST"))
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string(Destino.DATOS))
	var lista: Dictionary = datos.get("destinos", {}) if datos is Dictionary else {}
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_cuerpo.add_child(fila)
	var grupo := ButtonGroup.new()
	for id in (datos.get("orden", ["marte"]) if datos is Dictionary else ["marte"]):
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo
		b.text = str(lista.get(id, {}).get("nombre", {}).get(idioma, id))
		b.custom_minimum_size = Vector2(230, 40)
		b.button_pressed = str(sala.config["destino"]) == str(id)
		b.disabled = not jefe
		b.pressed.connect(func() -> void: Red.configurar(str(id), str(sala.config["dificultad"])))
		fila.add_child(b)


## Duración de cada sol (plan 3.1): la fija el jefe de la sala y la ven todos.
func _selector_duracion_sol(sala, jefe: bool) -> void:
	_subtitulo(tr("M_SETUP_SOL"))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_cuerpo.add_child(fila)
	var grupo := ButtonGroup.new()
	for minutos in Sesion.DURACIONES_SOL:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo
		b.text = tr("M_SETUP_SOL_N") % minutos
		b.custom_minimum_size = Vector2(110, 40)
		b.button_pressed = int(sala.config.get("duracion_sol_min", 12)) == minutos
		b.disabled = not jefe
		b.pressed.connect(func() -> void: Red.configurar(str(sala.config["destino"]), str(sala.config["dificultad"]), minutos))
		fila.add_child(b)


func _selector_dificultad(sala, jefe: bool) -> void:
	_subtitulo(tr("M_SETUP_DIFF"))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	_cuerpo.add_child(fila)
	var grupo := ButtonGroup.new()
	for id in ["exploracion", "estandar", "experta"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = grupo
		b.text = tr("DIFF_" + id.to_upper())
		b.custom_minimum_size = Vector2(180, 40)
		b.button_pressed = str(sala.config["dificultad"]) == id
		b.disabled = not jefe
		b.pressed.connect(func() -> void: Red.configurar(str(sala.config["destino"]), id))
		fila.add_child(b)
