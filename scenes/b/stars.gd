extends Control
## Tres estrellas llenas/vacías con su recuento escrito (el estado nunca depende solo de la forma o el color).
const UI := preload("res://scenes/b/ui_style.gd")
var stars := 0


func _ready() -> void:
	custom_minimum_size = Vector2(368, 48)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for j in range(3):
		var points := PackedVector2Array()
		for i in range(10):
			var angle := i * PI / 5.0 - PI / 2.0
			points.append(Vector2(24 + j * 54, 24) + Vector2(cos(angle), sin(angle)) * (21.0 if i % 2 == 0 else 9.0))
		draw_colored_polygon(points, UI.AMBER if j < stars else Color(UI.CREAM, 0.16))
	var fuente := ThemeDB.fallback_font
	draw_string(fuente, Vector2(184, 31), tr("STARS_COUNT") % stars, HORIZONTAL_ALIGNMENT_LEFT, -1.0, UI.FONT_TEXT, UI.CREAM)
