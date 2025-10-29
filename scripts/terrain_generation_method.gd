extends Resource
class_name TerrainGenerationMethod

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
