extends Node3D
## Mundo de Jezero (diseño visual consolidado, sección 5):
## suelo continuo facetado de 46×46 m jugables sin cuadrícula dibujada; franja no jugable de 23 a 36 m con
## surcos y derrubios; cuenca seca pálida de 36 a 80 m; dos anillos de lomas de 80 a 170 m en 360°.
## También presenta objetivos, obstáculos, selección, ruta, cursor de destino y la retícula a demanda.
const Art := preload("res://scenes/b/art.gd")
const W := preload("res://scenes/b/world_art.gd")

const TILE := 2.0
const LIMIT := 11
const PLAY_EDGE := 23.0
const BASIN_Y := -0.55
const INNER := 40.0  ## mitad del lado de la malla detallada (después sigue el plano de la cuenca)
const CELL := 2.0
const OUTER := 80.0  ## mitad del lado de la malla de colinas lejanas (celdas de 4 m)
const OUTER_CELL := 4.0
const REGOLITH := Color("B97E64")
const CLAY := Color("C79170")
const SHADOW_ROCK := Color("90614D")
const BASIN := Color("C99C78")
const MOUNTAIN := Color("85655C")
const LAKE_CENTER := Vector2(-42.0, -48.0)
const LAKE_ROT := -0.8
const TARGET_LIGHT := Color("FBE0AC")

var targets: Dictionary = {}
var selected := ""
var selection: MeshInstance3D
var route_line: MeshInstance3D
var cursor: MeshInstance3D
var obstacles: Array[Vector2i] = []
var grid: Node3D
var grid_manual := false
var bounds_min := Vector2i(-LIMIT, -LIMIT)
var bounds_max := Vector2i(LIMIT, LIMIT)

var _noise := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _dune := FastNoiseLite.new()
var _fine := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _outline: Array[MeshInstance3D] = []
var _outlined := ""
var _outline_material: StandardMaterial3D
var _clock := 0.0
var _heights := PackedFloat32Array()
var _n := 0
var _decor: Node3D
var _grid_timer := 0.0


func _init() -> void:
	_noise.seed = 20261023
	_noise.frequency = 0.045
	_noise.fractal_octaves = 2
	_patch.seed = 77
	_patch.frequency = 0.09
	_patch.fractal_octaves = 1
	_dune.seed = 31
	_dune.frequency = 0.02
	_dune.fractal_octaves = 3
	_fine.seed = 5
	_fine.frequency = 0.55
	_fine.fractal_octaves = 1
	_hills.seed = 88
	_hills.frequency = 0.017
	_hills.fractal_octaves = 3
	_n = int(2.0 * INNER / CELL) + 1
	_heights.resize(_n * _n)
	for j in range(_n):
		for i in range(_n):
			_heights[j * _n + i] = _raw_height(-INNER + i * CELL, -INNER + j * CELL)


func _ready() -> void:
	_build_ground()
	_build_outer()
	_build_basin()
	_build_lake()
	_build_mountains()
	_build_grid()
	_build_cursor()
	selection = Art.ring(self, 0.8, Vector3.ZERO, TARGET_LIGHT)
	selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection.visible = false
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)
	_build_decor()


# ---------------------------------------------------------------- relieve

## Distancia «cuadrada» (el área jugable es un cuadrado) y redondeada con ruido (para disimular el contorno).
func _square(x: float, z: float) -> float:
	return maxf(absf(x), absf(z))


func _round(x: float, z: float) -> float:
	return pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25) + _noise.get_noise_2d(z * 0.6, x * 0.6) * 3.0


func _raw_height(x: float, z: float) -> float:
	var c := _square(x, z)
	var r := _round(x, z)
	var h := _noise.get_noise_2d(x, z) * 0.2 + _dune.get_noise_2d(x, z) * 0.85 + _dune.get_noise_2d(x * 2.7 + 9.0, z * 2.7) * 0.18
	# Franja de transición: el suelo sube con surcos secos y luego baja hacia la cuenca.
	var borde := c + maxf(0.0, _noise.get_noise_2d(x * 0.3, z * 0.3)) * 2.0
	var subida := smoothstep(23.5, 30.5, borde)
	if subida > 0.0:
		var angulo := atan2(z, x)
		var surco := absf(sin(angulo * 22.0 + _noise.get_noise_2d(x * 0.7, z * 0.7) * 4.0)) * 0.45
		h += subida * (0.75 + _noise.get_noise_2d(x * 0.5, z * 0.5) * 0.4) + surco * subida * 0.7
	var bajada := smoothstep(30.0, 38.5, maxf(c, r * 0.95))
	return lerpf(h, BASIN_Y, bajada)


## 0 dentro del pasillo hacia el lago (se mantiene bajo y despejado) y 1 fuera de él.
func _corridor_mask(x: float, z: float) -> float:
	var dir := LAKE_CENTER.normalized()
	var p := Vector2(x, z)
	var along := p.dot(dir)
	if along < 20.0:
		return 1.0
	var lateral := absf(p.dot(Vector2(-dir.y, dir.x)))
	var ancho := 8.0 + along * 0.15
	return smoothstep(ancho, ancho + 12.0, lateral)


