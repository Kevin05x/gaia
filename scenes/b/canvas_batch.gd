extends RefCounted
## Lote de formas 2D de color que se dibuja con UNA sola llamada de dibujo (triángulos con color por vértice).
## draw_arc, draw_circle o draw_polyline sueltos cuestan una llamada cada uno en cada cuadro: el minimapa y los
## marcadores de objetivos llegaban a ~200 por cuadro. Con el lote cuestan una. Sin suavizado de bordes: a estos
## tamaños (1–15 px) no se nota.

var _puntos := PackedVector2Array()
var _colores := PackedColorArray()
var _indices := PackedInt32Array()


func clear() -> void:
	_puntos.clear()
	_colores.clear()
	_indices.clear()


func is_empty() -> bool:
	return _indices.is_empty()


func triangulo(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var base := _puntos.size()
	_puntos.append(a)
	_puntos.append(b)
	_puntos.append(c)
	for i in 3:
		_colores.append(color)
	_indices.append(base)
	_indices.append(base + 1)
	_indices.append(base + 2)


## Polígono de relleno, partido en abanico desde el primer vértice (vale para formas convexas y para flechas en punta).
func poligono(vertices: PackedVector2Array, color: Color) -> void:
	for i in range(1, vertices.size() - 1):
		triangulo(vertices[0], vertices[i], vertices[i + 1], color)


func rect(r: Rect2, color: Color) -> void:
	triangulo(r.position, Vector2(r.end.x, r.position.y), r.end, color)
	triangulo(r.position, r.end, Vector2(r.position.x, r.end.y), color)


func disco(centro: Vector2, radio: float, color: Color, segmentos: int = 14) -> void:
	for i in segmentos:
		var a0 := TAU * i / segmentos
		var a1 := TAU * (i + 1) / segmentos
		triangulo(centro, centro + Vector2(cos(a0), sin(a0)) * radio, centro + Vector2(cos(a1), sin(a1)) * radio, color)


## Aro de «ancho» px centrado en «radio».
func aro(centro: Vector2, radio: float, ancho: float, color: Color, segmentos: int = 24) -> void:
	var dentro := maxf(radio - ancho / 2.0, 0.0)
	var fuera := radio + ancho / 2.0
	for i in segmentos:
		var a0 := TAU * i / segmentos
		var a1 := TAU * (i + 1) / segmentos
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a1), sin(a1))
		triangulo(centro + d0 * dentro, centro + d0 * fuera, centro + d1 * fuera, color)
		triangulo(centro + d0 * dentro, centro + d1 * fuera, centro + d1 * dentro, color)


func linea(a: Vector2, b: Vector2, ancho: float, color: Color) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var n := Vector2(-dir.y, dir.x).normalized() * ancho / 2.0
	triangulo(a + n, a - n, b - n, color)
	triangulo(a + n, b - n, b + n, color)


func polilinea(puntos: PackedVector2Array, ancho: float, color: Color) -> void:
	for i in range(puntos.size() - 1):
		linea(puntos[i], puntos[i + 1], ancho, color)


## Manda todo el lote a dibujar en «item» (el get_canvas_item() del Control que está en su _draw) y lo vacía.
func dibujar(item: RID) -> void:
	if not _indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(item, _indices, _puntos, _colores)
	clear()
