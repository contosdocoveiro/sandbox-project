class_name Weapon
extends CharacterBody2D



var _time = 0
var _animation_amplitude := 0.5
var _animation_frequency := 7
var _default_position = get_position()
var _owner_position_offset := Vector2.RIGHT

func teleport_to_attack_location() -> void:
	set_position(_owner_position_offset)
	

func _physics_process(delta: float) -> void:
	
	_move()
	_animate(delta)
	

func _move():
	
	_owner_position_offset = owner.position
	
	
	if(owner.last_faced_direction == Vector2.RIGHT):
		_owner_position_offset[0] += 20
		_owner_position_offset[1] -= 20
	elif(owner.last_faced_direction == Vector2.LEFT):
		_owner_position_offset[0] -= 20
		_owner_position_offset[1] -= 20
	elif(owner.last_faced_direction == Vector2.UP):
		_owner_position_offset[0] -= 2
		_owner_position_offset[1] -= 5
	elif(owner.last_faced_direction == Vector2.DOWN):
		_owner_position_offset[0] -= 2
		_owner_position_offset[1] += 5
	
	global_transform.origin = lerp(global_transform.origin, _owner_position_offset, 0.025)


func _animate(delta: float) -> void:
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	


func _on_combo_1_state_entered() -> void:
	pass # Replace with function body.
