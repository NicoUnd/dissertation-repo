#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) uniform sampler2D heightmap;

layout(set = 0, binding = 1, std430) buffer MaxMinBuffer {
	int max;
	int min;
}
max_min_buffer;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int int_value = int(texture(heightmap, uv).r * 255.0);
	
	atomicMax(max_min_buffer.max, int_value);
	atomicMin(max_min_buffer.min, int_value);
}
