extends Control
## Iconos vectoriales del HUD dibujados en una caja de 16×16 que se escala al tamaño del control.
## Ningún estado depende solo del color: batería baja lleva «!», enlace lleva eslabón, aviso triángulo, crítico octágono.

var kind: String = "battery":
	set(value):
		kind = value
		queue_redraw()
var color: Color = Color("FFF5E4"):
	set(value):
		color = value
		queue_redraw()
var level: float = 1.0:  ## carga de la batería 0..1
	set(value):
		level = clampf(value, 0.0, 1.0)
		queue_redraw()
var alert: bool = false:
	set(value):
		alert = value
		queue_redraw()

static var _moon: PackedVector2Array = PackedVector2Array()


static func make(tipo: String, lado: float = 16.0, tono: Color = Color("FFF5E4")) -> Control:
	var icono = load("res://scenes/b/hud_icon.gd").new()
	icono.kind = tipo
	icono.color = tono
	icono.custom_minimum_size = Vector2(lado, lado)
	icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icono.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return icono


func _draw() -> void:
	var lado := minf(size.x, size.y)
	var escala := lado / 16.0
	draw_set_transform(Vector2((size.x - lado) / 2.0, (size.y - lado) / 2.0), 0.0, Vector2(escala, escala))
	var w := 1.5
	match kind:
		"battery":
			_rect_outline(Rect2(1.0, 4.0, 12.0, 8.0), w)
			draw_rect(Rect2(13.2, 6.3, 1.8, 3.4), color)
			if alert:
				_bang(Vector2(7.0, 5.6), 4.0)
			else:
				draw_rect(Rect2(2.6, 5.6, 8.8 * level, 4.8), color)
		"science":
			draw_polyline(PackedVector2Array([Vector2(8, 11.5), Vector2(8, 2.5)]), color, w, true)
			draw_polyline(PackedVector2Array([Vector2(4.5, 6), Vector2(8, 2.5), Vector2(11.5, 6)]), color, w, true)
			draw_polyline(PackedVector2Array([Vector2(2.5, 11), Vector2(2.5, 14), Vector2(13.5, 14), Vector2(13.5, 11)]), color, w, true)
		"link":
			_capsule(Vector2(5.8, 10.2), 2.6, 2.4, -PI / 4.0, w)
			_capsule(Vector2(10.2, 5.8), 2.6, 2.4, -PI / 4.0, w)
		"pause":
			draw_rect(Rect2(4.0, 3.0, 2.8, 10.0), color)
			draw_rect(Rect2(9.2, 3.0, 2.8, 10.0), color)
		"play":
			draw_colored_polygon(PackedVector2Array([Vector2(5, 3), Vector2(13, 8), Vector2(5, 13)]), color)
		"moon":
			if _moon.is_empty():
				_moon = _crescent()
			draw_colored_polygon(_moon, color)
		"sun":
			draw_circle(Vector2(8, 8), 3.0, color)
			for i in range(8):
				var dir := Vector2.from_angle(i * PI / 4.0)
				draw_line(Vector2(8, 8) + dir * 4.8, Vector2(8, 8) + dir * 6.8, color, 1.3, true)
		"warning":
			draw_polyline(PackedVector2Array([Vector2(8, 1.8), Vector2(15, 14), Vector2(1, 14), Vector2(8, 1.8)]), color, w, true)
			_bang(Vector2(8, 6.0), 4.2)
		"critical":
			var puntos := PackedVector2Array()
			for i in range(9):
				puntos.append(Vector2(8, 8) + Vector2.from_angle(PI / 8.0 + i * PI / 4.0) * 7.0)
			draw_polyline(puntos, color, w, true)
			_bang(Vector2(8, 4.6), 4.8)
		"grid":
			for v in [5.5, 10.5]:
				draw_line(Vector2(v, 2), Vector2(v, 14), color, 1.3, true)
				draw_line(Vector2(2, v), Vector2(14, v), color, 1.3, true)
			_rect_outline(Rect2(2, 2, 12, 12), 1.3)
		"chevron_down":
			draw_polyline(PackedVector2Array([Vector2(4, 6), Vector2(8, 10), Vector2(12, 6)]), color, 1.8, true)
		"chevron_up":
			draw_polyline(PackedVector2Array([Vector2(4, 10), Vector2(8, 6), Vector2(12, 10)]), color, 1.8, true)
		"close":
			draw_line(Vector2(4, 4), Vector2(12, 12), color, 1.8, true)
			draw_line(Vector2(12, 4), Vector2(4, 12), color, 1.8, true)
		"info":
			draw_arc(Vector2(8, 8), 6.5, 0, TAU, 28, color, w, true)
			draw_line(Vector2(8, 7), Vector2(8, 11.5), color, 1.6, true)
			draw_circle(Vector2(8, 4.8), 0.95, color)
		"gear":
			draw_arc(Vector2(8, 8), 4.2, 0, TAU, 24, color, w, true)
			draw_circle(Vector2(8, 8), 1.4, color)
			for i in range(8):
				var d := Vector2.from_angle(i * PI / 4.0)
				draw_line(Vector2(8, 8) + d * 5.2, Vector2(8, 8) + d * 7.2, color, 2.0, true)
		"antenna":
			draw_line(Vector2(8, 7), Vector2(8, 14), color, w, true)
			draw_line(Vector2(5, 14), Vector2(11, 14), color, w, true)
			draw_arc(Vector2(8, 7), 3.0, -PI * 0.85, -PI * 0.15, 10, color, w, true)
			draw_arc(Vector2(8, 7), 5.8, -PI * 0.85, -PI * 0.15, 14, color, w, true)
	draw_set_transform(Vector2.ZERO)


