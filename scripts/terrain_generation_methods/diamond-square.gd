@tool
extends TerrainGenerationMethodExplicit;
class_name DiamondSquare;

var smoothness: float;

var distribution: int;

var chunked: bool;
var border_diamond_average_type: int:
	set(new_border_diamond_average_type):
		border_diamond_average_type = new_border_diamond_average_type;
		chunked = false;
var chunked_border_diamond_average_type: int:
	set(new_chunked_border_diamond_average_type):
		chunked_border_diamond_average_type = new_chunked_border_diamond_average_type;
		chunked = true;
		normalise = false;

var normalise: bool;

var compute_shader;

func get_square_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int) -> float:
	var square_average: float = 0;
	for square_corner_y: int in [y - half_step_size, y + half_step_size]:
		for square_corner_x: int in [x - half_step_size, x + half_step_size]:
			square_average += points[square_corner_y][square_corner_x] / 4;
			#if points[square_corner_y][square_corner_x] == 0:
			#	breakpoint;
	return square_average;

func get_diamond_average(points: Array[PackedFloat32Array], x: int, y: int, half_step_size: int, resolution: int) -> float:
	var diamond_total: float = 0;
	var num_of_corners_used: int = 0;
	for diamond_corner_y: int in [y - half_step_size, y + half_step_size]:
		if (border_diamond_average_type == 2 and y in [0, resolution]) or (border_diamond_average_type in [1, 2] and (diamond_corner_y < 0 or diamond_corner_y > resolution)):
			continue;
		if diamond_corner_y < 0:
			diamond_corner_y += resolution + 1;
		elif diamond_corner_y > resolution:
			diamond_corner_y -= resolution + 1;
		# diamond_corner_y = posmod(diamond_corner_y, resolution + 1);
		diamond_total += points[diamond_corner_y][x];
		num_of_corners_used += 1;
	for diamond_corner_x: int in [x - half_step_size, x + half_step_size]:
		if (border_diamond_average_type == 2 and x in [0, resolution]) or (border_diamond_average_type in [1, 2] and (diamond_corner_x < 0 or diamond_corner_x > resolution)):
			continue;
		if diamond_corner_x < 0:
			diamond_corner_x += resolution + 1;
		elif diamond_corner_x > resolution:
			diamond_corner_x -= resolution + 1;
		# diamond_corner_x = posmod(diamond_corner_x, resolution + 1);
		diamond_total += points[y][diamond_corner_x];
		num_of_corners_used += 1;
	
	assert(num_of_corners_used in [2, 3, 4]);
	return diamond_total / num_of_corners_used;

func random_offset(random_number_generator: RandomNumberGenerator, random_scale: float) -> float:
	if distribution == 0: # uniform
		return random_number_generator.randf_range(-0.5, 0.5) * random_scale
	else: # guassian
		return random_number_generator.randfn(0, 0.5 * random_scale);

func world_pos_random_offset(world_pos: Vector2, random_scale: float) -> float:
	if distribution == 0: # uniform
		#print("world_pos_random_offset returning: " + str((world_pos_randf(seed, world_pos) - 0.5) * random_scale));
		return (world_pos_randf(seed, world_pos) - 0.5) * random_scale;
	else: # guassian
		return world_pos_randfn(seed, world_pos, 0, 0.5 * random_scale);

func setup(rendering_device: RenderingDevice) -> void:
	#rendering_device = RenderingServer.create_local_rendering_device();
	
	var shader_file := load("res://shaders/compute_shaders/diamond-square.glsl");
	compute_shader = rendering_device.shader_create_from_spirv(shader_file.get_spirv());

func setdown(rendering_device: RenderingDevice) -> void:
	rendering_device.free_rid(compute_shader);
	#rendering_device.free();

static func uv_to_world_pos(resolution: int, chunk_coord: Vector2i, uv: Vector2i) -> Vector2:
	return (Vector2(uv) / float(resolution) + Vector2(chunk_coord)) * 4096; # * 4096 to get distance for rand()

static func world_pos_randf(seed: float, world_pos: Vector2i) -> float:
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed + hash(world_pos));
	return random_number_generator.randf();

