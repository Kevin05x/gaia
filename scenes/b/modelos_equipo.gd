extends RefCounted
## Modelos .glb que entrega el equipo de diseño (assets/modelos/). Cada uno se ajusta a un ancho en metros del juego,
## se apoya en el suelo (base en y = 0) y sus mallas quedan como hijas directas del nodo padre, de modo que el contorno
## de selección y la fusión de mallas funcionan igual que con las piezas hechas por código.
const CARPETA := "res://assets/modelos/"


static func existe(nombre: String) -> bool:
	return ResourceLoader.exists(CARPETA + nombre + ".glb")


## Coloca el modelo `nombre` bajo `padre`. `ancho` es la mayor medida horizontal final. Devuelve las mallas creadas
## (vacío si el archivo no existe, para que quien llama use su pieza por código).
static func poner(padre: Node3D, nombre: String, ancho: float, pos: Vector3 = Vector3.ZERO, giro: float = 0.0) -> Array[MeshInstance3D]:
	var creadas: Array[MeshInstance3D] = []
	var datos := _datos(nombre)
	if datos.is_empty():
		return creadas
	var caja: AABB = datos["caja"]
	var medida := maxf(caja.size.x, caja.size.z)
	if medida <= 0.0001:
		return creadas
	var escala := ancho / medida
	var centro := caja.get_center()
	var ajuste := Transform3D(Basis.from_euler(Vector3(0, giro, 0)).scaled(Vector3.ONE * escala), pos) \
		* Transform3D(Basis.IDENTITY, Vector3(-centro.x, -caja.position.y, -centro.z))
	# Rendimiento (WebGL no agrupa mallas): todas las piezas van fundidas en una sola malla con una superficie por
	# material. Un cristal de 16 piezas pasa de 16 llamadas de dibujo a 2 o 3.
	var copia := MeshInstance3D.new()
	copia.mesh = datos["fusion"]
	copia.transform = ajuste
	padre.add_child(copia)
	creadas.append(copia)
	return creadas


## Carga (una sola vez por partida) los modelos indicados, para que la primera obra no espere a leer el archivo.
static func precargar(nombres: Array) -> void:
	for nombre in nombres:
		_datos(str(nombre))


## Rendimiento: cada .glb se lee y se desarma una sola vez; después solo se copian sus mallas (compartidas).
## Antes se cargaba e instanciaba el archivo en cada obra y al terminarla (y Godot lo descargaba entre medias).
static var _cache: Dictionary = {}  ## nombre -> {"piezas": [[Mesh, Material, Transform3D]], "caja": AABB} ({} si no hay)


## Suelta los modelos guardados (al salir de la misión): Godot no debe cerrar con mallas aún retenidas.
static func vaciar() -> void:
	_cache.clear()


static func _datos(nombre: String) -> Dictionary:
	if _cache.has(nombre):
		return _cache[nombre]
	var datos := {}
	_cache[nombre] = datos
	if not existe(nombre):
		return datos
	var escena := load(CARPETA + nombre + ".glb") as PackedScene
	if escena == null:
		return datos
	var raiz := escena.instantiate() as Node3D
	var piezas: Array = []
	_recoger(raiz, Transform3D.IDENTITY, piezas)
	if not piezas.is_empty():
		var caja := AABB()
		var primera := true
		var lista: Array = []
		for p in piezas:
			var mi := p[0] as MeshInstance3D
			var b: AABB = (p[1] as Transform3D) * mi.get_aabb()
			caja = b if primera else caja.merge(b)
			primera = false
			lista.append([mi.mesh, mi.material_override, p[1]])
		datos["piezas"] = lista
		datos["caja"] = caja
		datos["fusion"] = _fundir(lista)
	raiz.free()
	return datos


static func _recoger(nodo: Node, acumulada: Transform3D, salida: Array) -> void:
	for hijo in nodo.get_children():
		if hijo is Node3D:
			var xf := acumulada * (hijo as Node3D).transform
			if hijo is MeshInstance3D and (hijo as MeshInstance3D).mesh != null:
				salida.append([hijo, xf])
			_recoger(hijo, xf, salida)


## Una malla con una superficie por material, con todas las piezas ya colocadas en su sitio.
static func _fundir(piezas: Array) -> ArrayMesh:
	var grupos: Dictionary = {}  ## material -> [[malla, superficie, transformación]]
	var orden: Array = []
	for p in piezas:
		var malla: Mesh = p[0]
		for i in malla.get_surface_count():
			var material: Material = p[1] if p[1] != null else malla.surface_get_material(i)
			if not grupos.has(material):
				grupos[material] = []
				orden.append(material)
			grupos[material].append([malla, i, p[2]])
	var fusion := ArrayMesh.new()
	for material in orden:
		var st := SurfaceTool.new()
		for parte in grupos[material]:
			st.append_from(parte[0], parte[1], parte[2])
		st.commit(fusion)
		fusion.surface_set_material(fusion.get_surface_count() - 1, material)
	return fusion
