@tool
extends Control

const HEIGHTMAP_RESOLUTIONS: Array[int] = [1024, 2048, 4096];

@onready var visualisation_viewport: SubViewport = %VisualisationViewport
@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var visualisation_camera_pivot: Node3D = %VisualisationCameraPivot

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@onready var timer: Timer = $Timer

@onready var ui: Control = %UI

@onready var save_heightmap_file_dialog: FileDialog = %SaveHeightmapFileDialog

@onready var generate_statistics_confirm_dialog: ConfirmationDialog = %GenerateStatisticsConfirmDialog
#@onready var statistics_accept_dialog: AcceptDialog = %StatisticsAcceptDialog

@onready var statistics_samples_label: Label = %StatisticsSamplesLabel
@onready var statistics_samples_h_slider: HSlider = %StatisticsSamplesHSlider

@onready var statistics_progress_center_container: CenterContainer = %StatisticsProgressCenterContainer
@onready var statistics_progress_bar: ProgressBar = %StatisticsProgressBar

var rendering_device: RenderingDevice;

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		if terrain_generation_method is TerrainGenerationMethodExplicit:
			terrain_generation_method.setdown(rendering_device);
		terrain_generation_method = new_terrain_generation_method;
		if terrain_generation_method_visualiser and heightmap_terrain_generation_method_visualiser:
			terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
			heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
			if terrain_generation_method:
				randomise_seed();
		if terrain_generation_method:
			if ui:
				ui.clear_terrain_generation_method_specific_parameters();
				
				if terrain_generation_method is TerrainGenerationMethodExplicit:
					var resolution_strings: Array[String] = [];
					for resoluton: int in TerrainGenerationMethodExplicit.RESOLUTIONS:
						resolution_strings.append(str(resoluton) + "x" + str(resoluton));
					ui.add_parameter(ParameterEnum.new("resolution", 2, resolution_strings), true);
				
				var amplitude: float = terrain_generation_method.default_amplitude;
				ui.add_parameter(ParameterNumber.new("amplitude", amplitude, terrain_generation_method.min_amplitude, terrain_generation_method.max_amplitude, false, false, true), true);
				terrain_generation_method_visualiser.mesh.material.set_shader_parameter("amplitude", amplitude);
				terrain_generation_method_visualiser.max_amplitude = terrain_generation_method.max_amplitude;
				
				ui.set_terrain_generation_method_specific_parameters(terrain_generation_method.parameters);
				if terrain_generation_method is TerrainGenerationMethodExplicit:
					if terrain_generation_method.GPU_accelerated:
						ui.add_parameter(ParameterButton.new("generate_CPU"), true);
						ui.add_parameter(ParameterButton.new("generate_GPU"), true);
					else:
						ui.add_parameter(ParameterButton.new("generate"), true);
			if terrain_generation_method is TerrainGenerationMethodExplicit:
				terrain_generation_method.setup(rendering_device);
		if heightmap_viewport:
			heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

var auto_randomise_seed: bool = false;

func _ready() -> void:
	terrain_generation_method = null;
	
	await get_tree().process_frame
	
	print("OKAY")
	heightmap_terrain_generation_method_visualiser.albedo_type = 1;
	#terrain_generation_method = preload("uid://bunfkxpwyox5q")
	
	rendering_device = RenderingServer.create_local_rendering_device();
	
	timer.start();