static func world_pos_randfn(seed: float, world_pos: Vector2i, mean: float, std_dev: float) -> float:
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed + hash(world_pos));
	return random_number_generator.randfn(mean, std_dev);

func get_border_diamond_average_type_for_GPU() -> int:
	const conversion: Dictionary[int, int] = {0: 3, 1: 2};
	if not chunked:
		return border_diamond_average_type;
	return conversion[chunked_border_diamond_average_type];

func generate_CPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image:
	var points: Array[PackedFloat32Array] = [];
	points.resize(resolution + 1);
	for row_index: int in resolution + 1:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution + 1);
		points[row_index] = row;
	
	if chunked:
		border_diamond_average_type = 2;
	
	#var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	#random_number_generator.seed = hash(seed);
	
	#points[0][0] = random_number_generator.randf();
	#points[0][resolution] = random_number_generator.randf();
	#points[resolution][0] = random_number_generator.randf();
	#points[resolution][resolution] = random_number_generator.randf();
	
	#print("GENERATING DIAMOND SQUARE")
	points[0][0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ZERO));
	#print(points[0][0]);
	points[resolution][0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.DOWN * resolution));
	#print(points[0][resolution]);
	points[0][resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.RIGHT * resolution));
	#print(points[resolution][0]);
	points[resolution][resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ONE * resolution));
	#print(points[resolution][resolution]);
	
	var step_size: int = resolution;
	var random_scale: float = 1;
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		@warning_ignore("integer_division")
		var half_step_size: int = step_size / 2;
		
		# diamond step
		var diamond_indecies: Array = range(half_step_size, resolution + 1, step_size);
		for y: int in diamond_indecies:
			for x: int in diamond_indecies:
				points[y][x] = clamp(get_square_average(points, x, y, half_step_size) + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale), 0, 1); # world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale)
				#print("square_avg: " + str(points[y][x]))
		
		# square step
		for y: int in range(0, resolution + 1, half_step_size):
			for x: int in range(posmod(y + half_step_size, step_size), resolution + 1, step_size):
				#print(Vector2i(x, y));
				#if Vector2i(x, y) == Vector2i(resolution/2, 0) and chunk_coord == Vector2i(0, 1):
					#print("res/2, 0:")
					#breakpoint;
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
				#if Vector2i(x, y) == Vector2i(resolution/2, resolution) and chunk_coord == Vector2i.ZERO:
					#print("res/2, res:")
					#breakpoint;
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
					#print(get_diamond_average(points, x, y, half_step_size, resolution))
				points[y][x] = clamp(get_diamond_average(points, x, y, half_step_size, resolution) + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale), 0, 1); # world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)), random_scale)
				#print("diamond_avg: " + str(points[y][x]))
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	#var world_pos: Vector2;
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(0, resolution/2));
	#print(str(world_pos) + ": " + str(points[resolution/2][0]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, resolution/2));
	#print(str(world_pos) + ": " + str(points[resolution/2][resolution]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, 0));
	#print(str(world_pos) + ": " + str(points[0][resolution/2]));
	#world_pos = uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, resolution));
	#print(str(world_pos) + ": " + str(points[resolution][resolution/2]));
	#
	#print("CHUNK COORD: " + str(chunk_coord))
	#if chunk_coord == Vector2i.ZERO:
		#print("BOTTOM ROW OF TOP LEFT")
		#print(points[resolution][resolution/2]);
	#else:
		#print(points[0][resolution/2]);
	#
	#print("FIRST ROW: " + str(points[0]))
	#print("LAST ROW: " + str(points[resolution]))
	
	points.remove_at(resolution/2);
	for row: PackedFloat32Array in points:
		row.remove_at(resolution/2);
	
	#var max: float = -INF;
	#var min: float = INF;
	#for row: PackedFloat32Array in points:
		#for point: float in row:
			#max = max(max, point);
			#min = min(min, point);
	#print("MAX: " + str(max) + " | MIN: " + str(min))
	
	#var new_points: Array[PackedFloat32Array] = [];
	#for row: PackedFloat32Array in points:
		#var new_row: PackedFloat32Array = PackedFloat32Array();
		#for point: float in row:
			#new_row.append(point * 2);
		#new_points.append(new_row);
	#points = new_points;
	
	var heightmap: Image = points_to_heightmap(points);
	if normalise:
		#print("HELLOO JAKE")
		heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;

