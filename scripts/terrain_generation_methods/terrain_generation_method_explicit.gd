@abstract
@tool
extends TerrainGenerationMethod;
class_name TerrainGenerationMethodExplicit;

const RESOLUTIONS: Array[int] = [32, 64, 128, 256, 512, 1024, 2048, 4096];

const HEIGHTMAP_SHADER = preload("uid://deuuby3m21rbw");
const HEIGHTMAP_UNSHADED_SHADER = preload("uid://cq77nryhphey4");
const HEIGHTMAP_WIREFRAME_SHADER = preload("uid://da2px1fwuix17");

@export var can_generate_CPU: bool;
@export var can_generate_GPU: bool;

var resolution: int = 1024;

func get_shader(shader_type: SHADER_TYPE) -> Shader:
	match shader_type:
		SHADER_TYPE.NORMAL:
			return HEIGHTMAP_SHADER;
		SHADER_TYPE.UNSHADED:
			return HEIGHTMAP_UNSHADED_SHADER;
		SHADER_TYPE.WIREFRAME:
			return HEIGHTMAP_WIREFRAME_SHADER;
	push_error("COULDNT FIND SHADER TYPE")
	return null;

func get_parameters(chunked: bool) -> Array[Parameter]:
	var to_return: Array[Parameter] = [ParameterNumber.new("amplitude", default_amplitude, min_amplitude, max_amplitude, false, false, false)];
	if not chunked:
		#to_return.append(ParameterBool.new("generating_in_chunks", false));
		var resolution_strings: Array[String] = [];
		for resoluton: int in RESOLUTIONS:
			resolution_strings.append(str(resoluton) + "x" + str(resoluton));
		to_return.append(ParameterEnum.new("resolution", 5, resolution_strings));
	
	if can_generate_in_chunks and chunked:
		if _chunked_parameters.size() > 0:
			to_return.append_array(_chunked_parameters);
		else:
			to_return.append_array(_parameters);
		to_return.append(ParameterButton.new("disable_chunks"));
	else:
		to_return.append_array(_parameters);
		if can_generate_in_chunks:
			to_return.append(ParameterButton.new("enable_chunks"));
	
	if can_generate_CPU:
		to_return.append(ParameterButton.new("generate_CPU"));
	if can_generate_GPU:
		to_return.append(ParameterButton.new("generate_GPU"));
	
	return to_return;

@abstract func setup(rendering_device: RenderingDevice) -> void;

@abstract func setdown(rendering_device: RenderingDevice) -> void;

@abstract func generate_CPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image;

@abstract func generate_GPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image;

static func log2(x: float) -> float:
	return log(x) / log(2);
