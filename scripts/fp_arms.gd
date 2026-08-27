extends Node3D
class_name FPArms

# ============================================================
# KNIFE SETTINGS
# ============================================================

@export_group("Knife")

## Seconds to pull the knife out on the first click.
@export var knife_draw_time: float = 0.22
## Seconds to put the knife away on right-click.
@export var knife_holster_time: float = 0.22

## Step 1: seconds to move to the raise point.
@export var knife_raise_time: float = 0.05
## Step 2: seconds to hold at the raise point.
@export var knife_hold_time: float = 0.1
## Step 3: seconds to swing down to rest.
@export var knife_swing_time: float = 0.05
## Clockwise roll (degrees) at the raised hold, before the swing down.
@export var knife_raise_rot_deg: float = 20.0
## Clockwise roll (degrees) on the swing back to rest. Peaks mid-swing, 0 at both ends.
@export var knife_swing_rot_deg: float = 70.0

## Design resolution for raise X/Y pixels.
@export var knife_screen_width: float = 1200.0
@export var knife_screen_height: float = 1920.0
## Raise point in that pixel space. End of the swing is the original rest pose.
@export var knife_raise_x: float = 600.0
@export var knife_raise_y: float = 1050.0

## Extra local offset while the knife is out and idle.
@export var knife_hold_offset: Vector3 = Vector3(0.01, 0.012, -0.018)
## Extra rotation (degrees) while the knife is out and idle.
@export var knife_hold_rot_deg: Vector3 = Vector3(-8.0, 6.0, 10.0)
## Extra local offset while drawing the knife out.
@export var knife_draw_lift: Vector3 = Vector3(0.02, -0.06, 0.04)
## Extra rotation (degrees) while drawing the knife out.
@export var knife_draw_lift_rot_deg: Vector3 = Vector3(22.0, 0.0, -8.0)
## Walk speed while the knife is drawn. 0.8 = 20% slower.
@export var knife_move_scale: float = 0.8

## First-person arms using the Pixelorama sprite in `assets/`.
## Sprint/slide: open hands. Everything else: closed fists.
## Drawn knife uses the right-arm-with-knife drawing on the right fist.

const ARM_LEFT_PATH := "res://assets/arm_left.png"
const ARM_RIGHT_PATH := "res://assets/arm_right.png"
const ARM_SPRINT_LEFT_PATH := "res://assets/arm_sprint_left.png"
const ARM_SPRINT_RIGHT_PATH := "res://assets/arm_sprint_right.png"
const ARM_RIGHT_KNIFE_PATH := "res://assets/arm_right_knife.png"

var settings: MovementSettings

var _player: Player
var _head: Node3D
var _left: Node3D
var _right: Node3D
var _left_sprite: Sprite3D
var _right_sprite: Sprite3D
var _tex_left: Texture2D
var _tex_right: Texture2D
var _tex_sprint_left: Texture2D
var _tex_sprint_right: Texture2D
var _tex_right_knife: Texture2D
var _sprint_hands: bool = false
var _left_rest_pos: Vector3
var _right_rest_pos: Vector3
var _left_rest_rot: Vector3
var _right_rest_rot: Vector3

var _left_pos: Vector3
var _right_pos: Vector3
var _left_rot: Vector3
var _right_rot: Vector3

var _stride: float = 0.0
var _breathe_t: float = 0.0
var _slide_dist: float = 0.0
var _was_on_floor: bool = true
var _air_vel_y: float = 0.0
var _landing: float = 0.0
var _prev_yaw: float = 0.0
var _prev_pitch: float = 0.0
var _yaw_sway: float = 0.0
var _pitch_sway: float = 0.0
var _air_x: float = 0.0

var _knife_out: bool = false
var _knife_draw_t: float = 0.0
var _knife_swing_t: float = -1.0
var _knife_holster_t: float = -1.0
var _knife_slice_armed: bool = false
var _knife_pending_slice: bool = false


func _ready() -> void:
	_player = _find_player()
	_build_arms()
	# Head is an @onready on Player, so it is still null while this child
	# _ready() runs. Read the node from the tree instead.
	if _player != null:
		_head = _player.get_node_or_null("Head") as Node3D
		_prev_yaw = _player.rotation.y
		if _head != null:
			_prev_pitch = _head.rotation.x
		_was_on_floor = _player.is_on_floor()
	_bind_settings()


