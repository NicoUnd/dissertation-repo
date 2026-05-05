#[compute]
#version 450
#extension GL_EXT_shader_atomic_float : require

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) uniform sampler2D heightmap;

layout(set = 0, binding = 1, std430) buffer HistogramBuffer {
	float data[];
}
histogram_buffer;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int int_value = int(texelFetch(heightmap, uv, 0).r * 2048.0);
	//int_value += 8;
	int_value = clamp(int_value, 0, 63);
	
	atomicAdd(histogram_buffer.data[int_value], 1.0);
}
