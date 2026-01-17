extends TerrainGenerationMethod;
class_name TerrainGenerationMethodNoise;

@export var _shader: Shader;
@export var _unshaded_shader: Shader;
@export var _wireframe_shader: Shader;

func get_shader(shader_type: SHADER_TYPE) -> Shader:
	match shader_type:
		SHADER_TYPE.NORMAL:
			return _shader;
		SHADER_TYPE.UNSHADED:
			return _unshaded_shader;
		SHADER_TYPE.WIREFRAME:
			return _wireframe_shader;
	push_error("COULDNT FIND SHADER TYPE")
	return null;
