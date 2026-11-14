extends GutTest
## Pruebas de los cuatro cohetes del taller (rama b/cohetes-telescopio).
## Fijan el balance: cada cohete tiene un perfil distinto y hay varios diseños ganadores.
## Las capacidades y los costos son valores de juego; el dato real de cada uno está en su
## "ref_clave" y en docs/DATOS_NASA.md.

const LaunchCruiseScript := preload("res://scenes/b/launch_cruise.gd")
const LaunchPadScript := preload("res://scenes/b/launch_pad.gd")
const WorkshopScript := preload("res://scenes/b/workshop.gd")

const COHETES: Array[String] = ["cohete_ligero", "cohete_medio", "cohete_pesado", "cohete_super"]
const TODOS_LOS_INSTRUMENTOS: Array[String] = ["espectrometro", "taladro", "camara", "meteo",
	"radar", "bateria", "dron", "companero"]
## Los cuatro lanzadores del manifiesto con la altura real a la que se muestran, de menor a mayor:
## Delta II, Titan IIIE-Centaur, Atlas V 541 y Saturno V (fuentes en docs/DATOS_NASA.md).
const ALTOS: Array = [["cohete_ligero", 39.0], ["cohete_medio", 48.8], ["cohete_pesado", 58.3],
	["cohete_super", 110.6]]

var reglas: Rules
var catalogo: Catalog


func before_all() -> void:
	# Mismas traducciones que registra MissionView.setup_locale(), sin crear la vista: las tarjetas
	# formatean textos con %d y sin catálogo tr() devolvería la clave.
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


func before_each() -> void:
	reglas = Rules.desde_archivo("res://content/rules.json")
	catalogo = Catalog.desde_archivo("res://content/parts.json")


func _diseno(ids: Array[String]) -> MissionDesign:
	var diseno := MissionDesign.new(catalogo, reglas)
	for id in ids:
		# MissionDesign ya trae una trayectoria puesta (Hohmann, por elegir_trayectoria_por_defecto):
		# la trayectoria se cambia, no se añade, o saldría ABOVE_MAX:trayectoria.
		if str(catalogo.obtener(id).get("categoria", "")) == "trayectoria":
			for previa in (diseno.seleccion["trayectoria"] as Array).duplicate():
				diseno.quitar(str(previa))
		assert_true(diseno.agregar(id), "no se pudo agregar %s" % id)
	return diseno


func test_hay_cuatro_cohetes() -> void:
	var ids := Array(catalogo.ids_de("cohetes"))
	assert_eq(ids.size(), 4, "el taller ofrece cuatro cohetes")
	for id in COHETES:
		assert_true(ids.has(id), "falta el cohete %s" % id)


func test_capacidad_y_costo_crecen_juntos() -> void:
	var capacidad_previa := 0.0
	var costo_previo := 0.0
	for id in COHETES:
		var pieza := catalogo.obtener(id)
		var capacidad := float(pieza["capacidad_kg"])
		var costo := float(pieza["costo_musd"])
		assert_gt(capacidad, capacidad_previa, "%s debe cargar más que el anterior" % id)
		assert_gt(costo, costo_previo, "%s debe costar más que el anterior" % id)
		capacidad_previa = capacidad
		costo_previo = costo


func test_cada_cohete_declara_su_dato_real() -> void:
	var texto := FileAccess.get_file_as_string("res://scenes/b/i18n/catalog.gd")
	for id in COHETES:
		var referencia: String = catalogo.obtener(id).get("ref_clave", "")
		assert_false(referencia.is_empty(), "%s no declara ref_clave" % id)
		assert_true(texto.contains("\"" + referencia + "\""), "falta el texto %s en catalog.gd" % referencia)


func test_el_cohete_ligero_no_alcanza_para_la_trayectoria_rapida() -> void:
	# La trayectoria rápida recorta la capacidad al 80 %: 600 kg x 0,8 = 480 kg, menos que el chasis.
	var diseno := _diseno(["cohete_ligero", "trayectoria_rapida", "chasis_base", "panel_solar", "antena_directa"])
	assert_has(Array(diseno.validar()), "OVER_MASS", "el ligero con ruta rápida no levanta el chasis")


