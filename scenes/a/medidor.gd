extends Node
## Modo medición de rendimiento: mide la misma partida en cualquier equipo, en el escritorio y en la web.
##   Escritorio: GAIA.exe --medir   (o Medir_rendimiento.bat). Escribe medicion_rendimiento.txt junto al .exe y cierra.
##   Web:        https://.../gaia/?medir=1   Muestra el resultado en pantalla y en la consola del navegador.
## Empieza la misión con el diseño inicial, espera CALENTAR_S (carga y sombreadores) y mide MEDIR_S segundos de
## operaciones: FPS medio, cuadro medio, percentil 95 y peor, memoria del motor y llamadas de dibujo.
## Con --escena=plataforma (web: ?escena=plataforma) mide la plataforma de lanzamiento de la Tierra con el Saturno V
## elegido (hangar de 70 944 triángulos y el cohete más alto), en vez de la misión (plan de mejoras 6.4).

const CALENTAR_S := 12.0
const MEDIR_S := 45.0

var _t := 0.0
var _cuadros: PackedFloat32Array = PackedFloat32Array()
var _dibujo := 0.0
var _muestras := 0
var _hecho := false
var _cohete_elegido := false
var _ultimo_us := 0  ## reloj real: «delta» del motor se recorta a 8 pasos de física (133 ms) y escondería los cuadros lentos


## Escena que se mide: «mision» (por defecto) o «plataforma».
static func escena() -> String:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--escena="):
			return a.get_slice("=", 1)
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("String(new URLSearchParams(window.location.search).get('escena') || '')", true)
		if str(r) == "plataforma":
			return "plataforma"
	return "mision"


## true si se pidió medir (argumento --medir o ?medir=1 en la web).
static func pedido() -> bool:
	if OS.get_cmdline_args().has("--medir") or OS.get_cmdline_user_args().has("--medir"):
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval("String(new URLSearchParams(window.location.search).has('medir'))", true)
		return str(r) == "true"
	return false


func _process(delta: float) -> void:
	if _hecho:
		return
	var ahora := Time.get_ticks_usec()
	var real_s := delta if _ultimo_us == 0 else (ahora - _ultimo_us) / 1000000.0
	_ultimo_us = ahora
	_t += real_s
	if _t < CALENTAR_S:
		if escena() == "plataforma" and _t > 1.0 and not _cohete_elegido:
			_elegir_saturno()
		return
	_cuadros.append(real_s)
	_dibujo += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_muestras += 1
	if _t >= CALENTAR_S + MEDIR_S:
		_hecho = true
		_terminar()


## Plataforma: marca el Saturno V (cohete_super) como haría el jugador; se monta durante el calentamiento.
func _elegir_saturno() -> void:
	var vista: Node = get_parent().get("view")
	if vista == null or vista.get("launch_pad") == null:
		return
	var plataforma: CanvasLayer = vista.launch_pad
	for categoria in plataforma.snapshot.get("workshop", {}).get("categories", []):
		for pieza in categoria.get("parts", []):
			if str(pieza.get("id", "")) == "cohete_super":
				plataforma.elegido = ""
				plataforma._on_card("cohete_super", float(pieza.get("capacity_kg", 1800.0)), float(pieza.get("real_height_m", 110.6)))
				_cohete_elegido = true


## Banco de CPU independiente de la GPU: corre la misma simulación (diseño inicial, 1200 pasos de 0,25 h) sin
## dibujar nada. Sirve para comparar el escritorio (GDScript nativo) con la web (WebAssembly) en el mismo equipo.
static func banco_simulacion() -> Array:
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, "marte", 1.0)
	var sim := Simulation.new(Balance.desde_archivo("res://content/balance.json"), Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"), catalogo, Economy.desde_archivo("res://content/economia.json"))
	for id in ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")
	const PASOS := 1200
	var inicio := Time.get_ticks_usec()
	var hechos := 0
	for i in range(PASOS):
		sim.avanzar(0.25)
		sim.snapshot()  # la vista pide una foto del estado en cada cuadro
		hechos += 1
		if sim.estado.fase != "operations":
			break
	var ms := (Time.get_ticks_usec() - inicio) / 1000.0
	return [ms / maxf(hechos, 1), hechos, ms]


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
		"Escena medida: %s" % ("plataforma de lanzamiento (Saturno V)" if escena() == "plataforma" else "misión (operaciones)"),
		"GPU: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()],
		"Ajuste gráfico: %s · ventana %s" % [str(g.get("preset", "?")), str(DisplayServer.window_get_size())],
		"Cuadros medidos: %d en %.0f s de operaciones" % [orden.size(), MEDIR_S],
		"FPS medio: %.1f" % (1.0 / maxf(medio, 0.0001)),
		"Cuadro medio: %.1f ms · p95: %.1f ms · peor: %.1f ms" % [medio * 1000.0,
			orden[int(orden.size() * 0.95)] * 1000.0 if orden.size() > 0 else 0.0, orden[-1] * 1000.0 if orden.size() > 0 else 0.0],
		"VRAM usada: %.0f MB" % (RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0),
		"Llamadas de dibujo por cuadro: %.0f" % (_dibujo / maxf(_muestras, 1)),
		"Simulación pura (CPU, sin gráficos): %.3f ms por paso · %d pasos en %.0f ms" % banco_simulacion(),
		"Procesador: %s · %d hilos" % ["(navegador)" if OS.has_feature("web") else OS.get_processor_name(), OS.get_processor_count()],
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
