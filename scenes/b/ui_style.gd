extends RefCounted
## Tema cálido de GAIA según el diseño visual consolidado (superficie marrón translúcida, texto crema).
## Todo el estilo de la interfaz sale de aquí: HUD, pausa e informe usan estas constantes y este tema.

const SURFACE := Color("2E1E16")
const CREAM := Color("FFF5E4")
const AMBER := Color("F0C079")
const TEAL := Color("9AD7C6")
const WARN := Color("F2AF7A")
const CORAL := Color("FF8178")
const TARGET_LIGHT := Color("FBE0AC")
const BORDER_DARK := Color("3F2D2B")
const SHADOW := Color(0.043, 0.031, 0.02, 0.5)

## Nombres antiguos que aún usan el informe y las estrellas.
const INK := SURFACE
const TEXT := CREAM
const MUTED := Color(1.0, 0.961, 0.894, 0.72)
const ORANGE := AMBER
const GREEN := TEAL

const RADIUS_PILL := 18
const RADIUS_BUTTON := 10
const RADIUS_PANEL := 12
const RADIUS_LABEL := 8

const ALPHA_NORMAL := 0.55
const ALPHA_STRONG := 0.70
const ALPHA_PRESSED := 0.80

const FONT_TITLE := 22
const FONT_OBJECTIVE := 14
const FONT_PANEL_TITLE := 18
const FONT_FIGURE := 17
const FONT_TEXT := 16
const FONT_SECONDARY := 14

## Etiqueta OpenType del eje de grosor («wght») de las fuentes variables.
const WGHT := 0x77676874

static var _fonts: Dictionary = {}


## Fuente del proyecto si el archivo existe en res://assets/fonts/; null si no (se usa la de Godot).
static func font(archivo: String) -> Font:
	if not _fonts.has(archivo):
		var ruta := "res://assets/fonts/%s" % archivo
		_fonts[archivo] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _fonts[archivo]


## Texto corriente: Inter (variable) con el grosor pedido. Si falta el archivo se usa la fuente de Godot.
static func text_font(peso: int = 450) -> Font:
	return _variable("text%d" % peso, "Inter.ttf", peso, 0)


## Títulos, cifras y etiquetas: Space Grotesk (variable) con grosor y separación entre letras.
static func display_font(peso: int = 600, separacion: int = 0) -> Font:
	return _variable("display%d_%d" % [peso, separacion], "SpaceGrotesk.ttf", peso, separacion)


static func _variable(clave: String, archivo: String, peso: int, separacion: int) -> Font:
	if _fonts.has(clave):
		return _fonts[clave]
	var base := font(archivo)
	var v := FontVariation.new()
	v.base_font = base if base != null else ThemeDB.fallback_font
	if base != null:
		v.variation_opentype = {WGHT: peso}
	v.spacing_glyph = separacion
	_fonts[clave] = v
	return v


## Compatibilidad: fuente con separación entre letras (título «G A I A»).
static func spaced_font(extra_px: int, _archivo: String = "") -> Font:
	return display_font(600, extra_px)


## Rótulo de cifras y títulos con la fuente de display.
static func display(l: Label, peso: int = 600, separacion: int = 0) -> void:
	l.add_theme_font_override("font", display_font(peso, separacion))


static func box(alpha: float = ALPHA_NORMAL, radius: int = RADIUS_PANEL, border_alpha: float = 0.25, border_px: int = 1,
		margin_x: float = 12.0, margin_y: float = 6.0, border_color: Color = CREAM) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(SURFACE, alpha)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_px if border_alpha > 0.0 else 0)
	s.border_color = Color(border_color, border_alpha)
	s.content_margin_left = margin_x
	s.content_margin_right = margin_x
	s.content_margin_top = margin_y
	s.content_margin_bottom = margin_y
	s.anti_aliasing = true
	return s


