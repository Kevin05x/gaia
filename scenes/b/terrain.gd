extends Node3D
## Mundo de Jezero (diseño visual consolidado, sección 5):
## suelo continuo facetado de 46×46 m jugables sin cuadrícula dibujada; franja no jugable de 23 a 36 m con
## surcos y derrubios; cuenca seca pálida de 36 a 80 m; dos anillos de lomas de 80 a 170 m en 360°.
## También presenta objetivos, obstáculos, selección, ruta, cursor de destino y la retícula a demanda.
const Art := preload("res://scenes/b/art.gd")
const W := preload("res://scenes/b/world_art.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")

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
var range_ring: MeshInstance3D  ## alcance de una torreta mientras se coloca
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

## Tamaño del mundo. Con un mapa grande todo lo que rodea al área jugable se aleja «_s» metros (múltiplo de 8)
## del mapa base de 23 m; las proporciones del diorama se conservan.
var zones: Array = []  ## [{"id": String, "center": Vector2 en metros}]
var lazy := false  ## true: el mundo se construye al recibir el mapa (configure), no al entrar en el árbol
var _s := 0.0
var _inner := INNER
var _outer := OUTER
var _lake := LAKE_CENTER
var _play := PLAY_EDGE
var _built := false
var _firma := ""
var _world: Node3D
var _acc: Dictionary = {}  ## instancias por familia y trozo, antes de volcarlas en MultiMesh
var _obstaculos_datos: Array = []
const CHUNK := 128.0  ## lado (m) de los trozos de las rocas escasas (centrados en el origen): cada uno se culla por su cuenta
const CHUNK_FINO := 48.0  ## ídem para lo muy numeroso (guijarros y fragmentos), que además se oculta a lo lejos
const HASH := 4.0  ## lado (m) de la rejilla que acelera las pruebas de distancia al colocar rocas
const ZONE_LOOK := {"orilla": [Color("DDC7A3"), 0.5], "falla": [Color("A9C4D3"), 0.62], "nucleo": [Color("5E4A45"), 0.7]}


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
	_calcular_alturas()


func _calcular_alturas() -> void:
	_n = int(2.0 * _inner / CELL) + 1
	_heights.resize(_n * _n)
	for j in range(_n):
		for i in range(_n):
			_heights[j * _n + i] = _raw_height(-_inner + i * CELL, -_inner + j * CELL)


func _ready() -> void:
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_build_grid()
	_build_cursor()
	selection = Art.ring(self, 0.8, Vector3.ZERO, TARGET_LIGHT)
	selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	selection.visible = false
	_decor = Node3D.new()
	_decor.name = "Decor"
	add_child(_decor)
	if not lazy:
		_build_world()
		_build_decor()


func _build_world() -> void:
	for hijo in _world.get_children():
		_world.remove_child(hijo)
		hijo.queue_free()
	_build_ground()
	_build_outer()
	_build_basin()
	_build_lake()
	_build_mountains()
	_built = true
	_firma = "%d|%s" % [int(_s), var_to_str(zones)]


## Ajusta el mundo al tamaño del mapa y a sus zonas; no hace nada si ya está construido así.
func _ajustar_mundo() -> void:
	var lado := maxi(maxi(absi(bounds_min.x), absi(bounds_min.y)), maxi(absi(bounds_max.x), absi(bounds_max.y)))
	var nuevo := maxf(0.0, ceilf((float(lado) * TILE + 1.0 - PLAY_EDGE) / 8.0) * 8.0)
	if _built and _firma == "%d|%s" % [int(nuevo), var_to_str(zones)]:
		return
	_s = nuevo
	_inner = INNER + nuevo
	_outer = OUTER + nuevo
	_lake = LAKE_CENTER * (1.0 + nuevo / 48.0)
	_play = PLAY_EDGE + nuevo
	_calcular_alturas()
	_build_world()


