@tool
extends MeshInstance3D;
class_name TerrainGenerationMethodVisualiser;

const TERRAIN_GENERATION_METHODS: Array[TerrainGenerationMethod] = [
	preload("res://terrain_generation_methods/fractal_brownian_motion.tres"),
	preload("res://terrain_generation_methods/worley.tres"),
	preload("res://terrain_generation_methods/diamond-square.tres"),
	preload("res://terrain_generation_methods/random_walk.tres"),
	preload("res://terrain_generation_methods/diffusion_limited_aggregation.tres"),
	preload("res://terrain_generation_methods/heightmap_blending.tres"),
];

const PLANE_RESOLUTIONS: Array[int] = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

@onready var water_mesh_instance_3d: MeshInstance3D = %WaterMeshInstance3D

func set_shader(new_shader: Shader, terrain_generation_method_specific_parameters: Array[Parameter]) -> void:
	mesh.material.shader = new_shader; #.duplicate();
	for terrain_generation_method_specific_parameter: Parameter in terrain_generation_method_specific_parameters:
		mesh.material.set_shader_parameter(terrain_generation_method_specific_parameter.name, terrain_generation_method_specific_parameter.value);
	apply_shader_options();

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		if not terrain_generation_method:
			mesh.material = ShaderMaterial.new();
		else:
			set_shader(terrain_generation_method.get_shader(unshaded), terrain_generation_method.parameters);

@export var unshaded: bool = false:
	set(new_unshaded):
		unshaded = new_unshaded;
		if terrain_generation_method:
			var terrain_generation_method_specific_parameters = terrain_generation_method.parameters;
			var prev_terrain_generation_method_specific_parameter_names: Array[String] = [];
			var prev_terrain_generation_method_specific_parameter_values: Array[Variant] = [];
			for terrain_generation_method_specific_parameter: Parameter in terrain_generation_method_specific_parameters:
				var terrain_generation_method_specific_parameter_name: String = terrain_generation_method_specific_parameter.name;
				prev_terrain_generation_method_specific_parameter_names.append(terrain_generation_method_specific_parameter_name);
				prev_terrain_generation_method_specific_parameter_values.append(mesh.material.get_shader_parameter(terrain_generation_method_specific_parameter_name));
			set_shader(terrain_generation_method.get_shader(unshaded), terrain_generation_method_specific_parameters);
			for terrain_generation_method_specific_parameter_index: int in terrain_generation_method_specific_parameters.size():
				mesh.material.set_shader_parameter(prev_terrain_generation_method_specific_parameter_names[terrain_generation_method_specific_parameter_index], prev_terrain_generation_method_specific_parameter_values[terrain_generation_method_specific_parameter_index]);

func apply_shader_options() -> void:
	mesh.material.set_shader_parameter("seed", seed);
	mesh.material.set_shader_parameter("albedo_type", albedo_type);
	mesh.material.set_shader_parameter("circle", circle);
	mesh.material.set_shader_parameter("perturbate", perturbate);
	mesh.material.set_shader_parameter("grass_texture", grass_texture);
	mesh.material.set_shader_parameter("dirt_texture", dirt_texture);

@export var albedo_type: int = 0:
	set(new_albedo_type):
		albedo_type = new_albedo_type;
		mesh.material.set_shader_parameter("albedo_type", albedo_type);

@export var circle: bool = false:
	set(new_circle):
		circle = new_circle;
		mesh.material.set_shader_parameter("circle", circle);
		if water_mesh_instance_3d:
			water_mesh_instance_3d.mesh.material.set_shader_parameter("circle", circle);

@export var perturbate: bool = false:
	set(new_perturbate):
		perturbate = new_perturbate;
		mesh.material.set_shader_parameter("perturbate", perturbate);

@export var seed: float = 1:
	set(new_seed):
		seed = new_seed;
		mesh.material.set_shader_parameter("seed", seed);

@export var grass_texture: Texture2D = preload("uid://dql2oecs77v8i"):
	set(new_grass_texture):
		grass_texture = new_grass_texture;
		mesh.material.set_shader_parameter("grass_texture", grass_texture);

@export var dirt_texture: Texture2D = preload("uid://bwrwr1amdu6se"):
	set(new_dirt_texture):
		dirt_texture = new_dirt_texture;
		mesh.material.set_shader_parameter("dirt_texture", dirt_texture);

var max_amplitude: float = 0;
@export var water_level: float = 0:
	set(new_water_level):
		water_level = new_water_level;
		water_mesh_instance_3d.visible = water_level != 0;
		water_mesh_instance_3d.position.y = max_amplitude * 0.5 * (water_level * 2 - 1);

func _ready() -> void:
	print("MAIN READY")
	mesh = PlaneMesh.new();
	mesh.size = Vector2(64, 64);
	mesh.subdivide_depth = 1027;
	mesh.subdivide_width = 1027;
	mesh.material = ShaderMaterial.new();
	
	terrain_generation_method = null;
