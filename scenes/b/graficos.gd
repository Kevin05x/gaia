class_name Graficos
extends RefCounted
## Configuración gráfica del jugador: un ajuste predefinido (Baja, Media, Alta, Ultra) o «Personalizada». Se guarda en
## el mismo archivo de preferencias (user://b_preferences.cfg, sección «graficos») y la aplican la vista de la misión
## (luz, sombras, materiales, decorado) y la calidad automática. Aquí solo hay datos: nada de nodos.
const ARCHIVO := "user://b_preferences.cfg"
const SECCION := "graficos"
const ORDEN: Array[String] = ["baja", "media", "alta", "ultra"]
const DEFECTO := "alta"  ## en el escritorio; en el navegador se empieza en Media (ver defecto())
## Tope de píxeles del mundo 3D: en pantallas grandes o con escala de Windows (125 %, 150 %) el navegador pide
## lienzos de 2,5 a 4 millones de píxeles. Por encima de ~1080p no se nota la diferencia y los gráficos integrados
## se ahogan, así que el 3D se dibuja como mucho a esto y se estira (la interfaz sigue nítida).
const MAX_PIXELES_3D := 1920 * 1080
## sombras: 0 apagadas, 1 normales, 2 altas · aa: 0 no, 1 MSAA 2x, 2 MSAA 4x · resolucion: escala del mundo 3D
## distancia: 0 corta, 1 normal, 2 lejana · auto: baja la calidad sola si el equipo no llega (nunca la sube de lo elegido)
const PRESETS := {
	"baja": {"sombras": 0, "aa": 0, "resolucion": 0.8, "post": false, "texturas": false, "polvo": false, "distancia": 0, "auto": true},
	"media": {"sombras": 1, "aa": 0, "resolucion": 1.0, "post": true, "texturas": true, "polvo": false, "distancia": 1, "auto": true},
	"alta": {"sombras": 1, "aa": 1, "resolucion": 1.0, "post": true, "texturas": true, "polvo": true, "distancia": 1, "auto": true},
	"ultra": {"sombras": 2, "aa": 2, "resolucion": 1.0, "post": true, "texturas": true, "polvo": true, "distancia": 2, "auto": true},
}
const FACTOR_DISTANCIA := [0.7, 1.0, 1.45]
const CLAVES: Array[String] = ["sombras", "aa", "resolucion", "post", "texturas", "polvo", "distancia", "auto"]


## Ajuste con el que se empieza si nunca se eligió uno: en el navegador (WebGL) Baja (medido el 15 nov con Chrome en una Intel UHD:
## Media tardaba más de un minuto en compilar sombreadores la primera vez y Baja unos 30 s); en el escritorio Alta.
static func defecto() -> String:
	return "baja" if OS.has_feature("web") else DEFECTO


## Valores de un ajuste predefinido (copia).
static func de_preset(nombre: String) -> Dictionary:
	var g: Dictionary = PRESETS.get(nombre, PRESETS[defecto()]).duplicate()
	g["preset"] = nombre if PRESETS.has(nombre) else defecto()
	return g


## Lee la configuración guardada. Si es de una versión anterior (solo «visual/quality»), Alta o Baja según eso.
static func cargar() -> Dictionary:
	if preload("res://scenes/a/medidor.gd").pedido():
		# Medición: siempre el mismo ajuste (el de fábrica de la plataforma, o --preset=X) y sin calidad automática,
		# para que las cifras de equipos distintos se puedan comparar.
		var nombre := defecto()
		for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
			if a.begins_with("--preset="):
				nombre = a.get_slice("=", 1)
		if OS.has_feature("web"):  # en la web el ajuste se pide en la dirección: ?medir=1&preset=baja
			var pedido: Variant = JavaScriptBridge.eval("String(new URLSearchParams(window.location.search).get('preset') || '')", true)
			if str(pedido) != "":
				nombre = str(pedido)
		var fijo := de_preset(nombre)
		fijo["auto"] = false
		return fijo
	var config := ConfigFile.new()
	if config.load(ARCHIVO) != OK:
		return de_preset(defecto())
	if not config.has_section(SECCION):
		return de_preset(defecto() if bool(config.get_value("visual", "quality", true)) else "baja")
	var g := de_preset(str(config.get_value(SECCION, "preset", defecto())))
	for clave in CLAVES:
		g[clave] = config.get_value(SECCION, clave, g[clave])
	g["preset"] = preset_de(g)
	return normalizar(g)


static func guardar(g: Dictionary) -> void:
	var config := ConfigFile.new()
	config.load(ARCHIVO)  # conserva idioma, volumen, tutorial, ventana...
	config.set_value(SECCION, "preset", preset_de(g))
	for clave in CLAVES:
		config.set_value(SECCION, clave, g[clave])
	config.set_value("visual", "quality", bool(g["texturas"]))  # compatibilidad con versiones anteriores
	config.save(ARCHIVO)


## «Mostrar FPS»: contador de rendimiento dentro del juego. Va aparte de los ajustes (no cambia el nivel elegido).
static func mostrar_fps() -> bool:
	var config := ConfigFile.new()
	if config.load(ARCHIVO) != OK:
		return false
	return bool(config.get_value(SECCION, "mostrar_fps", false))


static func guardar_fps(activo: bool) -> void:
	var config := ConfigFile.new()
	config.load(ARCHIVO)
	config.set_value(SECCION, "mostrar_fps", activo)
	config.save(ARCHIVO)


## Nombre del ajuste predefinido que coincide con estos valores, o «personalizada».
static func preset_de(g: Dictionary) -> String:
	for nombre in ORDEN:
		var p: Dictionary = PRESETS[nombre]
		var igual := true
		for clave in CLAVES:
			if not is_equal_approx(float(p[clave]), float(g.get(clave, p[clave]))):
				igual = false
				break
		if igual:
			return nombre
	return "personalizada"


## Acota valores (por si el archivo se editó a mano).
static func normalizar(g: Dictionary) -> Dictionary:
	g["sombras"] = clampi(int(g["sombras"]), 0, 2)
	g["aa"] = clampi(int(g["aa"]), 0, 2)
	g["resolucion"] = clampf(float(g["resolucion"]), 0.7, 1.0)
	g["distancia"] = clampi(int(g["distancia"]), 0, 2)
	for clave in ["post", "texturas", "polvo", "auto"]:
		g[clave] = bool(g[clave])
	return g


## Suavizado para la plataforma, el hangar y los visores de piezas: en una GPU integrada (Intel UHD) el MSAA 2x partía los
## cuadros por la mitad (medido el 15 nov: 17,9 FPS con él y 35,6 sin él en la plataforma), así que ahí se empieza sin él.
static func msaa_visor(g: Dictionary) -> Viewport.MSAA:
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return Viewport.MSAA_DISABLED
	return msaa(g)


static func msaa(g: Dictionary) -> Viewport.MSAA:
	return [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(g["aa"])]
