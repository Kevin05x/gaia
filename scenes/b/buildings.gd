extends Node3D
## Edificios de la base en el mundo 3D, según snapshot.buildings: modelos del equipo de diseño cuando existen
## (hangar, domo, foco, taladro y antena) y piezas por código si no. Una obra crece desde el suelo con un anillo
## ámbar y su porcentaje; un edificio apagado muestra «OFF». También dibuja la zona de construcción mientras el
## jugador elige casilla. Solo presenta: las reglas están en la simulación.
const Art := preload("res://scenes/b/art.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
const HpBar := preload("res://scenes/b/hp_bar.gd")
signal building_lost(pos: Vector3, tipo: String)  ## un edificio desapareció del snapshot (destruido): explosión con restos
signal module_lost(pos: Vector3)  ## la nave perdió un módulo (lo destruyó un ataque): explosión en ese módulo
signal building_started(pos: Vector3)  ## empezó una obra (o un módulo o mejora nuevos)
signal building_done(pos: Vector3, tipo: String)  ## terminó una obra
const TILE := 2.0
## tipo -> [modelo del equipo, ancho en metros]
const MODELOS := {"luz": ["foco", 1.3], "domo": ["hangar_roundA", 1.9], "extractor_hielo": ["taladro", 1.7],
	"hangar": ["hangar_cuadrado", 1.95], "antena": ["anthena_juego", 1.5], "torreta": ["torreta_simple", 1.5],
	"torreta_2": ["torreta_doble", 1.9]}

var ground: Callable  ## altura del terreno (x, z)
var _nodos: Dictionary = {}  ## id -> {"node", "model", "ring", "label", "off", "firma"}
var _zona: MeshInstance3D
var _por_casilla: Dictionary = {}  ## casilla -> id (para girar las torretas hacia su blanco)


func at_tile(tile: Vector2i) -> Vector3:
	var p := Vector3(tile.x * TILE, 0.0, tile.y * TILE)
	if ground.is_valid():
		p.y = ground.call(p.x, p.z)
	return p


func _process(delta: float) -> void:
	# Las obras se revelan de abajo hacia arriba, con suavidad entre un snapshot y el siguiente.
	for id in _nodos:
		var datos: Dictionary = _nodos[id]
		var fx: Dictionary = datos["fx"]
		if fx.is_empty():
			continue
		datos["mostrado"] = lerpf(float(datos["mostrado"]), float(datos["objetivo"]), 1.0 - exp(-8.0 * delta))
		var nodo: Node3D = datos["node"]
		BuildFx.revelar(fx, nodo.global_position.y, maxf(float(datos["mostrado"]), 0.02) * float(fx["alto"]) * 1.02)
		if datos["anillo_obra"]:
			(datos["ring"] as Node3D).rotation.y += delta * 2.4


func update_state(s: Dictionary) -> void:
	var lista: Array = s.get("buildings", [])
	var vistos := {}
	_por_casilla.clear()
	for e in lista:
		var id := str(e.get("id", ""))
		vistos[id] = true
		_por_casilla[e.get("tile", Vector2i.ZERO)] = id
		if not _nodos.has(id):
			_nodos[id] = _crear(e)
		_actualizar(_nodos[id], e)
	for id in _nodos.keys():
		if not vistos.has(id):
			var datos: Dictionary = _nodos[id]
			var nodo_perdido: Node3D = datos["node"]
			if visible and nodo_perdido.is_inside_tree():
				var centro := nodo_perdido.global_position + Vector3(0, float(datos.get("alto", 1.2)) * 0.5, 0)
				building_lost.emit(centro, str(datos.get("tipo", "")))
			nodo_perdido.queue_free()
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
	var barra := HpBar.crear(nodo, 3.1, 1.5)
	var cartel := BuildFx.cartel(nodo, 2.2)
	for c in cartel.values():
		(c as Node3D).visible = false
	return {"node": nodo, "model": null, "ring": anillo, "label": etiqueta, "firma": "", "bar": barra, "yaw": 0.0,
		"fx": {}, "cartel": cartel, "mostrado": 0.0, "objetivo": 0.0, "alto": 1.2, "tipo": "", "en_obra": false, "nivel": -1,
		"anillo_obra": false}


func _actualizar(datos: Dictionary, e: Dictionary) -> void:
	var tipo := str(e.get("type", ""))
	var nivel := int(e.get("level", 0))
	var en_obra := bool(e.get("building", false))
	var firma := "%s:%d:%s" % [tipo, nivel, en_obra]
	var nodo: Node3D = datos["node"]
	var progreso := float(e.get("progress", 1.0))
	var primero: bool = int(datos["nivel"]) == -1
	var era_obra: bool = datos["en_obra"]
	var nivel_antes: int = datos["nivel"]
	datos["tipo"] = tipo
	if datos["firma"] != firma:
		datos["firma"] = firma
		if datos["model"] != null:
			(datos["model"] as Node3D).queue_free()
		var modelo := Node3D.new()
		nodo.add_child(modelo)
		datos["model"] = modelo
		_modelo(modelo, tipo, maxi(nivel, 1 if en_obra else 0), en_obra, nivel)
		datos["fx"] = {}
		datos["alto"] = EscapeShip.ALTURA_TOTAL if tipo == "nave_fuga" else 1.2
		if tipo != "nave_fuga":
			var info := BuildFx.preparar(modelo, en_obra)
			datos["alto"] = float(info["alto"])
			if en_obra and not (info["mats"] as Array).is_empty():
				datos["fx"] = info
				datos["mostrado"] = progreso
				BuildFx.andamio(modelo, info)
	datos["objetivo"] = progreso
	var modelo_actual: Node3D = datos["model"]
	if tipo == "nave_fuga":
		modelo_actual.scale = Vector3.ONE  # la nave crece módulo a módulo: solo el que está en obra se escala
		if en_obra:
			EscapeShip.animar_obra(modelo_actual, nivel, progreso)
		(datos["label"] as Node3D).position.y = EscapeShip.ALTURA_TOTAL + 0.9
		(datos["bar"] as Node3D).position.y = EscapeShip.ALTURA_TOTAL + 0.4
	else:
		modelo_actual.scale = Vector3.ONE
	var anillo: Node3D = datos["ring"]
	anillo.scale = Vector3.ONE * (2.1 if tipo == "nave_fuga" else 1.0)
	anillo.visible = en_obra
	datos["anillo_obra"] = en_obra
	var vive := not en_obra and (tipo != "antena" or nivel >= 1)
	HpBar.fijar(datos["bar"], float(e.get("hp", 1.0)) / maxf(float(e.get("hp_max", 1.0)), 0.001) if vive else 1.0)
	# Tiempo que falta y barra de avance sobre la obra.
	var cartel: Dictionary = datos["cartel"]
	var alto_cartel: float = (EscapeShip.ALTURA_TOTAL + 0.6) if tipo == "nave_fuga" else float(datos["alto"]) + 0.45
	for c in cartel.values():
		(c as Node3D).visible = en_obra
	if en_obra:
		(cartel["barra"] as Node3D).position.y = alto_cartel
		(cartel["texto"] as Node3D).position.y = alto_cartel + 0.3
		BuildFx.fijar_cartel(cartel, progreso, float(e.get("remaining_s", 0.0)))
	var etiqueta: Label3D = datos["label"]
	if en_obra:
		etiqueta.text = ""
	elif not bool(e.get("active", true)):
		etiqueta.text = "OFF"
		etiqueta.modulate = Color("FF8178")
	elif tipo == "antena" and nivel >= 1:
		etiqueta.text = tr("ANTENNA_LV_SHORT") % nivel
		etiqueta.modulate = Color("9AD7C6")
	else:
		etiqueta.text = ""
	datos["en_obra"] = en_obra
	datos["nivel"] = nivel
	_avisar_cambios(datos, nodo, tipo, nivel, nivel_antes, en_obra, era_obra, primero)


## Emite una señal cuando empieza o termina una obra y cuando la nave pierde un módulo.
func _avisar_cambios(datos: Dictionary, nodo: Node3D, tipo: String, nivel: int, nivel_antes: int, en_obra: bool, era_obra: bool, primero: bool) -> void:
	if not visible or not nodo.is_inside_tree():
		return
	var base := nodo.global_position
	if primero:
		if en_obra:
			building_started.emit(base)
		return
	if tipo == "nave_fuga" and (nivel < nivel_antes or (era_obra and not en_obra and nivel <= nivel_antes)):
		var perdido := nivel_antes if nivel < nivel_antes else nivel + 1  # módulo terminado que cayó, o el que estaba en obra
		module_lost.emit(base + Vector3(0, _centro_modulo(perdido), 0))
	elif en_obra and not era_obra:
		building_started.emit(base)
	elif era_obra and not en_obra:
		building_done.emit(base, tipo)


## Altura (m, ya escalada) del centro del módulo «n» de la nave.
func _centro_modulo(n: int) -> float:
	var bases := EscapeShip.BASES
	var n_ok := clampi(n, 1, EscapeShip.MODULOS)
	var techo: float = bases[n_ok] if n_ok < EscapeShip.MODULOS else EscapeShip.ALTURA_TOTAL / EscapeShip.ESCALA
	return (bases[n_ok - 1] + techo) / 2.0 * EscapeShip.ESCALA


func _modelo(padre: Node3D, tipo: String, nivel: int, en_obra: bool = false, nivel_real: int = 0) -> void:
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
	if tipo == "nave_fuga":
		EscapeShip.construir(padre, nivel_real, en_obra)
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


## Gira la torreta de la casilla «tile» hacia el punto «hacia» (mundo). Las demás casillas no hacen nada.
func aim_at(tile: Vector2i, hacia: Vector3) -> void:
	var id: String = _por_casilla.get(tile, "")
	if id.is_empty() or not _nodos.has(id):
		return
	var datos: Dictionary = _nodos[id]
	var nodo: Node3D = datos["node"]
	var modelo: Node3D = datos["model"]
	if modelo == null or not str(datos["firma"]).begins_with("torreta"):
		return
	var d := hacia - nodo.global_position
	datos["yaw"] = lerp_angle(float(datos["yaw"]), atan2(-d.x, -d.z), 0.35)
	modelo.rotation.y = float(datos["yaw"])


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
