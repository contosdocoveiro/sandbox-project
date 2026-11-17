class_name StateManagerComponent extends Node2D

signal state_changed(previous: StringName, current: StringName)

@export var actor : CharacterBody2D
@export var animation_component : AnimationComponent
var input_component : InputComponent
var current_state : StringName = &""

func set_state(next: StringName) -> void:
	if next == current_state:
		return
	var previous := current_state
	current_state = next
	state_changed.emit(previous, next)
