class_name OpcionesGraficos
extends VBoxContainer
## Controles de la configuración gráfica (los usan el menú principal y el menú de pausa): botones Baja, Media, Alta y
## Ultra, y debajo cada opción por separado. Cambiar una opción suelta convierte el ajuste en «Personalizada». Emite
## «cambiado» con la configuración completa; quien lo usa la aplica y la guarda (Graficos.guardar).
const UI := preload("res://scenes/b/ui_style.gd")
signal cambiado(g: Dictionary)
signal fps_cambiado(activo: bool)  ## «Mostrar FPS» (se guarda solo; no forma parte de los ajustes)

var g: Dictionary = {}
var _presets: Dictionary = {}  ## nombre -> Button
var _estado: Label
var _sombras: OptionButton
var _aa: OptionButton
var _distancia: OptionButton
var _resolucion: HSlider
var _cifra: Label
var _checks: Dictionary = {}  ## clave -> CheckButton
var _fps: CheckButton
var _poniendo := false
var _tam_texto := 16


func _init(inicial: Dictionary, tam_texto: int = 16) -> void:
	g = inicial.duplicate()
	_tam_texto = tam_texto
	add_theme_constant_override("separation", 8)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	add_child(fila)
	var grupo := ButtonGroup.new()
	grupo.allow_unpress = false
	for nombre in Graficos.ORDEN:
		var b := Button.new()
		b.text = TranslationServer.translate("GFX_" + nombre.to_upper())
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(92, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = TranslationServer.translate("GFX_" + nombre.to_upper() + "_TIP")
		b.pressed.connect(func() -> void: _elegir_preset(nombre))
		fila.add_child(b)
		_presets[nombre] = b
	_estado = UI.label(self, "", 13, Color(UI.AMBER, 0.9))
	_sombras = _opciones("GFX_SHADOWS", ["GFX_OFF", "GFX_NORMAL", "GFX_HIGH_Q"], "sombras")
	_aa = _opciones("GFX_AA", ["GFX_NO", "MSAA 2x", "MSAA 4x"], "aa")
	_distancia = _opciones("GFX_DISTANCE", ["GFX_SHORT", "GFX_NORMAL_D", "GFX_FAR"], "distancia")
	var fila_res := _fila("GFX_RESOLUTION")
	_resolucion = HSlider.new()
	_resolucion.min_value = 0.7
	_resolucion.max_value = 1.0
	_resolucion.step = 0.05
	_resolucion.custom_minimum_size = Vector2(170, 24)
	_resolucion.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resolucion.focus_mode = Control.FOCUS_NONE
	fila_res.add_child(_resolucion)
	_cifra = UI.label(fila_res, "", 14, Color(UI.CREAM, 0.8))
	_cifra.custom_minimum_size.x = 48
	_resolucion.value_changed.connect(func(v: float) -> void:
		_cifra.text = "%d%%" % roundi(v * 100.0)
		_cambiar("resolucion", v))
	for par in [["post", "GFX_POST"], ["texturas", "GFX_TEXTURES"], ["polvo", "GFX_DUST"], ["auto", "GFX_AUTO"]]:
		var f := _fila(par[1])
		var c := CheckButton.new()
		c.focus_mode = Control.FOCUS_NONE
		c.toggled.connect(func(on: bool) -> void: _cambiar(par[0], on))
		f.add_child(c)
		_checks[par[0]] = c
	var fila_fps := _fila("GFX_FPS")
	_fps = CheckButton.new()
	_fps.focus_mode = Control.FOCUS_NONE
	_fps.button_pressed = Graficos.mostrar_fps()
	_fps.toggled.connect(func(on: bool) -> void:
		if _poniendo:
			return
		Graficos.guardar_fps(on)
		fps_cambiado.emit(on))
	fila_fps.add_child(_fps)
	var nota := UI.label(self, TranslationServer.translate("GFX_NOTE"), 12, Color(UI.CREAM, 0.6))
	nota.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nota.custom_minimum_size.x = 360
	_mostrar()


func casilla_fps() -> CheckButton:
	return _fps


func _fila(clave: String) -> HBoxContainer:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	add_child(fila)
	var etiqueta := UI.label(fila, TranslationServer.translate(clave), _tam_texto, UI.CREAM)
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	etiqueta.tooltip_text = TranslationServer.translate(clave + "_TIP")
	etiqueta.mouse_filter = Control.MOUSE_FILTER_STOP
	return fila


func _opciones(clave: String, nombres: Array, campo: String) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.custom_minimum_size = Vector2(150, 34)
	for n in nombres:
		o.add_item(TranslationServer.translate(n))
	o.item_selected.connect(func(i: int) -> void: _cambiar(campo, i))
	_fila(clave).add_child(o)
	return o


func _elegir_preset(nombre: String) -> void:
	if _poniendo:
		return
	g = Graficos.de_preset(nombre)
	_mostrar()
	cambiado.emit(g.duplicate())


func _cambiar(campo: String, valor: Variant) -> void:
	if _poniendo:
		return
	g[campo] = valor
	g["preset"] = Graficos.preset_de(g)
	_mostrar()
	cambiado.emit(g.duplicate())


## Pone los controles según «g» sin emitir cambios.
func _mostrar() -> void:
	_poniendo = true
	var preset := Graficos.preset_de(g)
	for nombre in _presets:
		(_presets[nombre] as Button).set_pressed_no_signal(nombre == preset)
	_estado.text = TranslationServer.translate("GFX_CUSTOM") if preset == "personalizada" \
		else TranslationServer.translate("GFX_" + preset.to_upper() + "_TIP")
	_sombras.select(int(g["sombras"]))
	_aa.select(int(g["aa"]))
	_distancia.select(int(g["distancia"]))
	_resolucion.set_value_no_signal(float(g["resolucion"]))
	_cifra.text = "%d%%" % roundi(float(g["resolucion"]) * 100.0)
	for clave in _checks:
		(_checks[clave] as CheckButton).set_pressed_no_signal(bool(g[clave]))
	_poniendo = false
