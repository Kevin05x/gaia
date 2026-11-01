class_name PolvoAmbiente
extends CPUParticles3D
## Motas de polvo flotando en el aire alrededor de la cámara: dan escala y sensación de atmósfera (el aire de Marte
## siempre lleva polvo en suspensión). Una sola llamada de dibujo; las motas se mueven con un viento suave y se
## desvanecen al nacer y al morir. Con tormenta hay más y van más rápido. Opción «Polvo en el aire».
var objetivo: Node3D  ## la cámara: las motas flotan delante de ella
var _viento := Vector3(1.2, 0.05, 0.5)


func _init() -> void:
	amount = 140
	lifetime = 9.0
	preprocess = 9.0
	local_coords = false
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(9.0, 4.0, 9.0)
	direction = Vector3(1.0, 0.1, 0.4)
	spread = 25.0
	gravity = Vector3(0.0, -0.02, 0.0)
	initial_velocity_min = 0.3
	initial_velocity_max = 1.1
	scale_amount_min = 0.5
	scale_amount_max = 1.4
	var rampa := Gradient.new()
	rampa.set_offset(0, 0.0)
	rampa.set_color(0, Color(1, 0.9, 0.8, 0.0))
	rampa.set_offset(1, 1.0)
	rampa.set_color(1, Color(1, 0.9, 0.8, 0.0))
	rampa.add_point(0.2, Color(1, 0.92, 0.82, 0.8))
	rampa.add_point(0.8, Color(1, 0.92, 0.82, 0.7))
	color_ramp = rampa
	var quad := QuadMesh.new()
	quad.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color("E9C9A6")
	quad.material = m
	mesh = quad
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if is_instance_valid(objetivo):
		global_position = objetivo.global_position - objetivo.global_transform.basis.z * 8.0


## Polvo de la simulación (0..1): con tormenta, más motas y más rápidas.
func fijar_polvo(polvo: float) -> void:
	speed_scale = 1.0 + polvo * 2.5
