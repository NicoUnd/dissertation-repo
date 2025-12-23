#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 2, local_size_y = 2, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float seed;
	float resolution;
	float hops_to_live;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer AttachDirectionsBuffer {
	int data[];
}
attach_directions_buffer;

float rand_state = 1.0;
float next_rand(ivec2 uv, float seed){ // random 0-1 changes every call
	rand_state += 0.2;
	return fract(sin(dot(vec2(uv), vec2(12.9898 + rand_state * 2.31, 78.233 + rand_state * 0.813))) * 437.5453 * seed * rand_state);
}

int uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) + uv.x);
}

ivec2 attach_direction_to_move(int attach_direction){
	if (attach_direction == 1) return ivec2(0, -1);
	if (attach_direction == 2) return ivec2(1, 0);
	if (attach_direction == 3) return ivec2(0, 1);
	if (attach_direction == 4) return ivec2(-1, 0);
	if (attach_direction == 5) return ivec2(1, -1);
	if (attach_direction == 6) return ivec2(1, 1);
	if (attach_direction == 7) return ivec2(-1, 1);
	return ivec2(-1, -1); // attach_direction == 8
}

ivec2 next_rand_move(ivec2 uv, float seed){
	int attach_direction = int(next_rand(uv, seed) * 4.0) + 1; // cant move diagonal
	return attach_direction_to_move(attach_direction);
}

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.x, gl_GlobalInvocationID.y);
	float seed = parameter_buffer.seed;
	float resolution_float = parameter_buffer.resolution;
	int resolution = int(resolution_float);
	
	ivec2 pos = ivec2(int(next_rand(uv, seed) * (resolution_float)), int(next_rand(uv, seed) * (resolution_float)));
	int pos_linear = uv_to_linear(pos);
	if (attach_directions_buffer.data[pos_linear] != 0) return;
	
	//attach_directions_buffer.data[pos_linear] = int(next_rand(uv, seed) * 4.0);
	//return;
	
	int hops_to_live = int(parameter_buffer.hops_to_live);
	while (hops_to_live > 0) {
		if (attach_directions_buffer.data[uv_to_linear(ivec2(pos.x, max(0, pos.y - 1)))] != 0) {
			attach_directions_buffer.data[pos_linear] = 1;
			return;
		}
		if (attach_directions_buffer.data[uv_to_linear(ivec2(min(resolution - 1, pos.x + 1), pos.y))] != 0) {
			attach_directions_buffer.data[pos_linear] = 2;
			return;
		}
		if (attach_directions_buffer.data[uv_to_linear(ivec2(pos.x, min(resolution - 1, pos.y + 1)))] != 0) {
			attach_directions_buffer.data[pos_linear] = 3;
			return;
		}
		if (attach_directions_buffer.data[uv_to_linear(ivec2(max(0, pos.x - 1), pos.y))] != 0) {
			attach_directions_buffer.data[pos_linear] = 4;
			return;
		}
		
		pos = clamp(pos + next_rand_move(uv, seed), 0, resolution - 1);
		pos_linear = uv_to_linear(pos);
		hops_to_live -= 1;
	}
}