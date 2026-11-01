class_name CalidadDinamica
extends Node
## Calidad automática. Se empieza con bordes suavizados (MSAA 2x: sin «dientes de sierra» en rocas y crestas lejanas)
## y resolución completa. Si durante unos segundos el juego va lento (gráficos integrados en el navegador), primero se
## quita el suavizado y, solo si sigue lento, el mundo 3D baja un poco de resolución (nunca de 0,8: más abajo se ve
## pixelado). La interfaz y los textos siempre van nítidos. Solo mide cuando se está jugando.
const NIVELES: Array = [[Viewport.MSAA_2X, 1.0], [Viewport.MSAA_DISABLED, 1.0], [Viewport.MSAA_DISABLED, 0.9],
	[Viewport.MSAA_DISABLED, 0.8]]
const VENTANA_S := 2.5  ## segundos de cada medición
const LENTO_MS := 24.0  ## por encima de esto (menos de ~42 cuadros/s) se baja un escalón
const SOBRADO_MS := 12.0  ## por debajo (más de ~80 cuadros/s) se puede subir un escalón
const ESPERA_SUBIR_S := 20.0

var activa := true
var medir: Callable  ## devuelve true si ahora se está jugando (si no, no se mide)
## Últimos recursos si aun así va lento: recibe 0 (todo como eligió el jugador), 1 (sin brillo ni postproceso) o 2 (además
## sin sombras). No toca lo guardado: solo esta partida.
var al_recortar: Callable
var _nivel := 0
var _niveles: Array = NIVELES  ## escalones según lo que eligió el jugador (configurar)
var _t := 0.0
var _cuadros := 0
var _desde_cambio := 0.0


func nivel() -> int:
	return _nivel


func escala() -> float:
	return _niveles[_nivel][1]


## Parte de lo que eligió el jugador (suavizado y resolución) y, si «auto», solo puede bajar desde ahí: primero quita el
## suavizado y luego baja la resolución hasta 0,8 como mucho.
func configurar(msaa: Viewport.MSAA, resolucion: float, auto: bool, con_post: bool = false, con_sombras: bool = false) -> void:
	_niveles = [[msaa, resolucion, 0]]
	if msaa != Viewport.MSAA_DISABLED:
		_niveles.append([Viewport.MSAA_DISABLED, resolucion, 0])
	var ultima := resolucion
	for e in [0.9, 0.8]:
		if e < resolucion - 0.01:
			_niveles.append([Viewport.MSAA_DISABLED, e, 0])
			ultima = e
	if con_post:
		_niveles.append([Viewport.MSAA_DISABLED, ultima, 1])
	if con_sombras:
		_niveles.append([Viewport.MSAA_DISABLED, ultima, 2])
	activa = auto
	_t = 0.0
	_cuadros = 0
	_fijar(0)


func _ready() -> void:
	_fijar(0)


func _process(delta: float) -> void:
	_desde_cambio += delta
	if not activa or (medir.is_valid() and not medir.call()) or delta > 0.5:
		_t = 0.0
		_cuadros = 0
		return
	_t += delta
	_cuadros += 1
	if _t < VENTANA_S:
		return
	var ms := _t / maxf(_cuadros, 1) * 1000.0
	_t = 0.0
	_cuadros = 0
	if ms > LENTO_MS and _nivel < _niveles.size() - 1:
		_fijar(_nivel + 1)
	elif ms < SOBRADO_MS and _nivel > 0 and _desde_cambio > ESPERA_SUBIR_S:
		_fijar(_nivel - 1)


func _fijar(n: int) -> void:
	_nivel = n
	_desde_cambio = 0.0
	var vp := get_viewport()
	if vp != null:
		vp.msaa_3d = _niveles[n][0]
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = _niveles[n][1]
	var recorte: int = _niveles[n][2] if (_niveles[n] as Array).size() > 2 else 0
	if al_recortar.is_valid():
		al_recortar.call(recorte)
