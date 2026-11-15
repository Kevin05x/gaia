extends CanvasLayer
## Tarjeta de objetivo (plan de mejoras 2.1): al empezar las operaciones de una partida nueva, una sola tarjeta con la
## meta («Envía 100 datos a la Tierra antes de que acabe el sol 6») y las tres cosas que la hacen posible: energía,
## instrumentos y antena con su ventana de enlace. La meta y el sol límite salen del snapshot (content/rules.json);
## los textos de la Luna los cambia Destino.aplicar_textos() (content/destinos.json › luna › textos).
## Solo muestra: no cambia nada de la simulación.

const UI := preload("res://scenes/b/ui_style.gd")
const Icon := preload("res://scenes/b/hud_icon.gd")

signal closed

var tapada: Callable  ## true mientras otra ventana (escena de la historia, imprevisto) ocupa la pantalla: espera
var _raiz: Control
var _vista := false  ## ya se mostró en esta partida


func _ready() -> void:
	layer = 7


func is_open() -> bool:
	return is_instance_valid(_raiz)


## Se muestra una vez, en la primera foto de las operaciones de una partida que empieza (sol 1, nada enviado ni en
## memoria): al «Continuar» una partida avanzada no vuelve a salir.
func update_snapshot(s: Dictionary) -> void:
	if _vista or is_open() or str(s.get("phase", "")) != "operations":
		return
	if int(s.get("sol", 1)) > 1 or float(s.get("sent", 0.0)) > 0.0 or float(s.get("data", 0.0)) > 0.0:
		_vista = true  # partida ya empezada
		return
	if tapada.is_valid() and tapada.call():
		return  # se vuelve a intentar con la siguiente foto
	_vista = true
	_construir(int(s.get("goal", 100)), int(s.get("sol_limit", 6)))


func cerrar() -> void:
	if is_instance_valid(_raiz):
		_raiz.queue_free()
	_raiz = null
	closed.emit()


func _construir(meta: int, sol_limite: int) -> void:
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
	caja.add_theme_stylebox_override("panel", UI.box(0.97, 14, 0.45, 1, 28, 22, UI.AMBER))
	UI.place(caja, "c", 0, 0, 620, 0)
	_raiz.add_child(caja)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	caja.add_child(col)
	UI.display(UI.label(col, tr("OBJ_TAG"), 12, UI.AMBER), 700, 3)
	var meta_txt := UI.label(col, tr("OBJ_GOAL") % [meta, sol_limite], 22, UI.CREAM)
	UI.display(meta_txt, 700, 1)
	meta_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	meta_txt.custom_minimum_size.x = 560
	var intro := UI.label(col, tr("OBJ_INTRO"), 14, Color(UI.CREAM, 0.8))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size.x = 560
	for paso in [["bolt", "OBJ_STEP1"], ["flask", "OBJ_STEP2"], ["antenna", "OBJ_STEP3"]]:
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 14)
		col.add_child(fila)
		var icono := Icon.make(str(paso[0]), 26, UI.AMBER)
		icono.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		fila.add_child(icono)
		var textos := VBoxContainer.new()
		textos.add_theme_constant_override("separation", 2)
		textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(textos)
		UI.display(UI.label(textos, tr(str(paso[1]) + "_T"), 15, UI.CREAM), 700, 1)
		var detalle := UI.label(textos, tr(str(paso[1])), 14, Color(UI.CREAM, 0.85))
		detalle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalle.custom_minimum_size.x = 500
	var ok := Button.new()
	ok.text = tr("OBJ_OK")
	ok.theme_type_variation = "PrimaryButton"
	ok.custom_minimum_size = Vector2(200, 44)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(cerrar)
	col.add_child(ok)
	caja.modulate.a = 0.0
	create_tween().tween_property(caja, "modulate:a", 1.0, 0.3)


func _unhandled_input(e: InputEvent) -> void:
	if is_open() and e is InputEventKey and e.pressed and not e.echo \
			and e.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		cerrar()
