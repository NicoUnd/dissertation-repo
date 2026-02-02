#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// A binding to the buffer we create in our script
layout(set = 0, binding = 0, std430) restrict buffer Parameters {
	float seed;
	float time_to_live;
	float inertia;
	float min_slope;
	float base_capacity;
	float deposition_rate;
	float erosion_rate;
	float gravity;
	float evaporation_rate;
	float radius;
}
parameter_buffer;

// A binding to the buffer we create in our script
layout(set = 0, binding = 1, r32f) uniform image2D heightmap;

float rand(ivec2 uv, float seed){ // random 0-1
	return fract(sin(dot(vec2(uv), vec2(12.9898, 78.233))) * 437.5453 * seed);
}

vec2 bilinear_gradient(vec2 pos) {
	int x_int = int(pos.x);
	int y_int = int(pos.y);
	ivec2 uv = ivec2(x_int, y_int);
	float x_fract = fract(pos.x);
	float y_fract = fract(pos.y);
	
	float bottom_left = imageLoad(heightmap, uv).r;
	float bottom_right = imageLoad(heightmap, uv + ivec2(1, 0)).r;
	float top_left = imageLoad(heightmap, uv + ivec2(0, 1)).r;
	float top_right = imageLoad(heightmap, uv + ivec2(1, 1)).r;
	
	vec2 grad = vec2((bottom_right - bottom_left) * (1.0 - y_fract) + (top_right - top_left) * y_fract,
		(top_left - bottom_left) * (1.0 - x_fract) + (top_right - bottom_right) * x_fract);
	return grad;
}

float bilinear_height(vec2 pos) {
	int x_int = int(pos.x);
	int y_int = int(pos.y);
	ivec2 uv = ivec2(x_int, y_int);
	float x_fract = fract(pos.x);
	float y_fract = fract(pos.y);
	
	float bottom_left = imageLoad(heightmap, uv).r;
	float bottom_right = imageLoad(heightmap, uv + ivec2(1, 0)).r;
	float top_left = imageLoad(heightmap, uv + ivec2(0, 1)).r;
	float top_right = imageLoad(heightmap, uv + ivec2(1, 1)).r;
	
	float bottom = mix(bottom_left, bottom_right, x_fract);
	float top = mix(top_left, top_right, x_fract);
	float height = mix(bottom, top, y_fract);
	return height;
}

void bilinear_deposit(vec2 pos, float amount) {
	int x_int = int(pos.x);
	int y_int = int(pos.y);
	ivec2 uv = ivec2(x_int, y_int);
	float x_fract = fract(pos.x);
	float y_fract = fract(pos.y);
	
	float weight_bottom_left = (1.0 - x_fract) * (1.0 - y_fract);
	float weight_bottom_right = x_fract * (1.0 - y_fract);
	float weight_top_left = (1.0 - x_fract) * y_fract;
	float weight_top_right = x_fract * y_fract;
	
	float bottom_left = imageLoad(heightmap, uv).r;
	float bottom_right = imageLoad(heightmap, uv + ivec2(1, 0)).r;
	float top_left = imageLoad(heightmap, uv + ivec2(0, 1)).r;
	float top_right = imageLoad(heightmap, uv + ivec2(1, 1)).r;
	
	imageStore(heightmap, uv, vec4(bottom_left + amount * weight_bottom_left));
	imageStore(heightmap, uv + ivec2(1, 0), vec4(bottom_right + amount * weight_bottom_right));
	imageStore(heightmap, uv + ivec2(0, 1), vec4(top_left + amount * weight_top_left));
	imageStore(heightmap, uv + ivec2(1, 1), vec4(top_right + amount * weight_top_right));
}

