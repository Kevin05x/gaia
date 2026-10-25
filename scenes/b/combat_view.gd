extends Node3D
## Combate en el mundo 3D, según snapshot.combat y snapshot.nests: los nidos, los monstruos (araña, Void Biter y
## Coloso, hechos por código en low-poly mientras llegan los modelos del equipo), los rayos de las torretas, los
## meteoritos que caen con su aviso en el suelo, y los fogonazos de impactos y bajas. Solo presenta: las reglas
## están en la simulación (sim/systems/combat_system.gd). Cuesta una malla por monstruo.
const Art := preload("res://scenes/b/art.gd")
const HpBar := preload("res://scenes/b/hp_bar.gd")
const TILE := 2.0
const MAX_RAYOS := 8
const MAX_METEORITOS := 8
const MAX_FOGONAZOS := 10
const ENTRADA_METEORITO := Vector3(5.0, 11.0, 2.0)  ## de dónde baja el meteorito, en línea recta, durante el último tramo del aviso
const TRAMO_CAIDA := 0.4  ## fracción final del aviso en la que se le ve caer (antes está fuera de cámara)
const ALTURA_BOCA := 1.55  ## de dónde sale el rayo de una torreta

var ground: Callable  ## altura del terreno (x, z)
var buildings: Node3D  ## para girar las torretas hacia su blanco

var _nidos: Array[Node3D] = []
var _nidos_firma := ""
var _enemigos: Dictionary = {}  ## id -> {"node", "model", "bar", "target": Vector3, "yaw": float, "fase": float, "tipo", "size", "age"}
var _plantillas: Dictionary = {}  ## tipo -> Node3D sin añadir al árbol
var _rayos: Array[MeshInstance3D] = []
var _material_rayo: StandardMaterial3D
var _meteoritos: Array[Dictionary] = []  ## {"root", "ring", "rock", "trail"}
var _fogonazos: Array[Dictionary] = []  ## {"node", "material", "t", "dur", "size", "color"}
var _impactos_vistos: Dictionary = {}
var _reloj := 0.0
var _alerta := false


func _ready() -> void:
	name = "Combat"
	_material_rayo = StandardMaterial3D.new()
	_material_rayo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_rayo.albedo_color = Color("FFD9A0")
	_material_rayo.emission_enabled = true
	_material_rayo.emission = Color("FFB45E")
	_material_rayo.emission_energy_multiplier = 2.0
	_material_rayo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in MAX_RAYOS:
		var rayo := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(0.07, 0.07, 1.0)
		rayo.mesh = caja
		rayo.material_override = _material_rayo
		rayo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rayo.visible = false
		add_child(rayo)
		_rayos.append(rayo)
	for i in MAX_METEORITOS:
		_meteoritos.append(_crear_meteorito())
	for i in MAX_FOGONAZOS:
		_fogonazos.append(_crear_fogonazo())


func at_tile(tile: Vector2) -> Vector3:
	var p := Vector3(tile.x * TILE, 0.0, tile.y * TILE)
	if ground.is_valid():
		p.y = ground.call(p.x, p.z)
	return p


func update_state(s: Dictionary) -> void:
	var combate: Dictionary = s.get("combat", {})
	var jugando: bool = not combate.is_empty() and s.get("phase", "") != "workshop"
	visible = jugando
	if not jugando:
		_limpiar_enemigos()
		return
	_construir_nidos(s.get("nests", []))
	var onda: Dictionary = combate.get("wave", {})
	_alerta = (not combate.get("enemies", []).is_empty()) or (not onda.is_empty() and float(onda.get("in_h", 99.0)) <= 3.0)
	_sincronizar_enemigos(combate.get("enemies", []))
	_mostrar_rayos(combate.get("shots", []))
	_mostrar_meteoritos(combate.get("impacts", []))


