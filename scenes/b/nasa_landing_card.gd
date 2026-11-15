extends CanvasLayer
## Tarjeta «Así lo hizo Perseverance» durante el lanzamiento y el aterrizaje: foto real de la NASA con su crédito,
## lo que eligió el jugador (cohete, trayectoria y días de crucero) y el dato real equivalente.
## Solo se muestra en la fase «landing»; no bloquea nada.

const UI := preload("res://scenes/b/ui_style.gd")
const NasaData := preload("res://scenes/b/nasa_data.gd")
const ANCHO := 360.0
const SEGUNDOS_POR_PAGINA := 3.5

var taller: Dictionary = {}  ## último snapshot del taller (lo pasa la vista de la misión)
var _panel: PanelContainer
var _foto: TextureRect
var _titulo: Label
var _texto: Label
var _credito: Label
var _pagina := 0
var _reloj := 0.0
var _activa := false


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.nave(UI.ALPHA_STRONG, UI.RADIUS_PANEL, 0.3, 1, 12, 12, UI.AMBER))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_panel, "tl", 24, 84, ANCHO, 0)
	add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(col)
	var etiqueta := UI.label(col, tr("NASA_CARD_TAG"), 12, UI.AMBER)
	UI.display(etiqueta, 700, 2)
	_foto = TextureRect.new()
	_foto.custom_minimum_size = Vector2(ANCHO - 24.0, 150)
	_foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_foto.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_foto)
	_credito = UI.label(col, "", 10, Color(UI.CREAM, 0.6))
	_credito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_titulo = UI.label(col, "", UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(_titulo, 700, 0)
	_texto = UI.label(col, "", 13, Color(UI.CREAM, 0.88))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size.x = ANCHO - 24.0
	_panel.visible = false


func update_snapshot(s: Dictionary) -> void:
	if s.has("workshop"):
		taller = s["workshop"]
	elif s.has("design_summary"):
		taller = s["design_summary"]
	var en_aterrizaje := str(s.get("phase", "")) == "landing" and not _secuencia_activa()
	if en_aterrizaje and not _activa:
		_activa = true
		_pagina = 0
		_reloj = 0.0
		_mostrar()
	elif not en_aterrizaje and _activa:
		_activa = false
		var t := create_tween()
		t.tween_property(_panel, "modulate:a", 0.0, 0.4)
		t.tween_callback(func() -> void: _panel.visible = false)


func _process(delta: float) -> void:
	if not _activa:
		return
	_reloj += delta
	if _reloj >= SEGUNDOS_POR_PAGINA and _pagina == 0:
		_pagina = 1
		_mostrar()


func _mostrar() -> void:
	_panel.visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.5)
	if _pagina == 0:
		_foto.texture = NasaData.imagen("lanzamiento")
		_credito.text = NasaData.credito("lanzamiento")
		_titulo.text = tr("NASA_CARD_LAUNCH")
		_texto.text = tr("NASA_CARD_LAUNCH_YOU") % [_nombre("cohetes"), _nombre("trayectoria"),
			int(taller.get("totals", {}).get("cruise_days", 0))] + "\n" + NasaData.dato("lanzamiento") + " " + NasaData.dato("crucero")
	else:
		_foto.texture = NasaData.imagen("aterrizaje")
		_credito.text = NasaData.credito("aterrizaje")
		_titulo.text = tr("NASA_CARD_LANDING")
		_texto.text = tr("NASA_CARD_LANDING_TEXT") + "\n" + NasaData.dato("aterrizaje")


## Nombre traducido de la pieza elegida en una categoría del taller.
func _nombre(categoria: String) -> String:
	var elegidas: Array = taller.get("selection", {}).get(categoria, [])
	if elegidas.is_empty():
		return "—"
	for cat in taller.get("categories", []):
		for parte in cat.get("parts", []):
			if str(parte.get("id", "")) == str(elegidas[0]):
				return tr(str(parte.get("name_key", "")))
	return str(elegidas[0])


## Mientras se ve la secuencia de lanzamiento y crucero, la tarjeta espera.
func _secuencia_activa() -> bool:
	var c := get_parent().get_node_or_null("LaunchCruise")
	return c != null and c.visible
