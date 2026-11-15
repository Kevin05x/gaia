extends GutTest
## Sala y permisos del multijugador en red (lógica pura: no se abre ningún socket).
const Sala := preload("res://scenes/net/sala.gd")
const Permisos := preload("res://scenes/net/permisos.gd")


func _sala(n: int) -> Object:
	var s = Sala.new()
	for i in range(n):
		assert_true(s.anadir(100 + i, "J%d" % (i + 1)))
	return s


func test_maximo_cuatro_jugadores() -> void:
	var s = _sala(4)
	assert_false(s.anadir(999, "quinto"), "la quinta persona no entra")
	assert_eq(s.cuantos(), 4)


func test_no_entra_dos_veces_el_mismo_id() -> void:
	var s = _sala(1)
	assert_false(s.anadir(100, "otra vez"))


func test_el_primero_es_el_jefe_y_solo_el_jefe_configura_y_empieza() -> void:
	var s = _sala(3)
	assert_true(s.es_jefe(100))
	assert_false(s.configurar(101, "luna", "dificil"), "un jugador que no es el jefe no cambia la configuración")
	assert_true(s.configurar(100, "luna", "dificil"))
	assert_eq(s.config["destino"], "luna")
	assert_false(s.empezar(101))
	assert_true(s.empezar(100))
	assert_true(s.jugando)


func test_con_la_partida_empezada_no_se_configura_pero_si_se_entra() -> void:
	var s = _sala(1)
	s.empezar(100)
	assert_eq(s.roles_de(100).size(), 4, "al empezar solo/a lleva los cuatro roles")
	assert_false(s.configurar(100, "luna", "facil"), "el destino ya no se cambia")
	assert_true(s.anadir(500, "tarde"), "se puede entrar con la misión en marcha")
	assert_eq(s.roles_de(100), ["direccion", "ciencia"], "los roles se reparten de nuevo entre los dos")
	assert_eq(s.roles_de(500), ["ingenieria", "comunicaciones"])
	for rol in ["direccion", "ingenieria", "ciencia", "comunicaciones"]:
		assert_ne(s.quien_tiene(rol), 0, "%s sigue teniendo dueño" % rol)


func test_con_la_partida_empezada_tampoco_entra_un_quinto() -> void:
	var s = _sala(4)
	s.empezar(100)
	assert_false(s.anadir(500, "quinto"))


func test_roles_como_en_el_equipo_de_una_pantalla() -> void:
	var s = _sala(4)
	s.empezar(100)
	assert_eq(s.roles_de(100), ["direccion"])
	assert_eq(s.roles_de(101), ["ingenieria"])
	assert_eq(s.roles_de(102), ["ciencia"])
	assert_eq(s.roles_de(103), ["comunicaciones"])
	var tres = _sala(3)
	tres.empezar(100)
	assert_eq(tres.roles_de(102), ["ciencia", "comunicaciones"])
	var solo = _sala(1)
	solo.empezar(100)
	assert_eq(solo.roles_de(100).size(), 4, "una persona sola tiene los cuatro roles")


func test_cada_rol_lo_tiene_alguien() -> void:
	for n in [1, 2, 3, 4]:
		var s = _sala(n)
		s.empezar(100)
		for rol in ["direccion", "ingenieria", "ciencia", "comunicaciones"]:
			assert_ne(s.quien_tiene(rol), 0, "con %d jugadores alguien lleva %s" % [n, rol])


func test_si_alguien_se_va_sus_roles_pasan_al_jefe() -> void:
	var s = _sala(4)
	s.empezar(100)
	s.quitar(102)  # ciencia
	assert_eq(s.cuantos(), 3)
	assert_true(s.roles_de(100).has("ciencia"), "el jefe hereda Ciencia")
	assert_true(s.roles_de(100).has("direccion"))
	assert_ne(s.quien_tiene("ciencia"), 0)


func test_si_se_va_el_jefe_manda_el_siguiente() -> void:
	var s = _sala(3)
	s.quitar(100)
	assert_true(s.es_jefe(101))
	assert_eq(s.numero(101), 1)


func test_nombre_vacio_o_largo() -> void:
	var s = Sala.new()
	s.anadir(1, "   ")
	s.anadir(2, "un nombre larguísimo que no cabe en la pantalla")
	assert_eq(s.nombres[1], "Jugador 1")
	assert_true(s.nombres[2].length() <= Sala.NOMBRE_MAXIMO)


