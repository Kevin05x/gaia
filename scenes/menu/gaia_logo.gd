extends SubViewportContainer
## Logotipo de GAIA en 3D real: letras extruidas de Space Grotesk con acabado metálico cálido y, a su lado, el emblema
## (planeta, órbita y luna). Se dibuja en su propio SubViewport transparente, así que se puede poner sobre cualquier fondo.
## Todo es original y procedural: no usa imágenes ni modelos externos.
const UI := preload("res://scenes/b/ui_style.gd")
const TEXTO := "GAIA"
const PIXEL := 0.02
const TAMANO_FUENTE := 96
const SEPARACION := 0.16
## Giro fijo de las letras para que se vean sus caras laterales y la profundidad.
const POSE := Vector3(0.07, -0.24, 0.0)
const SHADER := """
shader_type canvas_item;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV;
	float banda = floor(uv.y * 28.0);
	float azar = fract(sin(banda * 91.3 + floor(TIME * 24.0) * 7.7) * 43758.5);
	float activa = step(0.72, fract(sin(banda * 13.7 + floor(TIME * 18.0)) * 9341.2));
	float desvio = (azar - 0.5) * 0.12 * glitch * activa;
	float sep = 0.014 * glitch;
	vec4 r = texture(TEXTURE, uv + vec2(desvio + sep, 0.0));
	vec4 g = texture(TEXTURE, uv + vec2(desvio, 0.0));
	vec4 b = texture(TEXTURE, uv + vec2(desvio - sep, 0.0));
	COLOR = vec4(r.r, g.g, b.b, max(max(r.a, g.a), b.a));
}
"""

## "horizontal" = emblema + letras; "letras" = solo el nombre; "emblema" = solo el planeta.
@export var disposicion: String = "horizontal"
@export var girar: bool = false  ## el emblema gira y la luna orbita sin parar (menú); false = una sola imagen
var viewport: SubViewport
var camara: Camera3D
var letras: Array[MeshInstance3D] = []
var emblema: Node3D
var luna: MeshInstance3D
var barrido: OmniLight3D
var _destino: Array[Vector3] = []
var _ancho_total := 8.0
var _material_glitch: ShaderMaterial
var _t := 0.0


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sombreado := Shader.new()
	sombreado.code = SHADER
	_material_glitch = ShaderMaterial.new()
	_material_glitch.shader = sombreado
	material = _material_glitch
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if girar else SubViewport.UPDATE_ONCE
	add_child(viewport)
	_entorno()
	_construir()
	camara = Camera3D.new()
	camara.fov = 20.0
	viewport.add_child(camara)
	resized.connect(_ajustar)
	_ajustar()
	set_process(girar)


func _entorno() -> void:
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = Color("3a2a3d")
	cielo.sky_horizon_color = Color("f0a368")
	cielo.ground_horizon_color = Color("b9683e")
	cielo.ground_bottom_color = Color("1f120d")
	var ciclo := Sky.new()
	ciclo.sky_material = cielo
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.sky = ciclo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = 0.8
	var mundo := WorldEnvironment.new()
	mundo.environment = env
	viewport.add_child(mundo)
	var principal := DirectionalLight3D.new()
	principal.light_color = Color("ffe2b8")
	principal.light_energy = 2.2
	principal.rotation_degrees = Vector3(-35, -30, 0)
	viewport.add_child(principal)
	var contraluz := DirectionalLight3D.new()
	contraluz.light_color = Color("7fd3c4")
	contraluz.light_energy = 0.7
	contraluz.rotation_degrees = Vector3(-10, 150, 0)
	viewport.add_child(contraluz)
	barrido = OmniLight3D.new()
	barrido.light_color = Color("fff1d6")
	barrido.light_energy = 0.0
	barrido.omni_range = 9.0
	barrido.position = Vector3(-8, 1.5, 4)
	viewport.add_child(barrido)


func _material_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("f7e3b8")
	m.metallic = 0.5
	m.roughness = 0.26
	m.emission_enabled = true
	m.emission = Color("f0c079")
	m.emission_energy_multiplier = 0.28
	return m


func _construir() -> void:
	var fuente := UI.display_font(700, 0)
	var material_metal := _material_metal()
	var anchos: Array[float] = []
	var total := 0.0
	if disposicion != "emblema":
		for c in TEXTO:
			anchos.append(fuente.get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANO_FUENTE).x * PIXEL)
			total += anchos[-1]
		total += SEPARACION * (TEXTO.length() - 1) * 1.0
	var x := -total / 2.0
	if disposicion == "horizontal":
		x += 1.9  # deja sitio al emblema a la izquierda
	var i := 0
	if disposicion != "emblema":
		for c in TEXTO:
			var malla := TextMesh.new()
			malla.text = c
			malla.font = fuente
			malla.font_size = TAMANO_FUENTE
			malla.pixel_size = PIXEL
			malla.depth = 0.6
			malla.curve_step = 0.15
			var nodo := MeshInstance3D.new()
			nodo.mesh = malla
			nodo.material_override = material_metal
			var destino := Vector3(x + anchos[i] / 2.0, 0.0, 0.0)
			nodo.position = destino
			nodo.rotation = POSE
			viewport.add_child(nodo)
			letras.append(nodo)
			_destino.append(destino)
			x += anchos[i] + SEPARACION
			i += 1
	var izquierda := -total / 2.0 - 0.2
	var derecha := total / 2.0 + 0.2
	if disposicion == "horizontal":
		izquierda -= 0.0
		derecha += 1.9
		izquierda += 1.9 - 3.1
	if disposicion != "letras":
		emblema = _crear_emblema()
		viewport.add_child(emblema)
		if disposicion == "horizontal":
			emblema.position = Vector3(izquierda + 1.5, 0.05, 0.0)
		else:
			izquierda = -1.8
			derecha = 1.8
	_ancho_total = maxf(2.5, derecha - izquierda)
	_centro_x = (izquierda + derecha) / 2.0


