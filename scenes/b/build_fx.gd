class_name BuildFx
extends RefCounted
## Efecto de obra: el edificio se «imprime» de abajo hacia arriba. Cada malla pasa a un material que recorta todo lo que
## queda por encima de la altura ya construida y deja un borde ámbar brillante en el corte; alrededor aparece un andamio
## de hilos luminosos y, encima, el tiempo que falta con una barra de avance. Solo presenta: el avance lo da la simulación.
const AMBAR := Color("F0C079")
const SHADER := """
shader_type spatial;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform vec3 emission_color = vec3(0.0);
uniform float base_y = 0.0;
uniform float reveal_h = 0.0;
varying float wy;
void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}
void fragment() {
	float d = reveal_h - (wy - base_y);
	if (d < 0.0) {
		discard;
	}
	vec4 c = albedo_color;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vcol) {
		vec3 v = COLOR.rgb;
		c.rgb *= mix(pow((v + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), v * (1.0 / 12.92), vec3(lessThan(v, vec3(0.04045))));
	}
	ALBEDO = c.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color + vec3(1.0, 0.72, 0.30) * smoothstep(0.16, 0.0, d) * 1.7;
}
"""
static var _shader: Shader
static var _barras: Dictionary = {}
static var _material_andamio: StandardMaterial3D
const BARRA_PASOS := 24


static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## Mide el modelo y, con «convertir», pasa todas sus mallas al material de revelado. Devuelve {"mats": [ShaderMaterial], "alto", "ancho", "fondo"}
## (medidas en metros del modelo, que no está escalado). Si no hay mallas, «mats» queda vacío.
static func preparar(modelo: Node3D, convertir: bool = true) -> Dictionary:
	var mats: Array[ShaderMaterial] = []
	var caja := AABB()
	var primera := true
	for malla in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := malla as MeshInstance3D
		if mi.mesh == null:
			continue
		var relativa := _relativa(mi, modelo)
		var b: AABB = relativa * mi.get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
		if not convertir:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var origen: Material = mi.material_override if mi.material_override != null else mi.mesh.surface_get_material(i)
			var m := _desde(origen)
			mats.append(m)
			if mi.material_override != null:
				mi.material_override = m
				break
			mi.set_surface_override_material(i, m)
	return {"mats": mats, "alto": maxf(caja.end.y, 0.1), "ancho": maxf(caja.size.x, 0.4), "fondo": maxf(caja.size.z, 0.4),
		"centro": Vector2(caja.get_center().x, caja.get_center().z)}


