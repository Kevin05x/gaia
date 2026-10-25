class_name ShaderWarmup
extends Node3D
## Precalentado de sombreadores. En la web (WebGL) cada material nuevo se compila la primera vez que se dibuja, y eso
## congela la imagen un momento: la primera obra, la primera extracción, la primera explosión o la primera oleada se
## «trababan». Al empezar la misión, detrás de una cortina oscura que se desvanece, se dibuja durante unos cuadros una
## muestra de todo lo que aún no está a la vista (edificios terminados y en obra, monstruos, efectos guardados en reserva,
## partículas del taladro…), con y sin sombras del sol. Después se borra. No cambia nada de cómo se ve el juego.
signal terminado

const CUADROS := 4  ## cuadros con la muestra a la vista (2 con sombras del sol y 2 sin ellas)
const ESCALA := 0.06  ## la muestra es diminuta y está tapada por la cortina: el jugador no la ve

var camara: Camera3D
var sol: DirectionalLight3D
var _cuadro := -1
var _muestras: Array[Node3D] = []
var _sombras_antes := true


## «raices»: nodos cuya geometría oculta se copia (reservas de efectos). «extra»: muestras ya hechas (fuera del árbol).
func empezar(raices: Array, extra: Array) -> void:
	for raiz in raices:
		if raiz is Node:
			_copiar_ocultos(raiz as Node)
	for nodo in extra:
		if nodo is Node3D:
			_agregar(nodo as Node3D)
	_cuadro = 0
	if sol != null:
		_sombras_antes = sol.shadow_enabled
		sol.shadow_enabled = true
	_colocar()


func activo() -> bool:
	return _cuadro >= 0


func cantidad() -> int:
	return _muestras.size()


func _process(_delta: float) -> void:
	if _cuadro < 0:
		return
	_cuadro += 1
	_colocar()
	if sol != null and _cuadro == CUADROS / 2:
		sol.shadow_enabled = false  # la variante sin sombras (noche, tormenta) también queda compilada
	if _cuadro >= CUADROS:
		if sol != null:
			sol.shadow_enabled = _sombras_antes
		for m in _muestras:
			m.queue_free()
		_muestras.clear()
		_cuadro = -1
		terminado.emit()


## Las muestras se ponen en fila justo delante de la cámara (dentro de su vista, si no, no se dibujarían).
func _colocar() -> void:
	if camara == null or not camara.is_inside_tree():
		return
	var base := camara.global_transform
	var n := _muestras.size()
	for i in n:
		var columna := float(i % 12) - 5.5
		var fila := float(i / 12) - 2.0
		_muestras[i].global_transform = Transform3D(base.basis.scaled(Vector3.ONE * ESCALA),
			base * Vector3(columna * 0.09, fila * 0.09, -2.0))


func _agregar(nodo: Node3D) -> void:
	add_child(nodo)
	nodo.visible = true
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
			var copia := nodo.duplicate(0) as Node3D
			for hijo in copia.get_children():
				hijo.free()
			_agregar(copia)
			continue
		pila.append_array(nodo.get_children())
