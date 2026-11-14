extends GutTest
## Relieve del suelo: las mallas del suelo llevan tangentes (sin ellas Godot invierte el mapa de normales y los cráteres
## de la Luna se veían como bultos) y el regolito lunar es suave, sin costuras y repite poco. Ver ARTE_Y_LICENCIAS.md.

const W := preload("res://scenes/b/world_art.gd")
const T := preload("res://scenes/b/terrain.gd")
const NORMAL_LUNA := "res://assets/texturas/luna_regolito_normal.jpg"
const DETALLE_LUNA := "res://assets/texturas/luna_regolito_detalle.jpg"


func after_each() -> void:
	Destino.id = "marte"
	W.quality = true
	W.apply_quality()


## La imagen original (el .jpg, no la versión comprimida en VRAM) para medir sus píxeles.
func _imagen(ruta: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(ruta))
	assert_not_null(img, ruta)
	return img


func _comprobar_tangentes(malla: Mesh, nombre: String) -> void:
	for s in malla.get_surface_count():
		var a := malla.surface_get_arrays(s)
		var normales: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		assert_not_null(a[Mesh.ARRAY_TANGENT], nombre + " tiene tangentes")
		if a[Mesh.ARRAY_TANGENT] == null:
			return
		var tg: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
		assert_eq(tg.size(), normales.size() * 4, nombre + ": una tangente por vértice")
		var malas := 0
		for i in range(0, normales.size(), 7):
			var t := Vector3(tg[i * 4], tg[i * 4 + 1], tg[i * 4 + 2])
			# Igual que SurfaceTool.generate_tangents con UV = xz / 5: hacia +X, perpendicular a la normal y w = +1.
			if t.x <= 0.0 or absf(t.dot(normales[i])) > 0.01 or tg[i * 4 + 3] != 1.0:
				malas += 1
		assert_eq(malas, 0, nombre + ": tangentes hacia +X sobre la superficie")


func test_la_tangente_del_suelo_es_la_de_godot() -> void:
	assert_eq(T.tangente_suelo(Vector3.UP), Plane(1, 0, 0, 1), "suelo plano: la misma que generate_tangents")
	var n := Vector3(0.3, 0.9, 0.1).normalized()
	assert_almost_eq(T.tangente_suelo(n).normal.dot(n), 0.0, 0.0001, "en pendiente sigue sobre la superficie")


func test_las_mallas_del_suelo_llevan_tangentes_para_que_los_crateres_se_hundan() -> void:
	var terreno: Node3D = T.new()
	add_child_autofree(terreno)
	terreno.configure([], [Vector2i(3, 3)], {"min": Vector2i(-12, -12), "max": Vector2i(12, 12)}, [])
	var trozos := terreno.find_children("Ground_*", "MeshInstance3D", true, false)
	assert_gt(trozos.size(), 0, "hay trozos de suelo")
	for m in trozos:
		_comprobar_tangentes((m as MeshInstance3D).mesh, m.name)
	var colinas := terreno.find_child("Hills", true, false) as MeshInstance3D
	assert_not_null(colinas, "colinas lejanas")
	if colinas != null:
		_comprobar_tangentes(colinas.mesh, "Hills")


func test_el_regolito_lunar_es_suave_como_en_las_fotos() -> void:
	var img := _imagen(NORMAL_LUNA)
	var suma := 0.0
	var empinados := 0
	var cuenta := 0
	for y in range(0, img.get_height(), 3):
		for x in range(0, img.get_width(), 3):
			var c := img.get_pixel(x, y)
			var n := Vector3(c.r * 2.0 - 1.0, c.g * 2.0 - 1.0, c.b * 2.0 - 1.0).normalized()
			var inclinacion := rad_to_deg(acos(clampf(n.z, -1.0, 1.0)))
			suma += inclinacion
			empinados += 1 if inclinacion > 25.0 else 0
			cuenta += 1
	# La textura anterior (cráteres iguales y muy marcados) daba 17° de media y un 20 % de píxeles de más de 25°.
	assert_lt(suma / cuenta, 9.0, "inclinación media baja: llanura ondulada con cráteres")
	assert_lt(float(empinados) / cuenta, 0.02, "pocas paredes empinadas: solo los cráteres jóvenes")


func test_el_regolito_lunar_no_tiene_costuras_ni_mucho_contraste() -> void:
	var img := _imagen(DETALLE_LUNA)
	var w := img.get_width()
	var h := img.get_height()
	var borde := 0.0
	var interior := 0.0
	var media := 0.0
	var media2 := 0.0
	for i in h:
		borde += absf(img.get_pixel(0, i).get_luminance() - img.get_pixel(w - 1, i).get_luminance())
		interior += absf(img.get_pixel(w / 2, i).get_luminance() - img.get_pixel(w / 2 + 1, i).get_luminance())
		var l := img.get_pixel(i % w, i).get_luminance()
		media += l
		media2 += l * l
	assert_lt(borde, interior * 1.3, "el borde izquierdo continúa en el derecho: repite sin costura")
	media /= h
	var desviacion := sqrt(maxf(media2 / h - media * media, 0.0))
	assert_almost_eq(media, 0.8, 0.05, "«detalle» con media 0,8: no cambia el tono del suelo")
	assert_lt(desviacion, 0.1, "sin manchas fuertes que delaten la repetición")


func test_en_la_luna_el_suelo_repite_cada_20_m_y_en_marte_no_cambia() -> void:
	W.quality = true
	W.ground_material()
	Destino.id = "luna"
	W.apply_quality()
	assert_almost_eq(5.0 / W.ground_material().uv1_scale.x, 20.0, 0.01, "Luna: cada 20 m (UV = xz / 5)")
	Destino.id = "marte"
	W.apply_quality()
	assert_almost_eq(5.0 / W.ground_material().uv1_scale.x, 12.5, 0.01, "Marte: cada 12,5 m como antes")
