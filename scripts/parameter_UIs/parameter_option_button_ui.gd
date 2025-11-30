extends PanelContainer
class_name ParameterOptionButtonUI

@onready var label: Label = %Label
@onready var option_button: OptionButton = %OptionButton

func setup(parameter: ParameterEnum) -> void:
	label.text = parameter.name.capitalize();
	
	for parameter_option: String in parameter.options:
		option_button.add_item(parameter_option.capitalize());
	option_button.selected = parameter.value;

func _to_string() -> String:
	return label.text + ": " + option_button.get_item_text(option_button.selected);
