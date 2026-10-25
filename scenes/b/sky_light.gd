extends Node
## Luz, cielo y niebla en función de la hora simulada y del polvo (diseño visual, «Iluminación como función de la hora»).
## Solo cambia unos pocos parámetros compartidos; la energía del juego la decide siempre la simulación.

## hora, elevación°, color sol, energía, ambiente, energía ambiente, cielo arriba, horizonte, niebla, inicio, fin
const KEYS := [
	[0.0, -12.0, "FFBE8F", 0.0, "645765", 0.38, "20212F", "574453", "574453", 28.0, 110.0],
	[5.0, -12.0, "FFBE8F", 0.0, "645765", 0.38, "20212F", "574453", "574453", 28.0, 110.0],
	[6.0, 0.0, "FFBE8F", 0.30, "927079", 0.42, "745763", "E7A77E", "C88768", 35.0, 150.0],
	[7.0, 18.0, "FFE0BC", 0.70, "BE8F74", 0.50, "B29589", "BA8C76", "B08068", 45.0, 230.0],
	[12.0, 38.0, "FFE0BC", 1.00, "BE8F74", 0.50, "B29589", "BA8C76", "B08068", 45.0, 230.0],
	[17.0, 18.0, "FFE0BC", 0.70, "BE8F74", 0.50, "B29589", "BA8C76", "B08068", 45.0, 230.0],
	[18.0, 0.0, "FFB17D", 0.30, "91665D", 0.42, "875F6C", "E7A078", "C88768", 35.0, 150.0],
	[19.0, -12.0, "FFB17D", 0.0, "645765", 0.38, "20212F", "574453", "574453", 28.0, 110.0],
	[24.0, -12.0, "FFBE8F", 0.0, "645765", 0.38, "20212F", "574453", "574453", 28.0, 110.0],
]
const MOON_ENERGY := 0.22  ## luz de luna de la noche (energía del sol equivalente)
const STORM_DAY := {"top": Color("806052"), "horizon": Color("B98664"), "fog": Color("BA8162"), "begin": 16.0, "end": 75.0}
const STORM_NIGHT := {"top": Color("40332F"), "horizon": Color("72513F"), "fog": Color("72513F"), "begin": 12.0, "end": 60.0}
var energy_scale := 0.7  ## calibración artística (revisar en la exportación web)
var exposure := 0.85
var ambient_scale := 1.0
var tonemap := Environment.TONE_MAPPER_REINHARDT

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ProceduralSkyMaterial
var quality := true
var hour := 8.0
var dust := 0.0  ## valor de la simulación (0..1)
var _dust_visual := 0.0
var _shadow_by_dust := true
var _clock := 0.0


func setup(env: Environment, luz: DirectionalLight3D) -> void:
	environment = env
	sun = luz
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 8.0
	sky_material.sky_curve = 0.12
	sky_material.ground_curve = 0.05
	sky_material.energy_multiplier = 1.0
	var cielo := Sky.new()
	cielo.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = cielo
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = tonemap
	environment.tonemap_exposure = exposure
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0
	sun.shadow_blur = 1.2
	apply(true)


func set_state(nueva_hora: float, nuevo_polvo: float) -> void:
	hour = fposmod(nueva_hora, 24.0)
	dust = clampf(nuevo_polvo, 0.0, 1.0)


func _process(delta: float) -> void:
	if environment == null:
		return
	# El polvo visual se suaviza en 1 s si cambia en escalones.
	_dust_visual = move_toward(_dust_visual, dust, delta)
	_clock += delta
	if _clock >= 0.25:
		_clock = 0.0
		apply()