func fogonazo(pos: Vector3, color: Color, tamano: float, duracion: float = 0.45) -> void:
	for f in _fogonazos:
		if not f["node"].visible:
			f["t"] = 0.0
			f["dur"] = duracion
			f["size"] = tamano
			f["color"] = color
			f["node"].position = pos
			f["node"].visible = true
			return


func _process(delta: float) -> void:
	_reloj += delta
	if not visible:
		return
	var suave := 1.0 - exp(-22.0 * delta)
	for id in _enemigos:
		var e: Dictionary = _enemigos[id]
		var nodo: Node3D = e["node"]
		var destino: Vector3 = e["target"]
		var antes := nodo.position
		nodo.position = antes.lerp(destino, suave)
		var mov := nodo.position - antes
		mov.y = 0.0
		if mov.length() > 0.0008:
			e["yaw"] = lerp_angle(float(e["yaw"]), atan2(-mov.x, -mov.z), 1.0 - exp(-10.0 * delta))
		nodo.rotation.y = float(e["yaw"])
		e["age"] = float(e["age"]) + delta
		var crece := minf(float(e["age"]) / 0.5, 1.0)
		var modelo: Node3D = e["model"]
		var fase := float(e["fase"])
		var tam := float(e["size"])
		var moviendose := mov.length() > 0.0008
		if e["tipo"] == "void_biter":
			modelo.position.y = 0.55 + sin(_reloj * 3.0 + fase) * 0.16
			modelo.rotation.z = sin(_reloj * 2.0 + fase) * 0.08
		else:
			var ritmo := 10.0 if e["tipo"] == "arana" else 4.0
			modelo.position.y = absf(sin(_reloj * ritmo + fase)) * 0.07 * tam if moviendose else 0.0
			modelo.rotation.z = sin(_reloj * ritmo + fase) * 0.045 if moviendose else 0.0
		var golpe := 1.0
		if e["attacking"]:
			golpe = 1.0 + sin(_reloj * 26.0) * 0.07
		modelo.scale = Vector3(1.0 / golpe, golpe, golpe) * tam * crece
	var pulso := 0.5 + 0.5 * sin(_reloj * (5.0 if _alerta else 1.8))
	for nido in _nidos:
		var brillo := nido.get_node_or_null("Glow") as MeshInstance3D
		if brillo != null:
			var material := brillo.material_override as StandardMaterial3D
			material.emission_energy_multiplier = (1.4 + pulso * 2.6) if _alerta else (0.6 + pulso * 0.7)
	for f in _fogonazos:
		var nodo: MeshInstance3D = f["node"]
		if not nodo.visible:
			continue
		f["t"] = float(f["t"]) + delta
		var u: float = float(f["t"]) / float(f["dur"])
		if u >= 1.0:
			nodo.visible = false
			continue
		nodo.scale = Vector3.ONE * float(f["size"]) * (0.25 + u * 1.15)
		var color: Color = f["color"]
		color.a = (1.0 - u) * 0.8
		(f["material"] as StandardMaterial3D).albedo_color = color
	for rayo in _rayos:
		if rayo.visible:
			rayo.scale.x = 1.0 + sin(_reloj * 90.0) * 0.4
			rayo.scale.y = rayo.scale.x


# --- Nidos ------------------------------------------------------------------------------------------------------------

func _construir_nidos(lista: Array) -> void:
	var firma := var_to_str(lista)
	if firma == _nidos_firma:
		return
	_nidos_firma = firma
	for nido in _nidos:
		nido.queue_free()
	_nidos.clear()
	for entrada in lista:
		var nodo := Node3D.new()
		nodo.name = str(entrada.get("id", "nido"))
		add_child(nodo)
		nodo.position = at_tile(Vector2(entrada.get("tile", Vector2i.ZERO)))
		_modelo_nido(nodo, str(entrada.get("id", "")).hash())
		_nidos.append(nodo)


