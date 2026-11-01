class_name MurosView
extends Node3D
## Barrera de la base (muros y compuertas que el jugador levanta alrededor de la base). Inspirada en las estructuras de
## regolito sinterizado impresas en 3D que estudia la NASA para la Luna y Marte (capas horizontales visibles), con una
## tapa de compuesto oscuro y una línea de energía turquesa: el «escudo» que frena a los monstruos.
## Rendimiento: todos los tramos terminados se dibujan con MultiMesh (unas 7 llamadas de dibujo en total, haya 5 o 90
## muros) y solo se recolocan las instancias cuando cambia la barrera. Las obras las dibuja buildings.gd con pieza().
## Solo presenta: las reglas (vida, bloqueo, recarga del escudo) están en la simulación.
const TILE := 2.0
const TIPOS := ["barrera", "compuerta"]
const CAPA := 0.16  ## alto de cada capa impresa
const SUELO := -0.3  ## los muros nacen un poco enterrados (el terreno no es plano)
const ALTO_PILAR := 1.3
const ALTO_MURO := 0.94
const ANCHO_MURO := 0.22  ## medio ancho
const POSTE := 0.74  ## distancia del centro de la compuerta a cada poste
const ALTO_PUERTA := 1.75
const REGOLITO_A := Color("C9A685")
const REGOLITO_B := Color("BD9877")
const TAPA := Color("363D45")
const METAL := Color("8A939C")
const ENERGIA := Color("4FD8C4")
const VECINOS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]
const PULSOS := 6

const CORTINA := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.44, 0.91, 0.84, 1.0);
void fragment() {
	float lineas = 0.5 + 0.5 * sin(UV.y * 70.0 - TIME * 5.0);
	float borde = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.94, UV.x);
	float barrido = smoothstep(0.12, 0.0, abs(fract(UV.y - TIME * 0.35) - 0.5) - 0.38);
	float parpadeo = 0.9 + 0.1 * sin(TIME * 13.0 + UV.x * 9.0);
	ALBEDO = color.rgb;
	ALPHA = clamp((0.10 + 0.16 * lineas + 0.35 * barrido) * (0.35 + 0.65 * UV.y) * borde * parpadeo, 0.0, 1.0);
}
"""
const ESCUDO := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.44, 0.91, 0.84, 1.0);
uniform float fuerza = 0.0;
void fragment() {
	float borde = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.2);
	float celdas = 0.55 + 0.45 * abs(sin(UV.x * 75.0)) * abs(sin(UV.y * 40.0));
	ALBEDO = color.rgb;
	ALPHA = clamp((0.06 + borde * 0.95) * celdas * fuerza, 0.0, 1.0);
}
"""

static var _mallas: Dictionary = {}  ## parte -> Mesh
static var _materiales: Dictionary = {}

var ground: Callable  ## altura del terreno (x, z)
var _firma := ""
var _capas: Dictionary = {}  ## parte -> MultiMeshInstance3D
var _vida: Dictionary = {}  ## id -> hp del último snapshot (para el destello del escudo al recibir un golpe)
var _pulsos: Array = []  ## {"node", "mat", "t"}


static func es_muro(tipo: String) -> bool:
	return tipo in TIPOS


func _ready() -> void:
	for parte in ["pilar", "tramo", "puerta"]:
		for capa in [parte, parte + "_e"]:
			_capa(capa)
	_capa("cortina")
	for i in PULSOS:
		var nodo := MeshInstance3D.new()
		nodo.mesh = _malla("escudo")
		var mat := (_material("escudo") as ShaderMaterial).duplicate() as ShaderMaterial
		nodo.material_override = mat
		nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		nodo.visible = false
		add_child(nodo)
		_pulsos.append({"node": nodo, "mat": mat, "t": 9.0})
	set_process(false)


func _capa(parte: String) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _malla(parte)
	var nodo := MultiMeshInstance3D.new()
	nodo.name = parte
	nodo.multimesh = mm
	if parte.ends_with("_e") or parte == "cortina":
		nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	_capas[parte] = nodo


