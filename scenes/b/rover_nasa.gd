class_name RoverNasa
extends RefCounted
## Rover del juego hecho con el modelo oficial de la NASA (Perseverance, NASA 3D Resources, «free and without
## copyright»), a escala 1:1 (3,0 × 2,7 m, mástil a 2,1 m). Se desarma por piezas y se vuelve a armar con los
## mismos nombres que usa el resto del juego (Wheel0…5, arm, drill, spectrometer, radar, meteo, head, solar, rtg,
## HighGain), con las mallas fundidas por material para cuidar las llamadas de dibujo (en la web pesan mucho).
##  · El modelo de la NASA está en posición de aterrizaje: el mástil de cámaras va plegado sobre la cubierta; aquí se
##    levanta a su posición de trabajo (el mástil real mide unos 2,1 m).
##  · El modelo mira hacia +z; el juego, hacia −z: se gira media vuelta al armarlo.
##  · Las seis ruedas vienen fundidas en una sola malla: se reparten por triángulos para que cada una gire.
##  · El modelo no tiene paneles solares (el Perseverance usa un generador nuclear); el diseño «solar» del juego
##    lleva un panel plegable propio sobre la cubierta, con el mismo estilo.
const RUTA := "res://assets/nasa/modelos/perseverance.glb"
const GIRO := PI  ## el frente del modelo (+z) pasa a ser el del juego (−z)
const RADIO_RUEDA := 0.26  ## m (rueda real: 52,5 cm de diámetro)
const MAST := ["Cylinder", "bottom", "bottom_001", "bottom_002", "bottom_003", "Cylinder_001", "probe_001", "base", "top"]
const CABEZA := ["Cylinder_002", "head", "lens", "Mastcam_Z_cams", "microphones_001", "NavCams"]
const BRAZO := ["arm", "arm_001", "arm_002", "arm_003", "arm_004", "arm_cable_etc", "turret_obj", "turret_obj_002",
	"turret_obj_004", "turret_obj_006", "turret_parts", "cover_02", "cover_03", "hinge", "PIXL_cover_01"]
const TALADRO := ["corring_drill"]
const ESPECTRO := ["PIXL", "WATSON"]
const ANTENA := ["antenna_hg", "antenna_lg"]


## Las mallas fundidas se calculan una sola vez (tardan ~1 s en código) y se comparten entre la misión y el taller.
static var _cache: Dictionary = {}


## Suelta lo guardado (al salir de la partida).
static func vaciar() -> void:
	_cache.clear()
	_acabados.clear()


static func disponible() -> bool:
	return ResourceLoader.exists(RUTA)


