extends GutTest
## Los rayos de las torretas deben unir exactamente la boca de la torreta con el blanco, sea cual sea la dirección.


func _extremos(desde: Vector3, hasta: Vector3) -> Array:
	var largo := desde.distance_to(hasta)
	var base := Basis.looking_at((hasta - desde).normalized(), Vector3.UP).scaled_local(Vector3(1, 1, largo))
	var t := Transform3D(base, (desde + hasta) / 2.0)
	return [t * Vector3(0, 0, -0.5), t * Vector3(0, 0, 0.5)]  # los dos extremos de una caja de largo 1 en Z


func test_el_rayo_une_la_torreta_con_el_blanco_en_cualquier_direccion() -> void:
	for par in [[Vector3(0, 1.5, 0), Vector3(10, 0.7, 4)], [Vector3(3, 1.5, -2), Vector3(-8, 0.7, 6)], [Vector3(0, 1.5, 0), Vector3(1, 0.7, 12)],
			[Vector3(-5, 1.5, 5), Vector3(7, 0.7, -9)]]:
		var e := _extremos(par[0], par[1])
		var cerca: float = minf((e[0] as Vector3).distance_to(par[0]) + (e[1] as Vector3).distance_to(par[1]),
				(e[0] as Vector3).distance_to(par[1]) + (e[1] as Vector3).distance_to(par[0]))
		assert_lt(cerca, 0.01, "extremos %s" % str(par))
