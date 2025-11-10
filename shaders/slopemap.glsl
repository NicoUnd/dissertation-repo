#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0) uniform sampler2D heightmap;

layout(set = 0, binding = 1, r32f) writeonly uniform image2D slopemap;

layout(set = 0, binding = 2, std430) buffer ResolutionBuffer {
	int resolution;
}
resolution_buffer;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int resolution = resolution_buffer.resolution;
	float value = texture(heightmap, uv).r;
	imageStore(slopemap, uv, vec4(
		max(abs(value - texture(heightmap, ivec2(uv.x, (uv.y + 1) % resolution)).r),
		max(abs(value - texture(heightmap, ivec2(uv.x, (uv.y - 1) % resolution)).r),
		max(abs(value - texture(heightmap, ivec2((uv.x + 1) % resolution, uv.y)).r),
		abs(value - texture(heightmap, ivec2((uv.x - 1) % resolution, uv.y)).r)))),
	0.0, 0.0, 0.0));
}
