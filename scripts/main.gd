@tool
extends Node3D

@onready var heightmap_viewport: SubViewport = %HeightmapViewport;

@onready var terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %TerrainGenerationMethodVisualiser
@onready var heightmap_terrain_generation_method_visualiser: TerrainGenerationMethodVisualiser = %HeightmapTerrainGenerationMethodVisualiser

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		if terrain_generation_method_visualiser:
			terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
		if heightmap_terrain_generation_method_visualiser:
			heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;

func _ready() -> void:
	terrain_generation_method = null;
	
	await get_tree().process_frame
	
	terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
	heightmap_terrain_generation_method_visualiser.terrain_generation_method = terrain_generation_method;
	heightmap_terrain_generation_method_visualiser.albedo_is_heightmap = true;
	
	terrain_generation_method = preload("uid://bunfkxpwyox5q")
	terrain_generation_method_visualiser.circle = true;
	heightmap_terrain_generation_method_visualiser.circle = true;

func save_heightmap() -> void:
	const heightmap_save_path = "res://heightmap.png";
	
	var heightmap: Image = heightmap_viewport.get_texture().get_image();
	var error = heightmap.save_png(heightmap_save_path);
	print(error)


func _on_timer_timeout() -> void:
	terrain_generation_method_visualiser.seed = randf_range(1, 64)
