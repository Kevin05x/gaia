extends GutTest
## Pruebas del rediseño visual: cielo por hora, relieve, minimapa, taller y HUD.
## Son pruebas de comportamiento sin render: la vista solo presenta lo que entrega la simulación.

const SkyScript := preload("res://scenes/b/sky_light.gd")
const TerrainScript := preload("res://scenes/b/terrain.gd")
const MinimapScript := preload("res://scenes/b/minimap.gd")
const WorkshopScript := preload("res://scenes/b/workshop.gd")
const HudScript := preload("res://scenes/b/hud.gd")
const UIStyleScript := preload("res://scenes/b/ui_style.gd")
const ArtScript := preload("res://scenes/b/art.gd")
const WorldArt := preload("res://scenes/b/world_art.gd")
const TracksScript := preload("res://scenes/b/tracks.gd")
const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]

var sim: Simulation


func before_all() -> void:
	# Mismas traducciones que registra MissionView.setup_locale(), sin crear la vista.
	var tablas = preload("res://scenes/b/i18n/catalog.gd").TABLES
	for idioma in tablas:
		var traduccion := Translation.new()
		traduccion.locale = idioma
		for clave in tablas[idioma]:
			traduccion.add_message(clave, tablas[idioma][clave])
		TranslationServer.add_translation(traduccion)
	TranslationServer.set_locale("es")


func before_each() -> void:
	sim = Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"))


func _operar() -> Dictionary:
	for id in DISENO:
		assert_true(sim.ejecutar("design_add", {"part_id": id})["ok"], id)
	assert_true(sim.ejecutar("design_start")["ok"])
	assert_true(sim.ejecutar("landing_finished")["ok"])
	return sim.snapshot()


# ------------------------------------------------------------------ cielo

func test_cielo_mediodia_tiene_sol_y_medianoche_no() -> void:
	var cielo: Node = autofree(SkyScript.new())
	assert_almost_eq(float(cielo._sample(12.0)["sun_energy"]), 1.0, 0.001)
	assert_almost_eq(float(cielo._sample(0.0)["sun_energy"]), 0.0, 0.001)
	assert_almost_eq(float(cielo._sample(22.0)["sun_energy"]), 0.0, 0.001)


func test_cielo_es_continuo_al_cambiar_de_dia() -> void:
	var cielo: Node = autofree(SkyScript.new())
	var antes: Dictionary = cielo._sample(23.999)
	var despues: Dictionary = cielo._sample(0.0)
	assert_almost_eq(float(antes["elevation"]), float(despues["elevation"]), 0.05)
	assert_true((antes["fog"] as Color).is_equal_approx(despues["fog"]))


func test_cielo_la_energia_solar_sube_de_la_madrugada_al_mediodia() -> void:
	var cielo: Node = autofree(SkyScript.new())
	var anterior := -1.0
	for h in [5.0, 5.5, 6.0, 6.5, 7.0, 9.0, 12.0]:
		var e := float(cielo._sample(h)["sun_energy"])
		assert_gte(e, anterior, "la energía no baja hasta el mediodía (h=%s)" % h)
		anterior = e


func test_cielo_el_polvo_atenua_el_sol_y_acerca_la_niebla() -> void:
	var cielo: Node = autofree(SkyScript.new())
	var env := Environment.new()
	var luz: DirectionalLight3D = autofree(DirectionalLight3D.new())
	cielo.setup(env, luz)
	cielo.set_state(12.0, 0.0)
	cielo.apply(true)
	var sol_limpio := luz.light_energy
	var niebla_limpia := env.fog_depth_end
	cielo.set_state(12.0, 1.0)
	cielo.apply(true)
	assert_lt(luz.light_energy, sol_limpio, "con tormenta el sol llega más débil")
	assert_lt(env.fog_depth_end, niebla_limpia, "con tormenta la niebla se acerca")
	assert_false(luz.shadow_enabled, "con mucho polvo no hay sombras duras")