func _leer_zonas(valor: Array) -> void:
	zones = []
	for z in valor:
		var c: Vector2i = z.get("center", Vector2i.ZERO)
		zones.append({"id": str(z.get("id", "")), "center": Vector2(c.x * TILE, c.y * TILE)})


## Color de la zona en (x, z): RGB del tono y, en alfa, cuánto pesa. Las zonas se mezclan con suavidad (~20 m).
func _zona_mezcla(x: float, z: float) -> Color:
	var distancias: Array[float] = []
	var mejor := INF
	for zn in zones:
		var d: float = Vector2(x, z).distance_to(zn["center"])
		distancias.append(d)
		mejor = minf(mejor, d)
	var total := 0.0
	var rgb := Vector3.ZERO
	var fuerza := 0.0
	for k in range(zones.size()):
		var peso := exp(-(distancias[k] - mejor) / 9.0)
		var look: Array = ZONE_LOOK.get(str(zones[k]["id"]), [Color("C79170"), 0.0])
		var tono: Color = look[0]
		rgb += Vector3(tono.r, tono.g, tono.b) * peso
		fuerza += float(look[1]) * peso
		total += peso
	return Color(rgb.x / total, rgb.y / total, rgb.z / total, fuerza / total)


func _tinte_roca(color: Color, p: Vector2) -> Color:
	if zones.is_empty():
		return color
	var m := _zona_mezcla(p.x, p.y)
	var fade := 1.0 - smoothstep(0.0, 16.0, _square(p.x, p.y) - _s)
	return color.lerp(Color(m.r, m.g, m.b), m.a * 0.5 * fade)


# ---------------------------------------------------------------- relieve

## Distancia «cuadrada» (el área jugable es un cuadrado) y redondeada con ruido (para disimular el contorno).
func _square(x: float, z: float) -> float:
	return maxf(absf(x), absf(z))


func _round(x: float, z: float) -> float:
	return pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25) + _noise.get_noise_2d(z * 0.6, x * 0.6) * 3.0


## Distancias al borde del área jugable: x = cuadrada y y = redondeada (con ruido). En un mapa grande se descuenta el margen.
func _edges(x: float, z: float) -> Vector2:
	var c := _square(x, z)
	var base := pow(pow(absf(x), 4.0) + pow(absf(z), 4.0), 0.25)
	if _s > 0.0:
		base *= maxf(c - _s, 0.0) / maxf(c, 0.001)
	return Vector2(c - _s, base + _noise.get_noise_2d(z * 0.6, x * 0.6) * 3.0)


func _raw_height(x: float, z: float) -> float:
	var e := _edges(x, z)
	var c := e.x
	var r := e.y
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
	var dir := _lake.normalized()
	var p := Vector2(x, z)
	var along := p.dot(dir)
	if along < 20.0 + _s:
		return 1.0
	var lateral := absf(p.dot(Vector2(-dir.y, dir.x)))
	var ancho := 8.0 + along * 0.15
	return smoothstep(ancho, ancho + 12.0, lateral)


## Colinas y crestas entre el área jugable y las montañas: dejan libre el pasillo del lago y el propio lago.
func _outer_height(x: float, z: float) -> float:
	var d := _square(x, z) - _s
	var subida := smoothstep(41.0, 60.0, d) * (1.0 - smoothstep(66.0, 80.0, d))
	if subida <= 0.0:
		return BASIN_Y
	var local := (Vector2(x, z) - _lake).rotated(-LAKE_ROT)
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
	var pasos := int(2.0 * _outer / OUTER_CELL)
	for j in range(pasos):
		for i in range(pasos):
			var x := -_outer + i * OUTER_CELL
			var z := -_outer + j * OUTER_CELL
			if x >= -_inner and x + OUTER_CELL <= _inner and z >= -_inner and z + OUTER_CELL <= _inner:
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
	_world.add_child(colinas)


