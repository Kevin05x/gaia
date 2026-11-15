extends SceneTree
## Herramienta de desarrollo: cuánto tarda en aparecer la misión desde que se pulsa «Comenzar misión» (escena game.tscn), cuadro a cuadro.
## Imprime los cuadros más largos. Sirve para cazar lo que congela la web (donde el código va varias veces más lento).
## Uso (necesita GPU):  godot --rendering-driver opengl3 -s tools/medir_arranque.gd
const Sesion := preload("res://scenes/menu/game_session.gd")
var _ultimo := 0
var _largos: Array = []
var _cuadro := 0


func _initialize() -> void:
	Sesion.destino = "marte"
	var t0 := Time.get_ticks_msec()
	var escena := load("res://scenes/a/game.tscn") as PackedScene
	print("ARRANQUE load game.tscn: %d ms" % (Time.get_ticks_msec() - t0))
	var t1 := Time.get_ticks_msec()
	var nodo := escena.instantiate()
	print("ARRANQUE instantiate: %d ms" % (Time.get_ticks_msec() - t1))
	var t2 := Time.get_ticks_msec()
	root.add_child(nodo)
	print("ARRANQUE add_child (_ready de todo): %d ms" % (Time.get_ticks_msec() - t2))
	_ultimo = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	var ahora := Time.get_ticks_msec()
	var d := ahora - _ultimo
	_ultimo = ahora
	_cuadro += 1
	if d > 120:
		_largos.append("cuadro %d: %d ms (a los %d ms)" % [_cuadro, d, ahora])
	if _cuadro == 900:
		for l in _largos:
			print("ARRANQUE ", l)
		print("ARRANQUE total cuadros %d" % _cuadro)
		quit()
	return false
