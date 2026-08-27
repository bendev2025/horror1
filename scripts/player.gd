extends CharacterBody3D
class_name Player

## First-person CharacterBody3D controller: WASD, gravity, jump, mouse look, slide, vault, ledge grab, wall climb (Space).
##
## Expected scene tree:
##   Player (CharacterBody3D)  [this script]
##   ├── CollisionShape3D
##   └── Head (Node3D)         # pitch (look up/down) is applied here
##       └── Camera3D
##           └── FPArms        # viewmodel; knife-out also slows walk speed
##
## Tune feel in `scripts/movement_settings.gd`. Those defaults are what the
## player uses at runtime.
##
## Input Map actions (Project Settings → Input Map):
##   move_forward, move_back, move_left, move_right, jump, slide

var settings: MovementSettings

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var fp_arms: FPArms = $Head/Camera3D/FPArms
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var stand_check: ShapeCast3D = $StandCheck
@onready var body_mesh: MeshInstance3D = $BodyMesh

var _capsule: CapsuleShape3D
var _stand_height: float
var _stand_head_y: float
var _is_sliding: bool = false
var _slide_time_left: float = 0.0
var _slide_direction: Vector3 = Vector3.ZERO

var _is_vaulting: bool = false
var _vault_t: float = 0.0
var _vault_start: Vector3 = Vector3.ZERO
var _vault_end: Vector3 = Vector3.ZERO
var _vault_apex_y: float = 0.0
var _vault_exit_dir: Vector3 = Vector3.FORWARD
var _vault_obstacle: CollisionObject3D = null
var _vault_saved_snap: float = 0.2

var _is_hanging: bool = false
var _is_climbing: bool = false
var _ledge_normal: Vector3 = Vector3.FORWARD
var _ledge_y: float = 0.0
var _ledge_body: CollisionObject3D = null
var _climb_t: float = 0.0
var _climb_start: Vector3 = Vector3.ZERO
var _climb_end: Vector3 = Vector3.ZERO

var _is_wall_climbing: bool = false
var _climb_wall: CollisionObject3D = null
var _wall_normal: Vector3 = Vector3.FORWARD
var _wall_saved_snap: float = 0.2
var _was_on_floor: bool = true
var _airborne_peak_y: float = 0.0
var _flip_t: float = -1.0
var _ladder_flip_armed: bool = false
var _sprint_cam_t: float = 0.0


func _ready() -> void:
	# Always use the current defaults from movement_settings.gd.
	settings = MovementSettings.new()
	add_to_group("player")
	_ensure_slide_action()
	# Keep the camera glued to the window; Escape releases it (see _unhandled_input).
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = settings.floor_snap_length

	_capsule = collision_shape.shape.duplicate() as CapsuleShape3D
	collision_shape.shape = _capsule
	_stand_height = _capsule.height
	_stand_head_y = head.position.y
	_setup_stand_check()
	_apply_camera_mode()
	_apply_display_settings()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_mouse_capture()
		get_viewport().set_input_as_handled()
		return

	# Click the game window to recapture the cursor after releasing it.
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_mouse_look(event.relative)


func _physics_process(delta: float) -> void:
	if _is_climbing:
		_apply_ledge_climb(delta)
		_lerp_camera(delta)
		move_and_slide()
		return

	if _is_hanging:
		_update_hang()
		_lerp_camera(delta)
		move_and_slide()
		return

	if _is_wall_climbing:
		_apply_wall_climb(delta)
		_lerp_camera(delta)
		return

	if _try_start_wall_climb():
		_apply_wall_climb(delta)
		_lerp_camera(delta)
		return

	if not _is_vaulting:
		_try_start_vault()

	if _is_vaulting:
		_apply_vault(delta)
		_lerp_camera(delta)
		move_and_slide()
		return

	_update_slide(delta)
	_apply_gravity(delta)
	_apply_jump()
	_apply_movement(delta)
	_lerp_camera(delta)
	move_and_slide()
	_update_fall_flip()
	if not _is_sliding:
		_try_grab_ledge()
	# After moving, stand up as soon as the ceiling check is clear.
	if _is_sliding and (not Input.is_action_pressed("slide") or _slide_time_left <= 0.0):
		_try_end_slide()


