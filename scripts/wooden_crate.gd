extends StaticBody3D
class_name WoodenCrate

## Locked wooden crate. Takes knife slices to open, then spills batteries.

const CRATE_SIZE := Vector3(0.72, 0.7, 0.72)

var _spawner: LevelSpawner
var _record: Variant
var _hits: int = 0
var _opened: bool = false
var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _lid: MeshInstance3D
var _hit_flash: float = 0.0


func setup(spawner: LevelSpawner, record: Variant, kit: MachineKit) -> void:
	_spawner = spawner
	_record = record
	collision_layer = 1
	collision_mask = 0
	add_to_group("crate")
	_build_visual(kit)
	if record != null:
		_hits = int(record.hits)
		_opened = bool(record.opened)
	if _opened:
		_apply_opened(false)
	else:
		_apply_damage_visual()


func take_hit() -> void:
	if _opened:
		return
	_hits += 1
	_hit_flash = 0.12
	if _record != null:
		_record.hits = _hits
	var need := 3
	if _spawner != null:
		need = maxi(_spawner.CRATE_HITS_TO_OPEN, 1)
	if _hits >= need:
		_apply_opened(true)
	else:
		_apply_damage_visual()


func is_locked() -> bool:
	return not _opened


func _build_visual(kit: MachineKit) -> void:
	var wood: Material = null
	var wood_dark: Material = null
	var band: Material = null
	if kit != null:
		wood = kit.mat_wood
		wood_dark = kit.mat_wood_dark
		band = kit.mat_metal
	else:
		wood = _make_mat(Color(0.42, 0.26, 0.12, 1.0))
		wood_dark = _make_mat(Color(0.22, 0.12, 0.06, 1.0))
		band = _make_mat(Color(0.18, 0.16, 0.13, 1.0))

	_mesh = MeshInstance3D.new()
	_mesh.name = "Body"
	var box := BoxMesh.new()
	box.size = CRATE_SIZE
	_mesh.mesh = box
	_mesh.material_override = wood
	add_child(_mesh)

	# Dark edge bands so it reads as a crate, not a cube.
	_add_box(Vector3(CRATE_SIZE.x + 0.02, 0.06, 0.08), Vector3(0.0, CRATE_SIZE.y * 0.22, CRATE_SIZE.z * 0.5), band)
	_add_box(Vector3(CRATE_SIZE.x + 0.02, 0.06, 0.08), Vector3(0.0, -CRATE_SIZE.y * 0.22, CRATE_SIZE.z * 0.5), band)
	_add_box(Vector3(0.08, CRATE_SIZE.y + 0.02, 0.08), Vector3(CRATE_SIZE.x * 0.5, 0.0, 0.0), wood_dark)
	_add_box(Vector3(0.08, CRATE_SIZE.y + 0.02, 0.08), Vector3(-CRATE_SIZE.x * 0.5, 0.0, 0.0), wood_dark)

	_lid = MeshInstance3D.new()
	_lid.name = "Lid"
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(CRATE_SIZE.x + 0.04, 0.08, CRATE_SIZE.z + 0.04)
	_lid.mesh = lid_mesh
	_lid.material_override = wood_dark
	_lid.position = Vector3(0.0, CRATE_SIZE.y * 0.5 + 0.02, 0.0)
	add_child(_lid)

	_col = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = CRATE_SIZE
	_col.shape = shape
	add_child(_col)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	inst.mesh = mesh
	inst.position = pos
	inst.material_override = mat
	add_child(inst)


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _apply_damage_visual() -> void:
	# Placeholder stages: darker and a bit more beaten with each slice.
	var stage := clampf(float(_hits) / 3.0, 0.0, 1.0)
	var shake := 1.5 * stage
	rotation_degrees.z = shake
	if _mesh != null:
		_mesh.scale = Vector3.ONE * (1.0 - 0.04 * stage)


func _apply_opened(spawn_loot: bool) -> void:
	_opened = true
	if _record != null:
		_record.opened = true
		_record.hits = _hits
	remove_from_group("crate")
	collision_layer = 0
	if _col != null:
		_col.disabled = true
	if _lid != null:
		_lid.position = Vector3(0.18, CRATE_SIZE.y * 0.42, -0.08)
		_lid.rotation_degrees = Vector3(-70.0, 8.0, 12.0)
	if _mesh != null:
		_mesh.scale = Vector3(1.0, 0.55, 1.0)
		_mesh.position.y = -CRATE_SIZE.y * 0.12
	if spawn_loot and _record != null and not bool(_record.looted):
		_record.looted = true
		if _spawner != null:
			_spawner.spawn_crate_loot(global_position)


func _process(delta: float) -> void:
	if _hit_flash <= 0.0:
		if scale != Vector3.ONE:
			scale = Vector3.ONE
		return
	_hit_flash = maxf(_hit_flash - delta, 0.0)
	var punch := _hit_flash / 0.12
	scale = Vector3.ONE * (1.0 - 0.06 * punch)
