extends CanvasLayer

## Live spawn/perf counters. Drawn above the pixel world so leaks are visible in play.

var _spawner: LevelSpawner
var _label: Label


func _ready() -> void:
	layer = 21
	_spawner = get_parent().get_node_or_null("LevelSpawner") as LevelSpawner
	_label = Label.new()
	_label.name = "Stats"
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.offset_left = 16.0
	_label.offset_top = 12.0
	_label.offset_right = 420.0
	_label.offset_bottom = 220.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	_label.add_theme_constant_override("outline_size", 6)
	add_child(_label)


func _process(_delta: float) -> void:
	if _spawner == null:
		_label.text = "DEBUG\nLevelSpawner missing"
		return
	_label.text = "DEBUG\nPlatforms loaded: %d\nObstacles loaded: %d\nProcedural pads: %d\nWorldProps: %d\nPathHeads: %d\nRuntime nodes: %d\nFPS: %d" % [
		_spawner.debug_loaded_platforms(),
		_spawner.debug_loaded_obstacles(),
		_spawner.debug_procedural_pads(),
		_spawner.debug_world_prop_count(),
		_spawner.debug_path_head_count(),
		_spawner.debug_runtime_nodes(),
		int(Engine.get_frames_per_second())
	]
