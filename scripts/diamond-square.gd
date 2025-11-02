extends TerrainGenerationMethod
class_name DiamondSquare

var resolution: int = 1024;

var smoothness: float = 1;

var distribution: int = 0;

var wrap_around: bool = true;

var normalise: bool = false;

func get_square_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var square_average: float = 0;
	for square_corner_y: int in [y - half_step_size, y + half_step_size]:
		for square_corner_x: int in [x - half_step_size, x + half_step_size]:
			square_average += points[square_corner_y][square_corner_x] / 4;
			#if points[square_corner_y][square_corner_x] == 0:
			#	breakpoint;
	return square_average;

func get_diamond_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var diamond_total: float = 0;
	var num_of_corners_used: int = 0;
	for diamond_corner_y: int in [y - half_step_size, y + half_step_size]:
		if wrap_around:
			if diamond_corner_y < 0:
				diamond_corner_y += resolution;
			elif diamond_corner_y > resolution:
				diamond_corner_y -= resolution;
			# diamond_corner_y = posmod(diamond_corner_y, resolution + 1);
		elif diamond_corner_y > resolution or diamond_corner_y < 0:
			continue;
		diamond_total += points[diamond_corner_y][x];
		num_of_corners_used += 1;
		#if points[diamond_corner_y][x] == 0:
		#	breakpoint;
	for diamond_corner_x: int in [x - half_step_size, x + half_step_size]:
		if wrap_around:
			if diamond_corner_x < 0:
				diamond_corner_x += resolution;
			elif diamond_corner_x > resolution:
				diamond_corner_x -= resolution;
		elif diamond_corner_x > resolution or diamond_corner_x < 0:
			continue;
		diamond_total += points[y][diamond_corner_x];
		num_of_corners_used += 1;
		#if points[y][diamond_corner_x] == 0:
		#	breakpoint;
	
	assert(num_of_corners_used == 3 or num_of_corners_used == 4);
	return diamond_total / num_of_corners_used;

func random_offset(random_number_generator: RandomNumberGenerator, random_scale: float) -> float:
	if distribution == 0: # uniform
		return random_number_generator.randf_range(-0.5, 0.5) * random_scale
	else: # guassian
		return random_number_generator.randfn(0, 0.5 * random_scale);

func generate() -> Image:
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution + 1);
	for row_index: int in resolution + 1:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution + 1);
		points[row_index] = row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	points[0][0] = random_number_generator.randf();
	points[0][resolution] = random_number_generator.randf();
	points[resolution][0] = random_number_generator.randf();
	points[resolution][resolution] = random_number_generator.randf();
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		var half_step_size: int = step_size / 2;
		
		# diamond step
		var diamond_indecies: Array = range(half_step_size, resolution + 1, step_size);
		for y: int in diamond_indecies:
			for x: int in diamond_indecies:
				points[y][x] = clamp(get_square_average(points, x, y, half_step_size) + random_offset(random_number_generator, random_scale), 0, 1);
				#print("square_avg: " + str(points[y][x]))
		
		# square step
		for y: int in range(0, resolution + 1, half_step_size):
			for x: int in range(posmod(y + half_step_size, step_size), resolution + 1, step_size):
				points[y][x] = clamp(get_diamond_average(points, x, y, half_step_size) + random_offset(random_number_generator, random_scale), 0, 1);
				#print("diamond_avg: " + str(points[y][x]))
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	points.resize(resolution);
	for row: PackedFloat32Array in points:
		row.resize(resolution);
	
	if normalise:
		points = normalise_points(points);
	
	var heightmap: Image = points_to_heightmap(points);
	return heightmap;