static func _relativa(nodo: Node3D, raiz: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var actual: Node = nodo
	while actual != null and actual != raiz:
		if actual is Node3D:
			t = (actual as Node3D).transform * t
		actual = actual.get_parent()
	return t


static func _desde(origen: Material) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	if origen is StandardMaterial3D:
		var s := origen as StandardMaterial3D
		m.set_shader_parameter("albedo_color", s.albedo_color)
		m.set_shader_parameter("roughness", s.roughness)
		m.set_shader_parameter("metallic", s.metallic)
		m.set_shader_parameter("use_vcol", s.vertex_color_use_as_albedo)
		if s.albedo_texture != null:
			m.set_shader_parameter("albedo_tex", s.albedo_texture)
			m.set_shader_parameter("use_tex", true)
		if s.emission_enabled:
			m.set_shader_parameter("emission_color", Vector3(s.emission.r, s.emission.g, s.emission.b) * s.emission_energy_multiplier)
	return m


## Altura construida (m) y altura del suelo del edificio: lo que pasa de «altura» no se dibuja.
static func revelar(info: Dictionary, base_y: float, altura: float) -> void:
	for m in info.get("mats", []):
		(m as ShaderMaterial).set_shader_parameter("base_y", base_y)
		(m as ShaderMaterial).set_shader_parameter("reveal_h", altura)


## Andamio: cuatro postes y dos marcos de hilo ámbar translúcido alrededor del volumen final.
static func andamio(padre: Node3D, info: Dictionary) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Andamio"
	padre.add_child(raiz)
	var alto := float(info.get("alto", 1.0)) + 0.15
	var ancho := float(info.get("ancho", 1.5)) + 0.3
	var fondo := float(info.get("fondo", 1.5)) + 0.3
	var centro: Vector2 = info.get("centro", Vector2.ZERO)
	var mat := _andamio_material()
	var hilo := 0.035
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_caja(raiz, Vector3(hilo, alto, hilo), Vector3(centro.x + sx * ancho / 2.0, alto / 2.0, centro.y + sz * fondo / 2.0), mat)
	for y in [0.06, alto]:
		_caja(raiz, Vector3(ancho, hilo, hilo), Vector3(centro.x, y, centro.y - fondo / 2.0), mat)
		_caja(raiz, Vector3(ancho, hilo, hilo), Vector3(centro.x, y, centro.y + fondo / 2.0), mat)
		_caja(raiz, Vector3(hilo, hilo, fondo), Vector3(centro.x - ancho / 2.0, y, centro.y), mat)
		_caja(raiz, Vector3(hilo, hilo, fondo), Vector3(centro.x + ancho / 2.0, y, centro.y), mat)
	return raiz


static func _caja(padre: Node3D, tam: Vector3, pos: Vector3, mat: Material) -> void:
	var m := BoxMesh.new()
	m.size = tam
	var n := MeshInstance3D.new()
	n.mesh = m
	n.material_override = mat
	n.position = pos
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(n)


static func _andamio_material() -> StandardMaterial3D:
	if _material_andamio == null:
		_material_andamio = StandardMaterial3D.new()
		_material_andamio.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material_andamio.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material_andamio.albedo_color = Color(AMBAR, 0.55)
	return _material_andamio


## Barra de avance de la obra (sprite que mira a la cámara) y el tiempo restante en texto. Devuelve {"barra", "texto"}.
static func cartel(padre: Node3D, altura: float) -> Dictionary:
	var texto := Label3D.new()
	texto.name = "ObraTiempo"
	texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	texto.no_depth_test = true
	texto.font_size = 48
	texto.pixel_size = 0.0085
	texto.outline_size = 12
	texto.modulate = Color("FFF5E4")
	texto.outline_modulate = Color(0.12, 0.08, 0.06, 0.92)
	texto.render_priority = 6
	texto.position = Vector3(0, altura + 0.32, 0)
	padre.add_child(texto)
	var barra := Sprite3D.new()
	barra.name = "ObraBarra"
	barra.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barra.shaded = false
	barra.no_depth_test = true
	barra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	barra.pixel_size = 1.5 / 48.0
	barra.render_priority = 6
	barra.position = Vector3(0, altura + 0.02, 0)
	barra.texture = _barra(0)
	padre.add_child(barra)
	return {"barra": barra, "texto": texto}


static func fijar_cartel(c: Dictionary, progreso: float, segundos: float) -> void:
	var barra: Sprite3D = c["barra"]
	var paso := clampi(roundi(progreso * BARRA_PASOS), 0, BARRA_PASOS)
	var textura := _barra(paso)
	if barra.texture != textura:
		barra.texture = textura
	(c["texto"] as Label3D).text = formato_tiempo(segundos)


## «12 s» hasta un minuto; «1:05» a partir de ahí.
static func formato_tiempo(segundos: float) -> String:
	var s := maxi(ceili(segundos), 0)
	if s < 60:
		return "%d s" % s
	return "%d:%02d" % [s / 60, s % 60]


static func _barra(paso: int) -> ImageTexture:
	if _barras.has(paso):
		return _barras[paso]
	var ancho := 48
	var alto := 7
	var imagen := Image.create(ancho, alto, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0.07, 0.05, 0.05, 0.85))
	imagen.fill_rect(Rect2i(0, 0, ancho, 1), Color(AMBAR, 0.45))
	imagen.fill_rect(Rect2i(0, alto - 1, ancho, 1), Color(AMBAR, 0.45))
	var relleno := roundi(float(ancho - 4) * float(paso) / float(BARRA_PASOS))
	if relleno > 0:
		imagen.fill_rect(Rect2i(2, 2, relleno, alto - 4), AMBAR)
		imagen.fill_rect(Rect2i(2, 2, relleno, 1), Color("FFE2A8"))
	var textura := ImageTexture.create_from_image(imagen)
	_barras[paso] = textura
	return textura
