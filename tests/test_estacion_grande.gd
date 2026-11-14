extends GutTest
## La estación ocupa 3 × 3 casillas (content/mapa.json, «estacion_radio»: 1): el rover no la atraviesa, no se construye
## encima, se descarga a 2 casillas y se dibuja bastante más grande que el rover (antes medía como él).

const Escala := preload("res://scenes/b/escala.gd")
const Actores := preload("res://scenes/b/actors.gd")
const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]


func _sim(mapa := "res://content/mapa.json") -> Simulation:
	var s := Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"), MapData.desde_archivo(mapa),
		Catalog.desde_archivo("res://content/parts.json"), Economy.desde_archivo("res://content/economia.json"),
		StoryData.desde_archivo("res://content/historia.json"))
	for id in DISENO:
		s.ejecutar("design_add", {"part_id": id})
	s.ejecutar("design_start")
	s.ejecutar("landing_finished")
	return s


func test_los_mapas_declaran_la_estacion_de_3x3_sin_errores() -> void:
	for ruta in ["res://content/mapa.json", "res://content/mapa_luna.json"]:
		var mapa := MapData.desde_archivo(ruta)
		assert_eq(mapa.errores.size(), 0, "%s: %s" % [ruta, mapa.errores])
		assert_eq(mapa.radio_estacion, 1, ruta)


func test_el_rover_no_pisa_ninguna_casilla_de_la_estacion() -> void:
	var mapa := MapData.desde_archivo("res://content/mapa.json")
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := mapa.estacion + Vector2i(dx, dy)
			assert_true(mapa.bloqueada(c), "casilla %s de la estación" % c)
			assert_true(mapa.en_estacion(c))
	assert_false(mapa.bloqueada(mapa.estacion + Vector2i(2, 0)), "a 2 casillas ya se puede pasar")
	assert_false(mapa.en_estacion(mapa.estacion + Vector2i(2, 2)))


func test_los_monstruos_pueden_llegar_a_la_estacion() -> void:
	var mapa := MapData.desde_archivo("res://content/mapa.json")
	assert_false(mapa.bloqueada_para_enemigos(mapa.estacion + Vector2i(1, 0)), "atacan la estación desde su borde")
	assert_eq(mapa.pasos_a_la_estacion(mapa.estacion + Vector2i(1, 1)), 1)


func test_no_se_construye_sobre_la_estacion() -> void:
	var s := _sim()
	for r in ["rocas", "olivino"]:
		s.estado.recursos[r] = 200
	var e := s.estado.casilla_estacion
	assert_eq(s.ejecutar("build", {"building": "panel_solar", "tile": e + Vector2i(1, 0)})["reason"], "TILE_BLOCKED")
	assert_eq(s.ejecutar("build", {"building": "panel_solar", "tile": e + Vector2i(-1, 1)})["reason"], "TILE_BLOCKED")
	assert_true(s.ejecutar("build", {"building": "panel_solar", "tile": e + Vector2i(2, 1)})["ok"], "justo al lado sí")


func test_se_descarga_a_dos_casillas_de_la_estacion() -> void:
	var s := _sim()
	s.estado.carga["rocas"] = 5
	s.estado.casilla_rover = s.estado.casilla_estacion + Vector2i(2, -2)
	assert_true(s.junto_a_almacen())
	assert_true(s.ejecutar("unload")["ok"])
	assert_true(s.estado.carga.is_empty(), "descarga sin moverse")


func test_ir_a_descargar_lleva_al_borde_de_la_estacion() -> void:
	var s := _sim()
	s.estado.carga["rocas"] = 5
	var r: Dictionary = s.ejecutar("unload")
	assert_true(r["ok"], "hay camino hasta la estación: %s" % [r])
	var ruta: Array = r["path"]
	assert_false(ruta.is_empty(), "el rover sale desde lejos")
	var fin: Vector2i = ruta[-1]
	var d := fin - s.estado.casilla_estacion
	assert_eq(maxi(absi(d.x), absi(d.y)), 2, "termina en el anillo de 2 casillas, fuera del edificio")


func test_la_estacion_se_dibuja_mucho_mayor_que_el_rover_y_cabe_en_sus_casillas() -> void:
	var estacion: Node3D = preload("res://scenes/b/assets/models/station.tscn").instantiate()
	estacion.scale = Vector3.ONE * Actores.ESCALA_ESTACION
	add_child_autofree(estacion)
	var caja := AABB()
	var primera := true
	for m in estacion.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
		caja = b if primera else caja.merge(b)
		primera = false
	var lado := maxf(caja.size.x, caja.size.z)
	assert_gt(lado, Escala.ROVER_ANCHO * 3.0, "la base es al menos 3 veces más ancha que el rover")
	assert_lt(lado, Escala.TILE * 3.0, "cabe en sus 3 × 3 casillas")
