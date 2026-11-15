extends CanvasLayer
## Complejo de lanzamiento en la Tierra: el primer panorama de la partida.
##
## El rover espera sobre la plataforma **mirando a los lanzadores**: su frente apunta siempre al sitio
## del horizonte donde se levanta el cohete, antes y después de elegirlo. Abajo, el manifiesto de
## lanzadores en fila horizontal. Al marcar uno, se monta en el horizonte delante del rover; al pulsar
## el mando de abordaje, el rover **rueda hasta la mesa de lanzamiento y entra por la escotilla**, y solo
## cuando termina esa animación se manda el cohete a la simulación y toma el relevo el hangar
## (`scenes/b/workshop.gd`), donde se monta lo que va dentro.
##
## Solo presenta el bloque "workshop" del snapshot y envía la orden design_add del cohete elegido.
## No calcula costos, masas ni validez: eso lo hace la simulación.
##
## Interfaz: nada de tarjetas redondeadas ni paneles con sombra; es una consola de pista. Chapa de
## acero con las esquinas cortadas, corchetes de encuadre, reglillas de marcas y franjas de
## precaución, todo dibujado a mano (`scenes/b/consola.gd`).

const UI := preload("res://scenes/b/ui_style.gd")
const Graficos := preload("res://scenes/b/graficos.gd")
const Consola := preload("res://scenes/b/consola.gd")
const RoverNasa := preload("res://scenes/b/rover_nasa.gd")
const ModelosEquipo := preload("res://scenes/b/modelos_equipo.gd")

signal command(command: String, payload: Dictionary)
signal options_requested
## El techo ya está abierto y el cohete se fue: sigue la secuencia de lanzamiento y crucero.
signal despegue_terminado(diseno: Dictionary)

## Paleta de la Tierra: cielo frío y acero, para que contraste con el naranja de Marte.
const SKY_TOP := Color("12263C")
const SKY_HORIZON := Color("D98A4F")
const GROUND := Color("2A2A2E")

const CARD_SIZE := Vector2(190, 116)
const CARD_GAP := 10.0
const RIEL_SIZE := Vector2(818, 146)
const MARGEN := 20.0

## Posiciones del panorama, en metros (escala 1:1 del proyecto).
## El rover espera en primer plano, de espaldas a la cámara y de cara al horizonte.
## El rover va bastante por delante de la cámara: pegado a ella se salía del cuadro por la
## izquierda y no se le veía entero. Así queda en primer plano, a un lado, con el cohete delante.
const ROVER_POS := Vector3(-6.2, 0.0, -13.0)
const COHETE_POS := Vector3(2.0, 0.0, -115.0)
const CAMARA_CASA := Vector3(1.6, 3.4, 12.0)
const CAMARA_ENTRADA := Vector3(15.0, 2.2, 22.0)
const CAMARA_MIRA := Vector3(-0.8, 16.0, -40.0)
## Fondo ilustrado del complejo. Si el archivo no está, se usa el cielo por código y el panorama
## sigue funcionando (igual que ModelosEquipo con los .glb que aún no llegaron).
const FONDO := "res://assets/menu/plataforma_tierra.jpg"
const DURACION_ENTRADA := 2.2  ## s de la entrada dinámica de cámara
const DURACION_APARICION := 3.6  ## s que tardan las grúas en montar un cohete sin animación propia
const DURACION_ANIM_MAX := 9.0  ## s: tope por si un .glb trae una animación larguísima
const DURACION_ABORDAJE := 3.8  ## s del recorrido del rover hasta la escotilla
const DURACION_DESPEGUE := 8.0  ## s del despegue entero: techo que se aparta y cohete que sube
const PARTE_TECHO := 0.52  ## qué parte del despegue tarda el techo en abrirse del todo

## Edificio de montaje (modelo del equipo). Medidas tomadas del propio archivo, en sus unidades:
## 28 m de alto libre hasta las cerchas, 53 m de suelo por delante de la zona de montaje, 25,3 m
## de media anchura y la zona de montaje centrada en z = −16,2.
const HANGAR := "res://assets/modelos/hangar_gaia.glb"
const HANGAR_ALTO_UTIL := 21.0
const HANGAR_FONDO_LIBRE := 53.0
const HANGAR_SEMIANCHO := 25.3
const HANGAR_BASE := Vector3(0.0, 0.0, -16.2)
## Lo que trae el modelo y aquí sobra: su cohete (lo pone el jugador), sus rovers y su personal (el
## rover es el del juego), su base de lanzamiento (la pone `_build_mesa` con la escotilla) y su
## cielo (se ve el del panorama cuando el techo se abre).
const HANGAR_FUERA: Array[String] = ["Cohete", "Propulsores", "Motores", "Toberas", "Juntas cohete",
	"Juntas propulsores", "Revestimiento cohete", "Tornillos cohete", "Paneles del cohete",
	"Sensores cohete", "Anclajes cohete", "Anclajes de propulsores", "Brazos estabilizadores",
	"Rover delantero", "Rover auxiliar", "Personal tecnico", "Base de lanzamiento", "Cielo exterior"]
const HANGAR_TECHO: Array[String] = ["Cerchas del techo", "Ventanales techo", "Reflectores techo"]

var root: Control
var snapshot: Dictionary = {}
var elegido := ""  ## id del cohete marcado en pantalla (aún sin confirmar a la simulación)

var _signature := ""
var _cards: HBoxContainer
var _riel  ## Riel: chapa del manifiesto (clase interna, sin tipo para poder leer sus propiedades)
var _bloque  ## Bloque: título
var _lectura  ## Lectura: presupuesto
var _estado  ## Estado: tira de fase
var _leyenda  ## Leyenda: rótulo de pie
var _confirmar: Button
var _camera: Camera3D
var _rover: Node3D
var _ruedas: Array[Node3D] = []
var _radio_rueda := 0.26
var _cohete: Node3D
var _cohete_alto := 40.0
var _mesa: Node3D
var _mesa_alto := 2.0
var _rampa: MeshInstance3D  ## rampa de acceso: del suelo (pie) al borde de la cubierta (cima)
var _rampa_pie_z := 10.0  ## z local de la mesa donde la rampa toca el suelo
var _rampa_cima_z := 6.0  ## z local de la mesa donde la rampa llega a la cubierta
var _puerta: Node3D  ## escotilla iluminada de la mesa de lanzamiento, por donde entra el rover
var _puerta_luz: OmniLight3D
var _ascensor: Node3D
var _secciones: Array[Node3D] = []  ## tramos del cohete, de abajo arriba; cada uno con meta "y_final"
var _brazos: Array[Node3D] = []  ## brazos de las dos torres de servicio
var _chispas: Node3D
var _gruas: Node3D
var _anim: AnimationPlayer  ## animación de armado que trae el propio .glb, si la trae
var _anim_nombre := ""
var _mira_y := 6.0  ## altura a la que mira la cámara; sube con el cohete elegido
var _chispas_t := 0.0
var _con_fondo := false  ## true si la ilustración del complejo está en el proyecto
var _t := 0.0  ## reloj del panorama (entrada de cámara)
var _t_eleccion := -1.0  ## cuándo se marcó el cohete (−1: ninguno)
var _t_abordaje := -1.0  ## cuándo empezó el abordaje (−1: aún no)
var _t_salida := -1.0  ## cuándo empezó la salida del cohete, al volver del hangar (−1: aún no)
var _t_despegue := -1.0  ## cuándo empezó el despegue (−1: aún no)
var _diseno_despegue: Dictionary = {}
var _hangar: Node3D  ## edificio de montaje, si el modelo está en el proyecto
var _con_hangar := false
var _techo_izq: Node3D  ## las dos hojas del techo, que se apartan para dejar salir al cohete
var _techo_der: Node3D
var _techo := 0.0  ## 0 cerrado, 1 abierto del todo
var _techo_abierto_m := 20.0
var _llama: Node3D
var _clave: SpotLight3D  ## luz principal sobre el cohete
var _contra: OmniLight3D  ## contraluz que le dibuja el borde
var _abordado := false  ## true cuando el abordaje terminó y ya se mandó la orden
var _recomendado_marcado := false  ## el cohete recomendado se marca solo la primera vez que se entra
var _names: Dictionary = {}
var _alto_elegido := 0.0


func _ready() -> void:
	layer = 5  ## entre el hangar (4) y la secuencia de lanzamiento (9)
	visible = false
	build()


func build() -> void:
	if is_instance_valid(root):
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_panorama()
	_velos()
	_build_consola()


## Degradados oscuros arriba y abajo: el texto claro se lee sobre cualquier fondo, también cuando
## el panorama pase a ser una ilustración. Sin esto el cielo blanquea los títulos.
func _velos() -> void:
	for arriba in [true, false]:
		var velo := TextureRect.new()
		velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var grad := Gradient.new()
		grad.set_color(0, Color(0.02, 0.04, 0.07, 0.85 if arriba else 0.0))
		grad.set_color(1, Color(0.02, 0.04, 0.07, 0.0 if arriba else 0.9))
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = Vector2(0, 1)
		tex.width = 8
		tex.height = 256
		velo.texture = tex
		velo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		velo.stretch_mode = TextureRect.STRETCH_SCALE
		velo.anchor_left = 0.0
		velo.anchor_right = 1.0
		if arriba:
			velo.anchor_top = 0.0
			velo.anchor_bottom = 0.0
			velo.offset_bottom = 250
		else:
			velo.anchor_top = 1.0
			velo.anchor_bottom = 1.0
			velo.offset_top = -300
		root.add_child(velo)


# ------------------------------------------------------------------ panorama 3D


