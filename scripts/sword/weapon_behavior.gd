extends CharacterBody2D



var _time = 0
var _animation_amplitude := 0.5
var _animation_frequency := 7
var _default_position = get_position()
var _owner_position_offset := Vector2.RIGHT
var mouse_pos = Vector2(0,0)
var angle_to_mouse
@onready var _animation_player = $AnimationPlayer
@onready var _attack_sprite := $AnimatedSprite2D
@export var attack_playing := false
@export var radius := 16
@export var combo_finished := false
	

func _physics_process(delta: float) -> void:
	
	_move()
	_animate(delta)
	

func _move():
	
	
	mouse_pos = get_global_mouse_position()
	angle_to_mouse = global_position.direction_to(mouse_pos).angle()
	var player_pos = owner.global_transform.origin 
	var distance = player_pos.distance_to(mouse_pos)
	var mouse_dir = (mouse_pos-player_pos).normalized()
	mouse_pos = player_pos + (mouse_dir * radius)
	
	if(!_animation_player.is_playing()):
		global_transform.origin = lerp(global_transform.origin, mouse_pos, 0.05)

	
	if(combo_finished):
		$AnimatedSprite2D.rotation = 0
		return
	
	if(distance > radius):
		return
	else:
		mouse_pos = player_pos + (owner._last_faced_direction * radius)
		angle_to_mouse = owner._last_faced_direction.angle()
		

func _animate(delta: float) -> void:
	
	if(attack_playing == true):
		return
	_default_position = get_position()
	_time += delta * _animation_frequency
	set_position(_default_position + Vector2(0, sin(_time)*_animation_amplitude))
	