## Raíz «Rover» con hijo «RoverVisual» y las piezas con nombre. Vacío (null) si falta el modelo.
static func crear() -> Node3D:
	if not disponible():
		return null
	var escena := load(RUTA) as PackedScene
	if escena == null:
		return null
	var modelo := escena.instantiate() as Node3D
	var piezas: Array = []  # [nombre, Mesh, Transform3D (espacio del modelo, ya girado al sistema del juego)]
	_recoger(modelo, Transform3D(Basis(Vector3.UP, GIRO), Vector3.ZERO), piezas)
	modelo.free()
	var raiz := Node3D.new()
	raiz.name = "Rover"
	var vis := Node3D.new()
	vis.name = "RoverVisual"
	raiz.add_child(vis)
	var por_nombre: Dictionary = {}
	for p in piezas:
		por_nombre[p[0]] = p
	var usados: Dictionary = {}

	# --- Mástil: se levanta de la posición plegada a la vertical, girando alrededor de su base.
	var mast_piezas := _tomar(por_nombre, MAST, usados)
	var cabeza_piezas := _tomar(por_nombre, CABEZA, usados)
	var base := _centro(por_nombre.get("base"))
	var cab_c := _centro_de(cabeza_piezas)
	var eje := Vector3(cab_c.x - base.x, 0.0, cab_c.z - base.z).normalized()
	var giro_mastil := Basis(eje.cross(Vector3.UP).normalized(), PI * 0.5)
	var bisagra := Vector3(base.x, base.y - 0.02, base.z)
	var levantar := Transform3D(Basis.IDENTITY, bisagra) * Transform3D(giro_mastil, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -bisagra)
	for p in mast_piezas:
		p[2] = levantar * (p[2] as Transform3D)
	for p in cabeza_piezas:
		p[2] = levantar * (p[2] as Transform3D)
	cab_c = _centro_de(cabeza_piezas)  # ya levantada
	var cuello := Vector3(bisagra.x, _caja_de(mast_piezas).end.y, bisagra.z)

	# --- Ruedas: una malla por rueda, con su eje en el origen del nodo.
	if not _cache.has("ruedas"):
		_cache["ruedas"] = _separar_ruedas(por_nombre.get("Wheels_objs"))
	var ruedas: Array = _cache["ruedas"]
	usados["Wheels_objs"] = true
	for i in range(ruedas.size()):
		var n := Node3D.new()
		n.name = "Wheel%d" % i
		n.position = ruedas[i]["centro"]
		vis.add_child(n)
		_malla(n, [[ruedas[i]["mesh"], Transform3D.IDENTITY]], "Rueda%d" % i)

	# --- Grupos con nombre.
	var brazo_piezas := _tomar(por_nombre, BRAZO, usados)
	var caja_brazo := _caja_de(brazo_piezas)
	var hombro := Vector3(caja_brazo.get_center().x, 0.85, caja_brazo.end.z)
	var brazo := _grupo(vis, "arm", hombro, brazo_piezas, Vector3.ZERO)
	var taladro_p := _tomar(por_nombre, TALADRO, usados)
	_grupo(brazo, "drill", _centro_de(taladro_p), taladro_p, hombro)
	var espec_p := _tomar(por_nombre, ESPECTRO, usados)
	var punta_brazo := _centro_de(espec_p)
	_grupo(brazo, "spectrometer", punta_brazo, espec_p, hombro)
	_grupo(vis, "rtg", _centro(por_nombre.get("rtg")), _tomar(por_nombre, ["rtg"], usados), Vector3.ZERO)
	_grupo(vis, "radar", _centro(por_nombre.get("RIMFAX")), _tomar(por_nombre, ["RIMFAX"], usados), Vector3.ZERO)
	var antena_p := _tomar(por_nombre, ANTENA, usados)
	_grupo(vis, "HighGain", _centro_de(antena_p), antena_p, Vector3.ZERO)
	var mastil := _grupo(vis, "mast", cuello, mast_piezas, Vector3.ZERO)
	var cabeza := _grupo(vis, "head", Vector3(cuello.x, cab_c.y, cuello.z), cabeza_piezas, Vector3.ZERO)
	# --- Todo lo demás es la carrocería: una sola malla con una superficie por material.
	var resto: Array = []
	for p in piezas:
		if not usados.has(p[0]):
			resto.append(p)
	var cuerpo := Node3D.new()
	cuerpo.name = "Body"
	vis.add_child(cuerpo)
	_malla(cuerpo, resto.map(func(p: Array) -> Array: return [p[1], p[2]]), "Carroceria")

	_panel_solar(vis)
	_meteo(vis, cuello)
	# Datos para animar el brazo y orientar el rover hacia la roca de trabajo (punta del brazo).
	raiz.set_meta("tip_offset", atan2(punta_brazo.x, -punta_brazo.z))
	raiz.set_meta("alcance", Vector2(punta_brazo.x, punta_brazo.z).length())
	raiz.set_meta("radio_rueda", RADIO_RUEDA)
	raiz.set_meta("altura_mastil", cab_c.y + 0.2)
	return raiz


# ------------------------------------------------------------------------------------------------------------------

static func _recoger(n: Node, t: Transform3D, salida: Array) -> void:
	var actual := t
	if n is Node3D:
		actual = t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		salida.append([str(n.name), (n as MeshInstance3D).mesh, actual])
	for h in n.get_children():
		_recoger(h, actual, salida)


static func _tomar(por_nombre: Dictionary, nombres: Array, usados: Dictionary) -> Array:
	var lista: Array = []
	for nombre in nombres:
		if por_nombre.has(nombre):
			lista.append(por_nombre[nombre])
			usados[nombre] = true
	return lista


static func _tomar_sin_marcar(por_nombre: Dictionary, nombres: Array) -> Array:
	var lista: Array = []
	for nombre in nombres:
		if por_nombre.has(nombre):
			lista.append(por_nombre[nombre])
	return lista