## Altura exacta del suelo dibujado (interpolación en el mismo triángulo de la malla).
func height_at(x: float, z: float) -> float:
	if absf(x) >= _inner or absf(z) >= _inner:
		return _outer_height(x, z)
	var fx := (x + _inner) / CELL
	var fz := (z + _inner) / CELL
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
	return Vector3(-_inner + i * CELL, _heights[j * _n + i], -_inner + j * CELL)


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
	var e := _edges(pos.x, pos.z)
	var hacia_cuenca := smoothstep(27.0, 38.0, maxf(e.x, e.y))
	color = color.lerp(BASIN, hacia_cuenca)
	if not zones.is_empty():
		var zona := _zona_mezcla(pos.x, pos.z)
		color = color.lerp(Color(zona.r, zona.g, zona.b), zona.a * (1.0 - smoothstep(0.0, 16.0, e.x)))
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


## Suelo continuo de normales suaves (dunas) con color por vértice, indexado y partido en trozos de 22 celdas:
## cada trozo se descarta solo si queda fuera de la cámara. Las facetas quedan para rocas y montañas.
func _build_ground() -> void:
	var n := _n
	var posiciones := PackedVector3Array()
	var normales := PackedVector3Array()
	var colores := PackedColorArray()
	posiciones.resize(n * n)
	normales.resize(n * n)
	colores.resize(n * n)
	for j in range(n):
		for i in range(n):
			var v := _vertex(i, j)
			var nrm := _smooth_normal(i, j)
			posiciones[j * n + i] = v
			normales[j * n + i] = nrm
			colores[j * n + i] = _ground_color(v, nrm.y)
	var paso := 22
	for cj in range(0, n - 1, paso):
		for ci in range(0, n - 1, paso):
			var i1 := mini(ci + paso, n - 1)
			var j1 := mini(cj + paso, n - 1)
			var w := i1 - ci + 1
			var h := j1 - cj + 1
			var pv := PackedVector3Array()
			var pn := PackedVector3Array()
			var pc := PackedColorArray()
			var uv := PackedVector2Array()
			var idx := PackedInt32Array()
			pv.resize(w * h)
			pn.resize(w * h)
			pc.resize(w * h)
			uv.resize(w * h)
			for j in range(h):
				for i in range(w):
					var k := (cj + j) * n + ci + i
					pv[j * w + i] = posiciones[k]
					pn[j * w + i] = normales[k]
					pc[j * w + i] = colores[k]
					uv[j * w + i] = Vector2(posiciones[k].x, posiciones[k].z) / 5.0
			for j in range(h - 1):
				for i in range(w - 1):
					var a0 := j * w + i
					var a1 := a0 + 1
					var a2 := a0 + w
					var a3 := a2 + 1
					# Sentido horario visto desde arriba (cara frontal de Godot).
					for q in [a0, a1, a2, a1, a3, a2]:
						idx.push_back(q)
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = pv
			arrays[Mesh.ARRAY_NORMAL] = pn
			arrays[Mesh.ARRAY_COLOR] = pc
			arrays[Mesh.ARRAY_TEX_UV] = uv
			arrays[Mesh.ARRAY_INDEX] = idx
			var malla := ArrayMesh.new()
			malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var suelo := MeshInstance3D.new()
			suelo.name = "Ground_%d_%d" % [ci / paso, cj / paso]
			suelo.mesh = malla
			suelo.material_override = W.ground_material()
			suelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_world.add_child(suelo)


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
			if not (x >= -_inner and x + paso <= _inner and z >= -_inner and z + paso <= _inner):
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
	_world.add_child(cuenca)


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
			var pos := Vector3(_lake.x + local.x, y, _lake.y + local.y)
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
	_world.add_child(lago)


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
	var destino := _lake
	var largo := destino.length()
	var dir := destino / largo
	var along := p.dot(dir)
	if along < 20.0 + _s or along > largo + 10.0:
		return false
	var lateral := absf(p.dot(Vector2(-dir.y, dir.x)))
	return lateral < 9.0 + along * 0.22