func _material(color: Color, rugosidad := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	return m


func _build_panorama() -> void:
	_con_fondo = ResourceLoader.exists(FONDO)
	if _con_fondo:
		var lamina := TextureRect.new()
		lamina.texture = load(FONDO) as Texture2D
		lamina.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lamina.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		lamina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(lamina)
	var contenedor := SubViewportContainer.new()
	contenedor.stretch = true
	contenedor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contenedor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(contenedor)
	var vista := SubViewport.new()
	vista.own_world_3d = true
	vista.msaa_3d = Viewport.MSAA_2X
	vista.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	contenedor.add_child(vista)

	# Cielo de la Tierra: azul arriba, pálido en el horizonte.
	var cielo := ProceduralSkyMaterial.new()
	cielo.sky_top_color = SKY_TOP
	cielo.sky_horizon_color = SKY_HORIZON
	cielo.ground_bottom_color = GROUND.darkened(0.35)
	cielo.ground_horizon_color = SKY_HORIZON
	cielo.sun_angle_max = 12.0
	var entorno := Environment.new()
	if _con_fondo:
		vista.transparent_bg = true
		entorno.background_mode = Environment.BG_CLEAR_COLOR
	else:
		entorno.background_mode = Environment.BG_SKY
		entorno.sky = Sky.new()
		entorno.sky.sky_material = cielo
	entorno.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	entorno.ambient_light_energy = 0.62
	# Acabado de la imagen. ACES da un contraste más de película que el filmico, y el brillo es lo
	# que hace que las luces del hangar, la escotilla y la llama se vean encendidas y no pintadas.
	# Todo lo caro va detrás del ajuste «post», que el jugador puede apagar (Baja).
	entorno.tonemap_mode = Environment.TONE_MAPPER_ACES
	entorno.tonemap_white = 1.35
	var ajustes := Graficos.cargar()
	if bool(ajustes.get("post", true)):
		entorno.glow_enabled = true
		entorno.glow_intensity = 0.45
		entorno.glow_bloom = 0.12
		entorno.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		entorno.glow_hdr_threshold = 1.1
		entorno.ssao_enabled = int(ajustes.get("sombras", 1)) > 0
		entorno.ssao_intensity = 1.6
		entorno.ssao_radius = 3.0
		entorno.adjustment_enabled = true
		entorno.adjustment_contrast = 1.06
		entorno.adjustment_saturation = 1.04
	entorno.fog_enabled = true
	entorno.fog_light_color = SKY_HORIZON
	entorno.fog_density = 0.00032  # neblina de distancia: separa el cohete del fondo sin velarlo
	var mundo := WorldEnvironment.new()
	mundo.environment = entorno
	vista.add_child(mundo)

	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-34, 128, 0)
	sol.light_color = Color("FFD2A0")
	sol.light_energy = 1.5
	sol.shadow_enabled = int(Graficos.cargar().get("sombras", 1)) > 0
	sol.shadow_blur = 1.5
	sol.directional_shadow_max_distance = 420.0
	vista.add_child(sol)

	_camera = Camera3D.new()
	_camera.fov = 45
	_camera.far = 900.0
	vista.add_child(_camera)
	_camera.position = CAMARA_ENTRADA
	_camera.look_at(_punto_de_mira())

	_cohete = Node3D.new()  # se llena al elegir
	_cohete.position = COHETE_POS
	_cohete.visible = false
	vista.add_child(_cohete)
	_con_hangar = _build_hangar_modelo(vista)
	if not _con_fondo and not _con_hangar:
		_build_suelo(vista)
	if _con_hangar:
		_luces_de_nave(vista)
	_mesa = Node3D.new()
	_mesa.visible = false  # la plataforma de servicio aparece con el cohete, no antes
	vista.add_child(_mesa)
	_gruas = Node3D.new()
	_gruas.visible = false
	vista.add_child(_gruas)

	_rover = RoverNasa.crear()  # el Perseverance real a escala 1:1 (o el rover de bloques si falta el modelo)
	if _rover == null:
		_rover = load("res://scenes/b/assets/models/rover.tscn").instantiate()
	_rover.position = ROVER_POS
	vista.add_child(_rover)
	_radio_rueda = float(_rover.get_meta("radio_rueda", 0.26))
	_buscar_ruedas(_rover)
	_mirar_al_cohete()  # de cara al horizonte donde se levantarán los lanzadores

	_build_mesa()
	_encuadrar_hangar()  # sin cohete elegido, la nave se ve a la escala de una bancada media
	_build_chispas(vista)
	_build_llama(vista)
	_luces_del_cohete(vista)


## Plataforma de hormigón y llanura alrededor. Nada de relieve: el protagonista es el horizonte.
func _build_suelo(vista: SubViewport) -> void:
	var llanura := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(1400, 1400)
	llanura.mesh = plano
	llanura.material_override = _material(GROUND)
	vista.add_child(llanura)

	var losa := MeshInstance3D.new()
	var caja := BoxMesh.new()
	caja.size = Vector3(16, 0.3, 16)
	losa.mesh = caja
	losa.material_override = _material(GROUND.lightened(0.12), 0.65)
	losa.position = Vector3(ROVER_POS.x, 0.15, ROVER_POS.z)
	vista.add_child(losa)

	# Calzada de la plataforma al cohete: marca por dónde va a rodar el rover al abordar.
	var calzada := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(5.0, 0.12, 320.0)
	calzada.mesh = cm
	calzada.material_override = _material(GROUND.lightened(0.06), 0.8)
	calzada.position = Vector3(COHETE_POS.x, 0.06, -140.0)
	vista.add_child(calzada)


## Guarda las ruedas con nombre del rover para hacerlas girar durante el abordaje.
func _buscar_ruedas(n: Node) -> void:
	if n is Node3D and str(n.name).begins_with("Wheel"):
		_ruedas.append(n as Node3D)
	for h in n.get_children():
		_buscar_ruedas(h)


## El rover siempre de cara al sitio del horizonte donde está (o aparecerá) el cohete.
func _mirar_al_cohete() -> void:
	if not is_instance_valid(_rover):
		return
	var destino := COHETE_POS
	if is_instance_valid(_cohete):
		destino = _cohete.position
	var blanco := Vector3(destino.x, _rover.position.y, destino.z)
	if blanco.distance_to(_rover.position) < 0.5:
		return
	_rover.look_at(blanco)  # el frente del rover del juego es −z, igual que look_at
	_rover.rotation.x = 0.0
	_rover.rotation.z = 0.0


## Mesa de lanzamiento bajo el cohete, con la escotilla iluminada por la que entra el rover y el
## hueco del ascensor que lo sube. Se rehace con cada cohete: un Saturno V necesita una mesa mayor.
func _build_mesa() -> void:
	for hijo in _mesa.get_children():
		_mesa.remove_child(hijo)
		hijo.queue_free()
	_puerta = null
	_puerta_luz = null
	_ascensor = null
	var lado: float = clampf(_cohete_alto * 0.26, 11.0, 28.0)
	_mesa_alto = clampf(_cohete_alto * 0.035, 1.8, 4.2)
	var base := Vector3(COHETE_POS.x, 0.0, _cohete.position.z if is_instance_valid(_cohete) else COHETE_POS.z)
	_mesa.position = base

	var losa := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(lado, _mesa_alto, lado)
	losa.mesh = lm
	losa.material_override = _material(Color("3B4149"), 0.75)
	losa.position = Vector3(0, _mesa_alto * 0.5, 0)
	_mesa.add_child(losa)

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pata := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(lado * 0.1, _mesa_alto * 1.1, lado * 0.1)
			pata.mesh = pm
			pata.material_override = _material(Color("2A2F35"), 0.8)
			pata.position = Vector3(sx * lado * 0.42, _mesa_alto * 0.45, sz * lado * 0.42)
			_mesa.add_child(pata)

	# Rampa de acceso por la cara que mira a la cámara: su cara de arriba va justo del suelo (pie) al
	# borde de la cubierta (cima), y el rover sube por ella (ver _altura_de_la_rampa).
	var recorrido := _mesa_alto * 2.6
	var pendiente := atan2(_mesa_alto, recorrido)
	var grosor := 0.3
	_rampa_cima_z = lado * 0.5
	_rampa_pie_z = lado * 0.5 + recorrido
	_rampa = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(5.2, grosor, Vector2(recorrido, _mesa_alto).length())
	_rampa.mesh = rm
	_rampa.material_override = _material(Color("4A5057"), 0.8)
	_rampa.rotation.x = pendiente
	var normal := Vector3(0.0, cos(pendiente), sin(pendiente))  # la cara de arriba, ya inclinada
	_rampa.position = Vector3(0, _mesa_alto * 0.5, (_rampa_cima_z + _rampa_pie_z) * 0.5) - normal * grosor * 0.5
	_mesa.add_child(_rampa)

	# Escotilla: hueco oscuro con marco emisivo sobre la cubierta, al final de la rampa, de la altura
	# justa para que entre el rover (2,2 m).
	_puerta = Node3D.new()
	_puerta.position = Vector3(0, _mesa_alto, lado * 0.5 - 0.4)
	_mesa.add_child(_puerta)
	var hueco := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(4.4, 3.4, 0.3)
	hueco.mesh = hm
	hueco.material_override = _material(Color("07090C"), 0.9)
	hueco.position = Vector3(0, 1.7, 0)
	_puerta.add_child(hueco)
	var marco := StandardMaterial3D.new()
	marco.albedo_color = Color("F0C079")
	marco.emission_enabled = true
	marco.emission = Color("F0A040")
	marco.emission_energy_multiplier = 2.2
	for par in [[Vector3(0, 3.45, 0), Vector3(4.8, 0.2, 0.34)], [Vector3(-2.3, 1.7, 0), Vector3(0.2, 3.5, 0.34)],
			[Vector3(2.3, 1.7, 0), Vector3(0.2, 3.5, 0.34)]]:
		var barra := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = par[1]
		barra.mesh = bm
		barra.material_override = marco
		barra.position = par[0]
		_puerta.add_child(barra)
	_puerta_luz = OmniLight3D.new()
	_puerta_luz.light_color = Color("FFC071")
	_puerta_luz.light_energy = 0.55  # un rescoldo; se aviva cuando el rover entra (ver _abordar)
	_puerta_luz.omni_range = 8.0
	_puerta_luz.position = Vector3(0, 2.2, 1.6)
	_puerta.add_child(_puerta_luz)

	# Ascensor: una luz que sube por el costado del cohete cuando el rover ya entró.
	_ascensor = Node3D.new()
	_ascensor.visible = false
	_mesa.add_child(_ascensor)
	var jaula := MeshInstance3D.new()
	var jm := BoxMesh.new()
	jm.size = Vector3(2.0, 2.2, 2.0)
	jaula.mesh = jm
	var jmat := StandardMaterial3D.new()
	jmat.albedo_color = Color("FFD79A")
	jmat.emission_enabled = true
	jmat.emission = Color("FFB04A")
	jmat.emission_energy_multiplier = 3.0
	jaula.material_override = jmat
	_ascensor.add_child(jaula)


