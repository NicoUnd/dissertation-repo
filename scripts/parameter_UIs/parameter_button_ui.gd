extends Button
class_name ParameterButtonUI

var parameter_name: String;

func setup(parameter: ParameterButton, on_change: Callable) -> void:
	parameter_name = parameter.name;
	text = parameter_name.capitalize();
	connect("pressed", on_change);
