extends PanelContainer
class_name ShaderParameterOptionButtonUI

@onready var label: Label = %Label
@onready var option_button: OptionButton = %OptionButton

func setup(shader_parameter: ShaderParameterEnum) -> void:
	label.text = shader_parameter.name.capitalize();
	
	for shader_parameter_option: String in shader_parameter.options:
		option_button.add_item(shader_parameter_option.capitalize());
	option_button.selected = shader_parameter.value;
