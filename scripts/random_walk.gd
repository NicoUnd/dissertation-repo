extends TerrainGenerationMethod
class_name RandomWalk

var resolution: int = 1024;

var walk_percent_of_resolution: float = 0.25;

var walks: int = 16;

var start_from: int = 0;

var blur_radius: int = 5;

var compute_shader;

func setup(rendering_device: RenderingDevice) -> void:
	var shader_file := load("res://shaders/add.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());

func setdown(rendering_device: RenderingDevice) -> void:
	rendering_device.free_rid(compute_shader);

func create_layer(given_seed: float) -> Array[PackedFloat32Array]:
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
	points[current_coord.y][current_coord.x] = 1;
	
	for i: int in iterations:
		var valid_next_coords: Array[Vector2i] = [];
		for move: Vector2i in MOVES:
			var possible_next_coord: Vector2i = current_coord + move;
			if possible_next_coord.x >= 0 and possible_next_coord.x < resolution and possible_next_coord.y >= 0 and possible_next_coord.y < resolution:
				valid_next_coords.append(possible_next_coord);
		current_coord = valid_next_coords[random_number_generator.randi_range(0, valid_next_coords.size() - 1)];
		points[current_coord.y][current_coord.x] = 1;
	return points;

func generate_CPU(rendering_device: RenderingDevice) -> Image:
	var threads: Array[Thread] = [];
	threads.resize(walks);
	for layer: int in walks:
		threads[layer] = Thread.new();
		threads[layer].start(create_layer.bind(seed + layer)); # offsets the seed for each layer
	
	var aggregate_points: PackedFloat32Array = PackedFloat32Array();
	aggregate_points.resize(resolution * resolution);
	var aggregate_points_bytes: PackedByteArray = aggregate_points.to_byte_array();
	var aggregate_points_data := rendering_device.storage_buffer_create(aggregate_points_bytes.size(), aggregate_points_bytes);
	var aggregate_points_uniform := RDUniform.new();
	aggregate_points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	aggregate_points_uniform.binding = 0 # this needs to match the "binding" in our shader file
	aggregate_points_uniform.add_id(aggregate_points_data);
	
	@warning_ignore("integer_division")
	var workgroups: int = resolution * resolution / 1024;
	
	for thread: Thread in threads:
		var points: PackedFloat32Array = points_nested_to_linear(thread.wait_to_finish());
		var points_bytes: PackedByteArray = points.to_byte_array();
		var points_data := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
		var points_uniform := RDUniform.new();
		points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		points_uniform.binding = 1 # this needs to match the "binding" in our shader file
		points_uniform.add_id(points_data);
		
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
		rendering_device.free_rid(points_data);
		rendering_device.free_rid(pipeline);
	
	var output_bytes := rendering_device.buffer_get_data(aggregate_points_data);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(aggregate_points_data);
	
	var heightmap: Image = points_to_heightmap(points_linear_to_nested(output));
	heightmap = normalise_heightmap(heightmap, rendering_device);
	heightmap = gaussian_blur(heightmap, blur_radius, rendering_device);
	return heightmap;
