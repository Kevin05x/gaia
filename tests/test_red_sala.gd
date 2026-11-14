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


func test_no_se_entra_ni_se_configura_con_la_partida_empezada() -> void:
	var s = _sala(2)
	s.empezar(100)
	assert_false(s.anadir(500, "tarde"))
	assert_false(s.configurar(100, "luna", "facil"))


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
	assert_false(Permisos.permite(["ciencia"], "move"), "Ciencia no conduce")
	assert_true(Permisos.permite(["ciencia"], "act"))
	assert_false(Permisos.permite(["direccion"], "act"))
	assert_true(Permisos.permite(["comunicaciones"], "transmit"))
	assert_false(Permisos.permite(["ingenieria"], "transmit"))
	assert_true(Permisos.permite(["ingenieria"], "build"))
	assert_true(Permisos.permite([], "select"), "seleccionar es libre")
	assert_true(Permisos.permite(["ciencia", "comunicaciones"], "transmit"), "con dos roles se suman")


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