func test_ida_y_vuelta_por_la_red() -> void:
	var s = _sala(3)
	s.configurar(100, "luna", "facil")
	s.empezar(100)
	var copia = Sala.desde_dict(s.a_dict())
	assert_eq(copia.orden, s.orden)
	assert_eq(copia.config, s.config)
	assert_true(copia.jugando)
	assert_eq(copia.roles_de(102), s.roles_de(102))


func test_permisos_por_rol() -> void:
	assert_true(Permisos.permite(["direccion"], "move"))
	assert_true(Permisos.permite(["ciencia"], "move"), "cada jugador conduce su propio rover")
	assert_true(Permisos.permite(["ciencia"], "act"))
	assert_false(Permisos.permite(["direccion"], "act"))
	assert_true(Permisos.permite(["comunicaciones"], "transmit"))
	assert_false(Permisos.permite(["ingenieria"], "transmit"))
	assert_true(Permisos.permite(["ingenieria"], "build"))
	assert_true(Permisos.permite([], "select"), "seleccionar es libre")
	assert_true(Permisos.permite(["ciencia", "comunicaciones"], "transmit"), "con dos roles se suman")


func test_el_taller_es_de_todo_el_equipo_pero_lanzar_es_de_direccion() -> void:
	for rol in ["direccion", "ingenieria", "ciencia", "comunicaciones"]:
		assert_true(Permisos.permite([rol], "design_add"), "%s puede elegir piezas" % rol)
		assert_true(Permisos.permite([rol], "design_remove"))
	assert_true(Permisos.permite(["direccion"], "design_start"))
	assert_false(Permisos.permite(["ciencia", "comunicaciones"], "design_start"), "lanzar es de Dirección")


func test_el_aviso_dice_de_quien_es_la_orden() -> void:
	assert_eq(Permisos.razon_para("pause"), "NET_ONLY_DIRECCION")
	assert_eq(Permisos.razon_para("act"), "NET_ONLY_CIENCIA")
	assert_eq(Permisos.razon_para("transmit"), "NET_ONLY_COMUNICACIONES")
	assert_eq(Permisos.razon_para("build"), "NET_ONLY_INGENIERIA")
	assert_eq(Permisos.razon_para("approach"), Permisos.RAZON, "si la orden es de varios roles, aviso genérico")


func test_una_persona_sola_puede_todo() -> void:
	var s = _sala(1)
	s.empezar(100)
	var todas := ["move", "approach", "stop", "unload", "act", "transmit", "upgrade", "build", "build_module",
		"toggle_building", "decide", "event_choice", "pause", "redesign", "design_add", "design_start", "select"]
	for orden in todas:
		assert_true(Permisos.permite(s.roles_de(100), orden), "solo/a puede %s" % orden)


func test_todas_las_ordenes_de_la_simulacion_tienen_dueno() -> void:
	# Si el simulador gana una orden nueva y nadie la declara aquí, en red quedaría sin poder darse: este test lo avisa.
	var fuente := FileAccess.get_file_as_string("res://sim/simulation.gd")
	var regex := RegEx.new()
	regex.compile("\\t\\t\"([a-z_]+)\"(?:, \"[a-z_]+\")*:\\n")
	var vistas := {}
	for m in regex.search_all(fuente.substr(fuente.find("func ejecutar("), fuente.find("func avanzar(") - fuente.find("func ejecutar("))):
		vistas[m.get_string(1)] = true
	assert_gt(vistas.size(), 10, "se encontraron las órdenes del simulador")
	for orden in vistas:
		var libre: bool = Permisos.LIBRES.has(orden)
		var de_rol := false
		for rol in Permisos.POR_ROL:
			if Permisos.POR_ROL[rol].has(orden):
				de_rol = true
		assert_true(libre or de_rol, "la orden «%s» no tiene rol en scenes/net/permisos.gd" % orden)


const RedScript := preload("res://scenes/net/red.gd")


func test_sanear_deja_pasar_datos_simples() -> void:
	var ok = RedScript.sanear({"tile": Vector2i(3, 4), "target_id": "roca_1", "on": true, "choice": 2})
	assert_not_null(ok)
	assert_eq(ok["tile"], Vector2i(3, 4))


