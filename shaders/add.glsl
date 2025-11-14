#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer PointBuffer1{
	float data[];
}
points_buffer_1;

layout(set = 0, binding = 1, std430) restrict buffer PointBuffer2{
	float data[];
}
points_buffer_2;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	uint index = gl_GlobalInvocationID.x;

	points_buffer_1.data[index] += points_buffer_2.data[index];
}
