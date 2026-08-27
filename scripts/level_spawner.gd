extends Node3D
class_name LevelSpawner

## Grid generator. Pads sit on PATH_LENGTH cells at an explicit height.
## A segment is planned and validated, then committed. Visuals stream in/out.

enum SectionType { NORMAL, JUMP, SLIDE, VAULT, NARROW, CLIMB, DROP, BRANCH }
enum PropKind { PAD, SLIDE, VAULT, CLIMB, CRATE }

# ============================================================
# CRATE & BATTERY SETTINGS
# ============================================================

@export var CRATE_ENABLED := true
@export var CRATE_SPAWN_CHANCE := 0.10

@export var CRATE_HITS_TO_OPEN := 3
## How far a knife slash can reach a crate, in meters.
@export var CRATE_HIT_RANGE := 5

@export var BATTERY_RESTORE_PERCENT := 30.0

@export var CRATE_LOOT_CHANCE_0 := 15.0
@export var CRATE_LOOT_CHANCE_1 := 30.0
@export var CRATE_LOOT_CHANCE_2 := 25.0
@export var CRATE_LOOT_CHANCE_3 := 20.0

@export var BATTERY_PICKUP_RADIUS := 2.0


# ============================================================
# GENERATION SETTINGS
# ============================================================

## ================= PATH =================

## Width of every platform in meters
@export_category("Path")
@export var PATH_WIDTH: float = 3.0

## Length of each path segment in meters
@export var PATH_LENGTH: float = 5.5

## How much paths turn
## 0 = straight   0.5 = normal   1 = very twisty
@export_range(0.0, 1.0, 0.05)
var TURN_FREQUENCY: float = 0.5

## How often new branches appear
## 0 = none   0.0625 = normal   1 = constant
@export_range(0.0, 1.0, 0.01)
var INTERSECTION_FREQUENCY: float = 0.0625

## Minimum distance between separate paths
@export var MIN_PATH_GAP: float = 7.0

## Maximum distance between separate paths
## Ignored if below minimum (no upper limit)
@export var MAX_PATH_GAP: float = 8.0


## ================= OBSTACLES =================

@export_category("Obstacles")

## Overall amount of obstacles
## 0 = none   1 = normal   2 = twice as many
@export_range(0.0, 3.0, 0.1)
var OBSTACLE_DENSITY: float = 1.0

## Minimum number of segments between obstacle sections
@export_range(0, 20, 1)
var OBSTACLE_SPACING: int = 0

## Chance of narrow sections
@export_range(0.0, 1.0, 0.05)
var NARROW_CHANCE: float = 0.5

## Chance of climb sections
@export_range(0.0, 1.0, 0.01)
var CLIMB_CHANCE: float = 0.22

## Chance of drop sections
@export_range(0.0, 1.0, 0.01)
var DROP_CHANCE: float = 0.16

## Number of empty cells during jumps
@export_range(1, 10, 1)
var JUMP_CELLS: int = 3


## ================= TERRAIN =================

@export_category("Terrain")

## Maximum vertical change between connected sections
@export var MAX_HEIGHT_CHANGE: float = 5.2

## Maximum allowed slope
@export var MAX_SLOPE: float = 5.2 / 5.5

## Lowest possible platform height
@export var Y_LIMIT_MIN: float = -2.0

## Highest possible platform height
@export var Y_LIMIT_MAX: float = 12.0

## Maximum horizontal generation range
@export var X_LIMIT: float = 280.0


## ================= GENERATION =================

@export_category("Generation")

## How unpredictable the generated layout is
## 0 = predictable   1 = completely random
@export_range(0.0, 1.0, 0.05)
var RANDOMNESS: float = 1.0

## -1 = different layout every run
## Any positive number = repeatable layout
@export var GENERATION_SEED: int = -1

## Maximum number of paths being generated simultaneously
@export_range(1, 12, 1)
var MAX_ACTIVE_CHUNKS: int = 8


## ================= STREAMING =================

@export_category("Streaming")

## Distance ahead of player to generate
@export var SPAWN_AHEAD_DISTANCE: float = 56.0

## Distance from player before generated sections are unloaded
@export var CLEANUP_DISTANCE: float = 80.0

## Prevent platforms from spawning too close to player
@export var MIN_PLAYER_CLEARANCE: float = 18.0


@export_category("Scene")
@export var platform_chunk: PackedScene
@export var player: Node3D

const OBSTACLE_SIZE := Vector3(3.0, 0.8, 0.55)
const MIN_PAD_EDGE_GAP := 1.25
const NARROW_PADS_MIN := 3
const NARROW_PADS_MAX := 4
const CLIMB_COOLDOWN_MIN := 6
const CLIMB_COOLDOWN_MAX := 10
const CLIMB_WALL_DEPTH := 0.42
const DROP_COOLDOWN_MIN := 5
const DROP_COOLDOWN_MAX := 8
const DROP_LANDING_PADS := 3
const SLIDE_BAR_CLEARANCE := 1.08
const SLIDE_BAR_DIAMETER := 0.26
const SLIDE_SUPPORT_THICKNESS := 0.28
const FLOOR_COLLISION_SEAM := 0.1
const COLOR_OBSTACLE := Color(0.2, 0.19, 0.17, 1.0)
const COLOR_VAULT := Color(0.16, 0.14, 0.11, 1.0)
const HEIGHT_SNAP := 0.1

class Head:
	var cell: Vector2i = Vector2i.ZERO
	var y: float = 0.0
	var dir: int = 0
	var path_id: int = 1
	var since_climb: int = 4
	var since_drop: int = 3
	var since_branch: int = 0
	var since_obs: int = 0
	var branch_need: int = 12
	var ended: bool = false


class WorldProp:
	var kind: int = 0
	var pos: Vector3 = Vector3.ZERO
	var tall: bool = true
	var simple: bool = false
	var size: Vector3 = Vector3.ZERO
	var climb_height: float = 0.0
	var jump_gap: float = 0.0
	var climb_normal: Vector3 = Vector3(0.0, 0.0, 1.0)
	var cell: Vector2i = Vector2i.ZERO
	var dir: int = 0
	var path_id: int = 1
	var yaw_deg: float = 0.0
	var node: Node3D = null
	var hits: int = 0
	var opened: bool = false
	var looted: bool = false
	var side: float = 1.0


