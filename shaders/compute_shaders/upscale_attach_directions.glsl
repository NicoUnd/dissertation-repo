#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float seed;
	float resolution;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer AttachDirectionsBuffer {
	int data[];
}
attach_directions_buffer;

layout(set = 0, binding = 2, std430) restrict buffer UpscaledAttachDirectionsBuffer {
	int data[];
}
upscaled_attach_directions_buffer;

float rand(ivec2 uv, float seed){ // random 0-1
	return fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 437.5453 * seed);
}

int uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) + uv.x);
}

int upscaled_uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) * 2 + uv.x);
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

int move_to_attach_direction(ivec2 move){
	if (move == ivec2(0, -1)) return 1;
	if (move == ivec2(1, 0)) return 2;
	if (move == ivec2(0, 1)) return 3;
	if (move == ivec2(-1, 0)) return 4;
	if (move == ivec2(1, -1)) return 5;
	if (move == ivec2(1, 1)) return 6;
	if (move == ivec2(-1, 1)) return 7;
	return 8; // move == ivec2(-1, -1)
}

ivec2 rotate90(ivec2 v) {
    return ivec2(-v.y, v.x);
}

ivec2 random_offset(ivec2 uv, float seed, int attach_direction) {
	ivec2 move = attach_direction_to_move(attach_direction);
	int offset_type = int(rand(uv, seed + 1.5721) * 3.0);
	if (attach_direction > 4 || offset_type == 0) return ivec2(0, 0); // don't offset diagonal attaches
	if (offset_type == 1) return rotate90(move);
	return -rotate90(move); // offset_type == 2
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int attach_direction = attach_directions_buffer.data[uv_to_linear(uv)];
	
	if (attach_direction == 0) return;
	
	float seed = parameter_buffer.seed;
	float resolution_float = parameter_buffer.resolution;
	int resolution = int(resolution_float);
	ivec2 upscaled_uv = uv * 2;
	
	ivec2 move = attach_direction_to_move(attach_direction);
	ivec2 offset = random_offset(uv, seed, attach_direction);
	ivec2 inbetween_pos = upscaled_uv + move;// + offset;
	
	//upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(upscaled_uv)] = move_to_attach_direction(move + offset);
	//upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(inbetween_pos)] = move_to_attach_direction(move - offset);
	upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(upscaled_uv)] = attach_direction;
	upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(inbetween_pos)] = attach_direction;
}