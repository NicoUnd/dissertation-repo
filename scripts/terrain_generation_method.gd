extends Resource
class_name TerrainGenerationMethod

const RESOLUTIONS: Array[int] = [256, 512, 1024, 2048, 4096];

@export var name: String;

@export var shader: Shader;
@export var unshaded_shader: Shader;

@export var explicit_generation: bool;
@export var GPU_accelerated: bool;

@export var shader_parameters: Array[ShaderParameter] = [];

@export var can_generate_in_chunks: bool;

var seed: float;

func log2(x: float) -> float:
	return log(x) / log(2);

func setup() -> void:
	assert(false);
	return;

func setdown() -> void:
	assert(false);
	return;

func generate_CPU() -> Image:
	assert(false);
	return;

func generate_GPU() -> Image:
	assert(false);
	return;

static func points_to_heightmap(points: Array[PackedFloat32Array]) -> Image:
	var resolution: int = points.size();
	var bytes: PackedByteArray = PackedByteArray();
	bytes.resize(resolution * resolution * 4);
	var byte_index: int = 0;
	for y: int in resolution:
		for x: int in resolution:
			bytes.encode_float(byte_index, points[y][x]);
			byte_index += 4;
	
	var heightmap: Image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, bytes);
	return heightmap;

static func heightmap_to_points(heightmap: Image) -> Array[PackedFloat32Array]:
	var resolution: int = heightmap.get_width();
	var bytes: PackedByteArray = heightmap.get_data();
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array();
		row.resize(resolution);
		points[row_index] = row;
	for point_index: int in resolution * resolution:
		var byte_index: int = point_index * 4;
		@warning_ignore("integer_division")
		points[point_index / resolution][posmod(point_index, resolution)] = bytes.decode_float(byte_index);
	return points;

static func points_to_slopemap_points(points: Array[PackedFloat32Array]) -> Array[PackedFloat32Array]:
	var resolution: int = points.size();
	var slopemap_points: Array[PackedFloat32Array] = [];
	slopemap_points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array();
		row.resize(resolution);
		slopemap_points[row_index] = row;
	
	for y: int in resolution:
		for x: int in resolution:
			var point: float = points[y][x];
			slopemap_points[y][x] = max(
				abs(point - points[posmod(y + 1, resolution)][x]),
				abs(point - points[posmod(y - 1, resolution)][x]),
				abs(point - points[y][posmod(x + 1, resolution)]),
				abs(point - points[y][posmod(x - 1, resolution)]),
			);
	
	return slopemap_points;

