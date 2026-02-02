extends Control
class_name ErosionSettings

const HEIGHTMAP_BLENDING: TerrainGenerationMethodNoise = preload("uid://uir8vm75yx0o");

const EROSION_RESOLUTIONS: Array[int] = [256, 512, 1024, 2048, 4096];

@onready var main: Control = $".."

@onready var settings_v_box_container: VBoxContainer = %SettingsVBoxContainer

var compute_shader;

var resolution: int;

var time_to_live: int;
var inertia: float;
var min_slope: float;
var base_capacity: float;
var deposition_rate: float;
var erosion_rate: float;
var gravity: float;
var evaporation_rate: float;
var radius: float;

var log_base_2_drops: int;

var visualisation_speed: int;

func start_erosion() -> void:
	hide();
	for ui: Control in settings_v_box_container.get_children():
		ui.queue_free();
	
	var heightmap: Image = main.capture_heightmap(resolution);
	var amplitude: float = main.terrain_generation_method_visualiser.planes.get_child(0).mesh.material.get_shader_parameter("amplitude");
	main.terrain_generation_method = HEIGHTMAP_BLENDING;
	main.ui.terrain_generation_method_option_button.option_button.selected = TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS.find(HEIGHTMAP_BLENDING);
	main.set_parameter("heightmap1", ImageTexture.create_from_image(heightmap));
	main.set_parameter("amplitude", amplitude);
	
	erode(heightmap);

func erode(heightmap: Image) -> void:
	var rendering_device: RenderingDevice = main.rendering_device;
	
	@warning_ignore("narrowing_conversion")
	var workgroups: int = sqrt(pow(2, log_base_2_drops)) / 8;
	
	for workgroup in workgroups / pow(visualisation_speed, 2):
		var parameters: PackedFloat32Array = PackedFloat32Array([randf_range(1, 64), float(time_to_live), inertia, min_slope, base_capacity, deposition_rate, erosion_rate, gravity, evaporation_rate, radius]); # DIFFERENT NEEDS TO BE UPDATED IN SHADER
		
		var parameters_bytes: PackedByteArray = parameters.to_byte_array();
		var parameters_RID := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		var parameters_uniform := RDUniform.new();
		parameters_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameters_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameters_uniform.add_id(parameters_RID);
		
		var heightmap_bytes: PackedByteArray = heightmap.get_data();
		var texture_data := RDTextureFormat.new();
		texture_data.width = resolution;
		texture_data.height = resolution;
		texture_data.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT;
		texture_data.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT;
		var texture_RID = rendering_device.texture_create(texture_data, RDTextureView.new(), [heightmap_bytes]);
		
		var texture_uniform := RDUniform.new();
		texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE;
		texture_uniform.binding = 1;
		texture_uniform.add_id(texture_RID);
		
		var uniform_set := rendering_device.uniform_set_create([parameters_uniform, texture_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, visualisation_speed, visualisation_speed, 1);
		rendering_device.compute_list_end();
	
		rendering_device.submit();
		rendering_device.sync();
	
		var bytes: PackedByteArray = rendering_device.texture_get_data(texture_RID, 0);
		
		heightmap = Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, bytes);
		main.set_parameter("heightmap1", ImageTexture.create_from_image(heightmap));
		RenderingServer.force_draw();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(pipeline);
		rendering_device.free_rid(texture_RID);
		rendering_device.free_rid(parameters_RID);
	rendering_device.free_rid(compute_shader);

func cancel() -> void:
	hide();
	for ui: Control in settings_v_box_container.get_children():
		ui.queue_free();

