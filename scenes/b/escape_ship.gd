class_name EscapeShip
extends RefCounted
## Nave de fuga por módulos, inspirada en el SLS y la Orión de la NASA (núcleo naranja, dos propulsores blancos, cápsula con
## módulo de servicio y alas solares, torre de aborto) sobre una plataforma con torre de servicio. Cada módulo es un nodo
## («Modulo1»…«Modulo4») con su origen en su base y todas sus piezas fundidas en una sola malla, así que el que está en obra
## puede crecer escalando en Y. Provisional hasta tener el modelo del equipo.
##   1 Plataforma y motores · 2 Tanque y propulsores · 3 Cápsula de tripulación · 4 Torre de escape y carenado
const Art := preload("res://scenes/b/art.gd")
const MODULOS := 4
## Altura de la base de cada módulo sobre la plataforma (m).
const BASES: Array[float] = [0.0, 0.9, 5.3, 8.05]
const ESCALA := 0.8  ## el modelo se dibuja a esta escala para que quepa en pantalla
const ALTURA_TOTAL := 9.9 * ESCALA
const NARANJA := Color("D9772F")
const NARANJA_OSC := Color("B35B20")
const BLANCO := Color("EEE9E0")
const CREMA := Color("F2E9D4")
const NEGRO := Color("2A2725")
const GRIS_OSC := Color("3F3A36")
const GRIS := Color("8C8F94")
const HORMIGON := Color("6A645E")
const CORAL := Color("E8806A")
const AMBAR := Color("F0C079")
const TURQUESA := Color("9AD7C6")


## Construye los módulos pedidos: los terminados (1..nivel) y, con «en_obra», el siguiente (nivel + 1).
static func construir(raiz: Node3D, nivel: int, en_obra: bool) -> void:
	var hasta := clampi(nivel + (1 if en_obra else 0), 0, MODULOS)
	var cuerpo := Node3D.new()
	cuerpo.name = "Cuerpo"
	cuerpo.scale = Vector3.ONE * ESCALA
	raiz.add_child(cuerpo)
	raiz = cuerpo
	for n in range(1, hasta + 1):
		var modulo := Node3D.new()
		modulo.name = "Modulo%d" % n
		modulo.position = Vector3(0.0, BASES[n - 1], 0.0)
		raiz.add_child(modulo)
		match n:
			1:
				_plataforma_y_motores(modulo)
			2:
				_tanque_y_propulsores(modulo)
			3:
				_capsula(modulo)
			4:
				_torre_de_escape(modulo)
		Art.merged(modulo)
	if nivel >= 2:
		_brazo(raiz, 4.6, GRIS)  # los brazos de la torre llegan a los módulos que ya existen
	if nivel >= 3:
		_brazo(raiz, 7.2, GRIS)


## Escala el módulo en obra según el avance (0..1): crece desde su base.
static func animar_obra(raiz: Node3D, nivel: int, progreso: float) -> void:
	var modulo := raiz.get_node_or_null("Cuerpo/Modulo%d" % (nivel + 1)) as Node3D
	if modulo != null:
		var avance := clampf(progreso, 0.0, 1.0)
		modulo.scale = Vector3(lerpf(0.55, 1.0, avance), lerpf(0.08, 1.0, avance), lerpf(0.55, 1.0, avance))


static func _cil(p: Node3D, radio: float, alto: float, y: float, color: Color, arriba: float = -1.0, seg: int = 16, x: float = 0.0, z: float = 0.0) -> MeshInstance3D:
	return Art.cylinder(p, radio, alto, Vector3(x, y + alto / 2.0, z), color, arriba, seg)


static func _plataforma_y_motores(m: Node3D) -> void:
	_cil(m, 2.2, 0.2, 0.0, HORMIGON, -1.0, 22)
	_cil(m, 1.15, 0.24, 0.0, NEGRO, -1.0, 18)  # zona de escape de gases
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Art.box(m, Vector3(0.26, 0.5, 0.26), Vector3(sx * 0.62, 0.45, sz * 0.62), GRIS)  # anclajes
	_cil(m, 0.66, 0.7, 0.2, GRIS_OSC, 0.72, 16)  # falda de motores
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cil(m, 0.2, 0.55, 0.28, Color("5B5651"), 0.11, 10, sx * 0.24, sz * 0.24)  # toberas
			_cil(m, 0.14, 0.04, 0.28, Color("1B1917"), -1.0, 8, sx * 0.24, sz * 0.24)
	# Torre de servicio: cuatro montantes, travesaños y diagonales.
	var cx := 1.85
	var lado := 0.34
	var alto := 8.6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Art.rod(m, Vector3(cx + sx * lado, 0.2, sz * lado), Vector3(cx + sx * lado, alto, sz * lado), 0.05, GRIS)
	var niveles := 7
	for i in range(1, niveles + 1):
		var y := 0.2 + (alto - 0.2) * float(i) / float(niveles)
		var y0 := 0.2 + (alto - 0.2) * float(i - 1) / float(niveles)
		for par in [[Vector3(-1, 0, -1), Vector3(1, 0, -1)], [Vector3(1, 0, -1), Vector3(1, 0, 1)], [Vector3(1, 0, 1), Vector3(-1, 0, 1)], [Vector3(-1, 0, 1), Vector3(-1, 0, -1)]]:
			var a: Vector3 = par[0]
			var b: Vector3 = par[1]
			Art.rod(m, Vector3(cx + a.x * lado, y, a.z * lado), Vector3(cx + b.x * lado, y, b.z * lado), 0.03, GRIS)
		Art.rod(m, Vector3(cx - lado, y0, -lado), Vector3(cx + lado, y, -lado), 0.025, GRIS)
		Art.rod(m, Vector3(cx + lado, y0, lado), Vector3(cx - lado, y, lado), 0.025, GRIS)
	Art.box(m, Vector3(0.9, 0.18, 0.9), Vector3(cx, alto + 0.1, 0.0), GRIS_OSC)
	Art.ball(m, 0.09, Vector3(cx, alto + 0.28, 0.0), CORAL)  # baliza


