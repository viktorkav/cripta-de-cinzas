shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D ruido : filter_linear_mipmap, repeat_enable;
// PBR da Tripo (nó PBR do Canvas), empacotado no padrão glTF: G = roughness, B = metallic
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float usar_pbr = 0.0;
// O normal map da Tripo ficou de fora: medido em 11/11, muda menos de 0,5/255 em média nos modelos (faces voxel planas)
uniform float dissolver = 0.0;
uniform vec4 cor_borda : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform float flash = 0.0;
uniform vec4 cor_flash : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float aro = 0.0;
uniform vec4 cor_aro : source_color = vec4(1.0, 0.25, 0.15, 1.0);
uniform vec4 tinta : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float brilho_extra = 0.0;
uniform vec4 cor_extra : source_color = vec4(1.0, 0.2, 0.05, 1.0);
uniform float aro_base = 0.18;
uniform vec4 cor_aro_base : source_color = vec4(0.55, 0.62, 0.85, 1.0);

varying vec3 opos;

void vertex() {
	opos = VERTEX;
}

void fragment() {
	vec3 a = texture(albedo_tex, UV).rgb * tinta.rgb;
	float n = texture(ruido, opos.xz * 2.3 + vec2(opos.y * 1.7, opos.y * 0.6)).r;
	float alt = clamp(opos.y, 0.0, 1.0);
	n = n * 0.75 + (1.0 - alt) * 0.25;
	if (dissolver > 0.0 && n < dissolver) {
		discard;
	}
	float borda = dissolver > 0.0 ? smoothstep(dissolver + 0.07, dissolver, n) : 0.0;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = a;
	vec3 orm = texture(orm_tex, UV).rgb;
	ROUGHNESS = mix(0.72, orm.g, usar_pbr);
	METALLIC = orm.b * usar_pbr;
	SPECULAR = 0.4;
	vec3 em = cor_borda.rgb * borda * 7.0;
	em += cor_flash.rgb * flash * 1.6;
	em += cor_aro.rgb * fres * aro * 2.5;
	em += cor_aro_base.rgb * fres * aro_base * 0.6;
	em += cor_extra.rgb * brilho_extra * (0.3 + fres);
	EMISSION = em;
}