func _sample(h: float) -> Dictionary:
	var k := 0
	while k < KEYS.size() - 2 and h >= KEYS[k + 1][0]:
		k += 1
	var a: Array = KEYS[k]
	var b: Array = KEYS[k + 1]
	var t := smoothstep(0.0, 1.0, clampf((h - a[0]) / maxf(0.001, b[0] - a[0]), 0.0, 1.0))
	return {
		"elevation": lerpf(a[1], b[1], t),
		"sun_color": Color(a[2]).lerp(Color(b[2]), t),
		"sun_energy": lerpf(a[3], b[3], t),
		"ambient": Color(a[4]).lerp(Color(b[4]), t),
		"ambient_energy": lerpf(a[5], b[5], t),
		"top": Color(a[6]).lerp(Color(b[6]), t),
		"horizon": Color(a[7]).lerp(Color(b[7]), t),
		"fog": Color(a[8]).lerp(Color(b[8]), t),
		"begin": lerpf(a[9], b[9], t),
		"end": lerpf(a[10], b[10], t),
	}


func apply(inmediato := false) -> void:
	if inmediato:
		_dust_visual = dust
	var s := _sample(hour)
	var p := _dust_visual
	environment.tonemap_mode = tonemap
	environment.tonemap_exposure = exposure
	var dia := clampf(s["sun_energy"] / 0.3, 0.0, 1.0)
	var tormenta := {}
	for clave in ["top", "horizon", "fog"]:
		tormenta[clave] = STORM_NIGHT[clave].lerp(STORM_DAY[clave], dia)
	var inicio := lerpf(s["begin"], lerpf(STORM_NIGHT["begin"], STORM_DAY["begin"], dia), p)
	var fin := lerpf(s["end"], lerpf(STORM_NIGHT["end"], STORM_DAY["end"], dia), p)
	var arriba: Color = s["top"].lerp(tormenta["top"], p)
	var horizonte: Color = s["horizon"].lerp(tormenta["horizon"], p)
	var niebla: Color = s["fog"].lerp(tormenta["fog"], p)
	sky_material.sky_top_color = arriba
	sky_material.sky_horizon_color = horizonte
	sky_material.ground_horizon_color = horizonte
	sky_material.ground_bottom_color = niebla
	environment.fog_light_color = niebla
	environment.fog_depth_begin = inicio
	environment.fog_depth_end = fin
	environment.ambient_light_color = s["ambient"]
	environment.ambient_light_energy = s["ambient_energy"] * lerpf(1.0, 0.85, p) * ambient_scale
	# Corrección de color de la calidad alta: algo más de contraste, como una cámara fotográfica.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY if quality else Environment.REFLECTION_SOURCE_DISABLED
	environment.adjustment_enabled = quality
	environment.adjustment_contrast = 1.1
	environment.adjustment_saturation = 0.96
	# Sol: elevación de la tabla y azimut del este (amanecer) al oeste (atardecer).
	var azimut := lerpf(-75.0, 95.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0))
	var energia: float = s["sun_energy"] * lerpf(1.0, 0.30, p) * energy_scale
	sun.rotation_degrees = Vector3(-maxf(2.0, s["elevation"]), azimut, 0.0)
	sun.light_color = s["sun_color"]
	sun.light_energy = energia
	# Noche: una luz de luna tenue y azulada, sin sombras, para que torretas y edificios no sean siluetas negras.
	var noche := clampf(1.0 - s["sun_energy"] / 0.15, 0.0, 1.0)
	if noche > 0.0:
		sun.rotation_degrees = Vector3(-42.0, 205.0, 0.0)
		sun.light_color = Color("8FA8DA")
		energia = maxf(energia, MOON_ENERGY * noche * lerpf(1.0, 0.5, p))
		sun.light_energy = energia
	sun.visible = energia > 0.005
	sky_material.sun_angle_max = 8.0
	# Sombras: fuera con sol bajo o ausente; con polvo, histéresis 0,70 / 0,55.
	if p >= 0.70:
		_shadow_by_dust = false
	elif p < 0.55:
		_shadow_by_dust = true
	sun.shadow_enabled = quality and _shadow_by_dust and s["elevation"] > 3.0 and energia > 0.1
