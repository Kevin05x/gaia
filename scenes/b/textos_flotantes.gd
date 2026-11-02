class_name TextosFlotantes
extends Node3D
## Textos que suben y se desvanecen sobre el mundo («+3 Olivino» al recoger, al descargar en la base…). Un puñado de
## Label3D reutilizados: no crea nodos durante la partida y solo procesa mientras alguno está visible.
const MAX := 10
const DURACION := 1.5
const SUBIDA := 1.4
const SOBRE_PX := 70.0  ## arranca por encima del menú de acciones que sale junto al rover (en píxeles del texto)
const FILA_PX := 34.0  ## separación entre textos que salen a la vez del mismo sitio

var _textos: Array = []  ## {"node", "t", "base", "fila"}


func _ready() -> void:
	for i in MAX:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0012
		l.font_size = 24
		l.outline_size = 9
		l.outline_modulate = Color(0.1, 0.07, 0.05, 0.85)
		l.render_priority = 12
		l.outline_render_priority = 11
		l.visible = false
		add_child(l)
		_textos.append({"node": l, "t": DURACION, "base": Vector3.ZERO, "fila": 0})
	set_process(false)


## Muestra «texto» sobre «pos». Si ya hay otros en el mismo sitio, este toma la fila libre de más arriba (no se tapan
## aunque salgan juntos) y espera un poco su turno para que se lean de uno en uno.
func mostrar(pos: Vector3, texto: String, color: Color) -> void:
	var elegido: Dictionary = _textos[0]
	var espera := 0.0
	var ocupadas: Dictionary = {}
	for t in _textos:
		if float(t["t"]) > float(elegido["t"]):
			elegido = t
		if float(t["t"]) < DURACION and (t["base"] as Vector3).distance_to(pos) < 1.5:
			ocupadas[int(t["fila"])] = true
			if float(t["t"]) < 0.3:
				espera = maxf(espera, 0.3 - float(t["t"]))
	var fila := 0
	while ocupadas.has(fila):
		fila += 1
	elegido["t"] = -espera
	elegido["base"] = pos
	elegido["fila"] = fila
	var l: Label3D = elegido["node"]
	l.text = texto
	l.modulate = Color(color, 0.0)
	l.position = pos
	l.offset = Vector2(0, SOBRE_PX + FILA_PX * fila)
	l.visible = true
	set_process(true)


func activos() -> int:
	var n := 0
	for t in _textos:
		if float(t["t"]) < DURACION:
			n += 1
	return n


func _process(delta: float) -> void:
	var quedan := 0
	for t in _textos:
		var tiempo := float(t["t"])
		if tiempo >= DURACION:
			continue
		tiempo += delta
		t["t"] = tiempo
		var l: Label3D = t["node"]
		if tiempo < 0.0:
			quedan += 1
			continue  # aún esperando su turno
		if tiempo >= DURACION:
			l.visible = false
			continue
		quedan += 1
		var k := tiempo / DURACION
		var sube := 1.0 - pow(1.0 - k, 3.0)  # sale rápido y frena
		l.position = (t["base"] as Vector3) + Vector3(0, SUBIDA * sube, 0)
		var pop := 1.0 + 0.35 * maxf(0.0, 1.0 - tiempo / 0.18)  # aparece con un pequeño salto
		l.scale = Vector3.ONE * pop
		l.modulate.a = clampf(tiempo / 0.08, 0.0, 1.0) * clampf((1.0 - k) / 0.35, 0.0, 1.0)
		l.outline_modulate.a = l.modulate.a * 0.85
	if quedan == 0:
		set_process(false)