func set_parameter(parameter_name: String, parameter_value: Variant, is_terrain_generation_method_specific: bool=true) -> void:
	if parameter_name == "auto_randomise_seed":
		auto_randomise_seed = parameter_value;
		return;
	elif parameter_name == "resolution_of_plane":
		var resolution: int = TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS[parameter_value];
		var new_subdivide: int = int(resolution - 1);
		terrain_generation_method_visualiser.mesh.subdivide_width = new_subdivide;
		terrain_generation_method_visualiser.mesh.subdivide_depth = new_subdivide;
		return;
	elif parameter_name in ["albedo_type", "unshaded"]:
		terrain_generation_method_visualiser.set(parameter_name, parameter_value);
		return;
	elif parameter_name == "terrain_generation_method":
		terrain_generation_method = TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS[parameter_value];
		return;
	elif parameter_name.substr(0, "generate".length()) == "generate":
		assert(terrain_generation_method is TerrainGenerationMethodExplicit);
		var heightmap: Image;
		if parameter_name == "generate_GPU":
			assert(terrain_generation_method.GPU_accelerated);
			heightmap = terrain_generation_method.generate_GPU(rendering_device);
		else: # could be "generate" or "generate_CPU"
			heightmap = terrain_generation_method.generate_CPU(rendering_device);
		var heightmap_texture: ImageTexture = ImageTexture.create_from_image(heightmap);
		terrain_generation_method_visualiser.mesh.material.set_shader_parameter("heightmap", heightmap_texture);
		heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter("heightmap", heightmap_texture);
	
	if is_terrain_generation_method_specific:
		if terrain_generation_method is TerrainGenerationMethodExplicit and parameter_name != "amplitude":
			if parameter_name == "resolution":
				terrain_generation_method.set("resolution", terrain_generation_method.RESOLUTIONS[parameter_value]);
				return;
			terrain_generation_method.set(parameter_name, parameter_value);
		else:
			terrain_generation_method_visualiser.mesh.material.set_shader_parameter(parameter_name, parameter_value);
			heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter(parameter_name, parameter_value);
	else:
		if parameter_name == "seed":
			set_seed(parameter_value);
			return;
		terrain_generation_method_visualiser.set(parameter_name, parameter_value);
		if not parameter_name in ["circle", "water_level"]:
			heightmap_terrain_generation_method_visualiser.set(parameter_name, parameter_value);
	
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

#func save_heightmap() -> void:
	#const heightmap_save_path = "res://heightmap.png";
	#
	#var heightmap: Image = heightmap_viewport.get_texture().get_image();
	#var error = heightmap.save_png(heightmap_save_path);
	#print(error)

func set_seed(new_seed: float) -> void:
	terrain_generation_method_visualiser.seed = new_seed;
	heightmap_terrain_generation_method_visualiser.seed = new_seed;
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	
	terrain_generation_method.seed = new_seed;
	
	ui.seed_slider.h_slider.value = new_seed;

func randomise_seed() -> void:
	var new_seed = randf_range(1, 64);
	set_seed(new_seed);

func _on_timer_timeout() -> void:
	if auto_randomise_seed:
		randomise_seed();

func _on_save_heightmap_button_pressed() -> void:
	save_heightmap_file_dialog.show();
	save_heightmap_file_dialog.get_line_edit().text = "Heightmap.exr";

func capture_heightmap(resolution: int) -> Image:
	heightmap_viewport.size = Vector2(resolution, resolution);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw();
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	heightmap.convert(Image.FORMAT_RF);
	heightmap_viewport.size = Vector2(512, 512);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	return heightmap;

func _on_save_heightmap_file_dialog_confirmed() -> void:
	var heightmap_resolution: int = HEIGHTMAP_RESOLUTIONS[save_heightmap_file_dialog.get_selected_options()["Heightmap Resolution"]];
	var heightmap: Image = capture_heightmap(heightmap_resolution);
	
	var save_path = save_heightmap_file_dialog.current_dir.path_join(save_heightmap_file_dialog.get_line_edit().text);
	if heightmap.is_compressed():
		heightmap.decompress();
	if not save_path.ends_with(".exr"):
		save_path += ".exr";
	heightmap.save_exr(save_path, true);

func _on_generate_statistics_button_pressed() -> void:
	generate_statistics_confirm_dialog.show();

