extends GutTest
## Pruebas de MapData: el mapa real y mapas pequeños armados en la prueba.

const RUTA := "res://content/mapa.json"

var balance: Balance
var reglas: Rules


func before_each() -> void:
	balance = Balance.desde_archivo("res://content/balance.json")
	reglas = Rules.desde_archivo("res://content/rules.json")


func _base() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(RUTA))


## Mapa pequeño de 5x5 sin objetivos: salida en el centro y estación en una esquina.
func _pequeno() -> Dictionary:
	return {"limites": {"min": [-2, -2], "max": [2, 2]}, "inicio_rover": [0, 0], "estacion": [2, 2],
		"obstaculos": [], "objetivos": []}


func _cargar(datos: Dictionary) -> MapData:
	return MapData.desde_texto(JSON.stringify(datos))


func test_el_mapa_real_no_tiene_errores() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_eq(mapa.errores.size(), 0, "errores en mapa.json: %s" % [mapa.errores])


func test_contenido_del_mapa_real() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_eq(mapa.limite_min, Vector2i(-35, -35))
	assert_eq(mapa.limite_max, Vector2i(35, 35))
	assert_eq(mapa.objetivos.size(), 39)
	assert_eq(mapa.zonas.size(), 3)
	assert_ne(mapa.estacion, mapa.inicio_rover)
	var tipos := {}
	for objetivo in mapa.objetivos:
		tipos[objetivo["type"]] = true
	assert_eq(tipos.keys().size(), 3)


func test_casillas_bloqueadas() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_true(mapa.bloqueada(Vector2i(4, 0)), "obstáculo")
	assert_true(mapa.bloqueada(mapa.estacion), "estación")
	assert_true(mapa.bloqueada(Vector2i(2, -2)), "objetivo")
	assert_true(mapa.bloqueada(Vector2i(36, 0)), "fuera del mapa")
	assert_false(mapa.bloqueada(Vector2i(1, 0)))
	assert_false(mapa.bloqueada(mapa.inicio_rover))


func test_ruta_recta() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_eq(mapa.ruta(Vector2i(0, 0), Vector2i(3, 0)), [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)])


func test_ruta_que_rodea_un_obstaculo() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	var camino := mapa.ruta(Vector2i(3, 0), Vector2i(5, 0))
	assert_eq(camino.size(), 6)
	assert_eq(camino[camino.size() - 1], Vector2i(5, 0))
	var anterior := Vector2i(3, 0)
	for casilla in camino:
		assert_false(mapa.bloqueada(casilla), "pasa por una casilla bloqueada %s" % [casilla])
		assert_eq(absi(casilla.x - anterior.x) + absi(casilla.y - anterior.y), 1, "salto entre %s y %s" % [anterior, casilla])
		anterior = casilla


func test_ruta_vacia_si_no_hay_camino_o_destino_bloqueado() -> void:
	var datos := _pequeno()
	datos["obstaculos"] = [[-1, -2], [-2, -1]]
	var mapa := _cargar(datos)
	assert_eq(mapa.errores.size(), 0)
	assert_eq(mapa.ruta(Vector2i(0, 0), Vector2i(-2, -2)).size(), 0, "casilla encerrada")
	assert_eq(mapa.ruta(Vector2i(0, 0), Vector2i(-1, -2)).size(), 0, "destino bloqueado")
	assert_eq(mapa.ruta(Vector2i(0, 0), Vector2i(0, 0)).size(), 0, "misma casilla")
	assert_eq(mapa.ruta(Vector2i(0, 0), Vector2i(1, 0)).size(), 1)


func test_aplicar_a_vuelca_el_mapa_en_el_estado() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	var estado := MissionState.new(balance, reglas)
	var revision := estado.revision_mapa
	mapa.aplicar_a(estado)
	assert_eq(estado.casilla_rover, mapa.inicio_rover)
	assert_eq(estado.casilla_estacion, mapa.estacion)
	assert_eq(estado.obstaculos.size(), mapa.obstaculos.size())
	assert_eq(estado.objetivos.size(), 39)
	assert_eq(estado.limite_min, mapa.limite_min)
	assert_eq(estado.revision_mapa, revision + 1)
	var primero: Dictionary = estado.objetivos[0]
	assert_eq(primero["done"], [])
	assert_false(primero["depleted"])
	primero["depleted"] = true
	assert_false(mapa.objetivos[0].has("depleted"), "el mapa no debe cambiar al jugar")


func test_campo_obligatorio_faltante() -> void:
	var datos := _base()
	datos.erase("estacion")
	assert_has(Array(_cargar(datos).errores), "MISSING_FIELD:estacion")


func test_json_invalido_y_archivo_inexistente() -> void:
	assert_has(Array(MapData.desde_texto("{ esto no es json").errores), "INVALID_JSON")
	assert_has(Array(MapData.desde_archivo("res://content/no_existe.json").errores), "FILE_UNREADABLE:res://content/no_existe.json")


func test_casilla_invalida() -> void:
	var datos := _base()
	datos["estacion"] = [1]
	assert_has(Array(_cargar(datos).errores), "INVALID_TILE:estacion")
	datos = _base()
	datos["obstaculos"][0] = [1.5, 2]
	assert_has(Array(_cargar(datos).errores), "INVALID_TILE:obstaculos[0]")


func test_casilla_fuera_de_los_limites() -> void:
	var datos := _base()
	datos["objetivos"][0]["casilla"] = [99, 0]
	assert_has(Array(_cargar(datos).errores), "OUT_OF_BOUNDS:objetivos.JZ-01")


func test_objetivo_duplicado_tipo_invalido_y_revelado_faltante() -> void:
	var datos := _base()
	datos["objetivos"][1]["id"] = "JZ-01"
	assert_has(Array(_cargar(datos).errores), "DUPLICATE_TARGET:JZ-01")
	datos = _base()
	datos["objetivos"][0]["tipo"] = "volcan"
	assert_has(Array(_cargar(datos).errores), "INVALID_TARGET_TYPE:JZ-01")
	datos = _base()
	datos["objetivos"][0].erase("revelado")
	assert_has(Array(_cargar(datos).errores), "MISSING_FIELD:objetivos.JZ-01.revelado")


func test_dos_cosas_en_la_misma_casilla() -> void:
	var datos := _base()
	datos["objetivos"][0]["casilla"] = datos["obstaculos"][0]
	var errores := Array(_cargar(datos).errores)
	assert_true(errores.has("TILE_OCCUPIED:-1,-2"), "errores: %s" % [errores])


func test_objetivo_inalcanzable() -> void:
	var datos := _pequeno()
	datos["obstaculos"] = [[-1, -2], [-2, -1]]
	datos["objetivos"] = [{"id": "T1", "casilla": [-2, -2], "tipo": "rock", "revelado": true}]
	assert_has(Array(_cargar(datos).errores), "UNREACHABLE_TARGET:T1")


func test_las_zonas_del_mapa_real() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_eq(mapa.zona_de(mapa.estacion), "orilla", "la base está en la orilla")
	assert_eq(mapa.zona_de(mapa.inicio_rover), "orilla")
	assert_eq(mapa.zona_de(Vector2i(18, 2)), "falla")
	assert_eq(mapa.zona_de(Vector2i(10, 26)), "nucleo")
	var vista := mapa.zonas_para_la_vista()
	assert_eq(vista.size(), 3)
	assert_eq(vista[0]["id"], "orilla")


func test_todos_los_objetivos_del_mapa_real_son_alcanzables() -> void:
	var mapa := MapData.desde_archivo(RUTA)
	assert_eq(mapa.errores.size(), 0, "sin errores de ocupación ni de alcance")
