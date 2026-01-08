extends Button
class_name ParameterButtonUI

func setup(parameter: ParameterButton, on_change: Callable) -> void:
	text = parameter.name.capitalize();
	connect("pressed", on_change);
