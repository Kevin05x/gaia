extends GutTest
## Textos flotantes («+6 Xenolito»): salen por encima del menú de acciones y, si salen juntos, en filas distintas.


func test_textos_juntos_no_se_tapan() -> void:
	var t := TextosFlotantes.new()
	add_child_autofree(t)
	t.mostrar(Vector3.ZERO, "+6 Xenolito", Color.WHITE)
	t.mostrar(Vector3(0.2, 0, 0), "+3 Hito", Color.WHITE)
	var filas: Array = []
	for hijo in t.get_children():
		var l := hijo as Label3D
		if l.visible:
			filas.append(l.offset.y)
	assert_eq(filas.size(), 2)
	assert_ne(filas[0], filas[1], "cada uno en su fila")
	for y in filas:
		assert_true(float(y) >= TextosFlotantes.SOBRE_PX, "arranca por encima del menú de acciones")
