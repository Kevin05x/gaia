extends CanvasLayer
## Secuencia de lanzamiento y crucero entre el taller y el aterrizaje (se puede saltar con clic, Espacio o Esc).
##  1. Lanzamiento: el cohete elegido (ligero o pesado, con o sin propulsores laterales) despega con su carga.
##  2. Crucero: vista orbital Sol–Tierra–Marte con la trayectoria elegida. La nave sigue una cónica de transferencia
##     (mínima energía ≈ 180° alrededor del Sol; rápida ≈ 135°, más excéntrica) y Marte llega al punto de encuentro
##     a la vez. Contador de días, maniobras de corrección y llegada.
## Las órbitas están a escala de distancias (1 UA y 1,524 UA) y los planetas avanzan con su periodo real
## (365,25 y 687 días); la transferencia es una cónica simplificada para enseñar la idea, no una efeméride.

const UI := preload("res://scenes/b/ui_style.gd")
const NasaData := preload("res://scenes/b/nasa_data.gd")
const DURACION_LANZAMIENTO := 4.6
const DURACION_CRUCERO := 9.5
const DURACION_LLEGADA := 1.6

signal finished

var taller: Dictionary = {}
var _t := 0.0
var _activa := false
var _raiz: Control
var _lanzamiento: LaunchView
var _orbita: OrbitView
var _titulo: Label
var _texto: Label
var _dato: Label
var _saltar: Button
var _velo: ColorRect


func _ready() -> void:
	layer = 9
	visible = false


## Empieza la secuencia con el diseño del taller (selection, totals, categories).
func play(diseno: Dictionary) -> void:
	taller = diseno
	_t = 0.0
	_activa = true
	visible = true
	_construir()


func _construir() -> void:
	if is_instance_valid(_raiz):
		_raiz.queue_free()
	_raiz = Control.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.theme = UI.theme()
	_raiz.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _t > 0.6:
			_terminar())
	add_child(_raiz)
	var sel: Dictionary = taller.get("selection", {})
	var totales: Dictionary = taller.get("totals", {})
	_lanzamiento = LaunchView.new()
	_lanzamiento.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lanzamiento.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lanzamiento.pesado = (sel.get("cohetes", []) as Array).has("cohete_pesado")
	_raiz.add_child(_lanzamiento)
	_orbita = OrbitView.new()
	_orbita.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orbita.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orbita.rapida = (sel.get("trayectoria", []) as Array).has("trayectoria_rapida")
	_orbita.dias = maxi(int(totales.get("cruise_days", 203)), 1)
	_orbita.modulate.a = 0.0
	_raiz.add_child(_orbita)
	# Textos.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(col, "tl", 40, 34, 520, 200)
	_raiz.add_child(col)
	var etiqueta := UI.label(col, tr("LC_TAG"), 12, UI.AMBER)
	UI.display(etiqueta, 700, 3)
	_titulo = UI.label(col, "", 30, UI.CREAM)
	UI.display(_titulo, 700, 1)
	_texto = UI.label(col, "", 15, Color(UI.CREAM, 0.88))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.custom_minimum_size.x = 500
	_dato = UI.label(_raiz, "", 13, Color(UI.TEAL, 0.95))
	_dato.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.place(_dato, "bl", 40, 40, 620, 60)
	_saltar = Button.new()
	_saltar.text = tr("LC_SKIP")
	_saltar.custom_minimum_size = Vector2(140, 40)
	UI.place(_saltar, "br", 32, 32, 140, 40)
	_saltar.pressed.connect(_terminar)
	_raiz.add_child(_saltar)
	_velo = ColorRect.new()
	_velo.color = Color(0.02, 0.012, 0.01, 1.0)
	_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(_velo)
	create_tween().tween_property(_velo, "color:a", 0.0, 0.5)
	_titulo.text = tr("LC_LAUNCH_TITLE")
	_texto.text = tr("LC_LAUNCH_TEXT") % [_nombre("cohetes"), int(totales.get("mass_kg", 0)), int(totales.get("capacity_kg", 0))]
	_dato.text = NasaData.dato("lanzamiento")


