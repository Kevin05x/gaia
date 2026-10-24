extends GutTest
## Cámara: giro continuo al llevar el mouse al borde izquierdo/derecho.

const Camara := preload("res://scenes/b/camera.gd")
const PANTALLA := Vector2(1280, 720)


func test_centro_no_gira() -> void:
	assert_eq(Camara.edge_turn_at(Vector2(640, 360), PANTALLA), 0.0)
	assert_eq(Camara.edge_turn_at(Vector2(Camara.EDGE_PX + 1, 360), PANTALLA), 0.0)


func test_borde_izquierdo_y_derecho_giran_en_sentidos_opuestos() -> void:
	assert_lt(Camara.edge_turn_at(Vector2(1, 360), PANTALLA), 0.0)
	assert_gt(Camara.edge_turn_at(Vector2(1279, 360), PANTALLA), 0.0)


func test_mas_cerca_del_borde_gira_mas() -> void:
	var suave := absf(Camara.edge_turn_at(Vector2(PANTALLA.x - 5, 360), PANTALLA))
	var fuerte := absf(Camara.edge_turn_at(Vector2(PANTALLA.x - 1, 360), PANTALLA))
	assert_gt(fuerte, suave)
	assert_lte(fuerte, 1.0)


func test_fuera_de_la_ventana_no_gira() -> void:
	assert_eq(Camara.edge_turn_at(Vector2(-50, 360), PANTALLA), 0.0)
	assert_eq(Camara.edge_turn_at(Vector2(640, 900), PANTALLA), 0.0)
