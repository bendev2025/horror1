extends Area3D
class_name BatteryPickup

## Ground loot. Click while looking at it (within pickup radius) to restore charge.

const SPRITE_PATH := "res://assets/battery.png"
const PIXEL_SIZE := 0.008
const CLICK_RADIUS := 0.28

var _restore_percent: float = 20.0
var _pickup_radius: float = 2.0
var _player: Player
var _drain: CanvasLayer
var _bob_t: float = 0.0
var _base_y: float = 0.0
var _taken: bool = false


func setup(restore_percent: float, pickup_radius: float, player: Player, drain: CanvasLayer) -> void:
	_restore_percent = restore_percent
	_pickup_radius = maxf(pickup_radius, 0.2)
	_player = player
	_drain = drain
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("battery")
	_build_visual()
	var sphere := SphereShape3D.new()
	sphere.radius = CLICK_RADIUS
	var col := CollisionShape3D.new()
	col.shape = sphere
	add_child(col)
	_bob_t = randf() * TAU
	_base_y = position.y


func can_pickup_from(from_pos: Vector3) -> bool:
	if _taken:
		return false
	return from_pos.distance_to(global_position) <= _pickup_radius


func try_pickup() -> bool:
	if _taken:
		return false
	if _player != null and not can_pickup_from(_player.global_position):
		return false
	_taken = true
	if _drain != null and _drain.has_method("add_charge"):
		_drain.add_charge(_restore_percent)
	queue_free()
	return true


func _build_visual() -> void:
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = _load_png(SPRITE_PATH)
	sprite.pixel_size = PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.double_sided = true
	sprite.transparent = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.55, 0.18, 1.0)
	light.light_energy = 0.35
	light.omni_range = 1.6
	add_child(light)


func _load_png(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		push_error("BatteryPickup: could not load %s" % path)
		return null
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	if _taken:
		return
	_bob_t += delta * 3.2
	position.y = _base_y + sin(_bob_t) * 0.06
	if _player != null and _player.global_position.distance_to(global_position) > 90.0:
		queue_free()