func _in_lake(p: Vector2) -> bool:
	var local := (p - _lake).rotated(-LAKE_ROT)
	return pow(local.x / 54.0, 2.0) + pow(local.y / 25.0, 2.0) < 1.0


## Dos anillos irregulares de lomas que rodean los 360° (sin colisión ni sombras; la niebla los funde).
func _build_mountains() -> void:
	var ruido := FastNoiseLite.new()
	ruido.seed = 314
	ruido.frequency = 1.0
	var radios := [76.0, 84.0, 92.0, 100.0, 108.0, 116.0, 126.0, 136.0, 146.0, 156.0, 166.0]
	var o := _s * 1.4  # las lomas se alejan más que el borde: las esquinas del mapa están a 1,41 veces
	for q in range(radios.size()):
		radios[q] += o
	var segmentos := 160
	var puntos: Array = []
	for k in range(radios.size()):
		var anillo: Array = []
		for s in range(segmentos):
			var ang := TAU * s / segmentos
			var r: float = radios[k] + ruido.get_noise_2d(cos(ang) * 3.0, sin(ang) * 3.0 + k) * 5.0
			var n1 := (ruido.get_noise_2d(cos(ang) * 2.2, sin(ang) * 2.2) + 1.0) * 0.5
			var n2 := (ruido.get_noise_2d(cos(ang) * 1.4 + 40.0, sin(ang) * 1.4) + 1.0) * 0.5
			var h := BASIN_Y + (2.5 + 6.0 * n1) * _bump(r - o, 102.0, 24.0) + (9.0 + 15.0 * n2) * _bump(r - o, 158.0, 32.0)
			h += ruido.get_noise_2d(cos(ang) * 9.0, sin(ang) * 9.0 + k * 0.5) * 1.6 * smoothstep(80.0, 100.0, r - o)
			var cresta := 1.0 - absf(ruido.get_noise_2d(cos(ang) * 6.0 + 20.0, sin(ang) * 6.0 + k * 0.35))
			h += cresta * cresta * 4.5 * smoothstep(100.0, 150.0, r - o) * _bump(r - o, 158.0, 34.0)
			h += ruido.get_noise_2d(cos(ang) * 17.0, sin(ang) * 17.0 + k) * 1.1 * smoothstep(90.0, 130.0, r - o)
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
	_world.add_child(lomas)


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
	hide_range()


## Anillo del alcance (en casillas) alrededor de «tile»; 0 lo oculta.
func show_range(tile: Vector2i, casillas: float) -> void:
	if casillas <= 0.0:
		hide_range()
		return
	if range_ring == null:
		var toro := TorusMesh.new()
		toro.inner_radius = 0.972
		toro.outer_radius = 1.0
		toro.rings = 48
		toro.ring_segments = 3
		range_ring = MeshInstance3D.new()
		range_ring.name = "RangeRing"
		range_ring.mesh = toro
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(0.55, 0.9, 0.78, 0.9)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		range_ring.material_override = material
		range_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(range_ring)
	var x := tile.x * TILE
	var z := tile.y * TILE
	var radio := casillas * TILE
	range_ring.visible = true
	range_ring.position = Vector3(x, maxf(height_at(x, z), BASIN_Y) + 0.1, z)
	range_ring.scale = Vector3(radio, 1.0, radio)


func hide_range() -> void:
	if is_instance_valid(range_ring):
		range_ring.visible = false


