extends RefCounted
## Piezas procedurales del mundo: rocas low-poly de tres familias, materiales compartidos por color de vértice,
## sombra de contacto y utilidades de malla con normales por faceta. En Marte, el suelo y las rocas usan las texturas
## del equipo de arte (assets/texturas/); si faltan, las generadas por código (world_textures.gd).

const Tex := preload("res://scenes/b/world_textures.gd")

static var _materials: Dictionary = {}
static var quality := true  ## calidad alta: texturas con relieve; false: color de vértice liso (equipos modestos)
static var _meshes: Dictionary = {}
static var _contact_texture: Texture2D
static var sombras_decor := true  ## opción de sombras: las rocas grandes proyectan sombra solo si está activa


## Material opaco compartido: color por vértice (y por instancia en MultiMesh), mate.
static func vertex_material(sombra_propia := true) -> StandardMaterial3D:
	var clave := "vc%s" % sombra_propia
	if not _materials.has(clave):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.roughness = 1.0
		m.metallic_specular = 0.04  # regolito: casi sin brillo (con el cielo claro, el reflejo lo lavaba)
		if not sombra_propia:
			m.disable_receive_shadows = true
		_materials[clave] = m
	return _materials[clave]


## Agua del lago: brillante, refleja el cielo (calidad alta) y no recibe sombras.
static func water_material() -> StandardMaterial3D:
	if not _materials.has("water"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.roughness = 0.22
		m.metallic_specular = 0.9
		m.disable_receive_shadows = true
		_materials["water"] = m
	return _materials["water"]


## Suelo: arena con textura y mapa de normales (el tono lo da el color de vértice).
static func ground_material() -> StandardMaterial3D:
	if not _materials.has("ground"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.roughness = 1.0
		m.metallic_specular = 0.04
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials["ground"] = m
		apply_quality()
	return _materials["ground"]


## Roca: estratos y grietas en triplanar (sin UV en las mallas).
static func rock_material() -> StandardMaterial3D:
	if not _materials.has("rock"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.roughness = 0.92
		m.metallic_specular = 0.12
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials["rock"] = m
		apply_quality()
	return _materials["rock"]


## Texturas PBR de Marte y de la Luna hechas por el equipo de arte (assets/texturas/, ver ARTE_Y_LICENCIAS.md). La
## «detalle» es el color dividido por su media (media 0,8, igual que las de world_textures.gd): el color de vértice sigue
## dando el tono de cada zona y la textura solo añade grano, gravilla, cráteres, cantos y estratos. Si faltan, se usan
## las generadas por código (world_textures.gd).
const TEX_ARTE := "res://assets/texturas/%s_%s.jpg"
## Texturas del equipo de arte por destino: suelo, roca (rocas sueltas) y lomas (paisaje lejano).
const TEX_DESTINO := {
	"marte": {"suelo": "marte_regolito", "roca": "marte_roca_estratos", "lomas": "marte_roca_estratos"},
	"luna": {"suelo": "luna_regolito", "roca": "luna_roca", "lomas": "luna_roca"},
}
const ESCALA_SUELO_MARTE := 0.4  ## las UV del suelo repiten cada 5 m; con 0,4 la textura repite cada 12,5 m (menos repetición visible)
const ESCALA_SUELO_LUNA := 0.25  ## Luna: repite cada 20 m; con los cráteres de todos los tamaños la repetición no se nota
const ESCALA_ROCA_MARTE := 0.35  ## triplanar: estratos de unos 11 cm en lugar de 5 cm


const ESCALA_LOMAS_MARTE := 0.06  ## lomas lejanas: la textura repite cada ~17 m (estratos de ~60 cm, visibles a 100 m)


## Lomas del paisaje lejano: color de vértice y, con texturas, la roca del destino en triplanar a escala grande.
static func mountain_material() -> StandardMaterial3D:
	if not _materials.has("mountain"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.roughness = 1.0
		m.metallic_specular = 0.04
		m.disable_receive_shadows = true
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(ESCALA_LOMAS_MARTE, ESCALA_LOMAS_MARTE, ESCALA_LOMAS_MARTE)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials["mountain"] = m
		apply_quality()
	return _materials["mountain"]


## {"albedo", "normal", "rugosidad"} de una textura de Marte, o {} si falta algún archivo (se usan las de código).
static func _tex_arte(nombre: String) -> Dictionary:
	var clave := "tex_" + nombre
	if not _materials.has(clave):
		var t := {}
		var rutas := {"albedo": TEX_ARTE % [nombre, "detalle"], "normal": TEX_ARTE % [nombre, "normal"], "rugosidad": TEX_ARTE % [nombre, "rugosidad"]}
		for k in rutas:
			if not ResourceLoader.exists(rutas[k]):
				t = {}
				break
			t[k] = load(rutas[k])
		_materials[clave] = t
	return _materials[clave]


## Pone (o quita, con t vacío) la rugosidad por textura.
static func _rugosidad(m: StandardMaterial3D, t: Dictionary) -> void:
	m.roughness_texture = t.get("rugosidad")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED


## Activa o quita las texturas de los materiales compartidos (opción «calidad alta» de los ajustes).
static func apply_quality() -> void:
	preload("res://scenes/b/material_edificio.gd").aplicar(quality)
	var texs: Dictionary = TEX_DESTINO["luna" if Destino.es_luna() else "marte"]
	var suelo: StandardMaterial3D = _materials.get("ground")
	if suelo != null:
		if quality:
			var tm := _tex_arte(texs["suelo"])
			var t := tm if not tm.is_empty() else Tex.sand()
			suelo.albedo_texture = t["albedo"]
			suelo.normal_enabled = true
			suelo.normal_texture = t["normal"]
			suelo.albedo_color = Color(1.25, 1.25, 1.25)
			_rugosidad(suelo, tm)
			var e := (ESCALA_SUELO_LUNA if Destino.es_luna() else ESCALA_SUELO_MARTE) if not tm.is_empty() else 1.0
			suelo.uv1_scale = Vector3(e, e, 1.0)
		else:
			suelo.albedo_texture = null
			suelo.normal_enabled = false
			suelo.albedo_color = Color.WHITE
			_rugosidad(suelo, {})
	var lomas: StandardMaterial3D = _materials.get("mountain")
	if lomas != null:
		var lm := _tex_arte(texs["lomas"]) if quality else {}
		lomas.albedo_texture = lm.get("albedo")
		lomas.normal_enabled = not lm.is_empty()
		lomas.normal_texture = lm.get("normal")
		lomas.albedo_color = Color(1.25, 1.25, 1.25) if not lm.is_empty() else Color.WHITE
	var roca: StandardMaterial3D = _materials.get("rock")
	if roca != null:
		if quality:
			var rm := _tex_arte(texs["roca"])
			var r := rm if not rm.is_empty() else Tex.rock()
			roca.albedo_texture = r["albedo"]
			roca.normal_enabled = true
			roca.normal_texture = r["normal"]
			roca.albedo_color = Color(1.25, 1.25, 1.25)
			_rugosidad(roca, rm)
			var er := ESCALA_ROCA_MARTE if not rm.is_empty() else 0.7
			roca.uv1_scale = Vector3(er, er, er)
			# Borde iluminado suave (contraluz del polvo): separa las rocas del suelo en vez de fundirse con él.
			roca.rim_enabled = true
			roca.rim = 0.35
			roca.rim_tint = 0.6
		else:
			roca.albedo_texture = null
			roca.normal_enabled = false
			roca.albedo_color = Color.WHITE
			roca.rim_enabled = false
			_rugosidad(roca, {})


## Material sin iluminación (líneas, cursor, huellas). Con alpha si transparente.
static func flat_material(color: Color, transparente := true, prioridad := 0) -> StandardMaterial3D:
	var clave := "flat%s%s%d" % [color.to_html(), transparente, prioridad]
	if not _materials.has(clave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		if transparente:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.render_priority = prioridad
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials[clave] = m
	return _materials[clave]


## Añade un triángulo con normal de faceta (el aspecto low-poly sale de aquí).
static func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	if n.y < -0.2:
		# Las caras del suelo siempre miran hacia arriba.
		n = -n
		var t := b
		b = c
		c = t
	# Godot dibuja la cara frontal con vértices en sentido horario: se emite (a, c, b) respecto a la normal.
	for p in [a, c, b]:
		st.set_color(Destino.color(color))
		st.set_normal(n)
		st.add_vertex(p)


## Rocas por intersección de planos: cada cara es plana y de arista viva, como los cantos facetados del mockup.
## planes = cuántos planos de corte; scale = proporciones; flat = achatamiento de las normales en y (más plano arriba).
const STONE_PRESETS := {
	"pebble": {"planes": 1, "scale": Vector3(1.0, 0.6, 0.8), "flat": 0.6, "base": -0.2},
	"fragment": {"planes": 4, "scale": Vector3(1.0, 0.65, 0.85), "flat": 0.8, "base": -0.25},
	"block": {"planes": 7, "scale": Vector3(1.0, 0.8, 0.95), "flat": 0.5, "base": -0.3, "top": 0.75},
	"boulder": {"planes": 12, "scale": Vector3(1.0, 0.95, 0.9), "flat": 1.0, "base": -0.15},
	"cliff": {"planes": 12, "scale": Vector3(1.4, 1.05, 1.15), "flat": 0.35, "base": -0.3, "top": 0.95},
	"outcrop": {"planes": 9, "scale": Vector3(1.7, 0.7, 0.95), "flat": 0.6, "base": -0.2},
}


static func stone_mesh(familia: String, variante: int = 0) -> ArrayMesh:
	var datos: Dictionary = STONE_PRESETS[familia]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s%d" % [familia, variante]) + 17 * variante
	var planos: Array[Plane] = []
	# Planos de contención (el sólido siempre queda cerrado).
	for eje in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		planos.append(Plane(eje, rng.randf_range(0.9, 1.1)))
	planos.append(Plane(Vector3.UP, float(datos.get("top", rng.randf_range(0.85, 1.05)))))
	planos.append(Plane(Vector3.DOWN, -float(datos["base"])))
	for i in range(int(datos["planes"])):
		var n := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0) * float(datos["flat"]), rng.randf_range(-1.0, 1.0))
		if n.length() < 0.2:
			continue
		planos.append(Plane(n.normalized(), rng.randf_range(0.68, 0.98)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_polyhedron(st, planos, datos["scale"], Vector3.ZERO, familia == "boulder" or familia == "cliff", rng)
	return st.commit()


## Añade al SurfaceTool el poliedro convexo definido por los planos (cada cara con su tono y normal plana).
static func _add_polyhedron(st: SurfaceTool, planos: Array[Plane], escala: Vector3, desplazamiento: Vector3, estratos: bool, rng: RandomNumberGenerator) -> void:
	var puntos := Geometry3D.compute_convex_mesh_points(planos)
	if puntos.size() < 4:
		return
	for plano in planos:
		var cara: Array[Vector3] = []
		for p in puntos:
			if absf(plano.distance_to(p)) < 0.002:
				cara.append(p)
		if cara.size() < 3:
			continue
		var centro := Vector3.ZERO
		for p in cara:
			centro += p
		centro /= cara.size()
		var u := (cara[0] - centro).normalized()
		var w := plano.normal.cross(u).normalized()
		cara.sort_custom(func(a: Vector3, b: Vector3) -> bool:
			return atan2((a - centro).dot(w), (a - centro).dot(u)) < atan2((b - centro).dot(w), (b - centro).dot(u)))
		var tono := rng.randf_range(0.88, 1.04) * (0.88 + 0.2 * clampf(plano.normal.y, -0.3, 1.0))
		if estratos:
			var franja := int(floor((centro.y * escala.y + 0.2) * 4.2))
			tono *= [1.0, 0.82, 1.08, 0.9, 1.05][posmod(franja, 5)]
		var color := Color(tono, tono, tono, 1.0)
		var base := cara[0] * escala + desplazamiento
		for i in range(1, cara.size() - 1):
			_face(st, base, cara[i] * escala + desplazamiento, cara[i + 1] * escala + desplazamiento, color)


## Roca low-poly. familia: "fragment" (canto), "block" (bloque de techo plano), "outcrop" (afloramiento alargado).
## Rocas esculpidas en Blender para las familias grandes (assets/texturas/_fuentes/rocas_esculpidas.py): no convexas y
## erosionadas, unos 300 triángulos. Se ajustan a la caja de la roca procedural que sustituyen, así que el tamaño de cada
## obstáculo no cambia. Si falta el archivo, se usan las procedurales.
const ROCAS_ESCULPIDAS := "res://assets/modelos/rocas_esculpidas.glb"
const FAMILIAS_ESCULPIDAS := ["block", "boulder", "outcrop", "cliff"]
const VARIANTES_ESCULPIDAS := 4
static var _esculpidas: Dictionary = {}  ## «familia_variante» -> Mesh del archivo (se lee una vez)


static func _malla_esculpida(familia: String, variante: int) -> Mesh:
	if _esculpidas.is_empty():
		_esculpidas["_leido"] = true
		if ResourceLoader.exists(ROCAS_ESCULPIDAS):
			var raiz: Node = (load(ROCAS_ESCULPIDAS) as PackedScene).instantiate()
			for m in raiz.find_children("*", "MeshInstance3D", true, false):
				_esculpidas[str(m.name)] = (m as MeshInstance3D).mesh
			raiz.free()
	return _esculpidas.get("%s_%d" % [familia, posmod(variante, VARIANTES_ESCULPIDAS)])


## Copia de la roca esculpida estirada a la caja «destino» (normales corregidas para el estirado desigual).
static func _ajustar_a_caja(malla: Mesh, destino: AABB) -> ArrayMesh:
	var datos := malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var caja := AABB(vertices[0], Vector3.ZERO)
	for v in vertices:
		caja = caja.expand(v)
	var escala := destino.size / caja.size.max(Vector3.ONE * 0.0001)
	for i in vertices.size():
		vertices[i] = destino.position + (vertices[i] - caja.position) * escala
		if i < normales.size():
			normales[i] = (normales[i] / escala).normalized()
	# Sin índices, como las rocas procedurales: tres vértices por triángulo (lo esperan la oclusión y las pruebas).
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	var colores: Variant = datos[Mesh.ARRAY_COLOR]
	var v2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var c2 := PackedColorArray()
	for i in indices:
		v2.append(vertices[i])
		n2.append(normales[i] if i < normales.size() else Vector3.UP)
		c2.append((colores as PackedColorArray)[i] if colores != null else Color.WHITE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v2
	arrays[Mesh.ARRAY_NORMAL] = n2
	arrays[Mesh.ARRAY_COLOR] = c2
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return nueva


static func rock_mesh(familia: String, variante: int = 0) -> ArrayMesh:
	var clave := "%s%d" % [familia, variante]
	if _meshes.has(clave):
		return _meshes[clave]
	if FAMILIAS_ESCULPIDAS.has(familia) and STONE_PRESETS.has(familia):
		var esculpida := _malla_esculpida(familia, variante)
		if esculpida != null:
			var roca := _con_oclusion(_ajustar_a_caja(esculpida, stone_mesh(familia, variante).get_aabb()))
			_meshes[clave] = roca
			return roca
	if STONE_PRESETS.has(familia):
		var piedra := _con_oclusion(stone_mesh(familia, variante))
		_meshes[clave] = piedra
		return piedra
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(clave)
	var segmentos := 6
	var anillos := 3
	var escala := Vector3(1.0, 0.6, 0.8)
	var techo := 1.0
	match familia:
		"block":
			segmentos = 5
			anillos = 3
			escala = Vector3(1.0, 0.85, 0.9)
			techo = 0.55
		"outcrop":
			segmentos = 7
			anillos = 4
			escala = Vector3(1.6, 0.7, 0.95)
			techo = 0.62
		"pebble":
			segmentos = 5
			anillos = 2
			escala = Vector3(1.0, 0.6, 0.8)
			techo = 0.85
		"boulder":
			segmentos = 8
			anillos = 4
			escala = Vector3(1.0, 0.95, 0.9)
			techo = 0.92
	var puntos: Array = []
	for j in range(anillos + 1):
		var fila: Array = []
		var phi := PI * j / anillos
		for i in range(segmentos):
			var theta := TAU * i / segmentos + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(0.78, 1.12)
			var p := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * r
			if j == 0 or j == anillos:
				p = Vector3(0, cos(phi), 0)
			p.y = minf(p.y, techo)
			p *= escala
			p.y = maxf(p.y, -0.15)
			fila.append(p)
		puntos.append(fila)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(anillos):
		for i in range(segmentos):
			var i2 := (i + 1) % segmentos
			var a: Vector3 = puntos[j][i]
			var b: Vector3 = puntos[j][i2]
			var c: Vector3 = puntos[j + 1][i]
			var d: Vector3 = puntos[j + 1][i2]
			var tono := Color(1, 1, 1) * rng.randf_range(0.86, 1.06)
			if familia == "boulder":
				# Capas sedimentarias: franjas de tono según la altura de la faceta.
				var franja := int(floor(((a.y + c.y) * 0.5 + 0.2) * 4.2))
				tono = Color(1, 1, 1) * ([1.0, 0.8, 1.1, 0.9, 1.05][posmod(franja, 5)] * rng.randf_range(0.96, 1.04))
			tono.a = 1.0
			if j > 0:
				_face(st, a, c, b, tono)
			if j < anillos - 1:
				_face(st, b, c, d, tono * 0.97)
	var malla := _con_oclusion(st.commit())
	_meshes[clave] = malla
	return malla


## Oclusión ambiental horneada en el color de vértice: la parte baja de la roca (donde toca el suelo y le llega menos
## cielo) se oscurece poco a poco y la alta queda igual. Se hace una vez por malla al crearla: al jugar no cuesta nada.
static func _con_oclusion(malla: ArrayMesh) -> ArrayMesh:
	if malla == null or malla.get_surface_count() == 0:
		return malla
	var datos := malla.surface_get_arrays(0)
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return malla
	var colores: PackedColorArray = datos[Mesh.ARRAY_COLOR]
	if colores.size() != vertices.size():
		colores = PackedColorArray()
		colores.resize(vertices.size())
		colores.fill(Color.WHITE)
	var bajo := INF
	var alto := -INF
	for v in vertices:
		bajo = minf(bajo, v.y)
		alto = maxf(alto, v.y)
	var rango := maxf(alto - bajo, 0.001)
	for i in vertices.size():
		var t := (vertices[i].y - bajo) / rango
		var ao := lerpf(0.58, 1.0, smoothstep(0.0, 0.6, t))
		var c := colores[i]
		colores[i] = Color(c.r * ao, c.g * ao, c.b * ao, c.a)
	datos[Mesh.ARRAY_COLOR] = Destino.colores(colores)
	var material := malla.surface_get_material(0)
	var nueva := ArrayMesh.new()
	nueva.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, datos)
	if material != null:
		nueva.surface_set_material(0, material)
	return nueva


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 0.0000001:
		return
	n = n.normalized()
	var centro := (a + b + c) / 3.0
	if n.dot(centro) < 0.0:
		var t := b
		b = c
		c = t
		n = -n
	# Las caras de arriba algo más claras: se lee el volumen aun en sombra.
	var luz := clampf(0.88 + n.y * 0.14, 0.75, 1.05)
	var tono := Color(color.r * luz, color.g * luz, color.b * luz, 1.0)
	for p in [a, c, b]:
		st.set_color(Destino.color(tono))
		st.set_normal(n)
		st.add_vertex(p)


## Roca individual (obstáculos y objetivos) con su color.
static func rock(parent: Node3D, familia: String, variante: int, pos: Vector3, escala: Vector3, color: Color, sombra := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.material_override = rock_material()
	parent.add_child(n)
	n.position = pos
	n.scale = escala
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if sombra else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El color de la roca se hornea en una copia de la malla (pocas rocas individuales).
	n.mesh = tinted(rock_mesh(familia, variante), color)
	return n


static func tinted(base: ArrayMesh, color: Color) -> ArrayMesh:
	var clave := "%s_%s" % [base.get_rid().get_id(), color.to_html()]
	if _meshes.has(clave):
		return _meshes[clave]
	var arrays := base.surface_get_arrays(0)
	var colores: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(colores.size()):
		colores[i] = Color(colores[i].r * color.r, colores[i].g * color.g, colores[i].b * color.b, 1.0)
	arrays[Mesh.ARRAY_COLOR] = Destino.colores(colores)
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[clave] = malla
	return malla


## Sombra de contacto: disco con degradado radial (la única textura alfa del mundo).
static func contact_texture() -> Texture2D:
	if _contact_texture == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(64):
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				# Núcleo más denso y borde muy suave: se lee como contacto, no como un disco.
				var g := exp(-d * d * 3.0) * (1.0 - smoothstep(0.8, 1.0, d))  # campana suave que llega a 0 en el borde
				img.set_pixel(x, y, (Color(0.07, 0.068, 0.075, g * 0.9) if Destino.es_luna() else Color(0.10, 0.05, 0.05, g * 0.9)))
		_contact_texture = ImageTexture.create_from_image(img)
	return _contact_texture


## Material de las sombras de contacto (manchas suaves sin luz, opacidad por instancia).
static func ao_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = _materials.get("ao")
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = Destino.forward_plus()  # Forward+ ilumina en lineal: los colores de vértice están en sRGB
		m.albedo_texture = contact_texture()
		m.render_priority = -1
		_materials["ao"] = m
	return m


## Sombras de contacto de muchas rocas en una sola llamada de dibujo: items = [Vector3(x, y, z) con el radio en w aparte].
## Cada elemento es [posición, radio, opacidad].
static func ao_blobs(parent: Node3D, items: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = items.size()
	for k in range(items.size()):
		var it: Array = items[k]
		var r: float = it[1] * 2.0
		mm.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(r, 1.0, r)), it[0]))
		mm.set_instance_color(k, Color(1, 1, 1, it[2]))
	var m := ao_material()
	var n := MultiMeshInstance3D.new()
	n.name = "ContactShadows"
	n.multimesh = mm
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


static func contact_shadow(parent: Node3D, radio: float) -> MeshInstance3D:
	contact_texture()
	var quad := QuadMesh.new()
	quad.size = Vector2(radio * 2.0, radio * 2.0)
	quad.orientation = PlaneMesh.FACE_Y
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _contact_texture
	m.render_priority = -1
	var n := MeshInstance3D.new()
	n.mesh = quad
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	n.position.y = 0.04
	return n


## Meseta de roca estratificada (acantilado bajo): 3 o 4 peldaños con repisas, caras verticales facetadas y tapa clara.
## Color de vértice gris (franjas); el tono final lo da el color de instancia. Base de radio 1 y altura 1.
static func mesa_mesh(variante: int = 0) -> ArrayMesh:
	var clave := "mesa%d" % variante
	if _meshes.has(clave):
		return _meshes[clave]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + variante * 31
	var lados := 7
	var peldanos := 2 + (variante % 2)
	var bandas := [1.0, 0.78, 1.08, 0.88]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := -0.1
	var radio := 1.0
	var angulo0 := rng.randf() * TAU
	var jitter: Array = []
	for i in range(lados):
		jitter.append(rng.randf_range(0.82, 1.15))
	for t in range(peldanos):
		var alto := rng.randf_range(0.8, 1.25) / float(peldanos)
		var radio_sup := radio * rng.randf_range(0.88, 0.97)
		var abajo: Array = []
		var arriba: Array = []
		for i in range(lados):
			var ang := angulo0 + TAU * i / lados + rng.randf_range(-0.12, 0.12)
			var f: float = jitter[i] * rng.randf_range(0.93, 1.07)
			abajo.append(Vector3(cos(ang) * radio * f, y, sin(ang) * radio * f * 0.85))
			arriba.append(Vector3(cos(ang) * radio_sup * f, y + alto, sin(ang) * radio_sup * f * 0.85))
		var tono := float(bandas[t % bandas.size()])
		for i in range(lados):
			var i2 := (i + 1) % lados
			var c := Color(tono, tono, tono, 1.0) * rng.randf_range(0.95, 1.04)
			c.a = 1.0
			_face(st, abajo[i], arriba[i], abajo[i2], c * 0.97)
			_face(st, abajo[i2], arriba[i], arriba[i2], c)
		# Repisa o tapa
		var radio_sig := radio_sup * rng.randf_range(0.8, 0.92)
		var y_sig := y + alto
		if t < peldanos - 1:
			var siguiente: Array = []
			for i in range(lados):
				var dir: Vector3 = Vector3(arriba[i].x, 0, arriba[i].z).normalized()
				siguiente.append(Vector3(dir.x * radio_sig * jitter[i], y_sig, dir.z * radio_sig * jitter[i] * 0.85))
			for i in range(lados):
				var i2 := (i + 1) % lados
				var repisa := Color(1.1, 1.1, 1.1, 1.0)
				_face(st, arriba[i], siguiente[i], arriba[i2], repisa)
				_face(st, arriba[i2], siguiente[i], siguiente[i2], repisa * 0.97)
			radio = radio_sig
		else:
			var centro := Vector3(0, y_sig + 0.03, 0)
			for i in range(lados):
				var i2 := (i + 1) % lados
				_face(st, arriba[i], centro, arriba[i2], Color(1.14, 1.14, 1.14, 1.0))
		y = y_sig
	var malla := st.commit()
	_meshes[clave] = malla
	return malla
