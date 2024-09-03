extends Node

@export_category("Variables")
@export var can_input_attack := false

@onready var _combo1_hitbox = $"../AnimatedSprite2D/combo 1 hitbox/combo 1 hitbox shape"
@onready var _combo2_hitbox = $"../AnimatedSprite2D/combo 2 hitbox/combo 2 hitbox shape"
@onready var _combo3_hitbox = $"../AnimatedSprite2D/combo 3 hitbox/combo 3 hitbox shape"
@onready var _attack_sprite = $"../AnimatedSprite2D"
@onready var _animation_player = $"../AnimationPlayer"
@onready var _state_chart = $"../StateChart"
@onready var _sword = $".."
@onready var _sword_attack_sprite = $"../AnimatedSprite2D"

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
	if(Input.is_action_just_pressed("attack") and can_input_attack):
		_state_chart.send_event("attack_pressed_mid_combo")


func _on_idle_state_entered() -> void:
	_animation_player.play("idle entered")

func _on_combo_2_state_physics_processing(delta: float) -> void:
	if(Input.is_action_just_pressed("attack") and can_input_attack):
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
