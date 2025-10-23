@tool
extends Control

@onready var visualisation_viewport: SubViewport = %VisualisationViewport
@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@onready var timer: Timer = $VisualisationViewport/Timer

@onready var ui: Control = %UI

@onready var save_heightmap_file_dialog: FileDialog = %SaveHeightmapFileDialog

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		print("A")
		if terrain_generation_method_visualiser:
			print("B")
			terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
		if heightmap_terrain_generation_method_visualiser:
			heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
		if ui:
			ui.set_shader_specific_parameters(terrain_generation_method.shader_parameters);
		if heightmap_viewport:
			heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

var auto_randomise_seed: bool = false;

func _ready() -> void:
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
	if is_shader_specific:
		terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
		heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
	else:
		terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
		heightmap_terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
	
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

func save_heightmap() -> void:
	const heightmap_save_path = "res://heightmap.png";
	
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	var error = heightmap.save_png(heightmap_save_path);
	print(error)

func _on_timer_timeout() -> void:
	if auto_randomise_seed:
		var new_seed = randf_range(1, 64);
		terrain_generation_method_visualiser.seed = new_seed;
		heightmap_terrain_generation_method_visualiser.seed = new_seed;
		heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;

func _on_save_heightmap_button_pressed() -> void:
	save_heightmap_file_dialog.visible = true;
	save_heightmap_file_dialog.get_line_edit().text = "Heightmap.jpg";

func _on_save_heightmap_file_dialog_confirmed() -> void:
	var heightmap_viewport_size: int = [1024, 2048, 4096][save_heightmap_file_dialog.get_selected_options()["Heightmap Resolution"]];
	heightmap_viewport.size = Vector2(heightmap_viewport_size, heightmap_viewport_size);
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw();
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	heightmap_viewport.size = Vector2(512, 512);
	
	var save_path = save_heightmap_file_dialog.current_dir.path_join(save_heightmap_file_dialog.get_line_edit().text);
	if not save_path.ends_with(".jpg"):
		save_path += ".jpg";
	heightmap.save_jpg(save_path)
	
	heightmap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE;