func test_sanear_rechaza_lo_que_podria_romper_al_anfitrion() -> void:
	assert_null(RedScript.sanear({"tile": "no soy una casilla"}), "tile debe ser Vector2i")
	assert_null(RedScript.sanear({"tile": Vector2i(999999, 0)}), "casilla absurda")
	assert_null(RedScript.sanear({"x": [1, 2, 3]}), "listas no")
	assert_null(RedScript.sanear({"x": {"a": 1}}), "diccionarios no")
	assert_null(RedScript.sanear({"x": "a".repeat(200)}), "textos larguísimos no")
	assert_null(RedScript.sanear({5: 1}), "claves que no son texto no")
	var muchos := {}
	for i in range(20):
		muchos["k%d" % i] = i
	assert_null(RedScript.sanear(muchos), "demasiadas claves")


func test_direccion_del_anfitrion() -> void:
	assert_eq(RedScript.normalizar_direccion("192.168.1.20"), "ws://192.168.1.20:9080")
	assert_eq(RedScript.normalizar_direccion("192.168.1.20:9090"), "ws://192.168.1.20:9090")
	assert_eq(RedScript.normalizar_direccion("localhost"), "ws://localhost:9080")
	assert_eq(RedScript.normalizar_direccion("gaia-sala.onrender.com"), "wss://gaia-sala.onrender.com")
	assert_eq(RedScript.normalizar_direccion("wss://x.trycloudflare.com"), "wss://x.trycloudflare.com")
	assert_eq(RedScript.normalizar_direccion("  "), "")


func test_cada_rol_tiene_su_area_del_taller() -> void:
	assert_eq(Permisos.rol_de_categoria("cohetes"), "direccion")
	assert_eq(Permisos.rol_de_categoria("trayectoria"), "direccion")
	assert_eq(Permisos.rol_de_categoria("chasis"), "ingenieria")
	assert_eq(Permisos.rol_de_categoria("energia"), "ingenieria")
	assert_eq(Permisos.rol_de_categoria("comunicaciones"), "comunicaciones")
	assert_eq(Permisos.rol_de_categoria("extras"), "ciencia")
	for categoria in Catalog.CATEGORIAS:
		assert_ne(Permisos.rol_de_categoria(categoria), "", "la categoría %s tiene dueño" % categoria)


func test_las_piezas_se_compran_solo_en_tu_area() -> void:
	var catalogo := Catalog.desde_archivo("res://content/parts.json")
	for id in catalogo.piezas:
		var categoria: String = catalogo.piezas[id]["categoria"]
		assert_eq(Permisos.categoria_de_pieza(id), categoria, "categoría de %s" % id)
		var dueno := Permisos.rol_de_categoria(categoria)
		assert_true(Permisos.permite_pieza([dueno], id), "%s puede con %s" % [dueno, id])
		assert_true(Permisos.permite_pieza(["direccion", "ingenieria", "comunicaciones", "ciencia"], id), "uno solo puede todo")
		for otro in ["direccion", "ingenieria", "comunicaciones", "ciencia"]:
			if otro != dueno:
				assert_false(Permisos.permite_pieza([otro], id), "%s no puede con %s" % [otro, id])
		assert_eq(Permisos.razon_de_pieza(id), "NET_AREA_" + dueno.to_upper())
	assert_true(Permisos.permite_pieza(["ciencia"], "pieza_que_no_existe"), "las desconocidas las rechaza la simulación")


func test_con_cualquier_numero_de_jugadores_todas_las_areas_tienen_dueno() -> void:
	for cuantos in range(1, 5):
		var s = _sala(cuantos)
		s.empezar(100)
		var cubiertas: Array[String] = []
		for id in s.orden:
			cubiertas.append_array(Permisos.categorias_de(s.roles_de(id)))
		for categoria in Catalog.CATEGORIAS:
			assert_true(cubiertas.has(categoria), "%d jugadores: alguien elige %s" % [cuantos, categoria])


func test_gasto_por_rol_suma_las_piezas_de_su_area() -> void:
	const RolTaller := preload("res://scenes/net/rol_taller.gd")
	var taller := {"categories": [
		{"id": "cohetes", "parts": [{"id": "c1", "cost_musd": 150}]},
		{"id": "chasis", "parts": [{"id": "ch1", "cost_musd": 200}]},
		{"id": "extras", "parts": [{"id": "x1", "cost_musd": 30}, {"id": "x2", "cost_musd": null}]}],
		"selection": {"cohetes": ["c1"], "chasis": ["ch1"], "extras": ["x1", "x2"]}}
	var gasto: Dictionary = RolTaller.gasto_por_rol(taller)
	assert_eq(gasto["direccion"], 150.0)
	assert_eq(gasto["ingenieria"], 200.0)
	assert_eq(gasto["ciencia"], 30.0)
	assert_eq(gasto["comunicaciones"], 0.0)


# --- Presupuesto propio por rol (plan 12, 15 nov) ----------------------------------------------------------------