func _update_slide(delta: float) -> void:
	if not _is_sliding and Input.is_action_just_pressed("slide") and _is_near_floor():
		_start_slide()
		return

	if not _is_sliding:
		return

	if _slide_time_left > 0.0:
		_slide_time_left -= delta
		if _slide_time_left < 0.0:
			_slide_time_left = 0.0

	# Let go of the slide key (or run out the duration) to stand up,
	# unless a ceiling is still in the way.
	if not Input.is_action_pressed("slide") or _slide_time_left <= 0.0:
		_try_end_slide()


func _start_slide() -> void:
	_is_sliding = true
	_slide_time_left = settings.slide_duration
	_set_capsule_height(settings.slide_height)

	var dir := Vector3(velocity.x, 0.0, velocity.z)
	if dir.length_squared() < 0.04:
		dir = -global_transform.basis.z
	_slide_direction = dir.normalized()

	var start_speed := settings.slide_speed + settings.slide_boost
	velocity.x = _slide_direction.x * start_speed
	velocity.z = _slide_direction.z * start_speed
	# Airborne but close to the ground: drop into the slide instead of waiting to land.
	if not is_on_floor():
		velocity.y = minf(velocity.y, -settings.slide_air_drop_speed)


func _try_end_slide() -> void:
	if not _can_stand():
		# Slide motion is done; stay crouched until the ShapeCast is clear.
		_slide_time_left = 0.0
		return
	_is_sliding = false
	_slide_time_left = 0.0
	_set_capsule_height(_stand_height)


func _try_start_vault() -> void:
	# Vault is opt-in: run at the block and tap Space. No press = no vault.
	if _is_sliding or not is_on_floor():
		return
	if not Input.is_action_just_pressed("jump"):
		return

	# Vault straight along look direction so an off-center block cannot
	# pull the capsule left or right toward its origin.
	var face_dir := -global_transform.basis.z
	face_dir.y = 0.0
	if face_dir.length_squared() < 0.0001:
		return
	face_dir = face_dir.normalized()

	var move_dir := Vector3(velocity.x, 0.0, velocity.z)
	if move_dir.length() < settings.vault_min_speed:
		move_dir = face_dir
	else:
		move_dir = move_dir.normalized()

	var box := BoxShape3D.new()
	box.size = settings.vault_probe_size
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	var probe_center := (
		global_position
		+ Vector3.UP * settings.vault_probe_height
		+ face_dir * (settings.vault_probe_size.z * 0.5)
	)
	params.transform = Transform3D(Basis.looking_at(face_dir, Vector3.UP), probe_center)

	var hits := get_world_3d().direct_space_state.intersect_shape(params, 8)
	var collider: CollisionObject3D = null
	var to_obstacle := face_dir
	for hit in hits:
		var body := hit.collider as CollisionObject3D
		if body != null and body.is_in_group("vaultable"):
			collider = body
			to_obstacle = body.global_position - global_position
			to_obstacle.y = 0.0
			if to_obstacle.length_squared() > 0.0001:
				to_obstacle = to_obstacle.normalized()
			break
	if collider == null:
		return
	if move_dir.dot(to_obstacle) < settings.vault_approach_dot:
		return

	_start_vault(collider, face_dir)


