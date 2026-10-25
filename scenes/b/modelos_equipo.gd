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
	for p in datos["piezas"]:
		var copia := MeshInstance3D.new()
		copia.mesh = p[0]
		copia.material_override = p[1]
		copia.transform = ajuste * (p[2] as Transform3D)
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
	raiz.free()
	return datos


static func _recoger(nodo: Node, acumulada: Transform3D, salida: Array) -> void:
	for hijo in nodo.get_children():
		if hijo is Node3D:
			var xf := acumulada * (hijo as Node3D).transform
			if hijo is MeshInstance3D and (hijo as MeshInstance3D).mesh != null:
				salida.append([hijo, xf])
			_recoger(hijo, xf, salida)
