#@tool
extends Control

@onready var visualisation_viewport: SubViewport = %VisualisationViewport
@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@onready var timer: Timer = $VisualisationViewport/Timer

@onready var ui: Control = %UI

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

var auto_randomise_seed: bool = false;

func _ready() -> void:
	await get_tree().process_frame
	
	print("OKAY")
	heightmap_terrain_generation_method_visualiser.albedo_is_heightmap = true;
	terrain_generation_method = preload("uid://bunfkxpwyox5q")
	
	timer.start();

func set_shader_parameter(shader_parameter_name: String, shader_parameter_value: Variant, is_shader_specific: bool=true) -> void:
	if shader_parameter_name == "auto_randomise_seed":
		auto_randomise_seed = shader_parameter_value;
		return;
	elif shader_parameter_name == "resolution_of_plane":
		var new_subdivide: int = int(shader_parameter_value - 1);
		terrain_generation_method_visualiser.mesh.subdivide_width = new_subdivide;
		terrain_generation_method_visualiser.mesh.subdivide_depth = new_subdivide;
		return;
	elif shader_parameter_name in ["albedo_is_heightmap", "unshaded"]:
		terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
		return;
	if is_shader_specific:
		terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
		heightmap_terrain_generation_method_visualiser.mesh.material.set_shader_parameter(shader_parameter_name, shader_parameter_value);
	else:
		terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);
		heightmap_terrain_generation_method_visualiser.set(shader_parameter_name, shader_parameter_value);

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
