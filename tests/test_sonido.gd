extends GutTest
## Sonidos propios de cada acción del rover y animación de la transmisión.

const AudioScript := preload("res://scenes/b/audio.gd")
const FxScript := preload("res://scenes/b/transmission_fx.gd")


func _audio() -> Node:
	var a: Node = add_child_autofree(AudioScript.new())
	a.unlocked = true
	return a


func test_los_sonidos_continuos_se_repiten() -> void:
	var a := _audio()
	for p in [a.wind, a.motor, a.radio]:
		assert_eq((p.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)
		assert_gt((p.stream as AudioStreamWAV).loop_end, 1000, "el bucle cubre todo el sonido")


func test_cada_accion_tiene_su_propio_sonido() -> void:
	var a := _audio()
	var vistos: Dictionary = {}
	for id in ["drill", "spectrometer", "radar", "panorama", "drone", "companion", "meteo"]:
		a.start_action({"action": id, "seconds": 3.0})
		assert_eq(a.action_id, id)
		assert_true(a.tool_sound.playing, id)
		var flujo: AudioStreamWAV = a.tool_sound.stream
		assert_eq(flujo.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s suena en bucle mientras dura" % id)
		var huella: int = hash(flujo.data)
		assert_false(vistos.has(huella), "%s no repite el sonido de otra acción" % id)
		vistos[huella] = id
	a.start_action({"action": "drone", "seconds": 3.0})
	assert_true(a.start_sound.playing, "el dron tiene su arranque de rotores")
	a.cancel()
	assert_eq(a.action_id, "")
	assert_false(a.tool_sound.playing)


func test_la_accion_termina_sola() -> void:
	var a := _audio()
	a.start_action({"action": "drill", "seconds": 0.2})
	a._process(0.3)
	assert_false(a.tool_sound.playing)
	assert_eq(a.action_id, "")


func test_al_transmitir_suena_la_subida_y_los_datos() -> void:
	var a := _audio()
	a.update_state({"transmitting": true, "phase": "operations"}, false)
	assert_true(a.uplink_sound.playing, "barrido de subida al abrir la transmisión")
	assert_true(a.radio.playing, "chorro de datos mientras dura")
	a.update_state({"transmitting": false, "phase": "operations"}, false)
	assert_false(a.radio.playing)


func test_al_rodar_suena_el_motor() -> void:
	var a := _audio()
	a.update_state({"phase": "operations"}, true)
	assert_true(a.motor.playing)
	a.update_state({"phase": "operations"}, false)
	assert_false(a.motor.playing)


func test_la_animacion_de_transmision_aparece_y_se_apaga() -> void:
	var fx: Node3D = add_child_autofree(FxScript.new())
	var rover := Node3D.new()
	add_child_autofree(rover)
	fx.rover = rover
	fx.base = Vector3(0, 2, 0)
	assert_false(fx.visible)
	fx.active = true
	fx._process(0.5)
	assert_true(fx.visible, "se ve al transmitir")
	assert_gt((fx._haz.material_override as StandardMaterial3D).albedo_color.a, 0.1, "el haz es visible")
	fx.active = false
	for i in range(10):
		fx._process(0.1)
	assert_false(fx.visible, "se apaga con un fundido al terminar")


# --- Combate (bloque C) ---------------------------------------------------------------------------------------------

func _voces_sonando(a: Node) -> int:
	var n := 0
	for v in a._voces:
		if v.playing:
			n += 1
	return n


func test_cada_efecto_de_combate_suena_una_sola_vez() -> void:
	var a := _audio()
	a._sonidos_de_combate({"shots": [], "enemies": [], "impacts": []}, false)  # primer cuadro: no suena lo anterior
	var snap := {"shots": [{"n": 1, "kind": "shot"}], "enemies": [], "impacts": []}
	a._sonidos_de_combate(snap, false)
	assert_eq(_voces_sonando(a), 1, "el disparo nuevo suena")
	a._sonidos_de_combate(snap, false)
	a._sonidos_de_combate(snap, false)
	assert_eq(_voces_sonando(a), 1, "el mismo disparo en cuadros siguientes no vuelve a sonar")
	a._sonidos_de_combate({"shots": [{"n": 1, "kind": "shot"}, {"n": 2, "kind": "impact"}], "enemies": [], "impacts": []}, false)
	assert_eq(_voces_sonando(a), 2, "el impacto nuevo suena aparte")


func test_alarma_rugido_y_mordida() -> void:
	var a := _audio()
	a._sonidos_de_combate({"shots": [], "enemies": [], "impacts": []}, false)
	var e := {"id": "e1", "type": "coloso", "attacking": false}
	a._sonidos_de_combate({"shots": [], "enemies": [e], "impacts": []}, false)
	assert_eq(_voces_sonando(a), 2, "alarma y rugido al aparecer el primer monstruo")
	for v in a._voces:
		v.stop()
	a._sonidos_de_combate({"shots": [], "enemies": [{"id": "e1", "type": "coloso", "attacking": true}], "impacts": []}, false)
	assert_eq(_voces_sonando(a), 1, "al empezar a atacar suena la mordida")
	a._sonidos_de_combate({"shots": [], "enemies": [{"id": "e1", "type": "coloso", "attacking": true}], "impacts": []}, false)
	assert_eq(_voces_sonando(a), 1, "no repite mientras sigue atacando")


func test_el_meteorito_silba_al_caer_y_no_suena_en_pausa() -> void:
	var a := _audio()
	a._sonidos_de_combate({"shots": [], "enemies": [], "impacts": []}, false)
	var lejos := {"shots": [], "enemies": [], "impacts": [{"tile": Vector2i(1, 1), "t": 5.5, "total": 6.0}]}
	a._sonidos_de_combate(lejos, false)
	assert_eq(_voces_sonando(a), 0, "recién anunciado no suena")
	var cerca := {"shots": [], "enemies": [], "impacts": [{"tile": Vector2i(1, 1), "t": 1.5, "total": 6.0}]}
	a._sonidos_de_combate(cerca, false)
	assert_eq(_voces_sonando(a), 1, "silba al entrar en el tramo de caída")
	a._sonidos_de_combate(cerca, false)
	assert_eq(_voces_sonando(a), 1, "una sola vez")
	var b := _audio()
	b._sonidos_de_combate({"shots": [], "enemies": [], "impacts": []}, true)
	b._sonidos_de_combate({"shots": [{"n": 1, "kind": "shot"}], "enemies": [], "impacts": []}, true)
	assert_eq(_voces_sonando(b), 0, "en pausa no suena")


func test_los_sonidos_de_combate_son_distintos() -> void:
	var vistos: Dictionary = {}
	for id in AudioScript.SFX:
		var huella: int = hash((AudioScript.SFX[id][0] as AudioStreamWAV).data)
		assert_false(vistos.has(huella), "%s tiene su propio sonido" % id)
		vistos[huella] = id
