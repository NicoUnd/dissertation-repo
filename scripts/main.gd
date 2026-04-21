@tool
extends Control

const HEIGHTMAP_RESOLUTIONS: Array[int] = [1024, 2048, 4096];
const RENDER_FRAMES_AMOUNTS: Array[int] = [1, 5, 20, 50, 100];
const RENDER_RESOLUTION_MULTIPLIERS: Array[float] = [1, 0.5, 0.25];

const HEIGHTMAP_BLENDING_SCENE: TerrainGenerationMethodNoise = preload("uid://uir8vm75yx0o");

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

@onready var capture_heightmap_resolution_menu: PopupMenu = %CaptureHeightmapResolutionMenu
@onready var normalise_heightmap_resolution_menu: PopupMenu = %NormaliseHeightmapResolutionMenu

@onready var visualisation_texture_rect: TextureRect = %VisualisationTextureRect
@onready var heightmap_texture_rect: TextureRect = %HeightmapTextureRect

@onready var vertices_label: Label = %VerticesLabel
@onready var erosion_score_label: Label = %ErosionScoreLabel

var rendering_device: RenderingDevice;

var last_resolution_of_plane: int = 1024;

var save_render_path: String;
var save_render_index: int;
var save_render_amount: int;
var save_render_resolution_multiplier: float;
var save_render_file_type_prefix: String;

var rg16_to_r32_compute_shader: RID;

var filled_UI: bool = false;
var generating_in_chunks: bool = false; # for explicit generation methods, can either generate in chunks or one plane, UI dialog will show this
func set_generating_in_chunks(new_generating_in_chunks: bool) -> void:
	generating_in_chunks = new_generating_in_chunks;
	if not generating_in_chunks:
		reset_to_one_plane(last_resolution_of_plane);
	ui.set_terrain_generation_method_specific_parameters(terrain_generation_method.get_parameters(generating_in_chunks));

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
				set_generating_in_chunks(false);
				
		if terrain_generation_method:
			if ui:
				ui.clear_terrain_generation_method_specific_parameters();
				filled_UI = false;
				
				terrain_generation_method_visualiser.set_planes_shader_parameter("amplitude", terrain_generation_method.default_amplitude);
				terrain_generation_method_visualiser.max_amplitude = terrain_generation_method.max_amplitude;
				heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("no_fade", true);
				heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("amplitude", 1);
				
				ui.set_terrain_generation_method_specific_parameters(terrain_generation_method.get_parameters(generating_in_chunks));
				
				filled_UI = true;
			if terrain_generation_method is TerrainGenerationMethodExplicit:
				terrain_generation_method.setup(rendering_device);
		if heightmap_viewport:
			heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
		ui.turn_off_perturbation();

var auto_randomise_seed: bool = false;

func _ready() -> void:
	terrain_generation_method = null;
	
	await get_tree().process_frame
	
	#print("OKAY")
	heightmap_terrain_generation_method_visualiser.albedo_type = 2; # heightmap
	heightmap_terrain_generation_method_visualiser.render_mode = 1;
	heightmap_terrain_generation_method_visualiser.reset_to_one_plane(512);
	#terrain_generation_method = preload("uid://bunfkxpwyox5q")
	
	rendering_device = RenderingServer.create_local_rendering_device();
	
	var shader_file := preload("res://shaders/compute_shaders/rg16_to_r32.glsl");
	rg16_to_r32_compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());

func update_heightmap() -> void:
	var heightmap: Image = capture_heightmap(256);
	heightmap_texture_rect.texture = ImageTexture.create_from_image(heightmap);

