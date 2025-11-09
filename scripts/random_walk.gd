extends TerrainGenerationMethod
class_name RandomWalk

var resolution: int = 1024;

var iterations: int = 1024*1024/2

func setup() -> void:
	pass;

func generate() -> Image:
	const MOVES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT];
	
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution);
		points[row_index] = row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	var current_coord: Vector2i = Vector2i(random_number_generator.randi_range(0, resolution - 1), random_number_generator.randi_range(0, resolution - 1));
	points[current_coord.y][current_coord.x] = 1;
	
	for i: int in iterations:
		var valid_next_coords: Array[Vector2i] = [];
		for move: Vector2i in MOVES:
			var possible_next_coord: Vector2i = current_coord + move;
			if possible_next_coord.x >= 0 and possible_next_coord.x < resolution and possible_next_coord.y >= 0 and possible_next_coord.y < resolution:
				valid_next_coords.append(possible_next_coord);
		current_coord = valid_next_coords[random_number_generator.randi_range(0, valid_next_coords.size() - 1)];
		points[current_coord.y][current_coord.x] = 1;
	
	var heightmap: Image = points_to_heightmap(points);
	return heightmap;
