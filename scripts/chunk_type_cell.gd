extends Panel
class_name ChunkTypeCell

enum LODS {MAX, VERY_HIGH, HIGH, MEDIUM, LOW, VERY_LOW, MIN, UNLOADED}
const LOD_COLOURS: Array[Color] = [Color.GREEN, Color.FOREST_GREEN, Color.OLIVE, Color.GOLD, Color.DARK_ORANGE, Color.CRIMSON, Color.BROWN, Color.DIM_GRAY];
const LOD_RESOLUTION_FACTORS: Array[int] = [4096, 2048, 1024, 512, 256, 128, 64, 0];
var LOD: LODS:
	set(new_LOD):
		LOD = new_LOD;
		modulate = LOD_COLOURS[LOD];

var mouse_over: bool = false;
func _on_mouse_entered() -> void:
	mouse_over = true;
func _on_mouse_exited() -> void:
	mouse_over = false;
func _process(delta: float) -> void:
	if mouse_over and Input.is_action_pressed("paint"):
		LOD = ChunkSettings.LOD_brush;

func get_resolution(chunk_grid_resolution: int) -> int:
	@warning_ignore("integer_division")
	return LOD_RESOLUTION_FACTORS[LOD] / chunk_grid_resolution;