## Cohete del horizonte, montado por partes. Usa el modelo del equipo si existe
## (assets/modelos/<id>.glb); si no, lo arma por código con una altura acorde a su capacidad.
## Cada pieza queda registrada en _secciones con su altura final: las grúas las van colocando.
func _poner_cohete(id: String, capacidad: float, alto_real: float = 0.0) -> void:
	for hijo in _cohete.get_children():
		_cohete.remove_child(hijo)
		hijo.queue_free()
	_secciones.clear()
	_anim = null
	_anim_nombre = ""
	_cohete_alto = 30.0 + capacidad / 40.0  # 600 kg -> 45 m; 1.800 kg -> 75 m
	if _poner_modelo(id, alto_real):
		_secciones[0].set_meta("y_final", _secciones[0].position.y)
		_encuadrar()
		return
	var radio := _cohete_alto * 0.055
	var alto_cuerpo := _cohete_alto * 0.82
	# Tres tramos de fuselaje: se ven llegar uno a uno, como en el montaje real.
	var tramos := 3
	for t in range(tramos):
		var tramo := MeshInstance3D.new()
		var cil := CylinderMesh.new()
		cil.top_radius = radio
		cil.bottom_radius = radio
		cil.height = alto_cuerpo / float(tramos)
		tramo.mesh = cil
		tramo.material_override = _material(Color("E8E4DC") if t % 2 == 0 else Color("D5CFC4"), 0.5)
		tramo.position = Vector3(0, cil.height * (0.5 + t), 0)
		_cohete.add_child(tramo)
		_secciones.append(tramo)
	var punta := MeshInstance3D.new()
	var cono := CylinderMesh.new()
	cono.top_radius = 0.0
	cono.bottom_radius = radio
	cono.height = _cohete_alto * 0.18
	punta.mesh = cono
	punta.material_override = _material(Color("C8502F"), 0.55)
	punta.position = Vector3(0, alto_cuerpo + cono.height * 0.5, 0)
	_cohete.add_child(punta)
	_secciones.append(punta)
	# Propulsores laterales solo en los de más capacidad: se ve de un vistazo que es más grande.
	if capacidad >= 900.0:
		for lado in [-1.0, 1.0]:
			var lateral := MeshInstance3D.new()
			var cil2 := CylinderMesh.new()
			cil2.top_radius = radio * 0.45
			cil2.bottom_radius = radio * 0.45
			cil2.height = alto_cuerpo * 0.6
			lateral.mesh = cil2
			lateral.material_override = _material(Color("D8D2C6"), 0.5)
			lateral.position = Vector3(lado * radio * 1.4, cil2.height * 0.5, 0)
			_cohete.add_child(lateral)
			_secciones.append(lateral)
	for s in _secciones:
		s.set_meta("y_final", s.position.y)
	_encuadrar()


## Coloca el .glb del cohete (assets/modelos/<id>.glb) y lo normaliza, porque los modelos no
## siempre llegan como pide el contrato de ARTE_Y_LICENCIAS.md. Los cuatro llegaron distintos:
##  · con escala no uniforme (achatados en Y): se iguala a su componente mayor, o al estirarlos a la
##    altura real saldrían rechonchos;
##  · tumbados (más largos en Z que en Y): se ponen de pie;
##  · en centímetros (más de 200 unidades de alto) y descentrados: se pasan a metros, se centran en
##    X/Z y se apoyan en y = 0.
## Se conserva su tamaño real: la escala del proyecto es 1:1 (docs/ESCALAS.md). Si el .glb trae su
## propia animación de armado, se guarda para reproducirla en vez del montaje por grúas.
## Devuelve false si no hay modelo, y entonces el cohete se dibuja por código.
func _poner_modelo(id: String, alto_real: float) -> bool:
	var ruta := "res://assets/modelos/%s.glb" % id
	if not ResourceLoader.exists(ruta):
		return false
	var escena := load(ruta) as PackedScene
	if escena == null:
		return false
	var modelo := escena.instantiate() as Node3D
	if modelo == null:
		return false
	_uniformar_escala(modelo)
	var pivote := Node3D.new()
	_cohete.add_child(pivote)
	pivote.add_child(modelo)
	# La animación del .glb se deja en su último fotograma para medir el cohete ya montado: si se
	# midiera con las piezas volando, la altura saldría de donde empiezan, no de donde acaban.
	_anim = _buscar_animacion(modelo)
	if _anim != null:
		_anim_nombre = str(_anim.get_animation_list()[0])
		if _anim.has_animation("Armado"):
			_anim_nombre = "Armado"
		_anim.play(_anim_nombre)
		_anim.seek(_anim.get_animation(_anim_nombre).length, true)
		_anim.pause()
	var caja := _caja(modelo, modelo.transform)
	if caja.size.y <= 0.0001 and caja.size.z <= 0.0001:
		pivote.queue_free()
		_anim = null
		return false
	if caja.size.z > caja.size.y * 1.5:  # tumbado sobre Z: de pie
		modelo.rotation.x = -PI / 2.0
		caja = _caja(modelo, modelo.transform)
	var escala := 1.0
	if alto_real > 0.0:
		escala = alto_real / caja.size.y  # a la altura real del lanzador (escala 1:1)
	elif caja.size.y > 200.0:
		escala = 0.01  # sin dato: se asume que venía en centímetros
	pivote.scale = Vector3.ONE * escala
	pivote.position = Vector3(-caja.get_center().x * escala, -caja.position.y * escala, -caja.get_center().z * escala)
	_cohete_alto = caja.size.y * escala
	_secciones.append(pivote)
	return true


## Iguala las escalas no uniformes a su componente mayor. El Delta II llegó achatado
## (0,6 × 0,5 × 0,6): estirado luego a su altura real quedaba más ancho de lo que es el lanzador de
## verdad. No se toca el archivo de arte, solo la copia cargada.
##
## **Las ramas con esqueleto se dejan como están.** En una malla con piel, la escala de los nodos de
## encima se cancela contra las poses de enlace, así que ya se dibuja sin deformar; cambiarla no la
## endereza, la rompe: al Titan IIIE le estiraba la altura un 50 % y se salía por arriba del cuadro.
func _uniformar_escala(n: Node) -> void:
	if n is Node3D and not _tiene_piel(n):
		var s: Vector3 = (n as Node3D).scale
		var m: float = maxf(s.x, maxf(s.y, s.z))
		if not is_equal_approx(s.x, s.y) or not is_equal_approx(s.y, s.z):
			(n as Node3D).scale = Vector3.ONE * m
	for h in n.get_children():
		_uniformar_escala(h)


## True si debajo de `n` (o en el propio `n`) hay una malla movida por un esqueleto.
func _tiene_piel(n: Node) -> bool:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if not mi.skeleton.is_empty() and mi.get_node_or_null(mi.skeleton) != null:
			return true
	for h in n.get_children():
		if _tiene_piel(h):
			return true
	return false


