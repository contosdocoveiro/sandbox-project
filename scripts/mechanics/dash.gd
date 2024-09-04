extends Node2D

@onready var _duration_timer = $DurationTimer
@onready var _dash_ghost = preload("res://scenes/dash_ghost.tscn")
@onready var _ghost_timer = $GhostTimer
var can_dash := true
var dash_cooldown := 0.4
var sprite

func start_dash(sprite, duration):
	self.sprite = sprite
	
	_duration_timer.wait_time = duration
	_duration_timer.start()
	
	_ghost_timer.start()
	instance_ghost()
	
	
func instance_ghost():
	var ghost: AnimatedSprite2D = _dash_ghost.instantiate()
	get_parent().get_parent().add_child(ghost)
	
	ghost.global_position = global_position
	ghost.sprite_frames = sprite.sprite_frames
	ghost.frame = sprite.frame
	ghost.flip_h = sprite.flip_h
	ghost.animation = sprite.animation
	ghost.speed_scale = sprite.speed_scale
	ghost.offset = sprite.offset

func is_dashing():
	return !_duration_timer.is_stopped()

func end_dash():
	_ghost_timer.stop()
	can_dash = false
	await get_tree().create_timer(dash_cooldown).timeout
	can_dash = true


func _on_duration_timer_timeout() -> void:
	end_dash()


func _on_ghost_timer_timeout() -> void:
	instance_ghost()
