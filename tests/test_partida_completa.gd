extends GutTest
## Jugador automático: juega partidas enteras (historia, combate, tutorial y nave por módulos), guarda y carga cada sol,
## manda órdenes absurdas y comprueba que nada se rompe y que siempre hay un final.

const DISENO: Array[String] = ["cohete_ligero", "chasis_base", "panel_solar", "antena_rele",
	"camara", "espectrometro", "taladro", "radar", "dron", "meteo", "companero"]
const EDIFICIOS: Array[String] = ["panel_solar", "domo", "hangar", "extractor_hielo", "luz", "torreta", "torreta_2", "hangar", "torreta"]

var economia: Economy
var historia: StoryData
var combate: CombatData
var tutorial: TutorialData
var rng := RandomNumberGenerator.new()
var problemas: Array[String] = []


func _nueva() -> Simulation:
	return Simulation.new(Balance.desde_archivo("res://content/balance.json"),
		Rules.desde_archivo("res://content/rules.json"),
		MapData.desde_archivo("res://content/mapa.json"),
		Catalog.desde_archivo("res://content/parts.json"),
		economia, historia, combate, tutorial)


func before_each() -> void:
	economia = Economy.desde_archivo("res://content/economia.json")
	historia = StoryData.desde_archivo("res://content/historia.json")
	combate = CombatData.desde_archivo("res://content/combate.json")
	tutorial = TutorialData.desde_archivo("res://content/tutorial.json")
	problemas.clear()


func _operar(sim: Simulation) -> void:
	for id in DISENO:
		sim.ejecutar("design_add", {"part_id": id})
	sim.ejecutar("design_start")
	sim.ejecutar("landing_finished")


## Reglas que nunca deben romperse, pase lo que pase.
func _invariantes(sim: Simulation, donde: String) -> void:
	var e := sim.estado
	for r in e.recursos:
		if int(e.recursos[r]) < 0:
			problemas.append("%s: recurso %s negativo" % [donde, r])
	if is_nan(e.hora) or is_nan(e.bateria_wh) or is_nan(e.datos) or is_nan(e.enviados) or is_nan(e.rocky_hp) or is_nan(e.rover_hp):
		problemas.append("%s: NaN en el estado" % donde)
	if e.bateria_wh < -0.01 or e.bateria_wh > e.bateria_capacidad_wh + 0.01:
		problemas.append("%s: batería fuera de rango %f/%f" % [donde, e.bateria_wh, e.bateria_capacidad_wh])
	if e.rocky_hp < -0.01 or e.rocky_hp > 100.01 or e.rover_hp > 100.01:
		problemas.append("%s: vida fuera de rango" % donde)
	if e.etica < -0.01 or e.etica > 100.01:
		problemas.append("%s: ética fuera de rango %f" % [donde, e.etica])
	var naves := 0
	var ocupadas := {}
	for edificio in e.edificios:
		var nivel := int(edificio["level"])
		var tipo := str(edificio["type"])
		var modulos := economia.modulos_de(tipo).size()
		if modulos > 0:
			if nivel > modulos or int(edificio["target_level"]) > modulos:
				problemas.append("%s: %s con nivel %d de %d módulos" % [donde, tipo, nivel, modulos])
			if tipo == "nave_fuga":
				naves += 1
		if int(edificio["target_level"]) < nivel:
			problemas.append("%s: %s con nivel objetivo menor al nivel" % [donde, tipo])
		if float(edificio["hp"]) < 0.0 and nivel > 0:
			problemas.append("%s: %s con vida negativa y aún en pie" % [donde, tipo])
		var casilla: Vector2i = edificio["tile"]
		if ocupadas.has(casilla):
			problemas.append("%s: dos edificios en %s" % [donde, casilla])
		ocupadas[casilla] = true
	if naves > 1:
		problemas.append("%s: %d naves de fuga" % [donde, naves])
	for enemigo in e.enemigos:
		if float(enemigo["hp"]) <= 0.0:
			problemas.append("%s: enemigo muerto sigue vivo" % donde)
		var pos: Vector2 = enemigo["pos"]
		if is_nan(pos.x) or is_nan(pos.y):
			problemas.append("%s: enemigo con posición NaN" % donde)


