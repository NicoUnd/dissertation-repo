@tool
extends TerrainGenerationMethodExplicit;
class_name DiamondSquare;

var smoothness: float;

var distribution: int;

var diamond_average_type: int;

var normalise: bool;

var compute_shader;

func get_square_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var square_average: float = 0;
	for square_corner_y: int in [y - half_step_size, y + half_step_size]:
		for square_corner_x: int in [x - half_step_size, x + half_step_size]:
			square_average += points[square_corner_y][square_corner_x] / 4;
			#if points[square_corner_y][square_corner_x] == 0:
			#	breakpoint;
	return square_average;

func get_diamond_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int, resolution: int) -> float:
	var diamond_total: float = 0;
	var num_of_corners_used: int = 0;
	for diamond_corner_y: int in [y - half_step_size, y + half_step_size]:
		if (diamond_average_type == 2 and y in [0, resolution]) or (diamond_average_type in [1, 2] and (diamond_corner_y < 0 or diamond_corner_y > resolution)):
			continue;
		if diamond_corner_y < 0:
			diamond_corner_y += resolution + 1;
		elif diamond_corner_y > resolution:
			diamond_corner_y -= resolution + 1;
		# diamond_corner_y = posmod(diamond_corner_y, resolution + 1);
		diamond_total += points[diamond_corner_y][x];
		num_of_corners_used += 1;
	for diamond_corner_x: int in [x - half_step_size, x + half_step_size]:
		if (diamond_average_type == 2 and x in [0, resolution]) or (diamond_average_type in [1, 2] and (diamond_corner_x < 0 or diamond_corner_x > resolution)):
			continue;
		if diamond_corner_x < 0:
			diamond_corner_x += resolution + 1;
		elif diamond_corner_x > resolution:
			diamond_corner_x -= resolution + 1;
		# diamond_corner_x = posmod(diamond_corner_x, resolution + 1);
		diamond_total += points[y][diamond_corner_x];
		num_of_corners_used += 1;
	
	assert(num_of_corners_used in [2, 3, 4]);
	return diamond_total / num_of_corners_used;

func random_offset(random_number_generator: RandomNumberGenerator, random_scale: float) -> float:
	if distribution == 0: # uniform
		return random_number_generator.randf_range(-0.5, 0.5) * random_scale
	else: # guassian
		return random_number_generator.randfn(0, 0.5 * random_scale);

func world_pos_random_offset(world_pos: Vector2, random_scale: float) -> float:
	if distribution == 0: # uniform
		#print("world_pos_random_offset returning: " + str((world_pos_randf(seed, world_pos) - 0.5) * random_scale));
		return (world_pos_randf(seed, world_pos) - 0.5) * random_scale;
	else: # guassian
		return world_pos_randfn(seed, world_pos, 0, 0.5 * random_scale);

func setup(rendering_device: RenderingDevice) -> void:
	#rendering_device = RenderingServer.create_local_rendering_device();
	
	var shader_file := load("res://shaders/compute_shaders/diamond-square.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());

func setdown(rendering_device: RenderingDevice) -> void:
	rendering_device.free_rid(compute_shader);
	#rendering_device.free();

static func uv_to_world_pos(resolution: int, chunk_coord: Vector2i, uv: Vector2i) -> Vector2:
	return (Vector2(uv) / float(resolution) + Vector2(chunk_coord)) * 4096; # * 4096 to avoid floating point errors

static func world_pos_randf(seed: float, world_pos: Vector2i) -> float:
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed + hash(world_pos));
	return random_number_generator.randf();

static func world_pos_randfn(seed: float, world_pos: Vector2i, mean: float, std_dev: float) -> float:
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed + hash(world_pos));
	return random_number_generator.randfn(mean, std_dev);

