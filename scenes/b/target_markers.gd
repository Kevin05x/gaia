extends Control
## Capa 2D sobre el mundo: símbolo discreto de cada objetivo revelado, doble trazo y línea guía del seleccionado,
## y flecha en el borde cuando el objetivo queda fuera del encuadre. Los enterrados sin revelar nunca se marcan.
const UI := preload("res://scenes/b/ui_style.gd")

var targets: Array = []
var selected := ""
var project: Callable  ## id -> {"pos": Vector2, "behind": bool} o {} si no existe
var label_rect := Rect2()  ## etiqueta contextual (para la línea guía); vacía si no se muestra
var pulse := 1.0
const BORDE := 34.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	pulse = 0.85 + 0.15 * sin(Time.get_ticks_msec() / 1600.0 * TAU)
	queue_redraw()


func _draw() -> void:
	if not project.is_valid() or size.x < 2 * BORDE or size.y < 2 * BORDE:
		return
	var marco := Rect2(Vector2.ZERO, size).grow(-BORDE)
	for t in targets:
		if not t.get("revealed", false):
			continue
		var id := str(t.get("id", ""))
		var datos: Dictionary = project.call(id)
		if datos.is_empty():
			continue
		var p: Vector2 = datos["pos"]
		var es_sel := id == selected
		if datos.get("behind", false) or not marco.has_point(p):
			_edge_arrow(p, marco, es_sel, datos.get("behind", false))
			continue
		var apagado: bool = t.get("depleted", false)
		if es_sel:
			_selected(p)
		else:
			_symbol(p, str(t.get("type", "rock")), apagado)


func _symbol(p: Vector2, tipo: String, apagado: bool) -> void:
	var tono := Color(UI.CREAM, 0.45 if apagado else 0.92)
	var borde := Color(UI.BORDER_DARK, 0.55 if apagado else 0.85)
	var r := 6.0
	var forma := PackedVector2Array()
	match tipo:
		"mineral":
			forma = PackedVector2Array([p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0), p + Vector2(0, -r)])
		"buried":
			forma = PackedVector2Array([p + Vector2(-r, -r * 0.8), p + Vector2(r, -r * 0.8), p + Vector2(0, r * 0.9), p + Vector2(-r, -r * 0.8)])
	if forma.is_empty():
		draw_arc(p, r + 1.2, 0, TAU, 24, borde, 2.6, true)
		draw_arc(p, r, 0, TAU, 24, tono, 1.6, true)
	else:
		draw_polyline(forma, borde, 3.4, true)
		draw_polyline(forma, tono, 1.6, true)
	if apagado:
		draw_line(p + Vector2(-2.5, 0), p + Vector2(-0.5, 2), tono, 1.4, true)
		draw_line(p + Vector2(-0.5, 2), p + Vector2(3, -2), tono, 1.4, true)
	else:
		draw_circle(p, 1.6, tono)


func _selected(p: Vector2) -> void:
	var luz := Color(UI.TARGET_LIGHT, pulse)
	draw_arc(p, 15.0, 0, TAU, 40, Color(UI.BORDER_DARK, 0.9 * pulse), 2.0, true)
	draw_arc(p, 12.5, 0, TAU, 40, luz, 2.2, true)
	draw_circle(p, 2.2, luz)
	if label_rect.size != Vector2.ZERO:
		var destino := Vector2(clampf(p.x, label_rect.position.x + 8, label_rect.end.x - 8), label_rect.end.y)
		if label_rect.position.y > p.y:
			destino.y = label_rect.position.y
		var dir := (destino - p).normalized()
		var inicio := p + dir * 16.0
		if inicio.distance_to(destino) > 4.0:
			draw_line(inicio, destino, Color(UI.BORDER_DARK, 0.7), 3.0, true)
			draw_line(inicio, destino, luz, 1.4, true)


func _edge_arrow(p: Vector2, marco: Rect2, es_sel: bool, detras: bool) -> void:
	var centro := size / 2.0
	var dir := (p - centro)
	if detras:
		dir = Vector2(dir.x, absf(dir.y) + 1.0)
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# Punto del borde en esa dirección.
	var tx := (marco.size.x / 2.0) / maxf(absf(dir.x), 0.0001)
	var ty := (marco.size.y / 2.0) / maxf(absf(dir.y), 0.0001)
	var q := centro + dir * minf(tx, ty)
	var tono := Color(UI.TARGET_LIGHT, pulse) if es_sel else Color(UI.CREAM, 0.8)
	var lado := 9.0 if es_sel else 7.0
	var punta := q + dir * lado
	var normal := Vector2(-dir.y, dir.x)
	var tri := PackedVector2Array([punta, q - dir * lado * 0.4 + normal * lado * 0.8, q - dir * lado * 0.4 - normal * lado * 0.8])
	draw_colored_polygon(tri, Color(UI.SURFACE, 0.7))
	tri.append(tri[0])
	draw_polyline(tri, tono, 1.6, true)
