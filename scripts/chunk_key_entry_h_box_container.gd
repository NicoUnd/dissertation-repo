extends HBoxContainer
class_name LODKeyEntry

@onready var color_rect: ColorRect = %ColorRect
@onready var label: Label = %Label

func setup(color: Color, text: String) -> void:
	color_rect.color = color;
	label.text = text;
