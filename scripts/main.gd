@tool
extends Control

const HEIGHTMAP_RESOLUTIONS: Array[int] = [1024, 2048, 4096];
const RENDER_FRAMES_AMOUNTS: Array[int] = [1, 5, 20, 50, 100];
const RENDER_RESOLUTION_MULTIPLIERS: Array[float] = [1, 0.5, 0.25];

@onready var visualisation_viewport: SubViewport = %VisualisationViewport
@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var visualisation_camera_pivot: Node3D = %VisualisationCameraPivot
@onready var visualisation_perspective_camera_3d: Camera3D = %VisualisationPerspectiveCamera3D
@onready var visualisation_orthographic_camera_3d: Camera3D = %VisualisationOrthographicCamera3D

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@onready var ui: Control = %UI

@onready var chunk_settings: Control = %ChunkSettings
@onready var erosion_settings: ErosionSettings = %ErosionSettings

@onready var save_heightmap_file_dialog: FileDialog = %SaveHeightmapFileDialog
@onready var save_render_file_dialog: FileDialog = %SaveRenderFileDialog

@onready var generate_statistics_confirm_dialog: ConfirmationDialog = %GenerateStatisticsConfirmDialog
#@onready var statistics_accept_dialog: AcceptDialog = %StatisticsAcceptDialog

@onready var statistics_samples_label: Label = %StatisticsSamplesLabel
@onready var statistics_samples_h_slider: HSlider = %StatisticsSamplesHSlider

@onready var statistics_progress_center_container: CenterContainer = %StatisticsProgressCenterContainer
@onready var statistics_progress_bar: ProgressBar = %StatisticsProgressBar

@onready var visualisation_texture_rect: TextureRect = %VisualisationTextureRect
@onready var heightmap_texture_rect: TextureRect = %HeightmapTextureRect

@onready var vertices_label: Label = $MarginContainer/VerticesLabel

var rendering_device: RenderingDevice;

var last_resolution_of_plane: int = 1024;

var save_render_path: String;
var save_render_index: int;
var save_render_amount: int;
var save_render_resolution_multiplier: float;
var save_render_file_type_prefix: String;

var filled_UI: bool = false;
var explicit_chunk_generation: bool = false; # for explicit generation methods, can either generate in chunks or one plane, UI dialog will show this
func set_explicit_chunk_generation_and_update_UI_and_planes(new_explicit_chunk_generation: bool) -> void:
	explicit_chunk_generation = new_explicit_chunk_generation;
	if not explicit_chunk_generation:
		reset_to_one_plane(last_resolution_of_plane);
	if not filled_UI: # bottom buttons won't be the generate buttons
		return;
	var generate_chunks_string: String = "chunks_" if explicit_chunk_generation else "";
	if terrain_generation_method is TerrainGenerationMethodExplicit:
		if terrain_generation_method.can_generate_GPU:
			ui.pop_terrain_generation_method_specific_parameter();
		if terrain_generation_method.can_generate_CPU:
			ui.pop_terrain_generation_method_specific_parameter();
			ui.add_parameter(ParameterButton.new("generate_" + generate_chunks_string + "CPU"), true);
		if terrain_generation_method.can_generate_GPU:
			ui.add_parameter(ParameterButton.new("generate_" + generate_chunks_string + "GPU"), true);

