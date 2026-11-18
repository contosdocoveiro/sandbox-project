extends Node2D
class_name Dash

@export var actor: Node2D

@onready var _duration_timer = $DurationTimer
@onready var _dash_ghost = preload("res://components/movement/dash_ghost.tscn")
@onready var _ghost_timer = $GhostTimer
var can_dash := true
var dash_cooldown := 0.4
var sprite

func _ready() -> void:
	if(get_parent()):
		sprite = get_parent().find_child("Body")

func start_dash(duration):
	if(can_dash):
		_duration_timer.wait_time = duration
		_duration_timer.start()
	
		_ghost_timer.start()
	
	
func instance_ghost():
	var ghost: AnimatedSprite2D = _dash_ghost.instantiate()
	actor.get_parent().add_child(ghost)
	
	var origin = actor.global_position if actor else get_parent().global_position as Vector2
	
	ghost.sprite_frames = sprite.sprite_frames
	ghost.animation = sprite.animation
	ghost.frame = sprite.get_frame()
	ghost.flip_h = sprite.flip_h
	ghost.speed_scale = sprite.speed_scale
	ghost.offset = sprite.offset
	ghost.global_position = origin
	ghost.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	
func is_dashing():
	return !_duration_timer.is_stopped()

func end_dash():
	_duration_timer.stop()
	_ghost_timer.stop()
	can_dash = false
	await get_tree().create_timer(dash_cooldown).timeout
	sprite.position = Vector2.ZERO
	can_dash = true
	


func _on_duration_timer_timeout() -> void:
	end_dash()


func _on_ghost_timer_timeout() -> void:
	instance_ghost()
