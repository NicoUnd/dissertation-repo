@tool
extends TextureRect

const DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_ROTATION: Vector3 = Vector3(0, 0.510913, 0.859632);
const DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_MAGNITUDE: float = 61.65427;
const DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_POSITION: Vector3 = Vector3(0, 31.7, 53);

const DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE: float = 70;

const DEFAULT_CAMERA_SPEED: float = 5;

@onready var light_pivot: Node3D = %LightPivot

@onready var visualisation_camera_pivot: Node3D = %VisualisationCameraPivot
@onready var visualisation_perspective_camera_3d: Camera3D = %VisualisationPerspectiveCamera3D
@onready var visualisation_orthographic_camera_3d: Camera3D = %VisualisationOrthographicCamera3D

@onready var save_render_file_dialog: FileDialog = %SaveRenderFileDialog

var rotation_type: int = 0;
var rotation_speed: float = 0.1;

var freeroam_camera: bool = false;

var camera_speed: float = 5;

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

func set_camera_type(camera_type: int) -> void:
	camera_speed = DEFAULT_CAMERA_SPEED;
	freeroam_camera = camera_type == 2;
	if camera_type == 1:
		visualisation_perspective_camera_3d.current = false;
		visualisation_orthographic_camera_3d.current = true;
		orthographic_size = DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE;
		return;
	assert(camera_type in [0, 2]);
	visualisation_orthographic_camera_3d.current = false;
	visualisation_perspective_camera_3d.current = true;
	visualisation_perspective_camera_3d.top_level = camera_type == 2;
	visualisation_perspective_camera_3d.global_position = DEFAULT_VISUALISATION_PERSPECTIVE_CAMERA_POSITION;
	zoom = 1; # reset zoom
	visualisation_perspective_camera_3d.look_at(Vector3.ZERO);

func _input(event: InputEvent) -> void:
	const MAX_ZOOM: float = 0.1;
	const MIN_SIZE: float = 4;
	const MAX_CAMERA_SPEED: float = 15;
	const MIN_CAMERA_SPEED: float = 1;
	
	if not freeroam_camera and Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
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
				zoom = min(zoom * 1.1, 2);
			else:
				orthographic_size = min(orthographic_size * 1.1, DEFAULT_VISUALISATION_ORTHOGRAPHIC_CAMERA_SIZE * 1.5);
	
	if freeroam_camera:
		if Input.is_action_just_released("mouse_wheel_up"):
			camera_speed = min(camera_speed + 0.2, MAX_CAMERA_SPEED);
		elif Input.is_action_just_released("mouse_wheel_down"):
			camera_speed = max(camera_speed - 0.2, MIN_CAMERA_SPEED);
		
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_current_cursor_shape() == Input.CURSOR_HSIZE and event is InputEventMouseMotion:
			var mouse_delta: Vector2 = event.relative * 0.001;
			var yaw = -mouse_delta.x;
			var pitch = -mouse_delta.y;
			
			visualisation_perspective_camera_3d.rotation.x = clamp(visualisation_perspective_camera_3d.rotation.x + pitch, -PI/2, PI/2);
			visualisation_perspective_camera_3d.rotation.y += yaw;

func _process(delta: float) -> void:
	if save_render_file_dialog.visible:
		return;
	
	if freeroam_camera:
		if Input.is_action_pressed("forward"):
			visualisation_perspective_camera_3d.position += -visualisation_perspective_camera_3d.transform.basis.z * camera_speed * delta;
		if Input.is_action_pressed("left"):
			visualisation_perspective_camera_3d.position += -visualisation_perspective_camera_3d.transform.basis.x * camera_speed * delta;
		if Input.is_action_pressed("right"):
			visualisation_perspective_camera_3d.position += visualisation_perspective_camera_3d.transform.basis.x * camera_speed * delta;
		if Input.is_action_pressed("backward"):
			visualisation_perspective_camera_3d.position += visualisation_perspective_camera_3d.transform.basis.z * camera_speed * delta;
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.get_current_cursor_shape() == Input.CURSOR_HSIZE:
		mouse_been_held_for += delta;
	else:
		mouse_been_released_for += delta;
		mouse_been_held_for = 0;
	if mouse_been_held_for > 0.2:
		mouse_been_released_for = 0;
	if mouse_been_held_for < 0.2:
		var delta_rotation: float = delta * rotation_speed;
		match rotation_type:
			0:
				visualisation_camera_pivot.rotation.y += delta_rotation;
			1:
				light_pivot.rotation.y += delta_rotation;
			2:
				visualisation_camera_pivot.rotation.y += delta_rotation;
				light_pivot.rotation.y += delta_rotation;