func test_cielo_de_noche_apaga_el_sol_y_las_sombras() -> void:
	var cielo: Node = autofree(SkyScript.new())
	var env := Environment.new()
	var luz: DirectionalLight3D = autofree(DirectionalLight3D.new())
	cielo.setup(env, luz)
	cielo.set_state(2.0, 0.0)
	cielo.apply(true)
	assert_false(luz.visible)
	assert_false(luz.shadow_enabled)


func test_cielo_limita_hora_y_polvo() -> void:
	var cielo: Node = autofree(SkyScript.new())
	cielo.set_state(27.0, 5.0)
	assert_almost_eq(float(cielo.hour), 3.0, 0.001)
	assert_almost_eq(float(cielo.dust), 1.0, 0.001)


# ------------------------------------------------------------------ relieve

func test_relieve_es_finito_y_continuo_en_la_zona_jugable() -> void:
	var mundo: Node3D = autofree(TerrainScript.new())
	var maximo := 0.0
	var minimo := 0.0
	for i in range(-23, 24):
		for j in range(-23, 24):
			var h := float(mundo.height_at(float(i), float(j)))
			assert_true(is_finite(h))
			maximo = maxf(maximo, h)
			minimo = minf(minimo, h)
			var vecino := float(mundo.height_at(i + 0.2, j + 0.2))
			assert_lt(absf(h - vecino), 0.6, "sin escalones bruscos en (%d,%d)" % [i, j])
	assert_lt(maximo - minimo, 3.5, "la zona jugable es casi llana")


func test_relieve_fuera_de_la_malla_es_el_plano_de_la_cuenca() -> void:
	var mundo: Node3D = autofree(TerrainScript.new())
	assert_almost_eq(float(mundo.height_at(120.0, 0.0)), TerrainScript.BASIN_Y, 0.001)
	assert_almost_eq(float(mundo.height_at(0.0, -90.0)), TerrainScript.BASIN_Y, 0.001)


func test_colinas_exteriores_empalman_y_dejan_libre_el_pasillo_del_lago() -> void:
	var mundo: Node3D = autofree(TerrainScript.new())
	for z in range(-30, 31, 10):
		assert_lt(absf(float(mundo.height_at(39.9, float(z))) - float(mundo.height_at(40.1, float(z)))), 0.35, "sin escalón en el borde de la malla detallada (z=%d)" % z)
	var dir: Vector2 = TerrainScript.LAKE_CENTER.normalized()
	var en_pasillo := dir * 55.0
	assert_lt(float(mundo.height_at(en_pasillo.x, en_pasillo.y)), TerrainScript.BASIN_Y + 2.5, "el pasillo hacia el lago queda bajo")
	var maximo := -10.0
	for k in range(36):
		var a := TAU * k / 36.0
		maximo = maxf(maximo, float(mundo.height_at(cos(a) * 58.0, sin(a) * 58.0)))
	assert_gt(maximo, TerrainScript.BASIN_Y + 3.0, "hay colinas alrededor")


func test_farallones_se_construyen_con_sombra_en_calidad_alta() -> void:
	var mundo: Node3D = add_child_autofree(TerrainScript.new())
	mundo.configure([{"id": "A", "tile": Vector2i(1, 1), "type": "rock", "revealed": true}], [], {})
	var grupos := 0
	for hijo in mundo._decor.get_children():
		if str(hijo.name).begins_with("Cliffs_"):
			grupos += 1
			assert_gt((hijo as MultiMeshInstance3D).multimesh.instance_count, 0)
	assert_gt(grupos, 2, "varios tipos de farallón y bloque caído")


func test_decoracion_tiene_sombras_de_contacto_y_guijarros_alrededor_de_las_rocas() -> void:
	var mundo: Node3D = add_child_autofree(TerrainScript.new())
	mundo.configure([{"id": "A", "tile": Vector2i(1, 1), "type": "rock", "revealed": true}], [Vector2i(3, 3)], {})
	var sombras := 0
	var halos := 0
	for hijo in mundo._decor.get_children():
		if str(hijo.name).begins_with("ContactShadows"):
			sombras += (hijo as MultiMeshInstance3D).multimesh.instance_count
		elif str(hijo.name).begins_with("Decor_halo_"):
			halos += (hijo as MultiMeshInstance3D).multimesh.instance_count
	assert_gt(sombras, 10, "sombras de contacto (una llamada de dibujo por trozo)")
	assert_gt(halos, 20, "guijarros caídos alrededor de las rocas grandes")


