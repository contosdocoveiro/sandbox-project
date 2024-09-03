extends Node

@export_category("Variables")
@export var can_input_attack := false
@export var _attack_buffer_timer := 0.5


@onready var _attack_sprite = $"../AnimatedSprite2D"
@onready var _animation_player = $"../AnimationPlayer"
@onready var _state_chart = $"../StateChart"
@onready var _sword = $".."
@onready var _sword_attack_sprite = $"../AnimatedSprite2D"

var _attack_buffer := false

func _store_attack_buffer() -> void:
	_attack_buffer = true
	print("entrei!")
	get_tree().create_timer(_attack_buffer_timer).timeout.connect(_on_attack_buffer_timeout)

func _on_attack_buffer_timeout() -> void:
	_attack_buffer = false

func _physics_process(delta: float) -> void:
	_detect_states()
		
		
func _detect_states() -> void:
	if(Input.is_action_just_pressed("attack")):
		_state_chart.send_event("attack_pressed")

func _on_combo_1_state_entered() -> void:
	_sword_attack_sprite.rotation = _sword.angle_to_mouse
	_sword.global_transform.origin = _sword.mouse_pos
	_animation_player.play("combo 1")


func _on_combo_1_state_physics_processing(delta: float) -> void:
	if(Input.is_action_just_pressed("attack")):
		if(can_input_attack):
			_state_chart.send_event("attack_pressed_mid_combo")
		else:
			_store_attack_buffer()
	if(_attack_buffer and can_input_attack):
		_state_chart.send_event("attack_pressed_mid_combo")


func _on_idle_state_entered() -> void:
	_animation_player.play("idle entered")

func _on_combo_2_state_physics_processing(delta: float) -> void:
	if(Input.is_action_just_pressed("attack")):
		if(can_input_attack):
			_state_chart.send_event("attack_pressed_mid_combo")
		else:
			_store_attack_buffer()
	if(_attack_buffer and can_input_attack):
		_state_chart.send_event("attack_pressed_mid_combo")
	
func _on_combo_2_state_entered() -> void:
	_sword_attack_sprite.rotation = _sword.angle_to_mouse
	_sword.global_transform.origin = _sword.mouse_pos
	_animation_player.play("combo 2")
	
	

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if(anim_name == "combo 1" or "combo 2"):
		if(anim_name == "combo 1"):
			_animation_player.play("combo 1 end")
		elif(anim_name == "combo 2"):
			_animation_player.play("combo 2 end")
	if(anim_name == "idle entered"):
		_animation_player.play("RESET")
	
	if(anim_name == "combo 1 end" or "combo 2 end" or "combo 3"):
		if(!_animation_player.is_playing()):
			_state_chart.send_event("combo_finished")


func _on_combo_3_state_entered() -> void:
	_sword_attack_sprite.rotation = _sword.angle_to_mouse
	_sword.global_transform.origin = _sword.mouse_pos
	_animation_player.play("combo 3")
