#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float seed;
	float resolution;
	float step_size;
	float random_scale;
	float border_diamond_average_type; // 0: wrap_around, 1: ignore_inside, 2: ignore_outside, 3: chunked
	float distribution;
	float diamond_step;
	float chunk_coord_x;
	float chunk_coord_y;
}
parameter_buffer;

layout(set = 0, binding = 1, std430) restrict buffer PointsBuffer {
	float data[];
}
points_buffer;

layout(set = 0, binding = 2, std430) restrict buffer NA {float data[];} buffer_Na;
layout(set = 0, binding = 3, std430) restrict buffer NB {float data[];} buffer_Nb;
layout(set = 0, binding = 4, std430) restrict buffer NC {float data[];} buffer_Nc;
layout(set = 0, binding = 5, std430) restrict buffer EA {float data[];} buffer_Ea;
layout(set = 0, binding = 6, std430) restrict buffer EB {float data[];} buffer_Eb;
layout(set = 0, binding = 7, std430) restrict buffer EC {float data[];} buffer_Ec;
layout(set = 0, binding = 8, std430) restrict buffer SA {float data[];} buffer_Sa;
layout(set = 0, binding = 9, std430) restrict buffer SB {float data[];} buffer_Sb;
layout(set = 0, binding = 10, std430) restrict buffer SC {float data[];} buffer_Sc;
layout(set = 0, binding = 11, std430) restrict buffer WA {float data[];} buffer_Wa;
layout(set = 0, binding = 12, std430) restrict buffer WB {float data[];} buffer_Wb;
layout(set = 0, binding = 13, std430) restrict buffer WC {float data[];} buffer_Wc;


layout(set = 0, binding = 14, std430) restrict buffer CornerBuffer {float data[];}
corner_buffer; // 8 floats, first four for buffer a, last four for buffer b, going clockwise starting in NW


int uv_to_linear(ivec2 uv) {
	return (uv.y * (int(parameter_buffer.resolution) + 1) + uv.x);
}

float rand(ivec2 uv, float seed){ // random 0-1
	return fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 437.5453 * seed);
}


float world_pos_rand(ivec2 uv, float seed, ivec2 chunk_coord){ // random 0-1
	float resolution = parameter_buffer.resolution;
	vec2 world_pos = (vec2(uv) / resolution + vec2(chunk_coord)) * 4096.0; // to get distance for rand()
	return fract(sin(dot(world_pos, vec2(12.9898, 78.233))) * 437.5453 * seed);
	//return fract(sin(dot(vec2(uv), vec2(float(chunk_coord.x) * 621.421 + 12.9898, float(chunk_coord.y) * 125.1298 + 78.233))) * 437.5453 * seed);
}

// Box-Muller transform
float rand_normal(ivec2 uv, float seed) { // normal random value with mean=0 and stddev=1
	float u1 = rand(uv, seed);
	float u2 = rand(uv + ivec2(1.3123, 42.145), seed); // small offset for another random number
	
	u1 = max(u1, 0.0001); // avoid log(0)
	float z = sqrt(-2.0 * log(u1)) * cos(6.2831853 * u2); // 2 pi = 6.2831853
	return z;
}

float world_pos_rand_normal(ivec2 uv, float seed, ivec2 chunk_coord) { // normal random value with mean=0 and stddev=1
	float u1 = world_pos_rand(uv, seed, chunk_coord);
	float u2 = world_pos_rand(uv + ivec2(1.3123, 42.145), seed, chunk_coord); // small offset for another random number
	
	u1 = max(u1, 0.0001); // avoid log(0)
	float z = sqrt(-2.0 * log(u1)) * cos(6.2831853 * u2); // 2 pi = 6.2831853
	return z;
}

float random_offset(ivec2 uv, ivec2 chunk_coord, float random_scale) {
	if (parameter_buffer.distribution == 0) { // uniform
		return (world_pos_rand(uv, parameter_buffer.seed, chunk_coord) - 0.5) * random_scale;
	} else { // guassian
		return world_pos_rand_normal(uv, parameter_buffer.seed, chunk_coord) * 0.5 * random_scale; // base std dev is 0.5
	}
}

float get_square_average() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	
	float square_total = 0.0;
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, uv.y - half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, uv.y + half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, uv.y - half_step_size))];
	square_total += points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, uv.y + half_step_size))];
	return square_total / 4.0;
}

