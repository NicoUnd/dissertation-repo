extends HBoxContainer
class_name ShaderParameterSliderUI

@onready var label: Label = %Label
@onready var h_slider: HSlider = %HSlider

func setup(shader_parameter: ShaderParameterNumber) -> void:
	label.text = shader_parameter.name.capitalize();
	h_slider.min_value = shader_parameter.min_value;
	h_slider.max_value = shader_parameter.max_value;
	if shader_parameter.is_int:
		h_slider.step = 1;
	else:
		h_slider.step = 0.1;
	h_slider.value = shader_parameter.value;
