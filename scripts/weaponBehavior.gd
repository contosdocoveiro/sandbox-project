extends CharacterBody2D

var _state_machine

@onready var _dog = $"../Dog"
@onready var _animation_tree : AnimationTree = $AnimationTree
var _time = 0
var _animation_amplitude := 0.5
var _animation_frequency := 7
var _default_position = get_position()
var _dog_position_offset : Vector2

func _ready() -> void:
	_state_machine = _animation_tree["parameters/playback"]

func teleport_to_attack_location() -> void:
	set_position(_dog_position_offset)
	

func _physics_process(delta: float) -> void:
	
	_move()
	_attack()
	_animate(delta)
	

func _move():
	
	_dog_position_offset = _dog.position
	
	
	if(_dog.last_faced_direction == Vector2.RIGHT):
		_dog_position_offset[0] += 2
		_dog_position_offset[1] -= 5
	elif(_dog.last_faced_direction == Vector2.LEFT):
		_dog_position_offset[0] -= 2
		_dog_position_offset[1] -= 5
	elif(_dog.last_faced_direction == Vector2.UP):
		_dog_position_offset[0] -= 2
		_dog_position_offset[1] -= 5
	elif(_dog.last_faced_direction == Vector2.DOWN):
		_dog_position_offset[0] -= 2
		_dog_position_offset[1] += 5
	
	global_transform.origin = lerp(global_transform.origin, _dog_position_offset, 0.025)
	
	if(_dog._direction != Vector2.ZERO):
		_animation_tree["parameters/attack/blend_position"] = _dog._direction
		
func _attack() -> void:
	if Input.is_action_just_pressed("attack") and not _dog._is_attacking:
		set_physics_process(false)
	
func _animate(delta: float) -> void:
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	
	if _dog._is_attacking:
		if(_dog_position_offset.distance_squared_to(get_position()) > 5000):
			teleport_to_attack_location()
		_state_machine.travel("attack")
		return
	
	_state_machine.travel("idle")


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "slash down"
	or anim_name == "slash up"
	or anim_name == "slash left"
	or anim_name == "slash right"):
		set_physics_process(true)
