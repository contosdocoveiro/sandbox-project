extends CharacterBody2D

@onready var animation_player = $AnimationPlayer

func take_damage(damage):
	animation_player.stop()
	animation_player.play("take damage")
	
