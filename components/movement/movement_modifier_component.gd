class_name MovementModifierComponent
extends Node

@export var physics_component: PhysicsComponent

var _modifiers: Dictionary = {}   # StringName -> multiplier
var _timers: Dictionary = {}      # StringName -> remaining seconds

func add(source: StringName, multiplier: float, duration := -1.0) -> void:
	_modifiers[source] = maxf(multiplier, 0.0)
	if duration > 0.0:
		_timers[source] = duration
	else:
		_timers.erase(source)
	_refresh()

func remove(source: StringName) -> void:
	_modifiers.erase(source)
	_timers.erase(source)
	_refresh()

func get_speed_scale() -> float:
	var scale := 1.0
	for value in _modifiers.values():
		scale *= value
	return scale

func _process(delta: float) -> void:
	if _timers.is_empty():
		return

	for source in _timers.keys():
		_timers[source] -= delta
		if _timers[source] <= 0.0:
			remove(source)

func _refresh() -> void:
	if physics_component:
		physics_component.speed_scale = get_speed_scale()
