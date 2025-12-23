#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float resolution;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

layout(set = 0, binding = 2, std430) restrict buffer UpscaledPointsBuffer {
	float data[];
}
upscaled_points_buffer;

int uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) + uv.x);
}

int upscaled_uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) * 2 + uv.x);
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 upscaled_uv = ivec2(gl_GlobalInvocationID.xy);
	
	vec2 uv = (vec2(upscaled_uv) + 0.5) * 0.5 - 0.5;
	int resolution = int(parameter_buffer.resolution);
	
	ivec2 p0 = ivec2(floor(uv));
	ivec2 p1 = p0 + ivec2(1, 0);
	ivec2 p2 = p0 + ivec2(0, 1);
	ivec2 p3 = p0 + ivec2(1, 1);
	
	p0 = clamp(p0, 0, resolution - 1);
	p1 = clamp(p1, 0, resolution - 1);
	p2 = clamp(p2, 0, resolution - 1);
	p3 = clamp(p3, 0, resolution - 1);
	
	float v0 = points_buffer.data[uv_to_linear(p0)];
	float v1 = points_buffer.data[uv_to_linear(p1)];
	float v2 = points_buffer.data[uv_to_linear(p2)];
	float v3 = points_buffer.data[uv_to_linear(p3)];
	
	vec2 frac = fract(uv);
	float dx = frac.x;
	float dy = frac.y;
	
	upscaled_points.data[upscaled_uv] = mix(mix(v0, v1, dx), mix(v2, v3, dx), dy);
}