extends Control
## Escena mínima para mirar el logo 3D (solo pruebas).
const Logo := preload("res://scenes/menu/gaia_logo.gd")
func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.color = Color("0d0a10")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var logo := Logo.new()
	logo.set_anchors_preset(Control.PRESET_CENTER)
	logo.offset_left = -480
	logo.offset_right = 480
	logo.offset_top = -190
	logo.offset_bottom = 190
	add_child(logo)
	logo.mostrar_final()
