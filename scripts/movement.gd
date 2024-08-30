extends CharacterBody2D

var _state_machine
var _is_attacking : bool = false

@export_category("Variables")
@export var _move_speed = 120
var last_faced_direction := Vector2.RIGHT
var _direction := Vector2.ZERO
var is_attacking : bool

@export_category("Objects")
@onready var _animation_tree : AnimationTree = $AnimationTree

func _ready() -> void:
	_state_machine = _animation_tree["parameters/playback"]

func _physics_process(delta: float) -> void:
	
	_move()
	_attack()
	_animate()
	move_and_slide()
	

func _move() -> void:
	#moves in 4 directions
	_direction = Input.get_vector("left","right","up","down").normalized()
	#blend positions
	if(_direction != Vector2.ZERO):
		_animation_tree["parameters/idle/blend_position"] = _direction
		_animation_tree["parameters/run/blend_position"] = _direction
		_animation_tree["parameters/attack/blend_position"] = _direction
		last_faced_direction = _direction
	
	velocity = _direction * _move_speed
	
func _attack() -> void:
	if Input.is_action_just_pressed("attack") and not _is_attacking:
		_is_attacking = true
		set_physics_process(false)
		
	pass

func _animate() -> void:
	if _is_attacking:
		_state_machine.travel("attack")
		return
		
	if velocity.length() > 5:
		_state_machine.travel("run")
		return
	
	_state_machine.travel("idle")
	



func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "attack foward"
	or anim_name == "attack up"
	or anim_name == "attack left"
	or anim_name == "attack right"):
		_is_attacking = false
		set_physics_process(true)
