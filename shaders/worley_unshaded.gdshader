shader_type spatial;
render_mode depth_prepass_alpha, unshaded;

#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float period: hint_range(1.0, 64.0);
uniform float amplitude: hint_range(1.0, 64.0);

uniform float c1: hint_range(0.0, 1.0, 0.1);
uniform float c2: hint_range(0.0, 1.0, 0.1);
uniform float c3: hint_range(0.0, 1.0, 0.1);

float worley(vec2 uv, float peri, float amp) {
	vec2 grid_index = floor(uv / peri);
	vec2 grid_fract = fract(uv / peri);

	float min_dist = 9999.9;
	float second_min_dist = 9999.9;
	float third_min_dist = 9999.9;

	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = random(grid_index + neighbor);
			vec2 displacement = neighbor + point - grid_fract;
			float dist = displacement.x * displacement.x + displacement.y * displacement.y; // no sqrt for efficiency
			if (dist < min_dist) {
				third_min_dist = second_min_dist;
				second_min_dist = min_dist;
				min_dist = dist;
			} else {
				if (dist < second_min_dist) {
					third_min_dist = second_min_dist;
					second_min_dist = dist;
				} else {
					if (dist < third_min_dist) {
						third_min_dist = dist;
					}
				}
			}
		}
	}
	return clamp(c1 * min_dist + c2 * second_min_dist + c3 * third_min_dist, -1.0, 1.0) * amp;
}

vec3 get_normal(vec2 uv, float peri, float amp) {
	const float delta = 0.01;

    float hL = worley(vec2(uv.x - delta, uv.y), peri, amp);
    float hR = worley(vec2(uv.x + delta, uv.y), peri, amp);
    float hD = worley(vec2(uv.x, uv.y - delta), peri, amp);
    float hU = worley(vec2(uv.x, uv.y + delta), peri, amp);

    float dx = hR - hL;
    float dy = hU - hD;

    vec3 normal = normalize(vec3(-dx, delta, -dy));
    return normal;
}

void vertex() {
	vec2 uv = VERTEX.xz;
	if (perturbate) {
		uv += 2.0 * perlin_2D(uv * 0.25);
	}
	VERTEX.y += worley(uv, period, amplitude);
	NORMAL = get_normal(uv, period, amplitude);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = world_pos.xz;
	if (perturbate) {
		uv += 2.0 * perlin_2D(uv * 0.25);
	}
	vec3 world_normal = get_normal(uv, period, amplitude);

	if (albedo_type == 0) {
		//vec2 texture_uv = fract(world_pos.xz);
		//texture_uv += 2.0 * perlin_2D(texture_uv * 0.25);
		float steepness = dot(world_normal, vec3(0.0, 1.0, 0.0));
		steepness *= steepness;
		float highness = smoothstep(0.15, 0.7, world_pos.y * 2.0 / (amplitude * 0.5));
		ALBEDO = (steepness * (highness * vec4(1.0, 1.0, 1.0, 1.0) + (1.0 - highness) * vec4(0.15, 0.25, 0.18, 1.0)) +
		(1.0 - steepness) * vec4(0.02, 0.02, 0.02, 1.0)).xyz;
		//ALBEDO = (steepness * vec4(0.2, 0.25, 0.2, 1.0) +
		//(1.0 - steepness) * vec4(0.05, 0.05, 0.05, 1.0)).xyz;
	} else {
		if (albedo_type == 1) {
			ALBEDO = vec3(((world_pos.y + amplitude * 0.5) / (amplitude)));
			ALBEDO = vec3((world_pos.y + amplitude) / (2.0 * amplitude));
		} else { // albedo_type == 2
			ALBEDO = world_normal;
		}
	}

	if (circle) {
		ALPHA = 1.0 - smoothstep(512.0 + 256.0 + 128.0 + 64.0 + 32.0, 1024.0, world_pos.x * world_pos.x + world_pos.z * world_pos.z);
	}
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
