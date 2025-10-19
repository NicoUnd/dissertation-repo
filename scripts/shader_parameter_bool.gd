extends ShaderParameter
class_name ShaderParameterBool

func _init(given_name: String="", given_value: bool=false) -> void:
	name = given_name;
	value = given_value;
