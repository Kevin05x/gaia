extends Control
## Emblema de GAIA: un planeta con su órbita y una luna pequeña, dibujado por código (original, sin archivos).
const UI := preload("res://scenes/b/ui_style.gd")
const TILT := -0.45


func _ready() -> void:
	custom_minimum_size = Vector2(30, 30)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _orbit_point(c: Vector2, t: float, r: float) -> Vector2:
	var p := Vector2(cos(t) * r * 1.45, sin(t) * r * 0.5)
	return c + p.rotated(TILT)


func _arco(c: Vector2, r: float, desde: float, hasta: float, tono: Color, grosor: float) -> void:
	var puntos := PackedVector2Array()
	var pasos := 18
	for i in range(pasos + 1):
		puntos.append(_orbit_point(c, lerpf(desde, hasta, float(i) / pasos), r))
	draw_polyline(puntos, tono, grosor, true)


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) * 0.3
	# Mitad trasera de la órbita, el planeta y luego la mitad delantera.
	_arco(c, r, PI, TAU, Color(UI.CREAM, 0.45), 1.3)
	draw_circle(c, r, Color("c07a3c"))
	draw_circle(c + Vector2(-r * 0.22, -r * 0.25), r * 0.68, UI.AMBER)
	draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(UI.CREAM, 0.55))
	_arco(c, r, 0.0, PI, Color(UI.CREAM, 0.92), 1.6)
	var luna := _orbit_point(c, 0.5, r)
	draw_circle(luna, r * 0.26 + 1.2, Color(UI.SURFACE, 0.9))
	draw_circle(luna, r * 0.26, UI.TEAL)
