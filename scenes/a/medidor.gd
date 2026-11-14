extends Node
## Modo medición de rendimiento: mide la misma partida en cualquier equipo, en el escritorio y en la web.
##   Escritorio: GAIA.exe --medir   (o Medir_rendimiento.bat). Escribe medicion_rendimiento.txt junto al .exe y cierra.
##   Web:        https://.../gaia/?medir=1   Muestra el resultado en pantalla y en la consola del navegador.
## Empieza la misión con el diseño inicial, espera CALENTAR_S (carga y sombreadores) y mide MEDIR_S segundos de
## operaciones: FPS medio, cuadro medio, percentil 95 y peor, memoria del motor y llamadas de dibujo.

const CALENTAR_S := 12.0
const MEDIR_S := 45.0

var _t := 0.0
var _cuadros: PackedFloat32Array = PackedFloat32Array()
var _dibujo := 0.0
var _muestras := 0
var _hecho := false


## true si se pidió medir (argumento --medir o ?medir=1 en la web).
static func pedido() -> bool:
	if OS.get_cmdline_args().has("--medir") or OS.get_cmdline_user_args().has("--medir"):
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("new URLSearchParams(window.location.search).has('medir')", true)
		return r == true
	return false


func _process(delta: float) -> void:
	if _hecho:
		return
	_t += delta
	if _t < CALENTAR_S:
		return
	_cuadros.append(delta)
	_dibujo += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_muestras += 1
	if _t >= CALENTAR_S + MEDIR_S:
		_hecho = true
		_terminar()


func _terminar() -> void:
	var orden := _cuadros.duplicate()
	orden.sort()
	var suma := 0.0
	for c in orden:
		suma += c
	var medio := suma / maxf(orden.size(), 1)
	var g := Graficos.cargar()
	var texto := "\n".join([
		"GAIA - medición de rendimiento",
		"Fecha: %s" % Time.get_datetime_string_from_system(),
		"Plataforma: %s (%s)" % [OS.get_name(), "web" if OS.has_feature("web") else "escritorio"],
		"GPU: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"Ajuste gráfico: %s · ventana %s" % [str(g.get("preset", "?")), str(DisplayServer.window_get_size())],
		"Cuadros medidos: %d en %.0f s de operaciones" % [orden.size(), MEDIR_S],
		"FPS medio: %.1f" % (1.0 / maxf(medio, 0.0001)),
		"Cuadro medio: %.1f ms · p95: %.1f ms · peor: %.1f ms" % [medio * 1000.0,
			orden[int(orden.size() * 0.95)] * 1000.0 if orden.size() > 0 else 0.0, orden[-1] * 1000.0 if orden.size() > 0 else 0.0],
		"VRAM usada: %.0f MB" % (RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0),
		"Llamadas de dibujo por cuadro: %.0f" % (_dibujo / maxf(_muestras, 1)),
	])
	print(texto)
	if OS.has_feature("web"):
		var etiqueta := Label.new()
		etiqueta.text = texto
		etiqueta.add_theme_font_size_override("font_size", 18)
		etiqueta.add_theme_color_override("font_color", Color.WHITE)
		etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
		etiqueta.add_theme_constant_override("outline_size", 6)
		etiqueta.position = Vector2(40, 120)
		var capa := CanvasLayer.new()
		capa.layer = 50
		capa.add_child(etiqueta)
		add_child(capa)
		return
	var ruta := OS.get_executable_path().get_base_dir().path_join("medicion_rendimiento.txt")
	var archivo := FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		archivo = FileAccess.open("user://medicion_rendimiento.txt", FileAccess.WRITE)
	if archivo != null:
		archivo.store_string(texto + "\n")
		archivo.close()
	get_tree().quit()
