class_name Escala
extends RefCounted
## Escala única del mundo 3D: 1 unidad = 1 metro REAL. Todo lo que se dibuja se mide contra estas cifras para que nada
## quede desproporcionado (antes el rover era más alto que los hangares y que la antena).
##  · Una casilla del mapa mide 4 m × 4 m: cabe el rover real (3,0 × 2,7 m) con holgura y un módulo de base de ≈4 m.
##  · El rover es el Perseverance de la NASA a escala 1:1 (3,0 m de largo, 2,7 m de ancho con ruedas, mástil a 2,2 m).
##  · El helicóptero es el Ingenuity real (1,2 m de rotor a rotor, 0,5 m de alto).
##  · Una persona mide 1,8 m (referencia para juzgar edificios y puertas).
const TILE := 4.0  ## metros por casilla
const PERSONA := 1.8
const ROVER_LARGO := 3.0
const ROVER_ANCHO := 2.7
const ROVER_ALTO := 2.2
const INGENUITY_ROTOR := 1.2  ## m, de punta a punta de las hélices
## Alturas de referencia de la base (m): un módulo debe ser claramente más alto que el rover para poder guardarlo.
const ALTURA_MODULO_MIN := 2.6


## Casilla -> posición en el mundo (sin altura).
static func a_mundo(casilla: Vector2i) -> Vector3:
	return Vector3(casilla.x * TILE, 0.0, casilla.y * TILE)


## Punto del mundo -> casilla más cercana.
static func a_casilla(punto: Vector3) -> Vector2i:
	return Vector2i(roundi(punto.x / TILE), roundi(punto.z / TILE))