func _start_vault(obstacle: CollisionObject3D, over_dir: Vector3) -> void:
	var size := Vector3(3.4, 0.8, 0.55)
	if obstacle.has_meta("vault_size"):
		size = obstacle.get_meta("vault_size")

	# Distance along the vault direction from the player to the far face, plus a landing pad.
	var to_center := obstacle.global_position - global_position
	var along := to_center.dot(over_dir)
	var half_depth := absf(over_dir.x) * size.x * 0.5 + absf(over_dir.z) * size.z * 0.5
	var land_along := along + half_depth + settings.vault_land_clearance

	_is_vaulting = true
	_vault_t = 0.0
	_vault_start = global_position
	_vault_end = global_position + over_dir * land_along
	_vault_end.y = global_position.y
	_vault_apex_y = obstacle.global_position.y + size.y * 0.5 + settings.vault_clearance
	_vault_exit_dir = over_dir
	_vault_obstacle = obstacle
	_vault_saved_snap = floor_snap_length
	floor_snap_length = 0.0
	add_collision_exception_with(obstacle)


func _apply_vault(delta: float) -> void:
	var duration := maxf(settings.vault_duration, 0.01)
	_vault_t += delta / duration
	if _vault_t >= 1.0:
		global_position = _vault_end
		velocity = Vector3(
			_vault_exit_dir.x * settings.move_speed,
			0.0,
			_vault_exit_dir.z * settings.move_speed
		)
		_end_vault()
		return

	var t := _vault_t
	var s := t * t * (3.0 - 2.0 * t)
	var pos := _vault_start.lerp(_vault_end, s)
	var base_y := lerpf(_vault_start.y, _vault_end.y, s)
	pos.y = base_y + (_vault_apex_y - base_y) * (4.0 * t * (1.0 - t))
	# Set position directly so move_and_slide cannot shove us sideways
	# off nearby colliders while we are already ignoring the vault block.
	global_position = pos
	velocity = Vector3.ZERO


func _end_vault() -> void:
	_is_vaulting = false
	_vault_t = 0.0
	floor_snap_length = _vault_saved_snap
	if is_instance_valid(_vault_obstacle):
		remove_collision_exception_with(_vault_obstacle)
	_vault_obstacle = null


func _try_start_wall_climb() -> bool:
	if _is_sliding or _is_vaulting or _is_hanging or _is_climbing:
		return false
	if not Input.is_action_pressed("jump"):
		return false

	var body := _find_climbable_nearby()
	if body == null or not body.has_meta("climb_top_y"):
		return false

	var top_y: float = body.get_meta("climb_top_y")
	var bottom_y: float = body.get_meta("climb_bottom_y")
	if global_position.y > top_y - 0.35:
		return false
	if global_position.y < bottom_y - 0.6:
		return false

	var wall_normal := Vector3(0.0, 0.0, 1.0)
	if body.has_meta("climb_normal"):
		wall_normal = body.get_meta("climb_normal")
	wall_normal.y = 0.0
	if wall_normal.length_squared() < 0.0001:
		return false
	wall_normal = wall_normal.normalized()

	_start_wall_climb(body, wall_normal)
	return true


func _find_climbable_nearby() -> CollisionObject3D:
	var reach := settings.wall_climb_detect
	var box := BoxShape3D.new()
	box.size = Vector3(reach * 2.0, 2.4, reach * 2.0)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = box
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * settings.wall_climb_height)
	var hits := get_world_3d().direct_space_state.intersect_shape(params, 12)
	var best: CollisionObject3D = null
	var best_d := 9999.0
	for hit in hits:
		var collider := hit.collider as CollisionObject3D
		if collider == null or not collider.is_in_group("climbable"):
			continue
		var d := global_position.distance_squared_to(collider.global_position)
		if d < best_d:
			best_d = d
			best = collider
	return best


func _start_wall_climb(body: CollisionObject3D, wall_normal: Vector3) -> void:
	_is_wall_climbing = true
	_climb_wall = body
	_wall_normal = wall_normal
	velocity = Vector3.ZERO
	_wall_saved_snap = floor_snap_length
	floor_snap_length = 0.0
	if _is_sliding:
		_is_sliding = false
		_slide_time_left = 0.0
		_set_capsule_height(_stand_height)
	add_collision_exception_with(body)
	_stick_to_climb_wall()


