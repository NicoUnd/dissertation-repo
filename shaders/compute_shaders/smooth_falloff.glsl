#[compute]
#version 450
#extension GL_EXT_shader_atomic_float2 : require

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float resolution;
}
parameter_buffer;

layout(set = 0, binding = 2, std430) restrict buffer IntPointsBuffer {
	int data[];
}
int_points_buffer;

layout(set = 0, binding = 1, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

int uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) + uv.x);
}

float smooth_falloff(int x) {
	return 1.0 - 1.0 / float(1 + x);
}

// The code we want to execute in each invocation
void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	int pos_linear = uv_to_linear(pos);
	points_buffer.data[pos_linear] = smooth_falloff(int_points_buffer.data[pos_linear]);
}