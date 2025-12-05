#[compute]
#version 450
#extension GL_EXT_shader_atomic_float2 : require

// Invocations in the (x, y, z) dimension
layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float resolution;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer IntPointsBuffer {
	int data[];
}
int_points_buffer;

layout(set = 0, binding = 2, std430) restrict buffer PointsBuffer {
	int data[];
}
points_buffer;

int uv_to_linear(ivec2 uv) {
	return (uv.y * int(parameter_buffer.resolution) + uv.x);
}

ivec2 attach_direction_to_move(int attach_direction){
	if (attach_direction == 1) return ivec2(0, -1);
	if (attach_direction == 2) return ivec2(1, 0);
	if (attach_direction == 3) return ivec2(0, 1);
	return ivec2(-1, 0); // attach_direction == 4
}

// The code we want to execute in each invocation
void main() {
	ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
	int pos_linear = uv_to_linear(pos);
	int attach_direction = attach_directions_buffer.data[pos_linear];
	if (attach_direction != 0) {
		atomicMax(points_buffer.data[pos_linear], 1);
		return;
		
		int resolution = int(parameter_buffer.resolution);
		
		int step = 1;
		ivec2 centre = ivec2(resolution / 2, resolution / 2);
		return;
		while (pos != centre && step < 10) {
			// move
			pos += attach_direction_to_move(attach_directions_buffer.data[pos_linear]);
			pos_linear = uv_to_linear(pos);
			step += 1;
			
			// set_smooth_falloff
			atomicMax(points_buffer.data[pos_linear], step);
		}
	}
}