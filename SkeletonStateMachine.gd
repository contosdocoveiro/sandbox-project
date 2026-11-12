extends Node

@onready var state_chart = $"../StateChart"
@onready var animation_player = $"../AnimationPlayer"
@onready var sprite = $"../Body"
@export var is_attacking := false
@export var attack_cooldown : Timer

var attack_ready = true
	

func _on_idle_state_entered() -> void:
	animation_player.play("idle")
func _on_idle_state_physics_processing(delta: float) -> void:
	if (owner.is_in_attack_range and attack_ready):
		state_chart.send_event("attacking")
	elif (owner.velocity != Vector2.ZERO and !is_attacking):
		state_chart.send_event("walking")



func _on_walking_state_entered() -> void:
	animation_player.play("walk")
func _on_walking_state_physics_processing(delta: float) -> void:
	if (owner.is_in_attack_range and attack_ready):
		state_chart.send_event("attacking")
	elif owner.velocity == Vector2.ZERO:
		state_chart.send_event("idle")


func _on_attacking_state_entered() -> void:
	if attack_ready:
		animation_player.play("attack")
		attack_ready = false
		attack_cooldown.start()

func _on_attack_cooldown_timeout() -> void:
	attack_ready = true
	print("atack_ready")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if (anim_name == "attack"):
		print("acabou")
		state_chart.send_event("idle")