func test_huellas_dejan_marcas_discontinuas() -> void:
	var huellas: MeshInstance3D = add_child_autofree(TracksScript.new())
	huellas.ground = func(_x: float, _z: float) -> float: return 0.0
	huellas.seed_curve(Vector3.ZERO, 6.0)
	var v: PackedVector3Array = huellas.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(v.size(), 0)
	assert_eq(v.size() % 6, 0, "cada marca es un cuadrilátero de dos triángulos")


func test_terreno_reconoce_los_limites_del_mapa() -> void:
	var mundo: Node3D = autofree(TerrainScript.new())
	assert_true(mundo.in_bounds(Vector2i(0, 0)))
	assert_true(mundo.in_bounds(Vector2i(11, -11)))
	assert_false(mundo.in_bounds(Vector2i(12, 0)))
	assert_false(mundo.in_bounds(Vector2i(0, -12)))


# ------------------------------------------------------------------ minimapa

func test_minimapa_casilla_y_punto_son_inversos() -> void:
	var mapa: Control = autofree(MinimapScript.new())
	mapa.size = Vector2(136, 136)
	mapa.state = {"bounds": {"min": Vector2i(-11, -11), "max": Vector2i(11, 11)}}
	for x in range(-11, 12, 5):
		for y in range(-11, 12, 5):
			var casilla := Vector2i(x, y)
			assert_eq(mapa.tile_at(mapa.point(casilla)), casilla)


func test_minimapa_el_rover_en_la_esquina_cae_dentro_del_control() -> void:
	var mapa: Control = autofree(MinimapScript.new())
	mapa.size = Vector2(136, 136)
	mapa.state = {"bounds": {"min": Vector2i(-11, -11), "max": Vector2i(11, 11)}}
	var p: Vector2 = mapa.point(Vector2i(-11, -11))
	assert_true(Rect2(Vector2.ZERO, mapa.size).has_point(p))
	var q: Vector2 = mapa.point(Vector2i(11, 11))
	assert_true(Rect2(Vector2.ZERO, mapa.size).has_point(q))


# ------------------------------------------------------------------ taller

func test_taller_solo_se_muestra_en_la_fase_taller() -> void:
	var taller: CanvasLayer = add_child_autofree(WorkshopScript.new())
	taller.update_snapshot(sim.snapshot())
	assert_true(taller.visible)
	taller.update_snapshot(_operar())
	assert_false(taller.visible)


func test_taller_pide_agregar_y_quitar_piezas_a_la_simulacion() -> void:
	var taller: CanvasLayer = add_child_autofree(WorkshopScript.new())
	var ordenes: Array = []
	taller.command.connect(func(orden: String, carga: Dictionary) -> void: ordenes.append([orden, carga]))
	var s := sim.snapshot()
	taller.update_snapshot(s)
	var pieza := {"id": "cohete_ligero", "available": true, "reason": ""}
	taller._on_card(pieza, false)
	assert_eq(ordenes[0][0], "design_add")
	assert_eq(ordenes[0][1]["part_id"], "cohete_ligero")
	taller._on_card(pieza, true)
	assert_eq(ordenes[1][0], "design_remove")


func test_taller_valida_antes_de_iniciar() -> void:
	var taller: CanvasLayer = add_child_autofree(WorkshopScript.new())
	var ordenes: Array[String] = []
	taller.command.connect(func(orden: String, _carga: Dictionary) -> void: ordenes.append(orden))
	for id in DISENO:
		sim.ejecutar("design_add", {"part_id": id})
	taller.update_snapshot(sim.snapshot())
	taller._on_action()
	assert_eq(ordenes, ["design_validate"])
	taller.update_snapshot(sim.snapshot())
	taller._on_action()
	assert_eq(ordenes.size(), 2)


