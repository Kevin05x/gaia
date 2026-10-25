class_name CombatSystem
extends RefCounted
## Defensa de la base: oleadas que salen de los nidos y andan hacia la estación, torretas que disparan solas y
## gastan batería, daño a edificios, antena, rover y Rocky, reparación de Rocky, lluvias de meteoritos y la
## «amenaza» (la actividad de la base despierta a la fauna). El jugador no controla unidades: construye, reparte
## la energía y decide. Simulación pura: sin nodos, sin azar suelto (los meteoritos usan una semilla por lluvia).
## Cifras en content/combate.json (monstruos, oleadas, meteoritos) y content/economia.json (torretas).

const EVENTO_OLEADA := "WAVE_STARTED"  ## WAVE_STARTED:<id>
const EVENTO_OLEADA_DERROTADA := "WAVE_CLEARED"  ## WAVE_CLEARED:<id>
const EVENTO_ENEMIGO_ABATIDO := "ENEMY_KILLED"  ## ENEMY_KILLED:<tipo>
const EVENTO_ROVER_GOLPEADO := "ROVER_HIT"
const EVENTO_METEORITOS := "METEOR_SHOWER"  ## METEOR_SHOWER:<id>, cuando empieza la lluvia
const EVENTO_IMPACTO := "METEOR_IMPACT"
const AVISO_OLEADA_H := 3.0  ## horas de juego antes de una oleada en las que el HUD avisa
const TTL_DISPARO := 0.18  ## segundos que dura el rayo de una torreta en la vista
const TTL_ATAQUE := 0.35  ## segundos que dura el gesto de ataque de un monstruo
const AMENAZA_MAX := 100.0
const DANO_ROVER_METEORITO := 25.0  ## % de vida del rover que quita un meteorito que cae sobre él

var _datos: CombatData
var _economia: Economy
var _edificios: BuildSystem
var _mapa: MapData


func _init(datos: CombatData, economia: Economy, edificios: BuildSystem, mapa: MapData) -> void:
	_datos = datos
	_economia = economia
	_edificios = edificios
	_mapa = mapa


## La actividad de la base despierta a la fauna: cada taladro suma amenaza.
func reaccionar(estado: MissionState, eventos: Array[String]) -> void:
	var por_taladro := float(_datos.amenaza.get("taladro", 0.0))
	for evento in eventos:
		if evento.begins_with("%s:drill:" % ScienceSystem.EVENTO_ACCION_TERMINADA):
			estado.amenaza = minf(estado.amenaza + por_taladro, AMENAZA_MAX)


## Avanza el combate «delta_s» segundos reales (= «horas» de juego). «energia» paga disparos y reparaciones.
func avanzar(estado: MissionState, delta_s: float, horas: float, energia: EnergySystem) -> Array[String]:
	var eventos: Array[String] = []
	_envejecer_efectos(estado, delta_s)
	_actualizar_amenaza(estado, horas)
	eventos.append_array(_programar(estado))
	_soltar_meteoritos(estado, delta_s)
	eventos.append_array(_caer_meteoritos(estado, delta_s))
	if not estado.enemigos.is_empty():
		eventos.append_array(_mover_y_atacar(estado, delta_s))
		eventos.append_array(_disparar(estado, delta_s, energia))
	_reparar(estado, delta_s, energia)
	return eventos


# --- Para la vista y los avisos ---------------------------------------------------------------------------------------

## Próxima oleada pendiente: {"id", "sol", "hour", "in_h", "count"} (vacío si no queda ninguna).
func proxima_oleada(estado: MissionState) -> Dictionary:
	var ahora := CombatData.momento(estado.sol, estado.hora)
	for oleada in _datos.oleadas:
		if estado.oleadas_hechas.has(oleada["id"]):
			continue
		var total := 0
		for grupo in oleada["grupos"]:
			total += int(grupo["cantidad"])
		total += extra_por_amenaza(estado)
		return {"id": oleada["id"], "sol": oleada["sol"], "hour": oleada["hora"],
			"in_h": maxf(CombatData.momento(oleada["sol"], oleada["hora"]) - ahora, 0.0), "count": total}
	return {}


