class_name ExplosionFx
extends Node3D
## Explosiones y polvo de obra, sin sistemas de partículas: unas pocas piezas reutilizadas (bola de fuego, humo, anillo,
## chispas y restos) que se mueven y se apagan solas. Al destruirse un edificio salen restos volando: caen con gravedad,
## rebotan en el suelo y se encogen hasta desaparecer. Solo presenta.
const MAX_RESTOS := 56
const MAX_BOLAS := 14
const GRAVEDAD := 11.0
const COLORES_RESTOS: Array[Color] = [Color("8C8F94"), Color("6A645E"), Color("3F3A36"), Color("B35B20"), Color("D9B07A")]

var ground: Callable  ## altura del terreno (x, z)
var _restos: Array = []  ## {"node", "v", "w", "t", "vida", "base"}
var _bolas: Array = []  ## {"node", "t", "dur", "ini", "fin", "color", "sube"}
var _anillos: Array = []
var _materiales_restos: Array[StandardMaterial3D] = []
var _caja := BoxMesh.new()
var _esfera := SphereMesh.new()
var _activos := 0


func _ready() -> void:
	_caja.size = Vector3.ONE
	_esfera.radius = 0.5
	_esfera.height = 1.0
	_esfera.radial_segments = 10
	_esfera.rings = 5
	for c in COLORES_RESTOS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_materiales_restos.append(m)
	for i in range(MAX_RESTOS):
		var n := MeshInstance3D.new()
		n.mesh = _caja
		n.material_override = _materiales_restos[i % _materiales_restos.size()]
		n.visible = false
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_restos.append({"node": n, "v": Vector3.ZERO, "w": Vector3.ZERO, "t": 0.0, "vida": 0.0, "base": 0.0, "libre": true})
	for i in range(MAX_BOLAS):
		var n := MeshInstance3D.new()
		n.mesh = _esfera
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		n.material_override = m
		n.visible = false
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_bolas.append({"node": n, "t": 0.0, "dur": 1.0, "ini": 0.3, "fin": 1.0, "color": Color.WHITE, "sube": 0.0, "libre": true})
	for i in range(3):
		var n := MeshInstance3D.new()
		var anillo := TorusMesh.new()
		anillo.inner_radius = 0.42
		anillo.outer_radius = 0.5
		anillo.rings = 20
		anillo.ring_segments = 4
		n.mesh = anillo
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		n.material_override = m
		n.visible = false
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(n)
		_anillos.append({"node": n, "t": 0.0, "dur": 0.6, "fin": 4.0, "libre": true})
	set_process(false)


func _suelo(p: Vector3) -> float:
	return float(ground.call(p.x, p.z)) if ground.is_valid() else 0.0


## Explosión en «pos» (centro de lo que explota). «tamano»: 1 para una torreta, 2 para un hangar, 3 para un módulo de la nave.
## «partes» son los restos que salen volando.
func explotar(pos: Vector3, tamano: float = 1.0, partes: int = 12) -> void:
	_bola(pos, Color("FFE6A8"), 0.4 * tamano, 2.6 * tamano, 0.32, 0.0)  # destello
	_bola(pos, Color("FF8A3D"), 0.5 * tamano, 2.2 * tamano, 0.65, 0.4)  # bola de fuego
	for i in range(3):
		var d := Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.6), randf_range(-0.5, 0.5)) * tamano
		_bola(pos + d, Color(0.2, 0.17, 0.16, 0.85), 0.5 * tamano, randf_range(1.8, 2.8) * tamano, randf_range(1.4, 2.2), 1.1)  # humo
	_anillo(Vector3(pos.x, _suelo(pos) + 0.1, pos.z), 3.2 * tamano)
	for i in range(maxi(partes, 0)):
		var angulo := randf() * TAU
		var fuerza := randf_range(2.8, 6.2) * sqrt(tamano)
		var v := Vector3(cos(angulo) * fuerza, randf_range(4.0, 8.5) * sqrt(tamano), sin(angulo) * fuerza)
		var lado := randf_range(0.1, 0.34) * tamano
		_resto(pos, v, Vector3(lado, lado * randf_range(0.4, 1.2), lado * randf_range(0.5, 1.1)))
	set_process(true)


