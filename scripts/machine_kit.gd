extends RefCounted
class_name MachineKit

## Shared industrial look for platforms and obstacles.
## Visual only: never adds gameplay collision.

const DANGER := Color(0.32, 0.05, 0.04, 1.0)
const DANGER_GLOW := Color(0.38, 0.06, 0.04, 1.0)
const ENERGY := Color(0.24, 0.06, 0.05, 1.0)
const METAL := Color(0.16, 0.14, 0.12, 1.0)
const METAL_LIGHT := Color(0.24, 0.2, 0.16, 1.0)
const CONCRETE := Color(0.2, 0.18, 0.15, 1.0)
const WOOD := Color(0.16, 0.1, 0.05, 1.0)
const WOOD_DARK := Color(0.08, 0.045, 0.025, 1.0)
const WOOD_STAIN := Color(0.12, 0.04, 0.03, 1.0)

var rng: RandomNumberGenerator
var mat_metal: StandardMaterial3D
var mat_metal_light: StandardMaterial3D
var mat_concrete: StandardMaterial3D
var mat_hazard: StandardMaterial3D
var mat_energy: StandardMaterial3D
var mat_glass: StandardMaterial3D
var mat_warn: StandardMaterial3D
var mat_pipe: StandardMaterial3D
var mat_wood: StandardMaterial3D
var mat_wood_dark: StandardMaterial3D
var mat_wood_stain: StandardMaterial3D
var _box_meshes: Dictionary = {}
var _cyl_meshes: Dictionary = {}


