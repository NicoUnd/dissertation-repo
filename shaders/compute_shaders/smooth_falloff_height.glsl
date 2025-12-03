#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer AttachDirectionsBuffer {
	vec2 data[];
}
attach_directions_buffer;

layout(set = 0, binding = 1, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

int sum(int n) {
	return 1 + sum(n-1);
}

// The code we want to execute in each invocation
void main() {
	
}