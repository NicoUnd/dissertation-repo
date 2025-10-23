extends Button
class_name ShaderParameterImageUI

func setup(shader_parameter: ShaderParameterImage) -> void:
	text = shader_parameter.name.capitalize();
	
	option_button.selected = shader_parameter.value;