func _bind_settings() -> void:
	if _player != null:
		settings = _player.settings


func _handle_knife_input() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if Input.is_action_just_pressed("holster"):
		_start_holster()
		return
	if not Input.is_action_just_pressed("attack"):
		return
	if _try_click_battery():
		return
	if _player._is_hanging or _player._is_climbing or _player._is_vaulting or _player._is_wall_climbing:
		return
	if not _knife_out:
		_knife_out = true
		_knife_draw_t = 0.0
		_refresh_hand_sprites()
		return
	# Ignore clicks until the current draw, slash, or holster has fully finished.
	if _knife_draw_t < knife_draw_time or _knife_swinging() or _knife_holstering():
		return
	_start_knife_swing()


func is_knife_drawn() -> bool:
	return _knife_out


func _start_knife_swing() -> void:
	_knife_swing_t = 0.0
	_knife_slice_armed = true
	_knife_pending_slice = false


func _knife_holstering() -> bool:
	return _knife_holster_t >= 0.0


func _start_holster() -> void:
	if not _knife_out or _knife_holstering():
		return
	_knife_swing_t = -1.0
	_knife_slice_armed = false
	_knife_pending_slice = false
	if _knife_draw_t < knife_draw_time:
		var draw_u := clampf(_knife_draw_t / maxf(knife_draw_time, 0.01), 0.0, 1.0)
		_knife_holster_t = (1.0 - draw_u) * maxf(knife_holster_time, 0.01)
		_knife_draw_t = knife_draw_time
	else:
		_knife_holster_t = 0.0


func _finish_holster() -> void:
	_knife_out = false
	_knife_holster_t = -1.0
	_knife_swing_t = -1.0
	_knife_draw_t = 0.0
	_refresh_hand_sprites()


func _knife_attack_duration() -> float:
	return maxf(knife_raise_time, 0.0) + maxf(knife_hold_time, 0.0) + maxf(knife_swing_time, 0.0)


func _knife_swinging() -> bool:
	return _knife_swing_t >= 0.0


func _screen_px_to_local(px: float, py: float) -> Vector3:
	var cam := get_parent() as Camera3D
	if cam == null:
		return _right_rest_pos
	var vp := get_viewport().get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return _right_rest_pos
	var design_w := maxf(knife_screen_width, 1.0)
	var design_h := maxf(knife_screen_height, 1.0)
	var screen := Vector2(px / design_w * vp.x, py / design_h * vp.y)
	var depth := absf(_right_rest_pos.z)
	if depth < 0.001:
		depth = settings.arm_distance
	return to_local(cam.project_position(screen, depth))


func _knife_raise_pos() -> Vector3:
	return _screen_px_to_local(knife_raise_x, knife_raise_y)


