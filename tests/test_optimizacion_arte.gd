extends GutTest
## Presupuestos de arte para que el juego siga ligero (ajuste Baja y web): modelos con pocos triángulos y materiales,
## texturas de 1024 px como mucho y comprimidas en VRAM, emisivos acotados, las texturas de Marte solo en Marte y con
## «texturas» activado, y el paisaje lejano con una malla razonable. Ver scenes/b/docs/ARTE_Y_LICENCIAS.md.

const W := preload("res://scenes/b/world_art.gd")
const CARPETA_MODELOS := "res://assets/modelos/"
const CARPETA_TEXTURAS := "res://assets/texturas/"
const EDIFICIOS := ["hangar_cuadrado", "hangar_roundA", "torreta_simple", "torreta_doble", "foco", "taladro", "anthena_juego"]
const MAX_TRIANGULOS := 2500  ## por modelo del equipo
const MAX_MATERIALES := 8  ## cada material es una llamada de dibujo (modelos_equipo.gd funde por material)
const MAX_EMISIVOS := 2
const MAX_LADO_TEXTURA := 1024
const MAX_BYTES_TEXTURAS := 6 * 1024 * 1024  ## descarga de la versión web
const ESCENAS := ["res://scenes/b/assets/models/station.tscn", "res://scenes/b/assets/models/companion.tscn",
	"res://scenes/b/assets/models/drone.tscn", "res://scenes/b/assets/models/rover.tscn"]


func after_each() -> void:
	Destino.id = "marte"
	W.quality = true
	W.apply_quality()


