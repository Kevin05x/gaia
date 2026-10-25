extends Node3D
## Edificios de la base en el mundo 3D, según snapshot.buildings: modelos del equipo de diseño cuando existen
## (hangar, domo, foco, taladro y antena) y piezas por código si no. Una obra crece desde el suelo con un anillo
## ámbar y su porcentaje; un edificio apagado muestra «OFF». También dibuja la zona de construcción mientras el
## jugador elige casilla. Solo presenta: las reglas están en la simulación.
const Art := preload("res://scenes/b/art.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
const TILE := 2.0
## tipo -> [modelo del equipo, ancho en metros]
const MODELOS := {"luz": ["foco", 1.3], "domo": ["hangar_roundA", 1.9], "extractor_hielo": ["taladro", 1.7],
	"hangar": ["hangar_cuadrado", 1.95], "antena": ["anthena_juego", 1.5]}

var ground: Callable  ## altura del terreno (x, z)
var _nodos: Dictionary = {}  ## id -> {"node", "model", "ring", "label", "off", "firma"}
var _zona: MeshInstance3D


func at_tile(tile: Vector2i) -> Vector3:
	var p := Vector3(tile.x * TILE, 0.0, tile.y * TILE)
	if ground.is_valid():
		p.y = ground.call(p.x, p.z)
	return p


func update_state(s: Dictionary) -> void:
	var lista: Array = s.get("buildings", [])
	var vistos := {}
	for e in lista:
		var id := str(e.get("id", ""))
		vistos[id] = true
		if not _nodos.has(id):
			_nodos[id] = _crear(e)
		_actualizar(_nodos[id], e)
	for id in _nodos.keys():
		if not vistos.has(id):
			var datos: Dictionary = _nodos[id]
			(datos["node"] as Node3D).queue_free()
			_nodos.erase(id)


func clear() -> void:
	for id in _nodos:
		(_nodos[id]["node"] as Node3D).queue_free()
	_nodos.clear()
	hide_zone()


func _crear(e: Dictionary) -> Dictionary:
	var nodo := Node3D.new()
	nodo.name = str(e.get("id", "edificio"))
	add_child(nodo)
	nodo.position = at_tile(e.get("tile", Vector2i.ZERO))
	var anillo := Art.ring(nodo, 1.05, Vector3(0, 0.06, 0), Color("F0C079"))
	var etiqueta := Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.font_size = 40
	etiqueta.pixel_size = 0.01
	etiqueta.outline_size = 10
	etiqueta.modulate = Color("FFF5E4")
	etiqueta.outline_modulate = Color(0.12, 0.08, 0.06, 0.9)
	etiqueta.position = Vector3(0, 2.6, 0)
	nodo.add_child(etiqueta)
	return {"node": nodo, "model": null, "ring": anillo, "label": etiqueta, "firma": ""}


func _actualizar(datos: Dictionary, e: Dictionary) -> void:
	var tipo := str(e.get("type", ""))
	var nivel := int(e.get("level", 0))
	var en_obra := bool(e.get("building", false))
	var firma := "%s:%d:%s" % [tipo, nivel, en_obra]
	var nodo: Node3D = datos["node"]
	if datos["firma"] != firma:
		datos["firma"] = firma
		if datos["model"] != null:
			(datos["model"] as Node3D).queue_free()
		var modelo := Node3D.new()
		nodo.add_child(modelo)
		datos["model"] = modelo
		_modelo(modelo, tipo, maxi(nivel, 1 if en_obra else 0))
	var progreso := float(e.get("progress", 1.0))
	var modelo_actual: Node3D = datos["model"]
	var escala := lerpf(0.2, 1.0, progreso) if en_obra else 1.0
	modelo_actual.scale = Vector3(1.0, escala, 1.0) if en_obra else Vector3.ONE
	var anillo: Node3D = datos["ring"]
	anillo.visible = en_obra
	if en_obra:
		anillo.rotation.y += 0.04
	var etiqueta: Label3D = datos["label"]
	if en_obra:
		etiqueta.text = "%d%%" % roundi(progreso * 100.0)
		etiqueta.modulate = Color("F0C079")
	elif not bool(e.get("active", true)):
		etiqueta.text = "OFF"
		etiqueta.modulate = Color("FF8178")
	elif tipo == "antena" and nivel >= 1:
		etiqueta.text = tr("ANTENNA_LV_SHORT") % nivel
		etiqueta.modulate = Color("9AD7C6")
	else:
		etiqueta.text = ""


func _modelo(padre: Node3D, tipo: String, nivel: int) -> void:
	if tipo == "antena" and nivel <= 0:
		# Sitio de la antena aún sin construir: losa y anillo de marcado.
		Art.cylinder(padre, 0.85, 0.12, Vector3(0, 0.06, 0), Color("6F625A"))
		Art.ring(padre, 0.95, Vector3(0, 0.14, 0), Color("9AD7C6"))
		return
	if tipo == "panel_solar":
		Art.cylinder(padre, 0.08, 0.9, Vector3(0, 0.45, 0), Color("8C8F94"))
		var panel := Art.panel(padre, Vector3(1.7, 0.06, 1.15), Vector3(0, 0.95, 0), 3, 5)
		panel.rotation.x = -0.45
		return
	if MODELOS.has(tipo):
		var info: Array = MODELOS[tipo]
		var ancho := float(info[1])
		if tipo == "antena":
			ancho *= 0.75 + 0.15 * nivel
		if not Equipo.poner(padre, str(info[0]), ancho).is_empty():
			return
	# Pieza por código si falta el modelo del equipo.
	Art.rbox(padre, Vector3(1.6, 1.0, 1.6), Vector3(0, 0.5, 0), Color("B7A796"))


## Zona de construcción: casillas válidas en verde azulado y ocupadas en coral, siguiendo el relieve.
func show_zone(validas: Array, ocupadas: Array) -> void:
	hide_zone()
	var malla := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for grupo in [[validas, Color(0.55, 0.9, 0.78, 0.34)], [ocupadas, Color(1.0, 0.45, 0.42, 0.26)]]:
		for t in grupo[0]:
			_cuadro(malla, t, grupo[1])
	malla.surface_end()
	_zona = MeshInstance3D.new()
	_zona.mesh = malla
	_zona.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_zona)


func hide_zone() -> void:
	if is_instance_valid(_zona):
		_zona.queue_free()
	_zona = null


func _cuadro(malla: ImmediateMesh, tile: Vector2i, color: Color) -> void:
	var c := Vector3(tile.x * TILE, 0.0, tile.y * TILE)
	var m := TILE * 0.46
	var esquinas: Array[Vector3] = []
	for d in [Vector2(-m, -m), Vector2(m, -m), Vector2(m, m), Vector2(-m, m)]:
		var p := Vector3(c.x + d.x, 0.0, c.z + d.y)
		p.y = (ground.call(p.x, p.z) if ground.is_valid() else 0.0) + 0.07
		esquinas.append(p)
	for i in [0, 1, 2, 0, 2, 3]:
		malla.surface_set_color(color)
		malla.surface_add_vertex(esquinas[i])