## Metros que el mundo se ha ensanchado respecto del mapa base (0 en el mapa chico).
func extra_size() -> float:
	return _s


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
		_decor.remove_child(hijo)
		hijo.queue_free()
	_acc.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261023
	var reservado: Dictionary = {}  # rejilla con lo que no se debe tapar: objetivos, obstáculos y el origen
	_hash_poner(reservado, Vector2.ZERO)
	var contactos: Array = []  # [posición, radio, opacidad] de las sombras de contacto
	var halos: Array[Vector3] = []  # rocas grandes alrededor de las que se reparten guijarros (x, radio, z)
	for id in targets:
		var tp: Vector3 = targets[id].position
		_hash_poner(reservado, Vector2(tp.x, tp.z))
		contactos.append([Vector3(tp.x, height_at(tp.x, tp.z) + 0.07, tp.z), 1.25, 0.6])
		halos.append(Vector3(tp.x, 0.9, tp.z))
	for t in obstacles:
		_hash_poner(reservado, Vector2(t.x * TILE, t.y * TILE))
		contactos.append([Vector3(t.x * TILE, height_at(t.x * TILE, t.y * TILE) + 0.07, t.y * TILE), 1.3, 0.6])
		halos.append(Vector3(t.x * TILE, 1.0, t.y * TILE))
	for o in _obstaculos_datos:
		_add_inst("obst_%s%d" % [o["familia"], o["variante"]], W.rock_mesh(o["familia"], o["variante"]), o["pos"], o["base"], o["color"], {"sombra": true})
	# zona: "inner" = dentro del área jugable (solo piezas pequeñas que no parecen objetivos ni obstáculos);
	# "ring" = franja de transición y cuenca (bloques y mesetas grandes).
	var fa := pow((_play + 14.0) / (PLAY_EDGE + 14.0), 2.0) * (0.7 if _s > 0.0 else 1.0)  # el área jugable crece con el cuadrado
	var fr := (_play + 30.0) / (PLAY_EDGE + 30.0)  # la franja exterior crece con el perímetro
	var familias := [
		{"id": "pebble", "mesh": "pebble", "count": int(360 * fa), "min": 0.05, "max": 0.2, "zone": "inner", "clear": 1.2, "vis": 110.0, "variants": 1, "trozo": CHUNK_FINO},
		{"id": "fragment", "mesh": "fragment", "count": int(200 * fa), "min": 0.16, "max": 0.5, "zone": "inner", "clear": 1.9, "vis": 110.0, "variants": 2, "trozo": CHUNK_FINO},
		{"id": "block", "mesh": "block", "count": int(70 * fr), "min": 0.6, "max": 1.7, "zone": "ring", "clear": 2.0, "vis": 0.0, "variants": 2},
		{"id": "boulder", "mesh": "boulder", "count": int(70 * fr), "min": 0.8, "max": 2.2, "zone": "ring", "clear": 2.0, "vis": 0.0, "variants": 2},
		{"id": "outcrop", "mesh": "outcrop", "count": int(30 * fr), "min": 0.9, "max": 2.6, "zone": "ring", "clear": 2.0, "vis": 0.0, "variants": 2},
		{"id": "mesa0", "mesh": "mesa0", "count": int(20 * fr), "min": 2.2, "max": 5.5, "zone": "mesa", "clear": 4.0, "vis": 0.0, "variants": 1},
		{"id": "mesa1", "mesh": "mesa1", "count": int(20 * fr), "min": 2.2, "max": 5.5, "zone": "mesa", "clear": 4.0, "vis": 0.0, "variants": 1},
		{"id": "mesa_big", "mesh": "mesa0", "count": int(12 * fr), "min": 6.0, "max": 11.0, "zone": "far", "clear": 8.0, "vis": 0.0, "variants": 1},
	]
	var paleta := [Color("B98160"), Color("A56E52"), Color("B07A5C"), Color("C69770"), Color("96654C")]
	# Cada familia pequeña usa 3 variantes de forma para que no se repita el mismo canto.
	var expandidas: Array = []
	for d in familias:
		if str(d["mesh"]).begins_with("mesa"):
			d["variant"] = 0
			expandidas.append(d)
		else:
			var nv: int = d["variants"]
			for v in range(nv):
				var copia: Dictionary = d.duplicate()
				copia["variant"] = v
				copia["id"] = "%s_%d" % [d["id"], v]
				copia["count"] = int(ceil(float(d["count"]) / nv))
				expandidas.append(copia)
	familias = expandidas
	var paleta_mesa := [Color("C58C66"), Color("B67E5C"), Color("CE9A72"), Color("AE7154")]
	for datos in familias:
		var malla_id: String = datos["mesh"]
		var malla: Mesh = W.mesa_mesh(int(malla_id.substr(4))) if malla_id.begins_with("mesa") else W.rock_mesh(malla_id, int(datos["variant"]))
		var colocados: Dictionary = {}
		var cuantos := 0
		var intentos := 0
		var zona: String = datos["zone"]
		var alcance := float(datos["max"]) * 0.6 + 1.0  # hasta dónde estorba una roca ya colocada de esta familia
		var rango := (_play + 45.0) if zona == "inner" or zona == "ring" else (80.0 + _s)
		var tope := 6000 + int(float(datos["count"]) * 12.0)
		while cuantos < int(datos["count"]) and intentos < tope:
			intentos += 1
			var p := Vector2(rng.randf_range(-rango, rango), rng.randf_range(-rango, rango))
			var c := _square(p.x, p.y) - _s
			match zona:
				"inner":
					if c > 44.0 or (c > 30.0 and rng.randf() < 0.55):
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
			if _hash_cerca(reservado, p, float(datos["clear"])):
				continue
			if _hash_cerca(colocados, p, alcance, true):
				continue
			var escala := rng.randf_range(datos["min"], datos["max"])
			var alto := escala * (rng.randf_range(0.55, 0.9) if zona == "mesa" or zona == "far" else rng.randf_range(0.75, 1.15))
			var base := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(escala * rng.randf_range(0.85, 1.2), alto, escala * rng.randf_range(0.8, 1.1)))
			var y := height_at(p.x, p.y) - escala * 0.1
			_hash_poner(colocados, p, escala)
			cuantos += 1
			if escala >= 0.45:
				contactos.append([Vector3(p.x, y + escala * 0.1 + 0.07, p.y), escala * (1.15 if zona != "inner" else 1.3), 0.55])
				if zona != "far" and escala >= 0.8 and escala < 3.0:
					halos.append(Vector3(p.x, escala, p.y))
			var tono: Color = (paleta_mesa if zona == "mesa" or zona == "far" else paleta)[rng.randi() % 4]
			if c > 38.0:
				tono = tono.lerp(BASIN, 0.3)
			tono = tono.lerp(CLAY, 0.3)
			tono = _tinte_roca(tono, p)
			var grande := float(datos["max"]) >= 0.8 and zona != "mesa" and zona != "far"
			_add_inst(str(datos["id"]), malla, Vector3(p.x, y, p.y), base, tono * rng.randf_range(1.0, 1.2),
				{"sombra": grande, "vis": float(datos["vis"]), "trozo": float(datos.get("trozo", CHUNK))})
	_build_cliffs(rng, reservado)
	_build_halos(rng, halos)
	_volcar_instancias()
	# Sombras de contacto: una llamada de dibujo por trozo.
	var por_trozo: Dictionary = {}
	for contacto in contactos:
		var q: Vector3 = contacto[0]
		por_trozo.get_or_add(Vector2i(floori((q.x + CHUNK_FINO / 2.0) / CHUNK_FINO), floori((q.z + CHUNK_FINO / 2.0) / CHUNK_FINO)), []).append(contacto)
	for trozo in por_trozo:
		W.ao_blobs(_decor, por_trozo[trozo])


