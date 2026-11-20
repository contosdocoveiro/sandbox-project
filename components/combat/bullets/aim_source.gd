class_name AimSource
extends Node2D

enum Mode { MOUSE, TARGET, FIXED, RANDOM }

@export var mode := Mode.MOUSE
@export var origin: Node2D
@export var target: Node2D
@export var fixed_angle_degrees := 0.0
@export var random_spread_degrees := 360.0

func get_origin() -> Vector2:
	return origin.global_position if is_instance_valid(origin) else global_position

func get_aim_angle() -> float:
	match mode:
		Mode.MOUSE:
			return (get_global_mouse_position() - get_origin()).angle()
		Mode.TARGET:
			if is_instance_valid(target):
				return (target.global_position - get_origin()).angle()
		Mode.RANDOM:
			var half := deg_to_rad(random_spread_degrees) * 0.5
			return randf_range(-half, half)
		_:
			return deg_to_rad(fixed_angle_degrees)
	return 0.0
