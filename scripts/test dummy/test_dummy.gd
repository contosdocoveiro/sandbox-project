extends CharacterBody2D

@onready var _animation_player = $AnimationPlayer
@onready var _damage_number_position =$DamageNumbersOrigin

func take_damage(damage):
	_animation_player.stop()
	_animation_player.play("take damage")
	DamageNumbers.display_number(damage, _damage_number_position.global_position, true)
	
	
	
