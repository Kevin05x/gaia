extends GutTest
## Plan de mejoras del 15 nov, bloque 2: que se entienda el juego (docs/PLAN_MEJORAS.md).

const WorkshopScript := preload("res://scenes/b/workshop.gd")
const LaunchPadScript := preload("res://scenes/b/launch_pad.gd")

var _destino_antes := ""


func before_all() -> void:
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


func before_each() -> void:
	_destino_antes = Destino.id


func after_each() -> void:
	Destino.id = _destino_antes


## Simulación del destino con el catálogo adaptado, como la arma MissionRunner.
func _sim(destino: String) -> Simulation:
	Destino.id = destino
	var cfg := Destino.config(destino)
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	MissionRunner.adaptar_catalogo(catalogo, destino, float(cfg.get("factor_capacidad_cohete", 1.0)))
	return Simulation.new(Balance.desde_archivo(cfg["balance"]), Rules.desde_archivo(cfg["reglas"]),
		MapData.desde_archivo(cfg["mapa"]), catalogo, Economy.desde_archivo(cfg["economia"]))


## Hangar conectado a la simulación igual que en el juego: cada orden se ejecuta y vuelve un snapshot.
func _hangar(sim: Simulation) -> CanvasLayer:
	var hangar: CanvasLayer = add_child_autofree(WorkshopScript.new())
	hangar.command.connect(func(orden: String, carga: Dictionary) -> void:
		sim.ejecutar(orden, carga)
		hangar.update_snapshot(sim.snapshot()))
	return hangar


func _elegidas(sim: Simulation) -> Array:
	var ids: Array = []
	var seleccion: Dictionary = sim.snapshot()["workshop"]["selection"]
	for cat in seleccion:
		ids.append_array(seleccion[cat])
	ids.sort()
	return ids


# --- 2.4 Diseño recomendado ------------------------------------------------------------------------------------------

func test_2_4_marte_entra_al_hangar_con_el_diseno_recomendado() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	_hangar(sim).update_snapshot(sim.snapshot())
	var esperado := ["antena_rele", "camara", "chasis_base", "cohete_medio", "espectrometro", "panel_solar", "taladro",
		"trayectoria_rapida"]
	assert_eq(_elegidas(sim), esperado, "cohete medio, trayectoria rápida, chasis base, panel, relé y tres instrumentos")
	assert_true(sim.snapshot()["workshop"]["valid"], "y el diseño es válido")


func test_2_4_la_luna_recomienda_mmrtg() -> void:
	var sim := _sim("luna")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	_hangar(sim).update_snapshot(sim.snapshot())
	var elegidas := _elegidas(sim)
	assert_has(elegidas, "mmrtg", "en la Luna, energía que no depende del Sol")
	assert_does_not_have(elegidas, "panel_solar")
	assert_has(elegidas, "trayectoria_directa_luna")
	assert_true(sim.snapshot()["workshop"]["valid"], "y el diseño es válido")


func test_2_4_el_boton_vuelve_a_poner_el_diseno_recomendado() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	var recomendado := _elegidas(sim)
	sim.ejecutar("design_remove", {"part_id": "espectrometro"})
	sim.ejecutar("design_add", {"part_id": "dron"})
	sim.ejecutar("design_remove", {"part_id": "trayectoria_rapida"})
	sim.ejecutar("design_add", {"part_id": "trayectoria_hohmann"})
	hangar.update_snapshot(sim.snapshot())
	assert_ne(_elegidas(sim), recomendado, "el jugador lo cambió")
	assert_not_null(hangar._recomendado, "hay botón «Diseño recomendado»")
	hangar._recomendado.pressed.emit()
	assert_eq(_elegidas(sim), recomendado, "el botón lo restaura")


func test_2_4_la_plataforma_llega_con_el_cohete_medio_marcado() -> void:
	var sim := _sim("marte")
	var plataforma: CanvasLayer = add_child_autofree(LaunchPadScript.new())
	plataforma.update_snapshot(sim.snapshot())
	assert_eq(plataforma.elegido, "cohete_medio", "basta con abordar")
	plataforma._on_card("cohete_ligero", 600.0, 39.0)
	assert_eq(plataforma.elegido, "cohete_ligero", "y se puede elegir otro")
	plataforma._signature = ""
	plataforma.update_snapshot(sim.snapshot())
	assert_eq(plataforma.elegido, "cohete_ligero", "la marca recomendada no pisa la elección del jugador")


# --- 2.5 Aviso si falta un instrumento clave, con confirmación al despegar (sin bloquear) ----------------------------

func _textos_del_resumen(hangar: CanvasLayer) -> String:
	var textos := ""
	for etiqueta in hangar._summary_box.find_children("*", "Label", true, false):
		textos += (etiqueta as Label).text + "\n"
	return textos


func test_2_5_sin_taladro_se_avisa_en_rojo_y_no_bloquea() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	sim.ejecutar("design_remove", {"part_id": "taladro"})
	var taller: Dictionary = sim.snapshot()["workshop"]
	assert_has(taller["notices"], "MISSING_KEY:taladro", "la simulación avisa")
	assert_true(taller["valid"], "pero no bloquea")
	hangar.update_snapshot(sim.snapshot())
	assert_string_contains(_textos_del_resumen(hangar), "Sin taladro no podrás tomar muestras")


func test_2_5_despegar_sin_un_instrumento_clave_pide_confirmacion() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	sim.ejecutar("design_remove", {"part_id": "espectrometro"})
	hangar.update_snapshot(sim.snapshot())
	var ordenes: Array[String] = []
	hangar.command.connect(func(orden: String, _c: Dictionary) -> void: ordenes.append(orden))
	hangar.validated = true
	hangar._on_action()
	assert_false(ordenes.has("design_start"), "no despega todavía")
	assert_true(is_instance_valid(hangar._confirmacion), "pregunta antes")
	var botones: Array = hangar._confirmacion.find_children("*", "Button", true, false)
	assert_eq(botones.size(), 2, "«Volver al taller» y «Despegar igual»")
	(botones[1] as Button).pressed.emit()
	assert_true(ordenes.has("design_start"), "«Despegar igual» despega")


func test_2_5_con_todos_los_instrumentos_despega_sin_preguntar() -> void:
	var sim := _sim("marte")
	sim.ejecutar("design_add", {"part_id": "cohete_medio"})
	var hangar := _hangar(sim)
	hangar.update_snapshot(sim.snapshot())
	assert_eq(WorkshopScript.clave_que_faltan(sim.snapshot()["workshop"]), [])
	var ordenes: Array[String] = []
	hangar.command.connect(func(orden: String, _c: Dictionary) -> void: ordenes.append(orden))
	hangar.validated = true
	hangar._on_action()
	assert_true(ordenes.has("design_start"))
	assert_false(is_instance_valid(hangar._confirmacion))
