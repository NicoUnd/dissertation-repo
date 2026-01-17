extends CheckButton
class_name ParameterCheckBoxUI

var parameter_name: String;

func setup(parameter: ParameterBool, on_change: Callable) -> void:
	parameter_name = parameter.name;
	text = parameter_name.capitalize();
	button_pressed = parameter.value;
	connect("toggled", on_change);

func _to_string() -> String:
	return text + ": " + ("✓" if button_pressed else "✗");