## Colinas y crestas entre el área jugable y las montañas: dejan libre el pasillo del lago y el propio lago.
func _outer_height(x: float, z: float) -> float:
	var d := _square(x, z)
	var subida := smoothstep(41.0, 60.0, d) * (1.0 - smoothstep(66.0, 80.0, d))
	if subida <= 0.0:
		return BASIN_Y
	var local := (Vector2(x, z) - LAKE_CENTER).rotated(-LAKE_ROT)
	var en_lago := smoothstep(1.0, 1.9, pow(local.x / 54.0, 2.0) + pow(local.y / 25.0, 2.0))
	var mascara := subida * en_lago * lerpf(0.16, 1.0, _corridor_mask(x, z))
	if mascara <= 0.0:
		return BASIN_Y
	var cresta := pow(1.0 - absf(_hills.get_noise_2d(x, z)), 2.4)
	var onda := 0.5 + 0.5 * _hills.get_noise_2d(x * 0.5 + 30.0, z * 0.5)
	return BASIN_Y + mascara * (cresta * 9.0 + onda * 2.5 + 0.4 + _fine.get_noise_2d(x * 0.3, z * 0.3) * 0.25)


func _outer_normal(x: float, z: float) -> Vector3:
	var e := 2.0
	var dx := (_outer_height(x + e, z) - _outer_height(x - e, z)) / (2.0 * e)
	var dz := (_outer_height(x, z + e) - _outer_height(x, z - e)) / (2.0 * e)
	return Vector3(-dx, 1.0, -dz).normalized()


func _outer_vertex(st: SurfaceTool, x: float, z: float) -> void:
	var v := Vector3(x, _outer_height(x, z), z)
	var n := _outer_normal(x, z)
	var color := _ground_color(v, n.y)
	color = color.lerp(Color("A9694C"), clampf((v.y - BASIN_Y) / 6.0, 0.0, 1.0) * 0.45)
	if n.y < 0.9:
		# Capas de roca en las laderas: franjas de tono según la altura.
		color = color * (0.9 + 0.1 * sin(v.y * 5.5))
	st.set_color(color)
	st.set_normal(n)
	st.set_uv(Vector2(x, z) / 5.0)
	st.add_vertex(v)


## Malla de colinas lejanas (la zona central la cubre la malla detallada).
func _build_outer() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pasos := int(2.0 * OUTER / OUTER_CELL)
	for j in range(pasos):
		for i in range(pasos):
			var x := -OUTER + i * OUTER_CELL
			var z := -OUTER + j * OUTER_CELL
			if x >= -INNER and x + OUTER_CELL <= INNER and z >= -INNER and z + OUTER_CELL <= INNER:
				continue
			var c := OUTER_CELL
			_outer_vertex(st, x, z)
			_outer_vertex(st, x + c, z)
			_outer_vertex(st, x, z + c)
			_outer_vertex(st, x + c, z)
			_outer_vertex(st, x + c, z + c)
			_outer_vertex(st, x, z + c)
	var colinas := MeshInstance3D.new()
	colinas.name = "Hills"
	colinas.mesh = st.commit()
	colinas.material_override = W.ground_material()
	colinas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(colinas)


## Altura exacta del suelo dibujado (interpolación en el mismo triángulo de la malla).
func height_at(x: float, z: float) -> float:
	if absf(x) >= INNER or absf(z) >= INNER:
		return _outer_height(x, z)
	var fx := (x + INNER) / CELL
	var fz := (z + INNER) / CELL
	var i := clampi(floori(fx), 0, _n - 2)
	var j := clampi(floori(fz), 0, _n - 2)
	var u := fx - i
	var v := fz - j
	var h00 := _heights[j * _n + i]
	var h10 := _heights[j * _n + i + 1]
	var h01 := _heights[(j + 1) * _n + i]
	var h11 := _heights[(j + 1) * _n + i + 1]
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)


func _vertex(i: int, j: int) -> Vector3:
	return Vector3(-INNER + i * CELL, _heights[j * _n + i], -INNER + j * CELL)


func _ground_color(pos: Vector3, normal_y: float) -> Color:
	var mancha := _patch.get_noise_2d(pos.x, pos.z)
	var color := REGOLITH
	if mancha > 0.05:
		color = REGOLITH.lerp(CLAY, smoothstep(0.05, 0.45, mancha))
	elif mancha < -0.2:
		color = REGOLITH.lerp(SHADOW_ROCK, smoothstep(-0.2, -0.6, mancha) * 0.55)
	# Vetas claras de arena en las crestas de las dunas.
	var cresta := smoothstep(0.1, 0.55, _dune.get_noise_2d(pos.x + 40.0, pos.z - 17.0))
	color = color.lerp(Color("D19A72"), cresta * 0.35)
	var hacia_cuenca := smoothstep(27.0, 38.0, maxf(_square(pos.x, pos.z), _round(pos.x, pos.z)))
	color = color.lerp(BASIN, hacia_cuenca)
	color = color.lerp(SHADOW_ROCK, clampf((0.97 - normal_y) * 3.0, 0.0, 0.5))
	var grano := 1.0 + _fine.get_noise_2d(pos.x, pos.z) * 0.08
	return Color(color.r * grano, color.g * grano, color.b * grano)


func _smooth_normal(i: int, j: int) -> Vector3:
	var i0 := maxi(i - 1, 0)
	var i1 := mini(i + 1, _n - 1)
	var j0 := maxi(j - 1, 0)
	var j1 := mini(j + 1, _n - 1)
	var dx := (_heights[j * _n + i1] - _heights[j * _n + i0]) / ((i1 - i0) * CELL)
	var dz := (_heights[j1 * _n + i] - _heights[j0 * _n + i]) / ((j1 - j0) * CELL)
	return Vector3(-dx, 1.0, -dz).normalized()