## Anota una instancia en el grupo de su familia y su trozo; _volcar_instancias() crea después un MultiMesh por grupo.
func _add_inst(familia: String, malla: Mesh, pos: Vector3, base: Basis, color: Color, opciones: Dictionary) -> void:
	var lado := float(opciones.get("trozo", CHUNK))
	var clave := "%s_%d_%d" % [familia, floori((pos.x + lado / 2.0) / lado), floori((pos.z + lado / 2.0) / lado)]
	if not _acc.has(clave):
		_acc[clave] = {"mesh": malla, "t": [], "c": [], "opciones": opciones}
	_acc[clave]["t"].append(Transform3D(base, pos))
	_acc[clave]["c"].append(color)


func _volcar_instancias() -> void:
	for clave in _acc:
		var g: Dictionary = _acc[clave]
		var transformadas: Array = g["t"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = g["mesh"]
		mm.instance_count = transformadas.size()
		for k in range(transformadas.size()):
			mm.set_instance_transform(k, transformadas[k])
			var col: Color = g["c"][k]
			col.a = 1.0
			mm.set_instance_color(k, col)
		var opciones: Dictionary = g["opciones"]
		var inst := MultiMeshInstance3D.new()
		inst.name = "Decor_" + str(clave)
		inst.multimesh = mm
		inst.material_override = W.rock_material()
		var proyecta := bool(opciones.get("sombra", false))
		inst.set_meta("proyecta_sombra", proyecta)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if proyecta and W.quality else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lejos := float(opciones.get("vis", 0.0))
		if lejos > 0.0:
			inst.visibility_range_end = lejos
			inst.visibility_range_end_margin = 8.0
		_decor.add_child(inst)
	_acc.clear()


func _celda(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / HASH), floori(p.y / HASH))


