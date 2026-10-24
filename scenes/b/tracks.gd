extends MeshInstance3D
## Huellas del rover: una sola malla dinámica de dos bandas, limitada a los últimos 24 m (≤ 600 triángulos).
## No deforma el suelo ni crea un decal por casilla.
const W := preload("res://scenes/b/world_art.gd")
const MAX_LENGTH := 24.0
const STEP := 0.5
const TRACK_HALF := 0.62  ## separación de las bandas respecto al centro del rover
const BAND := 0.26
const COLOR := Color(0.36, 0.17, 0.11, 0.42)

var ground: Callable  ## (x, z) -> altura
var _points: Array[Vector3] = []


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material_override = W.flat_material(Color.WHITE, true, 0)
	mesh = ArrayMesh.new()


func clear() -> void:
	_points.clear()
	mesh = ArrayMesh.new()


## Huellas iniciales que llegan al punto de aterrizaje (el rover ya ha rodado un poco, como en el mockup).
func seed_curve(rover_pos: Vector3, largo: float = 12.0) -> void:
	_points.clear()
	var n := int(largo / STEP)
	for k in range(n, -1, -1):
		var d := k * STEP
		_points.append(Vector3(rover_pos.x + sin(d * 0.32) * 1.3, 0.0, rover_pos.z + d))
	_rebuild()


## Llamar cada cuadro con la posición del rover; solo añade un punto cada STEP metros.
func track(pos: Vector3) -> void:
	var p := Vector3(pos.x, 0.0, pos.z)
	if not _points.is_empty() and _points[_points.size() - 1].distance_to(p) < STEP:
		return
	if not _points.is_empty() and _points[_points.size() - 1].distance_to(p) > 4.0:
		_points.clear()  # salto (aterrizaje, reinicio): no unir con una banda larga
	_points.append(p)
	var maximo := int(MAX_LENGTH / STEP) + 1
	while _points.size() > maximo:
		_points.pop_front()
	_rebuild()


func _rebuild() -> void:
	var am := ArrayMesh.new()
	if _points.size() < 2:
		mesh = am
		return
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var total := _points.size()
	for lado in [-1.0, 1.0]:
		for k in range(total - 1):
			var a := _points[k]
			var b := _points[k + 1]
			var dir := (b - a).normalized()
			var normal := Vector3(-dir.z, 0, dir.x)
			# Cada tramo deja solo el 60 % marcado: se lee como la pisada de las grampas de la rueda.
			var b_marca: Vector3 = a + (b - a) * 0.6
			var centro_a: Vector3 = a + normal * TRACK_HALF * lado
			var centro_b: Vector3 = b_marca + normal * TRACK_HALF * lado
			var esquinas := [centro_a - normal * BAND / 2.0, centro_a + normal * BAND / 2.0, centro_b + normal * BAND / 2.0, centro_b - normal * BAND / 2.0]
			var alfa_a := COLOR.a * float(k) / total
			var alfa_b := COLOR.a * float(k + 1) / total
			for idx in [0, 1, 2, 0, 2, 3]:
				var q: Vector3 = esquinas[idx]
				var y: float = ground.call(q.x, q.z) if ground.is_valid() else 0.0
				verts.append(Vector3(q.x, y + 0.035, q.z))
				cols.append(Color(COLOR.r, COLOR.g, COLOR.b, alfa_a if idx in [0, 1] else alfa_b))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am
