@tool
extends Control

const HEIGHTMAP_RESOLUTIONS: Array[int] = [1024, 2048, 4096];

@onready var visualisation_viewport: SubViewport = %VisualisationViewport
@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@onready var timer: Timer = $VisualisationViewport/Timer

@onready var ui: Control = %UI

@onready var save_heightmap_file_dialog: FileDialog = %SaveHeightmapFileDialog

@onready var statistics_accept_dialog: AcceptDialog = %StatisticsAcceptDialog

@onready var statistics_progress_center_container: CenterContainer = %StatisticsProgressCenterContainer
@onready var statistics_progress_bar: ProgressBar = %StatisticsProgressBar

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		print("A")
		if terrain_generation_method_visualiser:
			print("B")
			terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
		if heightmap_terrain_generation_method_visualiser:
			heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
		if ui and terrain_generation_method:
			ui.set_shader_specific_parameters(terrain_generation_method.shader_parameters);
			if terrain_generation_method.explicit_generation:
				ui.add_shader_parameter(ShaderParameterButton.new("generate"), true);
		if heightmap_viewport:
			heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

var auto_randomise_seed: bool = false;

func _ready() -> void:
	terrain_generation_method = null;
	
	await get_tree().process_frame
	
	print("OKAY")
	heightmap_terrain_generation_method_visualiser.albedo_type = 1;
	#terrain_generation_method = preload("uid://bunfkxpwyox5q")
	
	timer.start();

func set_shader_parameter(shader_parameter_name: String, shader_parameter_value: Variant, is_shader_specific: bool=true) -> void:
	if shader_parameter_name == "auto_randomise_seed":
		auto_randomise_seed = shader_parameter_value;
		return;
	elif shader_parameter_name == "resolution_of_plane":
		var resolution: int = TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS[shader_parameter_value];
		var new_subdivide: int = int(resolution - 1);
		terrain_generation_method_visualiser.mesh.subdivide_width = new_subdivide;
		terrain_generation_method_visualiser.mesh.subdivide_depth = new_subdivide;
		return;
	elif shader_parameter_name in ["albedo_type", "unshaded"]:
		terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
		return;
	elif shader_parameter_name == "terrain_generation_method":
		terrain_generation_method = TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS[shader_parameter_value];
		return;
	elif shader_parameter_name == "generate":
		assert(terrain_generation_method.explicit_generation);
		var heightmap: Image = terrain_generation_method.generate(terrain_generation_method_visualiser.seed);
		var heightmap_texture: ImageTexture = ImageTexture.create_from_image(heightmap);
		terrain_generation_method_visualiser.mesh.material.set_shader_parameter("heightmap", heightmap_texture);
		heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter("heightmap", heightmap_texture);
	
	if is_shader_specific:
		if terrain_generation_method.explicit_generation and shader_parameter_name != "amplitude": # amplitude always in shader
			if shader_parameter_name == "resolution":
				terrain_generation_method.set("resolution", terrain_generation_method.RESOLUTIONS[shader_parameter_value]);
				return;
			terrain_generation_method.set(shader_parameter_name, shader_parameter_value);
		else:
			terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
			heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
	else:
		terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
		heightmap_terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
	
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

#func save_heightmap() -> void:
	#const heightmap_save_path = "res://heightmap.png";
	#
	#var heightmap: Image = heightmap_viewport.get_texture().get_image();
	#var error = heightmap.save_png(heightmap_save_path);
	#print(error)

func _on_timer_timeout() -> void:
	if auto_randomise_seed:
		var new_seed = randf_range(1, 64);
		terrain_generation_method_visualiser.seed = new_seed;
		heightmap_terrain_generation_method_visualiser.seed = new_seed;
		heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
		ui.seed_slider.h_slider.value = new_seed;

func _on_save_heightmap_button_pressed() -> void:
	save_heightmap_file_dialog.show();
	save_heightmap_file_dialog.get_line_edit().text = "Heightmap.exr";

func capture_heightmap(resolution: int) -> Image:
	heightmap_viewport.size = Vector2(resolution, resolution);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw();
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	heightmap_viewport.size = Vector2(512, 512);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
	return heightmap;

func _on_save_heightmap_file_dialog_confirmed() -> void:
	var heightmap_resolution: int = HEIGHTMAP_RESOLUTIONS[save_heightmap_file_dialog.get_selected_options()["Heightmap Resolution"]];
	var heightmap: Image = capture_heightmap(heightmap_resolution);
	
	var save_path = save_heightmap_file_dialog.current_dir.path_join(save_heightmap_file_dialog.get_line_edit().text);
	if heightmap.is_compressed():
		heightmap.decompress();
	heightmap.convert(Image.FORMAT_RF);
	if not save_path.ends_with(".exr"):
		save_path += ".exr";
	heightmap.save_exr(save_path, true);

func _on_generate_statistics_button_pressed() -> void:
	const NUMBER_OF_SAMPLES_TO_AVERAGE: int = 5;
	
	if terrain_generation_method:
		var heightmap_generation_times: Array[float] = [];
		
		statistics_progress_center_container.show();
		statistics_progress_bar.value = 0;
		statistics_progress_bar.max_value = NUMBER_OF_SAMPLES_TO_AVERAGE * HEIGHTMAP_RESOLUTIONS.size();
		await get_tree().process_frame;
		for heightmap_resolution: int in HEIGHTMAP_RESOLUTIONS:
			var average_time: float = 0;
			for i: int in NUMBER_OF_SAMPLES_TO_AVERAGE:
				var start_time = Time.get_ticks_msec();
				if terrain_generation_method.explicit_generation:
					terrain_generation_method.resolution = heightmap_resolution;
					terrain_generation_method.generate(1.0);
				else:
					capture_heightmap(heightmap_resolution);
				average_time += (Time.get_ticks_msec() - start_time) / float(NUMBER_OF_SAMPLES_TO_AVERAGE);
				
				statistics_progress_bar.value += 1;
				await get_tree().process_frame;
			heightmap_generation_times.append(average_time);
		print(heightmap_generation_times);
		statistics_progress_center_container.hide();
		
		statistics_accept_dialog.dialog_text = \
			terrain_generation_method.name.capitalize() + "
			Time taken to generate heightmaps:
			• 1024x1024: " + str(heightmap_generation_times[0]) + "ms
			• 2048x2048: " + str(heightmap_generation_times[1]) + "ms
			• 4096x4096: " + str(heightmap_generation_times[2]) + "ms
			Can generate in chunks: " + ("✓" if terrain_generation_method.can_generate_in_chunks else "✗") + "
			";
		statistics_accept_dialog.show();
