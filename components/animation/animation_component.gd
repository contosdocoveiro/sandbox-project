class_name AnimationComponent
extends Node2D

@export var actor : CharacterBody2D
@export var animation_player : AnimationPlayer
@export var sprite : Node2D
	

func animate() -> void:
	pass
	
func play(anim: StringName, restart := false) -> void:
	if anim == &"":
		return
	if restart and animation_player.current_animation == anim:
		animation_player.stop()
	animation_player.play(anim)

func face_x(x: float) -> void:
	if absf(x) > 0.01:
		sprite.flip_h = x < 0.0
