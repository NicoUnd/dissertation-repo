extends CheckButton
class_name ParameterCheckBoxUI

func setup(parameter: ParameterBool, on_change: Callable) -> void:
	text = parameter.name.capitalize();
	button_pressed = parameter.value;
	connect("toggled", on_change);

func _to_string() -> String:
	return text + ": " + ("✓" if button_pressed else "✗");
