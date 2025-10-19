extends CheckButton
class_name ShaderParameterCheckBoxUI

func setup(shader_parameter: ShaderParameterBool) -> void:
	text = shader_parameter.name.capitalize();
	button_pressed = shader_parameter.value;
