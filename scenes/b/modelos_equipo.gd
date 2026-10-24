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
	if not existe(nombre):
		return creadas
	var escena := load(CARPETA + nombre + ".glb") as PackedScene
	if escena == null:
		return creadas
	var raiz := escena.instantiate() as Node3D
	var piezas: Array = []
	_recoger(raiz, Transform3D.IDENTITY, piezas)
	if piezas.is_empty():
		raiz.free()
		return creadas
	var caja := AABB()
	var primera := true
	for p in piezas:
		var b: AABB = (p[1] as Transform3D) * (p[0] as MeshInstance3D).get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	var medida := maxf(caja.size.x, caja.size.z)
	if medida <= 0.0001:
		raiz.free()
		return creadas
	var escala := ancho / medida
	var centro := caja.get_center()
	var ajuste := Transform3D(Basis.from_euler(Vector3(0, giro, 0)).scaled(Vector3.ONE * escala), pos) \
		* Transform3D(Basis.IDENTITY, Vector3(-centro.x, -caja.position.y, -centro.z))
	for p in piezas:
		var origen := p[0] as MeshInstance3D
		var copia := MeshInstance3D.new()
		copia.mesh = origen.mesh
		copia.material_override = origen.material_override
		copia.transform = ajuste * (p[1] as Transform3D)
		padre.add_child(copia)
		creadas.append(copia)
	raiz.free()
	return creadas


static func _recoger(nodo: Node, acumulada: Transform3D, salida: Array) -> void:
	for hijo in nodo.get_children():
		if hijo is Node3D:
			var xf := acumulada * (hijo as Node3D).transform
			if hijo is MeshInstance3D and (hijo as MeshInstance3D).mesh != null:
				salida.append([hijo, xf])
			_recoger(hijo, xf, salida)
