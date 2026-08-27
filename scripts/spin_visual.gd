extends Node3D
class_name SpinVisual

## Visual-only spin. Does not affect collision or player movement.

@export var axis: Vector3 = Vector3.RIGHT
@export var speed: float = 2.4


func _process(delta: float) -> void:
	if axis.length_squared() < 0.0001:
		return
	var target := get_parent() as Node3D
	if target == null:
		return
	target.rotate(axis.normalized(), speed * delta)
