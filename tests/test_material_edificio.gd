extends GutTest
## Material realista de los edificios (scenes/b/material_edificio.gd y shaders/edificio.gdshader): chapa de paneles
## en triplanar con polvo del destino. Lo usan los modelos de edificios del equipo y las mallas fundidas de bloques.

const MaterialEdificio := preload("res://scenes/b/material_edificio.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
const Art := preload("res://scenes/b/art.gd")


func after_all() -> void:
	MaterialEdificio.aplicar(true)
	Equipo.vaciar()


func test_estan_las_texturas_de_chapa() -> void:
	assert_true(MaterialEdificio.hay_texturas(), "assets/texturas/edificio_paneles_{detalle,normal,mascaras}.jpg")


func test_los_edificios_usan_el_material_realista_y_lo_que_brilla_se_queda() -> void:
	Equipo.vaciar()
	for nombre in Equipo.EDIFICIOS:
		if not Equipo.existe(nombre):
			continue
		var padre := Node3D.new()
		add_child_autofree(padre)
		var mallas := Equipo.poner(padre, nombre, 3.0)
		assert_eq(mallas.size(), 1, nombre)
		var malla := mallas[0].mesh
		var realistas := 0
		for i in malla.get_surface_count():
			var m := malla.surface_get_material(i)
			if MaterialEdificio.es_propio(m):
				realistas += 1
			else:
				assert_true(m is StandardMaterial3D and ((m as StandardMaterial3D).emission_enabled or m.resource_name.begins_with("emisivo_")),
					"%s: solo los emisivos conservan su material (%s)" % [nombre, m])
		assert_gt(realistas, 0, nombre)


func test_los_minerales_conservan_sus_materiales() -> void:
	Equipo.vaciar()
	if not Equipo.existe("mineral_oro"):
		pass_test("sin el modelo")
		return
	var padre := Node3D.new()
	add_child_autofree(padre)
	var malla := Equipo.poner(padre, "mineral_oro", 1.0)[0].mesh
	for i in malla.get_surface_count():
		assert_false(MaterialEdificio.es_propio(malla.surface_get_material(i)))


func test_el_material_conserva_color_rugosidad_y_metal_del_original() -> void:
	var s := StandardMaterial3D.new()
	s.albedo_color = Color(0.2, 0.4, 0.6)
	s.roughness = 0.3
	s.metallic = 0.7
	var m := MaterialEdificio.desde(s, -1.5)
	assert_eq(m.get_shader_parameter("albedo_color"), Color(0.2, 0.4, 0.6))
	assert_almost_eq(float(m.get_shader_parameter("roughness")), 0.3, 0.001)
	assert_almost_eq(float(m.get_shader_parameter("metallic")), 0.7, 0.001)
	assert_almost_eq(float(m.get_shader_parameter("base_y")), -1.5, 0.001)


func test_las_mallas_fundidas_llevan_rugosidad_y_metal_por_pieza() -> void:
	var raiz := Node3D.new()
	add_child_autofree(raiz)
	Art.box(raiz, Vector3.ONE, Vector3.ZERO, Color.WHITE)
	Art.panel(raiz, Vector3(2, 0.1, 1), Vector3(0, 1, 0), 2, 2)
	Art.merged(raiz)
	var fundida := raiz.get_node("Merged") as MeshInstance3D
	assert_true(MaterialEdificio.es_propio(fundida.material_override))
	var uv2: PackedVector2Array = fundida.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
	assert_false(uv2.is_empty(), "UV2 = (rugosidad, metal)")
	assert_true(uv2.has(Vector2(0.86, 0.0)), "chapa mate")
	var celdas := false
	for v in uv2:
		if is_equal_approx(v.x, 0.22) and is_equal_approx(v.y, 0.3):
			celdas = true
	assert_true(celdas, "las celdas solares son lisas y algo metálicas")


func test_la_calidad_baja_apaga_las_texturas() -> void:
	var m := MaterialEdificio.desde(StandardMaterial3D.new())
	MaterialEdificio.aplicar(false)
	assert_eq(float(m.get_shader_parameter("detalle")), 0.0)
	MaterialEdificio.aplicar(true)
	assert_eq(float(m.get_shader_parameter("detalle")), 1.0)
