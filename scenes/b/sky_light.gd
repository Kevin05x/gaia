extends Node
## Luz, cielo y niebla en función de la hora simulada y del polvo (diseño visual, «Iluminación como función de la hora»).
## Solo cambia unos pocos parámetros compartidos; la energía del juego la decide siempre la simulación.

## hora, elevación°, color sol, energía, ambiente, energía ambiente, cielo arriba, horizonte, niebla, inicio, fin
## La niebla de profundidad empieza lejos: el mapa jugable (71 × 71 casillas de 2 m, unos 200 m de diagonal) se ve nítido
## y solo queda una bruma leve en el horizonte, fuera del mapa (lomas lejanas). FOG_CURVE > 1 retrasa aún más la bruma.
const KEYS := [
	[0.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[5.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[6.0, 0.0, "FFB98A", 0.32, "8A6E7C", 0.40, "4E4B66", "E3A27A", "C08568", 160.0, 500.0],
	[7.0, 18.0, "FFE2C2", 0.74, "A8877E", 0.44, "9E7A6E", "D8A786", "C79B7E", 170.0, 520.0],
	[12.0, 38.0, "FFE6C8", 1.00, "AC8A80", 0.44, "9E7A6E", "DAAA88", "C99D7F", 170.0, 520.0],
	[17.0, 18.0, "FFDDB8", 0.74, "A8877E", 0.44, "9E7A6E", "D8A786", "C79B7E", 170.0, 520.0],
	[18.0, 0.0, "FFAE78", 0.32, "886C78", 0.40, "4A4864", "DE9A72", "BE8466", 160.0, 500.0],
	[19.0, -12.0, "FFB17D", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[24.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
]
const FOG_CURVE := 1.6  ## exponente de la niebla sin tormenta (1 = lineal)
const FOG_CURVE_STORM := 1.1  ## en plena tormenta la bruma sube antes, pero sin tapar el entorno del rover
const MOON_ENERGY := 0.22  ## luz de luna de la noche (energía del sol equivalente)
const STORM_DAY := {"top": Color("806052"), "horizon": Color("B98664"), "fog": Color("BA8162"), "begin": 55.0, "end": 280.0}
const STORM_NIGHT := {"top": Color("40332F"), "horizon": Color("72513F"), "fog": Color("72513F"), "begin": 45.0, "end": 240.0}
var energy_scale := 0.86  ## calibración artística: sol más fuerte y ambiente más bajo y frío = más volumen
var exposure := 0.85
var ambient_scale := 1.0
var tonemap := Environment.TONE_MAPPER_REINHARDT

var environment: Environment
var sun: DirectionalLight3D
var sky_material: ShaderMaterial  ## CieloMarte (cielo propio de Marte)
var quality := true  ## compatibilidad: equivale a sombras > 0 y postproceso
var sombras := 1  ## opción gráfica: 0 apagadas, 1 normales, 2 altas
var post := true  ## opción gráfica: postproceso (reflejos del cielo, contraste, tonos)
var hour := 8.0
var dust := 0.0  ## valor de la simulación (0..1)
var _dust_visual := 0.0
var _shadow_by_dust := true
var _clock := 0.0


func setup(env: Environment, luz: DirectionalLight3D) -> void:
	environment = env
	sun = luz
	sky_material = CieloMarte.material()
	var cielo := Sky.new()
	cielo.sky_material = sky_material
	# Reflejos del cielo baratos (web): mapa de 64 px que se actualiza por partes en varios cuadros.
	cielo.radiance_size = Sky.RADIANCE_SIZE_64
	cielo.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	environment.background_mode = Environment.BG_SKY
	environment.sky = cielo
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = tonemap
	environment.tonemap_exposure = exposure
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_curve = FOG_CURVE
	environment.fog_sky_affect = 0.0
	environment.fog_aerial_perspective = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0
	sun.shadow_blur = 1.2
	apply(true)


## Calidad de las sombras del sol: 1 = normales (atlas 2048, 50 m, una sola cascada); 2 = altas (atlas 4096, 90 m, dos
## cascadas: finas cerca y largas lejos, más suaves).
func fijar_sombras(nivel: int) -> void:
	sombras = nivel
	if sun == null:
		return
	var altas := nivel >= 2
	RenderingServer.directional_shadow_atlas_set_size(4096 if altas else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if altas else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if altas else DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 90.0 if altas else 50.0
	sun.shadow_blur = 1.6 if altas else 1.2
	apply()


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
	var dia := clampf(s["sun_energy"] / 0.3, 0.0, 1.0)
	var tormenta := {}
	for clave in ["top", "horizon", "fog"]:
		tormenta[clave] = STORM_NIGHT[clave].lerp(STORM_DAY[clave], dia)
	var inicio := lerpf(s["begin"], lerpf(STORM_NIGHT["begin"], STORM_DAY["begin"], dia), p)
	var fin := lerpf(s["end"], lerpf(STORM_NIGHT["end"], STORM_DAY["end"], dia), p)
	var arriba: Color = s["top"].lerp(tormenta["top"], p)
	var horizonte: Color = s["horizon"].lerp(tormenta["horizon"], p)
	var niebla: Color = s["fog"].lerp(tormenta["fog"], p)
	# Rendimiento: cambiar un color del cielo obliga a volver a pintar el cielo (y su mapa de reflejos), así que
	# cada valor solo se escribe si cambió de verdad (_poner). Entre las 7:00 y las 17:00 el cielo no cambia nada.
	_cielo("cenit", arriba)
	_cielo("horizonte", horizonte)
	_cielo("suelo_horizonte", horizonte.lerp(niebla, 0.5))
	_cielo("suelo", niebla.darkened(0.55))
	# Halo azul de Marte: solo con el Sol cerca del horizonte (elevación < ~14°).
	_cielo("atardecer", snappedf(clampf(1.0 - absf(float(s["elevation"])) / 14.0, 0.0, 1.0) * (1.0 - p), 0.02))
	_cielo("polvo", snappedf(p, 0.02))
	_cielo("noche", snappedf(clampf(1.0 - s["sun_energy"] / 0.12, 0.0, 1.0), 0.02))
	_poner(environment, "fog_light_color", niebla)
	_poner(environment, "fog_depth_begin", snappedf(inicio, 0.5))
	_poner(environment, "fog_depth_end", snappedf(fin, 0.5))
	_poner(environment, "fog_depth_curve", snappedf(lerpf(FOG_CURVE, FOG_CURVE_STORM, p), 0.01))
	_poner(environment, "ambient_light_color", s["ambient"])
	_poner(environment, "ambient_light_energy", snappedf(s["ambient_energy"] * lerpf(1.0, 0.85, p) * ambient_scale, 0.001))
	# Corrección de color de la calidad alta: algo más de contraste, como una cámara fotográfica.
	_poner(environment, "reflected_light_source", Environment.REFLECTION_SOURCE_SKY if post else Environment.REFLECTION_SOURCE_DISABLED)
	_postproceso(s, p)
	# Sol: elevación de la tabla y azimut del este (amanecer) al oeste (atardecer).
	var azimut := lerpf(-75.0, 95.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0))
	var energia: float = s["sun_energy"] * lerpf(1.0, 0.30, p) * energy_scale
	var giro := Vector3(-maxf(2.0, s["elevation"]), azimut, 0.0)
	var color_sol: Color = s["sun_color"]
	# Noche: una luz de luna tenue y azulada, sin sombras, para que torretas y edificios no sean siluetas negras.
	var noche := clampf(1.0 - s["sun_energy"] / 0.15, 0.0, 1.0)
	if noche > 0.0:
		giro = Vector3(-42.0, 205.0, 0.0)
		color_sol = Color("8FA8DA")
		energia = maxf(energia, MOON_ENERGY * noche * lerpf(1.0, 0.5, p))
	_poner(sun, "rotation_degrees", giro)
	_poner(sun, "light_color", color_sol)
	_poner(sun, "light_energy", snappedf(energia, 0.001))
	_poner(sun, "visible", energia > 0.005)
	# Sombras: fuera con sol bajo o ausente; con polvo, histéresis 0,70 / 0,55.
	if p >= 0.70:
		_shadow_by_dust = false
	elif p < 0.55:
		_shadow_by_dust = true
	_poner(sun, "shadow_enabled", sombras > 0 and _shadow_by_dust and s["elevation"] > 3.0 and energia > 0.1)


## Postproceso (opción gráfica): tonos de cine (Filmic: las luces fuertes no se queman), brillo suave de lo que
## emite luz (energía de muros y compuertas, focos, el sol), contraste y saturación de foto, y bruma del color del sol
## en la dirección del sol. Sin postproceso: el aspecto plano anterior (Reinhard), que es lo más barato.
func _postproceso(s: Dictionary, p: float) -> void:
	_poner(environment, "tonemap_mode", Environment.TONE_MAPPER_FILMIC if post else tonemap)
	_poner(environment, "tonemap_exposure", 0.94 if post else exposure)
	_poner(environment, "tonemap_white", 5.0)
	_poner(environment, "adjustment_enabled", post)
	_poner(environment, "adjustment_contrast", 1.08)
	_poner(environment, "adjustment_saturation", 1.2)
	_poner(environment, "glow_enabled", post)
	_poner(environment, "glow_intensity", 0.4)
	_poner(environment, "glow_strength", 1.0)
	_poner(environment, "glow_bloom", 0.0)
	_poner(environment, "glow_hdr_threshold", 1.6)
	_poner(environment, "glow_blend_mode", Environment.GLOW_BLEND_MODE_SOFTLIGHT)
	# Sin niebla de altura: en Compatibility se suma también cerca de la cámara y lo lavaba todo (probado).
	_poner(environment, "fog_height_density", 0.0)
	_poner(environment, "fog_sun_scatter", snappedf((0.2 if post else 0.0) * clampf(float(s["sun_energy"]), 0.0, 1.0) * (1.0 - p * 0.5), 0.01))


## Igual que _poner pero para un parámetro del sombreador del cielo (cambiarlo vuelve a pintar el mapa de reflejos).
func _cielo(parametro: StringName, valor: Variant) -> void:
	var actual: Variant = sky_material.get_shader_parameter(parametro)
	if actual != null and typeof(actual) == typeof(valor):
		if valor is Color and (actual as Color).is_equal_approx(valor):
			return
		if valor is float and is_equal_approx(actual, valor):
			return
	sky_material.set_shader_parameter(parametro, valor)


## Escribe la propiedad solo si cambia (los colores y vectores, con tolerancia): cada escritura avisa al servidor de render.
static func _poner(objeto: Object, propiedad: StringName, valor: Variant) -> void:
	var actual: Variant = objeto.get(propiedad)
	if typeof(actual) == typeof(valor):
		if valor is Color or valor is Vector3:
			if actual.is_equal_approx(valor):
				return
		elif valor is float:
			if is_equal_approx(actual, valor):
				return
		elif actual == valor:
			return
	objeto.set(propiedad, valor)
