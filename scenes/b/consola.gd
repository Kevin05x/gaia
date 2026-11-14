extends RefCounted
## Lenguaje visual de «consola»: chapas con esquinas cortadas, corchetes de encuadre, reglillas de
## marcas y franjas de precaución, todo dibujado a mano con `_draw()`.
##
## Existe porque las pantallas montadas con paneles redondeados y tarjetas centradas se leen como una
## página web, y esto es la consola de un complejo de lanzamiento: chapa metálica, nada de esquinas
## redondeadas, nada de sombras blandas, el estado se marca con marcas y barras, no con brillos.
##
## No guarda estado: son funciones estáticas que cualquier `CanvasItem` puede llamar dentro de su
## `_draw()`. Las usa `scenes/b/launch_pad.gd`.

const UI := preload("res://scenes/b/ui_style.gd")

## Esquinas que se cortan (biselan), como banderas que se suman.
const TL := 1
const TR := 2
const BR := 4
const BL := 8
const DIAGONAL := TL | BR  ## el corte habitual de la consola: dos esquinas opuestas

## Paleta de la consola. Acero frío para la chapa, crema y ámbar de GAIA para el contenido.
const CHAPA := Color("0A1016", 0.90)
const CHAPA_VIVA := Color("132230", 0.94)
const CHAPA_HONDA := Color("060C11", 0.94)
const ACERO := Color("9DB5C6")
const LINEA := Color("7F9BAF", 0.55)
const LINEA_TENUE := Color("7F9BAF", 0.20)
const AMBAR := Color("F0C079")
const PRECAUCION := Color("2A1E0B", 0.95)


## Contorno de una chapa: rectángulo con las esquinas pedidas cortadas a 45°.
static func contorno(r: Rect2, corte: float, esquinas: int = DIAGONAL) -> PackedVector2Array:
	var c: float = minf(corte, minf(r.size.x, r.size.y) * 0.5)
	var p := PackedVector2Array()
	var x0 := r.position.x
	var y0 := r.position.y
	var x1 := r.end.x
	var y1 := r.end.y
	if esquinas & TL:
		p.append(Vector2(x0, y0 + c))
		p.append(Vector2(x0 + c, y0))
	else:
		p.append(Vector2(x0, y0))
	if esquinas & TR:
		p.append(Vector2(x1 - c, y0))
		p.append(Vector2(x1, y0 + c))
	else:
		p.append(Vector2(x1, y0))
	if esquinas & BR:
		p.append(Vector2(x1, y1 - c))
		p.append(Vector2(x1 - c, y1))
	else:
		p.append(Vector2(x1, y1))
	if esquinas & BL:
		p.append(Vector2(x0 + c, y1))
		p.append(Vector2(x0, y1 - c))
	else:
		p.append(Vector2(x0, y1))
	return p


## Chapa: relleno plano y borde de una línea. Sin radio y sin sombra: es metal, no una tarjeta.
static func chapa(c: CanvasItem, r: Rect2, relleno: Color, borde: Color = LINEA,
		grosor: float = 1.0, corte: float = 12.0, esquinas: int = DIAGONAL) -> void:
	var p := contorno(r, corte, esquinas)
	if relleno.a > 0.0:
		c.draw_colored_polygon(p, relleno)
	if borde.a > 0.0 and grosor > 0.0:
		var cerrado := p.duplicate()
		cerrado.append(p[0])
		c.draw_polyline(cerrado, borde, grosor, true)


## Corchetes de encuadre en las cuatro esquinas: dos trazos por esquina, como una mira.
static func corchetes(c: CanvasItem, r: Rect2, color: Color, largo: float = 14.0, grosor: float = 2.0) -> void:
	var l: float = minf(largo, minf(r.size.x, r.size.y) * 0.45)
	for par in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[r.end, Vector2(-1, -1)], [Vector2(r.position.x, r.end.y), Vector2(1, -1)]]:
		var o: Vector2 = par[0]
		var d: Vector2 = par[1]
		c.draw_line(o, o + Vector2(d.x * l, 0), color, grosor)
		c.draw_line(o, o + Vector2(0, d.y * l), color, grosor)


