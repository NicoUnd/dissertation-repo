extends TerrainGenerationMethodExplicit;
class_name DiffusionLimitedAggregation;

const INITIAL_RESOLUTION: int = 32;

var compute_shader;
var upscale_compute_shader;
var dla_height_compute_shader;
var smooth_falloff_compute_shader;

var walk_hops_to_live: int;

func setup(rendering_device: RenderingDevice) -> void:
	var shader_file := load("res://shaders/compute_shaders/diffusion_limited_aggregation_batched.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	var upscale_shader_file := load("res://shaders/compute_shaders/upscale.glsl");
	upscale_compute_shader = rendering_device.shader_create_from_spirv(upscale_shader_file.get_spirv());
	var dla_height_shader_file := load("res://shaders/compute_shaders/DLA_height.glsl");
	dla_height_compute_shader = rendering_device.shader_create_from_spirv(dla_height_shader_file.get_spirv());
	var smooth_falloff_shader_file := load("res://shaders/compute_shaders/smooth_falloff.glsl")
	smooth_falloff_compute_shader = rendering_device.shader_create_from_spirv(smooth_falloff_shader_file.get_spirv());

func setdown(rendering_device: RenderingDevice) -> void:
	return;

func fill_layer(points: Array[PackedFloat32Array], attach_directions: Array[PackedVector2Array], random_number_generator: RandomNumberGenerator) -> void:
	const MOVES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT];
	
	var layer_resolution: int = points.size();
	var steps: int = ceil(layer_resolution * layer_resolution * 0.08);
	for step: int in steps:
		var pos: Vector2i = Vector2i(
			random_number_generator.randi_range(0, layer_resolution - 1),
			random_number_generator.randi_range(0, layer_resolution - 1)
		);
		if points[pos.y][pos.x]:
			continue;
		
		while true:
			# check if neighbour is filled in
			if points[max(pos.y - 1, 0)][pos.x]:
				attach_directions[pos.y][pos.x] = Vector2.UP;
				break;
			if points[min(pos.y + 1, layer_resolution - 1)][pos.x]:
				attach_directions[pos.y][pos.x] = Vector2.DOWN;
				break;
			if points[pos.y][max(pos.x - 1, 0)]:
				attach_directions[pos.y][pos.x] = Vector2.LEFT;
				break;
			if points[pos.y][min(pos.x + 1, layer_resolution - 1)]:
				attach_directions[pos.y][pos.x] = Vector2.RIGHT;
				break;
			
			pos += MOVES[random_number_generator.randi_range(0, 3)]
			pos = pos.clampi(0, layer_resolution - 1);
		
		points[pos.y][pos.x] = 1;

func upscale_layer(points: Array[PackedFloat32Array], attach_directions: Array[PackedVector2Array], random_number_generator: RandomNumberGenerator) -> Array[Array]: # returns an array with points at index 0 and attach_directions at index 1
	var layer_resolution: int = points.size();
	var upscaled_layer_resolution: int = layer_resolution * 2;
	
	var upscaled_points: Array[PackedFloat32Array] = [];
	upscaled_points.resize(upscaled_layer_resolution);
	var upscaled_attach_directions: Array[PackedVector2Array] = [];
	upscaled_attach_directions.resize(upscaled_layer_resolution);
	for row_index: int in upscaled_layer_resolution:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(upscaled_layer_resolution);
		upscaled_points[row_index] = row;
		
		var directions_row: PackedVector2Array = PackedVector2Array();
		directions_row.resize(upscaled_layer_resolution);
		upscaled_attach_directions[row_index] = directions_row;
	
	upscaled_points[layer_resolution][layer_resolution] = 1;
	
	for y: int in layer_resolution:
		for x: int in layer_resolution:
			var attach_direction: Vector2i = Vector2i(attach_directions[y][x]);
			if attach_direction == Vector2i.ZERO:
				continue;
			
			var upscaled_pos: Vector2i = Vector2i(x*2, y*2);
			upscaled_points[upscaled_pos.y][upscaled_pos.x] = 1;
			
			var inbetween_pos: Vector2i = (upscaled_pos + attach_direction).clampi(0, upscaled_layer_resolution - 1);
			upscaled_points[inbetween_pos.y][inbetween_pos.x] = 1;
			
			var vector2_attach_direction: Vector2 = Vector2(attach_direction);
			upscaled_attach_directions[upscaled_pos.y][upscaled_pos.x] = vector2_attach_direction;
			
			upscaled_attach_directions[inbetween_pos.y][inbetween_pos.x] = vector2_attach_direction;
	
	return [upscaled_points, upscaled_attach_directions];

