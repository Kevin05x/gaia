class_name Horizonte
extends RefCounted
## Paisaje lejano del cráter (fuera de la zona jugable): lomas que lo rodean 360° y, más allá, dos filas de mesetas
## escalonadas. Separado de terrain.gd (que ya era muy grande) y construido como malla indexada: cada vértice se calcula
## una sola vez (antes, seis), así la carga gasta unas 6 veces menos en esto. Sin colisión ni sombras.
const W := preload("res://scenes/b/world_art.gd")
const BASIN_Y := -0.55
## Paleta acercada a la foto NASA PIA24542 (Jezero), como la del terreno: el borde del cráter se ve claro y desvaído por
## el polvo del aire (colinas medidas #C5AA8C, cielo junto al horizonte #DABFA2). Ver ARTE_Y_LICENCIAS.md.
const BASIN := Color("B59372")
const MOUNTAIN := Color("886D5A")
const ESTRATO_A := Color("936A4E")
const ESTRATO_B := Color("C69772")
const CUMBRE := Color("D9B493")
const CIELO := Color("DAB495")
const AIRE_LOMAS := 0.12  ## bruma de las lomas (a 76–170 m); las mesetas, más lejos, llevan más
const AIRE_MESETAS := 0.55


const CORDILLERA := "res://assets/horizonte/cordillera.glb"  ## la saca tools/blender/horizonte.py
const S_REFERENCIA := 140.0  ## medio lado del mapa para el que se generó la cordillera (m)
const R_DENTRO := 290.0
const R_FUERA := 575.0


static func hay_cordillera() -> bool:
	return ResourceLoader.exists(CORDILLERA)