static func uv_to_linear(uv: Vector2i, resolution: int) -> float:
	return uv.y * float(resolution + 1) + uv.x;

func fill_layer_1(rendering_device: RenderingDevice, points: PackedFloat32Array, resolution: int, chunk_coord: Vector2i) -> PackedFloat32Array:
	# diamond step
	@warning_ignore("integer_division")
	var centre_coord: Vector2i = Vector2i.ONE * resolution/2;
	var centre: float = (points[0] + points[resolution] + points[(resolution + 1) * resolution] + points[(resolution + 1) * (resolution + 1) - 1]) / 4 + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, centre_coord), 1);
	points[uv_to_linear(centre_coord, resolution)] = centre;
	
	# square step
	var Ncentre: float = clamp((
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(0, -resolution))) + 
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, -resolution))) + 
			points[0] + points[resolution]) / 4 + \
			world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, -resolution/2)), 1), 0, 1);
	var Ecentre: float = clamp((
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, 0))) + 
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, resolution))) + 
			points[(resolution + 1) * (resolution + 1) - 1] + points[resolution]) / 4 + \
			world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution*3/2, resolution/2)), 1), 0, 1);
	var Scentre: float = clamp((
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(0, 2*resolution))) + 
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, 2*resolution))) + 
			points[(resolution + 1) * resolution] + points[(resolution + 1) * (resolution + 1) - 1]) / 4 + \
			world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, resolution*3/2)), 1), 0, 1);
	var Wcentre: float = clamp((
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, 0))) + 
			world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, resolution))) + 
			points[0] + points[(resolution + 1) * resolution]) / 4 + \
			world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution/2, resolution/2)), 1), 0, 1);
	
	var Ncoord: Vector2i = Vector2i(resolution/2, 0);
	points[uv_to_linear(Ncoord, resolution)] = (points[0] + points[resolution] + centre + Ncentre) / 4 + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Ncoord), 1);
	var Ecoord: Vector2i = Vector2i(resolution, resolution/2);
	points[uv_to_linear(Ecoord, resolution)] = (points[(resolution + 1) * (resolution + 1) - 1] + points[resolution] + centre + Ecentre) / 4 + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Ecoord), 1);
	var Scoord: Vector2i = Vector2i(resolution/2, resolution);
	points[uv_to_linear(Scoord, resolution)] = (points[(resolution + 1) * resolution] + points[(resolution + 1) * (resolution + 1) - 1] + centre + Scentre) / 4 + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Scoord), 1);
	var Wcoord: Vector2i = Vector2i(0, resolution/2);
	points[uv_to_linear(Wcoord, resolution)] = (points[0] + points[(resolution + 1) * resolution] + centre + Wcentre) / 4 + world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Wcoord), 1);
	
	return points;

func initialise_a_buffer(xs: Array[int], ys: Array[int], resolution: int, chunk_coord: Vector2i) -> PackedFloat32Array:
	assert(xs.size() * ys.size() == 2);
	var buffer: PackedFloat32Array = PackedFloat32Array();
	buffer.resize(2);
	var index: int = 0;
	for y: int in ys:
		for x: int in xs:
			buffer[index] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)));
			index += 1;
	return buffer;

func initialise_b_buffer(x: int, y: int, resolution: int, chunk_coord: Vector2i) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array();
	buffer.resize(3);
	buffer[1] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(x, y)));
	return buffer;

func pad_c_buffer_to_become_b_buffer(c_buffer: PackedFloat32Array) -> PackedFloat32Array:
	var b_buffer_size: int = c_buffer.size() * 2 + 1;
	var b_buffer: PackedFloat32Array = PackedFloat32Array();
	b_buffer.resize(b_buffer_size);
	for index: int in b_buffer_size:
		if posmod(index, 2) == 0:
			b_buffer[index] = -1;
		else:
			b_buffer[index] = c_buffer[(index - 1) / 2];
	return b_buffer;

