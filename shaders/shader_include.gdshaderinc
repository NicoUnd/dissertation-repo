// every terrain generation method shader parameters
uniform float seed: hint_range(1.0, 64.0, 0.1);

uniform int albedo_type;

uniform bool circle;

uniform bool perturbate;


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