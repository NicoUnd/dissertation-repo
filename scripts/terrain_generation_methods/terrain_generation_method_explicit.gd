@abstract
extends TerrainGenerationMethod;
class_name TerrainGenerationMethodExplicit;

const RESOLUTIONS: Array[int] = [256, 512, 1024, 2048, 4096];

const HEIGHTMAP_SHADER = preload("uid://deuuby3m21rbw");
const HEIGHTMAP_UNSHADED_SHADER = preload("uid://cq77nryhphey4");

@export var GPU_accelerated: bool;

var resolution: int = 1024;

func get_shader(unshaded: bool) -> Shader:
	return HEIGHTMAP_UNSHADED_SHADER if unshaded else HEIGHTMAP_SHADER;

@abstract func setup(rendering_device: RenderingDevice) -> void;

@abstract func setdown(rendering_device: RenderingDevice) -> void;

@abstract func generate_CPU(rendering_device: RenderingDevice) -> Image;

@abstract func generate_GPU(rendering_device: RenderingDevice) -> Image;

func log2(x: float) -> float:
	return log(x) / log(2);
