extends CanvasLayer
## Informe final (960×592 sobre la escena atenuada). Muestra lo que entrega la simulación:
## resultado, estrellas, causas y foto con crédito; si la foto falla usa la ilustración original en el mismo espacio.
const UI := preload("res://scenes/b/ui_style.gd")
const StoryPanel := preload("res://scenes/b/story_panel.gd")
signal redesign_requested
var root: Control
var report: Dictionary = {}
var taller: Dictionary = {}  ## último diseño del taller: lo usa la comparación con la misión real


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
	if report.has("ending"):
		_ending(lienzo)
	else:
		_photo(lienzo)
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
	var registro: Array = report.get("story_log", [])
	if not registro.is_empty():
		var cabecera := UI.label(causas, tr("DECISIONS_LOG"), UI.FONT_SECONDARY, UI.AMBER)
		cabecera.custom_minimum_size.y = 26
		for entrada in registro:
			var paso := UI.label(causas, "• " + StoryPanel.text_of(entrada), UI.FONT_SECONDARY, Color(UI.CREAM, 0.85))
			paso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			paso.custom_minimum_size.x = 340
	_imprevistos(causas)
	_equipo(causas)
	var creditos := UI.label(lienzo, tr("CREDITS"), 12, Color(UI.CREAM, 0.6))
	creditos.position = Vector2(24, 548)
	creditos.size = Vector2(440, 30)
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
	var boton_real := Button.new()
	boton_real.text = tr("CMP_OPEN")
	boton_real.size = Vector2(250, 44)
	boton_real.position = Vector2(960 - 24 - 180 - 12 - 250, 592 - 24 - 44)
	boton_real.clip_text = true
	lienzo.add_child(boton_real)
	boton_real.pressed.connect(_comparar.bind(panel))


## Imprevistos de la misión y lo que decidió el equipo en cada uno.
func _imprevistos(causas: VBoxContainer) -> void:
	var hechos: Array = report.get("events", [])
	if hechos.is_empty():
		return
	var datos: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/imprevistos.json"))
	var lista: Dictionary = {}
	for item in (datos.get("imprevistos", []) if datos is Dictionary else []):
		lista[str(item.get("id", ""))] = item
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var cabecera := UI.label(causas, tr("EVT_REPORT"), UI.FONT_SECONDARY, UI.AMBER)
	cabecera.custom_minimum_size.y = 26
	for h in hechos:
		var item: Dictionary = lista.get(str(h.get("id", "")), {})
		var opciones: Array = item.get("opciones", [])
		var eleccion := int(h.get("choice", 0))
		var opcion := str(opciones[eleccion].get("texto", {}).get(idioma, "")) if eleccion < opciones.size() else ""
		var l := UI.label(causas, "• %s: %s" % [str(item.get("titulo", {}).get(idioma, h.get("id", ""))), opcion], UI.FONT_SECONDARY, Color(UI.CREAM, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 340


## Evaluación por roles: qué aportó cada responsable (dirección, ingeniería, ciencia y comunicaciones).
func _equipo(causas: VBoxContainer) -> void:
	var t: Dictionary = taller.get("totals", {})
	var cabecera := UI.label(causas, tr("TEAM_TITLE"), UI.FONT_SECONDARY, UI.AMBER)
	cabecera.custom_minimum_size.y = 26
	var equipo: Dictionary = report.get("team", {})
	var jugadores := int(equipo.get("players", 1))
	var dificultad := tr("DIFF_" + str(report.get("difficulty", "estandar")).to_upper())
	var lineas: Array[String] = [tr("TEAM_SUMMARY") % [jugadores, dificultad] if jugadores > 1 else tr("TEAM_SOLO") % dificultad]
	if not t.is_empty():
		var cap := float(t.get("capacity_kg", 0))
		var margen := 0 if cap <= 0.0 else int(round((cap - float(t.get("mass_kg", 0))) / cap * 100.0))
		lineas.append(tr("TEAM_DIR") % int(float(t.get("budget_musd", 0)) - float(t.get("cost_musd", 0))))
		lineas.append(tr("TEAM_ENG") % margen)
	lineas.append(tr("TEAM_SCI") % [int(report.get("sent", 0)), int(report.get("goal", 100))])
	var enlace: Array = taller.get("selection", {}).get("comunicaciones", [])
	if not enlace.is_empty():
		lineas.append(tr("TEAM_COM") % tr("PIEZA_ANTENA_RELE" if enlace.has("antena_rele") else "PIEZA_ANTENA_DIRECTA").to_lower())
	var votos: Array = equipo.get("votes", [])
	if jugadores > 1 and not votos.is_empty():
		var a_favor := 0
		for v in votos:
			if bool(v.get("go", false)):
				a_favor += 1
		lineas.append(tr("TEAM_VOTES") % [a_favor, votos.size()])
	for texto in lineas:
		var l := UI.label(causas, "• " + texto, UI.FONT_SECONDARY, Color(UI.CREAM, 0.85))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 340


## Abre «Tu misión frente a la real» encima del informe, en el mismo panel.
func _comparar(panel: Control) -> void:
	var comparar := preload("res://scenes/b/nasa_compare.gd").new()
	comparar.report = report
	comparar.taller = taller
	panel.add_child(comparar)
	comparar.build()
	comparar.closed.connect(func() -> void: comparar.queue_free())


func clear() -> void:
	if is_instance_valid(root):
		root.queue_free()
		root = null
	report.clear()


## Foto del cráter con su crédito (partida sin historia).
func _photo(lienzo: Control) -> void:
	var textura := TextureRect.new()
	textura.position = Vector2(24, 106)
	textura.size = Vector2(520, 292)
	textura.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	textura.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var NasaData := preload("res://scenes/b/nasa_data.gd")
	var real := NasaData.imagen("selfie")
	if not (report.get("photo") is Texture2D) and real != null:
		report["photo"] = real
		report["photo_credit"] = NasaData.credito("selfie")
		report["photo_url"] = NasaData.url_imagen("selfie")
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


## Final de la historia: título, relato, ética y vida de Rocky en el espacio de la foto.
func _ending(lienzo: Control) -> void:
	var final: Dictionary = report.get("ending", {})
	var exito := bool(report.get("success", false))
	var arriba := 112.0
	var textura := StoryPanel.image_of(str(final.get("image", "")))
	if textura != null:
		var imagen := TextureRect.new()
		imagen.texture = textura
		imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		imagen.position = Vector2(24, 106)
		imagen.size = Vector2(520, 180)
		lienzo.add_child(imagen)
		arriba = 296.0
	var titulo := UI.label(lienzo, StoryPanel.text_of(final.get("title", {})), 22, UI.TEAL if exito else UI.WARN)
	UI.display(titulo, 700, 1)
	titulo.position = Vector2(24, arriba)
	titulo.size = Vector2(520, 32)
	var desplazable := ScrollContainer.new()
	desplazable.position = Vector2(24, arriba + 38.0)
	desplazable.size = Vector2(520, 446.0 - arriba - 38.0)
	desplazable.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lienzo.add_child(desplazable)
	var texto := UI.label(desplazable, StoryPanel.text_of(final.get("text", {})), UI.FONT_TEXT, Color(UI.CREAM, 0.92))
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texto.custom_minimum_size.x = 500
	var datos := UI.label(lienzo, tr("ENDING_STATS") % [roundi(float(report.get("ethics", 50.0))), roundi(float(report.get("rocky_hp", 100.0)))],
		UI.FONT_SECONDARY, UI.AMBER)
	datos.position = Vector2(24, 452)
