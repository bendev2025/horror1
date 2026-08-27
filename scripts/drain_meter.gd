extends CanvasLayer

## Bottom-left HUD: current walk speed (M/s) and a percent that drains over one minute.

const DRAIN_SECONDS := 60.0

var _charge := 100.0
var _label: Label
var _speed_label: Label
var _player: Player


func _ready() -> void:
	layer = 20
	add_to_group("drain_meter")
	_player = get_parent().get_node_or_null("Player") as Player
	_speed_label = _make_hud_label("Speed", -96.0, -56.0, 22)
	_label = _make_hud_label("Percent", -56.0, -16.0, 28)
	_refresh()


func _make_hud_label(label_name: String, offset_top: float, offset_bottom: float, font_size: int) -> Label:
	var label := Label.new()
	label.name = label_name
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.grow_horizontal = Control.GROW_DIRECTION_END
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	label.offset_left = 16.0
	label.offset_top = offset_top
	label.offset_right = 280.0
	label.offset_bottom = offset_bottom
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.7, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.92))
	label.add_theme_constant_override("outline_size", 8)
	add_child(label)
	return label


func _process(delta: float) -> void:
	if _charge > 0.0:
		_charge = maxf(_charge - (100.0 / DRAIN_SECONDS) * delta, 0.0)
	_refresh()


func add_charge(percent: float) -> void:
	_charge = clampf(_charge + percent, 0.0, 100.0)
	_refresh()


func _refresh() -> void:
	_label.text = "%d%%" % clampi(roundi(_charge), 0, 100)
	var speed := 0.0
	if _player != null:
		speed = Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	_speed_label.text = "%.1f M/s" % speed