func generate_CPU(rendering_device: RenderingDevice) -> Image:
	var points: Array[PackedFloat32Array] = [];
	points.resize(INITIAL_RESOLUTION);
	var attach_directions: Array[PackedVector2Array] = [];
	attach_directions.resize(INITIAL_RESOLUTION);
	for row_index: int in INITIAL_RESOLUTION:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(INITIAL_RESOLUTION);
		points[row_index] = row;
		
		var directions_row: PackedVector2Array = PackedVector2Array();
		directions_row.resize(INITIAL_RESOLUTION);
		attach_directions[row_index] = directions_row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	@warning_ignore("integer_division")
	points[INITIAL_RESOLUTION/2][INITIAL_RESOLUTION/2] = 1;
	
	for __ in log2(resolution / INITIAL_RESOLUTION):
		fill_layer(points, attach_directions, random_number_generator);
		var upscaled_layer: Array[Array] = upscale_layer(points, attach_directions, random_number_generator);
		points = upscaled_layer[0];
		attach_directions = upscaled_layer[1];
		print(points.size());
	fill_layer(points, attach_directions, random_number_generator);
	print(points.size());
	
	var heightmap: Image = points_to_heightmap(points);
	heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;

func fill_layer_GPU(layer_resolution: int, rendering_device: RenderingDevice, attach_directions_uniform: RDUniform, add) -> void:
	@warning_ignore("integer_division")
	var workgroups = layer_resolution / INITIAL_RESOLUTION;
	
	var output_bytes := rendering_device.buffer_get_data(add);
	print(output_bytes.to_int32_array()[layer_resolution * layer_resolution / 2 + layer_resolution / 2]);
	if layer_resolution == INITIAL_RESOLUTION:
		var total: int = 0;
		for x in output_bytes.to_int32_array():
			total += x;
		print("TOTAL: " + str(total));
	
	for i: int in INITIAL_RESOLUTION * 0.5: # this will be the same for every layer, just larget batches
		# need to update the seed so that each calling will get different random numbers
		var shader_parameters: PackedFloat32Array = PackedFloat32Array([hash(layer_resolution + seed + i) % 16, float(layer_resolution), float(walk_hops_to_live)]);
		var parameters_bytes: PackedByteArray = shader_parameters.to_byte_array();
		var parameters_data := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		var parameter_uniform := RDUniform.new();
		parameter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameter_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameter_uniform.add_id(parameters_data);
		
		var uniform_set := rendering_device.uniform_set_create([parameter_uniform, attach_directions_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(parameters_data);
		rendering_device.free_rid(pipeline);
	
	output_bytes = rendering_device.buffer_get_data(add);
	print(output_bytes.to_int32_array()[layer_resolution * layer_resolution / 2 + layer_resolution / 2]);
	if layer_resolution == INITIAL_RESOLUTION:
		var total: int = 0;
		for x in output_bytes.to_int32_array():
			total += x;
		print("TOTAL: " + str(total));

func upscale_layer_GPU(layer_resolution: int, rendering_device: RenderingDevice, attach_directions_uniform: RDUniform) -> Array: # array of RDUniform and RID
	var upscaled_attach_directions: PackedInt32Array = PackedInt32Array();
	var upscale_resolution: int = layer_resolution * 2;
	upscaled_attach_directions.resize(upscale_resolution * upscale_resolution);
	
	var shader_parameters: PackedFloat32Array = PackedFloat32Array([seed, float(layer_resolution)]);
	var parameters_bytes: PackedByteArray = shader_parameters.to_byte_array();
	var parameters_data := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
	var parameter_uniform := RDUniform.new();
	parameter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	parameter_uniform.binding = 0 # this needs to match the "binding" in our shader file
	parameter_uniform.add_id(parameters_data);
	
	var upscaled_attach_directions_bytes: PackedByteArray = upscaled_attach_directions.to_byte_array();
	var upscaled_attach_directions_buffer_data := rendering_device.storage_buffer_create(upscaled_attach_directions_bytes.size(), upscaled_attach_directions_bytes);
	var upscaled_attach_directions_buffer_uniform := RDUniform.new();
	upscaled_attach_directions_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	upscaled_attach_directions_buffer_uniform.binding = 2 # this needs to match the "binding" in our shader file
	upscaled_attach_directions_buffer_uniform.add_id(upscaled_attach_directions_buffer_data);
	
	@warning_ignore("integer_division")
	var workgroups = layer_resolution / 32;
	
	var uniform_set := rendering_device.uniform_set_create([parameter_uniform, attach_directions_uniform, upscaled_attach_directions_buffer_uniform], upscale_compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(upscale_compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(parameters_data);
	rendering_device.free_rid(pipeline);
	
	return [upscaled_attach_directions_buffer_uniform, upscaled_attach_directions_buffer_data];

func smooth_falloff_height_GPU(rendering_device: RenderingDevice, attach_directions_uniform: RDUniform) -> PackedFloat32Array:
	var int_points: PackedInt32Array = PackedInt32Array();
	int_points.resize(resolution * resolution);
	
	var shader_parameters: PackedFloat32Array = PackedFloat32Array([float(resolution)]);
	var parameters_bytes: PackedByteArray = shader_parameters.to_byte_array();
	var parameters_data := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
	var parameter_uniform := RDUniform.new();
	parameter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	parameter_uniform.binding = 0 # this needs to match the "binding" in our shader file
	parameter_uniform.add_id(parameters_data);
	
	var int_points_bytes: PackedByteArray = int_points.to_byte_array();
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var int_points_data := rendering_device.storage_buffer_create(int_points_bytes.size(), int_points_bytes);
	var int_points_uniform := RDUniform.new();
	int_points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	int_points_uniform.binding = 2 # this needs to match the "binding" in our shader file
	int_points_uniform.add_id(int_points_data);
	
	var workgroups = resolution / 32;
	
	var uniform_set := rendering_device.uniform_set_create([parameter_uniform, attach_directions_uniform, int_points_uniform], dla_height_compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(dla_height_compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	var output_bytes := rendering_device.buffer_get_data(points_data);
	var output := output_bytes.to_float32_array();
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	
	var points: PackedInt32Array = PackedInt32Array();
	points.resize(resolution * resolution);
	
	var shader_parameters: PackedFloat32Array = PackedFloat32Array([float(resolution)]);
	var parameters_bytes: PackedByteArray = shader_parameters.to_byte_array();
	var parameters_data := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
	var parameter_uniform := RDUniform.new();
	parameter_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	parameter_uniform.binding = 0 # this needs to match the "binding" in our shader file
	parameter_uniform.add_id(parameters_data);
	
	var points_bytes: PackedByteArray = points.to_byte_array();
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var points_data := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
	var points_uniform := RDUniform.new();
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	points_uniform.binding = 2 # this needs to match the "binding" in our shader file
	points_uniform.add_id(points_data);
	
	var workgroups = resolution / 32;
	
	var uniform_set := rendering_device.uniform_set_create([parameter_uniform, attach_directions_uniform, points_uniform], dla_height_compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(dla_height_compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(points_data);
	rendering_device.free_rid(parameters_data);
	rendering_device.free_rid(pipeline);
	
	return output;

func generate_GPU(rendering_device: RenderingDevice) -> Image:
	var attach_directions: PackedInt32Array = PackedInt32Array();
	attach_directions.resize(INITIAL_RESOLUTION * INITIAL_RESOLUTION);
	
	@warning_ignore("integer_division")
	attach_directions[INITIAL_RESOLUTION * INITIAL_RESOLUTION / 2 + INITIAL_RESOLUTION / 2] = 1;
	
	var attach_directions_bytes: PackedByteArray = attach_directions.to_byte_array();
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var attach_directions_data := rendering_device.storage_buffer_create(attach_directions_bytes.size(), attach_directions_bytes);
	var attach_directions_uniform := RDUniform.new();
	attach_directions_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	attach_directions_uniform.binding = 1 # this needs to match the "binding" in our shader file
	attach_directions_uniform.add_id(attach_directions_data);
	
	var layer_resolution: int = INITIAL_RESOLUTION;
	while layer_resolution < resolution:
		fill_layer_GPU(layer_resolution, rendering_device, attach_directions_uniform, attach_directions_data);
		
		var upscaled_data: Array = upscale_layer_GPU(layer_resolution, rendering_device, attach_directions_uniform);
		attach_directions_uniform = upscaled_data[0];
		attach_directions_uniform.binding = 1; # from 2
		rendering_device.free_rid(attach_directions_data);
		attach_directions_data = upscaled_data[1];
		
		layer_resolution *= 2;
		print(layer_resolution);
	assert(layer_resolution == resolution);
	
	fill_layer_GPU(layer_resolution, rendering_device, attach_directions_uniform, attach_directions_data);
	var points_linear: PackedFloat32Array = smooth_falloff_height_GPU(rendering_device, attach_directions_uniform);
	
	rendering_device.free_rid(attach_directions_data);
	
	var points: Array[PackedFloat32Array] = points_linear_to_nested(points_linear);
	var heightmap: Image = points_to_heightmap(points);
	#heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;
