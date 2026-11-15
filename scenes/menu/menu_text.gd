extends RefCounted
## Textos y preferencias de las pantallas de entrada (intro, menú, tutorial y carga) en español e inglés.
## Registra sus traducciones en el TranslationServer junto a las del juego y comparte el archivo de preferencias
## (`user://b_preferences.cfg`) con la vista de la misión.
const PREFERENCIAS := "user://b_preferences.cfg"
const TABLES := {
	"es": {
		"INTRO_SUBTITLE": "DISEÑO DE MISIONES ESPACIALES",
		"INTRO_CREDIT": "NASA Space Apps Challenge 2026",
		"INTRO_CLICK": "PULSA PARA COMENZAR",
		"M_CONTINUE": "CONTINUAR",
		"M_NEW": "NUEVA PARTIDA",
		"M_HOWTO": "CÓMO JUGAR",
		"M_CONTROLS": "CONTROLES",
		"M_SETTINGS": "CONFIGURACIÓN",
		"M_CREDITS": "CRÉDITOS",
		"M_RECORDS": "RÉCORDS",
		"M_RECORDS_TITLE": "Récords del equipo",
		"M_RECORDS_EMPTY": "Todavía no hay misiones terminadas. Completa una misión y aparecerá aquí con su puntuación y su código de diseño.",
		"M_RECORDS_NOTE": "La puntuación premia la ciencia enviada, las estrellas, el éxito y el presupuesto ahorrado. Pega un código en el taller (botón «Código») para probar el diseño de otro equipo.",
		"M_REC_SCORE": "Puntos",
		"M_REC_CODE": "Código",
		"M_QUIT": "SALIR",
		"M_SAVE_INFO": "Sol %d  ·  %d de %d de ciencia enviada",
		"M_NO_SAVE": "Sin partida guardada",
		"M_LOADING": "CARGANDO",
		"M_TIP": "CONSEJO",
		"M_TIP1": "De noche los paneles solares no producen: planifica tu batería antes de que se ponga el sol.",
		"M_TIP2": "Solo cuenta la ciencia transmitida a la Tierra, y solo se puede enviar con el enlace abierto.",
		"M_TIP3": "Haz clic en el minimapa para mover el rover más rápido por el terreno.",
		"M_TIP4": "Una tormenta de polvo reduce la energía solar: guarda reserva de batería.",
		"M_TIP5": "Cada pieza del taller cuesta presupuesto, masa y energía. El equilibrio es la clave.",
		"M_TIP6": "Q y E giran la cámara; la rueda del mouse acerca o aleja.",
		"M_BACK": "Volver",
		"M_FOOTER": "NASA Space Apps Challenge 2026  ·  Space Mission Design Game",
		"M_NEW_CONFIRM_TITLE": "¿Empezar de nuevo?",
		"M_NEW_CONFIRM": "Ya tienes una misión guardada. Si empiezas una nueva, la guardada se reemplaza en cuanto llegues al siguiente sol.",
		"M_NEW_CONFIRM_YES": "Empezar una nueva",
		"M_NEW_CONFIRM_NO": "Cancelar",
		"M_SET_LANGUAGE": "Idioma",
		"M_SET_VOLUME": "Volumen general",
		"M_SET_MUTE": "Silenciar todo",
		"M_SET_GRAPHICS": "Gráficos",
		"M_SET_GRAPHICS_HIGH": "Altos",
		"M_SET_GRAPHICS_LOW": "Ligeros",
		"M_SET_GRAPHICS_NOTE": "Los gráficos ligeros quitan sombras y reducen las partículas: úsalos en equipos modestos.",
		"M_SET_FULLSCREEN": "Pantalla completa",
		"M_SET_WINDOW": "Tamaño de ventana",
		"M_SET_WINDOW_NOTE": "Solo aparecen los tamaños que caben en tu pantalla. «Nativa» la ocupa entera, a su resolución (pantalla completa).",
		"M_SET_NATIVE": "Nativa · %d×%d",
		"M_SET_TUTORIAL": "Mostrar el tutorial al empezar una partida",
		"M_CONTROLS_TITLE": "Controles",
		"M_CTRL_MOUSE": "Ratón",
		"M_CTRL_KEYS": "Teclado",
		"M_CTRL_CLICK": "Clic en una roca marcada",
		"M_CTRL_CLICK_D": "Muestra su acción: investigar, perforar, acercar.",
		"M_CTRL_GROUND": "Clic en el suelo o en el minimapa",
		"M_CTRL_GROUND_D": "Mueve el rover hasta ese punto.",
		"M_CTRL_WHEEL": "Rueda",
		"M_CTRL_WHEEL_D": "Acerca o aleja la cámara.",
		"M_CTRL_QE": "Q / E",
		"M_CTRL_QE_D": "Gira la cámara alrededor del rover. También: lleva el mouse al borde izquierdo o derecho de la pantalla.",
		"M_CTRL_F": "F",
		"M_CTRL_F_D": "Centra la cámara en el rover.",
		"M_CTRL_CVX": "C  ·  V  ·  X",
		"M_CTRL_CVX_D": "Panorama, radar y compañero.",
		"M_CTRL_T": "T",
		"M_CTRL_T_D": "Transmite la ciencia a la Tierra.",
		"M_CTRL_ESC": "Esc",
		"M_CTRL_ESC_D": "Pausa y opciones.",
		"M_CTRL_F1": "F1 / H  ·  F3 / P",
		"M_CTRL_F1_D": "Ayuda y rendimiento.",
		"M_CREDITS_TITLE": "Créditos",
		"M_CREDITS_TEAM": "Equipo GAIA",
		"M_CREDITS_ROLES": "Kevin: simulación, datos, taller y publicación\nAmner: mundo 3D, interfaz, HUD, informe y sonido",
		"M_CREDITS_DATA": "Datos y ciencia",
		"M_CREDITS_DATA_D": "Datos e imágenes públicas de la NASA, cada una con su crédito: Mars 2020 / Perseverance, Apolo 11, CAPSTONE, Artemis II y datos lunares (press kits de NASA/JPL, NASA Science, images.nasa.gov). Las cifras de juego están a escala y se distinguen de los datos reales. GAIA es un proyecto independiente: no está afiliado a la NASA ni cuenta con su respaldo.",
		"M_CREDITS_ART": "Arte",
		"M_CREDITS_ART_D": "Generado con IA (con marca de agua visible): logotipo, fondo del menú, pantalla de carga e ilustraciones de la historia (Canva). Modelos 3D de minerales, antenas, focos, hangares y torretas: equipo de diseño. El resto del mundo 3D se genera por código. Tipografías Inter y Space Grotesk (OFL).",
		"M_CREDITS_MUSIC": "Música",
		"M_CREDITS_MUSIC_D": "Música y sonido originales del juego, sintetizados por código.",
		"M_CREDITS_ENGINE": "Hecho con Godot Engine 4.7 (MIT). Parte del código, los textos y los datos se desarrollaron con asistencia de IA (Claude, de Anthropic) bajo la dirección del equipo.",
		"M_TUT_TITLE": "Cómo jugar",
		"M_TUT_SKIP": "Omitir",
		"M_TUT_PREV": "Anterior",
		"M_TUT_NEXT": "Siguiente",
		"M_TUT_CLOSE": "Cerrar",
		"M_TUT_START": "¡Empezar la misión!",
		"M_T1_TITLE": "La misión",
		"M_T1_BODY": "Eres el centro de control de una misión a Marte. Tu rover llegará al cráter Jezero, el lecho de un antiguo lago, a buscar señales de que allí hubo agua. Tu meta: que el equipo científico de la Tierra reciba todos los datos que necesita.",
		"M_T2_TITLE": "El taller",
		"M_T2_BODY": "Antes de despegar diseñas la misión: cohete, chasis, energía, comunicaciones e instrumentos. Cada pieza cuesta presupuesto, masa y energía. Si pesas demasiado no despegas; si te quedas sin energía, el rover se detiene.",
		"M_T3_TITLE": "Despegue y aterrizaje",
		"M_T3_BODY": "Tu diseño viaja hasta Marte y baja por la atmósfera. Un buen equilibrio entre masa y sistemas hace que el aterrizaje salga bien. Con el rover en el suelo empiezan las operaciones, que avanzan por soles, los días marcianos.",
		"M_T4_TITLE": "Explorar",
		"M_T4_BODY": "Haz clic en una roca marcada para ver qué puede hacer tu rover con ella. Haz clic en el suelo o en el minimapa para moverlo. De noche los paneles solares no producen: planifica tu batería antes de que se ponga el sol.",
		"M_T5_TITLE": "Transmitir a la Tierra",
		"M_T5_BODY": "La ciencia solo cuenta cuando llega a la Tierra. Transmítela con T o desde el panel, siempre que el enlace esté abierto. Cuando alcances la meta, o si la misión falla, verás un informe que explica qué pasó y por qué.",
	},
	"en": {
		"INTRO_SUBTITLE": "SPACE MISSION DESIGN",
		"INTRO_CREDIT": "NASA Space Apps Challenge 2026",
		"INTRO_CLICK": "CLICK TO START",
		"M_CONTINUE": "CONTINUE",
		"M_NEW": "NEW GAME",
		"M_HOWTO": "HOW TO PLAY",
		"M_CONTROLS": "CONTROLS",
		"M_SETTINGS": "SETTINGS",
		"M_CREDITS": "CREDITS",
		"M_RECORDS": "RECORDS",
		"M_RECORDS_TITLE": "Team records",
		"M_RECORDS_EMPTY": "No finished missions yet. Complete a mission and it will appear here with its score and design code.",
		"M_RECORDS_NOTE": "The score rewards science sent, stars, success and budget saved. Paste a code in the workshop (\"Code\" button) to try another team's design.",
		"M_REC_SCORE": "Points",
		"M_REC_CODE": "Code",
		"M_QUIT": "QUIT",
		"M_SAVE_INFO": "Sol %d  ·  %d of %d science sent",
		"M_NO_SAVE": "No saved game",
		"M_LOADING": "LOADING",
		"M_TIP": "TIP",
		"M_TIP1": "Solar panels produce nothing at night: plan your battery before the sun sets.",
		"M_TIP2": "Only science transmitted to Earth counts, and it can only be sent while the link is open.",
		"M_TIP3": "Click the minimap to move the rover across the terrain faster.",
		"M_TIP4": "A dust storm cuts solar power: keep a battery reserve.",
		"M_TIP5": "Every workshop part costs budget, mass and power. Balance is the key.",
		"M_TIP6": "Q and E rotate the camera; the mouse wheel zooms in and out.",
		"M_BACK": "Back",
		"M_FOOTER": "NASA Space Apps Challenge 2026  ·  Space Mission Design Game",
		"M_NEW_CONFIRM_TITLE": "Start over?",
		"M_NEW_CONFIRM": "You already have a saved mission. If you start a new one, the saved one is replaced as soon as you reach the next sol.",
		"M_NEW_CONFIRM_YES": "Start a new one",
		"M_NEW_CONFIRM_NO": "Cancel",
		"M_SET_LANGUAGE": "Language",
		"M_SET_VOLUME": "Master volume",
		"M_SET_MUTE": "Mute everything",
		"M_SET_GRAPHICS": "Graphics",
		"M_SET_GRAPHICS_HIGH": "High",
		"M_SET_GRAPHICS_LOW": "Light",
		"M_SET_GRAPHICS_NOTE": "Light graphics remove shadows and cut particles: use them on modest hardware.",
		"M_SET_FULLSCREEN": "Fullscreen",
		"M_SET_WINDOW": "Window size",
		"M_SET_WINDOW_NOTE": "Only sizes that fit your screen are listed. \"Native\" fills it at its own resolution (fullscreen).",
		"M_SET_NATIVE": "Native · %d×%d",
		"M_SET_TUTORIAL": "Show the tutorial when starting a game",
		"M_CONTROLS_TITLE": "Controls",
		"M_CTRL_MOUSE": "Ratón",
		"M_CTRL_KEYS": "Keyboard",
		"M_CTRL_CLICK": "Click a marked rock",
		"M_CTRL_CLICK_D": "Shows its action: investigate, drill, approach.",
		"M_CTRL_GROUND": "Click the ground or the minimap",
		"M_CTRL_GROUND_D": "Moves the rover to that point.",
		"M_CTRL_WHEEL": "Wheel",
		"M_CTRL_WHEEL_D": "Zooms the camera in and out.",
		"M_CTRL_QE": "Q / E",
		"M_CTRL_QE_D": "Rotates the camera around the rover. Also: move the mouse to the left or right screen edge.",
		"M_CTRL_F": "F",
		"M_CTRL_F_D": "Centers the camera on the rover.",
		"M_CTRL_CVX": "C  ·  V  ·  X",
		"M_CTRL_CVX_D": "Panorama, radar and companion.",
		"M_CTRL_T": "T",
		"M_CTRL_T_D": "Transmits science to Earth.",
		"M_CTRL_ESC": "Esc",
		"M_CTRL_ESC_D": "Pause and options.",
		"M_CTRL_F1": "F1 / H  ·  F3 / P",
		"M_CTRL_F1_D": "Help and performance.",
		"M_CREDITS_TITLE": "Credits",
		"M_CREDITS_TEAM": "GAIA team",
		"M_CREDITS_ROLES": "Kevin: simulation, data, workshop and release\nAmner: 3D world, interface, HUD, report and sound",
		"M_CREDITS_DATA": "Data and science",
		"M_CREDITS_DATA_D": "Public NASA data and images, each with its credit: Mars 2020 / Perseverance, Apollo 11, CAPSTONE, Artemis II and lunar data (NASA/JPL press kits, NASA Science, images.nasa.gov). Game figures are scaled and kept apart from real data. GAIA is an independent project: it is not affiliated with or endorsed by NASA.",
		"M_CREDITS_ART": "Art",
		"M_CREDITS_ART_D": "AI-generated (with a visible watermark): logo, menu background, loading screen and story illustrations (Canva). 3D models of minerals, antennas, lights, hangars and turrets: design team. The rest of the 3D world is generated by code. Inter and Space Grotesk typefaces (OFL).",
		"M_CREDITS_MUSIC": "Music",
		"M_CREDITS_MUSIC_D": "Original game music and sound, synthesized by code.",
		"M_CREDITS_ENGINE": "Made with Godot Engine 4.7 (MIT). Parts of the code, texts and data were developed with AI assistance (Claude, by Anthropic) under the team's direction.",
		"M_TUT_TITLE": "How to play",
		"M_TUT_SKIP": "Skip",
		"M_TUT_PREV": "Previous",
		"M_TUT_NEXT": "Next",
		"M_TUT_CLOSE": "Close",
		"M_TUT_START": "Start the mission!",
		"M_T1_TITLE": "The mission",
		"M_T1_BODY": "You are mission control for a trip to Mars. Your rover will reach Jezero crater, the bed of an ancient lake, to look for signs that water once flowed there. Your goal: make sure the science team on Earth receives all the data it needs.",
		"M_T2_TITLE": "The workshop",
		"M_T2_BODY": "Before launch you design the mission: rocket, chassis, power, communications and instruments. Every part costs budget, mass and power. Too heavy and you will not lift off; out of power and the rover stops.",
		"M_T3_TITLE": "Launch and landing",
		"M_T3_BODY": "Your design travels to Mars and descends through the atmosphere. A good balance of mass and systems makes the landing succeed. Once the rover is on the ground, operations begin and advance by sols, the Martian days.",
		"M_T4_TITLE": "Explore",
		"M_T4_BODY": "Click a marked rock to see what your rover can do with it. Click the ground or the minimap to move it. At night the solar panels produce nothing: plan your battery before the sun sets.",
		"M_T5_TITLE": "Transmit to Earth",
		"M_T5_BODY": "Science only counts once it reaches Earth. Transmit it with T or from the panel, whenever the link is open. When you reach the goal, or if the mission fails, a report explains what happened and why.",
	},
}
static var _instaladas := false