func update_state(s: Dictionary) -> void:
	var terminados: Dictionary = {}  ## casilla -> tipo
	var partes := PackedStringArray()
	var vivos := {}
	for e in s.get("buildings", []):
		var tipo := str(e.get("type", ""))
		if not tipo in TIPOS:
			continue
		var id := str(e.get("id", ""))
		var hp := float(e.get("hp", 0.0))
		var en_obra := bool(e.get("building", false))
		if _vida.has(id) and hp < float(_vida[id]) - 0.5 and not en_obra:
			_pulso(e.get("tile", Vector2i.ZERO))
		_vida[id] = hp
		vivos[id] = true
		if en_obra:
			continue
		var casilla: Vector2i = e.get("tile", Vector2i.ZERO)
		terminados[casilla] = tipo
		partes.append("%s%d,%d" % [tipo.left(1), casilla.x, casilla.y])
	for id in _vida.keys():
		if not vivos.has(id):
			_vida.erase(id)
	partes.sort()
	var firma := ";".join(partes)
	if firma != _firma:
		_firma = firma
		_recolocar(terminados)


func clear() -> void:
	_firma = ""
	_vida.clear()
	_recolocar({})


func _centro(casilla: Vector2i) -> Vector3:
	var p := Vector3(casilla.x * TILE, 0.0, casilla.y * TILE)
	if ground.is_valid():
		p.y = ground.call(p.x, p.z)
	return p


## Eje de la compuerta: a lo largo de los muros vecinos (este-oeste si no hay ninguno).
static func eje_de(casilla: Vector2i, tipos: Dictionary) -> Vector3:
	var en_x := tipos.has(casilla + Vector2i(1, 0)) or tipos.has(casilla + Vector2i(-1, 0))
	var en_z := tipos.has(casilla + Vector2i(0, 1)) or tipos.has(casilla + Vector2i(0, -1))
	return Vector3(0, 0, 1) if en_z and not en_x else Vector3(1, 0, 0)


func _recolocar(tipos: Dictionary) -> void:
	var listas := {"pilar": [], "tramo": [], "puerta": []}
	for casilla in tipos:
		var c := _centro(casilla)
		if tipos[casilla] == "compuerta":
			var eje := eje_de(casilla, tipos)
			listas["puerta"].append(Transform3D(Basis(eje, Vector3.UP, eje.cross(Vector3.UP)), c))
		else:
			listas["pilar"].append(Transform3D(Basis(), c))
		for d in VECINOS:
			var otra: Vector2i = casilla + d
			if not tipos.has(otra):
				continue
			if d.x != 0 and d.y != 0 and (tipos.has(casilla + Vector2i(d.x, 0)) or tipos.has(casilla + Vector2i(0, d.y))):
				continue  # en diagonal solo si no hay ya un tramo recto que cierre la esquina
			var a := _extremo(casilla, otra, tipos)
			var b := _extremo(otra, casilla, tipos)
			var x := b - a
			var horizontal := Vector3(x.x, 0.0, x.z).normalized()
			# Base inclinada: el tramo sigue la pendiente del suelo y sus capas quedan paralelas a él.
			listas["tramo"].append(Transform3D(Basis(x, Vector3.UP, Vector3(-horizontal.z, 0.0, horizontal.x)), a))
	for parte in listas:
		for capa in [parte, parte + "_e"]:
			_fijar(capa, listas[parte])
	_fijar("cortina", listas["puerta"])


## Punto donde un tramo toca la casilla «desde»: su centro, o el poste más cercano si es una compuerta.
func _extremo(desde: Vector2i, hacia: Vector2i, tipos: Dictionary) -> Vector3:
	var c := _centro(desde)
	if tipos[desde] != "compuerta":
		return c
	var eje := eje_de(desde, tipos)
	var otro := _centro(hacia)
	var lado := 1.0 if (otro - c).dot(eje) >= 0.0 else -1.0
	var p := c + eje * POSTE * lado
	p.y = c.y
	return p


func _fijar(capa: String, transformadas: Array) -> void:
	var mm := (_capas[capa] as MultiMeshInstance3D).multimesh
	mm.instance_count = transformadas.size()
	for i in transformadas.size():
		mm.set_instance_transform(i, transformadas[i])