func test_el_cohete_medio_permite_llevar_todos_los_instrumentos() -> void:
	var ids: Array[String] = ["cohete_medio", "trayectoria_hohmann", "chasis_base", "panel_solar", "antena_directa"]
	ids.append_array(TODOS_LOS_INSTRUMENTOS)
	var diseno := _diseno(ids)
	assert_eq(Array(diseno.validar()), [], "el medio con solar y antena directa cabe en masa y presupuesto")


func test_el_superpesado_no_deja_presupuesto_para_el_mmrtg() -> void:
	var diseno := _diseno(["cohete_super", "trayectoria_hohmann", "chasis_base", "mmrtg", "antena_directa"])
	assert_has(Array(diseno.validar()), "OVER_BUDGET", "el superpesado con MMRTG se pasa de los 700 M USD")


func test_el_lanzamiento_lee_la_capacidad_del_cohete_elegido() -> void:
	# Antes el lanzamiento comparaba contra el id "cohete_pesado", así que el medio y el superpesado
	# se dibujaban como el ligero. Ahora sale del dato, y no se rompe si cambian los cohetes.
	var secuencia: CanvasLayer = add_child_autofree(LaunchCruiseScript.new())
	for id in COHETES:
		var esperada := float(catalogo.obtener(id)["capacidad_kg"])
		secuencia.taller = {
			"selection": {"cohetes": [id]},
			"categories": [{"id": "cohetes", "parts": [{"id": id, "capacity_kg": esperada}]}],
		}
		assert_eq(secuencia._capacidad_del_cohete(), esperada, "%s debe informar su propia capacidad" % id)
	secuencia.taller = {"selection": {"cohetes": []}, "categories": []}
	assert_eq(secuencia._capacidad_del_cohete(), 0.0, "sin cohete elegido no hay capacidad")


func test_solo_el_cohete_ligero_queda_bajo_el_umbral_de_aspecto() -> void:
	# Garantiza que los tres cohetes grandes se vean distintos del ligero en el despegue.
	var bajo_umbral: Array[String] = []
	for id in COHETES:
		if float(catalogo.obtener(id)["capacidad_kg"]) < LaunchCruiseScript.UMBRAL_PESADO_KG:
			bajo_umbral.append(id)
	assert_eq(bajo_umbral, ["cohete_ligero"], "solo el ligero despega sin propulsores laterales")


func test_cada_cohete_tiene_al_menos_un_diseno_valido() -> void:
	# Un diseño ganador distinto por cohete: el perfil de cada uno sacrifica algo diferente.
	var disenos := {
		"cohete_ligero": ["trayectoria_hohmann", "chasis_base", "panel_solar", "antena_rele", "camara", "radar"],
		"cohete_medio": ["trayectoria_hohmann", "chasis_base", "panel_solar", "antena_directa", "espectrometro", "taladro"],
		"cohete_pesado": ["trayectoria_rapida", "chasis_base", "panel_solar", "antena_rele", "camara", "meteo"],
		"cohete_super": ["trayectoria_rapida", "chasis_base", "panel_solar", "antena_directa", "camara"],
	}
	for cohete in disenos:
		var ids: Array[String] = [cohete]
		for id in disenos[cohete]:
			ids.append(str(id))
		var diseno := _diseno(ids)
		assert_eq(Array(diseno.validar()), [], "%s debería tener un diseño válido" % cohete)


# ------------------------------------------------------------------ plataforma de la Tierra


func _simulacion() -> Simulation:
	var balance := Balance.desde_archivo("res://content/balance.json")
	var mapa := MapData.desde_archivo("res://content/mapa.json")
	return Simulation.new(balance, reglas, mapa, catalogo)


