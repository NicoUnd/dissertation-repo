extends Control
class_name UI;

@onready var main: Control = $".."

@onready var parameters_v_box_container: VBoxContainer = %ParametersVBoxContainer

var seed_slider: ParameterSliderUI;
var terrain_generation_method_specific_UIs: Array[Control] = [];

static func parameter_to_parameter_ui(parameter: Parameter) -> Control:
	const PARAMETER_CHECK_BOX_UI_SCENE = preload("uid://bngc5tmbrhe76")
	const PARAMETER_SLIDER_UI_SCENE = preload("uid://u3fkap1o8cbi")
	const PARAMETER_OPTION_BUTTON_UI_SCENE = preload("uid://wgyphejds23x")
	const PARAMETER_IMAGE_UI_SCENE = preload("uid://337ax8mji8ac")
	const PARAMETER_BUTTON_UI_SCENE = preload("uid://c4n6m7j3yipbk")
	
	if parameter is ParameterBool:
		return PARAMETER_CHECK_BOX_UI_SCENE.instantiate();
	elif parameter is ParameterNumber:
		return PARAMETER_SLIDER_UI_SCENE.instantiate();
	elif parameter is ParameterEnum:
		return PARAMETER_OPTION_BUTTON_UI_SCENE.instantiate();
	elif parameter is ParameterImage:
		return PARAMETER_IMAGE_UI_SCENE.instantiate();
	elif parameter is ParameterButton:
		return PARAMETER_BUTTON_UI_SCENE.instantiate();
	push_error("parameter type not recognised");
	return;

func add_parameter(parameter: Parameter, is_terrain_generation_method_specific: bool) -> void:
	var parameter_name: String = parameter.name;
	var on_change: Callable = func (new_value: Variant=null): main.set_parameter(parameter_name, new_value, is_terrain_generation_method_specific);;
	var new_parameter_UI: Control = parameter_to_parameter_ui(parameter);
	parameters_v_box_container.add_child(new_parameter_UI);
	new_parameter_UI.setup(parameter, on_change);
	
	if parameter_name == "seed":
		seed_slider = new_parameter_UI;
	
	if is_terrain_generation_method_specific:
		terrain_generation_method_specific_UIs.append(new_parameter_UI)
		if not parameter is ParameterButton:
			main.set_parameter(parameter_name, parameter.value, true);

func clear_terrain_generation_method_specific_parameters() -> void:
	for terrain_generation_method_specific_UI: Control in terrain_generation_method_specific_UIs:
		terrain_generation_method_specific_UI.queue_free();
	terrain_generation_method_specific_UIs = [];

func pop_terrain_generation_method_specific_parameter() -> void:
	terrain_generation_method_specific_UIs.pop_back().queue_free();

func set_terrain_generation_method_specific_parameters(terrain_generation_method_specific_parameters: Array[Parameter]) -> void:
	for terrain_generation_method_specific_parameter: Parameter in terrain_generation_method_specific_parameters:
		add_parameter(terrain_generation_method_specific_parameter, true);

func update_chunked_specific_parameters(chunked_specific_parameters: Array[Parameter]) -> void:
	for chunked_specific_parameter: Parameter in chunked_specific_parameters:
		var chunked_specific_parameter_name: String = chunked_specific_parameter.name;
		var on_change: Callable = func (new_value: Variant=null):
			main.set_parameter(chunked_specific_parameter_name, new_value, true);
			if main.explicit_chunk_generation:
				main.set_explicit_chunk_generation_and_update_UI_and_planes(false);; # if these parameters are changed, no longer generating in chunks
		for terrain_generation_method_specific_UI: Control in terrain_generation_method_specific_UIs:
			if terrain_generation_method_specific_UI.parameter_name == chunked_specific_parameter.name:
				terrain_generation_method_specific_UI.setup(chunked_specific_parameter, on_change);
				main.set_parameter(chunked_specific_parameter_name, chunked_specific_parameter.value, true);

func _ready() -> void:
	add_parameter(ParameterNumber.new("seed", 1, 1, 64, false, false, false), false);
	add_parameter(ParameterBool.new("auto_randomise_seed",false), false);
	add_parameter(ParameterEnum.new("albedo_type", 0, ["colour_blend", "heightmap", "normal", "white", "black"]), false);
	add_parameter(ParameterEnum.new("render_mode", 0, ["shaded", "unshaded", "wireframe"]), false);
	add_parameter(ParameterBool.new("circle", true), false);
	add_parameter(ParameterBool.new("perturbate", false), false);
	add_parameter(ParameterNumber.new("water_level", 0, 0, 1, false, false, false), false);
	add_parameter(ParameterEnum.new("camera_type", 1, ["perspective", "orthographic", "freeroam"]), false);
	add_parameter(ParameterEnum.new("rotation_type", 0, ["camera", "light", "both", "none"]), false);
	add_parameter(ParameterNumber.new("rotation_speed", 0.1, 0.01, 1, false, false, true), false);
	
	var plane_resolution_strings: Array[String] = [];
	for plane_resolution: int in TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS:
		plane_resolution_strings.append(str(plane_resolution) + "x" + str(plane_resolution));
	add_parameter(ParameterEnum.new("resolution_of_plane", 8, plane_resolution_strings), false);
	
	parameters_v_box_container.add_child(HSeparator.new());
	
	var terrain_generation_method_names: Array[String] = [];
	for terrain_generation_method in TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS:
		terrain_generation_method_names.append(terrain_generation_method.name.capitalize());
	add_parameter(ParameterEnum.new("terrain_generation_method", -1, terrain_generation_method_names), false);