## Cordillera hecha en Blender (picos, mesetas escalonadas y barrancos): sustituye a las lomas y a las mesetas por código.
## Solo trae la forma; el color, la neblina y la paleta de Marte o la Luna se ponen aquí, con las mismas reglas de siempre.
## null si falta el archivo (entonces se usan lomas() y mesetas()).
static func cordillera(s: float, fino: FastNoiseLite) -> MeshInstance3D:
	if not hay_cordillera():
		return null
	var escena := load(CORDILLERA) as PackedScene
	if escena == null:
		return null
	var raiz := escena.instantiate()
	var origen: Mesh = null
	for nodo in raiz.find_children("*", "MeshInstance3D", true, false):
		origen = (nodo as MeshInstance3D).mesh
		break
	raiz.free()
	if origen == null or origen.get_surface_count() < 1:
		return null
	var datos := origen.surface_get_arrays(0)
	var vertices: PackedVector3Array = datos[Mesh.ARRAY_VERTEX]
	var normales: PackedVector3Array = datos[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = datos[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or indices.is_empty():
		return null
	var escala := s / S_REFERENCIA if s > 0.0 else 1.0
	var hacia_arriba := 0.0
	for n in normales:
		hacia_arriba += n.y
	var invertir := hacia_arriba < 0.0  # la malla se ve desde dentro del cráter: las normales deben mirar hacia arriba
	var colores := PackedColorArray()
	colores.resize(vertices.size())
	for i in range(vertices.size()):
		var v := vertices[i]
		v.x *= escala
		v.z *= escala
		vertices[i] = v
		var nrm := (-normales[i] if invertir else normales[i]).normalized()
		normales[i] = nrm
		var t := clampf((Vector2(v.x, v.z).length() / escala - R_DENTRO) / (R_FUERA - R_DENTRO), 0.0, 1.0)
		var altura := v.y - BASIN_Y
		var tono := BASIN.lerp(MOUNTAIN, smoothstep(0.5, 6.0, altura))
		var banda := 0.5 + 0.5 * sin(altura * 0.55 + fino.get_noise_2d(v.x * 0.02, v.z * 0.02) * 3.0)
		tono = tono.lerp(ESTRATO_A.lerp(ESTRATO_B, banda), smoothstep(2.0, 14.0, altura) * 0.85)
		tono *= lerpf(0.52, 1.0, smoothstep(0.30, 0.80, nrm.y)) * 0.9  # paredes y barrancos, en sombra
		tono = tono.lerp(CUMBRE, smoothstep(30.0, 85.0, altura) * 0.35)  # cumbres al sol
		tono *= 1.0 + fino.get_noise_2d(v.x * 0.5, v.z * 0.5) * 0.06
		tono = tono.lerp(CIELO, lerpf(0.04, 0.36, smoothstep(0.05, 0.95, t)))
		tono.a = 1.0
		colores[i] = tono
	if invertir:
		for j in range(0, indices.size(), 3):
			var tmp := indices[j + 1]
			indices[j + 1] = indices[j + 2]
			indices[j + 2] = tmp
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = Destino.colores(colores)
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var nodo := MeshInstance3D.new()
	nodo.name = "Cordillera"
	nodo.mesh = malla
	nodo.material_override = W.cordillera_material()
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Faldón: un suelo enorme y plano justo debajo de todo, del color de la lejanía. Tapa la franja donde el suelo de las colinas
	# termina y la cordillera aún no empieza (por ahí se veía el cielo negro como una línea).
	var faldon := MeshInstance3D.new()
	faldon.name = "Faldon"
	var plano := PlaneMesh.new()
	plano.size = Vector2(1700.0, 1700.0)
	faldon.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Destino.color(BASIN.lerp(CIELO, 0.25))
	mat.roughness = 1.0
	mat.metallic_specular = 0.04
	faldon.material_override = mat
	faldon.position = Vector3(0.0, BASIN_Y - 0.45, 0.0)
	faldon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nodo.add_child(faldon)
	return nodo


## Lomas: 17 anillos con crestas finas, estratos de color (como las paredes del delta de Jezero), laderas empinadas
## más oscuras y cumbres más claras. «s»: medio lado del mapa jugable (m).
static func lomas(s: float, fino: FastNoiseLite) -> MeshInstance3D:
	var ruido := FastNoiseLite.new()
	ruido.seed = 314
	ruido.frequency = 1.0
	var o := s * 1.4  # las lomas se alejan más que el borde: las esquinas del mapa están a 1,41 veces
	var segmentos := 240
	var puntos: Array = []
	for k in range(17):
		var radio := 76.0 + k * 5.6 + o
		var anillo := PackedVector3Array()
		anillo.resize(segmentos)
		for s_idx in range(segmentos):
			var ang := TAU * s_idx / segmentos
			var c := cos(ang)
			var sn := sin(ang)
			var r: float = radio + ruido.get_noise_2d(c * 3.0, sn * 3.0 + k * 0.6) * 5.0
			var n1 := (ruido.get_noise_2d(c * 2.2, sn * 2.2) + 1.0) * 0.5
			var n2 := (ruido.get_noise_2d(c * 1.4 + 40.0, sn * 1.4) + 1.0) * 0.5
			var h := BASIN_Y + (2.5 + 6.0 * n1) * _bump(r - o, 102.0, 24.0) + (9.0 + 15.0 * n2) * _bump(r - o, 158.0, 32.0)
			h += ruido.get_noise_2d(c * 9.0, sn * 9.0 + k * 0.3) * 1.6 * smoothstep(80.0, 100.0, r - o)
			var cresta := 1.0 - absf(ruido.get_noise_2d(c * 6.0 + 20.0, sn * 6.0 + k * 0.2))
			h += cresta * cresta * 4.5 * smoothstep(100.0, 150.0, r - o) * _bump(r - o, 158.0, 34.0)
			# Crestas finas (ruido «ridged» de alta frecuencia): siluetas nítidas contra el cielo.
			var fina := 1.0 - absf(ruido.get_noise_2d(c * 24.0 + 7.0, sn * 24.0 + k * 0.4))
			h += pow(fina, 3.0) * 2.2 * smoothstep(110.0, 150.0, r - o) * _bump(r - o, 160.0, 30.0)
			h += ruido.get_noise_2d(c * 17.0, sn * 17.0 + k * 0.6) * 1.1 * smoothstep(90.0, 130.0, r - o)
			anillo[s_idx] = Vector3(c * r, h, sn * r)
		puntos.append(anillo)
	var nodo := _malla(puntos, "Mountains", AIRE_LOMAS, fino)
	nodo.material_override = W.mountain_material()  # estratos en triplanar (Marte, calidad con texturas)
	return nodo


## Horizonte lejano: mesetas en terrazas más allá de las lomas, aclaradas hacia el color del cielo (perspectiva aérea
## «pintada» en los vértices): se leen lejos sin depender de una niebla espesa que lo emborrona todo.
static func mesetas(s: float, fino: FastNoiseLite) -> MeshInstance3D:
	var ruido := FastNoiseLite.new()
	ruido.seed = 902
	ruido.frequency = 1.0
	var o := s * 1.4
	var segmentos := 220
	var puntos: Array = []
	for k in range(9):
		var radio := 250.0 + k * 14.0 + o
		var perfil := _bump(radio - o, 300.0, 70.0)
		var anillo := PackedVector3Array()
		anillo.resize(segmentos)
		for s_idx in range(segmentos):
			var ang := TAU * s_idx / segmentos + 0.013 * k
			var c := cos(ang)
			var sn := sin(ang)
			var r: float = radio + ruido.get_noise_2d(c * 4.0, sn * 4.0) * 8.0
			var base := (ruido.get_noise_2d(c * 2.5 + 11.0, sn * 2.5) + 1.0) * 0.5
			var alto := 14.0 + 34.0 * base * base
			alto = lerpf(floorf(alto / 7.0) * 7.0, alto, 0.25)  # terrazas: cimas planas, paredes casi verticales
			var h := BASIN_Y + alto * perfil + ruido.get_noise_2d(c * 30.0, sn * 30.0 + k) * 1.2 * perfil
			anillo[s_idx] = Vector3(c * r, h, sn * r)
		puntos.append(anillo)
	return _malla(puntos, "Skyline", AIRE_MESETAS, fino)


## Une los anillos en una malla indexada con color por vértice. «aire» (0..1) aclara hacia el color del cielo.
static func _malla(puntos: Array, nombre: String, aire: float, fino: FastNoiseLite) -> MeshInstance3D:
	var anillos := puntos.size()
	var segmentos: int = (puntos[0] as PackedVector3Array).size()
	var vertices := PackedVector3Array()
	var normales := PackedVector3Array()
	var colores := PackedColorArray()
	vertices.resize(anillos * segmentos)
	normales.resize(anillos * segmentos)
	colores.resize(anillos * segmentos)
	for k in range(anillos):
		var fila: PackedVector3Array = puntos[k]
		var dentro_f: PackedVector3Array = puntos[maxi(k - 1, 0)]
		var fuera_f: PackedVector3Array = puntos[mini(k + 1, anillos - 1)]
		for s_idx in range(segmentos):
			var v := fila[s_idx]
			var nrm := (fuera_f[s_idx] - dentro_f[s_idx]).cross(fila[(s_idx + 1) % segmentos] - fila[(s_idx + segmentos - 1) % segmentos])
			if nrm.y < 0.0:
				nrm = -nrm
			nrm = nrm.normalized()
			var altura := v.y - BASIN_Y
			var tono := BASIN.lerp(MOUNTAIN, smoothstep(0.5, 6.0, altura))
			var banda := 0.5 + 0.5 * sin(altura * 1.35 + fino.get_noise_2d(v.x * 0.05, v.z * 0.05) * 2.5)
			tono = tono.lerp(ESTRATO_A.lerp(ESTRATO_B, banda), smoothstep(2.0, 8.0, altura) * 0.55)
			tono *= lerpf(0.72, 1.0, smoothstep(0.35, 0.85, nrm.y))  # paredes empinadas en sombra
			tono = tono.lerp(CUMBRE, smoothstep(16.0, 34.0, altura) * 0.25)  # cumbres al sol
			tono *= 1.0 + fino.get_noise_2d(v.x * 0.7, v.z * 0.7) * 0.08
			tono = tono.lerp(CIELO, aire)
			tono.a = 1.0
			var i := k * segmentos + s_idx
			vertices[i] = v
			normales[i] = nrm
			colores[i] = tono
	var indices := PackedInt32Array()
	indices.resize((anillos - 1) * segmentos * 6)
	var j := 0
	for k in range(anillos - 1):
		for s_idx in range(segmentos):
			var a := k * segmentos + s_idx
			var b := (k + 1) * segmentos + s_idx
			var a2 := k * segmentos + (s_idx + 1) % segmentos
			var b2 := (k + 1) * segmentos + (s_idx + 1) % segmentos
			for idx in [a, b, a2, a2, b, b2]:
				indices[j] = idx
				j += 1
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normales
	arrays[Mesh.ARRAY_COLOR] = Destino.colores(colores)
	arrays[Mesh.ARRAY_INDEX] = indices
	var malla := ArrayMesh.new()
	malla.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var nodo := MeshInstance3D.new()
	nodo.name = nombre
	nodo.mesh = malla
	nodo.material_override = W.vertex_material(false)
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return nodo


static func _bump(r: float, centro: float, ancho: float) -> float:
	var t := (r - centro) / ancho
	return maxf(0.0, 1.0 - t * t)
