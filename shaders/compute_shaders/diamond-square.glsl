#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float seed;
	float resolution;
	float step_size;
	float random_scale;
	float wrap_around;
	float distribution;
	float diamond_step;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

int uv_to_linear(ivec2 uv) {
	return (uv.y * (int(parameter_buffer.resolution) + 1) + uv.x);
}

float rand(ivec2 uv, float seed){ // random 0-1
	return fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 437.5453 * seed);
}

// Box-Muller transform
float rand_normal(ivec2 uv, float seed) { // normal random value with mean=0 and stddev=1
	float u1 = rand(uv, seed);
	float u2 = rand(uv + ivec2(1.3123, 42.145), seed); // small offset for another random number
	
	u1 = max(u1, 0.0001); // avoid log(0)
	float z = sqrt(-2.0 * log(u1)) * cos(6.2831853 * u2); // 2 pi = 6.2831853
	return z;
}

float random_offset() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	float random_scale = parameter_buffer.random_scale;
	if (parameter_buffer.distribution == 0) { // uniform
		return (rand(uv, parameter_buffer.seed) - 0.5) * random_scale;
	} else { // guassian
		return rand_normal(uv, parameter_buffer.seed) * 0.5 * random_scale; // base std dev is 0.5
	}
}

float get_square_average() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	
	float square_total = 0.0;
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, uv.y - half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, uv.y + half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, uv.y - half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, uv.y + half_step_size))];
	return square_total / 4.0;
}

float get_diamond_corner(ivec2 corner_uv) { // returns -1 if the corner is not used
	bool wrap_around = bool(parameter_buffer.wrap_around);
	int resolution = int(parameter_buffer.resolution);
	if (corner_uv.y > resolution || corner_uv.y < 0) {
		if (!wrap_around) {
			return -1.0;
		}
		corner_uv.y = corner_uv.y % (resolution + 1);
	}
	if (corner_uv.x > resolution || corner_uv.x < 0) {
		if (!wrap_around) {
			return -1.0;
		}
		corner_uv.x = corner_uv.x % (resolution + 1);
	}
	return points_buffer.data[uv_to_linear(corner_uv)];
}

float get_diamond_average() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	
	float diamond_total = 0.0;
	int corners_used = 0;
	float corner_value = get_diamond_corner(ivec2(uv.x, uv.y - half_step_size));
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x, uv.y + half_step_size));
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x - half_step_size, uv.y));
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x + half_step_size, uv.y));
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	return diamond_total / float(corners_used);
}

void diamond_step() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	if (uv.x % step_size == half_step_size && uv.y % step_size == half_step_size) {
		points_buffer.data[uv_to_linear(uv)] = clamp(get_square_average() + random_offset(), 0.0, 1.0);
	}
}

void square_step() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	if ((uv.x % step_size == half_step_size && uv.y % step_size == 0) || (uv.x % step_size == 0 && uv.y % step_size == half_step_size)) {
		points_buffer.data[uv_to_linear(uv)] = clamp(get_diamond_average() + random_offset(), 0.0, 1.0);
	}
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int resolution = int(parameter_buffer.resolution);
	
	if (uv.x <= resolution && uv.y <= resolution) {
		//float random_color = rand(uv, parameter_buffer.seed);
		//points_buffer.data[uv.y * (resolution + 1) + uv.x] += 0.3;
		if (bool(parameter_buffer.diamond_step)) {
			diamond_step();
		} else {
			square_step();
		}
	}
}
