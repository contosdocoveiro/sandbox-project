extends Node
class_name DogStateMachine

@onready var _state_chart = $"../StateChart"
@onready var _animation_player = $"../AnimationPlayer"
@onready var _sprite = $"../Body"
@onready var _sword = $"../Sword"
@onready var _dash = $"../Dash"
var _last_pressed
var _is_attacking := false
var mouse_dir := Vector2(0,0)


func send_attack_signal() -> void:
	_state_chart.send_event("attacking")

func _physics_process(delta: float) -> void:
	_detect_states()
	


func _detect_states() -> void:
	
	var mouse_pos = $"..".get_global_mouse_position()
	var player_pos = owner.global_transform.origin 
	mouse_dir = (mouse_pos-player_pos).normalized()
	
	if(Input.is_action_just_pressed("left")):
		_last_pressed = "left"
	if(Input.is_action_just_pressed("right")):
		_last_pressed = "right"
	if(Input.is_action_just_pressed("down")):
		_last_pressed = "down"
	if(Input.is_action_just_pressed("up")):
		_last_pressed = "up"
	
	
	if($"..".velocity != Vector2(0,0) and _is_attacking == false and _dash.is_dashing() == false):
		_state_chart.send_event("running")
	elif(_is_attacking == false and $"..".velocity == Vector2(0,0) and _dash.is_dashing() == false):
		_state_chart.send_event("idle")
	


func _on_attack_state_entered() -> void:
	
	if((mouse_dir.x)**2 > (mouse_dir.y)**2):
		if(mouse_dir.x < 0):
			_sprite.flip_h = true
		else:
			_sprite.flip_h = false
		_animation_player.play("attack sideways")
	elif(mouse_dir.x < mouse_dir.y):
		_animation_player.play("attack down")
	else:
		_animation_player.play("attack up")
	_is_attacking = true


func _on_idle_state_entered() -> void:
	
	if(_last_pressed == "left" or _last_pressed == "right"):
		_animation_player.play("idle sideways")
	elif(_last_pressed == "down"):
		_animation_player.play("idle down")
	else:
		_animation_player.play("idle up")

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if((anim_name == "attack up" or "attack down" or "attack sideways")):
			_state_chart.send_event("idle")
			_is_attacking = false


func _on_running_state_processing(delta: float) -> void:
	if(Input.is_action_pressed("right")):
		_sprite.flip_h = false
		_animation_player.play("run sideways")
	elif(Input.is_action_pressed("left")):
		_sprite.flip_h = true
		_animation_player.play("run sideways")
	elif(Input.is_action_pressed("up")):
		_animation_player.play("run up")
	elif(Input.is_action_pressed("down")):
		_animation_player.play("run down")
		
	if(Input.is_action_just_pressed("dash")):
		_state_chart.send_event("dashing")


func _on_dashing_state_entered() -> void:
	if(_last_pressed == "left" or _last_pressed == "right"):
		_animation_player.play("dash sideways")
	elif(_last_pressed == "down"):
		_animation_player.play("dash down")
	else:
		_animation_player.play("dash up")
