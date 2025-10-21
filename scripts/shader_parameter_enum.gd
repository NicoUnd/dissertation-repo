extends ShaderParameter
class_name ShaderParameterEnum

@export var options: Array[String];

func _init(given_name: String="", given_value: int=0, given_options: Array[String]=[]) -> void:
	name = given_name;
	value = given_value;
	options = given_options;
