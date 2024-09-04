extends CharacterBody2D

@onready var detection_area = $DetectionArea
@export var _life = 100
@onready var animation_player = $AnimationPlayer
@onready var _damage_number_position =$DamageNumbersOrigin




func take_damage(damage): #Damage function
	animation_player.stop()
	animation_player.play("take damage")
	_life -= damage
	DamageNumbers.display_number(damage, _damage_number_position.global_position)




func _physics_process(delta: float) -> void: #Movement Function that follows player
	#if detection_area._player_ref != null:
		#var _direction: Vector2 = global_position.direction_to(detection_area._player_ref.global_position)
		#velocity = _direction * 30
		#move_and_slide()
	pass