## Destello del escudo donde un monstruo golpea un muro.
func _pulso(casilla: Vector2i) -> void:
	var elegido: Dictionary = _pulsos[0]
	for p in _pulsos:
		if float(p["t"]) > float(elegido["t"]):
			elegido = p
	elegido["t"] = 0.0
	var nodo: MeshInstance3D = elegido["node"]
	nodo.position = _centro(casilla) + Vector3(0, 0.15, 0)
	nodo.visible = true
	set_process(true)


func _process(delta: float) -> void:
	var activos := 0
	for p in _pulsos:
		var t := float(p["t"])
		if t >= 0.5:
			continue
		t += delta
		p["t"] = t
		var nodo: MeshInstance3D = p["node"]
		if t >= 0.5:
			nodo.visible = false
			continue
		activos += 1
		var k := t / 0.5
		nodo.scale = Vector3.ONE * lerpf(1.0, 1.3, sqrt(k))
		(p["mat"] as ShaderMaterial).set_shader_parameter("fuerza", (1.0 - k) * (1.0 - k) * 1.4)
	if activos == 0:
		set_process(false)


## Pieza suelta de una casilla (para una obra que se imprime capa a capa y para la foto de la ficha). La barrera lleva
## dos medios tramos para que se lea como muro; la compuerta, su cortina de energía solo si está terminada.
static func pieza(padre: Node3D, tipo: String, en_obra: bool) -> void:
	var partes: Array = ["puerta", "puerta_e"] if tipo == "compuerta" else ["pilar", "pilar_e", "tramo", "tramo_e"]
	if tipo == "compuerta" and not en_obra:
		partes.append("cortina")
	for parte in partes:
		var mi := MeshInstance3D.new()
		mi.mesh = _malla(parte)
		if parte.begins_with("tramo"):
			mi.transform = Transform3D(Basis().scaled(Vector3(2.0, 1.0, 1.0)), Vector3(-1.0, 0, 0))
		if parte.ends_with("_e") or parte == "cortina":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		padre.add_child(mi)


## Muestras de todos los materiales de la barrera, para que ShaderWarmup compile sus sombreadores al empezar.
static func muestras() -> Array[Node3D]:
	var raiz := Node3D.new()
	pieza(raiz, "barrera", false)
	pieza(raiz, "compuerta", false)
	var escudo := MeshInstance3D.new()
	escudo.mesh = _malla("escudo")
	escudo.material_override = _material("escudo")
	raiz.add_child(escudo)
	return [raiz]


# --- Mallas (se construyen una sola vez y las comparten todas las instancias) -----------------------------------------

static func _material(nombre: String) -> Material:
	if _materiales.has(nombre):
		return _materiales[nombre]
	var m: Material
	match nombre:
		"solido":
			var s := StandardMaterial3D.new()
			s.vertex_color_use_as_albedo = true
			s.roughness = 0.88
			m = s
		"energia":
			var s := StandardMaterial3D.new()
			s.albedo_color = ENERGIA
			s.emission_enabled = true
			s.emission = ENERGIA
			s.emission_energy_multiplier = 0.85
			m = s
		_:
			var sh := Shader.new()
			sh.code = CORTINA if nombre == "cortina" else ESCUDO
			var mat := ShaderMaterial.new()
			mat.shader = sh
			m = mat
	_materiales[nombre] = m
	return m


static func _malla(parte: String) -> Mesh:
	if _mallas.has(parte):
		return _mallas[parte]
	var malla: Mesh
	if parte == "escudo":
		var esfera := SphereMesh.new()
		esfera.radius = 1.25
		esfera.height = 1.25
		esfera.is_hemisphere = true
		esfera.radial_segments = 20
		esfera.rings = 6
		malla = esfera
	else:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match parte:
			"pilar": _pilar(st)
			"pilar_e": _prisma(st, 0.12, ALTO_PILAR + 0.1, ALTO_PILAR + 0.22, ENERGIA, 8, true)
			"tramo": _tramo(st)
			"tramo_e": _caja(st, Vector3(0.0, ALTO_MURO + 0.08, -0.035), Vector3(1.0, ALTO_MURO + 0.115, 0.035), ENERGIA)
			"puerta": _puerta(st)
			"puerta_e": _puerta_energia(st)
			"cortina": _cortina(st)
		malla = st.commit()
		var material_de := "cortina" if parte == "cortina" else ("energia" if parte.ends_with("_e") else "solido")
		malla.surface_set_material(0, _material(material_de))
	_mallas[parte] = malla
	return malla