class Plan:
	var kind: int = 0
	var pad_cells: Array = []
	var pad_ys: Array = []
	var pad_tall: Array = []
	var pad_simple: Array = []
	var jump_gap: float = 0.0
	var jump_cell: Vector2i = Vector2i.ZERO
	var obstacle_kind: int = -1
	var obstacle_cell: Vector2i = Vector2i.ZERO
	var climb_high_cell: Vector2i = Vector2i.ZERO
	var climb_height: float = 0.0
	var blocked_cells: Array = []
	var next_cell: Vector2i = Vector2i.ZERO
	var next_y: float = 0.0
	var next_dir: int = 0
	var is_branch: bool = false
	var branch_cell: Vector2i = Vector2i.ZERO
	var branch_y: float = 0.0
	var branch_dir: int = 0


var _rng := RandomNumberGenerator.new()
var _kit: MachineKit
var _heads: Array = []
var _pads: Dictionary = {}
var _obstacles: Dictionary = {}
var _blocked: Dictionary = {}
var _entities: Array = []
var _active_platforms: Array[Node3D] = []
var _stat_loaded_pads: int = 0
var _stat_loaded_obstacles: int = 0
var _mesh_boxes: Dictionary = {}
var _shape_boxes: Dictionary = {}
var _mesh_cyls: Dictionary = {}
var _shape_cyls: Dictionary = {}
var _mat_fallback: StandardMaterial3D
var _mat_vault: StandardMaterial3D
var _floor_shape: BoxShape3D
var _next_path_id: int = 2


func _randf() -> float:
	if RANDOMNESS <= 0.0:
		return 0.5
	return _rng.randf()


func _randf_range(a: float, b: float) -> float:
	if RANDOMNESS <= 0.0:
		return (a + b) * 0.5
	return _rng.randf_range(a, b)


func _randi_range(a: int, b: int) -> int:
	if b <= a:
		return a
	if RANDOMNESS <= 0.0:
		return int((a + b) / 2)
	return _rng.randi_range(a, b)


func _obstacle_weight(base: int) -> int:
	return maxi(0, int(round(float(base) * maxf(OBSTACLE_DENSITY, 0.0))))


func _climb_min() -> float:
	return minf(4.0, MAX_HEIGHT_CHANGE)


func _drop_min() -> float:
	return minf(3.5, MAX_HEIGHT_CHANGE)


func _max_step_for_run(run: float) -> float:
	return minf(MAX_HEIGHT_CHANGE, MAX_SLOPE * maxf(run, 0.001))


func _spacing_search_radius() -> int:
	var meters := maxf(MIN_PATH_GAP, MAX_PATH_GAP)
	return maxi(1, int(ceil(maxf(meters, 0.001) / maxf(PATH_LENGTH, 0.001))))


func _parallel_gap_ok(dist: float) -> bool:
	if dist < MIN_PATH_GAP:
		return false
	if MAX_PATH_GAP >= MIN_PATH_GAP and dist > MAX_PATH_GAP:
		return false
	return true


func _ready() -> void:
	if GENERATION_SEED < 0:
		_rng.randomize()
	else:
		_rng.seed = GENERATION_SEED
	_kit = MachineKit.new()
	_kit.setup(_rng)
	add_to_group("level_spawner")
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Node3D
	if platform_chunk == null:
		push_error("LevelSpawner: assign a PlatformChunk PackedScene in the inspector.")
		return
	_mat_fallback = StandardMaterial3D.new()
	_mat_fallback.albedo_color = COLOR_OBSTACLE
	_mat_vault = StandardMaterial3D.new()
	_mat_vault.albedo_color = COLOR_VAULT
	var start := _make_head(Vector2i.ZERO, 0.0, 0, 1)
	_heads.append(start)
	_commit_pad(Vector2i.ZERO, 0.0, 0, true, false, 0.0, 1)
	_generate(20)
	_stream_visuals()


func _physics_process(_delta: float) -> void:
	if player == null or platform_chunk == null:
		return
	_cull_ended_heads()
	_ensure_frontier()
	_generate(12)
	_stream_visuals()
	_forget_far_records()


# =============================================================================
# Path progression
# =============================================================================

func _make_head(cell: Vector2i, y: float, dir: int, path_id: int) -> Head:
	var h := Head.new()
	h.cell = cell
	h.y = y
	h.dir = dir
	h.path_id = path_id
	h.since_climb = CLIMB_COOLDOWN_MIN
	h.since_drop = DROP_COOLDOWN_MIN
	h.since_branch = 0
	h.since_obs = 0
	h.branch_need = _roll_branch_need()
	h.ended = false
	return h


func _roll_branch_need() -> int:
	if INTERSECTION_FREQUENCY <= 0.0:
		return 1000000
	var mid := 1.0 / INTERSECTION_FREQUENCY
	var spread := mid * clampf(RANDOMNESS, 0.0, 1.0) * 0.25
	var lo := maxi(1, int(round(mid - spread)))
	var hi := maxi(lo, int(round(mid + spread)))
	return _randi_range(lo, hi)


func _delta(dir: int) -> Vector2i:
	match wrapi(dir, 0, 4):
		1:
			return Vector2i(1, 0)
		2:
			return Vector2i(0, 1)
		3:
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, -1)


func _yaw_deg(dir: int) -> float:
	match wrapi(dir, 0, 4):
		1:
			return -90.0
		2:
			return 180.0
		3:
			return 90.0
		_:
			return 0.0


func _dir_from_yaw_deg(yaw_deg: float) -> int:
	var q := wrapi(roundi(-yaw_deg / 90.0), 0, 4)
	return q


func _cell_world(cell: Vector2i, y: float) -> Vector3:
	return Vector3(float(cell.x) * PATH_LENGTH, y, float(cell.y) * PATH_LENGTH)


func _world_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / PATH_LENGTH), roundi(pos.z / PATH_LENGTH))


func _should_extend(head: Head) -> bool:
	if head == null or head.ended:
		return false
	var here := _cell_world(head.cell, head.y)
	var nxt := _cell_world(head.cell + _delta(head.dir), head.y)
	return _near_xz(here, SPAWN_AHEAD_DISTANCE) or _near_xz(nxt, SPAWN_AHEAD_DISTANCE)


func _near_xz(pos: Vector3, radius: float) -> bool:
	if player == null:
		return true
	return Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z).length() <= radius


func _generate(budget: int) -> void:
	var used := 0
	var snapshot: Array = _heads.duplicate()
	for entry in snapshot:
		var head: Head = entry
		if used >= budget:
			break
		while used < budget and _should_extend(head):
			if not _append_segment(head):
				head.ended = true
				break
			used += 1


func _append_segment(head: Head) -> bool:
	var plans: Array = _collect_valid_plans(head)
	if plans.is_empty():
		head.ended = true
		return false
	var plan: Plan = plans[0] if RANDOMNESS <= 0.0 else plans[_randi_range(0, plans.size() - 1)]
	_commit_plan(head, plan)
	return true


