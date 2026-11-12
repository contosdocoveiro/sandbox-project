class_name PlayerAnimationComponent
extends AnimationComponent

var input_component
var last_direction : Vector2
var current_animation_length : float

func _ready() -> void:
	input_component = actor.find_child("PlayerInputComponent")
	state_manager = actor.find_child("PlayerStateManagerComponent")
	

func animate():
	if(input_component.input_direction != Vector2.ZERO):
		last_direction = input_component.input_direction
	if(state_manager.current_state == "attacking"):
		animate_attacking()
	elif(state_manager.current_state == "running"):
		animate_running()
	elif(state_manager.current_state == "idle"):
		animate_idle()
	pass
	
func animate_idle():
	if(last_direction.x != 0):
		if(last_direction.x > 0):
			sprite.flip_h = false
		else:
			sprite.flip_h = true
		animation_player.play("idle sideways")
	else:
		if(last_direction.y > 0):
			animation_player.play("idle down")
		else:
			animation_player.play("idle up")

func animate_attacking():
	if(animation_player.is_playing()):
		animation_player.stop()
	var mouse_pos = owner.get_global_mouse_position()
	var player_pos = owner.global_transform.origin 
	var mouse_dir = (mouse_pos-player_pos).normalized()
	
	if((mouse_dir.x)**2 > (mouse_dir.y)**2):
		if(mouse_dir.x < 0):
			sprite.flip_h = true
		else:
			sprite.flip_h = false
		animation_player.play("attack sideways")
		
	elif(mouse_dir.x < mouse_dir.y):
		animation_player.play("attack down")
	else:
		animation_player.play("attack up")
	
func animate_running():
	if(input_component.move_input_key == "left" or
	input_component.move_input_key == "right"):
		animation_player.play("run sideways")
		if(input_component.move_input_key == "left"):
			sprite.flip_h = true
		else:
			sprite.flip_h = false
	elif(input_component.move_input_key == "up"):
		animation_player.play("run up")
	elif(input_component.move_input_key == "down"):
		animation_player.play("run down")