func generate_GPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image:
	#print("CHUNKED: " + str(chunked));
	#print("chunked_border_diamond_average_type: " + str(chunked_border_diamond_average_type))
	#print("BORDER diamond type: " + str(get_border_diamond_average_type_for_GPU()))
	var a = get_border_diamond_average_type_for_GPU()
	#breakpoint
	
	var points: PackedFloat32Array = PackedFloat32Array();
	points.resize((resolution + 1) * (resolution + 1));
	
	points[0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ZERO));
	points[resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.RIGHT * resolution));
	points[(resolution + 1) * resolution] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.DOWN * resolution));
	points[(resolution + 1) * (resolution + 1) - 1] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i.ONE * resolution));
	
	points = fill_layer_1(rendering_device, points, resolution, chunk_coord);
	
	#if chunk_coord == Vector2i.ZERO:
	#	print("chunk_coord (0, 0)")
	#	print(points[uv_to_linear(Vector2i(resolution/2, resolution), resolution)])
	#if chunk_coord == Vector2i.DOWN:
	#	print("chunk_coord (0, 1)")
	#	print(points[uv_to_linear(Vector2i(resolution/2, 0), resolution)])
	
	var points_bytes: PackedByteArray = points.to_byte_array();
	#print(points_bytes.size());
	#var points_data := rendering_device.texture_buffer_create(points_bytes.size(), RenderingDevice.DATA_FORMAT_R32_SFLOAT, points_bytes);
	var points_RID := rendering_device.storage_buffer_create(points_bytes.size(), points_bytes);
	var points_uniform := RDUniform.new();
	points_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
	points_uniform.binding = 1 # this needs to match the "binding" in our shader file
	points_uniform.add_id(points_RID);
	
	var workgroups: int = ceil(float(resolution + 1) / 4); # + 1 for the fact that resolution + 1 x resolution + 1
	
	var corner_buffer: PackedFloat32Array = PackedFloat32Array(); # 8 floats, first four for buffer a, last four for buffer b, going clockwise starting in NW
	corner_buffer.resize(8);
	corner_buffer[0] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, -resolution)));
	corner_buffer[1] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, -resolution)));
	corner_buffer[2] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, 2*resolution)));
	corner_buffer[3] = world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, 2*resolution)));
	# last four values can go unassigned as they get assigned in the compute shader
	
	var buffer_Na: PackedFloat32Array = initialise_a_buffer([0, resolution], [-resolution], resolution, chunk_coord);
	var buffer_Ea: PackedFloat32Array = initialise_a_buffer([2*resolution], [0, resolution], resolution, chunk_coord);
	var buffer_Sa: PackedFloat32Array = initialise_a_buffer([0, resolution], [2*resolution], resolution, chunk_coord);
	var buffer_Wa: PackedFloat32Array = initialise_a_buffer([-resolution], [0, resolution], resolution, chunk_coord);
	#print("buffer_Na initial: " + str(buffer_Na));
	
	var buffer_Nb: PackedFloat32Array = PackedFloat32Array();
	buffer_Nb.resize(3);
	buffer_Nb.fill(-1);
	buffer_Nb[1] = clamp((
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(0, -resolution))) + 
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, -resolution))) + 
		points[0] + points[resolution]) / 4 + \
		world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, -resolution/2)), 1), 0, 1);
	var buffer_Eb: PackedFloat32Array = PackedFloat32Array();
	buffer_Eb.resize(3);
	buffer_Eb.fill(-1);
	buffer_Eb[1] = clamp((
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, 0))) + 
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(2*resolution, resolution))) + 
		points[(resolution + 1) * (resolution + 1) - 1] + points[resolution]) / 4 + \
		world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution*3/2, resolution/2)), 1), 0, 1);
	var buffer_Sb: PackedFloat32Array = PackedFloat32Array();
	buffer_Sb.resize(3);
	buffer_Sb.fill(-1);
	buffer_Sb[1] = clamp((
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(0, 2*resolution))) + 
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution, 2*resolution))) + 
		points[(resolution + 1) * resolution] + points[(resolution + 1) * (resolution + 1) - 1]) / 4 + \
		world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(resolution/2, resolution*3/2)), 1), 0, 1);
	var buffer_Wb: PackedFloat32Array = PackedFloat32Array();
	buffer_Wb.resize(3);
	buffer_Wb.fill(-1);
	buffer_Wb[1] = clamp((
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, 0))) + 
		world_pos_randf(seed, uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution, resolution))) + 
		points[0] + points[(resolution + 1) * resolution]) / 4 + \
		world_pos_random_offset(uv_to_world_pos(resolution, chunk_coord, Vector2i(-resolution/2, resolution/2)), 1), 0, 1);
	#print("buffer_Nb initial: " + str(buffer_Nb));
	
	# var step_size: int = resolution; 
	# var random_scale: float = 1;
	# because already filled layer 1
	
	@warning_ignore("integer_division")
	var step_size: int = resolution/2;
	var random_scale: float = pow(2, -smoothness);
	while step_size > 1:
		assert(posmod(step_size, 2) == 0) # step_size is even
		# diamond step
		var parameters: PackedFloat32Array = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(get_border_diamond_average_type_for_GPU()), float(distribution), float(true), float(chunk_coord.x), float(chunk_coord.y)]); # DIFFERENT NEEDS TO BE UPDATED IN SHADER
		
		var parameters_bytes: PackedByteArray = parameters.to_byte_array();
		var parameters_RID := rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		var parameters_uniform := RDUniform.new();
		parameters_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameters_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameters_uniform.add_id(parameters_RID);
		
		# create buffer As
		var buffer_Na_RID := rendering_device.storage_buffer_create(buffer_Na.size() * 4, buffer_Na.to_byte_array());
		var buffer_Na_uniform := RDUniform.new();
		buffer_Na_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Na_uniform.binding = 2 # this needs to match the "binding" in our shader file
		buffer_Na_uniform.add_id(buffer_Na_RID);
		var buffer_Ea_RID := rendering_device.storage_buffer_create(buffer_Ea.size() * 4, buffer_Ea.to_byte_array());
		var buffer_Ea_uniform := RDUniform.new();
		buffer_Ea_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Ea_uniform.binding = 5 # this needs to match the "binding" in our shader file
		buffer_Ea_uniform.add_id(buffer_Ea_RID);
		var buffer_Sa_RID := rendering_device.storage_buffer_create(buffer_Sa.size() * 4, buffer_Sa.to_byte_array());
		var buffer_Sa_uniform := RDUniform.new();
		buffer_Sa_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Sa_uniform.binding = 8 # this needs to match the "binding" in our shader file
		buffer_Sa_uniform.add_id(buffer_Sa_RID);
		var buffer_Wa_RID := rendering_device.storage_buffer_create(buffer_Wa.size() * 4, buffer_Wa.to_byte_array());
		var buffer_Wa_uniform := RDUniform.new();
		buffer_Wa_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Wa_uniform.binding = 11 # this needs to match the "binding" in our shader file
		buffer_Wa_uniform.add_id(buffer_Wa_RID);
		
		# create buffer Bs
		var buffer_Nb_RID := rendering_device.storage_buffer_create(buffer_Nb.size() * 4, buffer_Nb.to_byte_array());
		var buffer_Nb_uniform := RDUniform.new();
		buffer_Nb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Nb_uniform.binding = 3 # this needs to match the "binding" in our shader file
		buffer_Nb_uniform.add_id(buffer_Nb_RID);
		var buffer_Eb_RID := rendering_device.storage_buffer_create(buffer_Eb.size() * 4, buffer_Eb.to_byte_array());
		var buffer_Eb_uniform := RDUniform.new();
		buffer_Eb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Eb_uniform.binding = 6 # this needs to match the "binding" in our shader file
		buffer_Eb_uniform.add_id(buffer_Eb_RID);
		var buffer_Sb_RID := rendering_device.storage_buffer_create(buffer_Sb.size() * 4, buffer_Sb.to_byte_array());
		var buffer_Sb_uniform := RDUniform.new();
		buffer_Sb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Sb_uniform.binding = 9 # this needs to match the "binding" in our shader file
		buffer_Sb_uniform.add_id(buffer_Sb_RID);
		var buffer_Wb_RID := rendering_device.storage_buffer_create(buffer_Wb.size() * 4, buffer_Wb.to_byte_array());
		var buffer_Wb_uniform := RDUniform.new();
		buffer_Wb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Wb_uniform.binding = 12 # this needs to match the "binding" in our shader file
		buffer_Wb_uniform.add_id(buffer_Wb_RID);
		
		# create new C buffers
		var step_resolution: int = float(resolution) / (float(step_size)/2);
		var buffer_c: PackedFloat32Array = PackedFloat32Array();
		buffer_c.resize(step_resolution/2);
		
		var buffer_Nc_RID := rendering_device.storage_buffer_create(buffer_c.size() * 4, buffer_c.to_byte_array());
		var buffer_Nc_uniform := RDUniform.new();
		buffer_Nc_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Nc_uniform.binding = 4 # this needs to match the "binding" in our shader file
		buffer_Nc_uniform.add_id(buffer_Nc_RID);
		var buffer_Ec_RID := rendering_device.storage_buffer_create(buffer_c.size() * 4, buffer_c.to_byte_array());
		var buffer_Ec_uniform := RDUniform.new();
		buffer_Ec_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Ec_uniform.binding = 7 # this needs to match the "binding" in our shader file
		buffer_Ec_uniform.add_id(buffer_Ec_RID);
		var buffer_Sc_RID := rendering_device.storage_buffer_create(buffer_c.size() * 4, buffer_c.to_byte_array());
		var buffer_Sc_uniform := RDUniform.new();
		buffer_Sc_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Sc_uniform.binding = 10 # this needs to match the "binding" in our shader file
		buffer_Sc_uniform.add_id(buffer_Sc_RID);
		var buffer_Wc_RID := rendering_device.storage_buffer_create(buffer_c.size() * 4, buffer_c.to_byte_array());
		var buffer_Wc_uniform := RDUniform.new();
		buffer_Wc_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		buffer_Wc_uniform.binding = 13 # this needs to match the "binding" in our shader file
		buffer_Wc_uniform.add_id(buffer_Wc_RID);
		
		# create new corner buffer
		var corner_buffer_RID := rendering_device.storage_buffer_create(8 * 4, corner_buffer.to_byte_array());
		var corner_buffer_uniform := RDUniform.new();
		corner_buffer_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		corner_buffer_uniform.binding = 14 # this needs to match the "binding" in our shader file
		corner_buffer_uniform.add_id(corner_buffer_RID);
		
		var uniform_set := rendering_device.uniform_set_create([parameters_uniform, points_uniform, buffer_Na_uniform, buffer_Ea_uniform, buffer_Sa_uniform, buffer_Wa_uniform, buffer_Nb_uniform, buffer_Eb_uniform, buffer_Sb_uniform, buffer_Wb_uniform, buffer_Nc_uniform, buffer_Ec_uniform, buffer_Sc_uniform, buffer_Wc_uniform, corner_buffer_uniform], compute_shader, 0);
		
		var pipeline := rendering_device.compute_pipeline_create(compute_shader);
		var compute_list := rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(parameters_RID);
		rendering_device.free_rid(pipeline);
		
		# square step
		parameters = PackedFloat32Array([seed, float(resolution), float(step_size), float(random_scale), float(get_border_diamond_average_type_for_GPU()), float(distribution), float(false), float(chunk_coord.x), float(chunk_coord.y)]); # DIFFERENT NEEDS TO BE UPDATED IN SHADER
		
		parameters_bytes = parameters.to_byte_array();
		parameters_RID = rendering_device.storage_buffer_create(parameters_bytes.size(), parameters_bytes);
		parameters_uniform = RDUniform.new();
		parameters_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER;
		parameters_uniform.binding = 0 # this needs to match the "binding" in our shader file
		parameters_uniform.add_id(parameters_RID);
		
		uniform_set = rendering_device.uniform_set_create([parameters_uniform, points_uniform, buffer_Na_uniform, buffer_Ea_uniform, buffer_Sa_uniform, buffer_Wa_uniform, buffer_Nb_uniform, buffer_Eb_uniform, buffer_Sb_uniform, buffer_Wb_uniform, buffer_Nc_uniform, buffer_Ec_uniform, buffer_Sc_uniform, buffer_Wc_uniform, corner_buffer_uniform], compute_shader, 0);
		
		pipeline = rendering_device.compute_pipeline_create(compute_shader);
		compute_list = rendering_device.compute_list_begin();
		rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline);
		rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0);
		rendering_device.compute_list_dispatch(compute_list, workgroups, workgroups, 1);
		rendering_device.compute_list_end();
		
		rendering_device.submit();
		rendering_device.sync();
		
		# update buffers
		buffer_Na = rendering_device.buffer_get_data(buffer_Nb_RID).to_float32_array();
		buffer_Ea = rendering_device.buffer_get_data(buffer_Eb_RID).to_float32_array();
		buffer_Sa = rendering_device.buffer_get_data(buffer_Sb_RID).to_float32_array();
		buffer_Wa = rendering_device.buffer_get_data(buffer_Wb_RID).to_float32_array();
		#print("buffer_Nb: " + str(rendering_device.buffer_get_data(buffer_Nb_RID).to_float32_array()));
		
		buffer_Nb = pad_c_buffer_to_become_b_buffer(rendering_device.buffer_get_data(buffer_Nc_RID).to_float32_array());
		buffer_Eb = pad_c_buffer_to_become_b_buffer(rendering_device.buffer_get_data(buffer_Ec_RID).to_float32_array());
		buffer_Sb = pad_c_buffer_to_become_b_buffer(rendering_device.buffer_get_data(buffer_Sc_RID).to_float32_array());
		buffer_Wb = pad_c_buffer_to_become_b_buffer(rendering_device.buffer_get_data(buffer_Wc_RID).to_float32_array());
		#if step_size >= resolution/32:
			#print("buffer_Na: " + str(rendering_device.buffer_get_data(buffer_Na_RID).to_float32_array()));
			#print("buffer_Nb: " + str(rendering_device.buffer_get_data(buffer_Nb_RID).to_float32_array()));
			#print("buffer_Nc: " + str(rendering_device.buffer_get_data(buffer_Nc_RID).to_float32_array()));
			#print("buffer_Nc padded for Nb: " + str(buffer_Nb));

		corner_buffer = rendering_device.buffer_get_data(corner_buffer_RID).to_float32_array();
		#print("corner_buffer: " + str(corner_buffer))
		corner_buffer[0] = corner_buffer[4];
		corner_buffer[1] = corner_buffer[5];
		corner_buffer[2] = corner_buffer[6];
		corner_buffer[3] = corner_buffer[7];
		
		rendering_device.free_rid(uniform_set);
		rendering_device.free_rid(parameters_RID);
		rendering_device.free_rid(buffer_Na_RID);
		rendering_device.free_rid(buffer_Ea_RID);
		rendering_device.free_rid(buffer_Sa_RID);
		rendering_device.free_rid(buffer_Wa_RID);
		rendering_device.free_rid(buffer_Nb_RID);
		rendering_device.free_rid(buffer_Eb_RID);
		rendering_device.free_rid(buffer_Sb_RID);
		rendering_device.free_rid(buffer_Wb_RID);
		rendering_device.free_rid(buffer_Nc_RID);
		rendering_device.free_rid(buffer_Ec_RID);
		rendering_device.free_rid(buffer_Sc_RID);
		rendering_device.free_rid(buffer_Wc_RID);
		rendering_device.free_rid(corner_buffer_RID);
		rendering_device.free_rid(pipeline);
		
		step_size /= 2;
		random_scale *= pow(2, -smoothness);
	
	var output_bytes := rendering_device.buffer_get_data(points_RID);
	var output := output_bytes.to_float32_array();
	#print("FINAL POINTS: " + str(output))
	
	rendering_device.free_rid(points_RID);
	
	var output_points: Array[PackedFloat32Array] = points_linear_to_nested(output);
	
	#for row_ind: int in (resolution + 1) * (resolution + 1):
		#if output[row_ind] != 0:
			#print("NOT ZERO VALUE: " + str(output[row_ind]) + " ind: " + str(row_ind))
	#for row_ind: int in resolution * resolution:
		#if output[row_ind] != output_points[row_ind / (resolution + 1)][posmod(row_ind, resolution + 1)]:
			#print("NOT SAME" + str(row_ind));
	
	output_points.remove_at(resolution/2);
	for row: PackedFloat32Array in output_points:
		row.remove_at(resolution/2);
	
	var heightmap: Image = points_to_heightmap(output_points);
	if normalise and not chunked:
		heightmap = normalise_heightmap(heightmap, rendering_device);
	return heightmap;