func _unhandled_input(e: InputEvent) -> void:
	if not _activa:
		return
	if e is InputEventKey and e.pressed and not e.echo and (e.keycode == KEY_SPACE or e.keycode == KEY_ESCAPE or e.keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		_terminar()


func _process(delta: float) -> void:
	if not _activa:
		return
	_t += delta
	_lanzamiento.t = _t
	_lanzamiento.queue_redraw()
	var tc := _t - DURACION_LANZAMIENTO
	if tc > -0.6 and _orbita.modulate.a < 1.0:
		_orbita.modulate.a = clampf((tc + 0.6) / 0.8, 0.0, 1.0)
		_lanzamiento.modulate.a = 1.0 - _orbita.modulate.a
	if tc >= 0.0:
		var avance := clampf(tc / DURACION_CRUCERO, 0.0, 1.0)
		if _orbita.avance == 0.0 and avance > 0.0:
			_titulo.text = tr("LC_CRUISE_TITLE")
			_texto.text = tr("LC_CRUISE_RAPIDA" if _orbita.rapida else "LC_CRUISE_HOHMANN") % _orbita.dias
			_dato.text = NasaData.dato("crucero") + " " + tr("LC_DISTANCE_FACT")
		_orbita.avance = avance
		_orbita.queue_redraw()
		if avance >= 1.0 and tc >= DURACION_CRUCERO + DURACION_LLEGADA:
			_terminar()
		elif avance >= 1.0:
			_titulo.text = tr("LC_ARRIVAL_TITLE")
			_texto.text = tr("LC_ARRIVAL_TEXT")


func _terminar() -> void:
	if not _activa:
		return
	_activa = false
	var tw := create_tween()
	tw.tween_property(_velo, "color:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		visible = false
		if is_instance_valid(_raiz):
			_raiz.queue_free()
		finished.emit())


func _nombre(categoria: String) -> String:
	var elegidas: Array = taller.get("selection", {}).get(categoria, [])
	if elegidas.is_empty():
		return "—"
	for cat in taller.get("categories", []):
		for parte in cat.get("parts", []):
			if str(parte.get("id", "")) == str(elegidas[0]):
				return tr(str(parte.get("name_key", "")))
	return str(elegidas[0])


## Despegue visto de lado: torre, cohete (con propulsores si es pesado), llama, humo y cielo que se oscurece.
class LaunchView extends Control:
	var t := 0.0
	var pesado := false
	var _humo: Array = []
	var _nubes: Array = []

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if _nubes.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = 11
			for i in range(14):
				_nubes.append([rng.randf() * w, rng.randf_range(-h * 2.5, -h * 0.15), rng.randf_range(60, 160)])
		var subida := clampf((t - 1.4) / 2.8, 0.0, 1.0)
		var altura := pow(subida, 2.0) * h * 2.6  # metros «de pantalla» que sube el cohete
		# La cámara sigue al cohete: él sube hasta el 40 % de la pantalla y luego se mueve el mundo.
		var y_base := h * 0.855 - minf(altura, h * 0.30)  # la tobera; sube hasta el 55 % y luego se mueve el mundo
		var mundo := maxf(altura - h * 0.30, 0.0)
		var arriba := Color("2a5a94").lerp(Color("04050b"), clampf(mundo / (h * 1.6), 0.0, 1.0))
		var abajo := Color("a9c9e6").lerp(Color("0e1426"), clampf(mundo / (h * 1.6), 0.0, 1.0))
		for i in range(16):
			var a := float(i) / 16.0
			draw_rect(Rect2(0, h * a, w, h / 16.0 + 1.0), arriba.lerp(abajo, a))
		for n in _nubes:
			var y: float = n[1] + mundo * 0.9
			if y > -80.0 and y < h + 80.0:
				for k in range(4):
					draw_circle(Vector2(n[0] + k * n[2] * 0.35, y + sin(k) * 8.0), n[2] * 0.32, Color(1, 1, 1, 0.16))
		var temblor := Vector2.ZERO
		if t > 1.0 and subida < 0.6:
			temblor = Vector2(randf_range(-2.5, 2.5), randf_range(-2.0, 2.0)) * (1.0 - subida)
		var suelo := h * 0.86 + mundo
		var x0 := w * 0.62
		if suelo < h + 40.0:
			draw_rect(Rect2(0, suelo, w, h - suelo + 60), Color("2a2e29"))
			draw_rect(Rect2(x0 - 90, suelo - 10, 180, 12), Color("55575b"))
			var torre := Color("707378")
			draw_rect(Rect2(x0 + 52, suelo - h * 0.55, 20, h * 0.55), torre)
			for k in range(12):
				var y := suelo - h * 0.045 * k
				draw_line(Vector2(x0 + 52, y), Vector2(x0 + 72, y - h * 0.045), Color(torre, 0.8), 2.0)
			if subida <= 0.0:
				draw_line(Vector2(x0 + 52, suelo - h * 0.4), Vector2(x0 + 20, suelo - h * 0.4), torre, 4.0)
		var largo := h * (0.56 if pesado else 0.46)
		var ancho := 40.0
		var base := Vector2(x0, y_base) + temblor
		var cuerpo := Rect2(base.x - ancho / 2.0, base.y - largo, ancho, largo)
		var encendido := clampf((t - 0.7) / 0.6, 0.0, 1.0)
		if encendido > 0.0:
			draw_circle(base + Vector2(0, 30), 80.0 * encendido, Color(1.0, 0.7, 0.3, 0.18 * encendido))
			var largo_llama := (90.0 + randf() * 30.0) * encendido * (1.35 if pesado else 1.0)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-15, 0), base + Vector2(15, 0), base + Vector2(0, largo_llama)]), Color(1.0, 0.68, 0.25, 0.95))
			draw_colored_polygon(PackedVector2Array([base + Vector2(-8, 0), base + Vector2(8, 0), base + Vector2(0, largo_llama * 0.62)]), Color(1.0, 0.97, 0.85, 1.0))
			if suelo < h + 40.0 and randf() < 0.95:
				for i in range(2):
					_humo.append([Vector2(x0 + randf_range(-40, 40), suelo - 6), randf_range(22, 46), 0.0, randf_range(-3.5, 3.5)])
		var vivos: Array = []
		for p in _humo:
			p[2] += 0.016
			p[0] += Vector2(p[3], -0.4)
			p[0].y += mundo * 0.0
			p[1] += 0.8
			if p[2] < 2.6:
				vivos.append(p)
				draw_circle(p[0] + Vector2(0, mundo - minf(mundo, 0.0)), p[1], Color(0.93, 0.92, 0.9, 0.55 * (1.0 - p[2] / 2.6)))
		_humo = vivos
		# Cuerpo con tobera, etapas y cofia.
		draw_rect(cuerpo, Color("f3f0e8"))
		draw_rect(Rect2(cuerpo.position.x + ancho * 0.62, cuerpo.position.y, ancho * 0.38, largo), Color(0, 0, 0, 0.10))
		draw_rect(Rect2(cuerpo.position.x, cuerpo.position.y + largo * 0.30, ancho, 5), Color("c9732c"))
		draw_rect(Rect2(cuerpo.position.x, cuerpo.position.y + largo * 0.72, ancho, 3), Color(0, 0, 0, 0.25))
		draw_colored_polygon(PackedVector2Array([base + Vector2(-12, 0), base + Vector2(12, 0), base + Vector2(16, 12), base + Vector2(-16, 12)]), Color("3a3a3e"))
		var cofia := PackedVector2Array([Vector2(cuerpo.position.x - 4, cuerpo.position.y), Vector2(cuerpo.end.x + 4, cuerpo.position.y),
			Vector2(cuerpo.end.x + 4, cuerpo.position.y - 26), Vector2(base.x, cuerpo.position.y - 70), Vector2(cuerpo.position.x - 4, cuerpo.position.y - 26)])
		draw_colored_polygon(cofia, Color("e9e5db"))
		if pesado:
			for lado in [-1, 1]:
				var bx: float = base.x + float(lado) * (ancho / 2.0 + 9.0)
				draw_rect(Rect2(bx - 9, base.y - largo * 0.44, 18, largo * 0.44), Color("ecebe4"))
				draw_colored_polygon(PackedVector2Array([Vector2(bx - 9, base.y - largo * 0.44), Vector2(bx + 9, base.y - largo * 0.44),
					Vector2(bx, base.y - largo * 0.44 - 22)]), Color("dedbd1"))
				if encendido > 0.0:
					draw_colored_polygon(PackedVector2Array([Vector2(bx - 7, base.y), Vector2(bx + 7, base.y), Vector2(bx, base.y + 70.0 * encendido)]), Color(1.0, 0.8, 0.4, 0.9))
		var fuente := get_theme_default_font()
		var cuenta := "T%+.0f s" % (t - 1.4)
		draw_string(fuente, Vector2(w - 260, 76), cuenta, HORIZONTAL_ALIGNMENT_RIGHT, 220, 32, Color(1, 1, 1, 0.9))
		var km := pow(subida, 2.0) * 60.0
		draw_string(fuente, Vector2(w - 260, 106), tr("LC_ALTITUDE") % km, HORIZONTAL_ALIGNMENT_RIGHT, 220, 15, Color(1, 1, 1, 0.7))