## Registra las traducciones (una sola vez) y aplica el idioma guardado.
static func install() -> void:
	if not _instaladas:
		for idioma in TABLES:
			var traduccion := Translation.new()
			traduccion.locale = idioma
			for clave in TABLES[idioma]:
				traduccion.add_message(clave, TABLES[idioma][clave])
			TranslationServer.add_translation(traduccion)
			Destino.registrar(traduccion)
		var catalogo = preload("res://scenes/b/i18n/catalog.gd").TABLES
		for idioma in catalogo:
			var traduccion := Translation.new()
			traduccion.locale = idioma
			for clave in catalogo[idioma]:
				traduccion.add_message(clave, catalogo[idioma][clave])
			TranslationServer.add_translation(traduccion)
			Destino.registrar(traduccion)
		var red = preload("res://scenes/net/net_text.gd").TABLES
		for idioma in red:
			var traduccion := Translation.new()
			traduccion.locale = idioma
			for clave in red[idioma]:
				traduccion.add_message(clave, red[idioma][clave])
			TranslationServer.add_translation(traduccion)
			Destino.registrar(traduccion)
		_instaladas = true
	TranslationServer.set_locale(String(preferencias().get("language", "es")))
	aplicar_audio()
	aplicar_ventana()


## Lee las preferencias guardadas con sus valores por defecto.
static func preferencias() -> Dictionary:
	var datos := {"language": "es", "volume": 0.65, "muted": false, "quality": true, "tutorial": true, "window_size": Vector2i.ZERO,
		"fullscreen": false, "radio_voices": true, "acciones_modo": "emergentes"}
	var config := ConfigFile.new()
	if config.load(PREFERENCIAS) == OK:
		datos["language"] = config.get_value("ui", "language", "es")
		datos["volume"] = config.get_value("audio", "volume", 0.65)
		datos["muted"] = config.get_value("audio", "muted", false)
		datos["quality"] = config.get_value("visual", "quality", true)
		datos["tutorial"] = config.get_value("ui", "tutorial", true)
		datos["window_size"] = config.get_value("visual", "window_size", Vector2i.ZERO)
		datos["fullscreen"] = bool(config.get_value("visual", "fullscreen", false))
		datos["radio_voices"] = bool(config.get_value("audio", "radio_voices", true))
		datos["acciones_modo"] = str(config.get_value("ui", "acciones_modo", "emergentes"))
	return datos