func _emit_vertex(st: SurfaceTool, i: int, j: int) -> void:
	var v := _vertex(i, j)
	var n := _smooth_normal(i, j)
	st.set_color(_ground_color(v, n.y))
	st.set_normal(n)
	st.set_uv(Vector2(v.x, v.z) / 5.0)
	st.add_vertex(v)


## Suelo continuo de normales suaves (dunas) con color por vértice; las facetas quedan para rocas y montañas.
func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(_n - 1):
		for i in range(_n - 1):
			# Vértices en sentido horario visto desde arriba (cara frontal de Godot).
			_emit_vertex(st, i, j)
			_emit_vertex(st, i + 1, j)
			_emit_vertex(st, i, j + 1)
			_emit_vertex(st, i + 1, j)
			_emit_vertex(st, i + 1, j + 1)
			_emit_vertex(st, i, j + 1)
	var suelo := MeshInstance3D.new()
	suelo.name = "Ground"
	suelo.mesh = st.commit()
	suelo.material_override = W.ground_material()
	suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(suelo)


## Lecho del antiguo lago: plano facetado pálido que continúa la malla detallada hasta las lomas.
func _build_basin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paso := 10.0
	var lado := 90.0
	var y := BASIN_Y - 0.015
	var x := -lado
	while x < lado:
		var z := -lado
		while z < lado:
			if not (x >= -INNER and x + paso <= INNER and z >= -INNER and z + paso <= INNER):
				var a := Vector3(x, y, z)
				var b := Vector3(x + paso, y, z)
				var c := Vector3(x, y, z + paso)
				var d := Vector3(x + paso, y, z + paso)
				for t in [[a, c, b], [b, c, d]]:
					var centro: Vector3 = (t[0] + t[1] + t[2]) / 3.0
					var mancha := _patch.get_noise_2d(centro.x * 0.4, centro.z * 0.4)
					var color := BASIN.lerp(Color("C99A73"), clampf(mancha * 1.6, 0.0, 1.0) * 0.6)
					color = color * rng.randf_range(0.97, 1.03)
					color.a = 1.0
					W.tri(st, t[0], t[1], t[2], color)
			z += paso
		x += paso
	var cuenca := MeshInstance3D.new()
	cuenca.name = "Basin"
	cuenca.mesh = st.commit()
	cuenca.material_override = W.vertex_material()
	cuenca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cuenca)


## Antiguo lago: lecho pálido y liso en la cuenca, delante de la vista inicial (contorno irregular, un solo plano).
func _build_lake() -> void:
	var anillos := 7
	var segmentos := 30
	var y := BASIN_Y + 0.03
	var rejilla: Array = []
	for r in range(anillos + 1):
		var t := float(r) / anillos
		var fila: Array = []
		for k in range(segmentos):
			var ang := TAU * k / segmentos
			var rx := 44.0 * (1.0 + _noise.get_noise_2d(cos(ang) * 4.0, sin(ang) * 4.0) * 0.35)
			var rz := 19.0 * (1.0 + _noise.get_noise_2d(cos(ang) * 4.0 + 7.0, sin(ang) * 4.0) * 0.4)
			var local := Vector2(cos(ang) * rx * t, sin(ang) * rz * t).rotated(LAKE_ROT)
			var pos := Vector3(LAKE_CENTER.x + local.x, y, LAKE_CENTER.y + local.y)
			fila.append({"p": pos, "c": _lake_color(pos, t)})
		rejilla.append(fila)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in range(anillos):
		for k in range(segmentos):
			var k2 := (k + 1) % segmentos
			var v00: Dictionary = rejilla[r][k]
			var v10: Dictionary = rejilla[r + 1][k]
			var v01: Dictionary = rejilla[r][k2]
			var v11: Dictionary = rejilla[r + 1][k2]
			for v in [v00, v10, v01, v10, v11, v01]:
				st.set_normal(Vector3.UP)
				st.set_color(v["c"])
				st.add_vertex(v["p"])
	var lago := MeshInstance3D.new()
	lago.name = "Lake"
	lago.mesh = st.commit()
	lago.material_override = W.water_material()
	lago.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lago)


## Color del lago: agua clara con reflejos, orilla húmeda más oscura y bancos de arena en el interior.
func _lake_color(pos: Vector3, t: float) -> Color:
	var agua := Color("CFB2A0").lerp(Color("BF9F89"), smoothstep(0.35, 1.0, t))
	var n := _fine.get_noise_2d(pos.x * 0.9, pos.z * 0.9)
	var banco := _noise.get_noise_2d(pos.x * 0.25 + 40.0, pos.z * 0.25)
	if banco > 0.22 and t < 0.9:
		agua = agua.lerp(Color("C9966F"), smoothstep(0.22, 0.45, banco) * 0.85)
	var veta := 0.5 + 0.5 * sin((pos.x * 0.8 + pos.z * 0.35) * 0.6 + n * 4.0)
	agua = agua.lerp(Color("F1E1D6"), smoothstep(0.75, 1.0, veta) * 0.35 * (1.0 - t * 0.5))
	if t > 0.86:
		agua = agua.lerp(Color("B58B70"), smoothstep(0.86, 1.0, t) * 0.7)
	return agua


## Pasillo entre el origen y el lago (la vista inicial mira hacia allí): sin bloques ni mesetas que lo tapen.
func _in_view_corridor(p: Vector2) -> bool:
	var destino := LAKE_CENTER
	var largo := destino.length()
	var dir := destino / largo
	var along := p.dot(dir)
	if along < 20.0 or along > largo + 10.0:
		return false
	var lateral := absf(p.dot(Vector2(-dir.y, dir.x)))
	return lateral < 9.0 + along * 0.22


