@tool
extends TextureRect

const DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_ROTATION: Vector3 = Vector3(0, 0.510913, 0.859632);
const DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_MAGNITUDE: float = 61.65427;

const DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE: float = 70;

@onready var visualisation_camera_pivot: Node3D = %VisualisationCameraPivot
@onready var visualisation_perspective_camera_3d: Camera3D = %VisualisationPerspectiveCamera3D
@onready var visualisation_orthographic_camera_3d: Camera3D = %VisualisationOrthographicCamera3D

var last_mouse_position: Vector2 = Vector2.ZERO;
var mouse_been_released_for: float = INF;
var mouse_been_held_for: float = 0;
var zoom: float = 1.0:
	set(new_zoom):
		zoom = new_zoom;
		visualisation_perspective_camera_3d.position = DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_ROTATION * DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_MAGNITUDE * zoom;
var orthographic_size: float = DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE:
	set(new_orthographic_size):
		orthographic_size = new_orthographic_size;
		visualisation_orthographic_camera_3d.size = orthographic_size;

func _input(event: InputEvent) -> void:
	const MAX_ZOOM: float = 0.1;
	const MIN_SIZE: float = 10;
	
	if Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_position: Vector2 = event.position;
			if last_mouse_position != Vector2.ZERO:
				var mouse_position_delta: Vector2 = last_mouse_position - mouse_position;
				visualisation_camera_pivot.rotation.y += mouse_position_delta.length() * 0.001 * sign(mouse_position_delta.x);
			last_mouse_position = mouse_position;
		else:
			last_mouse_position = Vector2.ZERO;
		
		var perspective: bool = visualisation_perspective_camera_3d.current;
		if Input.is_action_just_released("mouse_wheel_up"):
			if perspective:
				zoom = max(zoom * 0.9, MAX_ZOOM);
			else:
				orthographic_size = max(orthographic_size * 0.9, MIN_SIZE);
		elif Input.is_action_just_released("mouse_wheel_down"):
			if perspective:
				zoom = min(zoom * 1.1, 1);
			else:
				orthographic_size = min(orthographic_size * 1.1, DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE);

func _process(delta: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
		mouse_been_held_for += delta;
	else:
		mouse_been_released_for += delta;
		mouse_been_held_for = 0;
	if mouse_been_held_for > 0.2:
		mouse_been_released_for = 0;
	if mouse_been_held_for < 0.2:
		visualisation_camera_pivot.rotation.y += delta * 0.1;
