extends TerrainGenerationMethod
class_name DiamondSquare

var resolution: int = 1024;

var smoothness: float = 1;

var distribution: int = 0;

var wrap_around: bool = true;

var normalise: bool = false;

var rendering_device: RenderingDevice;
var compute_shader;

func get_square_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var square_average: float = 0;
	for square_corner_y: int in [y - half_step_size, y + half_step_size]:
		for square_corner_x: int in [x - half_step_size, x + half_step_size]:
			square_average += points[square_corner_y][square_corner_x] / 4;
			#if points[square_corner_y][square_corner_x] == 0:
			#	breakpoint;
	return square_average;

func get_diamond_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var diamond_total: float = 0;
	var num_of_corners_used: int = 0;
	for diamond_corner_y: int in [y - half_step_size, y + half_step_size]:
		if wrap_around:
			if diamond_corner_y < 0:
				diamond_corner_y += resolution;
			elif diamond_corner_y > resolution:
				diamond_corner_y -= resolution;
			# diamond_corner_y = posmod(diamond_corner_y, resolution + 1);
		elif diamond_corner_y > resolution or diamond_corner_y < 0:
			continue;
		diamond_total += points[diamond_corner_y][x];
		num_of_corners_used += 1;
		#if points[diamond_corner_y][x] == 0:
		#	breakpoint;
	for diamond_corner_x: int in [x - half_step_size, x + half_step_size]:
		if wrap_around:
			if diamond_corner_x < 0:
				diamond_corner_x += resolution;
			elif diamond_corner_x > resolution:
				diamond_corner_x -= resolution;
		elif diamond_corner_x > resolution or diamond_corner_x < 0:
			continue;
		diamond_total += points[y][diamond_corner_x];
		num_of_corners_used += 1;
		#if points[y][diamond_corner_x] == 0:
		#	breakpoint;
	
	assert(num_of_corners_used == 3 or num_of_corners_used == 4);
	return diamond_total / num_of_corners_used;

func random_offset(random_number_generator: RandomNumberGenerator, random_scale: float) -> float:
	if distribution == 0: # uniform
		return random_number_generator.randf_range(-0.5, 0.5) * random_scale
	else: # guassian
		return random_number_generator.randfn(0, 0.5 * random_scale);

func setup() -> void:
	rendering_device = RenderingServer.create_local_rendering_device();
	
	var shader_file := load("res://shaders/diamond-square.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	print("SETTING UP RENDERING DEVICE")

func setdown() -> void:
	rendering_device.free_rid(rendering_device);
	rendering_device.free_rid(compute_shader);

func generate_CPU() -> Image:
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution + 1);
	for row_index: int in resolution + 1:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution + 1);
		points[row_index] = row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	points[0][0] = random_number_generator.randf();
	points[0][resolution] = random_number_generator.randf();
	points[resolution][0] = random_number_generator.randf();
	points[resolution][resolution] = random_number_generator.randf();
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		var half_step_size: int = step_size / 2;
		
		# diamond step
		var diamond_indecies: Array = range(half_step_size, resolution + 1, step_size);
		for y: int in diamond_indecies:
			for x: int in diamond_indecies:
				points[y][x] = clamp(get_square_average(points, x, y, half_step_size) + random_offset(random_number_generator, random_scale), 0, 1);
				#print("square_avg: " + str(points[y][x]))
		
		# square step
		for y: int in range(0, resolution + 1, half_step_size):
			for x: int in range(posmod(y + half_step_size, step_size), resolution + 1, step_size):
				points[y][x] = clamp(get_diamond_average(points, x, y, half_step_size) + random_offset(random_number_generator, random_scale), 0, 1);
				#print("diamond_avg: " + str(points[y][x]))
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	points.resize(resolution);
	for row: PackedFloat32Array in points:
		row.resize(resolution);
	
	var heightmap: Image = points_to_heightmap(points);
	if normalise:
		heightmap = normalise_heightmap(heightmap);
	return heightmap;

func generate_GPU() -> Image:
	var points: PackedFloat32Array = PackedFloat32Array();
	points.resize((resolution + 1) * (resolution + 1));
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	points[0] = random_number_generator.randf();
	points[resolution] = random_number_generator.randf();
	points[(resolution + 1) * resolution] = random_number_generator.randf();
	points[(resolution + 1) * (resolution + 1) - 1] = random_number_generator.randf();
	
	var points_bytes: PackedByteArray = points.to_byte_array();
	print(points_bytes.size());
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var points_data := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
	var points_uniform := RDUniform.new();
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	points_uniform.binding = 1 # this needs to match the "binding" in our shader file
	points_uniform.add_id(points_data);
	
	var workgroups: int = ceil(float(resolution + 1) / 32); # + 1 for the fact that resolution + 1 x resolution + 1
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		# diamond step
		var parameters: PackedFloat32Array = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(wrap_around), float(distribution), float(true)]);
		
		var bytes: PackedByteArray = parameters.to_byte_array();
		var buffer_data := rendering_device.storage_buffer_create(bytes.size(), bytes);
		var buffer_uniform := RDUniform.new();
		buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_uniform.binding = 0 # this needs to match the "binding" in our shader file
		buffer_uniform.add_id(buffer_data);
		
		var uniform_set := rendering_device.uniform_set_create([buffer_uniform, points_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		# square step
		parameters = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(wrap_around), float(distribution), float(false)]);
		
		bytes = parameters.to_byte_array();
		buffer_data = rendering_device.storage_buffer_create(bytes.size(), bytes);
		buffer_uniform = RDUniform.new();
		buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_uniform.binding = 0 # this needs to match the "binding" in our shader file
		buffer_uniform.add_id(buffer_data);
		
		uniform_set = rendering_device.uniform_set_create([buffer_uniform, points_uniform], compute_shader, 0);
		
		pipeline = rendering_device.compute_pipeline_create(compute_shader);
		compute_list = rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(buffer_data);
		#rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(pipeline);
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	var output_bytes := rendering_device.buffer_get_data(points_data);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(points_data);
	
	var linear_index: int = 0;
	var output_points: Array[PackedFloat32Array] = [];
	output_points.resize(resolution + 1);
	for row_index: int in resolution + 1:
		var row: PackedFloat32Array = output.slice(linear_index, linear_index + resolution + 1); # use 32 bits as is standard in exp file format
		output_points[row_index] = row;
		linear_index += resolution + 1;
	
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
		heightmap = normalise_heightmap(heightmap);
	return heightmap;