func _apply_wall_climb(delta: float) -> void:
	if not is_instance_valid(_climb_wall):
		_end_wall_climb()
		return

	var top_y: float = _climb_wall.get_meta("climb_top_y")
	var bottom_y: float = _climb_wall.get_meta("climb_bottom_y")
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var vert := 0.0
	if Input.is_action_pressed("jump") or Input.is_action_pressed("move_forward"):
		vert = 1.0
	elif Input.is_action_pressed("move_back"):
		vert = -1.0

	var next_y := global_position.y + vert * settings.wall_climb_speed * delta
	next_y = clampf(next_y, bottom_y, top_y)

	var right := global_transform.basis.x
	right.y = 0.0
	if right.length_squared() > 0.0001:
		right = right.normalized()
		right -= _wall_normal * right.dot(_wall_normal)
		if right.length_squared() > 0.0001:
			right = right.normalized()
			global_position += right * (input.x * settings.wall_climb_strafe * delta)

	global_position.y = next_y
	_stick_to_climb_wall()
	velocity = Vector3.ZERO

	if next_y >= top_y - 0.08 and vert > 0.0:
		_start_wall_mount(top_y)
		return
	if next_y <= bottom_y + 0.02 and vert < 0.0:
		_end_wall_climb()
		velocity = _wall_normal * 2.0


func _stick_to_climb_wall() -> void:
	if not is_instance_valid(_climb_wall):
		return
	var size := Vector3(2.0, 4.5, 0.42)
	if _climb_wall.has_meta("climb_size"):
		size = _climb_wall.get_meta("climb_size")
	var along := absf(_wall_normal.x) * size.x * 0.5 + absf(_wall_normal.z) * size.z * 0.5
	var face := _climb_wall.global_position + _wall_normal * along
	var stand := face + _wall_normal * (_capsule.radius + 0.06)
	var pos := global_position
	var wall_pos := _climb_wall.global_position
	# Snap onto the face; clamp strafing along the wall's wide axis.
	if absf(_wall_normal.z) >= absf(_wall_normal.x):
		pos.z = stand.z
		var half_w := maxf(size.x * 0.5 - _capsule.radius - 0.08, 0.2)
		pos.x = clampf(pos.x, wall_pos.x - half_w, wall_pos.x + half_w)
	else:
		pos.x = stand.x
		var half_w := maxf(size.z * 0.5 - _capsule.radius - 0.08, 0.2)
		pos.z = clampf(pos.z, wall_pos.z - half_w, wall_pos.z + half_w)
	global_position = pos


func _start_wall_mount(top_y: float) -> void:
	_is_wall_climbing = false
	_is_climbing = true
	_climb_t = 0.0
	_ledge_normal = _wall_normal
	_ledge_body = _climb_wall
	_ledge_y = top_y
	_climb_start = global_position
	_climb_end = global_position - _wall_normal * settings.wall_climb_mount
	_climb_end.y = top_y + 0.05
	_climb_wall = null
	_ladder_flip_armed = true


func _end_wall_climb() -> void:
	_is_wall_climbing = false
	floor_snap_length = _wall_saved_snap
	if is_instance_valid(_climb_wall):
		remove_collision_exception_with(_climb_wall)
	_climb_wall = null


