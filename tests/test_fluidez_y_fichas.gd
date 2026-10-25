extends GutTest
## Ronda E: guardar al salir, detener o redirigir la marcha, fichas de edificios, niebla lejana y rendimiento
## (precalentado de sombreadores, modelos en caché y menú que no se rehace en cada extracción).

const Sesion := preload("res://scenes/menu/game_session.gd")
const BaseHud := preload("res://scenes/b/base_hud.gd")
const HudScript := preload("res://scenes/b/hud.gd")
const SkyScript := preload("res://scenes/b/sky_light.gd")
const Equipo := preload("res://scenes/b/modelos_equipo.gd")
const BuildingsScript := preload("res://scenes/b/buildings.gd")
const PortScript := preload("res://scenes/b/port.gd")
const RUTA_PRUEBA := "user://prueba_fluidez.dat"

var sim: Simulation


func before_all() -> void:
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")
	Sesion.ruta = RUTA_PRUEBA


func after_all() -> void:
	Sesion.borrar()
	Sesion.ruta = Sesion.RUTA


func before_each() -> void:
	sim = Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"),
		Economy.desde_archivo("res://content/economia.json"))
	for id in ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele", "camara", "espectrometro", "taladro", "radar"]:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")


# --- Guardado -------------------------------------------------------------------------------------------------------

func test_lo_juntado_se_conserva_al_guardar_y_continuar() -> void:
	sim.estado.recursos["rocas"] = 87
	sim.estado.recursos["olivino"] = 23
	assert_true(sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(-11, -11)})["ok"])
	assert_true(Sesion.guardar(sim))
	var otra := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"), Economy.desde_archivo("res://content/economia.json"))
	assert_true(otra.cargar(Sesion.leer()))
	var snap := otra.snapshot()
	assert_eq(int(snap["resources"]["rocas"]), 67, "87 menos los 20 del panel")
	assert_eq(int(snap["resources"]["olivino"]), 23)
	assert_eq((snap["buildings"] as Array).filter(func(b: Dictionary) -> bool: return b["type"] == "panel_solar").size(), 1,
		"la obra empezada también vuelve")


func test_salir_al_menu_guarda_la_partida() -> void:
	var port: Node = autofree(PortScript.new())
	var runner := MissionRunner.new()
	runner.crear_vista = false
	runner.saltar_taller = true
	runner.port = port
	add_child_autofree(runner)
	Sesion.borrar()
	assert_false(runner.guardar_partida(), "en el aterrizaje no hay nada que continuar")
	port.submit("landing_finished")
	runner.sim.estado.recursos["rocas"] = 140
	assert_true(runner.guardar_partida())
	assert_true(Sesion.hay_guardado())
	assert_eq(int(Sesion.leer()["estado"]["recursos"]["rocas"]), 140)


# --- Detener o redirigir la marcha ----------------------------------------------------------------------------------

func _en_marcha(destino: Vector2i) -> void:
	var r := sim.ejecutar("move", {"tile": destino})
	assert_true(r["ok"], "la marcha empieza")
	sim.avanzar(float(r["seconds_per_tile"]) * 1.5)  # va a mitad del segundo tramo
	assert_true(sim.estado.en_movimiento)


func test_esc_detiene_al_rover_en_la_casilla_que_pisa() -> void:
	_en_marcha(Vector2i(6, 0))
	var bateria := sim.estado.bateria_wh
	var r := sim.ejecutar("stop")
	assert_true(r["ok"])
	assert_false(sim.estado.en_movimiento)
	assert_eq((r["path"] as Array).size(), 1, "solo le queda terminar el tramo que estaba recorriendo")
	assert_eq(sim.estado.casilla_rover, r["path"][0])
	assert_gt(sim.estado.bateria_wh, bateria, "devuelve la energía del camino que ya no hará")
	assert_eq(sim.ejecutar("stop")["reason"], "NOT_MOVING")


func test_otra_casilla_redirige_la_marcha() -> void:
	_en_marcha(Vector2i(6, 0))
	var r := sim.ejecutar("move", {"tile": Vector2i(0, 5)})
	assert_true(r["ok"])
	assert_true(r.get("redirected", false))
	var camino: Array = r["path"]
	assert_eq(camino[camino.size() - 1], Vector2i(0, 5), "llega al destino nuevo")
	assert_true(sim.estado.en_movimiento)
	for i in range(400):
		sim.avanzar(0.2)
	assert_eq(sim.estado.casilla_rover, Vector2i(0, 5))


func test_esc_en_el_hud_pide_detener_si_el_rover_va_en_marcha() -> void:
	var hud: CanvasLayer = HudScript.new()
	add_child_autofree(hud)
	hud.build()
	var pedidos: Array = []
	hud.command.connect(func(orden: String, _datos: Dictionary) -> void: pedidos.append(orden))
	var snap := sim.snapshot()
	snap["moving"] = true
	hud.update_snapshot(snap)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	hud._unhandled_input(esc)
	assert_eq(pedidos, ["stop"])


