extends Control

const PARAMETER_CHECK_BOX_UI_SCENE = preload("uid://bngc5tmbrhe76")
const PARAMETER_SLIDER_UI_SCENE = preload("uid://u3fkap1o8cbi")
const PARAMETER_OPTION_BUTTON_UI_SCENE = preload("uid://wgyphejds23x")
const PARAMETER_IMAGE_UI_SCENE = preload("uid://337ax8mji8ac")
const PARAMETER_BUTTON_UI_SCENE = preload("uid://c4n6m7j3yipbk")

@onready var main: Control = $".."

@onready var parameters_v_box_container: VBoxContainer = %ParametersVBoxContainer

var seed_slider: ParameterSliderUI;
var terrain_generation_method_specific_UIs: Array[Control] = [];

func add_parameter(parameter: Parameter, is_terrain_generation_method_specific: bool) -> void:
	var on_change: Callable = func (new_value: Variant): main.set_parameter(parameter.name, new_value, is_terrain_generation_method_specific);;
	var new_parameter_UI: Control;
	if parameter is ParameterBool:
		new_parameter_UI = PARAMETER_CHECK_BOX_UI_SCENE.instantiate();
		parameters_v_box_container.add_child(new_parameter_UI);
		new_parameter_UI.setup(parameter);
		new_parameter_UI.connect("toggled", on_change);
	elif parameter is ParameterNumber:
		new_parameter_UI = PARAMETER_SLIDER_UI_SCENE.instantiate();
		parameters_v_box_container.add_child(new_parameter_UI);
		new_parameter_UI.setup(parameter);
		new_parameter_UI.h_slider.connect("value_changed", on_change);
	elif parameter is ParameterEnum:
		new_parameter_UI = PARAMETER_OPTION_BUTTON_UI_SCENE.instantiate();
		parameters_v_box_container.add_child(new_parameter_UI);
		new_parameter_UI.setup(parameter);
		new_parameter_UI.option_button.connect("item_selected", on_change);
	elif parameter is ParameterImage:
		new_parameter_UI = PARAMETER_IMAGE_UI_SCENE.instantiate();
		parameters_v_box_container.add_child(new_parameter_UI);
		new_parameter_UI.setup(parameter);
		new_parameter_UI.connect("image_selected", on_change);
	elif parameter is ParameterButton:
		new_parameter_UI = PARAMETER_BUTTON_UI_SCENE.instantiate();
		parameters_v_box_container.add_child(new_parameter_UI);
		new_parameter_UI.setup(parameter);
		new_parameter_UI.connect("pressed_down", on_change);
	
	if parameter.name == "seed":
		seed_slider = new_parameter_UI;
	
	if is_terrain_generation_method_specific:
		terrain_generation_method_specific_UIs.append(new_parameter_UI)
		if not parameter is ParameterButton:
			main.set_parameter(parameter.name, parameter.value, true);

func clear_terrain_generation_method_specific_parameters() -> void:
	for terrain_generation_method_specific_UI: Control in terrain_generation_method_specific_UIs:
		terrain_generation_method_specific_UI.queue_free();
	terrain_generation_method_specific_UIs = [];

func set_terrain_generation_method_specific_parameters(terrain_generation_method_specific_parameters: Array[Parameter]) -> void:
	for terrain_generation_method_specific_parameter: Parameter in terrain_generation_method_specific_parameters:
		add_parameter(terrain_generation_method_specific_parameter, true);

func _ready() -> void:
	add_parameter(ParameterNumber.new("seed", 1, 1, 64, false, false, false), false);
	add_parameter(ParameterBool.new("auto_randomise_seed",false), false);
	add_parameter(ParameterEnum.new("albedo_type", 0, ["texture", "heightmap", "normal"]), false);
	add_parameter(ParameterBool.new("unshaded", false), false);
	add_parameter(ParameterBool.new("circle", true), false);
	add_parameter(ParameterBool.new("perturbate", false), false);
	add_parameter(ParameterNumber.new("water_level", 0, 0, 1, false, false, false), false);
	add_parameter(ParameterEnum.new("camera_type", 1, ["perspective", "orthographic"]), false);
	
	var plane_resolution_strings: Array[String] = [];
	for plane_resolution: int in TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS:
		plane_resolution_strings.append(str(plane_resolution) + "x" + str(plane_resolution));
	add_parameter(ParameterEnum.new("resolution_of_plane", 8, plane_resolution_strings), false);
	
	parameters_v_box_container.add_child(HSeparator.new());
	
	var terrain_generation_method_names: Array[String] = [];
	for terrain_generation_method in TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS:
		terrain_generation_method_names.append(terrain_generation_method.name.capitalize());
	add_parameter(ParameterEnum.new("terrain_generation_method", -1, terrain_generation_method_names), false);
