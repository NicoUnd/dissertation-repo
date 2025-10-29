extends TerrainGenerationMethod
class_name DiamondSquare

var resolution: int = 1024;

var interpolation: int = 0;

var distribution: int = 0;

var wrap_around: bool = true;

func generate(seed: float) -> Image:
	var pixels: Array[PackedFloat32Array] = [];
	pixels.resize(resolution + 1);
	for row_index: int in resolution:
		var row: PackedFloat32Array = PackedFloat32Array(); # use 32 bits as is standard in exp file format
		row.resize(resolution + 1);
		pixels[row_index] = row;
	
	var random_number_generator: RandomNumberGenerator = RandomNumberGenerator.new();
	random_number_generator.seed = hash(seed);
	
	pixels[0][0] = random_number_generator.randf();
	pixels[0][resolution + 1] = random_number_generator.randf();
	pixels[resolution + 1][0] = random_number_generator.randf();
	pixels[resolution + 1][resolution + 1] = random_number_generator.randf();
	
	for iteration: int in log2(resolution):
		var indecies: Array[int] = 
	
	return;