func _knife_attack_pos(rest: Vector3) -> Vector3:
	var raised := _knife_raise_pos()
	var t := _knife_swing_t
	var raise_t := maxf(knife_raise_time, 0.1)
	var hold_t := maxf(knife_hold_time, 0.05)
	if t < raise_t:
		var u := clampf(t / raise_t, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		return rest.lerp(raised, u)
	if t < raise_t + hold_t:
		return raised
	var u := _knife_swing_down_u()
	return raised.lerp(rest, u)


func _knife_swing_down_u() -> float:
	var raise_t := maxf(knife_raise_time, 0.1)
	var hold_t := maxf(knife_hold_time, 0.05)
	var swing_t := maxf(knife_swing_time, 0.1)
	var t := _knife_swing_t
	if t < raise_t + hold_t:
		return 0.0
	var u := clampf((t - raise_t - hold_t) / swing_t, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


func _knife_attack_rot() -> Vector3:
	# Clockwise on screen is negative local Z.
	var raise_t := maxf(knife_raise_time, 0.1)
	var hold_t := maxf(knife_hold_time, 0.05)
	var t := _knife_swing_t
	var raise_spin := 0.0
	if t < raise_t:
		var u := clampf(t / raise_t, 0.0, 1.0)
		u = u * u * (3.0 - 2.0 * u)
		raise_spin = u
	elif t < raise_t + hold_t:
		raise_spin = 1.0
	else:
		raise_spin = 1.0 - _knife_swing_down_u()
	var swing_u := _knife_swing_down_u()
	var swing_spin := 0.0
	if swing_u > 0.0 and swing_u < 1.0:
		swing_spin = sin(swing_u * PI)
	var spin := raise_spin * knife_raise_rot_deg + swing_spin * knife_swing_rot_deg
	return Vector3(0.0, 0.0, deg_to_rad(-spin))


func _update_knife(delta: float) -> void:
	if not _knife_out:
		return
	if _knife_holstering():
		_knife_holster_t += delta
		if _knife_holster_t >= knife_holster_time:
			_finish_holster()
		return
	if _knife_draw_t < knife_draw_time:
		_knife_draw_t += delta
		return
	if _knife_swing_t >= 0.0:
		_knife_swing_t += delta
		if _knife_slice_armed and _knife_swing_down_u() > 0.001:
			_knife_slice_armed = false
			_knife_pending_slice = true
		if _knife_swing_t >= _knife_attack_duration():
			_knife_swing_t = -1.0


func _physics_process(_delta: float) -> void:
	_bind_settings()
	if _player == null or settings == null:
		return
	# Sample after Player.move_and_slide (parent runs first).
	if not _player.is_on_floor():
		_air_vel_y = _player.velocity.y
	elif not _was_on_floor:
		var impact := 0.0
		if settings.landing_ref_speed > 0.0:
			impact = clampf(-_air_vel_y / settings.landing_ref_speed, 0.0, 1.35)
		_landing = maxf(_landing, impact * settings.landing_impact)
	_was_on_floor = _player.is_on_floor()
	if _knife_pending_slice:
		_knife_pending_slice = false
		_try_slice_crate()


func _try_click_battery() -> bool:
	if _player == null:
		return false
	var cam := get_parent() as Camera3D
	if cam == null:
		return false
	var spawner := get_tree().get_first_node_in_group("level_spawner") as LevelSpawner
	var reach := 2.0
	if spawner != null:
		reach = maxf(spawner.BATTERY_PICKUP_RADIUS, 0.4)
	var space := _player.get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from + -cam.global_transform.basis.z * reach
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()])
	ray.collide_with_areas = true
	ray.collide_with_bodies = true
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return false
	var node := hit.get("collider") as Node
	while node != null:
		if node is BatteryPickup:
			var bat := node as BatteryPickup
			if bat.can_pickup_from(_player.global_position):
				return bat.try_pickup()
			return false
		node = node.get_parent()
	return false


func _try_slice_crate() -> void:
	if _player == null:
		return
	var cam := get_parent() as Camera3D
	if cam == null:
		return
	var spawner := get_tree().get_first_node_in_group("level_spawner") as LevelSpawner
	var reach := 2.4
	if spawner != null:
		reach = maxf(spawner.CRATE_HIT_RANGE, 0.4)
	var space := _player.get_world_3d().direct_space_state
	var from := cam.global_position
	var forward := -cam.global_transform.basis.z
	var to := from + forward * reach
	var ray := PhysicsRayQueryParameters3D.create(from, to, 1, [_player.get_rid()])
	var hit := space.intersect_ray(ray)
	if _apply_crate_hit(hit):
		return
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = sphere
	q.transform = Transform3D(Basis.IDENTITY, from + forward * minf(reach * 0.55, 1.4))
	q.collision_mask = 1
	q.exclude.append(_player.get_rid())
	var hits := space.intersect_shape(q, 8)
	var best: WoodenCrate = null
	var best_d := INF
	for entry in hits:
		var crate := _crate_from_collider(entry.get("collider"))
		if crate == null or not crate.is_locked():
			continue
		var d: float = crate.global_position.distance_squared_to(from)
		if d < best_d:
			best_d = d
			best = crate
	if best != null:
		best.take_hit()


func _apply_crate_hit(hit: Dictionary) -> bool:
	if hit.is_empty():
		return false
	var crate := _crate_from_collider(hit.get("collider"))
	if crate == null or not crate.is_locked():
		return false
	crate.take_hit()
	return true


func _crate_from_collider(collider: Variant) -> WoodenCrate:
	var node := collider as Node
	while node != null:
		if node is WoodenCrate:
			return node as WoodenCrate
		node = node.get_parent()
	return null


func _process(delta: float) -> void:
	_bind_settings()
	if _player == null or settings == null:
		return
	if _left == null or _right == null or _head == null:
		return
	visible = not settings.third_person
	if not visible:
		return
	_handle_knife_input()
	_apply_arm_view()
	_update_sway(delta)
	_update_arms(delta)
	_update_knife(delta)