func setup(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	var noise := _make_noise()
	mat_metal = _metal(METAL, 0.45, 0.78, noise)
	mat_metal_light = _metal(METAL_LIGHT, 0.35, 0.82, noise)
	mat_concrete = _concrete(noise)
	mat_hazard = _hazard()
	mat_energy = _energy()
	mat_glass = _glass()
	mat_warn = _warn_light()
	mat_pipe = _metal(Color(0.14, 0.11, 0.09, 1.0), 0.5, 0.9, noise)
	mat_wood = _wood(WOOD, noise)
	mat_wood_dark = _wood(WOOD_DARK, noise)
	mat_wood_stain = _wood(WOOD_STAIN, noise)


func dress_platform(chunk: Node3D, tall_decor: bool = true, pillar_side: float = 0.0, simple: bool = false) -> void:
	var mesh_inst := chunk.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh_inst != null:
		mesh_inst.material_override = mat_metal
	_add_deck_plate(chunk)
	if simple:
		return
	_add_side_rails(chunk)
	_add_underside_pipes(chunk)
	_add_bolts(chunk, Vector3(2.7, -0.02, 5.1), 6)
	if rng.randf() < 0.35:
		_add_edge_lights(chunk)
	if not tall_decor:
		return
	# Keep columns on the outer edge so they cannot punch through a slide bar
	# on this pad or a neighboring lane.
	if rng.randf() < 0.55:
		var side := pillar_side
		if is_zero_approx(side):
			side = 1.0 if rng.randf() < 0.5 else -1.0
		_add_side_pillar(chunk, side)
	if rng.randf() < 0.4:
		_add_side_panel(chunk, pillar_side)


func dress_slide(body: Node3D, support_x: float, post_top_y: float) -> void:
	# Details only. Posts, feet, sleeves, and the pipe already have collision.
	for side: float in [-1.0, 1.0]:
		var x := support_x * side
		_add_warning_lamp(body, Vector3(x, post_top_y + 0.03, 0.0))
		_box(body, Vector3(0.07, 0.04, 0.07), Vector3(x, 0.1, 0.16), mat_pipe)
		_box(body, Vector3(0.07, 0.04, 0.07), Vector3(x, 0.1, -0.16), mat_pipe)


func dress_vault(body: Node3D, size: Vector3) -> void:
	# Hide the collider mesh. Planks and posts fill that same box so the
	# vault collider and the visible barricade occupy the same volume.
	_hide_primary_mesh(body)
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5

	var post_xs: Array[float] = [-hx + 0.12, rng.randf_range(-0.16, 0.16), hx - 0.12]
	for i in post_xs.size():
		var pw := rng.randf_range(0.12, 0.16)
		var pd := rng.randf_range(0.16, 0.22)
		var px := clampf(post_xs[i], -hx + pw * 0.5, hx - pw * 0.5)
		var pz := clampf(rng.randf_range(-0.05, 0.03), -hz + pd * 0.5, hz - pd * 0.5)
		var post := _box(body, Vector3(pw, size.y, pd), Vector3(px, 0.0, pz), _barricade_wood())
		post.rotation_degrees = Vector3(0.0, rng.randf_range(-1.2, 1.2), rng.randf_range(-0.7, 0.7))
		# Foot sits on the pad under the post.
		var fw := pw + 0.07
		var fd := pd + 0.05
		_box(body, Vector3(fw, 0.07, fd), Vector3(px, -hy + 0.035, pz), _barricade_wood())

	# Sill board on the deck, tying the posts together.
	_box(body, Vector3(size.x * 0.96, 0.07, 0.11), Vector3(0.0, -hy + 0.035, -0.06), mat_wood_dark)

	var plank_count := rng.randi_range(3, 4)
	var start_y := -hy + 0.08
	var end_y := hy - 0.012
	var gap := 0.018
	var slot := (end_y - start_y - gap * float(plank_count - 1)) / float(plank_count)
	for i in plank_count:
		var ph := clampf(slot + rng.randf_range(-0.025, 0.025), 0.11, 0.22)
		var pw := rng.randf_range(size.x * 0.88, size.x * 0.98)
		var pd := rng.randf_range(0.14, 0.2)
		var px := rng.randf_range(-0.05, 0.05)
		var pz := rng.randf_range(0.02, 0.09)
		var y := start_y + float(i) * (slot + gap) + ph * 0.5
		px = clampf(px, -hx + pw * 0.5, hx - pw * 0.5)
		pz = clampf(pz, -hz + pd * 0.5, hz - pd * 0.5)
		y = clampf(y, -hy + ph * 0.5, hy - ph * 0.5)
		var plank := _box(body, Vector3(pw, ph, pd), Vector3(px, y, pz), _barricade_wood())
		plank.rotation_degrees = Vector3(
			rng.randf_range(-0.6, 0.6),
			rng.randf_range(-0.8, 0.8),
			rng.randf_range(-0.7, 0.7)
		)
		# Nail heads where a plank meets the outer posts.
		_add_pipe(body, Vector3(-hx + 0.14, y, pz + pd * 0.45), Vector3(90.0, 0.0, 0.0), 0.04, 0.015)
		_add_pipe(body, Vector3(hx - 0.14, y, pz + pd * 0.45), Vector3(90.0, 0.0, 0.0), 0.04, 0.015)

	# Diagonal braces between posts, kept inside the collider box.
	var lean := 22.0 if rng.randf() < 0.5 else -22.0
	var brace := _box(body, Vector3(1.05, 0.08, 0.07), Vector3(-0.28, -0.06, -0.02), mat_wood_stain)
	brace.rotation_degrees = Vector3(0.0, 0.0, lean)
	var brace_b := _box(body, Vector3(1.05, 0.08, 0.07), Vector3(0.28, -0.06, -0.02), mat_wood_dark)
	brace_b.rotation_degrees = Vector3(0.0, 0.0, -lean)


func _barricade_wood() -> Material:
	var roll := rng.randf()
	if roll < 0.45:
		return mat_wood
	if roll < 0.8:
		return mat_wood_dark
	return mat_wood_stain


func dress_climb_wall(body: Node3D, size: Vector3) -> void:
	# Hide the collider mesh so there is no slab behind the ladder.
	for child in body.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
	var face_z := size.z * 0.5 + 0.04
	# Rails span the full climb height so they meet both decks.
	var left := _box(body, Vector3(0.16, size.y, 0.18), Vector3(-0.42, 0.0, face_z), mat_wood)
	left.rotation_degrees = Vector3(rng.randf_range(-1.2, 1.2), 0.0, rng.randf_range(-2.8, -0.6))
	var right := _box(body, Vector3(0.16, size.y, 0.18), Vector3(0.44, 0.0, face_z), mat_wood_dark)
	right.rotation_degrees = Vector3(rng.randf_range(-1.0, 1.6), 0.0, rng.randf_range(0.5, 3.2))
	# Thick rungs: uneven spacing, some warped, some missing or snapped.
	var y := -size.y * 0.5 + rng.randf_range(0.22, 0.36)
	var top := size.y * 0.5 - 0.18
	while y < top:
		var roll := rng.randf()
		if roll < 0.12:
			_box(body, Vector3(0.06, 0.06, 0.07), Vector3(-0.4, y, face_z + 0.04), mat_pipe)
		elif roll < 0.24:
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var stub := _box(
				body,
				Vector3(rng.randf_range(0.28, 0.42), 0.09, 0.12),
				Vector3(0.28 * side, y, face_z + 0.03),
				mat_wood_stain
			)
			stub.rotation_degrees = Vector3(
				rng.randf_range(-8.0, 8.0),
				rng.randf_range(-10.0, 10.0),
				rng.randf_range(14.0, 32.0) * side
			)
		else:
			var rung := _box(
				body,
				Vector3(rng.randf_range(0.82, 0.98), rng.randf_range(0.09, 0.12), rng.randf_range(0.12, 0.16)),
				Vector3(rng.randf_range(-0.04, 0.05), y, face_z + 0.03),
				mat_wood if rng.randf() < 0.7 else mat_wood_stain
			)
			rung.rotation_degrees = Vector3(
				rng.randf_range(-5.0, 5.0),
				rng.randf_range(-3.0, 3.0),
				rng.randf_range(-8.0, 8.0)
			)
		y += rng.randf_range(0.38, 0.55)
	_add_warning_lamp(body, Vector3(-0.5, size.y * 0.46, face_z + 0.08))


func add_jump_scenery(chunk: Node3D, gap_depth: float) -> void:
	var mid := -gap_depth * 0.45
	_add_energy_ring(chunk, Vector3(0.0, 1.35, mid), rng.randf_range(1.7, 2.2))
	if rng.randf() < 0.7:
		_add_side_pillar(chunk, 1.0)
	if rng.randf() < 0.7:
		_add_side_pillar(chunk, -1.0)
	# Hanging machine guts in the void, no collision.
	if rng.randf() < 0.5:
		_add_pipe(chunk, Vector3(rng.randf_range(-1.2, 1.2), -0.7, mid), Vector3(90.0, 0.0, 0.0), rng.randf_range(2.5, 4.5), 0.07)


func _hide_primary_mesh(body: Node3D) -> void:
	var mesh_inst := body.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh_inst != null:
		mesh_inst.visible = false


func _add_deck_plate(chunk: Node3D) -> void:
	var plate := _box(chunk, Vector3(2.78, 0.05, 5.22), Vector3(0.0, -0.02, 0.0), mat_metal_light)
	plate.name = "Deck"
	# Bevel lip so the walkable top is not a razor cube.
	_box(chunk, Vector3(2.96, 0.04, 5.42), Vector3(0.0, -0.12, 0.0), mat_metal)


func _add_side_rails(chunk: Node3D) -> void:
	_box(chunk, Vector3(0.08, 0.12, 5.3), Vector3(-1.48, 0.02, 0.0), mat_pipe)
	_box(chunk, Vector3(0.08, 0.12, 5.3), Vector3(1.48, 0.02, 0.0), mat_pipe)


func _add_underside_pipes(chunk: Node3D) -> void:
	var count := rng.randi_range(1, 3)
	for i in count:
		var x := rng.randf_range(-1.1, 1.1)
		_add_pipe(chunk, Vector3(x, -0.42, 0.0), Vector3(90.0, 0.0, 0.0), rng.randf_range(3.8, 5.4), rng.randf_range(0.05, 0.09))


func _add_edge_lights(chunk: Node3D) -> void:
	var zs := [-2.4, 2.4]
	for z in zs:
		if rng.randf() < 0.4:
			_add_warning_lamp(chunk, Vector3(-1.42, 0.05, z))
		if rng.randf() < 0.4:
			_add_warning_lamp(chunk, Vector3(1.42, 0.05, z))


func _add_side_pillar(chunk: Node3D, side: float) -> void:
	var h := rng.randf_range(3.2, 6.5)
	var x := 3.8 * side
	# Sit at a pad corner, not mid-pad, so a low obstacle in the lane stays clear.
	var z := 2.2 if rng.randf() < 0.5 else -2.2
	_box(chunk, Vector3(0.55, h, 0.55), Vector3(x, h * 0.5 - 0.3, z), mat_concrete)
	_box(chunk, Vector3(0.7, 0.12, 0.7), Vector3(x, h - 0.18, z), mat_metal)
	if rng.randf() < 0.45:
		_add_warning_lamp(chunk, Vector3(x, h - 0.05, z))
	# Pipes only stick outward, never back toward the walkable lane / slide bar.
	if rng.randf() < 0.45:
		_add_pipe(chunk, Vector3(x + 0.7 * side, h * 0.4, z), Vector3(0.0, 0.0, 90.0), rng.randf_range(1.0, 1.6), 0.08)


func _add_side_panel(chunk: Node3D, pillar_side: float = 0.0) -> void:
	var side := pillar_side
	if is_zero_approx(side):
		side = 1.0 if rng.randf() < 0.5 else -1.0
	var z := 2.0 if rng.randf() < 0.5 else -2.0
	var panel := _box(chunk, Vector3(0.08, 1.4, 1.6), Vector3(2.35 * side, 0.55, z), mat_metal)
	panel.name = "HullPanel"
	if rng.randf() < 0.5:
		var glass := _box(chunk, Vector3(0.04, 0.55, 0.7), panel.position + Vector3(-0.07 * side, 0.1, 0.0), mat_glass)
		glass.name = "Glass"


func _add_energy_ring(parent: Node3D, local_pos: Vector3, radius: float) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "RustRing"
	var torus := TorusMesh.new()
	torus.inner_radius = radius * 0.82
	torus.outer_radius = radius
	torus.rings = 10
	torus.ring_segments = 16
	ring.mesh = torus
	ring.material_override = mat_pipe
	ring.position = local_pos
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	parent.add_child(ring)
	var spin := SpinVisual.new()
	spin.axis = Vector3.FORWARD
	spin.speed = rng.randf_range(0.08, 0.22)
	ring.add_child(spin)


func _add_pipe(parent: Node3D, pos: Vector3, rot_deg: Vector3, height: float, radius: float) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = _shared_cyl(radius, height, 8)
	inst.material_override = mat_pipe
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


func _add_bolts(parent: Node3D, span: Vector3, count: int) -> void:
	for i in count:
		var u := (float(i) + 0.5) / float(count) - 0.5
		var pos := Vector3(u * span.x, span.y, (1.0 if i % 2 == 0 else -1.0) * span.z * 0.5)
		var bolt := MeshInstance3D.new()
		bolt.mesh = _shared_cyl(0.035, 0.05, 6)
		bolt.material_override = mat_pipe
		bolt.position = pos
		bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(bolt)


func _add_warning_lamp(parent: Node3D, pos: Vector3) -> void:
	var lamp := MeshInstance3D.new()
	lamp.mesh = _shared_box(Vector3(0.08, 0.05, 0.08))
	lamp.material_override = mat_warn
	lamp.position = pos
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp.set_script(preload("res://scripts/flicker_light.gd"))
	parent.add_child(lamp)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = _shared_box(size)
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst


func _shared_box(size: Vector3) -> BoxMesh:
	var key := Vector3(snappedf(size.x, 0.01), snappedf(size.y, 0.01), snappedf(size.z, 0.01))
	var mesh: BoxMesh = _box_meshes.get(key)
	if mesh == null:
		mesh = BoxMesh.new()
		mesh.size = size
		_box_meshes[key] = mesh
	return mesh


func _shared_cyl(radius: float, height: float, segments: int) -> CylinderMesh:
	var key := Vector3(snappedf(radius, 0.001), snappedf(height, 0.001), float(segments))
	var mesh: CylinderMesh = _cyl_meshes.get(key)
	if mesh == null:
		mesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = segments
		_cyl_meshes[key] = mesh
	return mesh


func _make_noise() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_VALUE
	noise.frequency = 0.14
	noise.fractal_octaves = 4
	noise.seed = rng.randi()
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.normalize = true
	return tex


func _metal(color: Color, metallic: float, roughness: float, noise: NoiseTexture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = noise
	mat.metallic = metallic
	mat.roughness = roughness
	mat.roughness_texture = noise
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.55, 0.55, 0.55)
	mat.uv1_triplanar_sharpness = 4.0
	return mat


func _concrete(noise: NoiseTexture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CONCRETE
	mat.albedo_texture = noise
	mat.metallic = 0.05
	mat.roughness = 0.92
	mat.roughness_texture = noise
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	return mat


func _wood(color: Color, noise: NoiseTexture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.albedo_texture = noise
	mat.metallic = 0.0
	mat.roughness = 0.95
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(0.85, 0.22, 0.85)
	return mat


func _hazard() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DANGER
	mat.metallic = 0.15
	mat.roughness = 0.72
	mat.emission_enabled = true
	mat.emission = DANGER_GLOW
	mat.emission_energy_multiplier = 0.28
	return mat


func _energy() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.05, 0.04, 0.7)
	mat.metallic = 0.2
	mat.roughness = 0.55
	mat.emission_enabled = true
	mat.emission = ENERGY
	mat.emission_energy_multiplier = 0.32
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _glass() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.05, 0.5)
	mat.metallic = 0.05
	mat.roughness = 0.45
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.06, 0.04, 1.0)
	mat.emission_energy_multiplier = 0.04
	return mat


func _warn_light() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DANGER
	mat.metallic = 0.1
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = DANGER_GLOW
	mat.emission_energy_multiplier = 0.85
	return mat
