extends Control
class_name ChunkSettings

const CHUNK_GRID_RESOLUTIONS: Array[int] = [1, 2, 4, 8, 16, 32];

enum LOD_PRESET {CENTRE, CORNER, EDGE}
var LOD_preset: LOD_PRESET:
	set(new_LOD_preset):
		LOD_preset = new_LOD_preset;
		apply_LOD_preset();

const CHUNK_TYPE_CELL_SCENE = preload("uid://xpucngsf7x4r");

@onready var main: Control = $".."

@onready var settings_v_box_container: VBoxContainer = %SettingsVBoxContainer

@onready var chunk_types_grid_container: GridContainer = %ChunkTypesGridContainer

var LOD_preset_sensitivity: float:
	set(new_LOD_preset_sensitivity):
		LOD_preset_sensitivity = new_LOD_preset_sensitivity;
		set_chunk_types_grid();

var chunk_grid_resolution: int:
	set(new_chunk_grid_resolution):
		chunk_grid_resolution = new_chunk_grid_resolution;
		set_chunk_types_grid();

static var LOD_brush: ChunkTypeCell.LODS = ChunkTypeCell.LODS.MAX;

func set_chunk_types_grid() -> void:
	print("SETTING CHUNK TYPES GRID")
	for chunk_type_cell: ChunkTypeCell in chunk_types_grid_container.get_children():
		chunk_type_cell.free();
	
	chunk_types_grid_container.columns = chunk_grid_resolution;
	
	for y: int in chunk_grid_resolution:
		for x: int in chunk_grid_resolution:
			var new_chunk_type_cell: ChunkTypeCell = CHUNK_TYPE_CELL_SCENE.instantiate();
			chunk_types_grid_container.add_child(new_chunk_type_cell);
	
	apply_LOD_preset();

func get_LOD_preset_max_distance(LOD_preset: LOD_PRESET) -> float:
	match LOD_preset:
		LOD_PRESET.CENTRE:
			return sqrt(chunk_grid_resolution * chunk_grid_resolution * 2) * 0.5;
		LOD_PRESET.CORNER:
			return sqrt(chunk_grid_resolution * chunk_grid_resolution * 2) * 0.9;
		LOD_PRESET.EDGE:
			return chunk_grid_resolution;
		_:
			push_error("Couldn't match LOD_PRESET");
			return 0;

func get_LOD_preset_distance(coord: Vector2i, LOD_preset: LOD_PRESET) -> float:
	match LOD_preset:
		LOD_PRESET.CENTRE:
			return coord.distance_to(Vector2i.ONE * chunk_grid_resolution/2);
		LOD_PRESET.CORNER:
			return coord.distance_to(Vector2i.ZERO);
		LOD_PRESET.EDGE:
			return coord.y;
		_:
			push_error("Couldn't match LOD_PRESET");
			return 0;

func apply_LOD_preset() -> void:
	var max_distance: float = get_LOD_preset_max_distance(LOD_preset);
	var y: int = 0;
	var x: int = 0;
	for chunk_type_cell: ChunkTypeCell in chunk_types_grid_container.get_children():
		var dist: float = get_LOD_preset_distance(Vector2i(x, y), LOD_preset);
		chunk_type_cell.LOD = clamp(int(8 * LOD_preset_sensitivity * dist / max_distance), 0, 7) as ChunkTypeCell.LODS;
		x = (x + 1) % chunk_grid_resolution;
		if x == 0:
			y += 1;

func get_resolutions() -> Array[Array]: # Array[Array[int]]
	var y: int = 0;
	var x: int = 0;
	var resolutions: Array[Array] = [];
	for chunk_type_cell: ChunkTypeCell in chunk_types_grid_container.get_children():
		if x == 0:
			resolutions.append([]);
		resolutions[y].append(chunk_type_cell.get_resolution(chunk_grid_resolution));
		x = (x + 1) % chunk_grid_resolution;
		if x == 0:
			y += 1;
	return resolutions;