func _update_sway(delta: float) -> void:
	var yaw := _player.rotation.y
	var pitch := _head.rotation.x
	var yaw_rate := wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.0001)
	var pitch_rate := (pitch - _prev_pitch) / maxf(delta, 0.0001)
	_prev_yaw = yaw
	_prev_pitch = pitch

	# Lag opposite the camera so the arms feel like they have mass.
	var yaw_target := clampf(
		-yaw_rate * deg_to_rad(settings.turn_sway),
		deg_to_rad(-settings.max_turn_sway_deg),
		deg_to_rad(settings.max_turn_sway_deg)
	)
	var pitch_target := clampf(
		-pitch_rate * deg_to_rad(settings.turn_sway) * 0.45,
		deg_to_rad(-settings.max_turn_sway_deg) * 0.5,
		deg_to_rad(settings.max_turn_sway_deg) * 0.5
	)
	var sway_blend := 1.0 - exp(-settings.sway_recover * delta)
	_yaw_sway = lerpf(_yaw_sway, yaw_target, sway_blend)
	_pitch_sway = lerpf(_pitch_sway, pitch_target, sway_blend)
	rotation = Vector3(_pitch_sway, _yaw_sway, -_yaw_sway * 0.25)


func _update_arms(delta: float) -> void:
	var hvel := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var speed := hvel.length()
	var on_floor := _player.is_on_floor()
	var sliding: bool = _player._is_sliding
	var hanging: bool = _player._is_hanging or _player._is_wall_climbing
	var climbing: bool = _player._is_climbing
	var vaulting: bool = _player._is_vaulting
	var climb_t: float = _player._climb_t
	var vel_y := _player.velocity.y

	_landing = move_toward(_landing, 0.0, settings.landing_recover_speed * delta)

	var sprint_t := 0.0
	var span := settings.sprint_full_speed - settings.sprint_start_speed
	if span > 0.001:
		sprint_t = clampf((speed - settings.sprint_start_speed) / span, 0.0, 1.0)

	var moving := on_floor and not sliding and not hanging and not climbing and not vaulting
	if moving and speed > settings.idle_speed_threshold:
		var freq := settings.swing_speed * lerpf(1.0, settings.sprint_freq, sprint_t)
		_stride += speed * freq * delta
	if sliding:
		_slide_dist += speed * delta
	else:
		_slide_dist = 0.0

	# Open hands only while sliding or sprinting. Every other pose uses closed fists.
	var want_sprint := sliding or (on_floor and speed > settings.sprint_start_speed)
	if hanging or climbing or vaulting or (not on_floor and not sliding):
		want_sprint = false
	_set_sprint_hands(want_sprint)
	_refresh_hand_sprites()

	_breathe_t += delta * settings.breathe_rate * TAU

	var local_vel := _player.global_transform.basis.inverse() * _player.velocity
	var air_target := 0.0
	if not on_floor and not hanging and not climbing:
		if _player.settings.move_speed > 0.001:
			air_target = clampf(local_vel.x / _player.settings.move_speed, -1.0, 1.0)
	var air_blend := 1.0 - exp(-settings.transition_smoothness * delta)
	_air_x = lerpf(_air_x, air_target, air_blend)

	var left_off := Vector3.ZERO
	var right_off := Vector3.ZERO
	var left_rot := Vector3.ZERO
	var right_rot := Vector3.ZERO

	if hanging or climbing:
		var reach := settings.hang_pose
		var pitch := settings.hang_pitch_deg
		if climbing:
			reach += settings.climb_pose * clampf(climb_t, 0.0, 1.0)
			pitch += settings.climb_pitch_deg * clampf(climb_t, 0.0, 1.0)
		left_off = Vector3(-reach.x, reach.y, reach.z)
		right_off = Vector3(reach.x, reach.y, reach.z)
		left_rot = Vector3(deg_to_rad(pitch), deg_to_rad(-4.0), deg_to_rad(-6.0))
		right_rot = Vector3(deg_to_rad(pitch), deg_to_rad(4.0), deg_to_rad(6.0))
	elif sliding:
		var sway := sin(_slide_dist * settings.slide_sway_speed) * settings.slide_sway_amount
		var slide := settings.slide_pose
		left_off = Vector3(-0.01, slide.y, slide.z + sway)
		right_off = Vector3(0.01, slide.y, slide.z + sway)
		left_rot = Vector3(deg_to_rad(settings.slide_pitch_deg), 0.0, deg_to_rad(4.0))
		right_rot = Vector3(deg_to_rad(settings.slide_pitch_deg), 0.0, deg_to_rad(-4.0))
	elif vaulting:
		var jp := settings.jump_pose
		left_off = Vector3(-jp.x * 0.6, jp.y * 0.7, -0.03)
		right_off = Vector3(jp.x * 0.6, jp.y * 0.7, -0.03)
		left_rot = Vector3(deg_to_rad(settings.jump_pitch_deg * 0.5), 0.0, 0.0)
		right_rot = Vector3(deg_to_rad(settings.jump_pitch_deg * 0.5), 0.0, 0.0)
	elif not on_floor:
		var jump_w := 0.0
		if settings.jump_ref_speed > 0.001:
			jump_w = clampf(vel_y / settings.jump_ref_speed, 0.0, 1.0)
		var fall_w := 0.0
		if settings.fall_ref_speed > 0.001:
			fall_w = clampf(-vel_y / settings.fall_ref_speed, 0.0, 1.0)
		var jp := settings.jump_pose * jump_w
		var fp := settings.fall_pose * fall_w
		var combined := jp + fp
		left_off = Vector3(-combined.x, combined.y, combined.z)
		right_off = Vector3(combined.x, combined.y, combined.z)
		var pitch := settings.jump_pitch_deg * jump_w + settings.fall_pitch_deg * fall_w
		left_rot = Vector3(deg_to_rad(pitch), 0.0, deg_to_rad(-4.0 * fall_w))
		right_rot = Vector3(deg_to_rad(pitch), 0.0, deg_to_rad(4.0 * fall_w))
		left_off.x += _air_x * settings.air_control_amount
		right_off.x += _air_x * settings.air_control_amount
	elif speed <= settings.idle_speed_threshold:
		var breathe := sin(_breathe_t) * settings.breathe_amount
		left_off = Vector3(0.0, breathe, breathe * 0.35)
		right_off = Vector3(0.0, breathe, breathe * 0.35)
	else:
		var s := sin(_stride)
		var c := sin(_stride + PI)
		# Walk still uses a small shoulder twist. Sprint does not rotate:
		# one arm goes up while the other goes down.
		var walk := 1.0 - sprint_t
		var bob := absf(s) * settings.bob_amount * walk
		var pitch_amp := settings.swing_amount * 7.0 * walk
		var yaw_amp := 0.04 * walk
		var roll_amp := 0.05 * walk
		var pump := settings.sprint_height * lerpf(1.0, settings.sprint_intensity, sprint_t) * sprint_t
		left_off = Vector3(0.0, bob + s * pump, 0.0)
		right_off = Vector3(0.0, bob + c * pump, 0.0)
		left_rot = Vector3(-s * pitch_amp, s * yaw_amp, s * roll_amp)
		right_rot = Vector3(-c * pitch_amp, c * yaw_amp, c * roll_amp)

	if _landing > 0.001 and not hanging and not climbing:
		var dip := settings.landing_pose * _landing
		left_off += dip
		right_off += dip
		left_rot.x += deg_to_rad(10.0) * _landing
		right_rot.x += deg_to_rad(10.0) * _landing

	if _knife_out:
		if not _sprint_hands:
			right_off += knife_hold_offset
			right_rot += Vector3(
				deg_to_rad(knife_hold_rot_deg.x),
				deg_to_rad(knife_hold_rot_deg.y),
				deg_to_rad(knife_hold_rot_deg.z)
			)
			var lift := 0.0
			if _knife_holstering():
				lift = clampf(_knife_holster_t / maxf(knife_holster_time, 0.01), 0.0, 1.0)
			elif _knife_draw_t < knife_draw_time:
				var draw_u := clampf(_knife_draw_t / maxf(knife_draw_time, 0.01), 0.0, 1.0)
				lift = 1.0 - draw_u
			if lift > 0.0:
				right_off += knife_draw_lift * lift
				right_rot += Vector3(
					deg_to_rad(knife_draw_lift_rot_deg.x) * lift,
					deg_to_rad(knife_draw_lift_rot_deg.y) * lift,
					deg_to_rad(knife_draw_lift_rot_deg.z) * lift
				)

	var lerp_speed := settings.transition_smoothness
	if _landing > 0.12:
		lerp_speed = settings.landing_snap
	var blend := 1.0 - exp(-lerp_speed * delta)
	_left_pos = _left_pos.lerp(_left_rest_pos + left_off, blend)
	_left_rot = _left_rot.lerp(_left_rest_rot + left_rot, blend)
	if _knife_swinging():
		var rest := _right_rest_pos + right_off
		_right_pos = _knife_attack_pos(rest)
		_right_rot = _right_rest_rot + right_rot + _knife_attack_rot()
	else:
		_right_pos = _right_pos.lerp(_right_rest_pos + right_off, blend)
		_right_rot = _right_rot.lerp(_right_rest_rot + right_rot, blend)

	_left.position = _left_pos
	_right.position = _right_pos
	_left.rotation = _left_rot
	_right.rotation = _right_rot