func reset_to_one_plane(resolution: int) -> void:
	terrain_generation_method_visualiser.reset_to_one_plane(resolution);
	update_verticies(resolution * resolution);

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		filled_UI = false;
		if terrain_generation_method is TerrainGenerationMethodExplicit:
			terrain_generation_method.setdown(rendering_device);
		terrain_generation_method = new_terrain_generation_method;
		if terrain_generation_method_visualiser and heightmap_terrain_generation_method_visualiser:
			terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
			heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
			if terrain_generation_method:
				randomise_seed();
				set_explicit_chunk_generation_and_update_UI_and_planes(false);
				
		if terrain_generation_method:
			if ui:
				ui.clear_terrain_generation_method_specific_parameters();
				filled_UI = false;
				
				if terrain_generation_method is TerrainGenerationMethodExplicit:
					var resolution_strings: Array[String] = [];
					for resoluton: int in TerrainGenerationMethodExplicit.RESOLUTIONS:
						resolution_strings.append(str(resoluton) + "x" + str(resoluton));
					ui.add_parameter(ParameterEnum.new("resolution", 5, resolution_strings), true);
				
				var amplitude: float = terrain_generation_method.default_amplitude;
				ui.add_parameter(ParameterNumber.new("amplitude", amplitude, terrain_generation_method.min_amplitude, terrain_generation_method.max_amplitude, false, false, true), true);
				#terrain_generation_method_visualiser.set_planes_shader_parameter("amplitude", amplitude);
				terrain_generation_method_visualiser.max_amplitude = terrain_generation_method.max_amplitude;
				heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("no_fade", true);
				#heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("amplitude", 1);
				
				ui.set_terrain_generation_method_specific_parameters(terrain_generation_method.parameters);
				if terrain_generation_method.can_generate_in_chunks:
					ui.add_parameter(ParameterButton.new("chunk_settings"), true);
				if terrain_generation_method is TerrainGenerationMethodExplicit:
					if terrain_generation_method.can_generate_CPU:
						ui.add_parameter(ParameterButton.new("generate_CPU"), true);
					if terrain_generation_method.can_generate_GPU:
						ui.add_parameter(ParameterButton.new("generate_GPU"), true);
				filled_UI = true;
			if terrain_generation_method is TerrainGenerationMethodExplicit:
				terrain_generation_method.setup(rendering_device);
		if heightmap_viewport:
			heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

var auto_randomise_seed: bool = false;

func _ready() -> void:
	terrain_generation_method = null;
	
	await get_tree().process_frame
	
	#print("OKAY")
	heightmap_terrain_generation_method_visualiser.albedo_type = 2;
	heightmap_terrain_generation_method_visualiser.render_mode = 1;
	heightmap_terrain_generation_method_visualiser.reset_to_one_plane(512);
	#terrain_generation_method = preload("uid://bunfkxpwyox5q")
	
	heightmap_viewport.use_hdr_2d
	
	rendering_device = RenderingServer.create_local_rendering_device();

func generate(generate_button_string: String) -> void:
	if explicit_chunk_generation:
		var planes: Array = terrain_generation_method_visualiser.planes.get_children();
		@warning_ignore("narrowing_conversion")
		var chunk_grid_resolution: int = sqrt(planes.size());
		var blank_heightmap: Texture2D = Texture2D.new();
		heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("heightmap", Texture2D.new());
		for plane_index: int in planes.size():
			#print("GENERATING FOR PLANE")
			var plane: Chunk = planes[plane_index];
			var resolution: int = plane.mesh.subdivide_depth + 2;
			@warning_ignore("integer_division")
			#var chunk_coord: Vector2i = Vector2i(plane_index / chunk_grid_resolution, plane_index % chunk_grid_resolution);
			var heightmap: Image;
			if generate_button_string == "generate_chunks_GPU":
				assert(terrain_generation_method.can_generate_GPU);
				heightmap = terrain_generation_method.generate_GPU(rendering_device, resolution, plane.coord);
			else: # "generate_chunks_CPU"
				assert(terrain_generation_method.can_generate_CPU);
				heightmap = terrain_generation_method.generate_CPU(rendering_device, resolution, plane.coord);
			var heightmap_texture: ImageTexture = ImageTexture.create_from_image(heightmap);
			plane.mesh.material.set_shader_parameter("heightmap", heightmap_texture);
			if planes.size() == 1:
				heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("heightmap", heightmap_texture);
	else:
		var heightmap: Image;
		if generate_button_string == "generate_GPU":
			assert(terrain_generation_method.can_generate_GPU);
			heightmap = terrain_generation_method.generate_GPU(rendering_device, terrain_generation_method.resolution);
		else: # "generate_CPU"
			assert(terrain_generation_method.can_generate_CPU);
			heightmap = terrain_generation_method.generate_CPU(rendering_device, terrain_generation_method.resolution);
		var heightmap_texture: ImageTexture = ImageTexture.create_from_image(heightmap);
		terrain_generation_method_visualiser.set_planes_shader_parameter("heightmap", heightmap_texture);
		heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("heightmap", heightmap_texture);