func _modelo_nido(nodo: Node3D, semilla: int) -> void:
	var tierra := Color("3b2b30")
	Art.cylinder(nodo, 1.55, 0.8, Vector3(0, 0.4, 0), tierra, 0.8, 7)
	Art.cylinder(nodo, 0.95, 0.12, Vector3(0, 0.84, 0), Color("120c14"), -1.0, 7)
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	for i in 7:
		var ang := float(i) / 7.0 * TAU + azar.randf() * 0.4
		var radio := 1.25 + azar.randf() * 0.25
		var alto := 0.9 + azar.randf() * 0.9
		var base := Vector3(cos(ang) * radio, 0.62, sin(ang) * radio)
		var punta := base + Vector3(cos(ang) * 0.25, alto, sin(ang) * 0.25)
		Art.rod(nodo, base, punta, 0.17, Color("2c2128") if i % 2 == 0 else Color("4a3040"))
	Art.merged(nodo)
	var brillo := MeshInstance3D.new()
	brillo.name = "Glow"
	var disco := CylinderMesh.new()
	disco.top_radius = 0.62
	disco.bottom_radius = 0.62
	disco.height = 0.04
	disco.radial_segments = 8
	brillo.mesh = disco
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("7B4FCB")
	material.emission_enabled = true
	material.emission = Color("9B6BFF")
	material.emission_energy_multiplier = 0.8
	brillo.material_override = material
	brillo.position = Vector3(0, 0.92, 0)
	brillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(brillo)


# --- Monstruos --------------------------------------------------------------------------------------------------------

func _sincronizar_enemigos(lista: Array) -> void:
	var vistos := {}
	for dato in lista:
		var id := str(dato.get("id", ""))
		vistos[id] = true
		if not _enemigos.has(id):
			_enemigos[id] = _crear_enemigo(dato)
		var e: Dictionary = _enemigos[id]
		var pos2: Vector2 = dato.get("pos", Vector2.ZERO)
		e["target"] = at_tile(pos2)
		e["attacking"] = bool(dato.get("attacking", false))
		HpBar.fijar(e["bar"], float(dato.get("hp", 1.0)) / maxf(float(dato.get("hp_max", 1.0)), 0.001))
	for id in _enemigos.keys():
		if not vistos.has(id):
			var e: Dictionary = _enemigos[id]
			var nodo: Node3D = e["node"]
			fogonazo(nodo.position + Vector3(0, 0.6 * float(e["size"]), 0), Color("6B3FA0"), 1.4 * maxf(float(e["size"]), 0.8))
			nodo.queue_free()
			_enemigos.erase(id)


func _crear_enemigo(dato: Dictionary) -> Dictionary:
	var tipo := str(dato.get("type", "arana"))
	var nodo := Node3D.new()
	nodo.name = "Enemigo_" + str(dato.get("id", ""))
	add_child(nodo)
	var modelo := _plantilla(tipo).duplicate() as Node3D
	nodo.add_child(modelo)
	var pos := at_tile(Vector2(dato.get("pos", Vector2.ZERO)))
	nodo.position = pos
	var tamano := float(dato.get("size", 1.0))
	var barra := HpBar.crear(nodo, (1.5 if tipo != "coloso" else 1.9) * maxf(tamano, 0.9) + 0.5, 0.9 if tipo != "coloso" else 1.9)
	return {"node": nodo, "model": modelo, "bar": barra, "target": pos, "yaw": 0.0, "fase": float(str(dato.get("id", "")).hash() % 628) / 100.0,
		"tipo": tipo, "size": tamano, "age": 0.0, "attacking": false}


func _limpiar_enemigos() -> void:
	for id in _enemigos:
		(_enemigos[id]["node"] as Node3D).queue_free()
	_enemigos.clear()


func _plantilla(tipo: String) -> Node3D:
	if not _plantillas.has(tipo):
		var raiz := Node3D.new()
		raiz.name = "Model"
		match tipo:
			"void_biter":
				_modelo_biter(raiz)
			"coloso":
				_modelo_coloso(raiz)
			_:
				_modelo_arana(raiz)
		_plantillas[tipo] = raiz
	return _plantillas[tipo]


