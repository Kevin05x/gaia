class_name Horizonte
extends RefCounted
## Paisaje lejano del cráter (fuera de la zona jugable): lomas que lo rodean 360° y, más allá, dos filas de mesetas
## escalonadas. Separado de terrain.gd (que ya era muy grande) y construido como malla indexada: cada vértice se calcula
## una sola vez (antes, seis), así la carga gasta unas 6 veces menos en esto. Sin colisión ni sombras.
const W := preload("res://scenes/b/world_art.gd")
const BASIN_Y := -0.55
const BASIN := Color("C99C78")
const MOUNTAIN := Color("85655C")
const ESTRATO_A := Color("9A5E44")
const ESTRATO_B := Color("C48B66")
const CUMBRE := Color("D8A884")
const CIELO := Color("C9957A")


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
	return _malla(puntos, "Mountains", 0.0, fino)


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
	return _malla(puntos, "Skyline", 0.45, fino)


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
	arrays[Mesh.ARRAY_COLOR] = colores
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