func _in_lake(p: Vector2) -> bool:
	var local := (p - LAKE_CENTER).rotated(-LAKE_ROT)
	return pow(local.x / 54.0, 2.0) + pow(local.y / 25.0, 2.0) < 1.0


## Dos anillos irregulares de lomas que rodean los 360° (sin colisión ni sombras; la niebla los funde).
func _build_mountains() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 314
	ruido.frequency = 1.0
	var radios := [76.0, 84.0, 92.0, 100.0, 108.0, 116.0, 126.0, 136.0, 146.0, 156.0, 166.0]
	var segmentos := 160
	var puntos: Array = []
	for k in range(radios.size()):
		var anillo: Array = []
		for s in range(segmentos):
			var ang := TAU * s / segmentos
			var r: float = radios[k] + ruido.get_noise_2d(cos(ang) * 3.0, sin(ang) * 3.0 + k) * 5.0
			var n1 := (ruido.get_noise_2d(cos(ang) * 2.2, sin(ang) * 2.2) + 1.0) * 0.5
			var n2 := (ruido.get_noise_2d(cos(ang) * 1.4 + 40.0, sin(ang) * 1.4) + 1.0) * 0.5
			var h := BASIN_Y + (2.5 + 6.0 * n1) * _bump(r, 102.0, 24.0) + (9.0 + 15.0 * n2) * _bump(r, 158.0, 32.0)
			h += ruido.get_noise_2d(cos(ang) * 9.0, sin(ang) * 9.0 + k * 0.5) * 1.6 * smoothstep(80.0, 100.0, r)
			var cresta := 1.0 - absf(ruido.get_noise_2d(cos(ang) * 6.0 + 20.0, sin(ang) * 6.0 + k * 0.35))
			h += cresta * cresta * 4.5 * smoothstep(100.0, 150.0, r) * _bump(r, 158.0, 34.0)
			h += ruido.get_noise_2d(cos(ang) * 17.0, sin(ang) * 17.0 + k) * 1.1 * smoothstep(90.0, 130.0, r)
			anillo.append(Vector3(cos(ang) * r, h, sin(ang) * r))
		puntos.append(anillo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var anillos_n := radios.size()
	var normales: Array = []
	for k in range(anillos_n):
		var fila: Array = []
		for s_idx in range(segmentos):
			var izq: Vector3 = puntos[k][(s_idx + segmentos - 1) % segmentos]
			var der: Vector3 = puntos[k][(s_idx + 1) % segmentos]
			var dentro: Vector3 = puntos[maxi(k - 1, 0)][s_idx]
			var fuera: Vector3 = puntos[mini(k + 1, anillos_n - 1)][s_idx]
			var nrm := (fuera - dentro).cross(der - izq)
			if nrm.y < 0.0:
				nrm = -nrm
			fila.append(nrm.normalized())
		normales.append(fila)
	for k in range(anillos_n - 1):
		for s_idx in range(segmentos):
			var s2 := (s_idx + 1) % segmentos
			var idxs := [[k, s_idx], [k + 1, s_idx], [k, s2], [k, s2], [k + 1, s_idx], [k + 1, s2]]
			for ij in idxs:
				var v: Vector3 = puntos[ij[0]][ij[1]]
				var base := BASIN.lerp(MOUNTAIN, smoothstep(BASIN_Y + 0.5, BASIN_Y + 6.0, v.y))
				var tono := base * (1.0 + _fine.get_noise_2d(v.x * 0.7, v.z * 0.7) * 0.10)
				tono.a = 1.0
				st.set_color(tono)
				st.set_normal(normales[ij[0]][ij[1]])
				st.add_vertex(v)
	var lomas := MeshInstance3D.new()
	lomas.name = "Mountains"
	lomas.mesh = st.commit()
	lomas.material_override = W.vertex_material(false)
	lomas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lomas)


func _bump(r: float, centro: float, ancho: float) -> float:
	var t := (r - centro) / ancho
	return maxf(0.0, 1.0 - t * t)


# ---------------------------------------------------------------- retícula, cursor y rocas decorativas

func _build_grid() -> void:
	grid = Node3D.new()
	grid.name = "Grid"
	grid.visible = false
	add_child(grid)
	_rebuild_grid()


func _rebuild_grid() -> void:
	for hijo in grid.get_children():
		hijo.queue_free()
	var x0 := bounds_min.x * TILE - TILE / 2.0
	var x1 := bounds_max.x * TILE + TILE / 2.0
	var z0 := bounds_min.y * TILE - TILE / 2.0
	var z1 := bounds_max.y * TILE + TILE / 2.0
	var am := ArrayMesh.new()
	var verts := PackedVector3Array()
	var lineas: Array = []
	var x := x0
	while x <= x1 + 0.01:
		lineas.append([Vector3(x, 0, z0), Vector3(x, 0, z1)])
		x += TILE
	var z := z0
	while z <= z1 + 0.01:
		lineas.append([Vector3(x0, 0, z), Vector3(x1, 0, z)])
		z += TILE
	for par in lineas:
		var desde: Vector3 = par[0]
		var hasta: Vector3 = par[1]
		var pasos := int(ceil(desde.distance_to(hasta)))
		for k in range(pasos):
			var p := desde.lerp(hasta, float(k) / pasos)
			var q := desde.lerp(hasta, float(k + 1) / pasos)
			verts.append(Vector3(p.x, height_at(p.x, p.z) + 0.05, p.z))
			verts.append(Vector3(q.x, height_at(q.x, q.z) + 0.05, q.z))
	var cols := PackedColorArray()
	cols.resize(verts.size())
	cols.fill(Color(1.0, 0.96, 0.89, 0.38))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var n := MeshInstance3D.new()
	n.mesh = am
	n.material_override = W.flat_material(Color.WHITE, true, 1)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.add_child(n)


