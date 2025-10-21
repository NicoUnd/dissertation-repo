shader_type spatial;
render_mode depth_prepass_alpha;

// every terrain generation method shader parameters
uniform int albedo_type;

uniform bool circle;

uniform float seed: hint_range(1.0, 64.0, 0.1);

uniform sampler2D dirt_texture;
uniform sampler2D grass_texture;

// terrain generation method specific parameters
uniform float period: hint_range(1.0, 64.0);
uniform float amplitude: hint_range(1.0, 64.0);

uniform int octaves: hint_range(1, 16);

uniform int value_type;


// pseudo random number from a seed (uv)
//vec2 random(vec2 uv) {
	//uv = vec2(dot(uv, vec2(127.1, 311.7)),
	          //dot(uv, vec2(269.5, 183.3)));
	//return normalize(-1.0 + 2.0 * fract(sin(uv) * 43758.5453123));
//}

vec2 random(vec2 uv){
	uv += vec2(seed * 124.231, seed * 74.512);
    uv = vec2( dot(uv, vec2(127.1 ,311.7) ),
               dot(uv, vec2(269.5,183.3) ) );
	return -1.0 + 2.0 * fract(sin(uv) * 43758.5453123);
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
	return value;
}

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
	vec3 world_normal = get_normal(world_pos.xz, octaves, period, amplitude);
	
	if (albedo_type == 0) {
		vec2 texture_uv = fract(world_pos.xz);
		float steepness = dot(world_normal, vec3(0.0, 1.0, 0.0));
		ALBEDO = (steepness * vec4(0.2, 0.25, 0.2, 1.0) + (1.0 - steepness) * vec4(0.05, 0.05, 0.05, 1.0)).xyz;
	} else {
		if (albedo_type == 1) {
			float max_height = get_fract_brownian_motion_max_height(octaves, amplitude);
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
