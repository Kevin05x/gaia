class_name ShaderWarmup
extends Node3D
## Precalentado de sombreadores. En la web (WebGL) cada material nuevo se compila la primera vez que se dibuja, y eso
## congela la imagen un momento: la primera obra, la primera extracción, la primera explosión o la primera oleada se
## «trababan». Al empezar la misión, detrás de una cortina oscura que se desvanece, se dibuja durante unos cuadros una
## muestra de todo lo que aún no está a la vista (edificios terminados y en obra, monstruos, efectos guardados en reserva,
## partículas del taladro…), con y sin sombras del sol, unas pocas por cuadro para no congelar el navegador. Después
## se borra. No cambia nada de cómo se ve el juego.
signal terminado

const POR_CUADRO := 4  ## muestras que se dibujan por cuadro: cada cuadro compila pocos sombreadores y la web no se congela
const ESCALA := 0.06  ## la muestra es diminuta y está tapada por la cortina: el jugador no la ve

var camara: Camera3D
var sol: DirectionalLight3D
var _cuadro := -1
var _muestras: Array[Node3D] = []
var _sombras_antes := true
var _vistas: Dictionary = {}  ## firmas de lo ya copiado (las reservas de efectos repiten muchas piezas iguales)


## «raices»: nodos cuya geometría oculta se copia (reservas de efectos). «extra»: muestras ya hechas (fuera del árbol).
func empezar(raices: Array, extra: Array) -> void:
	for raiz in raices:
		if raiz is Node:
			_copiar_ocultos(raiz as Node)
	for nodo in extra:
		if nodo is Node3D:
			_agregar(nodo as Node3D)
	for m in _muestras:
		m.visible = false
	_cuadro = 0
	if sol != null:
		_sombras_antes = sol.shadow_enabled
		sol.shadow_enabled = true
	_mostrar_grupo(0)


## Termina ya (la pantalla de carga se cansó de esperar): borra las muestras y avisa, como si hubiera acabado.
func terminar() -> void:
	if _cuadro < 0:
		return
	if sol != null:
		sol.shadow_enabled = _sombras_antes
	for m in _muestras:
		m.queue_free()
	_muestras.clear()
	_cuadro = -1
	terminado.emit()


func activo() -> bool:
	return _cuadro >= 0


func cantidad() -> int:
	return _muestras.size()


## Avance de 0 a 1 (para la pantalla de carga).
func avance() -> float:
	if _cuadro < 0:
		return 1.0
	return clampf(float(_cuadro) / float(maxi(_grupos() * 2, 1)), 0.0, 1.0)


func _grupos() -> int:
	return ceili(float(_muestras.size()) / float(POR_CUADRO))


## Cada cuadro se dibuja solo un grupo pequeño de muestras: primero todas con sombras del sol y luego sin ellas
## (noche y tormenta usan la variante sin sombras).
func _mostrar_grupo(indice: int) -> void:
	var g := indice % maxi(_grupos(), 1)
	for i in _muestras.size():
		_muestras[i].visible = i / POR_CUADRO == g
	_colocar()


func _process(_delta: float) -> void:
	if _cuadro < 0:
		return
	_cuadro += 1
	var total := _grupos() * 2
	if sol != null and _cuadro == _grupos():
		sol.shadow_enabled = false
	if _cuadro >= total:
		if sol != null:
			sol.shadow_enabled = _sombras_antes
		for m in _muestras:
			m.queue_free()
		_muestras.clear()
		_cuadro = -1
		terminado.emit()
		return
	_mostrar_grupo(_cuadro)


## Las muestras se ponen en fila justo delante de la cámara (dentro de su vista, si no, no se dibujarían).
func _colocar() -> void:
	if camara == null or not camara.is_inside_tree():
		return
	var base := camara.global_transform
	var n := _muestras.size()
	for i in n:
		var columna := float(i % POR_CUADRO) - (POR_CUADRO - 1) * 0.5
		var fila := 0.0
		_muestras[i].global_transform = Transform3D(base.basis.scaled(Vector3.ONE * ESCALA),
			base * Vector3(columna * 0.09, fila * 0.09, -2.0))


func _agregar(nodo: Node3D) -> void:
	add_child(nodo)
	_muestras.append(nodo)
	for hijo in nodo.find_children("*", "", true, false):
		if hijo is CPUParticles3D:
			(hijo as CPUParticles3D).emitting = true
		if hijo is Node3D and not (hijo as Node3D).visible:
			(hijo as Node3D).visible = true


## Copia cada geometría oculta (solo lo dibujable: malla, material y sombra), sin scripts ni señales.
func _copiar_ocultos(raiz: Node) -> void:
	var pila: Array[Node] = [raiz]
	while not pila.is_empty():
		var nodo: Node = pila.pop_back()
		if nodo is SubViewport or nodo == self:
			continue  # el taller tiene su propio mundo
		if nodo is GeometryInstance3D and not (nodo as Node3D).is_visible_in_tree():
			var firma := _firma(nodo as GeometryInstance3D)
			if _vistas.has(firma):
				continue  # mismo tipo de nodo y mismos materiales: su sombreador ya está en la muestra
			_vistas[firma] = true
			var copia := nodo.duplicate(0) as Node3D
			for hijo in copia.get_children():
				hijo.free()
			_agregar(copia)
			continue
		pila.append_array(nodo.get_children())


## Clase del nodo más sus materiales: dos piezas con la misma firma usan los mismos sombreadores.
static func _firma(g: GeometryInstance3D) -> String:
	var partes: Array = [g.get_class(), g.material_override.get_instance_id() if g.material_override else 0]
	if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
		var mi := g as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(i)
			if m == null:
				m = mi.mesh.surface_get_material(i)
			partes.append(m.get_instance_id() if m else 0)
	return str(partes)