func _collect_valid_plans(head: Head) -> Array:
	var bag: Array = []
	var turn_w := maxi(0, int(round(clampf(TURN_FREQUENCY, 0.0, 1.0) * 4.0)))
	var allow_obs := OBSTACLE_SPACING <= 0 or head.since_obs >= OBSTACLE_SPACING
	var slide_w := _obstacle_weight(3) if allow_obs else 0
	var jump_w := _obstacle_weight(2) if allow_obs else 0
	var narrow_w := 0
	if allow_obs and NARROW_CHANCE > 0.0:
		narrow_w = _obstacle_weight(maxi(1, int(round(2.0 * NARROW_CHANCE / 0.5))))
	var climb_w := 0
	if CLIMB_CHANCE > 0.0 and head.since_climb >= CLIMB_COOLDOWN_MIN:
		climb_w = maxi(1, int(round(CLIMB_CHANCE / 0.22)))
	var drop_w := 0
	if DROP_CHANCE > 0.0 and head.since_drop >= DROP_COOLDOWN_MIN:
		drop_w = maxi(1, int(round(DROP_CHANCE / 0.16)))
	_add_plan(bag, _plan_normal(head), 3)
	_add_plan(bag, _plan_turn(head, 1), turn_w)
	_add_plan(bag, _plan_turn(head, -1), turn_w)
	_add_plan(bag, _plan_slide(head), slide_w)
	_add_plan(bag, _plan_vault(head), slide_w)
	_add_plan(bag, _plan_jump(head), jump_w)
	_add_plan(bag, _plan_narrow(head), narrow_w)
	_add_plan(bag, _plan_climb(head), climb_w)
	_add_plan(bag, _plan_drop(head), drop_w)
	if INTERSECTION_FREQUENCY > 0.0 and _heads.size() < MAX_ACTIVE_CHUNKS and head.since_branch >= head.branch_need:
		_add_plan(bag, _plan_branch(head, 1), 1)
		_add_plan(bag, _plan_branch(head, -1), 1)
	if not bag.is_empty():
		return bag
	var rescue: Array = []
	_add_plan(rescue, _plan_normal(head), 1)
	_add_plan(rescue, _plan_turn(head, 1), 1)
	_add_plan(rescue, _plan_turn(head, -1), 1)
	return rescue


func _add_plan(bag: Array, plan: Plan, copies: int) -> void:
	if plan == null or copies <= 0:
		return
	for _i in copies:
		bag.append(plan)


# =============================================================================
# Obstacle / segment selection — each planner returns null if invalid
# =============================================================================

func _base_plan(head: Head, kind: int) -> Plan:
	var p := Plan.new()
	p.kind = kind
	p.next_dir = head.dir
	p.next_y = head.y
	return p


func _push_pad(plan: Plan, cell: Vector2i, y: float, tall: bool, simple: bool) -> void:
	plan.pad_cells.append(cell)
	plan.pad_ys.append(y)
	plan.pad_tall.append(tall)
	plan.pad_simple.append(simple)


func _plan_normal(head: Head) -> Plan:
	var cell := head.cell + _delta(head.dir)
	if not _cell_free(cell, head.y):
		return null
	var p := _base_plan(head, SectionType.NORMAL)
	_push_pad(p, cell, head.y, true, false)
	p.next_cell = cell
	return _finish_plan(p, head)


func _plan_turn(head: Head, side: int) -> Plan:
	var dir := wrapi(head.dir + side, 0, 4)
	var cell := head.cell + _delta(dir)
	if not _cell_free(cell, head.y):
		return null
	var p := _base_plan(head, SectionType.NORMAL)
	p.next_dir = dir
	_push_pad(p, cell, head.y, true, true)
	p.next_cell = cell
	return _finish_plan(p, head)


func _plan_run(head: Head, count: int, obstacle_at: int, obstacle_kind: int, kind: int) -> Plan:
	var d := _delta(head.dir)
	var cells: Array = []
	var cell := head.cell
	for _i in count:
		cell += d
		cells.append(cell)
		if not _cell_free(cell, head.y):
			return null
	var obs_cell: Vector2i = cells[obstacle_at]
	if _obstacles.has(obs_cell):
		return null
	var p := _base_plan(head, kind)
	for i in cells.size():
		var tall := i != obstacle_at
		_push_pad(p, cells[i], head.y, tall, true)
	p.obstacle_kind = obstacle_kind
	p.obstacle_cell = obs_cell
	p.next_cell = cells[cells.size() - 1]
	return _finish_plan(p, head)


func _plan_slide(head: Head) -> Plan:
	return _plan_run(head, 3, 1, PropKind.SLIDE, SectionType.SLIDE)


func _plan_vault(head: Head) -> Plan:
	return _plan_run(head, 3, 1, PropKind.VAULT, SectionType.VAULT)


func _plan_narrow(head: Head) -> Plan:
	var count := _randi_range(NARROW_PADS_MIN, NARROW_PADS_MAX)
	var flavor := PropKind.SLIDE if _randf() < 0.5 else PropKind.VAULT
	return _plan_run(head, count, mini(1, count - 1), flavor, SectionType.NARROW)


func _plan_jump(head: Head) -> Plan:
	var d := _delta(head.dir)
	var takeoff := head.cell + d
	var land := takeoff + d * JUMP_CELLS
	var gaps: Array = []
	var gap := takeoff
	for _i in JUMP_CELLS - 1:
		gap += d
		gaps.append(gap)
		if _pads.has(gap) or _blocked.has(gap) or not _in_bounds(gap, head.y):
			return null
	if not _cell_free(takeoff, head.y) or not _cell_free(land, head.y):
		return null
	var p := _base_plan(head, SectionType.JUMP)
	_push_pad(p, takeoff, head.y, false, true)
	_push_pad(p, land, head.y, true, false)
	p.jump_gap = float(JUMP_CELLS) * PATH_LENGTH
	p.jump_cell = takeoff
	p.blocked_cells = gaps
	p.next_cell = land
	return _finish_plan(p, head)


func _plan_climb(head: Head) -> Plan:
	var rise := snappedf(_randf_range(_climb_min(), MAX_HEIGHT_CHANGE), HEIGHT_SNAP)
	rise = minf(rise, snappedf(Y_LIMIT_MAX - head.y, HEIGHT_SNAP))
	rise = minf(rise, snappedf(_max_step_for_run(PATH_LENGTH), HEIGHT_SNAP))
	if rise < _climb_min():
		return null
	var y_high := snappedf(head.y + rise, HEIGHT_SNAP)
	if y_high > Y_LIMIT_MAX + 0.001:
		return null
	var d := _delta(head.dir)
	var low := head.cell + d
	var high := low + d
	var top := high + d
	if not _cell_free(low, head.y) or not _cell_free(high, y_high) or not _cell_free(top, y_high):
		return null
	if _obstacles.has(low) or _obstacles.has(high):
		return null
	var p := _base_plan(head, SectionType.CLIMB)
	_push_pad(p, low, head.y, false, true)
	_push_pad(p, high, y_high, true, false)
	_push_pad(p, top, y_high, true, false)
	p.obstacle_kind = PropKind.CLIMB
	p.obstacle_cell = low
	p.climb_high_cell = high
	p.climb_height = y_high - head.y
	p.next_cell = top
	p.next_y = y_high
	return _finish_plan(p, head)