# --- Fichas de edificios --------------------------------------------------------------------------------------------

func test_cada_edificio_tiene_foto_y_textos_de_ficha() -> void:
	for op in sim.snapshot()["build_options"]:
		var tipo := str(op["id"])
		assert_not_null(BaseHud.foto_de(tipo), "foto de " + tipo)
		var clave := "BLD_DESC_" + BaseHud._clave(tipo)
		assert_ne(tr(clave), clave, "descripción de " + tipo)
		assert_true(op.has("info") and float(op["info"]["hp"]) > 0.0, "datos de " + tipo)
	assert_not_null(BaseHud.foto_de("nave_fuga"))


func test_la_ficha_muestra_datos_y_permite_construir() -> void:
	var base := BaseHud.new()
	add_child_autofree(base)
	var pedidos: Array = []
	base.placement_requested.connect(func(tipo: String) -> void: pedidos.append(tipo))
	sim.estado.recursos["rocas"] = 150
	sim.estado.recursos["olivino"] = 100
	base.update_snapshot(sim.snapshot())
	base.toggle_menu()
	(base._filas["torreta"]["info"] as Button).pressed.emit()
	assert_true(base.ficha_abierta())
	assert_eq((base._ficha.get_meta("titulo") as Label).text, tr("BLD_TURRET"))
	assert_not_null((base._ficha.get_meta("foto") as TextureRect).texture)
	var textos: Array = (base._ficha.get_meta("datos") as GridContainer).get_children().map(func(n: Node) -> String: return (n as Label).text)
	assert_has(textos, tr("INFO_DAMAGE"), "una torreta muestra su daño")
	assert_has(textos, tr("INFO_RANGE"))
	(base._ficha.get_meta("construir") as Button).pressed.emit()
	assert_eq(pedidos, ["torreta"])
	assert_false(base.ficha_abierta())
	assert_false(base.menu.visible)


func test_el_menu_no_se_rehace_cuando_solo_cambian_los_recursos() -> void:
	var base := BaseHud.new()
	add_child_autofree(base)
	base.update_snapshot(sim.snapshot())
	base.toggle_menu()
	var fila: Button = base._filas["panel_solar"]["button"]
	sim.estado.recursos["rocas"] = 5
	base.update_snapshot(sim.snapshot())
	assert_eq(base._filas["panel_solar"]["button"], fila, "la misma fila, solo con sus textos al día")
	assert_true(fila.disabled, "sin rocas no se puede")
	assert_true((base._filas["panel_solar"]["reason"] as Label).visible)


# --- Niebla y rendimiento -------------------------------------------------------------------------------------------

func test_la_niebla_no_tapa_el_mapa_jugable() -> void:
	var cielo: Node = autofree(SkyScript.new())
	for hora in [0.0, 6.0, 12.0, 18.5]:
		assert_gte(float(cielo._sample(hora)["begin"]), 140.0, "a las %s el mapa (142 m de lado) se ve nítido" % hora)


func test_los_modelos_del_equipo_se_leen_una_sola_vez() -> void:
	Equipo.vaciar()
	var a: Node3D = autofree(Node3D.new())
	var b: Node3D = autofree(Node3D.new())
	var primero := Equipo.poner(a, "torreta_simple", 1.5)
	var segundo := Equipo.poner(b, "torreta_simple", 1.5)
	assert_false(primero.is_empty())
	assert_eq(primero.size(), segundo.size())
	assert_eq(primero[0].mesh, segundo[0].mesh, "comparten la malla ya cargada")
	assert_true(Equipo._cache.has("torreta_simple"))


func test_hay_muestras_de_todos_los_edificios_para_precalentar() -> void:
	var edificios: Node3D = autofree(BuildingsScript.new())
	var muestras: Array = edificios.muestras_para_precalentar()
	assert_gt(muestras.size(), 16, "cada edificio, terminado y en obra")
	var con_obra := 0
	for m in muestras:
		for malla in m.find_children("*", "MeshInstance3D", true, false):
			if (malla as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial:
				con_obra += 1
				break
		m.free()
	assert_gt(con_obra, 5, "las obras usan el material de revelado")


func test_la_vista_precalienta_y_quita_la_cortina() -> void:
	var juego: Node = load("res://scenes/a/game.tscn").instantiate()
	add_child_autofree(juego)
	await get_tree().process_frame
	var vista: Node = juego.view
	assert_not_null(vista.warmup)
	assert_true(vista.warmup.activo() or not is_instance_valid(vista.cortina))
	assert_gt(vista.warmup.cantidad(), 30, "edificios, monstruos y efectos en reserva")
	for i in range(30):
		await get_tree().process_frame
	assert_false(vista.warmup.activo())
	assert_eq(vista.warmup.get_child_count(), 0, "las muestras se borran")
	await get_tree().create_timer(0.5).timeout
	assert_false(is_instance_valid(vista.cortina), "la cortina se desvanece")
