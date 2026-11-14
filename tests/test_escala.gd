extends GutTest
## Escala única del mundo 3D (1 unidad = 1 m real, casilla de 4 m): el rover es el Perseverance de la NASA a 1:1 y ningún
## edificio queda más bajo que él ni desborda su casilla. Estas pruebas evitan que vuelva el rover más alto que la torre.
const RoverNasa := preload("res://scenes/b/rover_nasa.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
const Edificios := preload("res://scenes/b/buildings.gd")
const Muros := preload("res://scenes/b/muros_view.gd")


func _caja(n: Node, t: Transform3D = Transform3D.IDENTITY) -> AABB:
	var actual := t
	if n is Node3D:
		actual = t * (n as Node3D).transform
	var caja := AABB()
	var primera := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		caja = actual * (n as MeshInstance3D).get_aabb()
		primera = false
	for h in n.get_children():
		if h is Node3D and not (h as Node3D).visible:
			continue
		var c := _caja(h, actual)
		if c.size != Vector3.ZERO:
			caja = c if primera else caja.merge(c)
			primera = false
	return caja


func test_la_casilla_mide_cuatro_metros_y_la_conversion_es_reversible() -> void:
	assert_eq(Escala.TILE, 4.0)
	assert_eq(Escala.a_mundo(Vector2i(3, -2)), Vector3(12, 0, -8))
	assert_eq(Escala.a_casilla(Vector3(12.9, 0, -7.2)), Vector2i(3, -2))


func test_el_rover_de_la_nasa_tiene_su_tamano_real() -> void:
	if not RoverNasa.disponible():
		pending("falta el modelo")
		return
	var rover: Node3D = RoverNasa.crear()
	add_child_autofree(rover)
	for parte in ["RoverVisual", "arm", "drill", "spectrometer", "solar", "rtg", "radar", "meteo", "head", "HighGain", "Wheel0", "Wheel5"]:
		assert_not_null(rover.find_child(parte, true, false), "pieza «%s»" % parte)
	rover.get_node("RoverVisual/solar").visible = false
	var caja := _caja(rover.get_node("RoverVisual"))
	assert_between(caja.size.z, 2.7, 3.4, "largo ≈ 3,0 m")
	assert_between(caja.size.x, 2.4, 3.0, "ancho con ruedas ≈ 2,7 m")
	assert_between(caja.size.y, 1.9, 2.5, "alto con el mástil levantado ≈ 2,2 m")
	assert_almost_eq(caja.position.y, 0.0, 0.05, "apoyado en el suelo")


func test_las_seis_ruedas_giran_sobre_su_eje() -> void:
	if not RoverNasa.disponible():
		pending("falta el modelo")
		return
	var rover: Node3D = RoverNasa.crear()
	add_child_autofree(rover)
	for i in range(6):
		var rueda := rover.find_child("Wheel%d" % i, true, false) as Node3D
		var caja := _caja(rueda.get_child(0))  # la malla, respecto al origen del nodo
		assert_between(maxf(caja.size.y, caja.size.z), 0.45, 0.6, "diámetro ≈ 52 cm")
		assert_almost_eq(caja.get_center().y, 0.0, 0.05, "el eje queda en el origen de la rueda")
		assert_almost_eq(caja.get_center().z, 0.0, 0.05)


func test_ningun_edificio_es_mas_bajo_que_el_rover_ni_desborda_su_casilla() -> void:
	for tipo in Edificios.MODELOS:
		var info: Array = Edificios.MODELOS[tipo]
		var padre := Node3D.new()
		add_child_autofree(padre)
		Equipo.poner(padre, str(info[0]), float(info[1]), Vector3.ZERO, 0.0, float(info[2]))
		var caja := _caja(padre)
		if caja.size == Vector3.ZERO:
			continue  # el modelo del equipo no está en esta copia
		assert_gt(caja.size.y, Escala.ROVER_ALTO, "%s más alto que el rover" % tipo)
		assert_lt(maxf(caja.size.x, caja.size.z), Escala.TILE, "%s cabe en su casilla" % tipo)


func test_la_compuerta_deja_pasar_al_rover() -> void:
	assert_gt(Muros.POSTE * Muros.K_PUERTA * 2.0, Escala.ROVER_ANCHO + 0.5, "paso libre mayor que el ancho del rover")
	assert_gt(Muros.ALTO_PUERTA * Muros.K_PUERTA, Escala.ROVER_ALTO + 0.4, "alto libre mayor que el rover")
	assert_lt(Muros.ALTO_MURO * Muros.K_MURO, Escala.ROVER_ALTO, "el muro no tapa al rover")


func test_el_helicoptero_es_el_ingenuity_real() -> void:
	var ruta := "res://assets/nasa/modelos/ingenuity.glb"
	if not ResourceLoader.exists(ruta):
		pending("falta el modelo")
		return
	var heli: Node3D = (load(ruta) as PackedScene).instantiate()
	add_child_autofree(heli)
	var caja := _caja(heli)
	assert_between(maxf(caja.size.x, caja.size.z), 1.0, 1.4, "rotor a rotor ≈ 1,2 m")
	assert_between(caja.size.y, 0.4, 0.7, "alto ≈ 0,5 m")


func _superficies(n: Node) -> int:
	var total := 0
	var pila := [n]
	while not pila.is_empty():
		var x: Node = pila.pop_back()
		if x is MeshInstance3D and (x as MeshInstance3D).mesh != null:
			total += (x as MeshInstance3D).mesh.get_surface_count()
		pila.append_array(x.get_children())
	return total


func test_rover_compacto_reduce_llamadas_de_dibujo() -> void:
	if not RoverNasa.disponible():
		pending("sin modelo del Perseverance")
		return
	var completo := RoverNasa.crear(0)
	var n_completo := _superficies(completo)
	completo.free()
	var compacto := RoverNasa.crear(1)
	var n_compacto := _superficies(compacto)
	compacto.free()
	RoverNasa.crear(0).free()  # deja el nivel completo para otras pruebas
	assert_lt(n_compacto, n_completo * 0.6, "el detalle reducido recorta al menos 40 %% de las superficies (%d -> %d)" % [n_completo, n_compacto])
	assert_lt(n_compacto, 60)