## Animación de armado del modelo. El equipo las llama «Armado», y Blender exporta además copias
## numeradas («Armado.001»…) que son la misma: se usa la que lleva el nombre limpio si está.
func _buscar_animacion(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer and not (n as AnimationPlayer).get_animation_list().is_empty():
		return n as AnimationPlayer
	for h in n.get_children():
		var encontrada := _buscar_animacion(h)
		if encontrada != null:
			return encontrada
	return null


## Cuánto dura el montaje: lo que dure la animación del propio modelo (con un tope), o el montaje
## por grúas si el .glb no trae ninguna.
func _duracion_montaje() -> float:
	if _anim != null and _anim.has_animation(_anim_nombre):
		return minf(_anim.get_animation(_anim_nombre).length, DURACION_ANIM_MAX)
	return DURACION_APARICION


## Punto al que mira la cámara: a la distancia del cohete, no a una fija, porque un Saturno V
## está mucho más lejos que un lanzador pequeño y si no se le apunta al cielo por encima.
func _punto_de_mira() -> Vector3:
	var z: float = _cohete.position.z if is_instance_valid(_cohete) else CAMARA_MIRA.z
	return Vector3(CAMARA_MIRA.x, _mira_y, z)


## Coloca el cohete a la distancia que lo deja entero en pantalla y rehace mesa y torres a su medida.
## Un Saturno V (110,6 m) necesita más distancia que un lanzador de 39 m para caber en el mismo cuadro.
func _encuadrar() -> void:
	_cohete.position = Vector3(COHETE_POS.x, 0.0, -maxf(_cohete_alto, 20.0) * 2.3)
	_mira_y = _cohete_alto * 0.34
	_build_mesa()
	_cohete.position.y = _mesa_alto  # el cohete se apoya sobre la mesa de lanzamiento
	_build_gruas()
	_encuadrar_hangar()
	_colocar_luces()
	_mirar_al_cohete()


## Caja que ocupan todas las mallas bajo `nodo`, en el espacio de su padre.
##
## Las mallas con esqueleto se miden aparte, y no es un capricho: en glTF, una malla con piel se
## dibuja en el sitio donde la dejan los huesos, y en la pose de reposo la escala de los nodos de
## encima **se cancela** contra las poses de enlace. Es decir, el Titan IIIE se ve a su tamaño de
## malla (19,4 m) aunque su «rig» venga con una escala de 0,4. Si se midiera arrastrando esa escala
## como con cualquier otro nodo, saldría casi la mitad de alto, y al estirarlo a su altura real el
## cohete se salía por arriba de la pantalla. Por eso aquí se mide con la transformación de la raíz
## del modelo, sin la cadena de en medio.
func _caja(nodo: Node3D, base: Transform3D) -> AABB:
	var total := AABB()
	var primera := true
	var pila: Array = [[nodo, base]]
	while not pila.is_empty():
		var par: Array = pila.pop_back()
		var n: Node = par[0]
		var t: Transform3D = par[1]
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var con_hueso := not mi.skeleton.is_empty() and mi.get_node_or_null(mi.skeleton) != null
			var caja := (base if con_hueso else t) * mi.mesh.get_aabb()
			total = caja if primera else total.merge(caja)
			primera = false
		for hijo in n.get_children():
			if hijo is Node3D:
				pila.append([hijo, t * (hijo as Node3D).transform])
	return total


## Dos torres de servicio con brazo articulado, una a cada lado del cohete. Los brazos se acercan
## al fuselaje mientras se monta y luego se retiran.
func _build_gruas() -> void:
	for hijo in _gruas.get_children():
		_gruas.remove_child(hijo)
		hijo.queue_free()
	_brazos.clear()
	var alto := _cohete_alto * 0.82
	var mat_acero := _material(Color("4A4F57"), 0.7)
	var mat_brazo := _material(Color("E0A33A"), 0.55)
	for lado in [-1.0, 1.0]:
		var torre := Node3D.new()
		torre.position = _cohete.position + Vector3(lado * _cohete_alto * 0.26, 0.0, _cohete_alto * 0.07)
		torre.position.y = 0.0
		_gruas.add_child(torre)
		var mastil := MeshInstance3D.new()
		var caja := BoxMesh.new()
		caja.size = Vector3(alto * 0.045, alto, alto * 0.045)
		mastil.mesh = caja
		mastil.material_override = mat_acero
		mastil.position = Vector3(0, alto * 0.5, 0)
		torre.add_child(mastil)
		for n in range(7):  # plataformas de servicio
			var plat := MeshInstance3D.new()
			var pcaja := BoxMesh.new()
			pcaja.size = Vector3(alto * 0.11, alto * 0.009, alto * 0.06)
			plat.mesh = pcaja
			plat.material_override = mat_acero
			plat.position = Vector3(-lado * alto * 0.03, alto * (0.12 + n * 0.12), 0)
			torre.add_child(plat)
		var brazo := Node3D.new()  # pivota hacia el cohete durante el montaje
		brazo.position = Vector3(0, alto * 0.45, 0)
		torre.add_child(brazo)
		var viga := MeshInstance3D.new()
		var vcaja := BoxMesh.new()
		vcaja.size = Vector3(alto * 0.2, alto * 0.018, alto * 0.018)
		viga.mesh = vcaja
		viga.material_override = mat_brazo
		viga.position = Vector3(-lado * alto * 0.1, 0, 0)
		brazo.add_child(viga)
		_brazos.append(brazo)


## Chispas de soldadura en el punto donde se está uniendo la sección.
func _build_chispas(vista: SubViewport) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FFD79A")
	mat.emission_enabled = true
	mat.emission = Color("FFB04A")
	mat.emission_energy_multiplier = 7.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_chispas = Node3D.new()
	_chispas.visible = false
	vista.add_child(_chispas)
	for i in range(14):
		var punto := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.32
		esfera.height = 0.64
		esfera.radial_segments = 6
		esfera.rings = 3
		punto.mesh = esfera
		punto.material_override = mat
		_chispas.add_child(punto)


## Escenario: el edificio de montaje. Es un modelo del equipo (assets/modelos/hangar_gaia.glb) y
## trae mucho más de lo que hace falta, así que al cargarlo se le quita lo que aquí sobra:
##  · **su cohete**, que se sustituye por el que eligió el jugador;
##  · sus dos rovers y su personal, porque el rover es el del juego;
##  · su base de lanzamiento, que la pone `_build_mesa()` a la medida del cohete y con la escotilla.
## El techo se aparta en dos mitades cuando llega el despegue (ver `_abrir_techo`).
##
## El edificio mide 28 m de alto y los lanzadores, de 39 a 110,6 m: no caben. Se escala al cohete
## elegido, como un edificio de montaje de verdad, que se construye a la medida de su cohete. Como
## la cámara ya encuadra cada lanzador igual (`_encuadrar`), el edificio se ve siempre del mismo
## tamaño en pantalla y la comparación entre cohetes la sigue dando la silueta del manifiesto.
func _build_hangar_modelo(vista: SubViewport) -> bool:
	if not ResourceLoader.exists(HANGAR):
		return false
	var escena := load(HANGAR) as PackedScene
	if escena == null:
		return false
	_hangar = escena.instantiate() as Node3D
	if _hangar == null:
		return false
	vista.add_child(_hangar)
	# Las mallas del modelo cuelgan de un nodo intermedio; las hojas del techo tienen que colgar del
	# mismo sitio o saldrían desplazadas.
	var dentro: Node = _hangar
	if _hangar.get_child_count() > 0 and _hangar.get_child(0) is Node3D:
		dentro = _hangar.get_child(0)
	_techo_izq = Node3D.new()
	_techo_der = Node3D.new()
	dentro.add_child(_techo_izq)
	dentro.add_child(_techo_der)
	_repasar_hangar(_hangar)
	return true


## Recorre el modelo: esconde lo que sobra y parte el techo en dos hojas que puedan apartarse.
func _repasar_hangar(n: Node) -> void:
	for h in n.get_children().duplicate():
		_repasar_hangar(h)
	if not (n is MeshInstance3D) or (n as MeshInstance3D).mesh == null:
		return
	# Ojo: Godot no admite barras en los nombres de nodo y las sustituye al importar, así que el
	# grupo se reconoce por cómo empieza el nombre, nunca comparándolo entero.
	var grupo := str(n.name)
	for fuera in HANGAR_FUERA:
		if grupo.begins_with(fuera):
			(n as MeshInstance3D).visible = false
			return
	for techo in HANGAR_TECHO:
		if grupo.begins_with(techo):
			_partir_techo(n as MeshInstance3D)
			return


## Parte una pieza del techo en dos hojas, izquierda y derecha, y cuelga cada una de su nodo.
## El modelo trae el techo como una sola malla por material, así que para que se abra «como un
## techo» hay que separarlo por triángulos; no hay otra forma sin tocar el archivo de arte.
func _partir_techo(mi: MeshInstance3D) -> void:
	var malla := mi.mesh
	var t := mi.transform
	for lado in [-1.0, 1.0]:
		var mitad := _mitad(malla, t, lado)
		if mitad == null:
			continue
		var copia := MeshInstance3D.new()
		copia.mesh = mitad
		copia.name = "%s_%s" % [mi.name, "izq" if lado < 0.0 else "der"]
		(_techo_izq if lado < 0.0 else _techo_der).add_child(copia)
	mi.visible = false


## Los triángulos de `malla` (ya en el espacio del hangar) cuyo centro cae del lado pedido en X.
func _mitad(malla: Mesh, t: Transform3D, lado: float) -> ArrayMesh:
	var salida := ArrayMesh.new()
	for s in range(malla.get_surface_count()):
		var a := malla.surface_get_arrays(s)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		if v.is_empty():
			continue
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(v.size()))
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nu := PackedVector2Array()
		var ni := PackedInt32Array()
		var mapa: Dictionary = {}
		for k in range(0, idx.size() - 2, 3):
			var centro := (t * v[idx[k]] + t * v[idx[k + 1]] + t * v[idx[k + 2]]) / 3.0
			if signf(centro.x) != lado and absf(centro.x) > 0.001:
				continue
			if absf(centro.x) <= 0.001 and lado < 0.0:
				continue  # los que caen justo en el eje van a una sola hoja
			for q in range(3):
				var o: int = idx[k + q]
				if not mapa.has(o):
					mapa[o] = nv.size()
					nv.append(t * v[o])
					nn.append((t.basis * (n[o] if o < n.size() else Vector3.UP)).normalized())
					nu.append(uv[o] if o < uv.size() else Vector2.ZERO)
				ni.append(mapa[o])
		if nv.is_empty():
			continue
		var arr: Array = []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = nv
		arr[Mesh.ARRAY_NORMAL] = nn
		arr[Mesh.ARRAY_TEX_UV] = nu
		arr[Mesh.ARRAY_INDEX] = ni
		salida.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		salida.surface_set_material(salida.get_surface_count() - 1, malla.surface_get_material(s))
	return salida if salida.get_surface_count() > 0 else null