func generate_CPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image:
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution + 1);
	for row_index: int in resolution + 1:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution + 1);
		points[row_index] = row;
	
	#var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	#random_number_generator.seed = hash(seed);
	
	#points[0][0] = random_number_generator.randf();
	#points[0][resolution] = random_number_generator.randf();
	#points[resolution][0] = random_number_generator.randf();
	#points[resolution][resolution] = random_number_generator.randf();
	
	#print("GENERATING DIAMOND SQUARE")
	points[0][0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ZERO));
	#print(points[0][0]);
	points[resolution][0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.DOWN * resolution));
	#print(points[0][resolution]);
	points[0][resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.RIGHT * resolution));
	#print(points[resolution][0]);
	points[resolution][resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ONE * resolution));
	#print(points[resolution][resolution]);
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		@warning_ignore("integer_division")
		var half_step_size: int = step_size / 2;
		
		# diamond step
		var diamond_indecies: Array = range(half_step_size, resolution + 1, step_size);
		for y: int in diamond_indecies:
			for x: int in diamond_indecies:
				points[y][x] = clamp(get_square_average(points, x, y, half_step_size) + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale), 0, 1); # world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale)
				#print("square_avg: " + str(points[y][x]))
		
		# square step
		for y: int in range(0, resolution + 1, half_step_size):
			for x: int in range(posmod(y + half_step_size, step_size), resolution + 1, step_size):
				#print(Vector2i(x, y));
				#if Vector2i(x, y) == Vector2i(resolution/2, 0) and chunk_coord == Vector2i(0, 1):
					#print("res/2, 0:")
					#breakpoint;
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
				#if Vector2i(x, y) == Vector2i(resolution/2, resolution) and chunk_coord == Vector2i.ZERO:
					#print("res/2, res:")
					#breakpoint;
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
				points[y][x] = clamp(get_diamond_average(points, x, y, half_step_size, resolution) + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale), 0, 1); # world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale)
				#print("diamond_avg: " + str(points[y][x]))
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	#var world_pos: Vector2;
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(0, resolution/2));
	#print(str(world_pos) + ": " + str(points[resolution/2][0]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, resolution/2));
	#print(str(world_pos) + ": " + str(points[resolution/2][resolution]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, 0));
	#print(str(world_pos) + ": " + str(points[0][resolution/2]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, resolution));
	#print(str(world_pos) + ": " + str(points[resolution][resolution/2]));
	#
	#print("CHUNK COORD: " + str(chunk_coord))
	#if chunk_coord == Vector2i.ZERO:
		#print("BOTTOM ROW OF TOP LEFT")
		#print(points[resolution][resolution/2]);
	#else:
		#print(points[0][resolution/2]);
	#
	#print("FIRST ROW: " + str(points[0]))
	#print("LAST ROW: " + str(points[resolution]))
	
	points.resize(resolution);
	for row: PackedFloat32Array in points:
		row.resize(resolution);
	
	#var max: float = -INF;
	#var min: float = INF;
	#for row: PackedFloat32Array in points:
		#for point: float in row:
			#max = max(max, point);
			#min = min(min, point);
	#print("MAX: " + str(max) + " | MIN: " + str(min))
	
	#var new_points: Array[PackedFloat32Array] = [];
	#for row: PackedFloat32Array in points:
		#var new_row: PackedFloat32Array = PackedFloat32Array();
		#for point: float in row:
			#new_row.append(point * 2);
		#new_points.append(new_row);
	#points = new_points;
	
	var heightmap: Image = points_to_heightmap(points);
	if normalise:
		heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;

func generate_GPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image:
	var points: PackedFloat32Array = PackedFloat32Array();
	points.resize((resolution + 1) * (resolution + 1));
	
	points[0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ZERO));
	points[resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.RIGHT * resolution));
	points[(resolution + 1) * resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.DOWN * resolution));
	points[(resolution + 1) * (resolution + 1) - 1] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ONE * resolution));
	
	var points_bytes: PackedByteArray = points.to_byte_array();
	print(points_bytes.size());
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var points_RID := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
	var points_uniform := RDUniform.new();
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	points_uniform.binding = 1 # this needs to match the "binding" in our shader file
	points_uniform.add_id(points_RID);
	
	var workgroups: int = ceil(float(resolution + 1) / 4); # + 1 for the fact that resolution + 1 x resolution + 1
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		# diamond step
		var parameters: PackedFloat32Array = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(diamond_average_type), float(distribution), float(true), float(chunk_coord.x), float(chunk_coord.y)]); # DIFFERENT NEEDS TO BE UPDATED IN SHADER
		
		var parameters_bytes: PackedByteArray = parameters.to_byte_array();
		var parameters_RID := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		var parameters_uniform := RDUniform.new();
		parameters_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameters_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameters_uniform.add_id(parameters_RID);
		
		var uniform_set := rendering_device.uniform_set_create([parameters_uniform, points_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(parameters_RID);
		rendering_device.free_rid(pipeline);
		
		# square step
		parameters = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(diamond_average_type), float(distribution), float(false), float(chunk_coord.x), float(chunk_coord.y)]); # DIFFERENT NEEDS TO BE UPDATED IN SHADER
		
		parameters_bytes = parameters.to_byte_array();
		parameters_RID = rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		parameters_uniform = RDUniform.new();
		parameters_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameters_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameters_uniform.add_id(parameters_RID);
		
		uniform_set = rendering_device.uniform_set_create([parameters_uniform, points_uniform], compute_shader, 0);
		
		pipeline = rendering_device.compute_pipeline_create(compute_shader);
		compute_list = rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(parameters_RID);
		rendering_device.free_rid(pipeline);
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	var output_bytes := rendering_device.buffer_get_data(points_RID);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(points_RID);
	
	var output_points: Array[PackedFloat32Array] = points_linear_to_nested(output);
	
	#for row_ind: int in (resolution + 1) * (resolution + 1):
		#if output[row_ind] != 0:
			#print("NOT ZERO VALUE: " + str(output[row_ind]) + " ind: " + str(row_ind))
	#for row_ind: int in resolution * resolution:
		#if output[row_ind] != output_points[row_ind / (resolution + 1)][posmod(row_ind, resolution + 1)]:
			#print("NOT SAME" + str(row_ind));
	
	output_points.resize(resolution);
	for row: PackedFloat32Array in output_points:
		row.resize(resolution);
	
	var heightmap: Image = points_to_heightmap(output_points);
	if normalise:
		heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;