## Nube de polvo y unas chispas cuando una obra termina.
func polvo(pos: Vector3, tamano: float = 1.0) -> void:
	for i in range(4):
		var d := Vector3(randf_range(-1.0, 1.0), 0.1, randf_range(-1.0, 1.0)) * tamano * 0.6
		_bola(pos + d, Color(0.78, 0.62, 0.48, 0.5), 0.4 * tamano, randf_range(1.2, 1.9) * tamano, randf_range(0.7, 1.1), 0.3)
	_anillo(Vector3(pos.x, _suelo(pos) + 0.08, pos.z), 2.4 * tamano, Color("F0C079"))
	set_process(true)


func _resto(pos: Vector3, v: Vector3, tam: Vector3) -> void:
	for r in _restos:
		if r["libre"]:
			r["libre"] = false
			r["v"] = v
			r["w"] = Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
			r["t"] = 0.0
			r["vida"] = randf_range(1.6, 2.6)
			var n: MeshInstance3D = r["node"]
			n.position = pos
			n.scale = tam
			n.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
			n.visible = true
			return


func _bola(pos: Vector3, color: Color, ini: float, fin: float, dur: float, sube: float) -> void:
	for b in _bolas:
		if b["libre"]:
			b["libre"] = false
			b["t"] = 0.0
			b["dur"] = dur
			b["ini"] = ini
			b["fin"] = fin
			b["color"] = color
			b["sube"] = sube
			var n: MeshInstance3D = b["node"]
			n.position = pos
			n.scale = Vector3.ONE * ini
			n.visible = true
			return


func _anillo(pos: Vector3, fin: float, color: Color = Color("FFC27A")) -> void:
	for a in _anillos:
		if a["libre"]:
			a["libre"] = false
			a["t"] = 0.0
			a["fin"] = fin
			a["color"] = color
			var n: MeshInstance3D = a["node"]
			n.position = pos
			n.scale = Vector3.ONE * 0.3
			n.visible = true
			return


func activos() -> int:
	var n := 0
	for r in _restos:
		if not r["libre"]:
			n += 1
	for b in _bolas:
		if not b["libre"]:
			n += 1
	for a in _anillos:
		if not a["libre"]:
			n += 1
	return n


func _process(delta: float) -> void:
	var vivo := false
	for r in _restos:
		if r["libre"]:
			continue
		vivo = true
		var n: MeshInstance3D = r["node"]
		r["t"] = float(r["t"]) + delta
		var v: Vector3 = r["v"]
		v.y -= GRAVEDAD * delta
		n.position += v * delta
		n.rotation += (r["w"] as Vector3) * delta
		var suelo := _suelo(n.position) + n.scale.y * 0.4
		if n.position.y < suelo:
			n.position.y = suelo
			v.y = -v.y * 0.32
			v.x *= 0.6
			v.z *= 0.6
			r["w"] = (r["w"] as Vector3) * 0.5
			if absf(v.y) < 0.6:
				v.y = 0.0
		r["v"] = v
		var restante := float(r["vida"]) - float(r["t"])
		if restante < 0.5:
			var k := maxf(restante / 0.5, 0.0)
			n.scale = n.scale.lerp(Vector3.ZERO, 1.0 - k) if k > 0.0 else Vector3.ZERO
		if restante <= 0.0:
			n.visible = false
			r["libre"] = true
	for b in _bolas:
		if b["libre"]:
			continue
		vivo = true
		var n: MeshInstance3D = b["node"]
		b["t"] = float(b["t"]) + delta
		var k := clampf(float(b["t"]) / float(b["dur"]), 0.0, 1.0)
		var ease_k := 1.0 - pow(1.0 - k, 3.0)
		n.scale = Vector3.ONE * lerpf(float(b["ini"]), float(b["fin"]), ease_k)
		n.position.y += float(b["sube"]) * delta
		var c: Color = b["color"]
		c.a = c.a * (1.0 - k) * (1.0 - k * 0.3)
		(n.material_override as StandardMaterial3D).albedo_color = c
		if k >= 1.0:
			n.visible = false
			b["libre"] = true
	for a in _anillos:
		if a["libre"]:
			continue
		vivo = true
		var n: MeshInstance3D = a["node"]
		a["t"] = float(a["t"]) + delta
		var k := clampf(float(a["t"]) / float(a["dur"]), 0.0, 1.0)
		n.scale = Vector3(1, 0.35, 1) * lerpf(0.3, float(a["fin"]), 1.0 - pow(1.0 - k, 2.0))
		var c: Color = a.get("color", Color("FFC27A"))
		c.a = 0.8 * (1.0 - k)
		(n.material_override as StandardMaterial3D).albedo_color = c
		if k >= 1.0:
			n.visible = false
			a["libre"] = true
	if not vivo:
		set_process(false)