func _plan_drop(head: Head) -> Plan:
	var fall := snappedf(_randf_range(_drop_min(), MAX_HEIGHT_CHANGE), HEIGHT_SNAP)
	fall = minf(fall, snappedf(head.y - Y_LIMIT_MIN, HEIGHT_SNAP))
	fall = minf(fall, snappedf(_max_step_for_run(PATH_LENGTH), HEIGHT_SNAP))
	if fall < _drop_min() or head.y < _drop_min():
		return null
	var y_low := snappedf(head.y - fall, HEIGHT_SNAP)
	if y_low < Y_LIMIT_MIN - 0.001:
		return null
	var d := _delta(head.dir)
	var ledge := head.cell + d
	if not _cell_free(ledge, head.y):
		return null
	var landings: Array = []
	var cell := ledge
	for _i in DROP_LANDING_PADS:
		cell += d
		landings.append(cell)
		if not _cell_free(cell, y_low):
			return null
	var p := _base_plan(head, SectionType.DROP)
	_push_pad(p, ledge, head.y, true, false)
	for land in landings:
		_push_pad(p, land, y_low, true, false)
	p.next_cell = landings[landings.size() - 1]
	p.next_y = y_low
	return _finish_plan(p, head)


func _plan_branch(head: Head, side: int) -> Plan:
	var side_dir := wrapi(head.dir + side, 0, 4)
	var d := _delta(head.dir)
	var side_d := _delta(side_dir)
	var hub := head.cell + d
	var cont := hub + d
	var br := hub + side_d
	if not _cell_free(hub, head.y) or not _cell_free(cont, head.y) or not _cell_free(br, head.y):
		return null
	var p := _base_plan(head, SectionType.BRANCH)
	_push_pad(p, hub, head.y, false, true)
	_push_pad(p, cont, head.y, true, false)
	_push_pad(p, br, head.y, true, true)
	p.next_cell = cont
	p.is_branch = true
	p.branch_cell = br
	p.branch_y = head.y
	p.branch_dir = side_dir
	return _finish_plan(p, head)


# =============================================================================
# Occupancy validation
# =============================================================================

func _cell_free(cell: Vector2i, y: float) -> bool:
	if not _in_bounds(cell, y):
		return false
	if _pads.has(cell) or _blocked.has(cell):
		return false
	return true


func _in_bounds(cell: Vector2i, y: float) -> bool:
	var x := float(cell.x) * PATH_LENGTH
	if x > X_LIMIT or x < -X_LIMIT:
		return false
	if y < Y_LIMIT_MIN - 0.001 or y > Y_LIMIT_MAX + 0.001:
		return false
	return true


func _finish_plan(plan: Plan, head: Head) -> Plan:
	if plan == null or head == null:
		return null
	if not _plan_spacing_ok(plan, head):
		return null
	return plan


func _plan_spacing_ok(plan: Plan, head: Head) -> bool:
	var same: Dictionary = {}
	same[head.cell] = true
	for cell in plan.pad_cells:
		same[cell] = true
	for i in plan.pad_cells.size():
		var cell: Vector2i = plan.pad_cells[i]
		var dir := _plan_pad_dir(plan, head, cell)
		if _player_blocks_cell(cell, head, dir):
			return false
		if not _foreign_spacing_ok(cell, dir, same):
			return false
	return true


func _plan_pad_dir(plan: Plan, head: Head, cell: Vector2i) -> int:
	if plan.is_branch:
		if cell == plan.branch_cell:
			return plan.branch_dir
		if cell != plan.next_cell:
			return head.dir
	return plan.next_dir


func _player_blocks_cell(cell: Vector2i, head: Head, dir: int) -> bool:
	if player == null:
		return false
	var gap := _xz_gap_to_pad(cell, dir, player.global_position)
	if gap >= MIN_PLAYER_CLEARANCE:
		return false
	# The floor already under the player may continue ahead in its own lane.
	# Side paths and pads beside/behind the player are rejected before spawn.
	var pos := _cell_world(cell, 0.0)
	var rel := Vector2(pos.x - player.global_position.x, pos.z - player.global_position.z)
	var d := _delta(head.dir if head != null else dir)
	var fwd := Vector2(float(d.x), float(d.y))
	if fwd.length_squared() < 0.001:
		return true
	fwd = fwd.normalized()
	var along := rel.dot(fwd)
	var lateral := absf(rel.x * fwd.y - rel.y * fwd.x)
	if along >= 1.0 and lateral <= PATH_WIDTH * 0.5 + 0.35:
		return false
	return true


func _xz_gap_to_pad(cell: Vector2i, dir: int, from: Vector3) -> float:
	var c := _cell_world(cell, 0.0)
	var h := _half_xz(dir)
	var dx := maxf(absf(from.x - c.x) - h.x, 0.0)
	var dz := maxf(absf(from.z - c.z) - h.y, 0.0)
	return Vector2(dx, dz).length()


func _foreign_spacing_ok(cell: Vector2i, dir: int, same: Dictionary) -> bool:
	var radius := _spacing_search_radius()
	for dx in range(-radius, radius + 1):
		for dz in range(-radius, radius + 1):
			if dx == 0 and dz == 0:
				continue
			var other_cell := Vector2i(cell.x + dx, cell.y + dz)
			if same.has(other_cell):
				continue
			var other: WorldProp = _pads.get(other_cell)
			if other == null:
				continue
			if _pads_would_touch(cell, dir, other_cell, other.dir):
				return false
			if absi(dx) + absi(dz) == 1:
				return false
			var dist := Vector2(float(dx) * PATH_LENGTH, float(dz) * PATH_LENGTH).length()
			if _dirs_parallel(dir, other.dir) and not _parallel_gap_ok(dist):
				return false
	return true


func _dirs_parallel(a: int, b: int) -> bool:
	return wrapi(a, 0, 4) % 2 == wrapi(b, 0, 4) % 2


func _half_xz(dir: int) -> Vector2:
	var q := wrapi(dir, 0, 4)
	if q == 1 or q == 3:
		return Vector2(PATH_LENGTH * 0.5, PATH_WIDTH * 0.5)
	return Vector2(PATH_WIDTH * 0.5, PATH_LENGTH * 0.5)


