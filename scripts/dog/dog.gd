extends CharacterBody2D


@export_category("Variables")
@export var _move_speed = 120
@export var _life = 100
@onready var _state_machine := $DogStateMachine
var _direction := Vector2.ZERO
var _last_faced_direction := Vector2.RIGHT




func _physics_process(delta: float) -> void:
	
	_move()
	if(_state_machine._is_attacking == false):
		move_and_slide()
	
	

func _move() -> void:
	
	
	#moves in 4 directions
	_direction = Input.get_vector("left","right","up","down").normalized()
	
	if(_direction != Vector2.ZERO):
		_last_faced_direction = _direction
	
	#blend positions
	velocity = _direction * _move_speed
	