## Cuadrilátero con la normal dada; ordena los vértices para que esa cara sea la frontal (Godot: sentido horario).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, col: Color) -> void:
	var horario := (b - a).cross(c - a).dot(n) < 0.0
	var orden: PackedVector3Array = PackedVector3Array([a, b, c, a, c, d]) if horario else PackedVector3Array([a, c, b, a, d, c])
	for p in orden:
		st.set_normal(n)
		st.set_color(col)
		st.add_vertex(p)


static func _prisma(st: SurfaceTool, r: float, y0: float, y1: float, col: Color, lados: int, tapa: bool, r_tapa_in: float = 0.0) -> void:
	for i in lados:
		var a0 := TAU * (i + 0.5) / lados
		var a1 := TAU * (i + 1.5) / lados
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := ((p0 + p1) * 0.5).normalized()
		_quad(st, p0 + Vector3(0, y0, 0), p1 + Vector3(0, y0, 0), p1 + Vector3(0, y1, 0), p0 + Vector3(0, y1, 0), n, col)
		if tapa:
			var q0 := p0 * (r_tapa_in / r)
			var q1 := p1 * (r_tapa_in / r)
			_quad(st, p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), q1 + Vector3(0, y1, 0), q0 + Vector3(0, y1, 0), Vector3.UP, col)


## Pilar: capas impresas alternando ancho y tono, tapa de compuesto oscuro.
static func _pilar(st: SurfaceTool) -> void:
	var y := SUELO
	var k := 0
	while y < ALTO_PILAR - 0.01:
		var ancha := k % 2 == 0
		var r := 0.39 if ancha else 0.37
		var tope := minf(y + CAPA, ALTO_PILAR)
		# La capa ancha deja ver su borde superior (el escalón con la capa estrecha de encima).
		_prisma(st, r, y, tope, REGOLITO_A if ancha else REGOLITO_B, 8, ancha, 0.36)
		y = tope
		k += 1
	_prisma(st, 0.43, ALTO_PILAR, ALTO_PILAR + 0.1, TAPA, 8, true)
	_prisma(st, 0.2, ALTO_PILAR + 0.1, ALTO_PILAR + 0.14, METAL, 8, true)