float chunk_sample_border_diamond_corner(ivec2 corner_uv, ivec2 uv) {
	int resolution = int(parameter_buffer.resolution);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	int step_resolution = resolution / half_step_size;
	
	float random_scale = parameter_buffer.random_scale;
	ivec2 chunk_coord = ivec2(int(parameter_buffer.chunk_coord_x), int(parameter_buffer.chunk_coord_y));
	
	// buffer c
	if (corner_uv.y < 0){ // N
		int c_index = (uv.x - half_step_size) / step_size;
		
		// buffer b
		for (int i = 0; i <= 1; i++){
			int b_index = c_index + i;
			if (buffer_Nb.data[b_index] == -1){ // unassigned
				// buffer a & corner buffer
				if (uv.x - half_step_size == 0){ // NW corner
					corner_buffer.data[4] = clamp(
							(corner_buffer.data[0]
							+ buffer_Na.data[0]
							+ buffer_Wa.data[0]
							+ points_buffer.data[uv_to_linear(ivec2(0, 0))]) / 4.0
							+ random_offset(ivec2(-step_size, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Nb.data[0] = clamp(
							(corner_buffer.data[4]
							+ buffer_Na.data[0]
							+ buffer_Nb.data[1]
							+ points_buffer.data[uv_to_linear(ivec2(0, 0))]) / 4.0
							+ random_offset(ivec2(0, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else if (uv.x + half_step_size == resolution){ // NE corner
					corner_buffer.data[5] = clamp(
							(corner_buffer.data[1]
							+ buffer_Na.data[step_resolution/4]
							+ buffer_Ea.data[0]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, 0))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Nb.data[step_resolution/2] = clamp(
							(corner_buffer.data[5]
							+ buffer_Na.data[step_resolution/4]
							+ buffer_Nb.data[step_resolution/2 - 1]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, 0))]) / 4.0
							+ random_offset(ivec2(resolution, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else { // general N b buffer point
					buffer_Nb.data[b_index] = clamp(
							(buffer_Na.data[b_index/2]
							+ buffer_Nb.data[b_index - 1]
							+ buffer_Nb.data[b_index + 1]
							+ points_buffer.data[uv_to_linear(ivec2(b_index * step_size, 0))]) / 4.0
							+ random_offset(ivec2(b_index * step_size, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				}
			}
		}
		
		buffer_Nc.data[c_index] = clamp(
				(buffer_Nb.data[c_index]
				+ buffer_Nb.data[c_index + 1]
				+ points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, 0))]
				+ points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, 0))]) / 4.0
				+ random_offset(corner_uv, chunk_coord, random_scale)
		, 0.0, 1.0);
		return buffer_Nc.data[c_index];
	} else if (corner_uv.x > resolution){ // E
		int c_index = (uv.y - half_step_size) / step_size;
		
		// buffer b
		for (int i = 0; i <= 1; i++){
			int b_index = c_index + i;
			if (buffer_Eb.data[b_index] == -1){ // unassigned
				// buffer a & corner buffer
				if (uv.y - half_step_size == 0){ // NE corner
					corner_buffer.data[5] = clamp(
							(corner_buffer.data[1]
							+ buffer_Na.data[step_resolution/4]
							+ buffer_Ea.data[0]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, 0))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Eb.data[0] = clamp(
							(corner_buffer.data[5]
							+ buffer_Ea.data[0]
							+ buffer_Eb.data[1]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, 0))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, 0), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else if (uv.y + half_step_size == resolution){ // SE corner
					corner_buffer.data[6] = clamp(
							(corner_buffer.data[2]
							+ buffer_Sa.data[step_resolution/4]
							+ buffer_Ea.data[step_resolution/4]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, resolution))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Eb.data[step_resolution/2] = clamp(
							(corner_buffer.data[6]
							+ buffer_Ea.data[step_resolution/4]
							+ buffer_Eb.data[step_resolution/2 - 1]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, resolution))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, resolution), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else { // general E b buffer point
					buffer_Eb.data[b_index] = clamp(
							(buffer_Ea.data[b_index/2]
							+ buffer_Eb.data[b_index - 1]
							+ buffer_Eb.data[b_index + 1]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, b_index * step_size))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, b_index * step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				}
			}
		}
		
		buffer_Ec.data[c_index] = clamp(
				(buffer_Eb.data[c_index]
				+ buffer_Eb.data[c_index + 1]
				+ points_buffer.data[uv_to_linear(ivec2(resolution, uv.y - half_step_size))]
				+ points_buffer.data[uv_to_linear(ivec2(resolution, uv.y + half_step_size))]) / 4.0
				+ random_offset(corner_uv, chunk_coord, random_scale)
		, 0.0, 1.0);
		return buffer_Ec.data[c_index];
	} else if (corner_uv.y > resolution){ // S
		int c_index = (uv.x - half_step_size) / step_size;
		
		// buffer b
		for (int i = 0; i <= 1; i++){
			int b_index = c_index + i;
			if (buffer_Sb.data[b_index] == -1){ // unassigned
				// buffer a & corner buffer
				if (uv.x - half_step_size == 0){ // SW corner
					corner_buffer.data[7] = clamp(
							(corner_buffer.data[3]
							+ buffer_Sa.data[0]
							+ buffer_Wa.data[step_resolution/4]
							+ points_buffer.data[uv_to_linear(ivec2(0, resolution))]) / 4.0
							+ random_offset(ivec2(-step_size, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Sb.data[0] = clamp(
							(corner_buffer.data[7]
							+ buffer_Sa.data[0]
							+ buffer_Sb.data[1]
							+ points_buffer.data[uv_to_linear(ivec2(0, resolution))]) / 4.0
							+ random_offset(ivec2(0, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else if (uv.x + half_step_size == resolution){ // SE corner
					corner_buffer.data[6] = clamp(
							(corner_buffer.data[2]
							+ buffer_Sa.data[step_resolution/4]
							+ buffer_Ea.data[step_resolution/4]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, resolution))]) / 4.0
							+ random_offset(ivec2(resolution + step_size, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Sb.data[step_resolution/2] = clamp(
							(corner_buffer.data[6]
							+ buffer_Sa.data[step_resolution/4]
							+ buffer_Sb.data[step_resolution/2 - 1]
							+ points_buffer.data[uv_to_linear(ivec2(resolution, resolution))]) / 4.0
							+ random_offset(ivec2(resolution, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else { // general S b buffer point
					buffer_Sb.data[b_index] = clamp(
							(buffer_Sa.data[b_index/2]
							+ buffer_Sb.data[b_index - 1]
							+ buffer_Sb.data[b_index + 1]
							+ points_buffer.data[uv_to_linear(ivec2(b_index * step_size, resolution))]) / 4.0
							+ random_offset(ivec2(b_index * step_size, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				}
			}
		}
		
		buffer_Sc.data[c_index] = clamp(
				(buffer_Sb.data[c_index]
				+ buffer_Sb.data[c_index + 1]
				+ points_buffer.data[uv_to_linear(ivec2(uv.x - half_step_size, resolution))]
				+ points_buffer.data[uv_to_linear(ivec2(uv.x + half_step_size, resolution))]) / 4.0
				+ random_offset(corner_uv, chunk_coord, random_scale)
		, 0.0, 1.0);
		return buffer_Sc.data[c_index];
	} else if (corner_uv.x < 0){ // W
		int c_index = (uv.y - half_step_size) / step_size;
		
		// buffer b
		for (int i = 0; i <= 1; i++){
			int b_index = c_index + i;
			if (buffer_Wb.data[b_index] == -1){ // unassigned
				// buffer a & corner buffer
				if (uv.y - half_step_size == 0){ // NW corner
					corner_buffer.data[4] = clamp(
							(corner_buffer.data[0]
							+ buffer_Na.data[0]
							+ buffer_Wa.data[0]
							+ points_buffer.data[uv_to_linear(ivec2(0, 0))]) / 4.0
							+ random_offset(ivec2(-step_size, -step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Wb.data[0] = clamp(
							(corner_buffer.data[4]
							+ buffer_Wa.data[0]
							+ buffer_Wb.data[1]
							+ points_buffer.data[uv_to_linear(ivec2(0, 0))]) / 4.0
							+ random_offset(ivec2(-step_size, 0), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else if (uv.y + half_step_size == resolution){ // SW corner
					corner_buffer.data[7] = clamp(
							(corner_buffer.data[3]
							+ buffer_Sa.data[0]
							+ buffer_Wa.data[step_resolution/4]
							+ points_buffer.data[uv_to_linear(ivec2(0, resolution))]) / 4.0
							+ random_offset(ivec2(-step_size, resolution + step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
					
					buffer_Wb.data[step_resolution/2] = clamp(
							(corner_buffer.data[7]
							+ buffer_Wa.data[step_resolution/4]
							+ buffer_Wb.data[step_resolution/2 - 1]
							+ points_buffer.data[uv_to_linear(ivec2(0, resolution))]) / 4.0
							+ random_offset(ivec2(-step_size, resolution), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				} else { // general W b buffer point
					buffer_Wb.data[b_index] = clamp(
							(buffer_Wa.data[b_index/2]
							+ buffer_Wb.data[b_index - 1]
							+ buffer_Wb.data[b_index + 1]
							+ points_buffer.data[uv_to_linear(ivec2(0, b_index * step_size))]) / 4.0
							+ random_offset(ivec2(-step_size, b_index * step_size), chunk_coord, random_scale * 2.)
					, 0.0, 1.0);
				}
			}
		}
		
		buffer_Wc.data[c_index] = clamp(
				(buffer_Wb.data[c_index]
				+ buffer_Wb.data[c_index + 1]
				+ points_buffer.data[uv_to_linear(ivec2(0, uv.y - half_step_size))]
				+ points_buffer.data[uv_to_linear(ivec2(0, uv.y + half_step_size))]) / 4.0
				+ random_offset(corner_uv, chunk_coord, random_scale)
		, 0.0, 1.0);
		return buffer_Wc.data[c_index];
	}
}

float get_diamond_corner(ivec2 corner_uv, ivec2 uv) { // returns -1 if the corner is not used
	int border_diamond_average_type = int(parameter_buffer.border_diamond_average_type);
	int resolution = int(parameter_buffer.resolution);
	
	if (border_diamond_average_type == 3 && (corner_uv.y < 0 || corner_uv.y > resolution || corner_uv.x < 0 || corner_uv.x > resolution)) { // chunked and on border
		return chunk_sample_border_diamond_corner(corner_uv, uv);
	}
	
	if ((border_diamond_average_type == 2 && corner_uv.y != uv.y && (uv.y == 0 || uv.y == resolution)) || (border_diamond_average_type == 1 && (corner_uv.y > resolution || corner_uv.y < 0))) {
		return -1.0;
	}
	if (corner_uv.y > resolution) corner_uv.y -= (resolution + 1);
	if (corner_uv.y < 0) corner_uv.y += (resolution + 1);
	if ((border_diamond_average_type == 2 && corner_uv.x != uv.x && (uv.x == 0 || uv.x == resolution)) || (border_diamond_average_type == 1 && (corner_uv.x > resolution || corner_uv.x < 0))) {
		return -1.0;
	}
	if (corner_uv.x > resolution) corner_uv.x -= (resolution + 1);
	if (corner_uv.x < 0) corner_uv.x += (resolution + 1);
	return points_buffer.data[uv_to_linear(corner_uv)];
}

float get_diamond_average() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	
	float diamond_total = 0.0;
	int corners_used = 0;
	float corner_value = get_diamond_corner(ivec2(uv.x, uv.y - half_step_size), uv);
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x, uv.y + half_step_size), uv);
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x - half_step_size, uv.y), uv);
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	corner_value = get_diamond_corner(ivec2(uv.x + half_step_size, uv.y), uv);
	if (corner_value != -1.0) {
		diamond_total += corner_value;
		corners_used += 1;
	}
	return diamond_total / float(corners_used);
}

void diamond_step() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;

	float random_scale = parameter_buffer.random_scale;
	ivec2 chunk_coord = ivec2(int(parameter_buffer.chunk_coord_x), int(parameter_buffer.chunk_coord_y));

	if (uv.x % step_size == half_step_size && uv.y % step_size == half_step_size) {
		points_buffer.data[uv_to_linear(uv)] = clamp(get_square_average() + random_offset(uv, chunk_coord, random_scale), 0.0, 1.0);
	}
}

void square_step() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	int step_size = int(parameter_buffer.step_size);
	int half_step_size = step_size / 2;
	
	float random_scale = parameter_buffer.random_scale;
	ivec2 chunk_coord = ivec2(int(parameter_buffer.chunk_coord_x), int(parameter_buffer.chunk_coord_y));
	
	if ((uv.x % step_size == half_step_size && uv.y % step_size == 0) || (uv.x % step_size == 0 && uv.y % step_size == half_step_size)) {
		points_buffer.data[uv_to_linear(uv)] = clamp(get_diamond_average() + random_offset(uv, chunk_coord, random_scale), 0.0, 1.0);
	}
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int resolution = int(parameter_buffer.resolution);
	
	if (uv.x <= resolution && uv.y <= resolution) {
		//float random_color = rand(uv, parameter_buffer.seed);
		//points_buffer.data[uv.y * (resolution + 1) + uv.x] += 0.3;
		if (bool(parameter_buffer.diamond_step)) {
			diamond_step();
		} else {
			square_step();
		}
	}
}
