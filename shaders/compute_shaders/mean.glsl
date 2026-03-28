#[compute]
#version 450
#extension GL_EXT_shader_atomic_float : require

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) uniform sampler2D heightmap;

layout(set = 0, binding = 1, std430) buffer TotalBuffer{
	float total;
}
total_buffer;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	//ivec2 size = textureSize(heightmap, 0);
	//if (uv.x >= size.x || uv.y >= size.y) return; // guard clause
	
	//atomicAdd(total_buffer.total, 1);
	//atomicAdd(total_buffer.total, int(texelFetch(heightmap, uv, 0).r * 128.0));
	atomicAdd(total_buffer.total, texelFetch(heightmap, uv, 0).r);
}