void erode_radius(vec2 pos, float amount) {
	float erosion_rate = parameter_buffer.erosion_rate;
	float radius = parameter_buffer.radius;
	int radius_int = int(ceil(radius));
	int resolution = imageSize(heightmap).x;
	
	float weight_total = 0.0;
	for (int dy = -radius_int; dy <= radius_int; dy++) {
		for (int dx = -radius_int; dx <= radius_int; dx++) {
			ivec2 grid_pos = ivec2(pos + vec2(0.5)) + ivec2(dx, dy);
			if (grid_pos.x < 0 || grid_pos.x >= resolution || grid_pos.y < 0 || grid_pos.y >= resolution) continue;
			float dist = length(vec2(grid_pos) - pos);
			float weight = max(0.0, radius - dist);
			weight_total += weight;
		}
	}
	for (int dy = -radius_int; dy <= radius_int; dy++) {
		for (int dx = -radius_int; dx <= radius_int; dx++) {
			ivec2 grid_pos = ivec2(pos + vec2(0.5)) + ivec2(dx, dy);
			if (grid_pos.x < 0 || grid_pos.x >= resolution || grid_pos.y < 0 || grid_pos.y >= resolution) continue;
			float dist = length(vec2(grid_pos) - pos);
			float weight = max(0.0, radius - dist);
			if (weight <= 0.0) continue;
			weight /= weight_total;
			float height = imageLoad(heightmap, grid_pos).r;
			imageStore(heightmap, grid_pos, vec4(max(height - weight * amount, 0.0)));
		}
	}
}

// The code we want to execute in each invocation
void main() {
	// gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	
	int resolution = imageSize(heightmap).x;
	float seed = parameter_buffer.seed;
	vec2 pos = vec2(rand(uv, seed), rand(uv, seed + 41.124)) * float(resolution);
	
	vec2 dir = vec2(0.0);
	float speed = 0.0;
	float water = 0.0;
	float sediment = 0.0;
	float inertia = parameter_buffer.inertia;
	float min_slope = parameter_buffer.min_slope;
	float base_capacity = parameter_buffer.base_capacity;
	float deposition_rate = parameter_buffer.deposition_rate;
	float erosion_rate = parameter_buffer.erosion_rate;
	float gravity = parameter_buffer.gravity;
	float evaporation_rate = parameter_buffer.evaporation_rate;
	
	int time_to_live = int(parameter_buffer.time_to_live);
	while (time_to_live > 0) {
		if (pos.x < 0 || pos.x >= float(resolution - 1) || pos.y < 0 || pos.y >= float(resolution - 1)) return;
		
		dir = dir * inertia - bilinear_gradient(pos) * (1.0 - inertia);
		if (length(dir) < 0.0001) {
			float rand_angle = rand(ivec2(pos + vec2(5.1231, 19.231)) + ivec2(time_to_live), seed) * 6.2831853;
			dir = vec2(cos(rand_angle), sin(rand_angle));
		}
		dir = normalize(dir);
		
		vec2 pos_new = pos + dir;
		if (pos_new.x < 0 || pos_new.x >= float(resolution - 1) || pos_new.y < 0 || pos_new.y >= float(resolution - 1)) return;
		
		float height_delta = bilinear_height(pos_new) - bilinear_height(pos);
		
		if (height_delta > 0) { // uphill
			float amount_to_deposit = min(height_delta, sediment);
			bilinear_deposit(pos, amount_to_deposit);
			sediment -= amount_to_deposit;
		} else { // downhill
			float capacity = max(-height_delta, min_slope) * speed * water * base_capacity;
			if (sediment > capacity) {
				float amount_to_deposit = (sediment - capacity) * deposition_rate;
				bilinear_deposit(pos, amount_to_deposit);
				sediment -= amount_to_deposit;
			} else {
				float amount_to_erode = min((capacity - sediment) * erosion_rate, -height_delta);
				erode_radius(pos, amount_to_erode);
				sediment += amount_to_erode;
			}
		}
		
		speed = sqrt(speed * speed + height_delta * gravity);
		
		water *= (1.0 - evaporation_rate);
		
		pos = pos_new;
		time_to_live -= 1;
	}
}