func test_la_plataforma_se_ve_hasta_que_hay_cohete_y_luego_el_hangar() -> void:
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	assert_true(plataforma.visible, "sin cohete elegido se elige en la Tierra")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	plataforma.update_snapshot(sim.snapshot())
	assert_false(plataforma.visible, "con el cohete puesto, el relevo es del hangar")


func test_la_plataforma_muestra_una_tarjeta_por_cohete() -> void:
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	assert_eq(plataforma._cards.get_child_count(), COHETES.size(), "los cuatro cohetes, en fila")


func test_elegir_un_cohete_lo_levanta_pero_no_lo_confirma_solo() -> void:
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	var ordenes: Array = []
	plataforma.command.connect(func(orden: String, carga: Dictionary) -> void: ordenes.append([orden, carga]))
	plataforma.update_snapshot(sim.snapshot())
	plataforma._on_card("cohete_super", 1800.0)
	assert_eq(plataforma.elegido, "cohete_super")
	assert_true(plataforma._cohete.visible, "el cohete se levanta delante del rover")
	assert_gt(plataforma._cohete.get_child_count(), 0, "el cohete tiene cuerpo")
	assert_true(plataforma._confirmar.visible, "aparece el botón para entrar")
	assert_eq(ordenes, [], "mirar el cohete no lo confirma: primero se ve en el horizonte")
	plataforma._on_confirmar()
	assert_eq(ordenes, [], "confirmar arranca el abordaje; la orden espera a que el rover entre")
	_correr(plataforma, LaunchPadScript.DURACION_ABORDAJE + 0.5)
	assert_eq(ordenes.size(), 1, "con el rover dentro se manda la orden")
	assert_eq(ordenes[0][0], "design_add")
	assert_eq(ordenes[0][1]["part_id"], "cohete_super")
	_correr(plataforma, 1.0)
	assert_eq(ordenes.size(), 1, "la orden se manda una sola vez")


func test_el_hangar_ya_no_ofrece_cohetes() -> void:
	assert_false(WorkshopScript.ORDER.has("cohetes"), "el cohete se elige en la Tierra, no en el hangar")
	for categoria in WorkshopScript.ORDER:
		assert_true(Catalog.CATEGORIAS.has(categoria), "categoría desconocida en el hangar: %s" % categoria)


func test_el_hangar_pone_las_herramientas_basicas_y_avisa_si_se_quitan() -> void:
	# El rover no entra al hangar desnudo: llega con taladro y cámara puestos, porque abrir la lista
	# en blanco dejaba al jugador sin saber por dónde empezar. Quitarlas se puede, pero se avisa.
	var sim := _simulacion()
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
	var pedidas: Array[String] = []
	hangar.command.connect(func(orden: String, carga: Dictionary) -> void:
		if orden == "design_add":
			pedidas.append(str(carga.get("part_id", ""))))
	hangar.update_snapshot(sim.snapshot())
	assert_eq(pedidas, Array(MissionDesign.HERRAMIENTAS_BASICAS), "pide el taladro y la cámara")
	assert_eq(hangar.basicas_que_faltan(sim.snapshot()["workshop"]), Array(MissionDesign.HERRAMIENTAS_BASICAS),
		"mientras no estén puestas, faltan las dos")

	for id in pedidas:
		sim.ejecutar("design_add", {"part_id": id})
	hangar.update_snapshot(sim.snapshot())
	assert_eq(hangar.basicas_que_faltan(sim.snapshot()["workshop"]), [], "ya no falta ninguna")
	pedidas.clear()
	hangar.update_snapshot(sim.snapshot())
	assert_eq(pedidas, [], "no se piden dos veces")

	# El jugador quita el taladro: no se vuelve a poner solo, pero la ficha de misión lo avisa.
	sim.ejecutar("design_remove", {"part_id": "taladro"})
	hangar.update_snapshot(sim.snapshot())
	assert_eq(pedidas, [], "quitarla es decisión del jugador")
	assert_eq(hangar.basicas_que_faltan(sim.snapshot()["workshop"]), ["taladro"], "y queda avisada")