func update_verticies(vertices: int) -> void:
	var vertices_string: String = str(vertices);
	var formatted_vertices: String = "";
	var last_character_index: int = vertices_string.length() - 1;
	var count: int = 0;
	for index: int in range(last_character_index, -1, -1):
		if count > 0 and count % 3 == 0:
			formatted_vertices = "," + formatted_vertices;
		formatted_vertices = vertices_string[index] + formatted_vertices;
		count += 1;
	vertices_label.text = "Vertices: " + formatted_vertices;

func set_parameter(parameter_name: String, parameter_value: Variant=null, is_terrain_generation_method_specific: bool=true) -> void:
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	if parameter_name == "auto_randomise_seed":
		auto_randomise_seed = parameter_value;
		return;
	elif parameter_name == "resolution_of_plane":
		var resolution: int = TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS[parameter_value];
		reset_to_one_plane(resolution);
		last_resolution_of_plane = resolution;
		return;
	elif parameter_name in ["albedo_type", "render_mode"]:
		terrain_generation_method_visualiser.set(parameter_name, parameter_value);
		return;
	elif parameter_name == "camera_type":
		visualisation_texture_rect.set_camera_type(parameter_value);
		return;
	elif parameter_name in ["rotation_type", "rotation_speed"]:
		visualisation_texture_rect.set(parameter_name, parameter_value);
		return;
	elif parameter_name == "terrain_generation_method":
		terrain_generation_method = TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS[parameter_value];
		return;
	elif parameter_name.substr(0, "generate".length()) == "generate":
		assert(terrain_generation_method is TerrainGenerationMethodExplicit);
		generate(parameter_name);
		return;
	elif parameter_name == "chunk_settings":
		assert(terrain_generation_method.can_generate_in_chunks);
		chunk_settings.show();
		return;
	elif parameter_name in ["circle", "water_level"]:
		terrain_generation_method_visualiser.set(parameter_name, parameter_value);
		return;
	elif parameter_name == "fog_distance":
		visualisation_viewport.world_3d.environment.fog_depth_end = parameter_value;
		return;
	
	if is_terrain_generation_method_specific:
		if terrain_generation_method is TerrainGenerationMethodExplicit and parameter_name != "amplitude":
			if parameter_name == "resolution":
				terrain_generation_method.resolution = terrain_generation_method.RESOLUTIONS[parameter_value];
				if explicit_chunk_generation:
					set_explicit_chunk_generation_and_update_UI_and_planes(false);
				return;
			terrain_generation_method.set(parameter_name, parameter_value);
		else:
			#print("SETTING: " + parameter_name + " to " + str(parameter_value));
			terrain_generation_method_visualiser.set_planes_shader_parameter(parameter_name, parameter_value);
			heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter(parameter_name, parameter_value);
	else:
		if parameter_name == "seed":
			set_seed(parameter_value);
			return;
		terrain_generation_method_visualiser.set(parameter_name, parameter_value);
		heightmap_terrain_generation_method_visualiser.set(parameter_name, parameter_value);

func update_chunked_specific_parameters() -> void:
	ui.update_chunked_specific_parameters(terrain_generation_method.chunked_specific_parameters);

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
	
	if terrain_generation_method:
		terrain_generation_method.seed = new_seed;
	
	ui.seed_slider.h_slider.value = new_seed;

func randomise_seed() -> void:
	var new_seed = randf_range(1, 64);
	set_seed(new_seed);

func _on_auto_randomise_seed_timer_timeout() -> void:
	if auto_randomise_seed:
		randomise_seed();

func _on_capture_render_timer_timeout() -> void:
	if save_render_index < save_render_amount:
		save_render(save_render_path + str(save_render_index) + save_render_file_type_prefix);
		save_render_index += 1;

