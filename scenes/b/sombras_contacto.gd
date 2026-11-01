class_name SombrasContacto
extends Node3D
## Sombras de contacto de lo que se mueve o se construye durante la partida: estación, edificios, muros, Rocky y el
## dron. Es la «oclusión ambiental» barata: una mancha oscura y suave bajo cada cosa, inclinada con el suelo, que la
## asienta aunque el sol esté alto o detrás. El renderer de la web (Compatibility) no tiene SSAO, así que esto la
## sustituye. Dos MultiMesh (dos llamadas de dibujo): las fijas solo se recolocan cuando cambia la base y las móviles
## (pocas) se mueven cada cuadro. Las rocas del terreno ya traen las suyas (terrain.gd) y el rover la suya (actors.gd).
const W := preload("res://scenes/b/world_art.gd")
## tipo de edificio -> [radio (m), opacidad]
const TAMANOS := {"panel_solar": [1.15, 0.55], "luz": [0.8, 0.6], "domo": [1.55, 0.75], "extractor_hielo": [1.35, 0.7],
	"hangar": [1.75, 0.75], "torreta": [1.1, 0.7], "torreta_2": [1.3, 0.7], "antena": [1.2, 0.65], "nave_fuga": [2.6, 0.8],
	"barrera": [0.95, 0.7], "compuerta": [1.05, 0.6]}

const AMPLIA := 1.45

var ground: Callable  ## altura del terreno (x, z)
var _fijas: MultiMeshInstance3D
var _moviles: MultiMeshInstance3D
var _seguidos: Array = []  ## [Node3D, radio, opacidad, altura a la que se desvanece]
var _firma := ""


func _ready() -> void:
	_fijas = _capa("Fijas")
	_moviles = _capa("Moviles")


func _capa(nombre: String) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.orientation = PlaneMesh.FACE_Y
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	var nodo := MultiMeshInstance3D.new()
	nodo.name = nombre
	nodo.multimesh = mm
	nodo.material_override = W.ao_material()
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	return nodo


## Cosas que se mueven (Rocky, el dron): su mancha las sigue y se aclara cuanto más alto vuelan.
func seguir(nodo: Node3D, radio: float, opacidad: float, desvanece_a: float = 0.0) -> void:
	_seguidos.append([nodo, radio, opacidad, desvanece_a])
	_moviles.multimesh.instance_count = _seguidos.size()


## Estación, edificios y muros del snapshot. Solo rehace la capa si algo cambió.
func update_state(s: Dictionary, estacion: Vector3) -> void:
	var items: Array = [[estacion, 3.6, 0.85]]
	var partes := PackedStringArray([str(Vector2(estacion.x, estacion.z))])
	for e in s.get("buildings", []):
		var tipo := str(e.get("type", ""))
		var tam: Array = TAMANOS.get(tipo, [1.2, 0.6])
		var t: Vector2i = e.get("tile", Vector2i.ZERO)
		var en_obra := bool(e.get("building", false))
		if tipo == "antena" and int(e.get("level", 0)) <= 0 and not en_obra:
			continue  # sitio de la antena sin construir: solo una losa
		# La mancha sobresale del edificio: AMPLIA veces su radio, para que se vea el contacto alrededor.
		items.append([Vector3(t.x * 2.0, 0.0, t.y * 2.0), float(tam[0]) * AMPLIA, float(tam[1]) * (0.6 if en_obra else 1.0)])
		partes.append("%s%d,%d%s" % [tipo, t.x, t.y, en_obra])
	var firma := ";".join(partes)
	if firma == _firma:
		return
	_firma = firma
	var mm := _fijas.multimesh
	mm.instance_count = items.size()
	for k in items.size():
		var it: Array = items[k]
		mm.set_instance_transform(k, _sobre_suelo(it[0], float(it[1])))
		mm.set_instance_color(k, Color(1, 1, 1, float(it[2])))


func _process(_delta: float) -> void:
	var mm := _moviles.multimesh
	for k in _seguidos.size():
		var dato: Array = _seguidos[k]
		var nodo: Node3D = dato[0]
		if not is_instance_valid(nodo) or not nodo.is_visible_in_tree():
			mm.set_instance_color(k, Color(1, 1, 1, 0))
			continue
		var p := nodo.global_position
		var opacidad := float(dato[2])
		var radio := float(dato[1])
		var tope := float(dato[3])
		if tope > 0.0 and ground.is_valid():
			var alto := maxf(p.y - float(ground.call(p.x, p.z)), 0.0)
			var k_alto := clampf(alto / tope, 0.0, 1.0)
			opacidad *= 1.0 - k_alto * 0.8
			radio *= 1.0 + k_alto * 0.6  # más alto: más grande y más difusa
		mm.set_instance_transform(k, _sobre_suelo(p, radio))
		mm.set_instance_color(k, Color(1, 1, 1, opacidad))


## Cuadro de lado 2·radio apoyado en el suelo e inclinado con su pendiente.
func _sobre_suelo(p: Vector3, radio: float) -> Transform3D:
	var y := p.y
	var n := Vector3.UP
	if ground.is_valid():
		y = ground.call(p.x, p.z)
		var d := maxf(radio * 0.6, 0.5)
		var hx: float = ground.call(p.x + d, p.z) - ground.call(p.x - d, p.z)
		var hz: float = ground.call(p.x, p.z + d) - ground.call(p.x, p.z - d)
		n = Vector3(-hx, 2.0 * d, -hz).normalized()
	var x := Vector3.RIGHT.slide(n).normalized()
	return Transform3D(Basis(x, n, x.cross(n)).scaled(Vector3(radio * 2.0, 1.0, radio * 2.0)), Vector3(p.x, y + 0.06, p.z))
