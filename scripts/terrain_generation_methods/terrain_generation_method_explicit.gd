@abstract
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

@abstract func setup(rendering_device: RenderingDevice) -> void;

@abstract func setdown(rendering_device: RenderingDevice) -> void;

@abstract func generate_CPU(rendering_device: RenderingDevice, resolution: int, chunk_coord: Vector2i=Vector2i.ZERO) -> Image;

@abstract func generate_GPU(rendering_device: RenderingDevice, resolution: int) -> Image;

func log2(x: float) -> float:
	return log(x) / log(2);