func _exit_tree() -> void:
	for tipo in _plantillas:
		(_plantillas[tipo] as Node3D).free()  # las plantillas viven fuera del árbol: se liberan a mano
	_plantillas.clear()


## Un monstruo de cada tipo (fuera del árbol) para que ShaderWarmup compile sus materiales antes de la primera oleada.
func muestras_para_precalentar() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for tipo in ["arana", "void_biter", "coloso"]:
		lista.append(_plantilla(tipo).duplicate() as Node3D)
	return lista


func _brillo(padre: Node3D, pos: Vector3, radio: float, color: Color, nombre: String = "Eye") -> MeshInstance3D:
	var ojo := MeshInstance3D.new()
	ojo.name = nombre
	var esfera := SphereMesh.new()
	esfera.radius = radio
	esfera.height = radio * 2.0
	esfera.radial_segments = 6
	esfera.rings = 3
	ojo.mesh = esfera
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.2
	ojo.material_override = material
	ojo.position = pos
	ojo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(ojo)
	return ojo


func _modelo_arana(raiz: Node3D) -> void:
	var cuerpo := Color("4d3a5c")
	var pata := Color("3a2c47")
	var marca := Color("e0643f")
	var abdomen := Art.ball(raiz, 0.5, Vector3(0, 0.62, 0.52), Color("5a4268"))
	abdomen.scale = Vector3(1.0, 0.82, 1.2)
	Art.box(raiz, Vector3(0.16, 0.05, 0.62), Vector3(0, 1.0, 0.52), marca)
	var torax := Art.ball(raiz, 0.4, Vector3(0, 0.58, -0.1), cuerpo)
	torax.scale = Vector3(1.0, 0.75, 1.1)
	Art.ball(raiz, 0.26, Vector3(0, 0.55, -0.62), Color("624a72"))
	for lado in [-1.0, 1.0]:
		Art.rod(raiz, Vector3(lado * 0.1, 0.42, -0.82), Vector3(lado * 0.09, 0.14, -0.98), 0.045, Color("d9d0c0"))
		for i in 4:
			var z := -0.3 + float(i) * 0.24
			var cadera := Vector3(lado * 0.3, 0.58, z * 0.7)
			var rodilla := Vector3(lado * 0.95, 1.0, z * 1.25)
			var pie := Vector3(lado * 1.35, 0.0, z * 1.55)
			Art.rod(raiz, cadera, rodilla, 0.062, pata)
			Art.rod(raiz, rodilla, pie, 0.045, pata)
	Art.merged(raiz)
	for lado in [-1.0, 1.0]:
		_brillo(raiz, Vector3(lado * 0.1, 0.63, -0.8), 0.055, Color("FF5B3D"))
		_brillo(raiz, Vector3(lado * 0.18, 0.55, -0.72), 0.04, Color("FF5B3D"))


func _modelo_biter(raiz: Node3D) -> void:
	var piel := Color("2c2250")
	var cuerpo := Art.ball(raiz, 0.58, Vector3(0, 0.62, 0.0), piel)
	cuerpo.scale = Vector3(1.0, 0.8, 1.15)
	for lado in [-1.0, 1.0]:
		var ala := Art.rock(raiz, Vector3(lado * 0.78, 0.7, 0.12), Vector3(0.85, 0.07, 0.7), Color("3c2d66"))
		ala.rotation = Vector3(0.0, lado * 0.25, -lado * 0.4)
	for i in 5:
		var x := -0.36 + float(i) * 0.18
		var diente_sup := Art.cylinder(raiz, 0.07, 0.32, Vector3(x, 0.5, -0.72), Color("d9d0c0"), 0.0, 5)
		diente_sup.rotation.x = PI
		Art.cylinder(raiz, 0.07, 0.3, Vector3(x, 0.2, -0.7), Color("d9d0c0"), 0.0, 5)
	Art.rock(raiz, Vector3(0, 0.38, -0.55), Vector3(0.8, 0.2, 0.55), Color("2a1e45"))
	for i in 3:
		var punta := Art.cylinder(raiz, 0.1, 0.5, Vector3((float(i) - 1.0) * 0.22, 0.7, 0.78), Color("3b2b5e"), 0.0, 5)
		punta.rotation.x = -PI / 2.0 - 0.3
	Art.merged(raiz)
	_brillo(raiz, Vector3(0, 0.95, 0.12), 0.2, Color("9B6BFF"), "Core")
	for lado in [-1.0, 1.0]:
		_brillo(raiz, Vector3(lado * 0.2, 0.78, -0.5), 0.06, Color("C8A2FF"))