func _on_visibility_changed() -> void:
	if main:
		main.visualisation_texture_rect.z_index = 1 if visible else 0;
		main.heightmap_texture_rect.z_index = 1 if visible else 0;
	if not visible:
		return;
	
	if compute_shader:
		main.rendering_device.free_rid(compute_shader);
	var shader_file := load("res://shaders/compute_shaders/hydraulic_erosion.glsl");
	compute_shader = main.rendering_device.shader_create_from_spirv(shader_file.get_spirv());
	
	var erosion_resolution_strings: Array[String] = [];
	for erosion_resolution: int in EROSION_RESOLUTIONS:
		erosion_resolution_strings.append(str(erosion_resolution) + "x" + str(erosion_resolution));
	var erosion_resolution_parameter: ParameterEnum = ParameterEnum.new("resolution", 2, erosion_resolution_strings);
	var erosion_resolution_UI: ParameterOptionButtonUI = UI.parameter_to_parameter_ui(erosion_resolution_parameter);
	settings_v_box_container.add_child(erosion_resolution_UI);
	erosion_resolution_UI.setup(erosion_resolution_parameter, func (option: int): resolution = EROSION_RESOLUTIONS[option]);
	
	settings_v_box_container.add_child(HSeparator.new());
	
	var drops_parameter: ParameterNumber = ParameterNumber.new("log_base_2_drops", 28, 20, 36, true, false, false);
	var drops_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(drops_parameter);
	settings_v_box_container.add_child(drops_UI);
	drops_UI.setup(drops_parameter, func (new_drops): log_base_2_drops = new_drops);
	
	var time_to_live_parameter: ParameterNumber = ParameterNumber.new("time_to_live", 8192, 2048, 32768, true, false, true);
	var time_to_live_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(time_to_live_parameter);
	settings_v_box_container.add_child(time_to_live_UI);
	time_to_live_UI.setup(time_to_live_parameter, func (new_time_to_live): time_to_live = new_time_to_live);

	var inertia_parameter: ParameterNumber = ParameterNumber.new("inertia", 0.4, 0.0, 1.0, false, false, false);
	var inertia_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(inertia_parameter);
	settings_v_box_container.add_child(inertia_UI);
	inertia_UI.setup(inertia_parameter, func (new_inertia): inertia = new_inertia);

	var min_slope_parameter: ParameterNumber = ParameterNumber.new("min_slope", 0.05, 0.0, 0.1, false, false, false);
	var min_slope_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(min_slope_parameter);
	settings_v_box_container.add_child(min_slope_UI);
	min_slope_UI.setup(min_slope_parameter, func (new_min_slope): min_slope = new_min_slope);

	var base_capacity_parameter: ParameterNumber = ParameterNumber.new("base_capacity", 8, 1, 32, false, false, true);
	var base_capacity_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(base_capacity_parameter);
	settings_v_box_container.add_child(base_capacity_UI);
	base_capacity_UI.setup(base_capacity_parameter, func (new_base_capacity): base_capacity = new_base_capacity);

	var deposition_rate_parameter: ParameterNumber = ParameterNumber.new("deposition_rate", 0.8, 0.0, 2.0, false, false, false);
	var deposition_rate_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(deposition_rate_parameter);
	settings_v_box_container.add_child(deposition_rate_UI);
	deposition_rate_UI.setup(deposition_rate_parameter, func (new_deposition_rate): deposition_rate = new_deposition_rate);

	var erosion_rate_parameter: ParameterNumber = ParameterNumber.new("erosion_rate", 0.8, 0.0, 2.0, false, false, false);
	var erosion_rate_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(erosion_rate_parameter);
	settings_v_box_container.add_child(erosion_rate_UI);
	erosion_rate_UI.setup(erosion_rate_parameter, func (new_erosion_rate): erosion_rate = new_erosion_rate);

	var gravity_parameter: ParameterNumber = ParameterNumber.new("gravity", 2, 0.125, 16, false, false, true);
	var gravity_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(gravity_parameter);
	settings_v_box_container.add_child(gravity_UI);
	gravity_UI.setup(gravity_parameter, func (new_gravity): gravity = new_gravity);

	var evaporation_rate_parameter: ParameterNumber = ParameterNumber.new("evaporation_rate", 0.05, 0, 0.5, false, false, false);
	var evaporation_rate_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(evaporation_rate_parameter);
	settings_v_box_container.add_child(evaporation_rate_UI);
	evaporation_rate_UI.setup(evaporation_rate_parameter, func (new_evaporation_rate): evaporation_rate = new_evaporation_rate);

	var radius_parameter: ParameterNumber = ParameterNumber.new("radius", 4, 1, 8, false, false, true);
	var radius_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(radius_parameter);
	settings_v_box_container.add_child(radius_UI);
	radius_UI.setup(radius_parameter, func (new_radius): radius = new_radius);
	
	settings_v_box_container.add_child(HSeparator.new());
	
	var visualisation_speed_parameter: ParameterNumber = ParameterNumber.new("visualisation_speed", 4, 2, 32, true, false, true);
	var visualisation_speed_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(visualisation_speed_parameter);
	settings_v_box_container.add_child(visualisation_speed_UI);
	visualisation_speed_UI.setup(visualisation_speed_parameter, func (new_visualisation_speed): visualisation_speed = new_visualisation_speed);
	
	var start_erosion_parameter: ParameterButton = ParameterButton.new("start_erosion");
	var start_erosion_UI: ParameterButtonUI = UI.parameter_to_parameter_ui(start_erosion_parameter);
	settings_v_box_container.add_child(start_erosion_UI);
	start_erosion_UI.setup(start_erosion_parameter, start_erosion);
	
	var cancel_parameter: ParameterButton = ParameterButton.new("cancel");
	var cancel_UI: ParameterButtonUI = UI.parameter_to_parameter_ui(cancel_parameter);
	settings_v_box_container.add_child(cancel_UI);
	cancel_UI.setup(cancel_parameter, cancel);
	
	resolution = 1024;
	time_to_live = 8192;
	inertia = 0.4;
	min_slope = 0.05;
	base_capacity = 8;
	deposition_rate = 0.8;
	erosion_rate = 0.8;
	gravity = 2;
	evaporation_rate = 0.1;
	radius = 2;
	log_base_2_drops = 28;
	visualisation_speed = 4;
