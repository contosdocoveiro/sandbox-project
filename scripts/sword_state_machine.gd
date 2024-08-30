extends Node

@export_category("Variables")
@export var can_input_attack := false

@onready var _animation_player = $"../AnimationPlayer"
@onready var _state_chart = $"../StateChart"

func _physics_process(delta: float) -> void:
	_detect_states()
		
		
func _detect_states() -> void:
	if(Input.is_action_just_pressed("attack")):
		_on_attack_pressed()
		
func _on_attack_pressed():
	_state_chart.send_event("attack_pressed")


func _on_combo_1_state_entered() -> void:
	_animation_player.play("combo 1")


func _on_combo_1_state_physics_processing(delta: float) -> void:
	if(Input.is_action_just_pressed("attack") and can_input_attack):
		_state_chart.send_event("attack_pressed_combo1")


func _on_idle_state_entered() -> void:
	_animation_player.play("idle")

func _on_combo_2_state_physics_processing(delta: float) -> void:
	_animation_player.play("combo 2")
	
	



func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if(anim_name == "combo 1" or "combo 2"):
		_state_chart.send_event("combo_finished")