## Guarda el punto en la rejilla; «tam» es el tamaño de la roca (para el espaciado de las de su misma familia).
func _hash_poner(h: Dictionary, p: Vector2, tam: float = 0.0) -> void:
	h.get_or_add(_celda(p), []).append(Vector3(p.x, tam, p.y))


## ¿Hay algo a menos de «radio» de p? Con «por_tamano» cada vecino estorba hasta tam * 0.6 + 1.
func _hash_cerca(h: Dictionary, p: Vector2, radio: float, por_tamano: bool = false) -> bool:
	var c := _celda(p)
	var alcance := int(ceil(radio / HASH))
	for dx in range(-alcance, alcance + 1):
		for dz in range(-alcance, alcance + 1):
			var lista: Variant = h.get(Vector2i(c.x + dx, c.y + dz))
			if lista == null:
				continue
			for q in lista:
				var d := Vector2(p.x - q.x, p.y - q.z).length()
				if d < ((q.y * 0.6 + 1.0) if por_tamano else radio):
					return true
	return false


## Guijarros caídos alrededor de las rocas grandes (uno de los rasgos más visibles del mockup).
func _build_halos(rng: RandomNumberGenerator, halos: Array[Vector3]) -> void:
	var paleta := [Color("B07A5A"), Color("9C6648"), Color("BF8B66"), Color("8E5D44")]
	for h in halos:
		for k in range(rng.randi_range(2, 4)):
			var ang := rng.randf() * TAU
			var radio: float = h.y * rng.randf_range(0.9, 1.7) + 0.2
			var x: float = h.x + cos(ang) * radio
			var z: float = h.z + sin(ang) * radio
			var e := rng.randf_range(0.05, 0.17) * clampf(h.y, 0.8, 1.6)
			var base := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(e * 1.1, e * rng.randf_range(0.6, 1.0), e))
			_add_inst("halo", W.rock_mesh("pebble", 0), Vector3(x, height_at(x, z) - e * 0.15, z), base,
				_tinte_roca(paleta[rng.randi() % 4], Vector2(x, z)) * rng.randf_range(0.8, 0.98), {"vis": 110.0, "trozo": CHUNK_FINO})