func _build_arms() -> void:
	# Fists stay crossed (right drawing on the left hand, left on the right).
	# Sprint drawings keep left-on-left / right-on-right.
	_tex_left = _load_png(ARM_LEFT_PATH)
	_tex_right = _load_png(ARM_RIGHT_PATH)
	_tex_sprint_left = _load_png(ARM_SPRINT_RIGHT_PATH)
	_tex_sprint_right = _load_png(ARM_SPRINT_LEFT_PATH)
	_tex_right_knife = _load_png(ARM_RIGHT_KNIFE_PATH)
	_left = _make_arm(-1.0)
	_right = _make_arm(1.0)
	add_child(_left)
	add_child(_right)
	_left_rest_pos = _left.position
	_right_rest_pos = _right.position
	_left_rest_rot = _left.rotation
	_right_rest_rot = _right.rotation
	_left_pos = _left_rest_pos
	_right_pos = _right_rest_pos
	_left_rot = _left_rest_rot
	_right_rot = _right_rest_rot


func _apply_arm_view() -> void:
	_left_rest_pos = Vector3(-settings.arm_spread, settings.arm_height, -settings.arm_distance)
	_right_rest_pos = Vector3(settings.arm_spread, settings.arm_height, -settings.arm_distance)
	_apply_sprite_view(_left_sprite)
	_apply_sprite_view(_right_sprite)


