extends Camera3D

@onready var camera_pivot: Node3D = %CameraPivot

func _process(delta: float) -> void:
	camera_pivot.rotation.y += delta * 0.1;