func _on_save_heightmap_button_pressed() -> void:
	if explicit_chunk_generation: # explicit generation of chunks produced multiple different-resolution heightmaps, not possible to capture
		return;
	save_heightmap_file_dialog.show();
	save_heightmap_file_dialog.get_line_edit().text = "Heightmap.exr";

func _on_save_render_button_pressed() -> void:
	save_render_file_dialog.show();
	save_render_file_dialog.get_line_edit().text = "Render.png";

func _on_save_render_file_dialog_confirmed() -> void:
	save_render_resolution_multiplier = RENDER_RESOLUTION_MULTIPLIERS[save_render_file_dialog.get_selected_options()["Resolution "]];
	save_render_amount = RENDER_FRAMES_AMOUNTS[save_render_file_dialog.get_selected_options()["Number of Frames (4 per second) "]];
	save_render_index = 0;
	save_render_path = save_render_file_dialog.current_dir.path_join(save_render_file_dialog.get_line_edit().text);
	save_render_file_type_prefix = ".png";
	if save_render_path.ends_with(".png") or save_render_path.ends_with(".jpg"):
		if save_render_path.ends_with(".jpg"):
			save_render_file_type_prefix = ".jpg";
		save_render_path = save_render_path.substr(0, save_render_path.length() - 4);

func save_render(save_path: String) -> void:
	var render: Image = visualisation_viewport.get_texture().get_image();
	if render.is_compressed():
		render.decompress();
	var new_render_size: Vector2i = render.get_size() * save_render_resolution_multiplier;
	render.resize(new_render_size.x, new_render_size.y, Image.INTERPOLATE_BILINEAR);
	if save_render_file_type_prefix == ".png":
		render.save_png(save_path);
	else:
		render.save_jpg(save_path, 1);

func capture_heightmap(resolution: int) -> Image:
	if terrain_generation_method is TerrainGenerationMethodExplicit and not explicit_chunk_generation:
		var heightmap_texture = heightmap_terrain_generation_method_visualiser.planes.get_child(0).mesh.material.get_shader_parameter("heightmap");
		if not heightmap_texture:
			return Image.new();
		var heightmap: Image = heightmap_texture.get_image();
		heightmap.resize(resolution, resolution);
		return heightmap;
	heightmap_viewport.size = Vector2(resolution, resolution);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw();
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	heightmap.convert(Image.FORMAT_RF);
	heightmap_viewport.size = Vector2(512, 512);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	return heightmap;

func _on_save_heightmap_file_dialog_confirmed() -> void:
	var heightmap_resolution: int = HEIGHTMAP_RESOLUTIONS[save_heightmap_file_dialog.get_selected_options()["Heightmap Resolution "]];
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
	
	reset_to_one_plane(last_resolution_of_plane);
	
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
					if terrain_generation_method.can_generate_GPU:
						heightmap = terrain_generation_method.generate_GPU(rendering_device, terrain_generation_method.resolution);
					else:
						heightmap = terrain_generation_method.generate_CPU(rendering_device, terrain_generation_method.resolution);
				else:
					heightmap = capture_heightmap(heightmap_resolution);
				average_time += (Time.get_ticks_msec() - start_time) / float(NUMBER_OF_SAMPLES_TO_AVERAGE);
				
				var erosion_score = TerrainGenerationMethod.get_erosion_score(heightmap, rendering_device);
				average_erosion_score += erosion_score;
				print("erosion score: " + str(erosion_score))
				
				var heightmap_texture: ImageTexture = ImageTexture.create_from_image(heightmap);
				terrain_generation_method_visualiser.set_planes_shader_parameter("heightmap", heightmap_texture);
				
				statistics_progress_bar.value += 1;
				await get_tree().process_frame;
			heightmap_generation_times.append(int(average_time));
		#print(heightmap_generation_times);
		statistics_progress_center_container.hide();
		average_erosion_score /= HEIGHTMAP_RESOLUTIONS.size() * NUMBER_OF_SAMPLES_TO_AVERAGE;
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

func _on_erode_heightmap_button_pressed() -> void:
	if terrain_generation_method:
		erosion_settings.show();
