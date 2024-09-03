class_name Weapon
extends CharacterBody2D



var _time = 0
var _animation_amplitude := 0.5
var _animation_frequency := 7
var _default_position = get_position()
var _owner_position_offset := Vector2.RIGHT
@onready var _attack_sprite := $AnimatedSprite2D
@export var attack_playing := false
@export var radius := 25
	

func _physics_process(delta: float) -> void:
	
	_move()
	_animate(delta)
	

func _move():
	
	var mouse_pos = get_global_mouse_position()
	var player_pos = owner.global_transform.origin 
	var distance = player_pos.distance_to(mouse_pos) 
	var mouse_dir = (mouse_pos-player_pos).normalized()
	mouse_pos = player_pos + (mouse_dir * radius)
	$".".global_transform.origin = mouse_pos
	
	if(mouse_dir.x < 0):
		_attack_sprite.flip_h = true
	else:
		_attack_sprite.flip_h = false


func _animate(delta: float) -> void:
	if(attack_playing == true):
		return
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	
