extends GutTest
## Cordillera del horizonte hecha en Blender (tools/blender/horizonte.py): se carga, tiene picos de verdad y el juego
## no depende de ella (sin el archivo vuelve a las lomas por código).


func test_la_cordillera_se_carga_con_picos_y_color() -> void:
	assert_true(Horizonte.hay_cordillera())
	var nodo := Horizonte.cordillera(140.0, FastNoiseLite.new())
	assert_not_null(nodo)
	add_child_autofree(nodo)
	var caja := nodo.get_aabb()
	assert_gt(caja.size.y, 60.0, "picos de más de 60 m")
	assert_gt(caja.size.x, 900.0, "rodea el cráter")
	var datos := nodo.mesh.surface_get_arrays(0)
	assert_gt((datos[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 10000)
	assert_eq((datos[Mesh.ARRAY_COLOR] as PackedColorArray).size(), (datos[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	var arriba := 0.0
	for n in datos[Mesh.ARRAY_NORMAL] as PackedVector3Array:
		arriba += n.y
	assert_gt(arriba, 0.0, "las normales miran hacia arriba (se ve desde dentro del cráter)")


func test_la_cordillera_se_escala_a_otros_mapas_sin_cambiar_las_alturas() -> void:
	var normal := Horizonte.cordillera(140.0, FastNoiseLite.new())
	var grande := Horizonte.cordillera(280.0, FastNoiseLite.new())
	add_child_autofree(normal)
	add_child_autofree(grande)
	assert_almost_eq(grande.get_aabb().size.x, normal.get_aabb().size.x * 2.0, 2.0)
	assert_almost_eq(grande.get_aabb().size.y, normal.get_aabb().size.y, 0.5)


func test_el_terreno_sigue_construyendose_con_o_sin_cordillera() -> void:
	# Las lomas y mesetas por código (el respaldo) siguen existiendo.
	var lomas := Horizonte.lomas(140.0, FastNoiseLite.new())
	var mesetas := Horizonte.mesetas(140.0, FastNoiseLite.new())
	assert_not_null(lomas)
	assert_not_null(mesetas)
	lomas.free()
	mesetas.free()