func _modelo_coloso(raiz: Node3D) -> void:
	var roca := Color("7a6055")
	var placa := Color("9a7562")
	Art.rock(raiz, Vector3(0, 1.05, 0.0), Vector3(1.4, 0.8, 1.6), roca)
	Art.rock(raiz, Vector3(0, 1.55, 0.1), Vector3(1.05, 0.5, 1.2), placa)
	for lado in [-1.0, 1.0]:
		for fila in [-1.0, 1.0]:
			Art.cylinder(raiz, 0.24, 0.95, Vector3(lado * 0.58, 0.48, fila * 0.55), Color("66504a"), 0.18, 7)
			Art.box(raiz, Vector3(0.5, 0.14, 0.62), Vector3(lado * 0.58, 0.07, fila * 0.58), Color("2e2423"))
	Art.rock(raiz, Vector3(0, 1.15, -1.0), Vector3(0.7, 0.58, 0.72), Color("8a6a5c"))
	for lado in [-1.0, 1.0]:
		var cuerno := Art.cylinder(raiz, 0.12, 0.62, Vector3(lado * 0.36, 1.58, -1.1), Color("d6c9b4"), 0.0, 6)
		cuerno.rotation = Vector3(-0.5, 0.0, -lado * 0.3)
	for i in 5:
		var z := -0.6 + float(i) * 0.36
		Art.rock(raiz, Vector3(0, 1.95 - absf(z + 0.0) * 0.12, z), Vector3(0.38, 0.5, 0.3), Color("b08468") if i % 2 == 0 else placa)
	Art.merged(raiz)
	for i in 3:
		var grieta := MeshInstance3D.new()
		grieta.name = "Glow"
		var caja := BoxMesh.new()
		caja.size = Vector3(0.07, 0.03, 0.9)
		grieta.mesh = caja
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("FF8A3D")
		material.emission_enabled = true
		material.emission = Color("FF7A2E")
		material.emission_energy_multiplier = 2.4
		grieta.material_override = material
		grieta.position = Vector3((float(i) - 1.0) * 0.32, 1.84, 0.1)
		grieta.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(grieta)
	for lado in [-1.0, 1.0]:
		_brillo(raiz, Vector3(lado * 0.22, 1.25, -1.34), 0.07, Color("FF8A3D"))


# --- Rayos, meteoritos y fogonazos ------------------------------------------------------------------------------------

