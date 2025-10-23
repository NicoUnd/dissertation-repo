shader_type spatial;
render_mode depth_prepass_alpha;

#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float period: hint_range(1.0, 64.0);
uniform float amplitude: hint_range(1.0, 64.0);

uniform int octaves: hint_range(1, 16);

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
		peri /= 2.0;
		amp /= 2.0;
		given_octaves -= 1;
	}
	return total;
}

vec3 get_normal(vec2 uv, int given_octaves, float base_period, float base_amp) {
	const float delta = 0.01;

    float hL = fract_brownian_motion(vec2(uv.x - delta, uv.y), given_octaves, base_period, base_amp);
    float hR = fract_brownian_motion(vec2(uv.x + delta, uv.y), given_octaves, base_period, base_amp);
    float hD = fract_brownian_motion(vec2(uv.x, uv.y - delta), given_octaves, base_period, base_amp);
    float hU = fract_brownian_motion(vec2(uv.x, uv.y + delta), given_octaves, base_period, base_amp);

    float dx = hR - hL;
    float dy = hU - hD;

    vec3 normal = normalize(vec3(-dx, delta, -dy));
    return normal;
}

float get_fract_brownian_motion_max_height(int given_octaves, float base_amp) {
	float max_height = 0.0;
	int octave = 0;
	float amp = base_amp;
	while (octave < given_octaves) {
		max_height += amp;
		amp /= 2.0;
		octave += 1;
	}
	//max_height *= 0.5;
	if (value_type != 0) {
		max_height *= 0.5;
	}
	return max_height;
}

void vertex() {
	vec2 uv = VERTEX.xz;
	if (perturbate) {
		uv += 2.0 * perlin_2D(uv * 0.25);
	}
	
	if (value_type == 0 || value_type == 1) {
		VERTEX.y += fract_brownian_motion(uv, octaves, period, amplitude);
		if (value_type == 1) {
			VERTEX.y -= get_fract_brownian_motion_max_height(octaves, amplitude) * 0.25;
		}
	} else { // value_type == 2
		VERTEX.y -= fract_brownian_motion(uv, octaves, period, amplitude);
		VERTEX.y += get_fract_brownian_motion_max_height(octaves, amplitude) * 0.25;
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
	float max_height = get_fract_brownian_motion_max_height(octaves, amplitude);

	if (albedo_type == 0) {
		//vec2 texture_uv = fract(world_pos.xz);
		//texture_uv += 2.0 * perlin_2D(texture_uv * 0.25);
		float steepness = dot(world_normal, vec3(0.0, 1.0, 0.0));
		steepness *= steepness;
		float highness = smoothstep(0.15, 0.7, world_pos.y * 2.0 / max_height);
		ALBEDO = (steepness * (highness * vec4(1.0, 1.0, 1.0, 1.0) + (1.0 - highness) * vec4(0.15, 0.25, 0.18, 1.0)) +
		(1.0 - steepness) * vec4(0.02, 0.02, 0.02, 1.0)).xyz;
		//ALBEDO = (steepness * vec4(0.2, 0.25, 0.2, 1.0) +
		//(1.0 - steepness) * vec4(0.05, 0.05, 0.05, 1.0)).xyz;
	} else {
		if (albedo_type == 1) {
			ALBEDO = vec3(((world_pos.y + max_height) / (max_height * 2.0)));
			ALBEDO = vec3(world_pos.y / max_height + 0.5);
		} else { // albedo_type == 2
			ALBEDO = world_normal;
		}
	}
	
	if (circle) {
		ALPHA = 1.0 - smoothstep(512.0 + 256.0 + 128.0 + 64.0 + 32.0, 1024.0, world_pos.x * world_pos.x + world_pos.z * world_pos.z);
	}
}
