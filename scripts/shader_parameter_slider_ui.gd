extends PanelContainer
class_name ShaderParameterSliderUI

@onready var label: Label = %Label
@onready var h_slider: HSlider = %HSlider

var shader_parameter_name_capitalized: String;
var is_square_in_display: bool;
var is_int: bool;

func setup(shader_parameter: ShaderParameterNumber) -> void:
	shader_parameter_name_capitalized = shader_parameter.name.capitalize();
	is_square_in_display = shader_parameter.is_square_in_display;
	is_int = shader_parameter.is_int;
	
	var value: float = shader_parameter.value;
	update_text(value);
	
	h_slider.min_value = shader_parameter.min_value;
	h_slider.max_value = shader_parameter.max_value;
	if shader_parameter.name == "octaves":
		print(shader_parameter.is_exp)
	h_slider.exp_edit = shader_parameter.is_exp;
	if is_int:
		h_slider.step = 1;
	else:
		h_slider.step = 0.01;
	h_slider.value = value;

func update_text(new_value: float) -> void:
	var new_value_string = str(int(new_value) if is_int else new_value);
	label.text = shader_parameter_name_capitalized + " (" + new_value_string + (("x" + new_value_string) if is_square_in_display else "")+ ")"

func _to_string() -> String:
	var value: float = h_slider.value;
	var value_string = str(int(value) if is_int else value);
	return shader_parameter_name_capitalized + ": " + value_string + (("x" + value_string) if is_square_in_display else "");