func _decidir(sim: Simulation, modo: int) -> void:
	for i in range(8):
		if sim.estado.historia_nodo.is_empty():
			return
		var n := 2
		if historia.nodos.has(sim.estado.historia_nodo):
			n = (historia.nodos[sim.estado.historia_nodo]["opciones"] as Array).size()
		var eleccion := 0
		match modo:
			0: eleccion = 0
			1: eleccion = n - 1
			_: eleccion = rng.randi_range(0, n - 1)
		var r := sim.ejecutar("decide", {"choice": eleccion})
		if not r["ok"]:
			# opción bloqueada (por ejemplo, requiere compañero): se prueba con las demás
			for k in range(n):
				if sim.ejecutar("decide", {"choice": k})["ok"]:
					break


func _construir_algo(sim: Simulation) -> void:
	for id in ["rocas", "olivino", "hielo", "xenolito"]:
		sim.estado.recursos[id] = maxi(int(sim.estado.recursos.get(id, 0)), 100)
	var tipo: String = EDIFICIOS[rng.randi_range(0, EDIFICIOS.size() - 1)]
	var centro := sim.estado.casilla_estacion
	for intento in range(12):
		var tile := centro + Vector2i(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		if sim.ejecutar("build", {"building": tipo, "tile": tile})["ok"]:
			return


func _ordenes_absurdas(sim: Simulation) -> void:
	sim.ejecutar("build", {"building": "no_existe", "tile": Vector2i(0, 0)})
	sim.ejecutar("build", {"building": "panel_solar", "tile": Vector2i(99999, -99999)})
	sim.ejecutar("build_module", {"id": "fantasma"})
	sim.ejecutar("build_module", {"id": ""})
	sim.ejecutar("toggle_building", {"id": "fantasma", "on": false})
	sim.ejecutar("decide", {"choice": -5})
	sim.ejecutar("decide", {"choice": 99})
	sim.ejecutar("move", {"tile": Vector2i(-9999, 9999)})
	sim.ejecutar("act", {"action": "nada", "target_id": "no_hay"})
	sim.ejecutar("select", {"target_id": "no_hay"})
	sim.ejecutar("tutorial_skip") if rng.randf() < 0.1 else null
	sim.ejecutar("landing_finished")  # fuera de fase
	sim.ejecutar("design_start")


func _nave(sim: Simulation) -> void:
	for edificio in sim.estado.edificios:
		if str(edificio["type"]) == "nave_fuga":
			sim.ejecutar("build_module", {"id": edificio["id"]})
			return
	var centro := sim.estado.casilla_estacion
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			if sim.ejecutar("build", {"building": "nave_fuga", "tile": centro + Vector2i(dx, dy)})["ok"]:
				return


func _partida(semilla: int, modo: int, con_guardado: bool, inmortal: bool = false) -> Dictionary:
	rng.seed = semilla
	var sim := _nueva()
	_operar(sim)
	var fin := false
	var sol_guardado := 0
	var pasos := 0
	var tope := 40000  # 0,5 s por paso: ~5,5 horas de juego reales sería demasiado; el tope corta partidas colgadas
	while pasos < tope and not fin:
		pasos += 1
		_decidir(sim, modo)
		if inmortal:
			# prueba de la recta final: batería y rover a salvo, antena al máximo
			sim.estado.bateria_wh = sim.estado.bateria_capacidad_wh
			sim.estado.rover_hp = 100.0
			if pasos % 25 == 0:
				sim.ejecutar("upgrade")
		if pasos % 20 == 0:
			_construir_algo(sim)
			_nave(sim)
		if pasos % 17 == 0:
			_ordenes_absurdas(sim)
		if pasos % 9 == 0 and sim.estado.enviados < sim.estado.meta:
			# la ciencia entra a su ritmo: se simula lo que dejarían las acciones del rover
			sim.estado.datos = minf(sim.estado.datos + 4.0, sim.estado.memoria_capacidad)
			sim.ejecutar("transmit", {"on": true})
		var eventos := sim.avanzar(0.5)
		if eventos.has("MISSION_ENDED"):
			fin = true
		if pasos % 40 == 0:
			_invariantes(sim, "s%d paso %d" % [semilla, pasos])
		if con_guardado and sim.estado.sol != sol_guardado and sim.estado.fase == "operations":
			sol_guardado = sim.estado.sol
			var datos: Dictionary = str_to_var(var_to_str(sim.guardar()))
			var otra := _nueva()
			if not otra.cargar(datos):
				problemas.append("s%d sol %d: no se pudo cargar" % [semilla, sol_guardado])
			else:
				var antes: Dictionary = sim.guardar()["estado"]
				var despues: Dictionary = otra.guardar()["estado"]
				for clave in antes:
					if clave in ["pausado", "en_movimiento", "movimiento_en_curso", "ocupado", "accion_en_curso", "transmitiendo", "revision_mapa"]:
						continue
					if JSON.stringify(antes[clave], "", true) != JSON.stringify(despues.get(clave), "", true):
						problemas.append("s%d sol %d: «%s» cambió: %s ≠ %s" % [semilla, sol_guardado, clave, JSON.stringify(antes[clave], "", true).left(200), JSON.stringify(despues.get(clave), "", true).left(200)])
				sim = otra
				_invariantes(sim, "s%d tras cargar" % semilla)
	return {"fin": fin, "pasos": pasos, "informe": sim.informe, "sol": sim.estado.sol, "registro": JSON.stringify(sim.estado.historia_registro), "extra": "env=%d/%d antena=%d final=%s edif=%s resp=%s" % [sim.estado.enviados, sim.estado.meta, sim.estado.nivel_antena, sim.estado.historia_final, JSON.stringify(sim.estado.edificios.filter(func(b): return b["type"] == "nave_fuga").map(func(b): return "%s:%d/%d" % [b["type"], b["level"], b["target_level"]])), sim.estado.recursos]}


func test_recta_final_con_nave_y_los_cuatro_finales_posibles() -> void:
	var resumen: Array[String] = []
	var finales := {}
	for semilla in range(1, 4):
		for modo in range(3):
			var r := _partida(semilla * 10 + modo, modo, true, true)
			var informe: Dictionary = r["informe"]
			var final_id := str(informe.get("ending", {}).get("id", "?"))
			finales[final_id] = true
			resumen.append(r["extra"] + "\nINM s%d m%d: fin=%s pasos=%d sol=%d final=%s causas=%s reg=%s" % [semilla, modo, r["fin"], r["pasos"], r["sol"], final_id, informe.get("causes"), r["registro"].left(200)])
			assert_true(r["fin"], "la partida %d/%d no terminó nunca" % [semilla, modo])
	gut.p("\n".join(resumen))
	gut.p("finales vistos: %s" % [finales.keys()])
	assert_eq(problemas.size(), 0, "\n".join(problemas.slice(0, 15)))


func test_partidas_completas_con_guardado_no_rompen_nada() -> void:
	var resumen: Array[String] = []
	for semilla in range(1, 4):
		for modo in range(3):
			var r := _partida(semilla * 10 + modo, modo, true)
			resumen.append("s%d m%d: fin=%s pasos=%d sol=%d informe=%s reg=%s" % [semilla, modo, r["fin"], r["pasos"], r["sol"], JSON.stringify(r["informe"]).left(300), r["registro"]])
			assert_true(r["fin"], "la partida %d/%d no terminó nunca" % [semilla, modo])
	gut.p("\n".join(resumen))
	assert_eq(problemas.size(), 0, "\n".join(problemas.slice(0, 15)))
