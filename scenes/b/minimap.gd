extends Control
## Mapa de la misión: terreno marrón con cuadrícula, rocas, objetivos revelados, estación y rover con su rumbo.
## Al pasar el cursor resalta la casilla y muestra sus coordenadas; un clic pide mover el rover a esa casilla
## (la simulación decide si es válida).
const UI := preload("res://scenes/b/ui_style.gd")
const NONE := Vector2i(-9999, -9999)
signal tile_chosen(tile: Vector2i)
var state: Dictionary = {}:
	set(v):
		state = v
		var t: Vector2i = v.get("rover_tile", Vector2i.ZERO)
		if _last_rover != NONE and t != _last_rover:
			_heading = Vector2(t - _last_rover).normalized()
		_last_rover = t
var _hover := false
var _hover_tile := NONE
var _heading := Vector2(0, -1)
var _last_rover := NONE
var _estatica: ImageTexture
var _estatica_firma := ""
const ZONE_TONES := {"orilla": Color("E2C9A3"), "falla": Color("9FC0D2"), "nucleo": Color("3E2C28")}


func _ready() -> void:
	custom_minimum_size = Vector2(168, 168)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; _hover_tile = NONE; queue_redraw())
	tooltip_text = tr("MAP")


func _limits() -> Array:
	var b: Dictionary = state.get("bounds", {})
	return [b.get("min", Vector2i(-11, -11)), b.get("max", Vector2i(11, 11))]