## Coloca el edificio alrededor del cohete elegido: a su escala, con el suelo en y = 0 y su zona
## de montaje justo donde está el cohete. La escala sale de dos cosas que tienen que cumplirse a la
## vez: que el cohete quepa de alto y que la cámara quede **dentro** del edificio, no fuera del muro.
func _encuadrar_hangar() -> void:
	if not is_instance_valid(_hangar):
		return
	var por_alto := _cohete_alto / HANGAR_ALTO_UTIL
	var por_camara := (CAMARA_ENTRADA.z + 14.0 - _cohete.position.z) / HANGAR_FONDO_LIBRE
	var escala: float = maxf(por_alto, por_camara)
	_hangar.scale = Vector3.ONE * escala
	_hangar.position = Vector3(_cohete.position.x - HANGAR_BASE.x * escala, 0.0,
		_cohete.position.z - HANGAR_BASE.z * escala)
	_techo_abierto_m = HANGAR_SEMIANCHO * 0.92  # en unidades del modelo: el hangar ya lleva la escala
	_colocar_techo()


## Lleva las dos hojas del techo a donde toca según lo abierto que esté (0 cerrado, 1 abierto).
func _colocar_techo() -> void:
	if not is_instance_valid(_techo_izq):
		return
	var p := ease(clampf(_techo, 0.0, 1.0), 0.45)
	_techo_izq.position = Vector3(-_techo_abierto_m * p, _techo_abierto_m * p * 0.08, 0.0)
	_techo_der.position = Vector3(_techo_abierto_m * p, _techo_abierto_m * p * 0.08, 0.0)


# ------------------------------------------------------------------ consola
# Regla de esta pantalla: cuanto menos haya, mejor. Lo que se mira es el cohete y el rover; la
# consola solo pone lo justo para decidir, en cifras y rótulos de una palabra, nunca en párrafos,
# y sin una caja alrededor de cada cosa. Los rótulos van sueltos sobre el velo oscuro de los
# bordes; lo único enmarcado son las cuatro fichas, porque se pulsan.


func _build_consola() -> void:
	var marco := Marco.new()
	marco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(marco)

	_bloque = Bloque.new()
	_bloque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_bloque, "tl", 44, 38, 470, 58)
	root.add_child(_bloque)

	_lectura = Lectura.new()
	_lectura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_lectura, "tr", 26, 38, 250, 56)
	root.add_child(_lectura)

	_estado = Estado.new()
	_estado.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.place(_estado, "tc", 0, 44, 300, 24)
	root.add_child(_estado)

	if _con_fondo:
		_leyenda = Leyenda.new()
		_leyenda.texto = tr("AI_MARK")
		_leyenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UI.place(_leyenda, "bl", 26, 6, 420, 18)
		root.add_child(_leyenda)

	_riel = Riel.new()
	_riel.mouse_filter = Control.MOUSE_FILTER_IGNORE  # solo las fichas se pulsan
	UI.place(_riel, "br", 24, 20, RIEL_SIZE.x, RIEL_SIZE.y)
	root.add_child(_riel)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", int(CARD_GAP))
	_cards.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cards.offset_top = RIEL_SIZE.y - CARD_SIZE.y
	_riel.add_child(_cards)

	_confirmar = Mando.new()
	_confirmar.visible = false
	_confirmar.pressed.connect(_on_confirmar)
	UI.place(_confirmar, "br", 24, 20 + RIEL_SIZE.y + 14, 272, 48)
	root.add_child(_confirmar)
	_textos_consola()


## Reparte los textos traducidos por las piezas de la consola.
func _textos_consola() -> void:
	if is_instance_valid(_bloque):
		_bloque.etiqueta = tr("LP_TAG")
		_bloque.titulo = tr("LP_TITLE")
		_bloque.queue_redraw()
	if is_instance_valid(_riel):
		_riel.titulo = tr("LP_MANIFEST")
		_riel.regla = tr("LP_RULE")
		_riel.queue_redraw()
	if is_instance_valid(_confirmar):
		_confirmar.text = tr("LP_CONFIRM")


## Fila horizontal de lanzadores. Cada ficha: número, nombre real, silueta a escala y dos cifras.
func _rebuild_cards(taller: Dictionary) -> void:
	for hijo in _cards.get_children():
		_cards.remove_child(hijo)
		hijo.queue_free()
	var presupuesto := float(taller.get("totals", {}).get("budget_musd", 0.0))
	var alto_max := 1.0
	for categoria in taller.get("categories", []):
		if str(categoria.get("id", "")) != "cohetes":
			continue
		for pieza in categoria.get("parts", []):
			alto_max = maxf(alto_max, float(pieza.get("real_height_m", 0.0)))
	var indice := 0
	for categoria in taller.get("categories", []):
		if str(categoria.get("id", "")) != "cohetes":
			continue
		for pieza in categoria.get("parts", []):
			indice += 1
			_cards.add_child(_card(pieza, presupuesto, indice, alto_max))


func _card(pieza: Dictionary, presupuesto: float, indice: int = 1, alto_max: float = 1.0) -> Button:
	var id := str(pieza.get("id", ""))
	var capacidad: Variant = pieza.get("capacity_kg")
	var costo: Variant = pieza.get("cost_musd")
	var alto_real: Variant = pieza.get("real_height_m")
	var t := Tarjeta.new()
	t.custom_minimum_size = CARD_SIZE
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.indice = indice
	t.nombre = tr(str(pieza.get("name_key", "")))
	t.capacidad = float(capacidad) if capacidad != null else 0.0
	t.costo = float(costo) if costo != null else 0.0
	t.restante = presupuesto - t.costo
	t.alto = float(alto_real) if alto_real != null else 0.0
	t.alto_max = maxf(alto_max, 1.0)
	t.marcada = id == elegido
	# El dato real de la NASA que respalda la pieza, como ayuda al pasar el ratón.
	var referencia := str(pieza.get("ref_key", ""))
	if not referencia.is_empty():
		t.tooltip_text = tr(referencia)
	t.pressed.connect(_on_card.bind(id, t.capacidad, t.alto))
	return t


# ------------------------------------------------------------------ interacción


## Marca el cohete y lo monta en el horizonte. No se confirma hasta pulsar el mando de abordaje:
## así se ve delante del rover antes de entrar en él.
func _on_card(id: String, capacidad: float, alto_real: float = 0.0) -> void:
	if elegido == id or _t_abordaje >= 0.0:
		return
	elegido = id
	_alto_elegido = alto_real
	_t_eleccion = _t
	_poner_cohete(id, capacidad, alto_real)
	_cohete.visible = true
	_mesa.visible = true
	_gruas.visible = true
	_confirmar.visible = true
	_signature = ""  # fuerza el redibujo de las fichas con la nueva marca
	_rebuild_cards(snapshot.get("workshop", {}))


## Empieza el abordaje. La orden no sale aquí: sale cuando el rover ha entrado por la escotilla
## (ver _process), para que la animación se vea entera antes de pasar al hangar.
func _on_confirmar() -> void:
	if elegido.is_empty() or _t_abordaje >= 0.0:
		return
	_t_abordaje = _t
	_confirmar.disabled = true
	_confirmar.visible = false
	_cards.visible = false
	_riel.visible = false
	_bloque.visible = false  # el rover ya eligió: fuera el título y la explicación, queda la escena
	_montar(1.0, 0.0)  # el cohete ya está entero: se aborda uno montado


## El rover ya entró: ahora sí se manda el cohete a la simulación y el hangar toma el relevo.
func _fin_abordaje() -> void:
	if _abordado:
		return
	_abordado = true
	command.emit("design_add", {"part_id": elegido})


# ------------------------------------------------------------------ snapshot


func update_snapshot(s: Dictionary) -> void:
	snapshot = s
	var taller: Dictionary = s.get("workshop", {})
	var en_taller := str(s.get("phase", "")) == "workshop" and not taller.is_empty()
	# En cuanto la simulación confirma el cohete, el hangar toma el relevo.
	var sin_cohete := (taller.get("selection", {}).get("cohetes", []) as Array).is_empty()
	if _t_despegue >= 0.0:
		visible = true  # el despegue se ve entero aunque la fase ya haya cambiado
		return
	visible = en_taller and sin_cohete
	if not visible or not is_instance_valid(root):
		return
	# Se vuelve del hangar con «‹ Cambiar de cohete»: el rover está dentro, así que primero sale.
	if _abordado and _t_salida < 0.0:
		_empezar_salida()
	_names.clear()
	for categoria in taller.get("categories", []):
		for pieza in categoria.get("parts", []):
			_names[str(pieza["id"])] = str(pieza.get("name_key", ""))
	var firma := "%s|%s|%s" % [elegido, str(taller.get("totals")), TranslationServer.get_locale()]
	if firma == _signature:
		return
	_signature = firma
	_rebuild_cards(taller)
	_lectura.presupuesto = float(taller.get("totals", {}).get("budget_musd", 0))
	_lectura.queue_redraw()
	_marcar_recomendado(taller)


## La primera vez, la plataforma llega con el cohete recomendado del destino ya marcado (content/parts.json ›
## recomendada): basta con abordar o elegir otro. Al volver del hangar no se vuelve a marcar.
func _marcar_recomendado(taller: Dictionary) -> void:
	if _recomendado_marcado or not elegido.is_empty() or _t_abordaje >= 0.0 or _t_salida >= 0.0 or _abordado:
		return
	_recomendado_marcado = true
	for categoria in taller.get("categories", []):
		if str(categoria.get("id", "")) != "cohetes":
			continue
		for pieza in categoria.get("parts", []):
			if (pieza.get("recommended_for", []) as Array).has(Destino.id) and pieza.get("available", true):
				var capacidad: Variant = pieza.get("capacity_kg")
				var alto: Variant = pieza.get("real_height_m")
				_on_card(str(pieza["id"]), float(capacidad) if capacidad != null else 0.0, float(alto) if alto != null else 0.0)
				return


func rebuild() -> void:
	_signature = ""
	if is_instance_valid(root):
		_textos_consola()
		_rebuild_cards(snapshot.get("workshop", {}))


