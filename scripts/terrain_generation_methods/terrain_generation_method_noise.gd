extends TerrainGenerationMethod;
class_name TerrainGenerationMethodNoise;

@export var _shader: Shader;
@export var _unshaded_shader: Shader;

func get_shader(unshaded: bool) -> Shader:
	return _unshaded_shader if unshaded else _shader;
