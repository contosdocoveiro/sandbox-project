extends CharacterBody2D


@export_category("Variables")
@export var _move_speed = 120
var last_faced_direction := Vector2.RIGHT
var _direction := Vector2.ZERO


func _physics_process(delta: float) -> void:
	
	_move()
	move_and_slide()
	

func _move() -> void:
	#moves in 4 directions
	_direction = Input.get_vector("left","right","up","down").normalized()
	#blend positions
	if(_direction != Vector2.ZERO):
		last_faced_direction = _direction
	
	velocity = _direction * _move_speed
	
