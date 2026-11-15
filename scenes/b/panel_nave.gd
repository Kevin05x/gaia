extends StyleBox
## Panel «de nave» de GAIA (plan del 15 nov, pedido de Kevin: «las interfaces son planas, dales estilo de juego»).
## Dibujado por código, sin imágenes: placa oscura con degradado (más clara arriba), esquinas cortadas, filo biselado,
## luz ámbar en el borde superior y escuadras en las cuatro esquinas, como las de una consola de misión.
## Se usa con UI.nave(), que acepta los mismos parámetros que UI.box().

const AMBAR := Color("F0C079")
const CREMA := Color("FFF5E4")

var alpha := 0.7
var chaflan := 10.0
var borde_alpha := 0.3
var borde_px := 1.0
var borde_color := AMBAR


func _draw(lienzo: RID, rect: Rect2) -> void:
	var w := rect.size.x
	var h := rect.size.y
	if w < 8.0 or h < 8.0:
		return
	var c := minf(chaflan, minf(w, h) * 0.5)
	var o := rect.position
	var contorno := _octogono(o, w, h, c)
	# Placa: degradado vertical (arriba, más clara y cálida; abajo, casi negra).
	var colores := PackedColorArray()
	for p in contorno:
		var t := clampf((p.y - o.y) / h, 0.0, 1.0)
		colores.append(Color(Color("3A281D").lerp(Color("160E0A"), t * 0.9 + 0.05), alpha))
	RenderingServer.canvas_item_add_polygon(lienzo, contorno, colores)
	# Biselado interior: un filo claro arriba y a la izquierda, uno oscuro abajo.
	var filo := _octogono(o + Vector2(2, 2), w - 4.0, h - 4.0, maxf(c - 2.0, 0.0))
	filo.append(filo[0])
	var filos := PackedColorArray()
	for p in filo:
		var t := clampf((p.y - o.y) / h, 0.0, 1.0)
		filos.append(Color(CREMA, 0.10 * (1.0 - t)) if t < 0.5 else Color(0, 0, 0, 0.25 * t))
	RenderingServer.canvas_item_add_polyline(lienzo, filo, filos, 1.0, true)
	# Borde exterior.
	if borde_alpha > 0.0 and borde_px > 0.0:
		var borde := contorno.duplicate()
		borde.append(borde[0])
		RenderingServer.canvas_item_add_polyline(lienzo, borde, PackedColorArray([Color(borde_color, borde_alpha)]), borde_px, true)
	# Luz de encendido: filete ámbar en el borde superior.
	RenderingServer.canvas_item_add_line(lienzo, o + Vector2(c + 6.0, 1.5), o + Vector2(w - c - 6.0, 1.5),
		Color(borde_color, minf(0.35 + borde_alpha, 0.95)), 2.0, true)
	if w < 60.0 or h < 40.0:
		return
	# Escuadras en las esquinas (siguen el chaflán).
	var e := Color(borde_color, minf(0.5 + borde_alpha, 0.95))
	var i := 4.0
	var l := 12.0
	var cc := c
	var tl := PackedVector2Array([o + Vector2(i, cc + l), o + Vector2(i, cc + 1.0), o + Vector2(cc + 1.0, i), o + Vector2(cc + l, i)])
	var tr := PackedVector2Array([o + Vector2(w - i, cc + l), o + Vector2(w - i, cc + 1.0), o + Vector2(w - cc - 1.0, i), o + Vector2(w - cc - l, i)])
	var bl := PackedVector2Array([o + Vector2(i, h - cc - l), o + Vector2(i, h - cc - 1.0), o + Vector2(cc + 1.0, h - i), o + Vector2(cc + l, h - i)])
	var br := PackedVector2Array([o + Vector2(w - i, h - cc - l), o + Vector2(w - i, h - cc - 1.0), o + Vector2(w - cc - 1.0, h - i), o + Vector2(w - cc - l, h - i)])
	for escuadra in [tl, tr, bl, br]:
		RenderingServer.canvas_item_add_polyline(lienzo, escuadra, PackedColorArray([e]), 1.5, true)
	# Remaches junto a las esquinas superiores.
	for x in [c + 18.0, w - c - 18.0]:
		RenderingServer.canvas_item_add_circle(lienzo, o + Vector2(x, 6.0), 1.4, Color(borde_color, 0.55))


## Rectángulo de esquinas cortadas (chaflán «c») como lista de puntos.
static func _octogono(o: Vector2, w: float, h: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([o + Vector2(c, 0), o + Vector2(w - c, 0), o + Vector2(w, c), o + Vector2(w, h - c),
		o + Vector2(w - c, h), o + Vector2(c, h), o + Vector2(0, h - c), o + Vector2(0, c)])