func finish() -> void:
	var resolutions: Array[Array] = get_resolutions();
	main.terrain_generation_method_visualiser.set_planes(chunk_grid_resolution, resolutions);
	hide();
	for ui: Control in settings_v_box_container.get_children():
		ui.queue_free();

func _on_visibility_changed() -> void:
	if not visible:
		return;
	
	var chunk_grid_resolution_strings: Array[String] = [];
	for chunk_grid_resolution: int in CHUNK_GRID_RESOLUTIONS:
		chunk_grid_resolution_strings.append(str(chunk_grid_resolution) + "x" + str(chunk_grid_resolution));
	var chunk_grid_resolution_parameter: ParameterEnum = ParameterEnum.new("chunk_grid_resolution", 3, chunk_grid_resolution_strings);
	var chunk_grid_resolution_UI: ParameterOptionButtonUI = UI.parameter_to_parameter_ui(chunk_grid_resolution_parameter);
	settings_v_box_container.add_child(chunk_grid_resolution_UI);
	chunk_grid_resolution_UI.setup(chunk_grid_resolution_parameter, func (option: int): chunk_grid_resolution = CHUNK_GRID_RESOLUTIONS[option]);
	
	settings_v_box_container.add_child(HSeparator.new());
	
	var LOD_strings: Array[String] = [];
	for LOD_string in ChunkTypeCell.LODS.keys():
		LOD_strings.append(LOD_string);
	
	var LOD_brush_parameter: ParameterEnum = ParameterEnum.new("LOD_brush", 0, LOD_strings);
	var LOD_brush_UI: ParameterOptionButtonUI = UI.parameter_to_parameter_ui(LOD_brush_parameter);
	settings_v_box_container.add_child(LOD_brush_UI);
	LOD_brush_UI.setup(LOD_brush_parameter, func (option: int): LOD_brush = option as ChunkTypeCell.LODS);
	
	var LOD_fill_parameter: ParameterEnum = ParameterEnum.new("LOD_fill", 0, LOD_strings);
	var LOD_fill_UI: ParameterOptionButtonUI = UI.parameter_to_parameter_ui(LOD_fill_parameter);
	settings_v_box_container.add_child(LOD_fill_UI);
	LOD_fill_UI.setup(LOD_fill_parameter, func (option: int): for chunk_type_cell: ChunkTypeCell in chunk_types_grid_container.get_children(): chunk_type_cell.LOD = option as ChunkTypeCell.LODS);
	
	settings_v_box_container.add_child(HSeparator.new());
	
	var LOD_preset_sensitivity_parameter: ParameterNumber = ParameterNumber.new("sensitivity", 1, 0.25, 4, false, false, true);
	var LOD_preset_sensitivity_UI: ParameterSliderUI = UI.parameter_to_parameter_ui(LOD_preset_sensitivity_parameter);
	settings_v_box_container.add_child(LOD_preset_sensitivity_UI);
	LOD_preset_sensitivity_UI.setup(LOD_preset_sensitivity_parameter, func (value: float): LOD_preset_sensitivity = value);
	
	var LOD_preset_strings: Array[String] = [];
	for LOD_preset_string in LOD_PRESET.keys():
		LOD_preset_strings.append(LOD_preset_string);
	var LOD_preset_parameter: ParameterEnum = ParameterEnum.new("LOD_preset", 0, LOD_preset_strings);
	var LOD_preset_UI: ParameterOptionButtonUI = UI.parameter_to_parameter_ui(LOD_preset_parameter);
	settings_v_box_container.add_child(LOD_preset_UI);
	LOD_preset_UI.setup(LOD_preset_parameter, func (option): LOD_preset = option as LOD_PRESET);
	
	settings_v_box_container.add_child(HSeparator.new());
	
	var finish_parameter: ParameterButton = ParameterButton.new("finish");
	var finish_UI: ParameterButtonUI = UI.parameter_to_parameter_ui(finish_parameter);
	settings_v_box_container.add_child(finish_UI);
	finish_UI.setup(finish_parameter, finish);
	
	LOD_preset = LOD_PRESET.CENTRE;
	LOD_preset_sensitivity = 1;
	chunk_grid_resolution = 8;
