extends Node

@onready var _state_chart = $"../StateChart"
@onready var _animation_player = $"../AnimationPlayer"
@onready var _sprite = $"../Body"

var _is_attacking := false
var mouse_dir := Vector2(0,0)

func _physics_process(delta: float) -> void:
	_detect_states()
	

func _detect_states() -> void:
	
	var mouse_pos = $"..".get_global_mouse_position()
	var player_pos = owner.global_transform.origin 
	mouse_dir = (mouse_pos-player_pos).normalized()
	
	if(Input.is_action_just_pressed("attack")):
		_state_chart.send_event("attacking")
	elif($"..".velocity != Vector2(0,0) and _is_attacking == false):
		_state_chart.send_event("running")
	elif(_is_attacking == false and $"..".velocity == Vector2(0,0)):
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
	
	_animation_player.play("idle sideways")


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
