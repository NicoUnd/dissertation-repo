extends TextureRect
class_name ErodibilityMask

var erosion_settings: ErosionSettings;

var last_mouse_position: Vector2 = Vector2.ZERO

@export var brush_texture: GradientTexture2D;

func draw(mask: Image, position: Vector2) -> void:
	var brush_size: int = erosion_settings.erodibility_brush_size;
	var color: Color = Color(erosion_settings.brush_color, erosion_settings.brush_color, erosion_settings.brush_color);
	#var blend_rect2i: Rect2i = Rect2i(position, Vector2i.ONE * erosion_settings.erodibility_brush_size);
	var brush_image: Image = brush_texture.get_image();
	brush_image.resize(brush_size, brush_size);
	for x in brush_size:
		for y in brush_size:
			var alpha: Color = brush_image.get_pixel(x, y);
			brush_image.set_pixel(x, y, alpha * color);
	mask.blend_rect(brush_image, brush_image.get_used_rect(), position);
	
	#mask.fill_rect(Rect2i(position, Vector2i.ONE * erosion_settings.erodibility_brush_size), Color.WHITE if erosion_settings.white_brush else Color.BLACK);

func _process(delta) -> void:
	var mouse_position: Vector2 = get_local_mouse_position();
	if Input.is_action_pressed("paint"):
		var mask = texture.get_image();
		var brush_size: int = erosion_settings.erodibility_brush_size;
		var target_position: Vector2 = mouse_position - Vector2.ONE * float(brush_size) / 2;
		draw(mask, target_position);
		#blend_image.convert(Image.FORMAT_RGBA8);
		var mouse_delta: Vector2 = mouse_position - last_mouse_position;
		var mouse_delta_direction: Vector2 = mouse_delta.normalized();
		var step: int = 0;
		while step < ceil(mouse_delta.length()):
			var draw_position: Vector2 = mouse_position - mouse_delta_direction * step - Vector2.ONE * float(brush_size) / 2;
			draw(mask, draw_position);
			step += max(1, floor(float(brush_size) / 8))
		texture = ImageTexture.create_from_image(mask);
	last_mouse_position = mouse_position;