## El jugador cambió de idea en el hangar. El rover está dentro del cohete: sale por donde entró,
## vuelve rodando a su sitio y el cohete se retira del horizonte. Es el abordaje del revés.
func _empezar_salida() -> void:
	_t_salida = _t
	_abordado = false
	_t_abordaje = -1.0
	_confirmar.visible = false
	_riel.visible = false
	_bloque.visible = false
	_cohete.visible = true
	_mesa.visible = true
	_gruas.visible = true


## El rover ya está fuera y en su sitio: vuelta a la pantalla de elegir, sin nada marcado.
func _fin_salida() -> void:
	_t_salida = -1.0
	elegido = ""
	_t_eleccion = -1.0
	_alto_elegido = 0.0
	if is_instance_valid(_rover):
		_rover.position = ROVER_POS
		_rover.scale = Vector3.ONE
		_rover.visible = true
	_cohete.visible = false
	_mesa.visible = false
	_gruas.visible = false
	if is_instance_valid(_ascensor):
		_ascensor.visible = false
	_camera.position = CAMARA_CASA
	_mirar_al_cohete()
	_confirmar.disabled = false
	_confirmar.visible = false
	_cards.visible = true
	_riel.visible = true
	_bloque.visible = true
	_signature = ""  # que se rehagan las fichas sin ninguna marcada
	_rebuild_cards(snapshot.get("workshop", {}))


## ¿Puede esta pantalla enseñar el despegue? Solo con el edificio de montaje puesto y un cohete
## elegido; si falta el modelo, la secuencia de lanzamiento arranca directamente, como antes.
func puede_despegar() -> bool:
	return _con_hangar and not elegido.is_empty() and _t_despegue < 0.0


func despegando() -> bool:
	return _t_despegue >= 0.0


## Todo listo: se aparta el techo y el cohete se va. Al terminar avisa con `despegue_terminado`
## para que siga la secuencia de lanzamiento y crucero.
func despegar(diseno: Dictionary) -> void:
	if elegido.is_empty() or _t_despegue >= 0.0:
		return
	_diseno_despegue = diseno
	_t_despegue = _t
	visible = true
	_montar(1.0, 0.0)  # se despega con el cohete entero
	_cohete.visible = true
	_mesa.visible = true
	_gruas.visible = true
	_riel.visible = false
	_bloque.visible = false
	_confirmar.visible = false
	if is_instance_valid(_rover):
		_rover.visible = false  # el rover ya va dentro


## Un paso del despegue, con `d` de 0 a 1: primero se aparta el techo, luego el cohete sube por el
## hueco y la cámara lo acompaña.
func _despegar_paso(d: float) -> void:
	_techo = clampf(d / PARTE_TECHO, 0.0, 1.0)
	_colocar_techo()
	if is_instance_valid(_estado):
		_estado.fase = Estado.DESPEGANDO
		_estado.avance = d
	var sube: float = clampf((d - 0.62) / 0.38, 0.0, 1.0)
	var altura := pow(sube, 2.4) * _cohete_alto * 3.2
	_cohete.position.y = _mesa_alto + altura
	for brazo in _brazos:  # los brazos de servicio se retiran antes de que suba
		if is_instance_valid(brazo):
			brazo.rotation.y = deg_to_rad(-34.0 * clampf(d / 0.5, 0.0, 1.0))
	if is_instance_valid(_llama):
		_llama.visible = sube > 0.0
		_llama.position = _cohete.position
		_llama.scale = Vector3.ONE * _cohete_alto * (0.09 + 0.05 * sin(_t * 26.0))
	_camera.position = CAMARA_CASA
	_camera.look_at(Vector3(CAMARA_MIRA.x, _mesa_alto + _cohete_alto * 0.34 + altura * 0.82, _cohete.position.z))


func _fin_despegue() -> void:
	_t_despegue = -1.0
	visible = false
	if is_instance_valid(_llama):
		_llama.visible = false
	despegue_terminado.emit(_diseno_despegue)


## Llama de los motores: un cono emisivo que solo se ve mientras el cohete sube.
func _build_llama(vista: SubViewport) -> void:
	_llama = Node3D.new()
	_llama.visible = false
	vista.add_child(_llama)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("FFE1A8")
	mat.emission_enabled = true
	mat.emission = Color("FF9A3C")
	mat.emission_energy_multiplier = 9.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for par in [[1.0, 0.0], [0.55, -1.1]]:
		var cono := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55 * par[0]
		cm.bottom_radius = 0.0
		cm.height = 3.4 * par[0]
		cono.mesh = cm
		cono.material_override = mat
		cono.position = Vector3(0, -1.6 * par[0] + par[1], 0)
		_llama.add_child(cono)


## Luz de estudio para el cohete: una clave delante y a un lado, y un contraluz detrás que le
## dibuja el borde. Sin esto el lanzador se funde con el fondo oscuro del edificio y se pierde todo
## el trabajo del modelo.
func _luces_del_cohete(vista: SubViewport) -> void:
	_clave = SpotLight3D.new()
	_clave.light_color = Color("FFF0D8")
	_clave.light_energy = 7.0
	_clave.spot_range = 320.0
	_clave.spot_angle = 34.0
	_clave.spot_attenuation = 0.7
	_clave.shadow_enabled = int(Graficos.cargar().get("sombras", 1)) > 1
	vista.add_child(_clave)
	_contra = OmniLight3D.new()
	_contra.light_color = Color("9FC6E8")
	_contra.light_energy = 3.2
	_contra.omni_range = 120.0
	vista.add_child(_contra)


## Coloca las luces del cohete a su medida: la clave arriba y a la derecha, el contraluz detrás.
func _colocar_luces() -> void:
	if not is_instance_valid(_clave) or not is_instance_valid(_cohete):
		return
	var centro := Vector3(_cohete.position.x, _mesa_alto + _cohete_alto * 0.5, _cohete.position.z)
	_clave.position = centro + Vector3(_cohete_alto * 0.75, _cohete_alto * 0.55, _cohete_alto * 0.95)
	_clave.look_at(centro)
	_contra.position = centro + Vector3(-_cohete_alto * 0.35, _cohete_alto * 0.25, -_cohete_alto * 0.7)
	_contra.omni_range = _cohete_alto * 1.6


## Luces del interior: con el techo cerrado, el sol no entra y el edificio se queda a oscuras.
func _luces_de_nave(vista: SubViewport) -> void:
	for par in [[-0.5, 0.8], [0.5, 0.55], [0.0, 0.3]]:
		var luz := OmniLight3D.new()
		luz.light_color = Color("FFD9A8")
		luz.light_energy = 3.4
		luz.omni_range = 38.0
		luz.position = Vector3(HANGAR_SEMIANCHO * float(par[0]), 14.0, -HANGAR_FONDO_LIBRE * float(par[1]))
		_hangar.add_child(luz)
	var fria := OmniLight3D.new()
	fria.light_color = Color("A8C8E0")
	fria.light_energy = 2.0
	fria.omni_range = 40.0
	fria.position = Vector3(0.0, 19.0, HANGAR_BASE.z)
	_hangar.add_child(fria)


# ------------------------------------------------------------------ animación


func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_camera):
		return
	_t += delta
	if is_instance_valid(_estado):
		_estado.reloj = _t
		_estado.queue_redraw()
	if _t_despegue >= 0.0:
		var d: float = clampf((_t - _t_despegue) / DURACION_DESPEGUE, 0.0, 1.0)
		_despegar_paso(d)
		if d >= 1.0:
			_fin_despegue()
		return
	if _t_salida >= 0.0:
		var sale: float = clampf((_t - _t_salida) / DURACION_ABORDAJE, 0.0, 1.0)
		_abordar(1.0 - sale)  # la salida es el abordaje al revés, fotograma a fotograma
		if is_instance_valid(_estado):
			_estado.fase = Estado.SALIENDO
			_estado.avance = sale
		if sale >= 1.0:
			_fin_salida()
		return
	if _t_abordaje >= 0.0:
		var a: float = clampf((_t - _t_abordaje) / DURACION_ABORDAJE, 0.0, 1.0)
		_abordar(a)
		if a >= 1.0:
			_fin_abordaje()
		return
	# Entrada dinámica: la cámara entra desde un lado y se asienta mirando al edificio.
	var avance: float = clampf(_t / DURACION_ENTRADA, 0.0, 1.0)
	var suave := ease(avance, 0.35)  # salida suave
	var casa := CAMARA_CASA
	if _t_eleccion >= 0.0:
		var p: float = clampf((_t - _t_eleccion) / _duracion_montaje(), 0.0, 1.0)
		casa = _camara_del_montaje(p)
		_montar(p, delta)
		if is_instance_valid(_estado):
			_estado.fase = Estado.MONTANDO if p < 1.0 else Estado.LISTO
			_estado.avance = p
	elif is_instance_valid(_estado):
		_estado.fase = Estado.ELIGIENDO
		_estado.avance = avance
	_camera.position = CAMARA_ENTRADA.lerp(casa, suave)
	_camera.look_at(_punto_de_mira())


