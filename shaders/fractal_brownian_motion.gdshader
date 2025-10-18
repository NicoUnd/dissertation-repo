shader_type spatial;
render_mode depth_prepass_alpha;

// every terrain generation method shader parameters
uniform bool albedo_is_heightmap;

uniform bool circle;

uniform float seed: hint_range(1.0, 128.0, 0.1);

uniform sampler2D dirt_texture;
uniform sampler2D grass_texture;

// terrain generation method specific parameters
uniform float frequency: hint_range(1.0, 64.0);
uniform float ampltiude: hint_range(1.0, 64.0);

uniform int octaves: hint_range(1, 16);


// pseudo random number from a seed (uv)
//vec2 random(vec2 uv) {
	//uv = vec2(dot(uv, vec2(127.1, 311.7)),
	          //dot(uv, vec2(269.5, 183.3)));
	//return normalize(-1.0 + 2.0 * fract(sin(uv) * 43758.5453123));
//}

vec2 random(vec2 uv){
    uv = vec2( dot(uv, vec2(127.1 ,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123 * seed);
    //return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123 * (seed - TIME * 0.000001));
}

float perlin_2D(vec2 uv) {
	vec2 grid_index = floor(uv);
	vec2 grid_fract = fract(uv);

	vec2 BL = grid_index + vec2(0.0, 0.0);
	vec2 BR = grid_index + vec2(1.0, 0.0);
	vec2 TL = grid_index + vec2(0.0, 1.0);
	vec2 TR = grid_index + vec2(1.0, 1.0);

	vec2 grad_BL = random(BL);
	vec2 grad_BR = random(BR);
	vec2 grad_TL = random(TL);
	vec2 grad_TR = random(TR);

	vec2 offset_vector_BL = grid_fract - vec2(0.0, 0.0);
	vec2 offset_vector_BR = grid_fract - vec2(1.0, 0.0);
	vec2 offset_vector_TL = grid_fract - vec2(0.0, 1.0);
	vec2 offset_vector_TR = grid_fract - vec2(1.0, 1.0);

	float value_BL = dot(offset_vector_BL, grad_BL);
	float value_BR = dot(offset_vector_BR, grad_BR);
	float value_TL = dot(offset_vector_TL, grad_TL);
	float value_TR = dot(offset_vector_TR, grad_TR);

	vec2 smooth_factor = grid_fract * grid_fract * grid_fract *
            (grid_fract * (grid_fract * 6.0 - 15.0) + 10.0);

	float value_B = mix(value_BL, value_BR, smooth_factor.x);
	float value_T = mix(value_TL, value_TR, smooth_factor.x);

	float value = mix(value_B, value_T, smooth_factor.y);
	return (value + 1.0) * 0.5;
}

float fract_brownian_motion(vec2 uv, int given_octaves, float base_freq, float base_amp) {
	float total = 0.0;
	float freq = base_freq;
	float amp = base_amp;
	while (given_octaves > 0) {
		total += perlin_2D(uv / freq) * amp;
		freq /= 2.0;
		amp /= 2.0;
		given_octaves -= 1;
	}
	return total;
}

vec3 get_normal(vec2 uv, int given_octaves, float base_freq, float base_amp) {
	const float delta = 0.01;

    float hL = fract_brownian_motion(vec2(uv.x - delta, uv.y), given_octaves, base_freq, base_amp);
    float hR = fract_brownian_motion(vec2(uv.x + delta, uv.y), given_octaves, base_freq, base_amp);
    float hD = fract_brownian_motion(vec2(uv.x, uv.y - delta), given_octaves, base_freq, base_amp);
    float hU = fract_brownian_motion(vec2(uv.x, uv.y + delta), given_octaves, base_freq, base_amp);

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
	return max_height;
}

void vertex() {
	vec2 uv = VERTEX.xz;
	VERTEX.y += fract_brownian_motion(uv, octaves, frequency, ampltiude);
	VERTEX.y -= get_fract_brownian_motion_max_height(octaves, ampltiude) * 0.5;
	NORMAL = get_normal(uv, octaves, frequency, ampltiude);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 world_normal = get_normal(world_pos.xz, octaves, frequency, ampltiude);
	float upness = dot(world_normal, vec3(0.0, 1.0, 0.0));

	if (albedo_is_heightmap) {
		float max_height = get_fract_brownian_motion_max_height(octaves, ampltiude);
		ALBEDO = vec3(((world_pos.y + 0.25 * ampltiude) / max_height));
	} else {
		vec2 texture_uv = fract(world_pos.xz);
		ALBEDO = (upness * texture(grass_texture, texture_uv) + (1.0 - upness) * vec4(0.02, 0.02, 0.02, 1.0)).xyz;
	}
	if (circle) {
		ALPHA = 1.0 - smoothstep(512.0 + 256.0 + 128.0 + 64.0 + 32.0, 1024.0, world_pos.x * world_pos.x + world_pos.z * world_pos.z);
	}
}

//void light() {
	////vec3 N_world = get_normal(world_xz / frequency);
    ////vec3 N = normalize((VIEW_MATRIX * vec4(N_world, 0.0)).xyz);
	//vec3 N = NORMAL;
	//
    //vec3 L = LIGHT;
	//
	//// Lambertian diffuse term
    //float NdotL = max(dot(N, L), 0.0);
	//
	//// Combine with light color, attenuation, and material albedo
    //DIFFUSE_LIGHT += NdotL * ATTENUATION * LIGHT_COLOR * ALBEDO;
//}
