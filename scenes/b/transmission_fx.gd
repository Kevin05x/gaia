extends Node3D
## Animación de la transmisión de datos. Mientras se transmite: paquetes de datos viajan en arco del rover a la antena,
## de la punta de la antena sale un haz con paquetes que suben al cielo y ondas circulares se expanden hacia arriba.
## Aparece y desaparece con un fundido. Usa materiales sin sombreado (muy baratos en la web) y colores que se leen sobre el cielo cálido.
const CIAN := Color("2ff0d2")
const AMBAR := Color("fffbe8")
const BLANCO := Color("ffffff")
const ALTURA_HAZ := 9.0
const ONDAS := 3
const PAQUETES_SUBIDA := 9
const PAQUETES_ENTRADA := 5

var active := false
var rover: Node3D  ## de dónde salen los datos
var base := Vector3.ZERO  ## punta de la antena (coordenadas del mundo)
var _t := 0.0
var _k := 0.0  ## intensidad 0..1 (fundido)
var _ondas: Array[MeshInstance3D] = []
var _subida: Array[MeshInstance3D] = []
var _entrada: Array[MeshInstance3D] = []
var _haz: MeshInstance3D
var _brillo: MeshInstance3D


func _ready() -> void:
	top_level = true
	for i in range(ONDAS):
		var anillo := TorusMesh.new()
		anillo.inner_radius = 0.88
		anillo.outer_radius = 1.0
		anillo.rings = 28
		anillo.ring_segments = 6
		_ondas.append(_forma(anillo, CIAN))
	var cil := CylinderMesh.new()
	cil.top_radius = 0.05
	cil.bottom_radius = 0.09
	cil.height = ALTURA_HAZ
	cil.radial_segments = 8
	cil.rings = 1
	_haz = _forma(cil, CIAN)
	var esfera := SphereMesh.new()
	esfera.radius = 0.3
	esfera.height = 0.6
	esfera.radial_segments = 12
	esfera.rings = 6
	_brillo = _forma(esfera, AMBAR)
	for i in range(PAQUETES_SUBIDA):
		var p := SphereMesh.new()
		p.radius = 0.12
		p.height = 0.24
		p.radial_segments = 8
		p.rings = 4
		_subida.append(_forma(p, BLANCO if i % 2 == 0 else AMBAR))
	for i in range(PAQUETES_ENTRADA):
		var p := SphereMesh.new()
		p.radius = 0.13
		p.height = 0.26
		p.radial_segments = 8
		p.rings = 4
		_entrada.append(_forma(p, CIAN))
	visible = false


func _forma(malla: Mesh, color: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = malla
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _alfa(mi: MeshInstance3D, a: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	m.albedo_color.a = clampf(a, 0.0, 1.0)


func _process(delta: float) -> void:
	_k = move_toward(_k, 1.0 if active else 0.0, delta * 3.0)
	visible = _k > 0.001
	if not visible:
		return
	_t += delta
	for i in range(ONDAS):
		var fase := fposmod(_t * 0.65 + float(i) / ONDAS, 1.0)
		var o := _ondas[i]
		o.position = base + Vector3(0, 0.15 + fase * 3.4, 0)
		var radio := 0.35 + fase * 2.6
		o.scale = Vector3(radio, 1.0, radio)
		_alfa(o, (1.0 - fase) * 0.95 * _k)
	_haz.position = base + Vector3(0, ALTURA_HAZ * 0.5, 0)
	_alfa(_haz, (0.42 + 0.14 * sin(_t * 9.0)) * _k)
	_brillo.position = base
	var pulso := 1.0 + 0.25 * sin(_t * 10.0)
	_brillo.scale = Vector3.ONE * pulso
	_alfa(_brillo, 0.7 * _k)
	for i in range(PAQUETES_SUBIDA):
		var fase := fposmod(_t * 0.55 + float(i) / PAQUETES_SUBIDA, 1.0)
		var p := _subida[i]
		p.position = base + Vector3(0, fase * ALTURA_HAZ, 0)
		p.scale = Vector3(1.0, 2.8, 1.0) * (1.0 - fase * 0.6)
		_alfa(p, minf(fase * 8.0, 1.0) * (1.0 - fase) * _k * 1.3)
	if rover != null:
		var origen := rover.global_position + Vector3(0, 1.15, 0)
		for i in range(PAQUETES_ENTRADA):
			var fase := fposmod(_t * 0.8 + float(i) / PAQUETES_ENTRADA, 1.0)
			var p := _entrada[i]
			p.position = origen.lerp(base, fase) + Vector3(0, sin(fase * PI) * 1.8, 0)
			p.scale = Vector3.ONE * (1.1 - fase * 0.6)
			_alfa(p, sin(fase * PI) * _k * 1.4)