## Monstruos de más que traerá la próxima oleada por la actividad de la base.
func extra_por_amenaza(estado: MissionState) -> int:
	var por_extra := float(_datos.amenaza.get("por_extra", 0.0))
	if por_extra <= 0.0:
		return 0
	return mini(int(floorf(estado.amenaza / por_extra)), int(_datos.amenaza.get("extra_max", 0)))


func para_la_vista(estado: MissionState) -> Dictionary:
	var lista: Array[Dictionary] = []
	for enemigo in estado.enemigos:
		var def := _datos.enemigo(enemigo["type"])
		lista.append({"id": enemigo["id"], "type": enemigo["type"], "pos": enemigo["pos"], "hp": float(enemigo["hp"]),
			"hp_max": float(def.get("hp", 1.0)), "size": float(def.get("tamano", 1.0)), "attacking": float(enemigo["atk"]) > 0.0})
	var caidas: Array[Dictionary] = []
	for impacto in estado.impactos:
		caidas.append({"tile": impacto["tile"], "t": float(impacto["t"]), "total": float(impacto.get("total", impacto["t"])),
			"radius": float(impacto["radio"])})
	return {"enemies": lista, "shots": estado.disparos.duplicate(true), "impacts": caidas, "threat": estado.amenaza,
		"threat_extra": extra_por_amenaza(estado), "wave": proxima_oleada(estado), "rover_hp": estado.rover_hp}


## Avisos del HUD como [id, gravedad, valores].
func avisos(estado: MissionState) -> Array[Array]:
	var lista: Array[Array] = []
	if not estado.enemigos.is_empty():
		lista.append(["ENEMIES_ACTIVE", "critical", [estado.enemigos.size()]])
	if not estado.impactos.is_empty():
		lista.append(["METEORS_INCOMING", "critical", [estado.impactos.size()]])
	if estado.rover_hp <= 40.0:
		lista.append(["ROVER_DAMAGED", "warning", [int(roundf(estado.rover_hp))]])
	var siguiente := proxima_oleada(estado)
	if estado.enemigos.is_empty() and not siguiente.is_empty() and float(siguiente["in_h"]) <= AVISO_OLEADA_H:
		lista.append(["WAVE_SOON", "warning", [float(siguiente["in_h"]), int(siguiente["count"])]])
	return lista


# --- Oleadas y meteoritos ---------------------------------------------------------------------------------------------

func _efecto(estado: MissionState, desde: Vector2i, hasta: Vector2, ttl: float, tipo: String) -> void:
	estado.disparos.append({"from": desde, "to": hasta, "ttl": ttl, "kind": tipo, "n": estado.siguiente_disparo})
	estado.siguiente_disparo += 1


func _envejecer_efectos(estado: MissionState, delta_s: float) -> void:
	for i in range(estado.disparos.size() - 1, -1, -1):
		estado.disparos[i]["ttl"] = float(estado.disparos[i]["ttl"]) - delta_s
		if float(estado.disparos[i]["ttl"]) <= 0.0:
			estado.disparos.remove_at(i)


func _actualizar_amenaza(estado: MissionState, horas: float) -> void:
	if horas <= 0.0:
		return
	if estado.transmitiendo:
		estado.amenaza += horas * float(estado.nivel_antena) * float(_datos.amenaza.get("transmision_por_h_y_nivel", 0.0))
	estado.amenaza = clampf(estado.amenaza - horas * float(_datos.amenaza.get("decaimiento_por_h", 0.0)), 0.0, AMENAZA_MAX)