func _pads_would_touch(a: Vector2i, a_dir: int, b: Vector2i, b_dir: int) -> bool:
	var pa := _cell_world(a, 0.0)
	var pb := _cell_world(b, 0.0)
	var ha := _half_xz(a_dir)
	var hb := _half_xz(b_dir)
	var gap_x := absf(pa.x - pb.x) - ha.x - hb.x
	var gap_z := absf(pa.z - pb.z) - ha.y - hb.y
	return gap_x < MIN_PAD_EDGE_GAP and gap_z < MIN_PAD_EDGE_GAP


# =============================================================================
# Commit / spawn records
# =============================================================================

func _commit_plan(head: Head, plan: Plan) -> void:
	var branch_id := 0
	if plan.is_branch:
		branch_id = _next_path_id
		_next_path_id += 1
	for i in plan.pad_cells.size():
		var cell: Vector2i = plan.pad_cells[i]
		var y: float = plan.pad_ys[i]
		var tall: bool = plan.pad_tall[i]
		var simple: bool = plan.pad_simple[i]
		var gap := 0.0
		if plan.jump_gap > 0.0 and cell == plan.jump_cell:
			gap = plan.jump_gap
		var pad_dir := plan.next_dir
		var pid := head.path_id
		if plan.is_branch:
			if cell == plan.branch_cell:
				pad_dir = plan.branch_dir
				pid = branch_id
			elif cell != plan.next_cell:
				pad_dir = head.dir
		_commit_pad(cell, y, pad_dir, tall, simple, gap, pid)
	for gap_cell in plan.blocked_cells:
		_blocked[gap_cell] = true
	if plan.obstacle_kind == PropKind.SLIDE:
		_commit_slide(plan.obstacle_cell)
	elif plan.obstacle_kind == PropKind.VAULT:
		_commit_vault(plan.obstacle_cell)
	elif plan.obstacle_kind == PropKind.CLIMB:
		_commit_climb(plan.obstacle_cell, plan.climb_high_cell, plan.climb_height, head.dir)
	if CRATE_ENABLED and plan.kind == SectionType.NORMAL and plan.obstacle_kind < 0:
		if not plan.pad_cells.is_empty() and _randf() < CRATE_SPAWN_CHANCE:
			_commit_crate(plan.pad_cells[0])
	head.cell = plan.next_cell
	head.y = plan.next_y
	head.dir = plan.next_dir
	head.since_climb += 1
	head.since_drop += 1
	head.since_branch += 1
	head.since_obs += 1
	if plan.kind == SectionType.CLIMB:
		head.since_climb = -_randi_range(0, maxi(CLIMB_COOLDOWN_MAX - CLIMB_COOLDOWN_MIN, 0))
	elif plan.kind == SectionType.DROP:
		head.since_drop = -_randi_range(0, maxi(DROP_COOLDOWN_MAX - DROP_COOLDOWN_MIN, 0))
	if plan.kind == SectionType.SLIDE or plan.kind == SectionType.VAULT or plan.kind == SectionType.NARROW or plan.kind == SectionType.JUMP:
		head.since_obs = 0
	if plan.is_branch:
		head.since_branch = 0
		head.branch_need = _roll_branch_need()
		_heads.append(_make_head(plan.branch_cell, plan.branch_y, plan.branch_dir, branch_id))


func _commit_pad(
	cell: Vector2i,
	y: float,
	dir: int,
	tall: bool,
	simple: bool,
	jump_gap: float,
	path_id: int
) -> WorldProp:
	if _pads.has(cell):
		return _pads[cell]
	var prop := WorldProp.new()
	prop.kind = PropKind.PAD
	prop.cell = cell
	prop.dir = wrapi(dir, 0, 4)
	prop.path_id = path_id
	prop.yaw_deg = _yaw_deg(prop.dir)
	prop.pos = _cell_world(cell, y)
	prop.tall = tall
	prop.simple = simple
	prop.jump_gap = jump_gap
	_pads[cell] = prop
	_entities.append(prop)
	if _should_load(prop.pos):
		_load_prop(prop)
	return prop


func _commit_slide(cell: Vector2i) -> void:
	var pad: WorldProp = _pads.get(cell)
	if pad == null or _obstacles.has(cell):
		return
	var prop := WorldProp.new()
	prop.kind = PropKind.SLIDE
	prop.cell = cell
	prop.dir = pad.dir
	prop.yaw_deg = pad.yaw_deg
	prop.pos = pad.pos
	prop.size = Vector3(PATH_WIDTH, 1.2, 0.56)
	_obstacles[cell] = prop
	_entities.append(prop)
	if _should_load(prop.pos):
		_load_prop(prop)


func _commit_vault(cell: Vector2i) -> void:
	var pad: WorldProp = _pads.get(cell)
	if pad == null or _obstacles.has(cell):
		return
	var prop := WorldProp.new()
	prop.kind = PropKind.VAULT
	prop.cell = cell
	prop.dir = pad.dir
	prop.yaw_deg = pad.yaw_deg
	prop.pos = pad.pos
	prop.size = OBSTACLE_SIZE
	_obstacles[cell] = prop
	_entities.append(prop)
	if _should_load(prop.pos):
		_load_prop(prop)


func _commit_climb(low_cell: Vector2i, high_cell: Vector2i, height: float, dir: int) -> void:
	var low: WorldProp = _pads.get(low_cell)
	var high: WorldProp = _pads.get(high_cell)
	if low == null or high == null:
		return
	if _obstacles.has(low_cell) or _obstacles.has(high_cell):
		return
	var d := _delta(dir)
	var prop := WorldProp.new()
	prop.kind = PropKind.CLIMB
	prop.cell = low_cell
	prop.dir = dir
	prop.yaw_deg = _yaw_deg(dir)
	prop.pos = (low.pos + high.pos) * 0.5
	prop.pos.y = low.pos.y
	prop.size = Vector3(2.0, height, CLIMB_WALL_DEPTH)
	prop.climb_height = height
	prop.climb_normal = Vector3(-float(d.x), 0.0, -float(d.y))
	if absf(prop.climb_normal.x) >= absf(prop.climb_normal.z):
		prop.climb_normal = Vector3(1.0 if prop.climb_normal.x >= 0.0 else -1.0, 0.0, 0.0)
	else:
		prop.climb_normal = Vector3(0.0, 0.0, 1.0 if prop.climb_normal.z >= 0.0 else -1.0)
	_obstacles[low_cell] = prop
	_obstacles[high_cell] = prop
	_entities.append(prop)
	if _should_load(prop.pos):
		_load_prop(prop)


