class_name HudAvisos
extends RefCounted
## Avisos del HUD: franja ámbar (avisos) y roja (críticos) arriba al centro, con la lista desplegable «+N». Salió de
## hud.gd (que pasaba de 1400 líneas) y ahora solo rehace la lista cuando cambian los avisos: antes la borraba y la
## volvía a crear en cada snapshot mientras hubiera un aviso (nodos nuevos varias veces por segundo).
const UI := preload("res://scenes/b/ui_style.gd")

var lista: PanelContainer  ## lista desplegable (hud._toggle_panel la cierra junto a los otros paneles)
var _hud: Object  ## hud.gd: da las piezas (franjas, fundido) y el contenedor raíz
var _franja: PanelContainer
var _texto: Label
var boton_mas: Button  ## «+N» que abre la lista
var _caja: VBoxContainer
var _critica: PanelContainer
var _texto_critico: Label
var _firma := ""


func _init(hud: Object) -> void:
	_hud = hud
	_franja = hud._slot("warning", UI.WARN)
	UI.place(_franja, "tc", -70, 20, 340, 48)
	_texto = _franja.get_meta("text")
	boton_mas = Button.new()
	boton_mas.theme_type_variation = "PillButton"
	boton_mas.focus_mode = Control.FOCUS_NONE
	boton_mas.custom_minimum_size = Vector2(44, 30)
	boton_mas.add_theme_font_size_override("font_size", UI.FONT_SECONDARY)
	boton_mas.visible = false
	_franja.get_meta("row").add_child(boton_mas)
	boton_mas.pressed.connect(func(): hud._toggle_panel(lista))
	_critica = hud._slot("critical", UI.CORAL)
	UI.place(_critica, "tc", -70, 76, 340, 48)
	_texto_critico = _critica.get_meta("text")
	lista = PanelContainer.new()
	lista.add_theme_stylebox_override("panel", UI.box(0.8, UI.RADIUS_PANEL, 0.3, 1, 14, 10, UI.WARN))
	UI.place(lista, "tc", -70, 132, 340, 0)
	_caja = VBoxContainer.new()
	_caja.add_theme_constant_override("separation", 8)
	lista.add_child(_caja)
	lista.visible = false
	(hud.root as Control).add_child(lista)


func actualizar(s: Dictionary, en_operacion: bool) -> void:
	var criticos := []
	var avisos := []
	if en_operacion:
		for aviso in lista_de(s):
			if str(aviso.get("severity", "")) == "critical":
				criticos.append(aviso)
			else:
				avisos.append(aviso)
	var firma := var_to_str([criticos, avisos, TranslationServer.get_locale()])
	if firma == _firma:
		return
	_firma = firma
	if criticos.is_empty():
		_hud._fade(_critica, false)
	else:
		_texto_critico.text = formatear(criticos[0])
		_hud._fade(_critica, true)
	if avisos.is_empty():
		_hud._fade(_franja, false)
		lista.visible = false
		return
	_texto.text = formatear(avisos[0])
	boton_mas.visible = avisos.size() > 1
	boton_mas.text = TranslationServer.translate("MORE_WARNINGS") % (avisos.size() - 1)
	_hud._fade(_franja, true)
	for hijo in _caja.get_children():
		_caja.remove_child(hijo)
		hijo.queue_free()
	for aviso in avisos:
		var linea := UI.label(_caja, formatear(aviso), UI.FONT_SECONDARY)
		linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		linea.custom_minimum_size.x = 360
	if avisos.size() < 2:
		lista.visible = false


## true si el snapshot trae el aviso «id».
static func hay(s: Dictionary, id: String) -> bool:
	for aviso in s.get("warnings", []):
		if str(aviso.get("id", "")) == id:
			return true
	return false


static func lista_de(s: Dictionary) -> Array:
	if s.has("warnings"):
		return s["warnings"]
	# Proveedor de revisión de B (sin avisos): solo los estados evidentes.
	var resultado := []
	if s.get("safe_mode", false):
		resultado.append({"id": "SAFE_MODE", "severity": "critical", "key": "WARN_SAFE_MODE", "values": []})
	if s.get("storm", false):
		resultado.append({"id": "STORM_ACTIVE", "severity": "warning", "key": "WARN_STORM_ACTIVE", "values": []})
	return resultado


static func formatear(aviso: Dictionary) -> String:
	var valores = aviso.get("values", [])
	if str(aviso.get("key", "")) == "WARN_STORM_SOON" and valores is Array and not valores.is_empty():
		var horas := float(valores[0]) * 24.0
		if horas < 24.0:  # menos de un sol: se dice en horas, no «0.1 soles»
			return TranslationServer.translate("WARN_STORM_SOON_H") % maxi(1, ceili(horas))
	var texto := TranslationServer.translate(str(aviso.get("key", "")))
	if valores is Array and not valores.is_empty():
		texto = texto % valores
	return decimal(texto)


## En español los decimales llevan coma.
static func decimal(texto: String) -> String:
	if not TranslationServer.get_locale().begins_with("es"):
		return texto
	var er := RegEx.new()
	er.compile("(\\d)\\.(\\d)")
	return er.sub(texto, "$1,$2", true)
