extends Control

const SHADER_PARAMETER_CHECK_BOX_UI = preload("uid://bngc5tmbrhe76")
const SHADER_PARAMETER_SLIDER_UI_SCENE = preload("uid://u3fkap1o8cbi")
const SHADER_PARAMETER_OPTION_BUTTON_UI = preload("uid://wgyphejds23x")
const SHADER_PARAMETER_IMAGE_UI = preload("uid://337ax8mji8ac")
const SHADER_PARAMETER_BUTTON_UI = preload("uid://c4n6m7j3yipbk")

@onready var main: Control = $".."

@onready var shader_parameters_v_box_container: VBoxContainer = %ShaderParametersVBoxContainer

var seed_slider: ShaderParameterSliderUI;
var shader_specific_UIs: Array[Control] = [];

func add_shader_parameter(shader_parameter: ShaderParameter, is_shader_specific: bool) -> void:
	var on_change: Callable = func (new_value: Variant): main.set_shader_parameter(shader_parameter.name, new_value, is_shader_specific);;
	var new_shader_parameter_UI: Control;
	if shader_parameter is ShaderParameterBool:
		new_shader_parameter_UI = SHADER_PARAMETER_CHECK_BOX_UI.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.connect("toggled", on_change);
	elif shader_parameter is ShaderParameterNumber:
		new_shader_parameter_UI = SHADER_PARAMETER_SLIDER_UI_SCENE.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.h_slider.connect("value_changed", on_change);
	elif shader_parameter is ShaderParameterEnum:
		new_shader_parameter_UI = SHADER_PARAMETER_OPTION_BUTTON_UI.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.option_button.connect("item_selected", on_change);
	elif shader_parameter is ShaderParameterImage:
		new_shader_parameter_UI = SHADER_PARAMETER_IMAGE_UI.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.connect("image_selected", on_change);
	elif shader_parameter is ShaderParameterButton:
		new_shader_parameter_UI = SHADER_PARAMETER_BUTTON_UI.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.connect("pressed_down", on_change);
	
	if shader_parameter.name == "seed":
		seed_slider = new_shader_parameter_UI;
	
	if is_shader_specific:
		shader_specific_UIs.append(new_shader_parameter_UI)

func set_shader_specific_parameters(shader_specific_parameters: Array[ShaderParameter]) -> void:
	for shader_specific_UI: Control in shader_specific_UIs:
		shader_specific_UI.queue_free();
	shader_specific_UIs = [];
	for shader_specific_parameter: ShaderParameter in shader_specific_parameters:
		add_shader_parameter(shader_specific_parameter, true);

func _ready() -> void:
	add_shader_parameter(ShaderParameterNumber.new("seed", 1, 1, 64, false, false, false), false);
	add_shader_parameter(ShaderParameterBool.new("auto_randomise_seed",false), false);
	add_shader_parameter(ShaderParameterEnum.new("albedo_type", 0, ["texture", "heightmap", "normal"]), false);
	add_shader_parameter(ShaderParameterBool.new("unshaded", false), false);
	add_shader_parameter(ShaderParameterBool.new("circle", true), false);
	add_shader_parameter(ShaderParameterBool.new("perturbate", false), false);
	
	var plane_resolution_strings: Array[String] = [];
	for plane_resolution: int in TerrainGenerationMethodVisualiser.PLANE_RESOLUTIONS:
		plane_resolution_strings.append(str(plane_resolution) + "x" + str(plane_resolution));
	add_shader_parameter(ShaderParameterEnum.new("resolution_of_plane", 8, plane_resolution_strings), false);
	
	shader_parameters_v_box_container.add_child(HSeparator.new());
	
	var terrain_generation_method_names: Array[String] = [];
	for terrain_generation_method in TerrainGenerationMethodVisualiser.TERRAIN_GENERATION_METHODS:
		terrain_generation_method_names.append(terrain_generation_method.name.capitalize());
	add_shader_parameter(ShaderParameterEnum.new("terrain_generation_method", -1, terrain_generation_method_names), false);