func _build_cursor() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := 0.94
	var g := 0.12
	for lado in [[Vector2(-a, -a), Vector2(a, -a + g)], [Vector2(-a, a - g), Vector2(a, a)], [Vector2(-a, -a), Vector2(-a + g, a)], [Vector2(a - g, -a), Vector2(a, a)]]:
		var p0: Vector2 = lado[0]
		var p1: Vector2 = lado[1]
		var v := [Vector3(p0.x, 0, p0.y), Vector3(p1.x, 0, p0.y), Vector3(p1.x, 0, p1.y), Vector3(p0.x, 0, p1.y)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(Color.WHITE)
			st.add_vertex(v[idx])
	cursor = MeshInstance3D.new()
	cursor.name = "Cursor"
	cursor.mesh = st.commit()
	cursor.material_override = W.flat_material(Color(1, 1, 1, 0.85), true, 2).duplicate()
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)


## Cursor de destino sobre la casilla; coral si queda fuera del área o bloqueada.
func show_cursor(tile: Vector2i, valido: bool) -> void:
	var x := tile.x * TILE
	var z := tile.y * TILE
	cursor.visible = true
	cursor.position = Vector3(x, maxf(height_at(x, z), BASIN_Y) + 0.06, z)
	var m: StandardMaterial3D = cursor.material_override
	m.albedo_color = Color(1.0, 0.96, 0.89, 0.85) if valido else Color(1.0, 0.506, 0.47, 0.9)


func hide_cursor() -> void:
	if is_instance_valid(cursor):
		cursor.visible = false


func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= bounds_min.x and tile.y >= bounds_min.y and tile.x <= bounds_max.x and tile.y <= bounds_max.y


## La retícula aparece unos segundos al elegir destino, o fija con su botón.
func flash_grid(segundos: float = 2.5) -> void:
	_grid_timer = segundos


func toggle_grid() -> void:
	grid_manual = not grid_manual


func _process(delta: float) -> void:
	_clock += delta
	if _outline_material != null:
		# Pulso discreto: ciclo de 1600 ms, opacidad entre 70 y 100 %.
		_outline_material.albedo_color.a = 0.85 + 0.15 * sin(_clock * TAU / 1.6)
	_grid_timer = maxf(0.0, _grid_timer - delta)
	if is_instance_valid(grid):
		grid.visible = grid_manual or _grid_timer > 0.0