func _taller_de_prueba(gastado_ing: int) -> Dictionary:
	return {"totals": {"budget_musd": 700.0}, "categories": [
		{"id": "cohetes", "parts": [{"id": "c1", "cost_musd": 250}]},
		{"id": "chasis", "parts": [{"id": "ch1", "cost_musd": gastado_ing}]}],
		"selection": {"cohetes": ["c1"], "chasis": ["ch1"]}}


func test_el_reparto_suma_el_presupuesto_y_se_escala_a_la_dificultad() -> void:
	for destino in ["marte", "luna"]:
		Destino.id = destino
		var topes := Permisos.topes_por_rol(700.0)
		assert_eq(topes.size(), 4, destino)
		var suma := 0.0
		for rol in topes:
			suma += float(topes[rol])
		assert_almost_eq(suma, 700.0, 0.01, "%s: las partes suman el presupuesto" % destino)
		var experta := Permisos.topes_por_rol(620.0)
		var suma2 := 0.0
		for rol in experta:
			suma2 += float(experta[rol])
		assert_almost_eq(suma2, 620.0, 0.01, "%s: se escala a la dificultad" % destino)
	Destino.id = "marte"


func test_el_diseno_recomendado_cabe_en_las_partes_de_cada_rol() -> void:
	# Con dos jugadores el presupuesto es 700 + 200 = 900 (content/rules*.json › presupuesto_extra_por_jugador_musd).
	# Marte: cohete medio 250 + trayectoria rápida 10 · chasis 180 + panel solar 20 · antena relé 30 · espectrómetro, taladro y cámara 105.
	Destino.id = "marte"
	var t := Permisos.topes_por_rol(900.0)
	assert_lte(260.0, float(t["direccion"]))
	assert_lte(200.0, float(t["ingenieria"]))
	assert_lte(30.0, float(t["comunicaciones"]))
	assert_lte(105.0, float(t["ciencia"]))
	# Luna: cohete medio 250 + directa 15 · chasis 180 + MMRTG 120 · antena 30 · 105 de instrumentos.
	Destino.id = "luna"
	t = Permisos.topes_por_rol(900.0)
	assert_lte(265.0, float(t["direccion"]))
	assert_lte(300.0, float(t["ingenieria"]))
	assert_lte(30.0, float(t["comunicaciones"]))
	assert_lte(105.0, float(t["ciencia"]))
	Destino.id = "marte"


func test_el_resto_de_un_rol_dice_cuanto_le_queda_y_si_no_cabe() -> void:
	Destino.id = "marte"
	var taller := _taller_de_prueba(150)  # el taller de prueba tiene 700 M$; Ingeniería recibe 280/900 de eso y lleva 150
	var tope_ing := 280.0 * 700.0 / 900.0
	assert_almost_eq(float(Permisos.resto_de_rol("ingenieria", 20.0, taller)), tope_ing - 150.0 - 20.0, 0.01, "caben 20 y sobra el resto")
	assert_lt(float(Permisos.resto_de_rol("ingenieria", 80.0, taller)), 0.0, "80 no caben")
	assert_not_null(Permisos.resto_de_rol("direccion", 0.0, taller))
	assert_null(Permisos.resto_de_rol("rol_inexistente", 0.0, taller), "sin reparto no hay tope")


func test_cada_jugador_de_mas_suma_su_presupuesto_en_red() -> void:
	var sesion := preload("res://scenes/menu/game_session.gd")
	var runner := preload("res://scenes/a/mission_runner.gd")
	var antes_red: bool = sesion.en_red
	var antes_n: int = sesion.jugadores
	sesion.en_red = true
	for caso in [[1, 700.0], [2, 900.0], [3, 1100.0], [4, 1300.0]]:
		sesion.jugadores = caso[0]
		var reglas := Rules.desde_archivo("res://content/rules.json")
		runner.aplicar_dificultad(reglas, null, "estandar")
		assert_almost_eq(reglas.presupuesto_musd, float(caso[1]), 0.01, "%d jugadores" % caso[0])
	sesion.en_red = false  # fuera de la red no se suma nada, aunque la sesión recuerde varios jugadores
	sesion.jugadores = 4
	var sola := Rules.desde_archivo("res://content/rules.json")
	runner.aplicar_dificultad(sola, null, "estandar")
	assert_almost_eq(sola.presupuesto_musd, 700.0, 0.01, "una partida local no suma")
	sesion.en_red = antes_red
	sesion.jugadores = antes_n
