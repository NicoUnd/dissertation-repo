#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float amplitude: hint_range(1.0, 64.0);

uniform sampler2D heightmap: repeat_disable;


float sample_heightmap(vec2 uv, float amp, sampler2D h) {
	return (texture(h, uv).r * 2.0 - 1.0) * amp;
}

vec3 get_normal(vec2 uv, float amp, sampler2D h) {
	ivec2 heightmap_size = textureSize(h, 0);
	float delta = 1.0 / float(heightmap_size.x);

	float hL = sample_heightmap(vec2(uv.x - delta, uv.y), amp, h);
	float hR = sample_heightmap(vec2(uv.x + delta, uv.y), amp, h);
	float hD = sample_heightmap(vec2(uv.x, uv.y - delta), amp, h);
	float hU = sample_heightmap(vec2(uv.x, uv.y + delta), amp, h);

    float dx = hR - hL;
    float dy = hU - hD;

    vec3 normal = normalize(vec3(-dx, delta * 64.0, -dy));
    return normal;
}

void vertex() {
	vec2 uv = UV;
	if (perturbate) {
		uv *= 32.0;
		uv += 2.0 * perlin_2D(uv * 0.25);
		uv /= 32.0;
	}
	VERTEX.y += sample_heightmap(uv, amplitude, heightmap);
	//VERTEX.y -= amplitude;
	NORMAL = get_normal(uv, amplitude, heightmap);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = UV;
	if (perturbate) {
		uv *= 32.0;
		uv += 2.0 * perlin_2D(uv * 0.25);
		uv /= 32.0;
	}
	vec3 world_normal = get_normal(uv, amplitude, heightmap);

	ALBEDO = get_albedo(world_pos, world_normal, amplitude);
	ALPHA = get_alpha(world_pos);
}