## Rocas decorativas en MultiMesh (3 familias). Dentro del área jugable solo guijarros que no parecen obstáculos;
## los bloques grandes quedan en la franja de transición y la cuenca.
func _build_decor() -> void:
	for hijo in _decor.get_children():
		hijo.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023
	var reservado: Array[Vector2] = []
	for id in targets:
		reservado.append(Vector2(targets[id].position.x, targets[id].position.z))
	for t in obstacles:
		reservado.append(Vector2(t.x * TILE, t.y * TILE))
	reservado.append(Vector2.ZERO)
	var contactos: Array = []  # [posición, radio, opacidad] de las sombras de contacto
	var halos: Array[Vector3] = []  # rocas grandes alrededor de las que se reparten guijarros (x, radio, z)
	for t in obstacles:
		contactos.append([Vector3(t.x * TILE, height_at(t.x * TILE, t.y * TILE) + 0.07, t.y * TILE), 1.3, 0.6])
		halos.append(Vector3(t.x * TILE, 1.0, t.y * TILE))
	for id in targets:
		var tp: Vector3 = targets[id].position
		contactos.append([Vector3(tp.x, height_at(tp.x, tp.z) + 0.07, tp.z), 1.25, 0.6])
		halos.append(Vector3(tp.x, 0.9, tp.z))
	# zona: "inner" = dentro del área jugable (solo piezas pequeñas que no parecen objetivos ni obstáculos);
	# "ring" = franja de transición y cuenca (bloques y mesetas grandes).
	var familias := [
		{"id": "pebble", "mesh": "pebble", "count": 360, "min": 0.05, "max": 0.2, "zone": "inner", "clear": 1.2},
		{"id": "fragment", "mesh": "fragment", "count": 200, "min": 0.16, "max": 0.5, "zone": "inner", "clear": 1.9},
		{"id": "block", "mesh": "block", "count": 70, "min": 0.6, "max": 1.7, "zone": "ring", "clear": 2.0},
		{"id": "boulder", "mesh": "boulder", "count": 70, "min": 0.8, "max": 2.2, "zone": "ring", "clear": 2.0},
		{"id": "outcrop", "mesh": "outcrop", "count": 30, "min": 0.9, "max": 2.6, "zone": "ring", "clear": 2.0},
		{"id": "mesa0", "mesh": "mesa0", "count": 20, "min": 2.2, "max": 5.5, "zone": "mesa", "clear": 4.0},
		{"id": "mesa1", "mesh": "mesa1", "count": 20, "min": 2.2, "max": 5.5, "zone": "mesa", "clear": 4.0},
		{"id": "mesa_big", "mesh": "mesa0", "count": 12, "min": 6.0, "max": 11.0, "zone": "far", "clear": 8.0},
	]
	var paleta := [Color("B98160"), Color("A56E52"), Color("B07A5C"), Color("C69770"), Color("96654C")]
	# Cada familia pequeña usa 3 variantes de forma para que no se repita el mismo canto.
	var expandidas: Array = []
	for d in familias:
		if str(d["mesh"]).begins_with("mesa"):
			d["variant"] = 0
			expandidas.append(d)
		else:
			for v in range(3):
				var copia: Dictionary = d.duplicate()
				copia["variant"] = v
				copia["id"] = "%s_%d" % [d["id"], v]
				copia["count"] = int(ceil(float(d["count"]) / 3.0))
				expandidas.append(copia)
	familias = expandidas
	var paleta_mesa := [Color("C58C66"), Color("B67E5C"), Color("CE9A72"), Color("AE7154")]
	for datos in familias:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var malla_id: String = datos["mesh"]
		if malla_id.begins_with("mesa"):
			mm.mesh = W.mesa_mesh(int(malla_id.substr(4)))
		else:
			mm.mesh = W.rock_mesh(malla_id, int(datos["variant"]))
		var transformadas: Array[Transform3D] = []
		var colores: Array[Color] = []
		var colocados: Array[Vector3] = []
		var intentos := 0
		var zona: String = datos["zone"]
		while transformadas.size() < int(datos["count"]) and intentos < 6000:
			intentos += 1
			var rango := 68.0 if zona == "inner" or zona == "ring" else 80.0
			var p := Vector2(rng.randf_range(-rango, rango), rng.randf_range(-rango, rango))
			var c := _square(p.x, p.y)
			match zona:
				"inner":
					if c > 30.0 and rng.randf() < 0.55:
						continue
				"ring":
					if c < PLAY_EDGE + 1.5:
						continue
					if c > 40.0 and rng.randf() < 0.75:
						continue
				"mesa":
					if c < 26.0 or c > 62.0:
						continue
				"far":
					if c < 46.0 or c > 78.0:
						continue
			if _in_lake(p):
				continue
			if zona != "inner" and _in_view_corridor(p):
				continue
			var libre := true
			for q in reservado:
				if p.distance_to(q) < float(datos["clear"]):
					libre = false
					break
			if not libre:
				continue
			for q in colocados:
				if Vector2(p.x - q.x, p.y - q.z).length() < q.y * 0.6 + 1.0:
					libre = false
					break
			if not libre:
				continue
			var escala := rng.randf_range(datos["min"], datos["max"])
			var alto := escala * (rng.randf_range(0.55, 0.9) if zona == "mesa" or zona == "far" else rng.randf_range(0.75, 1.15))
			var base := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(escala * rng.randf_range(0.85, 1.2), alto, escala * rng.randf_range(0.8, 1.1)))
			var y := height_at(p.x, p.y) - escala * 0.1
			transformadas.append(Transform3D(base, Vector3(p.x, y, p.y)))
			colocados.append(Vector3(p.x, escala, p.y))
			if escala >= 0.45:
				contactos.append([Vector3(p.x, y + escala * 0.1 + 0.07, p.y), escala * (1.15 if zona != "inner" else 1.3), 0.55])
				if zona != "far" and escala >= 0.8 and escala < 3.0:
					halos.append(Vector3(p.x, escala, p.y))
			var tono: Color = (paleta_mesa if zona == "mesa" or zona == "far" else paleta)[rng.randi() % 4]
			if c > 38.0:
				tono = tono.lerp(BASIN, 0.3)
			tono = tono.lerp(CLAY, 0.3)
			colores.append(tono * rng.randf_range(1.0, 1.2))
		mm.instance_count = transformadas.size()
		for k in range(transformadas.size()):
			mm.set_instance_transform(k, transformadas[k])
			var col := colores[k]
			col.a = 1.0
			mm.set_instance_color(k, col)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Decor_" + str(datos["id"])
		inst.multimesh = mm
		inst.material_override = W.rock_material()
		var grande := float(datos["max"]) >= 0.8 and zona != "mesa" and zona != "far"
		inst.set_meta("proyecta_sombra", grande)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if grande and W.quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decor.add_child(inst)
	_build_cliffs(rng, reservado)
	_build_halos(rng, halos)
	if not contactos.is_empty():
		W.ao_blobs(_decor, contactos)


## Guijarros caídos alrededor de las rocas grandes (uno de los rasgos más visibles del mockup).
func _build_halos(rng: RandomNumberGenerator, halos: Array[Vector3]) -> void:
	var paleta := [Color("B07A5A"), Color("9C6648"), Color("BF8B66"), Color("8E5D44")]
	for variante in range(3):
		var transformadas: Array[Transform3D] = []
		var colores: Array[Color] = []
		for h in halos:
			if rng.randi() % 3 != variante:
				continue
			for k in range(rng.randi_range(2, 4)):
				var ang := rng.randf() * TAU
				var radio: float = h.y * rng.randf_range(0.9, 1.7) + 0.2
				var x: float = h.x + cos(ang) * radio
				var z: float = h.z + sin(ang) * radio
				var e := rng.randf_range(0.05, 0.17) * clampf(h.y, 0.8, 1.6)
				var base := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(e * 1.1, e * rng.randf_range(0.6, 1.0), e))
				transformadas.append(Transform3D(base, Vector3(x, height_at(x, z) - e * 0.15, z)))
				colores.append(paleta[rng.randi() % 4] * rng.randf_range(0.8, 0.98))
		if transformadas.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = W.rock_mesh("pebble", variante)
		mm.instance_count = transformadas.size()
		for k in range(transformadas.size()):
			mm.set_instance_transform(k, transformadas[k])
			var col := colores[k]
			col.a = 1.0
			mm.set_instance_color(k, col)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Halo_%d" % variante
		inst.multimesh = mm
		inst.material_override = W.rock_material()
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decor.add_child(inst)


