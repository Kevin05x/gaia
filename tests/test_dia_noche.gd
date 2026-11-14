extends GutTest
## Ciclo día/noche del cielo: el factor de noche que enciende las luces de la base y la tabla de amanecer y ocaso.

const SkyLight := preload("res://scenes/b/sky_light.gd")


func _cielo(hora: float) -> Node:
	var cielo := SkyLight.new()
	cielo.hour = hora
	add_child_autofree(cielo)
	return cielo


func test_de_dia_las_luces_estan_apagadas() -> void:
	assert_eq(_cielo(12.0).noche_factor(), 0.0)
	assert_eq(_cielo(9.0).noche_factor(), 0.0)


func test_de_noche_cerrada_las_luces_estan_al_maximo() -> void:
	assert_eq(_cielo(0.0).noche_factor(), 1.0)
	assert_eq(_cielo(22.0).noche_factor(), 1.0)


func test_al_amanecer_y_al_ocaso_hay_luz_parcial() -> void:
	for hora in [6.0, 18.0]:
		var f: float = _cielo(hora).noche_factor()
		assert_gt(f, 0.0, "a las %s h las luces ya sirven" % hora)
		assert_lt(f, 1.0)


func test_la_tabla_del_cielo_esta_ordenada_por_hora() -> void:
	for tabla in [SkyLight.KEYS, SkyLight.KEYS_LUNA]:
		for i in range(1, tabla.size()):
			assert_gt(float(tabla[i][0]), float(tabla[i - 1][0]), "la hora %s va después de la anterior" % tabla[i][0])
		assert_eq(float(tabla[0][0]), 0.0)
		assert_eq(float(tabla[-1][0]), 24.0)
