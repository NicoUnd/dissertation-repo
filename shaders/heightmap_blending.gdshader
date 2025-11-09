shader_type spatial;
render_mode depth_prepass_alpha;

#include "res://shaders/shader_include.gdshaderinc"

// terrain generation method specific parameters
uniform float amplitude: hint_range(1.0, 64.0);

uniform sampler2D heightmap1;
uniform sampler2D heightmap2;
uniform sampler2D heightmap3;
uniform sampler2D heightmap4;

uniform float c1: hint_range(0.0, 1.0, 0.1);
uniform float c2: hint_range(0.0, 1.0, 0.1);
uniform float c3: hint_range(0.0, 1.0, 0.1);
uniform float c4: hint_range(0.0, 1.0, 0.1);


varying float c1_normalised;
varying float c2_normalised;
varying float c3_normalised;
varying float c4_normalised;

float blend_heightmaps(vec2 uv, float amp, sampler2D h1, sampler2D h2, sampler2D h3, sampler2D h4, float given_c1, float given_c2, float given_c3, float given_c4) {
	return ((texture(h1, uv).r * given_c1 + texture(h2, uv).r * given_c2 + texture(h3, uv).r * given_c3 + texture(h4, uv).r * given_c4) * 2.0 - 1.0)* amp;
}

vec3 get_normal(vec2 uv, float amp, sampler2D h1, sampler2D h2, sampler2D h3, sampler2D h4, float given_c1, float given_c2, float given_c3, float given_c4) {
	const float delta = 1.0 / 4096.0;

	vec2 uv_clamped = clamp(vec2(uv.x - delta, uv.y), 0.0, 1.0);
    float hL = blend_heightmaps(uv_clamped, amp, h1, h2, h3, h4, given_c1, given_c2, given_c3, given_c4);
	uv_clamped = clamp(vec2(uv.x + delta, uv.y), 0.0, 1.0);
    float hR = blend_heightmaps(uv_clamped, amp, h1, h2, h3, h4, given_c1, given_c2, given_c3, given_c4);
	uv_clamped = clamp(vec2(uv.x, uv.y - delta), 0.0, 1.0);
    float hD = blend_heightmaps(uv_clamped, amp, h1, h2, h3, h4, given_c1, given_c2, given_c3, given_c4);
	uv_clamped = clamp(vec2(uv.x, uv.y + delta), 0.0, 1.0);
    float hU = blend_heightmaps(uv_clamped, amp, h1, h2, h3, h4, given_c1, given_c2, given_c3, given_c4);

    float dx = hR - hL;
    float dy = hU - hD;

    vec3 normal = normalize(vec3(-dx, delta * 64.0, -dy));
    return normal;
}

void vertex() {
	float total = c1 + c2 + c3 + c4;
	if (total < 1.0) {
		total = 1.0;
	}
	c1_normalised = c1 / total;
	c2_normalised = c2 / total;
	c3_normalised = c3 / total;
	c4_normalised = c4 / total;

	vec2 uv = UV;
	if (perturbate) {
		uv *= 32.0;
		uv += 2.0 * perlin_2D(uv * 0.25);
		uv /= 32.0;
	}
	VERTEX.y += blend_heightmaps(uv, amplitude, heightmap1, heightmap2, heightmap3, heightmap4, c1_normalised, c2_normalised, c3_normalised, c4_normalised);
	//VERTEX.y -= amplitude * 0.5;
	NORMAL = get_normal(uv, amplitude, heightmap1, heightmap2, heightmap3, heightmap4, c1_normalised, c2_normalised, c3_normalised, c4_normalised);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = UV;
	if (perturbate) {
		uv *= 32.0;
		uv += 2.0 * perlin_2D(uv * 0.25);
		uv /= 32.0;
	}
	vec3 world_normal = get_normal(uv, amplitude, heightmap1, heightmap2, heightmap3, heightmap4, c1_normalised, c2_normalised, c3_normalised, c4_normalised);

	if (albedo_type == 0) {
		//vec2 texture_uv = fract(world_pos.xz);
		//texture_uv += 2.0 * perlin_2D(texture_uv * 0.25);
		float steepness = dot(world_normal, vec3(0.0, 1.0, 0.0));
		steepness *= steepness;
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