static func _caja_pieza(p: Array) -> AABB:
	return (p[2] as Transform3D) * (p[1] as Mesh).get_aabb()


static func _centro(p: Variant) -> Vector3:
	if p == null:
		return Vector3.ZERO
	return _caja_pieza(p).get_center()


static func _caja_de(lista: Array) -> AABB:
	var caja := AABB()
	var primera := true
	for p in lista:
		if p == null:
			continue
		var c := _caja_pieza(p)
		caja = c if primera else caja.merge(c)
		primera = false
	return caja


static func _centro_de(lista: Array) -> Vector3:
	return _caja_de(lista).get_center()


## Nodo con nombre en `pos` (coordenadas del rover, sistema del juego) con las piezas dadas fundidas dentro. Si el
## padre no está en el origen del rover (el brazo), `origen_padre` es donde está.
static func _grupo(padre: Node3D, nombre: String, pos: Vector3, lista: Array, origen_padre: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nombre
	padre.add_child(n)
	n.position = pos - origen_padre
	var piezas: Array = []
	for p in lista:
		if p == null:
			continue
		piezas.append([p[1], Transform3D(Basis.IDENTITY, -pos) * (p[2] as Transform3D)])
	_malla(n, piezas, nombre)
	return n


## Funde mallas [Mesh, Transform3D] en una sola con una superficie por material.
static func _malla(padre: Node3D, piezas: Array, nombre: String) -> MeshInstance3D:
	if _cache.has("malla_" + nombre):
		var mc := MeshInstance3D.new()
		mc.name = nombre + "_malla"
		mc.mesh = _cache["malla_" + nombre]
		padre.add_child(mc)
		return mc
	var grupos: Dictionary = {}  # material -> {"v","n","u","t","i"}
	var orden: Array = []
	for par in piezas:
		var malla := par[0] as Mesh
		var t: Transform3D = par[1]
		for s in range(malla.get_surface_count()):
			var a := malla.surface_get_arrays(s)
			if a[Mesh.ARRAY_VERTEX] == null or (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
				continue
			var original := malla.surface_get_material(s)
			var color_vertice := Color.WHITE
			var mat: Material = original
			if original is BaseMaterial3D and (original as BaseMaterial3D).albedo_texture == null:
				# Sin textura: una sola superficie por tipo de acabado, con el color en el vértice (ahorra llamadas de dibujo).
				mat = _acabado(original as BaseMaterial3D)
				color_vertice = (original as BaseMaterial3D).albedo_color
			if not grupos.has(mat):
				grupos[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "u": PackedVector2Array(), "t": PackedFloat32Array(), "i": PackedInt32Array(), "c": PackedColorArray(), "tang": true, "vc": mat in _acabados.values()}
				orden.append(mat)
			var g: Dictionary = grupos[mat]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tg: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var gv: PackedVector3Array = g["v"]  # los arreglos empaquetados se copian: se escribe en local y se devuelve
			var gn: PackedVector3Array = g["n"]
			var gu: PackedVector2Array = g["u"]
			var gt: PackedFloat32Array = g["t"]
			var gi: PackedInt32Array = g["i"]
			var gc: PackedColorArray = g["c"]
			var base: int = gv.size()
			var b := t.basis
			var con_tangente: bool = g["tang"]
			for k in range(v.size()):
				gv.append(t * v[k])
				gn.append((b * (n[k] if k < n.size() else Vector3.UP)).normalized())
				gu.append(uv[k] if k < uv.size() else Vector2.ZERO)
				gc.append(color_vertice)
				if tg.size() >= (k + 1) * 4:
					var d := (b * Vector3(tg[k * 4], tg[k * 4 + 1], tg[k * 4 + 2])).normalized()
					gt.append_array(PackedFloat32Array([d.x, d.y, d.z, tg[k * 4 + 3]]))
				else:
					con_tangente = false
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for q in idx:
				gi.append(base + q)
			g["v"] = gv
			g["n"] = gn
			g["u"] = gu
			g["t"] = gt
			g["i"] = gi
			g["c"] = gc
			g["tang"] = con_tangente
	if orden.is_empty():
		return null
	var m := ArrayMesh.new()
	for mat in orden:
		var g: Dictionary = grupos[mat]
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g["v"]
		arr[Mesh.ARRAY_NORMAL] = g["n"]
		arr[Mesh.ARRAY_TEX_UV] = g["u"]
		if g["vc"]:
			arr[Mesh.ARRAY_COLOR] = g["c"]
		if g["tang"] and (g["t"] as PackedFloat32Array).size() == (g["v"] as PackedVector3Array).size() * 4:
			arr[Mesh.ARRAY_TANGENT] = g["t"]
		arr[Mesh.ARRAY_INDEX] = g["i"]
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m.surface_set_material(m.get_surface_count() - 1, mat)
	_cache["malla_" + nombre] = m
	var mi := MeshInstance3D.new()
	mi.name = nombre + "_malla"
	mi.mesh = m
	padre.add_child(mi)
	return mi


static var _acabados: Dictionary = {}  ## clave -> material compartido con color de vértice


## Acabado compartido que se parece al material original (metal o pintura, y su rugosidad); el tono va en el vértice.
static func _acabado(m: BaseMaterial3D) -> StandardMaterial3D:
	var metal := m.metallic >= 0.5
	var rugosidad := 0.25 if m.roughness < 0.38 else (0.5 if m.roughness < 0.7 else 0.85)
	var clave := "%s_%.2f" % ["metal" if metal else "pintura", rugosidad]
	if not _acabados.has(clave):
		var n := StandardMaterial3D.new()
		n.vertex_color_use_as_albedo = true
		n.vertex_color_is_srgb = true
		n.metallic = 0.85 if metal else 0.05
		n.roughness = rugosidad
		n.resource_name = clave
		_acabados[clave] = n
	return _acabados[clave]


## Reparte la malla única de las ruedas en seis: por lado (x) y por eje (z), con k-medias en z.
static func _separar_ruedas(p: Variant) -> Array:
	var salida: Array = []
	if p == null:
		return salida
	var malla := p[1] as Mesh
	var t: Transform3D = p[2]
	var caja := _caja_pieza(p)
	var zs := [caja.position.z + RADIO_RUEDA, caja.get_center().z, caja.end.z - RADIO_RUEDA]
	# Triángulos con centro, para asignarlos a una rueda.
	var tris: Array = []  # [superficie, [i0,i1,i2], centro]
	var arrs: Array = []
	for s in range(malla.get_surface_count()):
		var a := malla.surface_get_arrays(s)
		arrs.append(a)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		for k in range(0, idx.size() - 2, 3):
			var c := (t * v[idx[k]] + t * v[idx[k + 1]] + t * v[idx[k + 2]]) / 3.0
			tris.append([s, k, c])
	for _it in range(6):  # k-medias de la z de cada eje
		var suma := [0.0, 0.0, 0.0]
		var cuenta := [0, 0, 0]
		for tr in tris:
			var j := _cercano(tr[2].z, zs)
			suma[j] += tr[2].z
			cuenta[j] += 1
		for j in range(3):
			if cuenta[j] > 0:
				zs[j] = suma[j] / cuenta[j]
	var centro_x := caja.get_center().x
	var cajas: Array = []  # por rueda, AABB de sus vértices
	var grupo_tri: Array = []
	for _r in range(6):
		grupo_tri.append([])
		cajas.append(AABB())
	var inicial: Array = [true, true, true, true, true, true]
	for tr in tris:
		var lado := 0 if tr[2].x < centro_x else 1
		var r := lado * 3 + _cercano(tr[2].z, zs)
		grupo_tri[r].append(tr)
	# Orden: 0-2 un lado (de atrás hacia delante en z del juego), 3-5 el otro.
	for r in range(6):
		var puntos := PackedVector3Array()
		for tr in grupo_tri[r]:
			var a: Array = arrs[tr[0]]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			for q in range(3):
				puntos.append(t * v[idx[tr[1] + q]])
		var mn := Vector3(INF, INF, INF)
		var mx := Vector3(-INF, -INF, -INF)
		for q in puntos:
			mn = mn.min(q)
			mx = mx.max(q)
		var centro := (mn + mx) * 0.5
		# Malla de la rueda con vértices respecto a su eje.
		var m := ArrayMesh.new()
		var por_sup: Dictionary = {}
		for tr in grupo_tri[r]:
			if not por_sup.has(tr[0]):
				por_sup[tr[0]] = []
			por_sup[tr[0]].append(tr[1])
		for s in por_sup:
			var a: Array = arrs[s]
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var tg: PackedFloat32Array = a[Mesh.ARRAY_TANGENT] if a[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
			var nv := PackedVector3Array()
			var nn := PackedVector3Array()
			var nu := PackedVector2Array()
			var nt := PackedFloat32Array()
			var ni := PackedInt32Array()
			var mapa: Dictionary = {}
			for k in por_sup[s]:
				for q in range(3):
					var o: int = idx[k + q]
					if not mapa.has(o):
						mapa[o] = nv.size()
						nv.append(t * v[o] - centro)
						nn.append((t.basis * (n[o] if o < n.size() else Vector3.UP)).normalized())
						nu.append(uv[o] if o < uv.size() else Vector2.ZERO)
						if tg.size() >= (o + 1) * 4:
							var d := (t.basis * Vector3(tg[o * 4], tg[o * 4 + 1], tg[o * 4 + 2])).normalized()
							nt.append_array(PackedFloat32Array([d.x, d.y, d.z, tg[o * 4 + 3]]))
					ni.append(mapa[o])
			var arr: Array = []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = nv
			arr[Mesh.ARRAY_NORMAL] = nn
			arr[Mesh.ARRAY_TEX_UV] = nu
			if nt.size() == nv.size() * 4:
				arr[Mesh.ARRAY_TANGENT] = nt
			arr[Mesh.ARRAY_INDEX] = ni
			m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			m.surface_set_material(m.get_surface_count() - 1, malla.surface_get_material(s))
		if grupo_tri[r].is_empty():
			continue
		salida.append({"mesh": m, "centro": centro})
	return salida


static func _cercano(z: float, zs: Array) -> int:
	var mejor := 0
	for j in range(1, zs.size()):
		if absf(z - zs[j]) < absf(z - zs[mejor]):
			mejor = j
	return mejor


## Panel solar plegable del diseño «solar»: dos hojas azules sobre la cubierta, a la altura del cuerpo.
static func _panel_solar(vis: Node3D) -> void:
	var n := Node3D.new()
	n.name = "solar"
	vis.add_child(n)
	n.position = Vector3(0, 1.52, 0.05)
	var marco := StandardMaterial3D.new()
	marco.albedo_color = Color("c9ccd0")
	marco.metallic = 0.7
	marco.roughness = 0.4
	var celda := StandardMaterial3D.new()
	celda.albedo_color = Color("1c2f57")
	celda.metallic = 0.5
	celda.roughness = 0.25
	celda.emission_enabled = true
	celda.emission = Color("0b1633")
	for lado in [-1, 1]:
		var hoja := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.95, 0.035, 1.45)
		hoja.mesh = caja
		hoja.material_override = celda
		hoja.position = Vector3(lado * 0.52, 0.0, 0.0)
		hoja.rotation_degrees = Vector3(0, 0, lado * -6.0)
		n.add_child(hoja)
		var borde := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.99, 0.02, 1.49)
		borde.mesh = bm
		borde.material_override = marco
		borde.position = hoja.position - Vector3(0, 0.02, 0)
		borde.rotation = hoja.rotation
		n.add_child(borde)
	for x in [-0.55, 0.55]:
		var pata := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025
		cm.bottom_radius = 0.025
		cm.height = 0.45
		pata.mesh = cm
		pata.material_override = marco
		pata.position = Vector3(x, -0.24, 0.0)
		n.add_child(pata)


## Sensores de clima en una pluma corta junto al mástil (el modelo no los trae separados).
static func _meteo(vis: Node3D, cuello: Vector3) -> void:
	var n := Node3D.new()
	n.name = "meteo"
	vis.add_child(n)
	n.position = Vector3(cuello.x - 0.25, 1.42, cuello.z - 0.05)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("d9d6cf")
	mat.metallic = 0.6
	mat.roughness = 0.4
	var pluma := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012
	cm.bottom_radius = 0.012
	cm.height = 0.5
	cm.radial_segments = 8
	pluma.mesh = cm
	pluma.material_override = mat
	pluma.position = Vector3(0, 0.25, 0)
	n.add_child(pluma)
	var bola := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	sm.radial_segments = 10
	sm.rings = 5
	bola.mesh = sm
	bola.material_override = mat
	bola.position = Vector3(0, 0.52, 0)
	n.add_child(bola)
