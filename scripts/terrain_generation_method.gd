extends Resource
class_name TerrainGenerationMethod

const RESOLUTIONS: Array[int] = [256, 512, 1024, 2048, 4096];

@export var name: String;

@export var shader: Shader;
@export var unshaded_shader: Shader;

@export var explicit_generation: bool;

@export var shader_parameters: Array[ShaderParameter] = [];

@export var can_generate_in_chunks: bool;

func log2(x: float) -> float:
	return log(x) / log(2);

func generate(seed: float) -> Image:
	assert(false);
	return;

func normalise_points(points: Array[PackedFloat32Array]) -> Array[PackedFloat32Array]:
	var min_value: float = 1;
	var max_value: float = 0;
	for row: PackedFloat32Array in points:
		for value: float in row:
			min_value = min(min_value, value);
			max_value = max(max_value, value);
	
	var range_values: float = max_value - min_value;
	assert(range_values != 0);
	
	var normalised_points: Array[PackedFloat32Array] = []
	for row: PackedFloat32Array in points:
		var normalised_row: PackedFloat32Array = PackedFloat32Array();
		for value: float in row:
			var normalised_value: float = (value - min_value) / range_values;
			normalised_row.append(normalised_value);
		normalised_points.append(normalised_row);
	
	return normalised_points;
