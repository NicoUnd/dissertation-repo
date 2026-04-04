#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba16f) uniform image2D rg16;

layout(set = 0, binding = 1, r32f) restrict writeonly uniform image2D r32;

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int resolution = imageSize(r32).x;
	
	vec4 rg16_color = imageLoad(rg16, uv);
	
	float decoded = rg16_color.r + rg16_color.g / 65535.0;
	
	imageStore(r32, uv, vec4(decoded, 0.0, 0.0, 0.0));
}
