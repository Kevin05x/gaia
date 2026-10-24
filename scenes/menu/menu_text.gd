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
		"M_CTRL_F1": "F1  ·  F3",
		"M_CTRL_F1_D": "Ayuda y rendimiento.",
		"M_CREDITS_TITLE": "Créditos",
		"M_CREDITS_TEAM": "Equipo GAIA",
		"M_CREDITS_ROLES": "Kevin: simulación, datos, taller y publicación\nAmner: mundo 3D, interfaz, HUD, informe y sonido",
		"M_CREDITS_DATA": "Datos y ciencia",
		"M_CREDITS_DATA_D": "Imágenes y datos públicos de la NASA (images-api.nasa.gov, api.nasa.gov). Escenario inspirado en el cráter Jezero, Marte.",
		"M_CREDITS_ART": "Arte",
		"M_CREDITS_ART_D": "El logotipo y las pantallas de menú y de carga se generaron con inteligencia artificial en Canva. Tipografías Inter y Space Grotesk (licencia OFL). Modelos y texturas del juego, generados por código.",
		"M_CREDITS_MUSIC": "Música",
		"M_CREDITS_MUSIC_D": "Música y sonido originales del juego, sintetizados por código.",
		"M_CREDITS_ENGINE": "Hecho con Godot Engine 4.7 (MIT).",
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
		"M_CTRL_F1": "F1  ·  F3",
		"M_CTRL_F1_D": "Help and performance.",
		"M_CREDITS_TITLE": "Credits",
		"M_CREDITS_TEAM": "GAIA team",
		"M_CREDITS_ROLES": "Kevin: simulation, data, workshop and release\nAmner: 3D world, interface, HUD, report and sound",
		"M_CREDITS_DATA": "Data and science",
		"M_CREDITS_DATA_D": "Public NASA images and data (images-api.nasa.gov, api.nasa.gov). Setting inspired by Jezero crater, Mars.",
		"M_CREDITS_ART": "Art",
		"M_CREDITS_ART_D": "The logo and the menu and loading screens were generated with artificial intelligence in Canva. Inter and Space Grotesk typefaces (OFL license). The game's models and textures are generated by code.",
		"M_CREDITS_MUSIC": "Music",
		"M_CREDITS_MUSIC_D": "Original game music and sound, synthesized by code.",
		"M_CREDITS_ENGINE": "Made with Godot Engine 4.7 (MIT).",
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
		var catalogo = preload("res://scenes/b/i18n/catalog.gd").TABLES
		for idioma in catalogo:
			var traduccion := Translation.new()
			traduccion.locale = idioma
			for clave in catalogo[idioma]:
				traduccion.add_message(clave, catalogo[idioma][clave])
			TranslationServer.add_translation(traduccion)
		_instaladas = true
	TranslationServer.set_locale(String(preferencias().get("language", "es")))
	aplicar_audio()


## Lee las preferencias guardadas con sus valores por defecto.
static func preferencias() -> Dictionary:
	var datos := {"language": "es", "volume": 0.65, "muted": false, "quality": true, "tutorial": true}
	var config := ConfigFile.new()
	if config.load(PREFERENCIAS) == OK:
		datos["language"] = config.get_value("ui", "language", "es")
		datos["volume"] = config.get_value("audio", "volume", 0.65)
		datos["muted"] = config.get_value("audio", "muted", false)
		datos["quality"] = config.get_value("visual", "quality", true)
		datos["tutorial"] = config.get_value("ui", "tutorial", true)
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