var _centro_x := 0.0


func _crear_emblema() -> Node3D:
	var raiz := Node3D.new()
	var planeta := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.62
	esfera.height = 1.24
	esfera.radial_segments = 40
	esfera.rings = 20
	planeta.mesh = esfera
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("e29a52")
	m.roughness = 0.55
	m.emission_enabled = true
	m.emission = Color("c8742f")
	m.emission_energy_multiplier = 0.3
	planeta.material_override = m
	raiz.add_child(planeta)
	var orbita := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 1.14
	toro.outer_radius = 1.2
	toro.rings = 64
	toro.ring_segments = 8
	orbita.mesh = toro
	var mo := StandardMaterial3D.new()
	mo.albedo_color = Color("fff0d6")
	mo.emission_enabled = true
	mo.emission = Color("fff0d6")
	mo.emission_energy_multiplier = 0.55
	mo.roughness = 0.4
	orbita.material_override = mo
	orbita.rotation_degrees = Vector3(24, 0, -16)
	orbita.name = "Orbita"
	raiz.add_child(orbita)
	luna = MeshInstance3D.new()
	var esfera_luna := SphereMesh.new()
	esfera_luna.radius = 0.15
	esfera_luna.height = 0.3
	luna.mesh = esfera_luna
	var ml := StandardMaterial3D.new()
	ml.albedo_color = Color("9ad7c6")
	ml.emission_enabled = true
	ml.emission = Color("9ad7c6")
	ml.emission_energy_multiplier = 0.6
	luna.material_override = ml
	orbita.add_child(luna)
	_colocar_luna(0.6)
	return raiz


func _colocar_luna(angulo: float) -> void:
	# La luna recorre el aro (que está en el plano XY local del toro rotado).
	if luna != null:
		luna.position = Vector3(cos(angulo) * 1.17, 0.0, sin(angulo) * 1.17)


## Encuadra todo el logo según la proporción del contenedor.
func _ajustar() -> void:
	if camara == null:
		return
	var aspecto := maxf(0.2, size.x / maxf(1.0, size.y))
	var tangente := tan(deg_to_rad(camara.fov) / 2.0)
	# Con fov vertical fijo el ancho visible es 2·d·tan·aspecto; se encuadra al ancho del logo con margen.
	var distancia := (_ancho_total / 2.0 * 0.9) / (tangente * aspecto)
	distancia = maxf(distancia, 1.4 * 1.2 / tangente)
	camara.position = Vector3(_centro_x, 0.0, distancia)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if girar else SubViewport.UPDATE_ONCE


func _process(delta: float) -> void:
	_t += delta
	if emblema != null:
		emblema.rotation.y = sin(_t * 0.35) * 0.35
		emblema.get_child(0).rotation.y = _t * 0.5
		_colocar_luna(0.6 + _t * 0.9)
	for i in letras.size():
		letras[i].rotation.y = POSE.y + sin(_t * 0.5 + i * 0.6) * 0.07


func set_glitch(valor: float) -> void:
	if _material_glitch != null:
		_material_glitch.set_shader_parameter("glitch", clampf(valor, 0.0, 1.0))


## Las letras llegan volando desde la cámara y se encajan; después un destello recorre el metal.
func animar_entrada() -> Tween:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tw := create_tween()
	var azar := RandomNumberGenerator.new()
	azar.seed = 2026
	if emblema != null:
		emblema.scale = Vector3.ZERO
		tw.tween_property(emblema, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in letras.size():
		var l := letras[i]
		l.position = _destino[i] + Vector3(azar.randf_range(-2.0, 2.0), azar.randf_range(-1.5, 1.5), azar.randf_range(5.0, 8.0))
		l.rotation = Vector3(azar.randf_range(-1.2, 1.2), azar.randf_range(-1.5, 1.5), azar.randf_range(-0.6, 0.6))
		l.scale = Vector3.ONE * 0.2
		var entrada := 0.25 + i * 0.16
		tw.parallel().tween_property(l, "position", _destino[i], 0.85).set_delay(entrada).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "rotation", POSE, 0.85).set_delay(entrada).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "scale", Vector3.ONE, 0.7).set_delay(entrada).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fin_letras := 0.25 + letras.size() * 0.16 + 0.8
	tw.parallel().tween_method(set_glitch, 1.0, 0.0, 0.55).set_delay(fin_letras - 0.35)
	tw.parallel().tween_callback(_destello).set_delay(fin_letras)
	tw.tween_interval(0.0)
	return tw


func _destello() -> void:
	barrido.light_energy = 6.0
	barrido.position = Vector3(_centro_x - _ancho_total * 0.9, 1.5, 4.0)
	var tw := create_tween()
	tw.tween_property(barrido, "position:x", _centro_x + _ancho_total * 0.9, 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(barrido, "light_energy", 0.0, 0.25)
	tw.finished.connect(func() -> void:
		if not girar:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)


## Deja el logo ya armado (para saltar la animación).
func mostrar_final() -> void:
	set_glitch(0.0)
	for i in letras.size():
		letras[i].position = _destino[i]
		letras[i].rotation = POSE
		letras[i].scale = Vector3.ONE
	if emblema != null:
		emblema.scale = Vector3.ONE
	barrido.light_energy = 0.0
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if girar else SubViewport.UPDATE_ONCE
