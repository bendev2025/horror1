extends Node

## Renders the 3D world at a low resolution, then upscales with nearest-neighbor.
## First-person arms render at full resolution on top so they stay sharp.

const WORLD_PIXEL_WIDTH := 320
const WORLD_PIXEL_HEIGHT := 180
## Visual render layer used only by the viewmodel. Must match FPArms.
const ARMS_LAYER_BIT := 1 << 19

var _player_cam: Camera3D
var _world_vp: SubViewport
var _world_cam: Camera3D
var _arms_vp: SubViewport
var _arms_cam: Camera3D


func _ready() -> void:
	_player_cam = get_node_or_null("../Player/Head/Camera3D") as Camera3D
	if _player_cam == null:
		push_error("PixelWorld: Player camera not found.")
		return
	_player_cam.current = false
	_build_world_pass()
	_build_arms_pass()
	get_viewport().size_changed.connect(_fit_arms_viewport)
	_fit_arms_viewport()


func _process(_delta: float) -> void:
	if _player_cam == null:
		return
	if _world_cam != null:
		_copy_camera(_player_cam, _world_cam)
	if _arms_cam != null:
		_copy_camera(_player_cam, _arms_cam)


func _build_world_pass() -> void:
	_world_vp = SubViewport.new()
	_world_vp.name = "WorldPixels"
	_world_vp.size = Vector2i(WORLD_PIXEL_WIDTH, WORLD_PIXEL_HEIGHT)
	_world_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_vp.handle_input_locally = false
	_world_vp.gui_disable_input = true
	_world_vp.own_world_3d = false
	add_child(_world_vp)

	_world_cam = Camera3D.new()
	_world_cam.name = "WorldCam"
	_world_cam.current = true
	_world_cam.cull_mask = 0xFFFFF & ~ARMS_LAYER_BIT
	_world_vp.add_child(_world_cam)

	var blit := TextureRect.new()
	blit.name = "WorldBlit"
	blit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blit.stretch_mode = TextureRect.STRETCH_SCALE
	blit.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	blit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blit.texture = _world_vp.get_texture()
	var layer := CanvasLayer.new()
	layer.name = "WorldLayer"
	layer.layer = 0
	layer.add_child(blit)
	add_child(layer)


func _build_arms_pass() -> void:
	_arms_vp = SubViewport.new()
	_arms_vp.name = "ArmsView"
	_arms_vp.transparent_bg = true
	_arms_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_arms_vp.handle_input_locally = false
	_arms_vp.gui_disable_input = true
	_arms_vp.own_world_3d = false
	add_child(_arms_vp)

	_arms_cam = Camera3D.new()
	_arms_cam.name = "ArmsCam"
	_arms_cam.current = true
	_arms_cam.cull_mask = ARMS_LAYER_BIT
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.fog_enabled = false
	env.glow_enabled = false
	_arms_cam.environment = env
	_arms_vp.add_child(_arms_cam)

	var blit := TextureRect.new()
	blit.name = "ArmsBlit"
	blit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blit.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blit.stretch_mode = TextureRect.STRETCH_SCALE
	blit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	blit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blit.texture = _arms_vp.get_texture()
	var layer := CanvasLayer.new()
	layer.name = "ArmsLayer"
	layer.layer = 10
	layer.add_child(blit)
	add_child(layer)


func _fit_arms_viewport() -> void:
	if _arms_vp == null:
		return
	var size := get_viewport().get_visible_rect().size
	_arms_vp.size = Vector2i(maxi(int(size.x), 2), maxi(int(size.y), 2))


func _copy_camera(from: Camera3D, to: Camera3D) -> void:
	to.global_transform = from.global_transform
	to.fov = from.fov
	to.near = from.near
	to.far = from.far