func test_taller_cambia_la_pieza_unica_de_la_categoria() -> void:
	var taller: CanvasLayer = add_child_autofree(WorkshopScript.new())
	var ordenes: Array[String] = []
	taller.command.connect(func(orden: String, _carga: Dictionary) -> void: ordenes.append(orden))
	sim.ejecutar("design_add", {"part_id": "cohete_ligero"})
	taller.update_snapshot(sim.snapshot())
	taller.category = "cohetes"
	var otra := {"id": "cohete_pesado", "available": true, "reason": "CATEGORY_FULL"}
	taller._on_card(otra, false)
	assert_eq(ordenes, ["design_remove", "design_add"], "primero quita la actual y luego agrega la elegida")


# ------------------------------------------------------------------ HUD

func test_hud_muestra_los_controles_de_operacion_solo_al_operar() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	hud.update_snapshot(sim.snapshot())
	for c in hud._ops:
		assert_false(c.visible, "en el taller no hay controles de operación")
	hud.update_snapshot(_operar())
	for c in hud._ops:
		assert_true(c.visible)


func test_hud_envia_la_accion_del_objetivo_seleccionado() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	var ordenes: Array = []
	hud.command.connect(func(orden: String, carga: Dictionary) -> void: ordenes.append([orden, carga]))
	hud.set_target("objetivo_x")
	hud._run_action("spectrometer")
	hud._run_action("approach")
	hud._run_action("")
	assert_eq(ordenes.size(), 2)
	assert_eq(ordenes[0][0], "act")
	assert_eq(ordenes[0][1], {"target_id": "objetivo_x", "action": "spectrometer"})
	assert_eq(ordenes[1][0], "approach")


func test_hud_en_modo_seguro_y_con_tormenta_no_rompe() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	var s := _operar()
	s["safe_mode"] = true
	s["storm"] = true
	s["is_night"] = true
	hud.update_snapshot(s)
	assert_true(is_instance_valid(hud.root))


# ------------------------------------------------------------------ mallas, mundo y huellas

func test_fusion_de_mallas_junta_las_piezas_y_respeta_las_excluidas() -> void:
	var grupo: Node3D = autofree(Node3D.new())
	ArtScript.box(grupo, Vector3.ONE, Vector3(0, 0, 0), ArtScript.IVORY)
	ArtScript.box(grupo, Vector3.ONE, Vector3(2, 0, 0), ArtScript.DARK)
	ArtScript.cylinder(grupo, 0.5, 1.0, Vector3(4, 0, 0), ArtScript.BLUE)
	var aparte := ArtScript.box(grupo, Vector3.ONE, Vector3(6, 0, 0), ArtScript.ORANGE)
	aparte.name = "Aparte"
	ArtScript.merged(grupo, func(c: Node) -> bool: return c.name == "Aparte")
	assert_eq(grupo.get_child_count(), 2, "una malla fusionada y la pieza excluida")
	var fusionada := grupo.get_node("Merged") as MeshInstance3D
	assert_eq(fusionada.mesh.get_surface_count(), 1)
	assert_eq(fusionada.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].size(), fusionada.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	await get_tree().process_frame


func test_rover_optimizado_conserva_las_piezas_que_se_animan() -> void:
	var rover: Node3D = autofree(preload("res://scenes/b/assets/models/rover.tscn").instantiate())
	var antes := rover.find_children("*", "MeshInstance3D", true, false).size()
	ArtScript.optimize_rover(rover)
	await get_tree().process_frame
	var despues := rover.find_children("*", "MeshInstance3D", true, false).size()
	assert_lt(despues, antes / 3.0, "muchas menos mallas (llamadas de dibujo)")
	for nombre in ["Wheel0", "Wheel5", "arm", "head", "solar", "rtg", "drill", "radar", "spectrometer", "meteo"]:
		assert_not_null(rover.find_child(nombre, true, false), nombre)


func test_mesetas_y_peniascos_tienen_geometria_valida() -> void:
	for malla in [WorldArt.mesa_mesh(0), WorldArt.mesa_mesh(1), WorldArt.rock_mesh("boulder", 0), WorldArt.rock_mesh("pebble", 0)]:
		assert_eq(malla.get_surface_count(), 1)
		var n: int = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		assert_gt(n, 0)
		assert_eq(n % 3, 0, "solo triángulos")