## Dónde está la cámara mientras se monta el cohete, con `p` de 0 a 1.
##
## Un corte a una posición fija dejaba el montaje muerto: se veía armarse el cohete con la cámara
## clavada. Aquí describe un arco corto alrededor del lanzador mientras se acerca, y la mirada sube
## de la base a la punta al mismo ritmo, que es como se filmaría de verdad. Al acabar no se queda
## quieta del todo: sigue una deriva mínima, proporcional al tamaño del cohete, para que la imagen
## respire sin marear.
func _camara_del_montaje(p: float) -> Vector3:
	var s := smoothstep(0.0, 1.0, p)
	_mira_y = _cohete_alto * lerpf(0.13, 0.34, s)
	# El movimiento va en metros fijos, no en una fracción de lo que dista el cohete. Hacerlo en
	# fracción parecía lo elegante y fue un error: cada lanzador se monta a una distancia distinta
	# (el Saturno V, a 254 m; el Delta II, a 90), así que el mismo porcentaje eran 30 m en uno y 11
	# en el otro. El rover, que no se mueve de su sitio, cambiaba de tamaño al elegir otro cohete, y
	# con los más altos la cámara se le iba por detrás y desaparecía de la pantalla.
	# Así el rover se ve igual con los cuatro, y el cohete ya lo encuadra `_encuadrar()`.
	var acercar := lerpf(-4.0, 7.0, s)  # m hacia el cohete
	var lado := lerpf(3.2, -1.2, s)  # m de desplazamiento lateral: el arco corto
	var deriva := 0.55  # m de deriva lenta, para que la imagen respire sin marear
	return Vector3(CAMARA_CASA.x + lado + sin(_t * 0.21) * deriva,
		CAMARA_CASA.y + lerpf(0.0, 1.4, s) + sin(_t * 0.17) * deriva * 0.4,
		CAMARA_CASA.z - acercar)


## Montaje. Si el .glb trae su propia animación de armado, es ella la que manda y aquí solo se la
## lleva al fotograma que toca; si no, cada tramo baja a su sitio por turnos, los brazos de las
## torres se acercan mientras se suelda y las chispas saltan en la unión.
func _montar(p: float, delta: float) -> void:
	if not is_instance_valid(_cohete) or _secciones.is_empty():
		return
	var dentro := ease(1.0 - absf(clampf(p, 0.0, 1.0) * 2.0 - 1.0), 0.6)  # 0 -> 1 -> 0, con entrada suave
	for brazo in _brazos:
		if is_instance_valid(brazo):
			brazo.rotation.y = deg_to_rad(-26.0 * dentro)
	if _anim != null and _anim.has_animation(_anim_nombre):
		_anim.seek(clampf(p, 0.0, 1.0) * _anim.get_animation(_anim_nombre).length, true)
		if is_instance_valid(_chispas):
			_chispas.visible = false
		return
	var total := _secciones.size()
	var avance := p * float(total)  # cuántos tramos llevan colocados
	var en_curso := -1
	for i in range(total):
		var s: Node3D = _secciones[i]
		if not is_instance_valid(s):
			continue
		var y_final: float = s.get_meta("y_final", 0.0)
		var t_tramo: float = clampf(avance - float(i), 0.0, 1.0)
		if t_tramo > 0.0 and t_tramo < 1.0:
			en_curso = i
		# Entra desde arriba, como colgado de la grúa.
		s.position.y = y_final + (1.0 - ease(t_tramo, 0.3)) * (_cohete_alto * 0.55)
		s.visible = t_tramo > 0.0
	# Chispas en la unión del tramo que se está soldando.
	_chispas_t += delta
	if is_instance_valid(_chispas):
		_chispas.visible = en_curso >= 0
		if en_curso >= 0:
			var s: Node3D = _secciones[en_curso]
			_chispas.position = _cohete.position + Vector3(0, s.position.y, 0)
			for i in range(_chispas.get_child_count()):
				var punto: Node3D = _chispas.get_child(i)
				var a := float(i) * 1.7 + _chispas_t * 9.0
				var r := 1.2 + fmod(a, 2.4)
				punto.position = Vector3(cos(a) * r, sin(a * 1.7) * r * 0.5, sin(a) * r * 0.6)
				punto.scale = Vector3.ONE * (0.6 + 0.5 * sin(a * 3.1))


## Abordaje, con `a` de 0 a 1: el rover rueda por la calzada hasta la escotilla de la mesa de
## lanzamiento (las ruedas giran de verdad, con el radio del modelo de la NASA), la cámara lo sigue
## por detrás mientras el cohete crece delante, y en el último tramo entra por el hueco, se apaga el
## testigo de la puerta y sube el ascensor por el costado del cohete.
## Dónde está la boca de la escotilla, en coordenadas del panorama.
func _boca_de_la_escotilla() -> Vector3:
	if not is_instance_valid(_mesa) or not is_instance_valid(_puerta):
		return _cohete.position + Vector3(0, 2.0, 0)
	return _mesa.position + _puerta.position + Vector3(0, 1.8, 0)


## Altura del suelo que pisa el rover en «z» (coordenadas del panorama): 0 delante de la rampa, la de
## la cubierta detrás de su cima y, en medio, la de la pendiente.
func _altura_de_la_rampa(z: float) -> float:
	if not is_instance_valid(_mesa):
		return 0.0
	var local := z - _mesa.position.z
	if local >= _rampa_pie_z:
		return 0.0
	if local <= _rampa_cima_z:
		return _mesa_alto
	return _mesa_alto * (_rampa_pie_z - local) / (_rampa_pie_z - _rampa_cima_z)


## Apoya el rover en lo que pisa: la altura y el cabeceo salen de sus ruedas delanteras y traseras,
## así sube la rampa inclinado y se endereza al llegar arriba.
func _apoyar_en_la_rampa() -> void:
	const MEDIA_BATALLA := 1.3  # m del centro a cada eje (el Perseverance mide 3 m de largo)
	var delante := _altura_de_la_rampa(_rover.position.z - MEDIA_BATALLA)  # el frente del rover es −z
	var detras := _altura_de_la_rampa(_rover.position.z + MEDIA_BATALLA)
	_rover.position.y = (delante + detras) * 0.5
	_rover.rotation.x = atan2(delante - detras, MEDIA_BATALLA * 2.0)


func _abordar(a: float) -> void:
	if not is_instance_valid(_rover) or not is_instance_valid(_cohete):
		return
	if is_instance_valid(_estado):
		_estado.fase = Estado.ABORDANDO
		_estado.avance = a
	# Primero rueda hasta el pie de la rampa; luego sube por ella y entra por la escotilla de la cubierta.
	var base_z: float = _mesa.position.z if is_instance_valid(_mesa) else _cohete.position.z
	var destino := Vector3(_cohete.position.x, 0.0, base_z + _rampa_pie_z + 3.0)
	var boca_z: float = _boca_de_la_escotilla().z
	var rodando: float = clampf(a / 0.72, 0.0, 1.0)
	var camino := ease(rodando, 0.55)
	var antes := _rover.position
	_rover.position = ROVER_POS.lerp(destino, camino)
	var subiendo: float = clampf((a - 0.72) / 0.28, 0.0, 1.0)
	if subiendo > 0.0:
		_rover.position.z = lerpf(destino.z, boca_z - 3.0, subiendo)
	# «dentro»: cuánto ha pasado ya por el hueco (0 hasta que el morro llega a la escotilla).
	var dentro: float = clampf((boca_z + 1.5 - _rover.position.z) / 4.5, 0.0, 1.0)
	if dentro <= 0.0:
		_mirar_al_cohete()  # ya dentro del hueco no se reorienta: miraría al cohete que tiene encima
	_apoyar_en_la_rampa()
	# Ruedas: giran lo que avanzó el rover, no lo que pasó el tiempo, y en el sentido en el que se
	# mueve (al salir del cohete va marcha atrás, sin dejar de mirar a su nave).
	var recorrido := (_rover.position - antes).dot(-_rover.global_transform.basis.z)
	if _radio_rueda > 0.0:
		for rueda in _ruedas:
			if is_instance_valid(rueda):
				rueda.rotate_x(recorrido / _radio_rueda)
	# Cámara: detrás y algo por encima del rover, siguiéndolo. Al acercarse se echa atrás y sube, o
	# acabaría metida debajo del cohete, sin sitio para ver ni la escotilla ni al rover entrando.
	var seguimiento := Vector3(2.4, 2.6, 9.0).lerp(Vector3(5.0, 4.2, 15.0), ease(rodando, 0.6))
	_camera.position = CAMARA_CASA.lerp(_rover.position + seguimiento, ease(clampf(a / 0.3, 0.0, 1.0), 0.5))
	# Mira delante del rover al principio y a la escotilla al final.
	var delante := _rover.position + Vector3(0.0, 1.5, -10.0)
	_camera.look_at(delante.lerp(_boca_de_la_escotilla(), ease(rodando, 0.5)))
	# Último tramo: el rover se mete por la escotilla y el ascensor sube.
	if dentro > 0.0:
		_rover.scale = Vector3.ONE * maxf(1.0 - dentro, 0.02)
		_rover.visible = dentro < 0.98
		if is_instance_valid(_puerta_luz):
			_puerta_luz.light_energy = 0.55 + 4.0 * dentro
	else:
		# Fuera del hueco, el rover está entero. Hace falta decirlo porque esta misma función se
		# reproduce al revés para salir del cohete: si no, el rover salía del tamaño de una moneda.
		_rover.scale = Vector3.ONE
		_rover.visible = true
		if is_instance_valid(_puerta_luz):
			_puerta_luz.light_energy = 0.55
	if is_instance_valid(_ascensor):
		_ascensor.visible = dentro > 0.55
		_ascensor.position.y = _mesa_alto + (_cohete_alto * 0.62) * ease(clampf((dentro - 0.55) / 0.45, 0.0, 1.0), 0.6)


# ================================================================== piezas de la consola
# Todas se dibujan a mano. Dos reglas, y de ahí sale el aspecto:
#  · nada de cajas de fondo salvo en lo que se pulsa (las fichas y el mando);
#  · nada de frases: rótulo de una palabra arriba y la cifra debajo, como un panel de verdad.


