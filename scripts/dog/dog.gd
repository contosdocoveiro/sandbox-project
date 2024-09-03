extends CharacterBody2D


@export_category("Variables")
@export var _move_speed = 120
@onready var _state_machine := $DogStateMachine
var _direction := Vector2.ZERO




func _physics_process(delta: float) -> void:
	
	_move()
	
	if(_state_machine._is_attacking == false):
		move_and_slide()
	
	

func _move() -> void:
	
	
	#moves in 4 directions
	_direction = Input.get_vector("left","right","up","down").normalized()
	#blend positions
	velocity = _direction * _move_speed
	
