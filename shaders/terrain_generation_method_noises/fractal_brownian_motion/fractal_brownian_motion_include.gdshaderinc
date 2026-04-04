#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float period: hint_range(1.0, 64.0);
uniform float amplitude: hint_range(1.0, 64.0);

uniform int octaves: hint_range(1, 16);

uniform float lacunarity;
uniform float gain;

uniform int value_type;


float fract_brownian_motion(vec2 uv, int given_octaves, float base_period, float base_amp) {
	float total = 0.0;
	float peri = base_period;
	float amp = base_amp;
	while (given_octaves > 0) {
		float val = perlin_2D(uv / peri) * amp;
		if (value_type != 0) {
			total += abs(val);
		} else {
			total += val;
		}
		peri /= lacunarity;
		amp *= gain;
		given_octaves -= 1;
	}
	return total;
}

vec3 get_normal(vec2 uv, int given_octaves, float base_period, float base_amp) {
	const float delta = 16.0 / 1024.0;

	//float h = fract_brownian_motion(uv, given_octaves, base_period, base_amp);
	float hL = fract_brownian_motion(vec2(uv.x - delta, uv.y), given_octaves, base_period, base_amp);
	float hR = fract_brownian_motion(vec2(uv.x + delta, uv.y), given_octaves, base_period, base_amp);
	float hD = fract_brownian_motion(vec2(uv.x, uv.y - delta), given_octaves, base_period, base_amp);
	float hU = fract_brownian_motion(vec2(uv.x, uv.y + delta), given_octaves, base_period, base_amp);

	float dx = hR - hL;
	float dy = hU - hD;

	vec3 normal = normalize(vec3(-dx, delta, -dy));
	return normal;
}

void vertex() {
	vec2 uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	if (perturbate) {
		uv += 2.0 * perlin_2D(uv * 0.25);
	}

	if (value_type == 0 || value_type == 1) {
		VERTEX.y += fract_brownian_motion(uv, octaves, period, amplitude);
		if (value_type == 1) {
			VERTEX.y -= amplitude * 0.5;
		}
	} else { // value_type == 2
		VERTEX.y -= fract_brownian_motion(uv, octaves, period, amplitude);
		VERTEX.y += amplitude * 0.5;
	}
	NORMAL = get_normal(uv, octaves, period, amplitude);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world_pos.xz;
	if (perturbate) {
		uv += 2.0 * perlin_2D(uv * 0.25);
	}
	vec3 world_normal = get_normal(uv, octaves, period, amplitude);
	//float max_height = get_fract_brownian_motion_max_height(octaves, amplitude);

	ALBEDO = get_albedo(world_pos, world_normal, amplitude);
	ALPHA = get_alpha(world_pos, amplitude);
}
