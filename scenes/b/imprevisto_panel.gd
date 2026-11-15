extends CanvasLayer
## Ventana de imprevisto de misión: aparece cuando la simulación detiene el tiempo por algo inesperado (conjunción solar,
## rueda atrapada, partículas solares...). Muestra qué pasa, el hecho real en que se basa y dos opciones con sus
## consecuencias. En modo equipo invita a decidir juntos. Solo envía la orden «event_choice»; no calcula nada.

const UI := preload("res://scenes/b/ui_style.gd")
const Sesion := preload("res://scenes/menu/game_session.gd")

signal command(command: String, payload: Dictionary)
signal opened

var _raiz: Control
var _id := ""


func _ready() -> void:
	layer = 8


func is_open() -> bool:
	return is_instance_valid(_raiz)


func update_snapshot(s: Dictionary) -> void:
	var dato: Dictionary = s.get("unexpected", {})
	var id := str(dato.get("id", ""))
	if id == _id:
		return
	_id = id
	if is_instance_valid(_raiz):
		_raiz.queue_free()
		_raiz = null
	if not id.is_empty():
		_construir(dato)
		opened.emit()


## Frase con lo que cambió una decisión («applied» de la simulación), en el idioma de quien la lee:
## «-90 Wh de batería · +10 datos en memoria: transmítelos en la próxima ventana · el rover va al punto marcado».
static func resumen(aplicado: Dictionary) -> String:
	var partes: PackedStringArray = []
	var energia := roundi(float(aplicado.get("energia_wh", 0.0)))
	if energia != 0:
		partes.append(TranslationServer.translate("UNEXP_ENERGY") % energia)
	var datos := roundi(float(aplicado.get("datos", 0.0)))
	if datos > 0:
		partes.append(TranslationServer.translate("UNEXP_DATA_IN") % datos)
	elif datos < 0:
		partes.append(TranslationServer.translate("UNEXP_DATA_OUT") % -datos)
	var perdidos := roundi(float(aplicado.get("datos_perdidos", 0.0)))
	if perdidos > 0:
		partes.append(TranslationServer.translate("UNEXP_DATA_LOST") % perdidos)
	var vida := roundi(float(aplicado.get("rover_hp", 0.0)))
	if vida != 0:
		partes.append(TranslationServer.translate("UNEXP_HP") % vida)
	if aplicado.has("bloquear_enlace_h"):
		partes.append(TranslationServer.translate("UNEXP_LINK") % roundi(float(aplicado["bloquear_enlace_h"])))
	if aplicado.has("bloquear_movimiento_h"):
		partes.append(TranslationServer.translate("UNEXP_MOVE") % roundi(float(aplicado["bloquear_movimiento_h"])))
	if aplicado.has("detour_tile"):
		partes.append(TranslationServer.translate("UNEXP_DETOUR"))
	elif aplicado.has("detour_reason"):
		partes.append(TranslationServer.translate("UNEXP_NO_DETOUR"))
	if partes.is_empty():
		partes.append(TranslationServer.translate("UNEXP_NOTHING"))
	return " · ".join(partes)


func _texto(d: Variant) -> String:
	if d is Dictionary:
		return str(d.get("en" if TranslationServer.get_locale().begins_with("en") else "es", d.get("es", "")))
	return str(d)


func _construir(dato: Dictionary) -> void:
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = UI.theme()
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_raiz)
	var tapa := ColorRect.new()
	tapa.color = Color(0.03, 0.02, 0.02, 0.55)
	tapa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.add_child(tapa)
	var caja := PanelContainer.new()
	caja.add_theme_stylebox_override("panel", UI.box(0.97, 14, 0.45, 1, 28, 22, UI.WARN))
	UI.place(caja, "c", 0, 0, 640, 0)
	_raiz.add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	caja.add_child(col)
	var etiqueta := UI.label(col, tr("EVT_TAG"), 12, UI.WARN)
	UI.display(etiqueta, 700, 3)
	var titulo := UI.label(col, _texto(dato.get("title", {})), 26, UI.CREAM)
	UI.display(titulo, 700, 1)
	var texto := UI.label(col, _texto(dato.get("text", {})), 16, Color(UI.CREAM, 0.92))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 580
	var real := UI.label(col, _texto(dato.get("real", {})), 13, UI.TEAL)
	real.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	real.custom_minimum_size.x = 580
	var fuente := UI.label(col, tr("EVT_SOURCE") % str(dato.get("source", "")), 11, Color(UI.CREAM, 0.5))
	fuente.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if int(Sesion.jugadores) > 1:
		var equipo := UI.label(col, tr("EVT_TEAM"), 13, UI.AMBER)
		equipo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		equipo.custom_minimum_size.x = 580
	var opciones: Array = dato.get("options", [])
	for i in range(opciones.size()):
		var b := Button.new()
		b.text = _texto(opciones[i])
		b.custom_minimum_size = Vector2(580, 44)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == 0:
			b.theme_type_variation = "PrimaryButton"
		b.pressed.connect(func() -> void: command.emit("event_choice", {"choice": i}))
		col.add_child(b)
	caja.modulate.a = 0.0
	caja.scale = Vector2(0.96, 0.96)
	caja.resized.connect(func() -> void: caja.pivot_offset = caja.size / 2.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(caja, "modulate:a", 1.0, 0.25)
	tw.tween_property(caja, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
