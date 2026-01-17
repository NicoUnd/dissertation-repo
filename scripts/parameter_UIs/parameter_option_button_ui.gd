extends PanelContainer
class_name ParameterOptionButtonUI

@onready var label: Label = %Label
@onready var option_button: OptionButton = %OptionButton

var parameter_name: String;

func setup(parameter: ParameterEnum, on_change: Callable) -> void:
	parameter_name = parameter.name;
	label.text = parameter_name.capitalize();
	
	option_button.clear();
	for parameter_option: String in parameter.options:
		option_button.add_item(parameter_option.capitalize());
	option_button.selected = parameter.value;
	
	option_button.connect("item_selected", on_change);

func _to_string() -> String:
	return label.text + ": " + option_button.get_item_text(option_button.selected);
