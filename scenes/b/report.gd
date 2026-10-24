extends CanvasLayer
## Informe final (960×592 sobre la escena atenuada). Muestra lo que entrega la simulación:
## resultado, estrellas, causas y foto con crédito; si la foto falla usa la ilustración original en el mismo espacio.
const UI := preload("res://scenes/b/ui_style.gd")
signal redesign_requested
var root: Control
var report: Dictionary = {}


func _ready() -> void:
	layer = 10


func show_report(data: Dictionary) -> void:
	report = data.duplicate(true)
	rebuild()


func rebuild() -> void:
	if is_instance_valid(root):
		remove_child(root)
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	add_child(root)
	var atenuacion := ColorRect.new()
	atenuacion.color = Color(UI.SURFACE, 0.55)
	atenuacion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(atenuacion)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.ALPHA_STRONG, UI.RADIUS_PANEL, 0.25, 1, 0, 0))
	UI.place(panel, "c", 0, 0, 960, 592)
	root.add_child(panel)
	var lienzo := Control.new()
	panel.add_child(lienzo)
	var exito := bool(report.get("success", false))
	var resultado := Label.new()
	resultado.text = tr("WIN" if exito else "LOSE")
	resultado.add_theme_font_size_override("font_size", 30)
	var medio := UI.display_font(600)
	if medio != null:
		resultado.add_theme_font_override("font", medio)
	resultado.add_theme_color_override("font_color", UI.TEAL if exito else UI.WARN)
	resultado.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	resultado.position = Vector2(24, 24)
	resultado.size = Vector2(912, 52)
	lienzo.add_child(resultado)
	var datos := UI.label(lienzo, tr("REPORT_STATS") % [report.get("sent", 0), report.get("goal", 100), report.get("sol", 1)], UI.FONT_TEXT, Color(UI.CREAM, 0.85))
	datos.position = Vector2(24, 74)
	var textura := TextureRect.new()
	textura.position = Vector2(24, 106)
	textura.size = Vector2(520, 292)
	textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	textura.texture = report.get("photo") if report.get("photo") is Texture2D else preload("res://scenes/b/assets/jezero.svg")
	lienzo.add_child(textura)
	var credito := UI.label(lienzo, str(report.get("photo_credit", tr("PHOTO_FALLBACK"))), 13, Color(UI.CREAM, 0.75))
	credito.position = Vector2(24, 408)
	credito.size = Vector2(520, 40)
	credito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var fuente := str(report.get("photo_url", ""))
	if fuente.begins_with("https://"):
		var enlace := LinkButton.new()
		enlace.text = tr("PHOTO_SOURCE")
		enlace.position = Vector2(24, 450)
		lienzo.add_child(enlace)
		enlace.pressed.connect(func(): OS.shell_open(fuente))
	var estrellas := preload("res://scenes/b/stars.gd").new()
	estrellas.stars = clampi(int(report.get("stars", 0)), 0, 3)
	estrellas.position = Vector2(568, 112)
	estrellas.size = Vector2(368, 48)
	lienzo.add_child(estrellas)
	var titulo := UI.label(lienzo, tr("CAUSES"), UI.FONT_SECONDARY, UI.AMBER)
	titulo.position = Vector2(568, 168)
	var desplazable := ScrollContainer.new()
	desplazable.position = Vector2(568, 196)
	desplazable.size = Vector2(368, 204)
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lienzo.add_child(desplazable)
	var causas := VBoxContainer.new()
	causas.add_theme_constant_override("separation", 10)
	causas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazable.add_child(causas)
	for entrada in report.get("causes", []):
		var texto := tr(str(entrada.get("key", ""))) if entrada is Dictionary else tr(str(entrada))
		if entrada is Dictionary and entrada.has("values"):
			texto = texto % entrada["values"]
		var linea := UI.label(causas, "• " + texto, UI.FONT_TEXT)
		linea.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		linea.custom_minimum_size.x = 340
	var creditos := UI.label(lienzo, tr("CREDITS"), 12, Color(UI.CREAM, 0.6))
	creditos.position = Vector2(24, 548)
	creditos.size = Vector2(700, 30)
	creditos.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var boton_rediseno := Button.new()
	boton_rediseno.theme_type_variation = "PrimaryButton"
	boton_rediseno.text = tr("REDESIGN_SHORT")
	boton_rediseno.size = Vector2(180, 44)
	boton_rediseno.position = Vector2(960 - 24 - 180, 592 - 24 - 44)
	boton_rediseno.clip_text = true
	lienzo.add_child(boton_rediseno)
	boton_rediseno.pressed.connect(func(): redesign_requested.emit())
	boton_rediseno.grab_focus.call_deferred()


func clear() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	report.clear()