func _commit_crate(cell: Vector2i) -> void:
	if not CRATE_ENABLED:
		return
	if cell == Vector2i.ZERO:
		return
	var pad: WorldProp = _pads.get(cell)
	if pad == null or _obstacles.has(cell):
		return
	var prop := WorldProp.new()
	prop.kind = PropKind.CRATE
	prop.cell = cell
	prop.dir = pad.dir
	prop.yaw_deg = pad.yaw_deg
	prop.side = -1.0 if _randf() < 0.5 else 1.0
	prop.size = WoodenCrate.CRATE_SIZE
	var right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(pad.yaw_deg))
	prop.pos = pad.pos + right * (0.95 * prop.side)
	prop.pos.y = pad.pos.y + prop.size.y * 0.5
	_obstacles[cell] = prop
	_entities.append(prop)
	if _should_load(prop.pos):
		_load_prop(prop)


func spawn_crate_loot(origin: Vector3) -> void:
	var count := _roll_battery_count()
	var p := player as Player
	var drain := get_parent().get_node_or_null("DrainMeter") as CanvasLayer
	for i in count:
		var bat := BatteryPickup.new()
		add_child(bat)
		var spread := Vector3(_randf_range(-0.38, 0.38), 0.22, _randf_range(-0.38, 0.38))
		bat.global_position = origin + spread
		bat.setup(BATTERY_RESTORE_PERCENT, BATTERY_PICKUP_RADIUS, p, drain)


func _roll_battery_count() -> int:
	var w0 := maxf(CRATE_LOOT_CHANCE_0, 0.0)
	var w1 := maxf(CRATE_LOOT_CHANCE_1, 0.0)
	var w2 := maxf(CRATE_LOOT_CHANCE_2, 0.0)
	var w3 := maxf(CRATE_LOOT_CHANCE_3, 0.0)
	var total := w0 + w1 + w2 + w3
	if total <= 0.0:
		return 0
	var roll := _rng.randf() * total
	if roll < w0:
		return 0
	if roll < w0 + w1:
		return 1
	if roll < w0 + w1 + w2:
		return 2
	return 3


# =============================================================================
# Frontier recovery
# =============================================================================

func _cull_ended_heads() -> void:
	var extending: Array = []
	var idle: Array = []
	for entry in _heads:
		var h: Head = entry
		if h == null or h.ended:
			continue
		if _should_extend(h):
			extending.append(h)
		elif _near_xz(_cell_world(h.cell, h.y), CLEANUP_DISTANCE):
			idle.append(h)
	if extending.size() > MAX_ACTIVE_CHUNKS:
		extending = extending.slice(0, MAX_ACTIVE_CHUNKS)
	var kept: Array = extending.duplicate()
	for h in idle:
		if kept.size() >= MAX_ACTIVE_CHUNKS:
			break
		kept.append(h)
	_heads = kept


func _ensure_frontier() -> void:
	if _has_live_frontier():
		return
	var pad := _nearest_pad()
	if pad != null:
		var tip := _walk_tip(pad)
		if tip != null and not _head_covers(tip.cell):
			var probe := _make_head(tip.cell, tip.pos.y, tip.dir, tip.path_id)
			if not _collect_valid_plans(probe).is_empty():
				_heads.append(probe)
				return
	_recover_at_player()


func _head_covers(cell: Vector2i) -> bool:
	for entry in _heads:
		var h: Head = entry
		if h != null and not h.ended and h.cell == cell:
			return true
	return false


func _has_live_frontier() -> bool:
	for entry in _heads:
		var h: Head = entry
		if h != null and not h.ended and _should_extend(h):
			return true
	return false


func _nearest_pad() -> WorldProp:
	if player == null:
		return null
	var best: WorldProp = null
	var best_d := CLEANUP_DISTANCE
	var px := player.global_position.x
	var pz := player.global_position.z
	for key in _pads:
		var pad: WorldProp = _pads[key]
		if pad == null:
			continue
		var d := Vector2(pad.pos.x - px, pad.pos.z - pz).length()
		if d < best_d:
			best_d = d
			best = pad
	return best


func _walk_tip(start: WorldProp) -> WorldProp:
	var cur := start
	for _i in 32:
		var nxt_cell := cur.cell + _delta(cur.dir)
		if not _pads.has(nxt_cell):
			return cur
		var nxt: WorldProp = _pads[nxt_cell]
		if nxt.path_id != cur.path_id:
			return cur
		cur = nxt
	return cur


func _recover_at_player() -> void:
	if player == null:
		return
	var origin := _world_cell(player.global_position)
	var y := snappedf(clampf(player.global_position.y, Y_LIMIT_MIN, Y_LIMIT_MAX), HEIGHT_SNAP)
	var fwd := Vector2i(0, -1)
	var look := player.global_transform.basis.z
	var lx := -look.x
	var lz := -look.z
	if absf(lx) >= absf(lz):
		fwd = Vector2i(1 if lx >= 0.0 else -1, 0)
	else:
		fwd = Vector2i(0, 1 if lz >= 0.0 else -1)
	var dir := 0
	if fwd.x > 0:
		dir = 1
	elif fwd.y > 0:
		dir = 2
	elif fwd.x < 0:
		dir = 3
	var reach := PATH_LENGTH * 0.5
	var min_steps := maxi(2, int(ceil((MIN_PLAYER_CLEARANCE + reach) / PATH_LENGTH)))
	for extra in 4:
		var cell := origin + fwd * (min_steps + extra)
		if _try_recover_cell(cell, y, dir):
			return


func _try_recover_cell(cell: Vector2i, y: float, dir: int) -> bool:
	if not _in_bounds(cell, y):
		return false
	if _pads.has(cell):
		var existing: WorldProp = _pads[cell]
		if _head_covers(existing.cell):
			return true
		var probe := _make_head(existing.cell, existing.pos.y, existing.dir, existing.path_id)
		if _collect_valid_plans(probe).is_empty():
			return false
		_heads.append(probe)
		return true
	if _blocked.has(cell):
		return false
	if player != null and _xz_gap_to_pad(cell, dir, player.global_position) < MIN_PLAYER_CLEARANCE:
		return false
	if not _foreign_spacing_ok(cell, dir, {}):
		return false
	_blocked.erase(cell)
	var pid := _next_path_id
	_next_path_id += 1
	var pad := _commit_pad(cell, y, dir, true, false, 0.0, pid)
	_heads.append(_make_head(pad.cell, pad.pos.y, pad.dir, pad.path_id))
	return true


# =============================================================================
# Streaming + cleanup
# =============================================================================

func _should_load(pos: Vector3) -> bool:
	return _near_xz(pos, SPAWN_AHEAD_DISTANCE)


func _should_unload(pos: Vector3) -> bool:
	return not _near_xz(pos, CLEANUP_DISTANCE)