## Cambia un solo valor del archivo de preferencias sin tocar los demás.
static func guardar(seccion: String, clave: String, valor: Variant) -> void:
	var config := ConfigFile.new()
	config.load(PREFERENCIAS)
	config.set_value(seccion, clave, valor)
	config.save(PREFERENCIAS)


## Aplica el volumen y el silencio guardados al bus principal (el menú y la misión lo comparten).
static func aplicar_audio() -> void:
	var datos := preferencias()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(float(datos["volume"]), 0.0001)))
	AudioServer.set_bus_mute(0, bool(datos["muted"]))


## Tamaños de ventana ofrecidos (la imagen del juego se escala sola a cualquiera de ellos).
const TAMANOS_VENTANA: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(3200, 1800), Vector2i(3840, 2160)]
## Margen que se reserva para la barra de título y los bordes del sistema.
const MARGEN_VENTANA := Vector2i(16, 80)


## Tamaños que caben en la pantalla donde está la ventana. En la web decide el navegador, así que no se ofrece ninguno.
static func tamanos_disponibles() -> Array[Vector2i]:
	var libres: Array[Vector2i] = []
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return libres
	var util := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for t in TAMANOS_VENTANA:
		if t.x <= util.x - MARGEN_VENTANA.x and t.y <= util.y - MARGEN_VENTANA.y:
			libres.append(t)
	if libres.is_empty():
		libres.append(TAMANOS_VENTANA[0])
	return libres