## Reglilla de marcas a lo largo de una línea horizontal: una marca corta cada paso y una larga
## cada quinta. Es el detalle que convierte un borde en un instrumento.
static func reglilla(c: CanvasItem, origen: Vector2, ancho: float, color: Color,
		paso: float = 9.0, alto: float = 4.0, cada: int = 5, alto_mayor: float = 9.0) -> void:
	var n := int(ancho / paso)
	for i in range(n + 1):
		var x := origen.x + i * paso
		var h := alto_mayor if i % cada == 0 else alto
		c.draw_line(Vector2(x, origen.y), Vector2(x, origen.y + h), color, 1.0)


## Franja de precaución: rayas diagonales, como el borde de una plataforma de verdad.
static func rayas(c: CanvasItem, r: Rect2, fondo: Color, raya: Color, paso: float = 11.0) -> void:
	c.draw_rect(r, fondo)
	# Cada raya es un paralelogramo recortado al rectángulo: sin recortar se saldría de la franja.
	var marco := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var p := PackedVector2Array([
			Vector2(x, r.end.y),
			Vector2(x + r.size.y, r.position.y),
			Vector2(x + r.size.y + paso * 0.5, r.position.y),
			Vector2(x + paso * 0.5, r.end.y)])
		for trozo in Geometry2D.intersect_polygons(p, marco):
			c.draw_colored_polygon(trozo, raya)
		x += paso


## Línea fina de separación.
static func regla(c: CanvasItem, y: float, x0: float, x1: float, color: Color, grosor: float = 1.0) -> void:
	c.draw_line(Vector2(x0, y), Vector2(x1, y), color, grosor)


## Texto técnico: la fuente de display de GAIA, con el grosor y la separación entre letras que le dan
## el aire de rótulo de panel. Devuelve el ancho que ocupó, para encadenar rótulos en una fila.
static func texto(c: CanvasItem, pos: Vector2, s: String, tam: int, color: Color,
		peso: int = 600, separacion: int = 0) -> float:
	var f := UI.display_font(peso, separacion)
	var t: int = maxi(tam, UI.FONT_MIN)
	c.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, t, color)
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, t).x


## Texto corriente (Inter), para las frases que se leen de verdad.
static func parrafo(c: CanvasItem, pos: Vector2, s: String, tam: int, color: Color, ancho: float) -> void:
	var f := UI.text_font(440)
	c.draw_multiline_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, ancho, maxi(tam, UI.FONT_MIN),
		-1, color, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_GRAPHEME_BOUND)


## Ancho de un texto técnico, para medir antes de dibujar.
static func ancho(s: String, tam: int, peso: int = 600, separacion: int = 0) -> float:
	var f := UI.display_font(peso, separacion)
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(tam, UI.FONT_MIN)).x


## Punto de estado que late. `t` es el reloj de la pantalla en segundos.
static func testigo(c: CanvasItem, centro: Vector2, color: Color, t: float, radio: float = 3.5) -> void:
	var vivo := 0.45 + 0.55 * absf(sin(t * 2.4))
	c.draw_circle(centro, radio + 2.5, Color(color, 0.18 * vivo))
	c.draw_circle(centro, radio, Color(color, 0.55 + 0.45 * vivo))


## Barra de avance de la consola: carril de marcas y relleno sólido, sin esquinas redondeadas.
static func barra(c: CanvasItem, r: Rect2, avance: float, carril: Color, relleno: Color) -> void:
	c.draw_rect(r, carril)
	var p: float = clampf(avance, 0.0, 1.0)
	if p > 0.0:
		c.draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), relleno)
	var marcas := 10
	for i in range(1, marcas):
		var x := r.position.x + r.size.x * float(i) / float(marcas)
		c.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(CHAPA_HONDA, 0.8), 1.0)
