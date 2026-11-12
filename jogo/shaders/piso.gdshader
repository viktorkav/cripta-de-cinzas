shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_piso : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_piso : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_piso : hint_default_white, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D albedo_lado : source_color, filter_nearest_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_lado : hint_normal, filter_nearest_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 cust;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	cust = INSTANCE_CUSTOM.xyz;
}

vec2 girar(vec2 uv, float g) {
	if (g < 0.5) return uv;
	if (g < 1.5) return vec2(1.0 - uv.y, uv.x);
	if (g < 2.5) return vec2(1.0 - uv.x, 1.0 - uv.y);
	return vec2(uv.y, 1.0 - uv.x);
}

void fragment() {
	if (wnrm.y > 0.5) {
		vec2 uv = fract(wpos.xz + 0.5);
		uv = girar(uv, cust.y);
		float v = floor(cust.x + 0.5);
		vec2 cel = vec2(mod(v, 2.0), floor(v / 2.0));
		uv = (uv * 0.985 + 0.0075 + cel) * 0.5;
		ALBEDO = texture(albedo_piso, uv).rgb * cust.z * 1.35;
		NORMAL_MAP = texture(normal_piso, uv).rgb;
		ROUGHNESS = texture(rough_piso, uv).r;
	} else {
		vec2 uv = abs(wnrm.x) > 0.5 ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
		uv = vec2(uv.x, -uv.y / 3.0);
		ALBEDO = texture(albedo_lado, uv).rgb * 0.7 * cust.z;
		NORMAL_MAP = texture(normal_lado, uv).rgb;
		ROUGHNESS = 0.9;
	}
	SPECULAR = 0.35;
}