## Mobiliario de la pantalla: cuatro corchetes finos en las esquinas y nada más.
class Marco extends Control:
	const C := preload("res://scenes/b/consola.gd")

	func _draw() -> void:
		C.corchetes(self, Rect2(Vector2(16, 16), size - Vector2(32, 32)), Color(C.ACERO, 0.4), 20.0, 1.0)


## Encabezado: dónde estamos y qué hay que hacer. Dos líneas, sin explicación larga.
class Bloque extends Control:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	var etiqueta := ""
	var titulo := ""

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, 4), Vector2(3, 44)), Color(C.AMBAR, 0.9))
		C.texto(self, Vector2(14, 16), etiqueta, UI.FONT_MIN, Color(C.ACERO, 0.95), 700, 3)
		C.texto(self, Vector2(13, 46), titulo.to_upper(), 23, UI.CREAM, 700, 2)


## Lectura de presupuesto, alineada al borde derecho: rótulo pequeño, cifra grande y una raya.
class Lectura extends Control:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	var presupuesto := 0.0

	func _draw() -> void:
		var tag := tr("LP_BUDGET_TAG")
		C.texto(self, Vector2(size.x - C.ancho(tag, UI.FONT_MIN, 700, 3), 14), tag, UI.FONT_MIN,
			Color(C.ACERO, 0.95), 700, 3)
		var unidad := "M USD"
		var ancho_unidad := C.ancho(unidad, UI.FONT_MIN, 600, 1)
		C.texto(self, Vector2(size.x - ancho_unidad, 44), unidad, UI.FONT_MIN, Color(C.ACERO, 0.9), 600, 1)
		var cifra := "%d" % int(presupuesto)
		C.texto(self, Vector2(size.x - ancho_unidad - 8 - C.ancho(cifra, 27, 700, 0), 46), cifra, 27, UI.CREAM, 700, 0)
		C.regla(self, size.y - 2, size.x - 150, size.x, Color(C.ACERO, 0.3))


## Tira de estado: testigo que late, una palabra y, mientras algo avanza, una barra corta.
class Estado extends Control:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	enum {ELIGIENDO, MONTANDO, LISTO, ABORDANDO, SALIENDO, DESPEGANDO}

	var fase: int = ELIGIENDO
	var avance := 0.0
	var reloj := 0.0

	func _draw() -> void:
		var color := C.AMBAR if fase != ELIGIENDO and fase != LISTO else Color("9AD7C6")
		if fase == ELIGIENDO:
			color = C.ACERO
		var clave := str(["LP_ST_CHOOSE", "LP_ST_BUILD", "LP_ST_READY", "LP_ST_BOARD", "LP_ST_LEAVE",
			"LP_ST_LIFTOFF"][fase])
		var rotulo := tr(clave)
		var ancho := C.ancho(rotulo, UI.FONT_MIN, 700, 2)
		var barra := 0.0 if fase == ELIGIENDO or fase == LISTO else 54.0
		var x := (size.x - (ancho + 20.0 + barra)) * 0.5
		C.testigo(self, Vector2(x, size.y * 0.5), color, reloj, 3.0)
		C.texto(self, Vector2(x + 12, size.y * 0.5 + 5), rotulo, UI.FONT_MIN, Color(UI.CREAM, 0.92), 700, 2)
		if barra > 0.0:
			C.barra(self, Rect2(Vector2(x + 20 + ancho, size.y * 0.5 - 2), Vector2(barra, 4)), avance,
				Color(C.ACERO, 0.22), Color(color, 0.95))


## Rótulo pequeño de pie de pantalla (marca de imagen generada con IA).
class Leyenda extends Control:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	var texto := ""

	func _draw() -> void:
		C.texto(self, Vector2(0, 13), texto, UI.FONT_MIN, Color(UI.CREAM, 0.5), 600, 2)


## Cabecera del manifiesto: una línea con el nombre, la cuenta y la regla del juego. Sin chapa
## detrás: antes las cuatro fichas iban dentro de un panelón y se leía como una tarjeta web.
class Riel extends Control:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	var titulo := ""
	var regla := ""

	func _draw() -> void:
		# Sin cabecera: cuatro fichas en fila ya se ven que son la lista. Queda la regla del juego,
		# que es lo único de aquí que enseña algo.
		var y := 14.0
		var ancho := C.ancho(regla, UI.FONT_MIN, 600, 2)
		C.texto(self, Vector2(size.x - ancho, y), regla, UI.FONT_MIN, Color(UI.CREAM, 0.45), 600, 2)
		C.regla(self, y + 8, 0, size.x, Color(C.ACERO, 0.18))

	## Cuántas fichas hay dentro (el manifiesto las lleva en un HBoxContainer).
	func _fichas() -> int:
		for h in get_children():
			if h is HBoxContainer:
				return h.get_child_count()
		return 0


## Mando de abordaje: una barra de orden, no un botón. Los chevrones marcan hacia dónde lleva.
class Mando extends Button:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(estado, StyleBoxEmpty.new())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var encima := is_hovered() and not disabled
		C.chapa(self, r, Color("3A2B14", 0.95) if encima else Color("141A20", 0.88),
			Color(C.AMBAR, 1.0 if encima else 0.7), 2.0, 14.0, C.TL | C.BR)
		for i in range(3):
			var x := 16.0 + i * 7.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, size.y * 0.5 - 6), Vector2(x + 5, size.y * 0.5), Vector2(x, size.y * 0.5 + 6)]),
				Color(C.AMBAR, 0.35 + 0.22 * i))
		C.texto(self, Vector2(48, size.y * 0.5 + 6), text.to_upper(), 16,
			Color.WHITE if encima else UI.CREAM, 700, 2)


## Ficha de un lanzador: número, nombre real, silueta a escala y dos cifras con su rótulo.
## La silueta es la que decide de un vistazo: compara lo alto que es cada cohete de verdad.
class Tarjeta extends Button:
	const C := preload("res://scenes/b/consola.gd")
	const UI := preload("res://scenes/b/ui_style.gd")

	var indice := 1
	var nombre := ""
	var capacidad := 0.0
	var costo := 0.0
	var restante := 0.0
	var alto := 0.0
	var alto_max := 1.0
	var marcada := false

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		clip_contents = false
		for estado in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(estado, StyleBoxEmpty.new())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var encima := is_hovered()
		var relleno := Color("132230", 0.94) if marcada else (Color("0C151E", 0.88) if encima else Color("070C11", 0.82))
		var borde := Color(C.AMBAR, 0.95) if marcada else Color(C.ACERO, 0.55 if encima else 0.28)
		C.chapa(self, r, relleno, borde, 2.0 if marcada else 1.0, 13.0, C.TR)
		draw_rect(Rect2(Vector2.ZERO, Vector2(3, size.y)), Color(C.AMBAR, 0.95) if marcada else Color(C.ACERO, 0.28))

		var tinta_num := Color(C.AMBAR, 0.95) if marcada else Color(C.ACERO, 0.75)
		C.texto(self, Vector2(13, 22), "%02d" % indice, 14, tinta_num, 700, 1)
		C.parrafo(self, Vector2(13, 44), nombre, 14, UI.CREAM, size.x - 48)

		_silueta(Rect2(Vector2(size.x - 32, 12), Vector2(20, size.y - 42)))

		# Dos cifras, dos rótulos. Nada de frases.
		var base := size.y - 16.0
		_cifra(Vector2(13, base), "%d" % int(capacidad), "KG")
		_cifra(Vector2(size.x * 0.52, base), "%d" % int(costo), "M USD")
		if marcada:
			# Lo que quedaría de presupuesto, arriba y a la derecha: abajo se pisaba con los rótulos.
			var resto := tr("LP_LEFT") % int(restante)
			C.texto(self, Vector2(size.x - 40 - C.ancho(resto, UI.FONT_MIN, 600, 1), 22), resto,
				UI.FONT_MIN, Color(C.AMBAR, 0.9), 600, 1)

	## Una cifra con su unidad pequeña al lado. Sin rótulo debajo: la unidad ya dice lo que es.
	func _cifra(pos: Vector2, valor: String, unidad: String) -> void:
		var ancho := C.texto(self, pos, valor, 18, UI.CREAM, 700, 0)
		C.texto(self, Vector2(pos.x + ancho + 3, pos.y), unidad, UI.FONT_MIN, Color(C.ACERO, 0.8), 600, 0)

	## Silueta a escala: el lanzador dibujado a la altura que le toca frente al más alto del
	## manifiesto, con su altura real en metros girada al lado.
	func _silueta(r: Rect2) -> void:
		C.regla(self, r.end.y, r.position.x - 3, r.end.x + 1, Color(C.ACERO, 0.35))
		if alto <= 0.0:
			return
		var h: float = r.size.y * clampf(alto / alto_max, 0.08, 1.0)
		var ancho_cuerpo := r.size.x * 0.5
		var x := r.position.x + (r.size.x - ancho_cuerpo) * 0.5
		var tinta := Color(C.AMBAR, 0.95) if marcada else Color(C.ACERO, 0.6)
		var cuerpo := Rect2(Vector2(x, r.end.y - h), Vector2(ancho_cuerpo, h * 0.86))
		draw_rect(cuerpo, tinta)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, cuerpo.position.y), Vector2(x + ancho_cuerpo * 0.5, r.end.y - h - h * 0.12),
			Vector2(x + ancho_cuerpo, cuerpo.position.y)]), tinta)
		var metros := tr("LP_HEIGHT") % int(round(alto))
		var f := UI.display_font(600, 0)
		var tam: int = UI.FONT_MIN
		var medida := f.get_string_size(metros, HORIZONTAL_ALIGNMENT_LEFT, -1, tam)
		draw_set_transform(Vector2(r.end.x + 1, r.end.y), -PI / 2.0, Vector2.ONE)
		draw_string(f, Vector2(2, medida.y * 0.8), metros, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(UI.CREAM, 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
