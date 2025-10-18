@tool
extends MeshInstance3D;
class_name TerrainGenerationMethodVisualiser;

func set_shader(new_shader: Shader, shader_specific_default_parameters: Array[DefaultShaderParameter]) -> void:
	mesh = PlaneMesh.new();
	mesh.size = Vector2(64, 64);
	mesh.subdivide_depth = 1027;
	mesh.subdivide_width = 1027;
	
	mesh.material = ShaderMaterial.new();
	mesh.material.shader = new_shader.duplicate();
	for shader_specific_default_parameter: DefaultShaderParameter in shader_specific_default_parameters:
		mesh.material.set_shader_parameter(shader_specific_default_parameter.name, shader_specific_default_parameter.value);
	apply_shader_options();

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		if not terrain_generation_method:
			mesh.material = ShaderMaterial.new();
		else:
			set_shader(terrain_generation_method.unshaded_shader if unshaded else terrain_generation_method.shader, terrain_generation_method.default_shader_parameters);

@export var unshaded: bool = false:
	set(new_unshaded):
		unshaded = new_unshaded;
		if terrain_generation_method:
			set_shader(terrain_generation_method.unshaded_shader if unshaded else terrain_generation_method.shader, terrain_generation_method.default_shader_parameters);

func apply_shader_options() -> void:
	mesh.material.set_shader_parameter("seed", seed);
	print("APPLYING SHADER OPTIONS, albedo_is_heightmap is " + str(albedo_is_heightmap))
	print("albedo_is_heightmap is before " + str(mesh.material.get_shader_parameter("albedo_is_heightmap")))
	mesh.material.set_shader_parameter("albedo_is_heightmap", albedo_is_heightmap);
	print("albedo_is_heightmap is after " + str(mesh.material.get_shader_parameter("albedo_is_heightmap")))
	mesh.material.set_shader_parameter("circle", circle);
	mesh.material.set_shader_parameter("grass_texture", grass_texture);

@export var albedo_is_heightmap: bool = false:
	set(new_albedo_is_heightmap):
		albedo_is_heightmap = new_albedo_is_heightmap;
		mesh.material.set_shader_parameter("albedo_is_heightmap", albedo_is_heightmap);

@export var circle: bool = false:
	set(new_circle):
		circle = new_circle;
		mesh.material.set_shader_parameter("circle", circle);

@export var seed: float = 1:
	set(new_seed):
		seed = new_seed;
		mesh.material.set_shader_parameter("seed", seed);

@export var grass_texture: Texture2D = preload("uid://bwrwr1amdu6se"):
	set(new_grass_texture):
		grass_texture = new_grass_texture;
		mesh.material.set_shader_parameter("grass_texture", grass_texture);

func _ready() -> void:
	print("MAIN READY")
	mesh = PlaneMesh.new();
	mesh.size = Vector2(64, 64);
	mesh.subdivide_depth = 1027;
	mesh.subdivide_width = 1027;
	mesh.material = ShaderMaterial.new();
	
	terrain_generation_method = null;
