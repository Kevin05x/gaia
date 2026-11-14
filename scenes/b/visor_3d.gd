extends SubViewportContainer
## Visor 3D de los modelos oficiales de la NASA (NASA 3D Resources, «free and without copyright»): Perseverance e
## Ingenuity para Marte, el módulo lunar del Apolo para la Luna. Gira solo; se arrastra con el ratón para mirarlo.
## Tiene su propio mundo 3D (no toca la escena de la misión) y solo existe mientras el panel está abierto.

var archivos: Array = []  ## rutas res:// de los .glb a mostrar, uno al lado del otro
var tamanos: Array = []  ## medida mayor de cada modelo en la escena (escala de exposición, no real); por defecto 2,2 y 0,9
var _pivote: Node3D
var _camara: Camera3D
var _angulo := 0.6
var _altura := 0.35
var _arrastrando := false
var _radio := 3.0
var _centro := Vector3(0, 0.55, 0)


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.transparent_bg = false
	vista.msaa_3d = Viewport.MSAA_4X
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(vista)
	var mundo := WorldEnvironment.new()
	var entorno := Environment.new()
	entorno.background_mode = Environment.BG_COLOR
	entorno.background_color = Color("0b0a10")
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	entorno.ambient_light_color = Color("9aa3b8")
	entorno.ambient_light_energy = 0.55
	entorno.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	mundo.environment = entorno
	vista.add_child(mundo)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-38, 35, 0)
	sol.light_energy = 1.4
	sol.shadow_enabled = true
	vista.add_child(sol)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-15, 215, 0)
	relleno.light_energy = 0.45
	relleno.light_color = Color("aac4ff")
	vista.add_child(relleno)
	_pivote = Node3D.new()
	vista.add_child(_pivote)
	var x := 0.0
	var cajas: Array = []
	for ruta in archivos:
		if not ResourceLoader.exists(str(ruta)):
			continue
		var escena := load(str(ruta)) as PackedScene
		if escena == null:
			continue
		var modelo := escena.instantiate() as Node3D
		_pivote.add_child(modelo)
		var caja := _caja(modelo, Transform3D.IDENTITY)
		var i := cajas.size()
		var objetivo := float(tamanos[i]) if i < tamanos.size() else (2.2 if i == 0 else 0.9)
		var escala := objetivo / maxf(maxf(caja.size.x, maxf(caja.size.y, caja.size.z)), 0.001)
		modelo.scale = Vector3.ONE * escala
		caja = AABB(caja.position * escala, caja.size * escala)
		var cx := 0.0 if i == 0 else x + caja.size.x * 0.5  # uno al lado del otro, sin solaparse
		modelo.position = Vector3(cx - caja.get_center().x, -caja.position.y, -caja.get_center().z)
		x = cx + caja.size.x * 0.5 + 0.35
		cajas.append(caja)
	if cajas.is_empty():
		return
	var total := AABB()
	for k in range(cajas.size()):
		var m := _pivote.get_child(k) as Node3D
		var c := AABB(m.position + cajas[k].position, cajas[k].size)
		total = c if k == 0 else total.merge(c)
	_pivote.position = Vector3(-total.get_center().x, 0, -total.get_center().z)  # el conjunto gira sobre su centro
	_centro = Vector3(0, total.size.y * 0.42, 0)
	_radio = maxf(total.size.length() * 1.05, 2.6)
	var suelo := MeshInstance3D.new()
	var disco := CylinderMesh.new()
	disco.top_radius = 2.4
	disco.bottom_radius = 2.4
	disco.height = 0.02
	suelo.mesh = disco
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("2a2522")
	mat.roughness = 1.0
	suelo.material_override = mat
	suelo.position = Vector3(0, -0.011, 0)
	vista.add_child(suelo)
	_camara = Camera3D.new()
	_camara.fov = 38
	vista.add_child(_camara)
	_mover_camara()


func hay_modelo() -> bool:
	return _camara != null


func _caja(nodo: Node, t: Transform3D) -> AABB:
	var caja := AABB()
	var primera := true
	var actual := t
	if nodo is Node3D:
		actual = t * (nodo as Node3D).transform
	if nodo is MeshInstance3D and (nodo as MeshInstance3D).mesh != null:
		caja = actual * (nodo as MeshInstance3D).get_aabb()
		primera = false
	for h in nodo.get_children():
		var c := _caja(h, actual)
		if c.size != Vector3.ZERO:
			caja = c if primera else caja.merge(c)
			primera = false
	return caja


func _process(delta: float) -> void:
	if _camara == null:
		return
	if not _arrastrando:
		_angulo += delta * 0.35
	_mover_camara()


func _mover_camara() -> void:
	var centro := _centro
	_camara.position = centro + Vector3(cos(_angulo), 0, sin(_angulo)) * _radio * cos(_altura) + Vector3(0, _radio * sin(_altura), 0)
	_camara.look_at(centro)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_arrastrando = e.pressed
	elif e is InputEventMouseMotion and _arrastrando:
		_angulo += e.relative.x * 0.01
		_altura = clampf(_altura + e.relative.y * 0.006, 0.05, 1.2)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_radio = clampf(_radio * (0.9 if e.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 1.2, 12.0)