func test_piedras_facetadas_son_solidos_cerrados_y_distintos_por_variante() -> void:
	for familia in WorldArt.STONE_PRESETS:
		var vistas := {}
		for v in range(3):
			var malla: ArrayMesh = WorldArt.rock_mesh(familia, v)
			var vertices: PackedVector3Array = malla.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert_gte(vertices.size(), 12, "%s%d tiene al menos un tetraedro" % [familia, v])
			assert_eq(vertices.size() % 3, 0)
			vistas[vertices.size()] = true
			var caja := malla.get_aabb()
			assert_gt(caja.size.y, 0.1, "%s%d no es plana" % [familia, v])
			assert_lt(caja.size.x, 4.0, "%s%d no se dispara" % [familia, v])
		assert_gte(vistas.size(), 1)


func test_calidad_baja_quita_texturas_y_sombras_de_rocas() -> void:
	var mundo: Node3D = add_child_autofree(TerrainScript.new())
	mundo.configure([{"id": "A", "tile": Vector2i(1, 1), "type": "rock", "revealed": true}], [], {})
	WorldArt.quality = true
	WorldArt.ground_material()
	WorldArt.apply_quality()
	assert_not_null(WorldArt.ground_material().albedo_texture)
	mundo.apply_quality()
	var con_sombra := 0
	for hijo in mundo._decor.get_children():
		if hijo is GeometryInstance3D and hijo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			con_sombra += 1
	assert_gt(con_sombra, 0, "en calidad alta las rocas grandes proyectan sombra")
	WorldArt.quality = false
	WorldArt.apply_quality()
	mundo.apply_quality()
	assert_null(WorldArt.ground_material().albedo_texture)
	for hijo in mundo._decor.get_children():
		if hijo is GeometryInstance3D:
			assert_eq(hijo.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	WorldArt.quality = true
	WorldArt.apply_quality()


func test_cajas_biseladas_y_antenas_son_mallas_validas() -> void:
	var caja: ArrayMesh = ArtScript.bevel_mesh(Vector3(1.5, 0.4, 1.9), 0.06)
	var v: PackedVector3Array = caja.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_gt(v.size(), 36, "más caras que una caja simple (tiene chaflanes)")
	assert_eq(v.size() % 3, 0)
	assert_almost_eq(caja.get_aabb().size.x, 1.5, 0.01)
	assert_almost_eq(caja.get_aabb().size.z, 1.9, 0.01)
	var plato: ArrayMesh = ArtScript.dish_mesh(0.5, 0.2)
	assert_gt(plato.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 100)
	assert_almost_eq(plato.get_aabb().size.x, 1.0, 0.05)


func test_fusion_acepta_mallas_propias() -> void:
	var nodo: Node3D = autofree(Node3D.new())
	for i in range(3):
		ArtScript.rbox(nodo, Vector3.ONE * 0.5, Vector3(i, 0, 0), Color.WHITE)
	ArtScript.merged(nodo)
	assert_eq(nodo.get_child_count(), 1)
	assert_eq(nodo.get_child(0).name, "Merged")


func test_fila_de_acciones_no_se_monta_sobre_comunicacion() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	hud.update_snapshot(_operar())
	var ancho: float = hud.root.size.x
	hud._comms.size = Vector2(336, 72)
	hud._layout_actions()
	var derecha: float = hud._actions_row.offset_right
	assert_lte(derecha, ancho - 20.0 - 336.0, "la fila termina antes del panel de comunicación")
	assert_gte(hud._actions_row.offset_left, 170.0, "ni sobre el reloj")


func test_botones_principales_usan_la_variante_ambar() -> void:
	var tema: Theme = UIStyleScript.theme()
	assert_true(tema.has_stylebox("normal", "PrimaryButton"))
	var normal: StyleBoxFlat = tema.get_stylebox("normal", "PrimaryButton")
	assert_gt(normal.bg_color.r, 0.8, "relleno ámbar claro")
	var taller: CanvasLayer = add_child_autofree(WorkshopScript.new())
	assert_eq(taller._action.theme_type_variation, "PrimaryButton")


func test_contorno_del_objetivo_no_se_acumula() -> void:
	var mundo: Node3D = add_child_autofree(TerrainScript.new())
	mundo.configure([{"id": "A", "tile": Vector2i(1, 1), "type": "rock", "revealed": true}], [], {})
	var objetivo: Node3D = mundo.targets["A"]
	var piezas := objetivo.get_child_count()
	mundo.select("A")
	var con_contorno := objetivo.get_child_count()
	assert_eq(con_contorno, piezas * 2, "un contorno por pieza")
	for i in range(5):
		mundo.select("A")
	assert_eq(objetivo.get_child_count(), con_contorno, "seleccionar de nuevo no crea más contornos")
	mundo.select("")
	await get_tree().process_frame
	assert_eq(objetivo.get_child_count(), piezas, "al deseleccionar se quitan")


func test_huellas_iniciales_dibujan_dos_bandas() -> void:
	var huellas: MeshInstance3D = add_child_autofree(TracksScript.new())
	huellas.ground = func(_x: float, _z: float) -> float: return 0.0
	huellas.seed_curve(Vector3.ZERO, 6.0)
	assert_eq(huellas.mesh.get_surface_count(), 1)
	assert_gt(huellas.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size(), 12)


# ------------------------------------------------------------------ antena, tipografía, mapa y título

func _mallas(nodo: Node) -> int:
	var cuenta := 0
	for h in nodo.get_children():
		if h is MeshInstance3D:
			cuenta += 1
		cuenta += _mallas(h)
	return cuenta


func test_cada_nivel_de_antena_suma_modulos_nuevos() -> void:
	var estacion: Node3D = autofree(Node3D.new())
	var niveles: Array = preload("res://scenes/b/art.gd").station(estacion)
	assert_eq(niveles.size(), 3)
	var piezas: Array[int] = []
	for n in niveles:
		piezas.append(_mallas(n))
	assert_gt(piezas[1], piezas[0] + 15, "el nivel 2 añade relé, armario y panel solar")
	assert_gt(piezas[2], piezas[1] + 25, "el nivel 3 añade búnker, radomo, matriz y segundo relé")


func test_fuentes_del_proyecto_son_variables_con_grosor() -> void:
	var texto := UIStyleScript.text_font(560) as FontVariation
	assert_not_null(texto)
	assert_not_null(texto.base_font)
	assert_eq(texto.variation_opentype.get(UIStyleScript.WGHT), 560)
	var titulo := UIStyleScript.display_font(700, 5) as FontVariation
	assert_eq(titulo.spacing_glyph, 5)
	assert_eq(titulo.variation_opentype.get(UIStyleScript.WGHT), 700)
	assert_true(ResourceLoader.exists("res://assets/fonts/Inter.ttf"))
	assert_true(ResourceLoader.exists("res://assets/fonts/SpaceGrotesk.ttf"))


func test_pildoras_de_energia_y_ciencia_se_ajustan_y_no_se_pisan() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	hud.update_snapshot(_operar())
	hud._science_text.text = "Ciencia 1234/5000 muestras"
	hud._energy_text.text = "Energía 100 % · modo ahorro"
	hud._fit_top_right()
	for par in [[hud._science_pill, hud._science_text], [hud._energy_pill, hud._energy_text]]:
		var pildora: Button = par[0]
		var etiqueta: Label = par[1]
		var ancho: float = etiqueta.get_theme_font("font").get_string_size(etiqueta.text, HORIZONTAL_ALIGNMENT_LEFT, -1, etiqueta.get_theme_font_size("font_size")).x
		assert_gte(pildora.offset_right - pildora.offset_left, ancho + 23.0, "el texto cabe dentro de la píldora")
	assert_lte(hud._energy_pill.offset_right, hud._science_pill.offset_left, "la energía no pisa a la ciencia")
	assert_lte(hud._science_pill.offset_right, hud.pause_button.offset_left, "la ciencia no pisa la pausa")


func test_titulo_con_emblema_solo_fuera_del_taller() -> void:
	var hud: CanvasLayer = add_child_autofree(HudScript.new())
	hud.update_snapshot(sim.snapshot())
	assert_false(hud._mark.visible, "en el taller no hay título")
	hud.update_snapshot(_operar())
	assert_true(hud._mark.visible, "en operación se ve el logotipo 3D")
	assert_false(hud._title.visible, "el rótulo de texto solo se usa en el aterrizaje")


func test_minimapa_el_rover_apunta_hacia_donde_se_mueve() -> void:
	var mapa: Control = autofree(MinimapScript.new())
	mapa.size = Vector2(168, 168)
	mapa.state = {"rover_tile": Vector2i(0, 0)}
	mapa.state = {"rover_tile": Vector2i(3, 0)}
	assert_eq(mapa._heading, Vector2(1, 0))
	mapa.state = {"rover_tile": Vector2i(3, -2)}
	assert_eq(mapa._heading, Vector2(0, -1))
	assert_true(mapa._inside(Vector2i(0, 0)))
	assert_false(mapa._inside(Vector2i(12, 0)))


func test_mapa_grande_ensancha_el_mundo_y_reparte_las_rocas_en_trozos() -> void:
	var mundo: Node3D = add_child_autofree(TerrainScript.new())
	mundo.lazy = false
	mundo.configure([{"id": "A", "tile": Vector2i(1, 1), "type": "rock", "revealed": true}], [Vector2i(3, 3), Vector2i(-20, 15)],
		{"min": Vector2i(-35, -35), "max": Vector2i(35, 35)}, [{"id": "orilla", "center": Vector2i(-12, -12)}, {"id": "nucleo", "center": Vector2i(10, 26)}])
	assert_eq(mundo.extra_size(), 48.0)
	assert_true(mundo.in_bounds(Vector2i(35, -35)))
	assert_lt(absf(float(mundo.height_at(60.0, 60.0))), 3.5, "el área jugable sigue llana")
	assert_almost_eq(float(mundo.height_at(60.0, 130.0)), float(mundo.height_at(60.0, 129.0)), 1.0)
	var trozos := 0
	var pequenas := 0
	for hijo in mundo._decor.get_children():
		if hijo is MultiMeshInstance3D and str(hijo.name).begins_with("Decor_pebble"):
			pequenas += (hijo as MultiMeshInstance3D).multimesh.instance_count
			trozos += 1
			assert_gt((hijo as MultiMeshInstance3D).visibility_range_end, 0.0, "los guijarros lejanos se ocultan")
	assert_gt(trozos, 8, "los guijarros se reparten en varios trozos")
	assert_gt(pequenas, 1000)
	var mundo_chico: Node3D = add_child_autofree(TerrainScript.new())
	mundo_chico.configure([], [], {})
	assert_eq(mundo_chico.extra_size(), 0.0)


func test_minimapa_dibuja_la_capa_fija_una_sola_vez_por_mapa() -> void:
	var mapa: Control = autofree(MinimapScript.new())
	mapa.size = Vector2(168, 168)
	mapa.state = {"bounds": {"min": Vector2i(-35, -35), "max": Vector2i(35, 35)}, "obstacles": [Vector2i(3, 3), Vector2i(-20, 15)],
		"zones": [{"id": "orilla", "center": Vector2i(-12, -12)}, {"id": "nucleo", "center": Vector2i(10, 26)}]}
	mapa._capa_estatica(Vector2i(-35, -35), Vector2i(35, 35))
	var primera: ImageTexture = mapa._estatica
	assert_not_null(primera)
	assert_gte(primera.get_width(), 71 * 2)
	mapa._capa_estatica(Vector2i(-35, -35), Vector2i(35, 35))
	assert_same(mapa._estatica, primera, "no se rehace si el mapa no cambió")
	mapa.state = {"bounds": {"min": Vector2i(-11, -11), "max": Vector2i(11, 11)}, "obstacles": []}
	mapa._capa_estatica(Vector2i(-11, -11), Vector2i(11, 11))
	assert_ne(mapa._estatica, primera, "se rehace al cambiar el mapa")