## Tamaño de ventana y pantalla completa se guardan y se leen solo aquí («visual»: window_size y fullscreen), así el
## menú y la pausa del juego no se contradicen y lo elegido sigue igual al cerrar y abrir.

## Pone la ventana en modo ventana con ese tamaño, la centra en su pantalla y lo guarda (sale de pantalla completa).
static func poner_tamano_ventana(t: Vector2i) -> void:
	guardar("visual", "window_size", t)
	guardar("visual", "fullscreen", false)
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_ajustar_ventana(t)
	# Al salir de pantalla completa Windows devuelve la ventana a su tamaño anterior un cuadro después, y eso
	# deshacía el cambio: se vuelve a aplicar en el cuadro siguiente.
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol != null:
		arbol.process_frame.connect(func() -> void: _ajustar_ventana(t), CONNECT_ONE_SHOT)


static func _ajustar_ventana(t: Vector2i) -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return  # entretanto se eligió pantalla completa
	DisplayServer.window_set_size(t)
	var pantalla := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	@warning_ignore("integer_division")
	var pos := pantalla.position + (pantalla.size - t) / 2
	DisplayServer.window_set_position(Vector2i(pos.x, maxi(pantalla.position.y, pos.y - 12)))


## Pantalla completa a la resolución nativa del monitor (el modo de Godot la usa sola) o vuelta a la ventana
## con el último tamaño elegido. Lo guarda.
static func poner_pantalla_completa(activa: bool) -> void:
	guardar("visual", "fullscreen", activa)
	if DisplayServer.get_name() == "headless":
		return
	if activa:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	var t: Vector2i = preferencias()["window_size"]
	if t != Vector2i.ZERO and t in tamanos_disponibles():  # en la web no hay tamaños: decide el navegador
		poner_tamano_ventana(t)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Si el juego está (o debe estar) en pantalla completa. En la web manda el navegador (se sale con Esc), así que se