func _rect_outline(r: Rect2, w: float) -> void:
	draw_polyline(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]), color, w, true)


func _bang(arriba: Vector2, alto: float) -> void:
	draw_line(arriba, arriba + Vector2(0, alto * 0.62), color, 1.6, true)
	draw_circle(arriba + Vector2(0, alto * 0.95), 0.95, color)


func _capsule(centro: Vector2, medio_largo: float, radio: float, angulo: float, w: float) -> void:
	var puntos := PackedVector2Array()
	var eje := Vector2.from_angle(angulo)
	for i in range(11):
		var a := angulo - PI / 2.0 + i * PI / 10.0
		puntos.append(centro + eje * medio_largo + Vector2.from_angle(a) * radio)
	for i in range(11):
		var a := angulo + PI / 2.0 + i * PI / 10.0
		puntos.append(centro - eje * medio_largo + Vector2.from_angle(a) * radio)
	puntos.append(puntos[0])
	draw_polyline(puntos, color, w, true)


## Media luna: círculo exterior menos un círculo desplazado.
static func _crescent() -> PackedVector2Array:
	var c1 := Vector2(7.5, 8.5)
	var r1 := 6.2
	var c2 := Vector2(10.6, 6.0)
	var r2 := 5.2
	var n := 72
	var fuera: Array[int] = []
	for i in range(n):
		if (c1 + Vector2.from_angle(i * TAU / n) * r1).distance_to(c2) >= r2:
			fuera.append(i)
	var inicio := 0
	for k in range(fuera.size()):
		if not fuera.has((fuera[k] - 1 + n) % n):
			inicio = k
			break
	var puntos := PackedVector2Array()
	for k in range(fuera.size()):
		puntos.append(c1 + Vector2.from_angle(fuera[(inicio + k) % fuera.size()] * TAU / n) * r1)
	var dentro := PackedVector2Array()
	for i in range(n):
		var p := c2 + Vector2.from_angle(i * TAU / n) * r2
		if p.distance_to(c1) < r1:
			dentro.append(p)
	# Ordenar el arco interior para que empiece junto al final del exterior.
	var mejor := 0
	for i in range(dentro.size()):
		if dentro[i].distance_to(puntos[puntos.size() - 1]) < dentro[mejor].distance_to(puntos[puntos.size() - 1]):
			mejor = i
	var siguiente := dentro[(mejor + 1) % dentro.size()]
	var anterior := dentro[(mejor - 1 + dentro.size()) % dentro.size()]
	var paso := 1 if siguiente.distance_to(dentro[mejor]) < anterior.distance_to(dentro[mejor]) else -1
	for k in range(dentro.size()):
		puntos.append(dentro[(mejor + k * paso + dentro.size() * 2) % dentro.size()])
	return puntos
