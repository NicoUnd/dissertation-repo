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

layout(set = 0, binding = 2, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

int uv_to_linear(ivec2 uv) {
	return (uv.y * (int(parameter_buffer.resolution) + 1) + uv.x);
}

// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int index = uv_to_linear(uv);
	if (attach_directions_buffer[index] != 0) points_buffer[index] = 1.0;
}