func _head_owns(cell: Vector2i) -> bool:
	for entry in _heads:
		var h: Head = entry
		if h == null:
			continue
		if absi(h.cell.x - cell.x) <= 2 and absi(h.cell.y - cell.y) <= 2:
			return true
	return false


func _stream_visuals() -> void:
	for entry in _entities:
		var prop: WorldProp = entry
		if prop == null:
			continue
		var live := prop.node != null and is_instance_valid(prop.node)
		if live:
			if _should_unload(prop.pos):
				_unload_prop(prop)
		elif _should_load(prop.pos):
			_load_prop(prop)


func _forget_far_records() -> void:
	var kept: Array = []
	for entry in _entities:
		var prop: WorldProp = entry
		if prop == null:
			continue
		if _near_xz(prop.pos, CLEANUP_DISTANCE) or _head_owns(prop.cell):
			kept.append(prop)
			continue
		_unload_prop(prop)
		if prop.kind == PropKind.PAD:
			if _pads.get(prop.cell) == prop:
				_pads.erase(prop.cell)
			_blocked.erase(prop.cell)
			var occ: WorldProp = _obstacles.get(prop.cell)
			if occ != null:
				_clear_obstacle(occ)
		else:
			_clear_obstacle(prop)
	_entities = kept


func _clear_obstacle(prop: WorldProp) -> void:
	var drop: Array = []
	for key in _obstacles:
		if _obstacles[key] == prop:
			drop.append(key)
	for key in drop:
		_obstacles.erase(key)


# =============================================================================
# Debug counters (cheap)
# =============================================================================

func debug_loaded_platforms() -> int:
	return _stat_loaded_pads


func debug_loaded_obstacles() -> int:
	return _stat_loaded_obstacles


func debug_world_prop_count() -> int:
	return _entities.size()


func debug_procedural_pads() -> int:
	return _pads.size()


func debug_runtime_nodes() -> int:
	return _active_platforms.size()


func debug_path_head_count() -> int:
	return _heads.size()


func debug_invariant_errors() -> PackedStringArray:
	var errs: PackedStringArray = []
	var seen_obs: Dictionary = {}
	for key in _obstacles:
		var obs: WorldProp = _obstacles[key]
		if obs == null:
			errs.append("null obstacle at %s" % str(key))
			continue
		if obs.kind == PropKind.SLIDE or obs.kind == PropKind.VAULT:
			if seen_obs.has(key):
				errs.append("stacked obstacle cell %s" % str(key))
			seen_obs[key] = true
			var pad: WorldProp = _pads.get(key)
			if pad == null:
				errs.append("obstacle without pad at %s" % str(key))
			elif Vector2(obs.pos.x - pad.pos.x, obs.pos.z - pad.pos.z).length() > 0.01:
				errs.append("off-center obstacle at %s" % str(key))
			elif not is_equal_approx(obs.yaw_deg, pad.yaw_deg):
				errs.append("yaw mismatch at %s" % str(key))
		elif obs.kind == PropKind.CLIMB:
			if not _pads.has(obs.cell):
				errs.append("climb missing low pad")
	for key in _pads:
		var pad: WorldProp = _pads[key]
		if pad == null:
			continue
		if _pads[key] != pad:
			errs.append("pad dict mismatch")
		var nxt := pad.cell + _delta(pad.dir)
		if _pads.has(nxt):
			var n: WorldProp = _pads[nxt]
			if n.path_id == pad.path_id:
				var dy := absf(n.pos.y - pad.pos.y)
				if dy > 0.15 and dy < _drop_min() - 0.05:
					errs.append("staircase dy=%.2f at %s" % [dy, str(key)])
			elif _pads_would_touch(pad.cell, pad.dir, n.cell, n.dir):
				errs.append("foreign path touch at %s -> %s" % [str(pad.cell), str(n.cell)])
		var sep_r := _spacing_search_radius()
		for dx in range(0, sep_r + 1):
			for dz in range(-sep_r, sep_r + 1):
				if dx == 0 and dz <= 0:
					continue
				var other: WorldProp = _pads.get(Vector2i(pad.cell.x + dx, pad.cell.y + dz))
				if other == null:
					continue
				if absi(dx) + absi(dz) == 1:
					continue
				var dist := Vector2(float(dx) * PATH_LENGTH, float(dz) * PATH_LENGTH).length()
				if _dirs_parallel(pad.dir, other.dir) and not _parallel_gap_ok(dist):
					errs.append("parallel lanes spacing at %s and %s" % [str(pad.cell), str(other.cell)])
	return errs


# =============================================================================
# Visual spawn (unchanged models / groups / MachineKit)
# =============================================================================

func _load_prop(prop: WorldProp) -> void:
	if prop == null:
		return
	if prop.node != null and is_instance_valid(prop.node):
		return
	match prop.kind:
		PropKind.PAD:
			_load_pad(prop)
		PropKind.SLIDE:
			_load_slide(prop)
		PropKind.VAULT:
			_load_vault(prop)
		PropKind.CLIMB:
			_load_climb(prop)
		PropKind.CRATE:
			_load_crate(prop)


func _load_pad(prop: WorldProp) -> void:
	var chunk := platform_chunk.instantiate() as Node3D
	if chunk == null:
		push_error("LevelSpawner: platform_chunk must instantiate a Node3D.")
		return
	chunk.position = prop.pos
	chunk.rotation_degrees.y = prop.yaw_deg
	chunk.add_to_group("platform")
	chunk.set_meta("cell", prop.cell)
	_expand_floor_collision(chunk)
	add_child(chunk)
	_active_platforms.append(chunk)
	prop.node = chunk
	_stat_loaded_pads += 1
	if _kit != null:
		_kit.dress_platform(chunk, prop.tall, 0.0, prop.simple)
		if prop.jump_gap > 0.0:
			_kit.add_jump_scenery(chunk, prop.jump_gap)


