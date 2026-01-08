@tool
extends Node3D;
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

@onready var planes: Node = %Planes

@onready var water_mesh_instance_3d: MeshInstance3D = %WaterMeshInstance3D

func set_shader(new_shader: Shader, terrain_generation_method_specific_parameters: Array[Parameter]) -> void:
	for plane: MeshInstance3D in planes.get_children():
		plane.mesh.material.shader = new_shader; #.duplicate();
	for terrain_generation_method_specific_parameter: Parameter in terrain_generation_method_specific_parameters:
		set_planes_shader_parameter(terrain_generation_method_specific_parameter.name, terrain_generation_method_specific_parameter.value);
	apply_shader_options();

func set_planes_shader_parameter(name: String, value: Variant) -> void:
	for plane: MeshInstance3D in planes.get_children():
		plane.mesh.material.set_shader_parameter(name, value);

func remove_planes() -> void:
	for plane: MeshInstance3D in planes.get_children():
		plane.queue_free();

@export var terrain_generation_method: TerrainGenerationMethod:
	set(new_terrain_generation_method):
		terrain_generation_method = new_terrain_generation_method;
		if not terrain_generation_method:
			for plane: MeshInstance3D in planes.get_children():
				plane.mesh.material = ShaderMaterial.new();
		else:
			set_shader(terrain_generation_method.get_shader(unshaded), terrain_generation_method.parameters);

func get_specific_parameters() -> Array[Array]: # Arrar[Array[String], Array[Variant]]
	var specific_parameters = terrain_generation_method.parameters;
	var plane: MeshInstance3D = planes.get_child(0);
	if not plane:
		return [[], []];
	var specific_parameter_names: Array[String] = ["amplitude"];
	var specific_parameter_values: Array[Variant] = [plane.mesh.material.get_shader_parameter("amplitude")];
	for specific_parameter: Parameter in specific_parameters:
		var specific_parameter_name: String = specific_parameter.name;
		specific_parameter_names.append(specific_parameter_name);
		specific_parameter_values.append(plane.mesh.material.get_shader_parameter(specific_parameter_name));
	return [specific_parameter_names, specific_parameter_values];

func set_specific_parameters(prev_specific_parameter_names: Array[String], prev_specific_parameter_values: Array[Variant]) -> void:
	for specific_parameter_index: int in prev_specific_parameter_names.size():
		set_planes_shader_parameter(prev_specific_parameter_names[specific_parameter_index], prev_specific_parameter_values[specific_parameter_index]);

@export var unshaded: bool = false:
	set(new_unshaded):
		unshaded = new_unshaded;
		if terrain_generation_method:
			var prev_specific_parameters: Array[Array] = get_specific_parameters();
			set_shader(terrain_generation_method.get_shader(unshaded), terrain_generation_method.parameters);
			set_specific_parameters(prev_specific_parameters[0], prev_specific_parameters[1]);

func apply_shader_options() -> void:
	set_planes_shader_parameter("seed", seed);
	set_planes_shader_parameter("albedo_type", albedo_type);
	set_planes_shader_parameter("circle", circle);
	set_planes_shader_parameter("perturbate", perturbate);

@export var albedo_type: int = 0:
	set(new_albedo_type):
		albedo_type = new_albedo_type;
		if planes:
			set_planes_shader_parameter("albedo_type", albedo_type);

@export var circle: bool = false:
	set(new_circle):
		circle = new_circle;
		if planes:
			set_planes_shader_parameter("circle", circle);
		if water_mesh_instance_3d:
			water_mesh_instance_3d.mesh.material.set_shader_parameter("circle", circle);

@export var perturbate: bool = false:
	set(new_perturbate):
		perturbate = new_perturbate;
		if planes:
			set_planes_shader_parameter("perturbate", perturbate);

@export var seed: float = 1:
	set(new_seed):
		seed = new_seed;
		if planes:
			set_planes_shader_parameter("seed", seed);

var max_amplitude: float = 0;
@export var water_level: float = 0:
	set(new_water_level):
		water_level = new_water_level;
		water_mesh_instance_3d.visible = water_level != 0;
		water_mesh_instance_3d.position.y = max_amplitude * 0.5 * (water_level * 2 - 1);

func reset_to_one_plane(resolution: int) -> void:
	set_planes(1, [[resolution]]);

func set_planes(grid_resolution: int, resolutions: Array[Array]) -> void: # Array[Array[int]]
	assert(resolutions.size() == grid_resolution);
	var prev_plane: MeshInstance3D = planes.get_child(0);
	var prev_specific_parameters: Array[Array];
	var retain_prev_specific_parameters: bool = prev_plane and terrain_generation_method;
	if retain_prev_specific_parameters:
		prev_specific_parameters = get_specific_parameters();
	remove_planes();
	@warning_ignore("integer_division")
	var half_grid_resolution: int = grid_resolution / 2;
	var plane_offset: float = 64.0 / grid_resolution;
	var half_plane_offset: float = plane_offset / 2;
	for y: int in grid_resolution:
		for x: int in grid_resolution:
			var resolution: int = resolutions[y][x];
			if resolution == 0:
				continue;
			
			var new_plane: MeshInstance3D = MeshInstance3D.new();
			planes.add_child(new_plane);
			new_plane.owner = self;
			
			new_plane.mesh = PlaneMesh.new();
			var mesh_size: float = 64.0 / float(grid_resolution);
			new_plane.mesh.size = Vector2.ONE * mesh_size;
			
			if grid_resolution > 1:
				new_plane.position = Vector3((x - half_grid_resolution) * plane_offset + half_plane_offset, 0, (y - half_grid_resolution) * plane_offset + half_plane_offset);
			
			@warning_ignore("narrowing_conversion")
			var subdivides: int = resolution - 1;
			new_plane.mesh.subdivide_depth = subdivides;
			new_plane.mesh.subdivide_width = subdivides;
			
			new_plane.mesh.material = ShaderMaterial.new();
			if terrain_generation_method:
				new_plane.mesh.material.shader = terrain_generation_method.get_shader(unshaded);
				apply_shader_options();
			if retain_prev_specific_parameters:
				set_specific_parameters(prev_specific_parameters[0], prev_specific_parameters[1]);

func _ready() -> void:
	print("MAIN READY")
	remove_planes();
	#reset_to_one_plane(1024);
	set_planes(2, [[512, 512], [512, 512]])
	
	terrain_generation_method = null;
