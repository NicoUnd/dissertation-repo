extends TerrainGenerationMethodExplicit;
class_name DiffusionLimitedAggregation;

func setup(rendering_device: RenderingDevice) -> void:
	return;

func setdown(rendering_device: RenderingDevice) -> void:
	return;

func generate_CPU(rendering_device: RenderingDevice) -> Image:
	return;

func generate_GPU(rendering_device: RenderingDevice) -> Image: # will never happen as not GPU accelerated
	assert(false);
	return;