## {"triangulos", "materiales": Array[Material]} de todas las mallas bajo «nodo».
func _medir(nodo: Node) -> Dictionary:
	var tris := 0
	var mats: Array[Material] = []
	for m in nodo.find_children("*", "MeshInstance3D", true, false):
		var malla: Mesh = (m as MeshInstance3D).mesh
		if malla == null:
			continue
		for i in malla.get_surface_count():
			var arrays := malla.surface_get_arrays(i)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			tris += (indices.size() if indices != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
			var mat := (m as MeshInstance3D).get_active_material(i)
			if mat != null and not mats.has(mat):
				mats.append(mat)
	return {"triangulos": tris, "materiales": mats}


func _modelos() -> PackedStringArray:
	var lista := PackedStringArray()
	for f in DirAccess.get_files_at(CARPETA_MODELOS):
		if f.ends_with(".glb"):
			lista.append(f.get_basename())
	return lista


func test_los_modelos_del_equipo_son_ligeros() -> void:
	var modelos := _modelos()
	assert_gt(modelos.size(), 10, "están los modelos del equipo")
	for nombre in modelos:
		var nodo: Node = (load(CARPETA_MODELOS + nombre + ".glb") as PackedScene).instantiate()
		var m := _medir(nodo)
		assert_lt(int(m["triangulos"]), MAX_TRIANGULOS + 1, "%s: %d triángulos" % [nombre, m["triangulos"]])
		assert_lt((m["materiales"] as Array).size(), MAX_MATERIALES + 1, "%s: %d materiales" % [nombre, (m["materiales"] as Array).size()])
		nodo.free()


func test_los_edificios_brillan_de_noche_con_pocos_materiales_emisivos() -> void:
	for nombre in EDIFICIOS:
		var nodo: Node = (load(CARPETA_MODELOS + nombre + ".glb") as PackedScene).instantiate()
		var emisivos := 0
		for mat in _medir(nodo)["materiales"]:
			if mat is StandardMaterial3D and (mat as StandardMaterial3D).emission_enabled:
				emisivos += 1
				assert_true(str(mat.resource_name).begins_with("emisivo_"), "%s: el emisivo %s sigue la convención de nombres" % [nombre, mat.resource_name])
		assert_between(emisivos, 1, MAX_EMISIVOS, "%s tiene luces o ventanas (y no demasiados materiales emisivos)" % nombre)
		nodo.free()


func test_las_texturas_de_marte_son_de_1024_como_mucho_y_van_comprimidas() -> void:
	var total := 0
	var archivos := 0
	for f in DirAccess.get_files_at(CARPETA_TEXTURAS):
		if not f.ends_with(".jpg"):
			continue
		archivos += 1
		var ruta := CARPETA_TEXTURAS + f
		total += FileAccess.get_file_as_bytes(ruta).size()
		var tex := load(ruta) as Texture2D
		assert_not_null(tex, f)
		assert_lt(maxi(tex.get_width(), tex.get_height()), MAX_LADO_TEXTURA + 1, "%s: %d px" % [f, tex.get_width()])
		var importacion := FileAccess.get_file_as_string(ruta + ".import")
		assert_string_contains(importacion, "compress/mode=2", "%s: comprimida en VRAM" % f)
		assert_string_contains(importacion, "mipmaps/generate=true", "%s: con mipmaps (se repite en el suelo)" % f)
		assert_string_contains(importacion, "detect_3d/compress_to=0", "%s: el editor no cambia sus ajustes al abrirse" % f)
		if f.ends_with("_normal.jpg"):
			assert_string_contains(importacion, "compress/normal_map=1", "%s: marcada como mapa de normales" % f)
	assert_eq(archivos, 8, "regolito y roca: color, detalle, normal y rugosidad")
	assert_lt(total, MAX_BYTES_TEXTURAS, "las texturas pesan %.1f MB" % (total / 1048576.0))


func test_en_marte_el_suelo_las_rocas_y_las_lomas_usan_las_texturas() -> void:
	Destino.id = "marte"
	W.quality = true
	W.ground_material()
	W.rock_material()
	W.mountain_material()
	W.apply_quality()
	assert_string_contains(W.ground_material().albedo_texture.resource_path, "marte_regolito_detalle")
	assert_not_null(W.ground_material().roughness_texture, "rugosidad del suelo")
	assert_string_contains(W.rock_material().albedo_texture.resource_path, "marte_roca_estratos_detalle")
	assert_string_contains(W.mountain_material().albedo_texture.resource_path, "marte_roca_estratos_detalle")


func test_la_luna_no_usa_las_texturas_de_marte() -> void:
	Destino.id = "luna"
	W.quality = true
	W.ground_material()
	W.mountain_material()
	W.apply_quality()
	assert_false(W.ground_material().albedo_texture.resource_path.contains("marte"), "suelo lunar con su textura")
	assert_null(W.ground_material().roughness_texture)
	assert_null(W.mountain_material().albedo_texture, "las lomas lunares sin estratos de Marte")


func test_el_ajuste_baja_no_carga_texturas() -> void:
	W.quality = false
	W.ground_material()
	W.rock_material()
	W.mountain_material()
	W.apply_quality()
	assert_null(W.ground_material().albedo_texture)
	assert_null(W.ground_material().roughness_texture)
	assert_null(W.rock_material().albedo_texture)
	assert_null(W.mountain_material().albedo_texture)


func test_las_escenas_del_proyecto_tienen_materiales_del_entorno() -> void:
	for ruta in ESCENAS:
		var texto := FileAccess.get_file_as_string(ruta)
		assert_string_contains(texto, "materiales_entorno", "%s: polvo y PBR aplicados" % ruta)
		assert_false(texto.contains("roughness = 0.86"), "%s: no quedan materiales planos de antes" % ruta)


func test_el_paisaje_lejano_es_una_malla_ligera() -> void:
	var fino := FastNoiseLite.new()
	var lomas := Horizonte.lomas(142.0, fino)
	var mesetas := Horizonte.mesetas(142.0, fino)
	var total := int(_medir(lomas)["triangulos"]) + int(_medir(mesetas)["triangulos"])
	assert_lt(total, 15000, "lomas y mesetas: %d triángulos" % total)
	assert_eq(lomas.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "sin sombras")
	lomas.free()
	mesetas.free()
