extends Control

const SHADER_PARAMETER_SLIDER_UI_SCENE = preload("uid://u3fkap1o8cbi")

@onready var main: Control = $".."

@onready var shader_parameters_v_box_container: VBoxContainer = %ShaderParametersVBoxContainer

var shader_specific_UIs: Array[Control] = [];

func add_shader_parameter(shader_parameter: ShaderParameter, is_shader_specific: bool) -> void:
	var on_change: Callable = func (new_value: Variant): main.set_shader_parameter(shader_parameter.name, new_value, is_shader_specific);
	var new_shader_parameter_UI: Control;
	if shader_parameter is ShaderParameterBool:
		new_shader_parameter_UI = CheckButton.new();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.text = shader_parameter.name.capitalize();
		new_shader_parameter_UI.button_pressed = shader_parameter.value;
		new_shader_parameter_UI.connect("toggled", on_change);
	elif shader_parameter is ShaderParameterNumber:
		new_shader_parameter_UI = SHADER_PARAMETER_SLIDER_UI_SCENE.instantiate();
		shader_parameters_v_box_container.add_child(new_shader_parameter_UI);
		new_shader_parameter_UI.setup(shader_parameter);
		new_shader_parameter_UI.h_slider.connect("value_changed", on_change);
	
	if is_shader_specific:
		shader_specific_UIs.append(new_shader_parameter_UI)

func set_shader_specific_parameters(shader_specific_parameters: Array[ShaderParameter]) -> void:
	for shader_specific_UI: Control in shader_specific_UIs:
		shader_specific_UI.queue_free();
	shader_specific_UIs = [];
	for shader_specific_parameter: ShaderParameter in shader_specific_parameters:
		add_shader_parameter(shader_specific_parameter, true);

func _ready() -> void:
	add_shader_parameter(ShaderParameterNumber.new("seed", 1, 1, 64, false), false);
	add_shader_parameter(ShaderParameterBool.new("auto_randomise_seed",false), false);
	add_shader_parameter(ShaderParameterBool.new("circle", true), false);
	add_shader_parameter(ShaderParameterBool.new("albedo_is_heightmap", false), false);
	add_shader_parameter(ShaderParameterBool.new("unshaded", false), false);
	
	shader_parameters_v_box_container.add_child(HSeparator.new());
