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
	return ivec2(-1, 0); // attach_direction == 4
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
	
	upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(upscaled_uv)] = attach_direction;
	upscaled_attach_directions_buffer.data[upscaled_uv_to_linear(upscaled_uv + attach_direction_to_move(attach_direction))] = attach_direction;
}