func _try_grab_ledge() -> void:
	# Grab is opt-in: tap Space at the lip. No press = fall past it.
	if _is_hanging or _is_climbing or is_on_floor():
		return
	if not Input.is_action_just_pressed("jump"):
		return

	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	forward = forward.normalized()

	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	var side := forward.cross(Vector3.UP) * 0.7
	var mid_hit: Dictionary = {}
	for height_off: float in [-settings.ledge_grab_height_range, 0.0, settings.ledge_grab_height_range]:
		for lateral: Vector3 in [-side, Vector3.ZERO, side]:
			var mid_from: Vector3 = (
				global_position
				+ Vector3.UP * (settings.ledge_grab_height + height_off)
				+ lateral
			)
			var hit := space.intersect_ray(
				PhysicsRayQueryParameters3D.create(
					mid_from,
					mid_from + forward * settings.ledge_detect_distance,
					collision_mask,
					exclude
				)
			)
			if hit.is_empty():
				continue
			var body := hit.collider as CollisionObject3D
			if body != null and body.is_in_group("platform"):
				mid_hit = hit
				break
		if not mid_hit.is_empty():
			break
	if mid_hit.is_empty():
		_try_grab_ledge_from_below(forward, space, exclude)
		return
	var collider := mid_hit.collider as CollisionObject3D
	if collider == null or not collider.is_in_group("platform"):
		return

	var over_from: Vector3 = (mid_hit.position as Vector3) + Vector3.UP * 0.35
	var over_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			over_from,
			over_from + forward * 0.45,
			collision_mask,
			exclude
		)
	)
	if not over_hit.is_empty():
		return

	var wall_normal: Vector3 = mid_hit.normal as Vector3
	wall_normal.y = 0.0
	if wall_normal.length_squared() < 0.0001:
		return
	wall_normal = wall_normal.normalized()
	if forward.dot(-wall_normal) < 0.0:
		return

	var lip: Vector3 = mid_hit.position as Vector3
	var down_from := lip - wall_normal * 0.35 + Vector3.UP * 0.8
	var down_hit := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			down_from,
			down_from + Vector3.DOWN * 2.2,
			collision_mask,
			exclude
		)
	)
	if down_hit.is_empty():
		return
	var down_col := down_hit.collider as Node
	if down_col == null or not down_col.is_in_group("platform"):
		return

	var ledge_y: float = (down_hit.position as Vector3).y
	if global_position.y > ledge_y + 0.25:
		return
	if global_position.y < ledge_y - settings.ledge_hang_offset - settings.ledge_grab_below:
		return

	_start_hang(collider, wall_normal, lip, ledge_y)


func _try_grab_ledge_from_below(
	forward: Vector3,
	space: PhysicsDirectSpaceState3D,
	exclude: Array[RID]
) -> void:
	# Player is under the pad: chest rays miss the thin vertical lip.
	# Shoot up from several points ahead until we hit a platform underside.
	var up_len := settings.ledge_hang_offset + settings.ledge_grab_below + 1.0
	var steps := 10
	for i in range(steps + 1):
		var dist := 0.25 + settings.ledge_detect_distance * (float(i) / float(steps))
		var from := global_position + forward * dist + Vector3.UP * 0.05
		var hit := space.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				from,
				from + Vector3.UP * up_len,
				collision_mask,
				exclude
			)
		)
		if hit.is_empty():
			continue
		var body := hit.collider as CollisionObject3D
		if body == null or not body.is_in_group("platform"):
			continue
		var lip_info := _nearest_platform_lip(body, global_position)
		if lip_info.is_empty():
			continue
		var ledge_y: float = lip_info["y"]
		if global_position.y > ledge_y + 0.25:
			continue
		if global_position.y < ledge_y - settings.ledge_hang_offset - settings.ledge_grab_below:
			continue
		var wall_n: Vector3 = lip_info["normal"]
		var lip_pos: Vector3 = lip_info["lip"]
		_start_hang(body, wall_n, lip_pos, ledge_y)
		return