static func get_slopemap_data_GPU(heightmap: Image, rendering_device: RenderingDevice) -> PackedByteArray:
	var shader_file := load("res://shaders/slopemap.glsl");
	var compute_shader := rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var resolution: int = heightmap.get_width();
	
	var heightmap_bytes: PackedByteArray = heightmap.get_data();
	var texture_data := RDTextureFormat.new();
	texture_data.width = resolution;
	texture_data.height = resolution;
	texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT;
	texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	var gpu_texture = rendering_device.texture_create(texture_data, RDTextureView.new(), [heightmap_bytes]);
	
	var sampler_state = RDSamplerState.new();
	sampler_state.unnormalized_uvw = true;
	var sampler = rendering_device.sampler_create(sampler_state);
	
	var texture_uniform := RDUniform.new();
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;
	texture_uniform.binding = 0;
	texture_uniform.add_id(sampler);
	texture_uniform.add_id(gpu_texture);
	
	var slopemap_bytes = PackedByteArray();
	slopemap_bytes.resize(resolution * resolution * 4);
	var slopemap_texture_data := RDTextureFormat.new();
	slopemap_texture_data.width = resolution;
	slopemap_texture_data.height = resolution;
	slopemap_texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	slopemap_texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	var slopemap_gpu_texture = rendering_device.texture_create(slopemap_texture_data, RDTextureView.new(), [slopemap_bytes]);
	
	var slopemap_texture_uniform := RDUniform.new();
	slopemap_texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	slopemap_texture_uniform.binding = 1;
	slopemap_texture_uniform.add_id(slopemap_gpu_texture);
	
	var bytes: PackedByteArray = PackedInt32Array([resolution]).to_byte_array();
	var resolution_buffer_data := rendering_device.storage_buffer_create(bytes.size(), bytes);
	var buffer_uniform := RDUniform.new();
	buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	buffer_uniform.binding = 2 # this needs to match the "binding" in our shader file
	buffer_uniform.add_id(resolution_buffer_data);
	
	var uniform_set := rendering_device.uniform_set_create([texture_uniform, slopemap_texture_uniform, buffer_uniform], compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	@warning_ignore("integer_division")
	var workgroups: int = resolution / 32;
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	var output_bytes: PackedByteArray = rendering_device.texture_get_data(slopemap_gpu_texture, 0);
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	rendering_device.free_rid(compute_shader);
	rendering_device.free_rid(resolution_buffer_data);
	rendering_device.free_rid(gpu_texture);
	rendering_device.free_rid(slopemap_gpu_texture);
	
	return output_bytes;

static func mean_GPU(resolution: int, rendering_device: RenderingDevice, texture_uniform: RDUniform) -> float:
	var shader_file := load("res://shaders/mean.glsl");
	var compute_shader := rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var bytes: PackedByteArray = PackedFloat32Array([float(0)]).to_byte_array();
	var total_buffer_data := rendering_device.storage_buffer_create(bytes.size(), bytes);
	var buffer_uniform := RDUniform.new();
	buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	buffer_uniform.binding = 1 # this needs to match the "binding" in our shader file
	buffer_uniform.add_id(total_buffer_data);
	
	var uniform_set := rendering_device.uniform_set_create([texture_uniform, buffer_uniform], compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	@warning_ignore("integer_division")
	var workgroups: int = resolution / 32;
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	var output_bytes: PackedByteArray = rendering_device.buffer_get_data(total_buffer_data);
	var mean: float = output_bytes.to_float32_array()[0] / (resolution * resolution);
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	rendering_device.free_rid(compute_shader);
	rendering_device.free_rid(total_buffer_data);
	
	return mean;

static func std_dev_GPU(resolution: int, rendering_device: RenderingDevice, texture_uniform: RDUniform, mean: float) -> float:
	var shader_file := load("res://shaders/std_dev.glsl");
	var compute_shader := rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var bytes: PackedByteArray = PackedFloat32Array([mean, float(0)]).to_byte_array();
	var parameter_buffer_data := rendering_device.storage_buffer_create(bytes.size(), bytes);
	var buffer_uniform := RDUniform.new();
	buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	buffer_uniform.binding = 1 # this needs to match the "binding" in our shader file
	buffer_uniform.add_id(parameter_buffer_data);
	
	var uniform_set := rendering_device.uniform_set_create([texture_uniform, buffer_uniform], compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	@warning_ignore("integer_division")
	var workgroups: int = resolution / 32;
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	var output_bytes: PackedByteArray = rendering_device.buffer_get_data(parameter_buffer_data);
	var std_dev: float = sqrt(output_bytes.to_float32_array()[1] / (resolution * resolution));
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	rendering_device.free_rid(compute_shader);
	rendering_device.free_rid(parameter_buffer_data);
	
	return std_dev;

static func get_erosion_score(heightmap: Image) -> float:
	#var points: Array[PackedFloat32Array] = heightmap_to_points(heightmap);
	#var slopemap_points: Array[PackedFloat32Array] = points_to_slopemap_points(points);
	#print(slopemap_points[0].slice(0, 10));
	#
	#var total: float = 0;
	#for row: PackedFloat32Array in slopemap_points:
		#for point: float in row:
			#total += point;
	#var resolution: int = points.size();
	#@warning_ignore("narrowing_conversion")
	#var resolution_squared: int = pow(resolution, 2);
	#var mean: float = total / resolution_squared;
	#
	#total = 0;
	#for row: PackedFloat32Array in slopemap_points:
		#for point: float in row:
			#total += pow(mean - point, 2);
	#var std_dev: float = sqrt(total / resolution_squared);
	#
	#assert(mean != 0);
	#return std_dev / mean;
	
	var rendering_device: RenderingDevice = RenderingServer.create_local_rendering_device();
	
	var slopemap_bytes: PackedByteArray = get_slopemap_data_GPU(heightmap, rendering_device);
	
	#print(heightmap.get_data().to_float32_array().slice(0, 100));
	#print(slopemap_bytes.to_float32_array().slice(0, 100));
	#print(slopemap_bytes.to_float32_array().slice(1000, 1100));
	#print(slopemap_bytes.to_float32_array().slice(2000, 2100));
	#print(slopemap_bytes.to_float32_array().slice(10000, 10100));
	
	var resolution: int = heightmap.get_width();
	
	#var total_CPU: float = 0;
	#for row: PackedFloat32Array in slopemap_points:
		#for point: float in row:
			#total_CPU += point;
	#@warning_ignore("narrowing_conversion")
	#var mean_CPU: float = total_CPU / (resolution * resolution);
	#print("total_CPU", str(total_CPU));
	#print("mean_CPU", str(mean_CPU));
	#total_CPU = 0;
	#for row: PackedFloat32Array in slopemap_points:
		#for point: float in row:
			#total_CPU += pow(mean_CPU - point, 2);
	#var std_dev_CPU: float = sqrt(total_CPU / (resolution * resolution));
	#print("std_dev_CPU", str(std_dev_CPU));
	
	var texture_data := RDTextureFormat.new();
	texture_data.width = resolution;
	texture_data.height = resolution;
	texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT;
	texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	var gpu_texture = rendering_device.texture_create(texture_data, RDTextureView.new(), [slopemap_bytes]);
	
	var sampler_state = RDSamplerState.new();
	sampler_state.unnormalized_uvw = true;
	var sampler = rendering_device.sampler_create(sampler_state);
	
	var texture_uniform := RDUniform.new();
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;
	texture_uniform.binding = 0
	texture_uniform.add_id(sampler);
	texture_uniform.add_id(gpu_texture);
	
	var mean: float = mean_GPU(resolution, rendering_device, texture_uniform);
	if mean == 0:
		return 0;
	var std_dev: float = std_dev_GPU(resolution, rendering_device, texture_uniform, mean);
	print("mean" + str(mean));
	print("std_dev" + str(std_dev));
	
	rendering_device.free_rid(gpu_texture);
	rendering_device.free_rid(sampler);
	rendering_device.free();
	
	return std_dev / mean;

static func max_min_GPU(heightmap: Image, rendering_device: RenderingDevice) -> RID:
	var shader_file := load("res://shaders/max_min.glsl");
	var compute_shader := rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var resolution: int = heightmap.get_width();
	
	var heightmap_bytes: PackedByteArray = heightmap.get_data();
	var texture_data := RDTextureFormat.new();
	texture_data.width = resolution;
	texture_data.height = resolution;
	texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT;
	texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	var gpu_texture = rendering_device.texture_create(texture_data, RDTextureView.new(), [heightmap_bytes]);
	
	var sampler_state = RDSamplerState.new();
	sampler_state.unnormalized_uvw = true;
	var sampler = rendering_device.sampler_create(sampler_state);
	
	var texture_uniform := RDUniform.new();
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE;
	texture_uniform.binding = 0
	texture_uniform.add_id(sampler);
	texture_uniform.add_id(gpu_texture);
	
	var bytes: PackedByteArray = PackedInt32Array([int(0), int(255)]).to_byte_array();
	var max_min_buffer_data := rendering_device.storage_buffer_create(bytes.size(), bytes);
	var buffer_uniform := RDUniform.new();
	buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	buffer_uniform.binding = 1 # this needs to match the "binding" in our shader file
	buffer_uniform.add_id(max_min_buffer_data);
	
	var uniform_set := rendering_device.uniform_set_create([texture_uniform, buffer_uniform], compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	@warning_ignore("integer_division")
	var workgroups: int = resolution / 32;
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	rendering_device.free_rid(compute_shader);
	rendering_device.free_rid(gpu_texture);
	rendering_device.free_rid(sampler);
	
	return max_min_buffer_data;

static func normalise_GPU(heightmap: Image, max_min_buffer_data: RID, rendering_device: RenderingDevice) -> Image:
	var shader_file := load("res://shaders/normalise.glsl");
	var compute_shader := rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var resolution: int = heightmap.get_width();
	
	var heightmap_bytes: PackedByteArray = heightmap.get_data();
	var texture_data := RDTextureFormat.new();
	texture_data.width = resolution;
	texture_data.height = resolution;
	texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
	texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
	var gpu_texture = rendering_device.texture_create(texture_data, RDTextureView.new(), [heightmap_bytes]);
	
	var texture_uniform := RDUniform.new();
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
	texture_uniform.binding = 0;
	texture_uniform.add_id(gpu_texture);
	
	var buffer_uniform := RDUniform.new();
	buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	buffer_uniform.binding = 1 # this needs to match the "binding" in our shader file
	buffer_uniform.add_id(max_min_buffer_data);
	
	var uniform_set := rendering_device.uniform_set_create([texture_uniform, buffer_uniform], compute_shader, 0);
	
	var pipeline := rendering_device.compute_pipeline_create(compute_shader);
	var compute_list := rendering_device.compute_list_begin();
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
	@warning_ignore("integer_division")
	var workgroups: int = resolution / 32;
	rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
	rendering_device.compute_list_end();
	
	rendering_device.submit();
	rendering_device.sync();
	
	var bytes: PackedByteArray = rendering_device.texture_get_data(gpu_texture, 0);
	
	rendering_device.free_rid(uniform_set);
	rendering_device.free_rid(pipeline);
	rendering_device.free_rid(compute_shader);
	rendering_device.free_rid(gpu_texture);
	rendering_device.free_rid(max_min_buffer_data);
	
	return Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, bytes);

static func normalise_heightmap(heightmap: Image) -> Image:
	var rendering_device: RenderingDevice = RenderingServer.create_local_rendering_device();
	var normalised_heightmap: Image = normalise_GPU(heightmap, max_min_GPU(heightmap, rendering_device), rendering_device);
	rendering_device.free();
	return normalised_heightmap;
