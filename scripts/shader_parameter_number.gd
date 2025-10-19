extends ShaderParameter
class_name ShaderParameterNumber

@export var min_value: float;
@export var max_value: float;

@export var is_int: bool;

@export var is_square_in_display: bool;
@export var is_exp: bool;

func _init(given_name: String="", given_value: float=0, given_min_value: float=0, given_max_value: float=0, given_is_int: bool=false, given_is_square_in_display=false, given_is_exp: bool=false) -> void:
	name = given_name;
	value = given_value;
	min_value = given_min_value;
	max_value = given_max_value;
	is_int = given_is_int;
	is_square_in_display = given_is_square_in_display;
	is_exp = given_is_exp;
