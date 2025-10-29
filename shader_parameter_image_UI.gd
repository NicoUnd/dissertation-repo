extends Button
class_name ShaderParameterImageUI

signal image_selected(image_texture: ImageTexture)

@onready var select_heightmap_file_dialog: FileDialog = %SelectHeightmapFileDialog
@onready var failed_to_load_image_accept_dialog: AcceptDialog = %FailedToLoadImageAcceptDialog

func setup(shader_parameter: ShaderParameterImage) -> void:
	text = shader_parameter.name.capitalize();

func _on_pressed() -> void:
	select_heightmap_file_dialog.show();

func _on_file_dialog_file_selected(path: String) -> void:
	var image: Image = Image.new();
	var error: Error = image.load(path);
	
	if error != OK:
		failed_to_load_image_accept_dialog.show();
		return;
	
	if image.is_compressed():
		image.decompress();
	var texture: ImageTexture = ImageTexture.create_from_image(image);
	emit_signal("image_selected", texture);