func _load_slide(prop: WorldProp) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = prop.pos
	body.rotation_degrees.y = prop.yaw_deg
	var post := maxf(SLIDE_SUPPORT_THICKNESS, 0.16)
	var bar_d := maxf(SLIDE_BAR_DIAMETER, 0.12)
	var foot := post + 0.14
	var support_x := maxf((PATH_WIDTH - foot) * 0.5 - 0.08, 0.35)
	var bar_y := SLIDE_BAR_CLEARANCE + bar_d * 0.5
	var post_h := bar_y + bar_d * 0.5 + 0.08
	var bar_len := support_x * 2.0 + post
	var mat_post: Material = _kit.mat_metal if _kit != null else null
	var mat_foot: Material = _kit.mat_metal_light if _kit != null else null
	var mat_bar: Material = _kit.mat_pipe if _kit != null else null
	var mat_join: Material = _kit.mat_hazard if _kit != null else null
	for side: float in [-1.0, 1.0]:
		var sx := support_x * side
		_add_solid_box(body, Vector3(foot, 0.08, foot), Vector3(sx, 0.04, 0.0), mat_foot)
		_add_solid_box(body, Vector3(post, post_h, post), Vector3(sx, post_h * 0.5, 0.0), mat_post)
		_add_solid_box(
			body,
			Vector3(post + 0.08, bar_d + 0.1, post + 0.08),
			Vector3(sx, bar_y, 0.0),
			mat_join
		)
	_add_solid_cylinder(body, bar_d * 0.5, bar_len, Vector3(0.0, bar_y, 0.0), Vector3(0.0, 0.0, 90.0), mat_bar)
	add_child(body)
	_active_platforms.append(body)
	if _kit != null:
		_kit.dress_slide(body, support_x, post_h)
	prop.node = body
	_stat_loaded_obstacles += 1


func _load_vault(prop: WorldProp) -> void:
	var center := Vector3(prop.pos.x, prop.pos.y + prop.size.y * 0.5, prop.pos.z)
	var body := _place_static_box(prop.size, center, COLOR_VAULT)
	body.rotation_degrees.y = prop.yaw_deg
	body.add_to_group("vaultable")
	body.set_meta("vault_size", prop.size)
	if _kit != null:
		_kit.dress_vault(body, prop.size)
	prop.node = body
	_stat_loaded_obstacles += 1


func _load_climb(prop: WorldProp) -> void:
	var y_base := prop.pos.y
	var height := prop.climb_height
	var center := Vector3(prop.pos.x, y_base + height * 0.5, prop.pos.z)
	var body := _place_static_box(prop.size, center, COLOR_OBSTACLE, false)
	body.rotation_degrees.y = prop.yaw_deg
	body.add_to_group("climbable")
	body.set_meta("climb_top_y", y_base + height)
	body.set_meta("climb_bottom_y", y_base)
	body.set_meta("climb_size", prop.size)
	body.set_meta("climb_normal", prop.climb_normal)
	if _kit != null:
		_kit.dress_climb_wall(body, prop.size)
	prop.node = body
	_stat_loaded_obstacles += 1


func _load_crate(prop: WorldProp) -> void:
	var crate := WoodenCrate.new()
	crate.position = prop.pos
	crate.rotation_degrees.y = prop.yaw_deg
	add_child(crate)
	crate.setup(self, prop, _kit)
	prop.node = crate
	_active_platforms.append(crate)


func _unload_prop(prop: WorldProp) -> void:
	if prop == null:
		return
	if prop.node == null or not is_instance_valid(prop.node):
		prop.node = null
		return
	var idx := _active_platforms.find(prop.node)
	if idx >= 0:
		_active_platforms.remove_at(idx)
	if prop.kind == PropKind.PAD:
		_stat_loaded_pads = maxi(_stat_loaded_pads - 1, 0)
	elif prop.kind != PropKind.CRATE:
		_stat_loaded_obstacles = maxi(_stat_loaded_obstacles - 1, 0)
	prop.node.queue_free()
	prop.node = null


func _expand_floor_collision(chunk: Node3D) -> void:
	var col := chunk.find_child("CollisionShape3D", true, false) as CollisionShape3D
	if col == null:
		return
	var box := col.shape as BoxShape3D
	if box == null:
		return
	if _floor_shape == null:
		_floor_shape = BoxShape3D.new()
		_floor_shape.size = Vector3(
			box.size.x + FLOOR_COLLISION_SEAM,
			box.size.y,
			box.size.z + FLOOR_COLLISION_SEAM
		)
	col.shape = _floor_shape


func _shared_box_mesh(size: Vector3) -> BoxMesh:
	var key := Vector3(snappedf(size.x, 0.001), snappedf(size.y, 0.001), snappedf(size.z, 0.001))
	var mesh: BoxMesh = _mesh_boxes.get(key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_mesh_boxes[key] = mesh
	return mesh


func _shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := Vector3(snappedf(size.x, 0.001), snappedf(size.y, 0.001), snappedf(size.z, 0.001))
	var shape: BoxShape3D = _shape_boxes.get(key)
	if shape == null:
		shape = BoxShape3D.new()
		shape.size = size
		_shape_boxes[key] = shape
	return shape


func _shared_cyl_mesh(radius: float, height: float) -> CylinderMesh:
	var key := Vector3(snappedf(radius, 0.001), snappedf(height, 0.001), 12.0)
	var mesh: CylinderMesh = _mesh_cyls.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		_mesh_cyls[key] = mesh
	return mesh


func _shared_cyl_shape(radius: float, height: float) -> CylinderShape3D:
	var key := Vector3(snappedf(radius, 0.001), snappedf(height, 0.001), 0.0)
	var shape: CylinderShape3D = _shape_cyls.get(key)
	if shape == null:
		shape = CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_shape_cyls[key] = shape
	return shape


func _add_solid_box(body: StaticBody3D, size: Vector3, local_pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = _shared_box_mesh(size)
	inst.position = local_pos
	inst.material_override = mat if mat != null else _fallback_obstacle_mat()
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.shape = _shared_box_shape(size)
	col.position = local_pos
	body.add_child(col)


func _add_solid_cylinder(
	body: StaticBody3D,
	radius: float,
	height: float,
	local_pos: Vector3,
	rot_deg: Vector3,
	mat: Material
) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = _shared_cyl_mesh(radius, height)
	inst.position = local_pos
	inst.rotation_degrees = rot_deg
	inst.material_override = mat if mat != null else _fallback_obstacle_mat()
	body.add_child(inst)
	var col := CollisionShape3D.new()
	col.shape = _shared_cyl_shape(radius, height)
	col.position = local_pos
	col.rotation_degrees = rot_deg
	body.add_child(col)


func _fallback_obstacle_mat() -> StandardMaterial3D:
	if _mat_fallback == null:
		_mat_fallback = StandardMaterial3D.new()
		_mat_fallback.albedo_color = COLOR_OBSTACLE
	return _mat_fallback


func _place_static_box(size: Vector3, center: Vector3, color: Color, show_mesh: bool = true) -> Node3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	if show_mesh:
		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = _shared_box_mesh(size)
		if color.is_equal_approx(COLOR_VAULT):
			mesh_inst.material_override = _mat_vault
		else:
			mesh_inst.material_override = _fallback_obstacle_mat()
		body.add_child(mesh_inst)
	var col := CollisionShape3D.new()
	col.shape = _shared_box_shape(size)
	body.add_child(col)
	add_child(body)
	_active_platforms.append(body)
	return body
