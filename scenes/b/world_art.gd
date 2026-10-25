extends RefCounted
## Piezas procedurales del mundo: rocas low-poly de tres familias, materiales compartidos por color de vértice,
## sombra de contacto y utilidades de malla con normales por faceta. Todo original y sin texturas externas.

const Tex := preload("res://scenes/b/world_textures.gd")

static var _materials: Dictionary = {}
static var quality := true  ## calidad alta: texturas con relieve; false: color de vértice liso (equipos modestos)
static var _meshes: Dictionary = {}
static var _contact_texture: Texture2D


## Material opaco compartido: color por vértice (y por instancia en MultiMesh), mate.
static func vertex_material(sombra_propia := true) -> StandardMaterial3D:
	var clave := "vc%s" % sombra_propia
	if not _materials.has(clave):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 1.0
		m.metallic_specular = 0.2
		if not sombra_propia:
			m.disable_receive_shadows = true
		_materials[clave] = m
	return _materials[clave]


## Agua del lago: brillante, refleja el cielo (calidad alta) y no recibe sombras.
static func water_material() -> StandardMaterial3D:
	if not _materials.has("water"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
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
		m.roughness = 1.0
		m.metallic_specular = 0.25
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials["ground"] = m
		apply_quality()
	return _materials["ground"]


## Roca: estratos y grietas en triplanar (sin UV en las mallas).
static func rock_material() -> StandardMaterial3D:
	if not _materials.has("rock"):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.92
		m.metallic_specular = 0.3
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.7, 0.7, 0.7)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_materials["rock"] = m
		apply_quality()
	return _materials["rock"]


## Activa o quita las texturas de los materiales compartidos (opción «calidad alta» de los ajustes).
static func apply_quality() -> void:
	var suelo: StandardMaterial3D = _materials.get("ground")
	if suelo != null:
		if quality:
			var t := Tex.sand()
			suelo.albedo_texture = t["albedo"]
			suelo.normal_enabled = true
			suelo.normal_texture = t["normal"]
			suelo.albedo_color = Color(1.25, 1.25, 1.25)
		else:
			suelo.albedo_texture = null
			suelo.normal_enabled = false
			suelo.albedo_color = Color.WHITE
	var roca: StandardMaterial3D = _materials.get("rock")
	if roca != null:
		if quality:
			var r := Tex.rock()
			roca.albedo_texture = r["albedo"]
			roca.normal_enabled = true
			roca.normal_texture = r["normal"]
			roca.albedo_color = Color(1.25, 1.25, 1.25)
		else:
			roca.albedo_texture = null
			roca.normal_enabled = false
			roca.albedo_color = Color.WHITE


## Material sin iluminación (líneas, cursor, huellas). Con alpha si transparente.
static func flat_material(color: Color, transparente := true, prioridad := 0) -> StandardMaterial3D:
	var clave := "flat%s%s%d" % [color.to_html(), transparente, prioridad]
	if not _materials.has(clave):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = color
		m.vertex_color_use_as_albedo = true
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
		st.set_color(color)
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
static func rock_mesh(familia: String, variante: int = 0) -> ArrayMesh:
	var clave := "%s%d" % [familia, variante]
	if _meshes.has(clave):
		return _meshes[clave]
	if STONE_PRESETS.has(familia):
		var piedra := stone_mesh(familia, variante)
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
	var malla := st.commit()
	_meshes[clave] = malla
	return malla


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
		st.set_color(tono)
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
	arrays[Mesh.ARRAY_COLOR] = colores
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
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.12, 0.06, 0.04, a * a * 0.75))
		_contact_texture = ImageTexture.create_from_image(img)
	return _contact_texture


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
	var m: StandardMaterial3D = _materials.get("ao")
	if m == null:
		m = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = contact_texture()
		m.render_priority = -1
		_materials["ao"] = m
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