## Caja alineada a los ejes (sin cara inferior).
static func _caja(st: SurfaceTool, mn: Vector3, mx: Vector3, col: Color) -> void:
	_quad(st, Vector3(mn.x, mx.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3.UP, col)
	_quad(st, Vector3(mn.x, mn.y, mn.z), Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mx.y, mn.z), Vector3(mn.x, mx.y, mn.z), Vector3.FORWARD, col)
	_quad(st, Vector3(mn.x, mn.y, mx.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3.BACK, col)
	_quad(st, Vector3(mn.x, mn.y, mn.z), Vector3(mn.x, mn.y, mx.z), Vector3(mn.x, mx.y, mx.z), Vector3(mn.x, mx.y, mn.z), Vector3.LEFT, col)
	_quad(st, Vector3(mx.x, mn.y, mn.z), Vector3(mx.x, mn.y, mx.z), Vector3(mx.x, mx.y, mx.z), Vector3(mx.x, mx.y, mn.z), Vector3.RIGHT, col)


## Tramo de muro de largo 1 en X (la instancia lo estira hasta el vecino): capas impresas y tapa oscura.
static func _tramo(st: SurfaceTool) -> void:
	var y := SUELO
	var k := 0
	while y < ALTO_MURO - 0.01:
		var ancha := k % 2 == 0
		var w := ANCHO_MURO if ancha else ANCHO_MURO - 0.015
		var tope := minf(y + CAPA, ALTO_MURO)
		var col := REGOLITO_A if ancha else REGOLITO_B
		for lado in [-1.0, 1.0]:
			var z: float = w * lado
			_quad(st, Vector3(0, y, z), Vector3(1, y, z), Vector3(1, tope, z), Vector3(0, tope, z), Vector3(0, 0, lado), col)
			if ancha:
				var zi: float = (w - 0.015) * lado
				_quad(st, Vector3(0, tope, z), Vector3(1, tope, z), Vector3(1, tope, zi), Vector3(0, tope, zi), Vector3.UP, col)
		for x in [0.0, 1.0]:
			_quad(st, Vector3(x, y, -w), Vector3(x, y, w), Vector3(x, tope, w), Vector3(x, tope, -w), Vector3(x * 2.0 - 1.0, 0, 0), col)
		y = tope
		k += 1
	_quad(st, Vector3(0, ALTO_MURO, -ANCHO_MURO), Vector3(1, ALTO_MURO, -ANCHO_MURO), Vector3(1, ALTO_MURO, ANCHO_MURO),
		Vector3(0, ALTO_MURO, ANCHO_MURO), Vector3.UP, REGOLITO_B)
	_caja(st, Vector3(0.0, ALTO_MURO, -0.16), Vector3(1.0, ALTO_MURO + 0.08, 0.16), TAPA)


## Compuerta (eje X): zapatas de regolito, postes de compuesto y dintel. La cortina de energía va aparte.
static func _puerta(st: SurfaceTool) -> void:
	for lado in [-1.0, 1.0]:
		var x: float = POSTE * lado
		var y := SUELO
		var k := 0
		while y < 0.34:
			var tope := minf(y + CAPA, 0.34)
			_prisma_en(st, Vector3(x, 0, 0), 0.31 if k % 2 == 0 else 0.29, y, tope, REGOLITO_A if k % 2 == 0 else REGOLITO_B)
			y = tope
			k += 1
		_caja(st, Vector3(x - 0.13, 0.3, -0.13), Vector3(x + 0.13, ALTO_PUERTA, 0.13), TAPA)
		_caja(st, Vector3(x - 0.15, 0.3, -0.15), Vector3(x + 0.15, 0.42, 0.15), METAL)
	_caja(st, Vector3(-POSTE - 0.16, ALTO_PUERTA - 0.18, -0.16), Vector3(POSTE + 0.16, ALTO_PUERTA, 0.16), TAPA)
	_caja(st, Vector3(-0.22, ALTO_PUERTA, -0.1), Vector3(0.22, ALTO_PUERTA + 0.06, 0.1), METAL)


static func _prisma_en(st: SurfaceTool, c: Vector3, r: float, y0: float, y1: float, col: Color) -> void:
	for i in 8:
		var a0 := TAU * (i + 0.5) / 8.0
		var a1 := TAU * (i + 1.5) / 8.0
		var p0 := c + Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := c + Vector3(cos(a1) * r, 0, sin(a1) * r)
		var n := (Vector3(cos(a0) + cos(a1), 0, sin(a0) + sin(a1))).normalized()
		_quad(st, p0 + Vector3(0, y0, 0), p1 + Vector3(0, y0, 0), p1 + Vector3(0, y1, 0), p0 + Vector3(0, y1, 0), n, col)
		_quad(st, p0 + Vector3(0, y1, 0), p1 + Vector3(0, y1, 0), c + Vector3(0, y1, 0), c + Vector3(0, y1, 0), Vector3.UP, col)


static func _puerta_energia(st: SurfaceTool) -> void:
	for lado in [-1.0, 1.0]:
		var x: float = (POSTE - 0.14) * lado
		_caja(st, Vector3(x - 0.02, 0.42, -0.05), Vector3(x + 0.02, ALTO_PUERTA - 0.18, 0.05), ENERGIA)
	_caja(st, Vector3(-POSTE + 0.12, ALTO_PUERTA - 0.22, -0.05), Vector3(POSTE - 0.12, ALTO_PUERTA - 0.18, 0.05), ENERGIA)


static func _cortina(st: SurfaceTool) -> void:
	var x0 := -POSTE + 0.15
	var x1 := POSTE - 0.15
	var y0 := 0.05
	var y1 := ALTO_PUERTA - 0.22
	var esquinas := [[Vector3(x0, y0, 0), Vector2(0, 0)], [Vector3(x1, y0, 0), Vector2(1, 0)], [Vector3(x1, y1, 0), Vector2(1, 1)],
		[Vector3(x0, y1, 0), Vector2(0, 1)]]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.BACK)
		st.set_uv(esquinas[i][1])
		st.add_vertex(esquinas[i][0])