func _programar(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	var ahora := CombatData.momento(estado.sol, estado.hora)
	for oleada in _datos.oleadas:
		if estado.oleadas_hechas.has(oleada["id"]):
			continue
		if ahora < CombatData.momento(oleada["sol"], oleada["hora"]):
			break  # están ordenadas por momento
		estado.oleadas_hechas.append(oleada["id"])
		eventos.append("%s:%s" % [EVENTO_OLEADA, oleada["id"]])
		_lanzar(estado, oleada)
	for lluvia in _datos.meteoritos:
		if estado.oleadas_hechas.has(lluvia["id"]) or ahora < CombatData.momento(lluvia["sol"], lluvia["hora"]):
			continue
		estado.oleadas_hechas.append(lluvia["id"])
		estado.meteoritos_en_curso.append({"id": lluvia["id"], "restan": lluvia["impactos"], "t": 0.0,
			"separacion_s": lluvia["separacion_s"], "dano": lluvia["dano"], "radio": lluvia["radio"],
			"aviso_s": lluvia["aviso_s"], "sol": lluvia["sol"]})
		eventos.append("%s:%s" % [EVENTO_METEORITOS, lluvia["id"]])
	return eventos


## Saca de los nidos los monstruos de la oleada (hasta el máximo de activos). La amenaza acumulada añade monstruos
## al primer grupo del tipo indicado y se gasta.
func _lanzar(estado: MissionState, oleada: Dictionary) -> void:
	var extra := extra_por_amenaza(estado)
	var extra_tipo := str(_datos.amenaza.get("extra_tipo", ""))
	var indice := 0
	for grupo in oleada["grupos"]:
		var cantidad := int(grupo["cantidad"])
		if extra > 0 and grupo["tipo"] == extra_tipo:
			cantidad += extra
			estado.amenaza = maxf(estado.amenaza - float(extra) * float(_datos.amenaza.get("por_extra", 0.0)), 0.0)
			extra = 0
		var nidos := _nidos_de(str(grupo["zona"]))
		if nidos.is_empty():
			continue
		for i in cantidad:
			if estado.enemigos.size() >= _datos.max_activos:
				return
			var nido: Dictionary = nidos[i % nidos.size()]
			var angulo := float(indice) * 2.399963
			var radio := 0.35 + 0.12 * float(indice % 4)
			indice += 1
			estado.enemigos.append({"id": "e%d" % estado.siguiente_enemigo, "type": grupo["tipo"], "wave": oleada["id"],
				"pos": Vector2(nido["tile"]) + Vector2(cos(angulo), sin(angulo)) * radio, "dest": nido["tile"],
				"hp": float(_datos.enemigo(grupo["tipo"])["hp"]), "cd": 1.0, "atk": 0.0})
			estado.siguiente_enemigo += 1


func _nidos_de(zona: String) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for nido in _mapa.nidos:
		if zona.is_empty() or nido["zone"] == zona:
			lista.append(nido)
	if lista.is_empty():
		lista.append_array(_mapa.nidos)  # zona sin nidos: salen de cualquiera
	return lista


func _soltar_meteoritos(estado: MissionState, delta_s: float) -> void:
	for i in range(estado.meteoritos_en_curso.size() - 1, -1, -1):
		var lluvia := estado.meteoritos_en_curso[i]
		lluvia["t"] = float(lluvia["t"]) - delta_s
		if float(lluvia["t"]) <= 0.0 and int(lluvia["restan"]) > 0:
			estado.impactos.append({"tile": _casilla_de_impacto(estado, lluvia), "t": float(lluvia["aviso_s"]),
				"total": float(lluvia["aviso_s"]), "dano": float(lluvia["dano"]), "radio": float(lluvia["radio"])})
			lluvia["restan"] = int(lluvia["restan"]) - 1
			lluvia["t"] = float(lluvia["separacion_s"])
		if int(lluvia["restan"]) <= 0:
			estado.meteoritos_en_curso.remove_at(i)


## Casilla del impacto: con buena probabilidad cerca de un edificio. Semilla fija por lluvia y por impacto.
func _casilla_de_impacto(estado: MissionState, lluvia: Dictionary) -> Vector2i:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([lluvia["id"], lluvia["restan"]])
	var objetivos: Array[Dictionary] = []
	for edificio in estado.edificios:
		if _edificios.es_objetivo(edificio):
			objetivos.append(edificio)
	if not objetivos.is_empty() and azar.randf() < 0.6:
		var elegido := objetivos[azar.randi() % objetivos.size()]
		return elegido["tile"] + Vector2i(azar.randi_range(-1, 1), azar.randi_range(-1, 1))
	var radio := _economia.zona_base_radio + 1
	return estado.casilla_estacion + Vector2i(azar.randi_range(-radio, radio), azar.randi_range(-radio, radio))


func _caer_meteoritos(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	for i in range(estado.impactos.size() - 1, -1, -1):
		var impacto := estado.impactos[i]
		impacto["t"] = float(impacto["t"]) - delta_s
		if float(impacto["t"]) > 0.0:
			continue
		estado.impactos.remove_at(i)
		var centro := Vector2(impacto["tile"])
		var ids: Array[String] = []
		for edificio in estado.edificios:
			if _edificios.es_objetivo(edificio) and Vector2(edificio["tile"]).distance_to(centro) <= float(impacto["radio"]):
				ids.append(edificio["id"])
		for id in ids:
			eventos.append_array(_edificios.danar(estado, id, float(impacto["dano"])))
		if Vector2(estado.casilla_rover).distance_to(centro) <= float(impacto["radio"]):
			estado.rover_hp = maxf(estado.rover_hp - DANO_ROVER_METEORITO, 0.0)
			eventos.append(EVENTO_ROVER_GOLPEADO)
		_efecto(estado, impacto["tile"], centro, TTL_DISPARO * 2.0, "impact")
		eventos.append(EVENTO_IMPACTO)
	return eventos


# --- Monstruos --------------------------------------------------------------------------------------------------------

func _mover_y_atacar(estado: MissionState, delta_s: float) -> Array[String]:
	var eventos: Array[String] = []
	for enemigo in estado.enemigos:
		enemigo["cd"] = maxf(float(enemigo["cd"]) - delta_s, 0.0)
		enemigo["atk"] = maxf(float(enemigo["atk"]) - delta_s, 0.0)
		var def := _datos.enemigo(enemigo["type"])
		var blanco := _blanco_en_alcance(estado, enemigo["pos"], float(def["alcance"]))
		if not blanco.is_empty():
			if float(enemigo["cd"]) <= 0.0:
				enemigo["cd"] = float(def["cadencia_s"])
				enemigo["atk"] = TTL_ATAQUE
				eventos.append_array(_golpear(estado, def, blanco))
			continue
		var destino := Vector2(enemigo["dest"])
		var falta: Vector2 = destino - enemigo["pos"]
		var paso := float(def["velocidad"]) * delta_s
		if falta.length() <= paso + 0.001:
			enemigo["pos"] = destino
			enemigo["dest"] = _mapa.paso_hacia_la_estacion(enemigo["dest"])
		else:
			enemigo["pos"] = enemigo["pos"] + falta / falta.length() * paso
	return eventos


## Lo más cercano a «pos» que esté a tiro: {"kind": "edificio"|"rover"|"estacion", "id"?} (vacío si nada).
func _blanco_en_alcance(estado: MissionState, pos: Vector2, alcance: float) -> Dictionary:
	var mejor := {}
	var mejor_d := alcance
	for edificio in estado.edificios:
		if not _edificios.es_objetivo(edificio):
			continue
		var d := pos.distance_to(Vector2(edificio["tile"]))
		if d <= mejor_d:
			mejor_d = d
			mejor = {"kind": "edificio", "id": edificio["id"]}
	var d_rover := pos.distance_to(Vector2(estado.casilla_rover))
	if d_rover <= mejor_d:
		mejor_d = d_rover
		mejor = {"kind": "rover"}
	if pos.distance_to(Vector2(estado.casilla_estacion)) <= mejor_d:
		mejor = {"kind": "estacion"}
	return mejor


func _golpear(estado: MissionState, def: Dictionary, blanco: Dictionary) -> Array[String]:
	var eventos: Array[String] = []
	var drena := float(def.get("drena_wh", 0.0))
	match blanco["kind"]:
		"edificio":
			eventos.append_array(_edificios.danar(estado, blanco["id"], float(def["dano"]) * float(def.get("multiplicador_edificio", 1.0))))
		"rover":
			estado.rover_hp = maxf(estado.rover_hp - float(def.get("dano_rover", def["dano"])), 0.0)
			eventos.append(EVENTO_ROVER_GOLPEADO)
		"estacion":
			drena += float(def.get("dano_estacion_wh", 0.0))
			if estado.companero and estado.rocky_hp > 0.0:
				estado.rocky_hp = maxf(estado.rocky_hp - float(def.get("dano_rocky", 0.0)), 0.0)
	if drena > 0.0:
		estado.bateria_wh = maxf(estado.bateria_wh - drena, 0.0)
	return eventos


# --- Torretas ---------------------------------------------------------------------------------------------------------

func _disparar(estado: MissionState, delta_s: float, energia: EnergySystem) -> Array[String]:
	var apagado := estado.modo_seguro
	for edificio in estado.edificios:
		var arma := _economia.combate_de(edificio["type"])
		if arma.is_empty() or int(edificio["level"]) < 1 or not edificio["active"]:
			continue
		edificio["cd"] = maxf(float(edificio.get("cd", 0.0)) - delta_s, 0.0)
		if apagado or float(edificio["cd"]) > 0.0:
			continue
		var blanco := _enemigo_mas_cercano(estado, Vector2(edificio["tile"]), float(arma["alcance"]))
		if blanco.is_empty() or not energia.consumir(estado, float(arma.get("disparo_wh", 0.0))):
			continue
		blanco["hp"] = float(blanco["hp"]) - float(arma["dano"])
		edificio["cd"] = float(arma["cadencia_s"])
		_efecto(estado, edificio["tile"], blanco["pos"], TTL_DISPARO, "shot")
	return _retirar_abatidos(estado)


func _enemigo_mas_cercano(estado: MissionState, desde: Vector2, alcance: float) -> Dictionary:
	var mejor := {}
	var mejor_d := alcance
	for enemigo in estado.enemigos:
		if float(enemigo["hp"]) <= 0.0:
			continue
		var d := desde.distance_to(enemigo["pos"])
		if d <= mejor_d:
			mejor_d = d
			mejor = enemigo
	return mejor


func _retirar_abatidos(estado: MissionState) -> Array[String]:
	var eventos: Array[String] = []
	var olas_tocadas := {}
	for i in range(estado.enemigos.size() - 1, -1, -1):
		var enemigo := estado.enemigos[i]
		if float(enemigo["hp"]) > 0.0:
			continue
		olas_tocadas[enemigo["wave"]] = true
		eventos.append("%s:%s" % [EVENTO_ENEMIGO_ABATIDO, enemigo["type"]])
		estado.enemigos.remove_at(i)
	for ola in olas_tocadas:
		var quedan := false
		for enemigo in estado.enemigos:
			if enemigo["wave"] == ola:
				quedan = true
				break
		if not quedan:
			eventos.append("%s:%s" % [EVENTO_OLEADA_DERROTADA, ola])
	return eventos


# --- Rocky ------------------------------------------------------------------------------------------------------------

## Rocky repara el edificio más dañado y, dentro de la base, al rover. Cuesta batería y se esconde si hay monstruos cerca.
func _reparar(estado: MissionState, delta_s: float, energia: EnergySystem) -> void:
	if _datos.reparacion.is_empty() or not estado.companero or estado.rocky_hp <= 0.0 or estado.modo_seguro:
		return
	var estacion := Vector2(estado.casilla_estacion)
	for enemigo in estado.enemigos:
		if Vector2(enemigo["pos"]).distance_to(estacion) <= float(_datos.reparacion.get("rango_seguro", 4.0)):
			return
	var coste := float(_datos.reparacion.get("wh_por_hp", 0.0))
	var vida := float(_datos.reparacion.get("hp_por_s", 0.0)) * delta_s
	var peor := {}
	var peor_falta := 0.0
	for edificio in estado.edificios:
		if not _edificios.es_objetivo(edificio):
			continue
		var falta := _edificios.vida_maxima(edificio) - float(edificio["hp"])
		if falta > peor_falta:
			peor_falta = falta
			peor = edificio
	if not peor.is_empty() and energia.puede_consumir(estado, minf(vida, peor_falta) * coste):
		var puesta := _edificios.reparar(estado, peor["id"], vida)
		energia.consumir(estado, puesta * coste)
	if estado.rover_hp < 100.0 and _edificios.en_zona_base(estado, estado.casilla_rover):
		var vida_rover := minf(float(_datos.reparacion.get("rover_hp_por_s", 0.0)) * delta_s, 100.0 - estado.rover_hp)
		if energia.consumir(estado, vida_rover * coste):
			estado.rover_hp += vida_rover