func _mostrar_rayos(disparos: Array) -> void:
	var usados := 0
	var vistos := {}
	for d in disparos:
		var tipo := str(d.get("kind", "shot"))
		var origen: Vector2i = d.get("from", Vector2i.ZERO)
		var destino2: Vector2 = d.get("to", Vector2.ZERO)
		if tipo == "impact":
			var clave := "%d,%d" % [origen.x, origen.y]
			vistos[clave] = true
			if not _impactos_vistos.has(clave):
				_impactos_vistos[clave] = true
				var suelo := at_tile(Vector2(origen))
				fogonazo(suelo + Vector3(0, 0.4, 0), Color("FF9A4D"), 3.4, 0.6)
				fogonazo(suelo + Vector3(0, 0.2, 0), Color("5b4640"), 2.4, 0.9)
			continue
		if usados >= MAX_RAYOS:
			continue
		var desde := at_tile(Vector2(origen)) + Vector3(0, ALTURA_BOCA, 0)
		var hasta := at_tile(destino2) + Vector3(0, 0.7, 0)
		var largo := desde.distance_to(hasta)
		if largo < 0.05:
			continue
		var rayo := _rayos[usados]
		usados += 1
		rayo.visible = true
		rayo.global_transform = Transform3D(Basis.looking_at((hasta - desde).normalized(), Vector3.UP).scaled(Vector3(1, 1, largo)), (desde + hasta) / 2.0)
		if buildings != null and buildings.has_method("aim_at"):
			buildings.aim_at(origen, hasta)
	for i in range(usados, MAX_RAYOS):
		_rayos[i].visible = false
	for clave in _impactos_vistos.keys():
		if not vistos.has(clave):
			_impactos_vistos.erase(clave)


func _crear_meteorito() -> Dictionary:
	var raiz := Node3D.new()
	raiz.visible = false
	add_child(raiz)
	var aro := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.93
	toro.outer_radius = 1.0
	toro.rings = 24
	toro.ring_segments = 4
	aro.mesh = toro
	var material_aro := StandardMaterial3D.new()
	material_aro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_aro.albedo_color = Color("FF6B4A")
	aro.material_override = material_aro
	aro.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	raiz.add_child(aro)
	var piedra := Node3D.new()
	raiz.add_child(piedra)
	Art.ball(piedra, 0.5, Vector3.ZERO, Color("4a3a36"))
	_brillo(piedra, Vector3(0, 0.05, 0), 0.55, Color("FF7A2E"), "Fire")
	var estela := Art.cylinder(piedra, 0.42, 7.0, Vector3(0, 3.9, 0), Color("FFB45E"), 0.0, 7)
	estela.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	piedra.basis = Basis(Quaternion(Vector3.UP, ENTRADA_METEORITO.normalized()))
	return {"root": raiz, "ring": aro, "rock": piedra}


func _mostrar_meteoritos(impactos: Array) -> void:
	for i in MAX_METEORITOS:
		var m: Dictionary = _meteoritos[i]
		var raiz: Node3D = m["root"]
		if i >= impactos.size():
			raiz.visible = false
			continue
		var d: Dictionary = impactos[i]
		raiz.visible = true
		var suelo := at_tile(Vector2(d.get("tile", Vector2i.ZERO)))
		raiz.position = suelo
		var radio_m := float(d.get("radius", 1.5)) * TILE
		var aro: Node3D = m["ring"]
		var u := 1.0 - clampf(float(d.get("t", 0.0)) / maxf(float(d.get("total", 1.0)), 0.001), 0.0, 1.0)  ## avance del aviso: 0 recién anunciado, 1 impacta
		aro.position = Vector3(0, 0.12, 0)
		aro.scale = Vector3(radio_m, 1.0, radio_m) * (1.0 + (1.0 - u) * 0.0 + sin(_reloj * 14.0) * 0.04)
		var caida := clampf((u - (1.0 - TRAMO_CAIDA)) / TRAMO_CAIDA, 0.0, 1.0)  ## 0 = aún fuera de cámara, 1 = toca el suelo
		(m["rock"] as Node3D).position = ENTRADA_METEORITO * (1.0 - caida) + Vector3(0.0, 0.6, 0.0)


func _crear_fogonazo() -> Dictionary:
	var nodo := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.5
	esfera.height = 1.0
	esfera.radial_segments = 8
	esfera.rings = 4
	nodo.mesh = esfera
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nodo.material_override = material
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.visible = false
	add_child(nodo)
	return {"node": nodo, "material": material, "t": 0.0, "dur": 0.5, "size": 1.0, "color": Color.WHITE}