## Compatibilidad con el código anterior: color liso, radio y margen.
static func style(color: Color, radius: int = 12, margin: int = 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


## Caja de botón: relleno cálido, borde fino, sombra suave y esquinas suaves.
static func button_box(relleno: Color, borde: Color, borde_px: int, radius: int, mx: float, my: float, sombra: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = relleno
	s.set_corner_radius_all(radius)
	s.set_border_width_all(borde_px if borde.a > 0.0 else 0)
	s.border_color = borde
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.anti_aliasing = true
	if sombra > 0:
		s.shadow_size = sombra
		s.shadow_color = Color(0.05, 0.03, 0.02, 0.35)
		s.shadow_offset = Vector2(0, 2)
	return s


static func _focus(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.draw_center = false
	s.set_border_width_all(2)
	s.border_color = Color(AMBER, 0.95)
	s.set_corner_radius_all(radius)
	s.set_expand_margin_all(3)
	return s


static func _button_states(t: Theme, tipo: String, radius: int, mx: float, my: float) -> void:
	t.set_stylebox("normal", tipo, button_box(Color("4A3629", 0.82), Color(CREAM, 0.22), 1, radius, mx, my))
	t.set_stylebox("hover", tipo, button_box(Color("5E4433", 0.93), Color(AMBER, 0.75), 1, radius, mx, my, 5))
	t.set_stylebox("pressed", tipo, button_box(Color("2B1D15", 0.95), Color(AMBER, 1.0), 2, radius, mx, my, 0))
	t.set_stylebox("disabled", tipo, button_box(Color("3A2A20", 0.5), Color(CREAM, 0.1), 1, radius, mx, my, 0))
	t.set_stylebox("focus", tipo, _focus(radius))
	t.set_color("font_color", tipo, CREAM)
	t.set_color("font_hover_color", tipo, Color.WHITE)
	t.set_color("font_pressed_color", tipo, AMBER)
	t.set_color("font_focus_color", tipo, CREAM)
	t.set_color("font_disabled_color", tipo, Color(CREAM, 0.5))


## Botón principal (acción que avanza): relleno ámbar y texto oscuro.
static func _primary_states(t: Theme, tipo: String, radius: int, mx: float, my: float) -> void:
	t.set_stylebox("normal", tipo, button_box(Color("EDBB6B"), Color("FFE3B0", 0.55), 1, radius, mx, my, 4))
	t.set_stylebox("hover", tipo, button_box(Color("F8CF8B"), Color("FFF0D0", 0.8), 1, radius, mx, my, 6))
	t.set_stylebox("pressed", tipo, button_box(Color("C99650"), Color("FFE3B0", 0.9), 2, radius, mx, my, 0))
	t.set_stylebox("disabled", tipo, button_box(Color("5F4E3B", 0.65), Color(CREAM, 0.1), 1, radius, mx, my, 0))
	t.set_stylebox("focus", tipo, _focus(radius))
	for estado in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(estado, tipo, Color("2A1A10"))
	t.set_color("font_disabled_color", tipo, Color(CREAM, 0.5))


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_TEXT
	t.default_font = text_font(450)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_shadow_color", "Label", SHADOW)
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_stylebox("panel", "PanelContainer", box(ALPHA_STRONG, RADIUS_PANEL, 0.22, 1, 16, 14))

	_button_states(t, "Button", RADIUS_BUTTON, 14, 6)
	t.set_font("font", "Button", text_font(560))
	t.set_font_size("font_size", "Button", FONT_TEXT)
	# Botón principal (relleno ámbar).
	t.add_type("PrimaryButton")
	t.set_type_variation("PrimaryButton", "Button")
	_primary_states(t, "PrimaryButton", RADIUS_BUTTON, 18, 8)
	t.set_font_size("font_size", "PrimaryButton", FONT_TEXT)
	t.add_type("PrimaryPill")
	t.set_type_variation("PrimaryPill", "Button")
	_primary_states(t, "PrimaryPill", RADIUS_PILL, 16, 4)
	# Interruptores: el estado lo muestra el propio interruptor, no el marco del botón.
	for tipo in ["CheckButton", "CheckBox"]:
		var reposo := button_box(Color("3A2A20", 0.6), Color(CREAM, 0.18), 1, RADIUS_BUTTON, 14, 6, 0)
		var encima := button_box(Color("4A3629", 0.8), Color(AMBER, 0.55), 1, RADIUS_BUTTON, 14, 6, 0)
		t.set_stylebox("normal", tipo, reposo)
		t.set_stylebox("pressed", tipo, reposo)
		t.set_stylebox("hover", tipo, encima)
		t.set_stylebox("hover_pressed", tipo, encima)
		t.set_stylebox("focus", tipo, _focus(RADIUS_BUTTON))
		t.set_color("font_color", tipo, CREAM)
		t.set_color("font_hover_color", tipo, Color.WHITE)
		t.set_color("font_pressed_color", tipo, CREAM)
		t.set_color("font_hover_pressed_color", tipo, Color.WHITE)
	# Píldora (radio 18).
	t.add_type("PillButton")
	t.set_type_variation("PillButton", "Button")
	_button_states(t, "PillButton", RADIUS_PILL, 13, 4)
	# Etiqueta contextual: mitad izquierda y mitad derecha (radio 8).
	for par in [["LabelLeft", [RADIUS_LABEL, 0, 0, RADIUS_LABEL]], ["LabelRight", [0, RADIUS_LABEL, RADIUS_LABEL, 0]]]:
		var tipo: String = par[0]
		t.add_type(tipo)
		t.set_type_variation(tipo, "Button")
		_button_states(t, tipo, RADIUS_LABEL, 8, 4)
		for estado in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxFlat = t.get_stylebox(estado, tipo)
			var r: Array = par[1]
			sb.corner_radius_top_left = r[0]
			sb.corner_radius_top_right = r[1]
			sb.corner_radius_bottom_right = r[2]
			sb.corner_radius_bottom_left = r[3]
		t.set_font_size("font_size", tipo, FONT_SECONDARY)
	# Fila de lista (40 px). La variante con motivo deja sitio para la segunda línea.
	t.add_type("RowButton")
	t.set_type_variation("RowButton", "Button")
	_button_states(t, "RowButton", 6, 12, 2)
	t.set_font_size("font_size", "RowButton", FONT_SECONDARY)
	t.add_type("RowButtonReason")
	t.set_type_variation("RowButtonReason", "RowButton")
	_button_states(t, "RowButtonReason", 6, 12, 2)
	for estado in ["normal", "hover", "pressed", "disabled"]:
		var sbr: StyleBoxFlat = t.get_stylebox(estado, "RowButtonReason")
		sbr.content_margin_top = 3
		sbr.content_margin_bottom = 17
	t.set_font_size("font_size", "RowButtonReason", FONT_SECONDARY)
	# Botón plano para iconos.
	t.add_type("IconButton")
	t.set_type_variation("IconButton", "Button")
	_button_states(t, "IconButton", RADIUS_PILL, 0, 0)

	t.set_stylebox("background", "ProgressBar", box(0.35, 4, 0.0, 0, 0, 0))
	var relleno := box(0.95, 4, 0.0, 0, 0, 0)
	relleno.bg_color = TEAL
	t.set_stylebox("fill", "ProgressBar", relleno)
	# Deslizador y casillas.
	var pista := box(0.55, 3, 0.25, 1, 0, 0)
	pista.content_margin_top = 3
	pista.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", pista)
	var avance := box(0.95, 3, 0.0, 0, 0, 0)
	avance.bg_color = AMBER
	t.set_stylebox("grabber_area", "HSlider", avance)
	t.set_stylebox("grabber_area_highlight", "HSlider", avance)
	t.set_color("font_color", "CheckButton", CREAM)
	t.set_color("font_hover_color", "CheckButton", CREAM)
	t.set_color("font_pressed_color", "CheckButton", CREAM)
	t.set_color("font_focus_color", "CheckButton", CREAM)
	# Barras de desplazamiento discretas.
	var carril := box(0.2, 4, 0.0, 0, 0, 0)
	var asa := box(0.6, 4, 0.0, 0, 0, 0)
	asa.bg_color = Color(CREAM, 0.55)
	t.set_stylebox("scroll", "VScrollBar", carril)
	t.set_stylebox("grabber", "VScrollBar", asa)
	t.set_stylebox("grabber_highlight", "VScrollBar", asa)
	t.set_stylebox("grabber_pressed", "VScrollBar", asa)
	# Ayuda emergente con el mismo lenguaje.
	t.set_stylebox("panel", "TooltipPanel", box(0.92, RADIUS_LABEL, 0.3, 1, 10, 6))
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", FONT_SECONDARY)
	t.set_color("font_color", "LinkButton", AMBER)
	return t


static func label(parent: Node, text: String, size: int = FONT_TEXT, color: Color = CREAM) -> Label:
	var n := Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size", size)
	n.add_theme_color_override("font_color", color)
	parent.add_child(n)
	return n


static func button(parent: Node, text: String, callback: Callable) -> Button:
	var n := Button.new()
	n.text = text
	n.custom_minimum_size.y = 40
	parent.add_child(n)
	n.pressed.connect(callback)
	return n


static func panel(parent: Node) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 9)
	p.add_child(v)
	return v


## Coloca un control en una esquina o borde de la pantalla con margen, para que siga al borde al cambiar la ventana.
## esquina: tl, tr, bl, br, tc (arriba centro), bc (abajo centro), c (centro).
static func place(c: Control, esquina: String, mx: float, my: float, w: float, h: float) -> void:
	match esquina:
		"tl":
			_anchors(c, 0, 0, 0, 0)
			c.offset_left = mx
			c.offset_top = my
			c.offset_right = mx + w
			c.offset_bottom = my + h
			c.grow_horizontal = Control.GROW_DIRECTION_END
			c.grow_vertical = Control.GROW_DIRECTION_END
		"tr":
			_anchors(c, 1, 1, 0, 0)
			c.offset_right = -mx
			c.offset_left = -mx - w
			c.offset_top = my
			c.offset_bottom = my + h
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_END
		"bl":
			_anchors(c, 0, 0, 1, 1)
			c.offset_left = mx
			c.offset_right = mx + w
			c.offset_bottom = -my
			c.offset_top = -my - h
			c.grow_horizontal = Control.GROW_DIRECTION_END
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		"br":
			_anchors(c, 1, 1, 1, 1)
			c.offset_right = -mx
			c.offset_left = -mx - w
			c.offset_bottom = -my
			c.offset_top = -my - h
			c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		"tc":
			_anchors(c, 0.5, 0.5, 0, 0)
			c.offset_left = mx - w / 2.0
			c.offset_right = mx + w / 2.0
			c.offset_top = my
			c.offset_bottom = my + h
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_END
		"bc":
			_anchors(c, 0.5, 0.5, 1, 1)
			c.offset_left = -w / 2.0
			c.offset_right = w / 2.0
			c.offset_bottom = -my
			c.offset_top = -my - h
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_:
			_anchors(c, 0.5, 0.5, 0.5, 0.5)
			c.offset_left = -w / 2.0
			c.offset_right = w / 2.0
			c.offset_top = -h / 2.0
			c.offset_bottom = h / 2.0
			c.grow_horizontal = Control.GROW_DIRECTION_BOTH
			c.grow_vertical = Control.GROW_DIRECTION_BOTH


static func _anchors(c: Control, left: float, right: float, top: float, bottom: float) -> void:
	c.anchor_left = left
	c.anchor_right = right
	c.anchor_top = top
	c.anchor_bottom = bottom