func _apply_sprite_view(sprite: Sprite3D) -> void:
	if sprite == null:
		return
	sprite.pixel_size = settings.arm_size
	if sprite.texture != null:
		var hidden := (1.0 - clampf(settings.arm_visible, 0.0, 1.0)) * 0.5
		sprite.offset = Vector2(0.0, -float(sprite.texture.get_height()) * hidden)


func _make_arm(side: float) -> Node3D:
	var arm := Node3D.new()
	arm.name = "LeftArm" if side < 0.0 else "RightArm"
	arm.position = Vector3(0.15 * side, -0.05, -0.26)
	arm.rotation_degrees = Vector3(4.0, -8.0 * side, 3.0 * side)

	var tex := _tex_left if side < 0.0 else _tex_right
	var sprite := Sprite3D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	sprite.pixel_size = 0.012
	sprite.shaded = false
	sprite.double_sided = true
	sprite.transparent = true
	sprite.no_depth_test = true
	sprite.render_priority = 16
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sprite.layers = 1 << 19
	sprite.centered = true
	if tex != null:
		# Keep most of the sleeve on screen. A bottom pivot hid the arm under the view.
		sprite.offset = Vector2(0.0, -float(tex.get_height()) * 0.18)
	arm.add_child(sprite)
	if side < 0.0:
		_left_sprite = sprite
	else:
		_right_sprite = sprite

	return arm


func _set_sprint_hands(sprint_hands: bool) -> void:
	_sprint_hands = sprint_hands


func _refresh_hand_sprites() -> void:
	if _left_sprite != null:
		_left_sprite.texture = _tex_sprint_left if _sprint_hands else _tex_left
	if _right_sprite != null:
		if _knife_out:
			_right_sprite.texture = _tex_right_knife
		elif _sprint_hands:
			_right_sprite.texture = _tex_sprint_right
		else:
			_right_sprite.texture = _tex_right
	_apply_sprite_view(_left_sprite)
	_apply_sprite_view(_right_sprite)


func _load_png(path: String) -> Texture2D:
	var img := Image.new()
	if img.load(path) != OK:
		push_error("FPArms: could not load %s" % path)
		return null
	return ImageTexture.create_from_image(img)


func _find_player() -> Player:
	var node: Node = get_parent()
	while node != null:
		if node is Player:
			return node as Player
		node = node.get_parent()
	return null
