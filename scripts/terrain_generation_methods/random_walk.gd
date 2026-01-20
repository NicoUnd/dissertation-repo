extends TerrainGenerationMethodExplicit;
class_name RandomWalk;

var walk_percent_of_resolution: float;

var walks: int;

var start_from: int;

var blur_levels: int;

var compute_shader;

func setup(rendering_device: RenderingDevice) -> void:
	var shader_file := load("res://shaders/compute_shaders/add.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());

func setdown(rendering_device: RenderingDevice) -> void:
	rendering_device.free_rid(compute_shader);

func create_layer(given_seed: float, value: float, resolution: int) -> Array[PackedFloat32Array]:
	const MOVES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT];
	const NEAR_CENTRE_AMOUNT: float = 2.1;
	
	@warning_ignore("narrowing_conversion")
	var iterations: int = resolution * resolution * walk_percent_of_resolution;
	
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution);
		points[row_index] = row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(given_seed);
	
	var current_coord: Vector2i;
	match start_from:
		0:
			current_coord = Vector2i.ONE * resolution/2;
		1:
			@warning_ignore("narrowing_conversion")
			var into_resolution: int = resolution/NEAR_CENTRE_AMOUNT;
			current_coord = Vector2i(random_number_generator.randi_range(into_resolution, resolution - into_resolution), random_number_generator.randi_range(into_resolution, resolution - into_resolution));
		2:
			current_coord = Vector2i.ZERO;
		3:
			current_coord = [Vector2i.ZERO, Vector2i(resolution - 1, 0), Vector2i(0, resolution - 1), Vector2i.ONE * (resolution - 1)][random_number_generator.randi_range(0, 3)];
		4:
			current_coord = Vector2i(random_number_generator.randi_range(0, resolution - 1), random_number_generator.randi_range(0, resolution - 1));
	points[current_coord.y][current_coord.x] = value;
	
	for i: int in iterations:
		var valid_next_coords: Array[Vector2i] = [];
		for move: Vector2i in MOVES:
			var possible_next_coord: Vector2i = current_coord + move;
			if possible_next_coord.x >= 0 and possible_next_coord.x < resolution and possible_next_coord.y >= 0 and possible_next_coord.y < resolution:
				valid_next_coords.append(possible_next_coord);
		current_coord = valid_next_coords[random_number_generator.randi_range(0, valid_next_coords.size() - 1)];
		points[current_coord.y][current_coord.x] = value;
	return points;

func blur_with_detail(heightmap: Image, rendering_device: RenderingDevice) -> Image:
	var resolution: int = heightmap.get_height();
	var workgroups: int = resolution * resolution / 1024;
	
	var points_bytes: PackedByteArray = heightmap.get_data();
	var points_RID := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
	var points_uniform := RDUniform.new();
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	points_uniform.binding = 0 # this needs to match the "binding" in our shader file
	points_uniform.add_id(points_RID);
	
	#var blur_level_multiplier: float = 1;
	for blur_level: int in blur_levels:
		var multiplier: float = pow(blur_level + 1, 2);
		var blurred_heightmap: Image = gaussian_blur(heightmap, multiplier, rendering_device);
		var blurred_points_bytes: PackedByteArray = PackedFloat32Array([multiplier]).to_byte_array();
		blurred_points_bytes.append_array(blurred_heightmap.get_data());
		var blurred_points_RID := rendering_device.storage_buffer_create(blurred_points_bytes.size(), blurred_points_bytes);
		var blurred_points_uniform := RDUniform.new();
		blurred_points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		blurred_points_uniform.binding = 1 # this needs to match the "binding" in our shader file
		blurred_points_uniform.add_id(blurred_points_RID);
		
		var uniform_set := rendering_device.uniform_set_create([blurred_points_uniform, points_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, 1, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(blurred_points_RID);
		rendering_device.free_rid(pipeline);
		
		#blur_level_multiplier /= 2;
	
	var output_bytes := rendering_device.buffer_get_data(points_RID);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(points_RID);
	
	var combined_heightmap: Image = points_to_heightmap(points_linear_to_nested(output));
	combined_heightmap = normalise_heightmap(combined_heightmap, rendering_device);
	return combined_heightmap;

func generate_CPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image:
	var threads: Array[Thread] = [];
	threads.resize(walks);
	var value = 1.0 / walks;
	for layer: int in walks:
		threads[layer] = Thread.new();
		threads[layer].start(create_layer.bind(seed + layer, value, resolution)); # offsets the seed for each layer
	
	var aggregate_points: PackedFloat32Array = PackedFloat32Array();
	aggregate_points.resize(resolution * resolution);
	var aggregate_points_bytes: PackedByteArray = aggregate_points.to_byte_array();
	var aggregate_points_RID := rendering_device.storage_buffer_create(aggregate_points_bytes.size(), aggregate_points_bytes);
	var aggregate_points_uniform := RDUniform.new();
	aggregate_points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	aggregate_points_uniform.binding = 0 # this needs to match the "binding" in our shader file
	aggregate_points_uniform.add_id(aggregate_points_RID);
	
	@warning_ignore("integer_division")
	var workgroups: int = resolution * resolution / 1024;
	
	for thread_index: int in threads.size():
		var thread: Thread = threads[thread_index];
		
		var points: PackedFloat32Array = points_nested_to_linear(thread.wait_to_finish());
		#var image: Image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, points.to_byte_array());
		#var blurred_image: Image = gaussian_blur(image, thread_index + 1, rendering_device);
		var points_bytes: PackedByteArray = PackedFloat32Array([1.0]).to_byte_array(); # multiplier is 1
		#points_bytes.append_array(blurred_image.get_data());
		points_bytes.append_array(points.to_byte_array());
		var points_RID := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
		var points_uniform := RDUniform.new();
		points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		points_uniform.binding = 1 # this needs to match the "binding" in our shader file
		points_uniform.add_id(points_RID);
		
		var uniform_set := rendering_device.uniform_set_create([aggregate_points_uniform, points_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, 1, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(points_RID);
		rendering_device.free_rid(pipeline);
	
	var output_bytes := rendering_device.buffer_get_data(aggregate_points_RID);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(aggregate_points_RID);
	
	var heightmap: Image = points_to_heightmap(points_linear_to_nested(output));
	heightmap = blur_with_detail(heightmap, rendering_device);
	return heightmap;

func generate_GPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image: # will never happen as not GPU accelerated
	assert(false);
	return;
