extends CharacterBody2D
class_name PlayableCharacter


@export_category("Variables")
@export var _move_speed = 120
@export var life = 100
@export var dash_speed = 250
@export var dash_duration = 0.2
@export var _state_machine : PlayerStateMachine
@export var dash : Dash
@export var _sprite : Node2D

var knockback_vector := Vector2.ZERO
var _direction := Vector2.ZERO
var _last_faced_direction := Vector2.RIGHT


func send_attack_signal() -> void:
	_state_machine.send_attack_signal()

func _physics_process(delta: float) -> void:
	
	if Input.is_action_just_pressed("dash") and dash.can_dash and !dash.is_dashing():
		dash.start_dash(dash_duration)
	
	_move()
	move_and_slide()

func _move() -> void:
	
	
	#moves in 4 directions
	_direction = Input.get_vector("left","right","up","down").normalized()
	
	if(_direction != Vector2.ZERO):
		_last_faced_direction = _direction
	
	if(dash.is_dashing()):
		velocity = _direction * dash_speed
	
	elif(_state_machine._is_attacking):
		velocity = _direction * (_move_speed/2)
	else:
		velocity = _direction * _move_speed
	
