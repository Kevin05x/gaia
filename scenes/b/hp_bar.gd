extends RefCounted
## Barra de vida flotante sobre edificios y monstruos: un solo Sprite3D que mira a la cámara, con una textura
## pequeña por tramo de vida (21 en total, compartidas). Solo se ve cuando falta vida. Solo presenta.
const ANCHO_PX := 32
const ALTO_PX := 5
const PASOS := 20
static var _texturas: Dictionary = {}


static func crear(padre: Node3D, altura: float, ancho_m: float = 1.3) -> Sprite3D:
	var barra := Sprite3D.new()
	barra.name = "HpBar"
	barra.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	barra.shaded = false
	barra.no_depth_test = true
	barra.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	barra.pixel_size = ancho_m / float(ANCHO_PX)
	barra.position = Vector3(0, altura, 0)
	barra.render_priority = 5
	barra.visible = false
	barra.texture = _textura(PASOS)
	padre.add_child(barra)
	return barra


## «razon» es vida / vida máxima: solo se muestra si falta algo de vida.
static func fijar(barra: Sprite3D, razon: float) -> void:
	razon = clampf(razon, 0.0, 1.0)
	var visible := razon < 0.995
	if barra.visible != visible:
		barra.visible = visible
	if visible:
		var textura := _textura(clampi(ceili(razon * PASOS), 0, PASOS))
		if barra.texture != textura:
			barra.texture = textura


static func _textura(paso: int) -> ImageTexture:
	if _texturas.has(paso):
		return _texturas[paso]
	var imagen := Image.create(ANCHO_PX, ALTO_PX, false, Image.FORMAT_RGBA8)
	imagen.fill(Color(0.1, 0.07, 0.07, 0.88))
	var razon := float(paso) / float(PASOS)
	var tono := Color("8DD6A8") if razon > 0.5 else (Color("F0C079") if razon > 0.25 else Color("FF7468"))
	var relleno := roundi(float(ANCHO_PX - 2) * razon)
	if relleno > 0:
		imagen.fill_rect(Rect2i(1, 1, relleno, ALTO_PX - 2), tono)
	var textura := ImageTexture.create_from_image(imagen)
	_texturas[paso] = textura
	return textura
