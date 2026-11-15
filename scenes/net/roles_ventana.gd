extends CanvasLayer
## Ventana «¿Qué hace cada rol?» del multijugador: una tarjeta por rol con una imagen real del juego, qué elige en el taller y qué
## hace durante la misión. Se abre desde la sala de espera y desde el panel de rol del taller. Solo presenta: los permisos reales
## están en permisos.gd y los hace cumplir el anfitrión.
const UI := preload("res://scenes/b/ui_style.gd")
const Permisos := preload("res://scenes/net/permisos.gd")
const TutorialPanel := preload("res://scenes/b/tutorial_panel.gd")

## Rol -> captura real del juego (assets/tutorial/<destino>/<idioma>/<paso>.jpg) que muestra lo que hace.
const IMAGEN_DE_ROL := {"direccion": "mover", "ingenieria": "panel", "ciencia": "analizar", "comunicaciones": "transmitir"}
const ICONO_DE_ROL := {"direccion": "rocket", "ingenieria": "chassis", "ciencia": "flask", "comunicaciones": "antenna"}
const ROLES: Array[String] = ["direccion", "ingenieria", "ciencia", "comunicaciones"]


func _ready() -> void:
	layer = 30
	var raiz := Control.new()
	raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.theme = UI.theme()
	add_child(raiz)
	var velo := ColorRect.new()
	velo.color = Color(UI.SURFACE, 0.82)
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(velo)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", UI.nave(0.97, UI.RADIUS_PANEL, 0.45, 1, 22, 16, UI.AMBER))
	UI.place(marco, "c", 0, 0, 1120, 0)
	raiz.add_child(marco)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	marco.add_child(col)
	var titulo := UI.label(col, tr("NET_RW_TITLE"), UI.FONT_PANEL_TITLE, UI.CREAM)
	UI.display(titulo, 700, 2)
	var intro := UI.label(col, tr("NET_RW_INTRO"), 14, Color(UI.CREAM, 0.85))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var rejilla := GridContainer.new()
	rejilla.columns = 2
	rejilla.add_theme_constant_override("h_separation", 14)
	rejilla.add_theme_constant_override("v_separation", 12)
	col.add_child(rejilla)
	for rol in ROLES:
		rejilla.add_child(_tarjeta(rol))
	var pie := UI.label(col, tr("NET_RW_ALL"), 13, Color(UI.CREAM, 0.7))
	pie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cerrar := Button.new()
	cerrar.text = tr("NET_RW_CLOSE")
	cerrar.theme_type_variation = "PrimaryButton"
	cerrar.custom_minimum_size = Vector2(180, 40)
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_END
	cerrar.focus_mode = Control.FOCUS_NONE
	cerrar.pressed.connect(queue_free)
	col.add_child(cerrar)


func _tarjeta(rol: String) -> Control:
	var tarjeta := PanelContainer.new()
	tarjeta.add_theme_stylebox_override("panel", UI.box(0.55, UI.RADIUS_LABEL, 0.3, 1, 10, 8, UI.AMBER))
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	tarjeta.add_child(fila)
	var idioma := "en" if TranslationServer.get_locale().begins_with("en") else "es"
	var imagen := TextureRect.new()
	imagen.custom_minimum_size = Vector2(230, 130)
	imagen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	imagen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var ruta := TutorialPanel.ruta_captura(str(IMAGEN_DE_ROL[rol]), Destino.id, idioma)
	if not ruta.is_empty():
		imagen.texture = load(ruta)
	fila.add_child(imagen)
	var texto := VBoxContainer.new()
	texto.add_theme_constant_override("separation", 3)
	texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(texto)
	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	texto.add_child(cabecera)
	var Icon := preload("res://scenes/b/hud_icon.gd")
	cabecera.add_child(Icon.make(str(ICONO_DE_ROL[rol]), 18, UI.AMBER))
	var nombre := UI.label(cabecera, tr("NET_R_" + rol.to_upper()), UI.FONT_TEXT, UI.AMBER)
	UI.display(nombre, 700, 1)
	_linea(texto, tr("NET_RW_WORKSHOP"), tr("NET_RW_" + rol.to_upper() + "_WORKSHOP"))
	_linea(texto, tr("NET_RW_MISSION"), tr("NET_RW_" + rol.to_upper() + "_MISSION"))
	return tarjeta


func _linea(padre: Node, etiqueta: String, valor: String) -> void:
	var l := UI.label(padre, "%s %s" % [etiqueta, valor], 13, Color(UI.CREAM, 0.9))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 300


## Abre la ventana encima de «padre» (el menú, el taller...). Una sola a la vez.
static func abrir(padre: Node) -> void:
	for hijo in padre.get_children():
		if hijo.get_script() == preload("res://scenes/net/roles_ventana.gd"):
			return
	padre.add_child(preload("res://scenes/net/roles_ventana.gd").new())