func test_sin_cohete_elegido_el_hangar_no_avisa_de_herramientas() -> void:
	var sim := _simulacion()
	var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
	assert_eq(hangar.basicas_que_faltan(sim.snapshot()["workshop"]), [],
		"sin cohete todavía no hay misión de la que avisar")


func test_el_hangar_puede_devolver_a_la_plataforma() -> void:
	var sim := _simulacion()
	sim.ejecutar("design_add", {"part_id": "cohete_pesado"})
	var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
	var ordenes: Array = []
	hangar.command.connect(func(orden: String, carga: Dictionary) -> void: ordenes.append([orden, carga]))
	hangar.update_snapshot(sim.snapshot())
	# Lo primero que hace el hangar al recibir al rover es pedir las herramientas básicas.
	assert_eq(ordenes.size(), MissionDesign.HERRAMIENTAS_BASICAS.size(), "llega con las básicas puestas")
	ordenes.clear()
	hangar._on_cambiar_cohete()
	assert_eq(ordenes.size(), 1, "quita el cohete elegido")
	assert_eq(ordenes[0][0], "design_remove")
	assert_eq(ordenes[0][1]["part_id"], "cohete_pesado")


func test_los_cuatro_modelos_entran_a_su_altura_real() -> void:
	# Delta II, Titan IIIE-Centaur, Atlas V 541 y Saturno V. Ninguno llegó como pide el contrato de
	# ARTE_Y_LICENCIAS.md: uno achatado (escala no uniforme), otro con esqueleto (que se mide de otra
	# manera, porque la escala de sus nodos se cancela sola), otro en otras unidades y todos
	# descentrados. launch_pad los normaliza al cargarlos y los escala a su altura real: si una
	# medida se rompe, el cohete se sale de la pantalla y ninguna otra prueba lo nota.
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	for caso in ALTOS:
		var id := str(caso[0])
		var alto := float(caso[1])
		assert_eq(float(catalogo.obtener(id)["alto_real_m"]), alto, "%s declara su altura real" % id)
		assert_true(ResourceLoader.exists("res://assets/modelos/%s.glb" % id), "falta el modelo de %s" % id)
		plataforma.elegido = ""
		plataforma._on_card(id, float(catalogo.obtener(id)["capacidad_kg"]), alto)
		assert_almost_eq(plataforma._cohete_alto, alto, 0.5, "%s debe medir su altura real" % id)
		assert_eq(plataforma._secciones.size(), 1, "el modelo entra de una pieza")


func test_el_orden_del_manifiesto_es_el_de_los_lanzadores_reales() -> void:
	# El manifiesto va de menor a mayor, y con los cuatro modelos entregados eso tiene que coincidir
	# con la altura real de cada lanzador: si alguien mueve un modelo de categoría sin mirar, salta.
	var previo := 0.0
	for caso in ALTOS:
		var alto := float(catalogo.obtener(str(caso[0]))["alto_real_m"])
		assert_gt(alto, previo, "%s debe ser más alto que el anterior del manifiesto" % str(caso[0]))
		previo = alto


func test_un_cohete_sin_modelo_se_dibuja_por_codigo() -> void:
	# Propiedad que hay que conservar: el juego no depende de que el modelo exista. Los cuatro ya
	# tienen el suyo, así que se comprueba con un id que no tiene archivo.
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	assert_false(ResourceLoader.exists("res://assets/modelos/cohete_de_prueba.glb"))
	plataforma._on_card("cohete_de_prueba", 600.0, 0.0)
	assert_gt(plataforma._secciones.size(), 1, "sin modelo se monta por tramos")
	assert_null(plataforma._anim, "sin modelo no hay animación de armado")


