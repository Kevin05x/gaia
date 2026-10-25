extends GutTest
## Lote de formas 2D: cada forma añade los triángulos esperados y todo se dibuja con una sola llamada.

const Lote := preload("res://scenes/b/canvas_batch.gd")


func test_un_rectangulo_son_dos_triangulos() -> void:
	var lote := Lote.new()
	assert_true(lote.is_empty())
	lote.rect(Rect2(0, 0, 4, 4), Color.WHITE)
	assert_eq(lote._indices.size(), 6)
	assert_eq(lote._puntos.size(), 6)
	assert_eq(lote._colores.size(), 6)


func test_aro_disco_y_poligono() -> void:
	var lote := Lote.new()
	lote.disco(Vector2.ZERO, 3.0, Color.RED, 10)
	assert_eq(lote._indices.size(), 30)
	lote.clear()
	lote.aro(Vector2.ZERO, 5.0, 1.0, Color.RED, 12)
	assert_eq(lote._indices.size(), 12 * 6)
	lote.clear()
	lote.poligono(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 4), Vector2(0, 4)]), Color.RED)
	assert_eq(lote._indices.size(), 6, "un cuadrado de 4 vértices son 2 triángulos")


func test_las_lineas_tienen_el_ancho_pedido() -> void:
	var lote := Lote.new()
	lote.linea(Vector2(0, 0), Vector2(10, 0), 2.0, Color.WHITE)
	var ys: Array[float] = []
	for p in lote._puntos:
		ys.append(p.y)
	assert_almost_eq(ys.max() - ys.min(), 2.0, 0.001)
	lote.clear()
	lote.linea(Vector2(3, 3), Vector2(3, 3), 2.0, Color.WHITE)
	assert_true(lote.is_empty(), "una línea sin largo no dibuja nada")


func test_dibujar_vacia_el_lote() -> void:
	var lote := Lote.new()
	lote.rect(Rect2(0, 0, 2, 2), Color.WHITE)
	var control: Control = add_child_autofree(Control.new())
	lote.dibujar(control.get_canvas_item())
	assert_true(lote.is_empty())
