extends MeshInstance3D
class_name FlickerLight

## Dim, irregular flicker for horror lamps. Visual only.

var _base_energy: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	if material_override != null:
		material_override = material_override.duplicate()
		_base_energy = material_override.emission_energy_multiplier
	_time = randf() * 20.0


func _process(delta: float) -> void:
	if material_override == null or not material_override.emission_enabled:
		return
	_time += delta
	var pulse := absf(sin(_time * 6.1) * sin(_time * 11.7 + 0.4))
	var energy := _base_energy * (0.28 + 0.72 * pulse)
	if randf() < 0.018:
		energy *= 0.08
	material_override.emission_energy_multiplier = energy