func test_los_cuatro_modelos_traen_su_animacion_de_armado() -> void:
	# Los cuatro .glb llegaron con animación propia («Armado»): las etapas, la cofia y los
	# aceleradores entran volando hasta su sitio. Cuando un modelo la trae, manda ella y el montaje
	# dura lo que dure el archivo; cuando no, se monta por tramos con las grúas. Así una animación
	# nueva entra sin tocar código.
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	for caso in ALTOS:
		var id := str(caso[0])
		plataforma.elegido = ""
		plataforma._on_card(id, float(catalogo.obtener(id)["capacidad_kg"]), float(caso[1]))
		assert_not_null(plataforma._anim, "%s debe traer su AnimationPlayer" % id)
		assert_eq(plataforma._anim_nombre, "Armado",
			"%s: se usa la animación «Armado», no las copias numeradas que exporta Blender" % id)
		assert_gt(plataforma._duracion_montaje(), LaunchPadScript.DURACION_APARICION,
			"%s: el montaje dura lo que dure su animación" % id)
		# Al principio del montaje la animación está al principio; al final, al final.
		plataforma._montar(0.0, 0.0)
		assert_almost_eq(plataforma._anim.current_animation_position, 0.0, 0.05, id)
		plataforma._montar(1.0, 0.0)
		assert_almost_eq(plataforma._anim.current_animation_position,
			plataforma._anim.get_animation("Armado").length, 0.05, id)


func test_el_rover_espera_mirando_a_los_cohetes() -> void:
	# Lo primero que se ve de la partida: el rover en primer plano, de cara al sitio del horizonte
	# donde se levanta el cohete. Antes miraba a un ángulo fijo de tres cuartos y parecía estar de
	# espaldas a la decisión.
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	assert_lt(_desvio_del_rover(plataforma), 3.0, "sin cohete elegido ya mira al horizonte de la plataforma")
	for caso in ALTOS:
		var id := str(caso[0])
		plataforma.elegido = ""
		plataforma._on_card(id, float(catalogo.obtener(id)["capacidad_kg"]), float(caso[1]))
		assert_lt(_desvio_del_rover(plataforma), 3.0, "con el %s puesto el rover sigue de cara a su cohete" % id)


func test_el_rover_se_ve_igual_con_cualquier_cohete() -> void:
	# Fallo que hubo: la cámara del montaje se acercaba una fracción de lo que distaba el cohete.
	# Como cada lanzador se monta a una distancia distinta (el Saturno V, a 254 m; el Delta II, a
	# 90), esa fracción eran 30 m con uno y 11 con el otro: el rover, que no se mueve de su sitio,
	# cambiaba de tamaño al elegir otro cohete, y con los más altos la cámara se le iba por detrás
	# y desaparecía. El movimiento va ahora en metros fijos.
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	var distancias: Array[float] = []
	for caso in ALTOS:
		var id := str(caso[0])
		plataforma.elegido = ""
		plataforma._on_card(id, float(catalogo.obtener(id)["capacidad_kg"]), float(caso[1]))
		for avance in [0.0, 0.5, 1.0]:
			var camara: Vector3 = plataforma._camara_del_montaje(float(avance))
			assert_gt(camara.z, LaunchPadScript.ROVER_POS.z + 6.0,
				"%s: la cámara tiene que quedarse por delante del rover, nunca detrás" % id)
		distancias.append(plataforma._camara_del_montaje(1.0).distance_to(LaunchPadScript.ROVER_POS))
	var minima: float = distancias.min()
	var maxima: float = distancias.max()
	assert_lt(maxima - minima, 1.0,
		"el rover debe quedar a la misma distancia de la cámara con los cuatro cohetes (%s)" % str(distancias))


