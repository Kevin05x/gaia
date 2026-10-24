extends RefCounted
## Texturas procedurales del mundo (originales, generadas al cargar, sin archivos externos):
## arena de Jezero con ondulaciones y guijarros, y roca sedimentaria con estratos.
## Cada una entrega albedo en gris (el tono lo pone el color de vértice) y su mapa de normales.
const SIZE := 256

static var _cache: Dictionary = {}


static func _noise(tipo: int, frecuencia: float, semilla: int, octavas: int = 1) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = tipo as FastNoiseLite.NoiseType
	n.frequency = frecuencia
	n.seed = semilla
	n.fractal_octaves = octavas
	if octavas > 1:
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
	return n


## Capa sin costura normalizada a 0..1 (un valor por píxel).
static func _layer(n: FastNoiseLite) -> PackedFloat32Array:
	var img := n.get_seamless_image(SIZE, SIZE, false, false, 0.25, true)
	img.convert(Image.FORMAT_L8)
	var bytes := img.get_data()
	var salida := PackedFloat32Array()
	salida.resize(SIZE * SIZE)
	for i in range(SIZE * SIZE):
		salida[i] = bytes[i] / 255.0
	return salida


static func _to_textures(altura: PackedFloat32Array, albedo_base: float, albedo_rango: float, relieve: float) -> Dictionary:
	var gris := PackedByteArray()
	gris.resize(SIZE * SIZE)
	var alt := PackedByteArray()
	alt.resize(SIZE * SIZE)
	for i in range(SIZE * SIZE):
		var h := clampf(altura[i], 0.0, 1.0)
		gris[i] = int(clampf(albedo_base + (h - 0.5) * albedo_rango, 0.0, 1.0) * 255.0)
		alt[i] = int(h * 255.0)
	var imagen_albedo := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, gris)
	imagen_albedo.generate_mipmaps()
	var mapa := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, alt)
	mapa.bump_map_to_normal_map(relieve)
	mapa.generate_mipmaps()
	return {"albedo": ImageTexture.create_from_image(imagen_albedo), "normal": ImageTexture.create_from_image(mapa)}


## Arena: dunas pequeñas, ondulaciones por el viento, grano fino y guijarros.
static func sand() -> Dictionary:
	if _cache.has("sand"):
		return _cache["sand"]
	var grande := _layer(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.012, 11, 4))
	var medio := _layer(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, 12, 3))
	var grano := _layer(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.45, 13, 1))
	var celdas := _noise(FastNoiseLite.TYPE_CELLULAR, 0.1, 14, 1)
	celdas.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var guijarros := _layer(celdas)
	var altura := PackedFloat32Array()
	altura.resize(SIZE * SIZE)
	var ondas := 14.0
	for y in range(SIZE):
		for x in range(SIZE):
			var i := y * SIZE + x
			var onda := 0.5 + 0.5 * sin(TAU * ondas * (float(x) * 0.8 + float(y) * 0.6) / SIZE + (grande[i] - 0.5) * 9.0)
			var piedra := smoothstep(0.55, 0.12, guijarros[i])
			altura[i] = 0.3 * grande[i] + 0.1 * medio[i] + 0.16 * grano[i] + 0.06 * onda + 0.22 * piedra * (0.6 + 0.4 * medio[i])
	var texturas := _to_textures(altura, 0.8, 0.32, 1.7)
	_cache["sand"] = texturas
	return texturas


## Roca: estratos horizontales (la v de la textura es la altura), grietas finas y grano.
static func rock() -> Dictionary:
	if _cache.has("rock"):
		return _cache["rock"]
	var grande := _layer(_noise(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.02, 21, 4))
	var grano := _layer(_noise(FastNoiseLite.TYPE_SIMPLEX, 0.3, 22, 2))
	var celdas := _noise(FastNoiseLite.TYPE_CELLULAR, 0.035, 23, 1)
	celdas.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var grietas := _layer(celdas)
	var altura := PackedFloat32Array()
	altura.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			var i := y * SIZE + x
			var banda := 0.5 + 0.5 * sin(TAU * 9.0 * float(y) / SIZE + (grande[i] - 0.5) * 7.0)
			var fina := 0.5 + 0.5 * sin(TAU * 31.0 * float(y) / SIZE + (grano[i] - 0.5) * 5.0)
			var grieta := smoothstep(0.82, 0.6, grietas[i])
			altura[i] = 0.4 * banda + 0.12 * fina + 0.2 * grande[i] + 0.18 * grano[i] + 0.1 * (1.0 - grieta)
	var texturas := _to_textures(altura, 0.8, 0.36, 2.6)
	_cache["rock"] = texturas
	return texturas
