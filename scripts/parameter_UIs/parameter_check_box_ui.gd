extends CheckButton
class_name ParameterCheckBoxUI

func setup(parameter: ParameterBool) -> void:
	text = parameter.name.capitalize();
	button_pressed = parameter.value;

func _to_string() -> String:
	return text + ": " + ("✓" if button_pressed else "✗");