func _nearest_platform_lip(body: Node3D, from_pos: Vector3) -> Dictionary:
	var col := body.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col == null:
		return {}
	var box := col.shape as BoxShape3D
	if box == null:
		return {}
	var center := body.global_position
	var half := box.size * 0.5
	var local := from_pos - center
	var hx: float = half.x
	var hz: float = half.z
	var wall_normal := Vector3.ZERO
	var lip := Vector3.ZERO
	var inside := absf(local.x) <= hx and absf(local.z) <= hz
	if inside:
		var to_x := hx - absf(local.x)
		var to_z := hz - absf(local.z)
		if to_x <= to_z:
			var sx := 1.0 if local.x >= 0.0 else -1.0
			wall_normal = Vector3(sx, 0.0, 0.0)
			lip = Vector3(center.x + sx * hx, center.y, center.z + clampf(local.z, -hz, hz))
		else:
			var sz := 1.0 if local.z >= 0.0 else -1.0
			wall_normal = Vector3(0.0, 0.0, sz)
			lip = Vector3(center.x + clampf(local.x, -hx, hx), center.y, center.z + sz * hz)
	else:
		var sx := 0.0
		if local.x > hx:
			sx = 1.0
		elif local.x < -hx:
			sx = -1.0
		var sz := 0.0
		if local.z > hz:
			sz = 1.0
		elif local.z < -hz:
			sz = -1.0
		if absf(sx) >= absf(sz):
			wall_normal = Vector3(sx, 0.0, 0.0)
			lip = Vector3(center.x + sx * hx, center.y, center.z + clampf(local.z, -hz, hz))
		else:
			wall_normal = Vector3(0.0, 0.0, sz)
			lip = Vector3(center.x + clampf(local.x, -hx, hx), center.y, center.z + sz * hz)
	return { "normal": wall_normal, "lip": lip, "y": center.y }


func _start_hang(
	body: CollisionObject3D,
	wall_normal: Vector3,
	lip: Vector3,
	ledge_y: float
) -> void:
	_is_hanging = true
	_ledge_body = body
	_ledge_normal = wall_normal
	_ledge_y = ledge_y
	velocity = Vector3.ZERO
	var hang := lip + wall_normal * (_capsule.radius + 0.06)
	hang.y = ledge_y - settings.ledge_hang_offset
	global_position = hang


func _update_hang() -> void:
	velocity = Vector3.ZERO
	if Input.is_action_just_pressed("jump") or Input.is_action_pressed("move_forward"):
		_start_ledge_climb()
	elif Input.is_action_just_pressed("move_back"):
		_drop_from_ledge()


func _start_ledge_climb() -> void:
	_is_hanging = false
	_is_climbing = true
	_climb_t = 0.0
	_climb_start = global_position
	_climb_end = global_position - _ledge_normal * settings.ledge_climb_forward
	_climb_end.y = _ledge_y + 0.05
	if is_instance_valid(_ledge_body):
		add_collision_exception_with(_ledge_body)


func _apply_ledge_climb(delta: float) -> void:
	var duration := maxf(settings.ledge_climb_duration, 0.01)
	_climb_t += delta / duration
	if _climb_t >= 1.0:
		global_position = _climb_end
		velocity = Vector3(-_ledge_normal.x * settings.move_speed, 0.0, -_ledge_normal.z * settings.move_speed)
		_end_ledge_climb()
		return
	var t := _climb_t
	var s := t * t * (3.0 - 2.0 * t)
	var pos := _climb_start.lerp(_climb_end, s)
	velocity = (pos - global_position) / maxf(delta, 0.0001)


func _end_ledge_climb() -> void:
	_is_climbing = false
	_climb_t = 0.0
	floor_snap_length = _wall_saved_snap
	if is_instance_valid(_ledge_body):
		remove_collision_exception_with(_ledge_body)
	_ledge_body = null


func _drop_from_ledge() -> void:
	_is_hanging = false
	velocity = _ledge_normal * 2.0
	_ledge_body = null


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		# get_gravity() uses Project Settings and any Area3D gravity overrides (Godot 4.2+).
		velocity += get_gravity() * delta


func _apply_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		if _is_sliding:
			# Jump on the same frame as the slide; don't wait for is_on_floor()
			# after standing up, which is what made slide-jumps feel delayed.
			if not _can_stand():
				return
			velocity.y = settings.jump_velocity
			_is_sliding = false
			_slide_time_left = 0.0
			_set_capsule_height(_stand_height)
		elif is_on_floor():
			velocity.y = settings.jump_velocity

	if settings.variable_jump and Input.is_action_just_released("jump") and velocity.y > 0.0:
		velocity.y *= 0.5


