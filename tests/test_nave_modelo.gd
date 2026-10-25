extends GutTest
## Modelo 3D de la nave de fuga: un nodo por módulo terminado y el módulo en obra crece con el avance.

const Nave := preload("res://scenes/b/escape_ship.gd")


func _raiz(nivel: int, en_obra: bool) -> Node3D:
	var r: Node3D = add_child_autofree(Node3D.new())
	Nave.construir(r, nivel, en_obra)
	return r


func test_un_modulo_por_nivel() -> void:
	for nivel in range(1, 5):
		var r := _raiz(nivel, false)
		assert_eq(r.get_node("Cuerpo").get_child_count() >= nivel, true)
		assert_not_null(r.get_node_or_null("Cuerpo/Modulo%d" % nivel))
		assert_null(r.get_node_or_null("Cuerpo/Modulo%d" % (nivel + 1)))


func test_modulo_en_obra_aparece_y_crece() -> void:
	var r := _raiz(1, true)
	assert_not_null(r.get_node_or_null("Cuerpo/Modulo2"))
	Nave.animar_obra(r, 1, 0.0)
	var bajo: float = (r.get_node("Cuerpo/Modulo2") as Node3D).scale.y
	Nave.animar_obra(r, 1, 1.0)
	var alto: float = (r.get_node("Cuerpo/Modulo2") as Node3D).scale.y
	assert_lt(bajo, 0.2)
	assert_almost_eq(alto, 1.0, 0.001)


func test_nave_completa_no_pasa_de_cuatro_modulos() -> void:
	var r := _raiz(4, true)
	assert_null(r.get_node_or_null("Cuerpo/Modulo5"))
	assert_not_null(r.get_node_or_null("Cuerpo/Modulo4"))