func _draw() -> void:
	draw_style_box(UI.box(UI.ALPHA_STRONG if _hover else 0.5, UI.RADIUS_PANEL, 0.45 if _hover else 0.28), Rect2(Vector2.ZERO, size))
	var lim := _limits()
	var mn: Vector2i = lim[0]
	var mx: Vector2i = lim[1]
	var celda := _cell()
	var area := Rect2(point(mn) - celda / 2.0, point(mx) - point(mn) + celda)
	# Terreno, zonas, cuadrícula (una línea cada 5 casillas) y rocas: una textura que solo se rehace al cambiar el mapa.
	var terreno := StyleBoxFlat.new()
	terreno.bg_color = Color("9a5f43", 0.86)
	terreno.set_corner_radius_all(6)
	terreno.set_border_width_all(1)
	terreno.border_color = Color(UI.CREAM, 0.22)
	terreno.anti_aliasing = true
	draw_style_box(terreno, area)
	_capa_estatica(mn, mx)
	draw_texture_rect(_estatica, area, false)
	# Casilla bajo el cursor.
	if _hover and _hover_tile != NONE and _inside(_hover_tile):
		var caja := Rect2(point(_hover_tile) - celda / 2.0, celda)
		draw_rect(caja, Color(UI.AMBER, 0.32))
		draw_rect(caja, Color(UI.AMBER, 0.9), false, 1.2)
	# Objetivos revelados: rombo con aro.
	for t in state.get("targets", []):
		if not t.get("revealed", false):
			continue
		var p := point(t.get("tile", Vector2i.ZERO))
		var agotado: bool = t.get("depleted", false)
		var tono := Color(UI.CREAM, 0.4) if agotado else UI.TARGET_LIGHT
		if not agotado:
			draw_arc(p, 6.6, 0.0, TAU, 24, Color(UI.TARGET_LIGHT, 0.55), 1.2, true)
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4.2), p + Vector2(4.2, 0), p + Vector2(0, 4.2), p + Vector2(-4.2, 0)]), Color(UI.SURFACE, 0.9))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -3.2), p + Vector2(3.2, 0), p + Vector2(0, 3.2), p + Vector2(-3.2, 0)]), tono)
	# Estación: casita con tejado.
	var e := point(state.get("station_tile", Vector2i(-9, -9)))
	draw_colored_polygon(PackedVector2Array([e + Vector2(-6.5, -0.5), e + Vector2(0, -6.5), e + Vector2(6.5, -0.5)]), Color(UI.SURFACE, 0.95))
	draw_rect(Rect2(e + Vector2(-5.5, -1), Vector2(11, 7.5)), Color(UI.SURFACE, 0.95))
	draw_colored_polygon(PackedVector2Array([e + Vector2(-5, -1.2), e + Vector2(0, -5.4), e + Vector2(5, -1.2)]), UI.AMBER)
	draw_rect(Rect2(e + Vector2(-4, -0.4), Vector2(8, 6)), Color("f6dfb0"))
	draw_rect(Rect2(e + Vector2(-1.2, 2.2), Vector2(2.4, 3.4)), Color(UI.SURFACE, 0.9))
	# Rover: flecha con su rumbo y un halo.
	var r := point(state.get("rover_tile", Vector2i.ZERO))
	var lado := Vector2(-_heading.y, _heading.x)
	draw_circle(r, 8.5, Color(UI.CREAM, 0.16))
	var punta := r + _heading * 7.2
	var ala_a := r - _heading * 3.6 + lado * 4.6
	var ala_b := r - _heading * 3.6 - lado * 4.6
	var cola := r - _heading * 1.6
	draw_colored_polygon(PackedVector2Array([r + _heading * 8.6, r - _heading * 4.9 + lado * 5.8, r - _heading * 2.4, r - _heading * 4.9 - lado * 5.8]), Color(UI.SURFACE, 0.95))
	draw_colored_polygon(PackedVector2Array([punta, ala_a, cola, ala_b]), UI.CREAM)
	# Esquinas de marco y coordenadas.
	var largo := 6.0
	for esquina in [[area.position, Vector2(1, 1)], [Vector2(area.end.x, area.position.y), Vector2(-1, 1)],
			[Vector2(area.position.x, area.end.y), Vector2(1, -1)], [area.end, Vector2(-1, -1)]]:
		var o: Vector2 = esquina[0]
		var d: Vector2 = esquina[1]
		draw_line(o, o + Vector2(largo * d.x, 0), Color(UI.CREAM, 0.6), 1.5)
		draw_line(o, o + Vector2(0, largo * d.y), Color(UI.CREAM, 0.6), 1.5)
	var zona := str(state.get("rover_zone", ""))
	if zona != "":
		var fz := UI.display_font(600)
		var nombre := tr("ZONE_" + zona.to_upper())
		var ancho_z := fz.get_string_size(nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var origen_z := Vector2(area.position.x + 5, area.position.y + 15)
		draw_rect(Rect2(origen_z + Vector2(-3, -12), Vector2(ancho_z + 6, 15)), Color(UI.SURFACE, 0.72))
		draw_string(fz, origen_z, nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.CREAM)
	if _hover and _hover_tile != NONE and _inside(_hover_tile):
		var f := UI.display_font(600)
		var texto := "%d, %d" % [_hover_tile.x, _hover_tile.y]
		var ancho := f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var origen := Vector2(area.position.x + 5, area.end.y - 5)
		draw_rect(Rect2(origen + Vector2(-3, -13), Vector2(ancho + 6, 16)), Color(UI.SURFACE, 0.78))
		draw_string(f, origen, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.CREAM)


## Capa fija del mapa (zonas, cuadrícula y rocas) como imagen: con 200 rocas, dibujarlas una a una costaba cientos de llamadas por cuadro.
func _capa_estatica(mn: Vector2i, mx: Vector2i) -> void:
	var obstaculos: Array = state.get("obstacles", [])
	var zonas: Array = state.get("zones", [])
	var firma := "%s|%s|%d|%s" % [mn, mx, obstaculos.size(), var_to_str(zonas)]
	if _estatica != null and firma == _estatica_firma:
		return
	_estatica_firma = firma
	var cuenta: Vector2i = mx - mn + Vector2i.ONE
	var esc := clampi(ceili(220.0 / maxi(cuenta.x, cuenta.y)), 2, 10)
	var img := Image.create(cuenta.x * esc, cuenta.y * esc, false, Image.FORMAT_RGBA8)
	if not zonas.is_empty():
		for ty in range(cuenta.y):
			for tx in range(cuenta.x):
				var tile := Vector2(tx + mn.x, ty + mn.y)
				var mejor := INF
				var tono := Color(0, 0, 0, 0)
				for z in zonas:
					var d := tile.distance_squared_to(Vector2(z["center"]))
					if d < mejor:
						mejor = d
						tono = ZONE_TONES.get(str(z["id"]), Color(0, 0, 0, 0))
				if tono.a > 0.0:
					tono.a = 0.3
					img.fill_rect(Rect2i(tx * esc, ty * esc, esc, esc), tono)
	var raya := Color(UI.CREAM, 0.16)
	for x in range(1, cuenta.x):
		if x % 5 == 0:
			for py in range(img.get_height()):
				img.set_pixel(x * esc, py, img.get_pixel(x * esc, py).blend(raya))
	for y in range(1, cuenta.y):
		if y % 5 == 0:
			for px in range(img.get_width()):
				img.set_pixel(px, y * esc, img.get_pixel(px, y * esc).blend(raya))
	var radio := esc * 0.46
	for t in obstaculos:
		var origen := Vector2((t.x - mn.x) * esc, (t.y - mn.y) * esc)
		var centro := origen + Vector2(esc, esc) / 2.0
		for py in range(esc):
			for px in range(esc):
				var p := origen + Vector2(px + 0.5, py + 0.5)
				var x := int(origen.x) + px
				var y := int(origen.y) + py
				if p.distance_to(centro) <= radio:
					img.set_pixel(x, y, img.get_pixel(x, y).blend(Color("2f1d13", 0.85)))
				if p.distance_to(centro + Vector2(-radio * 0.2, -radio * 0.2)) <= radio * 0.62:
					img.set_pixel(x, y, img.get_pixel(x, y).blend(Color("5d3f2b", 0.95)))
	_estatica = ImageTexture.create_from_image(img)


func _inside(t: Vector2i) -> bool:
	var lim := _limits()
	var mn: Vector2i = lim[0]
	var mx: Vector2i = lim[1]
	return t.x >= mn.x and t.x <= mx.x and t.y >= mn.y and t.y <= mx.y


func _cell() -> Vector2:
	var lim := _limits()
	var cuenta: Vector2i = lim[1] - lim[0] + Vector2i.ONE
	var util := size - Vector2(16, 16)
	return Vector2(util.x / cuenta.x, util.y / cuenta.y)


func point(tile: Vector2i) -> Vector2:
	var mn: Vector2i = _limits()[0]
	var c := _cell()
	return Vector2(8, 8) + Vector2((tile.x - mn.x + 0.5) * c.x, (tile.y - mn.y + 0.5) * c.y)


func tile_at(pos: Vector2) -> Vector2i:
	var mn: Vector2i = _limits()[0]
	var c := _cell()
	return Vector2i(floori((pos.x - 8) / c.x) + mn.x, floori((pos.y - 8) / c.y) + mn.y)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var t := tile_at(e.position)
		if t != _hover_tile:
			_hover_tile = t
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		tile_chosen.emit(tile_at(e.position))
		accept_event()