## mira la ventana; en el escritorio, lo guardado.
static func en_pantalla_completa() -> bool:
	if OS.has_feature("web"):
		return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	return bool(preferencias()["fullscreen"])


## Resolución nativa del monitor donde está la ventana.
static func resolucion_nativa() -> Vector2i:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())


## Aplica al arrancar lo guardado: pantalla completa, o el tamaño de ventana si todavía cabe en la pantalla.
static func aplicar_ventana() -> void:
	var datos := preferencias()
	if bool(datos["fullscreen"]) and not OS.has_feature("web"):  # el navegador no deja entrar sin un clic
		poner_pantalla_completa(true)
		return
	var t: Vector2i = datos["window_size"]
	if t != Vector2i.ZERO and t in tamanos_disponibles():
		poner_tamano_ventana(t)


## Fila de botones con los tamaños disponibles y «Nativa» (pantalla completa a la resolución del monitor); al elegir
## uno lo aplica y lo guarda, y luego llama a «al_cambiar». El marcado sale de lo guardado, no del tamaño que tenga
## la ventana en ese instante (el cambio llega un cuadro después).
static func botones_tamano(fila: Control, al_cambiar: Callable = Callable()) -> void:
	var libres := tamanos_disponibles()
	if libres.is_empty():
		return
	var grupo := ButtonGroup.new()
	var datos := preferencias()
	var completa := en_pantalla_completa()
	var actual: Vector2i = datos["window_size"]
	if actual == Vector2i.ZERO:
		actual = DisplayServer.window_get_size()
	for t in libres:
		var b := Button.new()
		b.text = "%d×%d" % [t.x, t.y]
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size = Vector2(98, 40)
		b.button_pressed = not completa and t == actual
		b.pressed.connect(func() -> void:
			poner_tamano_ventana(t)
			if al_cambiar.is_valid():
				al_cambiar.call())
		fila.add_child(b)
	var nativa := Button.new()
	nativa.text = texto_nativa(resolucion_nativa())
	nativa.toggle_mode = true
	nativa.button_group = grupo
	nativa.custom_minimum_size = Vector2(98, 40)
	nativa.button_pressed = completa
	nativa.pressed.connect(func() -> void:
		poner_pantalla_completa(true)
		if al_cambiar.is_valid():
			al_cambiar.call())
	fila.add_child(nativa)


## «Nativa · 2560×1440». Sin traducciones cargadas (el texto no trae los dos %d), solo la resolución.
static func texto_nativa(r: Vector2i) -> String:
	var plantilla := TranslationServer.translate("M_SET_NATIVE")
	return plantilla % [r.x, r.y] if plantilla.count("%d") == 2 else "%d×%d" % [r.x, r.y]