func generate(generate_button_string: String) -> void:
	if generating_in_chunks:
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
			if generate_button_string == "generate_GPU":
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
		last_resolution_of_plane = resolution;
		set_generating_in_chunks(false);
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
	elif parameter_name == "enable_chunks":
		assert(terrain_generation_method.can_generate_in_chunks);
		chunk_settings.show();
		return;
	elif parameter_name == "disable_chunks":
		assert(terrain_generation_method.can_generate_in_chunks);
		set_generating_in_chunks(false);
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
	if generating_in_chunks: # explicit generation of chunks produced multiple different-resolution heightmaps, not possible to capture
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
	#if terrain_generation_method is TerrainGenerationMethodExplicit and not explicit_chunk_generation:
		#var heightmap_texture = heightmap_terrain_generation_method_visualiser.planes.get_child(0).mesh.material.get_shader_parameter("heightmap");
		#if not heightmap_texture:
		#	return Image.new();
		#var heightmap: Image = heightmap_texture.get_image();
		#heightmap.resize(resolution, resolution);
		#return heightmap;
		# CANT DO THIS AS DOESNT WORK WITH PERTURBATION
	heightmap_viewport.size = Vector2(resolution, resolution);
	visualisation_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED;
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	heightmap_terrain_generation_method_visualiser.reset_to_one_plane(resolution);
	heightmap_terrain_generation_method_visualiser.albedo_type = 6; # heightmap encoded
	heightmap_terrain_generation_method_visualiser.set_planes_shader_parameter("no_fade", true);
	RenderingServer.force_draw();
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	#print(heightmap.get_format());
	heightmap = TerrainGenerationMethod.rg16_to_r32_GPU(rendering_device, rg16_to_r32_compute_shader, heightmap);
	#print(heightmap.get_format());
	heightmap.convert(Image.FORMAT_RF);
	heightmap_viewport.size = Vector2(512, 512);
	heightmap_terrain_generation_method_visualiser.reset_to_one_plane(512);
	heightmap_terrain_generation_method_visualiser.albedo_type = 2; # heightmap
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	visualisation_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;
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
	print("RESET TO ONE PLANE")
	
	#var erosion_scores: Array[float] = [];
	#for i: int in 20:
	#	randomise_seed();
	#	
	#	var heightmap: Image;
	#	if terrain_generation_method is TerrainGenerationMethodExplicit:
	#		terrain_generation_method.resolution = 1024;
	#		if terrain_generation_method.can_generate_GPU:
	#			heightmap = terrain_generation_method.generate_GPU(rendering_device, terrain_generation_method.resolution);
	#		else:
	#			heightmap = terrain_generation_method.generate_CPU(rendering_device, terrain_generation_method.resolution);
	#	else:
	#		heightmap = capture_heightmap(1024);
	#	
	#	await get_tree().process_frame;
	#	
	#	var erosion_score = TerrainGenerationMethod.get_erosion_score(heightmap, rendering_device);
	#	erosion_scores.append(erosion_score);
	#print("erosion scores: " + str(erosion_scores))
	#return;
	
	if terrain_generation_method:
		var heightmap_generation_times: Array[int] = [];
		
		statistics_progress_center_container.show();
		statistics_progress_bar.value = 0;
		statistics_progress_bar.max_value = NUMBER_OF_SAMPLES_TO_AVERAGE * HEIGHTMAP_RESOLUTIONS.size();
		print("AAA")
		await get_tree().process_frame;
		
		print("BBB")
		
		var original_resolution: int;
		if terrain_generation_method is TerrainGenerationMethodExplicit:
			original_resolution = terrain_generation_method.resolution;
		var average_erosion_score: float = 0;
		for heightmap_resolution: int in HEIGHTMAP_RESOLUTIONS:
			var average_time: float = 0;
			print(heightmap_resolution)
			for i: int in NUMBER_OF_SAMPLES_TO_AVERAGE:
				randomise_seed();
				print("STARTING SAMPLE TO AVERAGE " + str(i))
				
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
				
				print("GOT THE HEIGHTMAP")
				
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

func transition_to_heightmap_blending(heightmap: Image) -> void:
	var amplitude: float = terrain_generation_method_visualiser.planes.get_child(0).mesh.material.get_shader_parameter("amplitude");
	terrain_generation_method = HEIGHTMAP_BLENDING_SCENE;
	ui.terrain_generation_method_option_button.option_button.selected = TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS.find(HEIGHTMAP_BLENDING_SCENE);
	set_parameter("heightmap1", ImageTexture.create_from_image(heightmap));
	set_parameter("amplitude", amplitude);
	if ui.amplitude_slider:
		ui.amplitude_slider.h_slider.value = amplitude;

func _on_capture_heightmap_button_pressed() -> void:
	capture_heightmap_resolution_menu.show();

func _on_normalise_heightmap_button_pressed() -> void:
	normalise_heightmap_resolution_menu.show();

func _on_capture_heightmap_resolution_menu_id_pressed(id: int) -> void:
	if id == 5: # title of window, not real option
		return;
	var heightmap: Image = capture_heightmap(ErosionSettings.EROSION_RESOLUTIONS[id]);
	transition_to_heightmap_blending(heightmap);

func _on_normalise_heightmap_resolution_menu_id_pressed(id: int) -> void:
	if id == 5: # title of window, not real option
		return;
	var heightmap: Image = capture_heightmap(ErosionSettings.EROSION_RESOLUTIONS[id]);
	heightmap = TerrainGenerationMethod.normalise_heightmap(heightmap, rendering_device);
	transition_to_heightmap_blending(heightmap);
