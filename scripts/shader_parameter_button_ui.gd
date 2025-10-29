extends Button
class_name ShaderParameterButtonUI

signal pressed_down(dummy: bool);

func setup(shader_parameter: ShaderParameterButton) -> void:
	text = shader_parameter.name.capitalize();

func _on_pressed() -> void:
	emit_signal("pressed_down", true);
