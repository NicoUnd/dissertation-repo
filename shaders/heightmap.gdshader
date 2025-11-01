shader_type spatial;
render_mode depth_prepass_alpha;

#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float amplitude: hint_range(1.0, 64.0);

uniform sampler2D heightmap;


float sample_heightmap(vec2 uv, float amp, sampler2D h) {
	return (texture(h, uv).r * 2.0 - 1.0) * amp;
}

vec3 get_normal(vec2 uv, float amp, sampler2D h) {
	const float delta = 1.0 / 4096.0;

	vec2 uv_clamped = clamp(vec2(uv.x - delta, uv.y), 0.0, 1.0);
    float hL = sample_heightmap(uv_clamped, amp, h);
	uv_clamped = clamp(vec2(uv.x + delta, uv.y), 0.0, 1.0);
    float hR = sample_heightmap(uv_clamped, amp, h);
	uv_clamped = clamp(vec2(uv.x, uv.y - delta), 0.0, 1.0);
    float hD = sample_heightmap(uv_clamped, amp, h);
	uv_clamped = clamp(vec2(uv.x, uv.y + delta), 0.0, 1.0);
    float hU = sample_heightmap(uv_clamped, amp, h);

    float dx = hR - hL;
    float dy = hU - hD;

    vec3 normal = normalize(vec3(-dx, delta * 16.0, -dy));
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
	//NORMAL = get_normal(uv, amplitude, heightmap);
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

	if (albedo_type == 0) {
		//vec2 texture_uv = fract(world_pos.xz);
		//texture_uv += 2.0 * perlin_2D(texture_uv * 0.25);
		float steepness = dot(world_normal, vec3(0.0, 1.0, 0.0));
		float highness = smoothstep(0.15, 0.7, world_pos.y / amplitude);
		ALBEDO = (steepness * (highness * vec4(1.0, 1.0, 1.0, 1.0) + (1.0 - highness) * vec4(0.15, 0.25, 0.18, 1.0)) +
		(1.0 - steepness) * vec4(0.02, 0.02, 0.02, 1.0)).xyz;
		//ALBEDO = (steepness * vec4(0.2, 0.25, 0.2, 1.0) +
		//(1.0 - steepness) * vec4(0.05, 0.05, 0.05, 1.0)).xyz;
	} else {
		if (albedo_type == 1) {
			//ALBEDO = vec3(((world_pos.y + amplitude * 0.5) / amplitude));
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
