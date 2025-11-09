extends Resource
class_name TerrainGenerationMethod

const RESOLUTIONS: Array[int] = [256, 512, 1024, 2048, 4096];

@export var name: String;

@export var shader: Shader;
@export var unshaded_shader: Shader;

@export var explicit_generation: bool;

@export var shader_parameters: Array[ShaderParameter] = [];

@export var can_generate_in_chunks: bool;

var seed: float;

func log2(x: float) -> float:
	return log(x) / log(2);

func setup() -> void:
	assert(false);
	return;

func generate() -> Image:
	assert(false);
	return;

static func points_to_heightmap(points: Array[PackedFloat32Array]) -> Image:
	var resolution: int = points.size();
	var bytes: PackedByteArray = PackedByteArray();
	bytes.resize(resolution * resolution * 4);
	var byte_index: int = 0;
	for y: int in resolution:
		for x: int in resolution:
			bytes.encode_float(byte_index, points[y][x]);
			byte_index += 4;
	
	var heightmap: Image = Image.create_from_data(resolution, resolution, false, Image.FORMAT_RF, bytes);
	return heightmap;

static func heightmap_to_points(heightmap: Image) -> Array[PackedFloat32Array]:
	var resolution: int = heightmap.get_width();
	var bytes: PackedByteArray = heightmap.get_data();
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array();
		row.resize(resolution);
		points[row_index] = row;
	for point_index: int in resolution * resolution:
		var byte_index: int = point_index * 4;
		@warning_ignore("integer_division")
		points[point_index / resolution][posmod(point_index, resolution)] = bytes.decode_float(byte_index);
	return points;

static func points_to_slopemap_points(points: Array[PackedFloat32Array]) -> Array[PackedFloat32Array]:
	var resolution: int = points.size();
	var slopemap_points: Array[PackedFloat32Array] = [];
	slopemap_points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array();
		row.resize(resolution);
		slopemap_points[row_index] = row;
	
	for y: int in resolution:
		for x: int in resolution:
			var point: float = points[y][x];
			slopemap_points[y][x] = max(
				abs(point - points[posmod(y + 1, resolution)][x]),
				abs(point - points[posmod(y - 1, resolution)][x]),
				abs(point - points[y][posmod(x + 1, resolution)]),
				abs(point - points[y][posmod(x - 1, resolution)]),
			);
	
	return slopemap_points;

static func get_erosion_score(heightmap: Image) -> float:
	var points: Array[PackedFloat32Array] = heightmap_to_points(heightmap);
	var slopemap_points: Array[PackedFloat32Array] = points_to_slopemap_points(points);
	
	var total: float = 0;
	for row: PackedFloat32Array in slopemap_points:
		for point: float in row:
			total += point;
	var resolution: int = points.size();
	@warning_ignore("narrowing_conversion")
	var resolution_squared: int = pow(resolution, 2);
	var mean: float = total / resolution_squared;
	
	total = 0;
	for row: PackedFloat32Array in slopemap_points:
		for point: float in row:
			total += pow(mean - point, 2);
	var std_dev: float = sqrt(total / resolution_squared);
	
	assert(mean != 0);
	return std_dev / mean;

static func normalise_points(points: Array[PackedFloat32Array]) -> Array[PackedFloat32Array]:
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