## Farallones: grupos de lajas altas y estratificadas con bloques caídos alrededor, sobre las colinas y la franja exterior.
func _build_cliffs(rng: RandomNumberGenerator, reservado: Array[Vector2]) -> void:
	var grupos := {}
	var centros: Array[Vector2] = []
	var paleta := [Color("B98563"), Color("A97656"), Color("C49169"), Color("9F6E52")]
	var intentos := 0
	while centros.size() < 16 and intentos < 800:
		intentos += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(34.0, 66.0)
		var p := Vector2(cos(ang), sin(ang)) * dist
		if _square(p.x, p.y) < PLAY_EDGE + 5.0 or _in_lake(p) or _in_view_corridor(p):
			continue
		var libre := true
		for q in reservado:
			if p.distance_to(q) < 5.0:
				libre = false
				break
		for q in centros:
			if p.distance_to(q) < 15.0:
				libre = false
				break
		if not libre:
			continue
		centros.append(p)
		var escala := rng.randf_range(1.8, 3.4)
		var piezas: Array = []
		for k in range(rng.randi_range(1, 2)):
			var o := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * escala * 0.5
			piezas.append(["cliff", rng.randi() % 3, o, escala * rng.randf_range(0.8, 1.15), true])
		for k in range(rng.randi_range(3, 5)):
			var a2 := rng.randf() * TAU
			var o2 := Vector2(cos(a2), sin(a2)) * escala * rng.randf_range(1.0, 1.9)
			piezas.append([("boulder" if rng.randf() < 0.55 else "block"), rng.randi() % 3, o2, escala * rng.randf_range(0.22, 0.42), false])
		for pieza in piezas:
			var familia: String = pieza[0]
			var clave := "%s%d" % [familia, pieza[1]]
			if not grupos.has(clave):
				grupos[clave] = {"mesh": W.rock_mesh(familia, pieza[1]), "t": [], "c": [], "sombra": pieza[4]}
			var pos2: Vector2 = p + pieza[2]
			var e: float = pieza[3]
			var base := Basis(Vector3.UP, rng.randf() * TAU)
			if familia == "cliff":
				base = base * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(-9.0, 9.0))) * Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-9.0, 9.0)))
			base = base.scaled(Vector3(e * rng.randf_range(0.9, 1.25), e * rng.randf_range(0.9, 1.3), e * rng.randf_range(0.85, 1.1)))
			grupos[clave]["t"].append(Transform3D(base, Vector3(pos2.x, height_at(pos2.x, pos2.y) - e * 0.18, pos2.y)))
			var tono: Color = paleta[rng.randi() % 4]
			grupos[clave]["c"].append(tono.lerp(CLAY, 0.2) * rng.randf_range(1.0, 1.15))
	for clave in grupos:
		var g: Dictionary = grupos[clave]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = g["mesh"]
		mm.instance_count = g["t"].size()
		for k in range(g["t"].size()):
			mm.set_instance_transform(k, g["t"][k])
			var col: Color = g["c"][k]
			col.a = 1.0
			mm.set_instance_color(k, col)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Cliffs_" + clave
		inst.multimesh = mm
		inst.material_override = W.rock_material()
		inst.set_meta("proyecta_sombra", g["sombra"])
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if g["sombra"] and W.quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_decor.add_child(inst)


## Activa o quita las sombras de las rocas grandes según la opción de calidad.
func apply_quality() -> void:
	if not is_instance_valid(_decor):
		return
	for hijo in _decor.get_children():
		if hijo is GeometryInstance3D and hijo.has_meta("proyecta_sombra"):
			hijo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if hijo.get_meta("proyecta_sombra") and W.quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- objetivos, obstáculos, selección y ruta

func configure(defs: Array, blocked: Array, limites: Dictionary = {}) -> void:
	_outline.clear()
	_outlined = ""
	for n in targets.values():
		n.queue_free()
	targets.clear()
	for node in get_tree().get_nodes_in_group("b_obstacle"):
		if node.get_parent() == self:
			node.queue_free()
	obstacles.clear()
	if not limites.is_empty():
		bounds_min = limites.get("min", bounds_min)
		bounds_max = limites.get("max", bounds_max)
		_rebuild_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for value in blocked:
		var tile: Vector2i = value
		obstacles.append(tile)
		var x := tile.x * TILE
		var z := tile.y * TILE
		var familia := "block" if rng.randf() < 0.6 else "outcrop"
		var piedra := W.rock(self, familia, rng.randi() % 3, Vector3(x, height_at(x, z) - 0.1, z),
			Vector3(rng.randf_range(0.85, 1.0), rng.randf_range(0.9, 1.25), rng.randf_range(0.8, 0.95)) * (0.9 if familia == "outcrop" else 1.0),
			[Color("A9714F"), Color("9C6648"), Color("B47B58")][rng.randi() % 3])
		piedra.rotation.y = rng.randf() * TAU
		piedra.add_to_group("b_obstacle")
	for d in defs:
		var id := str(d.id)
		var tile: Vector2i = d.tile
		var n := Node3D.new()
		n.name = id
		add_child(n)
		n.position = Vector3(tile.x * TILE, height_at(tile.x * TILE, tile.y * TILE), tile.y * TILE)
		var tipo := str(d.get("type", "rock"))
		match tipo:
			"mineral":
				_mineral(n, rng)
			"buried":
				_buried(n)
			_:
				_strata(n, rng)
		n.visible = d.get("revealed", false)
		targets[id] = n
	if is_instance_valid(_decor):
		_build_decor()