func _apply_movement(delta: float) -> void:
	# Timed slide keeps its slowdown. After the timer, stay low if needed but
	# allow WASD so the player can leave the obstacle instead of freezing under it.
	if _is_sliding and _slide_time_left > 0.0:
		_apply_slide_move()
		return

	# X = strafe (left/right), Y = along the body's forward axis (W/S).
	# In Godot, local -Z is forward, so "move_forward" maps to a negative Y here.
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := _walk_speed()
	var target := Vector3.ZERO
	if direction:
		target = Vector3(direction.x * speed, 0.0, direction.z * speed)
	var accel := speed / maxf(settings.accel_time, 0.01)
	if not direction:
		accel *= 4.0
	var next := Vector3(velocity.x, 0.0, velocity.z).move_toward(target, accel * delta)
	velocity.x = next.x
	velocity.z = next.z


func _walk_speed() -> float:
	var speed := settings.move_speed
	if fp_arms != null and fp_arms.is_knife_drawn():
		speed *= fp_arms.knife_move_scale
	return speed


func _apply_slide_move() -> void:
	# Linear slowdown from (slide_speed + boost) down to a stop over slide_duration.
	var u := 0.0
	if settings.slide_duration > 0.0:
		u = clampf(_slide_time_left / settings.slide_duration, 0.0, 1.0)
	var speed := (settings.slide_speed + settings.slide_boost) * u
	velocity.x = _slide_direction.x * speed
	velocity.z = _slide_direction.z * speed


func _set_capsule_height(height: float) -> void:
	_capsule.height = height
	# Keep the capsule's feet on the ground by recentering at half-height.
	collision_shape.position.y = height * 0.5
	if body_mesh != null:
		body_mesh.position.y = height * 0.5
		var y_scale := 1.0
		if _stand_height > 0.0:
			y_scale = height / _stand_height
		body_mesh.scale = Vector3(1.0, y_scale, 1.0)


func _update_fall_flip() -> void:
	# Front flip only when landing after dropping off a climbed ladder deck.
	var on_floor := is_on_floor()
	if on_floor:
		if not _was_on_floor and _ladder_flip_armed:
			var drop := _airborne_peak_y - global_position.y
			if drop >= settings.fall_flip_min_drop and _flip_t < 0.0:
				_flip_t = 0.0
				_ladder_flip_armed = false
		_was_on_floor = true
		_airborne_peak_y = global_position.y
		return
	if _was_on_floor:
		_airborne_peak_y = global_position.y
		_was_on_floor = false
	_airborne_peak_y = maxf(_airborne_peak_y, global_position.y)


func _tick_fall_flip(delta: float) -> float:
	if _flip_t < 0.0:
		return 0.0
	var duration := maxf(settings.fall_flip_duration, 0.01)
	_flip_t += delta / duration
	if _flip_t >= 1.0:
		_flip_t = -1.0
		return 0.0
	var u := _flip_t
	var s := u * u * (3.0 - 2.0 * u)
	# Negative pitch looks down first, then all the way around — a front flip.
	return -TAU * s


func _lerp_camera(delta: float) -> void:
	var target_y := settings.slide_head_height if _is_sliding else _stand_head_y
	var blend := 1.0 - exp(-settings.camera_lerp_speed * delta)
	head.position.y = lerpf(head.position.y, target_y, blend)
	# Positive pitch looks up, which reads as leaning back into the slide.
	var lean := 0.0
	if _is_sliding:
		lean = deg_to_rad(settings.slide_lean_degrees)
	var flip := _tick_fall_flip(delta)
	camera.rotation.x = lean + flip
	_apply_sprint_camera(delta, blend)
	_apply_speed_fov(blend)


func _sprint_camera_amount() -> float:
	if settings.third_person:
		return 0.0
	if _is_sliding or _is_hanging or _is_climbing or _is_vaulting or _is_wall_climbing:
		return 0.0
	if not is_on_floor():
		return 0.0
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var span := settings.sprint_full_speed - settings.sprint_start_speed
	if span <= 0.001:
		return 1.0 if speed >= settings.sprint_full_speed else 0.0
	return clampf((speed - settings.sprint_start_speed) / span, 0.0, 1.0)


