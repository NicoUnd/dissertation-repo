extends Button
class_name ParameterButtonUI

signal pressed_down(dummy: bool);

func setup(parameter: ParameterButton) -> void:
	text = parameter.name.capitalize();

func _on_pressed() -> void:
	emit_signal("pressed_down", true);