## Roca objetivo: peñasco facetado con capas sedimentarias (franjas de tono) y fragmentos alrededor.
func _strata(n: Node3D, rng: RandomNumberGenerator) -> void:
	var giro := rng.randf() * TAU
	var cuerpo := W.rock(n, "boulder", 0, Vector3(0, 0.02, 0), Vector3(1.05, 1.0, 0.9), Color("B48260"))
	cuerpo.rotation.y = giro
	var lateral := W.rock(n, "boulder", 0, Vector3(0.8, -0.02, 0.3), Vector3(0.5, 0.42, 0.45), Color("A47454"))
	lateral.rotation.y = giro + 1.7
	var pieza := W.rock(n, "fragment", 1, Vector3(-0.75, 0.0, -0.35), Vector3(0.34, 0.26, 0.3), Color("9C6A4E"))
	pieza.rotation.y = giro + 0.6


## Mineral expuesto: fragmentos pálidos dentro de una fractura oscura.
func _mineral(n: Node3D, rng: RandomNumberGenerator) -> void:
	var base := W.rock(n, "fragment", 2, Vector3(0, 0.05, 0), Vector3(0.95, 0.55, 0.85), Color("5E3A30"))
	base.rotation.y = rng.randf() * TAU
	for k in range(4):
		var cristal := Art.cylinder(n, 0.11, 0.42 + k * 0.1, Vector3((k % 2) * 0.3 - 0.15, 0.3 + k * 0.03, (k / 2) * 0.25 - 0.12), Color("DCE8E0") if k % 2 == 0 else Color("B5D3CB"), 0.02)
		cristal.rotation_degrees = Vector3(rng.randf_range(-20, 20), 0, k * 14 - 20)
		cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Capa enterrada ya revelada: montículo bajo con una franja pálida del antiguo lago.
func _buried(n: Node3D) -> void:
	W.rock(n, "fragment", 1, Vector3(0, -0.05, 0), Vector3(1.4, 0.35, 1.2), Color("A86A4E"))
	W.rock(n, "block", 1, Vector3(0.1, 0.12, 0.05), Vector3(0.9, 0.12, 0.7), Color("E2C9A0"))


func update_targets(defs: Array) -> void:
	for d in defs:
		var id := str(d.id)
		if targets.has(id):
			targets[id].visible = d.get("revealed", false)


func select(id: String) -> void:
	selected = id
	selection.visible = targets.has(id) and targets[id].visible
	if selection.visible:
		selection.position = targets[id].position + Vector3(0, 0.08, 0)
		if _outlined != id or _outline.is_empty():
			_clear_outline()
			_make_outline(targets[id])
			_outlined = id
	elif not _outline.is_empty():
		_clear_outline()


## Contorno brillante del objetivo (casco invertido: la malla ampliada, solo caras traseras, sin luz).
func _make_outline(nodo: Node3D) -> void:
	if _outline_material == null:
		_outline_material = StandardMaterial3D.new()
		_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outline_material.cull_mode = BaseMaterial3D.CULL_FRONT
		_outline_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outline_material.albedo_color = Color(TARGET_LIGHT, 0.95)
		_outline_material.render_priority = 2
	for hijo in nodo.get_children():
		if hijo is MeshInstance3D and hijo.mesh != null and not hijo.has_meta("outline"):
			var borde := MeshInstance3D.new()
			borde.mesh = hijo.mesh
			borde.material_override = _outline_material
			borde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			borde.set_meta("outline", true)
			nodo.add_child(borde)
			borde.position = hijo.position
			borde.rotation = hijo.rotation
			borde.scale = hijo.scale * 1.035
			_outline.append(borde)


func _clear_outline() -> void:
	for borde in _outline:
		if is_instance_valid(borde):
			if borde.get_parent() != null:
				borde.get_parent().remove_child(borde)
			borde.queue_free()
	_outline.clear()
	_outlined = ""


func target_at(point: Vector3) -> String:
	for id in targets:
		var n: Node3D = targets[id]
		if n.visible and Vector2(n.position.x - point.x, n.position.z - point.z).length() < 1.2:
			return id
	return ""


func show_route(tiles: Array) -> void:
	if is_instance_valid(route_line):
		route_line.queue_free()
	if tiles.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tile in tiles:
		var x: float = tile.x * TILE
		var z: float = tile.y * TILE
		var p := Vector3(x, height_at(x, z) + 0.07, z)
		var r := 0.16
		for v in [Vector3(-r, 0, 0), Vector3(0, 0, -r), Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(r, 0, 0), Vector3(0, 0, r)]:
			st.set_color(Color.WHITE)
			st.add_vertex(p + v)
	route_line = MeshInstance3D.new()
	route_line.mesh = st.commit()
	route_line.material_override = W.flat_material(Color(0.604, 0.843, 0.776, 0.9), true, 1)
	route_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(route_line)


func clear_route() -> void:
	if is_instance_valid(route_line):
		route_line.queue_free()
	route_line = null