func test_al_abordar_el_rover_rueda_hasta_la_escotilla_y_luego_entra() -> void:
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	plataforma._on_card("cohete_medio", 900.0, 48.8)
	var salida: Vector3 = plataforma._rover.position
	plataforma._on_confirmar()
	assert_false(plataforma._riel.visible, "el manifiesto se retira mientras el rover aborda")
	_correr(plataforma, LaunchPadScript.DURACION_ABORDAJE * 0.5)
	var medio: Vector3 = plataforma._rover.position
	assert_lt(medio.distance_to(plataforma._cohete.position), salida.distance_to(plataforma._cohete.position),
		"a mitad del abordaje el rover está más cerca de su cohete")
	assert_true(plataforma._rover.visible, "a mitad de camino todavía se le ve")
	_correr(plataforma, LaunchPadScript.DURACION_ABORDAJE)
	assert_false(plataforma._rover.visible, "al final el rover ya está dentro")
	assert_true(plataforma._ascensor.visible, "y el ascensor sube por el costado del cohete")


func test_al_cambiar_de_cohete_el_rover_sale_y_se_vuelve_a_elegir() -> void:
	# Desde el hangar se vuelve con «‹ Cambiar de cohete». El rover está dentro del cohete, así que
	# no puede aparecer de golpe en su sitio: sale por donde entró, vuelve rodando y entonces se
	# retira el cohete del horizonte y el manifiesto queda otra vez sin nada marcado.
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	plataforma._on_card("cohete_medio", 900.0, 48.8)
	plataforma._on_confirmar()
	_correr(plataforma, LaunchPadScript.DURACION_ABORDAJE + 0.5)
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	plataforma.update_snapshot(sim.snapshot())
	assert_false(plataforma.visible, "con el cohete puesto manda el hangar")

	sim.ejecutar("design_remove", {"part_id": "cohete_medio"})
	plataforma.update_snapshot(sim.snapshot())
	assert_true(plataforma.visible, "al quitar el cohete vuelve la plataforma")
	assert_gt(plataforma._t_salida, -1.0, "y arranca la salida del rover")
	assert_true(plataforma._cohete.visible, "el cohete sigue en pie mientras el rover sale")
	assert_false(plataforma._riel.visible, "el manifiesto no vuelve hasta que el rover está fuera")
	_correr(plataforma, 0.2)
	assert_true(plataforma._rover.visible, "se le ve salir por la escotilla")

	_correr(plataforma, LaunchPadScript.DURACION_ABORDAJE + 0.5)
	assert_eq(plataforma.elegido, "", "vuelve la elección sin ningún cohete marcado")
	assert_almost_eq(plataforma._rover.position.distance_to(LaunchPadScript.ROVER_POS), 0.0, 0.01,
		"el rover termina donde esperaba al principio")
	assert_almost_eq(plataforma._rover.scale.x, 1.0, 0.01, "y a su tamaño")
	assert_false(plataforma._cohete.visible, "el cohete se retira del horizonte")
	assert_true(plataforma._riel.visible, "y vuelve el manifiesto")
	assert_lt(_desvio_del_rover(plataforma), 3.0, "otra vez de cara al horizonte")


func test_una_vez_empezado_el_abordaje_no_se_cambia_de_cohete() -> void:
	var sim := _simulacion()
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	plataforma._on_card("cohete_ligero", 600.0, 39.0)
	plataforma._on_confirmar()
	plataforma._on_card("cohete_super", 1800.0, 110.6)
	assert_eq(plataforma.elegido, "cohete_ligero", "ya está abordando: no se cambia a medio camino")


# ------------------------------------------------------------------ apoyos


## Ángulo, en grados, entre el frente del rover (−z) y la dirección a su cohete.
func _desvio_del_rover(plataforma: CanvasLayer) -> float:
	var rover: Node3D = plataforma._rover
	var destino: Vector3 = plataforma._cohete.position
	var hacia := Vector3(destino.x - rover.position.x, 0.0, destino.z - rover.position.z).normalized()
	var frente := -rover.global_transform.basis.z
	frente.y = 0.0
	return rad_to_deg(frente.normalized().angle_to(hacia))


## Hace correr la pantalla los segundos pedidos, en pasos de un cuadro a 60 Hz.
func _correr(plataforma: CanvasLayer, segundos: float) -> void:
	var paso := 1.0 / 60.0
	for _i in range(int(segundos / paso) + 1):
		plataforma._process(paso)
