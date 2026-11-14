extends RefCounted
## Material realista de los edificios (modelos del equipo), la estación y las piezas de bloques fundidas (paneles
## solares, grúa, compañero, dron y rover web). Usa scenes/b/shaders/edificio.gdshader con las texturas de chapa de
## assets/texturas/edificio_paneles_* (generadas por _fuentes/texturas_edificios.py) y el polvo del destino.
## Con la calidad baja (opciones de gráficos) las texturas se apagan y queda el color liso con el polvo.
const SHADER := preload("res://scenes/b/shaders/edificio.gdshader")
const TEX := "res://assets/texturas/edificio_paneles_%s.jpg"
## Polvo que se posa en los edificios: gris del regolito lunar y ocre del suelo de Marte. Son tonos elegidos a ojo para
## que casen con la paleta del terreno de cada destino (estilizado), no una medición.
const POLVO := {"luna": Color("77736D"), "marte": Color("9A6A4C")}
const POLVO_CANTIDAD := {"luna": 0.45, "marte": 0.55}
const METROS_PANEL := 3.0  ## una repetición de la chapa: paneles de 37 cm a 1,1 m

static var _texturas: Dictionary = {}
static var _materiales: Array[ShaderMaterial] = []  ## todos los creados (para cambiar la calidad o el destino)
static var _fundido: ShaderMaterial
static var calidad := true


## true si están las tres texturas de chapa.
static func hay_texturas() -> bool:
	for k in ["detalle", "normal", "mascaras"]:
		if not ResourceLoader.exists(TEX % k):
			return false
	return true


static func _textura(k: String) -> Texture2D:
	if not _texturas.has(k):
		_texturas[k] = load(TEX % k) if ResourceLoader.exists(TEX % k) else null
	return _texturas[k]


## Material nuevo con el aspecto de «origen» (StandardMaterial3D de un modelo): mismo color, textura de paleta,
## color de vértice, rugosidad y metal. «base_y» es la altura local del suelo del modelo (para el polvo de abajo).
static func desde(origen: Material, base_y: float = 0.0) -> ShaderMaterial:
	var m := _nuevo()
	m.set_shader_parameter("base_y", base_y)
	if origen is StandardMaterial3D:
		var s := origen as StandardMaterial3D
		m.set_shader_parameter("albedo_color", s.albedo_color)
		m.set_shader_parameter("roughness", s.roughness)
		m.set_shader_parameter("metallic", s.metallic)
		m.set_shader_parameter("use_vcol", s.vertex_color_use_as_albedo)
		if s.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", s.albedo_texture)
			m.set_shader_parameter("use_tex", true)
	return m


## Material compartido de las mallas fundidas por Art.merged: color de vértice y, en UV2, la rugosidad y el metal de
## cada pieza.
static func fundido() -> ShaderMaterial:
	if _fundido == null:
		_fundido = _nuevo()
		_fundido.set_shader_parameter("use_vcol", true)
		_fundido.set_shader_parameter("pbr_uv2", true)
	return _fundido


## true si el material es uno de estos (BuildFx lo convierte a su material de obra leyendo sus parámetros).
static func es_propio(m: Material) -> bool:
	return m is ShaderMaterial and (m as ShaderMaterial).shader == SHADER


static func _nuevo() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("paneles_detalle", _textura("detalle"))
	m.set_shader_parameter("paneles_normal", _textura("normal"))
	m.set_shader_parameter("paneles_mascaras", _textura("mascaras"))
	m.set_shader_parameter("metros_panel", METROS_PANEL)
	_ajustar(m)
	_materiales.append(m)
	return m


static func _ajustar(m: ShaderMaterial) -> void:
	var destino := "luna" if Destino.es_luna() else "marte"
	m.set_shader_parameter("detalle", 1.0 if calidad and hay_texturas() else 0.0)
	m.set_shader_parameter("polvo_color", POLVO[destino])
	m.set_shader_parameter("polvo", POLVO_CANTIDAD[destino])


## Calidad alta (texturas) o baja (color liso), y el polvo del destino actual, en todos los materiales creados.
static func aplicar(con_calidad: bool) -> void:
	calidad = con_calidad
	for m in _materiales:
		_ajustar(m)


## Suelta los materiales guardados (al salir de la misión o cambiar de destino).
static func vaciar() -> void:
	_materiales.clear()
	if _fundido != null:
		_materiales.append(_fundido)
