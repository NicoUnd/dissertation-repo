extends PanelContainer
class_name ParameterSliderUI

@onready var label: Label = %Label
@onready var h_slider: HSlider = %HSlider

var parameter_name_capitalized: String;
var is_square_in_display: bool;
var is_int: bool;

func setup(parameter: ParameterNumber) -> void:
	parameter_name_capitalized = parameter.name.capitalize();
	is_square_in_display = parameter.is_square_in_display;
	is_int = parameter.is_int;
	
	var value: float = parameter.value;
	update_text(value);
	
	h_slider.min_value = parameter.min_value;
	h_slider.max_value = parameter.max_value;
	h_slider.exp_edit = parameter.is_exp;
	if is_int:
		h_slider.step = 1;
	else:
		h_slider.step = 0.01;
	h_slider.value = value;

func update_text(new_value: float) -> void:
	var new_value_string = str(int(new_value) if is_int else new_value);
	label.text = parameter_name_capitalized + " (" + new_value_string + (("x" + new_value_string) if is_square_in_display else "")+ ")"

func _to_string() -> String:
	var value: float = h_slider.value;
	var value_string = str(int(value) if is_int else value);
	return parameter_name_capitalized + ": " + value_string + (("x" + value_string) if is_square_in_display else "");