func generate_statistics() -> void:
	var NUMBER_OF_SAMPLES_TO_AVERAGE: int = int(statistics_samples_h_slider.value);
	
	if terrain_generation_method:
		var heightmap_generation_times: Array[int] = [];
		
		statistics_progress_center_container.show();
		statistics_progress_bar.value = 0;
		statistics_progress_bar.max_value = NUMBER_OF_SAMPLES_TO_AVERAGE * HEIGHTMAP_RESOLUTIONS.size();
		await get_tree().process_frame;
		
		var original_resolution: int;
		if terrain_generation_method is TerrainGenerationMethodExplicit:
			original_resolution = terrain_generation_method.resolution;
		var average_erosion_score: float = 0;
		for heightmap_resolution: int in HEIGHTMAP_RESOLUTIONS:
			var average_time: float = 0;
			for i: int in NUMBER_OF_SAMPLES_TO_AVERAGE:
				randomise_seed();
				
				var heightmap: Image;
				var start_time = Time.get_ticks_msec();
				if terrain_generation_method is TerrainGenerationMethodExplicit:
					terrain_generation_method.resolution = heightmap_resolution;
					if terrain_generation_method.GPU_accelerated:
						heightmap = terrain_generation_method.generate_GPU(rendering_device);
					else:
						heightmap = terrain_generation_method.generate_CPU(rendering_device);
				else:
					heightmap = capture_heightmap(heightmap_resolution);
				average_time += (Time.get_ticks_msec() - start_time) / float(NUMBER_OF_SAMPLES_TO_AVERAGE);
				
				average_erosion_score += TerrainGenerationMethod.get_erosion_score(heightmap, rendering_device) / float(NUMBER_OF_SAMPLES_TO_AVERAGE * HEIGHTMAP_RESOLUTIONS.size());
				#print("escore: " + str(TerrainGenerationMethod.get_erosion_score(heightmap)))
				
				statistics_progress_bar.value += 1;
				await get_tree().process_frame;
			heightmap_generation_times.append(int(average_time));
		print(heightmap_generation_times);
		statistics_progress_center_container.hide();
		if terrain_generation_method is TerrainGenerationMethodExplicit:
			terrain_generation_method.resolution = original_resolution;
		
		var parameters_string: String = "";
		for terrain_generation_method_specific_UI: Control in ui.terrain_generation_method_specific_UIs:
			if terrain_generation_method_specific_UI is ParameterCheckBoxUI or terrain_generation_method_specific_UI is ParameterOptionButtonUI or terrain_generation_method_specific_UI is ParameterSliderUI:
				var parameter_string: String = str(terrain_generation_method_specific_UI);
				if parameter_string.substr(0, "Amplitude".length()) != "Amplitude" and parameter_string.substr(0, "Resolution".length()) != "Resolution":
					parameters_string += "• " + str(terrain_generation_method_specific_UI) + "
					";
		
		var statistics_accept_dialog: AcceptDialog = AcceptDialog.new();
		add_child(statistics_accept_dialog);
		statistics_accept_dialog.title = "";
		statistics_accept_dialog.transient = false;
		#statistics_accept_dialog.mouse_passthrough_polygon = PackedVector2Array([Vector2(0, 0), Vector2(0, 0.1), Vector2(0.1, 0.1), Vector2(0.1, 0)]);
		statistics_accept_dialog.dialog_text = \
			terrain_generation_method.name.capitalize() + " with parameters:
			" + parameters_string + "
			Averages taken over " + str(NUMBER_OF_SAMPLES_TO_AVERAGE) + " samples.
			Time taken to generate heightmaps:
			• 1024x1024: " + str(heightmap_generation_times[0]) + "ms
			• 2048x2048: " + str(heightmap_generation_times[1]) + "ms
			• 4096x4096: " + str(heightmap_generation_times[2]) + "ms
			Can generate in chunks: " + ("✓" if terrain_generation_method.can_generate_in_chunks else "✗") + "
			Erosion score: " + str(average_erosion_score) + "
			";
		statistics_accept_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN;
		statistics_accept_dialog.show();

func _on_statistics_samples_h_slider_value_changed(value: float) -> void:
	statistics_samples_label.text = "Samples to Average Over (" + str(int(value)) + ")";