func _apply_sprint_camera(delta: float, blend: float) -> void:
	if settings.third_person:
		return
	var sprint_t := _sprint_camera_amount()
	var shift := settings.sprint_camera_shift
	if sprint_t > 0.001:
		var speed := Vector3(velocity.x, 0.0, velocity.z).length()
		_sprint_cam_t += speed * 1.2 * delta
	var bob := sin(_sprint_cam_t)
	var bounce := sin(_sprint_cam_t * 2.0)
	var target := Vector3(bob * shift.x * sprint_t, bounce * shift.y * sprint_t, 0.0)
	camera.position = camera.position.lerp(target, blend)


func _apply_speed_fov(blend: float) -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var t := 0.0
	if settings.speed_fov_at > 0.001:
		t = clampf(speed / settings.speed_fov_at, 0.0, 1.0)
	var target := settings.camera_fov + settings.speed_fov * t
	camera.fov = lerpf(camera.fov, target, blend)


func _is_near_floor() -> bool:
	if is_on_floor():
		return true
	var from := global_position + Vector3.UP * 0.05
	var to := global_position + Vector3.DOWN * settings.slide_air_drop_height
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _can_stand() -> bool:
	# Sweeps a standing-width box from slide height up to full capsule height.
	# Hits the slide bar; ignores the floor we are already standing on.
	if stand_check == null:
		return true
	stand_check.force_shapecast_update()
	return not stand_check.is_colliding()


func _setup_stand_check() -> void:
	var extra := _stand_height - settings.slide_height
	stand_check.position = Vector3(0.0, settings.slide_height, 0.0)
	stand_check.target_position = Vector3(0.0, maxf(extra, 0.05), 0.0)
	stand_check.collision_mask = collision_mask
	stand_check.add_exception(self)
	var box := BoxShape3D.new()
	box.size = Vector3(_capsule.radius * 2.0, 0.08, _capsule.radius * 2.0)
	stand_check.shape = box


func _ensure_slide_action() -> void:
	if InputMap.has_action("slide"):
		return
	InputMap.add_action("slide")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_CTRL
	InputMap.action_add_event("slide", key)


func _apply_camera_mode() -> void:
	if settings.third_person:
		camera.position = Vector3(0.0, settings.third_person_height, settings.third_person_distance)
	else:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
	camera.fov = settings.camera_fov
	if body_mesh != null:
		body_mesh.visible = settings.third_person


func _apply_mouse_look(mouse_delta: Vector2) -> void:
	# Yaw the whole body so WASD stays relative to where we are looking.
	rotate_y(-mouse_delta.x * settings.mouse_sensitivity)
	# Pitch only the head so the capsule collider never tilts.
	var min_pitch := settings.min_pitch_deg
	var max_pitch := settings.max_pitch_deg
	if settings.third_person:
		min_pitch = -35.0
		max_pitch = 50.0
	head.rotate_x(-mouse_delta.y * settings.mouse_sensitivity)
	head.rotation.x = clampf(
		head.rotation.x,
		deg_to_rad(min_pitch),
		deg_to_rad(max_pitch)
	)


func _apply_display_settings() -> void:
	var map := clampf(settings.map_brightness, 0.0, 4.0)
	var lamp_scale := clampf(settings.head_light, 0.0, 4.0)
	var lamp := get_node_or_null("Head/HeadLamp") as SpotLight3D
	if lamp != null:
		lamp.light_energy = 14.0 * lamp_scale
		lamp.visible = lamp_scale > 0.01
	var root := get_parent()
	if root == null:
		return
	var env_node := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.adjustment_enabled = true
		env_node.environment.adjustment_brightness = 0.72 * map
		env_node.environment.ambient_light_energy = 0.2 * map
	var sun := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 0.38 * map
	var fill := root.get_node_or_null("FillLight") as DirectionalLight3D
	if fill != null:
		fill.light_energy = 0.1 * map


func _toggle_mouse_capture() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
