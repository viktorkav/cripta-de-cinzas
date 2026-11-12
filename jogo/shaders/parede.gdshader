shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_lado : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_lado : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform vec2 furo_tela = vec2(0.5, 0.5);
uniform float furo_prof = 10.0;
uniform float furo_raio = 0.17;
uniform float aspecto = 1.7777;
uniform float furo_ativo = 1.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (furo_ativo > 0.5) {
		vec2 d = SCREEN_UV - furo_tela;
		d.x *= aspecto;
		float prof = -VERTEX.z;
		if (prof < furo_prof - 0.8) {
			float k = smoothstep(furo_raio, furo_raio * 0.55, length(d));
			float ign = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))));
			if (k > ign) discard;
		}
	}
	if (wnrm.y > 0.5) {
		ALBEDO = vec3(0.018, 0.016, 0.017);
		ROUGHNESS = 1.0;
	} else {
		vec2 uv = abs(wnrm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		uv = vec2(uv.x, -uv.y / 3.0);
		ALBEDO = texture(albedo_lado, uv).rgb;
		NORMAL_MAP = texture(normal_lado, uv).rgb;
		ROUGHNESS = 0.92;
	}
	SPECULAR = 0.3;
}
