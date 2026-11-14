extends Node
## Luz, cielo y niebla en función de la hora simulada y del polvo (diseño visual, «Iluminación como función de la hora»).
## Solo cambia unos pocos parámetros compartidos; la energía del juego la decide siempre la simulación.

## hora, elevación°, color sol, energía, ambiente, energía ambiente, cielo arriba, horizonte, niebla, inicio, fin
## La niebla de profundidad empieza lejos: el mapa jugable (71 × 71 casillas de 4 m, unos 284 m de lado) se ve nítido
## y solo queda una bruma leve en el horizonte, fuera del mapa (lomas lejanas). FOG_CURVE > 1 retrasa aún más la bruma.
const KEYS := [
	[0.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[5.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[5.5, -6.0, "FF8A5A", 0.0, "5A4A6E", 0.40, "1E1B2E", "8A4E4A", "6A4044", 150.0, 470.0],
	[6.0, 0.0, "FF9558", 0.55, "A07A82", 0.42, "5A4668", "F08A5A", "D0704F", 160.0, 500.0],
	[7.0, 18.0, "FFD8AA", 0.80, "A8877E", 0.44, "9E7A6E", "D8A786", "C79B7E", 170.0, 520.0],
	[12.0, 38.0, "FFE6C8", 1.00, "AC8A80", 0.44, "9E7A6E", "DAAA88", "C99D7F", 170.0, 520.0],
	[17.0, 18.0, "FFD8AA", 0.80, "A8877E", 0.44, "9E7A6E", "D8A786", "C79B7E", 170.0, 520.0],
	[18.0, 0.0, "FF8A52", 0.55, "9C747E", 0.42, "55425F", "F28552", "CC6A48", 160.0, 500.0],
	[18.5, -6.0, "FF8A5A", 0.0, "5A4A6E", 0.40, "1E1B2E", "8A4E4A", "6A4044", 150.0, 470.0],
	[19.0, -12.0, "FFB17D", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
	[24.0, -12.0, "FFBE8F", 0.0, "4E4E6A", 0.40, "141623", "3C3346", "4A3A48", 150.0, 470.0],
]
## Luna (polo sur): sin aire no hay cielo azul ni bruma; el Sol pasa bajo sobre el horizonte (sombras largas) y la
## luz es blanca y dura. De noche, solo la luz de la Tierra. Amanecer 4:00 y ocaso 20:00 (content/balance_luna.json).
const KEYS_LUNA := [
	[0.0, -10.0, "FFFFFF", 0.0, "2E3442", 0.30, "000105", "07080D", "07080D", 600.0, 1400.0],
	[3.0, -10.0, "FFFFFF", 0.0, "2E3442", 0.30, "000105", "07080D", "07080D", 600.0, 1400.0],
	[4.0, 0.0, "FFF4E6", 0.45, "3A3F4C", 0.30, "000105", "0A0B12", "0A0B12", 600.0, 1400.0],
	[5.5, 9.0, "FFF8F0", 1.05, "4A4E58", 0.32, "000105", "0B0C13", "0B0C13", 600.0, 1400.0],
	[12.0, 16.0, "FFFFFF", 1.15, "4C505A", 0.34, "000105", "0B0C13", "0B0C13", 600.0, 1400.0],
	[18.5, 9.0, "FFF8F0", 1.05, "4A4E58", 0.32, "000105", "0B0C13", "0B0C13", 600.0, 1400.0],
	[20.0, 0.0, "FFF4E6", 0.45, "3A3F4C", 0.30, "000105", "0A0B12", "0A0B12", 600.0, 1400.0],
	[21.0, -10.0, "FFFFFF", 0.0, "2E3442", 0.30, "000105", "07080D", "07080D", 600.0, 1400.0],
	[24.0, -10.0, "FFFFFF", 0.0, "2E3442", 0.30, "000105", "07080D", "07080D", 600.0, 1400.0],
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
## Efectos del renderer Forward+ (solo escritorio): 0 ninguno, 1 oclusión ambiental (SSAO), niebla volumétrica y sombras
## suaves, 2 además iluminación indirecta en pantalla (SSIL). En la web (Compatibility) no existen y se ignoran.
var avanzados := 0
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
	var tabla: Array = KEYS_LUNA if Destino.es_luna() else KEYS
	var k := 0
	while k < tabla.size() - 2 and h >= tabla[k + 1][0]:
		k += 1
	var a: Array = tabla[k]
	var b: Array = tabla[k + 1]
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


## 0 de día … 1 de noche cerrada, según la energía del sol de la hora actual (para las luces de la base).
func noche_factor() -> float:
	return clampf(1.0 - float(_sample(hour)["sun_energy"]) / 0.8, 0.0, 1.0)


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
	var luna := Destino.es_luna()
	_cielo("atardecer", 0.0 if luna else snappedf(clampf(1.0 - absf(float(s["elevation"])) / 14.0, 0.0, 1.0) * (1.0 - p), 0.02))
	_cielo("polvo", snappedf(p, 0.02))
	# En la Luna el cielo es negro también de día: las estrellas se ven siempre (más tenues con sol).
	var noche_cielo := clampf(1.0 - s["sun_energy"] / 0.12, 0.0, 1.0)
	_cielo("noche", snappedf(maxf(noche_cielo, 0.55) if luna else noche_cielo, 0.02))
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
	var azimut := lerpf(-75.0, 95.0, clampf((hour - 4.0) / 16.0, 0.0, 1.0)) if Destino.es_luna() \
		else lerpf(-75.0, 95.0, clampf((hour - 6.0) / 12.0, 0.0, 1.0))
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
	_poner(environment, "adjustment_contrast", 1.14 if Destino.es_luna() else 1.08)
	_poner(environment, "adjustment_saturation", 1.0 if Destino.es_luna() else 1.2)
	_poner(environment, "glow_enabled", post)
	_poner(environment, "glow_intensity", 0.4)
	_poner(environment, "glow_strength", 1.0)
	_poner(environment, "glow_bloom", 0.0)
	_poner(environment, "glow_hdr_threshold", 1.6)
	_poner(environment, "glow_blend_mode", Environment.GLOW_BLEND_MODE_SOFTLIGHT)
	# Sin niebla de altura: en Compatibility se suma también cerca de la cámara y lo lavaba todo (probado).
	_poner(environment, "fog_height_density", 0.0)
	_efectos_avanzados(s, p)
	_poner(environment, "fog_sun_scatter", 0.0 if Destino.es_luna() else snappedf((0.2 if post else 0.0) * clampf(float(s["sun_energy"]), 0.0, 1.0) * (1.0 - p * 0.5), 0.01))


## Forward+ (escritorio): oclusión ambiental en los rincones de rocas y edificios, luz indirecta que rebota del suelo
## rojizo, niebla volumétrica que el sol atraviesa (se espesa con la tormenta de polvo) y sombras de borde suave como
## las de un sol de verdad (tamaño angular del disco). La Luna no tiene aire: sin niebla y sombras más duras.
func _efectos_avanzados(s: Dictionary, p: float) -> void:
	if not Destino.forward_plus():
		return
	var nivel := avanzados if post else 0
	var luna := Destino.es_luna()
	_poner(environment, "ssao_enabled", nivel >= 1)
	_poner(environment, "ssao_radius", 1.6)
	_poner(environment, "ssao_intensity", 2.2 if luna else 1.8)
	_poner(environment, "ssao_power", 1.7)
	_poner(environment, "ssao_detail", 0.7)
	_poner(environment, "ssao_light_affect", 0.12)
	_poner(environment, "ssil_enabled", nivel >= 2)
	_poner(environment, "ssil_radius", 6.0)
	_poner(environment, "ssil_intensity", 0.0 if luna else 0.85)
	var niebla := nivel >= 2 and not luna  # la niebla volumétrica solo en Ultra: en Alta apagaba los colores
	_poner(environment, "volumetric_fog_enabled", niebla)
	if niebla:
		_poner(environment, "volumetric_fog_density", snappedf(0.003 + 0.03 * p, 0.0005))
		_poner(environment, "volumetric_fog_albedo", Color(s["fog"]).lerp(Color("D9A27E"), 0.4))
		_poner(environment, "volumetric_fog_anisotropy", 0.55)
		_poner(environment, "volumetric_fog_length", 140.0)
		_poner(environment, "volumetric_fog_ambient_inject", 0.12)
		_poner(environment, "volumetric_fog_sky_affect", 0.0)
	_poner(sun, "light_angular_distance", (0.25 if luna else 0.7) if nivel >= 1 else 0.0)
	_poner(sun, "shadow_blur", 1.0 if nivel >= 1 else (1.6 if sombras >= 2 else 1.2))


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