## Farallones: grupos de lajas altas y estratificadas con bloques caídos alrededor, sobre las colinas y la franja exterior.
func _build_cliffs(rng: RandomNumberGenerator, reservado: Dictionary) -> void:
	var grupos := {}
	var centros: Array[Vector2] = []
	var paleta := [Color("B98563"), Color("A97656"), Color("C49169"), Color("9F6E52")]
	var intentos := 0
	var cuantos := roundi(16.0 * (_play + 30.0) / (PLAY_EDGE + 30.0))
	while centros.size() < cuantos and intentos < 4000:
		intentos += 1
		var p := Vector2(rng.randf_range(-_play - 66.0, _play + 66.0), rng.randf_range(-_play - 66.0, _play + 66.0))
		var borde := _square(p.x, p.y) - _s
		if borde < PLAY_EDGE + 5.0 or borde > 66.0 or _in_lake(p) or _in_view_corridor(p):
			continue
		var libre := not _hash_cerca(reservado, p, 5.0)
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

func configure(defs: Array, blocked: Array, limites: Dictionary = {}, zonas: Array = []) -> void:
	_outline.clear()
	_outlined = ""
	for n in targets.values():
		n.queue_free()
	targets.clear()
	obstacles.clear()
	_obstaculos_datos.clear()
	if not limites.is_empty():
		bounds_min = limites.get("min", bounds_min)
		bounds_max = limites.get("max", bounds_max)
	_leer_zonas(zonas)
	if is_instance_valid(_world):
		_ajustar_mundo()
	if not limites.is_empty() and is_instance_valid(grid):
		_rebuild_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	# Los obstáculos se dibujan como instancias de MultiMesh por trozo (ver _build_decor), no como un nodo cada uno.
	for value in blocked:
		var tile: Vector2i = value
		obstacles.append(tile)
		var x := tile.x * TILE
		var z := tile.y * TILE
		var familia := "block" if rng.randf() < 0.6 else "outcrop"
		var variante := rng.randi() % 2
		var escala := Vector3(rng.randf_range(0.85, 1.0), rng.randf_range(0.9, 1.25), rng.randf_range(0.8, 0.95)) * (0.9 if familia == "outcrop" else 1.0)
		var color: Color = [Color("A9714F"), Color("9C6648"), Color("B47B58")][rng.randi() % 3]
		var giro := rng.randf() * TAU
		color = _tinte_roca(color, Vector2(x, z))
		_obstaculos_datos.append({"familia": familia, "variante": variante, "color": color,
			"pos": Vector3(x, height_at(x, z) - 0.1, z), "base": Basis(Vector3.UP, giro).scaled(escala)})
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
				_buried(n, rng)
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
	# Modelo del equipo de diseño (roca con cristales); si falta el archivo se usa la pieza por código.
	var modelo := Equipo.poner(n, "cristal5_brillo", 1.5, Vector3(0, -0.03, 0), rng.randf() * TAU)  # olivino: cristal verde del equipo de diseño
	if not modelo.is_empty():
		return
	var base := W.rock(n, "fragment", 2, Vector3(0, 0.05, 0), Vector3(0.95, 0.55, 0.85), Color("5E3A30"))
	base.rotation.y = rng.randf() * TAU
	for k in range(4):
		var cristal := Art.cylinder(n, 0.11, 0.42 + k * 0.1, Vector3((k % 2) * 0.3 - 0.15, 0.3 + k * 0.03, floori(k / 2.0) * 0.25 - 0.12), Color("DCE8E0") if k % 2 == 0 else Color("B5D3CB"), 0.02)
		cristal.rotation_degrees = Vector3(rng.randf_range(-20, 20), 0, k * 14 - 20)
		cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Capa enterrada ya revelada: montículo bajo con una franja pálida del antiguo lago.
func _buried(n: Node3D, rng: RandomNumberGenerator) -> void:
	# Hielo enterrado: roca con cristales de hielo del equipo de diseño (dos variantes); si faltan, la pieza por código.
	var modelo := Equipo.poner(n, "hielo_2" if rng.randf() < 0.5 else "hielo_3", 1.6, Vector3(0, -0.03, 0), rng.randf() * TAU)
	if not modelo.is_empty():
		return
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