## Vista orbital vista desde arriba: Sol, órbitas de la Tierra y de Marte, trayectoria y nave.
class OrbitView extends Control:
	var avance := 0.0
	var dias := 203
	var rapida := false
	const UA_TIERRA := 1.0
	const UA_MARTE := 1.524
	const ANGULO_SALIDA := deg_to_rad(200.0)

	func _barrido() -> float:
		return deg_to_rad(135.0) if rapida else PI

	## Excentricidad de la cónica que sale a 1 UA (perihelio) y llega a 1,524 UA tras «barrido» radianes.
	func _excentricidad() -> float:
		return (UA_MARTE - UA_TIERRA) / (UA_TIERRA - UA_MARTE * cos(_barrido()))

	func _radio(nu: float) -> float:
		var e := _excentricidad()
		return UA_TIERRA * (1.0 + e) / (1.0 + e * cos(nu))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("05060c"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in range(180):
			draw_circle(Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(0.5, 1.4), Color(1, 1, 1, rng.randf_range(0.2, 0.7)))
		if Destino.es_luna():
			_dibujar_luna(w, h)
			_hitos_y_contador(w, h, avance * dias)
			return
		var centro := Vector2(w * 0.6, h * 0.53)
		var escala := minf(w, h) * 0.27
		# Sol.
		for k in range(6):
			draw_circle(centro, 16.0 + k * 7.0, Color(1.0, 0.78, 0.35, 0.10))
		draw_circle(centro, 14.0, Color("ffd27a"))
		# Órbitas.
		draw_arc(centro, UA_TIERRA * escala, 0, TAU, 128, Color(0.45, 0.7, 1.0, 0.45), 1.5, true)
		draw_arc(centro, UA_MARTE * escala, 0, TAU, 128, Color(1.0, 0.55, 0.35, 0.45), 1.5, true)
		var dia := avance * dias
		var llegada := ANGULO_SALIDA + _barrido()
		# La Tierra sale de ANGULO_SALIDA; Marte está donde debe para llegar al encuentro (ventana de lanzamiento).
		var ang_tierra := ANGULO_SALIDA + TAU * dia / 365.25
		var ang_marte := llegada - TAU * (dias - dia) / 687.0
		# Trayectoria completa (punteada) y recorrida (sólida).
		var puntos := PackedVector2Array()
		var pasos := 90
		for i in range(pasos + 1):
			var nu := _barrido() * float(i) / pasos
			puntos.append(centro + Vector2.from_angle(-(ANGULO_SALIDA + nu)) * _radio(nu) * escala)
		for i in range(0, pasos, 2):
			draw_line(puntos[i], puntos[i + 1], Color(1, 1, 1, 0.35), 1.5, true)
		var nu_nave := _barrido() * _suave(avance)
		var recorrido := PackedVector2Array()
		for i in range(pasos + 1):
			var nu := nu_nave * float(i) / pasos
			recorrido.append(centro + Vector2.from_angle(-(ANGULO_SALIDA + nu)) * _radio(nu) * escala)
		if recorrido.size() >= 2:
			draw_polyline(recorrido, Color(0.62, 0.95, 0.85, 0.95), 2.5, true)
		# Planetas.
		var p_tierra := centro + Vector2.from_angle(-ang_tierra) * UA_TIERRA * escala
		var p_marte := centro + Vector2.from_angle(-ang_marte) * UA_MARTE * escala
		draw_circle(p_tierra, 9.0, Color("4e9be0"))
		draw_circle(p_marte, 7.5, Color("d9653b"))
		var nave := centro + Vector2.from_angle(-(ANGULO_SALIDA + nu_nave)) * _radio(nu_nave) * escala
		draw_circle(nave, 5.0, Color(1, 1, 1, 1))
		draw_circle(nave, 10.0 + 3.0 * sin(Time.get_ticks_msec() / 150.0), Color(0.62, 0.95, 0.85, 0.25))
		var fuente := get_theme_default_font()
		draw_string(fuente, p_tierra + Vector2(12, -10), tr("LC_EARTH"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9cc8f0"))
		draw_string(fuente, p_marte + Vector2(12, -10), tr("LC_MARS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("f0a07c"))
		draw_string(fuente, centro + Vector2(18, 26), tr("LC_SUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffd27a"))
		_hitos_y_contador(w, h, dia)

	func _hitos_y_contador(w: float, h: float, dia: float) -> void:
		var fuente := get_theme_default_font()
		var marca := tr("LC_DAY") % int(dia)
		draw_string(fuente, Vector2(w - 330, h - 120), marca, HORIZONTAL_ALIGNMENT_RIGHT, 290, 34, Color(1, 1, 1, 0.92))
		var hito := ""
		if avance < 0.12:
			hito = tr("LC_EV_SEPARATION")
		elif avance < 0.45:
			hito = tr("LC_EV_TCM1")
		elif avance < 0.85:
			hito = tr("LC_EV_CHECKOUT")
		else:
			hito = tr("LC_EV_APPROACH")
		draw_string(fuente, Vector2(w - 430, h - 86), hito, HORIZONTAL_ALIGNMENT_RIGHT, 390, 15, Color(0.62, 0.95, 0.85, 0.95))
		# Barra de tiempo.
		var barra := Rect2(w - 430, h - 70, 390, 4)
		draw_rect(barra, Color(1, 1, 1, 0.18))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * avance, 4)), Color(0.62, 0.95, 0.85, 0.9))

	## Tierra–Luna vista desde arriba (escala de distancias: la órbita lunar mide 384.400 km de radio).
	## Directa (como Apolo 11): media elipse desde la órbita baja hasta la Luna en unos 3 días.
	## Balística (como CAPSTONE): la nave se aleja hasta unas 4 distancias lunares, el Sol la frena y la curva, y vuelve
	## hasta encontrarse con la Luna meses después. Dibujo simplificado de la idea, no una efeméride.
	func _dibujar_luna(w: float, h: float) -> void:
		var balistica := rapida
		var centro := Vector2(w * (0.42 if balistica else 0.56), h * 0.55)
		var escala := minf(w, h) * (0.085 if balistica else 0.30)  # píxeles por distancia lunar
		var fuente := get_theme_default_font()
		# Dirección del Sol (a la izquierda).
		draw_string(fuente, Vector2(40, h * 0.5), "← " + tr("LC_SUN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("ffd27a"))
		# Tierra y órbita baja.
		draw_circle(centro, 11.0, Color("4e9be0"))
		draw_circle(centro, 15.0, Color(0.4, 0.7, 1.0, 0.18))
		draw_arc(centro, 1.0 * escala, 0, TAU, 128, Color(0.8, 0.8, 0.85, 0.45), 1.5, true)
		draw_string(fuente, centro + Vector2(14, 22), tr("LC_EARTH"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9cc8f0"))
		var dia := avance * dias
		var llegada := deg_to_rad(40.0)
		# La Luna da una vuelta cada 27,3 días: está donde debe para el encuentro al final del viaje.
		var ang_luna := llegada - TAU * (dias - dia) / 27.3
		var p_luna := centro + Vector2.from_angle(-ang_luna) * escala
		# Trayectoria.
		var puntos := PackedVector2Array()
		var pasos := 120
		for i in range(pasos + 1):
			puntos.append(_punto_luna(float(i) / pasos, centro, escala, llegada, balistica))
		for i in range(0, pasos, 2):
			draw_line(puntos[i], puntos[i + 1], Color(1, 1, 1, 0.35), 1.5, true)
		var hecho := PackedVector2Array()
		var k := _suave(avance)
		for i in range(pasos + 1):
			hecho.append(_punto_luna(k * float(i) / pasos, centro, escala, llegada, balistica))
		if hecho.size() >= 2:
			draw_polyline(hecho, Color(0.62, 0.95, 0.85, 0.95), 2.5, true)
		draw_circle(p_luna, 7.0, Color("c9c9c4"))
		draw_string(fuente, p_luna + Vector2(10, -10), tr("LC_MARS"), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e0e0dc"))
		var nave := _punto_luna(k, centro, escala, llegada, balistica)
		draw_circle(nave, 5.0, Color(1, 1, 1, 1))
		draw_circle(nave, 10.0 + 3.0 * sin(Time.get_ticks_msec() / 150.0), Color(0.62, 0.95, 0.85, 0.25))
		draw_string(fuente, Vector2(w - 430, h - 150), tr("LC_SCALE_MOON"), HORIZONTAL_ALIGNMENT_RIGHT, 390, 12, Color(1, 1, 1, 0.55))

	## Punto de la trayectoria lunar en la fracción f del viaje.
	func _punto_luna(f: float, centro: Vector2, escala: float, llegada: float, balistica: bool) -> Vector2:
		var salida := llegada + PI
		if not balistica:
			# Media elipse: de la órbita baja (0,05 DL) a la distancia lunar (1 DL).
			var nu := PI * f
			var r := lerpf(0.05, 1.0, (1.0 - cos(nu)) / 2.0)
			return centro + Vector2.from_angle(-(salida + nu)) * r * escala
		# Balística: sale hacia el Sol, llega a unas 4 DL y regresa por fuera hasta la Luna.
		var giro := salida - PI * f  # rodea por el lado contrario a la ruta directa
		var r2 := 0.05 + 3.9 * sin(PI * minf(f * 1.1, 1.0)) * (1.0 - f * 0.35)
		if f > 0.85:
			r2 = lerpf(r2, 1.0, (f - 0.85) / 0.15)
		return centro + Vector2.from_angle(-giro) * r2 * escala

	## Avance con un poco de aceleración al salir y frenado al llegar (como una cónica alrededor del Sol).
	func _suave(x: float) -> float:
		return x * x * (3.0 - 2.0 * x) * 0.55 + x * 0.45
