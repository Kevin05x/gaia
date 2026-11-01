class_name CieloMarte
extends RefCounted
## Cielo de Marte hecho a medida (sustituye al cielo procedural genérico). Basado en las fotos de los rovers de la NASA:
## de día el cielo es ocre/caramelo y más claro en el horizonte (polvo en suspensión); al amanecer y al atardecer el
## polvo deja pasar mejor la luz azul hacia delante y aparece un halo azulado alrededor del Sol. De noche, estrellas.
## Coste: solo se calcula en los píxeles de cielo (y en el mapa de reflejos de 64 px cuando cambia), sin texturas.
const CODIGO := """
shader_type sky;

uniform vec3 cenit : source_color = vec3(0.62, 0.48, 0.42);
uniform vec3 horizonte : source_color = vec3(0.84, 0.66, 0.53);
uniform vec3 suelo_horizonte : source_color = vec3(0.73, 0.55, 0.45);
uniform vec3 suelo : source_color = vec3(0.30, 0.20, 0.17);
uniform vec3 halo_azul : source_color = vec3(0.55, 0.70, 0.88);
uniform float atardecer = 0.0;  // 0 de día, 1 con el Sol en el horizonte: activa el halo azul
uniform float polvo = 0.0;      // tormenta: halo más ancho y cielo más plano
uniform float noche = 0.0;      // 1 de noche: estrellas

float hash3(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		// Degradado del cénit al horizonte, con una banda de bruma luminosa justo encima del horizonte.
		col = mix(horizonte, cenit, pow(h, mix(0.42, 0.75, polvo)));
		col = mix(col, horizonte * 1.06, exp(-h * 18.0) * 0.45);
	} else {
		col = mix(suelo_horizonte, suelo, 1.0 - exp(h * 6.0));
	}
	if (LIGHT0_ENABLED) {
		vec3 l = normalize(LIGHT0_DIRECTION);
		float c = max(dot(d, l), 0.0);
		vec3 tono = LIGHT0_COLOR;
		// Halo: estrecho y brillante cerca del disco, ancho y suave alrededor (más ancho con polvo).
		float corona = pow(c, mix(900.0, 200.0, polvo)) * 1.4 + pow(c, mix(40.0, 10.0, polvo)) * 0.35
			+ pow(c, 6.0) * 0.12;
		vec3 halo = mix(tono, halo_azul * 1.3, atardecer * smoothstep(0.75, 0.995, c));
		col += halo * corona * min(LIGHT0_ENERGY, 1.5) * (1.0 - noche * 0.75);
		float disco = smoothstep(0.99975, 0.99992, c);
		col = mix(col, tono * 3.0, disco * (1.0 - polvo * 0.6));
	}
	if (noche > 0.01 && h > 0.0 && !AT_CUBEMAP_PASS) {
		vec3 celda = floor(d * 260.0);
		float estrella = step(0.9975, hash3(celda));
		float brillo = hash3(celda + 7.0);
		col += vec3(0.95, 0.92, 1.0) * estrella * (0.4 + 0.6 * brillo) * noche * smoothstep(0.02, 0.25, h) * (1.0 - polvo);
	}
	// El mapa de reflejos (cubemap) se oscurece: un cielo de Marte tan claro, reflejado en el regolito y los paneles,
	// lavaba todo el suelo. El cielo que se ve no cambia.
	if (AT_CUBEMAP_PASS) {
		col *= 0.42;
	}
	COLOR = col;
}
"""


static func material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = CODIGO
	var m := ShaderMaterial.new()
	m.shader = sh
	return m