static func _tanque_y_propulsores(m: Node3D) -> void:
	_cil(m, 0.72, 4.4, 0.0, NARANJA, -1.0, 20)  # núcleo (espuma aislante naranja)
	_cil(m, 0.77, 0.22, 0.0, GRIS_OSC, -1.0, 20)
	for y in [1.0, 2.5, 3.7]:
		_cil(m, 0.735, 0.12, y, NARANJA_OSC, -1.0, 20)
	_cil(m, 0.745, 0.14, 4.26, BLANCO, -1.0, 20)
	_cil(m, 0.74, 0.07, 3.0, CORAL, -1.0, 20)  # franja de GAIA
	for sx in [-1.0, 1.0]:
		var x: float = sx * 1.16
		_cil(m, 0.34, 3.6, -0.2, BLANCO, -1.0, 14, x)  # propulsor
		_cil(m, 0.34, 0.95, 3.4, NEGRO, 0.0, 14, x)  # ojiva
		for y in [1.2, 2.3]:
			_cil(m, 0.352, 0.14, y, NEGRO, -1.0, 14, x)
		_cil(m, 0.352, 0.09, 2.9, CORAL, -1.0, 14, x)
		_cil(m, 0.3, 0.38, -0.55, GRIS_OSC, 0.2, 12, x)  # tobera
		for y in [0.9, 3.0]:
			Art.rod(m, Vector3(sx * 0.7, y, 0.0), Vector3(sx * 0.9, y, 0.0), 0.06, GRIS)  # puntales


static func _capsula(m: Node3D) -> void:
	_cil(m, 0.72, 0.5, 0.0, BLANCO, 0.5, 20)  # interetapa
	_cil(m, 0.5, 0.8, 0.5, CREMA, -1.0, 16)  # etapa superior
	_cil(m, 0.512, 0.08, 1.0, NEGRO, -1.0, 16)
	_cil(m, 0.46, 0.6, 1.3, GRIS_OSC, -1.0, 16)  # módulo de servicio
	_cil(m, 0.47, 0.07, 1.5, AMBAR, -1.0, 16)
	for i in 4:
		var angulo := TAU * float(i) / 4.0 + PI / 4.0
		var ala := Art.panel(m, Vector3(0.95, 0.04, 0.34), Vector3(sin(angulo) * 0.98, 1.62, cos(angulo) * 0.98), 2, 4)
		ala.rotation.y = angulo - PI / 2.0
		Art.rod(m, Vector3(sin(angulo) * 0.46, 1.62, cos(angulo) * 0.46), Vector3(sin(angulo) * 0.55, 1.62, cos(angulo) * 0.55), 0.03, GRIS)
	_cil(m, 0.46, 0.75, 1.9, BLANCO, 0.24, 16)  # cápsula de tripulación
	Art.ball(m, 0.075, Vector3(0.0, 2.3, 0.32), TURQUESA)  # ventanilla


static func _torre_de_escape(m: Node3D) -> void:
	_cil(m, 0.26, 0.15, 0.0, GRIS_OSC, 0.2, 12)
	_cil(m, 0.2, 0.7, 0.15, BLANCO, -1.0, 12)  # motores de aborto
	_cil(m, 0.208, 0.08, 0.45, NEGRO, -1.0, 12)
	for i in 3:
		var a := TAU * float(i) / 3.0
		Art.rod(m, Vector3(sin(a) * 0.2, 0.8, cos(a) * 0.2), Vector3(sin(a) * 0.05, 1.45, cos(a) * 0.05), 0.025, GRIS)  # celosía de la torre
	_cil(m, 0.24, 0.55, 0.85, BLANCO, 0.05, 12)  # carenado
	Art.rod(m, Vector3(0.0, 1.4, 0.0), Vector3(0.0, 1.85, 0.0), 0.022, GRIS)
	Art.ball(m, 0.05, Vector3(0.0, 1.88, 0.0), CORAL)


## Brazo de la torre de servicio hasta el núcleo, a la altura «y».
static func _brazo(raiz: Node3D, y: float, color: Color) -> void:
	var grupo := Node3D.new()
	grupo.name = "Brazo"
	raiz.add_child(grupo)
	Art.rod(grupo, Vector3(1.55, y, 0.0), Vector3(0.75, y + 0.05, 0.0), 0.05, color)
	Art.rod(grupo, Vector3(1.55, y + 0.25, 0.0), Vector3(0.75, y + 0.05, 0.0), 0.03, color)
	Art.box(grupo, Vector3(0.16, 0.16, 0.3), Vector3(0.72, y + 0.05, 0.0), CORAL)
	Art.merged(grupo)
