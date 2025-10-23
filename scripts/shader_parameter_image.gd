extends ShaderParameter
class_name ShaderParameterImage

func _init(given_name: String="", given_value: Image=null) -> void:
	name = given_name;
	value = given_value;
