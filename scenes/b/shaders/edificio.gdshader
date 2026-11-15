// Material realista de los edificios, la estación y los vehículos de bloques (ver scenes/b/material_edificio.gd).
// Conserva el color de cada pieza (color, textura de paleta o color de vértice) y le añade, en proyección triplanar
// en metros reales del objeto, la chapa de paneles atornillados (juntas, remaches, rayones, suciedad), su relieve y
// su rugosidad. Encima, el polvo del destino: se posa en las caras que miran hacia arriba y sube desde el suelo.
// Las coordenadas son las del objeto (no las del mundo): la textura no «resbala» cuando la torreta gira o el dron vuela.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform bool use_vcol = false;
uniform bool pbr_uv2 = false;  // mallas fundidas: UV2 = (rugosidad, metal) de cada pieza
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D paneles_detalle : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D paneles_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paneles_mascaras : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;  // R rugosidad, G polvo, B oclusión
uniform float metros_panel = 2.0;  // metros que ocupa una repetición de la textura de paneles
uniform float detalle : hint_range(0.0, 1.0) = 1.0;  // 0: sin texturas (calidad baja)
uniform float fuerza_normal = 0.6;

uniform vec3 polvo_color : source_color = vec3(0.45, 0.44, 0.42);
uniform float polvo : hint_range(0.0, 1.0) = 0.5;
uniform float lunar : hint_range(0.0, 1.0) = 0.0;  // 1 en la Luna: sin color cálido, chapa plateada y mate
uniform float base_y = 0.0;  // altura local del suelo del modelo (en unidades del modelo)

varying vec3 tri_pos;
varying vec3 tri_peso;
varying float alto_m;
varying vec2 pbr;

vec4 triplanar(sampler2D s, vec3 p, vec3 w) {
	return texture(s, p.xy) * w.z + texture(s, p.xz) * w.y + texture(s, p.zy * vec2(-1.0, 1.0)) * w.x;
}

void vertex() {
	vec3 esc = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	tri_pos = VERTEX * esc / metros_panel * vec3(1.0, -1.0, 1.0);
	vec3 w = pow(abs(NORMAL), vec3(4.0));
	tri_peso = w / max(w.x + w.y + w.z, 0.0001);
	alto_m = (VERTEX.y - base_y) * esc.y;
	pbr = pbr_uv2 ? UV2 : vec2(roughness, metallic);
	// Tangentes de la proyección triplanar (las mismas que usa StandardMaterial3D con triplanar).
	TANGENT = vec3(0.0, 0.0, -1.0) * abs(NORMAL.x) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.y) + vec3(1.0, 0.0, 0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0, 1.0, 0.0) * abs(NORMAL.x) + vec3(0.0, 0.0, -1.0) * abs(NORMAL.y) + vec3(0.0, 1.0, 0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
}

vec3 srgb_a_lineal(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), vec3(lessThan(c, vec3(0.04045))));
}

void fragment() {
	vec4 c = albedo_color;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (use_vcol) {
		c.rgb *= srgb_a_lineal(COLOR.rgb);
	}
	float rug = pbr.x;
	float met = pbr.y;
	float pegado = 0.25;
	if (detalle > 0.0) {
		vec3 d = triplanar(paneles_detalle, tri_pos, tri_peso).rgb;
		vec3 m = triplanar(paneles_mascaras, tri_pos, tri_peso).rgb;
		c.rgb *= mix(vec3(1.0), d * (1.0 / 0.9), detalle);
		rug = clamp(mix(rug, rug * (0.55 + 0.8 * m.r), detalle), 0.05, 1.0);
		pegado = mix(0.25, m.g, detalle);
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), triplanar(paneles_normal, tri_pos, tri_peso).rgb, detalle);
		NORMAL_MAP_DEPTH = fuerza_normal;
		AO = mix(1.0, m.b, detalle);
		AO_LIGHT_AFFECT = 0.4;
	}
	// Polvo: en las caras que miran hacia arriba y en la franja baja que toca el suelo.
	vec3 normal_mundo = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float arriba = smoothstep(0.45, 0.95, normal_mundo.y);
	float abajo = 1.0 - smoothstep(0.0, 0.7, alto_m);
	float p = clamp((arriba * (0.45 + 0.9 * pegado) + abajo * (0.35 + 0.6 * pegado)) * polvo, 0.0, 0.85);
	vec3 base_color = c.rgb;
	if (lunar > 0.0) {
		float lum = dot(base_color, vec3(0.299, 0.587, 0.114));
		base_color = mix(base_color, vec3(lum * 0.92) * vec3(0.98, 0.99, 1.03), lunar * 0.9);
	}
	ALBEDO = mix(base_color, polvo_color, p);
	ROUGHNESS = mix(rug, 0.95, p);
	METALLIC = mix(met, 0.0, p);
}
